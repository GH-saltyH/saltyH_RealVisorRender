// E3 MASS AUDIT (docs/RAINFX_V2_S_REVIEW.md section 7). Target: 96 x 8 RGBA32F, read back by Lua every ~0.5 s while the audit is on.
// Each output texel sums one block (32 x 8 blocks of the visor) of one reservoir set, in mm^3 (or mm^2 for areas):
//   x  0..31 (field / cells): R = drop volume (cells of the block, S), G = film volume (B), B = trail volume (R),
//                             A = exposed area sum(exposure x texel area) (rain / spray inflow = flux x A)
//   x 32..63 (haze, 2x res) : R = G_f volume, G = G_c volume, B = area of texels at the fine cap (G_f >= cap: runoff),
//                             A = area at the coarse cap (G_c >= 2 x top: runoff)
//   x 64..95 (counts)       : R = trail wet area, G = number of drops, B = drops at the largest cap (spill / old clamp), A = visor area
//   x 96..127 (E4 tails, sums): R = big drops (r >= gR2BigRMM), G = big drops moving >= 0.1 m/s, B = drops with s = Ca/Ca* > 1
//                             (the trail / tail rule), A = drops with a tail (S quarter 3)
//   x 128..159 (E4, maxima)   : R = fastest big drop (m/s), G = largest s, B = sum of the coat theta_r (deg, B1d) at big drops >= 0.1 m/s, A = longest tail L (mm)
float4 main(PS_IN pin) {
    int2 o = int2(pin.PosH.xy);
    int seg = (int)((uint)o.x / 32u);                              // uint: FXC X3556
    int2 b = int2(o.x - seg * 32, o.y);
    float4 r = float4(0, 0, 0, 0);
    float2 texMM = gR2CellSizeMM * gR2Cells / gR2FieldSize;
    float aF = texMM.x * texMM.y;
    float vMax = gR2ShapeK * gR2MaxRadiusMM * gR2MaxRadiusMM * gR2MaxRadiusMM;
    if (seg >= 3) {
        int2 cs = int2(uint2(gR2Cells) / uint2(32u, 8u));
        [loop] for (int cy = 0; cy < cs.y; ++cy) {
            [loop] for (int cx = 0; cx < cs.x; ++cx) {
                int2 c = b * cs + int2(cx, cy);
                float4 st = txR2State.Load(int3(c, 0));
                if (st.z <= 0) continue;
                float rmm = r2RadiusMM(st.z);
                float v = length(r2UnpackMove(st.w) * gR2CellSizeMM) * 1e-3 / max(gR2SimDt, 1e-5);
                float2 tc = (float2(c) + st.xy) / gR2Cells;
                float phi = r2HazePhiAround(tc, rmm);
                r2CoatSet(tc, txR2Field.SampleLevel(samLinearClamp, tc, 0));      // B1d
                float sR = r2TailExcess(rmm, v, r2Wet(txR2Field.SampleLevel(samLinearClamp, tc, 0)), phi);
                R2Tail T = r2TailUnpack(r2Tail(c));
                bool big = rmm >= gR2BigRMM;
                if (seg == 3) {
                    r.r += big ? 1.0 : 0.0;
                    r.g += big && v >= 0.1 ? 1.0 : 0.0;
                    r.b += sR > 1.0 ? 1.0 : 0.0;
                    r.a += T.on ? 1.0 : 0.0;
                } else {
                    r.r = big ? max(r.r, v) : r.r;
                    r.g = max(r.g, sR);
                    r.b += big && v >= 0.1 ? degrees(radians(gR2TrailThetaRDeg) * r2CoatF) : 0.0;   // E4 (B1d): coat theta_r at moving big drops
                    r.a = max(r.a, T.L);
                }
            }
        }
    } else if (seg == 0 || seg == 2) {
        int2 fs = int2(uint2(gR2FieldSize) / uint2(32u, 8u));
        [loop] for (int y = 0; y < fs.y; ++y) {
            [loop] for (int x = 0; x < fs.x; ++x) {
                int2 f = b * fs + int2(x, y);
                float4 F = txR2Field.Load(int3(f, 0));
                float hT = F.r * gR2TrailMaxMM;
                if (seg == 0) {
                    r.g += F.b * gR2FilmMaxMM * aF;
                    r.b += hT * aF;
                    float ex = F.a >= 1.5 ? F.a - 2.0 : F.a;          // field A = exposure (+2 x film mobile)
                    r.a += ex * aF;
                } else {
                    r.r += hT > 1e-5 ? aF : 0.0;
                    r.a += F.a > 0.0 ? aF : 0.0;                       // valid texels carry their exposure (> 0 on the visor)
                }
            }
        }
        int2 cs = int2(uint2(gR2Cells) / uint2(32u, 8u));
        [loop] for (int cy = 0; cy < cs.y; ++cy) {
            [loop] for (int cx = 0; cx < cs.x; ++cx) {
                float4 st = txR2State.Load(int3(b * cs + int2(cx, cy), 0));
                if (st.z <= 0) continue;
                if (seg == 0) r.r += st.z;
                else { r.g += 1.0; r.b += st.z >= 0.999 * vMax ? 1.0 : 0.0; }
            }
        }
    } else {
        int2 hs = int2(uint2(gR2HazeSize) / uint2(32u, 8u));
        float2 hMM = gR2CellSizeMM * gR2Cells / gR2HazeSize;
        float aH = hMM.x * hMM.y;
        [loop] for (int y = 0; y < hs.y; ++y) {
            [loop] for (int x = 0; x < hs.x; ++x) {
                float2 G = max(txR2Haze.Load(int3(b * hs + int2(x, y), 0)).rg, 0.0) * gR2FineMaxMM;
                r.r += G.x * aH;
                r.g += G.y * aH;
                r.b += G.x >= 0.999 * gR2HazeCapMM ? aH : 0.0;
                r.a += G.y >= 0.999 * 2.0 * gR2HazeTopMM ? aH : 0.0;
            }
        }
    }
    return r;
}
