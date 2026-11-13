// H1b HAZE COALESCENCE (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 25). Shared by cells.hlsl (birth / merge) and haze.hlsl (the
// same water removed), both reading HZ_prev = txR2Haze. Micro drops on the coat coarsen by coalescence once they cover
// the surface to the breath-figure saturation (phi ~0.55, haze depth gR2HazeSatMM): the haze water above it in a cell
// gathers into drawn drops -- a Poisson event per cell and frame, rate = excess / (nucleus volume x coalescence time),
// a nucleus of random volume (x0.5-2 of gR2HazeNucVolMM3) at a random place (no same-size lattice: S1 failure).
int2 r2HazePerCell() { return max(int2(round(gR2HazeSize / gR2Cells)), int2(1, 1)); }
float r2HazeExcess(int2 c) {                                  // mm^3 above saturation in cell c
    int2 k = r2HazePerCell();
    float2 texMM2 = gR2CellSizeMM / float2(k);
    float v = 0;
    [loop] for (int y = 0; y < k.y; ++y) {
        [loop] for (int x = 0; x < k.x; ++x) {
            float g = max(txR2Haze.Load(int3(c * k + int2(x, y), 0)).g, 0.0) * gR2FineMaxMM;   // H3-3: coarse water
            v += max(g - gR2HazeTopMM, 0.0);                  // above the top octave (pieces at a_max)
        }
    }
    return v * texMM2.x * texMM2.y;
}
// rev40: inverse CDF of the fragment size law, X = (lo^-a + u (hi^-a - lo^-a))^(-1/a) (moved here from cells.hlsl: N1 uses it)
float r2FragX(float u) {
    return exp2(log2(max(lerp(gR2FragLoP, gR2FragHiP, u), 1e-6)) * gR2FragInvA);
}
// N1 HETEROGENEOUS NUCLEATION SITES (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 27). The H1b event rate was the same in every
// saturated cell -> one nucleus per cell at a jittered place = a lattice at the cell pitch (user, high-speed chase).
// Coalescence nuclei form first on surface defects (worn / soiled spots): the site weight is the J1 strong-defect field at
// the point, w = ((v - thr) / (1 - thr))^2 (same noise as r2DefectC), 0 on ~85 % of the area. Two random points of the cell
// per frame estimate the cell's mean w without bias; rate = excess / (nucleus volume x tau) x w / <w> (gR2HazeNucWInv =
// 1 / <w> of the noise, Lua) -> the same mean birth rate, gathered on the defect spots (irregular clusters / gaps, repeated
// births at the same spots); the place is the chosen point (continuous). Cells whose two points miss every defect skip the
// 16-texel excess sum (most cells). Their excess stays haze up to the runoff cap. Nucleus radius = fineNucRMM x X (fragment
// law: mixed sizes, 0.03-0.24 mm), the rate divides by the mean volume V_nuc <X^3> (gR2HazeNucM3Inv) -> the same water per
// second; a nucleus below the drawn size is no event (both passes see the same result: no water lost).
// Returns x = volume (mm^3, 0 = no event), y = the cell's excess vEx (mm^3), zw = place in the cell.
float r2NucSiteW(float2 pc) {                                 // pc in cells
    if (gR2HazeNucSite < 0.5 || gR2StrongK <= 0.0) return 1.0;
    float v = r2VNoise(pc * gR2CellSizeMM * gR2StrongInvMM + float2(5.1, 9.7));
    float e = max(0.0, (v - gR2StrongThr) / max(1.0 - gR2StrongThr, 1e-3));
    return e * e;
}
float4 r2HazeNucleus(int2 c) {
    if (gR2HazeNucOn < 0.5) return float4(0, 0, 0, 0);
    uint fk = (uint)gR2Frame * 8u + 9601u;
    float2 s0 = float2(r2Rand(uint3((uint)c.x, (uint)c.y, fk + 2u)), r2Rand(uint3((uint)c.y, (uint)c.x, fk + 3u)));
    float2 s1 = float2(r2Rand(uint3((uint)c.x, (uint)c.y, fk + 4u)), r2Rand(uint3((uint)c.y, (uint)c.x, fk + 5u)));
    float w0 = r2NucSiteW(float2(c) + s0), w1 = r2NucSiteW(float2(c) + s1);
    float wm = 0.5 * (w0 + w1);
    if (wm <= 0.0) return float4(0, 0, 0, 0);
    float vEx = r2HazeExcess(c);
    if (vEx <= 0.0) return float4(0, 0, 0, 0);
    float wK = (gR2HazeNucSite < 0.5 || gR2StrongK <= 0.0) ? 1.0 : gR2HazeNucWInv;
    // H3-3 (docs/RAINFX_V2_H3_ATLAS_SPEC.md 4.2, 8f): a cell drop is born only when the cell's coarse water above the top
    // octave is enough for a drop of a_max (gR2HazeNucVolMM3 = shapeK a_max^3) -- smaller drops are the atlas pieces.
    // N1b rate cap: at most gR2HazeNucPMax per cell and 1/60 s (births spread in time; the new drop's halo then takes up
    // the neighbours' water = the depletion that sets the spacing); the drop takes 60-100 % of the cell's excess.
    if (vEx < gR2HazeNucVolMM3) return float4(0, 0, 0, 0);
    float lam = vEx / max(gR2HazeNucVolMM3, 1e-9) * gR2FrameDt / max(gR2HazeNucTau, 1e-3) * wm * wK;
    float pEv = min(1.0 - exp(-lam), gR2HazeNucPMax * gR2FrameDt * 60.0);
    if (r2Rand(uint3((uint)c.x, (uint)c.y, fk)) >= pEv) return float4(0, 0, 0, 0);
    float vB = vEx * lerp(0.6, 1.0, r2Rand(uint3((uint)c.y, (uint)c.x, fk + 1u)));
    float2 pN = r2Rand(uint3((uint)c.x, (uint)c.y, fk + 6u)) * (w0 + w1) < w0 ? s0 : s1;
    return float4(vB, vEx, pN);
}

// N3 / T1: exact distance from a swept segment to a cell rectangle (mm). 0 if the segment enters the rectangle (slab clip),
// else the minimum of its end points to the rectangle and the rectangle corners to the segment (separated convex shapes).
float r2BoxDist(float2 p, float2 lo, float2 hi) {
    float2 d = max(max(lo - p, p - hi), 0.0);
    return length(d);
}
float r2SegBoxDist(float2 a, float2 b, float2 lo, float2 hi) {
    float2 ab = b - a;
    float t0 = 0.0, t1 = 1.0;
    [unroll] for (int k = 0; k < 2; ++k) {
        if (abs(ab[k]) < 1e-9) {
            if (a[k] < lo[k] || a[k] > hi[k]) t0 = 2.0;
        } else {
            float u0 = (lo[k] - a[k]) / ab[k], u1 = (hi[k] - a[k]) / ab[k];
            t0 = max(t0, min(u0, u1));
            t1 = min(t1, max(u0, u1));
        }
    }
    if (t0 <= t1) return 0.0;
    float d = min(r2BoxDist(a, lo, hi), r2BoxDist(b, lo, hi));
    d = min(d, min(r2SegDist(lo, a, b), r2SegDist(hi, a, b)));
    d = min(d, min(r2SegDist(float2(lo.x, hi.y), a, b), r2SegDist(float2(hi.x, lo.y), a, b)));
    return d;
}


// T1 SUBSTEP WIPE MASK (docs/RAINFX_V2_H3_ATLAS_SPEC.md section 8m, wm.hlsl): per cell the swept share of its haze texels
// (<= 4 x 4), 4 bits each (0..15 / 15), slot j = (texel x - c x k.x) + 4 (texel y - c y k.y); x slots 0-5, y 6-11, z 12-15
// (integers < 2^24: exact in fp32).
float r2WmGet(float4 w, int j) {
    uint word = (uint)(j < 6 ? w.x : (j < 12 ? w.y : w.z));
    uint sh = 4u * (uint)(j < 6 ? j : (j < 12 ? j - 6 : j - 12));
    return (float)((word >> sh) & 15u) / 15.0;
}
