float4 main(PS_IN pin) {
    float visibility=gOptExternalShadow;
    if(gOptProbeReady>.5) {
        float3 measured=txOptProbe.SampleLevel(samLinearClamp,float2(.5,.5),5).rgb;
        float cosine=txOptProbeExpected.SampleLevel(samLinearClamp,float2(.5,.5),5).r;
        float expected=.05*gOptSunLum*cosine*gOptProbeGain;
        if(expected>1e-5)visibility=saturate(dot(max(measured,0),float3(.2126,.7152,.0722))/expected);
    }
    if(gOptSunOnScreen>.5) {
        float sky=0;
        [unroll]for(int y=-2;y<=2;y++)[unroll]for(int x=-2;x<=2;x++) {
            float depth=txOptDepth.SampleLevel(samPointClamp,gOptSunUV+float2(x,y)*gOptInvTarget,0).r;
            if(gOptReversedDepth>.5)depth=1-depth;
            sky+=depth>.99999?1:0;
        }
        visibility*=sky/25;
    }
    float previous=txOptPrevious.SampleLevel(samPointClamp,float2(.5,.5),0).r;
    visibility=lerp(previous,visibility,gOptSunBlend);
    return float4(visibility,visibility,visibility,1);
}
