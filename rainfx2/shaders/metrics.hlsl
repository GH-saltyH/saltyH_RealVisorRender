// rev12 evaluation metrics. Target: 32x8 RGBA8 (render.TextureFormat.R8G8B8A8.UNorm),
// read back with accessData every ~0.5 s and logged (docs/RAINFX_V2_CORE.md section 19).
// Each output texel summarises one block of the visor (field 32x32 texels, cells 16x16):
//   R = film cover fraction (W thickness >= gR2FilmMinMM)       over valid texels
//   G = drop area cover      (sum pi r^2 / cell area, per cell <= 1) over valid cells
//   B = mean micro haze M
//   A = valid fraction of the block (weight for the CPU average)

float4 main(PS_IN pin) {
    int2 b = int2(pin.PosH.xy);
    int2 fs = int2(uint2(gR2FieldSize) / uint2(32u, 8u));
    int2 cs = int2(uint2(gR2Cells) / uint2(32u, 8u));
    float valid = 0, film = 0, haze = 0;
    [loop] for (int y = 0; y < fs.y; y += 2) {
        [loop] for (int x = 0; x < fs.x; x += 2) {
            int2 f = b * fs + int2(x, y);
            float2 t = (float2(f) + 0.5) / gR2FieldSize;
            if (r2Tap(txR2Mask, t).a < 0.5) continue;
            float4 F = txR2Field.Load(int3(f, 0));
            valid += 1;
            film += F.b * gR2FilmMaxMM >= gR2FilmMinMM ? 1 : 0;
            haze += F.g;
        }
    }
    float cv = 0, cover = 0;
    float cellArea = gR2CellSizeMM.x * gR2CellSizeMM.y;
    [loop] for (int cy = 0; cy < cs.y; ++cy) {
        [loop] for (int cx = 0; cx < cs.x; ++cx) {
            int2 c = b * cs + int2(cx, cy);
            float2 t = (float2(c) + 0.5) / gR2Cells;
            if (r2Tap(txR2Mask, t).a < 0.5) continue;
            cv += 1;
            float4 st = txR2State.Load(int3(c, 0));
            float r = r2RadiusMM(st.z);
            cover += min(3.14159 * r * r / cellArea, 1.0);
        }
    }
    float n = max(valid, 1.0);
    return float4(film / n, cover / max(cv, 1.0), haze / n, valid / max(float(fs.x * fs.y) * 0.25, 1.0));
}
