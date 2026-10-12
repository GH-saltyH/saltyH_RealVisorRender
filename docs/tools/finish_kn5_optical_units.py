from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'realvisor.lua';s=p.read_text(encoding='utf-8');stamp=p.stat().st_mtime_ns
def rep(a,b,n=1):
    global s
    assert s.count(a)==n,(a[:70],s.count(a),n)
    s=s.replace(a,b)
rep("wfCheck('Water in mirrors (no glass optics capture)', 'RAIN_MIRROR_WATER')",
    "if ui.checkbox('Water in mirrors (no glass optics capture)',cfg.RUNTIME.RAIN_MIRROR_WATER) then cfg.RUNTIME.RAIN_MIRROR_WATER=not cfg.RUNTIME.RAIN_MIRROR_WATER end")
rep("GLASS/FX/int_txNormal.png","GLASS/FX/int_txNormal.dds")
rep('    local useMicroPattern = cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_ENABLED\n        and cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_ENABLED',
    '    -- Shared full surface is required by water fields and mirrors even with micro optics off.\n    local useMicroPattern = true')
rep('            gDynamicDropMicroRain = math.max(0.0, math.min(1.0,',
    '            gDynamicDropMicroRain = (cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_ENABLED and cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_ENABLED and 1 or 0)*math.max(0.0, math.min(1.0,')
rep('sample.tangentU * (radiusUV * .001 / cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM)',
    'sample.tangentU * (radiusUV * rainDynamicSceneCopyState.surface:unit())',2)
rep('sample.tangentV * (radiusUV * .001 / cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM)',
    'sample.tangentV * (radiusUV * rainDynamicSceneCopyState.surface:unit())',2)
# Uniform physical sites also back the activation-atlas-off fallback.
rep('float2 candidate = float2(sampleUV.x, -sampleUV.y);',
    '''uint site=((uint)(jitter.x*8192.0)+(uint)stateIndex*73u+(uint)attempt*211u)%8192u;
                float4 physicalSite=txRainPhysicalSites.Load(int3(site,0,0));
                float2 candidate = float2(physicalSite.x,physicalSite.y-1);''')
rep('    rainDynamicSceneCopyState.surface:bind(rainStateUpdateParams)\n    rainDynamicSceneCopyState.surface:bind(rainStateMetaUpdateParams)',
    "    rainDynamicSceneCopyState.surface:bind(rainStateUpdateParams)\n    rainStateUpdateParams.textures.txRainPhysicalSites=rainDynamicSceneCopyState.surface.root..'spawn_sites.dds'\n    rainDynamicSceneCopyState.surface:bind(rainStateMetaUpdateParams)",2)
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8')
p=ROOT/'visor_optics.lua';s=p.read_text(encoding='utf-8');stamp=p.stat().st_mtime_ns
rep('GLASS/FX/int_txNormal.png','GLASS/FX/int_txNormal.dds')
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8')
p=ROOT/'shaders/rainVisorDynamicDrop.hlsl';s=p.read_text(encoding='utf-8');stamp=p.stat().st_mtime_ns
# All local lens offsets now carry orthonormal physical plane units.
rep('float rainTrailRipple(float2 uv)',
    '''float2 rainMicroCenter(float2 uv,float2 local,float radiusCells) {
    return uv-rainMetricOffset(float2(uv.x,uv.y-1),local*radiusCells/max(gDynamicDropMicroPatternGrid,1.0));
}
float rainTrailRipple(float2 uv)''')
rep('patternUV - filmLocal\n                        * (rainMicroRadiusCells(filmPoint.b)\n                            / max(gDynamicDropMicroPatternGrid, 1.0))',
    'rainMicroCenter(patternUV,filmLocal,rainMicroRadiusCells(filmPoint.b))')
rep('patternUV\n                        - (filmPoint.xy * 2.0 - 1.0)\n                        * (rainMicroRadiusCells(filmPoint.b)\n                            / max(gDynamicDropMicroPatternGrid, 1.0))',
    'rainMicroCenter(patternUV,filmPoint.xy*2.0-1.0,rainMicroRadiusCells(filmPoint.b))')
rep('patternUV - (patternPoint.xy * 2.0 - 1.0)\n            * (microRadiusCells / max(gDynamicDropMicroPatternGrid, 1.0))',
    'rainMicroCenter(patternUV,patternPoint.xy*2.0-1.0,microRadiusCells)')
rep('patternUV - lensLocal\n                * (microRadiusCells / max(gDynamicDropMicroPatternGrid, 1.0))',
    'rainMicroCenter(patternUV,lensLocal,microRadiusCells)')
rep('float2 uvDx = hoistPatternDx;\n        float2 uvDy = hoistPatternDy;',
    'float2 rawPosition=float2(patternUV.x,patternUV.y-1);\n        float2 uvDx=rainMetricPlane(rawPosition,hoistPatternDx);\n        float2 uvDy=rainMetricPlane(rawPosition,hoistPatternDy);')
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8')
print('Physical optical units and atlas-off birth sites updated')
