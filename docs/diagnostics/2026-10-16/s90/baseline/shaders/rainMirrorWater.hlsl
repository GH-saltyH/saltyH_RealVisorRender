// Mirror-only water highlights. No main-view captures, E1 bake, or glass FX.
float4 main(PS_IN pin) {
    clip(pin.Tex.x < -2.5 ? 1 : -1);
    float2 uv=float2(pin.Tex.x+4,pin.Tex.y+1);
    float valid=txMirrorBoundary.SampleLevel(samLinearClamp,uv,0).a;
    clip(valid-.5);
    float water=max(txMirrorHeads.SampleLevel(samLinearClamp,uv,0).g,
        txMirrorTrails.SampleLevel(samLinearClamp,uv,0).g);
    float coverage=smoothstep(.08,.5,water);clip(coverage-.001);
    float3 n=normalize(pin.NormalW),v=normalize(-pin.PosC);
    if(dot(n,v)<0)n=-n;
    float fresnel=.02+.98*pow(1-saturate(dot(n,v)),5);
    float3 halfVector=v+gMirrorLightDirection;
    float3 h=halfVector/max(length(halfVector),1e-6);
    float glint=pow(saturate(dot(n,h)),160)*coverage;
    float a=coverage*(.025+.15*fresnel);
    return float4(gMirrorLightColor*(glint*.4+a*.15),a);
}
