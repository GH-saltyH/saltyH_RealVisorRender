struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txImpactBoundary;
Texture2D txImpactPrevious;
Texture2D txImpactSource;
Texture2D txRainBoundaryMask;
Texture2D txRainDu;
Texture2D txRainDv;
SamplerState samLinearClamp;
float gImpactDecay;
float gImpactFeed;
float3 gImpactObjectStep;
float gImpactTexel;
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

            float4 main(PS_IN pin):SV_TARGET
            {
                float2 p=float2(pin.Tex.x,pin.Tex.y-1);
                float2 stepUV=rainMetricProject(p,gImpactObjectStep/gRainMetersPerUnit);
                float2 uv = pin.Tex - stepUV;
                float4 centre = txImpactPrevious.SampleLevel(samLinearClamp, uv, 0.0);
                float4 side = txImpactPrevious.SampleLevel(samLinearClamp,
                    uv + float2(gImpactTexel, 0.0), 0.0)
                    + txImpactPrevious.SampleLevel(samLinearClamp,
                    uv - float2(gImpactTexel, 0.0), 0.0);
                float oldHeight = lerp(centre.g, side.g * 0.5, 0.035) * gImpactDecay;
                float density = txImpactSource.SampleLevel(samLinearClamp, pin.Tex, 0.0).r;
                // Fixed spatial source variation avoids re-randomizing the
                // water input every frame. Smooth influx avoids patch pops.
                float variation = 0.65 + 0.35 * sin(pin.Tex.x * 83.0
                    + sin(pin.Tex.y * 51.0) * 2.0);
                float height = min(32.0, oldHeight + gImpactFeed * density * variation);
                // Film canvas already encodes signed visor V as V+1.
                // Clamp sampling negative raw V would read the all-zero
                // top border of the boundary mask and erase every texel.
                float boundary = txImpactBoundary.SampleLevel(samLinearClamp,
                    pin.Tex, 0.0).a;
                height *= smoothstep(0.45,0.55,boundary)*rainValid(float2(uv.x,uv.y-1));
                return float4(height * 0.75, height, height, height);
            }
        