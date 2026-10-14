struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txMask;
Texture2D txRainBoundaryMask;
Texture2D txRainDu;
Texture2D txRainDv;
Texture2D txSummary;
Texture2D txTrailDescriptors;
Texture2D txTrailPrevious;
SamplerState samLinearClamp;
float gDebug;
float gFlipY;
float gNewTrailBeadCycles;
float gNewTrailDiffuse;
float gNewTrailDt;
float gNewTrailHeadSize;
float gNewTrailNoise;
float gNewTrailPhase;
float2 gNewTrailPixelUV;
float gNewTrailSeconds;
float gNewTrailSheetRipple;
float gNewTrailSupply;
float gNewTrailWet;
float gNewTrailWiden;
float gNewTrailWidthD;
float gNewTrailWipeSeconds;
float gRainMetersPerUnit;
float gRainReferencePerMM;
float gSize;
float gSparseWords;
float gSummaryWords;
float2 gTile;
float gTilesX;
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
// Appended to the existing sparse-word traversal. A single pass deposits
// current swept segments and decays previous history; no per-drop draw calls.
void rgEval(int i,float2 px,inout float4 acc) {
    float4 path=txTrailDescriptors.Load(int3(i,0,0));
    float4 shape=txTrailDescriptors.Load(int3(i,1,0));
    float4 frame=txTrailDescriptors.Load(int3(i,2,0));
    if(max(shape.y,frame.a)<=0)return;
    float2 a=px/gSize-path.xy,b=path.zw-path.xy;
    float2 delta=float2(frame.x*a.x+frame.y*a.y,frame.z*a.y);
    float2 travel=float2(frame.x*b.x+frame.y*b.y,frame.z*b.y);
    float t=saturate(dot(delta,travel)/max(dot(travel,travel),1e-18));
    float2 side=delta-travel*t;float d2=dot(side,side);
    // Integrate a subpixel footprint instead of letting a thin path disappear
    // between atlas rows. This is sampling support, never an artist texel width.
    float aa=.5*length(float2(frame.x/gSize,(abs(frame.y)+frame.z)*4/gSize));
    if(frame.a>0)acc.a=max(acc.a,.95*saturate((frame.a+aa-sqrt(d2))/max(aa,1e-9)));
    float sampledRadius=shape.x+aa*.5;
    if(shape.y<=0 || d2>=sampledRadius*sampledRadius)return;
    float k=saturate(1-d2/max(sampledRadius*sampledRadius,1e-18))*shape.x/max(sampledRadius,1e-9);
    float along=dot(delta,normalize(travel+float2(1e-15,0)))/max(shape.x*2,1e-8);
    // Thin films bead; thick ones stay continuous. No floor or plateau in sheets.
    float bead=.5+.5*sin(along*gNewTrailBeadCycles*6.2831853+float(i)*2.399963);
    float modulation=lerp(1,lerp(.15,1,bead*bead),gNewTrailNoise*(1-saturate(shape.y))*(1-shape.z));
    float ripple=1+gNewTrailSheetRipple*shape.z*sin(along*6.2831853+gNewTrailPhase);
    float height=min(shape.y*k*modulation*ripple,1);
    if(height>acc.g)acc.rgb=float3(shape.x*gNewTrailHeadSize/32,height,shape.z)*float3(height,1,height);
}
float4 ntHistory(float2 uv) {
    float4 p=txTrailPrevious.SampleLevel(samLinearClamp,uv,0);
    if(gNewTrailDiffuse>0 && p.g>1e-5) {
        float4 around=txTrailPrevious.SampleLevel(samLinearClamp,uv+float2(gNewTrailPixelUV.x,0),0)
            +txTrailPrevious.SampleLevel(samLinearClamp,uv-float2(gNewTrailPixelUV.x,0),0)
            +txTrailPrevious.SampleLevel(samLinearClamp,uv+float2(0,gNewTrailPixelUV.y),0)
            +txTrailPrevious.SampleLevel(samLinearClamp,uv-float2(0,gNewTrailPixelUV.y),0);
        p.rgb=lerp(p.rgb,around.rgb*.25,min(gNewTrailDiffuse,1));
    }
    float coat=saturate(txRainDv.SampleLevel(samLinearClamp,uv,0).a);
    float width=p.r/max(p.g,1e-7)*32/max(gNewTrailHeadSize,1);
    float sheet=saturate(p.b/max(p.g,1e-7));
    float diameter=2*width/max(gNewTrailWidthD*(1+gNewTrailWiden*sheet)*gRainReferencePerMM,1e-8);
    float life=gNewTrailSeconds*lerp(1,2.5,gNewTrailWet)*lerp(1,.4,coat)*(1+.5*smoothstep(.4,2.5,diameter));
    float dry=gNewTrailSupply<.001 && gNewTrailWet<.08 ? 2 : 1;
    p.rgb*=exp(-gNewTrailDt*1.05*dry/max(life,.05));
    p.a*=exp(-gNewTrailDt*3/max(gNewTrailWipeSeconds,.05));
    if(p.g<1e-4)p.rgb=0;if(p.a<1e-4)p.a=0;
    return p;
}
float4 ntResolve(float2 uv,float4 fresh) {
    float4 previous=ntHistory(uv);
    float4 result=previous;
    if(fresh.g>previous.g)result.rgb=fresh.rgb; // max, never additive thickening
    result.a=max(previous.a,fresh.a);
    return result;
}
void rgWalk(float fbits, int base, float2 px, inout float4 acc, inout int occupied)
{
    uint bits = (uint)fbits;
    [loop] while (bits != 0u)
    {
        uint b = firstbitlow(bits);
        bits &= bits - 1u;
        occupied++;
        rgEval(base + (int)b, px, acc);
    }
}
void rgWalkWord(int w, int tx, int ty, float2 px,
    inout float4 acc, inout int occupied)
{
    float4 m = txMask.Load(int3(tx * (int)gWords + w, ty, 0));
    // One loop body, rather than four inlined copies of the complete kernel.
    // m is read-only; dynamic l-value indexing is deliberately avoided.
    [loop] for(uint channel=0u;channel<4u;++channel)
        rgWalk(m[channel],w*96+(int)channel*24,px,acc,occupied);
}
void rgWalkSummary(float fbits, int base, int tx, int ty, float2 px,
    inout float4 acc, inout int occupied)
{
    uint bits = (uint)fbits;
    [loop] while (bits != 0u)
    {
        uint b = firstbitlow(bits);
        bits &= bits - 1u;
        int w = base + (int)b;
        if (w < (int)gWords) rgWalkWord(w, tx, ty, px, acc, occupied);
    }
}
float4 main(PS_IN pin):SV_TARGET
{
    if (gDebug > 2.5) return float4(0.0, 0.0, 0.0, 0.0);
    if(rainValid(float2(pin.Tex.x,pin.Tex.y-1))<.5) return 0;
    float2 tex = pin.Tex;
    if (gFlipY > 0.5) tex.y = 1.0 - tex.y;
    float2 px = tex * gSize;
    int tx = (int)min(floor(px.x / gTile.x), gTilesX - 1.0);
    int ty = (int)min(floor(px.y / gTile.y), gTilesY - 1.0);
    float4 acc = 0.0;
    int occupied = 0;
    if (gSparseWords > 0.5)
    {
        [loop] for (int block = 0; block < (int)gSummaryWords; ++block)
        {
            float4 s = txSummary.Load(int3(tx * (int)gSummaryWords + block, ty, 0));
            int base = block * 96;
            [loop] for(uint channel=0u;channel<4u;++channel)
                rgWalkSummary(s[channel],base+(int)channel*24,tx,ty,px,acc,occupied);
        }
    }
    else
    {
        [loop] for (int w = 0; w < (int)gWords; ++w)
            rgWalkWord(w, tx, ty, px, acc, occupied);
    }
    acc *= rainValid(float2(pin.Tex.x,pin.Tex.y-1));
    if (gDebug > 0.5 && gDebug < 1.5)
        return float4(saturate(occupied / 64.0), acc.g, 0.0, 1.0);
    return ntResolve(pin.Tex,acc);
}
