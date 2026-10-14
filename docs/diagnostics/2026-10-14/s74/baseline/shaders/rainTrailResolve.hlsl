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
    if(shape.y<=0)return; // Wipe-only work skips liquid integration/phase math.
    float2 tangent=normalize(travel+float2(1e-15,0));
    float2 normal=float2(-tangent.y,tangent.x);
    float2 pixelU=float2(frame.x/gSize,0);
    float2 pixelV=float2(frame.y*4/gSize,frame.z*4/gSize);
    float aaAcross=max(.5*(abs(dot(normal,pixelU))+abs(dot(normal,pixelV))),1e-9);
    float aaAlong=max(.5*(abs(dot(tangent,pixelU))+abs(dot(tangent,pixelV))),1e-9);
    float cornerRadius=.5*sqrt(dot(pixelU,pixelU)+dot(pixelV,pixelV)+2*abs(dot(pixelU,pixelV)));
    float sampledRadius=shape.x+(gNewTrailPixelIntegration>.5 ? cornerRadius : aa*.5);
    if(d2>=sampledRadius*sampledRadius)return;
    float k=saturate(1-d2/max(sampledRadius*sampledRadius,1e-18))*shape.x/max(sampledRadius,1e-9);
    if(gNewTrailPixelIntegration>.5) {
        // Closed-form box integral of the transverse parabolic film profile.
        // Average thickness is conserved as the path crosses atlas rows.
        float width=max(shape.x,1e-9),q=dot(side,normal);
        float lo=clamp(q-aaAcross,-width,width),hi=clamp(q+aaAcross,-width,width);
        k=max(0,(hi-lo-(hi*hi*hi-lo*lo*lo)/(3*width*width))/(2*aaAcross));
        float cap=abs(dot(side,tangent));
        k*=1-smoothstep(max(width-aaAlong,0),width+aaAlong,cap);
    }
    float beadResolved=gNewTrailBandlimit>.5 ? 1-smoothstep(.25,.5,
        gNewTrailBeadCycles*aaAlong/max(shape.x,1e-9)) : 1;
    float rippleResolved=gNewTrailBandlimit>.5 ? 1-smoothstep(.25,.5,
        aaAlong/max(shape.x,1e-9)) : 1;
    float modulationAmount=gNewTrailNoise*(1-saturate(shape.y))*(1-shape.z);
    float modulation=lerp(1,.46875,modulationAmount),ripple=1;
    if(beadResolved*modulationAmount>1e-5 || rippleResolved*gNewTrailSheetRipple*shape.z>1e-5) {
        float4 phase=txTrailDescriptors.Load(int3(i,4,0));
        float along=phase.x+dot(delta,tangent)/max(shape.x*2,1e-8);
        if(beadResolved*modulationAmount>1e-5) {
            float bead=.5+.5*sin(along*gNewTrailBeadCycles*6.2831853+float(i)*2.399963);
            float profile=lerp(.46875,lerp(.15,1,bead*bead),beadResolved);
            modulation=lerp(1,profile,modulationAmount);
        }
        if(rippleResolved*gNewTrailSheetRipple*shape.z>1e-5)
            ripple=1+gNewTrailSheetRipple*shape.z*rippleResolved*sin(along*6.2831853+gNewTrailPhase);
    }
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
    float outputScale=gNewTrailOutputDiameterScale>0 ? gNewTrailOutputDiameterScale : 1;
    float diameter=2*width/max(gNewTrailWidthD*(1+gNewTrailWiden*smoothstep(.3,.8,gNewTrailShear)*sheet)
        *gRainReferencePerMM*lerp(outputScale,1,sheet),1e-8);
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
