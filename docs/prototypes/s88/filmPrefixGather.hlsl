float4 main(PS_IN pin) {
    int2 p=min((int2)(pin.Tex*gTestGrid),(int2)gTestGrid-1);
    int2 axis=gTestAxis<.5 ? int2(1,0) : int2(0,1);
    // No max(0): negative stock must be exposed as a failed positivity gate,
    // rather than clipping and silently creating water.
    return txTestPackets.Load(int3(p,0))+txTestFlux.Load(int3(p,0))-txTestFlux.Load(int3(p+axis,0));
}
