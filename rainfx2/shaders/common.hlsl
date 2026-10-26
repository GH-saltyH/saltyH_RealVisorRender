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

// w = shape seed (0..15) * 2^20 + displacement (cells, |d|<8) quantised below 2^20.
// rev8: the displacement is accumulated over the substeps of one frame (P2 field and
// the physics view run once per frame), 1/62.5 cell resolution.
// The whole value stays an integer below 2^24, exact in fp32.
float r2PackMove(float2 d, float seed) {
    float2 q = round(clamp(d, -8.0, 8.0) * 62.5 + 500.0);    // 0..1000
    return clamp(floor(seed), 0.0, 15.0) * 1048576.0 + q.x * 1024.0 + q.y;
}
float r2UnpackSeed(float w) {
    return floor(w / 1048576.0);
}
float2 r2UnpackMove(float w) {
    float m = w - r2UnpackSeed(w) * 1048576.0;
    float qx = floor(m / 1024.0);
    float qy = m - qx * 1024.0;
    return (float2(qx, qy) - 500.0) / 62.5;
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

// Drop velocity in tex-uv per second. Memoryless terminal-velocity model:
// gravity+inertia and air drag against contact-angle hysteresis (pinning).
// Mirrored 1:1 by rainfx2/physics.lua (P.forces / P.speed) for review and diagnostics.
float2 r2DropVelocity(float2 t, float radiusMM, float pinNoise, out float speed) {
    speed = 0;
    float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
    float4 dvA = r2Tap(txR2Dv, t);
    float3 dv = r2ToWorld(dvA.xyz);
    float3 n = r2Normal(t);
    float r = radiusMM * 1e-3;
    float mass = 1e-6 * gR2ShapeK * radiusMM * radiusMM * radiusMM;     // kg (mm^3 * 1e-9 * 1000)
    float3 g = gR2AccelW - n * dot(gR2AccelW, n);
    float3 air = (gR2AirW - n * dot(gR2AirW, n)) * gR2AirSurface;
    float airLen = length(air);
    float3 F = mass * g + (0.25 * gR2RhoAir * gR2DragCd * R2_PI * r * r * airLen) * air;
    float Fm = length(F);
    float pinCos = lerp(gR2PinGlass, gR2PinCoat, saturate(dvA.a));
    float Fpin = gR2SurfaceTension * 2.0 * r * pinCos * pinNoise;
    if (Fm <= Fpin) return float2(0, 0);
    speed = (Fm - Fpin) / (gR2Friction * max(r, 1e-5));
    if (speed > gR2VShed) return float2(0, 0);               // shed (caller checks speed)
    speed = min(speed, gR2VMax);
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
    float pinNoise = lerp(gR2PinNoiseMin, gR2PinNoiseMax, r2Rand(uint3((uint)cell.x, (uint)cell.y, 911u)));
    // rev8: kinetic hysteresis. A drop that moved in the last step/frame is held by the
    // (smaller) receding/advancing hysteresis of a moving contact line: once depinned it
    // keeps sliding instead of stopping at the first strong cell (rev7 permanent traps).
    float2 lastMove = r2UnpackMove(s.w);
    if (dot(lastMove, lastMove) > 1e-6) pinNoise *= gR2PinKinetic;
    float speed;
    float2 vt = r2DropVelocity(t, rmm, pinNoise, speed);
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
