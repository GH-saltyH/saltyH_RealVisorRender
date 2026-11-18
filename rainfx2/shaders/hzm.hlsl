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
    return float4(0.0, (float)((cls << 8) | (wet << 10)), ratio, r2Exposure(tc));
}
