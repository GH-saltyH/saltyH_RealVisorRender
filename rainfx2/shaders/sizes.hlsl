// rev40 drop size histogram (docs/RAINFX_V2_DROP_PIPELINE_PLAN.md step 2 verification).
// Target: 10 x 16 RGBA8 UNorm (rev41: 8 -> 10 bins from 0.04 mm), read back with the metrics (~2 Hz, only while metrics are on).
// Texel (bin, stripe): number of drops in radius bin `bin` among the cell rows of `stripe`
// (gR2Cells.y / 16 rows). Bins are 1.5x wide from gR2SizeBin0MM; the last bin is open.
// Count = R * 255 * 256 + G * 255 (two exact bytes, max 65535).

float4 main(PS_IN pin) {
    int2 b = int2(pin.PosH.xy);
    int rows = (int)max((uint)gR2Cells.y / 16u, 1u);            // uint divide (FXC X3556)
    int cols = int(gR2Cells.x);
    float lo = gR2SizeBin0MM * exp2(0.5849625 * (float)b.x);      // log2(1.5)
    float hi = b.x >= 9 ? 1e9 : lo * 1.5;
    float n = 0;
    [loop] for (int y = 0; y < rows; ++y) {
        [loop] for (int x = 0; x < cols; ++x) {
            float4 st = txR2State.Load(int3(x, b.y * rows + y, 0));
            if (st.z <= 0) continue;
            float r = r2RadiusMM(st.z);
            n += (r >= lo && r < hi) ? 1.0 : 0.0;
        }
    }
    n = min(n, 65535.0);
    float hb = floor(n / 256.0);
    return float4(hb / 255.0, (n - hb * 256.0) / 255.0, 0, 1);
}
