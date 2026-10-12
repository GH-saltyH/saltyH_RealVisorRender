"""Exact, mtime-guarded s66 async startup and independent glass diagnostics."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def replace(s,a,b):
    assert s.count(a)==1,(a[:100],s.count(a));return s.replace(a,b)
def edit(name,fn):
    p=ROOT/name;t=p.stat().st_mtime_ns;s=fn(p.read_text(encoding='utf-8'))
    assert p.stat().st_mtime_ns==t,name;p.write_text(s,encoding='utf-8')
def lua(s):
    # Runtime shader requests wait via false/pending, never a synchronous FXC.
    s=s.replace('async=false','async=true').replace('async = false','async = true')
    s=replace(s,'    local dropMeshParams = {\n        mesh = rainDynamicSurfaceMesh,',
        '    local dropMeshParams = {\n        async = true,\n        mesh = rainDynamicSurfaceMesh,')
    s=replace(s,'    rainDynamicSurfaceMesh:setVisible(false, false)\n\n    rainDynamicSurfaceInitialized = true',
        '    rainDynamicSurfaceMesh:setVisible(false, false)\n    rainDynamicSurfaceMesh:setShadows(false) -- manual colour only; never an opaque visor sun caster\n\n    rainDynamicSurfaceInitialized = true')
    s=replace(s,'                shader.HLSL = source',
        '                shader.HLSL = \'#line 1 "RealVisor/\'..shader.ID..\'.hlsl"\\n\'..source')
    # All custom originals and generated rain stay out of native/shadow lists,
    # even when a previous colour callback aborted before restoring visibility.
    s=replace(s,'    rainDynamicSceneCopyState.nativeCaptureHide()\n    rainDynamicSceneCopyState.materialSettings:flush()',
        '    rainDynamicSceneCopyState.nativeCaptureHide()\n    if rainDynamicSurfaceMesh then rainDynamicSurfaceMesh:setVisible(false,false);rainDynamicSurfaceMesh:setShadows(false) end\n    rainDynamicSceneCopyState.materialSettings:flush()')
    s=replace(s,'        state.gpuHeadsActive = okG and resG == true',
        '''        state.gpuHeadsActive = okG and resG == true
        state.gpuHeadsPending=not state.gpuHeadsActive
        if state.gpuHeadsPending then
            state.birthMaskReady=false
            state.gpuHeadsErr=not okG and tostring(resG) or state.gpuHeadsErr or 'GPU head shaders pending'
            return false -- no expensive CPU particle fallback while compiling
        end''')
    # Bounds alone are sufficient for the shared mesh + pre-baked GPU sites.
    s=replace(s,'    rainDynamicSurfaceLookup = rainDynamicSurfaceBuildLookup(vertices, indices)',
        '''    if cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED and cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ONLY then
        local minU,minV,maxU,maxV=math.huge,math.huge,-math.huge,-math.huge
        for i=1,#vertices do local uv=vertices:get(i).uv
            minU,minV=math.min(minU,uv.x),math.min(minV,uv.y)
            maxU,maxV=math.max(maxU,uv.x),math.max(maxV,uv.y)
        end
        rainDynamicSurfaceLookup={minU=minU,minV=minV,maxU=maxU,maxV=maxV,
            rangeU=math.max(maxU-minU,1e-7),rangeV=math.max(maxV-minV,1e-7),
            bboxUVArea=(maxU-minU)*(maxV-minV),totalUVArea=0,
            validTriangleCount=math.floor(#indices/3),boundsOnly=true}
    else rainDynamicSurfaceLookup = rainDynamicSurfaceBuildLookup(vertices, indices) end''')
    s=replace(s,'    local lookupValidation = rainDynamicSurfaceValidateLookup(rainDynamicSurfaceLookup)',
        '''    local lookupValidation=rainDynamicSurfaceLookup.boundsOnly
        and {total=0,hitCount=0,missCount=0,bucketMembershipMiss=0,containmentMiss=0}
        or rainDynamicSurfaceValidateLookup(rainDynamicSurfaceLookup)
    if rainDynamicSurfaceLookup.boundsOnly then
        ac.log(appNameDebug..' Shared GPU rain mesh: obsolete per-triangle lookup/probes skipped')
    end''')
    # Defer model IO without recreating its node tree on every pending frame.
    s=replace(s,'local function initializeScene()\n\n',
        '''local function initializeScene()
    local startup=rainDynamicSceneCopyState
    if startup.sceneLoadPending then return false end
    if startup.sceneLoadError then return false end
    if not startup.sceneTreeReady then
''')
    a='''    visor =
        axisRollNode:loadKN5({

            filename = cfg.RUNTIME.MODEL_PATH,

            forceRenderableOn = true
        })'''
    b='''    startup.sceneTreeReady=true
    end
    if not visor then
        startup.sceneLoadPending=true;startup.sceneLoadStarted=os.preciseClock()
        startup.sceneLoadStatus='Loading visor KN5 asynchronously'
        local owner=axisRollNode
        owner:loadKN5Async({filename=cfg.RUNTIME.MODEL_PATH,forceRenderableOn=true},function(err,loaded)
            if axisRollNode~=owner then if loaded then loaded:dispose() end;return end
            startup.sceneLoadPending=false
            startup.sceneLoadMS=(os.preciseClock()-startup.sceneLoadStarted)*1000
            if err or not loaded then
                startup.sceneLoadError=tostring(err or 'No model returned')
                startup.sceneLoadStatus='KN5 load failed: '..startup.sceneLoadError
                ac.warn(appNameDebug..' '..startup.sceneLoadStatus);return
            end
            visor=loaded;visor:setVisible(false,false)
            startup.sceneLoadStatus='KN5 ready; applying saved profile/materials'
            ac.log(appNameDebug..' Async KN5 ready in '..string.format('%.1f ms',startup.sceneLoadMS))
        end)
        return false
    end'''
    s=replace(s,a,b)
    # Native capture failures cannot prevent the independent routing diagnostic.
    s=replace(s,'    test.attempts = test.attempts + 1',
        '    test.attempts = test.attempts + 1\n    test.frame=ac.getSim().frame')
    s=replace(s,"    vl.status = 'scene stack drawn'\nend",
        "    vl.status = 'scene stack drawn'\n    vl.sceneFrame=ac.getSim().frame\n    return true\nend")
    anchor='\n-- Called inside the overlay GeometryShot transparent callback.'
    helper='''
-- Glass and the routing test also draw while rain initialization/compilation
-- is pending or rain is off. Their geometry does not depend on rain atlases.
rainDynamicSceneCopyState.glassFallback = function()
    local st=rainDynamicSceneCopyState;local r=cfg.RUNTIME;local sim=ac.getSim()
    if not initialized or not visor or activeEnableMode~=1 or not sim
        or not r.RAIN_VISOR_LAYER or not r.RAIN_VISOR_SCENE_STACK or r.RAIN_VISOR_OVERLAY then return end
    local size=render.getRenderTargetSize()
    st.mainTargetWidth,st.mainTargetHeight=math.floor(size.x),math.floor(size.y)
    if st.visorLayer.sceneFrame~=sim.frame then
        local ok,err=pcall(function() st.visorSceneStack('pre');st.visorSceneStack('post') end)
        if not ok then st.visorLayer.err='Glass fallback: '..tostring(err) end
    end
    if r.RAIN_VISOR_LAYER_E1_SURFACE_TEST and st.e1SurfaceTest.frame~=sim.frame then
        st.e1SurfaceDraw('slot');st.e1SurfaceDraw('final')
    end
end
render.on(cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG and 'main.smoke'
    or (cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_TRACK and 'main.track.transparent' or 'main.root.transparent'),
    function() -- registered before rain; on a prepared rain frame the normal stack owns ordering
        if rainDynamicSceneCopyState.preparedFrame~=ac.getSim().frame then
            rainDynamicSceneCopyState.glassFallback()
        end
    end)
'''
    s=replace(s,anchor,helper+anchor)
    # Final safety/diagnostic callback follows the actual rain callback.
    anchor='-- Diagnostic capture must be registered before the rain draw for source order.'
    # Registration here is BEFORE main draw; defer final fallback registration
    # until the second (legacy) rain renderer section, after the first callback.
    anchor='-- Rain render path (v0.6.0: persistent GPU + dynamic surface)'
    # Anchor discovered by exact main callback end marker instead.
    a=s.index("    local sceneStackOk,sceneStackError = pcall(")
    end=s.index('\nend)\n',a)+len('\nend)\n')
    s=s[:end]+'''render.on(cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG and 'main.smoke'
    or (cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_TRACK and 'main.track.transparent' or 'main.root.transparent'),
    rainDynamicSceneCopyState.glassFallback)
'''+s[end:]
    return s
edit('realvisor.lua',lua)
edit('visor_optics.lua',lambda s:s.replace('async=false','async=true'))
edit('native_glass_occlusion.lua',lambda s:s.replace('async=false','async=true'))
print('s66 exact startup/async/fallback anchors applied; numeric settings untouched')
