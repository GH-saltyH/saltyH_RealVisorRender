struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txRainBoundaryMask;
Texture2D txRainDu;
Texture2D txRainDv;

float gMicroFirstPresence;
float2 gMicroGridUV;
float gMicroPatternGrid;
float gMicroPresence;
float gMicroRadiusMax;
float gMicroRadiusMin;
float gMicroRimCells;
float gMicroRimD;
float2 gMicroSearch;
float gMicroStrata;
float gRainMetersPerUnit;
float gRainReferencePerMM;
// KN5 local metres / raw signed UV. Discrete reads avoid blending different
// island Jacobians. Source boundary alpha is authoritative; never wrap it.
float4 rainMetricTap(Texture2D tx, float2 uv) {
    uint w=1u,h=1u;tx.GetDimensions(w,h);
    return tx.Load(int3(clamp((int2)(uv*float2(w,h)),int2(0,0),int2(w-1,h-1)),0));
}
void rainMetric(float2 p,out float3 u,out float3 v) {
    float2 uv=float2(p.x,p.y+1);
    u=rainMetricTap(txRainDu,uv).xyz;v=rainMetricTap(txRainDv,uv).xyz;
}
float2 rainMetricProject(float2 p,float3 forceObject) {
    float3 u,v;rainMetric(p,u,v);
    float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=max(a*c-b*b,1e-20);
    return float2(c*dot(u,forceObject)-b*dot(v,forceObject),
        a*dot(v,forceObject)-b*dot(u,forceObject))/det*gRainMetersPerUnit;
}
float3 rainMomentum(float2 p,float2 velocity) {
    float3 u,v;rainMetric(p,u,v);
    return (u*velocity.x+v*velocity.y)/gRainMetersPerUnit;
}
float rainMetricLength(float2 p,float2 delta) {
    float3 u,v;rainMetric(p,u,v);
    return length(u*delta.x+v*delta.y)/max(gRainMetersPerUnit,1e-8);
}
// Orthonormal physical plane, X along dP/dU. UV skew/scale retained exactly.
float2 rainMetricPlane(float2 p,float2 delta) {
    float3 u,v;rainMetric(p,u,v);
    float a=max(length(u),1e-9),b=dot(u/a,v),c=sqrt(max(dot(v,v)-b*b,1e-18));
    return float2(a*delta.x+b*delta.y,c*delta.y)/gRainMetersPerUnit;
}
float2 rainMetricOffset(float2 p,float2 plane) {
    float3 u,v;rainMetric(p,u,v);
    float a=max(length(u),1e-9),b=dot(u/a,v),c=sqrt(max(dot(v,v)-b*b,1e-18));
    float dv=plane.y*gRainMetersPerUnit/c;
    return float2((plane.x*gRainMetersPerUnit-b*dv)/a,dv);
}
float2 rainMetricExtent(float2 p,float radius) {
    float3 u,v;rainMetric(p,u,v);float a=dot(u,u),b=dot(u,v),c=dot(v,v);
    return radius*gRainMetersPerUnit*sqrt(float2(c,a)/max(a*c-b*b,1e-20));
}
float rainCoating(float2 p) {return rainMetricTap(txRainDv,float2(p.x,p.y+1)).a;}
float rainValid(float2 p) {
    float inside=all(p>=float2(0,-1))&&all(p<=float2(1,0)) ? 1 : 0;
    float alpha=rainMetricTap(txRainBoundaryMask,float2(p.x,p.y+1)).a;
    float support=saturate(rainMetricTap(txRainDu,float2(p.x,p.y+1)).a);
    return inside*alpha*support;
}
// Carry inertia through rotated/skewed triangle UV bases. A bounded adaptive
// step is at most 1 mm in the interior, and refines to half a source-mask
// texel at holes and atlas breaks. Excessive jumps die instead of wrapping.
float4 rainAdvance(float2 position,float2 velocity,float dt) {
    float remaining=max(dt,0);
    uint w=1u,h=1u;txRainBoundaryMask.GetDimensions(w,h);
    float2 maskSize=float2(w,h);
    float4 currentU=rainMetricTap(txRainDu,float2(position.x,position.y+1));
    float3 u=currentU.xyz,v=rainMetricTap(txRainDv,float2(position.x,position.y+1)).xyz;
    float speed=length(u*velocity.x+v*velocity.y)/max(gRainMetersPerUnit,1e-8);
    [loop] for(int step=0;step<128;++step) {
        if(remaining<=1e-7)break;
        if(speed<1e-9)break;
        float texelSpeed=max(abs(velocity.x)*maskSize.x,abs(velocity.y)*maskSize.y);
        float safe=currentU.a;
        float safePixels=max(.5,(safe-1)*.75);
        float h=min(remaining,min(safePixels/max(texelSpeed,1e-9),gRainReferencePerMM/max(speed,1e-9)));
        float2 next=position+velocity*h;
        if(any(next<float2(0,-1)) || any(next>float2(1,0)))return float4(2,2,0,0);
        float2 uv=float2(next.x,next.y+1);
        float4 nextU=rainMetricTap(txRainDu,uv);
        if(nextU.a<.5 || rainMetricTap(txRainBoundaryMask,uv).a<.5)return float4(2,2,0,0);
        float3 nextV=rainMetricTap(txRainDv,uv).xyz;
        float3 momentum=(u*velocity.x+v*velocity.y)/gRainMetersPerUnit;
        float a=dot(nextU.xyz,nextU.xyz),b=dot(nextU.xyz,nextV),c=dot(nextV,nextV);
        float det=max(a*c-b*b,1e-20);
        float mu=dot(nextU.xyz,momentum),mv=dot(nextV,momentum);
        float2 transported=float2(c*mu-b*mv,a*mv-b*mu)/det*gRainMetersPerUnit;
        float movedSpeed=length(nextU.xyz*transported.x+nextV*transported.y)/max(gRainMetersPerUnit,1e-8);
        velocity=movedSpeed>1e-9 ? transported*(speed/movedSpeed) : float2(0,0);
        position=next;remaining-=h;
        currentU=nextU;u=nextU.xyz;v=nextV;
        speed=length(u*velocity.x+v*velocity.y)/max(gRainMetersPerUnit,1e-8);
    }
    if(remaining>1e-7 && speed>1e-9)return float4(2,2,0,0);
    return float4(position,velocity);
}

                            float3 hashMicroCell(float2 cell)
                            {
                                float3 p = frac(float3(cell.x, cell.y, cell.x)
                                    * 0.1031);
                                p += dot(p, p.yzx + 33.33);
                                return frac((p.xxy + p.yzz) * p.zyx);
                            }
                            // Micro pattern v2 (docs/RAINFX_MICRO_PATTERN.md).
                            // Several strata of jittered disks with varying
                            // radius. Priority = 1 - gate: the earliest disk to
                            // appear with rain stays on top, later disks only
                            // show as crescents, half-moons and dots around it,
                            // so rising rain never cuts holes into visible disks.
                            // RG = lens-local coords of the winner (unit disk),
                            // B = gate (4 bit) * 16 + radius (4 bit), A = class:
                            // 1 interior, 0.5 outline rim, 0 empty.
                            float4 main(PS_IN pin):SV_TARGET
                            {
                                float2 p = pin.Tex * gMicroGridUV;
                                float2 baseCell = floor(p);
                                float best = -1.0;
                                float2 chosen = float2(0.0, 0.0);
                                float chosenRadius = gMicroRadiusMin;
                                float chosenGate = 0.99;
                                int strata = (int)gMicroStrata;
                                [loop] for (int layer = 0; layer < 6; ++layer)
                                {
                                    if (layer >= strata) break;
                                    float fl = (float)layer;
                                    float presenceLimit = layer == 0
                                        ? gMicroFirstPresence : gMicroPresence;
                                    [loop] for (int y = -(int)gMicroSearch.y; y <= (int)gMicroSearch.y; ++y)
                                    {
                                        [loop] for (int x = -(int)gMicroSearch.x; x <= (int)gMicroSearch.x; ++x)
                                        {
                                            float2 cell = baseCell
                                                + float2((float)x, (float)y);
                                            float3 h = hashMicroCell(cell
                                                + float2(137.31, 417.73) * fl);
                                            float3 g = hashMicroCell(cell
                                                + float2(59.17 * fl + 11.0,
                                                    23.9 * fl + 7.0));
                                            float2 center = cell + 0.5
                                                + (h.xy - 0.5) * 0.90;
                                            float radius = lerp(gMicroRadiusMin,
                                                gMicroRadiusMax, g.x);
                                            float2 uvCenter=center/gMicroGridUV;
                                            float2 rawCenter=float2(uvCenter.x,uvCenter.y-1);
                                            float2 local = rainMetricPlane(rawCenter,pin.Tex-uvCenter)*gMicroPatternGrid/radius;
                                            if(rainValid(rawCenter)<.5)continue;
                                            float presence = frac(h.x * 13.71
                                                + h.y * 7.17);
                                            float gate = clamp((fl + g.y)
                                                / (float)strata, 0.01, 0.99);
                                            float priority = 1.0 - gate;
                                            if (presence < presenceLimit
                                                && dot(local, local) < 1.0
                                                && priority > best)
                                            {
                                                best = priority;
                                                chosen = local;
                                                chosenRadius = radius;
                                                chosenGate = gate;
                                            }
                                        }
                                    }
                                }
                                float dist = saturate(length(chosen));
                                // The winner keeps a thin outline ring of fixed
                                // width in cells: fragments stay separated.
                                float rimStart = 1.0 - (gMicroRimD>=0 ? 2*gMicroRimD
                                    : gMicroRimCells/max(chosenRadius,0.05));
                                float cls = best < 0.0 ? 0.0
                                    : (dist < rimStart ? 1.0 : 0.5);
                                float gateQ = floor(chosenGate * 15.999);
                                float radiusQ = floor(saturate((chosenRadius
                                    - gMicroRadiusMin) / max(gMicroRadiusMax
                                    - gMicroRadiusMin, 1e-4)) * 15.999);
                                return float4(chosen * 0.5 + 0.5,
                                    (gateQ * 16.0 + radiusQ + 0.5) / 255.0, cls);
                            }
                        