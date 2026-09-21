SamplerState rainStatePoint
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
            rainStatePoint,
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
            rainStatePoint,
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
        float radius01 = rainHash(float2(stateIndex, 211.0));

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
            rainStatePoint,
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

    if (gRainDebug == 19)
    {
        float persistentDrops = rainPersistentDropLayer(pin);

        return float4(
            1.0,
            0.15,
            0.05,
            persistentDrops
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
