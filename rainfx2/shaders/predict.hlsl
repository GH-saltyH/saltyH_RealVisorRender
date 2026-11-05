// PERF-3 (2026-11-06): r2Predict ONCE per drop and substep. cells.hlsl evaluated it for every drop of its 5 x 5 window
// and for each of its three output thirds (drop | life | shape): 75 identical evaluations per drop per substep.
// r2Predict depends only on the source cell (state, life, shape, field / defect / impact textures, cell + frame
// hashes), never on the gathering pixel, so the stored result is bit-identical to the in-gather call.
// Target: 3 x the cell width (like S): [0] dest.xy, vol, alive ? 1 + moved : 0   [1] life after the step
//                                       [2] E8 child: cDest.xy, cVol, cPhi
float4 main(PS_IN pin) {
    int2 px = int2(pin.PosH.xy);
    int third = px.x >= 2 * (int)gR2Cells.x ? 2 : (px.x >= (int)gR2Cells.x ? 1 : 0);
    int2 s = px - int2(third * (int)gR2Cells.x, 0);
    float4 st = txR2State.Load(int3(s, 0));
    if (st.z <= 0) return float4(0, 0, 0, 0);          // cells skips empty sources before using the prediction
    R2Move m = r2Predict(s, st, r2Life(s), r2Shape(s));
    if (third == 0) return float4(m.dest, m.vol, m.alive > 0.5 ? 1.0 + max(m.moved, 0.0) : 0.0);
    if (third == 1) return m.life;
    return float4(m.cDest, m.cVol, m.cPhi);
}
