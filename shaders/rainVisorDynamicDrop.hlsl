/*
    RealVisor Dynamic Rain Drop — Stage 4A

    One mesh quad represents one physical persistent droplet.
    This shader intentionally reproduces the current canonical renderer's
    simple radial mask only. It does not add optical refraction yet.

    Quad UV contract:
        (0,0) .. (1,1)
        center = (0.5, 0.5)
        quad half-width/height = physical droplet radius on the visor surface

    Canonical profile equivalence:
        inner smooth region = 0.30 * radius
        outer edge          = 1.00 * radius
*/

float4 main(PS_IN pin)
{
    float2 local = (pin.Tex - 0.5) * 2.0;
    float distanceToCenter = length(local);

    // Do not shade transparent corners of the quad.
    clip(1.0 - distanceToCenter);

    float mask =
        1.0
        - smoothstep(
            0.30,
            1.00,
            distanceToCenter
        );

    return float4(
        0.82,
        0.90,
        1.0,
        mask * 0.35
    );
}
