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


// rev48-U1: water of an impact that lands on fed / sheet water, laid at once over its lamella ellipse (Vt-stretched,
// ragged soft rim) -- it joins the sheet. (Dry landings are drops: cells.hlsl. W1k-W1w field lamellae removed.)
float r2ImpactSheetDep(R2Impact im, float2 pc, float vUi, float RsI, float4 igS, out float aS, out float bS, out float shS,
                       out float2 dmS) {
    float sq = sqrt(max(igS.z, 1.0));
    aS = RsI * sq; bS = RsI / sq;
    float kw = min(1.0, 2.2 / max(aS, 1e-3));                    // the 5x5 window
    aS *= kw; bS *= kw;
    shS = gR2ShpLamShift * RsI * (igS.z - 1.0) * kw;
    dmS = (pc - im.ip) * gR2CellSizeMM;
    float2 dl = float2(dot(dmS, igS.xy) - shS, dot(dmS, float2(-igS.y, igS.x))) / float2(aS, bS);
    float dlen = length(dl);
    float2 dn = dlen > 1e-5 ? dl / dlen : float2(1, 0);
    float rag = 0.85 + 0.3 * (r2VNoise(dn * 5.1 + float(im.sk & 1023u) * 0.061) - 0.5);
    float q = dlen / max(rag, 1e-3);
    return (1.0 - smoothstep(0.9, 1.1, q)) * vUi / (3.14159265 * aS * bS * 0.75);
}

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
    float wet = r2Wet(F);
    R2TrailHit tr = r2TrailNone();   // rev47j: rivulet left this frame (centre-line depth)
    float texMM = 0.5 * (gR2CellSizeMM.x * gR2Cells.x / gR2FieldSize.x + gR2CellSizeMM.y * gR2Cells.y / gR2FieldSize.y);
    float sheetAdd = 0;                // rev48-W1: water handed to the sheet by drops on it (mm)
    float sweepG = 0;                  // H1: share of this texel swept by drops this frame (haze G taken up, r2SweepFrac)
    float2 texMM2 = gR2CellSizeMM * gR2Cells / gR2FieldSize;
    float2 pMM = pc * gR2CellSizeMM;
    // rev48-W1j IMPACT LAMELLAE (W1i review: real sheets form from impacts all over the exposed face, overlapping before
    // they vanish; round where the rain hits head-on, stretched / torn on the oblique sides). With the sheet on, the
    // unresolved rain arrives as discrete splats: each impact of the 5x5 cells (same rate as cells.hlsl, own hash) lays
    // its unresolved water uniformly over its lamella ellipse (radius Rs, aspect A along Vt, ragged rim). The total
    // rain it brings feeds the local supply estimate q (field A) that decides the fed regime (r2FedTx).
    float stampU = 0, stampQ = 0;
    bool stampOn = gR2SheetOn > 0.5 && gR2ImpactRate > 0;
    float vU = 0, vR = 0, vIS = 1;
    float4 igS = float4(1, 0, 1, 0);
    if (stampOn) {
        vU = gR2FilmRate / (gR2ImpactRate * 1e-6);                     // mm^3 per mean impact (expectation-exact)
        vR = gR2SheetResMMs / (gR2ImpactRate * 1e-6);
        igS = r2ImpactGeom(t);
        vIS = max(gR2SpeedRel * r2Exposure(t), 0.5);
    }
    [loop] for (int y = -2; y <= 2; ++y) {
        [loop] for (int x = -2; x <= 2; ++x) {
            int2 s = c0 + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            // rev48-U1: impacts of this frame (registry). All of them feed the local supply q (fed / wet regime); an impact
            // that landed on fed water lays its whole water into the sheet here (cells bears no drop for it)
            if (stampOn) {
                R2Impact im;
                float encI = txR2Lam.Load(int3(s, 0)).x;
                if (r2ImpactAt(s, encI, im) && floor(encI) - 1.0 == gR2Frame) {
                    float wD = (im.d * im.d * im.d) / max(gR2DsdM3, 1e-4);   // P1: share of the mean impact volume
                    float vUi = vU * wD, vRi = vR * wD;
                    float RsI = max(0.5 * im.d * 0.87 * pow(1000.0 * vIS * im.d, 0.2), 0.6 * gR2CellMM);
                    float aS, bS, shS; float2 dmS;
                    float dep = r2ImpactSheetDep(im, pc, vUi + vRi, RsI, igS, aS, bS, shS, dmS);
                    if (im.fed) stampU += dep;
                    float2 dl0 = float2(dot(dmS, igS.xy) - shS, dot(dmS, float2(-igS.y, igS.x))) / float2(aS, bS);
                    if (dot(dl0, dl0) <= 1.0) stampQ += (vUi + vRi) / (3.14159265 * aS * bS);
                }
            }
            float4 st = txR2State.Load(int3(s, 0));
            if (st.z <= 0) continue;
            float2 b = float2(s) + st.xy;
            if (F.g > 0) sweepG += r2SweepFrac(f, b, r2UnpackMove(st.w), r2RadiusMM(st.z));
            // rev48-W1: absorption into the sheet as the drop's own cap profile (same rule as merge.hlsl)
            if (gR2SheetOn > 0.5) {
                int2 fb = r2FieldTexelAt(b);
                float4 nm = r2SheetNucAt(s);
                float nuc = nm.r;
                float kAbs = r2SheetAbsorbFrac(st, r2Life(s), r2SheetHUnder(txR2Field, b, r2RadiusMM(st.z)), nm, r2SheetH(b / gR2Cells), r2WetTx(txR2Field, b / gR2Cells));
                if (kAbs > 0) {
                    float vA = kAbs * st.z;
                    float rr = r2RadiusMM(st.z);
                    if (nuc > 0.5) rr = r2SheetNucRMM(rr);              // rev48-W1d: bridged puddle
                    if (rr < 0.75 * min(texMM2.x, texMM2.y)) {
                        sheetAdd += all(fb == f) ? vA / (texMM2.x * texMM2.y) : 0.0;
                    } else {
                        float2 dm = pMM - b * gR2CellSizeMM;
                        float wC = sqrt(max(1.0 - dot(dm, dm) / (rr * rr), 0.0));
                        sheetAdd += vA * wC / (2.0943951 * rr * rr);      // integral of the cap weight = 2/3 pi r^2
                    }
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
                r2TrailCand(pc, s, st, wet, tr);
                float2 dirm = (b - a) * rsqrt(max(dot(b - a, b - a), 1e-12));
                if (dot(pc - b, dirm) > -0.3 * rCells)
                    coverF = max(coverF, saturate(1.0 - d / max(rCells * gR2SweepWidth, 0.25)));
            }
        }
    }

    float3 n = r2Normal(t);
    float exposureRaw = r2Exposure(t);
    float hcHere = r2SheetH(t);                    // rev48-W1i sheet threshold here (fed: sheetHFed)
    float exposure = exposureRaw * gR2Exposure;
    float T = F.r, M = F.g, W = F.b;
    // rev48-W1t: a patch that beaded this frame (bead.hlsl window of a cell within +-2 cells) gives up its F_prev water
    if (gR2SheetOn > 0.5 && W * gR2FilmMaxMM >= gR2SheetKeepMM) {
        int2 cf = int2(floor((float2(f) + 0.5) / gR2FieldSize * gR2Cells));
        [loop] for (int by = -1; by <= 1; ++by) {             // W1w: a bead takes its own 3x3 cells
            [loop] for (int bx = -1; bx <= 1; ++bx) {
                int2 sb = cf + int2(bx, by);
                if (any(sb < int2(0, 0)) || any(sb >= size)) continue;
                if (txR2Bead.Load(int3(sb, 0)).w > 0.5) W = 0;
            }
        }
    }
    // H1 HAZE G (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 17): sub-visible micro droplets on the coat, mm of water / gR2FineMaxMM.
    // Supply = the expected sub-visible stuck share of every impact (rain: weather.lua hazeMMs; spray: SP1 + the droplets
    // below the drawn size, init.lua) x exposure, + the expected water of the 2nd, 3rd ... visible spray droplet of a cell
    // in one frame (cells takes one event per frame). Loss = evaporation of the micro caps, and the water under the discs
    // that drops swept this frame (sweepG, the same r2SweepFrac the cells pass used to give it to those drops).
    // (S1b cleared the whole 1.16 mm cell of any drop -- blocky wipes.)
    {
        float gMM = F.g * gR2FineMaxMM * (1.0 - saturate(sweepG));
        float cellA = gR2CellSizeMM.x * gR2CellSizeMM.y;
        float lamS = gR2SprayVisRate * exposure * cellA * gR2Dt;
        gMM = gMM * exp(-gR2FineEvapK * gR2Dt) + (gR2SprayFineMMs + gR2RainHazeMMs) * exposure * gR2Dt
            + max(lamS - (1.0 - exp(-lamS)), 0.0) * gR2SprayVisVolMM3 / cellA;
        M = gMM / max(gR2FineMaxMM, 1e-6);
    }
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
    if (hT > gR2TrailPinMM && gT.w > 1e-4) {
        float2 tau = float2(cos(gT.z), sin(gT.z));
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
    if (hT >= gR2PearlMM && r2PearlEvent(r2TrailCell(f, gT), gT.w)) hT = 0.0;
    float trailMM = tr.depth;
    hT = max(hT, trailMM);
    T = hT / max(gR2TrailMaxMM, 1e-4);
    // ---- film W ----
    if (gR2SheetOn > 0.5) {
        // rev48-W1: the sheet pass moves the water (conservative fluxes, substeps); here only sources / sinks
        W += sheetAdd / gR2FilmMaxMM;
        // raindrops landing on sheet water (F_prev, as the cells pass sees it) or in the impact-film regime (W1g)
        // resolved raindrops: on sheet water they join it (expectation, as the cells pass suppresses their births); in the
        // fed regime the resolved share of this frame's lamellae lands as water too (cells: no births where fed)
        // W1w (rest-state simulation, docs/prototypes/rainfx2_w1v_rest_sim.py): only a CONNECTED sheet takes the resolved rain;
        // an isolated patch that did (and suppressed drop births there) grew without bound -- 12 % of the visor after 60 s
        // U1: rain on a connected sheet outside the fed regime joins it (expectation; cells bears no drop there)
        if (!r2ImpactFilm(t) && F.b * gR2FilmMaxMM >= hcHere && r2SheetConnected(r2SheetNucAt(c0)))
            W += (gR2SheetResMMs + gR2FilmRate) * exposure * gR2Dt / gR2FilmMaxMM;
        // rev48-W1c (W1b review: at rest the visor filled with dense, equal medium drops): thin film below the
        // sheet threshold is spread micro water, not a coherent patch -- rev11-47 smoothed it every frame
        // (filmDiffuse 0.6); without that each splash deposit stayed a blob, crossed the bead threshold and
        // beaded into a drop of one size (cell volume). Same smoothing again between THIN neighbours only,
        // as an antisymmetric face exchange of F_prev (conservative); the sheet itself is left to the sheet pass.
        float hI = F.b * gR2FilmMaxMM;
        if (hI < hcHere) {
            int2 fmx = int2(gR2FieldSize) - 1;
            float ex = 0;
            int2 nb[4] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1) };
            [unroll] for (int q = 0; q < 4; ++q) {
                int2 g = clamp(f + nb[q], int2(0, 0), fmx);
                float hJ = txR2Field.Load(int3(g, 0)).b * gR2FilmMaxMM;
                ex += (hJ < r2SheetHAtTexel(g) && r2Valid((float2(g) + 0.5) / gR2FieldSize) > 0.5) ? hJ - hI : 0.0;
            }
            W += 0.25 * gR2FilmDiffuse * ex / gR2FilmMaxMM;
        }
    }
    // FM1 (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 19): with the sheet off there is no film transport -- a thin film on the
    // coat is unstable and dewets where it lies (no invisible water drifting at the film speed and beading elsewhere,
    // the 'fountain' of section 16). W keeps its F_prev value here; only the crown runoff feeds it (below) and it beads in
    // place (dewet event). Films form only on the sheet path, from drops (nuc.hlsl) or overlapping lamellae (fed regime).
    // rev47j DEWETTING (rev47i review: a 0.1 mm rain film covered the visor -- and the drops -- at speed):
    // on the partially wetting visor a thin unresolved sheet is not stable; it gathers into beads. The
    // cells pass turned the film of an event cell (mean depth >= gR2FilmBeadMM) into a bead or fed it to
    // the drop there; its texels give the water up here (same hash, same F_prev mean).
    if (r2DewetEvent(c0) && r2DewetFilmOK(r2CellFilmMM(c0), c0)) W = 0;
    if (gR2SheetOn > 0.5) {
        // rev48-W1d (W1c review: medium drops of one size took over at rest): the unresolved rain is spread micro
        // water (fragments below the resolved radius), not a raindrop-sized puddle -- the 3x3 splash stamp put
        // ~0.3 mm in a texel, which became a pinned sheet blob whose rim beaded into r 0.3-0.4 mm drops. With the
        // sheet on it arrives as its expected value.
        // rev48-W1e IMPACT FILM (docs/RAINFX_V2_WATER_SHEET_PLAN.md section 7.4): no cap. Unconnected splash water
        // (h < sheetHJoin) breaks up into micro droplets at sheetThinRate (below); where the splash supply q beats
        // that (q > sheetThinRate * sheetHJoin, the lamellae of successive impacts overlap faster than they break
        // up) the water connects into a sheet and flows -- the impact-fed sheet of torrential rain at speed.
        W = max(W + stampU / gR2FilmMaxMM, 0.0);                        // W1j/W1k: discrete lamellae + recoil
    }
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
    // rev48-W1b (P1 review: thin film residues stayed as blue streaks forever with the sheet on): film too thin to be
    // a sheet or to bead (h < filmBeadMM) breaks into micro droplets / evaporates at sheetThinRate; film between
    // the bead and sheet thresholds drains as before (rev14); the sheet itself (h >= sheetHJoin) only flows.
    float hW = W * gR2FilmMaxMM;
    // W1e: unconnected water breaks up; W1f: so does an isolated patch thicker than the threshold (not a sheet)
    bool sheetHere = hW >= hcHere && r2SheetConnected(r2SheetNucAt(c0));
    // rev48-W1k (user: a shrunk lamella stays as a small sagging patch until other water takes it): an isolated patch
    // >= the threshold is a REMNANT -- it stays (slow evaporation), flows if thick, is collected by drops passing through
    // it and joins a sheet that reaches it; only unconnected water below the threshold breaks up.
    if (gR2SheetOn < 0.5) W *= exp(-gR2Dt * gR2SheetDrain);
    else if (!sheetHere) {
        // rev48-W1o (user: let the lamella shrink, thicken and stay at a fitting size): a remnant is kept when it is a
        // sheet-thick patch or a LUMP (>= sheetKeepMM and >= sheetLumpK x the mean 2 texels around: the recoiled residual);
        // an even thin film around it breaks up as micro water
        int2 fm = int2(gR2FieldSize) - 1;
        float hRing = 0.25 * (txR2Field.Load(int3(clamp(f + int2(2, 0), int2(0, 0), fm), 0)).b
                            + txR2Field.Load(int3(clamp(f - int2(2, 0), int2(0, 0), fm), 0)).b
                            + txR2Field.Load(int3(clamp(f + int2(0, 2), int2(0, 0), fm), 0)).b
                            + txR2Field.Load(int3(clamp(f - int2(0, 2), int2(0, 0), fm), 0)).b) * gR2FilmMaxMM;
        bool keep = hW >= hcHere || (hW >= gR2SheetKeepMM && hW >= gR2SheetLumpK * hRing);
        bool wetS = r2WetTx(txR2Field, t);                 // W1r: wetted surface keeps its layer
        W = (keep || wetS) ? max(W - gR2TrailEvapMMs * gR2Dt / gR2FilmMaxMM, 0.0) : W * exp(-gR2Dt * gR2SheetThinRate);
    }
    // rev21: drops sweeping through the film take it with them (and wipe the haze, M above).
    if (!sheetHere && !(gR2SheetOn > 0.5 && r2WetTx(txR2Field, t))) W *= 1.0 - coverM * gR2FilmCollect;   // W1u: drops do not wipe a wet layer   // rev22: pinned drops do not drain the film; W1g: nor a sheet
    // rev48-W1g: a rivulet inside a connected sheet is sheet water (mean depth of the parabolic section 2/3 h0)
    if (gR2SheetOn > 0.5 && sheetHere && T > 0) {
        W += 0.6667 * T * gR2TrailMaxMM / gR2FilmMaxMM;
        T = 0;
    }

    // rev48-W1j local rain supply q (mm/s): exponential average of the stamped rain over sheetFedTau (A, / sheetQMax)
    float aOut = exposureRaw;
    if (gR2SheetOn > 0.5) {
        float q = F.a * gR2SheetQMax * exp(-gR2Dt / max(gR2SheetFedTau, 1e-3))
                + (stampQ + gR2SprayFineMMs * exposure * gR2Dt) / max(gR2SheetFedTau, 1e-3);   // F1: road spray feeds the regime too
        aOut = saturate(q / gR2SheetQMax);
    }
    return float4(saturate(T), saturate(M), saturate(W), aOut);
}
