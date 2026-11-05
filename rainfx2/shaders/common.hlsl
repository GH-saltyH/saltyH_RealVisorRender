// RainFX v2 common code. Prepended to every v2 pass (CSP ui.fx / mesh.fx templates).
// Design: docs/RAINFX_CSP728_RE2_OPTIMAL_PLAN.md, docs/RAINFX_V2_CORE.md.
//
// Spaces:
//   tex uv  t = (U, V+1) in [0,1]^2, same convention as du/dv/mask Load().
//   cell    c = t * gR2Cells (one drop max per cell, int part = cell index).
// Metric: txR2Du/txR2Dv RGB = dP/dU, dP/dV in KN5 local metres per raw UV unit.
//   Local vectors go to world with mul(v, (float3x3)gR2ObjToWorld), the same
//   convention as the verified legacy solver (includes the profile scale).
//   Forces/velocities from Lua are WORLD vectors; all physics runs in world space.
// State texel (RGBA32F): x,y = position relative to the cell origin, z = volume mm^3,
//   ([0,1) after P1; the coalescence merge may leave it in [-0.75,1.75), P1 relocates),
//   w = shape seed + packed displacement of the last step (r2PackMove), exact in fp32.

#define R2_PI 3.14159265

// ---------- hashing (integer, frame-stable) ----------
uint r2Pcg(uint v) {
    uint s = v * 747796405u + 2891336453u;
    uint w = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
    return (w >> 22u) ^ w;
}
float r2Rand(uint3 k) {
    uint h = r2Pcg(k.x ^ r2Pcg(k.y ^ r2Pcg(k.z)));
    return float(h & 0x00ffffffu) / 16777216.0;
}

// ---------- geometry taps (nearest texel; never blend UV islands) ----------
float4 r2Tap(Texture2D tx, float2 t) {
    uint w = 1u, h = 1u;
    tx.GetDimensions(w, h);
    int2 p = clamp(int2(t * float2((float)w, (float)h)), int2(0, 0), int2((int)w - 1, (int)h - 1));
    return tx.Load(int3(p, 0));
}
float r2Valid(float2 t) {
    if (any(t < float2(0, 0)) || any(t > float2(1, 1))) return 0;
    if (r2Tap(txR2Du, t).a < 1.0) return 0;
    return r2Tap(txR2Mask, t).a >= 0.5 ? 1 : 0;
}
float3 r2ToWorld(float3 v) {
    return mul(v, (float3x3)gR2ObjToWorld);
}
// Baked object-space normal (outward, user-verified) -> world.
float3 r2Normal(float2 t) {
    float3 n = r2ToWorld(r2Tap(txR2Mask, t).xyz * 2.0 - 1.0);
    return n * rsqrt(max(dot(n, n), 1e-12));
}

// w = shape seed * 2^18 + displacement (cells, |d|<8) quantised below 2^18.
// rev8: the displacement is accumulated over the substeps of one frame (P2 field and
// the physics view run once per frame).
// rev40 (P0, docs/RAINFX_V2_DROP_SHAPE_RESEARCH.md): 16 -> 64 shape seeds; the displacement
// resolution 1/62.5 -> 1/31.25 cell (0.037 mm, only drives the motion stretch).
// The whole value stays an integer below 2^24, exact in fp32 (max 16 771 572).
#define R2_SEEDS 64.0
float r2PackMove(float2 d, float seed) {
    float2 q = round(clamp(d, -8.0, 8.0) * 31.25 + 250.0);   // 0..500
    return clamp(floor(seed), 0.0, R2_SEEDS - 1.0) * 262144.0 + q.x * 512.0 + q.y;
}
float r2UnpackSeed(float w) {
    return floor(w / 262144.0);
}
float2 r2UnpackMove(float w) {
    float m = w - r2UnpackSeed(w) * 262144.0;
    float qx = floor(m / 512.0);
    float qy = m - qx * 512.0;
    return (float2(qx, qy) - 250.0) / 31.25;
}

// rev48-R3 CAP VOLUME (docs/RAINFX_V2_PHYSICS_AUDIT.md C): a sessile drop is a spherical cap, V = K(theta) r^3,
// K = pi (2 - 3 cos + cos^3) / (3 sin^3). gR2ShapeK = K(contactDeg) (init.lua; rev7-R2 used the 90 deg hemisphere
// 2.094 while drawing 50-60 deg -> every drop drawn / collided / pinned 28-39 % too small in radius).
float r2CapK(float deg) {
    float t = tan(0.5 * radians(clamp(deg, 5.0, 90.0)));          // = pi (2 - 3c + c^3) / (3 s^3), h / a = tan(theta / 2)
    return 0.5235988 * t * (3.0 + t * t);
}
// M1: inverse (Cardano on t^3 + 3t - 6K/pi = 0): the cap angle (deg) of a volume factor K
float r2CapTheta(float K) {
    float q = 1.9098593 * max(K, 1e-4);
    float d = sqrt(0.25 * q * q + 1.0);
    float t = pow(abs(0.5 * q + d), 1.0 / 3.0) - pow(max(d - 0.5 * q, 1e-12), 1.0 / 3.0);
    return degrees(2.0 * atan(t));
}
// M1: the flatness f whose footprint (mean angle) covers rU while holding the volume of a radius-rm drop
float r2FlatForRadius(float rm, float rU) {
    float thD = r2CapTheta(gR2ShapeK * pow(saturate(rm / max(rU, 1e-5)), 3.0));
    return clamp(pow(abs(gR2ContactDeg) / max(thD, 1.0), 2.0 / 3.0), 1.0, 4.0);
}
float r2CapScaleMean(float f) {
    if (gR2CapVolume < 0.5) return 1.0;
    float thD = gR2ContactDeg / (f * sqrt(max(f, 1.0)));
    return clamp(pow(abs(gR2ShapeK / r2CapK(max(thD, 15.0))), 1.0 / 3.0), 0.8, 1.6);
}
// A drop's own contact angle: the per-drop spread (seed, = visor h2) lowered by its resting flatness f (profile
// theta / f^1.5, visor) -> the same water covers more: footprint scale (K(theta_mean) / K(theta_drop))^1/3.
float r2CapScale(float seed, float f) {   // R5b: the per-drop seed angle spread is gone (variation = position flatness)
    if (gR2CapVolume < 0.5) return 1.0;
    float thD = gR2ContactDeg / (f * sqrt(max(f, 1.0)));
    return clamp(pow(abs(gR2ShapeK / r2CapK(max(thD, 15.0))), 1.0 / 3.0), 0.8, 1.6);
}
// Drop radius (mm) from volume (mm^3). gR2ShapeK = V / r^3 for the contact angle.
float r2RadiusMM(float volMM3) {
    return volMM3 > 0 ? exp2(log2(volMM3 / gR2ShapeK) * (1.0 / 3.0)) : 0.0;
}

// Rain exposure of the exterior side: rain travelling against the outward normal.
// gR2NormalSign = -1 only as a manual override.
// rev47b (rev47 review: near-vertical visor at rest always read 'deep blue'): rain arrives in a cone
// (turbulence / gusts, sigma ~ gR2RainSpreadS = sin(spread)), so the projected flux is the cosine
// smoothed over the cone: E(x) = (x + sqrt(x^2 + s^2)) / 2 (analytic soft-plus of the cosine).
float r2Exposure(float2 t) {
    float x = dot(gR2RainDirW, -r2Normal(t)) * gR2NormalSign + gR2ExposureFloor;
    return saturate(0.5 * (x + sqrt(x * x + gR2RainSpreadS * gR2RainSpreadS)));
}

// Tangential surface airflow speed (m/s) at t.
float r2AirTangent(float3 n) {
    float3 a = gR2AirW - n * dot(gR2AirW, n);
    return length(a) * gR2AirSurface;
}

float r2Hash21(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
float r2VNoise(float2 p) {
    float2 i = floor(p), f = p - i;
    f = f * f * (3.0 - 2.0 * f);
    return lerp(lerp(r2Hash21(i), r2Hash21(i + float2(1, 0)), f.x),
                lerp(r2Hash21(i + float2(0, 1)), r2Hash21(i + float2(1, 1)), f.x), f.y);
}
// rev48-S6 F1 SURFACE DEFECTS (docs/RAINFX_V2_SHAPE_STATE_PLAN.md sections 18-20; stick-slip on heterogeneous
// coatings, Varagnolo et al. PRL 2013): a static field D in [0, 1] on the visor (features of defMM, mm space).
float r2Defect(float2 pMM) {
    return r2VNoise(pMM * gR2DefInvMM + float2(31.7, 11.3));
}

// Drop velocity in tex-uv per second. Memoryless terminal-velocity model:
// gravity+inertia and air drag against contact-angle hysteresis (pinning).
// Mirrored 1:1 by rainfx2/physics.lua (P.forces / P.speed) for review and diagnostics.
// rev41: drive = Fpin / |F| of a moving drop (1 = just depinned, -> 0 = driven far above pinning);
// the path heterogeneity (r2Steer) scales with it: weakly driven drops meander, strongly driven
// drops follow the force in nearly straight lines.
float2 r2DropVelocity(float2 t, float radiusMM, float pinNoise, float4 sh, out float speed, out float drive) {
    speed = 0;
    drive = 1;
    float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
    float4 dvA = r2Tap(txR2Dv, t);
    float3 dv = r2ToWorld(dvA.xyz);
    float3 n = r2Normal(t);
    float r = radiusMM * 1e-3;
    float mass = 1e-6 * gR2ShapeK * radiusMM * radiusMM * radiusMM;     // kg (mm^3 * 1e-9 * 1000)
    float3 g = gR2AccelW - n * dot(gR2AccelW, n);
    // rev47 helmet aerodynamics (docs/RAINFX_V2_REV46_REVIEW.md section 3; mirrored by physics.lua
    // P.aeroForces). rev7-46 used the projected relative air x 0.15: zero at the stagnation point, so
    // drops facing the air never moved (rev46 review). Now: helmet ~ sphere, outer flow
    // u_e = 1.5 kU U sin(theta) away from the stagnation point (gR2AeroDirW includes its elevation and
    // the buffeting wander), the drop top sees it through the thin stagnation boundary layer
    // (delta 0.3-0.7 mm), and the pressure gradient V rho u_e du_e/ds pushes the drop outward.
    float3 ah = gR2AeroDirW;
    float cn = -dot(n, ah);                                     // cos(theta), facing the oncoming air
    float3 ue = (ah - n * dot(ah, n)) * (gR2AeroU * smoothstep(-0.1, 0.2, cn));   // lee side separated
    // rev48-F4 SIZE LAW OF THE AIR LOAD (F3 review + reference 'verySmallWFSize_dryFlow', Light Drizzle, F1 helmet cam:
    // drops of ~0.3-0.4 mm start to move at 137-162 km/h, half that size at 162-192, fine dots at 180-220). R6b used
    // a quadratic drag with ONE Cd calibrated on a 10 uL drop and the laminar boundary-layer attenuation x(2 - x):
    // the load fell as r^4 below the BL (0.4-0.5 mm) -> r_c 0.6-1.2 mm at 200-250 km/h, small drops never moved.
    // Wind-tunnel shedding is reported as a critical outer air speed per drop volume with a WEAK size dependence
    // (Milne & Amirfazli 2009; White & Schmucker 2008; Fu et al. 2014: U_c ~ V^-0.1..-0.25): the drop sits in the
    // wall layer of every experiment, so the law already holds the boundary-layer and shape effects. Here:
    //   U_c(V) = shedU10 (V / 10 uL)^-shedBeta,   F_air = 2 gamma r dcos_coat (u_e / U_c)^2  (= the coat pinning at U_c)
    // F4b fit to the reference frames (shedU10 25, shedBeta 0.08): U_c 34 / 42 / 47 m/s for r 0.6 / 0.25 / 0.15 mm (theta 45:
    // ~143 / 177 / 200 km/h = 3rd / 4th / 5th gear), 25 m/s for r 2 mm (static at 100 km/h). Past depinning the sliding
    // speed (F - Fpin) / (0.3 r) = 0.087 ((u / U_c)^2 - 0.9 pin) m/s is size-free: small drops just above U_c crawl.
    float uLen = length(ue);
    float Vul = gR2ShapeK * radiusMM * radiusMM * radiusMM;                  // mm^3 = uL
    float Uc = gR2ShedU10 * pow(max(Vul * 0.1, 1e-7), -gR2ShedBeta);
    // F5 (F4b review: running drops far faster than the reference): the rev47 pressure-gradient push V rho u_e du_e/ds
    // (~ r^3: 4.5 x the coat pinning for r 2 mm at 200 km/h) is removed -- the measured U_c(V) already holds every air load
    float3 Fa = (gR2SurfaceTension * 2.0 * r * gR2PinCoat * uLen / (Uc * Uc)) * ue;
    float3 F = mass * g + Fa;
    float Fm = length(F);
    float pinCos = lerp(gR2PinGlass, gR2PinCoat, saturate(dvA.a));
    float Fpin = gR2SurfaceTension * 2.0 * r * pinCos * pinNoise;
    // rev48-S7 FURMIDGE WIDTH (docs/RAINFX_V2_SHAPE_STATE_PLAN.md section 22): the retention force is
    // gamma w (cos theta_r - cos theta_a) with w = the contact width ACROSS the force. rev7-S6 used w = 2r for
    // every shape. With the footprint ellipse (aspect A, axis u1): w / 2r = 1 / sqrt(c^2 / A + A (1 - c^2)),
    // c = cos(angle between the cross-force direction and u1) -> a drop long along the force (gravity sag,
    // slug, runback head) is held less, one long across it (air stretch at right angles) more.
    // Footprint aspect is area-preserving (S4c), so the drive (volume) is unchanged.
    float a0 = dot(du, du), b0 = dot(du, dv), c0 = dot(dv, dv);
    float det0 = max(a0 * c0 - b0 * b0, 1e-20);
    float pu0 = dot(du, F), pv0 = dot(dv, F);
    float2 fMM = float2(c0 * pu0 - b0 * pv0, a0 * pv0 - b0 * pu0) / det0 * (gR2CellSizeMM * gR2Cells);
    float eW = length(sh.xy);
    if (gR2ShpOn > 0.5 && gR2FootPinK > 0.0 && eW > 1e-3 && dot(fMM, fMM) > 1e-20) {
        float AW = sqrt((0.5 + eW) / max(0.5 - eW, 0.05));
        float phiW = 0.5 * atan2(sh.y, sh.x);
        float2 fd = normalize(fMM);
        float cW = dot(float2(-fd.y, fd.x), float2(cos(phiW), sin(phiW)));
        float wf = rsqrt(cW * cW / AW + AW * (1.0 - cW * cW));
        Fpin *= lerp(1.0, clamp(wf, 0.6, 1.6), gR2FootPinK);
    }
    if (Fm <= Fpin) return float2(0, 0);
    drive = Fpin / max(Fm, 1e-12);
    // rev48-R6 (docs/RAINFX_V2_PHYSICS_AUDIT.md G): ONE force balance for every unpinned drop -- the quasi-steady
    // contact-line friction speed v = (F - Fpin) / (friction r) (Kim, Lee & Kang 2002; Le Grand 2005), air and
    // gravity alike. A drop the air loads hard RUNS BACK along the surface (Milne & Amirfazli 2009) and leaves the
    // visor over its edge; nothing lifts off mid-visor. rev42-47l display caps removed: creep saturation vMax / vScale,
    // runbackK / runbackMax, the blow-off threshold shedK and the lift-off flight (liftMM, fly*). A fast drop moves
    // up to the gather window per substep (r2Predict) and is drawn as its frame streak (visor R6 blur), not capped.
    float vq = (Fm - Fpin) / (gR2Friction * max(r, 1e-5));
    speed = vq;
    float3 v = F * (speed / Fm);
    float a = dot(du, du), b = dot(du, dv), c = dot(dv, dv);
    float det = max(a * c - b * b, 1e-20);
    float pu = dot(du, v), pv = dot(dv, v);
    return float2(c * pu - b * pv, a * pv - b * pu) / det;
}

// rev11 water film (sheet W): mean velocity of a thin film (tex-uv per second).
// Couette shear by the air above it + gravity drainage (lubrication theory):
//   v = tau * h / (2 mu) + rho_w * g_t * h^2 / (3 mu),  tau = 0.5 rho_air Cf |u| u
// Mirrored by rainfx2/physics.lua P.filmVelocity.
float2 r2FilmVelocity(float2 t, float hMM) {
    float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
    float3 dv = r2ToWorld(r2Tap(txR2Dv, t).xyz);
    float3 n = r2Normal(t);
    float3 g = gR2AccelW - n * dot(gR2AccelW, n);
    float3 air = (gR2AirW - n * dot(gR2AirW, n)) * gR2AirSurface;
    float h = hMM * 1e-3;
    float3 tau = (0.5 * gR2RhoAir * gR2FilmCf * length(air)) * air;
    float3 v = (tau * (h / 2e-3) + g * (1000.0 * h * h / 3e-3)) * gR2FilmFlowK;
    float vl = length(v);
    if (vl > 1.0) v *= 1.0 / vl;
    float a = dot(du, du), b = dot(du, dv), c = dot(dv, dv);
    float det = max(a * c - b * b, 1e-20);
    float pu = dot(du, v), pv = dot(dv, v);
    return float2(c * pu - b * pv, a * pv - b * pu) / det;
}

// rev21 path heterogeneity (CSP windscreen rule, docs/RAINFX_V2_DROP_SIZE_RESEARCH.md section 4):
// surface value noise turns the path (pinning defects), and a moving drop steers toward the wetter
// side of earlier traces ahead (rivulets form). Speed is kept; only the direction turns.
// Depends on position only -> identical in every gathering cell.
// rev41 (rev40 review: "lightning" zig-zag at 100-300 km/h): the turn is SMOOTH noise (rev21 used
// sign kicks -> abrupt +-19 deg switches every few mm), both terms scale with drive = Fpin/|F|
// (strongly driven drops run straight), and the total turn is capped at 0.5 (27 deg).
// rev48-S6b F1: + the defect asymmetry across the HEAD. defSteer (mm-space vector, from r2Predict) points to
// the weaker side with length defK defPin |D_left - D_right| / sqrt(max(1, 2r / defMM)): the lateral share of
// the pinning force over the drive (x drive below), a wide contact line averaging more defects.
// rev48-S6 used defK 2 r (grad D . side): |lat| 5-18 -> the +-0.5 clamp was hit ~80 % of the time and the
// heading jumped +-27 deg at every defect (rev48_S6 review: exaggerated weaving).
float2 r2Steer(float2 t, float2 vt, float drive, float2 defSteer) {
    float2 texMM = gR2CellSizeMM * gR2Cells;
    float2 vm = vt * texMM;                                   // mm/s on the visor
    float sp = length(vm);
    float2 res = vt;
    if (sp > 1e-3 && (gR2TrailFollow > 0 || gR2DefK > 0 || gR2SheetOn > 0.5)) {   // C-clean: meander (rev21) removed
        float2 dir = vm / sp;
        float2 side = float2(-dir.y, dir.x);
        float2 ahead = t + dir * (1.5 / texMM);
        float tl = txR2Field.SampleLevel(samLinearClamp, ahead + side * (1.0 / texMM), 0).r;
        float tr = txR2Field.SampleLevel(samLinearClamp, ahead - side * (1.0 / texMM), 0).r;
        // rev48-W1t WATER PATHS (CSP pfxWindscreen_cs_simulate steers drops along the blurred water-map gradient): a running
        // drop turns toward the thicker sheet / film beside its path -- drainage gathers into the existing flows
        float bl = txR2Field.SampleLevel(samLinearClamp, ahead + side * (2.0 / texMM), 0).b;
        float br = txR2Field.SampleLevel(samLinearClamp, ahead - side * (2.0 / texMM), 0).b;
        float wf = gR2SheetOn > 0.5 ? gR2SheetFollowK * (bl - br) * gR2FilmMaxMM / 0.1 : 0.0;
        float lat = clamp((dot(defSteer, side) + gR2TrailFollow * (tl - tr) + wf) * saturate(drive), -0.5, 0.5);
        res = normalize(dir + side * lat) * sp / texMM;
    }
    return res;
}

// rev45 LIFE CYCLE (step 3, docs/RAINFX_V2_DROP_PHYSICS_MODEL.md section 6 B): the state texture is
// twice the cell width; the right half holds per-drop L = (age s, flight time left s, fade time left s,
// flight direction rad). The cells / merge / seed passes write both halves with the same gather, so
// L always follows its drop. Visible effect (visor): drops grow in, fade out when a splash sweeps
// them, and a blown-off drop flies off for a few frames as a stretched streak that leaves a trail,
// instead of popping in / vanishing (rev43-44 'ticking').
float4 r2Life(int2 s) {
    return txR2State.Load(int3(s + int2((int)gR2Cells.x, 0), 0));
}

// ---------- rev48-S1 SHAPE STATE (docs/RAINFX_V2_SHAPE_STATE_PLAN.md) ----------
// The state texture is three cell widths: [drop | life | shape]. Shape texel per drop:
//   x, y = contact-line tensor anisotropy (m1, m2) = e (cos 2phi, sin 2phi), unit-trace second moments
//          M = I/2 + [[m1, m2], [m2, -m1]] -> aspect A = sqrt((0.5 + e) / (0.5 - e)), major axis phi (visor mm)
//   z    = packed contour harmonics: a2 (along the major axis; > 0.2 = peanut waist), a3 (Y / triangle)
//   w    = bend (offset of the major-axis ends across, x minor half-length; banana / S along a path)
//          rev48-S4: packed with the drop's own resting spread f (flatness memory), r2PackBF; w >= 0 = legacy bend
// One analytic kernel draws round, oval, sagging, bent, lobed drops from these 4 numbers (visor r2AddDrop).
float4 r2Shape(int2 s) {
    return txR2State.Load(int3(s + int2(2 * (int)gR2Cells.x, 0), 0));
}
// rev48-R5b: + the 3-fold contour PHASE (visor angle of a lobe, 16 steps over 120 deg; was the per-drop seed hash):
// z = (a2q 1024 + a3q) 16 + pq < 2^24 (exact in fp32)
float r2PackHarm3(float a2, float a3, float ph) {
    float pq = fmod(round(frac(ph * 0.47746483) * 16.0), 16.0);          // ph / (2 pi / 3)
    return (round(clamp(a2, -0.5, 0.5) * 1000.0 + 500.0) * 1024.0 + round(clamp(a3, 0.0, 0.5) * 2000.0)) * 16.0 + pq;
}
float r2PackHarm(float a2, float a3) { return r2PackHarm3(a2, a3, 0.0); }
float2 r2UnpackHarm(float z) {
    float r = floor(z / 16.0);
    float hi = floor(r / 1024.0);
    return float2(hi / 1000.0 - 0.5, (r - hi * 1024.0) / 2000.0);
}
float r2UnpackHarmPh(float z) {
    return (z - 16.0 * floor(z / 16.0)) * 0.13089969;                     // (2 pi / 3) / 16
}
// rev48-S4 bend + resting spread in one fp32: w = -(1 + qb 4096 + qf), qb = bend 250 + 500, qf = (f - 1) 1000
// rev48-S6b bend MODE (+1024 x mode on the bend code, < 2^24): 0 = symmetric bow (births, merges: banana / S),
// 1 = HOOK at the +u1 end, 2 = hook at the -u1 end (a turning slide: the head half bends onto the new heading,
// the tail half stays on the old path).
float r2PackBFM(float bend, float f, float mode) {
    return -(1.0 + (round(clamp(bend, -2.0, 2.0) * 250.0 + 500.0) + 1024.0 * mode) * 4096.0 + round(clamp(f - 1.0, 0.0, 3.0) * 1000.0));
}
float r2PackBF(float bend, float f) {
    return r2PackBFM(bend, f, 0.0);
}
float r2UnpackBMode(float w) {
    return w >= 0.0 ? 0.0 : floor(floor((-w - 1.0) / 4096.0) / 1024.0);
}
float2 r2UnpackBF(float w) {
    if (w >= 0.0) return float2(w, 1.0);                 // legacy (rev48-S1..S3b): bend only
    float v = -w - 1.0;
    float qr = floor(v / 4096.0);
    float qb = qr - 1024.0 * floor(qr / 1024.0);
    return float2((qb - 500.0) / 250.0, 1.0 + (v - qr * 4096.0) / 1000.0);
}
// rev48-S2c rule, now evaluated ONCE per drop (birth / equilibrium) with a per-drop hash h instead of the
// cell index (S3b review: the cell-index hash re-rolled a moving drop's flatness at every cell crossing).
// rev48-R5b: the local pinning strength (same smooth field as r2Predict / R1 arrest) in place of per-drop hashes
float r2PinAt(float2 t) { return r2VNoise(t * gR2PinScale + 53.1); }
float r2RestEq(float rmm, float h, float wet) {
    return max(gR2BaseSpread, 1.0) + gR2SpreadVarK * smoothstep(gR2SpreadR0, gR2SpreadR1, rmm)
         * (0.35 + 0.65 * h) * (1.0 + gR2SpreadWetK * wet);
}
float4 r2ShapeMake3(float A, float phi, float a2, float a3, float ph3, float bend, float f) {
    float A2 = A * A;
    float e = min(0.5 * (A2 - 1.0) / (A2 + 1.0), 0.45);
    return float4(e * cos(2.0 * phi), e * sin(2.0 * phi), r2PackHarm3(a2, a3, ph3), r2PackBF(bend, f));
}
float4 r2ShapeMake(float A, float phi, float a2, float a3, float bend, float f) {
    return r2ShapeMake3(A, phi, a2, a3, 0.0, bend, f);
}
// Tangential gravity direction at t in visor mm (for sagging births).
float2 r2GravDirMM(float2 t) {
    float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
    float3 dv = r2ToWorld(r2Tap(txR2Dv, t).xyz);
    float3 n = r2Normal(t);
    float3 g = gR2AccelW - n * dot(gR2AccelW, n);
    float a = dot(du, du), b = dot(du, dv), c = dot(dv, dv);
    float det = max(a * c - b * b, 1e-20);
    float2 uv = float2(c * dot(du, g) - b * dot(dv, g), a * dot(dv, g) - b * dot(du, g)) / det;
    float2 mm = uv * gR2CellSizeMM * gR2Cells;
    return dot(mm, mm) > 1e-12 ? normalize(mm) : float2(0, 1);
}
// rev48-S5 E7: tangential gravity at t -- (direction in visor mm, |g_t| / 9.81)
float3 r2GravInfo(float2 t) {
    float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
    float3 dv = r2ToWorld(r2Tap(txR2Dv, t).xyz);
    float3 n = r2Normal(t);
    float3 g = gR2AccelW - n * dot(gR2AccelW, n);
    float a = dot(du, du), b = dot(du, dv), c = dot(dv, dv);
    float det = max(a * c - b * b, 1e-20);
    float2 uv = float2(c * dot(du, g) - b * dot(dv, g), a * dot(dv, g) - b * dot(du, g)) / det;
    float2 mm = uv * gR2CellSizeMM * gR2Cells;
    return float3(dot(mm, mm) > 1e-12 ? normalize(mm) : float2(0, 1), length(g) / 9.81);
}
// rev48-F5: the helmet OUTER air at t (the U_c(V) law's speed, r2DropVelocity) -- (direction in visor mm, u_e m/s)
float3 r2AirOuterInfo(float2 t) {
    float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
    float3 dv = r2ToWorld(r2Tap(txR2Dv, t).xyz);
    float3 n = r2Normal(t);
    float3 ah = gR2AeroDirW;
    float cn = -dot(n, ah);
    float3 ue = (ah - n * dot(ah, n)) * (gR2AeroU * smoothstep(-0.1, 0.2, cn));
    float a = dot(du, du), b = dot(du, dv), c = dot(dv, dv);
    float det = max(a * c - b * b, 1e-20);
    float2 uv = float2(c * dot(du, ue) - b * dot(dv, ue), a * dot(dv, ue) - b * dot(du, ue)) / det;
    float2 mm = uv * gR2CellSizeMM * gR2Cells;
    return float3(dot(mm, mm) > 1e-12 ? normalize(mm) : float2(1, 0), length(ue));
}
// rev48-S5 E6: the helmet air at a drop's top (same law as r2DropVelocity) -- (direction in visor mm, u_top m/s)
float3 r2AirTopInfo(float2 t, float rmm) {
    float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
    float3 dv = r2ToWorld(r2Tap(txR2Dv, t).xyz);
    float3 n = r2Normal(t);
    float3 ah = gR2AeroDirW;
    float cn = -dot(n, ah);
    float3 ue = (ah - n * dot(ah, n)) * (gR2AeroU * smoothstep(-0.1, 0.2, cn));
    float xb = 0.6 * rmm / max(gR2BLDeltaMM, 1e-3);
    float3 air = ue * (xb < 1.0 ? xb * (2.0 - xb) : 1.0);
    float a = dot(du, du), b = dot(du, dv), c = dot(dv, dv);
    float det = max(a * c - b * b, 1e-20);
    float2 uv = float2(c * dot(du, air) - b * dot(dv, air), a * dot(dv, air) - b * dot(du, air)) / det;
    float2 mm = uv * gR2CellSizeMM * gR2Cells;
    return float3(dot(mm, mm) > 1e-12 ? normalize(mm) : float2(1, 0), length(air));
}
// rev48-R5 DEFECT CONTOUR (docs/RAINFX_V2_PHYSICS_AUDIT.md F; replaces the S1 random classes bent / lobed / sag
// shpBendP / shpLobeP / shpSagP): a resting contact line is held where the surface pins it -- the line sits further out
// on a strongly pinning spot (Joanny & de Gennes 1984: the line deformation follows the heterogeneity). The surface
// defect field r2Defect (F1, same field that steers / stick-slips moving drops) is sampled at 8 points on the
// footprint circle; the radius perturbation dr / R = shpDefShape x defPin x (2 D - 1) gives the contour's Fourier modes:
// mode 2 -> the ellipse (aspect (1 + a) / (1 - a), axis), mode 3 -> the 3-fold amplitude. A drop smaller than the
// defect scale (defMM) samples a nearly uniform patch and stays round; a large one is irregular -- and two drops born
// on the same spot get the same tendency (no re-rolled look).
float4 r2DefectModes(float2 pMM, float R) {
    float2 c2 = float2(0, 0), c3 = float2(0, 0);
    [unroll] for (int j = 0; j < 8; ++j) {
        float th = 0.78539816 * (float)j;
        float dj = 2.0 * r2Defect(pMM + R * float2(cos(th), sin(th))) - 1.0;
        c2 += dj * float2(cos(2.0 * th), sin(2.0 * th));
        c3 += dj * float2(cos(3.0 * th), sin(3.0 * th));
    }
    float k = 0.25 * gR2ShpDefShape * gR2DefPin;                      // 2 / N Fourier normalisation x amplitude
    return float4(c2 * k, length(c3) * k, atan2(c3.y, c3.x) / 3.0);  // (a2 cos, a2 sin) of the radius, |a3|, lobe angle
}
float4 r2ShapeBirth(uint2 c, uint k, float rmm, float2 t, float wet) {
    if (gR2ShpOn < 0.5) return float4(0, 0, r2PackHarm(0, 0), 0);
    float fEq = r2RestEq(rmm, r2PinAt(t), wet);                      // R5b: resting flatness from the local pinning
    float4 dm = r2DefectModes(t * gR2CellSizeMM * gR2Cells, rmm * r2CapScaleMean(fEq));
    float a = min(length(dm.xy), 0.45);
    float A = (1.0 + a) / (1.0 - a);
    float phi = 0.5 * atan2(dm.y, dm.x);
    return r2ShapeMake3(A, phi, 0.0, min(dm.z, 0.3), dm.w, 0.0, fEq);
}
// rev48-S2 OBLIQUE IMPACT geometry at t (docs/RAINFX_V2_SHAPE_STATE_PLAN.md sections 2-3): the relative
// rain velocity splits into the normal part Vn (spreading, splash) and the tangential part Vt, which
// stretches the lamella DOWNSTREAM. Returns (unit Vt direction in visor mm, aspect A, Vt / Vn).
//   A = min(1 + shpImpactK Vt / Vn, shpImpactMax): at rest on a near-vertical visor (incidence 70-85 deg,
//   Vt/Vn 3-10) A -> 3 along the fall; at speed (10-25 deg) A ~ 1.1.
float4 r2ImpactGeom(float2 t) {
    float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
    float3 dv = r2ToWorld(r2Tap(txR2Dv, t).xyz);
    float3 n = r2Normal(t) * gR2NormalSign;
    float3 v = gR2RainDirW * gR2SpeedRel;
    float vn = max(dot(v, -n), 0.05 * gR2SpeedRel + 1e-3);
    float3 vt = v - n * dot(v, n);
    float a = dot(du, du), b = dot(du, dv), c = dot(dv, dv);
    float det = max(a * c - b * b, 1e-20);
    float2 uv = float2(c * dot(du, vt) - b * dot(dv, vt), a * dot(dv, vt) - b * dot(du, vt)) / det;
    float2 mm = uv * gR2CellSizeMM * gR2Cells;
    float ratio = length(vt) / vn;
    float2 dir = dot(mm, mm) > 1e-12 ? normalize(mm) : float2(0, 1);
    return float4(dir, min(1.0 + gR2ShpImpactK * ratio, gR2ShpImpactMax), ratio);
}
// rev48-U2 SPLAT RECOIL / BIRTH STICKING (docs/RAINFX_V2_UNIFIED_IMPACT_PLAN.md section 5).
// rev48-R1 (docs/RAINFX_V2_PHYSICS_AUDIT.md A): the lamella recoils at a material rate independent of the impact
// speed (Bartolo, Josserand & Bonn 2005, capillary-inertial): tau = shpRecoilC sqrt(rho r^3 / gamma), r = the drop's
// radius -- ~11 ms for 1 mm at 3 x 3.7 ms, i.e. within ONE frame (U2's 0.12 s was a 10-50x slow motion). A low
// receding angle drives the receding line more weakly (Cox-Voinov ~ theta^3 -> x (50 / theta_r)^1.5).
float r2SplatTau(float rmm) {
    float tc = sqrt(1000.0 * pow(max(rmm, 0.05) * 1e-3, 3.0) / 0.072);
    return clamp(gR2ShpRecoilC * tc * pow(50.0 / clamp(gR2SheetRecedeDeg, 15.0, 100.0), 1.5), 0.004, 0.3);
}
// The residual's downstream travel over the recoil (mm): an oblique lamella carries its mass in the downstream rim
// (Vt stretched), so the drop that gathers from it sits downstream of the impact point.
// (visor: same law, per pixel Vt / Vn)
float r2SplatShiftMM(float rmm, float f0, float4 ig) { return gR2ShpLamShift * rmm * max(f0 - 1.0, 0.0) * min(1.0 + ig.w, 2.0); }
// Impact birth shape: elongated along Vt (aspect between 0.6 and 1 of the lamella's), weak contour modes
// (fingers relax or detach as satellites); a share keeps the S1 bent / lobed classes until S3 forms them.
// rev48-S4 ARREST (user: the mid-recoil splat frames are the best drops -- keep such states): the receding rim
// of a splat is stopped by pinning somewhere between the full spread f0 and the drop's equilibrium; the
// arrested fraction (R1: from the local receding angle) sets the drop's remembered flatness f, its kept oblique aspect and its
// kept contour irregularity. The visor recoils from f0 to this f, which then stays (r2ShapeRelax holds it).
// rev48-S5 E1: the arrest follows the LOCAL pinning (pinning heterogeneity field, same as r2Predict): a
// strongly pinned spot stops the receding rim early (stays wide / flat / irregular), a slippery spot lets it
// recoil to a compact drop. kSplash = K / K0 of the impact: a splashing lamella leaves torn, lobed rims.
float4 r2ShapeImpact(uint2 c, uint k, float rmm, float2 t, float4 ig, float wet, float f0, float kSplash) {
    if (gR2ShpOn < 0.5) return float4(0, 0, r2PackHarm(0, 0), 0);
    float fEq = r2RestEq(rmm, r2PinAt(t), wet);                      // R5b
    // rev48-R1 PHYSICAL ARREST (PHYSICS_AUDIT A; replaces S4 shpArrest u^2): the receding rim stops where the drop's
    // angle reaches the LOCAL receding angle -- profile angle contactDeg / f^1.5 = theta_r,loc -> f = (contactDeg /
    // theta_r,loc)^(2/3), between the drop's equilibrium and the full spread. theta_r,loc follows the pinning field
    // (+-25 %: a strongly pinned spot holds a wider, flatter splat). A dirty / worn visor (low theta_r) keeps flat
    // wide splats, a fresh coat recoils to compact drops. The cap volume (R3) turns the kept flatness into a WIDER
    // footprint of the same water.
    float pinN = r2VNoise(t * gR2PinScale + 53.1);
    float thRl = clamp(gR2SheetRecedeDeg * (1.25 - 0.5 * pinN), 10.0, 100.0);
    float fA = clamp(pow(max(gR2ContactDeg / thRl, 1e-3), 2.0 / 3.0), fEq, max(f0, fEq));
    float ar = saturate((fA - fEq) / max(f0 - fEq, 1e-3));          // kept share of the spread (0 recoiled .. 1 none)
    // R5: the arrested footprint keeps (0.3 + 0.7 ar) of the lamella's Vt elongation, and its contour follows the
    // defects under the arrested rim (r2DefectModes at the arrested radius): the two anisotropies add (S5 E7 rule).
    // A splashing lamella leaves a torn rim (shpTearK x log2 K/K0). The S2 random terms (a2 0.08 u, a3 0.06 u) are gone.
    float Av = 1.0 + (ig.z - 1.0) * (0.3 + 0.7 * ar);
    float ev = 0.5 * (Av * Av - 1.0) / (Av * Av + 1.0);
    float phiV = atan2(ig.y, ig.x);
    float4 dm = r2DefectModes(t * gR2CellSizeMM * gR2Cells, rmm * r2CapScaleMean(fA));
    float ad = min(length(dm.xy), 0.45);
    float Ad = (1.0 + ad) / (1.0 - ad);
    float2 m = ev * float2(cos(2.0 * phiV), sin(2.0 * phiV))
             + 0.5 * (Ad * Ad - 1.0) / (Ad * Ad + 1.0) * (length(dm.xy) > 1e-6 ? normalize(dm.xy) : float2(0, 0));
    float em = min(length(m), 0.45);
    float A = sqrt((0.5 + em) / max(0.5 - em, 0.05));
    float phi = 0.5 * atan2(m.y, m.x);
    float a3 = min(dm.z + gR2ShpTearK * saturate(log2(max(kSplash, 1.0)) / 3.0) * (0.5 + 0.5 * ar), 0.3);
    return r2ShapeMake3(A, phi, 0.0, a3, dm.w, 0.0, fA);
}

// ---------- rev48-S3b PHYSICS FOOTPRINT = VISUAL FOOTPRINT ----------
// (rev48_S3 review: drops drawn larger by the resting spread (S2c) and the merged tensor (S3) merged only at
// their old, smaller physics radius -- visibly overlapping drops did not coalesce.) Same rule as the visor
// r2Cand: resting spread f (size, per-drop hash, wetness) x the tensor ellipse radius toward dirMM, capped
// by the +-2 cell draw window. Used by the coalescence claim.
// rev48-R7a big-drop tiles (big.hlsl): the tile winner is drawn / touches in a +-4 cell window, others in +-2
bool r2BigWinner(int2 s) {
    if (gR2BigOn < 0.5) return false;
    float4 b = txR2Big.Load(int3((uint2)s >> 2, 0));
    return b.z > 0.5 && all(int2(round(b.xy)) == s);
}
float r2WinMM(bool big) {
    return (big ? 4.0 : 2.0) * min(gR2CellSizeMM.x, gR2CellSizeMM.y) - 0.05;
}
float r2FootRadiusMM(int2 s, float4 st, float4 sh, float wet, float2 dirMM) {
    float r = r2RadiusMM(st.z);
    if (gR2ShpOn < 0.5 || gR2FootPhys < 0.5) return r;
    float2 bf = r2UnpackBF(sh.w);
    float R = r * r2CapScale(r2UnpackSeed(st.w), max(max(bf.y, gR2BaseSpread), 1.0));   // R3: same water, own angle
    float e = length(sh.xy);
    float A = sqrt((0.5 + e) / max(0.5 - e, 0.05));
    float2 hm = r2UnpackHarm(sh.z);
    float hF = min(1.0 + max(hm.x, 0.0) + hm.y, 1.7);
    // R3b: aspect-first fit (= visor r2Cand): an over-long footprint loses elongation, keeps its area
    float base = 1.24 * R * hF, rest = abs(bf.x) * 1.24 * R;
    float lWin = r2WinMM(r2BigWinner(s));
    if (base * sqrt(A) + rest > lWin) {
        float room = max(lWin - rest, 0.3 * lWin);
        float aF = (room / max(base, 1e-5)) * (room / max(base, 1e-5));
        if (aF >= 1.0) A = min(A, aF);
        else { A = 1.0; R *= lWin / (base + rest); }
    }
    float phi = 0.5 * atan2(sh.y, sh.x);
    float dl = length(dirMM);
    float cs = dl > 1e-6 ? dot(dirMM / dl, float2(cos(phi), sin(phi))) : 1.0;
    return R / sqrt(cs * cs / A + A * (1.0 - cs * cs));
}

// ---------- rev48-S3 MERGED FOOTPRINT (docs/RAINFX_V2_SHAPE_STATE_PLAN.md section 13) ----------
// Coalescing drops keep their union footprint for a while (contact lines stay pinned): the merged drop's
// second-moment tensor is the volume-weighted sum of each contributor's own tensor (r^2/2 (I/2 + M_i)) plus
// its offset from the common centroid (parallel axis). Accumulate per contributor (positions in mm in any
// common frame), then compose: anisotropy = deviatoric part / trace, the major axis runs along the merge
// line; two comparable drops add a peanut waist (a2 along the major axis), the largest keeps its contour.
// rev48-S4b (S4 review: a moving head that touched a larger-LOOKING drop ahead removed it in one frame and
// survived alone): the weights are FOOTPRINT AREAS (r f)^2, not volumes. Physically the water of the touching
// pair flows toward the footprint of lower Laplace pressure -- the wider, flatter (pinned) one -- so the
// merged drop sits where the larger footprint was, takes its seed / life / shape, and keeps the union area.
float r2FootW(float vol, float4 sh) {
    float rf = r2RadiusMM(vol);                 // rev48-S4c: drawn footprint = the water's own radius
    return rf * rf;
}
struct R2ShapeAcc { float3 S; float2 P; float W; float n; float wMax; float wSecond; float4 big; float V; float F; float A; float R; float Rmax; };
R2ShapeAcc r2ShapeAccInit() {
    R2ShapeAcc a;
    a.S = float3(0, 0, 0); a.P = float2(0, 0); a.W = 0; a.n = 0; a.wMax = 0; a.wSecond = 0; a.V = 0; a.F = 0; a.A = 0; a.R = 0; a.Rmax = 0;
    a.big = float4(0, 0, r2PackHarm(0, 0), 0);
    return a;
}
void r2ShapeAccAdd(inout R2ShapeAcc a, float4 sh, float vol, float2 pMM) {
    float w = r2FootW(vol, sh);                   // footprint area (mm^2 / pi)
    float b = 0.5 * w;
    a.S += w * float3(b * (0.5 + sh.x) + pMM.x * pMM.x, b * (0.5 - sh.x) + pMM.y * pMM.y, b * sh.y + pMM.x * pMM.y);
    a.P += w * pMM;
    a.W += w;
    float fI = max(max(r2UnpackBF(sh.w).y, gR2BaseSpread), 1.0);
    a.F += w * fI;
    float rD = r2RadiusMM(vol) * r2CapScaleMean(fI);              // M1: drawn footprint radius of this contributor
    a.A += rD * rD;
    a.R += rD;
    a.Rmax = max(a.Rmax, rD);
    a.V += vol;
    a.n += 1.0;
    if (w > a.wMax) { a.wSecond = a.wMax; a.wMax = w; a.big = sh; }
    else if (w > a.wSecond) a.wSecond = w;
}
// rev48-S4: a MOVING head that sweeps SMALL drops (< 20 % of the union area) keeps its own motion shape
// (S3b: composing with every small drop on the path rotated / popped it); a comparable or larger contact
// composes the union (elongated along the contact line = along the motion), then morphs back into a head.
float4 r2ShapeCompose(R2ShapeAcc a, bool bigMoving) {
    if (a.n < 1.5 || a.W <= 0 || gR2ShpOn < 0.5) return a.big;
    // rev48-M1 FOOTPRINT AREA MEMORY (UNIFIED_IMPACT_PLAN 6; R7a review: 'when they touch, one is removed'): the
    // contact lines of a coalescing pair stay pinned -- the composite covers the UNION of the footprints (Andrieu,
    // Beysens & Nikolayev 2002: the long axis then shrinks slowly, the short one stays). The merged drop keeps that
    // area by its flatness: f such that the cap of the merged volume covers sqrt(sum r_i^2) (r2FlatForRadius). S4c-S6
    // shrank it to the merged volume's own footprint (-21 % area for an equal pair) -> the partner seemed to vanish.
    float fUn = r2FlatForRadius(r2RadiusMM(a.V), sqrt(a.A));
    float2 bfB = r2UnpackBF(a.big.w);
    if (bigMoving && a.wMax > 0.8 * a.W) return float4(a.big.xyz, r2PackBFM(bfB.x, max(fUn, bfB.y), r2UnpackBMode(a.big.w)));
    float2 c = a.P / a.W;
    float3 S = a.S / a.W - float3(c.x * c.x, c.y * c.y, c.x * c.y);
    float T = max(S.x + S.y, 1e-8);
    float2 m = float2(0.5 * (S.x - S.y) / T, S.z / T) * gR2ShpMergeK;
    // rev48-M1b (M1 review: two sliding drops merged into a long thin rod): the contributors' offsets come from the
    // swept contact test (positions past the touching point) and the motion -> the second moment over-elongates.
    // The composite of TOUCHING drops is at most as long as their diameters in a row: aspect <= sum r_i / r_max
    // (equal pair 2, Andrieu 2002 composite), capped at 3.
    float Au = clamp(a.R / max(a.Rmax, 1e-5), 1.0, 3.0);
    float eU = min(0.5 * (Au * Au - 1.0) / (Au * Au + 1.0), 0.45);
    float e = length(m);
    if (e > eU) m *= eU / max(e, 1e-6);
    float2 hb = r2UnpackHarm(a.big.z);
    float bal = 4.0 * a.wMax * a.wSecond / max((a.wMax + a.wSecond) * (a.wMax + a.wSecond), 1e-12);
    // M2: the bridge fills within ~20 ms (Hernandez-Sanchez 2012; Andrieu 2002 'convex composite at once') -> the
    // composite is convex: no peanut waist by default (shpWaist 0), the winner's own contour is kept
    float a2 = max(hb.x, gR2ShpWaist * bal * saturate(length(m) / 0.25));
    return float4(m, r2PackHarm3(a2, hb.y, r2UnpackHarmPh(a.big.z)), r2PackBFM(bfB.x * (1.0 - bal), fUn, r2UnpackBMode(a.big.w)));
}

// rev48-S4 SHAPE MEMORY + MOTION MORPH (S3b review: flowing drops must follow the flow -- head and tail along
// the motion, no random pops; and a shape caught mid-event should persist until the next event):
//  * moving: the footprint morphs toward a motion ellipse (aspect 1 + shpMotionK v/shpMotionV along the
//    motion, contour modes and bend fade, flatness toward a compact head) over shpRelaxMove;
//  * pinned: the shape is HELD (contact-line pinning) -- it relaxes only over shpRelaxStill x size, so the
//    arrested splats, merged puddles and the last motion shape stay until something moves the drop again.
// rev48-S5 E7: a PINNED drop relaxes toward its gravity-sag ellipse (aspect 1 + shpBoK Bo, Bo = (r / 2.7 mm)^2
// |g_t| / g, major axis along the slope) instead of a circle -- large drops on the near-vertical visor are long.
// rev48-S5 E3 (an elongated drop that starts to slide): the motion target keeps the drop's own length for a
// while (a long slug -- the old footprint becomes head + tail along the motion, rotated, not shrunk through a
// circle); it shortens to the head over shpSlugTau. The trail rule then decides whether the slug leaves water.
// rev48-S5 E6 (pinned drop in the helmet air): the air at its top stretches it along the air by
// 1 + shpAirK We_air (We = rho u^2 r / gamma, capped), added to the gravity sag (anisotropy vectors add).
// rev48-S6: wrap an angle to [-pi/2, pi/2) (axis angles are defined mod pi)
float r2Wrap90(float a) {
    return a - 3.14159265 * floor(a / 3.14159265 + 0.5);
}
float4 r2ShapeRelax(float4 sh, float rmm, bool moving, float dt, float2 dirMM, float vms, float h, float wet, float3 gI, float3 aI) {
    // single exit (FXC X4000 'potentially uninitialized' with the early return of the moving branch)
    float2 hm = r2UnpackHarm(sh.z);
    float2 bf = r2UnpackBF(sh.w);
    float fEq = r2RestEq(rmm, h, wet);
    float4 res = sh;
    if (moving && dot(dirMM, dirMM) > 1e-12) {
        // rev48-S6 F2 TURNS: the stored major axis is the TAIL line (the low-passed past path); its
        // misalignment dl with the heading is the turn signal (no extra state). The axis ROTATES toward the
        // heading over shpTailTau (the pinned receding tail lags) and the head-tail line stretches
        // (shpTailStretch |sin dl|); above shpSnapDeg the tail lets go (axis over ~4 frames).
        // rev48-S6b (rev48_S6 review: 'the original shape rotates, the head under-turns'; expected a gentle L):
        // the HEAD half bends onto the heading at once (~2 frames) -- one-sided bend at the head end (mode 1/2)
        // with tip slope shpHookK x tan(dl left after the tail moved) -- and straightens as the tail is pulled in.
        // S6 bowed the whole drop symmetrically (crescent) while rotating it: the head kept the old direction.
        float A = 1.0 + gR2ShpMotionK * saturate(vms / max(gR2ShpMotionV, 1e-4));
        float A2 = A * A;
        float eM = min(0.5 * (A2 - 1.0) / (A2 + 1.0), 0.45);
        float2 d = normalize(dirMM);
        float e0 = length(sh.xy);
        float psi = atan2(d.y, d.x);
        float phi = e0 > 1e-4 ? 0.5 * atan2(sh.y, sh.x) : r2Wrap90(psi);
        float dl = r2Wrap90(psi - phi);
        float sgn = dot(d, float2(cos(phi), sin(phi))) >= 0.0 ? 1.0 : -1.0;
        // the packed move is quantized (1/31.25 cell ~ 0.037 mm): a slow drop's heading is noisy -> weight
        // the turn response by the frame move in packing steps (full from 4 steps)
        float wq = saturate(length(dirMM) * 31.25 / max(gR2CellMM, 1e-3) / 4.0);
        bool snap = abs(dl) > radians(gR2ShpSnapDeg);
        float tauR = snap ? 0.5 * gR2ShpRelaxMove : gR2ShpTailTau * (1.0 - 0.5 * saturate(wet));
        float kr = (1.0 - exp(-dt / max(tauR, 1e-3))) * (snap ? 1.0 : lerp(0.25, 1.0, wq));
        float phiN = phi + dl * kr;
        float eS = snap ? 0.0 : gR2ShpTailStretch * abs(sin(dl)) * wq;
        // E3 slug memory keeps the drop's own length, not the turn stretch (else it ratchets up)
        float eT = min(max(eM, max(e0 - eS, 0.0) * exp(-dt / max(gR2ShpSlugTau, 1e-3))) + eS, 0.45);
        float k = 1.0 - exp(-dt / max(snap ? 0.5 * gR2ShpRelaxMove : gR2ShpRelaxMove, 1e-3));
        float e = e0 + (eT - e0) * k;
        // hook: tip slope = hookK tan(dl left), in the visor's units (tip offset b x minor half, aa^2 over the
        // head half) -> b = 0.5 hookK A tan(dl)
        float Ae = sqrt((0.5 + e) / max(0.5 - e, 0.05));
        float dlN = r2Wrap90(psi - phiN);
        float mode = sgn > 0.0 ? 1.0 : 2.0;
        float mOld = r2UnpackBMode(sh.w);
        float bT = sgn * 0.5 * gR2ShpHookK * Ae * tan(clamp(dlN, -0.9, 0.9)) * wq;
        float kh = 1.0 - exp(-dt / 0.03);
        float bN = (mOld == mode ? bf.x : 0.0) + (bT - (mOld == mode ? bf.x : 0.0)) * kh;
        // a bow of another kind (birth / merge banana, or a hook at the other end) first fades out over
        // shpRelaxMove, then the hook starts (no pop)
        if (mOld != mode && abs(bf.x) > 0.03) { bN = bf.x * (1.0 - k); mode = mOld; }
        // the visor's u1 = (cos phi, sin phi), phi in (-90, 90]: crossing the boundary flips u1 -> the bend
        // side flips (and a hook's head end)
        float phiW = r2Wrap90(phiN);
        if (abs(phiW - phiN) > 1.0) { bN = -bN; mode = mode > 0.5 ? 3.0 - mode : 0.0; }
        float fMove = 1.0 + 0.5 * (fEq - 1.0);
        // rev48-M1b (M1 review: a sliding drop that ate another shrank first, then grew): a flat footprint (merged
        // union) recedes to the receding-angle limit over shpMergeTau x r while sliding too, not in shpRelaxMove
        float fLimM = pow(abs(gR2ContactDeg) / clamp(gR2SheetRecedeDeg, 10.0, 100.0), 2.0 / 3.0);
        bool flatM = bf.y > max(fLimM, fMove);
        float fTM = flatM ? max(fLimM, fMove) : fMove;
        float kfM = flatM ? 1.0 - exp(-dt / max(gR2ShpMergeTau * rmm, 1e-3)) : k;
        res = float4(e * float2(cos(2.0 * phiW), sin(2.0 * phiW)), r2PackHarm3(hm.x * (1.0 - k), hm.y * (1.0 - k), r2UnpackHarmPh(sh.z)),
                     r2PackBFM(bN, lerp(bf.y, fTM, kfM), mode));
    } else {
        float tau = 0.05 + gR2ShpRelaxStill * saturate(rmm * rmm / 0.09);
        float k = exp(-dt / max(tau, 1e-3));
        float Ag = 1.0 + gR2ShpBoK * (rmm * rmm / 7.29) * gI.z;
        float Ag2 = Ag * Ag;
        float eg = min(0.5 * (Ag2 - 1.0) / (Ag2 + 1.0), 0.45);
        float2 mg = eg * float2(gI.x * gI.x - gI.y * gI.y, 2.0 * gI.x * gI.y);
        float weA = 1.2 * aI.z * aI.z * rmm * 1e-3 / 0.072;
        float Aa = 1.0 + min(gR2ShpAirK * weA, gR2ShpAirMax - 1.0);
        float Aa2 = Aa * Aa;
        mg += min(0.5 * (Aa2 - 1.0) / (Aa2 + 1.0), 0.45) * float2(aI.x * aI.x - aI.y * aI.y, 2.0 * aI.x * aI.y);
        float eT = length(mg);
        mg *= eT > 0.45 ? 0.45 / eT : 1.0;
        // rev48-M1: a flat footprint (merged union, arrested splat) recedes only while its angle is below the receding
        // angle, i.e. down to fLim = (contactDeg / theta_r)^(2/3), over shpMergeTau x r (contact-line friction: Andrieu
        // 2002 t_c ~ R / u); a drop already above that limit relaxes to its equilibrium as before
        float fLim = pow(abs(gR2ContactDeg) / clamp(gR2SheetRecedeDeg, 10.0, 100.0), 2.0 / 3.0);
        float fT = bf.y > fLim ? max(fLim, fEq) : fEq;
        float kf = bf.y > fLim ? exp(-dt / max(gR2ShpMergeTau * rmm, 1e-3)) : k;
        res = float4(mg + (sh.xy - mg) * k, r2PackHarm3(hm.x * k * k, hm.y * k * k * k, r2UnpackHarmPh(sh.z)), r2PackBFM(bf.x * k, fT + (bf.y - fT) * kf, r2UnpackBMode(sh.w)));   // S6b: a stopped hook stays a hook
    }
    return res;
}

// rev45 wetness of the surface at a field sample (rule_trail 5): micro haze + film.
float r2Wet(float4 F) {
    return saturate(F.g * gR2WetHaze + (F.b * gR2FilmMaxMM + F.r * gR2TrailMaxMM) / max(gR2FilmFullMM, 1e-4));
}
// rev45 trail water depth (mm) left behind a moving head drop (rule_trail 3-7, user-approved review):
// film left by a receding contact line grows with speed ~ Ca^(2/3) (Landau-Levich), more on a wet
// surface, none behind small drops (they flow dry). Shared by cells (mass lost) and field (deposit).
// rev46 (rev45 review: trails behind slowly sliding drops in a 30-150 km/h head wind were only a wiped
// haze mark, thick only where flying drops left them): a sliding drop leaves a residual rivulet whose
// thickness scales with the head (its rear contact line), so the speed term starts at half strength
// and the head size counts (sqrt(r / 0.5 mm), <= 1.6).
// rev47l TRAIL RULE (docs/RAINFX_V2_TRAIL_RULES.md; rev47k review: even small drops in light rain drew long
// thick trails -- every runback drop left one). A sliding drop leaves water only when its receding contact
// line cannot keep up (Cox-Voinov / Podgorski-Flesselles-Limat): the receding dynamic angle reaches zero at
//   Ca* = theta_r^3 / (9 ln(r / lambda)),   Ca = mu U / gamma = U / 72 m/s,   lambda = 1 nm,
// with the receding angle lowered by a wet surface: theta_r = trailThetaR (1 - trailWetK wet).
//   s = Ca / Ca* < 1 : dry slide (rounded / cornered rear, no trail)            -> returns 0
//   s >= 1          : the rear cusp opens; rivulet half-width hw = 0.5 trailWidthK r sqrt(1 - 1/s)
//                     (narrow just above the threshold = pearling, wider when faster), centre depth
//                     h0 = trailLL r Ca^(2/3) (Landau-Levich, thicker when faster), at most the edge slope
//                     2 h0 / hw <= trailSlopeMax.
// Big heads move faster (force ~ r^2, pinning ~ r) -> they cross the threshold first; small drops flow dry.
float r2TrailRule(float rmm, float vms, float wet, out float hw) {
    hw = 0.0;
    if (rmm <= gR2MinRadiusMM || vms <= 0.0) return 0.0;
    float th = radians(gR2TrailThetaRDeg) * (1.0 - gR2TrailWetK * saturate(wet));
    float caS = th * th * th / (9.0 * log(max(rmm * 1e6, 10.0)));   // r / 1 nm
    float ca = vms / 72.0;
    float sR = ca / max(caS, 1e-9);
    if (sR <= 1.0) return 0.0;
    hw = 0.5 * gR2TrailWidthK * rmm * sqrt(1.0 - 1.0 / sR);
    float h = gR2TrailLL * rmm * pow(max(ca, 1e-12), 0.6667);   // FXC X3571: base kept positive
    return min(h, 0.5 * hw * gR2TrailSlopeMax);
}

// ---------- rev47j trail rivulets + mass-conserving dewetting (docs/RAINFX_V2_REV47J_REVIEW.md) ----------
// Trail geometry texture (field resolution, RGBA16F): xy = nearest centre-line point of the rivulet
// through this texel (mm from the texel centre), z = direction (rad), w = half-width (mm). The depth of
// the centre line is field R. The visor draws the rivulet as a lens kernel of that line (sub-texel sharp).
struct R2TrailHit { float depth; float2 pt; float2 dir; float hwMM; };
R2TrailHit r2TrailNone() {
    R2TrailHit h;
    h.depth = 0; h.pt = float2(0, 0); h.dir = float2(1, 0); h.hwMM = 0;
    return h;
}
// Candidate: the rivulet left by the REAR contact line of the moving drop of cell s this frame (the
// swept segment shifted back by the head radius, rev47h). Texels within hw + 0.9 field texel of the
// centre line store it, so the visor finds it from the texel under any pixel of the rivulet.
void r2TrailCand(float2 pc, int2 s, float4 st, float wet, inout R2TrailHit h) {
    float2 b = float2(s) + st.xy;
    float2 a = b - r2UnpackMove(st.w);
    if (dot(b - a, b - a) <= 4e-4) return;
    float rmm = r2RadiusMM(st.z);
    float2 dirm = (b - a) * rsqrt(dot(b - a, b - a));
    float rC = rmm / gR2CellMM;
    float2 a2 = a - dirm * rC, b2 = b - dirm * rC;
    float2 ab = b2 - a2;
    float2 q = a2 + ab * saturate(dot(pc - a2, ab) / max(dot(ab, ab), 1e-10));
    float vms = length(b - a) * gR2CellMM * 1e-3 / max(gR2Dt, 1e-5);
    float hw = 0.0;
    float dep = r2TrailRule(rmm, vms, wet, hw);
    if (dep <= h.depth) return;
    float texMM = 0.5 * (gR2CellSizeMM.x * gR2Cells.x / gR2FieldSize.x + gR2CellSizeMM.y * gR2Cells.y / gR2FieldSize.y);
    if (length((pc - q) * gR2CellSizeMM) > hw + 0.9 * texMM) return;
    h.depth = dep;
    h.pt = q;
    float2 dmm = dirm * gR2CellSizeMM;
    h.dir = dmm * rsqrt(max(dot(dmm, dmm), 1e-12));
    h.hwMM = hw;
}
int2 r2FieldPerCell() { return max(int2(round(gR2FieldSize / gR2Cells)), int2(1, 1)); }
// Mean film depth (mm) over the field texels of cell c (cells and field passes read the same F_prev).
float r2CellFilmMM(int2 c) {
    int2 k = r2FieldPerCell();
    float s = 0;
    [loop] for (int y = 0; y < k.y; ++y)
        [loop] for (int x = 0; x < k.x; ++x)
            s += txR2Field.Load(int3(c * k + int2(x, y), 0)).b;
    return s * gR2FilmMaxMM / (float)(k.x * k.y);
}
// rev48-W1m: where the water of cell c sits (texel-weighted centroid, 0..1 in the cell) -- a bead forms there
float2 r2CellFilmCentroid(int2 c, float2 fallback) {
    int2 k = r2FieldPerCell();
    float s = 0;
    float2 p = float2(0, 0);
    [loop] for (int y = 0; y < k.y; ++y)
        [loop] for (int x = 0; x < k.x; ++x) {
            float h = txR2Field.Load(int3(c * k + int2(x, y), 0)).b;
            s += h;
            p += h * (float2(x, y) + 0.5) / float2(k);
        }
    return s > 1e-6 ? p / s : fallback;
}
// ---------- rev48-W1 WATER SHEET (docs/RAINFX_V2_WATER_SHEET_PLAN.md) ----------
// With the sheet on, field B is the sheet / film height h (one water, mm / gR2FilmMaxMM). A drop that sits on
// sheet water (h under its centre >= gR2SheetHJoin) or has grown to gR2SheetRMax hands gR2SheetAbsorbK of its
// volume to the sheet per frame (all of it below r 0.15 mm): the field pass adds it (S_next, F_prev), the
// merge pass of the next frame removes it from the drop (same S, F_prev = txR2FieldOld) -- exact exchange.
// rev48-W1d NUCLEATION (docs/RAINFX_V2_WATER_SHEET_PLAN.md section 7.3): a sheet is born only from drop water --
// where the drops of a 5x5-cell cluster are dense (coverage >= gR2SheetNucPhi, drop water depth >= sheetHJoin)
// and an impact lamella bridges them, the nuc pass (nuc.hlsl, S_next) marks the cell; all of that drop joins
// the sheet at once, spread over r2SheetNucRMM (the bridged puddle), so the cluster's caps overlap into one sheet.
// NM texel of cell s: R nucleation, G drop coverage, B drop water depth, A sheet area share of the 5x5 cells (W1f).
float4 r2SheetNucAt(int2 s) {
    return gR2SheetOn > 0.5 ? txR2SheetNuc.Load(int3(clamp(s, int2(0, 0), int2(gR2Cells) - 1), 0)) : float4(0, 0, 0, 0);
}
// rev48-W1f CONNECTED SHEET (W1e review: at heavy the sheet took drops over one by one -- drop-shaped sheet blobs):
// water is a sheet only where it covers more of the 5x5-cell window than the largest drop could
// (gR2SheetConnA = sheetConnK * pi rMax^2 / window); a smaller patch is a drop's worth of water, not a sheet.
bool r2SheetConnected(float4 nm) {
    return nm.a >= gR2SheetConnA;
}
// rev48-W1g IMPACT-FILM REGIME (W1f review: at hurricane the exposed face stayed drops + trails): when ALL the rain
// landing here (resolved + unresolved, x local exposure) arrives faster than unconnected water breaks up
// (q >= sheetThinRate * sheetHJoin), successive splashes land on each other's lamellae -- the resolved share does
// not stay as separate drops either, all of it feeds the water layer (cells: no births; field: adds it).
// rev48-W1j (W1i review: the fed regime opened like a sliding door -- one straight edge = an iso-line of the smooth
// exposure): the regime is decided by the LOCAL supply q actually delivered by discrete impact lamellae (field A,
// exponential average over sheetFedTau of the stamped rain, written by the field pass), not by its expectation.
// Fed where q >= sheetThinRate x sheetHJoin: the lamellae land on each other before the water breaks up.
bool r2FedTx(Texture2D tx, float2 t) {
    return gR2SheetOn > 0.5 && tx.SampleLevel(samLinearClamp, t, 0).a * gR2SheetQMax >= gR2SheetThinRate * gR2SheetHJoin;
}
bool r2ImpactFilm(float2 t) {
    return r2FedTx(txR2Field, t);
}
// rev48-W1r WETTED SURFACE (P4 review: the sheet left a dry surface right behind it -- no wetting state; the reference
// keeps the whole exposed face wet under continuous supply): where the local supply q is >= sheetWetFrac x q_c the
// surface stays wet -- a deposited layer sheetWetMM (Landau-Levich film left by the moving sheet) does not flow, does not
// dissolve, is not pulled into the sheet; the next water lands on wet surface (no dry-front pinning).
bool r2WetTx(Texture2D tx, float2 t) {
    return gR2SheetOn > 0.5 && tx.SampleLevel(samLinearClamp, t, 0).a * gR2SheetQMax >= gR2SheetWetFrac * gR2SheetThinRate * gR2SheetHJoin;
}
// rev48-W1i FED SHEET (P2d review: sheets only ran down from the top edge, never formed on the exposed face):
// at speed the impact-fed film is THIN -- it is sheared away at up to 0.25 m/s, so h ~ q L / v ~ 0.02-0.08 mm,
// below sheetHJoin (0.10, the threshold for water that is NOT re-fed) -- and W1f broke it up as unconnected water.
// Where impacts keep re-feeding it (Gosset 2017: impingement holds a continuous film thinner than h0) the sheet
// threshold is sheetHFed instead. All sheet tests use r2SheetH (field, sheet, nuc, merge, cells, drops, visor).
float r2SheetH(float2 t) {
    return r2ImpactFilm(t) ? gR2SheetHFed : gR2SheetHJoin;
}
float r2SheetHTx(Texture2D tx, float2 t) {
    return r2FedTx(tx, t) ? gR2SheetHFed : gR2SheetHJoin;
}
float r2SheetHAtTexel(int2 f) {
    return r2SheetH((float2(f) + 0.5) / gR2FieldSize);
}
float r2SheetNucRMM(float r) {
    return max(r, 1.8 * min(gR2CellSizeMM.x, gR2CellSizeMM.y));   // stays inside the field pass 5x5 cell window
}
float r2SheetAbsorbFrac(float4 st, float4 L, float hUnderMM, float4 nm, float hcAbs, bool wet) {
    float k = 0.0;
    if (gR2SheetOn > 0.5 && st.z > 0 && L.y <= 0 && L.z <= 0) {
        float r = r2RadiusMM(st.z);
        if (nm.r > 0.5) k = 1.0;
        else if ((hUnderMM >= hcAbs || r >= gR2SheetRMax) && r2SheetConnected(nm)) k = r < 0.15 ? 1.0 : gR2SheetAbsorbK;
        // rev48-W1u (W1t review: drops crossing a sheet cut it and pinned drops stayed under sheets for ever): on wetted
        // surface a drop touching the water layer merges into it (its water adds to the sheet and flows on)
        else if (wet && hUnderMM >= 0.5 * gR2SheetWetMM) k = r < 0.15 ? 1.0 : gR2SheetAbsorbK;
    }
    return k;
}
// rev41 clustering (rev40 review: the reference shows dense groups of small and large drops, v2 an
// even spread): birth rates are modulated by a slowly drifting low-frequency field (gR2ClusterK,
// features of clusterMM, time scale ~3 s) with mean 1, so groups form and dissolve.
float r2Cluster(float2 t) {
    float n = r2VNoise(t * gR2ClusterScale + float2(gR2Time * 0.21, gR2Time * 0.13));
    return max(1.0 + gR2ClusterK * (2.0 * n - 1.0) * 1.6, 0.0);
}

// rev48-U1 IMPACT REGISTRY (docs/RAINFX_V2_UNIFIED_IMPACT_PLAN.md): one raindrop = one event. lam.hlsl writes per cell
// R = birth frame + 1 (+0.25 landed on fed water), G = the previous impact (visor disturbance). The impact point, the
// raindrop diameter (exponential DSD) and the seed come from the same hash for every consumer (cells, field, visor).
struct R2Impact { float2 ip; float d; bool fed; uint sk; };
// rev48-R2 / R4 impact outcome of a raindrop of diameter d (mm) at this exposure / oblique geometry (cells + field F-layer):
// own fall speed V_t(d) (Atlas 1973) with the vehicle / wind part of the relative speed; Mundo K; Bird 2009 halves
// (K (1 +- 2.5 (Vt/Vn) Re^-1/2)); deposition keeps all, a splashing half loses 1 - (K0/K_side)^resA; Laan lamella radius.
struct R2Outcome { float vImp; float We; float Re; float K; float Kdn; float Kup; float lDn; float lUp; float fRes; float Rs; };
R2Outcome r2ImpactOutcome(float d, float exposure, float4 ig) {
    R2Outcome o;
    float vTd = max(9.65 - 10.3 * exp(-0.6 * d), 0.1);
    float vD = sqrt(max(gR2SpeedRel * gR2SpeedRel - gR2TerminalSpeed * gR2TerminalSpeed, 0.0) + vTd * vTd);
    o.vImp = max(vD * exposure, 0.3);
    o.We = 13.8889 * o.vImp * o.vImp * d;
    o.Re = 1000.0 * o.vImp * d;
    o.K = sqrt(o.We) * pow(max(o.Re, 1e-3), 0.25);
    float xi = ig.w * rsqrt(max(o.Re, 1.0));
    o.Kdn = o.K * (1.0 + 2.5 * xi);
    o.Kup = o.K * max(1.0 - 2.5 * xi, 0.0);
    o.lDn = o.Kdn > gR2SplashK0 ? 1.0 - pow(abs(gR2SplashK0 / o.Kdn), gR2ResA) : 0.0;
    o.lUp = o.Kup > gR2SplashK0 ? 1.0 - pow(abs(gR2SplashK0 / max(o.Kup, 1e-3)), gR2ResA) : 0.0;
    o.fRes = 1.0 - 0.5 * (o.lDn + o.lUp);
    float Pl = o.We * pow(max(o.Re, 1.0), -0.4);
    o.Rs = max(0.5 * d * pow(max(o.Re, 1.0), 0.2) * sqrt(Pl) / (1.24 + sqrt(Pl)), 0.6 * gR2CellMM);
    return o;
}
// rev48-P1 impacting-diameter inverse CDF (weather.lua W.supply): 16 knots at s = k / 15 of u = 1 - (1 - s)^3
float r2DsdDiam(float u) {
    float q[16] = { gR2DQ0, gR2DQ1, gR2DQ2, gR2DQ3, gR2DQ4, gR2DQ5, gR2DQ6, gR2DQ7,
                    gR2DQ8, gR2DQ9, gR2DQ10, gR2DQ11, gR2DQ12, gR2DQ13, gR2DQ14, gR2DQ15 };
    float x = (1.0 - pow(saturate(1.0 - u), 1.0 / 3.0)) * 15.0;
    int i = min((int)x, 14);
    return lerp(q[i], q[i + 1], saturate(x - (float)i));
}
bool r2ImpactAt(int2 s, float enc, out R2Impact im) {
    im.ip = float2(0, 0); im.d = 0; im.fed = false; im.sk = 0u;
    if (enc < 0.5) return false;
    float birth = floor(enc) - 1.0;
    im.fed = frac(enc) > 0.1;
    im.sk = (uint)(birth + 0.5) * 8u + 9200u;
    im.ip = float2(s) + float2(r2Rand(uint3((uint)s.y, (uint)s.x, im.sk + 1u)), r2Rand(uint3((uint)s.x, (uint)s.y, im.sk + 2u)));
    im.d = clamp(r2DsdDiam(r2Rand(uint3((uint)s.x, (uint)s.y, im.sk + 3u))), 0.1, 6.0);   // P1: DSD x impingement (was exp(MeanDiam))
    return true;
}

int2 r2CellOfTexel(int2 f) {
    return int2(floor((float2(f) + 0.5) / gR2FieldSize * gR2Cells));
}
int2 r2FieldTexelAt(float2 cellPos) {
    return clamp(int2(floor(cellPos / gR2Cells * gR2FieldSize)), int2(0, 0), int2(gR2FieldSize) - 1);
}
// rev48-W1e CONTACT (W1d review: a sheet ran over drops that only blurred): water touching water merges -- the
// sheet height a drop sees is the highest under its footprint (centre + 4 rim points), not only under its centre.
// Field (F_prev) and merge (txR2FieldOld = the same F_prev) call it with the same texture and state.
float r2SheetHUnder(Texture2D tx, float2 cellPos, float rMM) {
    float2 d = rMM / gR2CellSizeMM;
    float h = tx.Load(int3(r2FieldTexelAt(cellPos), 0)).b;
    h = max(h, tx.Load(int3(r2FieldTexelAt(cellPos + float2(d.x, 0)), 0)).b);
    h = max(h, tx.Load(int3(r2FieldTexelAt(cellPos - float2(d.x, 0)), 0)).b);
    h = max(h, tx.Load(int3(r2FieldTexelAt(cellPos + float2(0, d.y)), 0)).b);
    h = max(h, tx.Load(int3(r2FieldTexelAt(cellPos - float2(0, d.y)), 0)).b);
    return h * gR2FilmMaxMM;
}
// Dewetting of THIN film only: a film already thick enough to be a sheet does not bead up (rev48-W1).
// rev48-W1e: with the sheet on, water below the sheet threshold is unconnected splash water (micro droplets): it
// breaks up at sheetThinRate (field pass) instead of beading into cell-volume drops of one size (W1b/W1c reviews).
bool r2DewetFilmOK(float hC, int2 c) {
    if (gR2SheetOn < 0.5) return hC >= gR2FilmBeadMM;
    // rev48-W1o / U1: no per-cell beading with the sheet on (a grid of drops); patches bead through bead.hlsl
    return false;
}
// rev48-W1 sheet velocity coefficients at t (world law -> field uv / s): v(h) = A h + B h^2 (h in mm),
// air shear tau h / (2 mu) with the helmet outer flow (same u_e as r2DropVelocity, Cf = gR2FilmCf) and
// gravity rho g_t h^2 / (3 mu).
float4 r2SheetCoef(float2 t) {
    float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
    float3 dv = r2ToWorld(r2Tap(txR2Dv, t).xyz);
    float3 n = r2Normal(t);
    float3 g = gR2AccelW - n * dot(gR2AccelW, n);
    float3 ah = gR2AeroDirW;
    float cn = -dot(n, ah);
    float3 ue = (ah - n * dot(ah, n)) * (gR2AeroU * smoothstep(-0.1, 0.2, cn));
    float3 tau = (0.5 * gR2RhoAir * gR2FilmCf * length(ue)) * ue;          // Pa
    float3 vA = tau * 0.5;                                                  // m/s per mm: tau h / (2 mu)
    float3 vB = g * (1.0 / 3.0);                                            // m/s per mm^2: rho g h^2 / (3 mu)
    float a = dot(du, du), b = dot(du, dv), c = dot(dv, dv);
    float det = max(a * c - b * b, 1e-20);
    float2 A = float2(c * dot(du, vA) - b * dot(dv, vA), a * dot(dv, vA) - b * dot(du, vA)) / det;
    float2 B = float2(c * dot(du, vB) - b * dot(dv, vB), a * dot(dv, vB) - b * dot(du, vB)) / det;
    return float4(A, B) * gR2FilmFlowK;
}

// Dewetting / pearling events of cell c this frame: pure hashes of (cell, frame), so the cells pass
// (turns the water into a bead) and the field pass (removes the same water) always agree.
bool r2DewetEvent(int2 c) {
    return r2Rand(uint3((uint)c.x, (uint)c.y, (uint)gR2Frame * 8u + 9001u)) < gR2DewetRate * gR2SimDt;
}
// rev47l: a narrow rivulet beads up faster (Plateau-Rayleigh growth ~ 1 / width): rate x 0.25 mm / hw.
bool r2PearlEvent(int2 c, float hwMM) {
    float k = clamp(0.25 / max(hwMM, 1e-3), 0.5, 6.0);
    return r2Rand(uint3((uint)c.y, (uint)c.x, (uint)gR2Frame * 8u + 9002u)) < gR2PearlRate * k * gR2SimDt;
}
// Cell of the centre-line point stored at field texel f (geometry g).
int2 r2TrailCell(int2 f, float4 g) {
    float2 pc = (float2(f) + 0.5) / gR2FieldSize * gR2Cells + g.xy / gR2CellSizeMM;
    return int2(floor(pc));
}

// One drop step. Every gathering cell evaluates this identically for a source.
struct R2Move {
    float2 dest;   // absolute cell coordinates after the step
    float vol;     // mm^3 after losses
    float alive;   // 0: none / gone (flight over, faded, left the surface)
    float moved;   // cells travelled
    float4 life;   // rev45 L after this step
    float2 cDest;  // rev48-S6c E8: the tail piece split off this step (absolute cells), its volume (0 = none)
    float cVol;    //   and its axis (rad); every gathering cell evaluates the same event (cell + frame hash)
    float cPhi;
};
// rev48-S6c E8 SPLIT CHILD marker: life.w = -5 (between the flight angle range [-pi, pi], used only while
// flying, and the splat marker < -9.5). A fresh child is drawn at once (it is existing water) and is not
// swept back into its parent by the claim pass (claim.hlsl).
bool r2SplitChild(float4 L) { return abs(L.w + 5.0) < 0.5 && L.y <= 0.0; }
R2Move r2Predict(int2 cell, float4 s, float4 L, float4 sh) {
    R2Move o;
    o.cDest = float2(0, 0);
    o.cVol = 0;
    o.cPhi = 0;
    o.dest = float2(cell) + s.xy;
    o.vol = 0;
    o.alive = 0;
    o.moved = 0;
    o.life = L;
    o.life.x = L.x + gR2Dt;
    if (s.z <= 0) return o;
    float2 t = (float2(cell) + s.xy) / gR2Cells;
    float rmm = r2RadiusMM(s.z);
    float4 Fs = txR2Field.SampleLevel(samLinearClamp, t, 0);
    float2 dc = float2(0, 0);
    float vol = s.z;
    bool gone = false;
    if (L.z > 0) {
        // fading (swept by a splash): stays, shrinks on screen, then it is gone
        o.life.z = L.z - gR2Dt;
        gone = o.life.z <= 0;
    } else {
        // rev41: pinning heterogeneity is a smooth surface field (gR2PinScale, ~4 mm features).
        float pinNoise = lerp(gR2PinNoiseMin, gR2PinNoiseMax, r2VNoise(t * gR2PinScale + 53.1));
        // rev8: kinetic hysteresis (a moving contact line is held less than a resting one).
        float2 lastMove = r2UnpackMove(s.w);
        // rev48-S6b F1: the head (one radius ahead along the last move) meets the defects first: the mean of
        // its two sides scales the pinning (stick-slip), their difference steers (r2Steer)
        float2 lmMM = lastMove * gR2CellSizeMM;
        float lmL = length(lmMM);
        float2 pMM = t * gR2CellSizeMM * gR2Cells;
        float dMean = 0.5;
        float2 defSteer = float2(0, 0);
        if (lmL > 1e-4) {
            float2 dh = lmMM / lmL;
            float2 sd = float2(-dh.y, dh.x) * rmm;
            float dL = r2Defect(pMM + dh * rmm + sd), dR = r2Defect(pMM + dh * rmm - sd);
            dMean = 0.5 * (dL + dR);
            defSteer = -sd / rmm * (gR2DefK * gR2DefPin * (dL - dR) * rsqrt(max(1.0, 2.0 * rmm * gR2DefInvMM)));
        } else {
            dMean = r2Defect(pMM);
        }
        pinNoise *= max(1.0 + gR2DefPin * (2.0 * dMean - 1.0), 0.05);
        if (dot(lastMove, lastMove) > 1e-6) pinNoise *= gR2PinKinetic;
        float speed = 0.0;
        float drive = 1.0;
        float2 vt = r2DropVelocity(t, rmm, pinNoise, sh, speed, drive);
        // rev48-U2 birth sticking (U1 review: splats 'bounced' off at speed): a fresh splat is a lamella spreading /
        // recoiling on the wall, not yet a drop the air can take -- the air / gravity drive ramps 0 -> 1 over 3 tau
        // (no launch while it ramps), then the pinning takes over. Its residual walks downstream by the splat shift
        // as the rim recoils (deterministic, exp(-age / tau) profile = the visor's recoil).
        bool splatU = gR2ShpOn > 0.5 && L.w < -9.5;
        float2 dcSplat = float2(0, 0);
        if (splatU) {
            float tauS = r2SplatTau(rmm);
            // U2a (U2 review: 'it starts while still recoiling'): no drive until the recoil is ~86 % done (2 tau),
            // full at 4 tau -- the lamella's contact line is pinned while it recedes; the pinning test takes over after
            float rampS = smoothstep(2.0 * tauS, 4.0 * tauS, L.x);
            vt *= rampS;
            speed *= rampS;
            drive *= rampS;
            float eS = exp(-L.x / tauS);
            if (eS > 0.01) {
                float4 igS = r2ImpactGeom(t);
                dcSplat = igS.xy * (r2SplatShiftMM(rmm, -L.w - 10.0, igS) * (eS - exp(-(L.x + gR2Dt) / tauS))) / gR2CellSizeMM;   // R1: exact step (tau < dt)
            }
        }
        {   // R6: no launch -- every unpinned drop slides (runback over the edge)
            vt = r2Steer(t, vt, drive, defSteer);
            // rev47 drop inertia (rev46 review: car jolts gave 'lightning' zig-zags): the speed relaxes
            // to the force-driven target over gR2DropTau; the previous speed is the packed move of the
            // last frame (substep 1) or of the substeps so far in this frame. A reversed force first
            // brakes the drop through zero instead of flipping its direction.
            float prevDur = gR2Sub > 1.5 ? (gR2Sub - 1.0) * gR2Dt : gR2SimDt;
            float2 vPrev = lastMove / max(prevDur, 1e-4) - dcSplat / max(gR2Dt, 1e-5);   // U2: the recoil walk is no momentum
            float2 vTgt = vt * gR2Cells;
            float tauI = gR2DropTau;                                  // R6: one relaxation (slideTau removed)
            float kI = tauI > 1e-4 ? 1.0 - exp(-gR2Dt / tauI) : 1.0;
            float2 vNew = vPrev + (vTgt - vPrev) * kI;
            // rev47a (rev47 review, rev47_unacceptableMovement.mp4: small drops crept ~2 mm/s with no air
            // and no motion): the stop test compared mm^2/s^2 against 4e-6 (meant 4 = 2 mm/s), so it never
            // fired, and the packed move (1/31.25 cell steps) rounds 0.7 of a step back up to a full step:
            // vPrev -> 0.7 vPrev -> rounds to 1 step -> perpetual creep at one step per frame. A drop with
            // no driving force now stops once it is slower than 1.5 packing steps per frame or 3 mm/s.
            float stopMMs = max(3.0, 1.5 * length(gR2CellSizeMM) / 31.25 / max(prevDur, 1e-4));
            if (dot(vTgt, vTgt) <= 0.0 && length(vNew * gR2CellSizeMM) < stopMMs) vNew = float2(0, 0);
            dc = vNew * gR2Dt + dcSplat;
        }
    }
    // the gather window limits one step (fast drops are speed-limited, never deleted)
    float dm = max(abs(dc.x), abs(dc.y));
    if (dm > gR2GatherCells) dc *= gR2GatherCells / dm;
    float travelMM = length(dc * gR2CellSizeMM);
    // rev45 trail (rule_trail 3): the head loses the water it leaves behind; it collects the haze and
    // film it sweeps (rule_merge 3, rule_trail 11); evaporation as before.
    float wet = r2Wet(Fs);
    float vms = travelMM * 1e-3 / max(gR2Dt, 1e-5);
    float hwT = 0.0;
    float hT0 = r2TrailRule(rmm, vms, wet, hwT);
    vol -= 1.3333 * hT0 * hwT * travelMM;   // rev47j/l: parabolic rivulet section (4/3) h0 hw
    // rev48-W1g: a drop sweeps thin water, not a sheet (W1f review: running drops ate the sheet and laid trails
    // inside it; on a sheet the drop is what gets absorbed -- field / merge)
    float hSweep = Fs.b * gR2FilmMaxMM;
    // W1k: an isolated remnant patch is collected like thin water (only a connected sheet absorbs the drop instead)
    if (gR2SheetOn > 0.5 && ((hSweep >= r2SheetH(t) && r2SheetConnected(r2SheetNucAt(cell))) || r2WetTx(txR2Field, t))) hSweep = 0.0;   // W1u: nor a wet layer
    vol += hSweep * gR2FilmCollect * 2.0 * rmm * travelMM;   // F9: the fine layer is gone
    // F5: diffusion-limited evaporation of the cap, 4 r D drho / rho_w (Picknett & Bexon; ~ r: small drops go first)
    // + the stagnation layer on its wetted area (init.lua fineBudget)
    vol -= gR2Dt * (gR2EvapDiff * rmm + gR2EvapConv * R2_PI * rmm * rmm);
    // Keep the destination inside the 5x5 gather window (merged drops may sit off-cell).
    float2 dest = float2(cell) + clamp(s.xy + dc, -1.99, 2.99);
    if (gone || r2Valid(dest / gR2Cells) < 0.5) return o;  // gone / absorbing boundary / hole
    if (r2RadiusMM(vol) < gR2MinRadiusMM) return o;           // residue only (the trail keeps it)
    // rev48-S6c E8 TAIL SPLIT (docs/RAINFX_V2_SHAPE_STATE_PLAN.md section 21). A sliding drop sheds its tail
    // as a separate drop when (A) it is stretched beyond shpSplitA (the rear pinches off, pearling of the
    // receding end; Podgorski et al. 2001) or (B) its tail lets go in a turn (|dl| > shpSnapDeg, the hook /
    // snap of S6b) while it still has a tail (e >= 0.12). One event per drop at shpSplitRate / s while the
    // condition holds; the piece (volume share fs) is placed behind the parent's new footprint along the axis,
    // just outside contact distance, inside the 5x5 gather window (else no event: mass stays exact).
    float2 dcMM = dc * gR2CellSizeMM;
    float e8 = length(sh.xy);
    // rev48-R2b (R2 review: split pieces popped out of fresh impact drops, overlapping them): a splat's recoil walk is
    // no slide -- no tail split while it recoils / sticks (4 tau)
    bool splatRamp = L.w < -9.5 && L.x < 4.0 * r2SplatTau(rmm);
    if (gR2ShpOn > 0.5 && gR2ShpSplitRate > 0.0 && L.y <= 0.0 && L.z <= 0.0 && e8 > 1e-3 && !splatRamp
        && dot(dcMM, dcMM) > 25.0 * gR2Dt * gR2Dt && rmm >= gR2ShpSplitRMin) {   // > 5 mm/s (F8: F7's pearling gate reverted -- not evidenced)
        float A8 = sqrt((0.5 + e8) / max(0.5 - e8, 0.05));
        float2 lastMove8 = r2UnpackMove(s.w);
        float phi8 = 0.5 * atan2(sh.y, sh.x);
        float2 u8 = float2(cos(phi8), sin(phi8));
        float2 d8 = normalize(dcMM);
        float dl8 = r2Wrap90(atan2(d8.y, d8.x) - phi8);
        bool cA = A8 >= gR2ShpSplitA;
        bool cB = abs(dl8) > radians(gR2ShpSnapDeg) && e8 >= 0.12 && dot(lastMove8, lastMove8) > 1e-6;   // already sliding
        uint fk = (uint)gR2Frame * 8u + (uint)gR2Sub;
        if ((cA || cB) && r2Rand(uint3((uint)cell.x, (uint)cell.y, fk + 7100u)) < gR2ShpSplitRate * gR2Dt) {
            float h8 = r2Rand(uint3((uint)cell.y, (uint)cell.x, fk + 7101u));
            float fs = cA ? 0.12 + 0.1 * saturate((A8 - gR2ShpSplitA) / gR2ShpSplitA) + 0.08 * h8 : 0.06 + 0.08 * h8;
            float rc = rmm * pow(max(fs, 1e-4), 0.3333);
            float eP = 0.55 * e8;                                   // the parent after losing its tail
            float AP = sqrt((0.5 + eP) / (0.5 - eP));
            // R2b: at the DRAWN footprints (R3 cap scale of the flatness; the volume radius put the piece inside its parent)
            float csP = r2CapScale(r2UnpackSeed(s.w), max(max(r2UnpackBF(sh.w).y, gR2BaseSpread), 1.0));
            float distMM = gR2CoalesceK * csP * (rmm * pow(max(1.0 - fs, 1e-4), 0.3333) * sqrt(AP) + rc) + 0.12;
            float2 tb = -u8 * (dot(d8, u8) >= 0.0 ? 1.0 : -1.0);  // the tail end of the axis
            float2 cd = dest + tb * distMM / gR2CellSizeMM;
            int2 cc = int2(floor(cd)) - cell;
            if (rc >= 1.2 * gR2MinRadiusMM && all(abs(cc) <= int2(2, 2)) && any(int2(floor(cd)) != int2(floor(dest)))
                && r2Valid(cd / gR2Cells) > 0.5) {
                o.cDest = cd;
                o.cVol = fs * vol;
                o.cPhi = atan2(tb.y, tb.x);
                vol -= o.cVol;
            }
        }
    }
    o.dest = dest;
    o.vol = vol;
    o.alive = 1;
    o.moved = length(dc);
    return o;
}

// Distance from point p to segment ab.
float r2SegDist(float2 p, float2 a, float2 b) {
    float2 ab = b - a;
    float l2 = dot(ab, ab);
    float k = l2 > 1e-10 ? saturate(dot(p - a, ab) / l2) : 0.0;
    return length(p - (a + ab * k));
}
