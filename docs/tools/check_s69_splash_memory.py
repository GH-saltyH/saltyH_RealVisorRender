"""Replay actual old/new collectors/CPU consumers with persistent rain events."""
from pathlib import Path
import runpy,re,json
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s69'
env=runpy.run_path(str(ROOT/'docs/tools/check_baked_housing.py'));Runtime=type(env['lua'])
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
runtime={}
for k,v in re.findall(r'\b(RAIN_\w+)\s*=\s*(true|false|-?\d+(?:\.\d+)?)\s*,',source):
    runtime.setdefault(k,v=='true' if v in ('true','false') else float(v))
setup='''
    rainDynamicSceneCopyState={}
    cfg={RUNTIME=runtime};cfg.RUNTIME.RAIN_GPU_SPLASH=false
    ac={getCar=function() return {speedKmh=150} end}
    rainDynamicStateRadius={};rainDynamicStateRenderClock=0
    function rainDynamicSurfaceFrac(x) return x-math.floor(x) end
    function vec2() return {} end;function rgbm() return {} end
    ui={drawImageQuad=function() end}
    surface={valid=function() return true end,quad=function() return true end,
        updateAtlas=function(_,target,size,callback) callback() end}
    target={};stamps={}
    for i=1,64 do
        stamps[i]={index=i,x=500+i,y=250,radius=3}
        rainDynamicStateRadius[i]=.0012
    end
    function freshState()
        painted=0;state={surface=surface,newTrailActive=true,birthSeenAt={},generation={}}
        state.waterKernel=function() return {} end
        state.splashReference=function() return 8 end;state.splashMinimum=function() return .7 end
        state.waterFieldSplashV2=function(quad,origin) assert(origin);painted=painted+1;return 1 end
        for i=1,64 do state.birthSeenAt[i]=0;state.generation[i]=0 end
        return state
    end
'''
report=[]
for label,path in [('s68_leaking',OUT/'baseline/realvisor.lua'),('s69_bounded',ROOT/'realvisor.lua')]:
    lua=Runtime();lua.globals().runtime=lua.table_from(runtime);lua.execute(setup)
    code=path.read_text(encoding='utf-8')
    a=code.index('rainDynamicSceneCopyState.waterFieldCollectGpuSplash = function')
    b=code.index('rainDynamicSceneCopyState.waterFieldDrawStamps = function',a)
    lua.execute(code[a:b])
    lua.execute('''
        state=nil;collectgarbage('collect');beforeKB=collectgarbage('count');freshState()
        for frame=1,300 do
            rainDynamicStateRenderClock=frame/60
            local age=(frame%12)/60+.05
            for i=1,64 do state.generation[i]=math.floor(frame/12);state.birthSeenAt[i]=rainDynamicStateRenderClock-age end
            rainDynamicSceneCopyState.waterFieldCollectGpuSplash(state,stamps,2048)
            rainDynamicSceneCopyState.waterFieldDrawCpuSplash(state,target,2048)
            state.gpuOverrides={} -- existing gpuOverrideWrite consumes this each real frame
        end
        collectgarbage('collect');retainedKB=collectgarbage('count')-beforeKB
        activeList=#state.gpuSplashList;paintCount=painted
        poolCount=0;for _ in pairs(state.cpuSplashItems or {}) do poolCount=poolCount+1 end
        -- Final splash events repeatedly completed after the transient effect.
        for cycle=1,300 do
            rainDynamicStateRenderClock=cycle+100
            for i=1,64 do state.generation[i]=cycle+1000;state.birthSeenAt[i]=rainDynamicStateRenderClock-1 end
            rainDynamicSceneCopyState.waterFieldCollectGpuSplash(state,stamps,2048)
        end
        pendingCount=state.pendingSplash and #state.pendingSplash or 0
    ''')
    row={'source':label,'frames':300,'active_slots':64,'painted_events':int(lua.globals().paintCount),
         'retained_transient_list':int(lua.globals().activeList),'retired_trail_queue':int(lua.globals().pendingCount),
         'retained_lua_kb_after_collection':float(lua.globals().retainedKB),'cpu_item_pool':int(lua.globals().poolCount)}
    report.append(row);print(json.dumps(row),flush=True)
assert report[0]['retained_transient_list']>10000 and report[0]['retired_trail_queue']==19200
assert report[1]['retained_transient_list']==0 and report[1]['retired_trail_queue']==0
assert report[1]['painted_events']<=300*64 and report[1]['cpu_item_pool']<=64
assert report[1]['retained_lua_kb_after_collection']<report[0]['retained_lua_kb_after_collection']*.15
# An old generation must never borrow the current slot's impact geometry.
lua.execute('''
    painted=0;state.gpuSplashList={{1,0,0,1,1,.1,-1}}
    rainDynamicSceneCopyState.waterFieldDrawCpuSplash(state,target,2048)
    assert(painted==0 and #state.gpuSplashList==0)
''')
(OUT/'splash_memory_checks.json').write_text(json.dumps(report,indent=2))
print('PASS: unbounded CPU splash replay/retired queue reproduced and removed; stale generations excluded')
