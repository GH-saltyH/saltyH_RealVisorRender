// P1c (rev6): coalescence merge. Target: S_next (gR2Cells, RGBA32F).
// Reads S (after P1) and the claims C. A cell keeps its own drop unless it was claimed,
// and gathers every neighbour whose claim points at it: volume adds, position is the
// volume centroid (may leave the cell by < 1 cell; the next P1 gather relocates it),
// seed and packed move follow the largest contributor. Mass is conserved except the
// stable-size cap (excess runs off, same rule as P1).

float4 main(PS_IN pin) {
    // rev45: twice the cell width; the second third writes the life cycle of the winning drop.
    int2 px = int2(pin.PosH.xy);
    int third = px.x >= 2 * (int)gR2Cells.x ? 2 : (px.x >= (int)gR2Cells.x ? 1 : 0);   // rev48-S1: + shape third
    bool lifeHalf = third == 1;
    int2 c = px - int2(third * (int)gR2Cells.x, 0);
    float4 shape = float4(0, 0, r2PackHarm(0, 0), 0);
    R2ShapeAcc sacc = r2ShapeAccInit();   // rev48-S3 merged footprint
    int2 size = int2(gR2Cells);
    float4 life = float4(0, 0, 0, 0);
    float4 me = txR2State.Load(int3(c, 0));
    float4 mc = txR2Claim.Load(int3(c, 0));
    // rev48-S4b: position, seed, life and shape follow FOOTPRINT AREA (r2FootW), volume adds
    float accV = 0, accW = 0, bigW = 0, w = r2PackMove(float2(0, 0), 0);
    float2 accP = float2(0, 0);
    float2 accM = float2(0, 0);                   // rev48-S4b: momentum (volume-weighted move) of the merged drop
    if (me.z > 0 && mc.z < 0.5) {
        accM = r2UnpackMove(me.w) * me.z;
        shape = r2Shape(c);
        float wa = r2FootW(me.z, shape);
        accV = me.z; accW = wa; accP = me.xy * wa; bigW = wa; w = me.w; life = r2Life(c);
        r2ShapeAccAdd(sacc, shape, me.z, me.xy * gR2CellSizeMM);
    }
    [unroll] for (int y = -2; y <= 2; ++y) {
        [unroll] for (int x = -2; x <= 2; ++x) {
            if (x == 0 && y == 0) continue;
            int2 s = c + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            float4 cl = txR2Claim.Load(int3(s, 0));
            if (cl.z < 0.5 || any(int2(round(cl.xy)) != int2(-x, -y))) continue;
            float4 st = txR2State.Load(int3(s, 0));
            float4 shs = r2Shape(s);
            float wa = r2FootW(st.z, shs);
            accV += st.z;
            accW += wa;
            accM += r2UnpackMove(st.w) * st.z;
            accP += (float2(x, y) + st.xy) * wa;
            r2ShapeAccAdd(sacc, shs, st.z, (float2(x, y) + st.xy) * gR2CellSizeMM);
            if (wa > bigW) { bigW = wa; w = st.w; life = r2Life(s); shape = shs; }
        }
    }
    if (accV <= 0) return third == 2 ? float4(0, 0, r2PackHarm(0, 0), 0) : (lifeHalf ? float4(0, 0, 0, 0) : float4(0.4995, 0.4995, 0, r2PackMove(float2(0, 0), 0)));
    if (third == 2) return r2ShapeCompose(sacc, length(r2UnpackMove(w)) > 0.05);   // rev48-S3/S4 merged footprint; a moving head keeps its own
    float2 p = clamp(accP / max(accW, 1e-12), -0.75, 1.749);
    float vMax = gR2ShapeK * gR2MaxRadiusMM * gR2MaxRadiusMM * gR2MaxRadiusMM;
    // the winner (widest footprint) gives seed / life / shape; the motion is the momentum of all of them, so a
    // head that runs into a wider pinned drop carries on from THAT position (the new head) instead of stopping
    return lifeHalf ? life : float4(p, min(accV, vMax), r2PackMove(accM / accV, r2UnpackSeed(w)));
}
