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
    // rev45: the target is twice the cell width; the second third writes the life cycle L of the same
    // cell (identical gather, so L follows the drop that wins the cell).
    int2 px = int2(pin.PosH.xy);
    // rev48-S1: three cell widths [drop | life | shape], same gather for all three
    int third = px.x >= 2 * (int)gR2Cells.x ? 2 : (px.x >= (int)gR2Cells.x ? 1 : 0);
    bool lifeHalf = third == 1;
    int2 c = px - int2(third * (int)gR2Cells.x, 0);
    float4 shape = float4(0, 0, r2PackHarm(0, 0), 0);
    bool bigMoved = false;
    bool bigSplit = false;                        // rev48-S6c E8: the winner shed its tail this step
    R2ShapeAcc sacc = r2ShapeAccInit();           // rev48-S3: drops landing in one cell merge footprints
    int2 size = int2(gR2Cells);
    float4 life = float4(0, 0, 0, 0);
    float accV = 0, accW = 0;                     // rev48-S4b: accW = footprint-area weight (position, winner)
    float2 accP = float2(0, 0);
    float2 accD = float2(0, 0);
    float bigV = 0, seed = 0;          // shape seed follows the largest contributor
    // rev48-S6c: [loop] -- with the E8 split in r2Predict the unrolled 5x5 body exceeded FXC's unroll limit (X3511)
    [loop] for (int y = -2; y <= 2; ++y) {
        [loop] for (int x = -2; x <= 2; ++x) {
            int2 s = c + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            float4 st = txR2State.Load(int3(s, 0));
            if (st.z <= 0) continue;
            float4 shs = r2Shape(s);
            R2Move m = r2Predict(s, st, r2Life(s), shs);
            // rev48-S6c E8: the tail piece split off by source s lands here -> a resting drop (or it merges with
            // what is here); it is existing water: drawn at once, not swept back into its parent (life.w -5)
            if (m.cVol > 0 && all(int2(floor(m.cDest)) == c)) {
                float4 shC = r2ShapeMake(1.2, m.cPhi, 0.0, 0.0, 0.0, r2UnpackBF(shs.w).y);
                float waC = r2FootW(m.cVol, shC);
                accV += m.cVol;
                accW += waC;
                accP += (m.cDest - float2(c)) * waC;
                r2ShapeAccAdd(sacc, shC, m.cVol, (m.cDest - float2(c)) * gR2CellSizeMM);
                if (waC > bigV) {
                    bigV = waC; seed = fmod(r2UnpackSeed(st.w) + 17.0, R2_SEEDS);
                    float thP = atan2(-sin(m.cPhi), -cos(m.cPhi));   // direction to the parent (visor neck)
                    life = float4(0, 0, 0, -5.0 + 0.1 * thP / 3.14159265);
                    shape = shC; bigMoved = false; bigSplit = false;
                }
            }
            if (m.alive < 0.5) continue;
            if (any(int2(floor(m.dest)) != c)) continue;
            float wa = r2FootW(m.vol, shs);
            accV += m.vol;
            accW += wa;
            accP += (m.dest - float2(c)) * wa;
            r2ShapeAccAdd(sacc, shs, m.vol, (m.dest - float2(c)) * gR2CellSizeMM);
            accD += (m.dest - (float2(s) + st.xy)) * m.vol;
            if (gR2Sub > 1.5) accD += r2UnpackMove(st.w) * m.vol;   // accumulate within the frame
            if (wa > bigV) { bigV = wa; seed = r2UnpackSeed(st.w); life = m.life; shape = shs; bigMoved = m.moved > 1e-3; bigSplit = m.cVol > 0; }
        }
    }
    if (third == 2 && accV > 0) shape = r2ShapeCompose(sacc, bigMoved);   // rev48-S4: moving head keeps its shape
    // rev48-S6c E8: a parent that shed its tail is shorter (e x 0.55) and straight (the hook / bow went with it)
    if (third == 2 && bigSplit) shape = float4(shape.xy * 0.55, shape.z, r2PackBF(0.0, r2UnpackBF(shape.w).y));
    float2 p = accW > 0 ? accP / accW : float2(0.5, 0.5);
    float2 disp = accV > 0 ? accD / accV : float2(0, 0);

    float2 t = (float2(c) + 0.5) / gR2Cells;
    float wetB = third == 2 ? r2Wet(txR2Field.SampleLevel(samLinearClamp, t, 0)) : 0.0;   // rev48-S4 shape births / equilibrium
    float3 gI = third == 2 ? r2GravInfo(t) : float3(0, 1, 0);                              // rev48-S5 E7 sag target
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
        float4 ig = r2ImpactGeom(t);                    // rev48-S2 oblique impact (Vt direction, aspect)
        float sqA = sqrt(ig.z);
        float bestV = 0.0, bestK = 1.0;              // rev48-S5 E1: K / K0 of the winning fragment's impact
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
                // rev48-S2: the lamella is an ellipse of aspect A stretched along Vt, its centre shifted
                // downstream -- fragments and the swept patch fall below / downstream of the impact point.
                // rev48-S2': shift 0.3 -> gR2ShpLamShift (0.15): the reference splats spread nearly evenly
                float2 dl = float2(dot(dm, ig.xy) - gR2ShpLamShift * Rs * (ig.z - 1.0), dot(dm, float2(-ig.y, ig.x)));
                dl *= float2(1.0 / sqA, sqA);
                if (dot(dl, dl) > Rs * Rs) continue;                                // lamella misses c
                if (K > gR2SplashK0 && accV > 0 && r2RadiusMM(accV) < gR2ClearMaxMM
                    && r2Rand(uint3(c.x, c.y, seed0 + 4242u + (uint)(ex + 2) * 5u + (uint)(ey + 2))) < gR2ClearK) {
                    swept = true;                                                    // swept by the splash
                }
                float ncov = max(3.14159265 * Rs * Rs / cellMM2, 1.0);
                float pf = min(nFrag, gR2FragMax) / ncov;
                uint k = seed0 + 505u + (uint)(ex + 2) * 5u + (uint)(ey + 2);
                float dF = min(dRes * r2FragX(r2Rand(uint3(c.y, c.x, k + 606u))), d);
                // rev48-S2' (reference birth events): satellites are left where the receding rim breaks -- on the
                // RIM of the splat footprint; the bulk (large fragments) gathers inside. Ring weight ~ mean 1.
                float ring = smoothstep(0.55, 0.9, length(dl) / max(Rs, 1e-3));
                pf *= dF < 0.5 * d ? lerp(0.3, 2.0, ring) : lerp(1.6, 0.4, ring);
                if (r2Rand(uint3(c.x, c.y, k)) >= pf) continue;
                if (0.5 * dF < gR2MinRadiusMM) continue;                             // too small: haze
                // rev47b: no 'torn off at birth' rule -- new drops run back with the air
                float bv = 0.5235988 * dF * dF * dF;
                if (bv > bestV) {
                    bestV = bv;
                    bestK = K / max(gR2SplashK0, 1e-3);
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
                // rev48-S2' SPREAD: the newborn is first a thin splat f0 x its final radius (normal Weber number
                // We_n = rho Vn^2 d / gamma, f0 1.8-3.2 with spread), recoiling in the visor as
                // f(age) = 1 + (f0 - 1) exp(-age / shpSpreadTau). life.w = -(10 + f0) marks it (flight unused).
                float vn = gR2SpeedRel / sqrt(1.0 + ig.w * ig.w);
                float weN = 1000.0 * vn * vn * (2e-3 * r2RadiusMM(bestV)) / 0.072;
                float f0 = clamp(gR2ShpSpreadMin + 0.45 * log2(max(weN / 30.0, 1.0)) * 0.5
                                 + 0.4 * r2Rand(uint3((uint)c.y, (uint)c.x, seed0 + 4141u)), gR2ShpSpreadMin, gR2ShpSpreadMax);
                life.w = -(10.0 + f0);
                shape = r2ShapeImpact(uint2(c), seed0 + 4040u, r2RadiusMM(bestV), t, ig, wetB, f0, bestK);   // rev48-S4 arrest
            }
            // rev48-S2 skid (newborn) / rev48-S2' PUSH (merged into an existing drop): the tangential impact
            // momentum moves the drop by its mass share; the kinetic pinning (pinKinetic) of a pushed drop near
            // its threshold then lets it run on -- the reference's 'drop pushed off by an impact'.
            float vSk = min(gR2ShpSkidK * ig.w * gR2SpeedRel / sqrt(1.0 + ig.w * ig.w), gR2ShpSkidMax);
            float share = bestV / (accV + bestV);
            disp = (bestV > accV ? float2(0, 0) : disp) + ig.xy * (vSk * share * 1000.0 * gR2Dt) / gR2CellSizeMM;
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
                shape = r2ShapeBirth(uint2(c), (uint)gR2Frame * 8u + 9100u, r2RadiusMM(vBead), t, wetB);
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
            shape = r2ShapeBirth(uint2(c), seed1 + 600u, 0.5 * bornD, t, wetB);
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
    // single exit (FXC X4000 with the rev48 third-section early return)
    float4 res = lifeHalf ? life : float4(min(saturate(p), 0.9995), accV, r2PackMove(disp, seed));
    if (third == 2) {
        // rev48-S4: motion morph from this step's displacement; pinned shapes are held (arrested splats keep
        // their state -- the S2 recoil flag is gone, the visor recoil f0 -> f is purely visual)
        float2 dMM = disp * gR2CellSizeMM;
        float vms = length(dMM) * 1e-3 / max(gR2Dt * max(gR2Sub, 1.0), 1e-5);
        bool mov = vms > 2e-3 && !(life.w < -9.5 && life.x < 0.3);   // a fresh splat's skid does not erase its arrest
        float rNow = r2RadiusMM(accV);
        float3 aI = accV > 0 ? r2AirTopInfo((float2(c) + p) / gR2Cells, rNow) : float3(1, 0, 0);   // rev48-S5 E6
        res = accV > 0 ? r2ShapeRelax(shape, rNow, mov, gR2Dt, dMM, vms, frac(seed * 0.4142136 + 0.17), wetB, gI, aI)
                       : float4(0, 0, r2PackHarm(0, 0), 0);
    }
    return res;
}
