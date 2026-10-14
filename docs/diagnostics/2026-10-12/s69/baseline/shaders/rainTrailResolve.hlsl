// Appended to the existing sparse-word traversal. A single pass deposits
// current swept segments and decays previous history; no per-drop draw calls.
void rgEval(int i,float2 px,inout float4 acc) {
    float4 path=txTrailDescriptors.Load(int3(i,0,0));
    float4 shape=txTrailDescriptors.Load(int3(i,1,0));
    float4 frame=txTrailDescriptors.Load(int3(i,2,0));
    if(max(shape.y,frame.a)<=0)return;
    float2 a=px/gSize-path.xy,b=path.zw-path.xy;
    float2 delta=float2(frame.x*a.x+frame.y*a.y,frame.z*a.y);
    float2 travel=float2(frame.x*b.x+frame.y*b.y,frame.z*b.y);
    float t=saturate(dot(delta,travel)/max(dot(travel,travel),1e-18));
    float2 side=delta-travel*t;float d2=dot(side,side);
    // Integrate a subpixel footprint instead of letting a thin path disappear
    // between atlas rows. This is sampling support, never an artist texel width.
    float aa=.5*length(float2(frame.x/gSize,(abs(frame.y)+frame.z)*4/gSize));
    if(frame.a>0)acc.a=max(acc.a,.95*saturate((frame.a+aa-sqrt(d2))/max(aa,1e-9)));
    float sampledRadius=shape.x+aa*.5;
    if(shape.y<=0 || d2>=sampledRadius*sampledRadius)return;
    float k=saturate(1-d2/max(sampledRadius*sampledRadius,1e-18))*shape.x/max(sampledRadius,1e-9);
    float along=dot(delta,normalize(travel+float2(1e-15,0)))/max(shape.x*2,1e-8);
    // Thin films bead; thick ones stay continuous. No floor or plateau in sheets.
    float bead=.5+.5*sin(along*gNewTrailBeadCycles*6.2831853+float(i)*2.399963);
    float modulation=lerp(1,lerp(.15,1,bead*bead),gNewTrailNoise*(1-saturate(shape.y))*(1-shape.z));
    float ripple=1+gNewTrailSheetRipple*shape.z*sin(along*6.2831853+gNewTrailPhase);
    float height=min(shape.y*k*modulation*ripple,1);
    if(height>acc.g)acc.rgb=float3(shape.x*gNewTrailHeadSize/32,height,shape.z)*float3(height,1,height);
}
float4 ntHistory(float2 uv) {
    float4 p=txTrailPrevious.SampleLevel(samLinearClamp,uv,0);
    if(gNewTrailDiffuse>0 && p.g>1e-5) {
        float4 around=txTrailPrevious.SampleLevel(samLinearClamp,uv+float2(gNewTrailPixelUV.x,0),0)
            +txTrailPrevious.SampleLevel(samLinearClamp,uv-float2(gNewTrailPixelUV.x,0),0)
            +txTrailPrevious.SampleLevel(samLinearClamp,uv+float2(0,gNewTrailPixelUV.y),0)
            +txTrailPrevious.SampleLevel(samLinearClamp,uv-float2(0,gNewTrailPixelUV.y),0);
        p.rgb=lerp(p.rgb,around.rgb*.25,min(gNewTrailDiffuse,1));
    }
    float coat=saturate(txRainDv.SampleLevel(samLinearClamp,uv,0).a);
    float width=p.r/max(p.g,1e-7)*32/max(gNewTrailHeadSize,1);
    float sheet=saturate(p.b/max(p.g,1e-7));
    float diameter=2*width/max(gNewTrailWidthD*(1+gNewTrailWiden*sheet)*gRainReferencePerMM,1e-8);
    float life=gNewTrailSeconds*lerp(1,2.5,gNewTrailWet)*lerp(1,.4,coat)*(1+.5*smoothstep(.4,2.5,diameter));
    float dry=gNewTrailSupply<.001 && gNewTrailWet<.08 ? 2 : 1;
    p.rgb*=exp(-gNewTrailDt*1.05*dry/max(life,.05));
    p.a*=exp(-gNewTrailDt*3/max(gNewTrailWipeSeconds,.05));
    if(p.g<1e-4)p.rgb=0;if(p.a<1e-4)p.a=0;
    return p;
}
float4 ntResolve(float2 uv,float4 fresh) {
    float4 previous=ntHistory(uv);
    float4 result=previous;
    if(fresh.g>previous.g)result.rgb=fresh.rgb; // max, never additive thickening
    result.a=max(previous.a,fresh.a);
    return result;
}
