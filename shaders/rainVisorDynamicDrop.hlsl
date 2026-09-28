/*
    RealVisor Dynamic Rain Drop — Stage 4A transport diagnostic

    RAIN_DYNAMIC_SURFACE_STATE_ENABLED uses this shader.

    Debug contract:
    - gDynamicDropDebugUV > 0.5:
        bypass circular clipping and display interpolated quad UV directly.
        Expected result per quad: horizontal red gradient, vertical green
        gradient, opaque output.
    - otherwise:
        Stage 4B.0 transparent optical-profile test. This does not sample the
        scene yet; it validates low-alpha composition, a Fresnel-like rim and
        a compact directional highlight before refraction is introduced.

    Stage 4B.1 contract:
    - gDynamicDropHDRCopyDebug > 0.5:
        after circular clipping, copy txDynamicScene at pin.ScreenPos without
        an offset. Correct screen-space alignment makes the footprint nearly
        disappear into the scene.

    Stage 4B.2 contract:
    - gDynamicDropRefractionDebug > 0.5:
        sample the same HDR scene with a controlled radial pixel offset. This
        validates lens direction and screen-space stability before tuning the
        final water optical model.

    Stage 4B.2D contract:
    - gDynamicDropSceneSourceDebug > 0.5:
        split each circle into HDR/LDR and ScreenPos/fixed-center quadrants to
        distinguish a black texture binding from invalid screen coordinates.

    Stage 4B.2F contract:
    - gDynamicDropScreenUVDebug > 0.5:
        compare direct HDR at 8x with an independent scene at two candidate
        UV scales, plus a known file texture.
*/

// All txDynamicScene/gDynamicDrop* inputs are injected by render.mesh({
// textures/values = ... }). Do not redeclare them in this file.

float4 main(PS_IN pin)
{
    float shapeSeed = floor(pin.Tex.x * 0.5);
    float2 quadTex = pin.Tex - float2(shapeSeed * 2.0, 0.0);
    bool trailQuad = quadTex.y > 1.5;
    if (trailQuad)
        quadTex.y -= 2.0;
    if (gDynamicDropDebugUV > 0.5)
    {
        // Do not clip anything in this branch. If the dynamic mesh is bound
        // and pin.Tex is transported correctly, each quad must show a 0..1
        // red/green gradient. A flat color identifies broken UV transport.
        return float4(quadTex.x, quadTex.y, 0.15, 1.0);
    }

    float2 local = (quadTex - 0.5) * 2.0;
    float r = length(local);

    if (trailQuad)
    {
        clip(gDynamicDropTrailEnabled - 0.5);
        float along = saturate(local.x * 0.5 + 0.5);
        float trailWidth = lerp(0.68, 1.0, along);
        float trailEdge = max(abs(local.x), abs(local.y) / trailWidth);
        clip(1.0 - trailEdge);
        float fade = smoothstep(-1.0, -0.25, local.x)
            * (1.0 - smoothstep(-0.20, 0.75, local.x))
            * (1.0 - smoothstep(0.78, 1.0, trailEdge));
        float2 offset = float2(local.y, -local.x) * 6.0;
        float3 trailScene;
        if (gDynamicDropGeometryShotDebug > 0.5)
        {
            float2 resolutionRatio = gDynamicDropInvRenderTargetSize
                / gDynamicDropInvScreenSize;
            float2 sceneUV = pin.PosH.xy * gDynamicDropInvScreenSize
                * lerp(float2(1.0, 1.0), resolutionRatio, 0.98);
            trailScene = txDynamicSnapshot.SampleLevel(samLinearClamp,
                saturate(sceneUV + offset * gDynamicDropInvRenderTargetSize),
                0.0).rgb;
        }
        else
            trailScene = txDynamicScene.SampleLevel(samLinearClamp,
                saturate(pin.ScreenPos + offset * gDynamicDropInvScreenSize),
                0.0).rgb;
        float rim = smoothstep(0.72, 1.0, trailEdge);
        float trailLuma = dot(trailScene, float3(0.2126, 0.7152, 0.0722));
        return float4(trailScene + float3(0.72, 0.86, 1.0)
            * rim * lerp(0.025, 0.10, saturate(trailLuma)), 0.50 * fade);
    }

    clip(1.0 - r);

    if (gDynamicDropScreenUVDebug > 0.5)
    {
        float2 raw = pin.ScreenPos.xy;
        float2 expandedUV = saturate((raw - 0.5) * 8.0 + 0.5);
        float2 sceneUVA = saturate(
            (raw - 0.5) * gDynamicDropGeometryUVScaleA + 0.5);
        float2 windowUV = saturate(
            pin.PosH.xy * gDynamicDropInvScreenSize);
        float2 pixelUV = saturate(
            pin.PosH.xy * gDynamicDropInvRenderTargetSize);
        bool compareSnapshot = gDynamicDropSnapshotDebug > 0.5;
        bool right = local.x >= 0.0;
        bool bottom = local.y >= 0.0;
        float3 sampledColor;

        if (compareSnapshot)
        {
            if (!right && !bottom)
            {
                // Red: live HDR reference.
                sampledColor = txDynamicScene.SampleLevel(
                    samLinearClamp, windowUV, 0.0).rgb;
            }
            else
            {
                // Compare undistorted and displaced samples from the same
                // independent, nonrecursive scene shot.
                float2 resolutionRatio = gDynamicDropInvRenderTargetSize
                    / gDynamicDropInvScreenSize;
                float2 sceneUV = windowUV
                    * lerp(float2(1.0, 1.0), resolutionRatio,
                        0.98);
                if (gDynamicDropGeometryShotDebug > 0.5)
                {
                    float boundaryFade = 1.0 - smoothstep(0.82, 1.0, r);
                    float radialProfile = smoothstep(0.05, 0.75, r)
                        * boundaryFade;
                    float refractionPixels = !bottom ? 0.0
                        : (right ? gDynamicDropRefractionPixels * 2.0
                            : gDynamicDropRefractionPixels);
                    sceneUV += local * radialProfile * refractionPixels
                        * gDynamicDropInvRenderTargetSize;
                    sampledColor = txDynamicSnapshot.SampleLevel(
                        samLinearClamp, saturate(sceneUV), 0.0).rgb;
                }
                else
                    sampledColor = txDynamicScreen.SampleLevel(
                        samLinearClamp, saturate(sceneUV), 0.0).rgb * 8.0;
            }
        }
        else if (!right && !bottom)
        {
            sampledColor = txDynamicScene.SampleLevel(
                samLinearClamp,
                gDynamicDropSnapshotDebug > 0.5 ? expandedUV : raw,
                0.0).rgb;
        }
        else if (right && !bottom)
        {
            sampledColor = txDynamicControl.SampleLevel(
                samLinearClamp, float2(0.5, 0.5), 0.0).rgb;
        }
        else if (!right && bottom)
        {
            sampledColor = txDynamicSnapshot.SampleLevel(
                samLinearClamp,
                gDynamicDropGeometryShotDebug > 0.5
                    ? sceneUVA : expandedUV,
                0.0).rgb;
            if (gDynamicDropGeometryShotDebug > 0.5)
                sampledColor *= 8.0;
        }
        else
        {
            if (gDynamicDropGeometryShotDebug > 0.5)
            {
                if (gDynamicDropPixelUVDebug > 0.5)
                    sampledColor = txDynamicScene.SampleLevel(
                        samLinearClamp, pixelUV, 0.0).rgb;
                else
                    sampledColor = txDynamicSnapshot.SampleLevel(
                        samLinearClamp, expandedUV, 0.0).rgb * 8.0;
            }
            else
                sampledColor = txDynamicScreen.SampleLevel(
                    samLinearClamp, expandedUV, 0.0).rgb;
        }
        float3 marker = !right
            ? (bottom ? float3(0.2, 0.5, 1.0) : float3(1.0, 0.15, 0.15))
            : (bottom ? float3(0.9, 0.2, 1.0) : float3(0.15, 1.0, 0.3));
        // Keep the sampled interior intact. An outer rim and cross prove
        // this branch is running even if the HDR sample is entirely black.
        float rim = smoothstep(0.90, 0.97, r);
        float separator = saturate(
            1.0
            - smoothstep(0.0, 0.035, min(abs(local.x), abs(local.y)))
        );

        return float4(
            lerp(lerp(sampledColor, marker, rim),
                float3(1.0, 0.75, 0.0), separator),
            1.0
        );
    }

    if (gDynamicDropSceneSourceDebug > 0.5)
    {
        // Left: HDR. Right: LDR. Top: pin.ScreenPos. Bottom: fixed (0.5, 0.5).
        // A thin yellow cross keeps the circle identifiable even if all four
        // texture samples are black.
        bool useLDR = local.x >= 0.0;
        bool useScreenPos = local.y < 0.0;
        float2 sampleUV = useScreenPos
            ? pin.ScreenPos
            : float2(0.5, 0.5);

        float3 hdrColor = txDynamicScene.SampleLevel(
            samLinearClamp,
            sampleUV,
            0.0
        ).rgb;
        float3 ldrColor = txDynamicScreen.SampleLevel(
            samLinearClamp,
            sampleUV,
            0.0
        ).rgb;
        float3 sampledColor = useLDR ? ldrColor : hdrColor;

        float separator = saturate(
            1.0
            - smoothstep(0.0, 0.035, min(abs(local.x), abs(local.y)))
        );

        return float4(
            lerp(sampledColor, float3(1.0, 0.75, 0.0), separator),
            1.0
        );
    }

    if (gDynamicDropHDRCopyDebug > 0.5)
    {
        // mesh.fx provides ScreenPos directly in normalized 0..1 screen
        // coordinates. No Lua-side resolution or projection math is needed.
        float3 sceneColor = txDynamicScene.SampleLevel(
            samLinearClamp,
            pin.ScreenPos,
            0.0
        ).rgb;

        return float4(sceneColor, 1.0);
    }

    // Each drop has a stable, distinct angular contour. The same adjusted
    // radius drives clipping, lens normal, rim and alpha.
    float footprintScale = 1.0;
    if (gDynamicDropShapeDebug > 0.5)
    {
        float angle = atan2(local.y, local.x);
        float phase = shapeSeed * 2.3999632;
        float contour = (0.09 + 0.07 * frac(shapeSeed * 0.7548777))
            * (0.5 + 0.5 * sin(3.0 * angle + phase + 0.7))
            + (0.06 + 0.07 * frac(shapeSeed * 0.5698403))
            * (0.5 + 0.5 * sin(5.0 * angle - phase * 0.73 - 0.9));
        contour *= saturate(gDynamicDropShapeStrength);
        footprintScale = 1.0 - contour;
        r /= footprintScale;
        clip(1.0 - r);
    }

    // Reconstruct a hemisphere-like local normal from the optical footprint.
    // This is an optical profile only: the actual visor surface normal remains
    // owned by the transport mesh and the target-surface lookup.
    float z = sqrt(saturate(1.0 - r * r));
    float3 dropNormal = normalize(float3(local / footprintScale, z));

    float fresnel = pow(saturate(1.0 - z), 2.4);

    float3 lightDirection = normalize(float3(-0.45, -0.55, 0.70));
    float highlight = pow(
        saturate(dot(dropNormal, lightDirection)),
        28.0
    );

    if (gDynamicDropRefractionDebug > 0.5)
    {
        // Fade the displacement back near the clipped boundary to avoid a
        // harsh discontinuity while retaining an obvious radial lens test.
        float boundaryFade = 1.0 - smoothstep(0.82, 1.0, r);
        float radialProfile = smoothstep(0.05, 0.75, r) * boundaryFade;

        float3 refractedScene;
        if (gDynamicDropGeometryShotDebug > 0.5)
        {
            float2 resolutionRatio = gDynamicDropInvRenderTargetSize
                / gDynamicDropInvScreenSize;
            float2 sceneUV = pin.PosH.xy * gDynamicDropInvScreenSize
                * lerp(float2(1.0, 1.0), resolutionRatio, 0.98);
            // The left half retains the 48px radial lens. Opaque output
            // prevents the original background bleeding through.
            float refractionPixels = gDynamicDropOpaqueRefractionSplitDebug
                > 0.5 ? 48.0 : gDynamicDropRefractionPixels;
            float2 refractionOffset = dropNormal.xy * radialProfile
                * refractionPixels
                * gDynamicDropInvRenderTargetSize;
            // Evaluate derivatives for both halves before the per-pixel
            // split; derivatives inside a divergent branch are undefined.
            float2 localDx = ddx(local);
            float2 localDy = ddy(local);
            if (gDynamicDropInvertedFootprintDebug > 0.5
                && local.x < 0.0)
            {
                // Reconstruct the projected quad radius from the mesh UV
                // Jacobian. This works for each droplet's own screen size
                // and visor curvature, without a fixed pixel-radius guess.
                float jacobian = localDx.x * localDy.y
                    - localDy.x * localDx.y;
                if (abs(jacobian) > 1e-6)
                {
                    float2 fromCenterPixels = float2(
                        localDy.y * local.x - localDy.x * local.y,
                        localDx.x * local.y - localDx.y * local.x
                    ) / jacobian;
                    fromCenterPixels = clamp(fromCenterPixels,
                        float2(-96.0, -96.0), float2(96.0, 96.0));
                    float footprintFade = 1.0
                        - smoothstep(0.72, 0.98, r);
                    float2 shotUVPerWindowPixel = gDynamicDropInvScreenSize
                        * lerp(float2(1.0, 1.0), resolutionRatio, 0.98);
                    // Subtracting 3x the projected center displacement
                    // produces a 2x inverted scene image in the interior.
                    refractionOffset = -3.0 * fromCenterPixels
                        * footprintFade * shotUVPerWindowPixel;
                }
            }
            // On the back-facing visor, only the image-right half receives
            // the force-driven prototype; the left retains proven optics.
            if (gDynamicDropWaveEnvelope > 0.0 && local.x < 0.0)
            {
                float waveProfile = smoothstep(0.10, 0.45, r)
                    * (1.0 - smoothstep(0.75, 1.0, r));
                float waveFront = dot(local, gDynamicDropWaveDirection) * 12.0
                    - gDynamicDropWavePhase;
                float wavePixels = sin(waveFront) * waveProfile
                    * gDynamicDropWaveEnvelope * 6.0;
                refractionOffset += gDynamicDropWaveDirection * wavePixels
                    * gDynamicDropInvRenderTargetSize;
            }
            refractedScene = txDynamicSnapshot.SampleLevel(
                samLinearClamp, saturate(sceneUV + refractionOffset),
                0.0).rgb;
            // Visible right half: inspect shot depth at exactly the same
            // refracted UV. Magenta indicates a far/sky pixel; cyan indicates
            // geometry or a missing/invalid depth signal.
            if (gDynamicDropSkyDepthDebug > 0.5 && local.x < 0.0)
            {
                float shotDepth = txDynamicShotDepth.SampleLevel(
                    samLinearClamp, saturate(sceneUV + refractionOffset),
                    0.0).r;
                refractedScene = shotDepth > 0.99999
                    ? float3(0.95, 0.12, 0.72)
                    : float3(0.05, 0.55, 0.70);
            }
            // Both halves use the same sky correction while the inverted
            // footprint comparison is enabled, isolating the optical shape.
            else if (gDynamicDropSkyFogColorDebug > 0.5
                && (local.x < 0.0
                    || gDynamicDropInvertedFootprintDebug > 0.5))
            {
                float shotDepth = txDynamicShotDepth.SampleLevel(
                    samLinearClamp, saturate(sceneUV + refractionOffset),
                    0.0).r;
                if (shotDepth > 0.99999)
                {
                    if (gDynamicDropSkyCloudDetailDebug > 0.5)
                    {
                        // Transfer only cloud luminance contrast onto the
                        // weather-matched sky color. A broad mip of the
                        // same shot supplies a local exposure reference;
                        // do not reintroduce the old sunset cloud hue.
                        float3 broadSky = txDynamicSnapshot.SampleLevel(
                            samLinearClamp,
                            saturate(sceneUV + refractionOffset), 9.0).rgb;
                        float skyLuma = dot(refractedScene,
                            float3(0.2126, 0.7152, 0.0722));
                        float broadLuma = dot(broadSky,
                            float3(0.2126, 0.7152, 0.0722));
                        // The broad reference darkened every tested sky
                        // region in Hurricane. Keep the matched fog tone as
                        // the anchor and transfer only restrained contrast.
                        float rawContrast = skyLuma
                            / max(broadLuma, 0.02);
                        float cloudContrast = clamp(
                            1.0 + (rawContrast - 1.0) * 0.25,
                            0.95, 1.12);
                        refractedScene = gDynamicDropWeatherFogColor
                            * cloudContrast;
                    }
                    else
                        refractedScene = gDynamicDropWeatherFogColor;
                }
            }
            // Sky color test on the back-facing visor: image-left keeps
            // GeometryShot; image-right samples the final screen at the
            // identical normalized UV and displacement. Screen may contain
            // earlier drops, so this branch is diagnostic only.
            if (gDynamicDropSkySourceDebug > 0.5 && local.x < 0.0)
                refractedScene = txDynamicScreen.SampleLevel(
                    samLinearClamp, saturate(sceneUV + refractionOffset),
                    0.0).rgb;
        }
        else
        {
            float2 refractionOffset = dropNormal.xy * radialProfile
                * gDynamicDropRefractionPixels * gDynamicDropInvScreenSize;
            refractedScene = txDynamicScene.SampleLevel(
                samLinearClamp,
                saturate(pin.ScreenPos + refractionOffset),
                0.0).rgb;
        }

        // Keep the proven Stage 4B.0 rim/highlight at low strength so the
        // droplet boundary remains identifiable over smooth backgrounds.
        float sceneLuma = dot(refractedScene,
            float3(0.2126, 0.7152, 0.0722));
        float3 opticalAccent =
            float3(0.72, 0.86, 1.00) * fresnel
                * lerp(0.035, 0.16, saturate(sceneLuma))
            + float3(0.92, 0.98, 1.00) * highlight * 0.14;
        if (gDynamicDropGeometryShotDebug > 0.5
            && gDynamicDropOpaqueRefractionSplitDebug > 0.5)
            opticalAccent += float3(0.95, 0.68, 0.08)
                * (1.0 - smoothstep(0.005, 0.025, abs(local.x)))
                * 0.55;

        // The translucent candidate was preferred over full replacement:
        // retain a visible convex lens while preserving the live scene.
        float alpha = saturate(
            0.55 + fresnel * 0.25 + highlight * 0.10
            + smoothstep(0.75, 0.98, r) * 0.08);
        if (gDynamicDropGeometryShotDebug > 0.5
            && gDynamicDropOpaqueRefractionSplitDebug > 0.5)
            alpha = 1.0;
        return float4(refractedScene + opticalAccent, alpha);
    }

    // Keep the center almost transparent. The rim and small highlight are the
    // only strong contributions in this pre-refraction validation stage.
    float alpha = saturate(
        0.035
        + fresnel * 0.26
        + highlight * 0.18
    );

    float3 color = lerp(
        float3(0.72, 0.86, 1.00),
        float3(0.92, 0.98, 1.00),
        saturate(fresnel + highlight)
    );

    return float4(color, alpha);
}
