// Bridge actual SI predictor output + physical mm3 stock into remap packet.
float4 main(PS_IN pin) {
    int2 p=min((int2)(pin.Tex*gFilmGrid),(int2)gFilmGrid-1);
    float volume=poolAvailable(p+(int)gFilmPad);
    float2 uv=(p+.5)/gFilmGrid;float3 u,v;rainMetric(float2(uv.x,uv.y-1),u,v);
    float2 velocity=txFilmPredicted.Load(int3(p,0)).rg;
    float3 world=mul(u,(float3x3)gFilmObjectToWorld)*velocity.x+mul(v,(float3x3)gFilmObjectToWorld)*velocity.y;
    return float4(volume,world*volume);
}
