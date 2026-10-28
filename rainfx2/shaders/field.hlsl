// P2: surface field update. Target: F_next (RGBA16_UNorm), reads F_prev and S_next.
//   R = trail rivulet: centre-line water depth / gR2TrailMaxMM (rev47 T-layer; rev47j geometry in TG)
//   G = micro haze M: unresolved droplets / mist (scattering, mip blur)
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
    float wet = r2Wet(F);
    R2TrailHit tr = r2TrailNone();   // rev47j: rivulet left this frame (centre-line depth)
    float texMM = 0.5 * (gR2CellSizeMM.x * gR2Cells.x / gR2FieldSize.x + gR2CellSizeMM.y * gR2Cells.y / gR2FieldSize.y);
    [unroll] for (int y = -2; y <= 2; ++y) {
        [unroll] for (int x = -2; x <= 2; ++x) {
            int2 s = c0 + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            float4 st = txR2State.Load(int3(s, 0));
            if (st.z <= 0) continue;
            float2 b = float2(s) + st.xy;
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
    float exposure = exposureRaw * gR2Exposure;
    float uT = r2AirTangent(n);
    float T = F.r, M = F.g, W = F.b;
    M += gR2MicroRate * exposure * gR2Dt * (1.0 - M);
    M *= exp(-gR2Dt * (gR2MicroEvap + gR2MicroShear * uT * uT));
    float mWiped = M * cover * gR2MicroCollect;
    M -= mWiped;
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
    hT = max(hT, trailMM + (trailMM > 0 ? mWiped * gR2HazeDepthMM : 0.0));
    T = hT / max(gR2TrailMaxMM, 1e-4);
    // ---- film W ----
    float hPrev = W * gR2FilmMaxMM;
    float2 tb = t - r2FilmVelocity(t, hPrev) * gR2Dt;     // back-trace (field runs once per frame)
    float2 tx = 1.0 / gR2FieldSize;
    if (r2Valid(tb) > 0.5) {
        float cC = txR2Field.SampleLevel(samLinearClamp, tb, 0).b;
        float c4 = (txR2Field.SampleLevel(samLinearClamp, tb + float2(tx.x, 0), 0).b
                  + txR2Field.SampleLevel(samLinearClamp, tb - float2(tx.x, 0), 0).b
                  + txR2Field.SampleLevel(samLinearClamp, tb + float2(0, tx.y), 0).b
                  + txR2Field.SampleLevel(samLinearClamp, tb - float2(0, tx.y), 0).b) * 0.25;
        W = lerp(cC, c4, gR2FilmDiffuse);
    } else {
        W = 0;                                               // inflow from outside the mesh
    }
    // rev47j DEWETTING (rev47i review: a 0.1 mm rain film covered the visor -- and the drops -- at speed):
    // on the partially wetting visor a thin unresolved sheet is not stable; it gathers into beads. The
    // cells pass turned the film of an event cell (mean depth >= gR2FilmBeadMM) into a bead or fed it to
    // the drop there; its texels give the water up here (same hash, same F_prev mean).
    if (r2DewetEvent(c0) && r2CellFilmMM(c0) >= gR2FilmBeadMM) W = 0;
    // Supply: gR2FilmRate mm/s at full exposure, in splashes of gR2FilmSplashMM each.
    float rate = gR2FilmRate * exposure;
    if (rate > 0) {
        float lam = rate * gR2Dt / max(gR2FilmSplashMM, 1e-6);   // splashes per texel per frame
        float pHit = min(lam, 1.0);
        float dep = rate * gR2Dt / max(pHit, 1e-6);
        float add = 0;
        uint fr = (uint)gR2Frame;
        [unroll] for (int sy = -1; sy <= 1; ++sy) {
            [unroll] for (int sx = -1; sx <= 1; ++sx) {
                uint2 q = uint2(f + int2(sx, sy));
                float w = (sx == 0 ? 2.0 : 1.0) * (sy == 0 ? 2.0 : 1.0) / 16.0;
                if (r2Rand(uint3(q.x, q.y, fr * 3u + 7u)) < pHit) add += w;
            }
        }
        W += add * dep / gR2FilmMaxMM;
    }
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
    W *= exp(-gR2Dt * gR2SheetDrain);
    // rev21: drops sweeping through the film take it with them (and wipe the haze, M above).
    W *= 1.0 - coverM * gR2FilmCollect;   // rev22: pinned drops do not drain the film (rev21 T3 film 1 %)

    return float4(saturate(T), saturate(M), saturate(W), exposureRaw);
}
