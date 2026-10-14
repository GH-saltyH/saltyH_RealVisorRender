from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];p=ROOT/'shaders/rainVisorDynamicDrop.hlsl';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
def one(a,b):
    global s
    assert s.count(a)==1,(a[:100],s.count(a));s=s.replace(a,b)
anchor='float4 rainPureTrail(float4 t)'
helper='''// New Trail packs liquid in RGB and independent micro clearance in A.
float4 rainWipeTap(float2 uv) {
    float4 t=txDynamicTrailMask.SampleLevel(samLinearClamp,saturate(uv),0);
    return gDynamicDropNewTrail>.5 ? float4(0,t.a,0,0) : t;
}
float rainNewTrailHeight(float2 uv) {
    return txDynamicWaterTrail.SampleLevel(samLinearClamp,saturate(uv),0).g;
}
'''
one(anchor,helper+anchor)
# Replace every wipe read, retaining its existing downstream channel contract.
import re
s,n=re.subn(r'txDynamicTrailMask\.SampleLevel\(\s*samLinearClamp,\s*(.+?),\s*0(?:\.0)?\)',r'rainWipeTap(\1)',s,flags=re.S)
# Restore the helper itself; no recursion.
one('float4 t=rainWipeTap(saturate(uv));','float4 t=txDynamicTrailMask.SampleLevel(samLinearClamp,saturate(uv),0);')
assert n==7,n
one('            float inside = smoothstep(gDynamicDropWFThreshold - hWidth,\n                gDynamicDropWFThreshold + hWidth, h0);','''            float threshold=trailWins && gDynamicDropNewTrail>.5 ? .015 : gDynamicDropWFThreshold;
            if(trailWins && gDynamicDropNewTrail>.5)hWidth=min(hWidth,.007);
            float inside = smoothstep(threshold - hWidth, threshold + hWidth, h0);''')
one('                bool trailV2 = trailWins && gDynamicDropTrailRefractV2 > 0.5;',
    '                bool trailV2 = trailWins && (gDynamicDropNewTrail>.5 || gDynamicDropTrailRefractV2 > 0.5);')
one('                if (trailV2)\n                {\n                    float thr = gDynamicDropWFThreshold;', '''                if (trailV2)
                {
                    if(gDynamicDropNewTrail>.5) {
                        // Metric offsets sample a physical footprint diameter,
                        // independent of the atlas UV rotation/skew/resolution.
                        float r=max(radiusUV*2*gDynamicDropNewTrailGradientD,1e-6);
                        float2 p=float2(patternUV.x,patternUV.y-1);
                        float2 du=rainMetricOffset(p,float2(r,0)),dv=rainMetricOffset(p,float2(0,r));
                        float2 grad=float2(rainNewTrailHeight(patternUV+du)-rainNewTrailHeight(patternUV-du),
                            rainNewTrailHeight(patternUV+dv)-rainNewTrailHeight(patternUV-dv))/(2*r);
                        slope=float2(dot(grad,physicalDx),dot(grad,physicalDy))*radiusPx;
                        float magnitude=length(slope);
                        slope*=min(1,gDynamicDropTrailSlopeMax/max(magnitude,1e-6));
                        trailOffsetPx=slope*min(gDynamicDropTrailRefractPx,
                            2*radiusPx*gDynamicDropNewTrailRefractD);
                    } else {
                    float thr = gDynamicDropWFThreshold;''')
one('                        * (1.0 + gDynamicDropTrailEdgeBoost * edgeRim);\n                }',
    '                        * (1.0 + gDynamicDropTrailEdgeBoost * edgeRim);\n                    }\n                }')
one('                if (trailWins)\n                    wfAlpha *= 1.0 - saturate(gDynamicDropSmearTrailClear)\n                        * gSmearMask;', '''                if (trailWins) {
                    if(gDynamicDropNewTrail>.5)wfAlpha*=smoothstep(.015,.20,h0);
                    wfAlpha *= 1.0 - saturate(gDynamicDropSmearTrailClear)*gSmearMask;
                }''')
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8')
print('New Trail liquid profile, physical lens slope and A-channel wipe integrated')
