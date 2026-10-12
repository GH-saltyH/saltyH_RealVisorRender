struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txMask;

float gSummaryW;
float gSummaryWords;
float gTilesY;
float gWords;

float4 main(PS_IN pin):SV_TARGET
{
    uint x = (uint)floor(pin.Tex.x * gSummaryW);
    uint ty = (uint)floor(pin.Tex.y * gTilesY);
    uint tx = x / (uint)gSummaryWords;
    uint block = x - tx * (uint)gSummaryWords;
    uint bx = 0u, by = 0u, bz = 0u, bw = 0u;
    [loop] for (uint j = 0u; j < 96u; ++j)
    {
        uint word = block * 96u + j;
        if (word >= (uint)gWords) break;
        float4 m = txMask.Load(int3(tx * (uint)gWords + word, ty, 0));
        if (m.x > 0.0 || m.y > 0.0 || m.z > 0.0 || m.w > 0.0)
        {
            uint bit = 1u << (j % 24u);
            if (j < 24) bx |= bit;
            else if (j < 48) by |= bit;
            else if (j < 72) bz |= bit;
            else bw |= bit;
        }
    }
    return float4((float)bx, (float)by, (float)bz, (float)bw);
}
