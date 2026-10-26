// P1c (rev6): coalescence merge. Target: S_next (gR2Cells, RGBA32F).
// Reads S (after P1) and the claims C. A cell keeps its own drop unless it was claimed,
// and gathers every neighbour whose claim points at it: volume adds, position is the
// volume centroid (may leave the cell by < 1 cell; the next P1 gather relocates it),
// seed and packed move follow the largest contributor. Mass is conserved except the
// stable-size cap (excess runs off, same rule as P1).

float4 main(PS_IN pin) {
    int2 c = int2(pin.PosH.xy);
    int2 size = int2(gR2Cells);
    float4 me = txR2State.Load(int3(c, 0));
    float4 mc = txR2Claim.Load(int3(c, 0));
    float accV = 0, bigV = 0, w = r2PackMove(float2(0, 0), 0);
    float2 accP = float2(0, 0);
    if (me.z > 0 && mc.z < 0.5) {
        accV = me.z; accP = me.xy * me.z; bigV = me.z; w = me.w;
    }
    [unroll] for (int y = -2; y <= 2; ++y) {
        [unroll] for (int x = -2; x <= 2; ++x) {
            if (x == 0 && y == 0) continue;
            int2 s = c + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            float4 cl = txR2Claim.Load(int3(s, 0));
            if (cl.z < 0.5 || any(int2(round(cl.xy)) != int2(-x, -y))) continue;
            float4 st = txR2State.Load(int3(s, 0));
            accV += st.z;
            accP += (float2(x, y) + st.xy) * st.z;
            if (st.z > bigV) { bigV = st.z; w = st.w; }
        }
    }
    if (accV <= 0) return float4(0.4995, 0.4995, 0, r2PackMove(float2(0, 0), 0));
    float2 p = clamp(accP / accV, -0.75, 1.749);
    float vMax = gR2ShapeK * gR2MaxRadiusMM * gR2MaxRadiusMM * gR2MaxRadiusMM;
    return float4(p, min(accV, vMax), w);
}
