// P3 (rev5): refraction source = the frame copied BEFORE the visor glass stack
// (glass stack fallbackSource), with the helmet housing removed.
// The housing (FRAME, BAND_INNER, fabric, CAM) is a native KN5 draw, so it is in the
// frame copy and in the depth buffer. A drop sits OUTSIDE the visor: a ray bent by it
// continues into the world, never into the housing. Housing pixels (linear depth below
// gR2HousingM, or covered by the H-mask housing shot) get weight 0; output is premultiplied (rgb*w, w) so the mip chain is a
// push-pull hole fill (visor.hlsl r2Scene composites fine mips over coarse ones).
// Target: half-resolution RGBA16F with full mips (the refracted image is always blurred).

float4 main(PS_IN pin) {
    float3 c = txR2Src.SampleLevel(samLinearClamp, pin.Tex, 0).rgb;
    float d = txR2Depth.SampleLevel(samPointClamp, pin.Tex, 0).r;
    if (gR2DepthReversed > 0.5) d = 1.0 - d;
    float lin = d > 0.99999 ? 10000.0 : gR2Near * gR2Far / max(gR2Far - d * (gR2Far - gR2Near), 1e-7);
    float w = lin > gR2HousingM ? 1.0 : 0.0;
    // H-mask (docs/RAINFX_V2_TRAIL_REVIEW3.md section 59): the housing's own coverage at this view (half res, bilinear x 2 = a half
    // texel dilation so its antialiased rim does not leak into the hole fill). Nothing is nearer than the housing inside the helmet,
    // so covered = housing at any depth; car parts touching the visor (not covered) stay whatever their depth.
    // H-mask3: the mask = the housing meshes drawn flat (alpha 1) into their own shot, cleared to 0. 4 point taps half a mask
    // texel apart = the dilation.
    if (gR2HousingMaskOn > 0.5) {
        float hc = 0.0;
        [unroll] for (int k = 0; k < 4; ++k) {
            float2 o = (float2(k & 1, k >> 1) - 0.5) * gR2HousingMaskTexel;
            hc = max(hc, txR2HousingMask.SampleLevel(samPointClamp, pin.Tex + o, 0).a);   // H-mask3: flat shader, alpha 1 = housing
        }
        w *= 1.0 - hc;
    }
    // R-img5 (docs/RAINFX_V2_TRAIL_REVIEW3.md section 52): store c / (1 + luma) so a mip / blur averages the TONE, not the radiance -- a
    // small HDR light no longer floods every coarse texel (whole drops took the light's colour); the visor inverts after sampling.
    if (gR2SceneCompress > 0.5) c /= 1.0 + gR2CompressK * dot(c, float3(0.2126, 0.7152, 0.0722));   // k = strength (0 = linear)
    return float4(c * w, w);
}
