// P4: visor composite on the GLASS_RAINFX copy (render.mesh, CSP mesh.fx template).
// Drawn between glass stack 'pre' (housing, COAT) and 'post' (EXT band, INT).
//
// Drops are evaluated ANALYTICALLY per screen pixel from the cell state (5x5 cells).
//
// rev4 shape (CSP rain-map model, docs/RAINFX_V2_CORE.md section 11): per-drop contour
// noise, fixed-width rim bevel, weak dome term.
//
// rev5 optics (section 12): the reference cameras are focused far away, the visor is a
// few cm from the lens -> every drop is seen through the whole entrance pupil.
// For focus at infinity the blur disc projected onto the visor equals the pupil
// diameter (gR2ApertureMM), independent of distance. A pixel therefore sees
//   colour = (1 - F) * background + F * mean(refracted rays)
// with F = fraction of the pupil footprint covered by water (disc-disc overlap) and the
// refracted rays summarised by their F-weighted mean deflection and its spread
// (spread -> blur of the refracted image). One scene fetch set per pixel.
// Deflection is physical: theta = (n-1) * slope (thin prism, n = 1.333), converted to
// screen UV with the vertical FOV. The scene is the housing-free source (source.hlsl).
// #define R2_DEPTH_ONLY 1 -> same coverage, writes depth only where water is solid.

float4 r2VisorTap(Texture2D tx, float2 t) {
    uint w = 1u, h = 1u;
    tx.GetDimensions(w, h);
    int2 p = clamp(int2(t * float2((float)w, (float)h)), int2(0, 0), int2((int)w - 1, (int)h - 1));
    return tx.Load(int3(p, 0));
}
float r2VisorRadiusMM(float v) {
    return v > 0 ? exp2(log2(v / gR2ShapeK) * (1.0 / 3.0)) : 0.0;
}
float r2VisorSeed(float w) { return floor(w / 1048576.0); }   // = r2UnpackSeed
float2 r2VisorMove(float w) {                                 // = r2UnpackMove
    float m = w - r2VisorSeed(w) * 1048576.0;
    float qx = floor(m / 1024.0);
    return (float2(qx, m - qx * 1024.0) - 500.0) / 250.0;
}
// Cubic B-spline reconstruction of the film thickness (field B) with its gradient
// (per texel). 16 Loads, no filtering artefacts at texel edges.
float r2FilmBSpline(float2 t, out float2 grad) {
    float2 p = t * gR2FieldSize - 0.5;
    float2 i0 = floor(p);
    float2 f = p - i0;
    float2 g = 1.0 - f;
    float4 wx = float4(g.x * g.x * g.x, 3.0 * f.x * f.x * f.x - 6.0 * f.x * f.x + 4.0,
                       -3.0 * f.x * f.x * f.x + 3.0 * f.x * f.x + 3.0 * f.x + 1.0, f.x * f.x * f.x) / 6.0;
    float4 wy = float4(g.y * g.y * g.y, 3.0 * f.y * f.y * f.y - 6.0 * f.y * f.y + 4.0,
                       -3.0 * f.y * f.y * f.y + 3.0 * f.y * f.y + 3.0 * f.y + 1.0, f.y * f.y * f.y) / 6.0;
    float4 dx = float4(-g.x * g.x, 3.0 * f.x * f.x - 4.0 * f.x, -3.0 * f.x * f.x + 2.0 * f.x + 1.0, f.x * f.x) * 0.5;
    float4 dy = float4(-g.y * g.y, 3.0 * f.y * f.y - 4.0 * f.y, -3.0 * f.y * f.y + 2.0 * f.y + 1.0, f.y * f.y) * 0.5;
    int2 size = int2(gR2FieldSize) - 1;
    float h = 0;
    grad = float2(0, 0);
    [unroll] for (int j = 0; j < 4; ++j) {
        float4 row;
        [unroll] for (int i = 0; i < 4; ++i) {
            int2 q = clamp(int2(i0) + int2(i - 1, j - 1), int2(0, 0), size);
            row[i] = txR2Field.Load(int3(q, 0)).b;
        }
        float rx = dot(wx, row);
        h += wy[j] * rx;
        grad.x += wy[j] * dot(dx, row);
        grad.y += dy[j] * rx;
    }
    return h;
}
float r2Lum(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
// Per-drop radial perturbation in [-1, 1] (3 harmonics, phases from the 4-bit seed).
float r2Contour(float2 dir, float seed) {
    float a = atan2(dir.y, dir.x);
    float3 ph = frac(float3(0.137, 0.611, 0.853) * (seed + 1.0) * 7.31) * 6.2832;
    return 0.55 * sin(2.0 * a + ph.x) + 0.30 * sin(3.0 * a + ph.y) + 0.15 * sin(5.0 * a + ph.z);
}
// Housing-free scene: premultiplied (rgb*w, w) mips, composited fine over coarse
// (push-pull hole fill). mip is in source (half-resolution) levels.
float3 r2Scene(float2 uv, float mip) {
    float4 a = txR2Scene.SampleLevel(samLinearClamp, uv, mip);
    float4 b = txR2Scene.SampleLevel(samLinearClamp, uv, mip + 2.5);
    float4 c = txR2Scene.SampleLevel(samLinearClamp, uv, mip + 6.0);
    float3 cc = c.a > 1e-3 ? c.rgb / c.a : gR2VeilColor;
    return a.rgb + (1.0 - a.a) * (b.rgb + (1.0 - b.a) * cc);
}

float4 main(PS_IN pin) {
    float2 t = float2(pin.Tex.x, pin.Tex.y + 1.0);
    clip(r2VisorTap(txR2Mask, t).a - 0.5);

    // Screen <-> visor-mm Jacobian (outside the loop: derivatives need uniform flow).
    float2 dtx = ddx(t), dty = ddy(t);
    float2 pxU = float2(dtx.x, dty.x) * gR2TexMM.x;     // d(mm along u)/d(px x, px y)
    float2 pxV = float2(dtx.y, dty.y) * gR2TexMM.y;
    float pixMM = sqrt(max(dot(dtx * gR2TexMM, dtx * gR2TexMM), dot(dty * gR2TexMM, dty * gR2TexMM)));
    float rb = max(0.5 * gR2ApertureMM, 0.6 * pixMM);   // pupil footprint radius on the visor

    // ---- analytic drops seen through the pupil ----
    float2 pc = t * gR2Cells;
    int2 c0 = int2(floor(pc));
    int2 size = int2(gR2Cells);
    float F = 0, S2 = 0, L = 0, G = 0;
    float2 S = float2(0, 0);
    [unroll] for (int y = -2; y <= 2; ++y) {
        [unroll] for (int x = -2; x <= 2; ++x) {
            int2 s = c0 + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            float4 st = txR2State.Load(int3(s, 0));
            if (st.z <= 0) continue;
            float r = r2VisorRadiusMM(st.z);
            float2 dmm = (pc - (float2(s) + st.xy)) * gR2CellSizeMM;
            float d = length(dmm);
            if (d > r * (1.0 + gR2ContourAmp) + rb) continue;
            float2 dirv = d > 1e-5 ? dmm / d : float2(1, 0);
            float rEff = r * (1.0 + gR2ContourAmp * r2Contour(dirv, r2VisorSeed(st.w)));
            // Pupil coverage: disc(rEff) * disc(rb) overlap / pupil area (smooth approximation).
            float lo = abs(rEff - rb), hi = rEff + rb;
            float k = saturate((hi - d) / max(hi - lo, 1e-5));
            float f = k * k * (3.0 - 2.0 * k) * min(1.0, (rEff * rEff) / (rb * rb));
            if (f <= 1e-4) continue;
            // Mean ray: profile slope at the overlap centroid (signed distance along dirv).
            float dc = 0.5 * (max(d - rb, -rEff) + min(d + rb, rEff));
            float ad = abs(dc);
            float e = min(gR2BevelMM, rEff);
            float xr = saturate((rEff - ad) / e);
            float hgt = min(r * gR2Aspect, gR2MaxHeightMM);
            float q = saturate(ad / rEff);
            float sm = hgt * 6.0 * xr * (1.0 - xr) / e + hgt * gR2DomeK * 2.0 * q / rEff;
            sm = sm / max(1.0, sm / gR2SlopeMax);
            float2 sv = -dirv * (dc < 0 ? -sm : sm);           // uphill = towards the centre
            // rev7: rays through different parts of the drop inside the footprint deflect
            // differently. Without this intra-drop spread a defocused drop sampled one far
            // point per pixel (sharp "petal" lobes). Linear-lens estimate: slope ~ kl * position,
            // variance = kl^2 * (extent_along^2 + extent_across^2) / 12.
            float sRim = min(hgt * (1.5 / e + 2.0 * gR2DomeK / rEff), gR2SlopeMax);
            float kl = sRim / rEff;
            float ext = max(min(d + rb, rEff) - max(d - rb, -rEff), 0.0);
            float lat = 2.0 * min(rb, rEff);
            F += f;
            S += f * sv;
            S2 += f * (sm * sm + kl * kl * (ext * ext + lat * lat) * (1.0 / 12.0));
            L += f * smoothstep(gR2LossStart, gR2LossEnd, sm);
            // Rims whose uphill direction points up on screen face the sky.
            float2 gs = sv.x * pxU + sv.y * pxV;
            float gl = dot(gs, gs);
            float facing = gl > 1e-20 ? saturate(dot(gs, gR2ScreenUp) * rsqrt(gl)) : 0.0;
            float f2 = facing * facing;
            G += f * f2 * f2 * smoothstep(0.5, 1.1, sm);
        }
    }
    float Fn = max(F, 1e-5);
    float cov = saturate(F);

    float4 Fd = txR2Field.SampleLevel(samLinearClamp, t, 0);

    // ---- water film (sheet W, field B): a thin refracting, scattering layer ----
    // rev13: thickness and its gradient from a cubic B-spline over 4x4 field texels.
    // rev11 used bilinear taps: the gradient of a bilinear field has creases on every
    // texel edge, and at near-eye magnification (one texel ~ 20 px) the refraction showed
    // them as a mosaic of square tiles. The B-spline is C2 (smooth refraction) and slightly
    // smoothing, like surface tension.
    float2 hG;
    float hF = r2FilmBSpline(t, hG) * gR2FilmMaxMM;
    float filmCov = smoothstep(gR2FilmMinMM, gR2FilmFullMM, hF);
    float2 fieldMM = gR2TexMM / gR2FieldSize;                      // mm per field texel (u, v)
    float2 filmSlope = hG * gR2FilmMaxMM / fieldMM * gR2FilmRefract;
    // Drops sink into a thick film: their own outline fades.
    cov *= 1.0 - gR2FilmAbsorb * filmCov;
    float haze = saturate(Fd.g * gR2HazeK + Fd.r * gR2TraceHaze) * (1.0 - cov);

#ifdef R2_DEPTH_ONLY
    clip(cov - gR2DepthCoverage);
    return float4(0, 0, 0, 0);
#else
    float aFilm = filmCov * (1.0 - cov);
    haze *= 1.0 - filmCov;
    float a = cov + aFilm + haze;
    // rev16 forward scattering (veil over the WHOLE visor area, not only where water is drawn):
    // micro haze M, the film and airborne spray scatter bright surroundings toward the eye,
    // lifting blacks and flattening contrast (reference A: p50 x1.3-1.6, detail x0.27-0.42).
    float scatterX = gR2ScatterM * sqrt(max(Fd.g - gR2ScatterM0, 0.0))    // concave: B already veiled
                   + gR2ScatterFilm * filmCov * saturate(hF / max(gR2FilmFullMM, 1e-4))
                   + gR2ScatterSpray * gR2Spray;
    float scat = min(1.0 - exp(-scatterX), gR2ScatterMax);
    clip(gR2Debug > 0.5 ? 1.0 : max(a, scat) - 0.003);

    // Mean deflection (tex-space slope) -> screen direction and angle.
    float2 sMean = S / Fn;
    float sl = length(sMean);
    float spread = sqrt(max(S2 / Fn - sl * sl, 0.0));
    float2 gs = sMean.x * pxU + sMean.y * pxV;
    float2 dir = dot(gs, gs) > 1e-20 ? normalize(gs) : float2(0, 0);
    float thetaK = 0.333 * gR2Refraction;                 // (n - 1) * user gain
    float2 sp = pin.PosH.xy * gR2InvRT;
    float aspect = gR2InvRT.x / max(gR2InvRT.y, 1e-9);    // H / W
    // Film deflection (same mapping, added to the drops' mean deflection).
    float fl = length(filmSlope);
    float2 gsF = filmSlope.x * pxU + filmSlope.y * pxV;
    float2 dirF = dot(gsF, gsF) > 1e-20 ? normalize(gsF) : float2(0, 0);
    float2 offF = dirF * (fl * thetaK * gR2FovK) * float2(aspect, 1.0);
    float filmMip = gR2FilmMip * filmCov;
    float2 suv = saturate(sp + offF + dir * (sl * thetaK * gR2FovK) * float2(aspect, 1.0));
    // Blur of the refracted image: spread of deflections inside the pupil footprint (px, full res).
    float blurPx = spread * thetaK * gR2FovK / gR2InvRT.y;
    float mip = max(gR2DropMip + log2(max(blurPx * 0.5, 1.0)), filmMip);
    float3 cDrop = r2Scene(suv, mip);
    float3 cBlur = r2Scene(sp, gR2HazeMip);
    // Tone window around the local background (keeps drops from becoming chrome/black dots).
    float l = max(r2Lum(cDrop), 1e-5);
    float lb = max(r2Lum(cBlur), 1e-5);
    float lbUp = max(lb, r2Lum(gR2VeilColor) * gR2ToneFloor);
    cDrop *= clamp(l, lb * gR2ToneMin, lbUp * gR2ToneMax) / l;
    cDrop *= 1.0 - gR2EdgeLoss * (L / Fn);
    cDrop += gR2VeilColor * (gR2Glint * G / Fn);

    float3 veil = lerp(cBlur, gR2VeilColor, gR2VeilMix);
    float3 cFilm = r2Scene(saturate(sp + offF), filmMip);
    cFilm = lerp(cFilm, veil, gR2FilmVeil * filmCov);
    // rev16: reference B/C drops are low-contrast soft discs slightly BRIGHTER than the
    // background (scattered sky light), not dark-rimmed lenses: veil the drop colour.
    cDrop = lerp(cDrop, veil, gR2DropVeil);
    float3 col = (cDrop * cov + cFilm * aFilm + veil * haze) / max(a, 1e-4);
    // Composite the scatter over everything below (alpha blending: out = src*A + dst*(1-A)).
    // Wanted: (col*a + dst*(1-a))*(1-s) + amb*s  ->  A = a + s - a*s, src = (col*a*(1-s) + amb*s) / A.
    // amb = very blurred local surroundings biased to the sky/fog light (scattering favours bright).
    float3 amb = lerp(r2Scene(sp, gR2ScatterMip), gR2VeilColor, gR2ScatterSky) * gR2ScatterGain;
    a = saturate(a);
    float aOut = a + scat - a * scat;
    col = (col * a * (1.0 - scat) + amb * scat) / max(aOut, 1e-4);
    a = aOut;
    if (gR2Debug > 4.5) {
        // Film thickness: black 0, blue thin, cyan ~0.05 mm, white >= 0.2 mm.
        float k = saturate(hF / 0.2);
        col = float3(k * k, sqrt(k), saturate(hF / 0.01)) * gR2DebugBright;
        a = 0.85;
    } else if (gR2Debug > 3.5) {
        // Physics view (sharp discs, aperture ignored). rev10: ABSOLUTE speed bins
        // (rev9 scaled to the step limit, which grows in slow motion -> always green):
        // blue pinned, green < 0.1, yellow < 0.3, orange < 0.6, red >= 0.6 m/s,
        // magenta = speed-limited by the solver step;
        // the leading half (direction of the frame's move) is brighter. Grey = trace field
        // (path swept in the last ~2 s): continuous lines = sliding, gaps = jumps.
        col = float3(0.03, 0.03, 0.03) + Fd.r * 0.45;
        a = 0.85;
        float bestD = 1e9;
        [loop] for (int py = -2; py <= 2; ++py) {
            for (int px = -2; px <= 2; ++px) {
                int2 s = c0 + int2(px, py);
                if (any(s < int2(0, 0)) || any(s >= size)) continue;
                float4 st = txR2State.Load(int3(s, 0));
                if (st.z <= 0) continue;
                float r = r2VisorRadiusMM(st.z);
                float2 dmm = (pc - (float2(s) + st.xy)) * gR2CellSizeMM;
                float d = length(dmm);
                if (d > r || d / r > bestD) continue;
                bestD = d / r;
                float2 mv = r2VisorMove(st.w) * gR2CellSizeMM;      // mm per substep
                float v = length(mv) * 1e-3 / max(gR2SimDt, 1e-5);   // m/s
                col = v < 1e-3 ? float3(0.1, 0.3, 1.0)
                    : v > 0.97 * gR2VLimit ? float3(1.0, 0.1, 1.0)
                    : v < 0.1 ? float3(0.1, 1.0, 0.2)
                    : v < 0.3 ? float3(1.0, 0.95, 0.1)
                    : v < 0.6 ? float3(1.0, 0.5, 0.05)
                    : float3(1.0, 0.1, 0.05);
                if (v >= 1e-3 && dot(dmm, mv) < 0) col *= 0.45;
                col *= 1.0 - 0.5 * smoothstep(0.8, 1.0, d / r);
            }
        }
        col *= gR2DebugBright;
    } else if (gR2Debug > 2.5) {
        // Refraction source as the drops see it (housing must be gone, filled from around).
        col = r2Scene(sp, 0.0) * gR2DebugBright;
        a = 1.0;
    } else if (gR2Debug > 1.5) {
        // Exposure of the exterior side: red = rain arrives, blue = sheltered.
        col = float3(Fd.a, 0.1, 1.0 - Fd.a) * gR2DebugBright;
        a = 0.6;
    } else if (gR2Debug > 0.5) {
        col = float3(cov, Fd.g, Fd.r) * gR2DebugBright;
        a = max(a, 0.6);
    }
    return float4(col, saturate(a));
#endif
}
