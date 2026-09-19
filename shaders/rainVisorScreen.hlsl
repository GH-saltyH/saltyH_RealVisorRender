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
    float3 normalCamera,
    out float3 tangentUCamera,
    out float3 tangentVCamera
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
        The normal map can differ slightly from the geometric normal.
        Re-orthogonalize the UV tangents against the supplied surface
        normal so force projection remains tangent to the actual normal
        used by the rain model.
    */
    tangentUCamera =
        normalize(
            tangentUCamera
            - normalCamera * dot(
                tangentUCamera,
                normalCamera
            )
        );

    tangentVCamera =
        normalize(
            tangentVCamera
            - normalCamera * dot(
                tangentVCamera,
                normalCamera
            )
        );

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
    PS_IN pin,
    float patternScale
)
{
    float3 tangentU;
    float3 tangentV;

    rainSurfaceBasisCamera(
        pin,
        normal,
        tangentU,
        tangentV
    );

    float2 result =
        float2(
            -dot(force, tangentU),
            dot(force, tangentV)
        );

    /*
        Convert from real mesh UV movement into this layer's procedural
        UV space. Positive patternScale values preserve direction.
    */
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
    Single-drop lifecycle diagnostic.

    This deliberately removes population effects:
        - one fixed spawn position
        - one fixed size
        - one fixed adhesion threshold
        - one deterministic lifetime / respawn gap

    The purpose is to verify the core state machine before adding
    population density and candidate-specific surface reconstruction.
*/
float rainSingleDropDiagnostic(PS_IN pin, float time)
{
    const float2 spawnUV = float2(0.5, 0.535);
    const float dropSize = 0.085;

    /* Keep the same procedural scale as the large layer. */
    float2 proceduralUV = pin.Tex;
    float2 grid = proceduralUV * 18.0;
    float2 spawnPos = spawnUV * 18.0;

    /*
        Keep the existing force model intact.
        A fixed midpoint adhesion makes the state transition
        observable without depending on a random candidate.
    */
    float adhesion =
        lerp(
            gRainAdhesionMin,
            gRainAdhesionMax,
            0.5
        );

    float3 surfaceNormal =
        rainSurfaceNormalCamera(spawnUV);

    float3 gravityForce =
        float3(
            0.0,
            -gRainGravity,
            0.0
        );

    float3 effectiveForce =
        gravityForce
        + gRainAcceleration * gRainForceScale;

    /*
        The tangent frame is evaluated from the actual rendered
        fragment. The drop is intentionally tiny and centered, so
        this diagnostic is for lifecycle first, not candidate-wide
        tangent reconstruction.
    */
    float2 tangentForce =
        rainProjectForceToUV(
            effectiveForce,
            surfaceNormal,
            pin,
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
        float movementSpeed =
            excessForce * gRainFlowSpeed;

        float travelDistance =
            min(
                movementSpeed * age,
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

    /*
        Diagnostic trail is derived from the same movement vector.
        No independent flow direction is introduced.
    */
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

            /*
                Convert the candidate's procedural position back to the
                real mesh UV before sampling the object-space normal.
            */
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

            /*
                All forces are now evaluated for THIS drop at THIS UV.

                Gravity is camera-local, matching gRainAcceleration.
                The normal removes the component pressing through the
                visor; only the tangential component can move the drop.
            */
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
                    pin,
                    patternScale
                );

            float forceMagnitude =
                length(tangentForce);

            /*
                Each procedural candidate now has its own lifecycle.

                cycle = visible lifetime + respawn gap

                The particle is:
                    born at age 0
                    -> moves while alive
                    -> disappears at lifetime
                    -> stays absent for respawnGap
                    -> respawns with a new phase

                Because every cell/candidate has a different lifetime,
                gap and phase, the whole visor no longer resets as one
                population.
            */
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

            /*
                The gap is an actual dead state rather than a zero-alpha
                particle. This makes creation/destruction asynchronous.
            */
            if (cycleTime >= lifetime)
                continue;

            float age = cycleTime;

            float life01 =
                saturate(
                    age / lifetime
                );

            /*
                Soft birth/death envelopes prevent a hard popping edge
                while retaining an actual finite lifetime.
            */
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

            /*
                This is the actual adhesion threshold.

                Below threshold:
                    excessForce = 0 -> drop stays attached.

                Above threshold:
                    excessForce determines both movement speed and
                    visible trail strength.
            */
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
                /*
                    No tangent force over the drop's own adhesion
                    threshold: it does not move.
                */
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
                Movement is driven directly by the SAME thresholded
                tangent force used above.

                There is no separate global flow vector anymore, so a
                change in force direction changes this drop's direction
                immediately according to its own local surface normal.
            */
            float movementSpeed =
                excessForce
                * gRainFlowSpeed;

            float travelDistance =
                movementSpeed
                * age;

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

            /*
                The trail uses the ACTUAL movement vector.

                Its length is the actual distance travelled by the drop;
                there is no fixed drop-size cap anymore.
            */
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

            /*
                A little extra persistence for stronger force, but the
                direction and length remain tied to actual movement.
            */
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

    float2 tangentForce =
        rainProjectForceToUV(
            acceleration,
            normal,
            pin,
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

    return float4(
        0.0,
        0.0,
        0.0,
        1.0
    );
}


/* 
    Render-path / UV diagnostic.

    This is intentionally independent from:
        - normal texture
        - force projection
        - lifetime
        - movement
        - alpha fading

    The marker is defined directly in MESH UV space. If this is not
    visible with gRainDebug == 3, the problem is upstream of the rain
    lifecycle itself: mesh coverage/UVs, depth/cull/blend state, or
    shader submission.
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
    /*
        Debug 3: absolute UV/render-path visibility test.
        This must produce a clearly visible opaque red marker.
    */
    if (gRainDebug == 3)
    {
        /*
            Hard render-path test.

            Deliberately ignore UV, textures, normals, forces and alpha
            masks. Every fragment of the submitted mesh must be opaque red.

            If this is invisible, the failure is outside the rain-drop
            algorithm itself.
        */
        return float4(
            1.0,
            0.0,
            0.0,
            1.0
        );
    }

    /*
        Debug 4: single-drop lifecycle diagnostic.
    */
    if (gRainDebug == 4)
    {
        float diagnostic =
            rainSingleDropDiagnostic(
                pin,
                gRainTime
            );

        return float4(
            0.82,
            0.90,
            1.0,
            diagnostic * 0.70
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