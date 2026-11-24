// B2 TAIL RASTER (docs/RAINFX_V2_TRAIL_REVIEW3.md sections 11.4, 20, B3a 22). Target: TT (HALF the field size, RGBA32F), once per frame on the final
// state, after the big-drop tiles. A tail (S quarter 3: head-relative centre-line points q1..q3, length L) is part of its drop
// and reaches up to ~14 r -- beyond the drop's own draw window -- so its surface is rasterised here and the visor adds it to
// the drop union (one water surface: head + tail, W0 prototype B). Tails of the big drops (r >= gR2BigRMM, one per 4 x 4 tile)
// within +-3 tiles (~14 mm). Profile (W0): half-width w = 0.75 r (1 - xi)^0.8, centre height h = 0.55 h_cap (1 - xi)^0.6,
// xi = 0 at the head's rear edge .. 1 at the end; parabolic section. The highest tail at the texel is kept as a LINE (nearest
// centre-line point, direction, w, h) so the visor draws it sub-texel sharp (the 0.59 mm texel only holds the geometry).
// Output (B3g, section 29): raster rows x = packQ(centre-line point - texel centre, +-8 mm), y = tile index + 4096 x arc a
// (12 bit, -8..56 mm), z = direction (rad), w = 1; TP rows (below the raster, one texel per big-drop tile) = the tail constants
// (r2TailTPPack). The visor evaluates r2TailProf exactly at its own arc position (B3d slope extrapolation drew spikes).
// Former output (B3d/e): x = packQ(centre-line point - texel centre, +-8 mm; neck fraction nk), y = pack((dw/ds, dh/ds), 2), z = direction (rad) + 8 x end arc,
// w = 1 + r2TailPack2((w, h), 4) (0 = no tail).
// B3a (section 22, reference flow study section 21): the head goes over a NECK (one head radius) into a thin RIVULET of nearly
// constant width, not a tadpole taper: neck 0.6 r -> w_r, rivulet half-width / depth = the trail rule at the head's speed and coat
// (r2TrailRule: hw = 0.5 trailWidthK r sqrt(1 - 1/s), h = trailLL r Ca^2/3 <= edge slope), end taper over the last 15 %, a
// Rayleigh-Plateau varicose +-15 % (spacing 9 w_r, phase fixed on the visor). TT is half resolution (1.18 mm texels, reach
// +-4 tiles ~19 mm): a texel keeps the line nearest to it within w + 1 texel (the visor evaluates the line exactly per pixel).
// B3c (section 24; B3b game test: debug 4 shows the VOLUME radius r, the visor draws the head larger -- cap scale of its flatness,
// aspect ellipse, sliding rear stretch 1 + k): the tail was laid out in r, so its neck lay under the drawn head and only a thin
// rivulet stuck out (tadpole / stick). The tail is now measured from the DRAWN head (r2DrawnRadiiMM, = the visor silhouette):
// it starts at the drawn rear edge (the drawn rear beyond r is tail water already: visible length L - (R_rear - r)), the neck
// leaves the head outline at its own width (ellipse) and narrows over 2.1 W to the rivulet; rivulet half-width scales with the
// drawn half-width W: 0.5 tailWidthK W sqrt(1 - 1/s) >= 0.2 W (B3d default tailWidthK 0.6: <= 0.3 W, flow study 0.2-0.3 D).
// B3g: the constants of one tail (head s), in two parts so the raster can reject by arc before the trail rule (field samples):
// r2TailHead = drawn head (rear R_rear, side W), visible length Lv, dIn; r2TailRiv = neck / rivulet (trail rule, coat state).
float4 r2TailHead(int2 s, float4 st, R2Tail T, out float vms, out float dRr) {      // -> (dIn, W, R_rear, Lv)
    float rmm = r2RadiusMM(st.z);
    vms = length(r2UnpackMove(st.w) * gR2CellSizeMM) * 1e-3 / max(gR2SimDt, 1e-5);
    float2 dR0 = length(T.q1) > 1e-4 ? normalize(T.q1) : float2(0, -1);
    float2 RW2 = r2DrawnRadiiMM(s, st, dR0, vms, true);          // s = the tile's big drop (big-tile window)
    dRr = max(RW2.x - rmm, 0.0);                                 // drawn rear beyond r = tail water under the head
    return float4(0.5 * min(RW2.y, RW2.x), RW2.y, RW2.x, T.L - dRr);
}
void r2TailRiv(int2 s, float4 st, float4 HD, float vms, float2 totMM, out float4 PP, out float4 PH, out float vph) {
    float rmm = r2RadiusMM(st.z);
    float2 h0 = (float2(s) + st.xy) * gR2CellSizeMM;
    // L2b: the head's REAR rim angle (theta_drop - hysteresis / 2: the sliding head recedes at its rear)
    float c30 = cos(radians(gR2TailNeckDeg)), s30 = max(sin(radians(gR2TailNeckDeg)), 1e-3);
    float dIn = HD.x, Ws = HD.y, Rr = HD.z;
    // the rivulet of the trail rule at this head (speed of the frame's move, coat state at the head)
    float2 tH = h0 / totMM;
    float4 Fh = txR2Field.SampleLevel(samLinearClamp, tH, 0);
    r2CoatSet(tH, Fh);
    float hwR = 0.0;
    float hR = r2TrailRule(rmm, vms, r2Wet(Fh), hwR);
    // B3c: the rivulet scales with the DRAWN head half-width W (trail rule: hw = 0.5 trailWidthK r sqrt(1 - 1/s))
    hwR *= (gR2TailWidthK / max(gR2TrailWidthK, 1e-3)) * (Ws / max(rmm, 1e-3));
    hwR = max(hwR, 0.2 * Ws);                                    // a slowing head keeps a rivulet (it decays with L)
    hR = max(hR, 0.25 * hwR * gR2TrailSlopeMax);
    // L2 (section 57): the neck starts at the head centre with half-width W. L2b (section 58): its height is the head cap's own
    // height at rho_n = gR2TailNeckRho of the radius (L2 used the full apex W tan(theta / 2): the cylinder then lay ABOVE the
    // whole rear half of the spherical head, which vanished under its tail -- user 2026-11-25). Now the head stays on top over
    // rho < rho_n and the tail rises out of it only on the rear rim (the neck), laterally the steeper head rim stays higher.
    float rn = saturate(gR2TailNeckRho);
    float hc = Ws * (sqrt(max(1.0 - rn * rn * s30 * s30, 0.0)) - c30) / s30;
    float w0 = Ws;
    vph = 1.7 * (float)(s.x + 3 * s.y);
    PP = float4(Rr, Ws, w0, hwR);                                // L2: x = distance rear edge -> head centre
    PH = float4(hc, hR, HD.w, 1.0 / max(9.0 * hwR, 0.05));
}
float4 main(PS_IN pin) {
    int2 f = int2(pin.PosH.xy);
    float2 ttSize = floor(gR2FieldSize * 0.5);
    int2 tn = int2((uint2(gR2Cells) + 3u) >> 2);
    float2 totMM = gR2CellSizeMM * gR2Cells;
    float4 res = float4(0, 0, 0, 0);
    bool on = gR2TailOn > 0.5 && gR2BigOn > 0.5 && tn.x * tn.y <= 4096;
    if (f.y >= (int)ttSize.y) {
        // B3g TP rows: the constants of the tail of big-drop tile (f.x, f.y - raster rows)
        int2 tt = int2(f.x, f.y - (int)ttSize.y);
        if (on && all(tt < tn)) {
            float4 b = txR2Big.Load(int3(tt, 0));
            int2 s = int2(b.xy);
            float4 st = txR2State.Load(int3(s, 0));
            R2Tail T = r2TailUnpack(r2Tail(s));
            if (b.z > 0.5 && st.z > 0 && T.on && T.L >= 0.05) {
                float vms, dRr;
                float4 HD = r2TailHead(s, st, T, vms, dRr);
                float4 PP = float4(0, 0, 0, 0), PH = float4(0, 0, 0, 0); float vph = 0.0;
                r2TailRiv(s, st, HD, vms, totMM, PP, PH, vph);
                if (HD.w >= 0.05) res = r2TailTPPack(PP, PH, vph);
            }
        }
    }
    float2 t = (float2(f) + 0.5) / ttSize;
    if (f.y < (int)ttSize.y && on && r2Valid(t) > 0.5) {            // (no early return: FXC X4000 on main)
        float2 pMM = t * totMM;
        float texMM = max(totMM.x / ttSize.x, totMM.y / ttSize.y);
        int2 tc = int2((uint2)int2(t * gR2Cells) >> 2);
        float bestS = -1e9;
        [loop] for (uint it = 0u; it < 81u; ++it) {          // B3c: one flat loop over the 9 x 9 tiles (FXC /O3 stack overflow on the nested pair)
            int tx = (int)(it % 9u) - 4, ty = (int)(it / 9u) - 4;
            int2 tt = tc + int2(tx, ty);
            if (any(tt < int2(0, 0)) || any(tt >= tn)) continue;
            float4 b = txR2Big.Load(int3(tt, 0));
            if (b.z < 0.5) continue;
            int2 s = int2(b.xy);
            float4 st = txR2State.Load(int3(s, 0));
            if (st.z <= 0) continue;
            R2Tail T = r2TailUnpack(r2Tail(s));
            if (!T.on || T.L < 0.05) continue;
            float rmm = r2RadiusMM(st.z);
            float2 h0 = (float2(s) + st.xy) * gR2CellSizeMM;
            float reach = rmm + T.L + 4.0 + texMM;                  // B3c: + the widest drawn neck (w <= 3.9)
            if (dot(pMM - h0, pMM - h0) > reach * reach) continue;
            float2 P[4] = { h0, h0 + T.q1, h0 + T.q2, h0 + T.q3 };
            float arcTot = length(T.q1) + length(T.q2 - T.q1) + length(T.q3 - T.q2);
            float rear = max(arcTot - T.L, 0.0);
            float bd = 1e9, bArc = 0.0;
            float2 bQ = h0, bT = float2(1, 0);
            float acc = 0.0;
            [unroll] for (int k = 0; k < 3; ++k) {
                float2 ab = P[k + 1] - P[k];
                float l2 = dot(ab, ab);
                float u = l2 > 1e-10 ? saturate(dot(pMM - P[k], ab) / l2) : 0.0;
                float2 q = P[k] + ab * u;
                float d = length(pMM - q);
                if (d < bd && l2 > 1e-10) { bd = d; bArc = acc + u * sqrt(l2); bQ = q; bT = ab * rsqrt(l2); }
                acc += sqrt(l2);
            }
            if (bd > 4.0 + texMM) continue;                           // beyond any neck / rivulet (w <= 3.9)
            float vms = 0.0, dRr = 0.0;
            float4 HD = r2TailHead(s, st, T, vms, dRr);
            if (HD.w < 0.05) continue;
            float a = bArc - rear - dRr;                             // B3c: mm behind the DRAWN rear edge
            if (a < -HD.z || a > HD.w) continue;                     // L2: from the head centre / past the end
            float4 PP = float4(0, 0, 0, 0), PH = float4(0, 0, 0, 0); float vph = 0.0;
            r2TailRiv(s, st, HD, vms, totMM, PP, PH, vph);
            float2 wh = r2TailProf(a, dot(bQ, bT) * PH.w, vph, PP, PH);
            float w = wh.x, h = wh.y;
            if (w < 0.02 || bd > w + texMM) continue;
            float sc = bd < w ? h * (1.0 - (bd / w) * (bd / w)) : -(bd - w);
            if (sc > bestS) {
                bestS = sc;
                int tIdx = tt.x + tn.x * tt.y;
                float aq = clamp(round((a + 8.0) / 64.0 * 4095.0), 0.0, 4095.0);
                res = float4(r2TailPackQ(bQ - pMM, 0.0), (float)tIdx + 4096.0 * aq, atan2(bT.y, bT.x), 1.0);
            }
        }
    }
    return res;
}
