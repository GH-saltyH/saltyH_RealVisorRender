"""Real Lua: transported visual preview, cache, long supported trail, actual hook."""
from pathlib import Path
import json,runpy,re,time
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s65'
env=runpy.run_path(str(ROOT/'docs/tools/check_s62_runtime.py'));lua=env['lua']
lua.execute('''
    q1,q2,q3,q4=vec2(),vec2(),vec2(),vec2()
    -- Fast preview used to freeze at >20 mm. Its current result stays supported.
    local u,v=.5,-.5
    local du,dv=surface:offset(u,v,1.4,0)
    local U,V=surface:preview(u,v,du,dv,.05,1)
    assert(surface:valid(U,V))
    assert(surface:length(u,v,U-u,V-v)*surface:unit()>.02)
    assert(surface:segment(u,v,U,V),'A supported fast same-generation path must connect')
    local a,b=surface:preview(u,v,du,dv,.05,1);assert(a==U and b==V)
    local changedU,changedV=surface:preview(u,v,du*.5,dv*.5,.05,1)
    assert(changedU~=U or changedV~=V,'Preview cache must invalidate velocity changes')
    local x,y=surface:preview(u,v,100,-100,.05,2)
    assert(surface:valid(x,y),'High velocity cannot turn blank metric cells into full-screen quads')
    assert(surface:ribbon(q1,q2,q3,q4,900,900,910,912,2,1,0,2048))
    local crossX,crossY=surface:plane(900/2048,900/2048-1,(q4.x-q1.x)/2048,(q4.y-q1.y)/2048)
    local tangentX,tangentY=surface:plane(900/2048,900/2048-1,10/2048,12/2048)
    assert(math.abs(crossX*tangentX+crossY*tangentY)<1e-10)
    assert(math.abs(math.sqrt(crossX*crossX+crossY*crossY)*2048-4)<1e-8)
''')
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
baseline=(OUT/'baseline/realvisor.lua').read_text(encoding='utf-8')
def block(text,anchor):
    a=text.index('[[',text.index(anchor))+2;return text[a:text.index(']]',a)]
for n in ('rainStateUpdateParams','rainStateMetaUpdateParams'):
    assert block(source,'local '+n+' = {')==block(baseline,'local '+n+' = {'),n
assert (ROOT/'shaders/rainSurfaceMetric.hlsl').read_bytes()==(OUT/'baseline/shaders/rainSurfaceMetric.hlsl').read_bytes()
manifest=json.loads((OUT/'baseline/manifest.json').read_text())
import hashlib
for f in ('settings.ini','settings_mats.ini','native_glass_state.lua','visor_optics.lua'):
    assert hashlib.sha256((ROOT/f).read_bytes()).hexdigest()==manifest[f]['sha256'],f
# Execute the actual new capture, with point depth reconstruction bindings,
# pending failure and resize disposal. Also assert binding at the live rain draw.
a=source.index('rainDynamicSceneCopyState.rainOcclusionUpdate = function()')
b=source.index("-- phase 'pre'",a)
lua.execute('''
    sim={cameraClipNear=.0035,cameraClipFar=1000};ac={getSim=function() return sim end}
    render.getRenderTargetSize=function() return vec2(1280,720) end
    render.TextureFormat.R32G32={Float=1}
    render.BlendMode.Opaque=1;pending=false
    function ui.ExtraCanvas() return {setName=function(self) return self end,
        dispose=function(self) self.disposed=true end,
        updateSceneWithShader=function(self,p) self.params=p;return not pending end} end
''')
lua.execute(source[a:b])
lua.execute('''
    bakedCalls=0;allocated=0
    occlusionCanvas=ui.ExtraCanvas
    render.TextureFormat.R16G16B16A16={Float=1}
    cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_ENABLED=true;cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_USE_TEXTURE=true
    cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_R_TILING=1;cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_G_TILING=2.5
    function ui.ExtraCanvas(size)
        allocated=allocated+1;assert(size.x==2048 and size.y==512)
        return {setName=function(self) return self end,updateWithShader=function(self,p)
            bakedCalls=bakedCalls+1;return not pending end}
    end
    rainDynamicSceneCopyState.smearTexturePath='mask.png'
''')
a=source.index('rainDynamicSceneCopyState.smearBake = function(state)')
b=source.index('rainDynamicSceneCopyState.smearUpdate =',a)
lua.execute(source[a:b])
lua.execute('''
    local s=rainDynamicSceneCopyState
    for i=1,1000 do s.smearBake(s) end
    assert(allocated==1 and bakedCalls==1 and s.smearBakeReady)
    cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_G_TILING=3;s.smearBake(s)
    assert(allocated==1 and bakedCalls==2)
    cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_G_TILING=4;pending=true;s.smearBake(s);assert(not s.smearBakeReady)
    pending=false;s.smearBake(s);assert(s.smearBakeReady and bakedCalls==4)
    ui.ExtraCanvas=occlusionCanvas
''')
lua.execute('''
    local s=rainDynamicSceneCopyState;s.rainOcclusionUpdate();local old=s.rainOcclusion
    assert(s.rainOcclusionReady and old.params.textures.txSceneDepth=='dynamic::depth')
    pending=true;s.rainOcclusionUpdate();assert(s.rainOcclusion==old and not s.rainOcclusionReady)
    render.getRenderTargetSize=function() return vec2(640,360) end
    pending=false;s.rainOcclusionUpdate();assert(old.disposed and s.rainOcclusionReady)
''')
a=source.index("    local sceneStackOk,sceneStackError = pcall(rainDynamicSceneCopyState.measure,'Glass pre'")
b=source.index('    -- s53: glass in front of the rain',a)
lua.execute('''
    cfg.RUNTIME.RAIN_DYNAMIC_DROP_DEPTH_OFF=false;cfg.RUNTIME.RAIN_DYNAMIC_DROP_UV_DEBUG=false
    rainDynamicSceneCopyState.measure=function(_,fn,...) return fn(...) end
    rainDynamicSceneCopyState.visorSceneStack=function() return true end
    rainDynamicSceneCopyState.e1SourceEditor=function() return {visible=true} end
    render.CullMode={None=0};render.DepthMode={Off=2,ReadOnly=1};render.BlendMode.BlendAccurate=4
    render.setCullMode=function(v) end;render.setDepthMode=function(v) currentDepth=v end
    render.setBlendMode=function(v) currentBlend=v end
    render.mesh=function(p)
        assert(currentDepth==1 and currentBlend==4)
        assert(p.textures.txDynamicOcclusion and p.values.gDynamicDropOcclusionOn==1)
        return true
    end
    dropMeshParams={textures={},values={}}
''')
lua.execute(source[a:b])
start=source.index('rainDynamicSceneCopyState.visorSceneStack = function(phase)')
finish=source.index('-- Called inside the overlay GeometryShot',start)
lua.execute(source[start:finish])
lua.execute('''
    local s=rainDynamicSceneCopyState
    cfg.RUNTIME.RAIN_VISOR_SCENE_STACK=true;cfg.RUNTIME.RAIN_VISOR_OVERLAY=false
    cfg.RUNTIME.RAIN_VISOR_LAYER_OPTICS=true
    render.BlendMode.BlendPremultiplied=3
    s.visorLayer={shader='ready',defs={housing={},glass={{mesh='COAT',kind=2},{rain=true},
        {mesh='INT',kind=3},{mesh='EXT',kind=1}}}}
    s.nativeGlass={update=function() return true end}
    s.mainTargetWidth=1280;s.mainTargetHeight=720
    s.cachedOptics={needsComposite=function() return false end}
    s.visorLayerSceneHide=function() end;s.e1SurfaceDraw=function() end
    s.visorOpticsCapture=function() return not capturePending and 'post-rain' or nil end
    fxDraws={}
    s.visorLayerDrawItem=function(item,ov)
        fxDraws[item.mesh]=(fxDraws[item.mesh] or 0)+1
        if item.kind==3 then assert(ov.src=='post-rain') end
    end
    s.visorSceneStack('pre');s.visorSceneStack('post')
    assert(fxDraws.COAT==1 and fxDraws.INT==1 and fxDraws.EXT==1 and s.visorLayer.opticsReady)
    capturePending=true;s.visorSceneStack('post')
    assert(fxDraws.INT==1 and fxDraws.EXT==2 and not s.visorLayer.opticsReady)
''')
prepare=source[source.index('-- Complete GPU and transport preparation'):source.index('rainDynamicSceneCopyState.updateTrailMask =')]
assert prepare.index("'Water canvases total'")<prepare.index("'Wipe mask'")
(OUT/'runtime_checks.json').write_text(json.dumps({'physical_gpu_code_byte_identical':True,
 'settings_and_accepted_lighting_unchanged':True,'fast_transport_preview_and_cache':True,
 'supported_long_trail_connects':True,'occlusion_resize_and_pending':True,'live_rain_guard_and_readonly_state':True,
 'actual_INT_EXT_after_rain_and_pending_capture_gate':True,'GPU_sweep_prepared_before_wipe':True},indent=2))
print('PASS: fast preview/cache/long trails, endpoint ribbon frames, static smear bake/retry, unchanged GPU physics/light/settings, live occlusion')

# Fresh cache each run measures actual changing snapshots, not cache-hit timing.
bench=(ROOT/'docs/tools/bench_s64_cpu.py').read_text(encoding='utf-8')
e={'__file__':str(ROOT/'docs/tools/bench_s64_cpu.py')};exec(bench[:bench.index('report=[]')],e)
ll=e['lua'];report=[]
for label,path,surfacepath in [('s64',OUT/'baseline/realvisor.lua',OUT/'baseline/rain_surface.lua'),
 ('s65',ROOT/'realvisor.lua',ROOT/'rain_surface.lua')]:
    factory=ll.execute(surfacepath.read_text(encoding='utf-8'))
    surface=factory(ROOT.as_posix(),ll.globals().cfg['RUNTIME'])
    ll.globals().rainDynamicSceneCopyState['surface']=surface
    code=path.read_text(encoding='utf-8');anchor=e['anchor'];end=e['end']
    ll.execute(code[code.index(anchor):code.index(end,code.index(anchor))])
    for scenario,speed in [('stationary',0),('driving',1.4)]:
        ll.globals().rainDynamicStateVelocityU=ll.table_from((e['vel'][:,0]*speed).tolist())
        ll.globals().rainDynamicStateVelocityV=ll.table_from((e['vel'][:,1]*speed).tolist())
        times=[]
        for i in range(8):
            ll.execute(f'rainDynamicStateSnapshotTime={i};rainDynamicStateRenderClock={i+.05};rainDynamicSceneCopyState.surface.previews=nil')
            start=time.perf_counter();ll.globals().rainDynamicSceneCopyState['updateMergeCommands'](2000,True)
            times.append((time.perf_counter()-start)*1000)
        row={'source':label,'scenario':scenario,'median_cpu_ms':float(np.median(times[3:]))}
        report.append(row);print(json.dumps(row),flush=True)
(OUT/'merge_benchmark.json').write_text(json.dumps(report,indent=2))
