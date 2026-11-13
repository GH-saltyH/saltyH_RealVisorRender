// T1 SUBSTEP WIPE MASK (docs/RAINFX_V2_H3_ATLAS_SPEC.md section 8m). Target: WM_next (gR2Cells, RGBA32F, ping-pong), run after
// EVERY cells substep on its S_next; reads WM_prev (txR2Wm, the union of the earlier substeps of this frame; substep 1 starts
// from 0). The haze pass of the frame reads the last one instead of gathering drops itself.
// Why per substep: a drop moves <= gatherCells (1.95) cells per substep, but up to substeps x 1.95 per frame. The haze /
// take-up gather sees a drop only from the 5 x 5 cells around its CURRENT cell, so a frame-end gather missed the start of
// long paths (section 8k B). Here every substep end lies within +-2 cells of every path point of that substep, so the union
// covers the whole path. The swept segment is the packed move of the frame so far (cells.hlsl accumulates it over the
// substeps: the same straight segment the haze pass used), so nothing is wiped twice in a different place.
// Per cell: the swept share of each of its <= 4 x 4 haze texels (r2SweepFrac, the cells take-up law; disc + N2 halo),
// united with the earlier substeps as 1 - (1 - a)(1 - b), 4 bits per texel (r2WmGet, hazenuc.hlsl).
float4 main(PS_IN pin) {
    int2 c0 = int2(pin.PosH.xy);
    int2 size = int2(gR2Cells);
    int2 k = min(r2HazePerCell(), int2(4, 4));
    float4 prev = gR2Sub > 1.5 ? txR2Wm.Load(int3(c0, 0)) : float4(0, 0, 0, 0);
    float2 lo = float2(c0) * gR2CellSizeMM, hi = lo + gR2CellSizeMM;
    float qL = length(0.25 * gR2Cells / gR2HazeSize * gR2CellSizeMM);
    float add[16];
    [unroll] for (int i = 0; i < 16; ++i) add[i] = 0.0;
    bool hit = false;
    [loop] for (uint ci = 0u; ci < 25u; ++ci) {
        int2 s = c0 + int2((int)(ci % 5u) - 2, (int)(ci / 5u) - 2);
        if (any(s < int2(0, 0)) || any(s >= size)) continue;
        float4 st = txR2State.Load(int3(s, 0));
        if (st.z <= 0) continue;
        float2 b = float2(s) + st.xy, mv = r2UnpackMove(st.w);
        float rmm = r2RadiusMM(st.z);
        if (r2SegBoxDist((b - mv) * gR2CellSizeMM, b * gR2CellSizeMM, lo, hi) > (r2HaloOut(rmm) + qL) * 1.001 + 1e-4) continue;
        hit = true;
        [unroll] for (int j = 0; j < 16; ++j) {
            int2 o = int2(j & 3, j >> 2);
            if (o.x < k.x && o.y < k.y && add[j] < 1.0) add[j] += r2SweepFrac(c0 * k + o, gR2HazeSize, b, mv, rmm);
        }
    }
    if (!hit) return prev;
    uint w[3] = { 0u, 0u, 0u };
    [unroll] for (int j = 0; j < 16; ++j) {
        float u = 1.0 - (1.0 - r2WmGet(prev, j)) * (1.0 - saturate(add[j]));
        uint q = (uint)round(saturate(u) * 15.0);
        uint wi = j < 6 ? 0u : (j < 12 ? 1u : 2u);
        uint sh = 4u * (uint)(j < 6 ? j : (j < 12 ? j - 6 : j - 12));
        w[wi] |= q << sh;
    }
    return float4((float)w[0], (float)w[1], (float)w[2], 0.0);
}
