struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txSplashMeta;

float gAtlasCols;
float gAtlasH;
float gAtlasW;
float gKs;
float gSize;
float gSplashBreakAt;
float gSplashCount;
float gSplashHollowAt;
float gSplashMinKernel;
float gSplashScatter;
float gSplashSpread;
float gTileSize;

float splashFrac(float x) { return x - floor(x); }
float splashStep(float a, float b, float x)
{
    float q = saturate((x - a) / max(b - a, 1e-4));
    return q * q * (3.0 - 2.0 * q);
}
void splashKern(float2 px, float2 c, float ax, float ay, float2 u,
    float code, float energy, float amp, inout float4 acc)
{
    ax *= gKs; ay *= gKs;
    float2 d = px-c;
    float2 v = float2(-u.y, u.x);
    float2 p = float2(dot(d, u) / max(ax, 1e-3),
        dot(d, v) / max(ay, 1e-3));
    float k = saturate(1.0 - dot(p, p)) * amp;
    if (k <= 0.0 || amp <= 0.005) return;
    acc.rgb = float3(min(code, 1.0), 1.0, energy) * k
        + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}
float4 main(PS_IN pin):SV_TARGET
{
    float2 atlasPx = floor(pin.Tex * float2(gAtlasW, gAtlasH));
    int col = (int)floor(atlasPx.x / gTileSize);
    int row = (int)floor(atlasPx.y / gTileSize);
    int i = row * (int)gAtlasCols + col;
    if (i >= (int)gSplashCount) return 0.0;
    float4 a = txSplashMeta.Load(int3(i * 2, 0, 0));
    float4 b = txSplashMeta.Load(int3(i * 2 + 1, 0, 0));
    float Rf = a.x * gSize, E = a.y, t = saturate(a.z);
    float sa = b.x, sb = b.y, reach = b.z * gSize;
    float2 cell = atlasPx - float2(col, row) * gTileSize;
    float2 px = ((cell + 0.5) / gTileSize * 2.0 - 1.0) * reach;
    float4 acc = 0.0;
    float s = 1.0 - (1.0 - t) * (1.0 - t);
    float Rp = Rf * (1.0 + gSplashSpread * E * s);
    float centre = (1.0 - splashStep(0.05, gSplashHollowAt, t))
        * (1.0 - 0.45 * s);
    if (centre > 0.02)
        splashKern(px, 0.0, Rp * 0.80,
            Rp * 0.80 * (0.88 + 0.12 * splashFrac(sb * 2.9)),
            float2(cos(sa * 6.28), sin(sa * 6.28)),
            Rp / 32.0, 0.5 * E, centre, acc);
    float ringOn = splashStep(0.0, 0.18, t);
    float brk = saturate((t - gSplashBreakAt)
        / max(1.0 - gSplashBreakAt, 1e-3));
    int n = (int)floor(10.0 + 12.0 * E
        * (0.5 + 0.5 * splashFrac(sb * 3.7)) + 0.5);
    [loop] for (int k = 1; k <= n; ++k)
    {
        float h1 = splashFrac(sa * 17.13 + k * 0.7548776662);
        float h2 = splashFrac(sb * 11.71 + k * 0.5698402911);
        float h3 = splashFrac((sa + sb) * 7.77 + k * 0.4142135623);
        if (h3 < brk * 0.6) continue;
        float ang = (k + 0.6 * (h1 - 0.5)) / n * 6.28318530718 + sa * 6.28;
        float ca = cos(ang), sn = sin(ang);
        float d = Rp * (0.88 + 0.24 * h2) + Rf
            * gSplashScatter * E * brk * (0.4 + h2);
        float rr = max(gSplashMinKernel, Rf * (0.30 + 0.18 * h1)
            * (1.0 - 0.55 * brk) * (0.8 + 0.4 * E));
        float along = rr * (1.0 + (0.8 + 0.6 * h2) * (1.0 - brk));
        splashKern(px, float2(ca, sn) * d, along, rr,
            float2(-sn, ca), rr / 32.0, 1.0, ringOn, acc);
    }
    if (t > 0.25)
    {
        int m = (int)floor(2.0 + 6.0 * E * splashFrac(sa * 4.9) + 0.5);
        float fly = (t - 0.25) / 0.75;
        [loop] for (int k = 1; k <= m; ++k)
        {
            float h1 = splashFrac(sb * 13.3 + k * 0.6180339887);
            float h2 = splashFrac(sa * 19.9 + k * 0.3819660113);
            float ang = h1 * 6.28318530718;
            float d = Rp * (1.05 + 0.9 * h2 * fly);
            float rr = max(gSplashMinKernel, Rf * (0.08 + 0.14 * h2));
            splashKern(px, float2(cos(ang), sin(ang)) * d,
                rr, rr, float2(1.0, 0.0), rr / 32.0, 1.0, 1.0, acc);
        }
    }
    // Atlas is drawn with straight-alpha UI blending. Convert the
    // accumulated premultiplied colour back before that final blend.
    if (acc.a > 1e-5) acc.rgb /= acc.a;
    return acc;
}
