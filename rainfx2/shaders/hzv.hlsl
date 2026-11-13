// H3-P2 HAZE VALIDITY CLASS (docs/RAINFX_V2_H3_ATLAS_SPEC.md section 8d). Target: HZV (gR2Cells, R16F), run ONCE (static
// geometry: du alpha + boundary mask). Per cell: 0 = none of its haze texels valid, 1 = all valid (and the haze grid is an
// exact multiple of the cells), 2 = mixed. N3b computed this in hzm every frame (16 r2Valid = 32 loads of the large du /
// mask textures per cell: hzm 0.05 -> 0.11 ms); hzm now loads it once per cell.
float4 main(PS_IN pin) {
    int2 c0 = int2(pin.PosH.xy);
    int2 k = r2HazePerCell();
    uint nV = 0u, nT = 0u;
    [loop] for (int vy = 0; vy < k.y; ++vy) {
        [loop] for (int vx = 0; vx < k.x; ++vx) {
            int2 f = c0 * k + int2(vx, vy);
            if (any(f >= int2(gR2HazeSize))) continue;
            nT += 1u;
            nV += r2Valid((float2(f) + 0.5) / gR2HazeSize) > 0.5 ? 1u : 0u;
        }
    }
    uint cls = nV == 0u ? 0u : (nV == nT && all(k * int2(gR2Cells) == int2(gR2HazeSize)) ? 1u : 2u);
    return float4((float)cls, 0, 0, 0);
}
