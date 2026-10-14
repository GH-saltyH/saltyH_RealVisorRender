float optHash(float2 p) {return frac(sin(dot(p,float2(127.1,311.7))+gOptSeed)*43758.5453);}
float optNoise(float2 p) {
    float2 a=floor(p),f=frac(p);f=f*f*(3-2*f);
    return lerp(lerp(optHash(a),optHash(a+float2(1,0)),f.x),
        lerp(optHash(a+float2(0,1)),optHash(a+1),f.x),f.y);
}
float4 main(PS_IN pin) {
#if OPT_MASK_TEXTURE
    float4 pattern=txOptPattern.SampleLevel(samLinearClamp,frac(pin.Tex),0);
    return float4(saturate(pattern.r*gOptDensity),saturate(pattern.g*gOptScratchDensity),pattern.b,saturate(pattern.a*gOptDensity));
#else
    float2 uv=pin.Tex,center=float2(.5,.9),q=uv-center;
    float radius=length(q),angle=atan2(q.y,q.x);
    float cluster=.55+.3*optNoise(uv*7)+.15*optNoise(uv*21);
    float grains=pow(optNoise(uv*180),5);
    float dust=saturate(cluster*(.2+grains)*gOptDensity);
    float arc=pow(saturate(.5+.5*sin(radius*650+optNoise(float2(angle*9,0))*2)),22);
    float scratch=arc*pow(optNoise(uv*25),3)*gOptScratchDensity;
    float tangent=frac((angle+1.57079633)/6.28318531+1);
    float smudge=pow(optNoise(uv*4),3)*(.6+.4*sin(radius*180+angle*2));
    return float4(dust,scratch,tangent,saturate(smudge));
#endif
}
