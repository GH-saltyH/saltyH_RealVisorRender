// rev48-W1 WATER SHEET FLOW (docs/RAINFX_V2_WATER_SHEET_PLAN.md sections 2.2, 6), gR2SheetSub substeps per
// frame. Target: F (field size, RGBA16 UNorm); only B (sheet / film height h) changes, R G A are copied.
// Mass-conserving finite volumes: every face carries the upwind cell's flux h v.n dt / dx (<= 0.24 h per
// face and substep, CFL), v(h) = K.xy h + K.zw h^2 (air shear + gravity, lubrication), |v| <= gR2SheetUMax.
// A wet cell spills into a DRY neighbour (h < gR2SheetHJoin) only when h >= gR2SheetFront (advancing contact
// line: thin edges stay pinned -> fronts, fingers). Surface tension: antisymmetric face exchange
// gR2SheetSmooth (h_j - h_i) between wet neighbours. Water flowing off the visor (outside the mask) is gone.
float r2SheetOut(int2 f, float h, float hDst, int2 d, float2 mmPerUV) {
    float4 K = txR2SheetK.Load(int3(f, 0));
    float2 v = K.xy * h + K.zw * (h * h);                     // uv / s
    float vmm = length(v * mmPerUV) * 1e-3;                  // m/s
    v *= vmm > gR2SheetUMax ? gR2SheetUMax / vmm : 1.0;
    float c = max(dot(v, float2(d)), 0.0) * gR2SheetDt * (abs(d.x) > 0 ? gR2FieldSize.x : gR2FieldSize.y);
    float o = min(c, 0.24) * h;
    return (hDst < gR2SheetHJoin && h < gR2SheetFront) ? 0.0 : o;
}

float4 main(PS_IN pin) {
    int2 f = int2(pin.PosH.xy);
    float2 t = (float2(f) + 0.5) / gR2FieldSize;
    float4 F = txR2Field.Load(int3(f, 0));
    float4 res = float4(0, 0, 0, 0);
    if (r2Valid(t) > 0.5) {
        float2 mmPerUV = gR2CellSizeMM * gR2Cells;
        int2 fmax = int2(gR2FieldSize) - 1;
        float h = F.b * gR2FilmMaxMM;
        float hN = h;
        int2 dirs[4] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1) };
        [unroll] for (int k = 0; k < 4; ++k) {
            int2 d = dirs[k];
            int2 g = f + d;
            bool inside = all(g >= int2(0, 0)) && all(g <= fmax) && r2Valid((float2(g) + 0.5) / gR2FieldSize) > 0.5;
            float hg = inside ? txR2Field.Load(int3(g, 0)).b * gR2FilmMaxMM : 0.0;
            hN -= r2SheetOut(f, h, hg, d, mmPerUV);                    // out of me toward g (lost if g is outside)
            if (inside) {
                hN += r2SheetOut(g, hg, h, -d, mmPerUV);               // out of g toward me
                if (h >= gR2SheetHJoin && hg >= gR2SheetHJoin) hN += gR2SheetSmooth * (hg - h);
                // rev48-W1f RECEDING CONTACT LINE (W1e review: a moving sheet faded out -- its rear left water below
                // the threshold, which broke up): thin water next to a CONNECTED sheet retracts into it (dewetting
                // rim, gR2SheetRetract /s), antisymmetric -> conservative. The sheet keeps its water and grows with
                // the drops it takes on its way.
                float kR = saturate(gR2SheetRetract * gR2SheetDt) * 0.25;
                if (h < gR2SheetHJoin && hg >= gR2SheetHJoin && r2SheetConnected(r2SheetNucAt(r2CellOfTexel(g)))) hN -= kR * h;
                if (h >= gR2SheetHJoin && hg < gR2SheetHJoin && r2SheetConnected(r2SheetNucAt(r2CellOfTexel(f)))) hN += kR * hg;
            }
        }
        res = float4(F.r, F.g, saturate(max(hN, 0.0) / gR2FilmMaxMM), F.a);
    }
    return res;
}
