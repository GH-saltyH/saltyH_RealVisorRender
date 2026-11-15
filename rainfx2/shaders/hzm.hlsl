// N3 HAZE CELL DATA (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 27, H3 spec 8m). Target: HZM (gR2Cells, RGBA32F), made on S_next
// after the cells passes, read by the haze pass. Per cell c0:
//   x    = 0 (T1, 2026-11-13: the drop reach bits are gone -- the haze pass reads the substep wipe mask wm.hlsl; the bits
//          found only drops whose END cell was within +-2 cells, so a drop moving > ~3 cells / frame left most of its
//          path unwiped: 17-57 % of the haze stayed in the trail at 0.28-0.55 m/s);
//   y    = bits 8-9: validity class of the cell's haze texels (0 none valid, 1 all valid, 2 mixed -> the haze pass runs
//          r2Valid per texel only there; static, hzv.hlsl);
//          bits 10-11 (H3-P4): S1 water-layer class of the cell's haze texels from F_prev (0 none wet, 1 all wet, 2 mixed ->
//          the haze pass samples the field per texel only there). Exact: the haze test is linear in the field (bilinear =
//          convex combination of the field texels its texels touch), so if every touched texel passes (fails) the depth
//          test, so does every bilinear sample;
//   z    = H1b / N1 removal ratio vB / vEx of the cell (r2HazeNucleus, the same event the cells pass realised);
//   w    = rain / spray exposure at the cell centre (N3b: neighbouring cells differ < 0.5 % on the helmet).
// F6' FILM NUCLEATION (docs/RAINFX_V2_FILM_S2_DESIGN.md section 10), x = 1 + haze water (mm, cell mean) that becomes film here
// (0 = none). The water on the height maps (haze HZ_prev + film / trail F_prev) of a cell turns into ONE film layer of the
// same depth when (a) it is connected: this cell and its 4 neighbours each hold a saturated layer (>= gR2HazeSatMM, the
// micro caps at their maximum coverage touch), (b) it is a layer: the cell holds >= gR2FilmWetMM, and (c) the supply holds it:
// q >= h fedRate (the unified edge-retreat law, r2FedRate) -- below that a film recedes into caps in a few frames, so in
// ordinary weather (q << q_fed, E1 readout) nothing changes. Lua turns the whole test off (gR2FilmNucOn 0) unless the
// visor-wide supply reaches the fed limit of the thinnest layer. The haze pass empties the haze of the cell, the field adds
// x - 1 to every film texel of the cell (cell mean x cell area = the haze water moved).
float r2CellWaterMM(int2 c, out float hz) {
    hz = 0.0;
    float w = 0.0;
    if (all(c >= int2(0, 0)) && all(c < int2(gR2Cells))) {
        int2 k = r2HazePerCell();
        float s = 0.0;
        [loop] for (int y = 0; y < k.y; ++y)
            [loop] for (int x = 0; x < k.x; ++x) {
                float2 G = max(txR2Haze.Load(int3(c * k + int2(x, y), 0)).rg, 0.0);
                s += G.x + G.y;
            }
        hz = s * gR2FineMaxMM / (float)(k.x * k.y);
        int2 kf = r2FieldPerCell();
        float sf = 0.0;
        [loop] for (int fy = 0; fy < kf.y; ++fy)
            [loop] for (int fx = 0; fx < kf.x; ++fx) {
                float4 F = txR2Field.Load(int3(c * kf + int2(fx, fy), 0));
                sf += F.b * gR2FilmMaxMM + F.r * gR2TrailMaxMM;
            }
        w = hz + sf / (float)(kf.x * kf.y);
    }
    return w;
}
float r2FilmNucX(int2 c0, float2 tc) {
    float x = 0.0;
    if (gR2FilmNucOn > 0.5 && r2Valid(tc) > 0.5) {
        float hz;
        float w = r2CellWaterMM(c0, hz);
        float q = (gR2FilmRate + gR2SprayFineMMs + gR2RainHazeMMs + gR2SprayCoarseMMs) * gR2Exposure * r2Exposure(tc);
        if (w >= gR2FilmWetMM && q >= w * r2FedRate(gR2FilmRefWMM, saturate(w / max(gR2FilmFullMM, 1e-4)))) {
            bool con = true;
            [loop] for (int k = 0; k < 4; ++k) {
                float hn;
                if (con && r2CellWaterMM(c0 + r2Nb4(k), hn) < gR2HazeSatMM) con = false;
            }
            if (con) x = 1.0 + hz;
        }
    }
    return x;
}
float4 main(PS_IN pin) {
    int2 c0 = int2(pin.PosH.xy);
    float2 tc = (float2(c0) + 0.5) / gR2Cells;
    float4 nz = r2Valid(tc) > 0.5 ? r2HazeNucleus(c0) : float4(0, 0, 0, 0);   // = the cells gate
    float ratio = nz.x > 0.0 ? nz.x / max(nz.y, 1e-12) : 0.0;
    uint cls = (uint)round(txR2HzValid.Load(int3(c0, 0)).r);   // H3-P2: static class (hzv.hlsl, once)
    // H3-P4: the field texels the bilinear samples of this cell's haze texels touch (haze texel centres -> field coords)
    int2 k = r2HazePerCell();
    float2 fs = gR2FieldSize / gR2HazeSize;
    int2 lo = int2(floor((float2(c0 * k) + 0.5) * fs - 0.5));
    int2 hi = int2(floor((float2(c0 * k + k) - 0.5) * fs - 0.5)) + 1;
    int2 fmx = int2(gR2FieldSize) - 1;
    bool hAll = true, hNone = true;
    [loop] for (int y = lo.y; y <= hi.y; ++y) {
        [loop] for (int x = lo.x; x <= hi.x; ++x) {
            float4 F = txR2Field.Load(int3(clamp(int2(x, y), int2(0, 0), fmx), 0));
            bool h = F.b * gR2FilmMaxMM + F.r * gR2TrailMaxMM >= gR2HazeWetMM;
            hAll = hAll && h; hNone = hNone && !h;
        }
    }
    uint wet = hAll ? 1u : (hNone ? 0u : 2u);   // FILM S2-0: depth only (the supply-based wet layer is gone)
    return float4(r2FilmNucX(c0, tc), (float)((cls << 8) | (wet << 10)), ratio, r2Exposure(tc));
}
