// Five rows: swept path, actual head transfers/support, incident source,
// source support, union bounds. Volumes are mm3; coordinates are field cells.
float2 pfSupport(float2 p,float radiusMM,out float capped) {
    float2 wanted=max(ceil(rainMetricExtent(p,radiusMM*gRainReferencePerMM)*gFilmGrid),1);
    capped=any(wanted>gFilmPad) ? 1 : 0;
    return min(wanted,gFilmPad);
}
float4 main(PS_IN pin) {
    uint i=min((uint)(pin.Tex.x*gFilmCount),(uint)gFilmCount-1u);
    uint row=min((uint)(pin.Tex.y*5),4u);
    float4 state=txFilmNewState.Load(int3(i,0,0)),meta=txFilmNewMeta.Load(int3(i,0,0));
    float4 oldState=txFilmOldState.Load(int3(i,0,0)),oldMeta=txFilmOldMeta.Load(int3(i,0,0));
    float status=meta.a-4*floor(meta.a*.25),oldStatus=oldMeta.a-4*floor(oldMeta.a*.25);
    float4 path=0,transfer=0,incident=0,support=0;
    float2 low=1e9,high=-1e9;
    if(status==1 && meta.g>0 && rainValid(state.rg)>=.5) {
        // The provisional SI meta already derives this radius at the current
        // contact angle. Avoid repeating a cube root in all five rows.
        float radiusMM=max(meta.r,0)/max(gRainReferencePerMM,1e-12);
        float heightMM=rainSiCapHeightMM(radiusMM,gFilmTheta);
        float trailCandidate=0;
        bool same=oldStatus==1 && floor(oldMeta.a*.25)==floor(meta.a*.25)
            && rainValid(oldState.rg)>=.5 && meta.g<=oldMeta.g*(1+1e-6);
        if(same && gFilmMotionDt>0) {
            float2 delta=state.rg-oldState.rg;
            float distanceMM=rainMetricLength(oldState.rg,delta)/gRainReferencePerMM;
            float speedMS=distanceMM*.001/gFilmMotionDt;
            if(distanceMM>1e-6 && speedMS>gFilmMinSpeedMS) {
                float coat=saturate(rainCoating(state.rg));
                float shear=saturate(gFilmAirMS/30);
                float widthMM=2*radiusMM*(1+gFilmWiden*shear);
                float ca=gFilmMu*speedMS/max(gFilmGamma,1e-9);
                float hMM=lerp(gFilmDepositBare,gFilmDepositCoat,coat)*radiusMM*pow(max(ca,0),2.0/3.0)
                    *(1-.6*smoothstep(.5,1,shear));
                trailCandidate=min(meta.g,max(hMM*widthMM*distanceMM,0));
                float capped=0;float2 kernel=pfSupport(state.rg,widthMM*.5,capped);
                path=float4(float2(oldState.x,oldState.y+1)*gFilmGrid+gFilmPad-.5,
                            float2(state.x,state.y+1)*gFilmGrid+gFilmPad-.5);
                transfer.yz=kernel;support.z=capped;
            }
        }
        // Store the transfer the float32 head can actually lose, not an
        // arbitrarily smaller requested loss that rounds away in the head.
        precise float remaining=meta.g-trailCandidate;
        transfer.x=meta.g-remaining;
        float evapCandidate=min(remaining,3.141592653589793*(radiusMM*radiusMM+heightMM*heightMM)
            *gFilmEvapUMS*.001*gFilmDt);
        precise float afterEvap=remaining-evapCandidate;
        transfer.w=remaining-afterEvap;
        if(transfer.x>0) {low=min(path.xy,path.zw)-transfer.yz;high=max(path.xy,path.zw)+transfer.yz;}
    }
    float4 source=txFilmBirthEvent.Load(int3(i,0,0));
    float4 allocation=txFilmBirthEvent.Load(int3(i,2,0)),ledger=txFilmBirthEvent.Load(int3(i,3,0));
    float film=max(allocation.y,0)+max(ledger.x,0),micro=max(allocation.z,0);
    if(film+micro>0) {
        float2 p=source.xy;
        incident=float4(float2(p.x,p.y+1)*gFilmGrid+gFilmPad-.5,film,micro);
        float beta=max(txFilmBirthEvent.Load(int3(i,1,0)).z,1);
        float radiusMM=rainSiContactRadiusMM(max(allocation.x,0),gFilmTheta)*beta;
        float capped=0;support.xy=pfSupport(p,radiusMM,capped);support.z=max(support.z,capped);
        low=min(low,incident.xy-support.xy);high=max(high,incident.xy+support.xy);
    }
    if(row==0u)return path;
    if(row==1u)return transfer;
    if(row==2u)return incident;
    if(row==3u)return support;
    return float4(low,high);
}
