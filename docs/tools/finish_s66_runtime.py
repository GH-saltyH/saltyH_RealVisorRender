"""One-shot guarded fixes after s66 compiler/capture isolation diagnosis."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def one(s,a,b):
    assert s.count(a)==1,(a[:100],s.count(a))
    return s.replace(a,b)
def edit(name,fn):
    p=ROOT/name;stamp=p.stat().st_mtime_ns;s=fn(p.read_text(encoding='utf-8'))
    assert p.stat().st_mtime_ns==stamp,name
    p.write_text(s,encoding='utf-8')
def rain(s):
    # Earlier clip experiments did not fix X4000. Restore baseline semantics.
    baseline=(ROOT/'docs/diagnostics/2026-10-12/s66/baseline/shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8')
    a=s.index('float4 main(PS_IN pin)');body=s[a:]
    start=body.index('    if(gDynamicDropSurfaceDebug>6.5)');end=body.index('    float4 c =',start)
    diagnostic=body[start:end].replace('    if(gDynamicDropSurfaceDebug>6.5) {','    {')
    body=body[:start]+'#ifdef RAIN_SURFACE_DEBUG\n'+diagnostic+'#else\n'+body[end:]
    pos=body.rfind('    return c;')+len('    return c;')
    body=body[:pos]+'\n#endif'+body[pos:]
    return baseline[:baseline.index('float4 main(PS_IN pin)')]+body
edit('shaders/rainVisorDynamicDrop.hlsl',rain)
def runtime(s):
    s=one(s,'    rainDynamicSceneCopyState = {}','''    rainDynamicSceneCopyState = {}
    -- Main-camera hooks must not run inside our offscreen GeometryShots.
    -- Restore the scope on pending and error exits as well as successful draws.
    rainDynamicSceneCopyState.captureUpdate=function(shot,...)
        local st=rainDynamicSceneCopyState
        st.offscreenCaptureActive=(st.offscreenCaptureActive or 0)+1
        local ok,result=pcall(shot.update,shot,...)
        st.offscreenCaptureActive=st.offscreenCaptureActive-1
        if not ok then error(result) end
        return result
    end
    rainDynamicSceneCopyState.loadRuntimeModule=function(name)
        local st=rainDynamicSceneCopyState
        st.moduleFactories=st.moduleFactories or {};st.moduleErrors=st.moduleErrors or {}
        if st.moduleFactories[name] then return st.moduleFactories[name] end
        if st.moduleErrors[name] then return nil,st.moduleErrors[name] end
        local ok,factory=pcall(dofile,appFolder..'/'..name)
        if not ok or type(factory)~='function' then
            local message='Required runtime module '..name..': '..tostring(factory)
            st.moduleErrors[name]=message;ac.warn(appNameDebug..' '..message)
            return nil,message
        end
        st.moduleFactories[name]=factory;return factory
    end''')
    s=one(s,'            rainDynamicSceneCopyState.geometryShot.update,rainDynamicSceneCopyState.geometryShot,',
        '            rainDynamicSceneCopyState.captureUpdate,rainDynamicSceneCopyState.geometryShot,')
    # These named receivers are GeometryShots, not ExtraCanvas updates.
    for receiver in ('ov.shot','st.shot','st.positionShot','op.shot','shot'):
        s=s.replace(receiver+':update(', 'rainDynamicSceneCopyState.captureUpdate('+receiver+',')
    s=one(s,"    local st=rainDynamicSceneCopyState;local r=cfg.RUNTIME;local sim=ac.getSim()\n    if not initialized", "    local st=rainDynamicSceneCopyState;local r=cfg.RUNTIME;local sim=ac.getSim()\n    if (st.offscreenCaptureActive or 0)>0 then return end\n    if not initialized")
    s=one(s,"    if st.visorLayer.sceneFrame~=sim.frame then\n        local ok,err=pcall(function() st.visorSceneStack('pre');st.visorSceneStack('post') end)",
        "    if st.visorLayer.postFrame~=sim.frame then\n        local ok,err=pcall(function()\n            if st.visorLayer.preFrame~=sim.frame then st.visorSceneStack('pre') end\n            st.visorSceneStack('post')\n        end)")
    s=one(s,"    vl.sceneFrame=ac.getSim().frame", "    vl[phase=='pre' and 'preFrame' or 'postFrame']=ac.getSim().frame")
    s=one(s,"        st.nativeGlass=st.nativeGlass or dofile(appFolder..'/native_glass_occlusion.lua')({", """        if not st.nativeGlass then
            local factory,err=st.loadRuntimeModule('native_glass_occlusion.lua')
            if not factory then vl.err=err;vl.status='Required native glass module missing';return false end
            st.nativeGlass=factory({""")
    s=one(s,"            editor=function(name) return st.visorLayerEditor(name) end})\n        if not st.measure('Native glass mask'", "            editor=function(name) return st.visorLayerEditor(name) end,\n            captureUpdate=st.captureUpdate})\n        end\n        if not st.measure('Native glass mask'")
    s=one(s,"    folder=appFolder,runtime=cfg.RUNTIME,", "    folder=appFolder,runtime=cfg.RUNTIME,captureUpdate=rainDynamicSceneCopyState.captureUpdate,")
    s=one(s,"        or 'main.root.transparent'), function()\n    if not cfg.RUNTIME.RAIN_ENABLED", "        or 'main.root.transparent'), function()\n    if (rainDynamicSceneCopyState.offscreenCaptureActive or 0)>0 then return end\n    if not cfg.RUNTIME.RAIN_ENABLED")
    s=one(s,"render.on('main.track.opaque', function()\n    if not visor", "render.on('main.track.opaque', function()\n    if (rainDynamicSceneCopyState.offscreenCaptureActive or 0)>0 then return end\n    if not visor")
    s=one(s,"render.on('mirror.track.transparent',function()\n    local st=rainDynamicSceneCopyState", "render.on('mirror.track.transparent',function()\n    local st=rainDynamicSceneCopyState\n    if (st.offscreenCaptureActive or 0)>0 then return end")
    s=one(s,"mesh=rainDynamicSurfaceMesh,transform='original',shader=st.mirrorWaterShader,", "mesh=rainDynamicSurfaceMesh,transform='original',async=true,shader=st.mirrorWaterShader,")
    s=one(s,"    dropMeshParams.shader=rainDynamicSceneCopyState.surface.shader..dropMeshParams.shader", """    dropMeshParams.shader=(cfg.RUNTIME.RAIN_DEBUG>6.5 and '#define RAIN_SURFACE_DEBUG 1\\n' or '')
        ..rainDynamicSceneCopyState.surface.shader..dropMeshParams.shader""")
    # Runtime key spelling is established in the shader binding.
    assert 'gDynamicDropSurfaceDebug=cfg.RUNTIME.RAIN_DEBUG' in s
    s=one(s,"    local customStack=cfg.RUNTIME.RAIN_VISOR_LAYER and (cfg.RUNTIME.RAIN_VISOR_OVERLAY\n        or (cfg.RUNTIME.RAIN_VISOR_SCENE_STACK and cfg.RUNTIME.RAIN_ENABLED\n            and cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_STATE_ENABLED))", "    local customStack=cfg.RUNTIME.RAIN_VISOR_LAYER and (cfg.RUNTIME.RAIN_VISOR_OVERLAY\n        or cfg.RUNTIME.RAIN_VISOR_SCENE_STACK)")
    s=one(s,"    local wantHide = overlayLayer or (r.RAIN_VISOR_SCENE_STACK\n        and r.RAIN_ENABLED and r.RAIN_DYNAMIC_SURFACE_STATE_ENABLED)", "    local wantHide = overlayLayer or (r.RAIN_VISOR_LAYER and r.RAIN_VISOR_SCENE_STACK)")
    return s
edit('realvisor.lua',runtime)
edit('native_glass_occlusion.lua',lambda s:one(s,'self.shot:update(sim.cameraPosition,sim.cameraLook,sim.cameraUp,sim.cameraFOV)',
    '(d.captureUpdate or function(shot,...) return shot:update(...) end)(self.shot,sim.cameraPosition,sim.cameraLook,sim.cameraUp,sim.cameraFOV)'))
def optics(s):
    s=one(s,'self[name]:update(eyeWorld,look,up,self.bakeFov)', '(d.captureUpdate or function(shot,...) return shot:update(...) end)(self[name],eyeWorld,look,up,self.bakeFov)')
    s=one(s,'self.sourceDepth:update(origin,look,up,r.RAIN_VISOR_OPTICS_SOURCE_FOV)', '(d.captureUpdate or function(shot,...) return shot:update(...) end)(self.sourceDepth,origin,look,up,r.RAIN_VISOR_OPTICS_SOURCE_FOV)')
    return s
edit('visor_optics.lua',optics)
print('Applied s66 isolated diagnostic, module errors and scoped offscreen capture')
