// Offline momentum -> tangent velocity. Wall reaction is explicit in debug
// output; this projection is NOT free global three-dimensional conservation.
float4 main(PS_IN pin) {
    int2 p=min((int2)(pin.Tex*gFilmGrid),(int2)gFilmGrid-1);
    float4 packet=txTraceCurrent.Load(int3(p,0));
    float2 uv=(p+.5)/gFilmGrid;float3 u,v;rainMetric(float2(uv.x,uv.y-1),u,v);
    float3 uw=mul(u,(float3x3)gFilmObjectToWorld),vw=mul(v,(float3x3)gFilmObjectToWorld);
    float2 velocity=rainSiProjectUV(uw,vw,packet.gba/max(packet.r,1e-30));
    float3 reaction=packet.gba-(uw*velocity.x+vw*velocity.y)*packet.r;
    return gTraceWallDebug>.5 ? float4(reaction,packet.r) : float4(velocity,0,0);
}
