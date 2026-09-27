/*
    RealVisor Dynamic Rain Drop — Stage 4A transport diagnostic

    RAIN_DYNAMIC_SURFACE_STATE_ENABLED uses this shader.

    Debug contract:
    - gDynamicDropDebugUV > 0.5:
        bypass circular clipping and display interpolated quad UV directly.
        Expected result per quad: horizontal red gradient, vertical green
        gradient, opaque output.
    - otherwise:
        render the physical-radius quad as a circular diagnostic droplet.
*/

float gDynamicDropDebugUV;

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

    float edge = smoothstep(0.72, 0.98, r);
    float center = 1.0 - smoothstep(0.0, 0.65, r);

    float3 innerColor = float3(0.78, 0.90, 1.00);
    float3 edgeColor = float3(0.25, 0.55, 1.00);
    float3 color = lerp(innerColor, edgeColor, edge);
    float alpha = 0.82 + center * 0.12;

    return float4(color, alpha);
}
