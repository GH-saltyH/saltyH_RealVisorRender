// rev47j P2b: trail geometry. Target: TG_next (field resolution, RGBA16F). Reads S_next, F_prev, TG_prev.
//   xy = nearest centre-line point of the rivulet through this texel (mm from the texel centre)
//   z  = direction of the rivulet (rad, visor mm space), w = half-width (mm)
// The centre-line depth is field R (field pass, same candidate rule r2TrailCand). The field (0.59 mm
// texels) cannot hold a 0.2-0.6 mm wide rivulet as a height map; storing the line itself lets the visor
// draw it sharp at any magnification (docs/RAINFX_V2_REV47J_REVIEW.md section 3).
float4 main(PS_IN pin) {
    int2 f = int2(pin.PosH.xy);
    float2 t = (float2(f) + 0.5) / gR2FieldSize;
    if (r2Valid(t) < 0.5) return float4(0, 0, 0, 0);
    float4 G = txR2Trail.Load(int3(f, 0));
    float4 F = txR2Field.Load(int3(f, 0));
    float2 pc = t * gR2Cells;
    int2 c0 = int2(floor(pc));
    int2 size = int2(gR2Cells);
    float wet = r2Wet(F);
    R2TrailHit h = r2TrailNone();
    [unroll] for (int y = -2; y <= 2; ++y) {
        [unroll] for (int x = -2; x <= 2; ++x) {
            int2 s = c0 + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            float4 st = txR2State.Load(int3(s, 0));
            if (st.z <= 0) continue;
            r2TrailCand(pc, s, st, wet, h);
        }
    }
    // A new rivulet replaces the stored line where it is at least comparable to the old water.
    float hOld = F.r * gR2TrailMaxMM;
    if (h.depth > 0 && h.depth >= 0.6 * hOld)
        G = float4((h.pt - pc) * gR2CellSizeMM, atan2(h.dir.y, h.dir.x), h.hwMM);
    return G;
}
