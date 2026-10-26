// P4: visor composite on the GLASS_RAINFX copy (render.mesh, CSP mesh.fx template).
// Drawn between glass stack 'pre' (housing, COAT) and 'post' (EXT band, INT).
//
// rev18 drop lens = legacy Water Field rule (docs/RAINFX_V2_WF_LENS_PLAN.md), evaluated
// ANALYTICALLY from the cell state (5x5 candidates), no stamp canvas:
//   height  per drop h = 1 - (d / (1.24 R))^2 (+ seeded ellipse, teardrop motion, wobble),
//           metaball union U = 1 - prod(1 - h)  (merging drops bridge like the WF canvas)
//   edge    silhouette at U = 0.35 (= R), anti-aliased by the signed distance in px
//   slope   s = grad(U) * R  (dimensionless, ~1.3 at the rim, 0 at the centre, linear)
//   lens    scene(uv + s * 0.69 * (H/W, 1), mip 2 + 1.5 |s|/1.5)  -> inverted, minified
//   rim     energy loss 0.75 over |s| 0.7..1.3, sky glint 0.45 facing^4 on upward rims
// rev19 (rev18 review): slope magnitude from the SURFACE gradient (isotropic: a round drop has
// a full dark ring, not side crescents where the visor is foreshortened), seeded contact-line
// ellipse, teardrop motion (rear only, speed/vMax), WF large-drop warp.
// rev20: lobes removed; contact-angle cap slope (dark ring only for steep drops, none on a wet
// surface); airflow wobble of pinned drops; dynamic 5x5 loops (compile time).
// Defocus D-C coverage = disc (x) disc: peak min(1, (R / rb)^2) -> drops larger than the blur
// stay opaque (rev18 (R/(R+rb))^2 made every defocused drop see-through).
// D-A (gR2DefocusMode 1): 4 Vogel taps over the CoC disc, each a SHARP lens; averaged
// premultiplied (= blur of the colour layer, target row 2 of the defocus plan). D-B (offscreen
// layer) is impossible on preview728: render.mesh in ExtraCanvas:update draws nothing.
// No tone window and no sky correction: the source is the real HDR frame of this draw
// (WF needed them for its LDR GeometryShot; section 6 of the plan).
// Defocus (docs/RAINFX_V2_DEFOCUS_PLAN.md, D-C): the lens is always computed SHARP; the
// camera blur only softens the edge and blurs the refracted image. Circle of confusion
// from a thin lens: c_mm = A |zf - z| / zf on the visor, c_px = c_mm / (mm per px);
// z = camera distance of this visor pixel -> near the lens (right) blurs, far (left) sharp.
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
    return (float2(qx, m - qx * 1024.0) - 500.0) / 62.5;   // rev18 fix (rev8 packing)
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
// Housing-free scene: premultiplied (rgb*w, w) mips, composited fine over coarse
// (push-pull hole fill). mip is in source (half-resolution) levels.
float3 r2Scene(float2 uv, float mip) {
    float4 a = txR2Scene.SampleLevel(samLinearClamp, uv, mip);
    float4 b = txR2Scene.SampleLevel(samLinearClamp, uv, mip + 2.5);
    float4 c = txR2Scene.SampleLevel(samLinearClamp, uv, mip + 6.0);
    float3 cc = c.a > 1e-3 ? c.rgb / c.a : gR2VeilColor;
    return a.rgb + (1.0 - a.a) * (b.rgb + (1.0 - b.a) * cc);
}

// Screen-edge handling for strong refraction (WF reaches ~0.9 screen heights): mirror the
// sample back inside and blur by the overflow instead of smearing the border pixels.
float2 r2Mirror(float2 uv, out float overflow) {
    float2 o = max(max(-uv, uv - 1.0), 0.0);
    overflow = max(o.x, o.y);
    return 1.0 - abs(1.0 - abs(uv));
}
// Value noise (WF large-drop warp).
float r2Hash2(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
float r2Noise(float2 p) {
    float2 i = floor(p), f = p - i;
    f = f * f * (3.0 - 2.0 * f);
    return lerp(lerp(r2Hash2(i), r2Hash2(i + float2(1, 0)), f.x),
                lerp(r2Hash2(i + float2(0, 1)), r2Hash2(i + float2(1, 1)), f.x), f.y);
}
// One WF kernel into the union: G = G(1-h) + grad(h) P, P = P(1-h). q in mm (already
// shape-transformed), Rk in mm. The shape transforms are I - u u^T s (symmetric), applied in
// order 1, 2, 3, so the gradient w.r.t. the true position is A1 A2 A3 grad'(q').
// RW accumulates h * (radius, sin(contact angle)) for the h-weighted drop properties.
struct R2Shape { float2 u1; float s1; float2 u2; float s2; float2 u3; float s3; };
void r2Kernel(float2 q, float Rk, float2 props, R2Shape T,
              inout float P, inout float2 G, inout float2 RW, inout float HW) {
    float ik = 1.0 / (Rk * Rk);
    float h = 1.0 - dot(q, q) * ik;
    if (h <= 0.0) return;
    float2 g = (-2.0 * ik) * q;
    g -= T.u3 * (dot(T.u3, g) * T.s3);
    g -= T.u2 * (dot(T.u2, g) * T.s2);
    g -= T.u1 * (dot(T.u1, g) * T.s1);
    G = G * (1.0 - h) + g * P;
    P *= 1.0 - h;
    RW += h * props;
    HW += h;
}

struct R2Cand { float2 q; float r; float seed; float2 m; float k; };

// Candidate drop of cell s (false = empty or out of reach). reachMM widens the test for D-A taps.
bool r2Cand(int2 s, float2 pc, int2 size, float reachMM, out R2Cand c) {
    c = (R2Cand)0;
    if (any(s < int2(0, 0)) || any(s >= size)) return false;
    float4 st = txR2State.Load(int3(s, 0));
    if (st.z <= 0) return false;
    c.r = max(r2VisorRadiusMM(st.z), gR2MinDrawMM);
    c.q = (pc - (float2(s) + st.xy)) * gR2CellSizeMM;
    float reach = 1.3 * gR2KernelScale * c.r + reachMM;     // stretch/wobble margin
    if (dot(c.q, c.q) > reach * reach) return false;
    c.seed = r2VisorSeed(st.w);
    float2 mv = r2VisorMove(st.w) * gR2CellSizeMM;            // mm in the last frame
    float ml = length(mv);
    c.m = ml > 1e-4 ? mv / ml : float2(0, 0);
    float v = ml * 1e-3 / max(gR2SimDt, 1e-5);                 // m/s
    c.k = gR2MotionStretch * saturate(v / max(gR2VMax, 1e-3));
    return true;
}

// Per-pixel airflow context for the wobble (rev20): unit air direction in visor mm (u, v) and
// the tangential air speed at the surface (m/s).
struct R2Air { float2 dir; float u2; };

// One drop into the union at offset q (mm from its centre).
// rev20: lobes removed (C0 kernel edges drew a drop inside the drop, user rev19 review).
void r2AddDrop(float2 q, R2Cand c, R2Air air, float wetFlat,
               inout float P, inout float2 G, inout float2 RW, inout float HW) {
    float h1 = frac(c.seed * 0.7548776662 + 0.31);
    float h2 = frac(c.seed * 0.6180339887 + 0.17);
    R2Shape T;
    // Pinned contact line: seeded ellipse 1..1.22, any orientation (no two drops alike).
    float ang = h2 * 3.14159265;
    T.u1 = float2(cos(ang), sin(ang));
    float e1 = 0.22 * h1;
    T.s1 = e1 / (1.0 + e1);
    q -= T.u1 * (dot(q, T.u1) * T.s1);
    // Sliding: the rear half stretches (teardrop), the front stays round. k grows with v/vMax.
    T.u2 = c.m;
    float a = dot(q, c.m);
    T.s2 = a < 0.0 ? c.k / (1.0 + c.k) : 0.0;
    q -= c.m * (a * T.s2);
    // Wobble (rev20): a pinned drop in strong airflow rocks and squashes along the air before it
    // would tear off. Amplitude ~ drag / pinning (Fa/Fpin = C r u^2), two incommensurate tones.
    float ratio = gR2WobbleC * c.r * air.u2;
    float A = gR2WobbleAmp * smoothstep(0.1, 0.8, ratio);
    float w = 6.2831853 * gR2WobbleHz * (0.8 + 0.4 * h1) * gR2Time;
    float ph = c.seed * 2.39996 + h2 * 6.2831853;
    T.u3 = air.dir;
    T.s3 = A * (0.65 * sin(w + ph) + 0.35 * sin(1.73 * w + 2.0 * ph));
    q -= air.dir * (A * 0.3 * c.r * sin(w + ph + 1.0));        // rocking (translation)
    q -= T.u3 * (dot(q, T.u3) * T.s3);
    // Contact angle (rev20): impact-deposited drops settle near the RECEDING angle; per-drop
    // spread (surface heterogeneity), the sliding rear recedes further, a wet surface flattens.
    float th = gR2ContactDeg + gR2ContactSpread * (2.0 * h2 - 1.0);
    th -= gR2Hysteresis * (a < 0.0 ? saturate(c.k / max(gR2MotionStretch, 1e-3)) : 0.0);
    th *= 1.0 - wetFlat;
    float sth = sin(radians(clamp(th, 5.0, 89.0)));
    r2Kernel(q, gR2KernelScale * c.r, float2(c.r, sth), T, P, G, RW, HW);
}

// WF lens colour and coverage of the union (U, G per mm, R mm) seen at screen point spT.
float3 r2DropLens(float U, float2 G, float Rmm, float sth, float2 pxU, float2 pxV, float pixMM, float2 spT,
                  float2 offF, float minMip, float2 warp, float bandPx, float cocPx, float cocMipK,
                  float aspect, out float cov) {
    cov = 0.0;
    if (U <= 1e-4) return float3(0, 0, 0);
    float2 gs = G.x * pxU + G.y * pxV;                         // per px
    float gl = length(gs);
    float sd = (U - gR2Threshold) / max(gl, 1e-6);             // signed distance, px
    float e = saturate(sd / bandPx + 0.5);
    if (e <= 0.0) return float3(0, 0, 0);
    cov = e * e * (3.0 - 2.0 * e);
    // Surface slope (isotropic). The WF parabola gives rho = |grad U| R / 1.3 = radial fraction;
    // rev20 maps it onto a spherical cap of contact angle theta: s = rho sin / sqrt(1 - rho^2 sin^2)
    // (rim slope = tan(theta)). 90 deg -> wide dark ring, 55 deg -> thin ring, < 35 deg -> none.
    float rho = saturate(length(G) * Rmm * (1.24 * 1.24 / 2.0));
    float rs = rho * sth;
    float sl = min(rs / sqrt(max(1.0 - rs * rs, 0.04)), 5.0);
    float2 slope = gl > 1e-9 ? gs * (sl / gl) : float2(0, 0);  // screen direction, toward the centre
    float Rpx = Rmm / pixMM;
    float largeW = smoothstep(gR2LargeStartPx, max(gR2LargeFullPx, gR2LargeStartPx + 0.5), Rpx);
    float over;
    float2 suv = r2Mirror(spT + offF + slope * gR2WFRefraction * float2(aspect, 1.0)
                          + warp * (2.0 * gR2LargeWarpPx * largeW) * gR2InvRT, over);
    float magn = gR2WFRefraction * 1.3 / max(Rpx * gR2InvRT.y, 1e-6);   // scene px per output px
    float mip = gR2WFSceneMip + gR2WFSlopeMip * saturate(sl / 1.5) + gR2LargeBlurMip * largeW
              + cocMipK * 0.5 * log2(1.0 + 0.35 * cocPx * magn) + 4.0 * saturate(over * 4.0);
    float3 c = r2Scene(suv, max(mip, minMip));
    c *= 1.0 - gR2EdgeLoss * smoothstep(gR2LossStart, gR2LossEnd, sl);
    float facing = sl > 1e-4 ? saturate(dot(slope / sl, gR2ScreenUp)) : 0.0;
    float f2 = facing * facing;
    c += gR2VeilColor * (gR2Glint * f2 * f2 * smoothstep(0.5, 1.1, sl));
    return c;
}

float4 main(PS_IN pin) {
    float2 t = float2(pin.Tex.x, pin.Tex.y + 1.0);
    clip(r2VisorTap(txR2Mask, t).a - 0.5);

    // Screen <-> visor-mm Jacobian (outside the loop: derivatives need uniform flow).
    float2 dtx = ddx(t), dty = ddy(t);
    float2 pxU = float2(dtx.x, dty.x) * gR2TexMM.x;     // d(mm along u)/d(px x, px y)
    float2 pxV = float2(dtx.y, dty.y) * gR2TexMM.y;
    float pixMM = max(sqrt(max(dot(dtx * gR2TexMM, dtx * gR2TexMM), dot(dty * gR2TexMM, dty * gR2TexMM))), 1e-5);

    // Camera distance of this visor point -> circle of confusion (thin lens, focus gR2FocusM).
    float3 posW = mul(float4(pin.PosL, 1.0), gR2ObjToWorld).xyz;
    float z = length(posW - gR2CamPos);
    float cocMM = gR2ApertureMM * abs(gR2FocusM - z) / max(gR2FocusM, 1e-3);
    float cocPx = cocMM / pixMM;

    float2 sp = pin.PosH.xy * gR2InvRT;
    float aspect = gR2InvRT.x / max(gR2InvRT.y, 1e-9);    // H / W
    float4 Fd = txR2Field.SampleLevel(samLinearClamp, t, 0);

    // ---- water film (sheet W, field B): a thin refracting, scattering layer ----
    // rev13: thickness and its gradient from a cubic B-spline over 4x4 field texels (C2, no
    // texel-edge creases -> no mosaic at near-eye magnification).
    float2 hG;
    float hF = r2FilmBSpline(t, hG) * gR2FilmMaxMM;
    float filmCov = smoothstep(gR2FilmMinMM, gR2FilmFullMM, hF);
    float2 fieldMM = gR2TexMM / gR2FieldSize;                      // mm per field texel (u, v)
    float2 filmSlope = hG * gR2FilmMaxMM / fieldMM * gR2FilmRefract;
    float thetaK = 0.333;                                          // film: physical thin-prism rule
    float fl = length(filmSlope);
    float2 gsF = filmSlope.x * pxU + filmSlope.y * pxV;
    float2 dirF = dot(gsF, gsF) > 1e-20 ? normalize(gsF) : float2(0, 0);
    float2 offF = dirF * (fl * thetaK * gR2FovK) * float2(aspect, 1.0);
    float filmMip = gR2FilmMip * filmCov;

    // ---- analytic WF drops: metaball union of dome kernels (5x5 candidates) ----
    float2 pc = t * gR2Cells;
    int2 c0 = int2(floor(pc));
    int2 size = int2(gR2Cells);
    bool multi = gR2DefocusMode > 0.5 && cocPx > 1.0;          // D-A only where it blurs
    float rbPx = 0.5 * cocPx;
    float2 oT[4], dqT[4];
    float rot = 6.2831853 * frac(52.9829189 * frac(dot(pin.PosH.xy, float2(0.06711056, 0.00583715)))
                                 + gR2FrameNoise * 0.6180339887);
    [unroll] for (int i = 0; i < 4; ++i) {
        float an = i * 2.39996323 + rot;
        oT[i] = float2(cos(an), sin(an)) * (sqrt((i + 0.5) * 0.25) * rbPx);
        dqT[i] = float2(dot(pxU, oT[i]), dot(pxV, oT[i]));
    }
    float P = 1.0, HW = 0.0;
    float2 G = float2(0, 0), RW = float2(0, 0);
    float Pm[4] = { 1.0, 1.0, 1.0, 1.0 };
    float2 RWm[4] = { float2(0, 0), float2(0, 0), float2(0, 0), float2(0, 0) };
    float HWm[4] = { 0.0, 0.0, 0.0, 0.0 };
    float2 Gm[4] = { float2(0, 0), float2(0, 0), float2(0, 0), float2(0, 0) };
    float reachMM = multi ? rbPx * pixMM : 0.0;
    // Airflow in visor-mm coordinates for the wobble: surface tangents dP/du_mm, dP/dv_mm from
    // the screen Jacobian (J = [pxU; pxV], mm per px) and the world-position derivatives.
    float3 dPdx = ddx(posW), dPdy = ddy(posW);
    float detJ = pxU.x * pxV.y - pxU.y * pxV.x;
    float idet = abs(detJ) > 1e-12 ? 1.0 / detJ : 0.0;
    float3 Tu = (dPdx * pxV.y - dPdy * pxV.x) * idet;
    float3 Tv = (dPdy * pxU.x - dPdx * pxU.y) * idet;
    float3 nW = cross(Tu, Tv);
    nW = dot(nW, nW) > 1e-20 ? normalize(nW) : float3(0, 0, 1);
    float3 airT = (gR2AirW - nW * dot(gR2AirW, nW)) * gR2AirSurface;
    float2 aMM = float2(dot(airT, Tu) / max(dot(Tu, Tu), 1e-20), dot(airT, Tv) / max(dot(Tv, Tv), 1e-20));
    R2Air air;
    air.dir = dot(aMM, aMM) > 1e-20 ? normalize(aMM) : float2(1, 0);
    air.u2 = dot(airT, airT);
    // A wet surface (film / micro haze) lowers the effective contact angle: edges melt in (ref. A).
    float wetFlat = gR2WetFlatten * saturate(filmCov + 2.0 * Fd.g);
    // rev20: dynamic loops (rev19 unrolled 25 x (1 + 4 taps) x lobes: minutes of FXC and a long
    // first-use stall in game). Only the 4 D-A taps are unrolled (static register arrays).
    [loop] for (int y = -2; y <= 2; ++y) {
        [loop] for (int x = -2; x <= 2; ++x) {
            R2Cand c;
            if (!r2Cand(c0 + int2(x, y), pc, size, reachMM, c)) continue;
            [branch] if (multi) {
                [unroll] for (int k = 0; k < 4; ++k) r2AddDrop(c.q + dqT[k], c, air, wetFlat, Pm[k], Gm[k], RWm[k], HWm[k]);
            } else {
                r2AddDrop(c.q, c, air, wetFlat, P, G, RW, HW);
            }
        }
    }
    float U = 1.0 - P;
    float Rmm = RW.x / max(HW, 1e-6);
    float sth = RW.y / max(HW, 1e-6);
    // WF large-drop warp: irregular interior image in drop-sized cells (surface mm).
    float2 wc = pc * gR2CellSizeMM / max(0.6 * (multi ? 1.0 : max(Rmm, 0.2)), 1e-3);
    float2 warp = float2(r2Noise(wc), r2Noise(wc + 17.31)) - 0.5;
    float cov;
    float3 cDrop;
    [branch] if (multi) {
        // D-A: sharp lenses at 4 points of the CoC disc, premultiplied average.
        float ca = 0.0;
        float3 cc = float3(0, 0, 0);
        [unroll] for (int k = 0; k < 4; ++k) {
            float ck;
            float Rk = RWm[k].x / max(HWm[k], 1e-6);
            float sk = RWm[k].y / max(HWm[k], 1e-6);
            float3 col = r2DropLens(1.0 - Pm[k], Gm[k], Rk, sk, pxU, pxV, pixMM, sp + oT[k] * gR2InvRT,
                                    offF, filmMip, warp, 1.5, cocPx, 0.5, aspect, ck);
            ca += ck;
            cc += col * ck;
        }
        cov = ca * 0.25;
        cDrop = cc / max(ca, 1e-4);
    } else {
        // D-C: sharp lens, edge = disc (x) disc of the CoC, peak min(1, (R / rb)^2).
        cDrop = r2DropLens(U, G, Rmm, sth, pxU, pxV, pixMM, sp, offF, filmMip, warp,
                           max(1.5, cocPx), cocPx, 1.0, aspect, cov);
        float rb = 0.5 * cocMM;
        float peak = rb > 1e-4 ? saturate(Rmm * Rmm / (rb * rb)) : 1.0;
        cov *= peak;
    }
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
    // rev16/17 forward scattering of the VISOR SURFACE (micro haze M, film; spray 0).
    float scatterX = gR2ScatterM * sqrt(max(Fd.g - gR2ScatterM0, 0.0))
                   + gR2ScatterFilm * filmCov * saturate(hF / max(gR2FilmFullMM, 1e-4))
                   + gR2ScatterSpray * gR2Spray;
    float scat = min(1.0 - exp(-scatterX), gR2ScatterMax);
    clip(gR2Debug > 0.5 ? 1.0 : max(a, scat) - 0.003);

    float3 cBlur = r2Scene(sp, gR2HazeMip);
    float3 veil = lerp(cBlur, gR2VeilColor, gR2VeilMix);
    float3 cFilm = r2Scene(saturate(sp + offF), filmMip);
    cFilm = lerp(cFilm, veil, gR2FilmVeil * filmCov);
    float3 col = (cDrop * cov + cFilm * aFilm + veil * haze) / max(a, 1e-4);
    // Composite the scatter over everything below (alpha blending: out = src*A + dst*(1-A)).
    // Wanted: (col*a + dst*(1-a))*(1-s) + amb*s  ->  A = a + s - a*s, src = (col*a*(1-s) + amb*s) / A.
    float3 amb = lerp(r2Scene(sp, gR2ScatterMip), gR2VeilColor, gR2ScatterSky) * gR2ScatterGain;
    a = saturate(a);
    float aOut = a + scat - a * scat;
    col = (col * a * (1.0 - scat) + amb * scat) / max(aOut, 1e-4);
    a = aOut;
    if (gR2Debug > 5.5) {
        // Defocus: R = camera distance (0..15 cm), G = CoC px (0..40), B = drop silhouette.
        col = float3(saturate(z / 0.15), saturate(cocPx / 40.0), cov) * gR2DebugBright;
        a = 0.85;
    } else if (gR2Debug > 4.5) {
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
        col = float3(cov, Fd.g, Fd.r) * gR2DebugBright;   // R = drop coverage (sharp lens edge)
        a = max(a, 0.6);
    }
    return float4(col, saturate(a));
#endif
}
