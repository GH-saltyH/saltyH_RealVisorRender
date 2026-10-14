// Initialized single-exit state entry. Shared legacy/SI routing avoids FXC's
// X4000 propagation through early returns around inlined transport loops.
float4 main(PS_IN pin) {
    float4 result=0;
    float count=max(gRainStateCount,1);
    float index=clamp(floor(pin.Tex.x*count),0,count-1);
    float2 suv=float2((index+.5)/count,.5);
    if(gRainStateInit>.5) {
        float2 pos=float2(.5,-.5);
        if(gRainStateSingleDropTest>.5) pos=gRainStateSingleDropPosition;
        else if(gRainStatePhysicalTest>.5 && index<9) pos=float2(lerp(.25,.75,index/8),-.5);
        else if(gRainStatePhysicalGridTest>.5 && index<9) {
            uint i=(uint)index,ix=i%3u,iy=min(i/3u,2u);
            pos=float2(ix==0u ? .25 : ix==1u ? .5 : .75,
                iy==0u ? -.6 : iy==1u ? -.5 : -.45);
        } else pos=rainStateRespawnPosition(index,0,float2(.5,-.5));
        result=float4(pos,0,0);
    } else {
        float4 state=txRainState.SampleLevel(samPointRain,suv,0);
        float4 meta=txRainStateMeta.SampleLevel(samPointRain,suv,0);
        float2 p=state.rg,v=state.ba;
        float radius=meta.r;
        float mass=gRainSiOn>.5 ? max(meta.g,0) : max(meta.g,1);
        float dt=max(gRainStateDeltaTime,0);
        bool moving=true;
        result=float4(p,v);
        if(gRainStateLifecycle>.5) {
            float generation=floor(meta.a*.25),status=meta.a-generation*4;
            if(status>1.5) {
                float2 pos=p;
                if(gRainStatePhysicalTest>.5 && index<9) pos=float2(lerp(.25,.75,index/8),-.5);
                else pos=rainStateRespawnPosition(index,generation+1,p);
                result=float4(pos,0,0);moving=false;
            } else if(status<.5) {result=float4(p,0,0);moving=false;}
        }
        if(moving) {
            float jitter=frac(sin(index*12.9898+78.233)*43758.5453);
            float hold=gRainBirthHold*(.6+.8*jitter);
            float k=gRainStateLifecycle>.5 ? saturate((meta.b-hold)/max(gRainBirthRamp,1e-3)) : 1;
            k=k*k*(3-2*k);dt*=k;v*=k>0 ? 1 : 0;
#ifdef RAIN_MERGE_CODE
            if(gRainMergeEnabled>.5 && gRainStateLifecycle>.5
                && txRainMergeCmd.Load(int3((int)index,0,0)).b>=64.0/255.0) {
                float4 pState=0,pMeta=0;
                float4 merge=rainMergeDecode(index,count,floor(meta.a*.25),p,radius,pState,pMeta);
                float mergeOn=merge.z*(merge.x<1.5 ? 1 : 0);
                float attractOn=merge.z*(merge.x>1.5 ? 1 : 0)*(gRainSiOn>.5 ? 0 : 1);
                if(mergeOn>.5 && merge.w<.5) {result=float4(p,0,0);moving=false;}
                else {
                    float own=gRainSiOn>.5 ? mass : radius*radius*radius;
                    float other=(gRainSiOn>.5 ? max(pMeta.g,0) : pMeta.r*pMeta.r*pMeta.r)*mergeOn;
                    float total=max(own+other,1e-15);
                    float3 momentum=(rainMomentum(p,v)*own+rainMomentum(pState.rg,pState.ba)*other)/total;
                    p=(p*own+pState.rg*other)/total;
                    if(rainValid(p)<.5) {result=float4(2,2,0,0);moving=false;}
                    else {
                        v=rainMetricProject(p,momentum);
                        radius=lerp(radius,rainMergeRadius(radius,pMeta.r),mergeOn);
                        if(gRainSiOn>.5) mass=own+other;
                        else mass=lerp(mass,max(rainMergeMassProfile(radius/gRainStatePhysicalRadiusUVPerMM),1),mergeOn);
                        float2 toward=pState.rg-p;
                        float dist=rainMetricLength(p,toward);
                        float reach=max((radius+pMeta.r)*gRainAttractReach,1e-7);
                        float2 change=toward/max(dist,1e-7)*gRainAttractGain*saturate(1-dist/reach)*dt*attractOn;
                        float cap=rainMetricLength(p,v)*gRainSteerTurnRate*dt;
                        v+=change*min(1,cap/max(rainMetricLength(p,change),1e-9));
                    }
                }
            }
#endif
#ifdef RAIN_WETPATH_CODE
            if(moving && gRainSiOn<.5 && gRainWetPathGain>0 && dt>0
                && rainMetricLength(p,v)>max(gRainWetPathMinSpeed,1e-6)) {
                float speed=rainMetricLength(p,v);
                float2 directionUV=v/max(speed,1e-7);
                float2 texel=gRainWetPathTexel;
                float2 uv=float2(p.x,p.y+1)+directionUV*(radius*gRainWetPathAhead+2*texel);
                float2 gradient=float2(
                    txRainWetPath.SampleLevel(samLinearRain,uv+float2(texel.x,0),0).g
                    -txRainWetPath.SampleLevel(samLinearRain,uv-float2(texel.x,0),0).g,
                    txRainWetPath.SampleLevel(samLinearRain,uv+float2(0,texel.y),0).g
                    -txRainWetPath.SampleLevel(samLinearRain,uv-float2(0,texel.y),0).g)*.5;
                float2 planeV=rainMetricPlane(p,v);
                float3 u=0,w=0;rainMetric(p,u,w);
                float a=dot(u,u),b=dot(u,w),c=dot(w,w);
                float2 covector=gradient/max(texel,1e-9);
                float2 gradUV=float2(c*covector.x-b*covector.y,a*covector.y-b*covector.x)
                    /max(a*c-b*b,1e-20)*gRainMetersPerUnit*gRainMetersPerUnit;
                float2 grad=rainMetricPlane(p,gradUV),direction=planeV/max(speed,1e-7);
                float2 lateral=grad-dot(grad,direction)*direction;
                float on=saturate(speed/max(gRainWetPathMinSpeed,1e-6)-1);
                float2 change=lateral*(gRainWetPathGain*dt*on);
                change*=min(1,speed*gRainSteerTurnRate*dt/max(length(change),1e-9));
                v+=rainMetricOffset(p,change);
            }
#endif
            if(moving) {
                result=float4(p,v);
                if(gRainStatePhysics>.5 && (dt>0 || any(v!=0)))
                    result=rainStateUpdatePhysics(p,v,radius,mass,index,dt);
            }
        }
    }
    return result;
}
