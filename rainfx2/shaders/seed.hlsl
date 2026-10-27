// Physics test (rev7): replaces the cell state with a "drop ladder" — one drop every
// 6 cells in both directions, radius rising from gR2LadderMinMM (left, u = 0) to
// gR2LadderMaxMM (right, u = 1) in 8 bands. With rain frozen this shows directly
// which sizes stay pinned and which slide (and where) under the current gravity,
// car acceleration and airflow. Target: S (gR2Cells, RGBA32F).

float4 main(PS_IN pin) {
    int2 c = int2(pin.PosH.xy);
    uint2 u = uint2(c);
    float2 t = (float2(c) + 0.5) / gR2Cells;
    float4 none = float4(0.4995, 0.4995, 0, r2PackMove(float2(0, 0), 0));
    // rev23 look lab (docs/RAINFX_V2_DROP_PIPELINE_PLAN.md step 1): a static drop set with the
    // reference size distribution (counts x0.7 per 1.5x size bin -> pdf ~ r^-1.88), random
    // position, seed and occupancy. Nothing moves; only the look is judged.
    float4 res = none;                              // single exit (FXC X4000)
    uint k = (uint)gR2Frame;
    bool valid = r2Valid(t) > 0.5;
    if (gR2SeedMode > 0.5) {
        if (valid && r2Rand(uint3(u.x, u.y, k * 5u + 1u)) <= gR2LabOcc) {
            // inverse CDF of pdf ~ r^-(1+a): r = (lo + (hi - lo) x)^(-1/a), via exp2/log2 (r > 0)
            float a = 0.88;
            float lo = exp2(-a * log2(max(gR2LabRMinMM, 1e-3)));
            float hi = exp2(-a * log2(max(gR2LabRMaxMM, 1e-3)));
            float x = lerp(lo, hi, r2Rand(uint3(u.x, u.y, k * 5u + 2u)));
            float rr = exp2(-log2(max(x, 1e-6)) / a);
            float2 q = float2(r2Rand(uint3(u.x, u.y, k * 5u + 3u)), r2Rand(uint3(u.x, u.y, k * 5u + 4u))) * 0.999;
            float sd = floor(r2Rand(uint3(u.y, u.x, k * 5u + 5u)) * 16.0);
            res = float4(q, gR2ShapeK * rr * rr * rr, r2PackMove(float2(0, 0), sd));
        }
    } else if (u.x % 6u == 3u && u.y % 6u == 3u && valid) {
        float band = floor(saturate(t.x) * 8.0) / 7.0;
        float r = lerp(gR2LadderMinMM, gR2LadderMaxMM, saturate(band));
        res = float4(0.5, 0.5, gR2ShapeK * r * r * r, r2PackMove(float2(0, 0), (float)((u.y / 6u) % 16u)));
    }
    return res;
}
