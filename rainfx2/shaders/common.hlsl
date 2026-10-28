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
float r2Exposure(float2 t) {
    return saturate(dot(gR2RainDirW, -r2Normal(t)) * gR2NormalSign + gR2ExposureFloor);
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
    float3 airM = (gR2AirW - n * dot(gR2AirW, n)) * gR2AirSurface;
    // rev42 observed downward flow (user, real onboard video: once the wind hits, drops run DOWN;
    // DROP_PIPELINE_PLAN section 5). The helmet/cockpit flow cannot be modelled; a share gR2AirDown
    // of the mean surface air is turned along the visor's downhill direction.
    float gl = length(g);
    float3 air = airM + (gl > 1e-4 ? g * (gR2AirDown * length(airM) / gl) : float3(0, 0, 0))
               + r2TurbAir(t, du, dv);
    float airLen = length(air);
    float3 Fa = (0.25 * gR2RhoAir * gR2DragCd * R2_PI * r * r * airLen) * air;
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
    speed = length(Fa) > gR2ShedK * Fpin ? 1e3 : gR2VMax * (1.0 - exp(-vq / max(gR2VScale, 1e-4)));
    if (speed > gR2VShed) return float2(0, 0);               // shed (caller checks speed)
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

// One drop step. Every gathering cell evaluates this identically for a source.
struct R2Move {
    float2 dest;   // absolute cell coordinates after the step
    float vol;     // mm^3 after losses
    float alive;   // 0: none / shed / left the surface
    float moved;   // cells travelled
};
R2Move r2Predict(int2 cell, float4 s) {
    R2Move o;
    o.dest = float2(cell) + s.xy;
    o.vol = 0;
    o.alive = 0;
    o.moved = 0;
    if (s.z <= 0) return o;
    float2 t = (float2(cell) + s.xy) / gR2Cells;
    float rmm = r2RadiusMM(s.z);
    // rev41: pinning heterogeneity is a smooth surface field (gR2PinScale, ~4 mm features) instead of
    // white noise per 1.2 mm cell, which made a drop near its threshold stop and start at every cell
    // edge (jerky "lightning" motion, rev40 review). Position only -> same in every gathering cell.
    float pinNoise = lerp(gR2PinNoiseMin, gR2PinNoiseMax, r2VNoise(t * gR2PinScale + 53.1));
    // rev8: kinetic hysteresis. A drop that moved in the last step/frame is held by the
    // (smaller) receding/advancing hysteresis of a moving contact line: once depinned it
    // keeps sliding instead of stopping at the first strong cell (rev7 permanent traps).
    float2 lastMove = r2UnpackMove(s.w);
    if (dot(lastMove, lastMove) > 1e-6) pinNoise *= gR2PinKinetic;
    float speed;
    float drive;
    float2 vt = r2DropVelocity(t, rmm, pinNoise, speed, drive);
    vt = r2Steer(t, vt, drive);
    float2 dc = vt * gR2Dt * gR2Cells;
    if (speed > gR2VShed) return o;                          // shed: leaves the surface
    // rev7: a fast drop is LIMITED to the gather window instead of being deleted
    // (rev6 deleted every drop faster than ~0.28 m/s at 60 fps / 2 substeps).
    float dm = max(abs(dc.x), abs(dc.y));
    if (dm > gR2GatherCells) dc *= gR2GatherCells / dm;
    float travelMM = length(dc * gR2CellSizeMM);
    float vol = s.z - gR2TrailLoss * travelMM * rmm * rmm
                    - gR2Evap * gR2Dt * R2_PI * rmm * rmm;
    // Keep the destination inside the 5x5 gather window (merged drops may sit off-cell).
    float2 dest = float2(cell) + clamp(s.xy + dc, -1.99, 2.99);
    if (r2Valid(dest / gR2Cells) < 0.5) return o;           // absorbing boundary / hole
    if (r2RadiusMM(vol) < gR2MinRadiusMM) return o;          // residue only (trace field keeps it)
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
