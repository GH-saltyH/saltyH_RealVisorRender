// rev48-W1d SHEET NUCLEATION (docs/RAINFX_V2_WATER_SHEET_PLAN.md section 7.3). Target: NM (gR2Cells, RGBA16F),
// once per frame on S_next (after the cells substeps). R = 1: the drops of this cell join the sheet (field pass of
// this frame adds them, merge pass of the next frame removes them -- same S, same NM). G = coverage, B = drop
// water depth (mm) of the 5x5-cell cluster, A = share of its cells that hold sheet water (F_prev, W1f).
// A sheet forms where the visor is wet enough: the drops of a cluster are dense (coverage >= gR2SheetNucPhi, the
// steady coverage of dropwise wetting ~0.5) and hold a sheet's worth of water (mean depth >= gR2SheetHJoin), and an
// impact lamella (radius ~ 1-2 cells) lands among them this frame and bridges them (expected rate, 3x3 cells).
float4 main(PS_IN pin) {
    int2 c = int2(pin.PosH.xy);
    float2 t = (float2(c) + 0.5) / gR2Cells;
    if (gR2SheetOn < 0.5 || r2Valid(t) < 0.5) return float4(0, 0, 0, 0);
    float3 du = r2ToWorld(r2Tap(txR2Du, t).xyz);
    float3 dv = r2ToWorld(r2Tap(txR2Dv, t).xyz);
    float cellArea = length(cross(du, dv)) / (gR2Cells.x * gR2Cells.y);   // m^2
    float lambda = gR2ImpactRate * cellArea * r2Exposure(t) * gR2Exposure * gR2Dt;   // impacts per cell per frame
    uint fr = (uint)gR2Frame * 8u + 9100u;
    bool hit = false;
    [unroll] for (int iy = -1; iy <= 1; ++iy) {
        [unroll] for (int ix = -1; ix <= 1; ++ix) {
            uint2 e = uint2(c + int2(ix, iy));
            if (r2Rand(uint3(e.x, e.y, fr)) < lambda) hit = true;
        }
    }
    int2 size = int2(gR2Cells);
    float V = 0, A = 0, n = 0, aS = 0;   // aS: cells of the window whose mean water (F_prev) is sheet (W1f)
    [loop] for (int y = -2; y <= 2; ++y) {
        [loop] for (int x = -2; x <= 2; ++x) {
            int2 s = c + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            n += 1;
            aS += txR2Field.SampleLevel(samLinearClamp, (float2(s) + 0.5) / gR2Cells, 0).b * gR2FilmMaxMM >= gR2SheetHJoin ? 1.0 : 0.0;
            float4 st = txR2State.Load(int3(s, 0));
            if (st.z <= 0) continue;
            float4 L = r2Life(s);
            if (L.y > 0 || L.z > 0) continue;                 // flying / fading drops are not on the visor
            float r = r2RadiusMM(st.z);
            V += st.z;
            A += 3.14159265 * r * r;
        }
    }
    float area = max(n, 1.0) * gR2CellSizeMM.x * gR2CellSizeMM.y;
    float phi = A / area, D = V / area;
    float nuc = (hit && gR2ImpactRate > 0 && phi >= gR2SheetNucPhi && D >= gR2SheetHJoin) ? 1.0 : 0.0;
    return float4(nuc, phi, D, aS / max(n, 1.0));   // A: sheet area share (W1f connected sheet)
}
