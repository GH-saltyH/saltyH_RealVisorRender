// PERF-9 DROP RECORDS (2026-11-06; PERF-7 review: the visor candidate loop stayed ~85 % of both visor passes -- every
// pixel re-derived each of its 34 candidates (3-4 loads + ~60 ALU incl. exp / pow / sqrt) although none of it
// depends on the pixel). r2CandCore runs ONCE per drop here; the visor reads the record (same code, same inputs,
// same values via init.lua candValues -> identical candidates). Target: 6 x the cell width, block k of drop s:
//   [0] centre (cells) xy, z = +-(rLeg + 1) (- = big-tile drop, 0 = empty), w = early-out radius (mm)
//   [1] r, k, f, fx   [2] shape state sh   [3] m.xy, seed, ch   [4] e, sft, aMax, imp   [5] nk.xy
// w = max(r2SupportCore with the largest wobble amplitude (A <= gR2WobbleAmp), the S6c / R2b marker radii): a
// candidate farther than w cannot change the union nor a marker -> the visor skips it after ONE load.
float4 main(PS_IN pin) {
    int2 px = int2(pin.PosH.xy);
    int nx = (int)gR2Cells.x;
    int blk = px.x / nx;
    int2 s = int2(px.x - blk * nx, px.y);
    R2Cand c; float rLeg; bool win;
    if (!r2CandCore(s, c, rLeg, win)) return float4(0, 0, 0, 0);
    if (blk == 0) {
        float w = r2SupportCore(c, gR2LookLab > 0.5 ? 0.0 : max(gR2WobbleAmp, 0.0), 0.0);
        if (c.ch >= 0.0 && c.ch < 1.5) w = max(w, 1.2 * c.r);
        if (c.imp > 0.5) w = max(w, (c.imp > 2.5 ? 3.0 : 1.2) * c.r);
        return float4(c.q, (win ? -1.0 : 1.0) * (rLeg + 1.0), w);
    }
    if (blk == 1) return float4(c.r, c.k, c.f, c.fx);
    if (blk == 2) return c.sh;
    if (blk == 3) return float4(c.m, c.seed, c.ch);
    if (blk == 4) return float4(c.e, c.sft, c.aMax, c.imp);
    return float4(c.nk, 0.0, 0.0);
}
