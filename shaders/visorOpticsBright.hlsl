// Extract excess HDR energy BEFORE building the blur mip chain. A uniform
// bright sky is not a collection of light sources. Preserve source hue.
float3 optExtract(float2 uv,float threshold) {
    float3 c=max(txOptScene.SampleLevel(samPointClamp,saturate(uv),0).rgb,0);
    float lum=dot(c,float3(.2126,.7152,.0722));
    return c*max(lum-threshold,0)/max(lum,.000001);
}
float4 main(PS_IN pin) {
    float3 average=max(txOptAverage.SampleLevel(samLinearClamp,float2(.5,.5),gOptSceneMaxMip).rgb,0);
    float threshold=max(gOptBrightThreshold,dot(average,float3(.2126,.7152,.0722))*gOptBrightRelative);
    // Half-size target: extract each full-size source texel independently,
    // then average excess energy. Never threshold an already blurred light.
    float2 step=gOptBrightInvSource*.5;
    return float4((optExtract(pin.Tex+step,threshold)+optExtract(pin.Tex-step,threshold)
        +optExtract(pin.Tex+step*float2(1,-1),threshold)
        +optExtract(pin.Tex+step*float2(-1,1),threshold))*.25,0);
}
