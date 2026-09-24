}


float4 rainPersistentLifecycleStateDebugOutput(PS_IN pin)
{
    /*
        Debug 42 / C3 meta-state probe.

        This isolates the lifecycle metadata writeback from the normal
        droplet rendering path:
          cyan  = alive (Meta.A = 1)
          yellow = respawn pending (Meta.A = 2)
          black/transparent = dead/waiting (Meta.A = 0)

        The authoritative boundary mask is sampled here as well.
        This lets the test distinguish:
          - valid + alive      = cyan
          - outside + alive    = red  (boundary decision was NOT committed)
          - dead/waiting       = black/transparent
          - respawn pending    = yellow

        This deliberately combines the same mask decision used by Debug 41
        with the persistent Meta state, so the writeback can be validated
        without losing the boundary context.
    */
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 resultColor = float3(0.25, 0.95, 1.0);

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

        float4 meta = txRainStateMeta.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        );

        float2 statePosition = txRainState.SampleLevel(
            samPointRain,
            stateUV,
            0.0
        ).rg;

        float currentMask = rainStateBoundaryMask(statePosition);

        float radius01 = saturate(
            (meta.r - 0.032) / (0.115 - 0.032)
        );

        float radius = lerp(
            0.008,
            0.016,
            radius01
        );

        float marker = 1.0 - smoothstep(
            radius * 0.35,
            radius,
            length(pin.Tex - statePosition)
        );

        if (marker > result)
        {
            result = marker;

            if (meta.a < 0.5)
                resultColor = float3(0.0, 0.0, 0.0);
            else if (meta.a > 1.5)
                resultColor = float3(1.0, 0.85, 0.10);
            else if (currentMask < 0.5)
                resultColor = float3(1.0, 0.0, 0.0);
            else
                resultColor = float3(0.25, 0.95, 1.0);
        }
    }

    return float4(
        resultColor,
        saturate(result)
    );
}

float4 rainPersistentLifecycleDebugOutput(PS_IN pin)
{
    /*
        Debug 39 / C3:
        Render only live persistent states. A state that reaches the calibrated
        normalized boundary is hidden while dead, then returns at a new hashed
        position after its respawn gap.

        This debug view intentionally does not draw a trail: the test is about
        identity, exit, waiting, and respawn distribution.
    */
    float count = max(gRainStateCount, 1.0);
    float result = 0.0;
    float3 resultColor = float3(0.25, 0.95, 1.0);