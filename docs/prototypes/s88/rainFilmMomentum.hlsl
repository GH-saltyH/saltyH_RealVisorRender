// OFFLINE paired gather: advect the predicted velocity with the *same*
// quantized film-volume face fluxes used by production pfResolve.
float4 fiFlux(int2 p) {
    if(any(p<0)||any(p>=(int2)gFilmGrid))return 0;
    return txFilmFlux.Load(int3(p,0));
}
float3 fiWorldVelocity(int2 p) {
    if(any(p<0)||any(p>=(int2)gFilmGrid))return 0;
    float2 uv=(p+.5)/gFilmGrid;float3 u,v;rainMetric(float2(uv.x,uv.y-1),u,v);
    float2 velocity=txFilmPredicted.Load(int3(p,0)).rg;
    return mul(u,(float3x3)gFilmObjectToWorld)*velocity.x
        +mul(v,(float3x3)gFilmObjectToWorld)*velocity.y;
}
float4 main(PS_IN pin) {
    int2 p=min((int2)(pin.Tex*gFilmGrid),(int2)gFilmGrid-1);
    float4 result=0;
    float4 current=txFilmCurrent.Load(int3(p+(int)gFilmPad,0));
    float area=txFilmCells.Load(int3(p,0)).r*gFilmScale2;
    if(current.r>0 && area>0) {
        float4 outgoing=fiFlux(p);
        precise float remainX=poolAvailable(p+(int)gFilmPad)-(outgoing.x+outgoing.y);
        precise float remainY=remainX-(outgoing.z+outgoing.w);
        float4 arriving=float4(fiFlux(p+int2(-1,0)).y,fiFlux(p+int2(1,0)).x,
                              fiFlux(p+int2(0,-1)).w,fiFlux(p+int2(0,1)).z);
        float3 momentum=fiWorldVelocity(p)*max(remainY,0)
            +fiWorldVelocity(p+int2(-1,0))*arriving.x+fiWorldVelocity(p+int2(1,0))*arriving.y
            +fiWorldVelocity(p+int2(0,-1))*arriving.z+fiWorldVelocity(p+int2(0,1))*arriving.w;
        float evaporated=max(current.b-txFilmPrevious.Load(int3(p+(int)gFilmPad,0)).b,0);
        // pfResolve evaporates film/micro in the same fraction. New deposits
        // and joined micro carry zero tangent momentum in this candidate.
        float retained=(current.r+current.g)/max(current.r+current.g+evaporated,1e-30);
        float3 velocity=momentum*(retained/current.r);
        float2 uv=(p+.5)/gFilmGrid;float3 u,v;rainMetric(float2(uv.x,uv.y-1),u,v);
        float3 uw=mul(u,(float3x3)gFilmObjectToWorld),vw=mul(v,(float3x3)gFilmObjectToWorld);
        result.rg=rainSiProjectUV(uw,vw,velocity);
    }
    return result;
}
