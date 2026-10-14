struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txRainDropBounds;

float gCount;
float gMaskW;
float2 gTile;
float gTilesY;
float gWords;

// s60: one helper per channel (no dynamic l-value indexing, which forced
// an unroll of a [loop] and failed to compile: X3550 / X3531).
float rgBitsFor(int base, float2 tmin, float2 tmax)
{
    uint bits = 0u;
    [loop] for (int b = 0; b < 24; b++)
    {
        int i = base + b;
        if (i >= (int)gCount) break;
        // Bounds are evaluated once per slot, rather than in every tile.
        float4 bounds=txRainDropBounds.Load(int3(i,0,0));
        if(all(bounds.zw>=tmin)&&all(bounds.xy<=tmax)) {
            // Clip the swept segment against the expanded tile. A diagonal
            // AABB alone would enqueue many empty tiles at driving speeds.
            float4 previous=txRainDropBounds.Load(int3(i,1,0));
            float4 current=txRainDropBounds.Load(int3(i,2,0));
            float2 travel=current.xy-previous.xy;
            float2 safe=float2(travel.x>=0 ? max(travel.x,1e-5) : min(travel.x,-1e-5),
                travel.y>=0 ? max(travel.y,1e-5) : min(travel.y,-1e-5));
            float2 a=(tmin-current.zw-previous.xy)/safe;
            float2 z=(tmax+current.zw-previous.xy)/safe;
            float2 enter=min(a,z),leave=max(a,z);
            if(max(max(enter.x,enter.y),0)<=min(min(leave.x,leave.y),1)) bits|=1u<<(uint)b;
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
