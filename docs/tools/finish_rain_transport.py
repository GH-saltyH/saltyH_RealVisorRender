from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];p=ROOT/'realvisor.lua'
s=p.read_text(encoding='utf-8');stamp=p.stat().st_mtime_ns
def rep(a,b,n=1):
    global s
    assert s.count(a)==n,(a[:80],s.count(a),n)
    s=s.replace(a,b)
a=s.index('                float2 anchor =',s.index('float2 rainStateFindValidPosition('));b=s.index('                float2 jitter =',a)
s=s[:a]+s[b:]
a=s.index('                float reach =',a);b=s.index('                uint site=',a)
s=s[:a]+s[b:]
rep('                    return candidate;','                    best=candidate;validCount=1;break;')
rep('''            position =
                rainStateIntegratePosition(
                    position,
                    velocity,
                    dt
                );

            return float4(
                position,
                velocity
            );''','''            return rainAdvance(position,velocity,dt);''')
a=s.index('                float2 predicted = p + v * dt;',s.index('local rainStateMetaUpdateParams'));b=s.index('                if (exits)',a)
s=s[:a]+'''                float4 predicted=rainAdvance(p,v,dt);
                bool exits=rainStateBoundaryMask(p)<.5 || rainStateBoundaryMask(predicted.rg)<.5;

'''+s[b:]
rep("    '[6] Physical state viewer'","    '[6] Physical state viewer',\n    '[7] Coating (cyan) / bare glass (orange)',\n    '[8] Surface metric: U length / V length / skew'")
rep('local RAIN_DEBUG_VALUES = { 0, 1, 2, 3, 4, 5, 6 }','local RAIN_DEBUG_VALUES = { 0, 1, 2, 3, 4, 5, 6, 7, 8 }')
rep('            gDynamicDropDepthOnly = 0.0,','            gDynamicDropDepthOnly = 0.0,\n            gDynamicDropSurfaceDebug=cfg.RUNTIME.RAIN_DEBUG,')
rep('    if rainDynamicSurfaceInitialized then\n        return rainDynamicSurfaceMesh ~= nil',
    '    if rainDynamicSurfaceInitialized then\n        return rainDynamicSurfaceMesh ~= nil')
# Scaling a profile changes physical micro footprints, requiring a static re-bake.
rep("return string.format('%.3f|%.2f|%.2f|%d|%.2f|%.2f|%.2f|%.2f',",
    "return string.format('%.5f|%.3f|%.2f|%.2f|%d|%.2f|%.2f|%.2f|%.2f',\n        rainDynamicSceneCopyState.surface.scale,")
rep('    rainDynamicSurfaceParent = parent','    rainDynamicSceneCopyState.surface.scale=rainTargetMesh:getWorldTransformationRaw():transformVector(vec3(1,0,0)):length()\n    rainDynamicSurfaceParent = parent')
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8')
p=ROOT/'shaders/rainVisorDynamicDrop.hlsl';s=p.read_text(encoding='utf-8');stamp=p.stat().st_mtime_ns
rep('''    float4 c = float4(0.0, 0.0, 0.0, 0.0);
    gFlowSceneOffset''','''    if(gDynamicDropSurfaceDebug>6.5) {
        clip(pin.Tex.x<-2.5 ? 1 : -1);
        float2 p=float2(pin.Tex.x+4,pin.Tex.y);clip(rainValid(p)-.5);
        float3 u,v;rainMetric(p,u,v);
        float3 color=gDynamicDropSurfaceDebug<7.5
            ? lerp(float3(1,.35,.05),float3(.05,.8,1),rainCoating(p))
            : saturate(float3(length(u),length(v)*4,abs(dot(normalize(u),normalize(v)))));
        return float4(color,1);
    }
    float4 c = float4(0.0, 0.0, 0.0, 0.0);
    gFlowSceneOffset''')
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8')
print('Adaptive physical transport, bounded exits, scaling re-bake and live geometry diagnostics')
