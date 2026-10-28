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

// rev40 stagnation turbulence (docs/RAINFX_V2_DROP_PIPELINE_PLAN.md step 2). Driving straight,
// the air meets the visor centre along the normal: the mean tangential air is ~0 there and small
// drops would stay pinned and pile up forever. The real helmet sits in turbulent flow whose
// tangential gusts rock and occasionally move them. Random tangential air (world vector): value
// noise over gR2TurbScale (cells of turbMM) blended between time slices of gR2TurbTau, magnitude
// turbK x the surface share of the relative air. Position + time only -> identical in every
// gathering cell (the gather stays consistent).
float3 r2TurbAir(float2 t, float3 du, float3 dv) {
    float ts = gR2Time / max(gR2TurbTau, 1e-3);
    float i = floor(ts), f = ts - i;
    f = f * f * (3.0 - 2.0 * f);
    float2 p = t * gR2TurbScale;
    float2 o0 = float2(fmod(i, 251.0) * 7.31, fmod(i, 241.0) * 3.17);
    float2 o1 = float2(fmod(i + 1.0, 251.0) * 7.31, fmod(i + 1.0, 241.0) * 3.17);
    float2 n0 = float2(r2VNoise(p + o0), r2VNoise(p + o0 + 91.7));
    float2 n1 = float2(r2VNoise(p + o1), r2VNoise(p + o1 + 91.7));
    float2 g = lerp(n0, n1, f) * 2.0 - 1.0;
    float3 eu = du * rsqrt(max(dot(du, du), 1e-20));
    float3 ev = dv - eu * dot(dv, eu);
    ev *= rsqrt(max(dot(ev, ev), 1e-20));
    return (eu * g.x + ev * g.y) * (max(gR2TurbK, 0.0) * gR2AirSurface * length(gR2AirW));   // single exit (FXC)
}

// Drop velocity in tex-uv per second. Memoryless terminal-velocity model:
// gravity+inertia and air drag against contact-angle hysteresis (pinning).
// Mirrored 1:1 by rainfx2/physics.lua (P.forces / P.speed) for review and diagnostics.
// rev41: drive = Fpin / |F| of a moving drop (1 = just depinned, -> 0 = driven far above pinning);
// the path heterogeneity (r2Steer) scales with it: weakly driven drops meander, strongly driven
// drops follow the force in nearly straight lines.
float2 r2DropVelocity(float2 t, float radiusMM, float pinNoise, out float speed, out float drive) {
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
    float xb = 0.6 * radiusMM / max(gR2BLDeltaMM, 1e-3);
    float3 air = ue * (xb < 1.0 ? xb * (2.0 - xb) : 1.0);
    float gl = length(g);
    air += (gl > 1e-4 ? g * (gR2AirDown * length(air) / gl) : float3(0, 0, 0)) + r2TurbAir(t, du, dv);
    float airLen = length(air);
    float3 Fa = (0.25 * gR2RhoAir * gR2DragCd * R2_PI * r * r * airLen) * air
              + ue * (gR2ShapeK * radiusMM * radiusMM * radiusMM * 1e-9 * gR2RhoAir * gR2AeroDuDs * max(cn, 0.0));
    float3 F = mass * g + Fa;
    float Fm = length(F);
    float pinCos = lerp(gR2PinGlass, gR2PinCoat, saturate(dvA.a));
    float Fpin = gR2SurfaceTension * 2.0 * r * pinCos * pinNoise;
    if (Fm <= Fpin) return float2(0, 0);
    drive = Fpin / max(Fm, 1e-12);
    // rev42 (rev41 recording): the visor is ~5 cm from the eye, 1 mm ~ 30 px, so 0.3 m/s is ~150 px per
    // frame -- every moving drop read as a jump / flash. Two regimes now:
    //  * blown off: the AIR drag alone exceeds gR2ShedK x pinning -> the drop is torn off at once
    //    (speed sentinel above gR2VShed, the caller removes it);
    //  * creeping: quasi-steady speed, saturated smoothly at gR2VMax (tanh, a few cm/s).
    float vq = (Fm - Fpin) / (gR2Friction * max(r, 1e-5));
    // rev43 (rev42 sprint recording: every moving drop crept at the same capped speed, a 'conveyor'):
    // graded saturation v = vMax (1 - exp(-vq / vScale)) keeps big / strongly driven drops faster.
    // rev47b RUNBACK (rev47 review: the visor dried up with speed): a drop whose air load exceeds
    // shedK x pinning is not blown off the surface -- it slides with the air (runback, speed ~ runbackK x
    // the air at its top, at most runbackMax), sweeps and merges, leaves a trail, and leaves the visor
    // only over an edge. Only drops above gR2LiftMM lift off (flight sentinel 1e3).
    bool blown = length(Fa) > gR2ShedK * Fpin;
    // rev47l (rev47k review): rev47b-k wrote clamp(runbackK air, vMax 0.08, runbackMax 0.06) = 0.06 for EVERY
    // blown drop (lower bound above the upper) -- all runback drops slid at one speed and all left trails.
    // Now the speed grows with the excess of the air load over the blow-off load (big drops: air ~ r^2,
    // pinning ~ r), continuous with the creeping regime below it.
    float vCreep = gR2VMax * (1.0 - exp(-vq / max(gR2VScale, 1e-4)));
    float excess = saturate(1.0 - gR2ShedK * Fpin / max(length(Fa), 1e-12));
    float vRun = max(min(vCreep, gR2RunbackMax), min(gR2RunbackK * airLen * excess, gR2RunbackMax));
    speed = blown ? (radiusMM > gR2LiftMM ? 1e3 : vRun) : vCreep;
    // rev45: a blown-off drop returns the force DIRECTION (1 m/s) so the caller can launch it (flight)
    float3 v = F * ((speed > gR2VShed ? 1.0 : speed) / Fm);
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
float2 r2Steer(float2 t, float2 vt, float drive) {
    float2 texMM = gR2CellSizeMM * gR2Cells;
    float2 vm = vt * texMM;                                   // mm/s on the visor
    float sp = length(vm);
    float2 res = vt;
    if (sp > 1e-3 && (gR2Meander > 0 || gR2TrailFollow > 0)) {
        float2 dir = vm / sp;
        float2 side = float2(-dir.y, dir.x);
        float nz = r2VNoise(t * gR2MeanderScale) * 2.0 - 1.0;
        float2 ahead = t + dir * (1.5 / texMM);
        float tl = txR2Field.SampleLevel(samLinearClamp, ahead + side * (1.0 / texMM), 0).r;
        float tr = txR2Field.SampleLevel(samLinearClamp, ahead - side * (1.0 / texMM), 0).r;
        float lat = clamp((gR2Meander * nz + gR2TrailFollow * (tl - tr)) * saturate(drive), -0.5, 0.5);
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
    float h = gR2TrailLL * rmm * pow(ca, 0.6667);
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
    float hw;
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
};
R2Move r2Predict(int2 cell, float4 s, float4 L) {
    R2Move o;
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
    } else if (L.y > 0) {
        // flying (blown off): leaves along its launch direction at gR2FlySpeed, losing trail water
        o.life.y = L.y - gR2Dt;
        gone = o.life.y <= 0;
        dc = float2(cos(L.w), sin(L.w)) * (gR2FlySpeed * 1000.0 * gR2Dt) / gR2CellSizeMM;
    } else {
        // rev41: pinning heterogeneity is a smooth surface field (gR2PinScale, ~4 mm features).
        float pinNoise = lerp(gR2PinNoiseMin, gR2PinNoiseMax, r2VNoise(t * gR2PinScale + 53.1));
        // rev8: kinetic hysteresis (a moving contact line is held less than a resting one).
        float2 lastMove = r2UnpackMove(s.w);
        if (dot(lastMove, lastMove) > 1e-6) pinNoise *= gR2PinKinetic;
        float speed;
        float drive;
        float2 vt = r2DropVelocity(t, rmm, pinNoise, speed, drive);
        if (speed > gR2VShed) {
            // blown off: launch (rev42-44 deleted the drop at once -> it 'teleported' away)
            float2 dcell = vt * gR2Cells;
            float2 dirc = dcell * rsqrt(max(dot(dcell, dcell), 1e-20));
            o.life.y = gR2FlyTime;
            o.life.w = atan2(dirc.y, dirc.x);
            dc = dirc * (gR2FlySpeed * 1000.0 * gR2Dt) / gR2CellSizeMM;
        } else {
            vt = r2Steer(t, vt, drive);
            // rev47 drop inertia (rev46 review: car jolts gave 'lightning' zig-zags): the speed relaxes
            // to the force-driven target over gR2DropTau; the previous speed is the packed move of the
            // last frame (substep 1) or of the substeps so far in this frame. A reversed force first
            // brakes the drop through zero instead of flipping its direction.
            float prevDur = gR2Sub > 1.5 ? (gR2Sub - 1.0) * gR2Dt : gR2SimDt;
            float2 vPrev = lastMove / max(prevDur, 1e-4);              // cells / s
            float2 vTgt = vt * gR2Cells;
            float tauI = speed > gR2VMax * 1.01 ? gR2SlideTau : gR2DropTau;   // rev47b: runback slides longer
            float kI = tauI > 1e-4 ? 1.0 - exp(-gR2Dt / tauI) : 1.0;
            float2 vNew = vPrev + (vTgt - vPrev) * kI;
            // rev47a (rev47 review, rev47_unacceptableMovement.mp4: small drops crept ~2 mm/s with no air
            // and no motion): the stop test compared mm^2/s^2 against 4e-6 (meant 4 = 2 mm/s), so it never
            // fired, and the packed move (1/31.25 cell steps) rounds 0.7 of a step back up to a full step:
            // vPrev -> 0.7 vPrev -> rounds to 1 step -> perpetual creep at one step per frame. A drop with
            // no driving force now stops once it is slower than 1.5 packing steps per frame or 3 mm/s.
            float stopMMs = max(3.0, 1.5 * length(gR2CellSizeMM) / 31.25 / max(prevDur, 1e-4));
            if (dot(vTgt, vTgt) <= 0.0 && length(vNew * gR2CellSizeMM) < stopMMs) vNew = float2(0, 0);
            dc = vNew * gR2Dt;
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
    float hwT;
    float hT0 = r2TrailRule(rmm, vms, wet, hwT);
    vol -= 1.3333 * hT0 * hwT * travelMM;   // rev47j/l: parabolic rivulet section (4/3) h0 hw
    vol += (Fs.g * gR2HazeDepthMM + Fs.b * gR2FilmMaxMM * gR2FilmCollect) * 2.0 * rmm * travelMM;
    vol -= gR2Evap * gR2Dt * R2_PI * rmm * rmm;
    // Keep the destination inside the 5x5 gather window (merged drops may sit off-cell).
    float2 dest = float2(cell) + clamp(s.xy + dc, -1.99, 2.99);
    if (gone || r2Valid(dest / gR2Cells) < 0.5) return o;  // gone / absorbing boundary / hole
    if (r2RadiusMM(vol) < gR2MinRadiusMM) return o;           // residue only (the trail keeps it)
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
