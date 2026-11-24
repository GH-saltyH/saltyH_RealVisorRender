// Shared by the simulation (prepended to common.hlsl) and the visor / rec (prepended to cand.hlsl): trail geometry
// packing (TR0) and the bead row of a broken line (TR2b), so the passes that write and draw them cannot drift apart.
// TR0 (docs/RAINFX_V2_TRAIL_REVIEW2.md section 6) TRAIL GEOMETRY TG (field resolution, RGBA32F), written after every cells
// substep: xy = nearest centre-line point (mm from the texel centre), z = direction (rad) + 8 x frame tag (frame mod 1023; 1023 = old: the trail pass
// re-tags every line it does not refresh, so a tag never wraps back to 'fresh'),
// w = half-width hw (mm, < 2) + 2 x round(centre depth / 1e-4 mm). A line tagged this frame is FRESH (the head's tail, drawn
// as a line, its depth laid into field R once); older lines have broken into bead rows (TR1: their edge angle
// atan(2 h0 / hw) <= 24 deg < theta_r(wet) -> they dewet within ~1 ms, r2DewetSpeedMMs).
float4 r2TgPack(float2 ptMM, float ang, float hw, float depth) {
    return float4(ptMM, ang + 8.0 * fmod(gR2Frame, 1023.0), min(hw, 1.99) + 2.0 * round(depth * 1e4));
}
float r2TgHw(float4 g) { return g.w - 2.0 * floor(g.w * 0.5); }
float r2TgDepth(float4 g) { return floor(g.w * 0.5) * 1e-4; }
float r2TgTag(float4 g) { return floor((g.z + 4.0) / 8.0); }
float r2TgAngle(float4 g) { return g.z - 8.0 * r2TgTag(g); }
bool r2TgFresh(float4 g) { return g.w > 1e-4 && abs(r2TgTag(g) - fmod(gR2Frame, 1023.0)) < 0.5; }
float4 r2TgOld(float4 g) { return float4(g.xy, r2TgAngle(g) + 8.0 * 1023.0, g.w); }
// Rayleigh-Plateau row of a broken line (half-width hw, centre depth h0, parabolic section (4/3) h0 hw):
// x = bead spacing 9 hw, y = bead cap radius (volume = spacing x section, cap of the drawn contact angle)
float2 r2BeadRow(float hw, float h0) {
    float lam = 9.0 * hw;
    return float2(lam, pow(max(lam * 1.3333 * h0 * hw / max(gR2ShapeK, 1e-3), 1e-12), 0.3333));
}
// B1 DROP TAIL STATE (docs/RAINFX_V2_TRAIL_REVIEW3.md section 11): S quarter 3 (x + 3 cells) of the drop's cell. A fast drop
// (Ca > Ca*) is a head + an ATTACHED tail lying on its own recent path (Podgorski 2001 / Le Grand 2005, W0 prototype B).
// x, y, z = tail centre-line points q1, q2, q3 (mm from the head centre, at 1/3, 2/3, 1 of the tail), w = 1 + packed
// (L target mm, spare); w = 0: no tail. Two 12-bit fixed values per float (integer-valued, exact in fp32).
#define R2_TAIL_RANGE 24.0   // mm, |q| range of the packed points
float r2TailPack2(float2 v, float range) {
    float2 q = clamp(round((v / range * 0.5 + 0.5) * 4095.0), 0.0, 4095.0);
    return q.x + 4096.0 * q.y;
}
// B3e TT x: centre-line point offset (2 x 10 bit, +-8 mm, 15.6 um) + the neck fraction nk (4 bit; 0 = at the head, 1 = rivulet)
float r2TailPackQ(float2 q, float nk) {
    float2 a = clamp(round((q / 16.0 + 0.5) * 1023.0), 0.0, 1023.0);
    return a.x + 1024.0 * a.y + 1048576.0 * clamp(round(nk * 15.0), 0.0, 15.0);
}
float2 r2TailUnpackQ(float f, out float nk) {
    float n = floor(f / 1048576.0);
    float r = f - 1048576.0 * n;
    float y = floor(r / 1024.0);
    nk = n / 15.0;
    return (float2(r - 1024.0 * y, y) / 1023.0 - 0.5) * 16.0;
}
float2 r2TailUnpack2(float f, float range) {
    float y = floor(f / 4096.0);
    float x = f - 4096.0 * y;
    return (float2(x, y) / 4095.0 - 0.5) * 2.0 * range;
}
// B3c-g tail profile at arc a behind the drawn rear edge (shared: tailtex selects, the visor draws -- B3g exact per pixel; no early
// returns: FXC /O3). PP = (dIn, W, w0, hw_r), PH = (h_neck, h_r, visible length Lv, 1 / varicose spacing); ph = varicose phase at a
// (visor mm along the line / spacing), vph = per-drop phase. Returns (w, h), w <= 3.9 mm.
float2 r2TailProf(float a, float ph, float vph, float4 PP, float4 PH) {
    // L2 SWEPT NECK (docs/RAINFX_V2_TRAIL_REVIEW3.md section 57): the tail starts at the HEAD CENTRE (a = -PP.x, PP.x = drawn rear
    // radius) with the head's own cross-section (half-width W, apex h_cap) and narrows to the rivulet over the head + 2.1 W; the
    // section always contains the head's section behind its centre -> the union is the swept tail there (no head rim crossing
    // the neck: the head / tail seam of section 30-32 and the game review 2026-11-25)
    float nk = smoothstep(0.0, 1.0, saturate((a + PP.x) / max(PP.x + 2.1 * PP.y, 1e-3)));
    float w = lerp(PP.z, PP.w, nk);
    float h = lerp(PH.x, PH.y, nk);
    float te = saturate((PH.z - a) / max(0.25 * PH.z, 1e-3));                          // end taper (last 25 %)
    w *= pow(te, 0.7); h *= te;
    w *= 1.0 + 0.15 * nk * sin(6.2831853 * ph + vph);
    return float2(min(w, 3.9), h);
}
float r2TailNeck(float a, float4 PP) { return smoothstep(0.0, 1.0, saturate((a + PP.x) / max(PP.x + 2.1 * PP.y, 1e-3))); }
// B3g TP texel (one per big-drop tile): x = (R_rear [L2: head centre], W), y = (w0, hw_r) [+-8 mm], z = (h_neck, h_r) [+-4 mm], w = 1 + (Lv [+-64 mm],
// vph / 2 pi x 60) -- 12-bit pairs (r2TailPack2)
float4 r2TailTPPack(float4 PP, float4 PH, float vph) {
    return float4(r2TailPack2(PP.xy, 8.0), r2TailPack2(PP.zw, 8.0), r2TailPack2(PH.xy, 4.0),
                  1.0 + r2TailPack2(float2(PH.z, frac(vph * 0.15915494) * 60.0), 64.0));
}
void r2TailTPUnpack(float4 g, out float4 PP, out float4 PH, out float vph) {
    PP = float4(r2TailUnpack2(g.x, 8.0), r2TailUnpack2(g.y, 8.0));
    float2 lz = r2TailUnpack2(g.w - 1.0, 64.0);
    PH = float4(r2TailUnpack2(g.z, 4.0), lz.x, 1.0 / max(9.0 * PP.w, 0.05));
    vph = lz.y / 60.0 * 6.2831853;
}
struct R2Tail { float2 q1; float2 q2; float2 q3; float L; bool on; };
R2Tail r2TailUnpack(float4 tl) {
    R2Tail r;
    r.on = tl.w > 0.5;
    r.q1 = r.on ? r2TailUnpack2(tl.x, R2_TAIL_RANGE) : float2(0, 0);
    r.q2 = r.on ? r2TailUnpack2(tl.y, R2_TAIL_RANGE) : float2(0, 0);
    r.q3 = r.on ? r2TailUnpack2(tl.z, R2_TAIL_RANGE) : float2(0, 0);
    r.L = r.on ? max(r2TailUnpack2(tl.w - 1.0, 64.0).x, 0.0) : 0.0;
    return r;
}
float4 r2TailPack(R2Tail r) {
    return r.on ? float4(r2TailPack2(r.q1, R2_TAIL_RANGE), r2TailPack2(r.q2, R2_TAIL_RANGE), r2TailPack2(r.q3, R2_TAIL_RANGE),
                         1.0 + r2TailPack2(float2(r.L, 0.0), 64.0)) : float4(0, 0, 0, 0);
}
// Value noise (moved from common.hlsl, B1d) and the B1d coat factor (docs/RAINFX_V2_TRAIL_REVIEW3.md section 18; comments at
// common r2CoatSet): theta_r = theta_r0 (1 - wetK wet) x r2CoatFactor -- wear D (J1 strong-defect noise x level), test dirt C,
// wetting memory M (field G).
float r2Hash21(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
float r2VNoise(float2 p) {
    float2 i = floor(p), f = p - i;
    f = f * f * (3.0 - 2.0 * f);
    return lerp(lerp(r2Hash21(i), r2Hash21(i + float2(1, 0)), f.x),
                lerp(r2Hash21(i + float2(0, 1)), r2Hash21(i + float2(1, 1)), f.x), f.y);
}
float r2CoatFactor(float2 t, float mem) {
    float2 pMM = t * gR2CellSizeMM * gR2Cells;
    float v = r2VNoise(pMM * gR2StrongInvMM + float2(5.1, 9.7) + gR2CoatSeed);
    float S = saturate((v - gR2StrongThr) / max(1.0 - gR2StrongThr, 1e-3));
    float D = gR2CoatWear * (0.3 + 0.7 * sqrt(S));
    float C = gR2TestDirt * (0.5 + 0.5 * r2VNoise(pMM / max(gR2DirtMM, 0.1) + float2(71.3, 17.9) + gR2CoatSeed));
    return max((1.0 - gR2CoatKD * D) * (1.0 - gR2CoatKC * C) * (1.0 - gR2CoatKM * saturate(mem)), 0.2);
}
