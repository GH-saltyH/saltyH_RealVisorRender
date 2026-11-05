// rev48-W1 WATER SHEET FLOW (docs/RAINFX_V2_WATER_SHEET_PLAN.md sections 2.2, 6), gR2SheetSub substeps per
// frame. Target: F (field size, RGBA16 UNorm); only B (sheet / film height h) changes, R G A are copied.
// Mass-conserving finite volumes: every face carries the upwind cell's flux h v.n dt / dx (<= 0.24 h per
// face and substep, CFL), v(h) = K.xy h + K.zw h^2 (air shear + gravity, lubrication), |v| <= gR2SheetUMax.
// A wet cell spills into a DRY neighbour (h < gR2SheetHJoin) only when h >= gR2SheetFront (advancing contact
// line: thin edges stay pinned -> fronts, fingers). Surface tension: antisymmetric face exchange
// gR2SheetSmooth (h_j - h_i) between wet neighbours. Water flowing off the visor (outside the mask) is gone.
// rev48-W1r: only the MOBILE water above the deposited wet layer hRes moves, at the velocity of the mobile thickness:
// thin parts barely move, thick heads run ahead and collect (v ~ h, h^2) -- the drainage gathers into its leading flows
float2 r2SheetVel(int2 f, float hm, float2 mmPerUV) {
    float4 K = txR2SheetK.Load(int3(f, 0));
    float2 v = K.xy * hm + K.zw * (hm * hm);                  // uv / s
    float vmm = length(v * mmPerUV) * 1e-3;                  // m/s
    return v * (vmm > gR2SheetUMax ? gR2SheetUMax / vmm : 1.0);
}
float r2SheetOut(int2 f, float h, float hRes, float hDst, float hcDst, bool wetDst, int2 d, float2 mmPerUV) {
    float hm = max(h - hRes, 0.0);
    float2 v = r2SheetVel(f, hm, mmPerUV);
    float c = max(dot(v, float2(d)), 0.0) * gR2SheetDt * (abs(d.x) > 0 ? gR2FieldSize.x : gR2FieldSize.y);
    float o = min(c, 0.24) * hm;
    return (!wetDst && hDst < hcDst && h < gR2SheetFront) ? 0.0 : o;
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
        float hcF = r2SheetHAtTexel(f);                                // rev48-W1i (fed: thinner sheet)
        bool wetF = r2WetTx(txR2Field, t);
        // rev48-W1s FURMIDGE PINNING OF PATCHES (W1r review: remnant patches raced off -- a 0.2 mm patch has a free-film
        // gravity speed of ~0.13 m/s -- spread thin and dissolved): an isolated patch on dry surface is held by contact-angle
        // hysteresis like a drop (critical length ~ gamma dcos / (rho g h) ~ several mm); only water above sheetPinMM or a
        // connected sheet flows. It moves once it is fed / joined into a sheet.
        bool conF = r2SheetConnected(r2SheetNucAt(r2CellOfTexel(f)));
        float hRF = wetF ? gR2SheetWetMM : (conF ? 0.0 : gR2SheetPinMM);
        float hmF = max(h - hRF, 0.0);
        float2 vF = r2SheetVel(f, hmF, mmPerUV);
        int2 dirs[4] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1) };
        [unroll] for (int k = 0; k < 4; ++k) {
            int2 d = dirs[k];
            int2 g = f + d;
            bool inside = all(g >= int2(0, 0)) && all(g <= fmax) && r2Valid((float2(g) + 0.5) / gR2FieldSize) > 0.5;
            float hg = inside ? txR2Field.Load(int3(g, 0)).b * gR2FilmMaxMM : 0.0;
            int2 gc = clamp(g, int2(0, 0), fmax);
            float hcG = r2SheetHAtTexel(gc);
            bool wetG = r2WetTx(txR2Field, (float2(gc) + 0.5) / gR2FieldSize);
            float hRG = wetG ? gR2SheetWetMM : (r2SheetConnected(r2SheetNucAt(r2CellOfTexel(gc))) ? 0.0 : gR2SheetPinMM);
            hN -= r2SheetOut(f, h, hRF, hg, hcG, wetG, d, mmPerUV);         // out of me toward g (lost if g is outside)
            if (inside) {
                hN += r2SheetOut(g, hg, hRG, h, hcF, wetF, -d, mmPerUV);    // out of g toward me
                // rev48-W1r DRAINAGE GATHERING (user: wide water should converge toward its leading flow, not move as one
                // slab): across the flow, mobile water drifts toward the thicker neighbour (faster water draws the film in,
                // the start of rivulets). Symmetric in (f, g) -> exact antisymmetric exchange; bounded by the thinner side.
                float hmG = max(hg - hRG, 0.0);
                // W1s: compared on 2-texel means (f, f - d) vs (g, g + d) -- the texel-pair antidiffusion grew a period-2
                // checker (the surface grid of the W1r review) and flow-parallel streaks
                int2 gF = clamp(f - d, int2(0, 0), fmax), gG = clamp(g + d, int2(0, 0), fmax);
                float hF2 = 0.5 * (hmF + max(txR2Field.Load(int3(gF, 0)).b * gR2FilmMaxMM - hRF, 0.0));
                float hG2 = 0.5 * (hmG + max(txR2Field.Load(int3(gG, 0)).b * gR2FilmMaxMM - hRG, 0.0));
                if (gR2SheetGatherK > 0 && hmF > 0 && hmG > 0) {
                    float2 vG = r2SheetVel(g, hmG, mmPerUV);
                    float2 va = 0.5 * (vF + vG);
                    float sp = length(va);
                    if (sp > 1e-9) {
                        float lat = 1.0 - abs(dot(va / sp, normalize(float2(d) / float2(gR2FieldSize))));
                        float cl = sp * gR2SheetDt * min(gR2FieldSize.x, gR2FieldSize.y);
                        float ex = gR2SheetGatherK * lat * min(cl, 0.24) * min(hmF, hmG)
                                 * clamp(3.0 * (hG2 - hF2) / max(hG2 + hF2, 1e-5), -1.0, 1.0);
                        hN += min(ex, 0.1 * hmG) * (ex > 0 ? 1.0 : 0.0) + max(ex, -0.1 * hmF) * (ex < 0 ? 1.0 : 0.0);
                    }
                }
                if (h >= hcF && hg >= hcG) hN += gR2SheetSmooth * (hg - h);
                // rev48-W1f RECEDING CONTACT LINE (W1e review: a moving sheet faded out -- its rear left water below
                // the threshold, which broke up): thin water next to a CONNECTED sheet retracts into it (dewetting
                // rim, gR2SheetRetract /s), antisymmetric -> conservative. The sheet keeps its water and grows with
                // the drops it takes on its way.
                float kR = saturate(gR2SheetRetract * gR2SheetDt) * 0.25;
                // W1j: only true residue next to a well-formed sheet (the bare threshold test was anti-diffusion -> dot lattice)
                // W1r: not on wetted surface (the deposited layer stays)
                if (!wetF && h < 0.5 * hcF && hg >= 1.5 * hcG && r2SheetConnected(r2SheetNucAt(r2CellOfTexel(g)))) hN -= kR * h;
                if (!wetG && h >= 1.5 * hcF && hg < 0.5 * hcG && r2SheetConnected(r2SheetNucAt(r2CellOfTexel(f)))) hN += kR * hg;
            }
        }
        res = float4(F.r, F.g, saturate(max(hN, 0.0) / gR2FilmMaxMM), F.a);
    }
    return res;
}
