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
float r2VisorSeed(float w) { return floor(w / 262144.0); }    // = r2UnpackSeed (rev40: 64 seeds)
float2 r2UnpackBF(float w) {                                     // = common.hlsl (rev48-S4 bend + resting spread)
    if (w >= 0.0) return float2(w, 1.0);
    float v = -w - 1.0;
    float qr = floor(v / 4096.0);
    float qb = qr - 1024.0 * floor(qr / 1024.0);                 // rev48-S6b: bend mode above
    return float2((qb - 500.0) / 250.0, 1.0 + (v - qr * 4096.0) / 1000.0);
}
float r2UnpackBMode(float w) {                                   // = common.hlsl (0 bow, 1 / 2 hook at the +u1 / -u1 end)
    return w >= 0.0 ? 0.0 : floor(floor((-w - 1.0) / 4096.0) / 1024.0);
}
float2 r2UnpackHarm(float z) {                                   // = common.hlsl (rev48-S1 shape state)
    float hi = floor(z / 2048.0);
    return float2(hi / 1000.0 - 0.5, (z - hi * 2048.0) / 2000.0);
}
float2 r2VisorMove(float w) {                                 // = r2UnpackMove
    float m = w - r2VisorSeed(w) * 262144.0;
    float qx = floor(m / 512.0);
    return (float2(qx, m - qx * 512.0) - 250.0) / 31.25;   // rev40 packing (common.hlsl r2PackMove)
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
// rev33: integer hash. frac(sin(x) * 43758) with x ~ 1e5 (visor mm / 0.6 R) loses precision on GPUs and
// gives a pixel-scale hatch inside large drops (WF large-drop warp).
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
void r2Kernel(float2 q, float Rk, float2 props, float beta, R2Shape T, float3 H, float2 hu, float3 AS,
              inout float P, inout float2 G, inout float2 RW, inout float HW) {
    float dR = 1.0;
    if (abs(H.x) + H.y > 1e-3) {
        float2 qq = q * rsqrt(max(dot(q, q), 1e-12));
        float ca = dot(qq, hu), sa = qq.y * hu.x - qq.x * hu.y;
        float c2 = ca * ca - sa * sa;
        float c3 = ca * (4.0 * ca * ca - 3.0), s3 = sa * (3.0 - 4.0 * sa * sa);
        dR = max(1.0 + H.x * c2 + H.y * (c3 * cos(H.z) + s3 * sin(H.z)), 0.3);
    }
    float ik = 1.0 / (Rk * Rk * dR * dR);
    float x = dot(q, q) * ik;
    float h = 1.0 - (1.0 - beta) * x - beta * x * x;
    if (h <= 0.0) return;
    float2 g = (-2.0 * ik * (1.0 - beta + 2.0 * beta * x)) * q;
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

struct R2Cand { float2 q; float r; float seed; float2 m; float k; float4 sh; float f; float fx; };

// Candidate drop of cell s (false = empty or out of reach). reachMM widens the test for D-A taps.
bool r2Cand(int2 s, float2 pc, int2 size, float reachMM, float wetV, out R2Cand c) {
    c = (R2Cand)0;
    if (any(s < int2(0, 0)) || any(s >= size)) return false;
    float4 st = txR2State.Load(int3(s, 0));
    if (st.z <= 0) return false;
    c.r = max(r2VisorRadiusMM(st.z), gR2MinDrawMM);
    // rev45 life cycle (right half of the state texture): grow in, fade out, flight streak
    float4 L = txR2State.Load(int3(s + int2(size.x, 0), 0));
    // rev48-S2' impact SPREAD (life.w = -(10 + f0), cells): the newborn is a thin splat f x its final
    // radius, recoiling f = 1 + (f0 - 1) exp(-age / tau); it replaces the grow-in of other births.
    // rev48-S4: the drop's own remembered flatness fS (shape state, set by its birth / arrest / merge, held
    // while pinned, morphed while moving) -- rev48-S2c hashed it from the cell index, which re-rolled a moving
    // drop's look at every cell crossing (S3b review: 1-frame flashes). A splat recoils from f0 to fS.
    float4 shS = txR2State.Load(int3(s + int2(2 * size.x, 0), 0));
    float2 bfS = r2UnpackBF(shS.w);
    float fB = max(max(bfS.y, gR2BaseSpread), 1.0);
    bool splat = L.w < -9.5 && L.y <= 0;
    float f0 = -L.w - 10.0;
    c.f = (splat && gR2ShpOn > 0.5 && f0 > fB) ? fB + (f0 - fB) * exp(-L.x / max(gR2ShpSpreadTau, 1e-3)) : fB;
    if (gR2ShpOn < 0.5) c.f = 1.0;
    c.fx = max(c.f - fB, 0.0);
    float vis = splat ? 1.0 : lerp(0.35, 1.0, smoothstep(0.0, max(gR2GrowTime, 1e-3), L.x));
    if (L.z > 0) vis *= saturate(L.z / max(gR2FadeTime, 1e-3));
    if (L.y > 0) vis *= lerp(0.55, 1.0, saturate(L.y / max(gR2FlyTime, 1e-3)));
    // rev48-S4c (S4b review: drawn sizes larger than the water made size / collision hard to judge): the
    // resting flatness f only shapes the PROFILE (contact angle / f^1.5, flat top) inside the drop's own
    // footprint; only the transient impact splat (same water spread thin, < 0.3 s) is wider than r.
    c.r *= vis * (c.f / fB);
    c.q = (pc - (float2(s) + st.xy)) * gR2CellSizeMM;
    float shE = length(shS.xy);
    float shA = sqrt((0.5 + shE) / max(0.5 - shE, 0.05));                 // rev48-S1: aspect widens the reach
    float reach = 1.3 * gR2KernelScale * c.r * sqrt(shA) * 1.35 * (L.y > 0 ? 1.0 + gR2FlyStretch : 1.0) + reachMM
                + 0.5 * c.r * (1.0 - fB / c.f);                           // splat centre shifted upstream
    if (dot(c.q, c.q) > reach * reach) return false;
    c.seed = r2VisorSeed(st.w);
    c.sh = shS;                                                // rev48-S1 shape state
    float2 mv = r2VisorMove(st.w) * gR2CellSizeMM;            // mm in the last frame
    float ml = length(mv);
    c.m = ml > 1e-4 ? mv / ml : float2(0, 0);
    float v = ml * 1e-3 / max(gR2SimDt, 1e-5);                 // m/s
    c.k = gR2MotionStretch * saturate(v / max(gR2VMax, 1e-3));
    if (L.y > 0) {                                             // flying: long streak along the flight
        c.m = normalize(float2(cos(L.w), sin(L.w)) * gR2CellSizeMM);
        c.k = gR2FlyStretch;
    }
    // rev48-S3b (rev48_S3 recording: big splats / merged drops showed straight cut edges and 'tick' notches):
    // a drop is only drawn by pixels within +-2 cells of its own cell, so its whole kernel (aspect, contour
    // modes, bend, motion stretch, splat shift) must fit 2 cells (~2.3 mm). Larger visuals are scaled down to
    // that window instead of being cut; the physics footprint uses the same cap (common r2FootRadiusMM).
    float2 hmC = r2UnpackHarm(c.sh.z);
    float hF = min(1.0 + (max(hmC.x, 0.0) + hmC.y) * (1.0 + 2.0 * c.fx) + 0.1 * c.fx, 1.7);
    float ext = gR2KernelScale * c.r * sqrt(shA) * hF * (1.0 + c.k) + 0.5 * c.r * c.fx / c.f
              + abs(bfS.x) * gR2KernelScale * c.r / sqrt(shA);
    float lWin = 2.0 * min(gR2CellSizeMM.x, gR2CellSizeMM.y) - 0.05;
    if (ext > lWin) c.r *= lWin / ext;
    return true;
}

// Per-pixel airflow context for the wobble (rev20): unit air direction in visor mm (u, v) and
// the tangential air speed at the surface (m/s).
struct R2Air { float2 dir; float u2; float2 gdir; };

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
    float shA = sqrt((0.5 + shE) / max(0.5 - shE, 0.05));
    float2 hm = r2UnpackHarm(c.sh.z);
    // rev48-S2' splat: its footprint sits UPSTREAM of the final drop (the rim recedes toward the downstream
    // end, where the drop gathers), contour modes grow with the spread (rings / torn branches)
    if (c.fx > 1e-3) {
        float2 down = dot(c.m, c.m) > 0.5 ? c.m : air.gdir;
        q += down * (0.5 * c.r * c.fx / c.f);
        hm = float2(clamp(hm.x * (1.0 + 2.0 * c.fx) + 0.06 * c.fx, -0.45, 0.45), min(hm.y * (1.0 + 2.0 * c.fx) + 0.04 * c.fx, 0.3));
    }
    float sphi = 0.5 * atan2(c.sh.y, c.sh.x);
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
        q -= vv * (r2UnpackBF(c.sh.w).x * rkS * ah * ah);
        q -= T.u1 * (dot(q, T.u1) * T.s1);
        H = float3(hm.x, hm.y, h1 * 6.2831853);
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
    float kSag = gR2SagK * saturate(c.r * c.r / 2.25);
    bool slide = c.k > kSag;
    T.u2 = slide ? c.m : air.gdir;
    float kk = slide ? c.k : kSag;
    float a = dot(q, T.u2);
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
    float th = gR2ContactDeg + gR2ContactSpread * (2.0 * h2 - 1.0);
    th -= gR2Hysteresis * (a < 0.0 ? saturate(c.k / max(gR2MotionStretch, 1e-3)) : 0.0);
    th *= 1.0 - wetFlat;
    // rev48-S2' splat: a spreading lamella is a thin sheet with its mass in a thick RIM (reference: bright flat
    // interior, dark crisp outline). S2'a: rim angle theta / f^1.5 (rev S2' f^3 flattened the rim away too)
    // and a flat-top profile (beta -> 0.85) so the interior stays flat while the edge refracts.
    th /= c.f * sqrt(c.f);
    float sth = sin(radians(clamp(th, 4.0, 89.0)));
    float beta = gR2FlatK * saturate((c.r - gR2FlatStartMM) / max(gR2FlatFullMM - gR2FlatStartMM, 1e-3));
    beta = max(beta, 0.85 * saturate(c.f - 1.0));
    // rev48-S2d apex offset: downhill (gravity) for large drops, a per-drop direction for small ones
    float2 rd = float2(cos(h2 * 6.2831853 + 1.3), sin(h2 * 6.2831853 + 1.3));
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
    float3 AS = float3(-ad, gR2AsymK * (0.35 + 0.65 * frac(c.seed * 0.6180339887 + 0.55)));
    r2Kernel(q, rkS, float2(rkS / gR2KernelScale, sth), beta, T, H, T.u1, AS, P, G, RW, HW);
}

// rev47j RIVULET KERNEL (rev47i review + reference frames: a sliding large drop leaves a thin, sharp,
// long-lived line, about a quarter of the drop width). The field R holds the centre-line depth h0, the
// trail texture TG the line itself (point, direction, half-width hw). Among the 3 x 3 field texels around
// the pixel the line closest to the pixel is drawn as a cylindrical lens of half-width hw whose edge angle
// follows the water: tan(theta) = 2 h0 / hw (parabolic section) -- the same lens and union as the drops,
// so the head and its tail join (teardrop with a tail) and a thinning trail flattens out of sight.
struct R2Trail { float2 q; float2 tau; float hw; float sth; };
bool r2TrailBest(float2 pc, out R2Trail tr) {
    tr.q = float2(0, 0); tr.tau = float2(1, 0); tr.hw = 0; tr.sth = 0;
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
            if (g.w <= 1e-4) continue;
            float2 Q = (float2(f) + 0.5) * texMM + g.xy;
            float2 tau = float2(cos(g.z), sin(g.z));
            float2 dv = pMM - Q;
            float al = dot(dv, tau);
            if (abs(al) > 1.2 * max(texMM.x, texMM.y)) continue;   // a line is valid near its own texel
            float2 dp = dv - tau * al;
            float Rk = gR2KernelScale * g.w;
            float k = 1.0 - dot(dp, dp) / (Rk * Rk);
            if (k <= best) continue;
            best = k;
            tr.q = dp;
            tr.tau = tau;
            tr.hw = g.w;
            float tn = min(2.0 * h0 / g.w, 1.0) * smoothstep(gR2TrailMinMM, gR2TrailFullMM, h0);
            tr.sth = tn * rsqrt(1.0 + tn * tn);
        }
    }
    return best > 0.0;
}
// The rivulet into the union at an extra offset dq (mm, D-A taps): only the cross-line part counts.
void r2AddTrail(R2Trail tr, float2 dq, inout float P, inout float2 G, inout float2 RW, inout float HW) {
    float2 q = tr.q + (dq - tr.tau * dot(dq, tr.tau));
    R2Shape T;
    T.u1 = float2(1, 0); T.s1 = 0; T.u2 = float2(1, 0); T.s2 = 0; T.u3 = float2(1, 0); T.s3 = 0;
    r2Kernel(q, gR2KernelScale * tr.hw, float2(tr.hw, tr.sth), 0.0, T, float3(0, 0, 0), float2(1, 0), float3(0, 0, 0), P, G, RW, HW);
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
                  float2 offF, float minMip, float2 warp, float bandPx, float cocPx, float cocMipK,
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
    if (gR2LensMode < 0.5) {
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
    } else {
    // rev28 = CSP windscreen drop shading (decoded from preview728 main_fx/ksWindscreenFX_new_ps,
    // docs/RAINFX_V2_CSP_DROP_SHADING.md):
    //  * flat interior: screen-space refraction, uv += (-N.side, N.up) * k, k ~ 0.25..0.5 uv units,
    //    weight saturate((nz - 0.3) * 10)  -> only where the drop normal is near the surface normal;
    //  * steep rim: NO screen lookup; environment CUBEMAP along a bent view ray
    //    V' = normalize(V + 0.5 (1 - nz) (-V - N)), x mirrored, times 0.7  -> clean outline, no
    //    aliasing, colour from the world direction (differs per visor location);
    //  * reflection: cubemap(lerp(reflect(V, N), N, 0.7), mip 2) x (1 - nz)^3.
    // Our cap tilt stays physical (contact angle) for the shape; the rim zone is defined on the radius
    // (CSP's rim = where its blurred-height normal turns steep), at least gR2RimMinPx wide.
    float rho = saturate(length(G) * Rmm * (1.24 * 1.24 / 2.0));
    float3 dUp = G.x * w.Tu + G.y * w.Tv;                      // uphill (toward the centre), world
    dUp = dUp - w.n * dot(dUp, w.n);
    dUp = dot(dUp, dUp) > 1e-30 ? normalize(dUp) : float3(0, 0, 0);
    float wantBand = clamp(gR2RimMinPx / max(Rpx, 1e-3), gR2RimBand, 0.5);
    float rhoR = saturate(1.0 - (1.0 - rho) * gR2RimBand / wantBand);   // small drops: wider rim
    // CSP-like normal: tilt grows toward the rim, nz ~ 0.3 at the contact line
    float tilt = lerp(0.0, 1.27, rhoR * rhoR);                 // radians, acos(0.3) = 1.27 at the edge
    tilt = max(tilt, atan(min(rho * sth / sqrt(max(1.0 - rho * rho * sth * sth, 0.04)), 5.0)));
    float nz = cos(tilt);
    float3 N = normalize(w.n * nz - dUp * sin(tilt));          // outward drop normal (world)
    float screenW = saturate((nz - 0.3) * 10.0);
    // screen-space part (flat interior)
    float2 nsc = -float2(dot(N, w.side), dot(N, w.up)) * w.sgn;   // toward the centre (inverting look)
    float2 dpx = nsc * gR2CspRefract * gR2LensK / 0.35;
    float largeW = smoothstep(gR2LargeStartPx, max(gR2LargeFullPx, gR2LargeStartPx + 0.5), Rpx);
    float2 uvRaw = spT + offF + dpx * float2(aspect, 1.0) + warp * (2.0 * gR2LargeWarpPx * largeW) * gR2InvRT;
    float2 fx = ddx(uvRaw) / gR2InvRT, fy = ddy(uvRaw) / gR2InvRT;
    float foot = max(dot(fx, fx), dot(fy, fy));
    float mipFoot = 0.5 * log2(max(foot, 1.0)) - 1.0;
    float over;
    float2 suv = r2Mirror(uvRaw, over);
    float mip = gR2WFSceneMip + gR2LargeBlurMip * largeW
              + cocMipK * 0.5 * log2(1.0 + 0.35 * cocPx * 0.9 / max(Rpx * gR2InvRT.y, 1e-6));
    mip = clamp(max(mip, mipFoot), minMip, 9.0);
    float3 cScr = r2Scene(suv, mip);
    // rim part: environment cubemap along the bent view ray (CSP: x mirrored)
    float3 Vb = normalize(w.V + 0.5 * (1.0 - nz) * (-w.V - N));
    float3 cEnv = txReflectionCubemap.SampleLevel(samLinearSimple, float3(-Vb.x, Vb.y, Vb.z), gR2RimCubeMip).rgb
                * gR2RimEnvK;
    float3 c = lerp(cEnv, cScr, screenW);
    // reflection (CSP: lerp(reflect, N, 0.7), mip 2, x (1 - nz)^3)
    float3 Rf = reflect(w.V, N);
    Rf = normalize(lerp(Rf, N, 0.7));
    float f3 = (1.0 - nz) * (1.0 - nz) * (1.0 - nz);
    c += txReflectionCubemap.SampleLevel(samLinearSimple, float3(-Rf.x, Rf.y, Rf.z), 2.0).rgb * (f3 * gR2ReflK);
    float rim = 1.0 - screenW;
    float envK = saturate(over * 6.0);
    if (gR2Debug > 6.5) c = float3(rim, envK, saturate(mip / 9.0));   // Debug 7: rim / env / mip
    cRes = c;
    }
    return cRes;
}

// rev29 full CSP windscreen port: the drop normal comes from the WATER MAP (wmap.hlsl), exactly like
// accRainWindscreen_finalize: gradient of the height blurred at a mip (CSP LOD 1.5), x 2.2; the shading
// is the decoded ksWindscreenFX_new_ps rule (screen refraction where nz > 0.3, cubemap rim, reflection).
float3 r2CspWater(float2 t, float2 spT, float2 offF, float minMip, float aspect, R2View w, out float cov, out float3 dbg) {
    float a0 = txR2WMap.SampleLevel(samLinearClamp, t, 0).w;
    float2 st = gR2WMStepMM / gR2TexMM;                        // uv step of the gradient
    float L = gR2WMBlurMip;
    float hx = txR2WMap.SampleLevel(samLinearClamp, t + float2(st.x, 0), L).w
             - txR2WMap.SampleLevel(samLinearClamp, t - float2(st.x, 0), L).w;
    float hy = txR2WMap.SampleLevel(samLinearClamp, t + float2(0, st.y), L).w
             - txR2WMap.SampleLevel(samLinearClamp, t - float2(0, st.y), L).w;
    float2 n2 = -gR2WMNormalK * float2(hx, hy);                // downhill = outward bump normal
    float nl = length(n2);
    if (nl > 0.995) n2 *= 0.995 / nl;
    float nz = sqrt(saturate(1.0 - dot(n2, n2)));
    float3 N = normalize(n2.x * w.Tu + n2.y * w.Tv + nz * w.n);
    cov = saturate(max(a0 * gR2WMCovK, length(n2) * 3.0));
    // (1) flat part: screen refraction, uv += -(N.side, N.up) * k  (CSP 0.25..0.5)
    float2 dpx = -float2(dot(N, w.side), dot(N, w.up)) * w.sgn * gR2CspRefract * gR2LensK / 0.35;
    float2 uvRaw = spT + offF + dpx;
    float2 fx = ddx(uvRaw) / gR2InvRT, fy = ddy(uvRaw) / gR2InvRT;
    float mipFoot = 0.5 * log2(max(max(dot(fx, fx), dot(fy, fy)), 1.0)) - 1.0;
    float over;
    float2 suv = r2Mirror(uvRaw, over);
    float mip = clamp(max(gR2WFSceneMip, mipFoot), minMip, 9.0);
    float3 cScr = r2Scene(suv, mip);
    float screenW = saturate((nz - 0.3) * 10.0);
    // (2) steep part: cubemap along the bent view ray, x 0.7
    float3 Vb = normalize(w.V + 0.5 * (1.0 - nz) * (-w.V - N));
    float3 cEnv = txReflectionCubemap.SampleLevel(samLinearSimple, float3(-Vb.x, Vb.y, Vb.z), gR2RimCubeMip).rgb * gR2RimEnvK;
    float3 c = lerp(cEnv, cScr, screenW);
    // (3) reflection
    float3 Rf = normalize(lerp(reflect(w.V, N), N, 0.7));
    float f3 = (1.0 - nz) * (1.0 - nz) * (1.0 - nz);
    c += txReflectionCubemap.SampleLevel(samLinearSimple, float3(-Rf.x, Rf.y, Rf.z), 2.0).rgb * (f3 * gR2ReflK);
    dbg = float3(1.0 - screenW, saturate(over * 6.0), saturate(mip / 9.0));
    return c;
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
    bool multi = gR2DefocusMode > 0.5 && cocPx > 1.0 && gR2CspMode < 0.5;          // D-A only where it blurs
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
    // A wet surface (film / micro haze) lowers the effective contact angle: edges melt in (ref. A).
    float wetFlat = gR2LookLab > 0.5 ? 0.0 : gR2WetFlatten * saturate(filmCov + 2.0 * Fd.g);
    // rev20: dynamic loops (rev19 unrolled 25 x (1 + 4 taps) x lobes: minutes of FXC and a long
    // first-use stall in game). Only the 4 D-A taps are unrolled (static register arrays).
    int yEnd = gR2CspMode > 0.5 ? -3 : 2;                     // rev29 CSP mode: no cell lens
    [loop] for (int y = -2; y <= yEnd; ++y) {
        [loop] for (int x = -2; x <= 2; ++x) {
            R2Cand c;
            if (!r2Cand(c0 + int2(x, y), pc, size, reachMM, wetV, c)) continue;
            if (multi) {   // rev25: no [branch] - r2DropLens takes ddx/ddy of its lookup
                [unroll] for (int k = 0; k < 4; ++k) r2AddDrop(c.q + dqT[k], c, air, wetFlat, Pm[k], Gm[k], RWm[k], HWm[k]);
            } else {
                r2AddDrop(c.q, c, air, wetFlat, P, G, RW, HW);
            }
        }
    }
    // rev47j rivulets (trail lens kernels), only where the field holds trail water
    R2Trail trl;
    if (gR2LookLab < 0.5 && gR2CspMode < 0.5 && Fd.r > 1e-4 && r2TrailBest(pc, trl)) {
        if (multi) {
            [unroll] for (int k = 0; k < 4; ++k) r2AddTrail(trl, dqT[k], Pm[k], Gm[k], RWm[k], HWm[k]);
        } else {
            r2AddTrail(trl, float2(0, 0), P, G, RW, HW);
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
    if (multi) {   // rev25: no [branch] - r2DropLens takes ddx/ddy of its lookup
        // D-A: sharp lenses at 4 points of the CoC disc, premultiplied average.
        float ca = 0.0;
        float3 cc = float3(0, 0, 0);
        [unroll] for (int k = 0; k < 4; ++k) {
            float ck;
            float Rk = RWm[k].x / max(HWm[k], 1e-6);
            float sk = RWm[k].y / max(HWm[k], 1e-6);
            float3 col = r2DropLens(1.0 - Pm[k], Gm[k], Rk, sk, pxU, pxV, pixMM, sp + oT[k] * gR2InvRT,
                                    offF, filmMip, warp, max(1.5, 0.5 * cocPx), cocPx, 0.5, aspect, vw, ck);
            ca += ck;
            cc += col * ck;
        }
        cov = ca * 0.25;
        cDrop = cc / max(ca, 1e-4);
    } else {
        // D-C: sharp lens, edge = disc (x) disc of the CoC, peak min(1, (R / rb)^2).
        cDrop = r2DropLens(U, G, Rmm, sth, pxU, pxV, pixMM, sp, offF, filmMip, warp,
                           max(1.5, cocPx), cocPx, 1.0, aspect, vw, cov);
        float rb = 0.5 * cocMM;
        float peak = rb > 1e-4 ? saturate(Rmm * Rmm / (rb * rb)) : 1.0;
        cov *= peak;
    }
    float3 cspDbg = float3(0, 0, 0);
    if (gR2CspMode > 0.5) cDrop = r2CspWater(t, sp, offF, filmMip, aspect, vw, cov, cspDbg);
    // Drops sink into a thick film: their own outline fades.
    cov *= 1.0 - gR2FilmAbsorb * filmCov * thickK;   // rev47j: only a thick sheet swallows the outline
    float haze = gR2LookLab > 0.5 ? 0.0 : saturate(Fd.g * gR2HazeK + Fd.r * gR2TraceHaze) * (1.0 - cov);

#ifdef R2_DEPTH_ONLY
    clip(cov - gR2DepthCoverage);
    return float4(0, 0, 0, 0);
#else
    float aFilm = filmCov * (1.0 - cov);
    haze *= 1.0 - filmCov;
    float a = cov + aFilm + haze;
    // rev16/17 forward scattering of the VISOR SURFACE (micro haze M, film; spray 0).
    float scatterX = gR2ScatterM * sqrt(max(Fd.g - gR2ScatterM0, 0.0))
                   + gR2ScatterFilm * filmCov * thickK
                   + gR2ScatterSpray * gR2Spray;
    float scat = gR2LookLab > 0.5 ? 0.0 : min(1.0 - exp(-scatterX), gR2ScatterMax);
    // rev47j (rev47i review: the veil covered the drops at speed): micro haze and film lie BETWEEN the
    // drops on the surface -- a drop has absorbed what was under it -- so their scatter is not drawn over drops.
    scat *= 1.0 - cov;
    clip(gR2Debug > 0.5 ? 1.0 : max(a, scat) - 0.003);

    float3 cBlur = r2Scene(sp, gR2HazeMip);
    float3 veil = lerp(cBlur, gR2VeilColor, gR2VeilMix);
    float3 cFilm = r2Scene(saturate(sp + offF), filmMip);
    cFilm = lerp(cFilm, veil, gR2FilmVeil * filmCov * thickK);
    // rev46 edge cues of a rivulet (legacy T4): steep sides lose light (thin dark line), the side
    // facing the sky catches a thin bright line -- the volume of the water band.
    float rimF = smoothstep(0.6, 2.5, fl) * filmCov;
    float upF = saturate(-dot(dirF, float2(0.0, 1.0)));
    cFilm = cFilm * (1.0 - 0.35 * rimF) + gR2VeilColor * (0.25 * rimF * upF * upF * upF * upF);
    float3 col = (cDrop * cov + cFilm * aFilm + veil * haze) / max(a, 1e-4);
    // Composite the scatter over everything below (alpha blending: out = src*A + dst*(1-A)).
    // Wanted: (col*a + dst*(1-a))*(1-s) + amb*s  ->  A = a + s - a*s, src = (col*a*(1-s) + amb*s) / A.
    float3 amb = lerp(r2Scene(sp, gR2ScatterMip), gR2VeilColor, gR2ScatterSky) * gR2ScatterGain;
    a = saturate(a);
    float aOut = a + scat - a * scat;
    col = (col * a * (1.0 - scat) + amb * scat) / max(aOut, 1e-4);
    a = aOut;
    if (gR2Debug > 8.5) {
        col = cDrop;                          // Debug 9 (drops only): lens direction, see r2DropLens
        a = max(cov, 0.0);
    } else if (gR2Debug > 7.5) {
        col = float3(cov, cov, cov);       // Debug 8: drop coverage only (is a pattern in the outline itself?)
        a = 1.0;
    } else if (gR2Debug > 6.5) {
        col = gR2CspMode > 0.5 ? cspDbg : cDrop;   // Debug 7 (drops only): R rim, G environment, B mip / 9
        a = cov;
    } else if (gR2Debug > 5.5) {
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
