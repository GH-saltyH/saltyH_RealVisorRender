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

    float2 t = (float2(c) + 0.5) / gR2Cells;
    // rev22 impact clearing (rev21 review: pinned fragments filled every cell -> a regular lattice
    // of dots at speed). A splashing impact (K > K0) spreads a lamella of diameter ~ beta D,
    // beta ~ 0.87 Re^1/5, that atomises / sweeps the small drops it runs over. A drop of
    // r < clearMax is removed at rate impactRate * area(lamella); larger drops keep merging.
    // Equilibrium occupancy = birth / (birth + clear) -> sparse, random, renewing.
    if (accV > 0 && gR2ImpactRate > 0 && r2RadiusMM(accV) < gR2ClearMaxMM) {
        float expC = r2Exposure(t);
        float vI = max(gR2SpeedRel * expC, 0.5);
        float D = gR2MeanDiamMM;
        float Kc = sqrt(13.8889 * vI * vI * D) * pow(max(1000.0 * vI * D, 1e-3), 0.25);
        float Rs = 0.5 * D * 0.87 * pow(max(1000.0 * vI * D, 1e-3), 0.2) * 1e-3;   // m
        float lamC = gR2ImpactRate * expC * gR2Exposure * R2_PI * Rs * Rs * gR2Dt
                   * saturate((Kc - gR2SplashK0) / gR2SplashK0) * gR2ClearK;
        uint seedC = (uint)gR2Frame * 8u + (uint)gR2Sub + 4242u;
        if (r2Rand(uint3((uint)c.x, (uint)c.y, seedC)) < lamC) { accV = 0; accP = float2(0, 0); }
    }
    // Birth: Poisson impacts on this cell, exponential DSD, partial sticking.
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
            // rev21 R-size (docs/RAINFX_V2_DROP_SIZE_RESEARCH.md section 3): impact splash
            // parameter K = We^1/2 Re^1/4 at the normal impact speed. Above K0 ~ 58 the drop
            // fragments: resolved fraction fRes = stick * (K0/K)^a in fragments of
            // dRes = d (K0/K)^b; one fragment per cell, the rest is micro haze / film.
            float vImp = max(gR2SpeedRel * exposure, 0.5);
            float K = sqrt(13.8889 * vImp * vImp * d) * pow(max(1000.0 * vImp * d, 1e-3), 0.25);
            float kr = min(1.0, gR2SplashK0 / max(K, 1e-3));
            float fRes = gR2StickSlow * pow(max(kr, 1e-6), gR2ResA);
            float dRes = d * pow(max(kr, 1e-6), gR2ResB);
            float nFrag = fRes * pow(d / max(dRes, 1e-3), 3.0);
            if (r2Rand(uint3((uint)c.x, (uint)c.y, seed0 + 505u)) < nFrag) {
                float bv = 0.5235988 * dRes * dRes * dRes;
                float2 bp = float2(r2Rand(uint3((uint)c.x, (uint)c.y, seed0 + 202u)),
                                   r2Rand(uint3((uint)c.x, (uint)c.y, seed0 + 303u)));
                p = (p * accV + bp * bv) / (accV + bv);
                if (bv > accV) seed = floor(r2Rand(uint3((uint)c.x, (uint)c.y, seed0 + 404u)) * 16.0);
                accV += bv;
            }
        }
    }
    // rev21: visible drops also GROW out of the unresolved water (research section 3.2):
    //  - dense micro haze condenses into a small drop (it then collects the haze, field pass);
    //  - the leading edge of a moving film throws a head drop (reference A, red circles).
    if (accV <= 0 && r2Valid(t) > 0.5) {
        float4 F = txR2Field.SampleLevel(samLinearClamp, t, 0);
        uint seed1 = (uint)gR2Frame * 8u + (uint)gR2Sub + 7777u;
        float nuc = gR2NucRate * max(F.g - gR2NucM, 0.0) * gR2Dt;
        float bornD = 0;
        if (r2Rand(uint3((uint)c.x, (uint)c.y, seed1)) < nuc)
            bornD = lerp(0.3, 0.6, r2Rand(uint3((uint)c.y, (uint)c.x, seed1 + 1u)));
        float hMM = F.b * gR2FilmMaxMM;
        if (bornD <= 0 && hMM > gR2HeadMinMM) {
            float2 vf = r2FilmVelocity(t, hMM);
            float2 tx = 1.0 / gR2FieldSize;
            float2 gW = float2(txR2Field.SampleLevel(samLinearClamp, t + float2(tx.x, 0), 0).b
                             - txR2Field.SampleLevel(samLinearClamp, t - float2(tx.x, 0), 0).b,
                               txR2Field.SampleLevel(samLinearClamp, t + float2(0, tx.y), 0).b
                             - txR2Field.SampleLevel(samLinearClamp, t - float2(0, tx.y), 0).b);
            float vl = length(vf), gl = length(gW);
            float front = (vl > 1e-6 && gl > 1e-4) ? saturate(-dot(vf / vl, gW / gl)) : 0.0;
            float head = gR2HeadRate * front * saturate(gl * 4.0) * gR2Dt;
            if (r2Rand(uint3((uint)c.x, (uint)c.y, seed1 + 2u)) < head)
                bornD = clamp(hMM * 8.0, 0.6, 2.4) * lerp(0.8, 1.2, r2Rand(uint3((uint)c.y, (uint)c.x, seed1 + 3u)));
        }
        if (bornD > 0) {
            accV = 0.5235988 * bornD * bornD * bornD;
            p = float2(r2Rand(uint3((uint)c.x, (uint)c.y, seed1 + 4u)), r2Rand(uint3((uint)c.x, (uint)c.y, seed1 + 5u)));
            seed = floor(r2Rand(uint3((uint)c.x, (uint)c.y, seed1 + 6u)) * 16.0);
            disp = float2(0, 0);
        }
    }
    // Excess beyond the largest stable cap runs off (keeps one-drop-per-cell bounded).
    float vMax = gR2ShapeK * gR2MaxRadiusMM * gR2MaxRadiusMM * gR2MaxRadiusMM;
    accV = min(accV, vMax);
    return float4(saturate(p) * 0.999, accV, r2PackMove(disp, seed));
}
