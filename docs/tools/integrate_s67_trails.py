from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];p=ROOT/'realvisor.lua';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
def one(a,b):
    global s
    assert s.count(a)==1,(a[:80],s.count(a));s=s.replace(a,b)
one('        RAIN_DYNAMIC_TRAIL_MASK_ENABLED = true,','''        -- New Trail: one current-GPU segment history for liquid and clearance.
        RAIN_NEW_TRAIL_ENABLED = true,
        RAIN_NEW_TRAIL_MIN_SPEED_MM_S = 1.3653333333,
        RAIN_NEW_TRAIL_FULL_SPEED_MM_S = 34.1333333333,
        RAIN_NEW_TRAIL_MIN_DROP_MM = 0.20,
        RAIN_NEW_TRAIL_MIN_FOOTPRINT_MM = 0.04,
        RAIN_NEW_TRAIL_HEIGHT = 0.75,
        RAIN_NEW_TRAIL_GRADIENT_D = 0.35,
        RAIN_NEW_TRAIL_REFRACT_D = 0.65,
        RAIN_NEW_TRAIL_BEAD_CYCLES_D = 1.25,
        RAIN_NEW_TRAIL_SHEET_RIPPLE = 0.08,
        RAIN_NEW_TRAIL_WET_RISE_SECONDS = 3.0,
        RAIN_NEW_TRAIL_WET_DRY_SECONDS = 20.0,
        RAIN_NEW_TRAIL_TRACK_SPRAY_GAIN = 0.0, -- optional track-puddle proxy, no measured spray
        RAIN_DYNAMIC_TRAIL_MASK_ENABLED = true,''')
one("            rainDynamicSceneCopyState.microRebakeIfNeeded(\n", "            rainDynamicSceneCopyState.microRebakeIfNeeded(\n") if False else None
one('    rainDynamicSceneCopyState.stateReadyFrame = sim.frame','''    rainDynamicSceneCopyState.stateReadyFrame = sim.frame
    rainDynamicSceneCopyState.smearUpdate(rainDynamicSceneCopyState,sim)
    rainDynamicSceneCopyState.newTrailMode(sim)''')
one('    if not cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_ENABLED\n        or not rainDynamicStateHasSnapshot then return end',
    '''    if rainDynamicSceneCopyState.newTrailActive then return end
    if not cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_ENABLED
        or not rainDynamicStateHasSnapshot then return end''')
one('    if not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED then\n        state.waterTrailReady = false',
    '''    if state.newTrailActive then return end
    if not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED then
        state.waterTrailReady = false''')
one('    values.gSweepEnabled=r.RAIN_DYNAMIC_TRAIL_MASK_ENABLED and 1 or 0',
    '    values.gSweepEnabled=not st.newTrailActive and r.RAIN_DYNAMIC_TRAIL_MASK_ENABLED and 1 or 0')
one("    st.gpuHeadsErr = nil\n    return true\nend",'''    if st.newTrailActive then
        if not st.newTrail:prepare({state=state,meta=meta,
            previousState=rainStateReadIsA and rainStateB or rainStateA,
            previousMeta=rainStateReadIsA and rainStateMetaB or rainStateMetaA,
            lifecycle=rainStateMetaUpdateParams.values.gRainStateLifecycle>.5,
            metric=st.gpuMetric,override=st.gpuOverride},values,sim,st) then
            st.gpuHeadsErr='New Trail shaders preparing';return false
        end
        st.newTrail:publish(sim,st)
    end
    st.gpuHeadsErr = nil
    return true
end''')
anchor='-- Splash v2 overrides (body amplitude, residual scale) collected by the'
helper='''rainDynamicSceneCopyState.newTrailMode=function(sim)
    local st=rainDynamicSceneCopyState
    local want=cfg.RUNTIME.RAIN_NEW_TRAIL_ENABLED and cfg.RUNTIME.RAIN_GPU_HEADS
    if want and not st.newTrail then
        local factory,err=st.loadRuntimeModule('rain_trails.lua')
        if not factory then st.gpuHeadsErr=err;return false end
        local a=assert(st.gpuHeadsPassB:find('void rgWalk(',1,true))
        st.newTrail=factory({folder=appFolder,runtime=cfg.RUNTIME,surface=st.surface,
            boundary=textureRainBoundaryMask,measure=st.measure,
            summary=st.gpuHeadsSummaryPass,traversal=st.gpuHeadsPassB:sub(a)})
    end
    if (want or false)~=st.newTrailActive then
        for _,name in ipairs({'waterTrailA','waterTrailB','trailMaskA','trailMaskB'}) do
            if st[name] then st[name]:dispose();st[name]=nil end
        end
        st.waterTrailRead=nil;st.waterTrailReady=false;st.trailMaskRead=nil;st.trailMaskFrame=nil
        st.newTrailActive=want or false
        if not want and st.newTrail then st.newTrail:dispose() end
    end
    if want then st.newTrail:environment(sim,st) end
    return true
end
'''
one(anchor,helper+anchor)
# A missing newly installed module must wait rather than re-enable legacy stamping.
one('    rainDynamicSceneCopyState.newTrailMode(sim)', '    if rainDynamicSceneCopyState.newTrailMode(sim)==false then return end')
one('    state.smearDensity, state.smearFacing = density, facing',
    '    state.smearAirKmh=airKmh\n    state.smearDensity, state.smearFacing = density, facing')
one('            gDynamicDropSurfaceDebug=cfg.RUNTIME.RAIN_DEBUG,','''            gDynamicDropNewTrail=rainDynamicSceneCopyState.newTrailActive and 1 or 0,
            gDynamicDropNewTrailGradientD=cfg.RUNTIME.RAIN_NEW_TRAIL_GRADIENT_D,
            gDynamicDropNewTrailRefractD=cfg.RUNTIME.RAIN_NEW_TRAIL_REFRACT_D,
            gDynamicDropSurfaceDebug=cfg.RUNTIME.RAIN_DEBUG,''')
one('            gDynamicDropImpactFilm = rainDynamicSceneCopyState.waterTrailComposite',
    '            gDynamicDropImpactFilm = not rainDynamicSceneCopyState.newTrailActive and rainDynamicSceneCopyState.waterTrailComposite')
one('                and cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_ENABLED',
    '                and not rainDynamicSceneCopyState.newTrailActive and cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_ENABLED')
one('                and cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_ENABLED',
    '                and not rainDynamicSceneCopyState.newTrailActive and cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_ENABLED')
one('    local ok,err=pcall(function() optics:updateBake();optics:updateExternalProbe();optics:updateNativeSource() end)',
    '    optics.pending=false\n    local ok,err=pcall(function() optics:updateBake();optics:updateExternalProbe();optics:updateNativeSource() end)')
ui='''rainDynamicSceneCopyState.newTrailUI=function()
    local s=rainDynamicSceneCopyState;local r=cfg.RUNTIME
    local sl=s.rainUISlider;local ck=s.rainUICheck
    ck('New Trail: current GPU segments + liquid/wipe history','RAIN_NEW_TRAIL_ENABLED')
    if not r.RAIN_NEW_TRAIL_ENABLED then return false end
    ui.textWrapped('Widths use drop diameter D; lens gradients use local trail footprint diameter. Screen pixels describe optical image displacement only.')
    ck('Liquid trails','RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED')
    ck('Clear micro droplets / haze along the same path','RAIN_DYNAMIC_TRAIL_MASK_ENABLED')
    sl('Liquid footprint width (x drop D)','RAIN_DYNAMIC_WATER_FIELD_TRAIL_WIDTH',.05,2,'%.2f D')
    sl('Wipe footprint width (x drop D)','RAIN_DYNAMIC_TRAIL_MASK_WIPE_WIDTH_SCALE',.05,2,'%.2f D')
    sl('Minimum footprint diameter (mm)','RAIN_NEW_TRAIL_MIN_FOOTPRINT_MM',.01,.5,'%.3f mm')
    sl('Minimum film-producing drop diameter (mm)','RAIN_NEW_TRAIL_MIN_DROP_MM',.05,1,'%.2f mm')
    sl('Film starts moving at (mm/s)','RAIN_NEW_TRAIL_MIN_SPEED_MM_S',.1,20,'%.2f mm/s')
    sl('Full speed response (mm/s)','RAIN_NEW_TRAIL_FULL_SPEED_MM_S',5,150,'%.1f mm/s')
    sl('Reference film height','RAIN_NEW_TRAIL_HEIGHT',.1,1,'%.2f')
    sl('Liquid base lifetime (s)','RAIN_DYNAMIC_WATER_FIELD_TRAIL_SECONDS',.1,3,'%.2f s')
    sl('Wipe recovery (s)','RAIN_DYNAMIC_TRAIL_MASK_SECONDS',.1,5,'%.2f s')
    sl('Thin film beading','RAIN_DYNAMIC_WATER_FIELD_TRAIL_NOISE',0,1,'%.2f')
    sl('Bead cycles per footprint D','RAIN_NEW_TRAIL_BEAD_CYCLES_D',.25,5,'%.2f /D')
    sl('Sheet width gain','RAIN_DYNAMIC_WATER_FIELD_SHEET_WIDEN',0,5,'%.2f')
    ck('Shear sheets','RAIN_DYNAMIC_WATER_FIELD_SHEET_ENABLED')
    sl('Sheet thickness ripple','RAIN_NEW_TRAIL_SHEET_RIPPLE',0,.3,'%.2f')
    sl('Gradient sampling radius (x footprint D)','RAIN_NEW_TRAIL_GRADIENT_D',.1,.75,'%.2f D')
    sl('Refraction displacement (x projected footprint D)','RAIN_NEW_TRAIL_REFRACT_D',0,2,'%.2f D')
    sl('Maximum lens displacement (screen px)','RAIN_DYNAMIC_TRAIL_REFRACT_PX',1,80,'%.1f px')
    sl('Wet rise response (s)','RAIN_NEW_TRAIL_WET_RISE_SECONDS',1,5,'%.1f s')
    sl('Wet dry response (s)','RAIN_NEW_TRAIL_WET_DRY_SECONDS',10,30,'%.1f s')
    sl('Track puddle spray proxy (0 disables)','RAIN_NEW_TRAIL_TRACK_SPRAY_GAIN',0,.3,'%.2f')
    ck('Path debug view','RAIN_DYNAMIC_TRAIL_MASK_DEBUG')
    local t=s.newTrail
    if t then ui.text(string.format('New Trail: wet %.2f / supply %.2f / shear %.2f; %dx%d; GPU updates %d',
        t.wet,t.supply or 0,t.shear or 0,t.size or 0,(t.size or 0)/4,t.updates)) end
    ui.textWrapped('Current GPU heads and segments share a frame. Tiny drops can clear a path without depositing liquid. 30 Hz deposition is avoided to keep moving heads connected.')
    return true
end
'''
one("rainDynamicSceneCopyState.rainUIPanels['trail'] = function()",ui+"rainDynamicSceneCopyState.rainUIPanels['trail'] = function()\n    if rainDynamicSceneCopyState.newTrailUI() then return end")
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8')
print('Integrated s67 unified GPU trails, preparation ordering, frame publication and diameter controls')
