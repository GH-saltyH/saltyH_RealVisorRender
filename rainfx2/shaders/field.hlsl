// P2: surface field update. Target: F_next (RGBA16_UNorm), reads F_prev and S_next.
//   R = trace T: thin water left on the swept path (low haze, faint refraction)
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
            if (dot(b - a, b - a) > 4e-4) coverM = max(coverM, saturate(1.0 - d / max(rCells * gR2SweepWidth, 0.25)));
        }
    }

    float3 n = r2Normal(t);
    float exposureRaw = r2Exposure(t);
    float exposure = exposureRaw * gR2Exposure;
    float uT = r2AirTangent(n);
    float T = F.r, M = F.g, W = F.b;
    M += gR2MicroRate * exposure * gR2Dt * (1.0 - M);
    M *= exp(-gR2Dt * (gR2MicroEvap + gR2MicroShear * uT * uT));
    M *= 1.0 - cover * gR2MicroCollect;
    T = max(T * exp(-gR2Dt * gR2TraceDecay), cover * gR2TraceAmount);
    // ---- film W ----
    float hPrev = W * gR2FilmMaxMM;
    float2 tb = t - r2FilmVelocity(t, hPrev) * gR2Dt;     // back-trace (field runs once per frame)
    float2 tx = 1.0 / gR2FieldSize;
    if (r2Valid(tb) > 0.5) {
        float c0 = txR2Field.SampleLevel(samLinearClamp, tb, 0).b;
        float c4 = (txR2Field.SampleLevel(samLinearClamp, tb + float2(tx.x, 0), 0).b
                  + txR2Field.SampleLevel(samLinearClamp, tb - float2(tx.x, 0), 0).b
                  + txR2Field.SampleLevel(samLinearClamp, tb + float2(0, tx.y), 0).b
                  + txR2Field.SampleLevel(samLinearClamp, tb - float2(0, tx.y), 0).b) * 0.25;
        W = lerp(c0, c4, gR2FilmDiffuse);
    } else {
        W = 0;                                               // inflow from outside the mesh
    }
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
    W *= exp(-gR2Dt * gR2SheetDrain);
    // rev21: drops sweeping through the film take it with them (and wipe the haze, M above).
    W *= 1.0 - coverM * gR2FilmCollect;   // rev22: pinned drops do not drain the film (rev21 T3 film 1 %)
    return float4(saturate(T), saturate(M), saturate(W), exposureRaw);
}
