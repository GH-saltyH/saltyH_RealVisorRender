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
// ellipse, teardrop motion (rear only, speed/vMax).
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
// rev48-P1 = common r2DsdDiam (impacting-diameter inverse CDF)
float r2VDsdDiam(float u) {
    float q[16] = { gR2DQ0, gR2DQ1, gR2DQ2, gR2DQ3, gR2DQ4, gR2DQ5, gR2DQ6, gR2DQ7,
                    gR2DQ8, gR2DQ9, gR2DQ10, gR2DQ11, gR2DQ12, gR2DQ13, gR2DQ14, gR2DQ15 };
    float x = (1.0 - pow(saturate(1.0 - u), 1.0 / 3.0)) * 15.0;
    int i = min((int)x, 14);
    return lerp(q[i], q[i + 1], saturate(x - (float)i));
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
            float4 fq = txR2Field.Load(int3(q, 0));
            row[i] = fq.b;   // rev47j: film only (rivulets are drawn as lens kernels, r2TrailBest)
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
// V3 (2026-11-15): coarse mips (>= 2.5: the half-resolution frame at <= 1/6) are read with a cubic B-spline (4 bilinear taps per
// level, Sigg & Hadwiger 2005; both levels of a fractional mip). Bilinear on a 12 x 7 texel mip spread a bright light into a
// texel-aligned square pyramid that jumped a whole texel (~130 px) as the camera moved (game test: the green board in the
// white veil scatter = straight-edged blocks stepping with the view). The B-spline is C2: round, continuous falloff.
float4 r2BSplineLevel(float2 uv, float lev) {
    uint w = 1u, h = 1u, n = 1u;
    txR2Scene.GetDimensions((uint)lev, w, h, n);
    float2 size = float2((float)w, (float)h);
    float2 p = uv * size - 0.5;
    float2 fl = floor(p);
    float2 f = p - fl;
    float2 f2 = f * f, f3 = f2 * f;
    float2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
    float2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
    float2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
    float2 w3 = f3 / 6.0;
    float2 g0 = w0 + w1, g1 = w2 + w3;
    float2 t0 = (fl - 0.5 + w1 / max(g0, 1e-6)) / size;          // texel centres: (i + 0.5) / size
    float2 t1 = (fl + 1.5 + w3 / max(g1, 1e-6)) / size;
    return g0.y * (g0.x * txR2Scene.SampleLevel(samLinearClamp, float2(t0.x, t0.y), lev)
                 + g1.x * txR2Scene.SampleLevel(samLinearClamp, float2(t1.x, t0.y), lev))
         + g1.y * (g0.x * txR2Scene.SampleLevel(samLinearClamp, float2(t0.x, t1.y), lev)
                 + g1.x * txR2Scene.SampleLevel(samLinearClamp, float2(t1.x, t1.y), lev));
}
float4 r2SceneTap(float2 uv, float mip, bool smooth) {
    float4 r = float4(0, 0, 0, 0);
    if (!smooth || gR2SceneBicubic < 0.5 || mip < 2.5) {
        r = txR2Scene.SampleLevel(samLinearClamp, uv, mip);
    } else {
        uint w = 1u, h = 1u, n = 1u;
        txR2Scene.GetDimensions(0u, w, h, n);
        float top = (float)n - 1.0;
        float l0 = min(floor(mip), top);
        float k = mip - floor(mip);
        r = r2BSplineLevel(uv, l0);
        if (k > 0.02 && l0 < top) r = lerp(r, r2BSplineLevel(uv, l0 + 1.0), k);
    }
    return r;
}
// V3b (game: +0.17 ms draw with every read smoothed): only the wide light spreads (scatter veil, V2 blur) use the B-spline;
// drop lenses, micro lenses and the film keep bilinear (their mips are fine or the area is a lens image anyway).
float3 r2SceneS(float2 uv, float mip, bool smooth) {
    float4 a = r2SceneTap(uv, mip, smooth);
    float3 r = a.rgb;
    if (a.a < 0.999) {                                            // V3: the hole fill only where the fine level has holes
        float4 b = r2SceneTap(uv, mip + 2.5, smooth);
        float4 c = txR2Scene.SampleLevel(samLinearClamp, uv, mip + 6.0);   // ~1-2 texels: flat
        float3 cc = c.a > 1e-3 ? c.rgb / c.a : gR2VeilColor;
        r = a.rgb + (1.0 - a.a) * (b.rgb + (1.0 - b.a) * cc);
    }
    return r;
}
float3 r2Scene(float2 uv, float mip) { return r2SceneS(uv, mip, false); }

// Value noise (sheet edge angle / impact rag).
// rev33: integer hash. frac(sin(x) * 43758) with x ~ 1e5 (visor mm / 0.6 R) loses precision on GPUs and
// gives a pixel-scale hatch.
float r2Hash2(float2 p) {
    uint2 q = uint2(int2(p) + 65536);
    uint h = q.x * 747796405u + q.y * 2891336453u;
    h = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u;
    h = (h >> 22u) ^ h;
    return float(h & 0x00ffffffu) / 16777216.0;
}
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
// rev40 P3 gravity flattening (docs/RAINFX_V2_DROP_SHAPE_RESEARCH.md): h = 1 - (1-b) x - b x^2,
// x = d^2 / Rk^2. b = 0 is the WF dome; b > 0 flattens the top and steepens the rim (large drops,
// Bond number (r / 2.7 mm)^2 -> 0.3-0.6), so the lens interior bends less and the rim band narrows.
// rev48-S1 contour harmonics H = (a2, a3, a3 phase): the kernel radius is modulated by
// 1 + a2 cos 2psi + a3 cos 3(psi - phase), psi measured from the drop's major axis hu (a2 > 0.2 pinches a
// peanut waist across it, a3 > 0.1 gives a Y / triangle). No atan2: multiple-angle polynomials.
// rev48-S2d ASYMMETRIC CAP AS = (apex direction xy, strength k): the shading height is h (1 - k d),
// d = q.a / Rk -- the same footprint (coverage uses h), but the apex sits off-centre toward -a: a real
// drop on an inclined, hysteretic surface is thicker downhill and thinner uphill, and every drop's
// pinning history differs (S2c review: 'all drops are the same dome with the same shading').
// rev48-U2 SPLAT LAMELLA SP = (rim share rho, finger amplitude, downstream dir xy): a spreading lamella is a thin flat
// sheet bounded by a thick rim (Roisman 2009; reference frames: bright flat interior, dark crisp outline). The
// profile blends the dome toward the rim torus 6.75 x^2 (1 - x) (x = r^2 / R^2, peak 1 at r = 0.82 R, 0 at the
// centre and the edge); the downstream rim of an oblique impact is torn into fingers (Rayleigh-Taylor of the rim,
// Thoroddsen; ~8 per circumference), weak upstream. Both fade with the recoil (rho, fk ~ spread).
void r2Kernel(float2 q, float Rk, float2 props, float beta, R2Shape T, float3 H, float2 hu, float3 AS, float4 SP,
              inout float P, inout float2 G, inout float2 RW, inout float HW) {
    float dR = 1.0;
    if (abs(H.x) + H.y > 1e-3) {
        float2 qq = q * rsqrt(max(dot(q, q), 1e-12));
        float ca = dot(qq, hu), sa = qq.y * hu.x - qq.x * hu.y;
        float c2 = ca * ca - sa * sa;
        float c3 = ca * (4.0 * ca * ca - 3.0), s3 = sa * (3.0 - 4.0 * sa * sa);
        dR = max(1.0 + H.x * c2 + H.y * (c3 * cos(H.z) + s3 * sin(H.z)), 0.3);
    }
    if (SP.y > 1e-3) {
        float2 qq = q * rsqrt(max(dot(q, q), 1e-12));
        float cd = dot(qq, SP.zw);
        float psi = atan2(qq.x * SP.w - qq.y * SP.z, cd);
        float fg = saturate(cos(8.0 * psi + H.z));
        dR *= 1.0 + SP.y * fg * fg * fg * saturate(0.25 + 0.75 * cd);
    }
    float ik = 1.0 / (Rk * Rk * dR * dR);
    float x = dot(q, q) * ik;
    float h = 1.0 - (1.0 - beta) * x - beta * x * x;
    if (h <= 0.0) return;
    float2 g = (-2.0 * ik * (1.0 - beta + 2.0 * beta * x)) * q;
    if (SP.x > 1e-3) {
        float hr = 6.75 * x * x * (1.0 - x);
        float2 gr = (13.5 * ik * x * (2.0 - 3.0 * x)) * q;
        h = lerp(h, hr, SP.x);
        g = lerp(g, gr, SP.x);
    }
    if (AS.z > 1e-3) {
        float d = dot(q, AS.xy) / max(Rk * dR, 1e-5);
        g = g * (1.0 - AS.z * d) - AS.xy * (h * AS.z / max(Rk * dR, 1e-5));
    }
    g -= T.u3 * (dot(T.u3, g) * T.s3);
    g -= T.u2 * (dot(T.u2, g) * T.s2);
    g -= T.u1 * (dot(T.u1, g) * T.s1);
    G = G * (1.0 - h) + g * P;
    P *= 1.0 - h;
    RW += h * props;
    HW += h;
}

// Per-pixel airflow context for the wobble (rev20): unit air direction in visor mm (u, v) and
// the tangential air speed at the surface (m/s).
struct R2Air { float2 dir; float u2; float2 gdir; float2 iDir; float iA; };   // U2: impact Vt direction, Vt / Vn

// One drop into the union at offset q (mm from its centre).
// rev20: lobes removed (C0 kernel edges drew a drop inside the drop, user rev19 review).
void r2AddDrop(float2 q, R2Cand c, R2Air air, float wetFlat,
               inout float P, inout float2 G, inout float2 RW, inout float HW) {
    float h1 = frac(c.seed * 0.7548776662 + 0.31);
    float h2 = frac(c.seed * 0.6180339887 + 0.17);
    R2Shape T;
    // rev48-S1 contact-line shape state (cells pass): area-preserving ellipse of aspect A along phi, bent
    // across its major axis, contour harmonics in the kernel. rev20-47: seeded ellipse 1..1.22 (kept when the
    // shape state is off).
    float shE = length(c.sh.xy);
    float shA = min(sqrt((0.5 + shE) / max(0.5 - shE, 0.05)), c.aMax);
    float2 hm = r2UnpackHarm(c.sh.z);
    float sphi = 0.5 * atan2(c.sh.y, c.sh.x);
    float bendS = r2UnpackBF(c.sh.w).x;
    // rev48-U2a LAMELLA LOOK (U2 review: 'the drop's own shape magnified, then shrunk' -- S2' amplified the drop's
    // contour modes x (1 + 2 fx) -> kidney / peanut splats): the spreading lamella is its OWN shape -- an ellipse
    // along the impact Vt (aspect = r2ImpactGeom z), torn only at the downstream rim (fingers, r2Kernel) -- and
    // morphs into the drop's arrested shape as it recoils: the footprint quadratic forms blend by e = exp(-age/tau)
    // (Q = (1-e) Q_drop + e Q_lamella, one ellipse, no axis flip), the drop's contour modes / bend fade in by (1-e).
    if (c.e > 1e-3 && gR2ShpOn > 0.5) {
        q += air.iDir * (c.sft * min(1.0 + air.iA, 2.0));   // U2: lamella centred on the impact point
        float AL = min(1.0 + gR2ShpImpactK * air.iA, gR2ShpImpactMax);
        float2 u = float2(cos(sphi), sin(sphi));
        float2 d = air.iDir;
        float wD = 1.0 - c.e;
        // Q = sum w (uu^T / A + vv^T A), v = perp(u): xx, yy, xy entries
        float qa = wD * (u.x * u.x / shA + u.y * u.y * shA) + c.e * (d.x * d.x / AL + d.y * d.y * AL);
        float qc = wD * (u.y * u.y / shA + u.x * u.x * shA) + c.e * (d.y * d.y / AL + d.x * d.x * AL);
        float qb = wD * (u.x * u.y * (1.0 / shA - shA)) + c.e * (d.x * d.y * (1.0 / AL - AL));
        float qm = 0.5 * (qa + qc), qd = sqrt(0.25 * (qa - qc) * (qa - qc) + qb * qb);
        shA = min(min(sqrt((qm + qd) / max(qm - qd, 1e-6)), 4.0), c.aMax);
        sphi = 0.5 * atan2(-2.0 * qb, qc - qa);             // axis of the smaller eigenvalue = major axis
        hm *= wD;
        bendS *= wD;
    }
    float rk0 = gR2KernelScale * c.r;
    float rkS = rk0;
    float3 H = float3(0, 0, 0);
    if (gR2ShpOn > 0.5) {
        T.u1 = float2(cos(sphi), sin(sphi));
        T.s1 = 1.0 - 1.0 / shA;
        rkS = rk0 / sqrt(shA);
        // bend: the major-axis ends move across by bend x minor half-length (parabola along the axis)
        float2 vv = float2(-T.u1.y, T.u1.x);
        float aa = dot(q, T.u1) / max(rk0 * sqrt(shA), 1e-4);
        // rev48-S6b: a turning slide is a HOOK -- only the head half (mode 1: +u1 end, 2: -u1 end) bends
        float bmd = r2UnpackBMode(c.sh.w);
        float ah = bmd < 0.5 ? aa : (bmd < 1.5 ? max(aa, 0.0) : max(-aa, 0.0));
        q -= vv * (bendS * rkS * ah * ah);
        q -= T.u1 * (dot(q, T.u1) * T.s1);
        H = float3(hm.x, hm.y, 3.0 * (r2UnpackHarmPh(c.sh.z) - sphi));   // R5b: stored lobe angle (defects), fixed on the visor
                                                         // (a merge / turn rotates the axis -> the lobes no longer spin with it)
    } else {
        float ang = h2 * 3.14159265;
        T.u1 = float2(cos(ang), sin(ang));
        float e1 = 0.22 * h1;
        T.s1 = e1 / (1.0 + e1);
        q -= T.u1 * (dot(q, T.u1) * T.s1);
    }
    // Sliding: the rear half stretches (teardrop), the front stays round. k grows with v/vMax.
    // rev24 gravity sag (user: the drop is thick toward the force, thin tail behind): a pinned
    // drop of Bond number ~ (r / 1.5 mm)^2 stretches against gravity; a sliding one along its motion.
    float kSag = gR2SagK * saturate(c.r * c.r / 2.25) * (1.0 - c.e);   // U2a: a lamella does not sag / stretch
    bool slide = c.k > kSag;
    T.u2 = slide ? c.m : air.gdir;
    float kk = slide ? c.k : kSag;
    float a = dot(q, T.u2);
    // rev48-S6c E8 neck: a fresh split piece is still drawn toward its parent (its rear stretched to the old
    // tail), retracting over shpNeckT -- the tail necks and beads up instead of a piece popping out
    if (c.ch >= 0.0 && c.ch < gR2ShpNeckT) {
        T.u2 = -c.nk;
        kk = max(kk, gR2ShpNeckK * (1.0 - c.ch / max(gR2ShpNeckT, 1e-3)));
        a = dot(q, T.u2);
    }
    T.s2 = a < 0.0 ? kk / (1.0 + kk) : 0.0;
    q -= T.u2 * (a * T.s2);
    // Wobble (rev20): a pinned drop in strong airflow rocks and squashes along the air before it
    // would tear off. Amplitude ~ drag / pinning (Fa/Fpin = C r u^2), two incommensurate tones.
    float ratio = gR2WobbleC * c.r * air.u2;
    float A = gR2LookLab > 0.5 ? 0.0 : gR2WobbleAmp * smoothstep(0.1, 0.8, ratio);
    float w = 6.2831853 * gR2WobbleHz * (0.8 + 0.4 * h1) * gR2Time;
    float ph = c.seed * 2.39996 + h2 * 6.2831853;
    T.u3 = air.dir;
    T.s3 = A * (0.65 * sin(w + ph) + 0.35 * sin(1.73 * w + 2.0 * ph));
    q -= air.dir * (A * 0.3 * c.r * sin(w + ph + 1.0));        // rocking (translation)
    q -= T.u3 * (dot(q, T.u3) * T.s3);
    // Contact angle (rev20): impact-deposited drops settle near the RECEDING angle; per-drop
    // spread (surface heterogeneity), the sliding rear recedes further, a wet surface flattens.
    float th = gR2ContactDeg;                                   // R5b: per-drop variation = its flatness f (local pinning)
    th -= gR2Hysteresis * (a < 0.0 ? saturate(c.k / max(gR2MotionStretch, 1e-3)) : 0.0);
    th *= 1.0 - wetFlat;
    // rev48-S2' splat: a spreading lamella is a thin sheet with its mass in a thick RIM (reference: bright flat
    // interior, dark crisp outline). S2'a: rim angle theta / f^1.5 (rev S2' f^3 flattened the rim away too)
    // and a flat-top profile (beta -> 0.85) so the interior stays flat while the edge refracts.
    th /= c.f * sqrt(c.f);
    float sth = sin(radians(clamp(th, 4.0, 89.0)));
    float beta = 0.85 * saturate(c.f - 1.0);                    // C-clean: rev40 flatK (off since rev41) removed
    // rev48-S2d apex offset: downhill (gravity) for large drops, a per-drop direction for small ones
    // R5b: the small drop's thick side = its strongest contour lobe (defect phase), not a seed direction
    float phL = r2UnpackHarmPh(c.sh.z);
    float2 rd = float2(cos(phL), sin(phL));
    float2 ad = lerp(rd, air.gdir, saturate(c.r * c.r / max(gR2AsymGravR * gR2AsymGravR, 1e-4)));
    // rev48-S4: a sliding drop is a HEAD -- thick at the front, thinning into its tail (teardrop stretch)
    if (dot(c.m, c.m) > 0.5) {
        float km = saturate(c.k / max(gR2MotionStretch, 1e-3));
        ad = lerp(ad, c.m, km);
        // rev48-S6 F2: in a turn the advancing front is compressed on the OUTER side (S6b: the hooked head tip
        // sits on the inner side +vv sign(bend)) -> the thick apex moves to the outer front
        float bnd = gR2ShpOn > 0.5 ? r2UnpackBF(c.sh.w).x : 0.0;
        ad -= float2(-T.u1.y, T.u1.x) * (sign(bnd) * min(gR2ShpFrontK * abs(bnd), 1.5) * km);
    }
    ad = dot(ad, ad) > 1e-6 ? normalize(ad) : float2(0, 1);
    float3 AS = float3(-ad, gR2AsymK * (0.35 + 0.65 * saturate(r2UnpackHarm(c.sh.z).y / 0.1)));   // R5b: lobe strength
    float4 SP = float4(0, 0, 0, 0);
    if (c.fx > 1e-3) SP = float4(min(gR2ShpRimK, 0.85) * saturate(c.fx), gR2ShpFingerK * saturate(c.fx) * (0.3 + 0.7 * saturate(0.5 * air.iA)), air.iDir);
    r2Kernel(q, rkS, float2(rkS / gR2KernelScale, sth), beta, T, H, T.u1, AS, SP, P, G, RW, HW);
}

// PERF-9: candidate from the drop record (rec.hlsl). Same acceptance as r2Cand (bounds, loop, rev48 reach + reachMM);
// early = beyond the record's early-out radius (+ D-A widening): no contribution, no marker -> skipped after one load.
bool r2CandRec(int2 s, float2 pc, int2 size, float reachMM, bool bigPass, bool tight, out R2Cand c, out bool early) {
    c = (R2Cand)0; early = false;
    if (any(s < int2(0, 0)) || any(s >= size)) return false;
    float4 R0 = txR2Rec.Load(int3(s, 0));
    if (R0.z == 0.0 || (R0.z < 0.0) != bigPass) return false;
    c.q = (pc - R0.xy) * gR2CellSizeMM;
    float qq = dot(c.q, c.q);
    float reach = (abs(R0.z) - 1.0) + reachMM;
    if (qq > reach * reach) return false;
    float wE = (R0.w + 1.5 * reachMM) * 1.002;
    early = tight && qq > wE * wE;
    if (early && gR2TightReach < 1.5) return true;           // caller skips; verify (2) loads the rest and draws it
    float4 R1 = txR2Rec.Load(int3(s + int2(size.x, 0), 0));
    float4 R3 = txR2Rec.Load(int3(s + int2(3 * size.x, 0), 0));
    float4 R4 = txR2Rec.Load(int3(s + int2(4 * size.x, 0), 0));
    float4 R5 = txR2Rec.Load(int3(s + int2(5 * size.x, 0), 0));
    c.sh = txR2Rec.Load(int3(s + int2(2 * size.x, 0), 0));
    c.r = R1.x; c.k = R1.y; c.f = R1.z; c.fx = R1.w;
    c.m = R3.xy; c.seed = R3.z; c.ch = R3.w;
    c.e = R4.x; c.sft = R4.y; c.aMax = R4.z; c.imp = R4.w;
    c.nk = R5.xy;
    return true;
}

// PERF-7 support bound with this pixel's wobble amplitude (= r2AddDrop's A); r2SupportCore in cand.hlsl
float r2SupportMM(R2Cand c, R2Air air, float reachMM) {
    return r2SupportCore(c, gR2LookLab > 0.5 ? 0.0 : gR2WobbleAmp * smoothstep(0.1, 0.8, gR2WobbleC * c.r * air.u2), reachMM);
}

// rev47j RIVULET KERNEL (rev47i review + reference frames: a sliding large drop leaves a thin, sharp,
// long-lived line, about a quarter of the drop width). The field R holds the centre-line depth h0, the
// trail texture TG the line itself (point, direction, half-width hw). Among the 3 x 3 field texels around
// the pixel the line closest to the pixel is drawn as a cylindrical lens of half-width hw whose edge angle
// follows the water: tan(theta) = 2 h0 / hw (parabolic section) -- the same lens and union as the drops,
// so the head and its tail join (teardrop with a tail) and a thinning trail flattens out of sight.
// TR1 / TR2b / TR3 (docs/RAINFX_V2_TRAIL_REVIEW2.md, FILM-UNIFY B): a FRESH line (tagged this frame, r2TgFresh) is the head's
// tail -> the rivulet lens above; an older line has broken into a Rayleigh-Plateau ROW OF BEADS (its edge angle <= 24 deg is
// below theta_r(wet), so it dewets within ~1 ms): bead spacing 9 hw, cap radius from spacing x section (r2BeadRow, ~0.3 x the
// head that laid it, so the rows carry the size spread of the heads), jitter +-30 % spacing, 0.75-1.2 size, +-0.3 hw across.
// Positions are fixed in visor mm along the line (phase = p . tau / spacing, key = the line's offset across itself), so
// every texel holding the same line draws the same beads. Water = field R (evaporates, collected by drops, S1 / sheet).
struct R2Trail { float2 q; float2 tau; float hw; float sth; bool fresh; float h0; float al; float off; float key; };
bool r2TrailBest(float2 pc, out R2Trail tr) {
    tr.q = float2(0, 0); tr.tau = float2(1, 0); tr.hw = 0; tr.sth = 0; tr.fresh = true; tr.h0 = 0; tr.al = 0; tr.off = 0; tr.key = 0;
    float2 ft = pc / gR2Cells * gR2FieldSize;
    int2 f0 = int2(floor(ft));
    int2 fmax = int2(gR2FieldSize) - 1;
    float2 pMM = pc * gR2CellSizeMM;
    float2 texMM = gR2CellSizeMM * gR2Cells / gR2FieldSize;
    float best = 0.0;
    [loop] for (int j = -1; j <= 1; ++j) {
        [loop] for (int i = -1; i <= 1; ++i) {
            int2 f = clamp(f0 + int2(i, j), int2(0, 0), fmax);
            float h0 = txR2Field.Load(int3(f, 0)).r * gR2TrailMaxMM;
            if (h0 < gR2TrailMinMM) continue;
            float4 g = txR2Trail.Load(int3(f, 0));
            float hw = r2TgHw(g);
            if (g.w <= 1e-4 || hw <= 1e-4) continue;
            bool fresh = r2TgFresh(g);
            float2 Q = (float2(f) + 0.5) * texMM + g.xy;
            float ang = r2TgAngle(g);
            float2 tau = float2(cos(ang), sin(ang));
            float2 dv = pMM - Q;
            float al = dot(dv, tau);
            if (abs(al) > 1.2 * max(texMM.x, texMM.y)) continue;   // a line is valid near its own texel
            float2 dp = dv - tau * al;
            float Rk = gR2KernelScale * hw * (fresh ? 1.0 : 1.9);   // beads reach ~1.4 hw + jitter
            float k = 1.0 - dot(dp, dp) / (Rk * Rk);
            if (k <= best) continue;
            best = k;
            tr.q = dp;
            tr.tau = tau;
            tr.hw = hw;
            tr.fresh = fresh;
            tr.h0 = h0;
            float2 nrm = float2(-tau.y, tau.x);
            tr.al = dot(pMM, tau);                                   // along the line, global (same for every texel)
            tr.off = dot(dp, nrm);                                   // pixel offset across the line
            tr.key = dot(Q, nrm);                                    // the line's own offset across itself
            float tn = min(2.0 * h0 / hw, 1.0) * smoothstep(gR2TrailMinMM, gR2TrailFullMM, h0);
            tr.sth = tn * rsqrt(1.0 + tn * tn);
        }
    }
    return best > 0.0;
}
// The rivulet (fresh) or its bead row into the union at an extra offset dq (mm, D-A taps).
void r2AddTrail(R2Trail tr, float2 dq, inout float P, inout float2 G, inout float2 RW, inout float HW) {
    R2Shape T;
    T.u1 = float2(1, 0); T.s1 = 0; T.u2 = float2(1, 0); T.s2 = 0; T.u3 = float2(1, 0); T.s3 = 0;
    if (tr.fresh) {
        float2 q = tr.q + (dq - tr.tau * dot(dq, tr.tau));
        r2Kernel(q, gR2KernelScale * tr.hw, float2(tr.hw, tr.sth), 0.0, T, float3(0, 0, 0), float2(1, 0), float3(0, 0, 0), float4(0, 0, 0, 0), P, G, RW, HW);
        return;
    }
    float2 row = r2BeadRow(tr.hw, tr.h0);
    float lam = max(row.x, 1e-3);
    float2 nrm = float2(-tr.tau.y, tr.tau.x);
    float al = tr.al + dot(dq, tr.tau);
    float off = tr.off + dot(dq, nrm);
    float keyF = round(tr.key * 8.0) + 4099.0 * round(atan2(tr.tau.y, tr.tau.x) * 32.0);   // integer line key (r2Hash2 is integer)
    float sthB = sin(radians(clamp(gR2ContactDeg, 4.0, 89.0)));
    int n0 = (int)floor(al / lam);
    [unroll] for (int k = -1; k <= 1; ++k) {
        int n = n0 + k;
        float2 hs = float2((float)n, keyF);
        float jA = r2Hash2(hs) - 0.5, jL = r2Hash2(hs + float2(300000.0, 0.0)) - 0.5, jS = r2Hash2(hs + float2(600000.0, 0.0));
        float rb = row.y * lerp(0.75, 1.2, jS);
        if (rb < 0.02) continue;
        float2 q = tr.tau * (al - ((float)n + 0.5 + 0.6 * jA) * lam) + nrm * (off - 0.6 * jL * tr.hw);
        r2Kernel(q, gR2KernelScale * rb, float2(rb, sthB), 0.0, T, float3(0, 0, 0), float2(1, 0), float3(0, 0, 0), float4(0, 0, 0, 0), P, G, RW, HW);
    }
}

// rev24 view context for the physical lens: eye ray, outward visor normal, world vectors of one mm
// along u / v, camera basis with the screen-axis signs (derived from ddx/ddy of the eye ray, so
// the sign conventions of cameraSide / cameraUp do not matter).
struct R2View { float3 V; float3 n; float3 Tu; float3 Tv; float3 side; float3 up; float3 look; float2 sgn; };
float2 r2Proj(float3 D, R2View w) {          // tangent-plane coordinates of a direction
    float lo = max(dot(D, w.look), 1e-3);
    return float2(dot(D, w.side), dot(D, w.up)) / lo;
}

// rev24 drop lens = physical PLANO-CONVEX lens (user rev23 review; offline
// docs/prototypes/rainfx2_planoconvex_compare.py vs reference 물방울형태및흐름). The eye ray enters
// the water through the flat contact face (parallel to the visor) and leaves through the curved
// cap, whose normal is the visor normal tilted by the cap slope: nD = normalize(n - s * d_up).
//   Vw = refract(V, -n, 1/1.333),  Vo = refract(Vw, -nD, 1.333)  (TIR -> back into the car: dark)
// The screen image is read where Vo points (tangent-plane projection relative to V); directions
// off screen / behind the camera read a sky / ground environment by world height. Because every
// drop sits on a differently oriented part of the visor, the dark (TIR / ground) crescent falls on
// a different side per location -- what the reference shows. No symmetric rim terms.
// rev25 (rev24 review: hard TIR edge + low mip -> moire stripes and DLSS flicker on large / close /
// overlapping drops; small drops washed out): no early returns (uniform flow, so the sample footprint
// can be measured with ddx/ddy), smooth TIR band from the refraction discriminant, mip from the
// actual footprint of the refracted lookup, coverage band that keeps small drops solid.
float3 r2DropLens(float U, float2 G, float Rmm, float sth, float2 pxU, float2 pxV, float pixMM, float2 spT,
                  float2 offF, float minMip, float bandPx, float cocPx, float cocMipK,
                  float aspect, R2View w, out float cov) {
    float2 gs = G.x * pxU + G.y * pxV;                         // per px
    float gl = length(gs);
    float sd = (U - gR2Threshold) / max(gl, 1e-6);             // signed distance, px
    float Rpx = Rmm / pixMM;
    // small drops: the AA band never exceeds a third of the radius (solid core down to ~1.5 px)
    float band = min(bandPx, max(0.75, 0.35 * Rpx));
    float e = U > 1e-4 ? saturate(sd / band + 0.5) : 0.0;
    cov = e * e * (3.0 - 2.0 * e);
    // rev31 lens mode 0 = legacy Water Field rule (user: P0 / pre-v2 drops are closer to the
    // reference than the physical (rev24-27) and CSP (rev28-29) lenses). Exactly rev18/19 r2DropLens.
    float3 cRes;
    {   // C-clean (2026-11-04): the rev28 CSP cell shading (lensMode 1, not adopted rev31) is removed
        // rev34 WF lens, SURFACE-BASED projection (user: refract the scene per drop from its own surface).
        // Each drop is a spherical cap (contact angle theta) on the visor at this point: cap normal
        // N = visor normal (interpolated NormalW) tilted toward the centre by the cap slope, which is
        // ~0 inside and rises steeply only at the rim (tan theta at the contact line) -> the strong
        // curl of real drops (crescent), not the linear WF parabola (half-moon image). The eye ray
        // enters through the flat contact face and leaves through the cap (physical, n = 1.333);
        // the screen offset is that deflection projected with the real camera, scaled per zone:
        //   interior x (wfRefraction / wfRimRefraction), rim + small drops x 1 (physical).
        // Rays that leave the screen or turn back read the environment cubemap in their direction;
        // total internal reflection reads the dim car interior (exits through the contact face).
        // rev43 PLANO-CONVEX LENS, one image (user rev42 review + recording rev42_2중상...: the drop showed
        // a small inverted image in the centre laid over a large blurred background image and an
        // environment cubemap at the rim -- three sources that never belong to the same scene).
        // Now every point of the drop is ONE physical ray: enter the flat contact face (visor side),
        // leave through the spherical cap (contact angle theta, n = 1.333), and read the scene where
        // that exit direction points (scene at infinity, the housing-free refraction source). The rim
        // bends hard and the centre spreads gently by the refraction law alone; one strength slider
        // (gR2LensPhys, 1 = physical). Directions outside the frame are compressed CONTINUOUSLY toward
        // the frame edge (same image, no second source); total internal reflection dims that same
        // image (light comes back from the car interior). docs/RAINFX_V2_CORE.md section 55.
        float rho = saturate(length(G) * Rmm * (1.24 * 1.24 / 2.0));   // radial fraction d / R
        // rev44: the optional low-poly cap (rev42-43) is removed (user: the angular look came from the
        // drop resolution itself; seeded polygons read artificial).
        float rs = rho * sth;
        float capS = min(rs / sqrt(max(1.0 - rs * rs, 0.02)), 7.0);     // tan of the cap surface angle
        float3 dUp = G.x * w.Tu + G.y * w.Tv;                          // toward the centre (world)
        dUp = dUp - w.n * dot(dUp, w.n);
        dUp = dot(dUp, dUp) > 1e-30 ? normalize(dUp) : float3(0, 0, 0);
        float3 N = normalize(w.n - capS * dUp);                         // outward cap normal
        float3 Vw = refract(w.V, -w.n, 1.0 / 1.333);
        float ci = dot(Vw, N);
        float kd = 1.0 - 1.333 * 1.333 * (1.0 - ci * ci);
        float3 Vp = normalize(1.333 * Vw + (sqrt(max(kd, 0.0)) - 1.333 * ci) * N);
        float tir = smoothstep(0.04, -0.04, kd);
        float3 Vo = normalize(lerp(w.V, Vp, gR2LensPhys));
        // exit direction -> screen position of that direction (relative to this pixel's own direction)
        float2 dpx = (r2Proj(Vo, w) - r2Proj(w.V, w)) * w.sgn * gR2FovK;   // screen heights
        float lo = dot(Vo, w.look);
        float2 uvA = spT + offF + dpx * float2(aspect, 1.0) - 0.5;      // centred screen coords
        if (lo < 0.05) uvA = (spT - 0.5) + normalize(dpx * float2(aspect, 1.0) + 1e-6) * 4.0;   // turned back
        // continuous soft compression into the frame: identity in the middle, asymptote 0.49
        float2 xa = abs(uvA) / 0.49;
        float2 cmp = uvA / sqrt(sqrt(1.0 + xa * xa * xa * xa));
        float squeeze = saturate(1.0 - length(cmp) / max(length(uvA), 1e-6));
        float2 uvW = cmp + 0.5;
        float2 fxW = ddx_fine(uvW) / gR2InvRT, fyW = ddy_fine(uvW) / gR2InvRT;
        float mipFW = 0.5 * log2(max(max(dot(fxW, fxW), dot(fyW, fyW)), 1.0));
        float mipW = clamp(gR2WFSceneMip + max(mipFW - 1.0, 0.0)
                     + cocMipK * 0.5 * log2(1.0 + 0.35 * cocPx * 0.9 / max(Rpx * gR2InvRT.y, 1e-6)), minMip, 7.0);
        float3 cW = r2Scene(saturate(uvW), mipW);
        cW *= lerp(1.0, 0.35, tir);       // TIR: same image, dimmed (rev44: fixed, the slider had no visible effect)
        // Fresnel sky highlight on the part of the cap facing world-up (reflection, not a second image)
        float up = saturate(dot(-dUp, float3(0, 1, 0)));
        cW += gR2VeilColor * (gR2Glint * up * up * up * up * smoothstep(0.8, 2.0, capS) * (1.0 - tir));
        if (gR2Debug > 8.5) {
            // Debug 9: where each lens point looks. R = deflected DOWN, G = deflected UP (world).
            // A real drop is an inverting lens: its upper part looks down (red top, green bottom).
            float dv = dot(Vo - w.V, float3(0, 1, 0));
            cW = float3(saturate(-dv * 6.0), saturate(dv * 6.0), tir);
        } else if (gR2Debug > 6.5) cW = float3(rho, squeeze * 4.0, max(tir, saturate(mipW / 7.0) * 0.5));
        cRes = cW;
    }
    return cRes;
}

// rev48-P4 SHEET SURFACE (docs/RAINFX_V2_WATER_SHEET_PLAN.md sections 2.3, 2.4, 9). Visual surface state of the real sheet
// (its water is in field B): wind waves and the impact crater / capillary ring / agitation. Hash = common.hlsl r2Rand.
uint r2VPcg(uint v) {
    uint s = v * 747796405u + 2891336453u;
    uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
    return (w >> 22u) ^ w;
}
float r2VRand(uint3 k) {
    uint h = r2VPcg(k.x ^ r2VPcg(k.y ^ r2VPcg(k.z)));
    return float(h & 0x00ffffffu) / 16777216.0;
}

float4 main(PS_IN pin) {
    float2 t = float2(pin.Tex.x, pin.Tex.y + 1.0);
    clip(r2VisorTap(txR2Mask, t).a - 0.5);

    // Screen <-> visor-mm Jacobian (outside the loop: derivatives need uniform flow).
    // rev32: FINE derivatives. Coarse ddx is constant per 2x2 quad: the screen<->surface Jacobian then
    // steps from quad to quad, and so do the signed edge distance and slope direction -> a 2 px
    // checker / hatch exactly in the steep rim band (seen with every lens method, DLSS on or off).
    float2 dtx = ddx_fine(t), dty = ddy_fine(t);
    float2 pxU = float2(dtx.x, dty.x) * gR2TexMM.x;     // d(mm along u)/d(px x, px y)
    float2 pxV = float2(dtx.y, dty.y) * gR2TexMM.y;
    float pixMM = max(sqrt(max(dot(dtx * gR2TexMM, dtx * gR2TexMM), dot(dty * gR2TexMM, dty * gR2TexMM))), 1e-5);

    // Camera distance of this visor point -> circle of confusion (thin lens, focus gR2FocusM).
    float3 posW = mul(float4(pin.PosL, 1.0), gR2ObjToWorld).xyz;
    float z = length(posW - gR2CamPos);
    float cocMM = gR2ApertureMM * abs(gR2FocusM - z) / max(gR2FocusM, 1e-3);
    float cocPx = gR2LookLab > 0.5 ? 0.0 : cocMM / pixMM;   // rev23 look lab: no defocus

    float2 sp = pin.PosH.xy * gR2InvRT;
    float aspect = gR2InvRT.x / max(gR2InvRT.y, 1e-9);    // H / W
    float4 Fd = txR2Field.SampleLevel(samLinearClamp, t, 0);
    // rev48-S2c local wetness (haze + film + trail water) for the per-drop resting spread
    float wetV = saturate(Fd.g * gR2WetHaze + (Fd.b * gR2FilmMaxMM + Fd.r * gR2TrailMaxMM) / max(gR2FilmFullMM, 1e-4));

    // ---- water film (sheet W, field B): a thin refracting, scattering layer ----
    // rev13: thickness and its gradient from a cubic B-spline over 4x4 field texels (C2, no
    // texel-edge creases -> no mosaic at near-eye magnification).
    float2 hG;
    float hF = r2FilmBSpline(t, hG) * gR2FilmMaxMM;
    // rev47i (rev47h review: lowering the film threshold drew a thin blurring sheet over the whole visor):
    // the film W keeps its own threshold; the trail layer (field R) has a lower one of its own, so thin
    // rivulets show without making the thin rain film visible everywhere.
    // rev47j: rivulets left the film path (lens kernels below); the film W only shows as a real sheet
    // (thicker than the dewetting beads, gR2FilmMinMM) -- the thin rain film gathers into drops.
    float filmCov = gR2LookLab > 0.5 ? 0.0 : smoothstep(gR2FilmMinMM, gR2FilmFullMM, hF);
    float2 fieldMM = gR2TexMM / gR2FieldSize;                      // mm per field texel (u, v)
    float2 filmSlope = hG * gR2FilmMaxMM / fieldMM * gR2FilmRefract * (gR2LookLab > 0.5 ? 0.0 : 1.0);
    float thetaK = 0.333;                                          // film: physical thin-prism rule
    float fl = length(filmSlope);
    float2 gsF = filmSlope.x * pxU + filmSlope.y * pxV;
    float2 dirF = dot(gsF, gsF) > 1e-20 ? normalize(gsF) : float2(0, 0);
    float2 offF = dirF * (fl * thetaK * gR2FovK) * float2(aspect, 1.0);
    // rev46 (rev45 review: trails look milky; legacy RAINFX_TRAIL_REFRACTION.md T2/T5 solved the same):
    // water does not blur -- sharp base mip, extra blur only with the slope (curvature); thin water is
    // clear, only thick (aerated) sheets get the veil / scatter.
    float filmMip = filmCov * (gR2FilmMip + min(0.6 * fl, 2.0));
    float thickK = smoothstep(0.15, 0.4, hF);

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
        // rev21: taps over 0.75 rb, each with a soft edge of 0.5 CoC (rev20 review: wobbling drops
        // turned into flakes with 4 sharp taps). Disc (x) disc split between taps and edge band.
        oT[i] = float2(cos(an), sin(an)) * (sqrt((i + 0.5) * 0.25) * 0.75 * rbPx);
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
    float3 dPdx = ddx_fine(posW), dPdy = ddy_fine(posW);
    float detJ = pxU.x * pxV.y - pxU.y * pxV.x;
    float idet = abs(detJ) > 1e-12 ? 1.0 / detJ : 0.0;
    float3 Tu = (dPdx * pxV.y - dPdy * pxV.x) * idet;
    float3 Tv = (dPdy * pxU.x - dPdx * pxU.y) * idet;
    float3 nW = cross(Tu, Tv);
    nW = dot(nW, nW) > 1e-20 ? normalize(nW) : float3(0, 0, 1);
    R2View vw;
    vw.V = normalize(posW - gR2CamPos);
    // rev26: interpolated vertex normal (smooth); cross(ddx, ddy) of the position is flat per triangle
    // and put seams into large drops crossing triangle edges.
    float3 nS = normalize(pin.NormalW);
    vw.n = dot(nS, vw.V) < 0.0 ? -nS : nS;                    // outward = away from the eye
    vw.Tv = Tv / max(length(Tv), 1e-12);
    vw.Tu = Tu / max(length(Tu), 1e-12);                       // unit world directions of +u / +v mm
    vw.side = gR2CamSide; vw.up = gR2CamUp; vw.look = gR2CamLook;
    float3 dVx = ddx_fine(vw.V), dVy = ddy_fine(vw.V);
    vw.sgn = float2(dot(dVx, vw.side) >= 0.0 ? 1.0 : -1.0, dot(dVy, vw.up) >= 0.0 ? 1.0 : -1.0);
    float3 airT = (gR2AirW - nW * dot(gR2AirW, nW)) * gR2AirSurface;
    float2 aMM = float2(dot(airT, Tu) / max(dot(Tu, Tu), 1e-20), dot(airT, Tv) / max(dot(Tv, Tv), 1e-20));
    R2Air air;
    air.dir = dot(aMM, aMM) > 1e-20 ? normalize(aMM) : float2(1, 0);
    air.u2 = dot(airT, airT);
    float3 gT = gR2AccelW - nW * dot(gR2AccelW, nW);
    float2 gMM = float2(dot(gT, Tu) / max(dot(Tu, Tu), 1e-20), dot(gT, Tv) / max(dot(Tv, Tv), 1e-20));
    air.gdir = dot(gMM, gMM) > 1e-20 ? normalize(gMM) : float2(0, 1);
    {   // rev48-U2: tangential impact direction / obliquity (= common r2ImpactGeom, per pixel)
        float3 rdA = gR2RainDirW - nW * dot(gR2RainDirW, nW);
        float2 uA2 = float2(dot(rdA, Tu) / max(dot(Tu, Tu), 1e-20), dot(rdA, Tv) / max(dot(Tv, Tv), 1e-20));
        air.iDir = dot(uA2, uA2) > 1e-20 ? normalize(uA2) : air.gdir;
        air.iA = length(rdA) / max(abs(dot(gR2RainDirW, nW)), 0.05);
    }
    // FILM S2-0 (docs/RAINFX_V2_FILM_S2_DESIGN.md): the rev48-P2..P4 sheet lens (contour / meniscus / ridge / waves / impact
    // craters) is removed; S2-3 draws the new film. Until then the film W uses the rev11-47 overlay below.
    float covS = 0.0;
    float2 sImpD = float2(0, 0);
    // A wet surface (film / micro haze) lowers the effective contact angle: edges melt in (ref. A).
    float wetFlat = gR2LookLab > 0.5 ? 0.0 : gR2WetFlatten * saturate(filmCov + 1.3333 * gR2WetHaze * Fd.g);   // H1: wetHaze 0 (micro caps are no film)
    // rev20: dynamic loops (rev19 unrolled 25 x (1 + 4 taps) x lobes: minutes of FXC and a long
    // first-use stall in game). Only the 4 D-A taps are unrolled (static register arrays).
    // rev48-R7a: ONE candidate loop (FXC failed silently with a second r2AddDrop site x 4 unrolled D-A taps): indices
    // 0-24 = the 5 x 5 cells, 25-33 = the big-drop winners of the 3 x 3 tiles around (window +-4 cells).
    // rev29 CSP mode: no cell lens (no candidates).
    // PERF-6 cost probe (diagnostics only, gR2PerfProbe 0 = off): 1 = stop after the per-pixel setup (mask, Jacobian, film
    // B-spline, view frame), 2 = stop after the candidate / kernel union (no lens / composite). Draw-time differences
    // between 0 / 1 / 2 split the visor cost into setup | candidates | lens + composite.
    if (gR2PerfProbe > 0.5 && gR2PerfProbe < 1.5) discard;
    uint nCand = gR2BigOn > 0.5 ? 34u : 25u;
    int2 tc = int2((uint2)c0 >> 2);
    float splitMark = 0.0, impMark = 0.0, tightMiss = 0.0;
    // PERF-10 candidate mask (msk.hlsl): only candidates that can reach this pixel's cell. Needs the records, tight
    // support and no D-A widening (reachMM 0); verify (2) runs all 34 and flags a used candidate the mask lacks.
    bool maskOk = gR2UseMask > 0.5 && gR2UseRec > 0.5 && gR2TightReach > 0.5 && !multi
                  && all(c0 >= int2(0, 0)) && all(c0 < size);
    uint mLo = 0x1FFFFu, mHi = 0x1FFFFu;
    if (maskOk) { float2 mk = txR2Msk.Load(int3(c0, 0)).xy; mLo = (uint)mk.x; mHi = (uint)mk.y; }
    bool maskIter = maskOk && gR2TightReach < 1.5;
    uint bLo = maskIter ? mLo : 0x1FFFFu, bHi = maskIter ? mHi : 0x1FFFFu;
    [loop] while (bLo != 0u || bHi != 0u) {
        uint ci;
        if (bLo != 0u) { ci = firstbitlow(bLo); bLo &= bLo - 1u; }
        else { ci = 17u + firstbitlow(bHi); bHi &= bHi - 1u; }
        if (ci >= nCand) continue;
        int2 s;
        bool bp = ci >= 25u;
        if (!bp) {
            s = c0 + int2((int)(ci % 5u) - 2, (int)(ci / 5u) - 2);
        } else {
            uint cj = ci - 25u;
            int2 tt = tc + int2((int)(cj % 3u) - 1, (int)(cj / 3u) - 1);
            if (any(tt < int2(0, 0)) || any(tt * 4 >= size)) continue;
            float4 bg = txR2Big.Load(int3(tt, 0));
            if (bg.z < 0.5) continue;
            s = int2(round(bg.xy));
        }
        R2Cand c;
        bool early = false;
        bool tight = gR2TightReach > 0.5;
        if (gR2UseRec > 0.5) {   // PERF-9 drop records
            if (!r2CandRec(s, pc, size, reachMM, bp, tight, c, early)) continue;
            if (early && gR2TightReach < 1.5) continue;
        } else {
            if (!r2Cand(s, pc, size, reachMM, wetV, bp, c)) continue;
        }
        if (c.ch >= 0.0 && c.ch < 1.5 && dot(c.q, c.q) < 1.44 * c.r * c.r) splitMark = 1.0;   // S6c highlight
        if (c.imp > 0.5 && dot(c.q, c.q) < (c.imp > 2.5 ? 9.0 : 1.44) * c.r * c.r) impMark = max(impMark, c.imp);   // R2b: satellites x3 marker
        // PERF-7: proven no-contribution -> skip (1); verify (2) draws it anyway and flags a contribution
        bool beyond = early;
        if (tight) { float sB = r2SupportMM(c, air, reachMM); beyond = beyond || dot(c.q, c.q) > sB * sB; }
        if (beyond && gR2TightReach < 1.5) continue;
        if (maskOk && !early && ((ci < 17u ? (mLo >> ci) : (mHi >> (ci - 17u))) & 1u) == 0u) tightMiss = 1.0;   // PERF-10 verify
        float hwB = HW + HWm[0] + HWm[1] + HWm[2] + HWm[3];
        if (multi) {   // rev25: no [branch] - r2DropLens takes ddx/ddy of its lookup
            [unroll] for (int k = 0; k < 4; ++k) r2AddDrop(c.q + dqT[k], c, air, wetFlat, Pm[k], Gm[k], RWm[k], HWm[k]);
        } else {
            r2AddDrop(c.q, c, air, wetFlat, P, G, RW, HW);
        }
        if (beyond && HW + HWm[0] + HWm[1] + HWm[2] + HWm[3] != hwB) tightMiss = 1.0;
    }
    // rev48-F9: the F2 fine-droplet micro-grid is removed with the fine layer (it drew non-drops as drops)
    // rev47j rivulets (trail lens kernels), only where the field holds trail water
    R2Trail trl;
    if (gR2LookLab < 0.5 && Fd.r > 1e-4 && r2TrailBest(pc, trl)) {
        if (multi) {
            [unroll] for (int k = 0; k < 4; ++k) r2AddTrail(trl, dqT[k], Pm[k], Gm[k], RWm[k], HWm[k]);
        } else {
            r2AddTrail(trl, float2(0, 0), P, G, RW, HW);
        }
    }
#ifndef R2_DEPTH_ONLY
    if (tightMiss > 0.5) return float4(8.0, 0.0, 0.0, 1.0);                  // PERF-7 verify: a skipped drop contributed
#endif
    if (gR2PerfProbe > 1.5) { if (P > 2.0) return float4(P, 0, 0, 0); discard; }   // PERF-6 probe: keep the union live, draw nothing
    float U = 1.0 - P;
    float Rmm = RW.x / max(HW, 1e-6);
    float sth = RW.y / max(HW, 1e-6);
    float cov;
    float3 cDrop;
    if (multi) {   // rev25: no [branch] - r2DropLens takes ddx/ddy of its lookup
        // D-A: sharp lenses at 4 points of the CoC disc, premultiplied average.
        float ca = 0.0;
        float3 cc = float3(0, 0, 0);
        [unroll] for (int k = 0; k < 4; ++k) {
            float ck;
            float Rk = RWm[k].x / max(HWm[k], 1e-6);
            float sk = RWm[k].y / max(HWm[k], 1e-6);
            float2 GmI = Gm[k] + sImpD * (gR2ImpactWaveK * saturate((1.0 - Pm[k] - gR2Threshold) * 4.0) / (0.77 * max(Rk, 0.2) * max(sk, 0.2)));
            float3 col = r2DropLens(1.0 - Pm[k], GmI, Rk, sk, pxU, pxV, pixMM, sp + oT[k] * gR2InvRT,
                                    offF, filmMip, max(1.5, 0.5 * cocPx), cocPx, 0.5, aspect, vw, ck);
            ca += ck;
            cc += col * ck;
        }
        cov = ca * 0.25;
        cDrop = cc / max(ca, 1e-4);
    } else {
        // D-C: sharp lens, edge = disc (x) disc of the CoC, peak min(1, (R / rb)^2).
        float2 GI = G + sImpD * (gR2ImpactWaveK * saturate((U - gR2Threshold) * 4.0) / (0.77 * max(Rmm, 0.2) * max(sth, 0.2)));
        cDrop = r2DropLens(U, GI, Rmm, sth, pxU, pxV, pixMM, sp, offF, filmMip,
                           max(1.5, cocPx), cocPx, 1.0, aspect, vw, cov);
        float rb = 0.5 * cocMM;
        float peak = rb > 1e-4 ? saturate(Rmm * Rmm / (rb * rb)) : 1.0;
        cov *= peak;
    }
    // Drops sink into a thick film: their own outline fades.
    cov *= 1.0 - gR2FilmAbsorb * filmCov * thickK;   // rev47j: only a thick sheet swallows the outline
#ifdef R2_DEPTH_ONLY
    clip(max(cov, covS) - gR2DepthCoverage);
    return float4(0, 0, 0, 0);
#else
    float aFilm = filmCov * (1.0 - cov);
    float a = cov + aFilm;
    // rev16/17 forward scattering of the VISOR SURFACE (micro haze M, film; spray 0).
    float scatterX = gR2ScatterFilm * filmCov * thickK * 1.0
                   + gR2ScatterSpray * gR2Spray;
    float scat = gR2LookLab > 0.5 ? 0.0 : min(1.0 - exp(-scatterX), gR2ScatterMax);
    // H1 HAZE (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 17): G = sub-visible micro droplets (mm of water). Caps of contact
    // radius a and volume shapeK a^3 placed at random cover phi = 1 - exp(-pi h / (shapeK a)) of the surface (Poisson),
    // up to the coalescence saturation of dropwise condensation (breath figures, ~0.55). Each micro cap bends light over a
    // wide cone -> the covered share is scattered (the same surface-scatter ambient as the film). Not over drops (below).
    // H3 MICRO LAYER (docs/RAINFX_V2_H3_ATLAS_SPEC.md sections 3, 3.5b, 8f). Haze water: R = G_f fresh fine (white veil),
    // G = G_c coarsened = the pieces of the baked layered atlas (txR2Micro, 25.6 mm tile: R G normal, B signed distance to
    // the piece outline, A rank = area share of the pieces sorted largest first; a gap carries its nearest piece's rank).
    //   size:   a_eff = hazeAMM x max(G_c / G_sat, 1) (self-similar coarsening) -> octave L = log2(a_eff / a50), two octaves,
    //           the coarse one on top, each with a fixed rotation / offset;
    //   exists: rank < min(coverage share of this octave, A_res). A_res = 1 - (r_min / (r_max s))^(1/q) is the rank whose
    //           piece radius equals the smallest RESOLVED radius r_min (resPx pixels / the defocus CoC): a piece is either
    //           drawn solid or not at all (H3-2c: sub-pixel pieces were the 'half-transparent noise');
    //   edge:   signed distance / pixel size (crisp at any magnification, no mip coverage);
    //   halo:   an existing piece keeps the veil off a band just outside its rim (signed distance > -halo);
    //   veil:   fresh fine water + the unresolved share of the coarse water, only off the pieces and their halos.
    // Pieces are clear water (plano-convex lens, R1). N3 verify: the haze pass writes R = -1 -> red.
    float microD = 0.0;
    float3 cMicro = float3(0, 0, 0);
    float blurU = 0.0;                                               // V2: unresolved coarse water as blurred scene
    float3 cBlur = float3(0, 0, 0);
    bool hazeMiss = false;
    if (gR2LookLab < 0.5 && gR2HazeK > 0.0) {
        float2 gH = txR2Haze.SampleLevel(samLinearClamp, t, 0).rg;   // H1c / H3-3: 2x-resolution haze layer (fine, coarse)
        hazeMiss = gR2HazeMaskMode > 1.5 && gH.x < -0.5;              // returned after the lens (uniform flow for ddx)
        float2 hMM = max(gH, 0.0) * gR2FineMaxMM;
        float kPhi = 3.14159265 / max(gR2ShapeK * gR2HazeAMM, 1e-6);
        float phiF = min(1.0 - exp(-kPhi * hMM.x), gR2HazePhiMax);
        float aC = max(gR2CoarseInRMM, hMM.y * gR2HazeAMM / max(gR2HazeSatMM, 1e-9));   // H3-3b: arrival / saturation size
        float phiC = min(1.0 - exp(-3.14159265 * hMM.y / max(gR2ShapeK * aC, 1e-6)), gR2HazePhiMax);
        float phiU = phiC, haloAcc = 0.0;                            // without pieces all coarse water is unresolved
        float rUnres = aC;                                           // radius of that unresolved water
        // H3-3b (2026-11-13 review: draw 0.89 -> 1.64 ms; pieces of rank ~0 drawn with no water; no wipe / halo seen):
        // only where coarse water exists (divergent branch: explicit-gradient / level samples only, no ddx inside),
        // existence strictly rank < threshold, and a cheap CSP lens (one scene tap + one cube tap on steep rims).
        if (gR2MicroOn > 0.5 && phiC > 0.002) {
            float aEff = aC * exp2(gR2MicroBias);
            float rMin = gR2MicroResPx * max(pixMM, 2.0 * cocMM);        // smallest piece radius drawn as a drop
            float L = clamp(log2(aEff / max(gR2MicroA50MM, 1e-6)), -8.0, 0.0);
            float L0 = floor(L), fL = L - L0;
            float2 pMMv = t * gR2TexMM;
            float2 gxMM = dtx * gR2TexMM, gyMM = dty * gR2TexMM;
            float relC = saturate(phiC / max(gR2HazePhiMax, 1e-3));
            float Dacc = 0.0, resSum = 0.0;
            float2 slope = float2(0, 0);
            [unroll] for (int k = 1; k >= 0; --k) {
                float Lk = L0 + (float)k;
                float wk = k == 1 ? fL : 1.0 - fL;
                float sK = exp2(Lk);
                float aRes = 1.0 - pow(saturate(rMin / max(gR2MicroRMaxMM * sK, 1e-6)), 1.0 / max(gR2MicroRankQ, 0.05));
                float thr = min(relC * wk, aRes);
                resSum += max(thr, 0.0);
                if (thr < 0.002) continue;                                   // nothing of this octave exists / resolves
                float sc = sK * gR2MicroTileMM;
                float ang = Lk * 2.39996;                                    // golden angle per octave
                float2 cs = float2(cos(ang), sin(ang));
                float2x2 R = float2x2(cs.x, -cs.y, cs.y, cs.x);
                float2 off = frac(Lk * float2(0.3719, 0.6180));
                float2 uvA = mul(R, pMMv) / sc + off;
                float2 ga = mul(R, gxMM) / sc * 0.5, gb = mul(R, gyMM) / sc * 0.5;   // one mip sharper
                float4 m = txR2Micro.SampleGrad(samLinear, uvA, ga, gb);    // H3-2d: one sample (rank blends only on edges)
                float rk = m.a;
                float sdMM = (m.b - 0.5) * 2.0 * gR2MicroSdfMM * sK;         // + inside the piece (range 0.6 mm: never clipped
                                                                             //   below a pixel -- 0.1 mm made every piece 25-75 %)
                float ex = saturate((thr - rk) / 0.003);                     // strictly below the threshold (no rank-0 ghosts)
                float add = ex * saturate(sdMM / pixMM + 0.5) * (1.0 - Dacc);
                float3 n = float3(m.xy * 2.0 - 1.0, 0.0);
                n.z = sqrt(saturate(1.0 - dot(n.xy, n.xy)));
                float2 g = -n.xy / max(n.z, 0.15);                           // height gradient (atlas axes)
                slope += add * mul(g, R);                                    // back to visor u / v axes (R^T g)
                Dacc += add;
                // H3-2d halo: distance to the nearest EXISTING piece -- the halo atlas holds the smallest rank within 4 radii
                // (the per-texel rank only knows the nearest piece, existing or not: the halo reached only the 0.025 mm gaps)
                float hW = max(gR2MicroHaloK * aEff, gR2MicroHaloPx * pixMM);
                haloAcc = max(haloAcc, ex * saturate(1.0 + sdMM / hW));
                float4 hl = txR2MicroHalo.SampleGrad(samPoint, uvA, ga * 2.0, gb * 2.0);
                haloAcc = max(haloAcc, (hl.x < thr ? 1.0 : 0.0) * saturate(1.0 - 0.03 * sK / hW));
                haloAcc = max(haloAcc, (hl.y < thr ? 1.0 : 0.0) * saturate(1.0 - 0.06 * sK / hW));
                haloAcc = max(haloAcc, (hl.z < thr ? 1.0 : 0.0) * saturate(1.0 - 0.12 * sK / hW));
                haloAcc = max(haloAcc, (hl.w < thr ? 1.0 : 0.0) * saturate(1.0 - 0.24 * sK / hW));   // radii = bake HALO_R
            }
            microD = saturate(Dacc) * (1.0 - cov);
            if (microD > 0.0) {
                // R1 (2026-11-13: the CSP prism / cube-rim lens looked foreign next to the cell drops): the SAME plano-convex
                // lens as r2DropLens -- enter the flat contact face, leave through the cap (normal = visor normal tilted by
                // the piece slope), project the exit direction with the real camera, compress continuously into the frame,
                // TIR dims the same image, sky glint on the up-facing rim. No ddx (divergent branch): the scene mip comes
                // from the piece size -- the refracted image sweeps ~0.6 screen heights across a piece of rPx pixels.
                slope = slope / max(Dacc, 1e-4) * gR2MicroRefract;
                float3 sW = slope.x * vw.Tu + slope.y * vw.Tv;
                sW -= vw.n * dot(sW, vw.n);
                float capS = min(length(sW), 7.0);
                float3 dUp = capS > 1e-6 ? sW / max(length(sW), 1e-9) : float3(0, 0, 0);
                float3 N = normalize(vw.n - capS * dUp);
                float3 Vw = refract(vw.V, -vw.n, 1.0 / 1.333);
                float ci = dot(Vw, N);
                float kd = 1.0 - 1.333 * 1.333 * (1.0 - ci * ci);
                float3 Vp = normalize(1.333 * Vw + (sqrt(max(kd, 0.0)) - 1.333 * ci) * N);
                float tir = smoothstep(0.04, -0.04, kd);
                float3 Vo = normalize(lerp(vw.V, Vp, gR2LensPhys));
                float2 dpx = (r2Proj(Vo, vw) - r2Proj(vw.V, vw)) * vw.sgn * gR2FovK;
                float2 uvA = sp + dpx * float2(aspect, 1.0) - 0.5;
                if (dot(Vo, vw.look) < 0.05) uvA = (sp - 0.5) + normalize(dpx * float2(aspect, 1.0) + 1e-6) * 4.0;
                float2 xa = abs(uvA) / 0.49;
                float2 uvW = uvA / sqrt(sqrt(1.0 + xa * xa * xa * xa)) + 0.5;
                float rPx = max(aEff / max(pixMM, 1e-5), 0.5);
                float mipFW = log2(max(0.6 / (gR2InvRT.y * rPx), 1.0));
                float mipW = clamp(gR2WFSceneMip + max(mipFW - 1.0, 0.0) + 0.5 * log2(1.0 + cocPx), 0.0, 7.0);
                cMicro = r2Scene(saturate(uvW), mipW) * lerp(1.0, 0.35, tir);
                float up = saturate(dot(-dUp, float3(0, 1, 0)));
                cMicro += gR2VeilColor * (gR2Glint * up * up * up * up * smoothstep(0.8, 2.0, capS) * (1.0 - tir));
            }
            phiU = phiC * saturate(1.0 - resSum / max(relC, 1e-4));          // coarse water too small to resolve
            rUnres = min(aEff, 0.5 * rMin);
        }
        // V2 (section 8j / 8m): unresolved lenses are still lenses -- each refracts the scene of its cone; a pixel holding many
        // averages them = the blurred scene (gR2MicroBlurK of their area); the rest (steep / TIR rims) scatters toward the
        // veil colour. Blur level: the R1 rule (image of ~0.6 screen heights across a lens of rPx pixels), rPx < 1 here.
        float veil = (1.0 - (1.0 - phiF) * (1.0 - (1.0 - gR2MicroBlurK) * phiU)) * (1.0 - haloAcc);
        blurU = gR2MicroBlurK * phiU * (1.0 - haloAcc) * (1.0 - microD);
        if (blurU > 0.002) {
            float rPxU = max(rUnres / max(pixMM, 1e-5), 0.25);
            float mipU = clamp(gR2WFSceneMip + max(log2(max(0.6 / (gR2InvRT.y * rPxU), 1.0)) - 1.0, 0.0) + 0.5 * log2(1.0 + cocPx), 0.0, 7.0);
            cBlur = r2SceneS(sp, mipU, true);
        }
        veil *= 1.0 - microD;
        scat = 1.0 - (1.0 - scat) * (1.0 - gR2HazeK * veil);
    }
    if (hazeMiss) return float4(8.0, 0.0, 0.0, 1.0);
    // H3: the scatter (film / spray / veil) is not drawn over a micro piece either
    scat *= 1.0 - microD;
    // rev47j (rev47i review: the veil covered the drops at speed): micro haze and film lie BETWEEN the
    // drops on the surface -- a drop has absorbed what was under it -- so their scatter is not drawn over drops.
    scat *= 1.0 - cov;
    clip(gR2Debug > 0.5 ? 1.0 : max(max(a, scat), max(microD, blurU)) - 0.003);

    // F2: ONE veil colour -- the surface scatter's ambient (scene behind at the scatter mip, toward the sky veil) is also
    // what a thick, aerated film turns to (F1 had a second 'haze' veil = blurred scene / veil mix with its own strength)
    float3 amb = lerp(r2SceneS(sp, gR2ScatterMip, true), gR2VeilColor, gR2ScatterSky) * gR2ScatterGain;
    float3 cFilm = r2Scene(saturate(sp + offF), filmMip);
    cFilm = lerp(cFilm, amb, gR2FilmVeil * filmCov * thickK);
    // rev46 edge cues of a rivulet (legacy T4): steep sides lose light (thin dark line), the side
    // facing the sky catches a thin bright line -- the volume of the water band.
    float rimF = smoothstep(0.6, 2.5, fl) * filmCov;
    float upF = saturate(-dot(dirF, float2(0.0, 1.0)));
    cFilm = cFilm * (1.0 - 0.35 * rimF) + gR2VeilColor * (0.25 * rimF * upF * upF * upF * upF);
    float3 col = (cDrop * cov + cFilm * aFilm) / max(a, 1e-4);
    if (microD > 0.0) {                                              // H3 pieces lie under the cell drops / film
        float aM = microD * (1.0 - saturate(a));
        col = (col * saturate(a) + cMicro * aM) / max(saturate(a) + aM, 1e-4);
        a = saturate(a) + aM;
    }
    if (blurU > 0.002) {                                             // V2: the unresolved lens layer, under drops / film / pieces
        float aB = blurU * (1.0 - saturate(a));
        col = (col * saturate(a) + cBlur * aB) / max(saturate(a) + aB, 1e-4);
        a = saturate(a) + aB;
    }
    // Composite the scatter over everything below (alpha blending: out = src*A + dst*(1-A)).
    // Wanted: (col*a + dst*(1-a))*(1-s) + amb*s  ->  A = a + s - a*s, src = (col*a*(1-s) + amb*s) / A.
    a = saturate(a);
    float aOut = a + scat - a * scat;
    col = (col * a * (1.0 - scat) + amb * scat) / max(aOut, 1e-4);
    a = aOut;
    if (false) {
    } else if (gR2Debug > 8.5) {
        col = cDrop;                          // Debug 9 (drops only): lens direction, see r2DropLens
        a = max(cov, 0.0);
    } else if (gR2Debug > 7.5) {
        col = float3(cov, cov, cov);       // Debug 8: drop coverage only (is a pattern in the outline itself?)
        a = 1.0;
    } else if (gR2Debug > 6.5) {
        col = cDrop;   // Debug 7 (drops only): R rho, G squeeze, B TIR / mip
        a = cov;
    } else if (gR2Debug > 5.5) {
        // Defocus: R = camera distance (0..15 cm), G = CoC px (0..40), B = drop silhouette.
        col = float3(saturate(z / 0.15), saturate(cocPx / 40.0), cov) * gR2DebugBright;
        a = 0.85;
    } else if (gR2Debug > 4.5) {
        // Film thickness (2026-11-15 rework: the 0.02-0.1 mm film that holds the F4b gate open drew as near-black blue).
        // Texel value (no B-spline, the gate's own test): grey = dry / below gR2FilmWetMM (0.02, haze-scale water: 0.15 x h / wet);
        // blue -> cyan = film 0.02 .. gR2FilmMinMM (0.1, not drawn); green -> white = drawn film up to + 0.3 mm (F3 caps at 0.3).
        // Red tint = F5 mobile body (A >= 2).
        int2 fT = clamp(int2(t * gR2FieldSize), int2(0, 0), int2(gR2FieldSize) - 1);
        float4 Fx = txR2Field.Load(int3(fT, 0));
        float hX = Fx.b * gR2FilmMaxMM;
        float hj = max(gR2FilmMinMM, 1e-3), hw = max(gR2FilmWetMM, 1e-4);
        float3 cF = hX < hw ? float3(0.15, 0.15, 0.15) * saturate(hX / hw)
                  : hX < hj ? lerp(float3(0.0, 0.2, 1.0), float3(0.0, 1.0, 1.0), saturate((hX - hw) / max(hj - hw, 1e-4)))
                  : lerp(float3(0.0, 0.85, 0.35), float3(1, 1, 1), saturate((hX - hj) / 0.3));
        if (Fx.a >= 1.5) cF = lerp(cF, float3(1.0, 0.1, 0.1), 0.6);
        col = cF * gR2DebugBright;
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
                // F7 origin of a PINNED drop: blue = raindrop residue / merged, cyan = E8 split piece, white = splash satellite,
                // (life.w markers; a marker lasts while the drop has not merged)
                float lw = txR2State.Load(int3(s + int2(size.x, 0), 0)).w;
                float3 pinC = abs(lw + 5.0) < 0.5 ? float3(0.1, 0.9, 0.9) : abs(lw + 7.0) < 0.5 ? float3(0.9, 0.9, 0.9)
                            : float3(0.1, 0.3, 1.0);
                col = v < 1e-3 ? pinC
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
        float ex = Fd.a >= 1.5 ? Fd.a - 2.0 : Fd.a;   // F5: A = exposure + 2 x film body mobile
        col = float3(ex, 0.1, 1.0 - ex) * gR2DebugBright;
        a = 0.6;
    } else if (gR2Debug > 0.5) {
        col = float3(cov, Fd.g, Fd.r) * gR2DebugBright;   // R = drop coverage (sharp lens edge)
        a = max(a, 0.6);
    }
    // rev48-S6c: 'Highlight split pieces' -- E8 tail pieces younger than 1.5 s in cyan (review aid)
    if (gR2HiSplit > 0.5 && splitMark > 0.0) { col = lerp(col, float3(0.0, 1.0, 1.0), 0.8); a = max(a, 0.85); }
    // U1: magenta = impact-born splat (< 0.3 s), yellow = an existing drop hit by an impact this frame (merge)
    if (gR2HiImpact > 0.5 && impMark > 0.0) { col = lerp(col, impMark > 5.5 ? float3(0.95, 0.95, 0.95) : impMark > 4.5 ? float3(0.1, 0.35, 1.0) : impMark > 3.5 ? float3(0.0, 1.0, 0.2) : (impMark > 2.5 ? float3(1.0, 0.25, 0.0) : (impMark > 1.5 ? float3(1.0, 0.9, 0.0) : float3(1.0, 0.0, 1.0))), 0.8); a = max(a, 0.85); }
    return float4(col, saturate(a));
#endif
}
