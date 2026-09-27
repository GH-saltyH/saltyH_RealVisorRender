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
*/

// txDynamicScene, gDynamicDropDebugUV and gDynamicDropHDRCopyDebug are
// injected by render.mesh({ textures/values = ... }). Do not redeclare them.

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
