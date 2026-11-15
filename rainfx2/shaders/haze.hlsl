// H1c / H3-3 HAZE LAYER (docs/RAINFX_V2_H3_ATLAS_SPEC.md sections 4, 8e, 8f). Target: HZ_next (gR2HazeSize, R16G16F), mm of water
// in units of gR2FineMaxMM:  R = G_f, FRESH FINE water (unresolved micro caps: the white veil),
//                            G = G_c, COARSENED water (the micro-drop pieces of the H3 atlas; size a_eff = a_min G_c / G_sat).
// Reads HZ_prev (txR2Haze), the T1 substep wipe mask (txR2Wm, wm.hlsl), the cell data (txR2HzMask, hzm.hlsl) and F_prev
// (txR2Field: S1 water layers). Twice the field resolution (0.29 mm).
//   loss:   the discs (+ N2 halo) drops swept this frame, BOTH components (r2SweepFrac -- the cells pass gave the same
//           water to those drops); G_c above the top octave (pieces at a_max) leaves as a cell drop (hzm ratio = the
//           cells event); evaporation (fine caps gR2FineEvapK, coarse x (a_min / a_eff)^2).
//   supply: sub-visible stuck share of every impact x cell exposure; the share landing ON existing pieces (their
//           coverage) joins G_c at once, the rest is fresh G_f; drawn spray pieces below a_max go to G_c (8g).
//   E2 coarsening G_f -> G_c: rate G_f / tau x (phi_f / phi_max)^2 -- micro caps merge when they touch (probability ~
//           coverage^2): slow right after a wipe, fast once the fine coat is dense. A wiped texel restarts at 0 / 0 and
//           re-evolves white veil -> small pieces -> large pieces (E1: size from G_c, not from the total).
// gR2HazeMaskMode >= 1 = T1 wipe mask, 0 = the legacy 25-record frame-end loop (A/B).
float4 main(PS_IN pin) {
    int2 f = int2(pin.PosH.xy);
    float2 t = (float2(f) + 0.5) / gR2HazeSize;
    float2 pc = t * gR2Cells;
    int2 c0 = int2(floor(pc));
    int2 size = int2(gR2Cells);
    float4 hm = txR2HzMask.Load(int3(c0, 0));
    uint hy = (uint)hm.y;
    uint cls = (hy >> 8) & 3u;                                       // N3b: 0 none valid | 1 all valid | 2 mixed
    if (cls == 0u || (cls == 2u && r2Valid(t) < 0.5)) return float4(0, 0, 0, 0);
    // S1 (section 8m): a water layer here (film B, rivulet R of F_prev) has taken the
    // micro caps in (water touching water merges) and takes the arriving fragments too -- the field pass adds that supply
    // to B under the same test. The white veil only exists on a dry / dropwise surface.
    uint wet = (hy >> 10) & 3u;                                     // H3-P4: hzm class (exact) -- sample only where mixed
    if (wet == 1u || hm.x > 0.5) return float4(0, 0, 0, 0);         // F6': the cell's haze became film (field adds it)
    if (wet == 2u) {
        float4 Fw = txR2Field.SampleLevel(samLinearClamp, t, 0);
        if (Fw.b * gR2FilmMaxMM + Fw.r * gR2TrailMaxMM >= gR2HazeWetMM) return float4(0, 0, 0, 0);
    }
    float2 G = max(txR2Haze.Load(int3(f, 0)).rg, 0.0) * gR2FineMaxMM;   // (fine, coarse) mm
    if (G.x + G.y > gR2HazeMinMM) {
        float sweep = 0;
        if (gR2HazeMaskMode > 0.5) {
            // T1: the union of this frame's substep sweeps (wm.hlsl) -- complete for drops faster than the 5 x 5 gather
            int2 o = f - c0 * r2HazePerCell();
            sweep = all(o < int2(4, 4)) ? r2WmGet(txR2Wm.Load(int3(c0, 0)), o.x + 4 * o.y) : 0.0;
        } else {                                                     // A/B: the legacy frame-end gather (misses long paths)
            [loop] for (int y = -2; y <= 2; ++y) {
                [loop] for (int x = -2; x <= 2; ++x) {
                    int2 s = c0 + int2(x, y);
                    if (any(s < int2(0, 0)) || any(s >= size)) continue;
                    float4 st = txR2State.Load(int3(s, 0));
                    if (st.z <= 0) continue;
                    sweep += r2SweepFrac(f, gR2HazeSize, float2(s) + st.xy, r2UnpackMove(st.w), r2RadiusMM(st.z));
                }
            }
        }
        G *= 1.0 - saturate(sweep);
        G.y = max(G.y - max(G.y - gR2HazeTopMM, 0.0) * hm.z, 0.0);   // H3-3: the cell's nucleus takes its share of the excess
    }
    // H2 HALF-RATE (docs/RAINFX_V2_H3_ATLAS_SPEC.md section 8p, 2026-11-15): the losses that other passes realise THIS frame (drop
    // sweeps = the water the cells gave those drops, the nucleus share = the cells event, S1 / F6' absorption above) apply every
    // frame; the slow layer law (supply, evaporation, coarsening tau 0.3-12 s, lamella overrun) runs on half the texels per frame
    // (checkerboard, alternating) with twice the step -- same rates, ~half the transcendental work.
    float nStep = gR2HazeHalf > 0.5 ? 2.0 : 1.0;
    // H2b (game test: wiped zones re-grew as a texel checkerboard -- while the coverage is far below saturation one step of
    // supply is a visible share, so the two parities differ): a texel still building its layer (G_f + G_c < saturation
    // depth) runs every frame; only saturated texels (the steady veil, where a step is invisible) alternate.
    bool building = G.x + G.y < gR2HazeSatMM;
    float nStep2 = building ? 1.0 : nStep;
    if (gR2HazeHalf > 0.5 && !building && (((uint)(f.x + f.y) + (uint)gR2Frame) & 1u) != 0u)
        return float4(G / max(gR2FineMaxMM, 1e-6), 0, 0);
    nStep = nStep2;
    float dt = gR2Dt * nStep;
    float kPhi = 3.14159265 / max(gR2ShapeK * gR2HazeAMM, 1e-6);
    float exposure = hm.w * gR2Exposure;                           // N3b: cell exposure (hzm)
    float cellA = gR2CellSizeMM.x * gR2CellSizeMM.y;
    float lamS = gR2SprayVisRate * exposure * cellA * gR2Dt;        // per FRAME (the cells pass realises one event per frame)
    float sup = (gR2SprayFineMMs + gR2RainHazeMMs) * exposure * dt;              // sub-visible fragments: fine caps
    // H3-3 (8g): drawn spray pieces below a_max are atlas water, not cell drops (they made the small-drop lattice), +
    // the expected large pieces of the 2nd, 3rd ... event of a cell in one frame (the cells pass realises one event)
    float supC = gR2SprayCoarseMMs * exposure * dt + nStep * max(lamS - (1.0 - exp(-lamS)), 0.0) * gR2SprayVisVolMM3 / cellA;
    // H3-3b cap law of the coarse water: its pieces ARRIVE at gR2CoarseInRMM (spray pieces < a_max, Lua) and grow once
    // they saturate the coverage (a = G_c / (G_sat / a_min)); coverage = 1 - exp(-pi G_c / (shapeK a)) up to phi_max
    float aC = max(gR2CoarseInRMM, G.y * gR2HazeAMM / max(gR2HazeSatMM, 1e-9));
    // evaporation (diffusion-limited caps: k ~ 1 / a^2)
    float aRel = aC / max(gR2HazeAMM, 1e-6);
    G.x *= exp(-gR2FineEvapK * dt);
    G.y *= exp(-gR2FineEvapK * dt / (aRel * aRel));
    // supply: onto the pieces -> G_c, onto the free surface -> G_f
    float relC = min(1.0 - exp(-3.14159265 * G.y / max(gR2ShapeK * aC, 1e-6)), gR2HazePhiMax) / max(gR2HazePhiMax, 1e-3);
    float onP = relC * gR2MicroCover;
    G.y += sup * onP + supC;
    G.x += sup * (1.0 - onP);
    // E2 coarsening
    float relF = min(1.0 - exp(-kPhi * G.x), gR2HazePhiMax) / max(gR2HazePhiMax, 1e-3);
    float dC = G.x * (1.0 - exp(-dt / max(gR2HazeCoarsenTau, 1e-3) * relF * relF));
    G.x -= dC;
    G.y += dC;
    // I1 IMPACT LAMELLA SWEEP (section 8l): every spray impact spreads to beta_max d (Roisman 2009) and gathers the fine caps
    // under it into its own deposit; the coat is overrun gR2HazeOverrun x exposure times per second (spray mm/s x lamella
    // area per mm^3 of the DSD, Lua) -> fine water becomes coarse pieces (2-36 / s at 200-240 km/h behind cars)
    float dI = G.x * (1.0 - exp(-gR2HazeOverrun * exposure * dt));
    G.x -= dI;
    G.y += dI;
    G.x = min(G.x, gR2HazeCapMM);                                   // fine runoff above twice the saturation
    G.y = min(G.y, 2.0 * gR2HazeTopMM);                             // coarse: up to twice the top octave (then cell drops)
    return float4(G / max(gR2FineMaxMM, 1e-6), 0, 0);
}
