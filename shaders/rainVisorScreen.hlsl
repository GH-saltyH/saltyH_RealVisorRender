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

float3 rainDebugNormalWorld(float2 p)
{
    float3 n = txRainSurfaceNormal.SampleLevel(
        samLinearRain,
        p,
        0.0
    ).rgb * 2.0 - 1.0;

    n = normalize(n);
    return normalize(mul(n, (float3x3)gRainObjectToWorld));
}

float2 rainDebugProjectWorldVector(float3 forceWorld, float3 normalWorld)
{
    float3 normalObject = normalize(
        mul(normalWorld, transpose((float3x3)gRainObjectToWorld))
    );

    float3 u = float3(1.0, 0.0, 0.0);
    u -= normalObject * dot(u, normalObject);

    if (length(u) < 0.0001)
    {
        u = float3(0.0, 0.0, 1.0);
        u -= normalObject * dot(u, normalObject);
    }

    u = normalize(u);

    float3 v = normalize(cross(normalObject, u));
    if (dot(v, float3(0.0, -1.0, 0.0)) < 0.0)
        v = -v;

    float3 uWorld = normalize(mul(u, (float3x3)gRainObjectToWorld));
    float3 vWorld = normalize(mul(v, (float3x3)gRainObjectToWorld));

    return float2(
        dot(forceWorld, uWorld),
        dot(forceWorld, vWorld)
    );
}

float3 rainDebugAirflow(float3 normalWorld, float radius)
{
    float3 air = gRainAirVelocityWorld;
    float speed = length(air);

    if (speed < 0.0001)
        return float3(0.0, 0.0, 0.0);

    float diameterMM =
        (radius * 2.0)
        / max(gRainStatePhysicalDiameterUVPerMM, 0.000001);

    float diameterM = diameterMM * 0.001;
    float radiusM = diameterM * 0.5;
    float area = 3.14159265 * radiusM * radiusM;
    float volume =
        (4.0 / 3.0)
        * 3.14159265
        * radiusM * radiusM * radiusM;
    float massKg = max(volume * 1000.0, 0.000000000001);

    float3 airDir = air / speed;
    float incidence = saturate(-dot(airDir, normalWorld));

    if (incidence <= 0.000001)
        return float3(0.0, 0.0, 0.0);

    float dragForce =
        0.5
        * max(gRainAirDensity, 0.0)
        * speed * speed
        * max(gRainAirDragCoeff, 0.0)
        * area
        * incidence;

    return airDir * (dragForce / massKg);
}

float3 rainDebugExternalForce(
    float3 normalWorld,
    float radius
)
{
    float3 forceWorld = float3(0.0, 0.0, 0.0);

    if (fmod(floor(gRainForceMask), 2.0) >= 0.5)
        forceWorld +=
            float3(0.0, -gRainStateGravity, 0.0)
            * gRainPhysicsAccelScale;

    if (fmod(floor(gRainForceMask / 2.0), 2.0) >= 0.5)
        forceWorld +=
            gRainAcceleration
            * gRainPhysicsAccelScale;

    if (fmod(floor(gRainForceMask / 4.0), 2.0) >= 0.5)
        forceWorld +=
            rainDebugAirflow(normalWorld, radius)
            * gRainPhysicsAccelScale;

    return forceWorld;
}

float4 rainNormalObjectDebug(PS_IN pin)
{
    float3 n =
        txRainSurfaceNormal.SampleLevel(
            samLinearRain,
            pin.Tex,
            0.0
        ).rgb;

    return float4(n, 1.0);
}

float4 rainNormalWorldDebug(PS_IN pin)
{
    float3 n = rainDebugNormalWorld(pin.Tex);
    return float4(n * 0.5 + 0.5, 1.0);
}

float4 rainPredictedPositionsDebug(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;

    [loop]
    for (int i = 0; i < 256; ++i)
    {
        if ((float)i >= count)
            break;

        float2 suv = float2(
            ((float)i + 0.5) / count,
            0.5
        );

        float4 state = txRainState.SampleLevel(
            samPointRain,
            suv,
            0.0
        );

        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            suv,
            0.0
        );

        if (meta.a < 0.5 || meta.a > 1.5)
            continue;

        float2 predicted =
            state.rg
            + state.ba * gRainDebugPredictionTime;

        result = max(
            result,
            rainCanonicalDrop(
                pin,
                predicted,
                max(meta.r, 0.000001)
            )
        );

        result = max(
            result,
            rainCanonicalDrop(
                pin,
                state.rg,
                max(meta.r * 0.55, 0.000001)
            )
        );
    }

    return float4(0.20, 0.85, 1.0, saturate(result));
}

float4 rainForceDirectionDebug(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 forceColor = float3(1.0, 0.25, 0.05);

    [loop]
    for (int i = 0; i < 256; ++i)
    {
        if ((float)i >= count)
            break;

        float2 suv = float2(
            ((float)i + 0.5) / count,
            0.5
        );

        float4 state = txRainState.SampleLevel(
            samPointRain,
            suv,
            0.0
        );

        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            suv,
            0.0
        );

        if (meta.a < 0.5 || meta.a > 1.5)
            continue;

        float3 normalWorld = rainDebugNormalWorld(state.rg);
        float3 forceWorld =
            rainDebugExternalForce(
                normalWorld,
                max(meta.r, 0.000001)
            );

        float2 forceUV =
            rainDebugProjectWorldVector(
                forceWorld,
                normalWorld
            );

        float magnitude = length(forceUV);
        float2 dir =
            magnitude > 0.000001
            ? forceUV / magnitude
            : float2(0.0, 0.0);

        /*
            Render the current drop plus a thin directional arrow.
            Arrow length is visualization-only and never feeds state.
        */
        float2 tip =
            state.rg
            + dir * magnitude * gRainDebugForceArrowScale;

        float2 shaft = tip - state.rg;
        float shaftLength = length(shaft);
        float2 toPoint = pin.Tex - state.rg;

        float along =
            shaftLength > 0.000001
            ? dot(toPoint, shaft) / (shaftLength * shaftLength)
            : 0.0;

        float2 closest =
            state.rg
            + shaft * saturate(along);

        float shaftMask =
            1.0
            - smoothstep(
                max(meta.r * 0.20, 0.00015),
                max(meta.r * 0.60, 0.00030),
                length(pin.Tex - closest)
            );

        float dropMask =
            rainCanonicalDrop(
                pin,
                state.rg,
                max(meta.r, 0.000001)
            );

        result = max(result, max(dropMask, shaftMask));
    }

    return float4(forceColor, saturate(result));
}

float4 rainPhysicalStateViewerDebug(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 color = float3(1.0, 0.15, 0.65);

    [loop]
    for (int i = 0; i < 256; ++i)
    {
        if ((float)i >= count)
            break;

        float2 suv = float2(
            ((float)i + 0.5) / count,
            0.5
        );

        float4 state = txRainState.SampleLevel(
            samPointRain,
            suv,
            0.0
        );

        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            suv,
            0.0
        );

        if (meta.a < 0.5 || meta.a > 1.5)
            continue;

        float speed =
            length(state.ba);

        float normalizedSpeed =
            saturate(
                speed
                / max(gRainDebugStateSpeedScale, 0.000001)
            );

        float2 probe =
            state.rg
            + float2(
                normalizedSpeed * 0.002,
                0.0
            );

        result = max(
            result,
            rainCanonicalDrop(
                pin,
                probe,
                max(meta.r * (0.65 + 0.35 * normalizedSpeed), 0.000001)
            )
        );
    }

    return float4(color, saturate(result));
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
    if (gRainDebug == 1)
        return rainNormalObjectDebug(pin);

    if (gRainDebug == 2)
        return rainNormalWorldDebug(pin);

    if (gRainDebug == 3)
        return rainBoundaryMaskDebug(pin);

    if (gRainDebug == 4)
        return rainPredictedPositionsDebug(pin);

    if (gRainDebug == 5)
        return rainForceDirectionDebug(pin);

    if (gRainDebug == 6)
        return rainPhysicalStateViewerDebug(pin);

    return rainPersistentStateRender(pin);
}
