// PERF-9 (2026-11-06): drop-candidate code shared by visor.hlsl (per pixel) and rec.hlsl (per drop record).
// Helpers = common.hlsl copies (rev-tagged where they came from); textures txR2State, txR2Lam, txR2Big.

float r2VisorRadiusMM(float v) {
    return v > 0 ? exp2(log2(v / gR2ShapeK) * (1.0 / 3.0)) : 0.0;
}
// rev48-R3 = common r2CapK / r2CapScale (cap volume: a flatter / lower-angle drop of the same water is wider)
float r2VCapK(float deg) {
    float t = tan(0.5 * radians(clamp(deg, 5.0, 90.0)));
    return 0.5235988 * t * (3.0 + t * t);
}
float r2VCapScale(float seed, float f) {
    if (gR2CapVolume < 0.5) return 1.0;
    float thD = gR2ContactDeg / (f * sqrt(max(f, 1.0)));
    return clamp(pow(abs(gR2ShapeK / r2VCapK(max(thD, 15.0))), 1.0 / 3.0), 0.8, 1.6);
}
// rev48-R1 = common r2SplatTau (capillary-inertial recoil, ~1 frame)
float r2VSplatTau(float rmm) {
    float tc = sqrt(1000.0 * pow(max(rmm, 0.05) * 1e-3, 3.0) / 0.072);
    return clamp(gR2ShpRecoilC * tc * pow(50.0 / clamp(gR2SheetRecedeDeg, 15.0, 100.0), 1.5), 0.004, 0.3);
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
float2 r2UnpackHarm(float z) {                                   // = common.hlsl (rev48-S1 / R5b shape state)
    float r = floor(z / 16.0);
    float hi = floor(r / 1024.0);
    return float2(hi / 1000.0 - 0.5, (r - hi * 1024.0) / 2000.0);
}
float r2UnpackHarmPh(float z) {                                  // = common.hlsl (R5b lobe angle on the visor)
    return (z - 16.0 * floor(z / 16.0)) * 0.13089969;
}
float2 r2VisorMove(float w) {                                 // = r2UnpackMove
    float m = w - r2VisorSeed(w) * 262144.0;
    float qx = floor(m / 512.0);
    return (float2(qx, m - qx * 512.0) - 250.0) / 31.25;   // rev40 packing (common.hlsl r2PackMove)
}
struct R2Cand { float2 q; float r; float seed; float2 m; float k; float4 sh; float f; float fx; float ch; float2 nk; float imp; float sft; float e; float aMax; };   // R3b: aspect cap of the window fit   // U2: lamella centre offset (mm) / min(1 + Vt/Vn, 2)   // U1: imp = 1 impact-born splat < 0.3 s, 2 hit by an impact this frame   // S6c: child age (-1 = none), neck dir

// Candidate drop of cell s (false = empty or out of reach). reachMM widens the test for D-A taps.
// rev48-R7a = common r2BigWinner: the tile's big drop is drawn from the 3 x 3 tiles (+-4 cells), not the 5 x 5 cells
bool r2VBigWinner(int2 s) {
    if (gR2BigOn < 0.5) return false;
    float4 b = txR2Big.Load(int3((uint2)s >> 2, 0));
    return b.z > 0.5 && all(int2(round(b.xy)) == s);
}
// PERF-9: everything of a candidate that does not depend on the gathering pixel (the drop record). c.q = the drop
// CENTRE in cells; rLeg = the rev48 reach without the D-A widening (needs r before the window fit); win = drawn
// by the big-tile loop (R7a). Used by r2Cand (per pixel, legacy path) and rec.hlsl (once per drop) -- one code.
bool r2CandCore(int2 s, out R2Cand c, out float rLeg, out bool win) {
    c = (R2Cand)0; rLeg = 0.0; win = false;
    float4 st = txR2State.Load(int3(s, 0));
    if (st.z <= 0) return false;
    // R7a: each drop is drawn by exactly one of the two loops (the tile lookup only for drops large enough to win)
    win = r2VisorRadiusMM(st.z) >= gR2BigRMM && r2VBigWinner(s);
    c.r = max(r2VisorRadiusMM(st.z), gR2MinDrawMM);
    // rev45 life cycle (right half of the state texture): grow in, fade out, flight streak
    int2 size = int2(gR2Cells);
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
    // rev48-U2: recoil tau from the receding angle (r2SplatTau); the lamella is centred on the IMPACT point while the
    // residual walks downstream (r2Predict) -> drawn centre = drop - dI shift (1 - e) e (no jump at birth or end)
    float eC = (splat && gR2ShpOn > 0.5 && f0 > fB) ? exp(-L.x / r2VSplatTau(r2VisorRadiusMM(st.z))) : 0.0;
    c.f = fB + max(f0 - fB, 0.0) * eC;
    c.e = eC;                                                       // U2a: lamella share of the look (1 at birth -> 0)
    c.sft = gR2ShpLamShift * r2VisorRadiusMM(st.z) * max(f0 - 1.0, 0.0) * eC * (1.0 - eC);
    if (gR2ShpOn < 0.5) c.f = 1.0;
    c.fx = max(c.f - fB, 0.0);
    bool child = abs(L.w + 5.0) < 0.5 && L.y <= 0;              // rev48-S6c E8 split piece: existing water
    c.ch = child ? L.x : -1.0;
    // rev48-U1 review aid: born by an impact (splat, < 0.3 s) or an impact of this frame landed in its cell (merge)
    float encH = gR2HiImpact > 0.5 ? txR2Lam.Load(int3(s, 0)).x : 0.0;   // PERF-4: review marker only
    c.imp = (splat && L.x < 0.3) ? 1.0 : ((encH > 0.5 && floor(encH) - 1.0 == gR2Frame) ? 2.0 : 0.0);
    if (abs(L.w + 7.0) < 0.5 && L.y <= 0 && L.x < 0.3) c.imp = 3.0;   // R2b: splash satellite < 0.3 s
    float thN = (L.w + 5.0) * 31.4159265;                          // direction to the parent at the split
    c.nk = float2(cos(thN), sin(thN));
    float vis = (splat || child) ? 1.0 : lerp(0.35, 1.0, smoothstep(0.0, max(gR2GrowTime, 1e-3), L.x));
    if (L.z > 0) vis *= saturate(L.z / max(gR2FadeTime, 1e-3));
    // rev48-S4c (S4b review: drawn sizes larger than the water made size / collision hard to judge): the
    // resting flatness f only shapes the PROFILE (contact angle / f^1.5, flat top) inside the drop's own
    // footprint; only the transient impact splat (same water spread thin, < 0.3 s) is wider than r.
    c.r *= vis * (c.f / fB) * r2VCapScale(r2VisorSeed(st.w), fB);   // R3: footprint of the drop's own cap
    c.q = float2(s) + st.xy;                                   // centre (cells); r2Cand makes it the pixel offset
    float shE = length(shS.xy);
    float shA = sqrt((0.5 + shE) / max(0.5 - shE, 0.05));                 // rev48-S1: aspect widens the reach
    // U2a: the lamella ellipse (Vt aspect, bounded by Vt/Vn 3) blends in by e -- continuous bound for reach / window
    float shAx = shA + c.e * max(min(1.0 + gR2ShpImpactK * 3.0, gR2ShpImpactMax) - shA, 0.0);
    rLeg = 1.3 * gR2KernelScale * c.r * sqrt(shAx) * 1.35 * 2.0
         + 0.5 * c.r * (1.0 - fB / c.f);                              // splat centre shifted upstream
    c.seed = r2VisorSeed(st.w);
    c.sh = shS;                                                // rev48-S1 shape state
    float2 mv = r2VisorMove(st.w) * gR2CellSizeMM;            // mm in the last frame
    float ml = length(mv);
    c.m = ml > 1e-4 ? mv / ml : float2(0, 0);
    float v = ml * 1e-3 / max(gR2SimDt, 1e-5);                 // m/s
    c.k = gR2MotionStretch * saturate(v / max(gR2VMax, 1e-3));
    // rev48-S3b (rev48_S3 recording: big splats / merged drops showed straight cut edges and 'tick' notches):
    // a drop is only drawn by pixels within +-2 cells of its own cell, so its whole kernel (aspect, contour
    // modes, bend, motion stretch, splat shift) must fit 2 cells (~2.3 mm). Larger visuals are scaled down to
    // that window instead of being cut; the physics footprint uses the same cap (common r2FootRadiusMM).
    float2 hmC = r2UnpackHarm(c.sh.z);
    float hF = min(1.0 + (max(hmC.x, 0.0) + hmC.y) * (1.0 - c.e) + gR2ShpFingerK * saturate(c.fx), 1.7);
    // rev48-R3b ASPECT-FIRST FIT (R3 review: two large drops merging became a small thin needle -- the merged
    // union ellipse, aspect up to 4.4, was fitted by shrinking the WHOLE drop): an over-long drop first gives up
    // elongation (aspect cap c.aMax, area kept = its water), and only a drop too big even when round shrinks.
    float base = gR2KernelScale * c.r * hF * (1.0 + c.k);
    float rest = 2.0 * c.sft + abs(bfS.x) * gR2KernelScale * c.r;
    float lWin = (win ? 4.0 : 2.0) * min(gR2CellSizeMM.x, gR2CellSizeMM.y) - 0.05;   // R7a big-drop window
    c.aMax = 100.0;
    if (base * sqrt(shAx) + rest > lWin) {
        float room = max(lWin - rest, 0.3 * lWin);
        float aF = (room / max(base, 1e-5)) * (room / max(base, 1e-5));
        if (aF >= 1.0) c.aMax = aF;
        else { c.aMax = 1.0; c.r *= lWin / (base + rest); }
    }
    // rev48-R6 FRAME STREAK (PHYSICS_AUDIT G): drops now move at their force-balance speed (no display cap), up to the
    // gather window per substep -- a fast drop is seen over the frame as the smear of its path: the rear stretches by
    // the frame's move (k = move / kernel radius), within the window that is left (no shrink for it).
    float kBlur = ml / max(gR2KernelScale * c.r, 1e-4);
    float kRoom = lWin / max(gR2KernelScale * c.r * hF * sqrt(min(shAx, c.aMax)), 1e-4) - 1.0;
    c.k = max(c.k, min(kBlur, max(kRoom, 0.0)));
    return true;
}

// Candidate drop of cell s for pixel pc (false = empty, other loop, or out of the rev48 reach + reachMM).
bool r2Cand(int2 s, float2 pc, int2 size, float reachMM, float wetV, bool bigPass, out R2Cand c) {
    c = (R2Cand)0;
    if (any(s < int2(0, 0)) || any(s >= size)) return false;
    float rLeg; bool win;
    if (!r2CandCore(s, c, rLeg, win) || win != bigPass) return false;
    c.q = (pc - c.q) * gR2CellSizeMM;
    float reach = rLeg + reachMM;
    return dot(c.q, c.q) <= reach * reach;
}

// PERF-7 TIGHT SUPPORT (2026-11-06; PERF-6 probe: the candidate loop is ~90 % of both visor passes, the lens ~3 %).
// r2Cand's reach (3.5 x the kernel radius) let ~10x the drop's footprint run the full r2AddDrop, which then leaves
// P / G / RW / HW untouched there (r2Kernel returns for h <= 0, i.e. x >= 1). This is a PROVEN bound on the offset
// |q| beyond which r2AddDrop cannot change anything -- r2AddDrop's chain run backwards (docs/RAINFX_V2_PERF_RESEARCH.md
// section 5, checked by docs/tools/check_tight_support.py on random drops):
//   kernel support    |q6| <  rkS dRm             dR <= (1 + |a2| + |a3|) (1 + finger), rkS = rk0 / sqrt(shA)
//   wobble squash     |q5| <= |q6| / (1 - A)      |s3| <= A along air.dir
//   rocking           |q4| <= |q5| + 0.3 A r
//   rear stretch      |q3| <= (1 + kk) |q4|       kk = max(motion k, sag, neck)
//   aspect + bend     |q1| <= shA |q3| + |bend| sqrt(shA) |q3|^2 / rk0
//   lamella shift     |q0| <= |q1| + 2 sft ;  D-A taps + reachMM
// Skipping a candidate beyond it is bit-identical (gR2TightReach 2 = verify: the candidate is still drawn, and a
// pixel where a skipped candidate DID contribute turns red).
float r2SupportCore(R2Cand c, float A, float reachMM) {   // A = the wobble amplitude of r2AddDrop (or a bound of it)
    float rk0 = gR2KernelScale * c.r;
    if (A >= 0.95) return 1e9;
    float kk = max(c.k, gR2SagK * saturate(c.r * c.r / 2.25) * (1.0 - c.e));
    if (c.ch >= 0.0 && c.ch < gR2ShpNeckT) kk = max(kk, gR2ShpNeckK * (1.0 - c.ch / max(gR2ShpNeckT, 1e-3)));
    kk = max(kk, 0.0);
    float fing = c.fx > 1e-3 ? max(gR2ShpFingerK, 0.0) * saturate(c.fx) : 0.0;
    float Y = 0.3 * A * c.r;
    float B;
    if (gR2ShpOn > 0.5) {
        float2 hm = r2UnpackHarm(c.sh.z);
        float X = rk0 * (1.0 + abs(hm.x) + abs(hm.y)) * (1.0 + fing) / (1.0 - A);
        float shE = length(c.sh.xy);
        float shA = min(sqrt((0.5 + shE) / max(0.5 - shE, 0.05)), c.aMax);
        if (c.e > 1e-3) {   // lamella blend: aspect <= max(drop, impact ellipse), capped at 4 / aMax as in r2AddDrop
            float aL = max(gR2ShpImpactMax, 1.0 / max(gR2ShpImpactMax, 1e-3));
            shA = min(min(max(shA, aL), 4.0), c.aMax);
        }
        shA = max(shA, 1.0);
        float sq = sqrt(shA);
        float bnd = abs(r2UnpackBF(c.sh.w).x);
        float k1 = 1.0 + kk;
        B = k1 * (X * sq + Y * shA) + bnd * k1 * k1 * (X + Y * sq) * (X + Y * sq) / max(rk0, 1e-6);
        if (c.e > 1e-3) B += 2.0 * abs(c.sft);
    } else {
        float X = rk0 * (1.0 + fing) / (1.0 - A);
        B = 1.22 * (1.0 + kk) * (X + Y);                     // seeded ellipse e1 <= 0.22
    }
    return (B + 1.5 * reachMM) * 1.002 + 1e-4;
}

