// P1b (rev6): coalescence claim. Target: C (gR2Cells, RGBA16F), reads S after P1.
// Two drops whose contact discs touch (d < gR2CoalesceK * (r1 + r2)) merge in reality
// at once. One drop per cell cannot express touching neighbours, so without this step a
// saturated visor becomes a regular lattice of equal drops (rev5 defocus made the
// lattice visible as a woven texture). Each drop claims the LARGEST touching neighbour
// that ranks above it (volume, then cell index); the merge pass moves its volume there.
// Output: xy = offset of the absorbing cell, z = 1 if claimed.

float r2CellIndex(int2 s) { return (float)s.y * gR2Cells.x + (float)s.x; }

float4 main(PS_IN pin) {
    int2 c = int2(pin.PosH.xy);
    int2 size = int2(gR2Cells);
    float4 me = txR2State.Load(int3(c, 0));
    if (me.z <= 0) return float4(0, 0, 0, 0);
    float rm = r2RadiusMM(me.z);
    float2 pm = float2(c) + me.xy;
    float im = r2CellIndex(c);
    float bestV = 0, bestI = -1;
    int2 best = int2(0, 0);
    [unroll] for (int y = -2; y <= 2; ++y) {
        [unroll] for (int x = -2; x <= 2; ++x) {
            if (x == 0 && y == 0) continue;
            int2 s = c + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            float4 st = txR2State.Load(int3(s, 0));
            if (st.z <= 0) continue;
            float is = r2CellIndex(s);
            if (st.z < me.z || (st.z == me.z && is < im)) continue;     // must rank above me
            float2 dmm = (float2(s) + st.xy - pm) * gR2CellSizeMM;
            if (length(dmm) >= gR2CoalesceK * (rm + r2RadiusMM(st.z))) continue;
            if (st.z > bestV || (st.z == bestV && is > bestI)) {
                bestV = st.z; bestI = is; best = int2(x, y);
            }
        }
    }
    return bestI >= 0 ? float4((float2)best, 1, 0) : float4(0, 0, 0, 0);
}
