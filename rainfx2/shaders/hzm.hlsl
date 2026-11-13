// N3 HAZE CELL DATA (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 27, H3 spec 8m). Target: HZM (gR2Cells, RGBA32F), made on S_next
// after the cells passes, read by the haze pass. Per cell c0:
//   x    = 0 (T1, 2026-11-13: the drop reach bits are gone -- the haze pass reads the substep wipe mask wm.hlsl; the bits
//          found only drops whose END cell was within +-2 cells, so a drop moving > ~3 cells / frame left most of its
//          path unwiped: 17-57 % of the haze stayed in the trail at 0.28-0.55 m/s);
//   y    = bits 8-9: validity class of the cell's haze texels (0 none valid, 1 all valid, 2 mixed -> the haze pass runs
//          r2Valid per texel only there; static, hzv.hlsl);
//   z    = H1b / N1 removal ratio vB / vEx of the cell (r2HazeNucleus, the same event the cells pass realised);
//   w    = rain / spray exposure at the cell centre (N3b: neighbouring cells differ < 0.5 % on the helmet).
float4 main(PS_IN pin) {
    int2 c0 = int2(pin.PosH.xy);
    float2 tc = (float2(c0) + 0.5) / gR2Cells;
    float4 nz = r2Valid(tc) > 0.5 ? r2HazeNucleus(c0) : float4(0, 0, 0, 0);   // = the cells gate
    float ratio = nz.x > 0.0 ? nz.x / max(nz.y, 1e-12) : 0.0;
    uint cls = (uint)round(txR2HzValid.Load(int3(c0, 0)).r);   // H3-P2: static class (hzv.hlsl, once)
    return float4(0.0, (float)(cls << 8), ratio, r2Exposure(tc));
}
