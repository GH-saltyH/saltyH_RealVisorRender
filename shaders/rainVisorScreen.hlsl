SamplerState samPointRain
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
};

SamplerState samLinearRain
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
};

/*
    RealVisor canonical RainFX renderer.

    Physics is no longer evaluated in this render shader.
    The authoritative persistent GPU state is produced by the Lua-managed
    RainFX state update pass:

        external forces
            -> surface projection
            -> adhesion
            -> flow acceleration
            -> surface drag
            -> physical size-dependent max speed
            -> position integration
            -> txRainState / txRainStateMeta

    This shader is display-only. It consumes that state directly.

    State:
        R,G = signed visor UV position
        B,A = surface velocity in UV/s

    Meta:
        R = physical droplet radius in visor UV
        G = physical normalized mass profile
        A = lifecycle state
            0 = dead/waiting
            1 = alive
            2 = respawn pending
*/

float rainCanonicalDrop(
    PS_IN pin,
    float2 position,
    float radius
)
{
    float distanceToDrop = length(pin.Tex - position);

    return 1.0 - smoothstep(
        radius * 0.30,
        radius,
        distanceToDrop
    );
}

float4 rainPersistentStateRender(
    PS_IN pin
)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;

    [loop]
    for (int i = 0; i < 256; ++i)
    {
        if ((float)i >= count)
            break;

        float stateIndex = (float)i;
        float2 stateUV = float2(
            (stateIndex + 0.5) / count,
            0.5
        );

        float4 state = txRainState.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        if (meta.a < 0.5 || meta.a > 1.5)
            continue;

        result = max(
            result,
            rainCanonicalDrop(
                pin,
                state.rg,
                max(meta.r, 0.000001)
            )
        );
    }

    return float4(
        0.82,
        0.90,
        1.0,
        result * 0.35
    );
}

float4 rainBoundaryMaskDebug(PS_IN pin)
{
    float mask = txRainBoundaryMask.SampleLevel(
        samLinearRain,
        pin.Tex,
        0.0
    ).r;

    return float4(mask, mask, mask, 1.0);
}

float4 rainLifecycleDebug(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 color = float3(0.25, 0.95, 1.0);

    [loop]
    for (int i = 0; i < 256; ++i)
    {
        if ((float)i >= count)
            break;

        float stateIndex = (float)i;
        float2 stateUV = float2(
            (stateIndex + 0.5) / count,
            0.5
        );

        float4 state = txRainState.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        float marker = rainCanonicalDrop(
            pin,
            state.rg,
            max(meta.r, 0.000001)
        );

        if (marker > result)
        {
            result = marker;

            if (meta.a < 0.5)
                color = float3(0.0, 0.0, 0.0);
            else if (meta.a > 1.5)
                color = float3(1.0, 0.85, 0.10);
            else
                color = float3(0.25, 0.95, 1.0);
        }
    }

    return float4(color, saturate(result));
}

float4 rainPhysicalStateDebug(PS_IN pin)
{
    /*
        Canonical physical-state viewer.

        The marker radius is the actual physical UV radius stored in Meta.R.
        No legacy visual enlargement or artificial size remapping is applied.
    */
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float moving = 0.0;

    [loop]
    for (int i = 0; i < 256; ++i)
    {
        if ((float)i >= count)
            break;

        float stateIndex = (float)i;
        float2 stateUV = float2(
            (stateIndex + 0.5) / count,
            0.5
        );

        float4 state = txRainState.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        if (meta.a < 0.5 || meta.a > 1.5)
            continue;

        moving = max(
            moving,
            step(0.00001, length(state.ba))
        );

        result = max(
            result,
            rainCanonicalDrop(
                pin,
                state.rg,
                max(meta.r, 0.000001)
            )
        );
    }

    if (result > 0.0)
    {
        return float4(
            1.0,
            0.15,
            0.65,
            saturate(result)
        );
    }

    return float4(
        1.0,
        1.0,
        1.0,
        moving * 0.5
    );
}

float4 main(PS_IN pin)
{
    if (gRainDebug == 40)
        return rainBoundaryMaskDebug(pin);

    if (gRainDebug == 41 || gRainDebug == 42)
        return rainLifecycleDebug(pin);

    if (gRainDebug == 51)
        return rainPhysicalStateDebug(pin);

    return rainPersistentStateRender(pin);
}
