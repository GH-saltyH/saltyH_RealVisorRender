SamplerState samPointRain
{
    Filter = MIN_MAG_MIP_POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
};


#ifdef RAIN_GPU_STATE_PASS

/*
    Stage 1 persistent GPU state validation.

    One ExtraCanvas texel represents one droplet:
        R = position X
        G = position Y
        B = velocity X
        A = velocity Y

    The Lua side ping-pongs two persistent ExtraCanvas resources.
    This pass only validates that state written in the previous frame
    can be read, integrated and written into the other canvas.
*/

float rainStateHash(float n)
{
    return frac(
        sin(n * 127.1 + 311.7) * 43758.5453
    );
}


float4 rainStateMain(PS_IN pin)
{
    float count =
        max(
            gRainStateCount,
            1.0
        );

    float index =
        min(
            floor(pin.Tex.x * count),
            count - 1.0
        );

    float2 stateUV =
        float2(
            (index + 0.5) / count,
            0.5
        );

    if (gRainStateInit > 0.5)
    {
        float seed =
            index + 1.0;

        float2 position =
            float2(
                rainStateHash(seed + 11.0),
                rainStateHash(seed + 47.0)
            );

        float2 velocity =
            (
                float2(
                    rainStateHash(seed + 83.0),
                    rainStateHash(seed + 131.0)
                )
                * 2.0
                - 1.0
            )
            * 0.006;

        return float4(
            position,
            velocity
        );
    }

    float4 state =
        txRainState.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

    float2 position =
        state.rg;

    float2 velocity =
        state.ba;

    float dt =
        max(
            gRainStateDeltaTime,
            0.0
        );

    /*
        Minimal stateful integration:
            v += F * dt
            drag
            clamp speed
            p += v * dt

        This is deliberately independent from the final RainFX
        adhesion/normal/merge model. It exists only to prove
        persistence and A/B ownership first.
    */
    velocity +=
        gRainStateForce
        * dt;

    velocity *=
        exp(
            -max(gRainStateDrag, 0.0)
            * dt
        );

    float speed =
        length(velocity);

    if (
        speed
        > gRainStateMaxSpeed
    )
    {
        velocity =
            velocity
            / max(speed, 0.000001)
            * gRainStateMaxSpeed;
    }

    position +=
        velocity
        * dt;

    position =
        frac(position);

    return float4(
        position,
        velocity
    );
}



float4 main(PS_IN pin)
{
    return rainStateMain(pin);
}




#else

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
        Object -> World

    so it is in the same coordinate system as the acceleration force.
*/

float3 rainSurfaceNormalObject_nonSaturate(float2 uv)
{
    float3 encoded =
        txRainSurfaceNormal.SampleLevel(
            samLinearSimple,
            uv,
            0.0
        ).rgb;

    float3 decoded =
        encoded * 2.0 - 1.0;

    return normalize(decoded);
}


float3 rainSurfaceNormalObject(float2 uv)
{
    float3 encoded =
        txRainSurfaceNormal.SampleLevel(
            samLinearSimple,
            // saturate(uv), -- removed
            uv,
            0.0
        ).rgb;

    float3 decoded =
        encoded * 2.0 - 1.0;

    return normalize(decoded);
}


float3 rainSurfaceNormalWorld(float2 uv)
{
    float3 normalObject =
        rainSurfaceNormalObject(uv);

    float3 normalWorld =
        mul(
            normalObject,
            (float3x3)gRainObjectToWorld
        );

    return normalize(normalWorld);
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
void rainSurfaceBasisWorld(
    PS_IN pin,
    out float3 tangentUWorld,
    out float3 tangentVWorld
)
{
    float3 dPosDx = ddx(pin.PosL);
    float3 dPosDy = ddy(pin.PosL);

    float2 dUvDx = ddx(pin.Tex);
    float2 dUvDy = ddy(pin.Tex);

    float determinant =
        dUvDx.x * dUvDy.y
        - dUvDx.y * dUvDy.x;

    if (abs(determinant) < 0.000001)
    {
        float3 fallbackNormal =
            rainSurfaceNormalWorld(pin.Tex);

        float3 fallbackWorldUp =
            float3(
                0.0,
                1.0,
                0.0
            );

        float3 fallbackWorldSide =
            float3(
                1.0,
                0.0,
                0.0
            );

        float3 fallbackU =
            normalize(
                cross(
                    fallbackWorldUp,
                    fallbackNormal
                )
            );

        if (length(fallbackU) < 0.000001)
        {
            fallbackU =
                normalize(
                    cross(
                        fallbackWorldSide,
                        fallbackNormal
                    )
                );
        }

        float3 fallbackV =
            normalize(
                cross(
                    fallbackNormal,
                    fallbackU
                )
            );

        tangentUWorld = fallbackU;
        tangentVWorld = fallbackV;
        return;
    }

    /*
        Standard UV-derivative reconstruction:
            dP/du = (dPdx * dVdy - dPdy * dVdx) / det
            dP/dv = (-dPdx * dUdy + dPdy * dUdx) / det

        pin.PosL is object-space mesh position, so the resulting
        tangents are converted to world space exactly like the normal.
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

    tangentUWorld =
        normalize(
            mul(
                tangentUObject,
                (float3x3)gRainObjectToWorld
            )
        );

    tangentVWorld =
        normalize(
            mul(
                tangentVObject,
                (float3x3)gRainObjectToWorld
            )
        );
}


/*
    Project a force into the ACTUAL UV tangent frame.

    U is mirrored at the final UV-output stage to preserve the existing
    tested visor left/right orientation. The normal itself is never
    negated or modified.
*/
float2 rainProjectForceToUVWorld(
    float3 forceWorld,
    float3 normalWorld,
    float3 baseTangentUWorld,
    float3 baseTangentVWorld,
    float patternScale
)
{
    /*
        Candidate-specific normal correction contains no ddx/ddy.
        The force and normal are both in WORLD space, while the UV
        tangent frame comes from the actual rendered mesh.
    */
    float3 tangentU =
        normalize(
            baseTangentUWorld
            - normalWorld * dot(
                baseTangentUWorld,
                normalWorld
            )
        );

    float3 tangentV =
        normalize(
            baseTangentVWorld
            - normalWorld * dot(
                baseTangentVWorld,
                normalWorld
            )
        );

    if (
        dot(
            cross(
                normalWorld,
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
            -dot(forceWorld, tangentU),
            dot(forceWorld, tangentV)
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
        rainSurfaceNormalWorld(spawnUV);

    float3 baseTangentU;
    float3 baseTangentV;

    rainSurfaceBasisWorld(
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
        rainProjectForceToUVWorld(
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
    /*
        A procedural droplet is a source object, not a property of the
        fragment currently being rendered.

        The previous implementation evaluated the force normal from pin.Tex.
        On a curved visor that made one droplet receive a different direction
        at every fragment around it. The result looked like a clock hand:
        the endpoint rotated around the origin instead of translating.

        Force/adhesion are now evaluated at the candidate's spawn UV and
        remain constant for that candidate during its procedural trajectory.
    */

    float2 proceduralUV =
        pin.Tex * patternScale
        + patternOffset;

    float2 grid =
        proceduralUV * cellScale;

    float2 baseCell =
        floor(grid);

    float result = 0.0;

    /*
        Keep the actual mesh-derived UV basis. The candidate normal is sampled
        at the candidate spawn location; this removes the per-fragment normal
        variation from the droplet trajectory.
    */
    float3 baseTangentU;
    float3 baseTangentV;

    rainSurfaceBasisWorld(
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

            float dropRadius01 =
                saturate(
                    (dropSize - 0.032)
                    / (0.115 - 0.032)
                );

            float massFactor =
                lerp(
                    1.0,
                    9.0,
                    dropRadius01 * dropRadius01
                );

            float adhesionBase =
                lerp(
                    gRainAdhesionMin,
                    gRainAdhesionMax,
                    rndMotion.x
                );

            float adhesion =
                adhesionBase
                / sqrt(massFactor);

            float2 spawnPos =
                cell
                + float2(
                    0.08 + rndPos.x * 0.84,
                    0.08 + rndPos.y * 0.84
                );

            /*
                Convert the procedural source coordinate back to mesh UV.
                This makes the normal lookup belong to the droplet itself.
            */
            float2 spawnProceduralUV =
                spawnPos
                / max(
                    cellScale,
                    0.000001
                );

            float2 spawnUV =
                rainPatternToMeshUV(
                    spawnProceduralUV,
                    patternScale,
                    patternOffset
                );

            float3 surfaceNormal =
                rainSurfaceNormalWorld(
                    spawnUV
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
                rainProjectForceToUVWorld(
                    effectiveForce,
                    surfaceNormal,
                    baseTangentU,
                    baseTangentV,
                    1.0
                );

            float forceMagnitude =
                length(tangentForce);

            float birthDelay =
                rndMotion.y * 1.5;

            float age =
                time
                - birthDelay;

            if (age < 0.0)
                continue;

            float lifeVisibility =
                smoothstep(
                    0.0,
                    0.20,
                    age
                );

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

            /*
                Travel distance is defined in MESH-UV space.
                Convert it to procedural grid space exactly once for rendering.

                This keeps the physical speed independent of the procedural
                cell density (cellScale) and avoids multiplying the speed
                domain by patternScale twice.
            */
            float travelDistanceUV =
                rainDropTravelDistance(
                    excessForce,
                    age
                );

            float travelDistanceGrid =
                travelDistanceUV
                * patternScale
                * cellScale;

            /*
                Candidate lookup is limited to the current cell and its
                immediate 8 neighbors. Keep the moving droplet inside that
                search envelope; otherwise the droplet itself disappears
                while the trail near its spawn cell remains visible.
            */
            travelDistanceGrid =
                min(
                    travelDistanceGrid,
                    gRainFlowMax
                );

            float2 movement =
                forceMagnitude > 0.000001
                ? normalize(tangentForce)
                    * travelDistanceGrid
                : float2(0.0, 0.0);

            float2 dropPos =
                spawnPos
                + movement;

            float2 delta =
                grid
                - dropPos;

            float distanceToDrop =
                length(delta);

            float drop =
                smoothstep(
                    dropSize,
                    dropSize * 0.30,
                    distanceToDrop
                );

            float dropOpacity =
                lerp(
                    0.55,
                    1.0,
                    dropRadius01
                );

            drop *= dropOpacity;

            /*
                The trail is the actual segment between spawnPos and dropPos.
                No independent trail length is introduced.
            */
            float movementLength =
                length(movement);

            float trail =
                0.0;

            if (
                movementLength > dropSize * 1.25
                && dynamic01 > 0.50
            )
            {
                float2 movementDir =
                    movement
                    / movementLength;

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

                float trailWidth =
                    max(
                        dropSize
                        * lerp(
                            0.14,
                            0.26,
                            dynamic01
                        ),
                        0.0015
                    );

                float trailMask =
                    smoothstep(
                        trailWidth,
                        0.0,
                        trailSide
                    );

                float trailHead =
                    smoothstep(
                        0.0,
                        trailWidth,
                        trailAlong
                    );

                float trailTail =
                    1.0
                    - smoothstep(
                        movementLength
                        - trailWidth,
                        movementLength,
                        trailAlong
                    );

                trail =
                    trailMask
                    * trailHead
                    * trailTail;

                trail *=
                    smoothstep(
                        0.35,
                        0.75,
                        dynamic01
                    );

                trail *=
                    lerp(
                        0.03,
                        0.15,
                        dynamic01
                    );
            }

            result =
                max(
                    result,
                    drop + trail
                );
        }
    }

    return saturate(result);
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




float4 rainDebugOutput(
    PS_IN pin
)
{
    float3 normalTexture = 
    txRainSurfaceNormal.SampleLevel(
        samLinearSimple,
        pin.Tex,
        0.0
    ).rgb;
    
    float3 acceleration =
        gRainAcceleration
        * gRainForceScale;

    float3 gravityForce =
        float3(
            0.0,
            -gRainGravity,
            0.0
        );

    float3 effectiveForce =
        gravityForce
        + gRainAcceleration * gRainForceScale;

    float accelerationMagnitude =
        length(acceleration);

    float3 encodedNormal =
        txRainSurfaceNormal.SampleLevel(
            samLinearSimple,
            saturate(pin.Tex),
            0.0
        ).rgb;

    float3 normalObject =
        rainSurfaceNormalObject(
            pin.Tex
        );

    float3 normalWorld =
        rainSurfaceNormalWorld(
            pin.Tex
        );

    float3 baseTangentU;
    float3 baseTangentV;

    rainSurfaceBasisWorld(
        pin,
        baseTangentU,
        baseTangentV
    );

    float2 tangentForce =
        rainProjectForceToUVWorld(
            effectiveForce,
            normalWorld,
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

    /*
        Texture diagnostic:
        5 = RAW sampled normal texture RGB.
        This deliberately does not decode or transform the value. If this
        is flat, the problem is texture binding/content/UV rather than
        world-space normal conversion.
    */
    if (gRainDebug == 5)
    {
        return float4(normalTexture, 1.0);
    }

    /*
        7 = decoded OBJECT-SPACE normal RGB.
        This is the value used by RainFX after decoding the texture.
    */
    if (gRainDebug == 7)
    {
        float3 normalObjectNoneSaturate = rainSurfaceNormalObject_nonSaturate(pin.Tex);

        return float4(
            normalObjectNoneSaturate * 0.5 + 0.5,
            1.0
        );
    }

    if (gRainDebug == 8)
    {
        float3 decoded =
            normalTexture * 2.0 - 1.0;

        return float4(
            decoded * 0.5 + 0.5,
            1.0
        );
    }

    if (gRainDebug == 9)
    {
        float3 decoded =
            normalTexture * 2.0 - 1.0;

        float len = length(decoded);

        return float4(
            saturate(len).xxx,
            1.0
        );
    }

    if (gRainDebug == 10)
    {
        float2 uv = pin.Tex;

        return float4(
            frac(uv),
            0.0,
            1.0
        );
    }

    if (gRainDebug == 11)
    {
        float2 uv = pin.Tex;
        float2 clampedUV = saturate(uv);

        float2 difference = abs(uv - clampedUV);

        return float4(
            saturate(difference * 4.0),
            0.0,
            1.0
        );
    }

    if (gRainDebug == 12)
    {
        float2 uv = pin.Tex;
        float2 clamped = saturate(uv);

        return float4(
            frac(uv),
            0.0,
            1.0
        );
    }

    if (gRainDebug == 13)
    {
        float2 uv = pin.Tex;
        float2 clamped = saturate(uv);

        float2 diff = uv - clamped;

        return float4(
            saturate(abs(diff)),
            0.0,
            1.0
        );
    }

    float2 uv = pin.Tex;

    float2 uvClamped = saturate(uv);

    float3 a =
        txRainSurfaceNormal.SampleLevel(
            samLinearSimple,
            uv,
            0.0
        ).rgb;

    float3 b =
        txRainSurfaceNormal.SampleLevel(
            samLinearSimple,
            uvClamped,
            0.0
        ).rgb;
    
        if (gRainDebug == 14)
    {
        return float4(abs(a - b), 1.0);
    }
    
    if (gRainDebug == 15)
    {
        float3 normalWorld =
            rainSurfaceNormalWorld(pin.Tex);

        return float4(
            normalWorld * 0.5 + 0.5,
            1.0
        );
    }


    /*
        17 = reference adhesion / projected force.
        This is intentionally a global diagnostic because individual
        procedural droplet sizes are not persistent render targets.
    */
    if (gRainDebug == 17)
    {
        float adhesionReference =
            lerp(
                gRainAdhesionMin,
                gRainAdhesionMax,
                0.5
            );

        float excess =
            max(
                tangentMagnitude - adhesionReference,
                0.0
            );

        return float4(
            saturate(
                adhesionReference
                / max(gRainAdhesionMax, 0.001)
            ),
            saturate(
                tangentMagnitude
                / max(gRainAdhesionMax, 0.001)
            ),
            saturate(
                excess
                / max(adhesionReference, 0.001)
            ),
            1.0
        );
    }

    if (gRainDebug == 16)
    {

    float forceLength =
        length(tangentForce);

    float2 forceDirection =
        forceLength > 0.000001
        ? tangentForce / forceLength
        : float2(0.0, 0.0);

    return float4(
        forceDirection * 0.5 + 0.5,
        saturate(forceLength),
        0.3
        );
    }   
    
    /*
        Local movement-direction diagnostic.
        Red/green encode the projected UV direction, blue encodes its strength.
        The force, normal and tangent frame are evaluated in WORLD space.
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


float rainPersistentDropLayer(PS_IN pin)
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

        float2 dropPosition = state.rg;
        float2 delta = pin.Tex - dropPosition;

        /*
            Stage 2 diagnostic:
            every state texel is rendered as an independent droplet.
            Radius is deterministic per state index and intentionally
            independent from the current fragment.
        */
        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        float radius01 = saturate(
            (meta.r - 0.032) / (0.115 - 0.032)
        );

        /*
            Stage 2 visibility diagnostic:
            use deliberately oversized markers first. This test is not
            intended to look like a physical raindrop yet; it proves that
            persistent state UV positions can be consumed by the visor mesh.
        */
        float radius = lerp(0.018, 0.032, radius01);

        float distanceToDrop = length(delta);
        float drop = 1.0 - smoothstep(
            radius * 0.25,
            radius,
            distanceToDrop
        );

        result = max(result, drop);
    }

    return saturate(result);
}


float4 rainStateDebugOutput(
    PS_IN pin
)
{
    float count =
        max(
            gRainStateCount,
            1.0
        );

    /*
        Map visor U across a subset of state texels so the debug output
        visibly changes when persistent positions/velocities evolve.
    */
    float stateIndex =
        floor(
            saturate(pin.Tex.x)
            * min(count - 1.0, 31.0)
        );

    float2 stateUV =
        float2(
            (stateIndex + 0.5) / count,
            0.5
        );

    float4 state =
        txRainState.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

    return float4(
        state.r,
        state.g,
        saturate(length(state.ba) * 8.0),
        1.0
    );
}



/*
    Persistent velocity-vector diagnostic.

    Debug 19 proves that persistent positions are independent.
    Debug 20 visualizes the VELOCITY stored in state.ba directly.

    The line direction is the normalized stored velocity.
    The line length is proportional to stored speed / max speed.
    No surface normal, curvature, force projection or procedural motion
    is involved in this diagnostic.
*/
/*
    Debug 21:
    Render only the persistent state position.

    Unlike Debug 20 this deliberately does not visualize velocity.
    The purpose is to verify that the RG position written by the
    persistent physics pass is actually changing over time.

    No normal, force, trail or velocity information is used here.
*/
float4 rainPersistentPositionDebugOutput(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 resultColor = float3(1.0, 1.0, 1.0);

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

        float2 statePosition = state.rg;

        float2 dropPosition = float2(
            statePosition.x,
            lerp(-0.579, -0.362, statePosition.y)
        );

        float distanceToDrop = length(
            pin.Tex - dropPosition
        );

        float radius01 = rainHash(
            float2(stateIndex, 271.0)
        );

        float markerRadius = lerp(
            0.0035,
            0.0070,
            radius01
        );

        float mask = 1.0 - smoothstep(
            markerRadius,
            markerRadius * 1.8,
            distanceToDrop
        );

        if (mask > result)
        {
            result = mask;

            float r = rainHash(
                float2(stateIndex, 401.0)
            );
            float g = rainHash(
                float2(stateIndex, 509.0)
            );
            float b = rainHash(
                float2(stateIndex, 617.0)
            );

            resultColor = float3(
                0.35 + r * 0.65,
                0.35 + g * 0.65,
                0.35 + b * 0.65
            );
        }
    }

    return float4(
        resultColor,
        saturate(result)
    );
}

/*
    Debug 22: raw persistent-state telemetry.
    R = normalized X, G = normalized Y, B = normalized speed.
*/
float4 rainPersistentRawStateDebugOutput(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 resultColor = float3(0.0, 0.0, 0.0);

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

        float2 statePosition = state.rg;
        float speed01 = saturate(
            length(state.ba) / max(gRainStateMaxSpeed, 0.000001)
        );

        float2 dropPosition = float2(
            statePosition.x,
            lerp(-0.579, -0.362, statePosition.y)
        );

        float markerRadius = lerp(
            0.0040,
            0.0065,
            rainHash(float2(stateIndex, 731.0))
        );

        float distanceToDrop = length(
            pin.Tex - dropPosition
        );

        float mask = 1.0 - smoothstep(
            markerRadius,
            markerRadius * 1.8,
            distanceToDrop
        );

        if (mask > result)
        {
            result = mask;
            resultColor = float3(
                statePosition.x,
                statePosition.y,
                speed01
            );
        }
    }

    return float4(resultColor, saturate(result));
}

/*
    Debug 23: current position plus a predicted endpoint using only
    current velocity. The second marker is NOT historical trajectory.
*/
/*
    Debug 25: actual accumulated persistent displacement.

    The Lua side captures a GPU origin snapshot when entering Debug 25.
    The state continues to integrate normally after the snapshot.

    White  = current position
    Green  = captured origin
    Orange = amplified displacement path

    Because persistent positions currently wrap with frac(), the delta is
    unwrapped to the shortest periodic displacement before visualization.
*/
float4 rainPersistentMeasuredGridDebugOutput(PS_IN pin)
{
    const float count = 9.0;
    const float visualScale = max(gRainStateDebugDisplacementScale, 1.0);
    float result = 0.0;
    float3 resultColor = float3(1.0, 1.0, 1.0);

    [loop]
    for (int i = 0; i < 9; ++i)
    {
        float2 stateUV = float2((float(i) + 0.5) / count, 0.5);
        float4 state = txRainState.SampleLevel(samPointRain, stateUV, 0.0);
        float4 meta = txRainStateMeta.SampleLevel(samPointRain, stateUV, 0.0);
        float4 originState = txRainStateOrigin.SampleLevel(samPointRain, stateUV, 0.0);

        float2 current = state.rg;
        float2 origin = originState.rg;
        float2 delta = rainShortestWrappedDelta(current, origin);
        float2 currentPosition = float2(current.x, lerp(gRainStateMeshVMin, gRainStateMeshVMax, current.y));
        float2 originPosition = float2(origin.x, lerp(gRainStateMeshVMin, gRainStateMeshVMax, origin.y));
        float2 deltaMesh = float2(delta.x, delta.y * (gRainStateMeshVMax - gRainStateMeshVMin));
        float2 amplifiedEnd = originPosition + deltaMesh * visualScale;

        float radius = meta.r;
        float radius01 = saturate((radius - 0.032) / (0.115 - 0.032));
        float radiusVisual = lerp(0.0045, 0.012, radius01);
        float currentMask = 1.0 - smoothstep(radiusVisual, radiusVisual * 1.25, length(pin.Tex - currentPosition));
        float originMask = 1.0 - smoothstep(0.0025, 0.0045, length(pin.Tex - originPosition));

        float2 lineVector = amplifiedEnd - originPosition;
        float lineLengthSq = dot(lineVector, lineVector);
        float2 pointVector = pin.Tex - originPosition;
        float lineT = saturate(dot(pointVector, lineVector) / max(lineLengthSq, 0.000001));
        float2 closest = originPosition + lineVector * lineT;
        float lineDistance = length(pin.Tex - closest);
        float lineMask = 1.0 - smoothstep(0.0012, 0.0024, lineDistance);

        if (originMask > result) { result = originMask; resultColor = float3(0.05, 1.0, 0.15); }
        if (lineMask > result) { result = lineMask; resultColor = float3(1.0, 0.35, 0.05); }
        if (currentMask > result) { result = currentMask; resultColor = lerp(float3(0.2, 0.7, 1.0), float3(1.0, 0.75, 0.1), radius01); }
    }

    return float4(resultColor, saturate(result));
}


/*
    Debug 26: compare persistent velocity with measured displacement rate.

    Lua periodically snapshots the current persistent position into
    txRainStateOrigin. The render pass then measures:

        measuredVelocity = shortestWrappedDelta(P, Psample) / sampleInterval

    Cyan   = velocity stored in persistent state
    Orange = velocity measured from actual position displacement
    White  = current position

    Both vectors use the same visualization scale. This diagnostic does not
    modify physics or persistent state.
*/
float2 rainShortestWrappedDelta(float2 current, float2 previous)
{
    float2 delta = current - previous;

    if (delta.x > 0.5) delta.x -= 1.0;
    if (delta.x < -0.5) delta.x += 1.0;
    if (delta.y > 0.5) delta.y -= 1.0;
    if (delta.y < -0.5) delta.y += 1.0;

    return delta;
}

float4 rainPersistentVelocityDeltaDebugOutput(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 resultColor = float3(1.0, 1.0, 1.0);
    float visualScale = max(gRainStateDebugVelocityScale, 1.0);
    float sampleInterval = max(gRainStateDebugSampleInterval, 0.01);

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
            samPointRain, stateUV, 0.0
        );

        float2 current = state.rg;
        float2 velocity = state.ba;
        float2 previous = txRainStateOrigin.SampleLevel(
            samPointRain, stateUV, 0.0
        ).rg;

        float2 delta = rainShortestWrappedDelta(current, previous);
        float2 measuredVelocity = delta / sampleInterval;

        float2 currentPosition = float2(
            current.x,
            lerp(-0.579, -0.362, current.y)
        );

        // Keep the diagnostic vectors in the same normalized state space.
        // The mesh V range is applied only when projecting them to pin.Tex.
        float2 velocityMesh = float2(
            velocity.x,
            velocity.y * (-0.362 + 0.579)
        );

        float2 measuredMesh = float2(
            measuredVelocity.x,
            measuredVelocity.y * (-0.362 + 0.579)
        );

        float2 velocityEnd =
            currentPosition + velocityMesh * visualScale;

        float2 measuredEnd =
            currentPosition + measuredMesh * visualScale;

        float2 velocityVector = velocityEnd - currentPosition;
        float velocityLengthSq = dot(velocityVector, velocityVector);
        float2 measuredVector = measuredEnd - currentPosition;
        float measuredLengthSq = dot(measuredVector, measuredVector);

        float2 toPoint = pin.Tex - currentPosition;

        float velocityT = saturate(
            dot(toPoint, velocityVector)
            / max(velocityLengthSq, 0.000001)
        );
        float2 velocityClosest =
            currentPosition + velocityVector * velocityT;
        float velocityDistance =
            length(pin.Tex - velocityClosest);

        float measuredT = saturate(
            dot(toPoint, measuredVector)
            / max(measuredLengthSq, 0.000001)
        );
        float2 measuredClosest =
            currentPosition + measuredVector * measuredT;
        float measuredDistance =
            length(pin.Tex - measuredClosest);

        float velocityMask =
            1.0 - smoothstep(
                0.0015,
                0.0030,
                velocityDistance
            );

        float measuredMask =
            1.0 - smoothstep(
                0.0015,
                0.0030,
                measuredDistance
            );

        float pointMask =
            1.0 - smoothstep(
                0.003,
                0.006,
                length(pin.Tex - currentPosition)
            );

        if (velocityMask > result)
        {
            result = velocityMask;
            resultColor = float3(0.05, 0.85, 1.0);
        }

        if (measuredMask > result)
        {
            result = measuredMask;
            resultColor = float3(1.0, 0.35, 0.05);
        }

        if (pointMask > result)
        {
            result = pointMask;
            resultColor = float3(1.0, 1.0, 1.0);
        }
    }

    return float4(resultColor, saturate(result));
}


float4 rainPersistentMotionScaleDebugOutput(PS_IN pin){float c=max(gRainStateCount,1.0),r=0.0;float3 col=float3(0,1,1);[loop]for(int i=0;i<256;++i){if((float)i>=c)break;float2 uv=float2(((float)i+0.5)/c,0.5);float4 st=txRainState.SampleLevel(samPointRain,uv,0.0);float2 p=st.rg,v=st.ba;float2 p1=frac(p+v),p10=frac(p+v*10.0),p50=frac(p+v*50.0);float2 a=float2(p.x,lerp(-0.579,-0.362,p.y));float2 b=float2(p1.x,lerp(-0.579,-0.362,p1.y));float2 d=float2(p10.x,lerp(-0.579,-0.362,p10.y));float2 e=float2(p50.x,lerp(-0.579,-0.362,p50.y));float m=1-smoothstep(.003,.006,length(pin.Tex-a));float m1=1-smoothstep(.0025,.005,length(pin.Tex-b));float m10=1-smoothstep(.0025,.005,length(pin.Tex-d));float m50=1-smoothstep(.0025,.005,length(pin.Tex-e));if(m>r){r=m;col=float3(1,1,1);}if(m1>r){r=m1;col=float3(1,.35,.05);}if(m10>r){r=m10;col=float3(1,.85,.05);}if(m50>r){r=m50;col=float3(.05,.9,1);}}return float4(col,saturate(r));}

float4 rainPersistentPredictedMotionDebugOutput(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 resultColor = float3(0.0, 1.0, 1.0);
    const float diagnosticTime = 1.0;

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

        float2 p = state.rg;
        float2 v = state.ba;

        float2 currentPosition = float2(
            p.x,
            lerp(-0.579, -0.362, p.y)
        );

        float2 predictedStatePosition = frac(
            p + v * diagnosticTime
        );

        float2 predictedPosition = float2(
            predictedStatePosition.x,
            lerp(
                -0.579,
                -0.362,
                predictedStatePosition.y
            )
        );

        float currentMask = 1.0 - smoothstep(
            0.003,
            0.006,
            length(pin.Tex - currentPosition)
        );

        float predictedMask = 1.0 - smoothstep(
            0.0025,
            0.0050,
            length(pin.Tex - predictedPosition)
        );

        if (currentMask > result)
        {
            result = currentMask;
            resultColor = float3(1.0, 1.0, 1.0);
        }

        if (predictedMask > result)
        {
            result = predictedMask;
            resultColor = float3(1.0, 0.35, 0.05);
        }
    }

    return float4(resultColor, saturate(result));
}

float4 rainPersistentVelocityDebugOutput(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 resultColor = float3(0.0, 1.0, 1.0);

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

        float2 statePosition = state.rg;
        float2 velocity = state.ba;

        float2 dropPosition = float2(
            statePosition.x,
            lerp(-0.579, -0.362, statePosition.y)
        );

        float speed = length(velocity);
        float speed01 = saturate(
            speed / max(gRainStateMaxSpeed, 0.000001)
        );

        if (speed <= 0.000001)
        {
            float distanceToDrop = length(
                pin.Tex - dropPosition
            );

            float dotMask = 1.0 - smoothstep(
                0.003,
                0.006,
                distanceToDrop
            );

            if (dotMask > result)
            {
                result = dotMask;
                resultColor = float3(0.15, 0.15, 1.0);
            }

            continue;
        }

        float2 direction = velocity / speed;

        /*
            State Y is mapped to the measured visor pin.Tex Y range.
            Apply the same scale to the velocity vector so its direction
            remains consistent with the rendered state position domain.
        */
        float2 directionMesh = normalize(
            float2(
                direction.x,
                direction.y * (-0.362 + 0.579)
            )
        );

        float lineLength = 0.045 * speed01;

        float2 lineStart = dropPosition;
        float2 lineEnd = lineStart + directionMesh * lineLength;
        float2 lineVector = lineEnd - lineStart;

        float lineVectorLengthSq = dot(
            lineVector,
            lineVector
        );

        float2 pointVector = pin.Tex - lineStart;

        float lineT = saturate(
            dot(pointVector, lineVector)
            / max(lineVectorLengthSq, 0.000001)
        );

        float2 closestPoint =
            lineStart + lineVector * lineT;

        float distanceToLine = length(
            pin.Tex - closestPoint
        );

        float lineWidth = lerp(
            0.0015,
            0.0030,
            speed01
        );

        float lineMask = 1.0 - smoothstep(
            lineWidth,
            lineWidth * 2.0,
            distanceToLine
        );

        float distanceToDrop = length(
            pin.Tex - dropPosition
        );

        float dropMask = 1.0 - smoothstep(
            0.003,
            0.006,
            distanceToDrop
        );

        float mask = max(lineMask, dropMask);

        if (mask > result)
        {
            result = mask;

            /*
                R/G = signed direction encoded to 0..1.
                B = normalized velocity magnitude.
            */
            resultColor = float3(
                direction.x * 0.5 + 0.5,
                direction.y * 0.5 + 0.5,
                speed01
            );
        }
    }

    return float4(
        resultColor,
        saturate(result)
    );
}

float4 rainPersistentAdhesionDebugOutput(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 resultColor = float3(1.0, 1.0, 1.0);

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
            samPointRain, stateUV, 0.0
        );
        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain, stateUV, 0.0
        );

        float2 p = state.rg;
        float radius = meta.r;
        float mass = max(meta.g, 1.0);

        float2 dropPosition = float2(
            p.x,
            lerp(-0.579, -0.362, p.y)
        );

        float3 normalWorld = rainSurfaceNormalWorld(p);
        float3 tangentUWorld;
        float3 tangentVWorld;
        rainSurfaceBasisWorld(pin, tangentUWorld, tangentVWorld);

        float3 forceWorld =
            float3(0.0, -gRainGravity, 0.0)
            + gRainAcceleration * gRainForceScale;

        float2 tangentForce = rainProjectForceToUVWorld(
            forceWorld,
            normalWorld,
            tangentUWorld,
            tangentVWorld,
            1.0
        );

        float forceMagnitude = length(tangentForce);
        float adhesionBase = lerp(
            gRainAdhesionMin,
            gRainAdhesionMax,
            rainHash(float2(stateIndex, 211.0))
        );
        float adhesion = adhesionBase / sqrt(mass);

        float ratio =
            forceMagnitude / max(adhesion, 0.000001);

        // Green: safely attached.
        // Yellow: approaching the adhesion threshold.
        // Red: threshold exceeded and flow is active.
        float3 color;
        if (ratio < 0.75)
            color = float3(0.05, 1.0, 0.20);
        else if (ratio < 1.0)
            color = float3(1.0, 0.85, 0.05);
        else
            color = float3(1.0, 0.08, 0.05);

        float radius01 = saturate(
            (radius - 0.032) / (0.115 - 0.032)
        );
        float markerRadius = lerp(0.004, 0.010, radius01);

        float distanceToDrop = length(pin.Tex - dropPosition);
        float mask = 1.0 - smoothstep(
            markerRadius * 0.35,
            markerRadius,
            distanceToDrop
        );

        if (mask > result)
        {
            result = mask;
            resultColor = color;
        }
    }

    return float4(resultColor, saturate(result));
}


float4 rainPersistentSurfaceForceDebugOutput(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 resultColor = float3(1.0, 1.0, 1.0);

    float3 surfaceNormal = rainSurfaceNormalWorld(pin.Tex);
    float3 tangentU;
    float3 tangentV;
    rainSurfaceBasisWorld(pin, tangentU, tangentV);

    float3 effectiveForce =
        float3(0.0, -gRainGravity, 0.0)
        + gRainAcceleration * gRainForceScale;

    float2 tangentForce = rainProjectForceToUVWorld(
        effectiveForce,
        surfaceNormal,
        tangentU,
        tangentV,
        1.0
    );

    float forceLength = length(tangentForce);
    float2 forceDirection =
        tangentForce / max(forceLength, 0.000001);

    // Debug only: convert the projected tangent force into a visible
    // direction on the actual rendered visor surface.
    float visualLength =
        0.025 * saturate(forceLength / 3.0);

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

        float2 p = state.rg;
        float2 dropPosition = float2(
            p.x,
            lerp(-0.579, -0.362, p.y)
        );

        float2 toPoint = pin.Tex - dropPosition;
        float pointMask = 1.0 - smoothstep(
            0.004,
            0.009,
            length(toPoint)
        );

        float2 endPosition =
            dropPosition
            + forceDirection * visualLength;

        float2 lineVector = endPosition - dropPosition;
        float lineLengthSq = dot(lineVector, lineVector);
        float lineT = saturate(
            dot(toPoint, lineVector)
            / max(lineLengthSq, 0.000001)
        );

        float2 closest =
            dropPosition + lineVector * lineT;

        float lineDistance =
            length(pin.Tex - closest);

        float lineMask = 1.0 - smoothstep(
            0.0012,
            0.0028,
            lineDistance
        );

        if (lineMask > result)
        {
            result = lineMask;
            resultColor = float3(1.0, 0.55, 0.05);
        }

        if (pointMask > result)
        {
            result = pointMask;
            resultColor = float3(0.05, 0.85, 1.0);
        }
    }

    return float4(resultColor, saturate(result));
}


float4 rainPersistentPhysicalDropDebugOutput(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 resultColor = float3(1.0, 1.0, 1.0);

    /*
        Debug 29:
        Render the persistent GPU state as actual drop-shaped markers.

        Position comes directly from the persistent state.
        Radius comes from persistent meta state.
        Velocity is only used for a short directional tail.

        This is intentionally still a diagnostic renderer:
        no merge, residue, edge death or final drop shading yet.
    */
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

        float2 p = state.rg;
        float2 velocity = state.ba;

        float2 dropPosition = float2(
            p.x,
            lerp(-0.579, -0.362, p.y)
        );

        float radius01 = saturate(
            (meta.r - 0.032) / (0.115 - 0.032)
        );

        float radius = lerp(
            0.0045,
            0.0095,
            radius01
        );

        /*
            Persistent state is normalized to [0, 1], while pin.Tex uses
            the actual visor mesh V range. Convert the measured distance
            back into the normalized state domain for a circular drop.
        */
        float2 delta = pin.Tex - dropPosition;
        delta.y /= max((-0.362 + 0.579), 0.000001);

        float normalizedDistance = length(delta);

        float dropMask = 1.0 - smoothstep(
            radius * 0.45,
            radius,
            normalizedDistance
        );

        float speed = length(velocity);
        float speed01 = saturate(
            speed / max(gRainStateMaxSpeed, 0.000001)
        );

        float2 direction =
            velocity / max(speed, 0.000001);

        float2 directionMesh = normalize(
            float2(
                direction.x,
                direction.y * (-0.362 + 0.579)
            )
        );

        float tailLength = 0.012 * speed01;

        float2 tailStart = dropPosition;
        float2 tailEnd =
            tailStart
            + directionMesh * tailLength;

        float2 lineVector =
            tailEnd - tailStart;

        float lineLengthSq =
            dot(lineVector, lineVector);

        float2 toPoint =
            pin.Tex - tailStart;

        float tailT =
            saturate(
                dot(toPoint, lineVector)
                / max(lineLengthSq, 0.000001)
            );

        float2 closest =
            tailStart + lineVector * tailT;

        float tailDistance =
            length(pin.Tex - closest);

        float tailWidth = lerp(
            0.0007,
            0.0018,
            speed01
        );

        float tailMask = 1.0 - smoothstep(
            tailWidth,
            tailWidth * 2.0,
            tailDistance
        );

        float mask =
            max(dropMask, tailMask);

        if (mask > result)
        {
            result = mask;
            resultColor = lerp(
                float3(1.0, 1.0, 1.0),
                float3(0.65, 0.90, 1.0),
                speed01
            );
        }
    }

    return float4(
        resultColor,
        saturate(result)
    );
}



float4 rainPersistentAirDragDebugOutput(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 resultColor = float3(0.0, 0.0, 0.0);

    /*
        Debug 31:
        Visualize the three force components at every persistent drop.

        Purple = gravity + vehicle acceleration.
        Cyan   = relative-air drag.
        White  = total force (base + air drag).

        The air velocity supplied by Lua is opposite vehicle world velocity.
        Drag magnitude is quadratic in air speed for this diagnostic:
            F_drag = airflow * |airflow| * scale

        This stage does NOT modify persistent physics.
    */
    float3 baseForce =
        float3(
            0.0,
            -gRainGravity,
            0.0
        )
        + gRainAcceleration * gRainForceScale;

    float airSpeed = length(gRainAirVelocityWorld);

    float3 airDragForce =
        gRainAirVelocityWorld
        * airSpeed
        * max(gRainAirDragScale, 0.0);

    float3 totalForce =
        baseForce
        + airDragForce;

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

        float4 state =
            txRainState.SampleLevel(
                samPointRain,
                stateUV,
                0.0
            );

        float4 meta =
            txRainStateMeta.SampleLevel(
                samPointRain,
                stateUV,
                0.0
            );

        float2 p = state.rg;

        float2 dropPosition = float2(
            p.x,
            lerp(
                gRainStateMeshVMin,
                gRainStateMeshVMax,
                p.y
            )
        );

        float2 localDelta =
            pin.Tex
            - dropPosition;

        localDelta.y /=
            max(
                gRainStateMeshVMax
                - gRainStateMeshVMin,
                0.000001
            );

        float radius01 = saturate(
            (meta.r - 0.032)
            / (0.115 - 0.032)
        );

        float markerRadius = lerp(
            0.005,
            0.014,
            radius01
        );

        float marker =
            1.0
            - smoothstep(
                markerRadius * 0.45,
                markerRadius,
                length(localDelta)
            );

        /*
            The normal/tangent reconstruction intentionally matches
            Debug 30 and the persistent physics convention.
        */
        float3 normalWorld =
            rainSurfaceNormalWorld(
                float2(
                    p.x,
                    lerp(
                        gRainStateMeshVMin,
                        gRainStateMeshVMax,
                        p.y
                    )
                )
            );

        float3 normalObject =
            normalize(
                mul(
                    normalWorld,
                    transpose(
                        (float3x3)gRainObjectToWorld
                    )
                )
            );

        float3 tangentUObject =
            float3(
                1.0,
                0.0,
                0.0
            );

        tangentUObject -=
            normalObject
            * dot(
                tangentUObject,
                normalObject
            );

        if (length(tangentUObject) < 0.0001)
        {
            tangentUObject =
                float3(
                    0.0,
                    0.0,
                    1.0
                );

            tangentUObject -=
                normalObject
                * dot(
                    tangentUObject,
                    normalObject
                );
        }

        tangentUObject =
            normalize(tangentUObject);

        float3 tangentVObject =
            normalize(
                cross(
                    normalObject,
                    tangentUObject
                )
            );

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

        float2 baseUVForce =
            float2(
                -dot(
                    baseForce,
                    tangentUWorld
                ),
                dot(
                    baseForce,
                    tangentVWorld
                )
            );

        float2 airUVForce =
            float2(
                -dot(
                    airDragForce,
                    tangentUWorld
                ),
                dot(
                    airDragForce,
                    tangentVWorld
                )
            );

        float2 totalUVForce =
            float2(
                -dot(
                    totalForce,
                    tangentUWorld
                ),
                dot(
                    totalForce,
                    tangentVWorld
                )
            );

        float baseLength =
            length(baseUVForce);

        float airLength =
            length(airUVForce);

        float totalLength =
            length(totalUVForce);

        float2 baseDirection =
            baseUVForce
            / max(
                baseLength,
                0.000001
            );

        float2 airDirection =
            airUVForce
            / max(
                airLength,
                0.000001
            );

        float2 totalDirection =
            totalUVForce
            / max(
                totalLength,
                0.000001
            );

        float vRange =
            max(
                gRainStateMeshVMax
                - gRainStateMeshVMin,
                0.000001
            );

        float baseVisualLength =
            0.018
            * saturate(
                baseLength / 3.0
            );

        float airVisualLength =
            0.018
            * saturate(
                airLength / 3.0
            );

        float totalVisualLength =
            0.018
            * saturate(
                totalLength / 3.0
            );

        float2 baseEnd =
            dropPosition
            + float2(
                baseDirection.x,
                baseDirection.y * vRange
            )
            * baseVisualLength;

        float2 airEnd =
            dropPosition
            + float2(
                airDirection.x,
                airDirection.y * vRange
            )
            * airVisualLength;

        float2 totalEnd =
            dropPosition
            + float2(
                totalDirection.x,
                totalDirection.y * vRange
            )
            * totalVisualLength;

        float2 baseLine =
            baseEnd
            - dropPosition;

        float2 airLine =
            airEnd
            - dropPosition;

        float2 totalLine =
            totalEnd
            - dropPosition;

        float2 fromDrop =
            pin.Tex
            - dropPosition;

        float baseT =
            saturate(
                dot(
                    fromDrop,
                    baseLine
                )
                / max(
                    dot(
                        baseLine,
                        baseLine
                    ),
                    0.000001
                )
            );

        float airT =
            saturate(
                dot(
                    fromDrop,
                    airLine
                )
                / max(
                    dot(
                        airLine,
                        airLine
                    ),
                    0.000001
                )
            );

        float totalT =
            saturate(
                dot(
                    fromDrop,
                    totalLine
                )
                / max(
                    dot(
                        totalLine,
                        totalLine
                    ),
                    0.000001
                )
            );

        float baseDistance =
            length(
                pin.Tex
                - (
                    dropPosition
                    + baseLine * baseT
                )
            );

        float airDistance =
            length(
                pin.Tex
                - (
                    dropPosition
                    + airLine * airT
                )
            );

        float totalDistance =
            length(
                pin.Tex
                - (
                    dropPosition
                    + totalLine * totalT
                )
            );

        /*
            Keep the three layers visually separable.

            Base force:
                thick purple line.

            Air drag:
                thinner cyan line.

            Total force:
                DO NOT draw the whole line white, because it would cover
                the two source layers. Only draw a small white endpoint
                marker for the resulting direction.

            This is a visualization change only.
        */
        float baseMask =
            1.0
            - smoothstep(
                0.0010,
                0.0032,
                baseDistance
            );

        float airMask =
            airLength > 0.0001
            ? (
                1.0
                - smoothstep(
                    0.0007,
                    0.0022,
                    airDistance
                )
            )
            : 0.0;

        float2 totalEndpoint =
            totalEnd;

        float totalEndpointDistance =
            length(
                pin.Tex
                - totalEndpoint
            );

        float totalEndpointMask =
            1.0
            - smoothstep(
                0.0020,
                0.0045,
                totalEndpointDistance
            );

        /*
            Endpoint marker is suppressed near the drop center so it
            cannot turn the whole origin into a white blob.
        */
        totalEndpointMask *=
            smoothstep(
                0.0030,
                0.0080,
                length(
                    pin.Tex
                    - dropPosition
                )
            );

        /*
            Draw source forces independently.

            The white total-force marker is deliberately evaluated last,
            but only exists around the predicted endpoint.
        */
        float3 baseColor =
            float3(1.0, 0.0, 1.0);

        float3 airColor =
            float3(0.0, 1.0, 1.0);

        float3 totalColor =
            float3(1.0, 1.0, 1.0);

        float3 composite =
            baseMask * baseColor
            + airMask * airColor
            + totalEndpointMask * totalColor;

        float compositeMask =
            max(
                marker * 0.65,
                max(
                    baseMask,
                    max(
                        airMask,
                        totalEndpointMask
                    )
                )
            );

        if (compositeMask > result)
        {
            result = compositeMask;
            resultColor = saturate(composite);
        }
    }

    return float4(
        resultColor,
        saturate(result)
    );
}


float4 rainPersistentForceVelocityDebugOutput(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 resultColor = float3(0.0, 0.0, 0.0);

    /*
        Debug 30:
        Compare the force direction used by persistent physics against
        the velocity already stored in the persistent state.

        Orange  = projected tangent force direction.
        Cyan    = persistent velocity direction.
        White   = overlap / agreement.

        This is a direction diagnostic only. It does not modify physics.
    */
    float3 effectiveForce =
        float3(
            0.0,
            -gRainGravity,
            0.0
        )
        + gRainAcceleration * gRainForceScale;

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

        float4 state =
            txRainState.SampleLevel(
                samPointRain,
                stateUV,
                0.0
            );

        float4 meta =
            txRainStateMeta.SampleLevel(
                samPointRain,
                stateUV,
                0.0
            );

        float2 p = state.rg;
        float2 velocity = state.ba;

        float2 dropPosition = float2(
            p.x,
            lerp(
                gRainStateMeshVMin,
                gRainStateMeshVMax,
                p.y
            )
        );

        float2 localDelta = pin.Tex - dropPosition;

        /*
            Debug 30 size diagnostic:
            use the persistent radius from Meta A/B instead of a fixed marker.

            The physical radius remains unchanged. Only the visible debug
            marker is amplified so size variance can be judged clearly.
        */
        localDelta.y /=
            max(
                gRainStateMeshVMax
                - gRainStateMeshVMin,
                0.000001
            );

        float radius01 = saturate(
            (meta.r - 0.032) / (0.115 - 0.032)
        );

        float debugRadius = lerp(
            0.006,
            0.022,
            radius01
        );

        float marker =
            1.0
            - smoothstep(
                debugRadius * 0.45,
                debugRadius,
                length(localDelta)
            );

        if (marker <= result)
            continue;

        float3 normalWorld =
            rainSurfaceNormalWorld(
                float2(
                    p.x,
                    lerp(
                        gRainStateMeshVMin,
                        gRainStateMeshVMax,
                        p.y
                    )
                )
            );

        /*
            Reconstruct the same object-space tangent convention used by
            the persistent physics pass. This lets us inspect the exact
            force direction currently driving the simulation.
        */
        float3 normalObject =
            normalize(
                mul(
                    normalWorld,
                    transpose(
                        (float3x3)gRainObjectToWorld
                    )
                )
            );

        float3 tangentUObject =
            float3(
                1.0,
                0.0,
                0.0
            );

        tangentUObject -=
            normalObject
            * dot(
                tangentUObject,
                normalObject
            );

        if (length(tangentUObject) < 0.0001)
        {
            tangentUObject =
                float3(
                    0.0,
                    0.0,
                    1.0
                );

            tangentUObject -=
                normalObject
                * dot(
                    tangentUObject,
                    normalObject
                );
        }

        tangentUObject =
            normalize(tangentUObject);

        float3 tangentVObject =
            normalize(
                cross(
                    normalObject,
                    tangentUObject
                )
            );

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

        float2 tangentForce =
            float2(
                -dot(
                    effectiveForce,
                    tangentUWorld
                ),
                dot(
                    effectiveForce,
                    tangentVWorld
                )
            );

        float forceLength =
            length(tangentForce);

        float2 forceDirection =
            tangentForce
            / max(
                forceLength,
                0.000001
            );

        float velocityLength =
            length(velocity);

        float2 velocityDirection =
            velocity
            / max(
                velocityLength,
                0.000001
            );

        /*
            Convert both normalized state-space directions to the rendered
            mesh aspect ratio before drawing them in pin.Tex space.
        */
        float vRange =
            max(
                gRainStateMeshVMax
                - gRainStateMeshVMin,
                0.000001
            );

        float2 forceEnd =
            dropPosition
            + float2(
                forceDirection.x,
                forceDirection.y * vRange
            ) * 0.020;

        float2 velocityEnd =
            dropPosition
            + float2(
                velocityDirection.x,
                velocityDirection.y * vRange
            ) * 0.020;

        float2 forceLine =
            forceEnd
            - dropPosition;

        float2 velocityLine =
            velocityEnd
            - dropPosition;

        float forceT =
            saturate(
                dot(
                    pin.Tex - dropPosition,
                    forceLine
                )
                / max(
                    dot(forceLine, forceLine),
                    0.000001
                )
            );

        float velocityT =
            saturate(
                dot(
                    pin.Tex - dropPosition,
                    velocityLine
                )
                / max(
                    dot(velocityLine, velocityLine),
                    0.000001
                )
            );

        float forceDistance =
            length(
                pin.Tex
                - (
                    dropPosition
                    + forceLine * forceT
                )
            );

        float velocityDistance =
            length(
                pin.Tex
                - (
                    dropPosition
                    + velocityLine * velocityT
                )
            );

        float forceMask =
            1.0
            - smoothstep(
                0.0010,
                0.0025,
                forceDistance
            );

        float velocityMask =
            1.0
            - smoothstep(
                0.0010,
                0.0025,
                velocityDistance
            );

        float overlap =
            saturate(
                dot(
                    forceDirection,
                    velocityDirection
                )
                * 0.5
                + 0.5
            );

        result =
            max(
                marker,
                max(
                    forceMask,
                    velocityMask
                )
            );

        resultColor =
            float3(
                forceMask,
                velocityMask,
                overlap
            );
    }

    return float4(
        resultColor,
        saturate(result)
    );
}


float4 rainPersistentAirflowInputDebugOutput(PS_IN pin)
{
    /*
        Debug 32:
        Multi-point airflow input verification.

        This intentionally verifies only:
            car.velocity -> -airflow -> camera basis

        No persistent state, normal map, tangent reconstruction,
        or physical drag is used here.

        Nine diagnostic origins are distributed across the visor.
        Every origin receives the same world-space airflow vector.
        Therefore all lines should rotate together when the camera/view
        rotates, while their direction remains consistent with the same
        incoming world-space airflow.
    */

    float3 airflow =
        gRainAirVelocityWorld;

    float airSpeed =
        length(airflow);

    float2 cameraAir =
        float2(
            dot(airflow, gRainCameraSide),
            dot(airflow, gRainCameraUp)
        );

    float cameraAirLength =
        length(cameraAir);

    float2 direction =
        cameraAir
        / max(cameraAirLength, 0.000001);

    float visualLength =
        0.12
        * saturate(
            airSpeed / 100.0
        );

    float result =
        0.0;

    float3 resultColor =
        float3(1.0, 1.0, 1.0);

    const float xPositions[3] =
    {
        0.30,
        0.50,
        0.70
    };

    const float yPositions[3] =
    {
        0.20,
        0.50,
        0.80
    };

    for (int yIndex = 0; yIndex < 3; ++yIndex)
    {
        float centerY =
            lerp(
                gRainStateMeshVMin,
                gRainStateMeshVMax,
                yPositions[yIndex]
            );

        for (int xIndex = 0; xIndex < 3; ++xIndex)
        {
            float2 center =
                float2(
                    xPositions[xIndex],
                    centerY
                );

            float2 lineVector =
                direction * visualLength;

            float2 fromCenter =
                pin.Tex
                - center;

            float lineT =
                saturate(
                    dot(fromCenter, lineVector)
                    / max(dot(lineVector, lineVector), 0.000001)
                );

            float lineDistance =
                length(
                    pin.Tex
                    - (
                        center
                        + lineVector * lineT
                    )
                );

            float lineMask =
                1.0
                - smoothstep(
                    0.0025,
                    0.0055,
                    lineDistance
                );

            float pointMask =
                1.0
                - smoothstep(
                    0.004,
                    0.008,
                    length(pin.Tex - center)
                );

            float contribution =
                max(
                    lineMask * saturate(airSpeed / 3.0),
                    pointMask
                );

            if (contribution > result)
            {
                result =
                    contribution;

                float speed01 =
                    saturate(
                        airSpeed / 100.0
                    );

                resultColor =
                    lerp(
                        float3(0.0, 0.25, 0.25),
                        float3(0.0, 1.0, 1.0),
                        speed01
                    );
            }
        }
    }

    return float4(
        resultColor,
        result
    );
}
float4 rainPersistentAirflowNormalProjectionDebugOutput(PS_IN pin)
{
    /*
        Debug 33:
        Multi-point airflow + surface-normal projection.

        Debug 32 verified the -car.velocity input and camera projection.
        This stage adds only the corrected RainSurfaceNormal:
            airflow -> normal projection -> camera basis

        It intentionally does not use persistent state or mesh derivatives.
        Nine points show how the new normal map changes airflow direction
        across the visor.
    */

    float3 airflow = gRainAirVelocityWorld;
    float airSpeed = length(airflow);

    float3 cameraSide = gRainCameraSide;
    float3 cameraUp = gRainCameraUp;

    float visualLength =
        0.12 * saturate(airSpeed / 100.0);

    float result = 0.0;
    float3 resultColor = float3(0.0, 0.25, 0.25);

    const float xPositions[3] = { 0.3, 0.5, 0.7 };
    const float yPositions[3] = { 0.20, 0.50, 0.80 };

    for (int yIndex = 0; yIndex < 3; ++yIndex)
    {
        float centerY =
            lerp(
                gRainStateMeshVMin,
                gRainStateMeshVMax,
                yPositions[yIndex]
            );

        for (int xIndex = 0; xIndex < 3; ++xIndex)
        {
            float centerX =
                lerp(
                    gRainStateMeshUMin,
                    gRainStateMeshUMax,
                    xPositions[xIndex]
                );
            
            float2 center =
                float2(
                    centerX,
                    centerY
                );

            float3 normalWorld =
                rainSurfaceNormalWorld(center);

            float3 projectedAirflow =
                airflow
                - normalWorld
                * dot(airflow, normalWorld);

            float projectedSpeed =
                length(projectedAirflow);

            float2 cameraProjected =
                float2(
                    dot(projectedAirflow, cameraSide),
                    dot(projectedAirflow, cameraUp)
                );

            float cameraLength =
                length(cameraProjected);

            float2 direction =
                cameraProjected
                / max(cameraLength, 0.000001);

            float2 lineVector =
                direction
                * visualLength
                * saturate(
                    projectedSpeed
                    / max(airSpeed, 0.000001)
                );

            float2 fromCenter =
                pin.Tex - center;

            float lineT =
                saturate(
                    dot(fromCenter, lineVector)
                    / max(
                        dot(lineVector, lineVector),
                        0.000001
                    )
                );

            float lineDistance =
                length(
                    pin.Tex
                    - (
                        center
                        + lineVector * lineT
                    )
                );

            float lineMask =
                1.0
                - smoothstep(
                    0.0025,
                    0.0055,
                    lineDistance
                );

            float pointMask =
                1.0
                - smoothstep(
                    0.004,
                    0.008,
                    length(pin.Tex - center)
                );

            float contribution =
                max(
                    lineMask * saturate(projectedSpeed / 3.0),
                    pointMask
                );

            if (contribution > result)
            {
                result = contribution;

                float projection01 =
                    saturate(
                        projectedSpeed
                        / max(airSpeed, 0.000001)
                    );

                resultColor =
                    lerp(
                        float3(0.0, 0.20, 0.20),
                        float3(0.0, 1.0, 1.0),
                        projection01
                    );
            }
        }
    }

    if (airSpeed < 0.01)
    {
        resultColor = float3(1.0, 1.0, 1.0);
    }

    return float4(resultColor, result);
}


/*
    Debug 35:
    Controlled droplet size / mass / adhesion threshold experiment.

    Nine fixed diagnostic droplets are rendered at calibrated visor
    positions. Radius varies deliberately while mass is derived from
    the same radius relationship used by the current RainFX model.

    Layout:
        S M L
        L S M
        M L S

    Marker size = test radius.
    Green  = safely below adhesion threshold.
    Yellow = approaching adhesion threshold.
    Red    = threshold exceeded; flow should be possible.

    This diagnostic does not integrate persistent state and does not
    modify RainFX physics. It isolates the radius -> mass -> adhesion
    relationship before acceleration/drag tuning.
*/
float4 rainPersistentDropScaleThresholdDebugOutput(PS_IN pin)
{
    const float xPositions[3] = { gRainStateMeshUMin, gRainUVCenterX, gRainStateMeshUMax };
    const float yPositions[3] = { gRainStateMeshVMin, gRainUVCenterY, gRainStateMeshVMax };

    const float radiusValues[9] =
    {
        0.115, 0.0735, 0.032,
        0.0735, 0.032, 0.115,
        0.032, 0.115, 0.0735
    };

    float3 forceWorld =
        float3(0.0, -gRainGravity, 0.0)
        + gRainAcceleration * gRainForceScale;

    float result = 0.0;
    float3 resultColor = float3(1.0, 1.0, 1.0);

    for (int yIndex = 0; yIndex < 3; ++yIndex)
    {
        float centerY = 
            yPositions[yIndex];
            // lerp(
            //     gRainStateMeshVMin,
            //     gRainStateMeshVMax,
            //     yPositions[yIndex]
            // );

        for (int xIndex = 0; xIndex < 3; ++xIndex)
        {
            int index =
                yIndex * 3
                + xIndex;

            float centerX =
                xPositions[xIndex];
                // lerp(
                //     gRainStateMeshUMin,
                //     gRainStateMeshUMax,
                //     xPositions[xIndex]
                // );

            float2 center =
                float2(centerX, centerY);

            float radius =
                radiusValues[index];

            float radius01 =
                saturate(
                    (radius - 0.032)
                    / (0.115 - 0.032)
                );

            // Keep this exactly aligned with the current RainFX mass model.
            float mass =
                lerp(
                    1.0,
                    9.0,
                    radius01 * radius01
                );

            float3 normalWorld =
                rainSurfaceNormalWorld(center);

            /*
                Use the same normal-derived tangent convention as the
                persistent Stage 1 state shader. This keeps this test
                independent from fragment derivatives while still applying
                the local visor normal at each diagnostic point.
            */
            float3 normalObject =
                normalize(
                    mul(
                        normalWorld,
                        transpose(
                            (float3x3)gRainObjectToWorld
                        )
                    )
                );

            float3 tangentUObject =
                float3(1.0, 0.0, 0.0);

            tangentUObject -=
                normalObject
                * dot(
                    tangentUObject,
                    normalObject
                );

            if (length(tangentUObject) < 0.0001)
            {
                tangentUObject =
                    float3(0.0, 0.0, 1.0);

                tangentUObject -=
                    normalObject
                    * dot(
                        tangentUObject,
                        normalObject
                    );
            }

            tangentUObject =
                normalize(tangentUObject);

            float3 tangentVObject =
                normalize(
                    cross(
                        normalObject,
                        tangentUObject
                    )
                );

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

            float2 tangentForce =
                float2(
                    -dot(
                        forceWorld,
                        tangentUWorld
                    ),
                    dot(
                        forceWorld,
                        tangentVWorld
                    )
                );

            float forceMagnitude =
                length(tangentForce);

            float adhesionBase =
                lerp(
                    gRainAdhesionMin,
                    gRainAdhesionMax,
                    0.5
                );

            float adhesion =
                adhesionBase
                / sqrt(
                    max(
                        mass,
                        0.000001
                    )
                );

            float ratio =
                forceMagnitude
                / max(
                    adhesion,
                    0.000001
                );

            float3 color;

            if (ratio < 0.75)
            {
                color =
                    float3(
                        0.05,
                        1.0,
                        0.20
                    );
            }
            else if (ratio < 1.0)
            {
                color =
                    float3(
                        1.0,
                        0.85,
                        0.05
                    );
            }
            else
            {
                color =
                    float3(
                        1.0,
                        0.08,
                        0.05
                    );
            }

            /*
                Deliberately larger than Debug 28 so the three physical
                test sizes are easy to distinguish in-game.
            */
            float markerRadius =
                lerp(
                    0.006,
                    0.018,
                    radius01
                );

            float distanceToDrop =
                length(
                    pin.Tex - center
                );

            float marker =
                1.0
                - smoothstep(
                    markerRadius * 0.35,
                    markerRadius,
                    distanceToDrop
                );

            if (marker > result)
            {
                result = marker;
                resultColor = color;
            }
        }
    }

    return float4(
        resultColor,
        saturate(result)
    );
}


float4 rainPersistentCombinedForceDebugOutput(PS_IN pin)
{
    /*
        Debug 34:
        Combined external force before persistent integration.

        This is the final cheap force-stage diagnostic before changing
        persistent physics. It combines:
            gravity
            vehicle acceleration
            airflow force

        The combined force is then projected onto the corrected visor
        normal at nine calibrated points.

        White point  = diagnostic origin
        Cyan line    = combined tangent force direction
        Brightness   = tangent force magnitude
    */

    float3 airflow =
        gRainAirVelocityWorld;

    float airSpeed =
        length(airflow);

    float3 baseForce =
        float3(0.0, -gRainGravity, 0.0)
        + gRainAcceleration * gRainForceScale;

    /*
        Keep the current Debug 31 airflow-force convention for this
        diagnostic only. Persistent physics is not modified here.
    */
    float3 airflowForce =
        airflow
        * airSpeed
        * max(gRainAirDragScale, 0.0);

    float3 totalForce =
        baseForce
        + airflowForce;

    float totalForceLength =
        length(totalForce);

    float visualLength =
        0.14
        * saturate(totalForceLength / 100.0);

    float result = 0.0;
    float3 resultColor = float3(0.0, 0.25, 0.25);

    const float xPositions[3] = { 0.30, 0.50, 0.70 };
    const float yPositions[3] = { 0.20, 0.50, 0.80 };

    for (int yIndex = 0; yIndex < 3; ++yIndex)
    {
        float centerY =
            lerp(
                gRainStateMeshVMin,
                gRainStateMeshVMax,
                yPositions[yIndex]
            );

        for (int xIndex = 0; xIndex < 3; ++xIndex)
        {
            float centerX =
                lerp(
                    gRainStateMeshUMin,
                    gRainStateMeshUMax,
                    xPositions[xIndex]
                );

            float2 center =
                float2(centerX, centerY);

            float3 normalWorld =
                rainSurfaceNormalWorld(center);

            float3 tangentForce =
                totalForce
                - normalWorld
                * dot(
                    totalForce,
                    normalWorld
                );

            float tangentSpeed =
                length(tangentForce);

            float2 cameraForce =
                float2(
                    dot(tangentForce, gRainCameraSide),
                    dot(tangentForce, gRainCameraUp)
                );

            float cameraLength =
                length(cameraForce);

            float2 direction =
                cameraForce
                / max(cameraLength, 0.000001);

            float2 lineVector =
                direction
                * visualLength
                * saturate(
                    tangentSpeed
                    / max(totalForceLength, 0.000001)
                );

            float2 fromCenter =
                pin.Tex - center;

            float lineT =
                saturate(
                    dot(fromCenter, lineVector)
                    / max(
                        dot(lineVector, lineVector),
                        0.000001
                    )
                );

            float lineDistance =
                length(
                    pin.Tex
                    - (
                        center
                        + lineVector * lineT
                    )
                );

            float lineMask =
                1.0
                - smoothstep(
                    0.0025,
                    0.0055,
                    lineDistance
                );

            float pointMask =
                1.0
                - smoothstep(
                    0.004,
                    0.008,
                    length(pin.Tex - center)
                );

            float contribution =
                max(
                    lineMask
                    * saturate(tangentSpeed / 3.0),
                    pointMask
                );

            if (contribution > result)
            {
                result = contribution;

                float tangent01 =
                    saturate(
                        tangentSpeed
                        / max(totalForceLength, 0.000001)
                    );

                resultColor =
                    lerp(
                        float3(0.0, 0.20, 0.20),
                        float3(0.0, 1.0, 1.0),
                        tangent01
                    );
            }
        }
    }

    if (totalForceLength < 0.01)
    {
        resultColor = float3(1.0, 1.0, 1.0);
    }

    return float4(resultColor, result);
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

    if (gRainDebug == 18)
    {
        return rainStateDebugOutput(pin);
    }

    if (gRainDebug == 20)
    {
        return rainPersistentVelocityDebugOutput(pin);
    }

    if (gRainDebug == 21)
    {
        return rainPersistentPositionDebugOutput(pin);
    }

    if (gRainDebug == 22)
    {
        return rainPersistentRawStateDebugOutput(pin);
    }

    if (gRainDebug == 23)
    {
        return rainPersistentPredictedMotionDebugOutput(pin);
    }

    if (gRainDebug == 24)
    {
        return rainPersistentMotionScaleDebugOutput(pin);
    }

    if (gRainDebug == 25)
    {
        return rainPersistentAccumulatedDisplacementDebugOutput(pin);
    }

    if (gRainDebug == 36)
    {
        return rainPersistentMeasuredGridDebugOutput(pin);
    }

    if (gRainDebug == 26)
    {
        return rainPersistentVelocityDeltaDebugOutput(pin);
    }

    if (gRainDebug == 27)
    {
        return rainPersistentSurfaceForceDebugOutput(pin);
    }

    if (gRainDebug == 28)
    {
        return rainPersistentAdhesionDebugOutput(pin);
    }

    if (gRainDebug == 29)
    {
        return rainPersistentPhysicalDropDebugOutput(pin);
    }

    if (gRainDebug == 30)
    {
        return rainPersistentForceVelocityDebugOutput(pin);
    }

    if (gRainDebug == 31)
    {
        return rainPersistentAirDragDebugOutput(pin);
    }

    if (gRainDebug == 32)
    {
        return rainPersistentAirflowInputDebugOutput(pin);
    }

    if (gRainDebug == 33)
    {
        return rainPersistentAirflowNormalProjectionDebugOutput(pin);
    }

    if (gRainDebug == 34)
    {
        return rainPersistentCombinedForceDebugOutput(pin);
    }

    if (gRainDebug == 35)
    {
        return rainPersistentDropScaleThresholdDebugOutput(pin);
    }

    if (gRainDebug == 19)
    {
        /*
            Stage 2 / persistent independent-drop validation.

            Persistent state positions are normalized to [0, 1].
            The current visor mesh uses the measured pin.Tex Y range
            approximately -0.579 .. -0.362, so conversion is performed
            only at render time. Physics state remains normalized.

            Every state texel is rendered independently. This deliberately
            uses a simple circle marker: no procedural drop generation,
            normal projection, merge or residue is involved yet.
        */
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

            float2 statePosition = state.rg;

            float2 dropPosition = float2(
                statePosition.x,
                lerp(
                    -0.567,
                    -0.466,
                    statePosition.y
                )
            );

            /*
                Keep marker size deterministic per persistent state index.
                The intentionally generous range makes this stage easy to
                distinguish from the existing procedural rain layer.
            */
            float4 meta = txRainStateMeta.SampleLevel(
                samPointRain,
                stateUV,
                0.0
            );

            float radius01 = saturate(
                (meta.r - 0.032) / (0.115 - 0.032)
            );

            float radius = lerp(
                0.012,
                0.024,
                radius01
            );

            float distanceToDrop = length(
                pin.Tex - dropPosition
            );

            float drop = 1.0 - smoothstep(
                radius * 0.25,
                radius,
                distanceToDrop
            );

            result = max(result, drop);
        }

        return float4(
            1.0,
            0.15,
            0.05,
            saturate(result)
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

#endif // RAIN_GPU_STATE_PASS