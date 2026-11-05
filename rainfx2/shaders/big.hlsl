// rev48-R7a BIG-DROP TILES (docs/RAINFX_V2_PHYSICS_AUDIT.md H / R7a). Target: BG (ceil(cells / 4), RGBA32F).
// A drop is drawn by the pixels of +-2 cells (5 x 5 gather, ~2.3 mm), so a large / merged / elongated drop was fitted
// (shrunk) into that window. Each 4 x 4 cell tile names its LARGEST drop of drawn radius >= gR2BigRMM: the visor draws
// that one from the 3 x 3 tiles around a pixel (reach >= 4 cells = 4.6 mm), the claim / merge passes use the same
// window for its footprint (contact with drops up to 5 cells away). Built on the frame's final state (visor) = the
// state the next frame's claim / merge run on. Output: xy = cell, z = 1 present, w = volume.
float4 main(PS_IN pin) {
    int2 tl = int2(pin.PosH.xy);
    int2 size = int2(gR2Cells);
    float4 best = float4(0, 0, 0, 0);
    [unroll] for (int y = 0; y < 4; ++y) {
        [unroll] for (int x = 0; x < 4; ++x) {
            int2 s = tl * 4 + int2(x, y);
            if (any(s >= size)) continue;
            float4 st = txR2State.Load(int3(s, 0));
            if (st.z <= best.w || st.z <= 0) continue;
            float4 L = r2Life(s);
            if (L.y > 0 || L.z > 0) continue;                     // flying / fading drops stay in the fine window
            if (r2RadiusMM(st.z) < gR2BigRMM) continue;
            best = float4((float2)s, 1, st.z);
        }
    }
    return best;
}
