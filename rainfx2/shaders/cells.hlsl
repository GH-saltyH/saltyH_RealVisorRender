// P1: drop cell update (birth + move + 5x5 gather/merge). Target: S_next (gR2Cells, RGBA32F).
// Reads txR2State = S_prev. Mass is conserved by the gather except edge exits,
// trail/evaporation losses and shed drops (see r2Predict).
// Output w = volume-weighted displacement of this step (cells), packed by r2PackMove,
// so the field pass can draw the swept segment without re-running r2Predict.

float4 main(PS_IN pin) {
    int2 c = int2(pin.PosH.xy);
    int2 size = int2(gR2Cells);
    float accV = 0;
    float2 accP = float2(0, 0);
    float2 accD = float2(0, 0);
    float bigV = 0, seed = 0;          // shape seed follows the largest contributor
    [unroll] for (int y = -2; y <= 2; ++y) {
        [unroll] for (int x = -2; x <= 2; ++x) {
            int2 s = c + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            float4 st = txR2State.Load(int3(s, 0));
            if (st.z <= 0) continue;
            R2Move m = r2Predict(s, st);
            if (m.alive < 0.5) continue;
            if (any(int2(floor(m.dest)) != c)) continue;
            accV += m.vol;
            accP += (m.dest - float2(c)) * m.vol;
            accD += (m.dest - (float2(s) + st.xy)) * m.vol;
            if (gR2Sub > 1.5) accD += r2UnpackMove(st.w) * m.vol;   // accumulate within the frame
            if (m.vol > bigV) { bigV = m.vol; seed = r2UnpackSeed(st.w); }
        }
    }
    float2 p = accV > 0 ? accP / accV : float2(0.5, 0.5);
    float2 disp = accV > 0 ? accD / accV : float2(0, 0);

    // Birth: Poisson impacts on this cell, exponential DSD, partial sticking.
    float2 t = (float2(c) + 0.5) / gR2Cells;
    if (gR2ImpactRate > 0 && r2Valid(t) > 0.5) {
        float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
        float3 dv = r2ToWorld(r2Tap(txR2Dv, t).xyz);
        float cellArea = length(cross(du, dv)) / (gR2Cells.x * gR2Cells.y);   // m^2
        float exposure = r2Exposure(t);
        float lambda = gR2ImpactRate * cellArea * exposure * gR2Exposure * gR2Dt;
        uint seed0 = (uint)gR2Frame * 8u + (uint)gR2Sub;
        if (r2Rand(uint3((uint)c.x, (uint)c.y, seed0)) < lambda) {
            float u1 = r2Rand(uint3((uint)c.y, (uint)c.x, seed0 + 101u));
            float d = clamp(-log(max(1.0 - u1, 1e-6)) * gR2MeanDiamMM, 0.1, 3.5);
            float bv = 0.5235988 * d * d * d * gR2StickFrac;
            float2 bp = float2(r2Rand(uint3((uint)c.x, (uint)c.y, seed0 + 202u)),
                               r2Rand(uint3((uint)c.x, (uint)c.y, seed0 + 303u)));
            p = (p * accV + bp * bv) / (accV + bv);
            if (bv > accV) seed = floor(r2Rand(uint3((uint)c.x, (uint)c.y, seed0 + 404u)) * 16.0);
            accV += bv;
        }
    }
    // Excess beyond the largest stable cap runs off (keeps one-drop-per-cell bounded).
    float vMax = gR2ShapeK * gR2MaxRadiusMM * gR2MaxRadiusMM * gR2MaxRadiusMM;
    accV = min(accV, vMax);
    return float4(saturate(p) * 0.999, accV, r2PackMove(disp, seed));
}
