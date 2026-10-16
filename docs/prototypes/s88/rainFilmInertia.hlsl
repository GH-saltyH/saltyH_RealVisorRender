// OFFLINE P4c candidate. Not loaded by the game.
// Frozen-height, depth-averaged relaxation closure. No pressure/contact line.
// RG = end-of-step UV/s; BA = interval-average UV/s for donor transport.
void fiRelax(float3 oldV,float3 acceleration,float h,float dt,out float3 next,out float3 mean) {
    float x=3*gFilmMu*dt/(998.2*h*h);
    float decay=exp(-x);
    // phi functions avoid cancellation in deep pools and avoid the
    // unbounded terminal-velocity intermediate of u_eq + (u-u_eq)e^-x.
    float phi1=0,phi2=0;
    if(x<.01) {
        phi1=1-x*.5+x*x/6-x*x*x/24;
        phi2=.5-x/6+x*x/24-x*x*x/120;
    } else {
        phi1=(1-decay)/x;phi2=(1-phi1)/x;
    }
    next=oldV*decay+acceleration*(dt*phi1);
    mean=oldV*phi1+acceleration*(dt*phi2);
}
float4 fiPredict(int2 inner) {
    float4 result=0;
    float area=txFilmCells.Load(int3(inner,0)).r*gFilmScale2;
    float volume=poolAvailable(inner+(int)gFilmPad);
    if(area>0 && volume>0) {
        float2 uv=(inner+.5)/gFilmGrid;
        float3 u,v;rainMetric(float2(uv.x,uv.y-1),u,v);
        float3 uw=mul(u,(float3x3)gFilmObjectToWorld),vw=mul(v,(float3x3)gFilmObjectToWorld);
        float3 crossUV=cross(uw,vw);float n2=dot(crossUV,crossUV);
        if(n2>1e-20) {
            float3 n=crossUV*rsqrt(n2);
            float3 air=gFilmAirWorld;
            if(gFilmAirDownward>.5) {
                float3 down=rainSiTangent(float3(0,-1,0),n);float len=length(down);
                if(len>1e-6) {
                    down/=len;
                    air+=down*(length(air)*.30*max(gFilmAirDownwardGain,0)-dot(air,down));
                }
            }
            air=rainSiTangent(air,n);
            float3 tau=.5*gFilmAirRho*gFilmFlowCf*length(air)*air;
            float h=volume/area*.001;
            float2 oldUV=txFilmVelocity.Load(int3(inner,0)).rg;
            float3 oldV=uw*oldUV.x+vw*oldUV.y;
            float3 acceleration=rainSiTangent(gFilmAccelerationWorld,n)+3*tau/(2*998.2*h);
            float3 next,mean;fiRelax(oldV,acceleration,h,max(gFilmDt,0),next,mean);
            result=float4(rainSiProjectUV(uw,vw,next),rainSiProjectUV(uw,vw,mean));
        }
    }
    return result;
}
