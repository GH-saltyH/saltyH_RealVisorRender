// One descriptor per current GPU slot, no CPU readback or predicted centres.
// Reference length is physical metres / gRainMetersPerUnit; UV is independent.
float2 ntPlane(float2 d,float3 f) {return float2(f.x*d.x+f.y*d.y,f.z*d.y);}
float ntValid(float2 uv) {
    uint w=1u,h=1u;txRainBoundaryMask.GetDimensions(w,h);
    float boundary=txRainBoundaryMask.Load(int3(clamp(int2(uv*float2(w,h)),int2(0,0),int2(w-1,h-1)),0)).a;
    txRainDu.GetDimensions(w,h);
    float support=txRainDu.Load(int3(clamp(int2(uv*float2(w,h)),int2(0,0),int2(w-1,h-1)),0)).a;
    return min(boundary,support);
}
float4 main(PS_IN pin) {
    uint i=(uint)min(floor(pin.Tex.x*gCount),gCount-1);
    uint row=(uint)floor(pin.Tex.y*5);
    float4 s=txRainState.Load(int3(i,0,0)),m=txRainStateMeta.Load(int3(i,0,0));
    float4 old=txRainPreviousState.Load(int3(i,0,0)),om=txRainPreviousMeta.Load(int3(i,0,0));
    float4 metric=txRainDropMetric.Load(int3(i,0,0));float3 f=metric.rgb;
    float2 endUV=float2(s.x,s.y+1),startUV=float2(old.x,old.y+1);
    float modelScale=max(gNewTrailModelDiameterScale,1);
    float outputScale=gNewTrailOutputDiameterScale>0 ? gNewTrailOutputDiameterScale : 1;
    float radius=max(m.r,0)*modelScale;
    float diameter=2*radius/max(gRainReferencePerMM,1e-8);
    float outputRadius=radius*outputScale;
    float status=m.a-4*floor(m.a/4),previousStatus=om.a-4*floor(om.a/4);
    float hold=gNewTrailBirthHold*(.6+.8*frac(sin(float(i)*12.9898+78.233)*43758.5453));
    float4 splash=txOverride.Load(int3(i,0,0));
    bool valid=status==1 && previousStatus==1 && floor(m.a/4)==floor(om.a/4)
    && metric.a>.5 && radius>0 && (gNewTrailLifecycle<.5 || m.b>=hold)
    && !(splash.a>.5 && splash.r<.95) && all(startUV>=0) && all(startUV<=1)
    && all(endUV>=0) && all(endUV<=1);
    float moved=length(ntPlane(endUV-startUV,f));
    valid=valid && moved>1e-8 && moved*gRainMetersPerUnit<.128;
    // Reject holes / unsupported atlas joins. These are descriptor work, not
    // repeated per visor pixel. Boundary never wraps.
    if(valid) {
        [unroll] for(uint k=0u;k<5u;++k) {
            float2 uv=lerp(startUV,endUV,float(k)*.25);
            if(ntValid(uv)<.5) valid=false;
        }
    }
    float4 result=float4(0,0,0,0);
    if(!valid) {
        result=row==3u ? float4(2e9,2e9,-2e9,-2e9) : float4(0,0,0,0);
        // A pinned/temporarily suppressed live drop keeps phase without
        // drawing a path. Respawn and unsupported exits still reset it.
        if(row==4u && status==1 && previousStatus==1 && floor(m.a/4)==floor(om.a/4)
        && metric.a>.5 && all(endUV>=0) && all(endUV<=1)) {
            float4 phase=float4(0,0,0,0);
            phase=txTrailPreviousDescriptors.Load(int3(i,4,0));
            float keep=phase.a>.5 && phase.b==floor(m.a/4) ? 1 : 0;
            result=float4(phase.g,phase.g,phase.b,1)*keep;
        }
    }
    else {
        if(row==0u) result=float4(startUV,endUV);
        else {
            float coat=saturate(txRainDv.SampleLevel(samLinearClamp,endUV,0).a);
            float speed=length(ntPlane(s.ba,f));
            float vn=smoothstep(gNewTrailMinSpeed,gNewTrailFullSpeed,speed);
            float size=smoothstep(.4,2.5,diameter);
            float wet=max(gNewTrailWet,saturate(txTrailPrevious.SampleLevel(samLinearClamp,endUV,0).g));
            float sheet=gNewTrailSheetEnabled*max(vn,smoothstep(gNewTrailDensityMin,gNewTrailDensityFull,gNewTrailDensity))
            *smoothstep(.15,.65,gNewTrailShear);
            // Thin traces retain the accepted output size; a developed sheet uses
            // the model diameter, so head-size compensation does not shrink it away.
            float filmRadius=radius*lerp(outputScale,1,sheet);
            float width=filmRadius*gNewTrailWidthD*(1+gNewTrailWiden*smoothstep(.3,.8,gNewTrailShear)*sheet);
            width=max(width,gNewTrailMinDiameterMM*gRainReferencePerMM*.5);
            float height=gNewTrailHeight*pow(max(vn,0),.67)*(.35+.65*size)
            *lerp(1,1.6,wet)*lerp(1,.35,coat)*(1-.6*smoothstep(.5,1,gNewTrailShear));
            // Slow large wet drops also feed a narrow gravity rivulet.
            float rivulet=gNewTrailSupply*wet*size*(1-smoothstep(.15,.5,gNewTrailShear))*vn;
            height=max(height,gNewTrailHeight*rivulet*lerp(1,.35,coat));
            // h0 is calibrated at 1 model-mm. Film deposition scales with the
            // model radius while output footprint compensation retains head size.
            height*=diameter;
            height*=lerp(1,.2,coat*(1-smoothstep(.05,.35,vn)));
            height*=smoothstep(gNewTrailMinDropMM,gNewTrailMinDropMM*2,diameter);
            if(gNewTrailWaterEnabled<.5 || (gNewTrailSupply<.001 && gNewTrailWet<.08)) height=0;
            height=min(height*(1+.15*saturate(txTrailPrevious.SampleLevel(samLinearClamp,endUV,0).g)),1);
            float life=gNewTrailSeconds*lerp(1,2.5,gNewTrailWet)*lerp(1,.4,coat)*(1+.5*size);
            float wipeRadius=max(outputRadius*gNewTrailWipeD,gNewTrailMinDiameterMM*gRainReferencePerMM*.5);
            if(gNewTrailWipeEnabled<.5)wipeRadius=0;
            if(row==1u)result=float4(width,height,sheet,life);
            else if(row==2u)result=float4(f,wipeRadius);
            else if(row==4u) {
                float4 previous=txTrailPreviousDescriptors.Load(int3(i,4,0));
                float generation=floor(m.a/4);
                float begin=previous.a>.5 && previous.b==generation ? previous.g : 0;
                // Integrated distance in local footprint diameters, not an origin
                // reset on each segment. Changing width preserves phase continuity.
                result=float4(begin,begin+moved/max(2*width,1e-8),generation,1);
            }
            else {
                float reach=max(width,wipeRadius);
                float a=max(f.x,1e-9),c=max(f.z,1e-9);
                float2 ext=reach*float2(sqrt(1+f.y*f.y/(c*c))/a,1/c);
                // A sampling pixel margin ensures conservative tiles at either resolution.
                ext+=gNewTrailPixelUV;
                result=float4(min(startUV,endUV)-ext,max(startUV,endUV)+ext);
            }
        }
    }
    return result;
}
