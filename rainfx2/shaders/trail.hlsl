// TR0 (docs/RAINFX_V2_TRAIL_REVIEW2.md section 6) TRAIL GEOMETRY, run after EVERY cells substep on that substep's S_next.
// Target: TG_next (field resolution, RGBA32F, r2TgPack); reads TG_prev (the previous substep / frame) and F_prev.
// rev47j stored the line itself (point, direction, half-width) because the 0.59 mm field cannot hold a 0.1-0.5 mm rivulet
// as a height map; rev47j-48 ran once per frame with the 5 x 5 cells around the texel, which only sees a drop whose END
// cell is within +-2 cells -- a head moving > ~3 cells / frame left only the last ~3 mm of each frame's path: the
// repeated short bars of the user's image. Per substep (<= 1.95 cells each) every point of the path is recorded.
// The swept segment is the move of the frame so far (cells accumulates it), its duration gR2Dt = i x h (Lua) -> the trail
// rule sees the mean speed of the frame. A line is replaced where the new one is at least comparable to the water there
// (the field's trail water or this frame's line), and is tagged with this frame (fresh; field lays its depth once).
float4 main(PS_IN pin) {
    int2 f = int2(pin.PosH.xy);
    float2 t = (float2(f) + 0.5) / gR2FieldSize;
    if (r2Valid(t) < 0.5) return float4(0, 0, 0, 0);
    float4 G = txR2Trail.Load(int3(f, 0));
    float4 F = txR2Field.Load(int3(f, 0));
    float2 pc = t * gR2Cells;
    int2 c0 = int2(floor(pc));
    int2 size = int2(gR2Cells);
    float wet = r2WetU(F, t);                                      // FILM-UNIFY A: one wetness
    r2CoatSet(t, F);                                               // B1d: coat state here (trail rule)
    R2TrailHit h = r2TrailNone();
    [loop] for (int y = -2; y <= 2; ++y) {
        [loop] for (int x = -2; x <= 2; ++x) {
            int2 s = c0 + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            float4 st = txR2State.Load(int3(s, 0));
            if (st.z <= 0) continue;
            r2TrailCand(pc, s, st, wet, h);
        }
    }
    float hOld = max(F.r * gR2TrailMaxMM, r2TgFresh(G) ? r2TgDepth(G) : 0.0);
    if (h.depth > 0 && h.depth >= 0.6 * hOld)
        G = r2TgPack((h.pt - pc) * gR2CellSizeMM, atan2(h.dir.y, h.dir.x), h.hwMM, h.depth);
    else if (G.w > 1e-4 && !r2TgFresh(G))
        G = r2TgOld(G);                                            // not refreshed this frame: a broken line (bead row)
    return G;
}
