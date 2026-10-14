// Single-exit lifecycle commit. R retains the renderer's reference-radius
// encoding; G is legacy mass profile or SI authoritative volume (versioned).
float4 main(PS_IN pin) {
    float4 result=0;
    float count=max(gRainStateCount,1);
    float index=clamp(floor(pin.Tex.x*count),0,count-1);
    float2 suv=float2((index+.5)/count,.5);
    if(gRainStateInit>.5) {
        float d=gRainStateLifecycle>.5 ? rainStateBirthDiameterMM(index,gRainStateRainIntensity,
            gRainStateRainWetness,gRainStateRainWater) : rainStatePhysicalDiameterMM(index);
        float volume=rainStatePhysicalMassProfile(d);
        float radius=gRainSiOn>.5 ? rainSiContactRadiusMM(volume,gRainSiTheta)*gRainStatePhysicalRadiusUVPerMM*2
            : d*gRainStatePhysicalRadiusUVPerMM;
        float status=gRainStateLifecycle>.5 && rainStateHash(index+419)>=gRainStateTargetOccupancy ? 0 : 1;
        if(gRainSiOn>.5 && status<.5) {radius=0;volume=0;}
        result=float4(radius,volume,0,status);
        if(gRainBirthOn>.5)result=0; // P2 begins empty: all water enters through a budgeted event.
    } else {
        result=txRainStateMeta.SampleLevel(samPointRainMeta,suv,0);
        float dt=max(gRainStateDeltaTime,0);
        bool age=true;
        float4 birth=0;
        [branch] if(gRainBirthOn>.5)birth=txRainBirthEvent.Load(int3((int)index,0,0));
        float oldGeneration=floor(result.a*.25);
        float expectedTag=fmod(oldGeneration+1,4096)+1;
        if(gRainBirthOn>.5 && result.a-oldGeneration*4<.5 && birth.a==expectedTag && birth.b>0) {
            result=float4(rainSiContactRadiusMM(birth.b,gRainSiTheta)*gRainStatePhysicalRadiusUVPerMM*2,
                birth.b,0,(birth.a-1)*4+1);age=false;
        } else if(gRainStateLifecycle>.5) {
            float generation=floor(result.a*.25),status=result.a-generation*4;
            float rain=saturate(gRainStateRainIntensity);
            if(status>1.5) {
                float next=fmod(generation+1,4096);
                float d=rainStateBirthDiameterMM(index+next*17.123,rain,
                    saturate(gRainStateRainWetness),saturate(gRainStateRainWater));
                result.g=rainStatePhysicalMassProfile(d);
                result.r=gRainSiOn>.5 ? rainSiContactRadiusMM(result.g,gRainSiTheta)*gRainStatePhysicalRadiusUVPerMM*2
                    : d*gRainStatePhysicalRadiusUVPerMM;
                result.a=next*4+1;result.b=0;age=false;
            } else if(status<.5 && gRainBirthOn>.5) {
                result.b=0;age=false; // No occupancy gate, synthetic gap or pending respawn.
            } else if(status<.5) {
                result.b+=dt;age=false;
                float gap=lerp(gRainStateRespawnGapMin,gRainStateRespawnGapMax,
                    rainStateHash(index+generation*23.71+701));
                float admission=gRainSpawnAtlasEnabled>.5 ? txRainSpawnAtlas.Load(int3((int)index,0,0)).b
                    : rainStateHash(index+419);
                float scale=lerp(3,.5,sqrt(rain))/max(gRainStateExposure,1);
                if(rain>.001 && admission<gRainStateTargetOccupancy && result.b>=gap*scale)
                    result.a=generation*4+2;
            } else {
                float4 state=txRainState.SampleLevel(samPointRainMeta,suv,0);
                float2 p=state.rg;
                bool retire=false;
#ifdef RAIN_MERGE_CODE
                float command=txRainMergeCmd.Load(int3((int)index,0,0)).b;
                if(gRainMergeEnabled>.5 && command>=64.0/255.0 && command<128.0/255.0) {
                    float4 partnerState=0,partnerMeta=0;
                    float4 merge=rainMergeDecode(index,count,generation,p,result.r,partnerState,partnerMeta);
                    float on=merge.z*(merge.x<1.5 ? 1 : 0);
                    if(on>.5 && merge.w<.5) retire=true;
                    else {
                        result.r=lerp(result.r,rainMergeRadius(result.r,partnerMeta.r),on);
                        if(gRainSiOn>.5) result.g+=max(partnerMeta.g,0)*on;
                        else result.g=lerp(result.g,rainStatePhysicalMassProfile(result.r/gRainStatePhysicalRadiusUVPerMM),on);
                    }
                }
#endif
                retire=retire || rainStateBoundaryMask(p)<.5;
                float life=lerp(gRainStateAgeMin,gRainStateAgeMax,rainStateHash(index+generation*5.197+211));
                if(rain<=.001)life=min(life,2);
                if(gRainSiOn<.5 && result.b+dt>=life)retire=true;
                if(retire) {
                    result.a=generation*4;result.b=0;age=false;
                    if(gRainSiOn>.5) {result.r=0;result.g=0;}
                }
            }
        }
        if(age) {
            if(gRainSiOn>.5 && abs(result.a-4*floor(result.a/4)-1)<.25)
                result.r=rainSiContactRadiusMM(result.g,gRainSiTheta)*gRainStatePhysicalRadiusUVPerMM*2;
            result.b+=dt;
        }
    }
    return result;
}
