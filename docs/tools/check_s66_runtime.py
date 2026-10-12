"""Execute production async startup, missing dependency, capture and routing paths."""
from pathlib import Path
import runpy,json,hashlib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s66'
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
env=runpy.run_path(str(ROOT/'docs/tools/check_baked_housing.py'));lua=env['lua']
report=[]
lua.execute('''
    local s=rainDynamicSceneCopyState
    s.offscreenCaptureActive=0
    local nested={update=function() assert(s.offscreenCaptureActive==2);return false end}
    local outer={update=function() assert(s.offscreenCaptureActive==1);return s.captureUpdate(nested) end}
    assert(s.captureUpdate(outer)==false and s.offscreenCaptureActive==0)
    outer.update=function() error('GPU pending error') end
    assert(not pcall(s.captureUpdate,outer) and s.offscreenCaptureActive==0)
    appFolder='missing-dir';appNameDebug='s66';warnings=0;ac={warn=function() warnings=warnings+1 end}
    s.moduleFactories=nil;s.moduleErrors=nil
    local factory,err=s.loadRuntimeModule('missing.lua');assert(factory==nil and err:find('missing.lua'))
    s.loadRuntimeModule('missing.lua');assert(warnings==1)
''')
report.append('Nested/offscreen captures restore scope on false/errors; missing dependencies report once')
a=source.index('local function initializeScene()');b=source.index('    if visor and cfg.RUNTIME.RAIN_VISOR_MOTION_STENCIL',a)
startup=source[a:b].replace('local function initializeScene()','function initializeScene()')+'\nreturn true\nend'
lua.execute('''
    visor=nil;rainDynamicSceneCopyState={}
    cfg.RUNTIME.MODEL_PATH='test.kn5';nodes=0;requests=0;clock=0
    os.preciseClock=function() clock=clock+.001;return clock end
    local methods={};methods.__index=methods
    function node() return setmetatable({true},methods) end
    function methods:createNode() nodes=nodes+1;return node() end
    methods.createBoundingSphereNode=methods.createNode
    function methods:loadKN5() error('Synchronous model load forbidden') end
    function methods:loadKN5Async(p,cb) requests=requests+1;callback=cb;assert(p.filename=='test.kn5') end
    ac.findNodes=function() return node() end;ac.log=function() end
    findDriverHeadAndNeck=function() end
''')
lua.execute(startup)
lua.execute('''
    assert(initializeScene()==false and requests==1 and nodes==8)
    for i=1,300 do assert(initializeScene()==false) end
    assert(requests==1 and nodes==8)
    local loaded={setVisible=function(self,v) self.visible=v end,dispose=function(self) self.disposed=true end}
    callback(nil,loaded);assert(visor==loaded and not loaded.visible)
    assert(initializeScene()==true and nodes==8 and requests==1)
    visor=nil;rainDynamicSceneCopyState={};initializeScene();callback('bad KN5',nil)
    assert(rainDynamicSceneCopyState.sceneLoadError=='bad KN5' and initializeScene()==false)
    visor=nil;rainDynamicSceneCopyState={};initializeScene();axisRollNode={};callback(nil,loaded)
    assert(loaded.disposed and not visor)
''')
report.append('One async KN5 request/8 nodes across 300 pending frames; success, failure and stale callback isolated')
# Execute real fallback and main entry guard using narrowly mocked draws.
lua.execute('''
    initialized=true;visor={};activeEnableMode=1
    sim={frame=7};ac.getSim=function() return sim end
    render.getRenderTargetSize=function() return {x=1280,y=720} end
    vec2=function(x,y) return {x=x,y=y} end
    render.AntialiasingMode={None=0};render.TextureFormat={R16G16B16A16={Float=1}}
    ui={ExtraCanvas=function() return {
        setName=function() end,copyFrom=function(_,name) assert(name=='dynamic::hdr');return true end,
        mipsUpdate=function() return true end,dispose=function() end} end}
    cfg.RUNTIME.RAIN_VISOR_LAYER=true;cfg.RUNTIME.RAIN_VISOR_SCENE_STACK=true
    cfg.RUNTIME.RAIN_VISOR_OVERLAY=false;cfg.RUNTIME.RAIN_ENABLED=false
    cfg.RUNTIME.RAIN_VISOR_LAYER_E1_SURFACE_TEST=true
    rainDynamicSceneCopyState={visorLayer={},e1SurfaceTest={}}
    pre,post,test=0,0,0
    local s=rainDynamicSceneCopyState
    s.visorSceneStack=function(phase)
        if phase=='pre' then pre=pre+1;error('Required native_glass_occlusion missing') end
        post=post+1
    end
    s.e1SurfaceDraw=function(stage) test=test+1;s.e1SurfaceTest.frame=sim.frame end
''')
a=source.index('rainDynamicSceneCopyState.glassFallback = function()');b=source.index('\nrender.on(',a)
lua.execute(source[a:b])
lua.execute('''
    local s=rainDynamicSceneCopyState
    s.glassFallback();assert(pre==1 and test==2 and s.visorLayer.err:find('native_glass'))
    s.offscreenCaptureActive=1;s.glassFallback();assert(pre==1 and test==2)
    s.offscreenCaptureActive=0
    s.visorSceneStack=function(phase)
        if phase=='pre' then pre=pre+1;s.visorLayer.preFrame=sim.frame
        else post=post+1;s.visorLayer.postFrame=sim.frame end
    end
    s.glassFallback();s.glassFallback();assert(pre==2 and post==1 and test==2)
    sim.frame=8;s.glassFallback();assert(pre==3 and post==2 and test==4)
''')
report.append('Rain-off and failed-stack E1 diagnostic renders independently; offscreen skipped; successful frame not duplicated')
a=source.index('    state.gpuHeadsActive = false',source.index('rainDynamicSceneCopyState.updateBirthMask ='))
b=source.index('    local cpuBuildStart',a)
lua.execute('''
    state={measure=function(_,f,...) return f(...) end,gpuHeadsRun=function() return false end}
    cfg.RUNTIME.RAIN_GPU_HEADS=true;cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING=false
    waterField=true;target={};size=2048;sim={}
''')
lua.execute('function checkPending() '+source[a:b]+' return true end')
lua.execute('''
    assert(checkPending()==false and state.gpuHeadsPending and not state.birthMaskReady)
    state.gpuHeadsRun=function() error('pending') end;assert(checkPending()==false)
    state.gpuHeadsRun=function() return true end;assert(checkPending()==true and not state.gpuHeadsPending)
''')
report.append('Pending GPU head builds return before CPU stamping; retry success clears pending')
lua.execute('''
    cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED=true;cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ONLY=true
    vertices={{uv={x=.1,y=-.9}},{uv={x=.7,y=-.3}},{uv={x=.4,y=-.6}}}
    vertices.get=function(self,i) return self[i] end;indices={1,2,3}
    lookupBuilds=0;rainDynamicSurfaceBuildLookup=function() lookupBuilds=lookupBuilds+1;return {} end
''')
a=source.index('    if cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED and cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ONLY then')
b=source.index('    ac.log(',a)
lua.execute(source[a:b])
lua.execute('''
    assert(lookupBuilds==0 and rainDynamicSurfaceLookup.boundsOnly)
    assert(rainDynamicSurfaceLookup.minU==.1 and rainDynamicSurfaceLookup.maxV==-.3)
    cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ONLY=false
''')
lua.execute(source[a:b]);lua.execute('assert(lookupBuilds==1)')
report.append('Shared GPU mesh skips obsolete UV lookup and full lookup remains available in the legacy diagnostic mode')
manifest=json.loads((OUT/'baseline/manifest.json').read_text())
for f in ('settings.ini','settings_mats.ini','rain_surface.lua','native_glass_state.lua','shaders/rainSurfaceMetric.hlsl'):
    assert hashlib.sha256((ROOT/f).read_bytes()).hexdigest()==manifest[f]['sha256'],f
for name in ('rainStateUpdateParams','rainStateMetaUpdateParams'):
    baseline=(OUT/'baseline/realvisor.lua').read_text(encoding='utf-8')
    def inline(t):
        a=t.index('[[',t.index('local '+name+' = {'))+2;return t[a:t.index(']]',a)]
    assert inline(source)==inline(baseline),name
assert 'rainDynamicSurfaceMesh:setShadows(false)' in source
assert not __import__('re').search(r'\w+\.rainDynamicSceneCopyState\.captureUpdate',source)
assert "if (rainDynamicSceneCopyState.offscreenCaptureActive or 0)>0 then return end\n    if not cfg.RUNTIME.RAIN_ENABLED" in source
report.append('Settings, surface transport and physical GPU laws byte-identical to s66 baseline; generated Rain shadows disabled')
(OUT/'runtime_checks.json').write_text(json.dumps(report,indent=2))
for row in report:print('PASS:',row)
