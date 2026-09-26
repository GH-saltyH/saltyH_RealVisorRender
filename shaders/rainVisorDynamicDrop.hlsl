/*
    RealVisor Dynamic Rain Drop — Stage 4A physical diagnostic

    One mesh quad represents one physical persistent droplet.

    IMPORTANT:
    - This file is the shader used by RAIN_DYNAMIC_SURFACE_STATE_ENABLED.
    - The quad remains the transport primitive, but only a circular footprint
      is allowed to survive pixel shading.
    - This is deliberately a high-contrast physical diagnostic, not the final
      optical rain shader. Refraction, highlights and film optics come later.

    Quad UV contract:
        (0,0) .. (1,1)
        center = (0.5, 0.5)
        quad half-width/height = physical droplet radius on the visor surface
*/

float4 main(PS_IN pin)
{
    float2 local = (pin.Tex - 0.5) * 2.0;
    float r = length(local);

    // Hard circular silhouette. If a square is still visible with this shader,
    // the problem is not the radial mask: it is shader selection/UV transport.
    clip(1.0 - r);

    // Keep the edge visually obvious so physical-radius differences can be
    // judged while driving. This is intentionally diagnostic, not optical.
    float edge = smoothstep(0.72, 0.98, r);
    float center = 1.0 - smoothstep(0.0, 0.65, r);

    float3 innerColor = float3(0.78, 0.90, 1.00);
    float3 edgeColor = float3(0.25, 0.55, 1.00);
    float3 color = lerp(innerColor, edgeColor, edge);

    // High, nearly uniform opacity avoids the previous soft footprint making
    // small droplets difficult to compare by apparent diameter.
    float alpha = 0.82 + center * 0.12;

    return float4(color, alpha);
}
