// P1: drop cell update (birth + move + 5x5 gather/merge). Target: S_next (gR2Cells, RGBA32F).
// Reads txR2State = S_prev. Mass is conserved by the gather except edge exits,
// trail/evaporation losses and shed drops (see r2Predict).
// Output w = volume-weighted displacement of this step (cells), packed by r2PackMove,
// so the field pass can draw the swept segment without re-running r2Predict.

// rev40: inverse CDF of the fragment size law, X = (lo^-a + u (hi^-a - lo^-a))^(-1/a).
float r2FragX(float u) {
    return exp2(log2(max(lerp(gR2FragLoP, gR2FragHiP, u), 1e-6)) * gR2FragInvA);
}

// rev41 clustering (rev40 review: the reference shows dense groups of small and large drops, v2 an
// even spread): birth rates are modulated by a slowly drifting low-frequency field (gR2ClusterK,
// features of clusterMM, time scale ~3 s) with mean 1, so groups form and dissolve.
float r2Cluster(float2 t) {
    float n = r2VNoise(t * gR2ClusterScale + float2(gR2Time * 0.21, gR2Time * 0.13));
    return max(1.0 + gR2ClusterK * (2.0 * n - 1.0) * 1.6, 0.0);
}

float4 main(PS_IN pin) {
    // rev45: the target is twice the cell width; the right half writes the life cycle L of the same
    // cell (identical gather, so L follows the drop that wins the cell).
    int2 px = int2(pin.PosH.xy);
    bool lifeHalf = px.x >= (int)gR2Cells.x;
    int2 c = lifeHalf ? px - int2((int)gR2Cells.x, 0) : px;
    int2 size = int2(gR2Cells);
    float4 life = float4(0, 0, 0, 0);
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
            R2Move m = r2Predict(s, st, r2Life(s));
            if (m.alive < 0.5) continue;
            if (any(int2(floor(m.dest)) != c)) continue;
            accV += m.vol;
            accP += (m.dest - float2(c)) * m.vol;
            accD += (m.dest - (float2(s) + st.xy)) * m.vol;
            if (gR2Sub > 1.5) accD += r2UnpackMove(st.w) * m.vol;   // accumulate within the frame
            if (m.vol > bigV) { bigV = m.vol; seed = r2UnpackSeed(st.w); life = m.life; }
        }
    }
    float2 p = accV > 0 ? accP / accV : float2(0.5, 0.5);
    float2 disp = accV > 0 ? accD / accV : float2(0, 0);

    float2 t = (float2(c) + 0.5) / gR2Cells;
    // rev44 COUPLED IMPACT EVENTS (rev43 sprint recording: ~2.7 drops appeared and ~2.7 vanished per
    // frame in a 900 x 300 px sky crop, at unrelated places -> 'ticking'). rev22-43 cleared small
    // drops and placed fragments by two independent per-cell random draws, so a drop vanished with no
    // visible cause and another popped up elsewhere. Now an impact is ONE event at an impact point
    // (hash of the impact cell and the substep); every cell inside its lamella (radius Rs, splashing
    // impacts K > K0) loses its small drop AND may receive one of that impact's fragments -- a local
    // splash replaces a patch of drops at once, cause and effect together. Expected rates equal the
    // rev41 rates (fragments per covered cell = min(nFrag, fragMax) / covered cells).
    // Fragments below the smallest stable radius are not born (rev43: they lived exactly one frame).
    if (gR2ImpactRate > 0 && r2Valid(t) > 0.5) {
        float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
        float3 dv = r2ToWorld(r2Tap(txR2Dv, t).xyz);
        float cellArea = length(cross(du, dv)) / (gR2Cells.x * gR2Cells.y);   // m^2
        float cellMM2 = gR2CellSizeMM.x * gR2CellSizeMM.y;
        float exposure = r2Exposure(t);
        float lambda = gR2ImpactRate * cellArea * exposure * gR2Exposure * gR2Dt;   // impacts per cell
        float vImp = max(gR2SpeedRel * exposure, 0.5);
        uint seed0 = (uint)gR2Frame * 8u + (uint)gR2Sub;
        float cl = r2Cluster(t);
        float bestV = 0.0;
        bool swept = false;
        float2 bestP = float2(0.5, 0.5);
        [loop] for (int ey = -2; ey <= 2; ++ey) {
            [loop] for (int ex = -2; ex <= 2; ++ex) {
                uint2 e = uint2(c + int2(ex, ey));
                if (r2Rand(uint3(e.x, e.y, seed0)) >= lambda * cl) continue;        // no impact at e
                float u1 = r2Rand(uint3(e.y, e.x, seed0 + 101u));
                float d = clamp(-log(max(1.0 - u1, 1e-6)) * gR2MeanDiamMM, 0.1, 3.5);
                float K = sqrt(13.8889 * vImp * vImp * d) * pow(max(1000.0 * vImp * d, 1e-3), 0.25);
                float kr = min(1.0, gR2SplashK0 / max(K, 1e-3));
                float fRes = gR2StickSlow * pow(max(kr, 1e-6), gR2ResA);
                float dRes = d * pow(max(kr, 1e-6), gR2ResB);
                float nFrag = fRes * pow(d / max(dRes, 1e-3), 3.0) / max(gR2FragM3, 1e-3);
                // lamella radius (mm), beta ~ 0.87 Re^1/5; a non-splashing drop stays in its cell
                float Rs = max(0.5 * d * 0.87 * pow(max(1000.0 * vImp * d, 1e-3), 0.2), 0.6 * gR2CellMM);
                float2 ip = float2(int2(e)) + float2(r2Rand(uint3(e.x, e.y, seed0 + 202u)), r2Rand(uint3(e.x, e.y, seed0 + 303u)));
                float2 dm = (float2(c) + 0.5 - ip) * gR2CellSizeMM;
                if (dot(dm, dm) > Rs * Rs) continue;                                // lamella misses c
                if (K > gR2SplashK0 && accV > 0 && r2RadiusMM(accV) < gR2ClearMaxMM
                    && r2Rand(uint3(c.x, c.y, seed0 + 4242u + (uint)(ex + 2) * 5u + (uint)(ey + 2))) < gR2ClearK) {
                    swept = true;                                                    // swept by the splash
                }
                float ncov = max(3.14159265 * Rs * Rs / cellMM2, 1.0);
                float pf = min(nFrag, gR2FragMax) / ncov;
                uint k = seed0 + 505u + (uint)(ex + 2) * 5u + (uint)(ey + 2);
                if (r2Rand(uint3(c.x, c.y, k)) >= pf) continue;
                float dF = min(dRes * r2FragX(r2Rand(uint3(c.y, c.x, k + 606u))), d);
                if (0.5 * dF < gR2MinRadiusMM) continue;                             // too small: haze
                // rev47b: no 'torn off at birth' rule -- new drops run back with the air
                float bv = 0.5235988 * dF * dF * dF;
                if (bv > bestV) {
                    bestV = bv;
                    bestP = float2(r2Rand(uint3(c.x, c.y, k + 202u)), r2Rand(uint3(c.x, c.y, k + 303u)));
                }
            }
        }
        // rev45: a swept drop is replaced by the splash fragment when one lands here (one event), else
        // it fades out over gR2FadeTime instead of vanishing (rev22-44 deleted it at once).
        // rev47b IMPACT MERGE (rev47 review): an impact on a small drop mostly merges with it; a share
        // gR2ImpactLoss splashes off (rev44-47 removed the whole drop -> water lost with every impact).
        // Only a drop left below the stable size fades out.
        if (swept) {
            float left = accV * (1.0 - gR2ImpactLoss);
            if (r2RadiusMM(left + bestV) < gR2MinRadiusMM) {
                if (life.z <= 0 && life.y <= 0) life.z = gR2FadeTime;
            } else {
                accV = left;
            }
        }
        if (bestV > 0) {
            p = (p * accV + bestP * bestV) / (accV + bestV);
            if (bestV > accV) {
                seed = floor(r2Rand(uint3((uint)c.x, (uint)c.y, seed0 + 404u)) * R2_SEEDS);
                life = float4(0, 0, 0, 0);                                         // newborn: grows in
            }
            accV += bestV;
        }
    }
    // rev47j DEWETTING + PEARLING (docs/RAINFX_V2_REV47J_REVIEW.md, mass-conserving): once per frame
    //  - a thin film on the partially wetting visor gathers into a bead: an event cell whose mean film depth
    //    is >= gR2FilmBeadMM turns all of it (depth x cell area) into a drop, or feeds the drop already there;
    //  - a rivulet section beads up (Plateau-Rayleigh): an event cell turns the rivulet section whose centre
    //    line runs through it ((4/3) h0 hw x cell length, h0 >= gR2PearlMM) into a bead ON the line.
    // The field pass removes exactly that water (same hash of cell and frame, same F_prev / TG_prev).
    if (gR2Sub < 1.5 && r2Valid(t) > 0.5) {
        float vBead = 0;
        float2 pBead = float2(r2Rand(uint3((uint)c.x, (uint)c.y, (uint)gR2Frame * 8u + 9003u)),
                              r2Rand(uint3((uint)c.y, (uint)c.x, (uint)gR2Frame * 8u + 9004u)));
        if (r2DewetEvent(c)) {
            float hC = r2CellFilmMM(c);
            if (hC >= gR2FilmBeadMM) vBead += hC * gR2CellSizeMM.x * gR2CellSizeMM.y;
        }
        // pearl event (per line: rate grows as the rivulet narrows); cheap reject at the highest rate first
        if (r2Rand(uint3((uint)c.y, (uint)c.x, (uint)gR2Frame * 8u + 9002u)) < gR2PearlRate * 6.0 * gR2SimDt) {
            int2 k = r2FieldPerCell();
            float best = 0, vT = 0;
            [loop] for (int fy = -1; fy <= k.y; ++fy) {
                [loop] for (int fx = -1; fx <= k.x; ++fx) {
                    int2 f = c * k + int2(fx, fy);
                    if (any(f < int2(0, 0)) || any(f >= int2(gR2FieldSize))) continue;
                    float h0 = txR2Field.Load(int3(f, 0)).r * gR2TrailMaxMM;
                    if (h0 < gR2PearlMM || h0 <= best) continue;
                    float4 g = txR2Trail.Load(int3(f, 0));
                    if (any(r2TrailCell(f, g) != c) || !r2PearlEvent(c, g.w)) continue;
                    best = h0;
                    vT = 1.3333 * h0 * g.w * gR2CellMM;
                    pBead = saturate((float2(f) + 0.5) / gR2FieldSize * gR2Cells + g.xy / gR2CellSizeMM - float2(c));
                }
            }
            vBead += vT;
        }
        if (vBead > 0) {
            if (accV > 0) {
                accV += vBead;
            } else if (r2RadiusMM(vBead) >= gR2MinRadiusMM) {
                accV = vBead;
                p = pBead;
                seed = floor(r2Rand(uint3((uint)c.x, (uint)c.y, (uint)gR2Frame * 8u + 9005u)) * R2_SEEDS);
                disp = float2(0, 0);
                life = float4(0, 0, 0, 0);
            }
        }
    }
    // rev21: visible drops also GROW out of the unresolved water (research section 3.2):
    //  - dense micro haze condenses into a small drop (it then collects the haze, field pass);
    //  - the leading edge of a moving film throws a head drop (reference A, red circles).
    if (accV <= 0 && r2Valid(t) > 0.5) {
        float4 F = txR2Field.SampleLevel(samLinearClamp, t, 0);
        uint seed1 = (uint)gR2Frame * 8u + (uint)gR2Sub + 7777u;
        float nuc = gR2NucRate * max(F.g - gR2NucM, 0.0) * gR2Dt * r2Cluster(t);
        float bornD = 0;
        if (r2Rand(uint3((uint)c.x, (uint)c.y, seed1)) < nuc)
            bornD = min(gR2NucDiamMM * r2FragX(r2Rand(uint3((uint)c.y, (uint)c.x, seed1 + 1u))), 1.5);   // rev40: same size law
        // rev47j: the film head drops (rev21) and the trail pearling births (rev45) created water; both are
        // replaced by the mass-conserving dewetting / pearling events above.
        if (bornD > 0) {                                  // rev42: no drop the air tears off at once
            if (0.5 * bornD < gR2MinRadiusMM) bornD = 0.0;   // rev44: no one-frame drops (rev47b: runback, no torn-off rule)
        }
        if (bornD > 0) {
            accV = 0.5235988 * bornD * bornD * bornD;
            p = float2(r2Rand(uint3((uint)c.x, (uint)c.y, seed1 + 4u)), r2Rand(uint3((uint)c.x, (uint)c.y, seed1 + 5u)));
            seed = floor(r2Rand(uint3((uint)c.x, (uint)c.y, seed1 + 6u)) * R2_SEEDS);
            disp = float2(0, 0);
            life = float4(0, 0, 0, 0);
        }
    }
    // Excess beyond the largest stable cap runs off (keeps one-drop-per-cell bounded).
    float vMax = gR2ShapeK * gR2MaxRadiusMM * gR2MaxRadiusMM * gR2MaxRadiusMM;
    accV = min(accV, vMax);
    // rev41: clamp, not scale. rev1-rev40 wrote saturate(p) * 0.999: every substep moved every drop
    // 0.1 % of its in-cell position toward the cell origin (-u, -v) -> the slow drift of resting drops
    // toward one offset that the user saw since the first v2 build (~1 mm over a few seconds).
    if (accV <= 0) life = float4(0, 0, 0, 0);
    return lifeHalf ? life : float4(min(saturate(p), 0.9995), accV, r2PackMove(disp, seed));
}
