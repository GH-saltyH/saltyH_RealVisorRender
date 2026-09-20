float2 rainHash22(float2 p)
{
    p = float2(
        dot(p, float2(127.1, 311.7)),
        dot(p, float2(269.5, 183.3))
    );

    return frac(sin(p) * 43758.5453);
}


float rainHash(float2 p)
{
    return frac(
        sin(dot(p, float2(127.1, 311.7))) * 43758.5453
    );
}


/*
    The supplied normal map is OBJECT-SPACE.

    encoded = normal * 0.5 + 0.5
    decoded = encoded * 2 - 1

    The normal is converted:
        Object -> World -> Camera-local

    so it is in the same coordinate system as the acceleration force.
*/
float3 rainSurfaceNormalObject(float2 uv)
{
    float3 encoded =
        txRainSurfaceNormal.SampleLevel(
            samLinearSimple,
            saturate(uv),
            0.0
        ).rgb;

    float3 decoded =
        encoded * 2.0 - 1.0;

    return normalize(decoded);
}


float3 rainSurfaceNormalCamera(float2 uv)
{
    float3 normalObject =
        rainSurfaceNormalObject(uv);

    float3 normalWorld =
        mul(
            normalObject,
            (float3x3)gRainObjectToWorld
        );

    normalWorld =
        normalize(normalWorld);

    return normalize(
        float3(
            dot(normalWorld, gRainCameraSide),
            dot(normalWorld, gRainCameraUp),
            dot(normalWorld, gRainCameraForward)
        )
    );
}


/*
    Build the ACTUAL UV tangent frame from the rendered mesh itself.

    mesh.fx exposes:
        pin.PosL = interpolated local mesh position
        pin.Tex  = interpolated mesh UV

    Their screen-space derivatives therefore describe the real local
    surface direction corresponding to UV U/V at this fragment.

    This replaces the previous artificial tangent frame that was built
    only from the normal and camera-up vector.
*/
void rainSurfaceBasisCamera(
    PS_IN pin,
    out float3 tangentUCamera,
    out float3 tangentVCamera
)
{
    float3 normalCamera =
        rainSurfaceNormalCamera(pin.Tex);

    float3 dPosDx = ddx(pin.PosL);
    float3 dPosDy = ddy(pin.PosL);

    float2 dUvDx = ddx(pin.Tex);
    float2 dUvDy = ddy(pin.Tex);

    float determinant =
        dUvDx.x * dUvDy.y
        - dUvDx.y * dUvDy.x;

    if (abs(determinant) < 0.000001)
    {
        float3 fallbackU =
            normalize(
                cross(
                    gRainCameraUp,
                    normalCamera
                )
            );

        if (length(fallbackU) < 0.000001)
        {
            fallbackU =
                normalize(
                    cross(
                        gRainCameraSide,
                        normalCamera
                    )
                );
        }

        float3 fallbackV =
            normalize(
                cross(
                    normalCamera,
                    fallbackU
                )
            );

        tangentUCamera = fallbackU;
        tangentVCamera = fallbackV;
        return;
    }

    /*
        Standard UV-derivative reconstruction:
            dP/du = (dPdx * dVdy - dPdy * dVdx) / det
            dP/dv = (-dPdx * dUdy + dPdy * dUdx) / det
    */
    float3 tangentUObject =
        (
            dPosDx * dUvDy.y
            - dPosDy * dUvDx.y
        ) / determinant;

    float3 tangentVObject =
        (
            -dPosDx * dUvDy.x
            + dPosDy * dUvDx.x
        ) / determinant;

    float3 tangentUWorld =
        normalize(
            mul(
                tangentUObject,
                (float3x3)gRainObjectToWorld
            )
        );

    float3 tangentVWorld =
        normalize(
            mul(
                tangentVObject,
                (float3x3)gRainObjectToWorld
            )
        );

    tangentUCamera =
        normalize(
            float3(
                dot(tangentUWorld, gRainCameraSide),
                dot(tangentUWorld, gRainCameraUp),
                dot(tangentUWorld, gRainCameraForward)
            )
        );

    tangentVCamera =
        normalize(
            float3(
                dot(tangentVWorld, gRainCameraSide),
                dot(tangentVWorld, gRainCameraUp),
                dot(tangentVWorld, gRainCameraForward)
            )
        );

    /*
        The tangent frame is purely geometric/UV based.
        It is intentionally independent of the candidate normal so
        derivatives are evaluated once per fragment, outside candidate
        loops. Candidate-specific normal orthogonalization is performed
        later without gradient instructions.
    */

    /*
        Preserve the UV V orientation after orthogonalization.
    */
    if (
        dot(
            cross(
                normalCamera,
                tangentUCamera
            ),
            tangentVCamera
        ) < 0.0
    )
    {
        tangentVCamera =
            -tangentVCamera;
    }
}


/*
    Project a force into the ACTUAL UV tangent frame.

    U is mirrored at the final UV-output stage to preserve the existing
    tested visor left/right orientation. The normal itself is never
    negated or modified.
*/
float2 rainProjectForceToUV(
    float3 force,
    float3 normal,
    float3 baseTangentU,
    float3 baseTangentV,
    float patternScale
)
{
    /*
        Candidate-specific normal correction contains no ddx/ddy.
        This keeps the physical surface normal local to the drop while
        allowing the actual mesh UV derivatives to be evaluated once
        per rendered fragment.
    */
    float3 tangentU =
        normalize(
            baseTangentU
            - normal * dot(
                baseTangentU,
                normal
            )
        );

    float3 tangentV =
        normalize(
            baseTangentV
            - normal * dot(
                baseTangentV,
                normal
            )
        );

    if (
        dot(
            cross(
                normal,
                tangentU
            ),
            tangentV
        ) < 0.0
    )
    {
        tangentV = -tangentV;
    }

    float2 result =
        float2(
            -dot(force, tangentU),
            dot(force, tangentV)
        );

    return result * patternScale;
}


float2 rainPatternToMeshUV(
    float2 proceduralUV,
    float patternScale,
    float2 patternOffset
)
{
    return (
        proceduralUV
        - patternOffset
    ) / max(
        patternScale,
        0.000001
    );
}


/*
    Analytic droplet travel under linear drag.

    This keeps the droplet deterministic without storing per-drop velocity
    between frames. The force excess determines acceleration, drag determines
    the terminal speed, and the terminal speed is capped independently.
*/
float rainDropTravelDistance(
    float excessForce,
    float age
)
{
    if (excessForce <= 0.000001 || age <= 0.0)
        return 0.0;

    float acceleration =
        excessForce * gRainFlowAcceleration;

    float drag =
        max(
            gRainFlowDrag,
            0.000001
        );

    float uncappedTerminalSpeed =
        acceleration / drag;

    float maxSpeed =
        max(
            gRainFlowMaxSpeed,
            0.0
        );

    if (maxSpeed <= 0.0)
        return 0.0;

    /*
        Below the speed cap, integrate:
            v(t) = vTerminal * (1 - exp(-drag * t))
            s(t) = vTerminal * t
                   - vTerminal / drag * (1 - exp(-drag * t))
    */
    if (uncappedTerminalSpeed <= maxSpeed)
    {
        return
            uncappedTerminalSpeed * age
            - (
                uncappedTerminalSpeed / drag
            ) * (
                1.0
                - exp(
                    -drag * age
                )
            );
    }

    /*
        If the natural terminal speed is above the cap, integrate the
        accelerating section up to the cap, then continue at max speed.
    */
    float speedRatio =
        saturate(
            maxSpeed / uncappedTerminalSpeed
        );

    float timeToMax =
        -log(
            max(
                1.0 - speedRatio,
                0.000001
            )
        ) / drag;

    if (age <= timeToMax)
    {
        return
            uncappedTerminalSpeed * age
            - (
                uncappedTerminalSpeed / drag
            ) * (
                1.0
                - exp(
                    -drag * age
                )
            );
    }

    float distanceToMax =
        uncappedTerminalSpeed * timeToMax
        - (
            uncappedTerminalSpeed / drag
        ) * (
            1.0
            - exp(
                -drag * timeToMax
            )
        );

    return
        distanceToMax
        + maxSpeed * (
            age - timeToMax
        );
}


/*
    Single-drop lifecycle diagnostic.
*/
float rainSingleDropDiagnostic(PS_IN pin, float time)
{
    const float2 spawnUV = float2(0.5, 0.535);
    const float dropSize = 0.085;

    float2 proceduralUV = pin.Tex;
    float2 grid = proceduralUV * 18.0;
    float2 spawnPos = spawnUV * 18.0;

    float adhesion =
        lerp(
            gRainAdhesionMin,
            gRainAdhesionMax,
            0.5
        );

    float3 surfaceNormal =
        rainSurfaceNormalCamera(spawnUV);

    float3 baseTangentU;
    float3 baseTangentV;

    rainSurfaceBasisCamera(
        pin,
        baseTangentU,
        baseTangentV
    );

    float3 gravityForce =
        float3(
            0.0,
            -gRainGravity,
            0.0
        );

    float3 effectiveForce =
        gravityForce
        + gRainAcceleration * gRainForceScale;

    float2 tangentForce =
        rainProjectForceToUV(
            effectiveForce,
            surfaceNormal,
            baseTangentU,
            baseTangentV,
            1.0
        );

    float forceMagnitude =
        length(tangentForce);

    float excessForce =
        max(
            forceMagnitude - adhesion,
            0.0
        );

    float dynamic01 =
        saturate(
            excessForce / max(adhesion, 0.001)
        );

    const float lifetime = 6.0;
    const float respawnGap = 0.75;
    const float cycleDuration = lifetime + respawnGap;

    float cycleTime =
        fmod(
            time,
            cycleDuration
        );

    if (cycleTime >= lifetime)
        return 0.0;

    float age = cycleTime;

    float lifeFadeIn =
        smoothstep(
            0.0,
            0.20,
            age
        );

    float lifeFadeOut =
        1.0
        - smoothstep(
            lifetime - 0.30,
            lifetime,
            age
        );

    float lifeVisibility =
        lifeFadeIn
        * lifeFadeOut;

    float2 movement = float2(0.0, 0.0);

    if (excessForce > 0.000001)
    {
        float travelDistance =
            min(
                rainDropTravelDistance(
                    excessForce,
                    age
                ),
                gRainFlowMax
            );

        movement =
            normalize(tangentForce)
            * travelDistance;
    }

    float2 dropPos =
        spawnPos + movement;

    float2 delta =
        grid - dropPos;

    float distanceToDrop =
        length(delta);

    float drop =
        1.0
        - smoothstep(
            dropSize * 0.30,
            dropSize,
            distanceToDrop
        );

    float movementLength =
        length(movement);

    float2 movementDir =
        movementLength > 0.000001
        ? movement / movementLength
        : float2(0.0, 0.0);

    float trailLength =
        movementLength;

    float trailWidth =
        max(
            dropSize * lerp(0.16, 0.28, dynamic01),
            0.0020
        );

    float trailAlong =
        dot(
            -delta,
            movementDir
        );

    float2 perpendicular =
        float2(
            -movementDir.y,
            movementDir.x
        );

    float trailSide =
        abs(
            dot(
                delta,
                perpendicular
            )
        );

    float trail =
        movementLength > 0.000001
        ? smoothstep(
            trailWidth,
            0.0,
            trailSide
        )
        : 0.0;

    float trailFadeIn =
        smoothstep(
            0.0,
            trailWidth,
            trailAlong
        );

    float trailFadeOut =
        1.0
        - smoothstep(
            trailLength * 0.70,
            max(
                trailLength,
                trailLength * 0.70 + trailWidth
            ),
            trailAlong
        );

    trail *=
        trailFadeIn
        * trailFadeOut
        * smoothstep(
            0.0,
            0.5,
            dynamic01
        );

    return saturate(
        (drop + trail)
        * lifeVisibility
    );
}


float rainDropLayer(
    PS_IN pin,
    float time,
    float cellScale,
    float patternScale,
    float2 patternOffset,
    float layerOffset
)
{
    float2 proceduralUV =
        pin.Tex * patternScale
        + patternOffset;

    float2 grid =
        proceduralUV * cellScale;

    float2 baseCell =
        floor(grid);

    float result = 0.0;

    float3 baseTangentU;
    float3 baseTangentV;

    rainSurfaceBasisCamera(
        pin,
        baseTangentU,
        baseTangentV
    );

    for (int y = -1; y <= 1; ++y)
    {
        for (int x = -1; x <= 1; ++x)
        {
            float2 cell =
                baseCell
                + float2(x, y);

            float2 cellSeed =
                cell
                + layerOffset * 19.37;

            float2 rndPos =
                rainHash22(
                    cellSeed + 17.13
                );

            float2 rndState =
                rainHash22(
                    cellSeed + 43.71
                );

            float2 rndMotion =
                rainHash22(
                    cellSeed + 91.37
                );

            float rndSpawn =
                rainHash(
                    cellSeed + 157.91
                );

            float spawnChance =
                lerp(
                    0.22,
                    0.52,
                    rndState.x
                );

            if (rndSpawn > spawnChance)
                continue;

            float dropSize =
                lerp(
                    0.032,
                    0.115,
                    pow(rndState.y, 1.65)
                );

            float adhesion =
                lerp(
                    gRainAdhesionMin,
                    gRainAdhesionMax,
                    rndMotion.x
                );

            float2 spawnPos =
                cell
                + float2(
                    0.08 + rndPos.x * 0.84,
                    0.08 + rndPos.y * 0.84
                );

            float2 surfaceUV =
                rainPatternToMeshUV(
                    spawnPos / cellScale,
                    patternScale,
                    patternOffset
                );

            float3 surfaceNormal =
                rainSurfaceNormalCamera(
                    surfaceUV
                );

            float3 gravityForce =
                float3(
                    0.0,
                    -gRainGravity,
                    0.0
                );

            float3 effectiveForce =
                gravityForce
                + gRainAcceleration * gRainForceScale;

            float2 tangentForce =
                rainProjectForceToUV(
                    effectiveForce,
                    surfaceNormal,
                    baseTangentU,
                    baseTangentV,
                    patternScale
                );

            float forceMagnitude =
                length(tangentForce);

            float lifetime =
                lerp(
                    gRainDropLifetimeMin,
                    gRainDropLifetimeMax,
                    rndState.x
                );

            lifetime =
                max(
                    lifetime,
                    0.001
                );

            float respawnGap =
                lerp(
                    gRainDropRespawnGapMin,
                    gRainDropRespawnGapMax,
                    rndState.y
                );

            float cycleDuration =
                lifetime
                + max(
                    respawnGap,
                    0.0
                );

            float cycleTime =
                fmod(
                    time
                    + rndMotion.y * cycleDuration,
                    cycleDuration
                );

            if (cycleTime >= lifetime)
                continue;

            float age = cycleTime;

            float life01 =
                saturate(
                    age / lifetime
                );

            float lifeFadeIn =
                smoothstep(
                    0.0,
                    min(
                        0.08,
                        lifetime * 0.20
                    ),
                    age
                );

            float lifeFadeOut =
                1.0
                - smoothstep(
                    lifetime
                    - min(
                        0.12,
                        lifetime * 0.20
                    ),
                    lifetime,
                    age
                );

            float lifeVisibility =
                lifeFadeIn
                * lifeFadeOut;

            float excessForce =
                max(
                    forceMagnitude
                    - adhesion,
                    0.0
                );

            float dynamic01 =
                saturate(
                    excessForce
                    /
                    max(
                        adhesion,
                        0.001
                    )
                );

            if (excessForce <= 0.000001)
            {
                float2 delta =
                    grid
                    - spawnPos;

                float distanceToDrop =
                    length(delta);

                float drop =
                    smoothstep(
                        dropSize,
                        dropSize * 0.30,
                        distanceToDrop
                    );

                result =
                    max(
                        result,
                        drop * lifeVisibility
                    );

                continue;
            }

            float travelDistance =
                rainDropTravelDistance(
                    excessForce,
                    age
                );

            travelDistance =
                min(
                    travelDistance,
                    gRainFlowMax
                );

            float2 movement =
                normalize(tangentForce)
                * travelDistance;

            float2 dropPos =
                spawnPos
                + movement;

            float2 pixelPos =
                grid;

            float2 delta =
                pixelPos
                - dropPos;

            float distanceToDrop =
                length(delta);

            float drop =
                smoothstep(
                    dropSize,
                    dropSize * 0.30,
                    distanceToDrop
                );

            float movementLength =
                length(movement);

            float2 movementDir =
                movementLength > 0.000001
                ? movement / movementLength
                : float2(0.0, 0.0);

            float trailLength =
                movementLength;

            float trailAmount =
                smoothstep(
                    0.15,
                    0.65,
                    dynamic01
                );

            float trailWidth =
                max(
                    dropSize * lerp(0.16, 0.28, dynamic01),
                    0.0020
                );

            float trailAlong =
                dot(
                    -delta,
                    movementDir
                );

            float2 perpendicular =
                float2(
                    -movementDir.y,
                    movementDir.x
                );

            float trailSide =
                abs(
                    dot(
                        delta,
                        perpendicular
                    )
                );

            float trail =
                movementLength > 0.000001
                ? smoothstep(
                    trailWidth,
                    0.0,
                    trailSide
                )
                : 0.0;

            float trailFadeIn =
                smoothstep(
                    0.0,
                    trailWidth,
                    trailAlong
                );

            float trailFadeOut =
                1.0
                - smoothstep(
                    trailLength * 0.70,
                    max(
                        trailLength,
                        trailLength * 0.70
                        + trailWidth
                    ),
                    trailAlong
                );

            trail *=
                trailFadeIn
                * trailFadeOut
                * trailAmount;

            trail *=
                lerp(
                    0.15,
                    0.75,
                    dynamic01
                );

            result =
                max(
                    result,
                    drop + trail
                );
        }
    }

    return saturate(result);
}


float4 rainDebugOutput(
    PS_IN pin
)
{
    float3 acceleration =
        gRainAcceleration
        * gRainForceScale;

    float accelerationMagnitude =
        length(acceleration);

    float3 normal =
        rainSurfaceNormalCamera(
            pin.Tex
        );

    float3 baseTangentU;
    float3 baseTangentV;

    rainSurfaceBasisCamera(
        pin,
        baseTangentU,
        baseTangentV
    );

    float2 tangentForce =
        rainProjectForceToUV(
            acceleration,
            normal,
            baseTangentU,
            baseTangentV,
            1.0
        );

    float tangentMagnitude =
        length(tangentForce);

    if (gRainDebug == 1)
    {
        return float4(
            saturate(
                tangentMagnitude * 0.5
            ),
            saturate(
                abs(tangentForce.x) * 0.5
            ),
            saturate(
                abs(tangentForce.y) * 0.5
            ),
            1.0
        );
    }

    if (gRainDebug == 2)
    {
        return float4(
            saturate(
                accelerationMagnitude * 0.05
            ),
            saturate(
                abs(acceleration.x) * 0.1
            ),
            saturate(
                abs(acceleration.z) * 0.1
            ),
            1.0
        );
    }

    /* Surface-normal diagnostic: RGB is camera-space normal remapped to 0..1. */
    if (gRainDebug == 5)
    {
        return float4(
            normal * 0.5 + 0.5,
            1.0
        );
    }

    /*
        Local movement-direction diagnostic.
        Red/green encode the projected UV direction, blue encodes its strength.
        This is intentionally based on the actual mesh tangent frame and the
        local normal at the current fragment.
    */
    if (gRainDebug == 6)
    {
        float2 direction =
            tangentMagnitude > 0.000001
            ? tangentForce / tangentMagnitude
            : float2(0.0, 0.0);

        return float4(
            direction * 0.5 + 0.5,
            saturate(tangentMagnitude * 0.5),
            1.0
        );
    }

    return float4(
        0.0,
        0.0,
        0.0,
        1.0
    );
}


/*
    Render-path / UV diagnostic.
*/
float rainUVVisibilityDiagnostic(PS_IN pin)
{
    const float2 centerUV = float2(0.5, 0.535);
    const float radiusUV = 0.025;

    float distanceToCenter =
        length(pin.Tex - centerUV);

    return 1.0
        - smoothstep(
            radiusUV * 0.70,
            radiusUV,
            distanceToCenter
        );
}


float4 main(PS_IN pin)
{
    if (gRainDebug == 3)
    {
        return float4(
            1.0,
            0.0,
            0.0,
            1.0
        );
    }

    if (gRainDebug == 4)
    {
        /*
            UV coverage diagnostic:
            - red/green = actual mesh UV
            - white vertical line = U 0.5
            - white horizontal line = V 0.535
            - blue tint = expected visor V band 0.37..0.70

            Alpha is forced to 1.
        */
        float u = saturate(pin.Tex.x);
        float v = saturate(pin.Tex.y);

        float uLine =
            1.0
            - smoothstep(
                0.006,
                0.010,
                abs(u - 0.5)
            );

        float vLine =
            1.0
            - smoothstep(
                0.006,
                0.010,
                abs(v - 0.535)
            );

        float visorVBand =
            smoothstep(0.37, 0.39, v)
            * (1.0 - smoothstep(0.68, 0.70, v));

        float cross = max(uLine, vLine);

        float3 uvColor =
            float3(
                u,
                saturate((v - 0.37) / 0.33),
                0.0
            );

        uvColor =
            lerp(
                uvColor,
                float3(0.0, 0.20, 1.0),
                0.35 * visorVBand
            );

        uvColor =
            lerp(
                uvColor,
                float3(1.0, 1.0, 1.0),
                cross
            );

        return float4(
            uvColor,
            1.0
        );
    }

    if (gRainDebug > 0)
    {
        return rainDebugOutput(pin);
    }

    float large =
        rainDropLayer(
            pin,
            gRainTime,
            18.0,
            1.0,
            float2(0.0, 0.0),
            0.0
        );

    float small =
        rainDropLayer(
            pin,
            gRainTime,
            39.0,
            1.73,
            float2(13.7, 13.7),
            13.7
        );

    float mask =
        large * 0.90
        + small * 0.32;

    mask =
        saturate(mask);

    mask *=
        gRainAmount;

    mask *=
        gRainDensity;

    mask =
        saturate(mask);

    return float4(
        0.82,
        0.90,
        1.0,
        mask * 0.35
    );
}