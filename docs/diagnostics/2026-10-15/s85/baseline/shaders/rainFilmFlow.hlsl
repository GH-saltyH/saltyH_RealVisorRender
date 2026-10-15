// P4a reduced, quasi-steady thin-film donor transport. Not a contact-line/CFD solver.
// Flux channels are actual departing film volumes / mm3: left,right,up,down.
struct FilmFlow { float4 flux; float courant; };
FilmFlow ffEvaluate(int2 p) {
    FilmFlow result;result.flux=0;result.courant=0;
    int2 inner=p-(int)gFilmPad;
    if(any(inner<0)||any(inner>=(int2)gFilmGrid))return result;
    float volume=max(txFilmPrevious.Load(int3(p,0)).r,0);
    float area=txFilmCells.Load(int3(inner,0)).r*gFilmScale2;
    if(volume<=0||area<=0||gFilmDt<=0)return result;
    float2 uv=(inner+.5)/gFilmGrid;
    float3 u,v;rainMetric(float2(uv.x,uv.y-1),u,v);
    float3 uw=mul(u,(float3x3)gFilmObjectToWorld),vw=mul(v,(float3x3)gFilmObjectToWorld);
    float3 crossUV=cross(uw,vw);float n2=dot(crossUV,crossUV);
    if(n2<1e-20)return result;
    float3 n=crossUV*rsqrt(max(n2,1e-20));
    float3 air=gFilmAirWorld;
    if(gFilmAirDownward>.5) {
        float3 down=rainSiTangent(float3(0,-1,0),n);float len=length(down);
        if(len>1e-6) {down/=len;air+=down*(length(air)*.30*max(gFilmAirDownwardGain,0)-dot(air,down));}
    }
    air=rainSiTangent(air,n);
    float3 tau=.5*gFilmAirRho*gFilmFlowCf*length(air)*air;
    float h=volume/area*.001; // mm3/mm2 -> m; physical stock only.
    float3 velocity=rainSiTangent(gFilmAccelerationWorld,n)*(998.2*h*h/(3*gFilmMu))
        +tau*(h/(2*gFilmMu));
    float2 travel=rainSiProjectUV(uw,vw,velocity)*gFilmGrid*gFilmDt;
    result.courant=abs(travel.x)+abs(travel.y);
    float2 share=abs(travel)*min(1,gFilmFlowCFL/max(result.courant,1e-30));
    // Matched quantized debits: gather subtracts in this same X then Y order.
    precise float restX=volume-volume*share.x;
    precise float movedX=volume-restX;
    precise float restY=restX-volume*share.y;
    precise float movedY=restX-restY;
    result.flux=float4(travel.x<0 ? movedX : 0,travel.x>=0 ? movedX : 0,
                      travel.y<0 ? movedY : 0,travel.y>=0 ? movedY : 0);
    return result;
}
