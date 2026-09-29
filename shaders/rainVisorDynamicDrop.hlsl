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

SamplerState samPointMicroMask
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
};

float4 main(PS_IN pin)
{
    bool surfaceMicroPattern = pin.Tex.x < -2.5;
    float2 encodedTex = surfaceMicroPattern
        ? float2(0.5, 0.5) : pin.Tex;
    float encodedSeed = floor(encodedTex.x * 0.5);
    bool microLayer = encodedSeed >= 2048.0;
    float shapeSeed = encodedSeed - (microLayer ? 2048.0 : 0.0);
    float2 quadTex = encodedTex - float2(encodedSeed * 2.0, 0.0);
    // Head quads encode three brief impact-age bands in whole UV steps.
    // Trail quads use 2..3 and therefore have no impact band.
    float impactBand = floor(quadTex.y * 0.25);
    quadTex.y -= impactBand * 4.0;
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
    bool wideSide = gDynamicDropSplitCompareDebug < 0.5
        || local.x < 0.0;

    if (surfaceMicroPattern)
    {
        clip(gDynamicDropMicroPatternEnabled - 0.5);
        float2 patternUV = saturate(float2(
            pin.Tex.x + 4.0, pin.Tex.y + 1.0));
        // Diagnostic displays UV-space water and wiping coverage over
        // the complete visor, including gaps between static circles.
        if (gDynamicDropTrailMaskDebug > 0.5)
        {
            float2 coverage = txDynamicTrailMask.SampleLevel(
                samLinearClamp, patternUV, 0.0).rg;
            float strength = max(coverage.r, coverage.g);
            clip(strength - 0.01);
            return float4(coverage.r, coverage.g, 0.12,
                saturate(strength * 0.85));
        }
        // At zero rain, skip the entire static pattern.
        clip(gDynamicDropMicroRain - 0.001);
        float4 pattern = txDynamicMicroPattern.SampleLevel(
            samLinearClamp, patternUV, 0.0);
        // Alpha stores only the disk silhouette, independent of rain.
        // The selection threshold lives in the blue channel.
        clip(pattern.a - 0.005);
        if (gDynamicDropMicroRain < 0.999)
        {
            // Point sampling by normalized UV keeps coverage and gate
            // aligned even if the canvas is internally capped or resized.
            float maskGate = txDynamicMicroPattern.SampleLevel(
                samPointMicroMask, patternUV, 0.0).b;
            clip(gDynamicDropMicroRain - maskGate);
        }
        float microVisibility = 1.0;
        if (gDynamicDropTrailMaskWipeEnabled > 0.5)
        {
            // G is the time-decaying clearance field. Preserve the baked
            // dot contour; only the whole disk's contribution fades out.
            float clearance = txDynamicTrailMask.SampleLevel(
                samLinearClamp, patternUV, 0.0).g;
            microVisibility = 1.0 - smoothstep(0.08, 0.70,
                saturate(clearance
                    * gDynamicDropTrailMaskWipeStrength));
            clip(microVisibility - 0.01);
        }
        float2 lensLocal = pattern.xy * 2.0 - 1.0;
        float lensRadius = saturate(length(lensLocal));
        // The baked alpha owns the silhouette, including its pixelated rim.
        // The winning disk owns the pixel; its outer ring also marks
        // boundaries where a newer disk hides an older one.
        float rim = smoothstep(0.65, 0.79, lensRadius);
        if (gDynamicDropMicroDebug > 0.5)
        {
            float3 diagnostic = lerp(float3(0.13, 0.22, 0.28),
                float3(0.83, 0.95, 1.0), rim);
            return float4(diagnostic, 0.83);
        }
        float2 resolutionRatio = gDynamicDropInvRenderTargetSize
            / gDynamicDropInvScreenSize;
        float2 shotScale = lerp(float2(1.0, 1.0),
            resolutionRatio, 0.98);
        float2 sceneUV = pin.PosH.xy * gDynamicDropInvScreenSize
            * shotScale;
        // Recover the screen-space center of this disk from the smooth
        // visor UV derivatives. A fixed pixel offset cannot invert disks
        // whose projected sizes change across the curved visor or with DLSS.
        float2 uvDx = ddx(patternUV);
        float2 uvDy = ddy(patternUV);
        float determinant = uvDx.x * uvDy.y - uvDx.y * uvDy.x;
        float2 radiusUV = lensLocal
            * (0.56 / max(gDynamicDropMicroPatternGrid, 1.0));
        float2 centerOffsetPixels = float2(0.0, 0.0);
        if (abs(determinant) > 1e-9)
            centerOffsetPixels = float2(
                (uvDy.y * radiusUV.x - uvDy.x * radiusUV.y)
                    / determinant,
                (uvDx.x * radiusUV.y - uvDx.y * radiusUV.x)
                    / determinant);
        float2 centerSceneUV = sceneUV
            - ddx(sceneUV) * centerOffsetPixels.x
            - ddy(sceneUV) * centerOffsetPixels.y;
        // Rotate the view around each disk's center, preserving its
        // orientation at zero degrees instead of mirroring it.
        float2 centerDelta = sceneUV - centerSceneUV;
        // The object-space visor normal determines which part of the
        // independently rendered camera view this disk faces. The same
        // normal map and mesh transform drive the existing rain physics.
        float3 objectNormal = txDynamicControl.SampleLevel(
            samLinearClamp, float2(patternUV.x, patternUV.y - 1.0),
            0.0).rgb * 2.0 - 1.0;
        float3 worldNormal = normalize(mul(normalize(objectNormal),
            (float3x3)gDynamicDropObjectToWorld));
        float3 cameraNormal = float3(
            dot(worldNormal, gDynamicDropCameraSide),
            -dot(worldNormal, gDynamicDropCameraUp),
            dot(worldNormal, gDynamicDropCameraLook));
        if (cameraNormal.z < 0.0)
            cameraNormal *= -1.0;
        float2 normalSceneShift = clamp(cameraNormal.xy
            / max(cameraNormal.z, 0.35)
            * gDynamicDropMicroNormalGain, -0.20, 0.20);
        float2 rotatedDelta = float2(
            centerDelta.x * gDynamicDropMicroImageRotation.x
                - centerDelta.y * gDynamicDropMicroImageRotation.y,
            centerDelta.x * gDynamicDropMicroImageRotation.y
                + centerDelta.y * gDynamicDropMicroImageRotation.x);
        // Looking through the inner visor face: the center recedes,
        // with a gradually shallower scale toward the near edge.
        float inwardProfile = 1.0 + gDynamicDropMicroConcaveOptics
            * (1.0 - lensRadius * lensRadius);
        float2 refractionUV = centerSceneUV + normalSceneShift
            + rotatedDelta * gDynamicDropMicroImageScale
                * inwardProfile;
        float3 sceneColor = txDynamicSnapshot.SampleLevel(
            samLinearClamp, saturate(refractionUV),
            gDynamicDropMicroSceneMip).rgb;
        // This normal field is baked once from the same winning circles
        // as the mask. It is a tangent-space spherical cap per disk.
        float3 capNormal = normalize(float3(lensLocal,
            sqrt(saturate(1.0 - lensRadius * lensRadius))));
        if (gDynamicDropMicroNormalReady > 0.5)
            capNormal = txDynamicMicroNormal.SampleLevel(
                samLinearClamp, patternUV,
                gDynamicDropMicroNormalMip).rgb * 2.0 - 1.0;
        // The rider sees the rear of the exterior convex drop. Its
        // cap slopes therefore read as a recess from the camera side.
        capNormal = normalize(float3(
            -capNormal.xy * gDynamicDropMicroNormalBump,
            max(capNormal.z, 0.08)));
        float3 visorNormal = normalize(cameraNormal);
        float3 tangentX = normalize(float3(
            max(visorNormal.z, 0.08), 0.0, -visorNormal.x));
        float3 tangentY = normalize(cross(visorNormal, tangentX));
        float3 shadedNormal = normalize(tangentX * capNormal.x
            + tangentY * capNormal.y + visorNormal * capNormal.z);
        // Project scene light into this drop's local visor tangent frame.
        // A view-side grazing component keeps the relief visible when
        // the sun is directly behind the visor or hidden by weather.
        float3 worldLightCamera = float3(
            dot(gDynamicDropMicroLightWorld, gDynamicDropCameraSide),
            -dot(gDynamicDropMicroLightWorld, gDynamicDropCameraUp),
            dot(gDynamicDropMicroLightWorld, gDynamicDropCameraLook));
        float2 tangentLight = float2(
            dot(worldLightCamera, tangentX),
            dot(worldLightCamera, tangentY));
        float2 reliefLight = normalize(tangentLight * 0.55
            + float2(-0.48, -0.36));
        float grazing = saturate(1.0 - visorNormal.z);
        float interiorRelief = smoothstep(0.08, 0.30, lensRadius)
            * (1.0 - smoothstep(0.55, 0.76, lensRadius));
        float signedLight = dot(capNormal.xy, reliefLight)
            * interiorRelief * (0.85 + grazing * 0.80);
        float litSide = saturate(signedLight)
            * gDynamicDropMicroAngleLight;
        float darkSide = saturate(-signedLight)
            * gDynamicDropMicroAngleShadow;
        float3 lightAccent = float3(0.78, 0.90, 1.0)
            * (litSide * 0.52
                + rim * gDynamicDropMicroRimStrength * 0.20);
        sceneColor *= 1.0 - saturate(darkSide * 0.42);
        // Each winning disk carries its complete scene image. Uncovered
        // pattern texels are clipped above and reveal the live scene.
        // The baked mask clips the topmost disk's entire thin rim, so
        // underlying scene appears even when another disk lies below it.
        return float4(sceneColor + lightAccent,
            saturate(gDynamicDropMicroOpacity * microVisibility));
    }

    if (microLayer)
    {
        clip(gDynamicDropMicroLayerEnabled - 0.5);
        clip(1.0 - r);
        if (gDynamicDropMicroDebug > 0.5)
        {
            float debugRim = smoothstep(0.60, 0.88, r);
            float3 debugColor = lerp(float3(0.17, 0.26, 0.31),
                float3(0.82, 0.94, 1.0), debugRim);
            return float4(debugColor,
                0.90 * (1.0 - smoothstep(0.92, 1.0, r)));
        }
        float zMicro = sqrt(saturate(1.0 - r * r));
        float2 microResolutionRatio = gDynamicDropInvRenderTargetSize
            / gDynamicDropInvScreenSize;
        float2 microUV = pin.PosH.xy * gDynamicDropInvScreenSize
            * lerp(float2(1.0, 1.0), microResolutionRatio, 0.98);
        float2 microOffset = local * (1.0 - r * r)
            * gDynamicDropMicroRefractionPixels
            * gDynamicDropInvScreenSize
            * lerp(float2(1.0, 1.0), microResolutionRatio, 0.98);
        float3 microScene = txDynamicSnapshot.SampleLevel(
            samLinearClamp,
            saturate(microUV + microOffset),
            gDynamicDropMicroSceneMip).rgb;
        float microRim = smoothstep(0.42, 0.96, r)
            * (1.0 - smoothstep(0.94, 1.0, r));
        float3 microNormal = normalize(float3(local, zMicro));
        float microGlint = saturate((dot(microNormal,
            normalize(float3(-0.45, -0.55, 0.70))) - 0.88) * 8.0);
        // A newer disk covers most of an older disk's rim at overlaps.
        float microAlpha = gDynamicDropMicroOpacity
            * (0.88 + 0.12 * microRim)
            * (1.0 - smoothstep(0.84, 1.0, r))
            + microGlint * 0.08;
        return float4(microScene
            + float3(0.78, 0.90, 1.0) * microGlint * 0.18,
            saturate(microAlpha));
    }

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
            * rim * lerp(0.025, 0.10, saturate(trailLuma)),
            gDynamicDropTrailOpacity * fade);
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

    // The birth seed chooses a round, stretched or asymmetric footprint.
    // The same radius drives clipping, lens normal, rim and alpha.
    float footprintScale = 1.0;
    if (gDynamicDropShapeDebug > 0.5)
    {
        float angle = atan2(local.y, local.x);
        float phase = shapeSeed * 2.3999632;
        float family = frac((shapeSeed + 1.0) * 0.61803399);
        float strength = saturate(gDynamicDropShapeStrength);
        float contour = (0.045 + 0.065 * frac(shapeSeed * 0.7548777))
            * sin(3.0 * angle + phase + 0.7)
            + (0.025 + 0.055 * frac(shapeSeed * 0.5698403))
            * sin(5.0 * angle - phase * 0.73 - 0.9);
        // A single broad lobe creates a tear-like silhouette in some births;
        // others remain nearly circular or gently elliptical.
        float broadLobe = max(0.0, cos(angle - phase));
        contour += (family > 0.67 ? 0.13 : 0.0)
            * (broadLobe * broadLobe - 0.25);
        contour += (family > 0.32 && family <= 0.67 ? 0.09 : 0.0)
            * cos(2.0 * angle + phase);
        // Only freshly born, sufficiently large drops carry this pulse.
        // Its asymmetric fingers shrink as the age band falls from 3 to 1.
        float impactPulse = saturate(impactBand / 3.0);
        contour += impactPulse * (0.10 * sin(7.0 * angle + phase)
            + 0.10 * max(0.0, cos(3.0 * angle - phase)));
        footprintScale = 0.88 + strength * contour;
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
            float2 orbDropCenter = sceneUV;
            // Evaluate derivatives for both halves before the per-pixel
            // split; derivatives inside a divergent branch are undefined.
            float2 localDx = ddx(local);
            float2 localDy = ddy(local);
            if ((gDynamicDropInvertedFootprintDebug > 0.5
                || gDynamicDropConcaveLensDebug > 0.5)
                && wideSide)
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
                    float2 shotUVPerWindowPixel = gDynamicDropInvScreenSize
                        * lerp(float2(1.0, 1.0), resolutionRatio, 0.98);
                    orbDropCenter = sceneUV
                        - fromCenterPixels * shotUVPerWindowPixel;
                    fromCenterPixels = clamp(fromCenterPixels,
                        float2(-96.0, -96.0), float2(96.0, 96.0));
                    if (gDynamicDropConcaveLensDebug > 0.5)
                    {
                        // At the rim both displacement and its radial slope
                        // reach zero. This removes the fold/caustic band
                        // needed by the previous inverted-to-normal map.
                        float edgeFade = 1.0 - saturate(r);
                        edgeFade *= edgeFade;
                        float strengthSeed = frac(shapeSeed * 0.7548777);
                        float axisSeed = frac(shapeSeed * 0.5698403);
                        float screenDistance = saturate(length(
                            (sceneUV - 0.5) * 1.4142136));
                        float strength = lerp(1.65, 2.20, strengthSeed)
                            * (1.0 + 0.10 * screenDistance);
                        float2 anisotropy = float2(
                            lerp(0.92, 1.08, axisSeed),
                            lerp(1.08, 0.92, axisSeed));
                        refractionOffset = fromCenterPixels * anisotropy
                            * strength * edgeFade * shotUVPerWindowPixel;
                    }
                    else
                    {
                        float footprintFade = 1.0
                            - smoothstep(0.72, 0.98, r);
                        refractionOffset = -4.5 * fromCenterPixels
                            * footprintFade * shotUVPerWindowPixel;
                    }
                }
            }
            // On the back-facing visor, only the image-right half receives
            // the force-driven prototype; the left retains proven optics.
            if (gDynamicDropWaveEnvelope > 0.0 && wideSide)
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
            float lensMIP = gDynamicDropConcaveLensDebug > 0.5
                && wideSide ? lerp(1.4, 1.9, saturate(r)) : 0.0;
            float2 sampleUV = sceneUV + refractionOffset;
            if (gDynamicDropWideSceneDebug > 0.5 && wideSide)
            {
                // Roughly one third of the viewport crosses the diameter
                // of each drop. Keep a slightly position-dependent center
                // and align the mapped image to the projected visor U axis.
                // The CPU already constructs this quad using surface
                // tangents and normal; its on-screen derivatives encode
                // the surface-dependent rotation and possible axis flip.
                float orbMode = gDynamicDropWideOrbDebug > 0.5
                    ? 1.0 : 0.0;
                float2 dropOffset = orbDropCenter - 0.5;
                // Below center -> upper source; above -> lower. Side drops
                // retain their side and also pick up a little upper scene.
                float2 bentCenter = 0.5 + float2(
                    dropOffset.x * gDynamicDropOrbPositionBend,
                    -dropOffset.y * gDynamicDropOrbPositionBend
                        -abs(dropOffset.x) * gDynamicDropOrbSideUpshift);
                float2 centerUV = lerp(sceneUV - local * 0.01,
                    clamp(bentCenter, 0.12, 0.88), orbMode);
                if (gDynamicDropForwardSceneOnly > 0.5)
                    centerUV = orbDropCenter;
                float angle = (frac(shapeSeed * 0.6180339) * 2.0 - 1.0)
                    * gDynamicDropWideRotationRadians;
                float rotationSin, rotationCos;
                sincos(angle, rotationSin, rotationCos);
                float2 surfaceAxis = float2(1.0, 0.0);
                float surfaceJacobian = localDx.x * localDy.y
                    - localDy.x * localDx.y;
                if (gDynamicDropWideSurfaceRotationDebug > 0.5
                    && abs(surfaceJacobian) > 1e-6)
                {
                    float2 projectedU = float2(localDy.y,
                        -localDx.y) / surfaceJacobian;
                    if (dot(projectedU, projectedU) > 1e-4)
                        surfaceAxis = normalize(projectedU);
                }
                float2 rotatedAxis = float2(
                    surfaceAxis.x * rotationCos
                        - surfaceAxis.y * rotationSin,
                    surfaceAxis.y * rotationCos
                        + surfaceAxis.x * rotationSin);
                float2 direction = rotatedAxis * local.x
                    + float2(-rotatedAxis.y, rotatedAxis.x) * local.y;
                // Invert both image axes together: a 180-degree image,
                // never a single-axis mirror. Keep the surface U rotation.
                direction *= lerp(1.0, -1.0,
                    saturate(gDynamicDropOrbInvertImage) * orbMode);
                // A mild convex profile maps the center smoothly and
                // compresses the edge without a repeated sharp rim image.
                float convex = 1.0 - 0.16 * saturate(r * r);
                float fieldRadius = lerp(0.17,
                    gDynamicDropOrbFieldRadius, orbMode);
                if (gDynamicDropForwardSceneOnly > 0.5)
                    fieldRadius = min(fieldRadius,
                        gDynamicDropForwardSceneRadius);
                float2 wideUV = centerUV + direction * fieldRadius
                    * lerp(1.0, convex, orbMode);
                // Spread the wide-to-local transition across most of the
                // footprint: a narrow outer transition bent hard edges.
                float wideWeight = lerp(
                    0.92 * (1.0 - smoothstep(0.15, 0.96, r)),
                    1.0 - smoothstep(0.60, 0.96, r), orbMode);
                // The orb image is mostly a rotated camera view. Restore
                // local UV only under a fading rim to avoid a visible fold.
                sampleUV = lerp(lerp(sampleUV, sceneUV, orbMode),
                    wideUV, wideWeight);
                float orbMIP = lerp(4.5,
                    gDynamicDropWideOrbEdgeMip,
                    smoothstep(0.38, 0.82, r));
                lensMIP = lerp(lensMIP, orbMIP, orbMode);
            }
            refractedScene = txDynamicSnapshot.SampleLevel(
                samLinearClamp, saturate(sampleUV),
                lensMIP).rgb;
            // Visible right half: inspect shot depth at exactly the same
            // refracted UV. Magenta indicates a far/sky pixel; cyan indicates
            // geometry or a missing/invalid depth signal.
            if (gDynamicDropSkyDepthDebug > 0.5 && wideSide)
            {
                float shotDepth = txDynamicShotDepth.SampleLevel(
                    samLinearClamp, saturate(sampleUV),
                    0.0).r;
                refractedScene = shotDepth > 0.99999
                    ? float3(0.95, 0.12, 0.72)
                    : float3(0.05, 0.55, 0.70);
            }
            // Both halves use the same sky correction while the new lens
            // comparison is enabled, isolating the optical shape.
            else if (gDynamicDropSkyFogColorDebug > 0.5
                && (wideSide
                    || gDynamicDropInvertedFootprintDebug > 0.5
                    || gDynamicDropConcaveLensDebug > 0.5))
            {
                float shotDepth = txDynamicShotDepth.SampleLevel(
                    samLinearClamp, saturate(sampleUV),
                    0.0).r;
                if (shotDepth > 0.99999)
                {
                    if (gDynamicDropScreenSourceCompareDebug > 0.5
                        && local.x < 0.0 && local.y > 0.0)
                    {
                        // Two mip reads from a half-size screen copy:
                        // level 4 removes narrow bright rain streaks,
                        // level 8 supplies a broad local cloud reference.
                        // Carry only relative luminance into the already
                        // verified fog tone, never the LDR scene color.
                        float2 weatherUV = saturate(sampleUV);
                        float3 weatherCloud = txDynamicWeatherScreen.SampleLevel(
                            samLinearClamp, weatherUV, 4.0).rgb;
                        float3 weatherBroad = txDynamicWeatherScreen.SampleLevel(
                            samLinearClamp, weatherUV, 8.0).rgb;
                        float3 lumaWeights = float3(
                            0.2126, 0.7152, 0.0722);
                        float cloudRatio = clamp(
                            dot(weatherCloud, lumaWeights)
                            / max(dot(weatherBroad, lumaWeights), 0.04),
                            0.82, 1.18);
                        refractedScene = gDynamicDropWeatherFogColor
                            * cloudRatio;
                    }
                    else if (gDynamicDropSkyCloudDetailDebug > 0.5)
                    {
                        // Transfer only cloud luminance contrast onto the
                        // weather-matched sky color. A broad mip of the
                        // same shot supplies a local exposure reference;
                        // do not reintroduce the old sunset cloud hue.
                        float3 broadSky = txDynamicSnapshot.SampleLevel(
                            samLinearClamp,
                            saturate(sampleUV), 9.0).rgb;
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
            // Legacy direct LDR source probe, disabled in the current test.
            if (gDynamicDropSkySourceDebug > 0.5 && local.x < 0.0)
                refractedScene = txDynamicScreen.SampleLevel(
                    samLinearClamp, saturate(sampleUV),
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
        if (gDynamicDropConcaveLensDebug > 0.5
            && wideSide)
            opticalAccent *= 0.55;
        if (gDynamicDropWideOrbDebug > 0.5
            && gDynamicDropWideSceneDebug > 0.5 && wideSide)
        {
            // Reuse the refracted scene luminance; no extra scene lookup.
            // The curved face catches light while the rim stays restrained.
            float faceGlow = saturate((sceneLuma - 0.30) * 0.55)
                * highlight * (1.0 - smoothstep(0.62, 0.94, r));
            opticalAccent += float3(0.87, 0.94, 1.0)
                * faceGlow * gDynamicDropOrbGlow;
        }
        if (gDynamicDropWideGlintDebug > 0.5
            && gDynamicDropConcaveLensDebug > 0.5
            && wideSide)
        {
            // A broad scene direction informs only positive light contrast.
            // Keep the base lens monotonic and the reflected scene hue out
            // of the drop, so the old shot's weather tint is not copied.
            float2 screenAtDrop = pin.PosH.xy
                * gDynamicDropInvScreenSize;
            float twist = (frac(shapeSeed * 0.6180339) - 0.5) * 0.8
                + (screenAtDrop.x - 0.5) * 0.3;
            float2 broadDirection = float2(
                local.x + twist * local.y,
                local.y - twist * local.x);
            float2 broadUV = saturate(0.5
                + broadDirection * 0.46);
            float3 lightSample = txDynamicSnapshot.SampleLevel(
                samLinearClamp, broadUV, 2.0).rgb;
            float3 lightReference = txDynamicSnapshot.SampleLevel(
                samLinearClamp, broadUV, 8.0).rgb;
            float3 lightWeights = float3(0.2126, 0.7152, 0.0722);
            float lightContrast = dot(lightSample, lightWeights)
                / max(dot(lightReference, lightWeights), 0.08);
            float glint = saturate((lightContrast - 1.35) * 0.55)
                * smoothstep(0.05, 0.22, r)
                * (1.0 - smoothstep(0.72, 0.96, r));
            opticalAccent += float3(0.78, 0.88, 1.0)
                * glint * 0.9;
        }
        if (gDynamicDropGeometryShotDebug > 0.5
            && gDynamicDropOpaqueRefractionSplitDebug > 0.5)
            opticalAccent += float3(0.95, 0.68, 0.08)
                * (1.0 - smoothstep(0.005, 0.025, abs(local.x)))
                * 0.55;
        if (gDynamicDropGeometryShotDebug > 0.5
            && gDynamicDropScreenSourceCompareDebug > 0.5
            && local.x < 0.0)
            opticalAccent += float3(0.95, 0.68, 0.08)
                * (1.0 - smoothstep(0.005, 0.025, abs(local.y)))
                * 0.55;

        // The translucent candidate retains the actual scene beneath the
        // independent shot. The right-hand probe fades opacity to zero at
        // the physical outline to remove the circular color cutout.
        float alpha = saturate(
            0.55 + fresnel * 0.25 + highlight * 0.10
            + smoothstep(0.75, 0.98, r) * 0.08);
        if (gDynamicDropGeometryShotDebug > 0.5
            && gDynamicDropOpaqueRefractionSplitDebug > 0.5)
            alpha = 1.0;
        if (gDynamicDropSoftCompositeDebug > 0.5
            && gDynamicDropConcaveLensDebug > 0.5
            && wideSide)
            alpha = (0.38 + fresnel * 0.08 + highlight * 0.04)
                * (1.0 - smoothstep(0.72, 1.0, r));
        if (gDynamicDropWideSceneDebug > 0.5 && wideSide)
            alpha = (0.72 + fresnel * 0.08)
                * (1.0 - smoothstep(0.42, 0.98, r));
        if (gDynamicDropWideOrbDebug > 0.5
            && gDynamicDropWideSceneDebug > 0.5 && wideSide)
            alpha = (0.72 + fresnel * 0.08)
                * (1.0 - smoothstep(0.45, 0.92, r));
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
