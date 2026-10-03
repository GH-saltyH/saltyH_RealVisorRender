/*
    rainVisorLayer.hlsl - visor KN5 parts drawn inside the post overlay
    (docs/RAINFX_VISOR_LAYER.md).

    Drawn by realvisor.lua with render.mesh({mesh = <KN5 SceneReference>,
    transform = 'original'}) inside the visor overlay GeometryShot, after
    post-processing. Output is LDR and PREMULTIPLIED (rgb * a, a):
    housing is opaque (a = 1, depth write), glass layers are blended
    back to front with BlendPremultiplied (depth read-only).

    gLayerKind
      0 housing  : V2 material (gLayerMat 0 frame, 1 glossy rubber,
                   2 alcantara fabric), a = 1
      1 GLASS_EXT: band where txLayerDiffuse.a ~ 1 (blocks the scene by
                   gLayerBandOpacity), faint film elsewhere (V1)
      2 glass    : faint film (GLASS_INT, GLASS_COATING) (V1)

    Light model (LDR, the frame is already tone mapped), s45:
      ambient = hemisphere chroma (horizon -> sky, from WeatherFX colours,
                luminance-normalised and desaturated in Lua) x LUMINANCE of
                the final-frame mean x gain x up/down occlusion.
                (s44 used the frame mean colour itself: against a bright
                sky the parts glowed in the sky tone, even when backlit.)
      sun     = light colour normalised x gain x N.L. gLayerLightDir points
                TOWARD the light (Lua negates sim.lightDirection, which
                points from the light into the scene: s44 lit the back).
    PS_IN has no tangent (docs/RAINFX_VISOR_GLASS.md §6): normal maps use
    a derivative cotangent frame.
*/

float2 rainLayerWrapUV(float2 uv) { return frac(uv); }

// Samplers are effectively clamp (docs/RAINFX_SMEAR_MASK.md): wrap by
// hand and keep the derivatives of the unwrapped UV for correct mips.
float4 rainLayerSample(Texture2D tx, float2 uv)
{
    return tx.SampleGrad(samLinearClamp, frac(uv), ddx(uv), ddy(uv));
}

// Schüler cotangent frame from screen derivatives.
float3x3 rainLayerTBN(float3 n, float3 p, float2 uv)
{
    float3 dp1 = ddx(p);
    float3 dp2 = ddy(p);
    float2 duv1 = ddx(uv);
    float2 duv2 = ddy(uv);
    float3 dp2perp = cross(dp2, n);
    float3 dp1perp = cross(n, dp1);
    float3 t = dp2perp * duv1.x + dp1perp * duv2.x;
    float3 b = dp2perp * duv1.y + dp1perp * duv2.y;
    float invmax = rsqrt(max(max(dot(t, t), dot(b, b)), 1e-20));
    return float3x3(t * invmax, b * invmax, n);
}

float3 rainLayerNormal(float3 n, float3 p, float2 uv)
{
    if (gLayerUseNormal < 0.5 || gLayerNormalStrength <= 0.0)
        return n;
    float2 xy = rainLayerSample(txLayerNormal, uv).rg * 2.0 - 1.0;
    if (gLayerNormalFlipG > 0.5)
        xy.y = -xy.y;
    xy *= gLayerNormalStrength;
    // Reconstruct z: works for RGB and two-channel (BC5) normal maps.
    float3 tn = float3(xy, sqrt(saturate(1.0 - dot(xy, xy))));
    float3x3 tbn = rainLayerTBN(n, p, uv);
    return normalize(mul(tn, tbn));
}

// s49 scene-shadow probe: a second copy of the visor housing is drawn IN
// THE SCENE with a dark, unlit-ambient, spec-free material, so CSP lights
// it with its real shadow maps (trees, buildings, car). Its HDR pixels are
// copied at the drop stage (txLayerProbe: rgb HDR, a = linear depth m).
// shadow = probe luminance / (albedo x sun luminance x N.L).
float rainLayerProbeShadow(float2 posH, float3 n)
{
    if (gLayerProbeOn < 0.5)
        return 1.0;
    float nl = dot(n, gLayerLightDir);
    if (nl < gLayerProbeMinNL)
        return 1.0;                 // grazing / back-facing: no signal
    float2 uv = saturate(posH * gLayerInvShotSize);
    float4 p = txLayerProbe.SampleLevel(samLinearClamp, uv, 0.0);
    if (p.a > gLayerProbeMaxDepth)
        return 1.0;                 // not the probe (edge / jitter)
    float lum = dot(p.rgb, float3(0.2126, 0.7152, 0.0722));
    float expected = gLayerProbeAlbedo * gLayerSunHDRLum * nl
        * gLayerProbeGain;
    float s = saturate(lum / max(expected, 1e-5));
    return lerp(1.0, s, saturate(gLayerProbeStrength));
}

float3 rainLayerAmbient(float3 n, float frameLum)
{
    float up = saturate(n.y * 0.5 + 0.5);
    float3 hemi = lerp(gLayerAmbHorizon, gLayerAmbSky, up);
    return hemi * frameLum * gLayerAmbientGain
        * lerp(gLayerAmbFloor, 1.0, up);
}

float4 main(PS_IN pin)
{
    float3 toEye = normalize(-pin.PosC);
    float3 ng = normalize(pin.NormalW);
    if (dot(ng, toEye) < 0.0)
        ng = -ng;                       // two-sided
    float frameLum = dot(txLayerSource.SampleLevel(samLinearClamp,
        float2(0.5, 0.4), gLayerAmbientMip).rgb,
        float3(0.2126, 0.7152, 0.0722));
    float3 amb = rainLayerAmbient(ng, frameLum);

    float4 d = gLayerUseDiffuse > 0.5
        ? rainLayerSample(txLayerDiffuse, pin.Tex)
        : float4(gLayerColor, 1.0);

    // s50: the scene-shadow probe is the only shadow source (s48 self-
    // shadow and ray shadow removed to avoid conflicts).
    float shadow = rainLayerProbeShadow(pin.PosH.xy, ng);
    float3 sunL = gLayerSun * shadow;
    if (gLayerProbeDebug > 0.5 && gLayerKind < 0.5)
        return float4(shadow, shadow, shadow, 1.0);

    if (gLayerKind < 0.5)
    {
        float3 n = rainLayerNormal(ng, pin.PosC, pin.Tex);
        amb = rainLayerAmbient(n, frameLum);
        // s47: non-directional scattered light (interior parts): sun light
        // bounced inside the shell / off the face, plus scene light coming
        // in through the visor opening. Zero for exterior parts.
        amb += gLayerBounce + gLayerAmbHorizon * (gLayerBounceFrame * frameLum);
        float3 l = gLayerLightDir;
        float nl = dot(n, l);
        float nv = saturate(dot(n, toEye));
        float4 m = gLayerUseMaps > 0.5
            ? rainLayerSample(txLayerMaps, pin.Tex)
            : float4(1.0, 1.0, 1.0, 1.0);
        // txMaps convention of AC ksPerPixelMultiMap: R spec, G gloss,
        // B reflection.
        float specMask = m.r;
        float gloss = saturate(gLayerGloss * m.g);
        float expo = lerp(4.0, 256.0, gloss * gloss);
        float3 h = normalize(l + toEye);
        float spec = pow(saturate(dot(n, h)), expo) * (nl > 0.0 ? 1.0 : 0.0)
            * gLayerSpec * specMask * (expo + 8.0) / 64.0;
        float fres = pow(1.0 - nv, 5.0);

        float3 c;
        if (gLayerMat > 1.5)
        {
            // Alcantara: wrapped diffuse, no sharp specular, soft sheen at
            // grazing angles (fibres catch the light), strong fuzzy normal.
            float wrap = saturate((nl + 0.45) / 1.45);
            float sheen = pow(1.0 - nv, gLayerSheenPower) * gLayerSheen
                * lerp(0.6, 1.0, m.g);
            float3 lit = amb + sunL * wrap;
            // s51: fibre highlight under DIRECT light only (sunL already
            // carries the probe shadow): a broad lobe (spec, txMaps R mask,
            // txMaps G gloss) plus a lit-zone lift so sunlit patches read
            // crisper than the shaded fabric. s44-s50 scaled spec by 0.15,
            // which is why FABRIC_SPEC had no visible effect.
            float fibre = specMask * gLayerSpec * saturate(nl)
                * gLayerFabricLitLift;
            c = d.rgb * lit + sheen * lit * lerp(d.rgb, 1.0, 0.35)
                + (spec + fibre) * sunL;
        }
        else
        {
            // Frame / glossy rubber: Lambert + Blinn highlight + Fresnel
            // environment (the frame mean stands in for the environment).
            float3 lit = amb + sunL * saturate(nl);
            float env = lerp(0.04, 1.0, fres) * gLayerSpec * 0.6
                * lerp(0.5, 1.0, m.b);
            c = d.rgb * lit + spec * sunL + env * amb;
        }
        return float4(saturate(c), 1.0);
    }

    float a = gLayerGlassAlpha;
    float3 c = amb;
    if (gLayerKind < 1.5)
    {
        float nl = saturate(dot(ng, gLayerLightDir));
        float band = smoothstep(0.96, 0.995, d.a);
        a = lerp(gLayerGlassAlpha, gLayerBandOpacity, band);
        c = lerp(amb, d.rgb * (amb + sunL * nl), band);
    }
    a = saturate(a);
    return float4(saturate(c) * a, a);
}
