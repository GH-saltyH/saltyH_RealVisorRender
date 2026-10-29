// rev48-W1 sheet velocity coefficients (docs/RAINFX_V2_WATER_SHEET_PLAN.md section 2.2), once per frame.
// Target: K (field size, RGBA32F): v(h) = K.xy h + K.zw h^2 in field uv / s, h in mm (r2SheetCoef).
float4 main(PS_IN pin) {
    int2 f = int2(pin.PosH.xy);
    float2 t = (float2(f) + 0.5) / gR2FieldSize;
    return r2Valid(t) > 0.5 ? r2SheetCoef(t) : float4(0, 0, 0, 0);
}
