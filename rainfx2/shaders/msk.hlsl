// PERF-10 CANDIDATE MASK (2026-11-06; after PERF-9 every visor pixel still loads 34 drop records -- 25 cells + 9
// big tiles -- although nearly all are empty or farther than their early-out radius). Per cell c0 of the visor
// pixel (pc in [c0, c0 + 1)): bit ci (the visor loop index) is set when candidate ci can reach SOME point of the
// cell, i.e. the record's centre lies within min(early radius w, rev48 reach) of the cell rectangle. A pixel's
// offset |q| is never below that rectangle distance, so a clear bit is a candidate the visor would skip anyway
// (r2CandRec: out of reach or 'early') -> the visor iterates set bits only, with identical results.
// Output: x = bits 0-16, y = bits 17-33 (integer-valued floats, exact). Valid only without D-A widening
// (reachMM 0): the visor uses it only for such pixels. Margin x 1.001 + 1e-4 mm only adds candidates.
float4 main(PS_IN pin) {
    int2 c0 = int2(pin.PosH.xy);
    int2 size = int2(gR2Cells);
    int2 tc = int2((uint2)c0 >> 2);
    uint nCand = gR2BigOn > 0.5 ? 34u : 25u;
    uint lo = 0u, hi = 0u;
    [loop] for (uint ci = 0u; ci < nCand; ++ci) {
        int2 s;
        bool bp = ci >= 25u;
        if (!bp) {
            s = c0 + int2((int)(ci % 5u) - 2, (int)(ci / 5u) - 2);
        } else {
            uint cj = ci - 25u;
            int2 tt = tc + int2((int)(cj % 3u) - 1, (int)(cj / 3u) - 1);
            if (any(tt < int2(0, 0)) || any(tt * 4 >= size)) continue;
            float4 bg = txR2Big.Load(int3(tt, 0));
            if (bg.z < 0.5) continue;
            s = int2(round(bg.xy));
        }
        if (any(s < int2(0, 0)) || any(s >= size)) continue;
        float4 R0 = txR2Rec.Load(int3(s, 0));
        if (R0.z == 0.0 || (R0.z < 0.0) != bp) continue;
        float2 dc = max(abs(R0.xy - (float2(c0) + 0.5)) - 0.5, 0.0) * gR2CellSizeMM;
        float lim = min(R0.w * 1.002, abs(R0.z) - 1.0) * 1.001 + 1e-4;
        if (dot(dc, dc) > lim * lim) continue;
        if (ci < 17u) lo |= 1u << ci; else hi |= 1u << (ci - 17u);
    }
    return float4((float)lo, (float)hi, 0.0, 0.0);
}
