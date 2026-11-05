// P1b (rev6): coalescence claim. Target: C (gR2Cells, RGBA16F), reads S after P1.
// Two drops whose contact discs touch (d < gR2CoalesceK * (r1 + r2)) merge in reality
// at once. One drop per cell cannot express touching neighbours, so without this step a
// saturated visor becomes a regular lattice of equal drops (rev5 defocus made the
// lattice visible as a woven texture). Each drop claims the LARGEST touching neighbour
// that ranks above it (volume, then cell index); the merge pass moves its volume there.
// Output: xy = offset of the absorbing cell, z = 1 if claimed.

float r2CellIndex(int2 s) { return (float)s.y * gR2Cells.x + (float)s.x; }

float4 main(PS_IN pin) {
    int2 c = int2(pin.PosH.xy);
    int2 size = int2(gR2Cells);
    float4 me = txR2State.Load(int3(c, 0));
    float4 Lm = r2Life(c);
    if (me.z <= 0 || Lm.y > 0 || Lm.z > 0) return float4(0, 0, 0, 0);   // rev45: flying / fading drops do not merge
    // rev45 sweep merge (rule_merge 1, 6): a drop that moved last frame merges with every drop its
    // path came within contact distance of, not only the ones touching its end position.

    float rm = r2RadiusMM(me.z);
    float4 shM = r2Shape(c);                                  // rev48-S3b footprint inputs
    float wetM = 0.0;                                         // rev48-S4: footprint uses the stored flatness
    float2 pm = float2(c) + me.xy;
    float2 am = pm - r2UnpackMove(me.w);                     // where it came from last frame
    float im = r2CellIndex(c);
    // rev48-S4b: rank by FOOTPRINT AREA (the merged drop gathers where the wider footprint was, merge.hlsl)
    float wM = r2FootW(me.z, shM);
    float bestV = 0, bestI = -1;
    int2 best = int2(0, 0);
    // rev48-R7a: ONE [loop] (FXC failed silently on the unrolled 5 x 5 + a second tile loop): candidates 0-24 = the
    // 5 x 5 cells, 25-33 = the big-drop winners of the 3 x 3 tiles around that lie 3-5 cells away (a big drop's
    // footprint reaches beyond the 5 x 5 window; merge.hlsl gathers that far for a winner)
    uint nCand = gR2BigOn > 0.5 ? 34u : 25u;
    int2 tc = int2((uint2)c >> 2);
    [loop] for (uint ci = 0u; ci < nCand; ++ci) {
        int2 o;
        if (ci < 25u) {
            o = int2((int)(ci % 5u) - 2, (int)(ci / 5u) - 2);
            if (o.x == 0 && o.y == 0) continue;
        } else {
            uint cj = ci - 25u;
            int2 tt = tc + int2((int)(cj % 3u) - 1, (int)(cj / 3u) - 1);
            if (any(tt < int2(0, 0)) || any(tt * 4 >= size)) continue;
            float4 bg = txR2Big.Load(int3(tt, 0));
            if (bg.z < 0.5) continue;
            o = int2(round(bg.xy)) - c;
            int om = max(abs(o.x), abs(o.y));
            if (om <= 2 || om > 5) continue;                         // in the fine window already / too far
        }
        int2 s = c + o;
        if (any(s < int2(0, 0)) || any(s >= size)) continue;
        float4 st = txR2State.Load(int3(s, 0));
        if (st.z <= 0) continue;
        float4 Ls = r2Life(s);
        if (Ls.y > 0 || Ls.z > 0) continue;
        float is = r2CellIndex(s);
        float4 shS = r2Shape(s);
        float wS = r2FootW(st.z, shS);
        if (wS < wM || (wS == wM && is < im)) continue;             // must rank above me
        float2 ps = float2(s) + st.xy;
        float2 as = ps - r2UnpackMove(st.w);
        float dc = min(r2SegDist(ps, am, pm), r2SegDist(pm, as, ps));   // cells, segment vs point
        // rev48-S6c E8: a fresh split piece sits on its parent's path -- end positions only (no sweep)
        if ((r2SplitChild(Lm) && Lm.x < 0.3) || (r2SplitChild(Ls) && Ls.x < 0.3)) dc = length(ps - pm);
        float dmm = dc * gR2CellMM;
        // rev48-S3b: footprint radii toward each other (resting spread x merged tensor = what is drawn)
        float2 dirMM = (ps - pm) * gR2CellSizeMM;
        float rmF = r2FootRadiusMM(c, me, shM, wetM, dirMM);
        float rsF = r2FootRadiusMM(s, st, shS, 0.0, -dirMM);
        if (dmm >= gR2CoalesceK * (rmF + rsF)) continue;
        if (wS > bestV || (wS == bestV && is > bestI)) {
            bestV = wS; bestI = is; best = o;
        }
    }
    return bestI >= 0 ? float4((float2)best, 1, 0) : float4(0, 0, 0, 0);
}
