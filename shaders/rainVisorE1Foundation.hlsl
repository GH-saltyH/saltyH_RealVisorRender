// Independent E1 foundation; no shared visor shader resources.
float4 main(PS_IN pin) {
 float3 eye=normalize(-pin.PosC);
 float3 normal=normalize(pin.NormalW);
 float3 direction=normalize(reflect(eye,normal));
 if(gE1Debug>0.5) return float4(direction*0.5+0.5,1);
 float forward=dot(direction,gE1Look);
 if(forward<=0.001) return float4(0,0,0,0);
 float2 uv=float2(dot(direction,gE1Side)/gE1Aspect,-dot(direction,gE1Up))/(forward*gE1TanFov)*0.5+0.5;
 if(any(uv<=0)||any(uv>=1)) return float4(0,0,0,0);
 float ior=max(gE1IOR,1.01);
 float f0=(ior-1)/(ior+1);f0*=f0;
 float f=f0+(1-f0)*pow(1-saturate(abs(dot(normal,eye))),5);
 return float4(max(txE1Source.SampleLevel(samLinearClamp,uv,0).rgb,0)*f*gE1Gain,0);
}
