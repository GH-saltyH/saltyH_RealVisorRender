"""Same physical readback: exact command comparison and allocation workload."""
from pathlib import Path
import runpy,re,json,time
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s69'
env=runpy.run_path(str(ROOT/'docs/tools/check_baked_housing.py'));Runtime=type(env['lua'])
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8');runtime={}
for k,v in re.findall(r'\b(RAIN_\w+)\s*=\s*(true|false|-?\d+(?:\.\d+)?)\s*,',source):
    runtime.setdefault(k,v=='true' if v in ('true','false') else float(v))
count=4096;sites=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/spawn_sites.dds').read_bytes(),'<f4',offset=148).reshape(-1,4)[:count]
du=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/du.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
dv=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/dv.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
u=du[(sites[:,1]*512).astype(int),(sites[:,0]*2048).astype(int),:3].astype(float)
v=dv[(sites[:,1]*512).astype(int),(sites[:,0]*2048).astype(int),:3].astype(float)
a=np.sum(u*u,1);b=np.sum(u*v,1);c=np.sum(v*v,1);force=np.array([0,0,-1.])
velocity=np.stack((c*(u@force)-b*(v@force),a*(v@force)-b*(u@force)),1)/(a*c-b*b)[:,None]
velocity/=np.maximum(np.linalg.norm(u*velocity[:,0,None]+v*velocity[:,1,None],axis=1),1e-8)[:,None]
velocity*=.001/.0029296875
report=[];commands={}
for label,path in [('s68',OUT/'baseline/realvisor.lua'),('s69',ROOT/'realvisor.lua')]:
    lua=Runtime();lua.globals().runtime=lua.table_from(runtime);lua.globals().folder=ROOT.as_posix()
    lua.execute('''
        ffi=require('ffi');cfg={RUNTIME=runtime};rainDynamicSceneCopyState={}
        rgbm=setmetatable({colors={transparent={}}},{__call=function(_,r,g,b,a) return {r=r,g=g,b=b,mult=a} end})
        function vec2(x,y) return {x=x or 0,y=y or 0} end
        render={TextureFormat={R8G8B8A8={UNorm=1}}};commands={}
        ui={ExtraCanvas=function() return {setName=function(self) return self end,
            clear=function() for k in pairs(commands) do commands[k]=nil end end,dispose=function() end,
            update=function(_,fn) fn() end} end,
            drawRectFilled=function(p1,p2,color) commands[p1.x]=color.r*65536+color.g*256+color.b end}
        rainDynamicStateHasSnapshot=true;rainDynamicStateReadbackCount=4096
        rainDynamicStateSnapshotTime=0;rainDynamicStateRenderClock=.05
    ''')
    surface=lua.execute((ROOT/'rain_surface.lua').read_text(encoding='utf-8'))(ROOT.as_posix(),lua.globals().runtime)
    lua.globals().rainDynamicSceneCopyState['surface']=surface
    for key,values in [('U',sites[:,0]),('V',sites[:,1]-1),('Alive',np.ones(count)),('Radius',np.full(count,.00085)),
                       ('VelocityU',velocity[:,0]*1.4),('VelocityV',velocity[:,1]*1.4)]:
        lua.globals()['rainDynamicState'+key]=lua.table_from(values.tolist())
    text=path.read_text(encoding='utf-8');start=text.index('rainDynamicSceneCopyState.updateMergeCommands = function(')
    stop=text.index('-- SDK render.measure',start);lua.execute(text[start:stop])
    lua.execute('''
        state=rainDynamicSceneCopyState;state.generation={}
        for i=1,4096 do state.generation[i]=(i*17)%128 end
        function step(k) rainDynamicStateSnapshotTime=k;rainDynamicStateRenderClock=k+.05;return state.updateMergeCommands(4096,true) end
        for i=1,10 do step(i) end
    ''')
    timings=[]
    for i in range(20):
        start=time.perf_counter();lua.globals().step(i+20);timings.append((time.perf_counter()-start)*1000)
    commands[label]={int(k):float(value) for k,value in lua.globals().commands.items()}
    lua.execute('''
        collectgarbage('collect');beforeKB=collectgarbage('count');collectgarbage('stop')
        for i=1,100 do step(i+100) end
        allocationKB=collectgarbage('count')-beforeKB;collectgarbage('restart');collectgarbage('collect')
    ''')
    state=lua.globals().state
    row={'source':label,'slots':count,'median_cpu_ms':float(np.median(timings)),
         'lua_allocation_kb_per_100_snapshots':float(lua.globals().allocationKB),
         'pairs':int(state['mergePairs']),'attracts':int(state['mergeAttracts']),
         'candidate_checks':int(state['mergeCandidateChecks']),'maximum_bucket':int(state['mergeMaximumBucket'])}
    report.append(row);print(json.dumps(row),flush=True)
assert commands['s68']==commands['s69'],'Linked grid must retain exact ascending candidate/tie order and encoded commands'
assert report[1]['lua_allocation_kb_per_100_snapshots']<report[0]['lua_allocation_kb_per_100_snapshots']*.2
(OUT/'merge_benchmark.json').write_text(json.dumps({'cases':report,'commands_equal':True},indent=2))
print('PASS: actual 4096-slot geometry produces identical merge/steer commands with bounded reusable scratch')
