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
        compare direct HDR, an independent scene source at raw and expanded
        UV, and a known file texture. The two expanded samples use the same
        UV transform when gDynamicDropSnapshotDebug is enabled.
*/

// All txDynamicScene/gDynamicDrop* inputs are injected by render.mesh({
// textures/values = ... }). Do not redeclare them in this file.

float4 main(PS_IN pin)
{
    if (gDynamicDropDebugUV > 0.5)
    {
        // Do not clip anything in this branch. If the dynamic mesh is bound
        // and pin.Tex is transported correctly, each quad must show a 0..1
        // red/green gradient. A flat color identifies broken UV transport.
        return float4(pin.Tex.x, pin.Tex.y, 0.15, 1.0);
    }

    float2 local = (pin.Tex - 0.5) * 2.0;
    float r = length(local);

    clip(1.0 - r);

    if (gDynamicDropScreenUVDebug > 0.5)
    {
        float2 raw = pin.ScreenPos.xy;
        float2 expandedUV = saturate((raw - 0.5) * 8.0 + 0.5);
        bool right = local.x >= 0.0;
        bool bottom = local.y >= 0.0;
        float3 sampledColor;

        if (!right && !bottom)
        {
            // Upper-left: direct HDR, using the same 8x mapping as the
            // snapshot below while snapshot comparison is enabled.
            sampledColor = txDynamicScene.SampleLevel(
                samLinearClamp,
                gDynamicDropSnapshotDebug > 0.5 ? expandedUV : raw,
                0.0).rgb;
        }
        else if (right && !bottom)
        {
            // Upper-right: known nonblack normal-map pixel at (0.5, 0.5)
            // verifies ordinary file-texture sampling in the same draw.
            sampledColor = txDynamicControl.SampleLevel(
                samLinearClamp, float2(0.5, 0.5), 0.0).rgb;
        }
        else if (!right && bottom)
        {
            // Lower-left: independently rendered scene when enabled, with
            // the identical 8x UV mapping as direct HDR above.
            sampledColor = txDynamicSnapshot.SampleLevel(
                samLinearClamp, expandedUV, 0.0).rgb;
            if (gDynamicDropGeometryShotDebug > 0.5)
                sampledColor *= 8.0;
        }
        else
        {
            // Lower-right: the same independent scene at unexpanded UV.
            // Fall back to LDR if the geometry shot is disabled.
            if (gDynamicDropGeometryShotDebug > 0.5)
                sampledColor = txDynamicSnapshot.SampleLevel(
                    samLinearClamp, raw, 0.0).rgb * 8.0;
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

    // Reconstruct a hemisphere-like local normal from the circular footprint.
    // This is an optical profile only: the actual visor surface normal remains
    // owned by the transport mesh and the target-surface lookup.
    float z = sqrt(saturate(1.0 - r * r));
    float3 dropNormal = normalize(float3(local.x, local.y, z));

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

        float2 refractionOffset =
            dropNormal.xy
            * radialProfile
            * gDynamicDropRefractionPixels
            * gDynamicDropInvScreenSize;

        float3 refractedScene = txDynamicScene.SampleLevel(
            samLinearClamp,
            saturate(pin.ScreenPos + refractionOffset),
            0.0
        ).rgb;

        // Keep the proven Stage 4B.0 rim/highlight at low strength so the
        // droplet boundary remains identifiable over smooth backgrounds.
        float3 opticalAccent =
            float3(0.72, 0.86, 1.00) * fresnel * 0.08
            + float3(0.92, 0.98, 1.00) * highlight * 0.14;

        return float4(refractedScene + opticalAccent, 1.0);
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
