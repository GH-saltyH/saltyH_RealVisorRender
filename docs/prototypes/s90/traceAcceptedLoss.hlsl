// Manual-test probe for the same gate an eventual runoff consumer must use.
// Not an additional steady pass in the proposed integration.
float4 main(PS_IN pin) {
    int2 p=min((int2)(pin.Tex*float2(gTestLeaves,gTestRows)),int2(gTestLeaves,gTestRows)-1);
    float accepted=txTraceAcceptance.Load(int3(0,0,0)).r;
    return accepted>.5 ? txTestLeaves.Load(int3(p+int2(0,(int)gTestRows),0)) : 0;
}
