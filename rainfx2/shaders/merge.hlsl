// P1c (rev6): coalescence merge. Target: S_next (gR2Cells, RGBA32F).
// Reads S (after P1) and the claims C. A cell keeps its own drop unless it was claimed,
// and gathers every neighbour whose claim points at it: volume adds, position is the
// volume centroid (may leave the cell by < 1 cell; the next P1 gather relocates it),
// seed and packed move follow the largest contributor. Mass is conserved except the
// stable-size cap (excess runs off, same rule as P1).

float4 main(PS_IN pin) {
    // rev45: twice the cell width; the second third writes the life cycle of the winning drop.
    int2 px = int2(pin.PosH.xy);
    int third = px.x >= 3 * (int)gR2Cells.x ? 3 : (px.x >= 2 * (int)gR2Cells.x ? 2 : (px.x >= (int)gR2Cells.x ? 1 : 0));   // + shape, B1 tail
    bool lifeHalf = third == 1;
    int2 c = px - int2(third * (int)gR2Cells.x, 0);
    float4 shape = float4(0, 0, r2PackHarm(0, 0), 0);
    R2ShapeAcc sacc = r2ShapeAccInit();   // rev48-S3 merged footprint
    int2 size = int2(gR2Cells);
    float4 life = float4(0, 0, 0, 0);
    float4 me = txR2State.Load(int3(c, 0));
    float4 mc = txR2Claim.Load(int3(c, 0));
    // FILM S2-1: a drop the field pass laid into the film last frame (same S, txR2FieldOld = its F_prev, r2FilmJoin) is gone
    if (r2FilmJoin(me, r2Life(c), txR2FieldOld, float2(c) + me.xy)) me.z = 0.0;
    me.z -= r2SpillMM3(me, r2Life(c));                               // R1: the excess the field laid as film last frame
    // rev48-S4b: position, seed, life and shape follow FOOTPRINT AREA (r2FootW), volume adds
    float accV = 0, accW = 0, bigW = 0, w = r2PackMove(float2(0, 0), 0);
    float2 accP = float2(0, 0);
    float2 accM = float2(0, 0);                   // rev48-S4b: momentum (volume-weighted move) of the merged drop
    float4 tailW = float4(0, 0, 0, 0);            // B1: the winner's tail and its old centre (cells, relative to c)
    float2 tailOld = float2(0, 0);
    if (me.z > 0 && mc.z < 0.5) {
        accM = r2UnpackMove(me.w) * me.z;
        shape = r2Shape(c);
        float wa = r2FootW(me.z, shape);
        accV = me.z; accW = wa; accP = me.xy * wa; bigW = wa; w = me.w; life = r2Life(c);
        if (third == 3) { tailW = r2Tail(c); tailOld = me.xy; }
        r2ShapeAccAdd(sacc, shape, me.z, me.xy * gR2CellSizeMM);
    }
    // rev48-R7a: a big-drop winner gathers claims from up to 5 cells (claim.hlsl tests it from the 3 x 3 tiles)
    int R = (me.z > 0 && mc.z < 0.5 && r2BigWinner(c)) ? 5 : 2;
    [loop] for (int y = -R; y <= R; ++y) {
        [loop] for (int x = -R; x <= R; ++x) {
            if (x == 0 && y == 0) continue;
            int2 s = c + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            float4 cl = txR2Claim.Load(int3(s, 0));
            if (cl.z < 0.5 || any(int2(round(cl.xy)) != int2(-x, -y))) continue;
            float4 st = txR2State.Load(int3(s, 0));
            if (r2FilmJoin(st, r2Life(s), txR2FieldOld, float2(s) + st.xy)) st.z = 0.0;   // FILM S2-1 (joined the film)
            st.z -= r2SpillMM3(st, r2Life(s));                       // R1
            if (st.z <= 0) continue;
            float4 shs = r2Shape(s);
            float wa = r2FootW(st.z, shs);
            accV += st.z;
            accW += wa;
            accM += r2UnpackMove(st.w) * st.z;
            accP += (float2(x, y) + st.xy) * wa;
            r2ShapeAccAdd(sacc, shs, st.z, (float2(x, y) + st.xy) * gR2CellSizeMM);
            if (wa > bigW) {
                bigW = wa; w = st.w; life = r2Life(s); shape = shs;
                if (third == 3) { tailW = r2Tail(s); tailOld = float2(x, y) + st.xy; }
            }
        }
    }
    if (accV <= 0) return third == 3 ? float4(0, 0, 0, 0) : third == 2 ? float4(0, 0, r2PackHarm(0, 0), 0) : (lifeHalf ? float4(0, 0, 0, 0) : float4(0.4995, 0.4995, 0, r2PackMove(float2(0, 0), 0)));
    if (third == 2) return r2ShapeCompose(sacc, length(r2UnpackMove(w)) > 0.05);   // rev48-S3/S4 merged footprint; a moving head keeps its own
    float2 p = clamp(accP / max(accW, 1e-12), -0.75, 1.749);
    // B1: the winner (widest footprint) keeps its tail, which stays where it lies (the merged centre moved); the smaller
    // drops' tails go with their water into the head (their tail water is part of their volume)
    if (third == 3) return r2TailShift(tailW, (tailOld - p) * gR2CellSizeMM);
    float vMax = gR2ShapeK * gR2MaxRadiusMM * gR2MaxRadiusMM * gR2MaxRadiusMM;
    // the winner (widest footprint) gives seed / life / shape; the motion is the momentum of all of them, so a
    // head that runs into a wider pinned drop carries on from THAT position (the new head) instead of stopping
    float vOut = (gR2FilmOn > 0.5 && gR2Spill > 0.5) ? accV : min(accV, vMax);   // R1: the excess spills as film (field)
    return lifeHalf ? life : float4(p, vOut, r2PackMove(accM / accV, r2UnpackSeed(w)));
}
