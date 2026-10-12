struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txMask;
Texture2D txOverride;
Texture2D txRainBoundaryMask;
Texture2D txRainDropBounds;
Texture2D txRainDropMetric;
Texture2D txRainDu;
Texture2D txRainDv;
Texture2D txRainState;
Texture2D txRainStateMeta;
Texture2D txSummary;

float gBodyStretch;
float gDebug;
float gFlipY;
float gKs;
float gLobesOn;
float gLookback;
float gMaxRadii;
float gPuddleMinMM;
float gPuddleOn;
float gPuddleReach;
float gPuddleShare;
float gRainMetersPerUnit;
float gRainReferencePerMM;
float gShapeOn;
float gShapeStrength;
float gSize;
float gSparseWords;
float gStretchGain;
float gSummaryWords;
float gSweepEnabled;
float2 gTile;
float gTilesX;
float gTilesY;
float gUvPerMM;
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

void rgKern(float2 px, float2 c, float ax, float ay, float2 u, float code,
    float amp, inout float4 acc)
{
    ax *= gKs; ay *= gKs;
    float2 d = rgPlane(px-c);
    float2 v = float2(-u.y, u.x);
    float2 p = float2(dot(d, u) / max(ax, 1e-3), dot(d, v) / max(ay, 1e-3));
    float k = saturate(1.0 - dot(p, p)) * amp;
    if (k <= 0.0 || amp <= 0.005) return;
    acc.rgb = float3(min(code, 1.0), 1.0, 0.0) * k + acc.rgb * (1.0 - k);
    // A is the independent swept wipe footprint. Water RGB stays unchanged.
}
void rgEval(int i, float2 px, inout float4 acc)
{
    float2 pos; float R; float2 vel; float idx; float gen; float rUV;
    if (!rgDrop(i, pos, R, vel, idx, gen, rUV)) return;
    if(gSweepEnabled>.5) {
        float4 path=txRainDropBounds.Load(int3(i,1,0));
        float2 travel=rgPlane(pos-path.xy),delta=rgPlane(px-path.xy);
        float length2=dot(travel,travel);
        if(path.a>.5 && length2>1e-6) {
            float t=saturate(dot(delta,travel)/length2);
            float2 d=delta-travel*t;
            float k=saturate(1-dot(d,d)/max(path.z*path.z,1e-6));
            acc.a=max(acc.a,k);
        }
    }
    float reach = R * (gKs * 1.4 + max(gMaxRadii, max(gPuddleReach * 1.1, 0.6)) + 0.1) + 2.0;
    if(any(abs(px-pos)>rgExtent(reach))) return;
    float speed = length(vel);
    float seedA = rgFrac(idx * 0.7548776662 + gen * 0.5698402911);
    float seedB = rgFrac(idx * 0.6180339887 + gen * 0.4142135623);
    // body stretch tail (updateBirthMask)
    bool hasTail = false; float2 tail = pos;
    if (gBodyStretch > 0.5)
    {
        float mr = min(gMaxRadii, speed * gLookback / max(R / gSize, 1e-6));
        if (speed > 0.0 && mr > 0.20) { tail = rgShift(pos,-vel / speed * (mr * R)); hasTail = true; }
    }
    // shape lobe
    bool hasLobe = false; float2 lobe = pos; float lobeR = 0.0;
    if (gShapeOn > 0.5 && seedA > 0.34 && R >= 1.2)
    {
        float jitter = (seedB - 0.5) * 1.10;
        float2 dir = float2((pos.x / gSize - 0.5) * 0.9 + jitter, 1.0 + (seedA - 0.5) * 0.30);
        dir /= max(length(dir), 1e-6);
        lobe = rgShift(pos,dir * (R * (0.45 + 0.15 * seedB) * gShapeStrength));
        lobeR = R * (0.55 + 0.10 * seedB);
        R = R * (1.0 - 0.10 * gShapeStrength);
        hasLobe = true;
    }
    // puddles
    bool hasPuddle = false; float2 p1 = pos, p2 = pos; float r1 = 0.0, r2 = 0.0;
    float diameterMM = 2.0 * rUV / max(gUvPerMM, 1e-6);
    float puddleSeed = rgFrac(idx * 0.4142135623 + gen * 0.7320508076);
    if (gPuddleOn > 0.5 && diameterMM >= gPuddleMinMM && puddleSeed < gPuddleShare)
    {
        float ang = rgFrac(idx * 0.5698402911 + gen * 0.6180339887) * 6.28318530718;
        float motion = min(speed * 10.0, 1.0);
        float2 vd = speed > 1e-6 ? vel / speed : float2(0.0, 0.0);
        float2 dd = float2(cos(ang), sin(ang)) * (1.0 - motion) + vd * motion;
        dd /= max(length(dd), 0.001);
        float reach = R * gPuddleReach;
        p1 = rgShift(pos,dd * reach); r1 = R * (0.58 + 0.12 * puddleSeed);
        p2 = rgShift(pos,float2(-dd.y * 0.7 - dd.x * 0.35, dd.x * 0.7 - dd.y * 0.35) * reach);
        r2 = R * 0.42;
        hasPuddle = true;
    }
    if (R <= 0.25) return;
    float code = R / 32.0;
    // splash v2 override from the CPU (body hidden / residual size)
    float amp = 1.0, scale = 1.0;
    float4 ov = txOverride.Load(int3(i, 0, 0));
    if (ov.a > 0.5) { amp = ov.r; scale = ov.g; }
    float2 u = speed > 1e-6 ? vel / speed
        : float2(cos(seedA * 3.14159265), sin(seedA * 3.14159265));
    R *= scale;
    float stretch = min(0.6, speed * gStretchGain / max(R / gSize, 1e-6) * 0.05);
    rgKern(px, pos, R * (1.0 + 0.6 * stretch), R * (1.0 - 0.25 * stretch), u, code, amp, acc);
    if (hasTail)
    {
        [unroll] for (int k = 1; k <= 2; k++)
        {
            float t = k * 0.4;
            float rr = R * (0.85 - 0.3 * t);
            rgKern(px, pos + (tail - pos) * t, rr, rr, u, code, amp, acc);
        }
    }
    if (hasLobe) rgKern(px, lobe, lobeR, lobeR, u, lobeR / 32.0, amp, acc);
    if (hasPuddle)
    {
        rgKern(px, p1, r1, r1, u, r1 / 32.0, amp, acc);
        rgKern(px, p2, r2, r2, u, r2 / 32.0, amp, acc);
    }
    if (gLobesOn > 0.5 && R >= 2.0)
    {
        int cnt = R >= 4.0 ? 2 : 1;
        [loop] for (int k = 1; k <= cnt; k++)
        {
            float a = (seedA + k * 0.37) * 6.28318530718;
            float d = R * (0.25 + 0.30 * rgFrac(seedB * 7.13 + k * 0.29));
            float rr = R * (0.45 + 0.30 * rgFrac(seedA * 5.71 + k * 0.53));
            rgKern(px, rgShift(pos,float2(cos(a), sin(a)) * d), rr, rr, u, R / 32.0, amp, acc);
        }
    }
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
    rgWalk(m.x, w * 96, px, acc, occupied);
    rgWalk(m.y, w * 96 + 24, px, acc, occupied);
    rgWalk(m.z, w * 96 + 48, px, acc, occupied);
    rgWalk(m.w, w * 96 + 72, px, acc, occupied);
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
            rgWalkSummary(s.x, base, tx, ty, px, acc, occupied);
            rgWalkSummary(s.y, base + 24, tx, ty, px, acc, occupied);
            rgWalkSummary(s.z, base + 48, tx, ty, px, acc, occupied);
            rgWalkSummary(s.w, base + 72, tx, ty, px, acc, occupied);
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
    return acc;
}
