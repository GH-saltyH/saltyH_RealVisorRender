// rev48-U1 IMPACT REGISTRY (docs/RAINFX_V2_UNIFIED_IMPACT_PLAN.md; W1q-W1s lamella registry). Target: LM (gR2Cells,
// RGBA32F), ping-pong, once per frame BEFORE the cells pass. Every raindrop impact of the frame is born here, ONE event
// per raindrop (rate impactRate x cell area x exposure x clustering): R = birth frame + 1 (+0.25 if it landed on fed
// water), G = the previous impact of the cell (visor: disturbance for 0.2 s). Consumers decode it with r2ImpactAt:
//   cells -- dry landing: the raindrop itself sticks as one splat drop (S2' spread / recoil) + satellites; on a drop: merge
//   field -- fed / sheet landing: its water joins the sheet; local supply q (fed / wet regime)
//   visor -- impact disturbance on drops and sheet
#define R2_LAM_LIFE 12
float4 main(PS_IN pin) {
    int2 c = int2(pin.PosH.xy);
    float2 t = (float2(c) + 0.5) / gR2Cells;
    float4 o = txR2Lam.Load(int3(c, 0));
    if (gR2ImpactRate <= 0 || r2Valid(t) < 0.5) return float4(0, 0, 0, 0);
    float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
    float3 dv = r2ToWorld(r2Tap(txR2Dv, t).xyz);
    float lam = gR2ImpactRate * length(cross(du, dv)) / (gR2Cells.x * gR2Cells.y) * r2Exposure(t) * gR2Exposure * gR2FrameDt
              * r2Cluster(t);
    float cur = (o.x > 0.5 && gR2Frame - (floor(o.x) - 1.0) <= R2_LAM_LIFE) ? o.x : 0.0;
    float prev = (o.y > 0.5 && gR2Frame - (floor(o.y) - 1.0) <= R2_LAM_LIFE) ? o.y : 0.0;
    uint sk = (uint)gR2Frame * 8u + 9200u;
    if (r2Rand(uint3((uint)c.x, (uint)c.y, sk)) < lam)
        return float4(gR2Frame + 1.0 + ((gR2SheetOn > 0.5 && r2FedTx(txR2Field, t)) ? 0.25 : 0.0), cur, 0, 0);
    return float4(cur, prev, 0, 0);
}
