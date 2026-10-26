local M={keys={export=1,original=2,packets=3,reduce=4,trace=5}}
M.export=[====[
// Immutable P2 context. Tokens and revisions are bounded exact float integers.
#define gBirthCount txContext.Load(int3(0,1,0)).w
#define gBirthTick txContext.Load(int3(0,1,0)).y
#define gBirthDt txContext.Load(int3(0,1,0)).z
#define gBirthNumberDensity txContext.Load(int3(0,4,0)).x
#define gBirthAreaM2 txContext.Load(int3(0,4,0)).y
#define gBirthExposure txContext.Load(int3(0,4,0)).z
#define gBirthIncidentAirFraction txContext.Load(int3(0,4,0)).w
#define gBirthWeights txContext.Load(int3(0,5,0))
#define gBirthAirWorld txContext.Load(int3(0,6,0)).xyz
#define gBirthTangentFraction txContext.Load(int3(0,6,0)).w
#define gBirthRhoWater txContext.Load(int3(0,7,0)).x
#define gBirthGamma txContext.Load(int3(0,7,0)).y
#define gBirthMu txContext.Load(int3(0,7,0)).z
#define gBirthMinPersistentMM txContext.Load(int3(0,7,0)).w
#define gBirthWetOverride txContext.Load(int3(0,8,0)).x
#define gBirthWetOn txContext.Load(int3(0,8,0)).y
#define gBirthWetHeightUM txContext.Load(int3(0,8,0)).z
#define gBirthNormalSign txContext.Load(int3(0,8,0)).w
#define gBirthAdvanceBare txContext.Load(int3(0,9,0)).x
#define gBirthAdvanceCoat txContext.Load(int3(0,9,0)).y
#define gBirthTheta txContext.Load(int3(0,9,0)).z
#define gPoolOn txContext.Load(int3(0,10,0)).x
#define gPoolCount txContext.Load(int3(0,10,0)).y
#define gPoolTick txContext.Load(int3(0,10,0)).z
#define gFilmGrid txContext.Load(int3(0,11,0)).xy
#define gFilmPad txContext.Load(int3(0,11,0)).z
#define gBirthObjectToWorld float4x4(txContext.Load(int3(0,13,0)),txContext.Load(int3(0,14,0)),txContext.Load(int3(0,15,0)),txContext.Load(int3(0,16,0)))
bool birthInteger(float x){return isfinite(x)&&x>=0&&x<=1048575&&x==floor(x);}
bool birthUnit(float x){return isfinite(x)&&x>=0&&x<=1;}
bool birthContext(){
 float4 token=txContext.Load(int3(0,0,0)),frame=txContext.Load(int3(0,1,0)),clock=txContext.Load(int3(0,2,0));
 float4 prev=txContext.Load(int3(0,17,0)),revision=txContext.Load(int3(0,3,0)),supply=txContext.Load(int3(0,4,0)),weights=gBirthWeights;
 float4 material=txContext.Load(int3(0,7,0)),wet=txContext.Load(int3(0,8,0)),angles=txContext.Load(int3(0,9,0)),pool=txContext.Load(int3(0,10,0)),grid=txContext.Load(int3(0,11,0)),response=txContext.Load(int3(0,12,0));
 bool ok=true;[unroll]for(uint k=0;k<18u;k++)ok=ok&&all(isfinite(txContext.Load(int3(0,k,0))));
 ok=ok&&birthInteger(token.x)&&token.x>0&&birthInteger(token.y)&&token.y>0&&token.y<1048575&&birthInteger(token.z)&&token.z>0&&token.w==1&&
  all(prev.xy==token.xy)&&birthInteger(prev.z)&&prev.z+1==token.z&&prev.w==1&&frame.x>=0&&frame.x<=16777215&&frame.x==floor(frame.x)&&birthInteger(frame.y)&&frame.w==gCount&&frame.z>0&&frame.z<=.05;
 float span=(clock.z-clock.x)*65536+(clock.w-clock.y);
 ok=ok&&all(clock>=0)&&all(clock==floor(clock))&&clock.x<=16777215&&clock.z<=16777215&&clock.y<65536&&clock.w<65536&&span>0&&span<=52428&&frame.z==span/1048576;
 ok=ok&&all(revision>=0)&&all(revision<=1048575)&&all(revision==floor(revision))&&supply.x>=0&&supply.y>0&&birthUnit(supply.z)&&birthUnit(supply.w)&&
  all(weights>=0)&&abs(dot(weights,1)-1)<=8*1.1920928955078125e-7&&birthUnit(gBirthTangentFraction)&&
  material.x>0&&material.y>0&&material.z>=0&&material.w>=0&&birthUnit(wet.x)&&(wet.y==0||wet.y==1)&&wet.z>0&&abs(wet.w)==1&&
  angles.x>0&&angles.x<180&&angles.y>0&&angles.y<180&&angles.z>0&&angles.z<180&&angles.w==0&&
  (pool.x==0||pool.x==1)&&pool.y==gCount&&pool.z==frame.y&&pool.w==0&&all(grid.xy==float2(gFieldWidth,gFieldHeight))&&grid.z>=1&&grid.z<=16&&grid.z==floor(grid.z)&&grid.w==1&&
  birthUnit(response.x)&&birthUnit(response.y)&&birthUnit(response.z)&&response.w==1;
 float3x3 m=(float3x3)gBirthObjectToWorld;float a=dot(m[0],m[0]),b=dot(m[1],m[1]),c=dot(m[2],m[2]),tol=max(a,b)*32*1.1920928955078125e-7;
 return ok&&a>1e-20&&abs(a-b)<=tol&&abs(a-c)<=tol&&abs(dot(m[0],m[1]))<=tol&&abs(dot(m[0],m[2]))<=tol&&abs(dot(m[1],m[2]))<=tol&&determinant(m)>0;
}
float4 main(PS_IN pin){
 float4 result=0;bool ready=txDecision.Load(int3(0,0,0)).r==0;
 uint slot=min((uint)(pin.Tex.x*gCount),(uint)gCount-1u);
 if(ready){
  if(gKind==0)result=txTrace.Load(int3(slot,min((uint)(pin.Tex.y*5),4u),0));
  else if(gKind==1)result=txPackets.Load(int3(slot,min((uint)(pin.Tex.y*4),3u),0));
  else if(gKind==2||gKind==3)result=txPackets.Load(int3(slot,(uint)gKind+2u,0));
  else if(gKind==4)result=txContext.Load(int3(0,0,0));
  else if(gKind==5){uint row=min((uint)(pin.Tex.y*5),4u);if(row==0u)result=txContext.Load(int3(0,0,0));else if(row==1u)result=float4(gFilmGrid,gFilmPad,gCount);else if(row==2u)result=float4(gPoolTick,txContext.Load(int3(0,1,0)).x,1,1);else if(row==3u)result=float4(1,1,16,0);else result=txContext.Load(int3(0,17,0));}
 }return result;
}
]====]
M.original=[====[
// Immutable P2 context. Tokens and revisions are bounded exact float integers.
#define gBirthCount txContext.Load(int3(0,1,0)).w
#define gBirthTick txContext.Load(int3(0,1,0)).y
#define gBirthDt txContext.Load(int3(0,1,0)).z
#define gBirthNumberDensity txContext.Load(int3(0,4,0)).x
#define gBirthAreaM2 txContext.Load(int3(0,4,0)).y
#define gBirthExposure txContext.Load(int3(0,4,0)).z
#define gBirthIncidentAirFraction txContext.Load(int3(0,4,0)).w
#define gBirthWeights txContext.Load(int3(0,5,0))
#define gBirthAirWorld txContext.Load(int3(0,6,0)).xyz
#define gBirthTangentFraction txContext.Load(int3(0,6,0)).w
#define gBirthRhoWater txContext.Load(int3(0,7,0)).x
#define gBirthGamma txContext.Load(int3(0,7,0)).y
#define gBirthMu txContext.Load(int3(0,7,0)).z
#define gBirthMinPersistentMM txContext.Load(int3(0,7,0)).w
#define gBirthWetOverride txContext.Load(int3(0,8,0)).x
#define gBirthWetOn txContext.Load(int3(0,8,0)).y
#define gBirthWetHeightUM txContext.Load(int3(0,8,0)).z
#define gBirthNormalSign txContext.Load(int3(0,8,0)).w
#define gBirthAdvanceBare txContext.Load(int3(0,9,0)).x
#define gBirthAdvanceCoat txContext.Load(int3(0,9,0)).y
#define gBirthTheta txContext.Load(int3(0,9,0)).z
#define gPoolOn txContext.Load(int3(0,10,0)).x
#define gPoolCount txContext.Load(int3(0,10,0)).y
#define gPoolTick txContext.Load(int3(0,10,0)).z
#define gFilmGrid txContext.Load(int3(0,11,0)).xy
#define gFilmPad txContext.Load(int3(0,11,0)).z
#define gBirthObjectToWorld float4x4(txContext.Load(int3(0,13,0)),txContext.Load(int3(0,14,0)),txContext.Load(int3(0,15,0)),txContext.Load(int3(0,16,0)))
bool birthInteger(float x){return isfinite(x)&&x>=0&&x<=1048575&&x==floor(x);}
bool birthUnit(float x){return isfinite(x)&&x>=0&&x<=1;}
bool birthContext(){
 float4 token=txContext.Load(int3(0,0,0)),frame=txContext.Load(int3(0,1,0)),clock=txContext.Load(int3(0,2,0));
 float4 prev=txContext.Load(int3(0,17,0)),revision=txContext.Load(int3(0,3,0)),supply=txContext.Load(int3(0,4,0)),weights=gBirthWeights;
 float4 material=txContext.Load(int3(0,7,0)),wet=txContext.Load(int3(0,8,0)),angles=txContext.Load(int3(0,9,0)),pool=txContext.Load(int3(0,10,0)),grid=txContext.Load(int3(0,11,0)),response=txContext.Load(int3(0,12,0));
 bool ok=true;[unroll]for(uint k=0;k<18u;k++)ok=ok&&all(isfinite(txContext.Load(int3(0,k,0))));
 ok=ok&&birthInteger(token.x)&&token.x>0&&birthInteger(token.y)&&token.y>0&&token.y<1048575&&birthInteger(token.z)&&token.z>0&&token.w==1&&
  all(prev.xy==token.xy)&&birthInteger(prev.z)&&prev.z+1==token.z&&prev.w==1&&frame.x>=0&&frame.x<=16777215&&frame.x==floor(frame.x)&&birthInteger(frame.y)&&frame.w==gCount&&frame.z>0&&frame.z<=.05;
 float span=(clock.z-clock.x)*65536+(clock.w-clock.y);
 ok=ok&&all(clock>=0)&&all(clock==floor(clock))&&clock.x<=16777215&&clock.z<=16777215&&clock.y<65536&&clock.w<65536&&span>0&&span<=52428&&frame.z==span/1048576;
 ok=ok&&all(revision>=0)&&all(revision<=1048575)&&all(revision==floor(revision))&&supply.x>=0&&supply.y>0&&birthUnit(supply.z)&&birthUnit(supply.w)&&
  all(weights>=0)&&abs(dot(weights,1)-1)<=8*1.1920928955078125e-7&&birthUnit(gBirthTangentFraction)&&
  material.x>0&&material.y>0&&material.z>=0&&material.w>=0&&birthUnit(wet.x)&&(wet.y==0||wet.y==1)&&wet.z>0&&abs(wet.w)==1&&
  angles.x>0&&angles.x<180&&angles.y>0&&angles.y<180&&angles.z>0&&angles.z<180&&angles.w==0&&
  (pool.x==0||pool.x==1)&&pool.y==gCount&&pool.z==frame.y&&pool.w==0&&all(grid.xy==float2(gFieldWidth,gFieldHeight))&&grid.z>=1&&grid.z<=16&&grid.z==floor(grid.z)&&grid.w==1&&
  birthUnit(response.x)&&birthUnit(response.y)&&birthUnit(response.z)&&response.w==1;
 float3x3 m=(float3x3)gBirthObjectToWorld;float a=dot(m[0],m[0]),b=dot(m[1],m[1]),c=dot(m[2],m[2]),tol=max(a,b)*32*1.1920928955078125e-7;
 return ok&&a>1e-20&&abs(a-b)<=tol&&abs(a-c)<=tol&&abs(dot(m[0],m[1]))<=tol&&abs(dot(m[0],m[2]))<=tol&&abs(dot(m[1],m[2]))<=tol&&determinant(m)>0;
}
SamplerState samLinearClamp;
// KN5 local metres / raw signed UV. Discrete reads avoid blending different
// island Jacobians. Source boundary alpha is authoritative; never wrap it.
float4 rainMetricTap(Texture2D tx, float2 uv) {
    uint w=1u,h=1u;tx.GetDimensions(w,h);
    return tx.Load(int3(clamp((int2)(uv*float2(w,h)),int2(0,0),int2(w-1,h-1)),0));
}
void rainMetric(float2 p,out float3 u,out float3 v) {
    float2 uv=float2(p.x,p.y+1);
    u=rainMetricTap(txRainDu,uv).xyz;v=rainMetricTap(txRainDv,uv).xyz;
}
float rainCoating(float2 p) {return rainMetricTap(txRainDv,float2(p.x,p.y+1)).a;}
float rainValid(float2 p) {
    float inside=all(p>=float2(0,-1))&&all(p<=float2(1,0)) ? 1 : 0;
    float alpha=rainMetricTap(txRainBoundaryMask,float2(p.x,p.y+1)).a;
    float support=saturate(rainMetricTap(txRainDu,float2(p.x,p.y+1)).a);
    return inside*alpha*support;
}
// P1 shared physical primitives. Lengths/velocity/force use m, m/s, N;
// authoritative stored volume is mm^3. No display/texel/reference-size inputs.
// Reduced attached-drop model, not CFD. Material/contact/aero inputs are explicit.
float rainSiVolumeMM3(float equivalentDiameterMM) {
    float d=max(equivalentDiameterMM,0);
    return 0.523598775598299*d*d*d;
}
float rainSiEquivalentDiameterMM(float volumeMM3) {
    return pow(max(volumeMM3,0)*1.90985931710274,1.0/3.0);
}
float rainSiMassKG(float volumeMM3,float rhoWater) {
    return max(volumeMM3,0)*1e-9*max(rhoWater,0);
}
float rainSiContactRadiusMM(float volumeMM3,float thetaDeg) {
    // Valid material input angles are strictly between 0 and 180 degrees.
    float t=tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
    return pow(max(volumeMM3,0)*1.90985931710274/(t*(3+t*t)),1.0/3.0);
}
float rainSiCapHeightMM(float radiusMM,float thetaDeg) {
    return max(radiusMM,0)*tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
}
float rainSiPinningN(float widthMM,float thetaR,float thetaA,float gamma,float shapeK) {
    float hysteresis=max(cos(thetaR*0.0174532925199433)-cos(thetaA*0.0174532925199433),0);
    return max(shapeK,0)*max(gamma,0)*max(widthMM,0)*.001*hysteresis;
}
float rainSiWeber(float equivalentDiameterMM,float normalImpactMS,float rhoWater,float gamma) {
    return max(rhoWater,0)*normalImpactMS*normalImpactMS*max(equivalentDiameterMM,0)*.001/max(gamma,1e-9);
}
float3 rainSiTangent(float3 v,float3 normal) {
    return v-normal*dot(v,normal);
}
float3 rainSiAirForceN(float3 relativeAirMS,float3 velocityMS,float3 normal,
    float contactRadiusMM,float capHeightMM,float rhoAir,float attachedCd) {
    float3 rel=relativeAirMS-velocityMS;
    float speed=length(rel);
    float a=max(contactRadiusMM,0)*.001;
    float h=max(capHeightMM,0)*.001;
    float incidence=speed>1e-9 ? saturate(abs(dot(rel,normal))/speed) : 0;
    // Projected cap-area approximation: grazing wind still has nonzero exposed area.
    // Caller supplies local surface air (including shielding), not a force gain.
    float area=lerp(2*a*h,3.141592653589793*a*a,incidence);
    return .5*max(rhoAir,0)*max(attachedCd,0)*area*speed*rel;
}
float3 rainSiIntegrateSlip(float3 velocityMS,float3 drivingForceN,float3 normal,
    float massKG,float staticPinN,float kineticPinN,float viscousKGPerS,float dt) {
    float3 v=rainSiTangent(velocityMS,normal);
    float3 force=rainSiTangent(drivingForceN,normal);
    float step=max(dt,0);
    if(massKG<=1e-16) return 0;
    if(step<=0) return v;
    // Numerical rest epsilon is in m/s. No diameter-based arbitrary speed cap.
    if(length(v)<=1e-7 && length(force)<=max(staticPinN,0)) return 0;
    float c=max(viscousKGPerS,0);
    float safeMass=max(massKG,1e-16);
    float decay=exp(-c*step/safeMass);
    float response=c>1e-16 ? (1-decay)/max(c,1e-16) : step/safeMass;
    float3 freeV=v*decay+force*response;
    float speed=length(freeV);
    // Proximal dry-friction update cannot reverse velocity through zero.
    float remaining=max(speed-max(kineticPinN,0)*response,0);
    return freeV*(remaining/max(speed,1e-16));
}
float3 rainSiSlideWorld(float3 velocityMS,float3 gravityMS2,float3 inertiaMS2,
    float3 localAirMS,float3 normal,float volumeMM3,float theta,float thetaR,float thetaA,
    float dynamicThetaR,float dynamicThetaA,float rhoWater,float mu,float gamma,
    float rhoAir,float attachedCd,float shapeK,float viscousShape,float dt) {
    float radius=rainSiContactRadiusMM(volumeMM3,theta);
    float height=rainSiCapHeightMM(radius,theta);
    float mass=rainSiMassKG(volumeMM3,rhoWater);
    float3 drive=mass*(gravityMS2+inertiaMS2)
        +rainSiAirForceN(localAirMS,velocityMS,normal,radius,height,rhoAir,attachedCd);
    float staticPin=rainSiPinningN(2*radius,thetaR,thetaA,gamma,shapeK);
    float kineticPin=rainSiPinningN(2*radius,dynamicThetaR,dynamicThetaA,gamma,shapeK);
    float c=max(viscousShape,0)*max(mu,0)*2*radius*.001;
    return rainSiIntegrateSlip(velocityMS,drive,normal,mass,staticPin,kineticPin,c,dt);
}
float2 rainSiProjectUV(float3 duWorld,float3 dvWorld,float3 displacementM) {
    float a=dot(duWorld,duWorld),b=dot(duWorld,dvWorld),c=dot(dvWorld,dvWorld);
    float det=a*c-b*b;
    if(det<=1e-20) return 0; // Caller rejects an unsupported/degenerate surface.
    return float2(c*dot(duWorld,displacementM)-b*dot(dvWorld,displacementM),
        a*dot(dvWorld,displacementM)-b*dot(duWorld,displacementM))/max(det,1e-20);
}
float3 rainSiWorldVelocity(float3 duWorld,float3 dvWorld,float2 uvVelocity) {
    return duWorld*uvVelocity.x+dvWorld*uvVelocity.y;
}
float3 rainSiMergedVelocity(float3 a,float3 b,float volumeA,float volumeB) {
    float va=max(volumeA,0),vb=max(volumeB,0),total=va+vb;
    return (a*va+b*vb)/max(total,1e-16); // Same liquid density, no radius/display weights.
}
// P4b bounded, unique region -> slot ownership. Counts and tick are integers.
uint poolTilesX() {return ((uint)gFilmGrid.x+15u)/16u;}
uint poolTileCount() {return poolTilesX()*(((uint)gFilmGrid.y+15u)/16u);}
uint poolRotation() {
    uint groups=((uint)max(gPoolCount,1)+poolTileCount()-1u)/poolTileCount();
    // Advance region rotation after a complete slot-group cycle. Using tick
    // directly aliases groups/regions at common counts such as 4096 slots.
    return ((uint)gPoolTick/groups)%poolTileCount();
}
uint poolOwner(uint tile) {
    uint tiles=poolTileCount(),count=(uint)max(gPoolCount,1),tick=(uint)gPoolTick;
    uint group=tick%((count+tiles-1u)/tiles);
    return group*tiles+(tile+tiles-poolRotation())%tiles;
}
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
        uint tiles=poolTileCount(),tile=(index%tiles+poolRotation())%tiles;
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
]====]
M.packets=[====[
// Immutable P2 context. Tokens and revisions are bounded exact float integers.
#define gBirthCount txContext.Load(int3(0,1,0)).w
#define gBirthTick txContext.Load(int3(0,1,0)).y
#define gBirthDt txContext.Load(int3(0,1,0)).z
#define gBirthNumberDensity txContext.Load(int3(0,4,0)).x
#define gBirthAreaM2 txContext.Load(int3(0,4,0)).y
#define gBirthExposure txContext.Load(int3(0,4,0)).z
#define gBirthIncidentAirFraction txContext.Load(int3(0,4,0)).w
#define gBirthWeights txContext.Load(int3(0,5,0))
#define gBirthAirWorld txContext.Load(int3(0,6,0)).xyz
#define gBirthTangentFraction txContext.Load(int3(0,6,0)).w
#define gBirthRhoWater txContext.Load(int3(0,7,0)).x
#define gBirthGamma txContext.Load(int3(0,7,0)).y
#define gBirthMu txContext.Load(int3(0,7,0)).z
#define gBirthMinPersistentMM txContext.Load(int3(0,7,0)).w
#define gBirthWetOverride txContext.Load(int3(0,8,0)).x
#define gBirthWetOn txContext.Load(int3(0,8,0)).y
#define gBirthWetHeightUM txContext.Load(int3(0,8,0)).z
#define gBirthNormalSign txContext.Load(int3(0,8,0)).w
#define gBirthAdvanceBare txContext.Load(int3(0,9,0)).x
#define gBirthAdvanceCoat txContext.Load(int3(0,9,0)).y
#define gBirthTheta txContext.Load(int3(0,9,0)).z
#define gPoolOn txContext.Load(int3(0,10,0)).x
#define gPoolCount txContext.Load(int3(0,10,0)).y
#define gPoolTick txContext.Load(int3(0,10,0)).z
#define gFilmGrid txContext.Load(int3(0,11,0)).xy
#define gFilmPad txContext.Load(int3(0,11,0)).z
#define gBirthObjectToWorld float4x4(txContext.Load(int3(0,13,0)),txContext.Load(int3(0,14,0)),txContext.Load(int3(0,15,0)),txContext.Load(int3(0,16,0)))
bool birthInteger(float x){return isfinite(x)&&x>=0&&x<=1048575&&x==floor(x);}
bool birthUnit(float x){return isfinite(x)&&x>=0&&x<=1;}
bool birthContext(){
 float4 token=txContext.Load(int3(0,0,0)),frame=txContext.Load(int3(0,1,0)),clock=txContext.Load(int3(0,2,0));
 float4 prev=txContext.Load(int3(0,17,0)),revision=txContext.Load(int3(0,3,0)),supply=txContext.Load(int3(0,4,0)),weights=gBirthWeights;
 float4 material=txContext.Load(int3(0,7,0)),wet=txContext.Load(int3(0,8,0)),angles=txContext.Load(int3(0,9,0)),pool=txContext.Load(int3(0,10,0)),grid=txContext.Load(int3(0,11,0)),response=txContext.Load(int3(0,12,0));
 bool ok=true;[unroll]for(uint k=0;k<18u;k++)ok=ok&&all(isfinite(txContext.Load(int3(0,k,0))));
 ok=ok&&birthInteger(token.x)&&token.x>0&&birthInteger(token.y)&&token.y>0&&token.y<1048575&&birthInteger(token.z)&&token.z>0&&token.w==1&&
  all(prev.xy==token.xy)&&birthInteger(prev.z)&&prev.z+1==token.z&&prev.w==1&&frame.x>=0&&frame.x<=16777215&&frame.x==floor(frame.x)&&birthInteger(frame.y)&&frame.w==gCount&&frame.z>0&&frame.z<=.05;
 float span=(clock.z-clock.x)*65536+(clock.w-clock.y);
 ok=ok&&all(clock>=0)&&all(clock==floor(clock))&&clock.x<=16777215&&clock.z<=16777215&&clock.y<65536&&clock.w<65536&&span>0&&span<=52428&&frame.z==span/1048576;
 ok=ok&&all(revision>=0)&&all(revision<=1048575)&&all(revision==floor(revision))&&supply.x>=0&&supply.y>0&&birthUnit(supply.z)&&birthUnit(supply.w)&&
  all(weights>=0)&&abs(dot(weights,1)-1)<=8*1.1920928955078125e-7&&birthUnit(gBirthTangentFraction)&&
  material.x>0&&material.y>0&&material.z>=0&&material.w>=0&&birthUnit(wet.x)&&(wet.y==0||wet.y==1)&&wet.z>0&&abs(wet.w)==1&&
  angles.x>0&&angles.x<180&&angles.y>0&&angles.y<180&&angles.z>0&&angles.z<180&&angles.w==0&&
  (pool.x==0||pool.x==1)&&pool.y==gCount&&pool.z==frame.y&&pool.w==0&&all(grid.xy==float2(gFieldWidth,gFieldHeight))&&grid.z>=1&&grid.z<=16&&grid.z==floor(grid.z)&&grid.w==1&&
  birthUnit(response.x)&&birthUnit(response.y)&&birthUnit(response.z)&&response.w==1;
 float3x3 m=(float3x3)gBirthObjectToWorld;float a=dot(m[0],m[0]),b=dot(m[1],m[1]),c=dot(m[2],m[2]),tol=max(a,b)*32*1.1920928955078125e-7;
 return ok&&a>1e-20&&abs(a-b)<=tol&&abs(a-c)<=tol&&abs(dot(m[0],m[1]))<=tol&&abs(dot(m[0],m[2]))<=tol&&abs(dot(m[1],m[2]))<=tol&&determinant(m)>0;
}
bool packetValid(float4 p){return all(isfinite(p))&&p.r>=0&&(p.r>0||all(p.yzw==0));}
float4 packet(float v,float3 velocity){return v>0?float4(v,velocity*v):0;}
float4 main(PS_IN pin){
 uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1u),row=min((uint)(pin.Tex.y*7),6u);float4 result=0;bool ok=birthContext();
 float4 spawn=txTrace.Load(int3(i,0,0)),motion=txTrace.Load(int3(i,1,0)),allocation=txTrace.Load(int3(i,2,0)),ledger=txTrace.Load(int3(i,3,0));
 float4 incident=txTrace.Load(int3(i,5,0)),normal=txTrace.Load(int3(i,6,0)),head=txTrace.Load(int3(i,7,0));
 [unroll]for(uint k=0;k<8u;k++)ok=ok&&all(isfinite(txTrace.Load(int3(i,k,0))));
 float film=allocation.y+ledger.x,micro=allocation.z,bounce=allocation.w,attached=ledger.z;
 ok=ok&&all(allocation>=0)&&all(ledger>=0)&&film>=0&&attached>=0;
 float sum=film+micro+bounce+attached;ok=ok&&abs(sum-allocation.x)<=max((sum+allocation.x)*128*1.1920928955078125e-7,1e-9);
 float3 n=normal.xyz,tangent=incident.xyz-dot(incident.xyz,n)*n;float4 response=txContext.Load(int3(0,12,0));
 float3 bounceVelocity=tangent*response.y-dot(incident.xyz,n)*n*response.x;
 float4 incoming=packet(allocation.x,incident.xyz),f=packet(film,tangent*response.z),mi=packet(micro,0),b=packet(bounce,bounceVelocity),a=packet(attached,head.xyz);
 if(allocation.x>0)ok=ok&&incident.w==1&&normal.w==1&&abs(dot(n,n)-1)<=32*1.1920928955078125e-7&&dot(incident.xyz,n)<0;
 if(attached>0)ok=ok&&head.w==1&&spawn.z>=attached&&abs(dot(head.xyz,n))<=max(length(head.xyz)*32*1.1920928955078125e-7,1e-8);
 ok=ok&&packetValid(incoming)&&packetValid(f)&&packetValid(mi)&&packetValid(b)&&packetValid(a);
 float4 wall=float4(0,incoming.yzw-f.yzw-mi.yzw-b.yzw-a.yzw);ok=ok&&all(isfinite(wall));
 if(ok){if(row==0u)result=incoming;else if(row==1u)result=f;else if(row==2u)result=mi;else if(row==3u)result=b;else if(row==4u)result=a;else if(row==5u)result=wall;}
 if(row==6u)result=float4(ok?0:1,0,0,0);return result;
}
]====]
M.reduce=[====[
// Fixed sixteen-way tree; maximum count never becomes a per-pixel slot loop.
float4 main(PS_IN pin){
 uint i=(uint)(pin.Tex.x*gWidth),n=(uint)gInputCount;float bad=0;
 [unroll]for(uint j=0;j<16u;++j){uint k=i*16u+j;if(k<n){float4 v=txInput.Load(int3(k,(int)gStatusRow,0));if(!all(isfinite(v))||v.r!=0)bad=1;}}
 return float4(bad,0,0,0);
}
]====]
M.trace=[====[
// Immutable P2 context. Tokens and revisions are bounded exact float integers.
#define gBirthCount txContext.Load(int3(0,1,0)).w
#define gBirthTick txContext.Load(int3(0,1,0)).y
#define gBirthDt txContext.Load(int3(0,1,0)).z
#define gBirthNumberDensity txContext.Load(int3(0,4,0)).x
#define gBirthAreaM2 txContext.Load(int3(0,4,0)).y
#define gBirthExposure txContext.Load(int3(0,4,0)).z
#define gBirthIncidentAirFraction txContext.Load(int3(0,4,0)).w
#define gBirthWeights txContext.Load(int3(0,5,0))
#define gBirthAirWorld txContext.Load(int3(0,6,0)).xyz
#define gBirthTangentFraction txContext.Load(int3(0,6,0)).w
#define gBirthRhoWater txContext.Load(int3(0,7,0)).x
#define gBirthGamma txContext.Load(int3(0,7,0)).y
#define gBirthMu txContext.Load(int3(0,7,0)).z
#define gBirthMinPersistentMM txContext.Load(int3(0,7,0)).w
#define gBirthWetOverride txContext.Load(int3(0,8,0)).x
#define gBirthWetOn txContext.Load(int3(0,8,0)).y
#define gBirthWetHeightUM txContext.Load(int3(0,8,0)).z
#define gBirthNormalSign txContext.Load(int3(0,8,0)).w
#define gBirthAdvanceBare txContext.Load(int3(0,9,0)).x
#define gBirthAdvanceCoat txContext.Load(int3(0,9,0)).y
#define gBirthTheta txContext.Load(int3(0,9,0)).z
#define gPoolOn txContext.Load(int3(0,10,0)).x
#define gPoolCount txContext.Load(int3(0,10,0)).y
#define gPoolTick txContext.Load(int3(0,10,0)).z
#define gFilmGrid txContext.Load(int3(0,11,0)).xy
#define gFilmPad txContext.Load(int3(0,11,0)).z
#define gBirthObjectToWorld float4x4(txContext.Load(int3(0,13,0)),txContext.Load(int3(0,14,0)),txContext.Load(int3(0,15,0)),txContext.Load(int3(0,16,0)))
bool birthInteger(float x){return isfinite(x)&&x>=0&&x<=1048575&&x==floor(x);}
bool birthUnit(float x){return isfinite(x)&&x>=0&&x<=1;}
bool birthContext(){
 float4 token=txContext.Load(int3(0,0,0)),frame=txContext.Load(int3(0,1,0)),clock=txContext.Load(int3(0,2,0));
 float4 prev=txContext.Load(int3(0,17,0)),revision=txContext.Load(int3(0,3,0)),supply=txContext.Load(int3(0,4,0)),weights=gBirthWeights;
 float4 material=txContext.Load(int3(0,7,0)),wet=txContext.Load(int3(0,8,0)),angles=txContext.Load(int3(0,9,0)),pool=txContext.Load(int3(0,10,0)),grid=txContext.Load(int3(0,11,0)),response=txContext.Load(int3(0,12,0));
 bool ok=true;[unroll]for(uint k=0;k<18u;k++)ok=ok&&all(isfinite(txContext.Load(int3(0,k,0))));
 ok=ok&&birthInteger(token.x)&&token.x>0&&birthInteger(token.y)&&token.y>0&&token.y<1048575&&birthInteger(token.z)&&token.z>0&&token.w==1&&
  all(prev.xy==token.xy)&&birthInteger(prev.z)&&prev.z+1==token.z&&prev.w==1&&frame.x>=0&&frame.x<=16777215&&frame.x==floor(frame.x)&&birthInteger(frame.y)&&frame.w==gCount&&frame.z>0&&frame.z<=.05;
 float span=(clock.z-clock.x)*65536+(clock.w-clock.y);
 ok=ok&&all(clock>=0)&&all(clock==floor(clock))&&clock.x<=16777215&&clock.z<=16777215&&clock.y<65536&&clock.w<65536&&span>0&&span<=52428&&frame.z==span/1048576;
 ok=ok&&all(revision>=0)&&all(revision<=1048575)&&all(revision==floor(revision))&&supply.x>=0&&supply.y>0&&birthUnit(supply.z)&&birthUnit(supply.w)&&
  all(weights>=0)&&abs(dot(weights,1)-1)<=8*1.1920928955078125e-7&&birthUnit(gBirthTangentFraction)&&
  material.x>0&&material.y>0&&material.z>=0&&material.w>=0&&birthUnit(wet.x)&&(wet.y==0||wet.y==1)&&wet.z>0&&abs(wet.w)==1&&
  angles.x>0&&angles.x<180&&angles.y>0&&angles.y<180&&angles.z>0&&angles.z<180&&angles.w==0&&
  (pool.x==0||pool.x==1)&&pool.y==gCount&&pool.z==frame.y&&pool.w==0&&all(grid.xy==float2(gFieldWidth,gFieldHeight))&&grid.z>=1&&grid.z<=16&&grid.z==floor(grid.z)&&grid.w==1&&
  birthUnit(response.x)&&birthUnit(response.y)&&birthUnit(response.z)&&response.w==1;
 float3x3 m=(float3x3)gBirthObjectToWorld;float a=dot(m[0],m[0]),b=dot(m[1],m[1]),c=dot(m[2],m[2]),tol=max(a,b)*32*1.1920928955078125e-7;
 return ok&&a>1e-20&&abs(a-b)<=tol&&abs(a-c)<=tol&&abs(dot(m[0],m[1]))<=tol&&abs(dot(m[0],m[2]))<=tol&&abs(dot(m[1],m[2]))<=tol&&determinant(m)>0;
}
SamplerState samLinearClamp;
// KN5 local metres / raw signed UV. Discrete reads avoid blending different
// island Jacobians. Source boundary alpha is authoritative; never wrap it.
float4 rainMetricTap(Texture2D tx, float2 uv) {
    uint w=1u,h=1u;tx.GetDimensions(w,h);
    return tx.Load(int3(clamp((int2)(uv*float2(w,h)),int2(0,0),int2(w-1,h-1)),0));
}
void rainMetric(float2 p,out float3 u,out float3 v) {
    float2 uv=float2(p.x,p.y+1);
    u=rainMetricTap(txRainDu,uv).xyz;v=rainMetricTap(txRainDv,uv).xyz;
}
float rainCoating(float2 p) {return rainMetricTap(txRainDv,float2(p.x,p.y+1)).a;}
float rainValid(float2 p) {
    float inside=all(p>=float2(0,-1))&&all(p<=float2(1,0)) ? 1 : 0;
    float alpha=rainMetricTap(txRainBoundaryMask,float2(p.x,p.y+1)).a;
    float support=saturate(rainMetricTap(txRainDu,float2(p.x,p.y+1)).a);
    return inside*alpha*support;
}
// P1 shared physical primitives. Lengths/velocity/force use m, m/s, N;
// authoritative stored volume is mm^3. No display/texel/reference-size inputs.
// Reduced attached-drop model, not CFD. Material/contact/aero inputs are explicit.
float rainSiVolumeMM3(float equivalentDiameterMM) {
    float d=max(equivalentDiameterMM,0);
    return 0.523598775598299*d*d*d;
}
float rainSiEquivalentDiameterMM(float volumeMM3) {
    return pow(max(volumeMM3,0)*1.90985931710274,1.0/3.0);
}
float rainSiMassKG(float volumeMM3,float rhoWater) {
    return max(volumeMM3,0)*1e-9*max(rhoWater,0);
}
float rainSiContactRadiusMM(float volumeMM3,float thetaDeg) {
    // Valid material input angles are strictly between 0 and 180 degrees.
    float t=tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
    return pow(max(volumeMM3,0)*1.90985931710274/(t*(3+t*t)),1.0/3.0);
}
float rainSiCapHeightMM(float radiusMM,float thetaDeg) {
    return max(radiusMM,0)*tan(clamp(thetaDeg,.1,179.9)*0.00872664625997165);
}
float rainSiPinningN(float widthMM,float thetaR,float thetaA,float gamma,float shapeK) {
    float hysteresis=max(cos(thetaR*0.0174532925199433)-cos(thetaA*0.0174532925199433),0);
    return max(shapeK,0)*max(gamma,0)*max(widthMM,0)*.001*hysteresis;
}
float rainSiWeber(float equivalentDiameterMM,float normalImpactMS,float rhoWater,float gamma) {
    return max(rhoWater,0)*normalImpactMS*normalImpactMS*max(equivalentDiameterMM,0)*.001/max(gamma,1e-9);
}
float3 rainSiTangent(float3 v,float3 normal) {
    return v-normal*dot(v,normal);
}
float3 rainSiAirForceN(float3 relativeAirMS,float3 velocityMS,float3 normal,
    float contactRadiusMM,float capHeightMM,float rhoAir,float attachedCd) {
    float3 rel=relativeAirMS-velocityMS;
    float speed=length(rel);
    float a=max(contactRadiusMM,0)*.001;
    float h=max(capHeightMM,0)*.001;
    float incidence=speed>1e-9 ? saturate(abs(dot(rel,normal))/speed) : 0;
    // Projected cap-area approximation: grazing wind still has nonzero exposed area.
    // Caller supplies local surface air (including shielding), not a force gain.
    float area=lerp(2*a*h,3.141592653589793*a*a,incidence);
    return .5*max(rhoAir,0)*max(attachedCd,0)*area*speed*rel;
}
float3 rainSiIntegrateSlip(float3 velocityMS,float3 drivingForceN,float3 normal,
    float massKG,float staticPinN,float kineticPinN,float viscousKGPerS,float dt) {
    float3 v=rainSiTangent(velocityMS,normal);
    float3 force=rainSiTangent(drivingForceN,normal);
    float step=max(dt,0);
    if(massKG<=1e-16) return 0;
    if(step<=0) return v;
    // Numerical rest epsilon is in m/s. No diameter-based arbitrary speed cap.
    if(length(v)<=1e-7 && length(force)<=max(staticPinN,0)) return 0;
    float c=max(viscousKGPerS,0);
    float safeMass=max(massKG,1e-16);
    float decay=exp(-c*step/safeMass);
    float response=c>1e-16 ? (1-decay)/max(c,1e-16) : step/safeMass;
    float3 freeV=v*decay+force*response;
    float speed=length(freeV);
    // Proximal dry-friction update cannot reverse velocity through zero.
    float remaining=max(speed-max(kineticPinN,0)*response,0);
    return freeV*(remaining/max(speed,1e-16));
}
float3 rainSiSlideWorld(float3 velocityMS,float3 gravityMS2,float3 inertiaMS2,
    float3 localAirMS,float3 normal,float volumeMM3,float theta,float thetaR,float thetaA,
    float dynamicThetaR,float dynamicThetaA,float rhoWater,float mu,float gamma,
    float rhoAir,float attachedCd,float shapeK,float viscousShape,float dt) {
    float radius=rainSiContactRadiusMM(volumeMM3,theta);
    float height=rainSiCapHeightMM(radius,theta);
    float mass=rainSiMassKG(volumeMM3,rhoWater);
    float3 drive=mass*(gravityMS2+inertiaMS2)
        +rainSiAirForceN(localAirMS,velocityMS,normal,radius,height,rhoAir,attachedCd);
    float staticPin=rainSiPinningN(2*radius,thetaR,thetaA,gamma,shapeK);
    float kineticPin=rainSiPinningN(2*radius,dynamicThetaR,dynamicThetaA,gamma,shapeK);
    float c=max(viscousShape,0)*max(mu,0)*2*radius*.001;
    return rainSiIntegrateSlip(velocityMS,drive,normal,mass,staticPin,kineticPin,c,dt);
}
float2 rainSiProjectUV(float3 duWorld,float3 dvWorld,float3 displacementM) {
    float a=dot(duWorld,duWorld),b=dot(duWorld,dvWorld),c=dot(dvWorld,dvWorld);
    float det=a*c-b*b;
    if(det<=1e-20) return 0; // Caller rejects an unsupported/degenerate surface.
    return float2(c*dot(duWorld,displacementM)-b*dot(dvWorld,displacementM),
        a*dot(dvWorld,displacementM)-b*dot(duWorld,displacementM))/max(det,1e-20);
}
float3 rainSiWorldVelocity(float3 duWorld,float3 dvWorld,float2 uvVelocity) {
    return duWorld*uvVelocity.x+dvWorld*uvVelocity.y;
}
float3 rainSiMergedVelocity(float3 a,float3 b,float volumeA,float volumeB) {
    float va=max(volumeA,0),vb=max(volumeB,0),total=va+vb;
    return (a*va+b*vb)/max(total,1e-16); // Same liquid density, no radius/display weights.
}
// P4b bounded, unique region -> slot ownership. Counts and tick are integers.
uint poolTilesX() {return ((uint)gFilmGrid.x+15u)/16u;}
uint poolTileCount() {return poolTilesX()*(((uint)gFilmGrid.y+15u)/16u);}
uint poolRotation() {
    uint groups=((uint)max(gPoolCount,1)+poolTileCount()-1u)/poolTileCount();
    // Advance region rotation after a complete slot-group cycle. Using tick
    // directly aliases groups/regions at common counts such as 4096 slots.
    return ((uint)gPoolTick/groups)%poolTileCount();
}
uint poolOwner(uint tile) {
    uint tiles=poolTileCount(),count=(uint)max(gPoolCount,1),tick=(uint)gPoolTick;
    uint group=tick%((count+tiles-1u)/tiles);
    return group*tiles+(tile+tiles-poolRotation())%tiles;
}
struct BirthEvaluation{float4 spawn,motion,allocation,ledger,pool,incident,normal,head;};
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
BirthEvaluation evaluateBirth(uint index) {
    BirthEvaluation trace;trace.incident=0;trace.normal=0;trace.head=0;
    uint count=(uint)max(gBirthCount,1);
    uint tick=(uint)gBirthTick;
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
        trace.incident=float4(relative,1);trace.normal=float4(n,1);
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
        trace.head=float4(rainSiWorldVelocity(uw,vw,initialUV),1);
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
        uint tiles=poolTileCount(),tile=(index%tiles+poolRotation())%tiles;
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
    trace.spawn=spawn;trace.motion=motion;trace.allocation=allocation;trace.ledger=ledger;trace.pool=pool;
    return trace;
}
float4 main(PS_IN pin){
 uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1u),row=min((uint)(pin.Tex.y*8),7u);if(!birthContext())return 0;
 BirthEvaluation t=evaluateBirth(i);return row==0u?t.spawn:row==1u?t.motion:row==2u?t.allocation:row==3u?t.ledger:row==4u?t.pool:row==5u?t.incident:row==6u?t.normal:t.head;
}
]====]
return M
