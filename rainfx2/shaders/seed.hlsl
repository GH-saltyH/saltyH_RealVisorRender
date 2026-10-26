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
    if (u.x % 6u != 3u || u.y % 6u != 3u || r2Valid(t) < 0.5) return none;
    float band = floor(saturate(t.x) * 8.0) / 7.0;
    float r = lerp(gR2LadderMinMM, gR2LadderMaxMM, saturate(band));
    return float4(0.5, 0.5, gR2ShapeK * r * r * r, r2PackMove(float2(0, 0), (float)((u.y / 6u) % 16u)));
}
