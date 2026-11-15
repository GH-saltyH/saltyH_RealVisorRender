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
