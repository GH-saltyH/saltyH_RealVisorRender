// P2: one immutable per-frame event atlas. Sources in mm^3, area in m^2.
// No display coefficient / track puddles / Smear inputs.
uint rbHash(uint x) {x=x*747796405u+2891336453u;uint w=((x>>((x>>28u)+4u))^x)*277803737u;return (w>>22u)^w;}
float rbRandom(uint x) {return (rbHash(x)>>8u)*(1.0/16777216.0);}
float4 rbDsd(float quantile) {
    // Float weights can sum one ULP below 1. Normalize to the actual endpoint
    // so a top quantile cannot fall through into an empty giant tail bin.
    quantile*=dot(txBirthDsd.Load(int3(127,0,0)),gBirthWeights);
    uint lo=0u,hi=127u;
    [unroll] for(int j=0;j<7;++j) {
        uint mid=(lo+hi)/2u;
        float cumulative=dot(txBirthDsd.Load(int3(mid,0,0)),gBirthWeights);
        if(quantile<cumulative)hi=mid;else lo=mid+1u;
    }
    return txBirthDsd.Load(int3(min(lo,127u),1,0)); // D_eq, V, terminal, reserved
}
float4 rbImpactFractions(float weber,float coat,float wet) {
    float x=clamp(log10(max(weber,1)),0,5)*31/5;
    int low=(int)floor(x),high=min(low+1,31);float f=frac(x);
    float4 dryBare=lerp(txBirthImpact.Load(int3(low,0,0)),txBirthImpact.Load(int3(high,0,0)),f);
    float4 wetBare=lerp(txBirthImpact.Load(int3(low,1,0)),txBirthImpact.Load(int3(high,1,0)),f);
    float4 dryCoat=lerp(txBirthImpact.Load(int3(low,2,0)),txBirthImpact.Load(int3(high,2,0)),f);
    float4 wetCoat=lerp(txBirthImpact.Load(int3(low,3,0)),txBirthImpact.Load(int3(high,3,0)),f);
    float4 shares=max(lerp(lerp(dryBare,wetBare,saturate(wet)),lerp(dryCoat,wetCoat,saturate(wet)),saturate(coat)),0);
    return shares/max(dot(shares,1),1e-16);
}
float4 main(PS_IN pin) {
    uint count=(uint)max(gBirthCount,1),index=min((uint)(pin.Tex.x*count),count-1u);
    uint rows=gPoolOn>.5 ? 5u : 4u;
    uint row=min((uint)(pin.Tex.y*rows),rows-1u),tick=(uint)gBirthTick;
    float4 oldMeta=txRainStateMeta.Load(int3(index,0,0));float4 oldState=txRainState.Load(int3(index,0,0));
    float generation=floor(oldMeta.a*.25),status=oldMeta.a-4*generation;
    float exitVolume=status>.5 && status<1.5 && rainValid(oldState.rg)<.5 ? max(oldMeta.g,0) : 0;
    float4 spawn=0,motion=0,allocation=0,ledger=float4(0,exitVolume,0,0),pool=0;
    [branch] if(gBirthNumberDensity>0 && gBirthDt>0 && gBirthExposure>0) {
    uint seed=index*131u+tick*8191u+(uint)generation*104729u;
    uint width=1u,height=1u;txBirthSites.GetDimensions(width,height);
    uint site=rbHash(seed+3u)%max(width,1u);
    float4 location=txBirthSites.Load(int3(site,0,0));float2 p=float2(location.x,location.y-1);
    pool.xy=p; // Preserve the original incident centre if head birth uses a pool.
    float4 descriptor=rbDsd(rbRandom(seed+23u));
    float3 du,dv;rainMetric(p,du,dv);
    float3 uw=mul(du,(float3x3)gBirthObjectToWorld),vw=mul(dv,(float3x3)gBirthObjectToWorld);
    float3 c=cross(uw,vw);float c2=dot(c,c);
    // Site B stores cross(dPdu,dPdv) alignment with authored outward normal.
    // Computed offline against this exact metric, avoiding a full normal atlas.
    float orientation=location.b>=0 ? 1 : -1;
    if(location.a>.5 && rainValid(p)>.5 && c2>1e-20) {
        float3 n=c*rsqrt(max(c2,1e-20))*orientation*gBirthNormalSign;
        float3 relative=gBirthAirWorld*gBirthIncidentAirFraction-float3(0,descriptor.z,0);
        float vn=max(0,-dot(relative,n));
        float lambda=max(gBirthNumberDensity,0)*max(gBirthAreaM2,0)/count*vn*max(gBirthDt,0)*saturate(gBirthExposure);
        float packet=rbRandom(seed+79u)<min(lambda,1) ? 1 : 0;
        // At lambda>1 the bounded sampler carries the excess as unresolved
        // continuum. No unbounded spawn loop/backlog, no silently lost source.
        float overflow=descriptor.y*max(lambda-1,0);
        float incoming=descriptor.y*packet;
        ledger.x=overflow;
        allocation.x=overflow;
        [branch] if(packet>.5) {
        float weber=rainSiWeber(descriptor.x,vn,gBirthRhoWater,gBirthGamma);
        float coat=rainCoating(p);
        float wet=gBirthWetOverride;
        if(gBirthWetOn>.5) {
            float2 heightUM=txBirthWetHeight.SampleLevel(samLinearClamp,float2(p.x,p.y+1),0).rg;
            wet=max(wet,saturate((heightUM.x+heightUM.y)/max(gBirthWetHeightUM,1e-6)));
        }
        float4 shares=rbImpactFractions(weber,coat,wet);
        float attached=incoming*shares.x;
        float film=incoming*shares.y,micro=incoming*shares.z,rebound=incoming*shares.w;
        bool microscopic=descriptor.x<gBirthMinPersistentMM;
        if(microscopic) {micro+=attached;attached=0;}
        bool free=status<.5 && oldMeta.g<=0;
        float unresolved=free ? 0 : attached;
        if(!free)attached=0;
        float tag=attached>0 ? fmod(generation+1,4096)+1 : 0;
        float3 tangent=rainSiTangent(relative,n)*saturate(gBirthTangentFraction);
        float2 initialUV=rainSiProjectUV(uw,vw,tangent);
        // Spread descriptor is reserved for P3's surface impact transient.
        float re=gBirthRhoWater*vn*descriptor.x*.001/max(gBirthMu,1e-9);
        float advancing=lerp(gBirthAdvanceBare,gBirthAdvanceCoat,coat);
        float beta=sqrt((weber+12)/max(3*(1-cos(advancing*.0174532925199433))+4*weber/sqrt(max(re,1)),1e-9));
        spawn=float4(p,attached,tag);
        motion=float4(initialUV,clamp(beta,1,6),weber);
        allocation=float4(incoming+overflow,film,micro,rebound);
        ledger=float4(unresolved+overflow,exitVolume,attached,packet);
        }
    }
    }
    [branch] if(gPoolOn>.5 && status==0 && oldMeta.g<=0 && spawn.z<=0) {
        uint tiles=poolTileCount(),tile=(index%tiles+(uint)gPoolTick%tiles)%tiles;
        if(poolOwner(tile)==index) {
            float4 candidate=txPoolCandidates.Load(int3(tile,0,0));
            float2 p=(candidate.xy+.5)/gFilmGrid;p.y-=1;
            if(candidate.w>.5 && candidate.z>0 && rainValid(p)>.5) {
                spawn=float4(p,candidate.z,fmod(generation+1,4096)+1);
                // No field momentum is stored. Reconstituted unresolved pool
                // starts at rest; P1 applies forces from the following step.
                motion.xy=0;pool.z=candidate.z;
            }
        }
    }
    float4 result=row==0u ? spawn : row==1u ? motion : row==2u ? allocation : row==3u ? ledger : pool;
    return result;
}
