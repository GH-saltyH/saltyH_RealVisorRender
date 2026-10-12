struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txRainBoundaryMask;
Texture2D txRainDropMetric;
Texture2D txRainDu;
Texture2D txRainDv;
Texture2D txRainState;
Texture2D txRainStateMeta;

float gCount;
float gKs;
float gMaskW;
float gMaxRadii;
float gPuddleReach;
float gRainMetersPerUnit;
float gRainReferencePerMM;
float gSize;
float2 gTile;
float gTilesY;
float gWords;
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
    [loop] for(int step=0;step<128;++step) {
        if(remaining<=1e-7)break;
        float speed=rainMetricLength(position,velocity);
        if(speed<1e-9)break;
        float texelSpeed=max(abs(velocity.x)*maskSize.x,abs(velocity.y)*maskSize.y);
        float safe=rainMetricTap(txRainDu,float2(position.x,position.y+1)).a;
        float safePixels=max(.5,(safe-1)*.75);
        float h=min(remaining,min(safePixels/max(texelSpeed,1e-9),gRainReferencePerMM/max(speed,1e-9)));
        float2 next=position+velocity*h;
        if(rainValid(next)<.5)return float4(2,2,0,0);
        float3 u,v;rainMetric(position,u,v);
        float3 momentum=(u*velocity.x+v*velocity.y)/gRainMetersPerUnit;
        float2 transported=rainMetricProject(next,momentum);
        float movedSpeed=rainMetricLength(next,transported);
        velocity=movedSpeed>1e-9 ? transported*(speed/movedSpeed) : float2(0,0);
        position=next;remaining-=h;
    }
    if(remaining>1e-7 && rainMetricLength(position,velocity)>1e-9)return float4(2,2,0,0);
    return float4(position,velocity);
}

static float3 rgFrame=float3(1,0,1);
float2 rgExtent(float radius) {
    float x=max(rgFrame.x,1e-9),z=max(rgFrame.z,1e-9);
    return radius*float2(sqrt(1+rgFrame.y*rgFrame.y/(z*z))/x,1/z);
}
float2 rgPlane(float2 delta) {return float2(rgFrame.x*delta.x+rgFrame.y*delta.y,rgFrame.z*delta.y);}
float2 rgShift(float2 pos,float2 physicalPixels) {
    float dv=physicalPixels.y/max(rgFrame.z,1e-9);
    return pos+float2((physicalPixels.x-rgFrame.y*dv)/max(rgFrame.x,1e-9),dv);
}
float rgFrac(float x) { return x - floor(x); }
bool rgDrop(int i, out float2 pos, out float R, out float2 vel,
    out float idx, out float gen, out float rUV)
{
    float4 st = txRainState.Load(int3(i, 0, 0));
    float4 me = txRainStateMeta.Load(int3(i, 0, 0));
    float packed = me.a;
    float status = packed - 4.0 * floor(packed / 4.0);
    pos = float2(st.r, st.g + 1.0) * gSize;
    float4 metric=txRainDropMetric.Load(int3(i,0,0));
    rgFrame=metric.rgb;
    if(metric.a<.5) {pos=0;R=0;vel=0;idx=0;gen=0;rUV=0;return false;}
    vel = rgPlane(st.ba);
    rUV = max(me.r, 0.0);
    R = rUV * gSize;
    idx = (float)i + 1.0;          // Lua slots are 1-based (seeds)
    gen = floor(packed / 4.0);
    if (abs(status - 1.0) > 0.25) return false;
    if (st.r < 0.0 || st.r > 1.0 || st.g < -1.0 || st.g > 0.0) return false;
    return R > 0.0;
}

// s60: one helper per channel (no dynamic l-value indexing, which forced
// an unroll of a [loop] and failed to compile: X3550 / X3531).
float rgBitsFor(int base, float2 tmin, float2 tmax)
{
    uint bits = 0u;
    [loop] for (int b = 0; b < 24; b++)
    {
        int i = base + b;
        if (i >= (int)gCount) break;
        float2 pos; float R; float2 vel; float idx; float gen; float rUV;
        if (rgDrop(i, pos, R, vel, idx, gen, rUV))
        {
            float reach = R * (gKs * 1.4 + max(gMaxRadii, max(gPuddleReach * 1.1, 0.6)) + 0.1) + 2.0;
            float2 ext=rgExtent(reach);
            if(all(pos+ext>=tmin)&&all(pos-ext<=tmax))
                bits |= (1u << (uint)b);
        }
    }
    return (float)bits;
}
float4 main(PS_IN pin):SV_TARGET
{
    float xf = floor(pin.Tex.x * gMaskW);
    float tyf = floor(pin.Tex.y * gTilesY);
    float txf = floor(xf / gWords);
    float wf = xf - txf * gWords;
    float2 tmin = float2(txf, tyf) * gTile;
    float2 tmax = tmin + gTile;
    int base = (int)wf * 96;
    return float4(rgBitsFor(base, tmin, tmax),
        rgBitsFor(base + 24, tmin, tmax),
        rgBitsFor(base + 48, tmin, tmax),
        rgBitsFor(base + 72, tmin, tmax));
}
