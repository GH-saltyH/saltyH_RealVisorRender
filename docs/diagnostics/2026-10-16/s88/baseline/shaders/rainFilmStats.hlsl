float4 main(PS_IN pin) {
    uint i=min((uint)(pin.Tex.x*16),15u);
    float4 v=txFilmTotals.Load(int3(0,i/4u,0));
    return v[i%4u];
}
