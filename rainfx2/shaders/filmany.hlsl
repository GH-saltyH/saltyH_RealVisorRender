// F4b FILM GATE (docs/RAINFX_V2_FILM_S2_DESIGN.md section 10). Target: 32x8 RGBA8, read back with accessData (async, 1-3 frames).
// R = 1 if a field texel of the block (32 x 32 texels, every 2nd) holds film (>= gR2FilmWetMM) or a mobile body (A >= 2).
// Lua runs the film transport only while some block is set (game test: film 0.216 ms on a visor without film).
float4 main(PS_IN pin) {
    int2 b = int2(pin.PosH.xy);
    int2 fs = int2(uint2(gR2FieldSize) / uint2(32u, 8u));
    float hit = 0.0, mob = 0.0, thick = 0.0;                       // R = film >= wet, G = mobile flag, B = thick film >= gR2FilmThickMM
    [loop] for (int y = 0; y < fs.y; y += 2) {
        [loop] for (int x = 0; x < fs.x; x += 2) {
            float4 F = txR2Field.Load(int3(b * fs + int2(x, y), 0));
            if (F.b * gR2FilmMaxMM >= gR2FilmWetMM) hit = 1.0;
            if (F.a >= 1.5) mob = 1.0;
            if (F.b * gR2FilmMaxMM >= gR2FilmThickMM) thick = 1.0;
        }
    }
    return float4(hit, mob, thick, 1.0);
}
