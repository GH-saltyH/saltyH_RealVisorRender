from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];p=ROOT/'realvisor.lua';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
def one(a,b):
    global s
    assert s.count(a)==1,(a[:90],s.count(a));s=s.replace(a,b)
one('        RAIN_NEW_TRAIL_HEAD_GRADIENT_D = 0.08,','''        RAIN_NEW_TRAIL_HEAD_GRADIENT_D = 0.08,
        RAIN_NEW_TRAIL_SPLASH_REF_MM = 0.0, -- migrate the current authored texel value once
        RAIN_NEW_TRAIL_SPLASH_MIN_MM = 0.0,
        RAIN_NEW_TRAIL_MICRO_RIM_D = -1.0,''')
one('rainDynamicSceneCopyState.newTrailMode=function(sim)', '''rainDynamicSceneCopyState.splashReference=function(size)
    local r=cfg.RUNTIME
    return r.RAIN_NEW_TRAIL_ENABLED and r.RAIN_NEW_TRAIL_SPLASH_REF_MM>0
        and r.RAIN_NEW_TRAIL_SPLASH_REF_MM*r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM*size*.5
        or r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SIZE_REF
end
rainDynamicSceneCopyState.splashMinimum=function(size)
    local r=cfg.RUNTIME
    return r.RAIN_NEW_TRAIL_ENABLED and r.RAIN_NEW_TRAIL_SPLASH_MIN_MM>0
        and r.RAIN_NEW_TRAIL_SPLASH_MIN_MM*r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM*size*.5
        or r.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS
end
rainDynamicSceneCopyState.newTrailMode=function(sim)''')
one('    local want=cfg.RUNTIME.RAIN_NEW_TRAIL_ENABLED and cfg.RUNTIME.RAIN_GPU_HEADS','''    local want=cfg.RUNTIME.RAIN_NEW_TRAIL_ENABLED and cfg.RUNTIME.RAIN_GPU_HEADS
    local r=cfg.RUNTIME
    if want then
        local samplesPerMM=r.RAIN_DYNAMIC_BIRTH_MASK_SIZE*r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM
        if r.RAIN_NEW_TRAIL_SPLASH_REF_MM<=0 then r.RAIN_NEW_TRAIL_SPLASH_REF_MM=2*r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SIZE_REF/samplesPerMM end
        if r.RAIN_NEW_TRAIL_SPLASH_MIN_MM<=0 then r.RAIN_NEW_TRAIL_SPLASH_MIN_MM=2*r.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS/samplesPerMM end
        if r.RAIN_NEW_TRAIL_MICRO_RIM_D<0 then
            r.RAIN_NEW_TRAIL_MICRO_RIM_D=r.RAIN_DYNAMIC_MICRO_PATTERN_RIM_TEXELS
                /math.max(r.RAIN_DYNAMIC_MICRO_PATTERN_TEXELS_PER_CELL*(r.RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MIN+r.RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MAX),.01)
        end
    end''')
one('                            r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SIZE_REF, 0.5))','                            state.splashReference(size), 0.5))')
one('                        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SIZE_REF,\n                        0.5))','                        state.splashReference(size),\n                        0.5))')
one('        local minimum=math.max(.5,cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS)',
    '        local minimum=math.max(.5,state.splashMinimum(size))')
# Other consumers have an explicit canvas width at this site.
one('        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS)\n    local drawn = 0',
    '        state.splashMinimum(size))\n    local drawn = 0')
one('            r.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS) }',
    '            st.splashMinimum(size)) }')
one('                            gMicroRimCells =', '''                            gMicroRimD=cfg.RUNTIME.RAIN_NEW_TRAIL_ENABLED and cfg.RUNTIME.RAIN_NEW_TRAIL_MICRO_RIM_D or -1,
                            gMicroRimCells =''')
one('                                float rimStart = 1.0 - gMicroRimCells\n                                    / max(chosenRadius, 0.05);','''                                float rimStart = 1.0 - (gMicroRimD>=0 ? 2*gMicroRimD
                                    : gMicroRimCells/max(chosenRadius,0.05));''')
one('        r.RAIN_DYNAMIC_MICRO_PATTERN_RIM_TEXELS,','        r.RAIN_DYNAMIC_MICRO_PATTERN_RIM_TEXELS,\n        r.RAIN_NEW_TRAIL_ENABLED and r.RAIN_NEW_TRAIL_MICRO_RIM_D or -1,')
one("        wfSlider('WF normal step (texels)',\n            'RAIN_DYNAMIC_WATER_FIELD_NORMAL_STEP_TEXELS', 0.5, 4.0, '%.2f')",'''        if cfg.RUNTIME.RAIN_NEW_TRAIL_ENABLED then
            wfSlider('Head gradient sampling radius (x drop D)','RAIN_NEW_TRAIL_HEAD_GRADIENT_D',.01,.4,'%.3f D')
        else
            wfSlider('WF normal step (texels)','RAIN_DYNAMIC_WATER_FIELD_NORMAL_STEP_TEXELS',0,3,'%.2f')
        end''')
one("        wfSlider('Splash v2 size ref (head texels)',\n            'RAIN_DYNAMIC_WATER_FIELD_SPLASH_SIZE_REF', 1.0, 32.0, '%.1f')",'''        if cfg.RUNTIME.RAIN_NEW_TRAIL_ENABLED then
            wfSlider('Splash reference drop diameter (mm)','RAIN_NEW_TRAIL_SPLASH_REF_MM',.1,10,'%.2f mm')
        else
            wfSlider('Splash v2 size ref (head texels)','RAIN_DYNAMIC_WATER_FIELD_SPLASH_SIZE_REF',1,32,'%.1f')
        end''')
one("        wfSlider('WF tear min piece (texels)',\n            'RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS', 0.5, 4.0, '%.2f')",'''        if cfg.RUNTIME.RAIN_NEW_TRAIL_ENABLED then
            wfSlider('Minimum splash piece diameter (mm)','RAIN_NEW_TRAIL_SPLASH_MIN_MM',.01,1,'%.3f mm')
        else
            wfSlider('WF tear min piece (texels)','RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS',.25,3,'%.2f')
        end''')
one("        wfSlider('Micro cut line (texels)',\n            'RAIN_DYNAMIC_MICRO_PATTERN_RIM_TEXELS', 0.0, 2.0, '%.2f')",'''        if cfg.RUNTIME.RAIN_NEW_TRAIL_ENABLED then
            wfSlider('Micro cut line width (x disk D)','RAIN_NEW_TRAIL_MICRO_RIM_D',0,.25,'%.3f D')
        else
            wfSlider('Micro cut line (texels)','RAIN_DYNAMIC_MICRO_PATTERN_RIM_TEXELS',0,2,'%.2f')
        end''')
one("        wfSlider('Micro pixelation (texels per cell)',", "        wfSlider('Micro sampling quality (samples per nominal D)',")
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8')
print('Converted active head/micro/splash shape controls to D or mm; resolution remains sampling quality')
