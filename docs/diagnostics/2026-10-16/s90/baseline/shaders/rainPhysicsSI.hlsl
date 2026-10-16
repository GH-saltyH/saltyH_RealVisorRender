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
