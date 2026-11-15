// P2: surface field update. Target: F_next (RGBA16_UNorm), reads F_prev and S_next.
//   R = trail rivulet: centre-line water depth / gR2TrailMaxMM (rev47 T-layer; rev47j geometry in TG)
//   G = S1 fine spray deposit: sub-visible micro droplets (70-90 um road spray) / gR2FineMaxMM, mm of water. Never drawn;
//       the cells pass turns it into real drops (absorbed by the cell's drop, or nucleated once a cell holds r >= fineNucRMM)
//   B = water film W (rev11): thickness / gR2FilmMaxMM. Semi-Lagrangian advection with
//       r2FilmVelocity, surface-tension smoothing (5-tap), stochastic 3x3 splash supply
//       (rain that does not stick as drops + spray from cars ahead), drainage.
//   A = rain exposure of the exterior side (debug view 2)
// Every texel looks at the 5x5 drop cells around it and their swept segment of
// this step (position - packed displacement -> position).


float4 main(PS_IN pin) {
    int2 f = int2(pin.PosH.xy);
    float2 t = (float2(f) + 0.5) / gR2FieldSize;
    if (r2Valid(t) < 0.5) return float4(0, 0, 0, 0);
    float4 F = txR2Field.Load(int3(f, 0));

    float2 pc = t * gR2Cells;
    int2 c0 = int2(floor(pc));
    int2 size = int2(gR2Cells);
    float cover = 0, coverM = 0;   // coverM: moving drops only (rev22 film collect)
    float coverF = 0;              // rev47h: FRONT half of moving heads (collects trail water)
    float wet = r2WetU(F, t);   // FILM-UNIFY A: one wetness
    float texMM = 0.5 * (gR2CellSizeMM.x * gR2Cells.x / gR2FieldSize.x + gR2CellSizeMM.y * gR2Cells.y / gR2FieldSize.y);
    float2 texMM2 = gR2CellSizeMM * gR2Cells / gR2FieldSize;
    float2 pMM = pc * gR2CellSizeMM;
    float filmAdd = 0.0;                                            // FILM S2-1: drops joining the film (mm here)
    [loop] for (int y = -2; y <= 2; ++y) {
        [loop] for (int x = -2; x <= 2; ++x) {
            int2 s = c0 + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            float4 st = txR2State.Load(int3(s, 0));
            if (st.z <= 0) continue;
            float2 b = float2(s) + st.xy;
            // FILM S2-1: a drop on film / at the largest cap joins the film as its own cap profile (merge removes it next
            // frame, same test); the disk stays inside the 5 x 5 window (<= 1.9 cells)
            if (r2FilmJoin(st, r2Life(s), txR2Field, b)) {
                float rr = r2FilmJoinRadiusMM(st.z);
                if (rr < 0.75 * min(texMM2.x, texMM2.y)) {
                    filmAdd += all(r2FieldTexelAt(b) == f) ? st.z / (texMM2.x * texMM2.y) : 0.0;
                } else {
                    float2 dmJ = pMM - b * gR2CellSizeMM;
                    filmAdd += st.z * sqrt(max(1.0 - dot(dmJ, dmJ) / (rr * rr), 0.0)) / (2.0943951 * rr * rr);   // cap weight integral 2/3 pi r^2
                }
            }
            float2 a = b - r2UnpackMove(st.w);
            float rCells = r2RadiusMM(st.z) / gR2CellMM;          // gR2CellMM: mean cell edge
            float d = r2SegDist(pc, a, b);
            cover = max(cover, saturate(1.0 - d / max(rCells * gR2SweepWidth, 0.25)));
            if (dot(b - a, b - a) > 4e-4) {
                coverM = max(coverM, saturate(1.0 - d / max(rCells * gR2SweepWidth, 0.25)));
                // rev45-47h trail: the REAR contact line leaves a rivulet (rev47j: shared candidate rule
                // r2TrailCand, centre-line depth over the texels near the line; the trail pass stores the
                // line geometry), and only the FRONT half of a moving head collects trail water.
                // TR0: the rivulet geometry / depth of this frame comes from TG (trail pass after every substep)
                float2 dirm = (b - a) * rsqrt(max(dot(b - a, b - a), 1e-12));
                if (dot(pc - b, dirm) > -0.3 * rCells)
                    coverF = max(coverF, saturate(1.0 - d / max(rCells * gR2SweepWidth, 0.25)));
            }
        }
    }

    float3 n = r2Normal(t);
    float exposureRaw = r2Exposure(t);
    float exposure = exposureRaw * gR2Exposure;
    float T = F.r, M = F.g, W = F.b;
    // H1c (section 25): the haze lives in its own 2x-resolution layer (haze.hlsl); field G stays 0.
    M = 0.0;
    // rev47 T-LAYER (docs/RAINFX_V2_REV46_REVIEW.md section 1): R = trail water depth / trailMaxMM.
    // rev45-46 put it into the film W, whose 5-tap diffusion (0.6 / frame) spread a one-texel trail below
    // the visible threshold in 2-3 frames. Trail water on the hydrophobic coat stays pinned: no diffusion,
    // no advection; it evaporates at a constant rate (thin trails vanish first), later drops sweep it up,
    // the cells pass beads it into small drops (pearling), and the haze it wipes joins it.
    float hT = T * gR2TrailMaxMM;
    // rev47k RIVULET FLOW (rev47j review: trails stayed forever as glass rods; the trail is water too):
    // a rivulet deeper than gR2TrailPinMM is not held by its contact lines and runs ALONG ITSELF with the
    // film law (gravity ~ h^2, air shear ~ h; r2FilmVelocity) projected on its direction, at most the
    // runback speed. Semi-Lagrangian along the stored line: the water above the pin depth slides downstream
    // and joins the head at the downstream end; a residue of the pin depth stays, beads up (pearling) into
    // a dotted row of small drops, or dries.
    float4 gT = txR2Trail.Load(int3(f, 0));
    // TR1 (docs/RAINFX_V2_TRAIL_REVIEW2.md): only a FRESH line (this frame's tail) is still a rivulet; older lines have broken
    // into bead rows (pinned caps), which do not run along the line -- flowing rivulets are sheet water (FILM-UNIFY C)
    if (hT > gR2TrailPinMM && r2TgFresh(gT)) {
        float2 tau = float2(cos(r2TgAngle(gT)), sin(r2TgAngle(gT)));
        float2 totMM = gR2CellSizeMM * gR2Cells;
        float va = dot(r2FilmVelocity(t, hT) * totMM, tau);                     // mm/s along the line
        va = clamp(va * gR2TrailFlowK, -1000.0 * gR2RunbackMax, 1000.0 * gR2RunbackMax);
        float2 tbT = t - tau * (va * gR2Dt) / totMM;
        float up = r2Valid(tbT) > 0.5 ? txR2Field.SampleLevel(samLinearClamp, tbT, 0).r * gR2TrailMaxMM : 0.0;
        // only the mobile excess above the pin depth travels; the pinned residue stays behind (a faint line
        // that later beads into a dotted row of small drops)
        hT = min(hT, gR2TrailPinMM) + max(up - gR2TrailPinMM, 0.0);
    }
    hT = max(hT - gR2TrailEvapMMs * gR2Dt, 0.0);
    hT *= 1.0 - coverF * gR2FilmCollect;
    // rev47j PEARLING (mass-conserving): the cells pass turned the rivulet section of an event cell into
    // a bead on the line; the texels whose stored centre-line point lies in that cell give the water up.
    if (hT >= gR2PearlMM && r2PearlEvent(r2TrailCell(f, gT), r2TgHw(gT))) hT = 0.0;
    // B2: mobile beads became drops (cells: F_prev depth, last frame's lines; a line of this frame is still the rivulet)
    if (!r2TgFresh(gT) && r2BeadMobile(F.r * gR2TrailMaxMM, r2TgHw(gT))) hT = 0.0;
    float trailMM = r2TgFresh(gT) ? r2TgDepth(gT) : 0.0;   // TR0: this frame's line (all substeps)
    hT = max(hT, trailMM);
    T = hT / max(gR2TrailMaxMM, 1e-4);
    // ---- film W ---- FILM S2-0 (docs/RAINFX_V2_FILM_S2_DESIGN.md section 2): the rev48-W1..W1w sheet (lamella stamps,
    // fed supply q, nucleation / connected-sheet tests, conditional absorption, thin-film decay, patch beads, sheet flow) is
    // removed. Until S2-1 the film is the pre-sheet one: crown runoff at rest, beading in place (dewet events), drainage.
    // FM1 (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 19): with the sheet off there is no film transport -- a thin film on the
    // coat is unstable and dewets where it lies (no invisible water drifting at the film speed and beading elsewhere,
    // the 'fountain' of section 16). W keeps its F_prev value here; only the crown runoff feeds it (below) and it beads in
    // place (dewet event). Films form only on the sheet path, from drops (nuc.hlsl) or overlapping lamellae (fed regime).
    // rev47j DEWETTING (rev47i review: a 0.1 mm rain film covered the visor -- and the drops -- at speed):
    // on the partially wetting visor a thin unresolved sheet is not stable; it gathers into beads. The
    // cells pass turned the film of an event cell (mean depth >= gR2FilmBeadMM) into a bead or fed it to
    // the drop there; its texels give the water up here (same hash, same F_prev mean).
    // FILM S2 (docs/RAINFX_V2_FILM_S2_DESIGN.md section 3): sources, edge retreat and caps on F_prev, then the film pass moves it.
    float nbB = txR2Field.Load(int3(min(f + int2(1, 0), int2(gR2FieldSize) - 1), 0)).b + txR2Field.Load(int3(max(f - int2(1, 0), int2(0, 0)), 0)).b
              + txR2Field.Load(int3(min(f + int2(0, 1), int2(gR2FieldSize) - 1), 0)).b + txR2Field.Load(int3(max(f - int2(0, 1), int2(0, 0)), 0)).b;
    float mobOut = 0.0;                                             // F5: body decision for the film substeps (A += 2)
    if (gR2SheetOn > 0.5 && (F.b > 0.0 || nbB > 0.0 || filmAdd > 0.0 || gR2FilmNucOn > 0.5)) {   // dry: cheap exit
        float hPrev = F.b * gR2FilmMaxMM;
        // S2-2 edge retreat / thin water joining film: r2FilmShedH of me and my 4 neighbours (gather, exact exchange) from the
        // 13-texel diamond loaded once (FXC: five texture-reading calls overflowed the /O3 compiler stack)
        float4 FE = r2FieldAt(txR2Field, f + int2(1, 0)), FW = r2FieldAt(txR2Field, f - int2(1, 0));
        float4 FN = r2FieldAt(txR2Field, f + int2(0, 1)), FS = r2FieldAt(txR2Field, f - int2(0, 1));
        float hE = FE.b * gR2FilmMaxMM, hW = FW.b * gR2FilmMaxMM, hN = FN.b * gR2FilmMaxMM, hS = FS.b * gR2FilmMaxMM;
        float hEE = r2FilmH(txR2Field, f + int2(2, 0)), hWW = r2FilmH(txR2Field, f - int2(2, 0));
        float hNN = r2FilmH(txR2Field, f + int2(0, 2)), hSS = r2FilmH(txR2Field, f - int2(0, 2));
        float hNE = r2FilmH(txR2Field, f + int2(1, 1)), hNW = r2FilmH(txR2Field, f + int2(-1, 1));
        float hSE = r2FilmH(txR2Field, f + int2(1, -1)), hSW = r2FilmH(txR2Field, f - int2(1, 1));
        float qS = (gR2FilmRate + gR2SprayFineMMs + gR2RainHazeMMs + gR2SprayCoarseMMs) * gR2Exposure;
        float invTex = 1.0 / min(texMM2.x, texMM2.y);
        float4 K = txR2SheetK.Load(int3(f, 0));
        float2 flow = r2FilmFlowTex(K, max(hPrev, 0.1));            // F5 front rule (last frame's body decision, F.a >= 2)
        // r2Nb4 order: 0 = +x, 1 = -x, 2 = +y, 3 = -y; a neighbour sends to me when its receiver points back at me
        float shedOut = r2FilmShedH(hPrev, hE, hW, hN, hS, qS, invTex, F.a >= 1.5 ? 1.0 : 0.0, flow).x * hPrev;
        float2 sE = r2FilmShedH(hE, hEE, hPrev, hNE, hSE, qS, invTex, FE.a >= 1.5 ? 1.0 : 0.0, flow);
        float2 sW = r2FilmShedH(hW, hPrev, hWW, hNW, hSW, qS, invTex, FW.a >= 1.5 ? 1.0 : 0.0, flow);
        float2 sN = r2FilmShedH(hN, hNE, hNW, hNN, hPrev, qS, invTex, FN.a >= 1.5 ? 1.0 : 0.0, flow);
        float2 sS = r2FilmShedH(hS, hSE, hSW, hPrev, hSS, qS, invTex, FS.a >= 1.5 ? 1.0 : 0.0, flow);
        float inF = (abs(sE.y - 1.0) < 0.5 ? sE.x * hE : 0.0) + (abs(sW.y - 0.0) < 0.5 ? sW.x * hW : 0.0)
                  + (abs(sN.y - 3.0) < 0.5 ? sN.x * hN : 0.0) + (abs(sS.y - 2.0) < 0.5 ? sS.x * hS : 0.0);
        // S2-2 / F3 cap: the cell's film body (alone in its 3 x 3 cells, or >= filmThickMM) became one drop (cells, same test)
        float vCap = 0.0;
        bool capC = r2FilmCapCell(c0, vCap);
        float hNew = hPrev - shedOut + inF;
        if (capC) hNew = inF;
        // S2-1 sources: drops joining (above, F1); unresolved rain and sub-visible spray / rain fragments landing on film
        // (S1: the haze pass drops them on a water layer). F2: only FILM water counts -- trail water takes its share below.
        hNew += filmAdd;
        // F6' (section 10): the cell's haze water became film this frame (hzm: same HZ_prev / F_prev test; haze pass emptied it)
        float nucX = gR2FilmNucOn > 0.5 ? txR2HzMask.Load(int3(c0, 0)).x : 0.0;
        if (nucX > 0.5) hNew += nucX - 1.0;
        if (hPrev >= gR2FilmWetMM || nucX > 0.5)
            hNew += (gR2FilmRate + gR2SprayFineMMs + gR2RainHazeMMs + gR2SprayCoarseMMs) * exposure * gR2Dt;
        W = max(hNew, 0.0) / gR2FilmMaxMM;
        // F5: one decision per body and frame on the frame-start water (F_prev), carried by the film substeps
        if (hNew >= gR2FilmWetMM && !capC && r2FilmMobileWin(txR2Field, f, K, max(hPrev, hNew))) mobOut = 1.0;
    } else if (r2DewetEvent(c0) && r2DewetFilmOK(r2CellFilmMM(c0), c0)) W = 0;
    // F2 (section 9): S1 water landing on TRAIL water (no film under it) joins the trail (the haze pass removed it there, same
    // water-layer test); 2026-11-13 game test: counted as film it grew sheets along the trails that the next drop joined.
    if (gR2SheetOn > 0.5 && F.b * gR2FilmMaxMM < gR2FilmWetMM && F.r * gR2TrailMaxMM >= gR2HazeWetMM)
        T += (gR2SprayFineMMs + gR2RainHazeMMs + gR2SprayCoarseMMs) * exposure * gR2Dt / max(gR2TrailMaxMM, 1e-4);
    // FM1: no dry-coat film supply with the sheet off (rev11 laid the SPLASHED rain share, flux x (1 - stickFrac), into W as
    // 3x3 stamps -- airborne water made into visor water). Impact water that is not a drop is haze (G) or leaves (H1 / SP1).
    // S1: the fine road spray lands as micro droplets (G above), not as film water (F9 put it into W: following a pack the
    // sliding drops swept it into thick trails / very large drops -- 2026-11-06 review)
    // rev47b CROWN RUNOFF (rev47 review: at rest the visor only saw the little rain that reaches a near-
    // vertical face): rain caught on the helmet crown drains over the top edge of the visor. A texel within
    // gR2CrownBandMM of the upper edge (one step up the surface leaves the visor) receives the crown catch
    // rain * gR2CrownMM / band (mm depth per s); the air blows the crown water back once moving (> 5-20 m/s).
    if (gR2CrownMM > 0 && gR2RainMMs > 0) {
        float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
        float3 dv = r2ToWorld(r2Tap(txR2Dv, t).xyz);
        float3 upT = float3(0, 1, 0) - n * n.y;
        float ul = length(upT);
        if (ul > 0.2) {
            float3 v = upT * (gR2CrownBandMM * 1e-3 / ul);
            float a = dot(du, du), bq = dot(du, dv), cq = dot(dv, dv);
            float det = max(a * cq - bq * bq, 1e-20);
            float2 st = float2(cq * dot(du, v) - bq * dot(dv, v), a * dot(dv, v) - bq * dot(du, v)) / det;
            if (r2Valid(t + st) < 0.5) {
                float calm = 1.0 - smoothstep(5.0, 20.0, length(gR2AirW));
                W += gR2RainMMs * gR2CrownMM / max(gR2CrownBandMM, 0.1) * calm * gR2Dt / gR2FilmMaxMM;
            }
        }
    }
    if (gR2SheetOn < 0.5) W *= exp(-gR2Dt * gR2SheetDrain);       // S2: no constant loss (drainage = transport off the visor)
    // rev21: drops sweeping through THIN water take it with them (S2: film >= wet is the drop's to join, not to collect)
    if (W * gR2FilmMaxMM < gR2FilmWetMM) W *= 1.0 - coverM * gR2FilmCollect;   // W1u: drops do not wipe a wet layer   // rev22: pinned drops do not drain the film; W1g: nor a sheet
    float aOut = exposureRaw + 2.0 * mobOut;                        // A = exposure (debug view 2) + 2 x F5 body mobile
    return float4(saturate(T), saturate(M), saturate(W), aOut);
}
