// rev48-W1t PATCH -> DROP (W1s review: settled remnant patches looked like oily residue and ignored the drops; real residual
// water rounds up into a cap by surface tension). Target: BM (gR2Cells, RGBA32F), once per frame BEFORE the cells substeps,
// on F_prev. A cell c beads the isolated patch around it when (event rate gR2PatchBeadRate):
//   its cell-mean film >= sheetKeepMM and it is the maximum of the 5x5 cells (tie-break by index), not wet, not a connected
//   sheet, no lamella of the 5x5 cells still recoiling; every patch texel (h >= keep / 2) lies in the inner 3x3 cells (the
//   outer ring is dry: isolated) and the patch volume is a drop (<= vMax).
// Out: R = patch volume (mm^3), GB = water centroid (cell units, relative to the cell origin), A = 1.
// The same frame the cells pass bears / feeds the drop of c with R and the field pass removes those texels' F_prev water:
// exact, one patch = one drop (no per-cell grid of beads, W1m-n). Windows of two beads never share a counted texel.
bool r2LamEncActiveB(float enc) {
    if (enc < 0.5) return false;
    float age = gR2Frame - (floor(enc) - 1.0);
    return age >= -1.0 && age <= 24.0;                         // registry of the last frame (lam runs after this pass)
}
float4 main(PS_IN pin) {
    int2 c = int2(pin.PosH.xy);
    float2 t = (float2(c) + 0.5) / gR2Cells;
    if (gR2SheetOn < 0.5 || gR2PatchBeadRate <= 0 || r2Valid(t) < 0.5) return float4(0, 0, 0, 0);
    if (r2Rand(uint3((uint)c.x, (uint)c.y, (uint)gR2Frame * 8u + 9300u)) >= gR2PatchBeadRate * gR2FrameDt) return float4(0, 0, 0, 0);
    float keep = gR2SheetKeepMM;
    float hc = r2CellFilmMM(c);
    if (hc < keep || r2WetTx(txR2Field, t) || r2SheetConnected(r2SheetNucAt(c))) return float4(0, 0, 0, 0);
    int2 size = int2(gR2Cells);
    int idc = c.y * size.x + c.x;
    [loop] for (int y = -2; y <= 2; ++y) {
        [loop] for (int x = -2; x <= 2; ++x) {
            int2 s = c + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            float4 lm = txR2Lam.Load(int3(s, 0));
            // W1v: recoiling lamellae no longer block (their residuals become drops themselves, W1u); only a lamella born on
            // this cell's own patch within the last 2 frames does (its spread is not settled water)
            float ageX = gR2Frame - (floor(lm.x) - 1.0);
            if (lm.x > 0.5 && ageX >= 0.0 && ageX < 2.0 && x == 0 && y == 0) return float4(0, 0, 0, 0);
            if (x == 0 && y == 0) continue;
            float hs = r2CellFilmMM(s);
            if (hs > hc || (hs == hc && s.y * size.x + s.x < idc)) return float4(0, 0, 0, 0);
        }
    }
    int2 k = r2FieldPerCell();
    int2 f0 = (c - 2) * k;
    int2 fmax = int2(gR2FieldSize) - 1;
    float2 texMM2 = gR2CellSizeMM * gR2Cells / gR2FieldSize;
    float ta = texMM2.x * texMM2.y;
    float V = 0;
    float2 P = float2(0, 0);
    [loop] for (int ty = 0; ty < 5 * k.y; ++ty) {
        [loop] for (int tx = 0; tx < 5 * k.x; ++tx) {
            int2 f = f0 + int2(tx, ty);
            if (any(f < int2(0, 0)) || any(f > fmax)) continue;
            float h = txR2Field.Load(int3(f, 0)).b * gR2FilmMaxMM;
            if (h < keep) continue;                                       // W1v: only the patch itself, not its thin halo
            // W1w (rest-state simulation): no isolation test -- a larger patch beads piecewise (dewetting splits a puddle
            // into several drops); the bead takes the patch water of its own 3x3 cells. Bead cells are 5x5 maxima, >= 3
            // cells apart, so their 3x3 windows never overlap (field removes the same texels).
            bool ring = tx < k.x || ty < k.y || tx >= 4 * k.x || ty >= 4 * k.y;
            if (ring) continue;
            V += h * ta;
            P += h * ta * ((float2(f) + 0.5) / float2(k));                // cell units
        }
    }
    float vMax = gR2ShapeK * gR2MaxRadiusMM * gR2MaxRadiusMM * gR2MaxRadiusMM;
    float vMin = gR2ShapeK * gR2MinRadiusMM * gR2MinRadiusMM * gR2MinRadiusMM;
    if (V <= vMin || V > vMax) return float4(0, 0, 0, 0);
    return float4(V, P / V - float2(c), 1.0);
}
