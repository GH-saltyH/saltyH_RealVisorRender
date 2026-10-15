// R32FLOAT staging for SDK floatValue(), only on explicit log request.
float4 main(PS_IN pin) {
    uint count=gBirthFilmOn>.5 ? 12u : 8u;
    uint i=min((uint)(pin.Tex.x*count),count-1u);
    float4 v=txBirthTotals.Load(int3(0,i<8u ? i/4u : 4u,0));
    uint channel=i%4u;float x=channel==0u ? v.x : channel==1u ? v.y : channel==2u ? v.z : v.w;
    return float4(x,0,0,0);
}
