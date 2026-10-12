struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txRainDropMetric;
Texture2D txRainPreviousMeta;
Texture2D txRainPreviousState;
Texture2D txRainState;
Texture2D txRainStateMeta;

float gCount;
float gKs;
float gMaxRadii;
float gPuddleReach;
float gRainMetersPerUnit;
float gSize;
float gSweepEnabled;
float gSweepMinRadius;
float gSweepWidthOffset;
float gSweepWidthScale;

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

float4 main(PS_IN pin):SV_TARGET {
    int i=(int)min(floor(pin.Tex.x*gCount),gCount-1);
    float2 pos,vel;float R,idx,gen,rUV;
    if(!rgDrop(i,pos,R,vel,idx,gen,rUV)) return float4(2e9,2e9,-2e9,-2e9);
    float reach=R*(gKs*1.4+max(gMaxRadii,max(gPuddleReach*1.1,.6))+.1)+2;
    float2 previous=pos;float valid=0;
    if(gSweepEnabled>.5) {
        float4 p=txRainPreviousState.Load(int3(i,0,0));
        float4 m=txRainPreviousMeta.Load(int3(i,0,0));
        float status=m.a-4*floor(m.a/4);
        float2 q=float2(p.x,p.y+1)*gSize;
        if(status==1 && floor(m.a/4)==gen && all(p.rg>=float2(0,-1)) && all(p.rg<=float2(1,0))
            && length(rgPlane(pos-q))/gSize*gRainMetersPerUnit<.128) {previous=q;valid=1;}
    }
    float wipeRadius=max(gSweepMinRadius,R*gSweepWidthScale+gSweepWidthOffset);
    reach=max(reach,wipeRadius);
    float2 ext=rgExtent(reach);
    uint row=(uint)floor(pin.Tex.y*3);
    if(row==1u) return float4(previous,wipeRadius,valid);
    if(row==2u) return float4(pos,ext);
    return float4(min(pos,previous)-ext,max(pos,previous)+ext);
}
