float4 main(PS_IN pin) {
    float cosine=saturate(dot(normalize(pin.NormalW),gOptLightWorld));
    return float4(cosine,cosine,cosine,1);
}
