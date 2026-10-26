// P3 (rev5): refraction source = the frame copied BEFORE the visor glass stack
// (glass stack fallbackSource), with the helmet housing removed.
// The housing (FRAME, BAND_INNER, fabric, CAM) is a native KN5 draw, so it is in the
// frame copy and in the depth buffer. A drop sits OUTSIDE the visor: a ray bent by it
// continues into the world, never into the housing. Housing pixels (linear depth below
// gR2HousingM) get weight 0; output is premultiplied (rgb*w, w) so the mip chain is a
// push-pull hole fill (visor.hlsl r2Scene composites fine mips over coarse ones).
// Target: half-resolution RGBA16F with full mips (the refracted image is always blurred).

float4 main(PS_IN pin) {
    float3 c = txR2Src.SampleLevel(samLinearClamp, pin.Tex, 0).rgb;
    float d = txR2Depth.SampleLevel(samPointClamp, pin.Tex, 0).r;
    if (gR2DepthReversed > 0.5) d = 1.0 - d;
    float lin = d > 0.99999 ? 10000.0 : gR2Near * gR2Far / max(gR2Far - d * (gR2Far - gR2Near), 1e-7);
    float w = lin > gR2HousingM ? 1.0 : 0.0;
    return float4(c * w, w);
}
