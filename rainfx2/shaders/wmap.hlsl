// rev29 CSP windscreen water map, ported to the visor (docs/RAINFX_V2_CSP_DROP_SHADING.md section 5).
// Target: WM_next (gR2WMSize, RGBA16F, mips). Reads WM_prev and the drop cells S.
//   CSP pfxWindscreen_ps : each drop is a FLAT-TOPPED disc with a soft edge and a faint skirt,
//                          its outline modulated by low-frequency noise (x 0.8..1.4), stretched
//                          along the velocity of a sliding drop; accumulated into the water map.
//   CSP accRainWindscreen_move : a = saturate(1.08 a - 0.04) - 0.005 (1 - |v|)  -- sharpens the
//                          water edges every frame; what a drop leaves behind stays as a trace.
// Here the stamps come from the cell state (5x5 gather), the previous map is sharpened and decays
// (gR2WMDecay /s, so traces fade on the visor instead of waiting for a wiper), new = max(stamp, old).
//   x = stamp this frame, y = sharpened shape, z = strength (decays), w = height read by the visor

float wmFade(float d, float split) {
    // CSP: fade = saturate(remap(d, 1 - split, 1, 1, 0)); fade = max(fade, saturate(remap(d, 1, 2, 1, 0)) * 0.2)
    float f = saturate((1.0 - d) / max(split, 1e-3));
    return max(f, saturate(2.0 - d) * gR2WMSkirt);
}

float4 main(PS_IN pin) {
    int2 f = int2(pin.PosH.xy);
    float2 t = (float2(f) + 0.5) / gR2WMSize;
    float4 prev = txR2WMap.Load(int3(f, 0));
    if (r2Valid(t) < 0.5) return float4(0, 0, 0, 0);
    float2 pc = t * gR2Cells;
    int2 c0 = int2(floor(pc));
    int2 size = int2(gR2Cells);
    float stamp = 0.0;
    [loop] for (int y = -2; y <= 2; ++y) {
        [loop] for (int x = -2; x <= 2; ++x) {
            int2 s = c0 + int2(x, y);
            if (any(s < int2(0, 0)) || any(s >= size)) continue;
            float4 st = txR2State.Load(int3(s, 0));
            if (st.z <= 0) continue;
            float r = max(r2RadiusMM(st.z) * gR2WMScale, gR2WMMinMM);   // rev30 visor scale
            float2 q = (pc - (float2(s) + st.xy)) * gR2CellSizeMM;      // mm from the drop centre
            float seed = r2UnpackSeed(st.w);
            // sliding: stretch along the frame's move (CSP: quad lengthened by speed, both sides)
            float2 mv = r2UnpackMove(st.w) * gR2CellSizeMM;
            float ml = length(mv);
            if (ml > 1e-4) {
                float2 m = mv / ml;
                float a = dot(q, m);
                q -= m * a * (1.0 - 1.0 / (1.0 + gR2WMStretch * ml / r));
            }
            // quad half-size: the soft edge (d 0.5..1) is centred on the drop radius
            float Rq = r / (1.0 - 0.5 * gR2WMSplit);
            float2 tq = q / Rq;
            if (dot(tq, tq) > 4.0) continue;
            // CSP: pin.Tex *= lerp(0.8, 1.4, noise(Tex * 0.1 + seed)) -> irregular outline
            float2 np = tq * 1.5 + float2(seed * 7.31, seed * 3.17);
            float2 ip = floor(np), fp = np - ip;
            fp = fp * fp * (3.0 - 2.0 * fp);
            float n00 = frac(sin(dot(ip, float2(127.1, 311.7))) * 43758.5453);
            float n10 = frac(sin(dot(ip + float2(1, 0), float2(127.1, 311.7))) * 43758.5453);
            float n01 = frac(sin(dot(ip + float2(0, 1), float2(127.1, 311.7))) * 43758.5453);
            float n11 = frac(sin(dot(ip + float2(1, 1), float2(127.1, 311.7))) * 43758.5453);
            float nz = lerp(lerp(n00, n10, fp.x), lerp(n01, n11, fp.x), fp.y);
            tq *= lerp(1.0, lerp(0.8, 1.4, nz), gR2WMNoise);
            stamp = max(stamp, wmFade(length(tq), gR2WMSplit));
        }
    }
    // CSP move: edge sharpening of the SHAPE (y). CSP's 1.08a - 0.04 has a fixed point at 0.5 and
    // drives everything above it to 1 (CSP clears traces with wipers / waterFade), so the fade is a
    // separate strength (z) that decays exponentially; the visor reads w = shape x strength.
    float shape = max(stamp, saturate(1.08 * prev.y - 0.04));
    float strength = max(stamp, prev.z * exp(-gR2WMDecay * gR2Dt));
    if (strength < 0.02) shape = 0.0;
    return float4(stamp, shape, strength, shape * strength);
}
