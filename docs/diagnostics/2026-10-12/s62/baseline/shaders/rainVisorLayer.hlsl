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
      2 glass    : faint film (GLASS_COATING) (V1)
      3 inner    : E2/E3 masked scene refraction

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

// Mesh UV is authored on a negative V tile. CSP sampler bindings can clamp
// even nominal wrap samplers, so repeat texel addresses explicitly. The UV
// from pin is unchanged; this is texture addressing, not a fitted UV region.
float4 rainLayerTextureRepeat(Texture2D tx, float2 uv)
{
    uint width, height, levels;
    tx.GetDimensions(0, width, height, levels);
    float2 size = float2(width, height);
    float footprint = max(length(ddx(uv) * size), length(ddy(uv) * size));
    uint mip = (uint)clamp(floor(log2(max(footprint, 1.0))), 0.0, (float)levels - 1.0);
    uint unusedLevels;
    tx.GetDimensions(mip, width, height, unusedLevels);
    float2 extent = float2(width, height);
    float2 texel = uv * float2(width, height) - 0.5;
    float2 p = floor(texel);
    float2 weight = frac(texel);
    int2 p0 = (int2)(p - floor(p / extent) * extent);
    int2 p1 = (int2)((p + 1.0) - floor((p + 1.0) / extent) * extent);
    float4 a = tx.Load(int3(p0, mip));
    float4 b = tx.Load(int3(p1.x, p0.y, mip));
    float4 c = tx.Load(int3(p0.x, p1.y, mip));
    float4 d = tx.Load(int3(p1, mip));
    return lerp(lerp(a, b, weight.x), lerp(c, d, weight.x), weight.y);
}

// Reconstruct the outer-band material at each refracted sample. This avoids
// framebuffer feedback and keeps opaque-band pixels from sampling outside.
float rainLayerBandCoverage(float alpha)
{
    float lo = saturate(gLayerBandAlphaMin);
    return smoothstep(lo, min(lo + 0.04, 1.0), alpha);
}
float3 rainLayerOpticsScene(float2 uv, float2 origin, float2 tex,
    float2 texDx, float2 texDy, float3 bandLight, float bandFloor)
{
    float2 deltaPixels = (uv - origin) / max(gLayerInvShotSize, 1e-8);
    float2 materialUV = tex + texDx * deltaPixels.x + texDy * deltaPixels.y;
    float4 band = txLayerBand.SampleGrad(samLinearClamp, frac(materialUV), texDx, texDy);
    float opacity = max(bandFloor, rainLayerBandCoverage(band.a)) * saturate(gLayerBandOpacity);
    float3 scene = txLayerSource.SampleLevel(samLinearClamp, uv, 0).rgb;
    return lerp(scene, band.rgb * bandLight, opacity);
}

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
    float2 xy = (gLayerKind < 0.5 && gLayerReferenceHousing > 0.5
        ? rainLayerTextureRepeat(txLayerNormal, uv)
        : rainLayerSample(txLayerNormal, uv)).rg * 2.0 - 1.0;
    if (gLayerNormalFlipG > 0.5)
        xy.y = -xy.y;
    xy *= gLayerNormalStrength;
    // Reconstruct z: works for RGB and two-channel (BC5) normal maps.
    float3 tn = float3(xy, sqrt(saturate(1.0 - dot(xy, xy))));
    float3x3 tbn = rainLayerTBN(n, p, uv);
    // s53 NaN guard: a degenerate derivative frame falls back to n.
    float3 rn = mul(tn, tbn);
    return dot(rn, rn) > 1e-12 ? normalize(rn) : n;
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

// Local ksPerPixelMultiMap reference: utils_ps.fx LightingParams.applyTxMaps
// and ext_lighting_models default Blinn-Phong. Engine AO, cubemap and local
// light/shadow resources are not exposed here; keep the existing light inputs.
float3 rainLayerReferenceHousing(PS_IN pin,float3 ng,float3 view,float frameLum,float3 sunL)
{
    float3 n=rainLayerNormal(ng,pin.PosC,pin.Tex);
    float3 diffuse=gLayerUseDiffuse>0.5
        ? rainLayerTextureRepeat(txLayerDiffuse,pin.Tex).rgb : gLayerColor;
    float3 maps=gLayerUseMaps>0.5
        ? rainLayerTextureRepeat(txLayerMaps,pin.Tex).rgb : float3(1,1,1);
    float nl=saturate(dot(n,gLayerLightDir));
    float nv=saturate(dot(n,view));
    // Keep the user's gloss control, but map G multiplies the base exponent
    // linearly (+1), rather than being squared inside an invented lobe gain.
    float baseExponent=lerp(4,256,saturate(gLayerGloss));
    float exponent=saturate(maps.g)*baseExponent+1;
    float3 halfVector=view+gLayerLightDir;
    float halfLength=dot(halfVector,halfVector);
    float nh=halfLength>1e-12 ? saturate(dot(n,halfVector*rsqrt(max(halfLength,1e-12)))) : 0;
    float specular=pow(nh,exponent)*nl*max(gLayerSpec,0)*max(maps.r,0);
    float3 ambient=rainLayerAmbient(n,frameLum)+gLayerBounce
        +gLayerAmbHorizon*(gLayerBounceFrame*frameLum);
    float3 direct=sunL*nl;
    float3 result=diffuse*(ambient+direct)+sunL*specular;
    if(gLayerMat>1.5) {
        // Fabric's optional fibre term remains a material extension. It no
        // longer creates wrapped direct light on the light-facing opposite side.
        float sheen=pow(1-nv,max(gLayerSheenPower,0.001))*max(gLayerSheen,0);
        result+=sheen*(ambient+direct)*lerp(diffuse,1,0.35)*saturate(maps.g);
        result+=sunL*nl*max(gLayerFabricLitLift,0)*max(gLayerSpec,0)*max(maps.r,0);
    } else {
        float fresnel=0.04+0.96*pow(1-nv,5);
        // B scales reflection directly, including zero; this is an ambient
        // environment proxy until directional cubemap lighting is connected.
        result+=ambient*fresnel*max(gLayerSpec,0)*max(maps.b,0);
    }
    return max(result,0);
}

float4 main(PS_IN pin)
{
    float3 toEye = normalize(-pin.PosC);
    float3 outwardNormal = normalize(pin.NormalW);
    float3 ng = outwardNormal;
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
        if(gLayerReferenceHousing>0.5) {
            float3 result=rainLayerReferenceHousing(pin,ng,toEye,frameLum,sunL);
            return float4(gLayerHDR>0.5 ? result : saturate(result),1);
        }
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
        float3 h = normalize(l + toEye + n * 1e-4);   // s53 NaN guard
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
        // s53: in-scene stack is HDR (post-processing tones it), the
        // archived overlay path is LDR.
        return float4(gLayerHDR > 0.5 ? max(c, 0.0) : saturate(c), 1.0);
    }

    if (gLayerKind > 2.5 && gLayerOptics > 0.5)
    {
        float3x3 tbn = rainLayerTBN(ng, pin.PosC, pin.Tex);
        float2 bandTex = rainLayerTextureRepeat(txLayerBandUV, pin.Tex).rg;
        float2 bandTexDx = ddx(bandTex);
        float2 bandTexDy = ddy(bandTex);
        float4 originBand = txLayerBand.SampleGrad(samLinearClamp, frac(bandTex), bandTexDx, bandTexDy);
        // Any pixel inside the band transition belongs to the band material.
        // A fractional floor would still blend outside-scene taps into it.
        float bandFloor = rainLayerBandCoverage(originBand.a) > 0.0 ? 1.0 : 0.0;
        float3 bandLight = gLayerBandExternalLight > 0.5
            ? amb + sunL * saturate(dot(ng, gLayerLightDir))
            : gLayerBandUnlitBrightness.xxx;
        // Use mesh UV directly with repeat texture addressing.
        float2 relief = rainLayerTextureRepeat(txLayerNormal, pin.Tex).rg * 2.0 - 1.0;
        float coverage = saturate(rainLayerTextureRepeat(txLayerOutline, pin.Tex).r);
        float4 lensField = rainLayerTextureRepeat(txLayerLens, pin.Tex);
        // The mask is the allowed area; only sharp authored normal peaks draw
        // the bevel. This narrows the line without moving or scaling mesh UV.
        float ridge = pow(smoothstep(0.03, max(gLayerOpticsRimPeak, 0.031), length(relief)),
            max(gLayerOpticsRimSharpness, 1.0));
        if (gLayerOpticsMaskPreview > 0.5)
            return float4((coverage * ridge).xxx, 1.0);
        if (coverage <= 0.0)
            return float4(0.0, 0.0, 0.0, 0.0);
        if (gLayerNormalFlipG > 0.5) relief.y = -relief.y;
        float2 rawRelief = relief;
        // BC neutral-normal error should not light an otherwise flat region.
        float reliefSupport = smoothstep(0.015, 0.08, length(relief));
        // E3 direction uses the authored rim normal independently of E2 gain.
        float2 lensSlope = relief * gLayerOpticsLensGain;
        lensSlope /= max(1.0, length(lensSlope));
        float3 perturbation = mul(float3(lensSlope, 0.0), tbn);
        relief *= gLayerOpticsNormal;
        float3 rn = mul(normalize(float3(relief, 1.0)), tbn);
        rn = dot(rn, rn) > 1e-12 ? normalize(rn) : ng;
        float2 direction = float2(dot(perturbation, gLayerCameraSide),
            -dot(perturbation, gLayerCameraUp));
        float2 pixel = gLayerInvShotSize;
        float2 lo = pixel * 0.5;
        float2 hi = 1.0 - lo;
        float2 uv = clamp(pin.PosH.xy * pixel, lo, hi);
        float2 shifted = clamp(uv + direction * gLayerOpticsRefractionPx * pixel, lo, hi);
        float3 base = rainLayerOpticsScene(uv, uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor);
        float3 warped = rainLayerOpticsScene(shifted, uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor);
        if (gLayerOpticsBlurPx > 0.0)
        {
            // Keep the main image crisp; a weak asymmetric pair across the
            // normal creates hairline tearing instead of a four-way box blur.
            float2 axis = direction * rsqrt(max(dot(direction, direction), 1e-8));
            float2 spread = axis * pixel * gLayerOpticsBlurPx;
            float3 splitA = rainLayerOpticsScene(clamp(shifted + spread, lo, hi), uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor);
            float3 splitB = rainLayerOpticsScene(clamp(shifted - spread * 0.5, lo, hi), uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor);
            warped = warped * 0.75 + splitA * 0.15 + splitB * 0.10;
        }
        // E2 responds to light and view direction. Subtract the flat-surface
        // lobe so flat glass stays neutral instead of receiving a white wash.
        float3 hRaw = gLayerLightDir + toEye;
        float3 h = hRaw * rsqrt(max(dot(hRaw, hRaw), 1e-12));
        float exponent = lerp(8.0, 256.0, saturate(gLayerOpticsReliefGloss));
        float specN = pow(saturate(dot(rn, h)), exponent) * saturate(dot(rn, gLayerLightDir));
        float specFlat = pow(saturate(dot(ng, h)), exponent) * saturate(dot(ng, gLayerLightDir));
        float3 highlight = sunL * max(specN - specFlat, 0.0)
            * gLayerOpticsReliefSpec * reliefSupport
            * (gLayerBandExternalLight > 0.5 ? 1.0 : 1.0 - bandFloor);
        // A bevel still has contrast under a featureless sky. Fresnel and
        // optical transmission supply this cue independently of sun N.L.
        float fresnel = 0.04 + 0.96 * pow(1.0 - saturate(dot(rn, toEye)), 5.0);
        float viewBevel = clamp(dot(rn - ng, toEye), -1.0, 1.0);
        float skyBevel = clamp(rn.y - ng.y, -1.0, 1.0);
        float transmission = saturate(1.0 - gLayerOpticsTransmissionLoss
            + (viewBevel + skyBevel) * gLayerOpticsReliefShade);
        float reflection = saturate(gLayerOpticsReflection * (0.15 + fresnel));
        float2 reflectionUV = clamp(uv - direction * gLayerOpticsReflectionPx * pixel, lo, hi);
        float3 environment = rainLayerOpticsScene(reflectionUV, uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor);
        float3 rim = lerp(warped * transmission, environment, reflection) + highlight;
        float3 interiorDelta = float3(0.0, 0.0, 0.0);
        if (gLayerOpticsInterior > 0.5 && ridge < 1.0)
        {
            // Rounded convex lens across the original WHITE band. Black
            // holes remain black. No sine warp or inferred enclosed region.
            float2 interiorSlope = lensField.rg + rawRelief * gLayerOpticsInteriorNormal;
            interiorSlope /= max(length(interiorSlope), 1.0);
            float3 interiorTangent = mul(float3(interiorSlope, 0.0), tbn);
            float2 interiorDirection = float2(dot(interiorTangent, gLayerCameraSide),
                -dot(interiorTangent, gLayerCameraUp));
            float2 offset = interiorDirection * (gLayerOpticsInteriorPx
                + lensField.b * gLayerOpticsInteriorBendPx);
            float2 interiorUV = clamp(uv + offset * pixel, lo, hi);
            float3 interior = rainLayerOpticsScene(interiorUV, uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor);
            if (gLayerOpticsInteriorSplitPx > 0.0)
            {
                float2 axis = offset * rsqrt(max(dot(offset, offset), 1e-8));
                float2 split = axis * pixel * gLayerOpticsInteriorSplitPx;
                float3 tear = rainLayerOpticsScene(clamp(interiorUV + split, lo, hi), uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor);
                interior = lerp(interior, tear, 0.15);
            }
            if (gLayerOpticsInteriorBlurPx > 0.0 && gLayerOpticsInteriorBlurAmount > 0.0)
            {
                // Explicit nine-tap Gaussian blur: true defocus, independent
                // of displacement. Weights sum to one, preserving scene tone.
                float2 radius = pixel * gLayerOpticsInteriorBlurPx;
                float3 blurred = interior * 0.25;
                blurred += rainLayerOpticsScene(clamp(interiorUV + float2(radius.x, 0), lo, hi), uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor) * 0.125;
                blurred += rainLayerOpticsScene(clamp(interiorUV - float2(radius.x, 0), lo, hi), uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor) * 0.125;
                blurred += rainLayerOpticsScene(clamp(interiorUV + float2(0, radius.y), lo, hi), uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor) * 0.125;
                blurred += rainLayerOpticsScene(clamp(interiorUV - float2(0, radius.y), lo, hi), uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor) * 0.125;
                blurred += rainLayerOpticsScene(clamp(interiorUV + radius, lo, hi), uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor) * 0.0625;
                blurred += rainLayerOpticsScene(clamp(interiorUV - radius, lo, hi), uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor) * 0.0625;
                blurred += rainLayerOpticsScene(clamp(interiorUV + float2(radius.x, -radius.y), lo, hi), uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor) * 0.0625;
                blurred += rainLayerOpticsScene(clamp(interiorUV + float2(-radius.x, radius.y), lo, hi), uv, bandTex, bandTexDx, bandTexDy, bandLight, bandFloor) * 0.0625;
                interior = lerp(interior, blurred, saturate(gLayerOpticsInteriorBlurAmount));
            }
            if (gLayerOpticsInteriorSoftPx > 0.0 && gLayerOpticsInteriorSoftAmount > 0.0)
            {
                // Prefilter each tap before averaging: unlike the sparse sharp
                // copies above, this removes detail rather than duplicating it.
                float radiusPx = gLayerOpticsInteriorSoftPx;
                float lod = clamp(log2(max(radiusPx,1.0)),0.0,5.0);
                float2 radius = pixel * radiusPx * 0.5;
                float3 soft = txLayerSource.SampleLevel(samLinearClamp,interiorUV,lod).rgb * 0.25;
                soft += txLayerSource.SampleLevel(samLinearClamp,clamp(interiorUV+float2(radius.x,0),lo,hi),lod).rgb * 0.125;
                soft += txLayerSource.SampleLevel(samLinearClamp,clamp(interiorUV-float2(radius.x,0),lo,hi),lod).rgb * 0.125;
                soft += txLayerSource.SampleLevel(samLinearClamp,clamp(interiorUV+float2(0,radius.y),lo,hi),lod).rgb * 0.125;
                soft += txLayerSource.SampleLevel(samLinearClamp,clamp(interiorUV-float2(0,radius.y),lo,hi),lod).rgb * 0.125;
                soft += txLayerSource.SampleLevel(samLinearClamp,clamp(interiorUV+radius,lo,hi),lod).rgb * 0.0625;
                soft += txLayerSource.SampleLevel(samLinearClamp,clamp(interiorUV-radius,lo,hi),lod).rgb * 0.0625;
                soft += txLayerSource.SampleLevel(samLinearClamp,clamp(interiorUV+float2(radius.x,-radius.y),lo,hi),lod).rgb * 0.0625;
                soft += txLayerSource.SampleLevel(samLinearClamp,clamp(interiorUV+float2(-radius.x,radius.y),lo,hi),lod).rgb * 0.0625;
                interior = lerp(interior,soft,saturate(gLayerOpticsInteriorSoftAmount));
            }
            interiorDelta = interior - base;
        }
        // Clear glass adds a scene difference to preserve existing rain.
        // Band overlap REPLACES the covered destination: an alpha-zero delta
        // assumes an identical base, and cannot guarantee outside occlusion.
        float3 opticalImage = rim * ridge + (base + interiorDelta) * (1.0 - ridge);
        opticalImage *= max(gLayerOpticsBrightness, 0.0);
        float bandReplace = bandFloor * saturate(gLayerBandOpacity);
        float3 output = lerp(opticalImage - base, opticalImage, bandReplace) * coverage;
        return float4(output, bandReplace * coverage);
    }
    float a = gLayerGlassAlpha;
    float3 c = amb;
    if (gLayerKind < 1.5)
    {
        float3 bandNormal=rainLayerNormal(ng,pin.PosC,pin.Tex);
        float nl = saturate(dot(bandNormal, gLayerLightDir));
        // s55: block-compressed alpha rarely reaches exactly 1, so the band
        // mask starts at gLayerBandAlphaMin; inside the band the opacity is
        // gLayerBandOpacity (1 = fully opaque, nothing behind shows).
        float bandLo = saturate(gLayerBandAlphaMin);
        float band = smoothstep(bandLo, min(bandLo + 0.04, 1.0), d.a);
        a = lerp(gLayerGlassAlpha, gLayerBandOpacity, band);
        if (band >= 0.999)
            a = gLayerBandOpacity;
        float3 bandLighting = gLayerBandExternalLight > 0.5
            ? amb + sunL * nl : gLayerBandUnlitBrightness.xxx;
        bandLighting*=1.0-0.35*saturate(length(bandNormal-ng));
        c = lerp(amb, d.rgb * bandLighting, band);
    }
    a = saturate(a);
    return float4((gLayerHDR > 0.5 ? max(c, 0.0) : saturate(c)) * a, a);
}
