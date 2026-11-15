// FILM S2-1 TRANSPORT (docs/RAINFX_V2_FILM_S2_DESIGN.md section 3.2-3.3, F5 section 9), gR2FilmSub substeps per frame after the
// field pass. Target: F (field size, RGBA32F); B (film h) moves, A carries the body decision (exposure + 2 x mobile).
// Mass-conserving upwind fluxes: every face carries the source texel's flux h v.n dt / dx; the four outflows of a texel are
// scaled together so they never exceed its water (Courant <= 1 per substep; Lua sets 2-4 substeps; faster film is a thick body
// that F3 turns into a drop). v(h) = K.xy h + K.zw h^2 (air shear + gravity, lubrication, sheetcoef).
// F5: only water of a MOBILE body moves (field pass: r2FilmMobileWin, Furmidge per unit width over the body, once per frame);
// a texel that receives water from a mobile body becomes part of it for the rest of the frame (the decision travels with the
// water -- a per-texel test every substep tore moving bodies into pinned pieces). Water leaving the visor drains.
float r2FilmShare(float4 K, float h, int2 d) {                 // share of h crossing face d this substep
    float2 cour = (K.xy * h + K.zw * (h * h)) * gR2SheetDt * gR2FieldSize;     // texels per substep
    float cd = max(dot(cour, float2(d)), 0.0);
    float tot = abs(cour.x) + abs(cour.y);
    return cd * (tot > 1.0 ? 1.0 / tot : 1.0);
}
// F4c TILE SKIP (docs/RAINFX_V2_FILM_S2_DESIGN.md section 12): the F4b summary (txR2FilmAny, 32 x 8 blocks of 32 x 32 texels,
// R film / G mobile, 1-3 frames old) marks the blocks with water to move. A texel moves water only if its block or one of
// the 8 around had some (film moves <= 4 texels / frame, the summary is <= 3 frames old: 12 < 32); any other texel copies
// itself (1 field Load + 9 tiny taps, no visor-mask taps). Cost ~ film area instead of the whole field.
bool r2FilmTileActive(int2 f) {
    bool act = gR2FilmTile < 0.5;
    if (!act) {
        int2 bs = int2(uint2(gR2FieldSize) / uint2(32u, 8u));
        int2 b = int2(uint2(f) / uint2(max(bs, int2(1, 1))));   // uint: FXC X3556
        [unroll] for (int i = 0; i < 9; ++i) {
            int2 bb = clamp(b + int2((int)((uint)i % 3u) - 1, (int)((uint)i / 3u) - 1), int2(0, 0), int2(31, 7));
            float2 v = txR2FilmAny.Load(int3(bb, 0)).rg;
            act = act || v.y > 0.5;                                // F4d: only MOBILE water moves (pinned film: field rules)
        }
    }
    return act;
}
float4 main(PS_IN pin) {
    int2 f = int2(pin.PosH.xy);
    float2 t = (float2(f) + 0.5) / gR2FieldSize;
    float4 F = txR2Field.Load(int3(f, 0));
    bool mob = F.a >= 1.5;
    float expo = mob ? F.a - 2.0 : F.a;
    float4 res = F;                                                // F4c: inactive block = unchanged copy
    bool act = r2FilmTileActive(f);
    if (act) res = float4(F.rg, 0.0, expo);
    if (act && r2Valid(t) > 0.5) {
        float h = F.b * gR2FilmMaxMM;
        float hN = h;
        bool got = false;
        if (mob && h > 0.0) {
            float4 K = txR2SheetK.Load(int3(f, 0));
            [unroll] for (int k = 0; k < 4; ++k) hN -= r2FilmShare(K, h, r2Nb4(k)) * h;   // lost off the visor (drainage)
        }
        [unroll] for (int k = 0; k < 4; ++k) {
            int2 d = r2Nb4(k);
            int2 g = f + d;
            if (all(g >= int2(0, 0)) && all(g < int2(gR2FieldSize))) {
                float4 Fg = txR2Field.Load(int3(g, 0));
                float hg = Fg.b * gR2FilmMaxMM;
                if (Fg.a >= 1.5 && hg > 0.0) {                         // F4: dry / pinned neighbours cost one load
                    float q = r2FilmShare(txR2SheetK.Load(int3(g, 0)), hg, -d) * hg;
                    hN += q;
                    got = got || q > 0.0;
                }
            }
        }
        bool mobOut = (mob && hN >= gR2FilmWetMM) || got;
        res = float4(F.rg, saturate(max(hN, 0.0) / gR2FilmMaxMM), expo + (mobOut ? 2.0 : 0.0));
    }
    return res;
}
