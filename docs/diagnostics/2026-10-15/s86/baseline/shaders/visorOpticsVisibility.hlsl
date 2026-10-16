float optVisibility(float3 localPoint,float3 localDirection) {
    float3 direction=normalize(mul(float4(localDirection,0),gOptPose).xyz);
    float3 origin=mul(float4(localPoint,1),gOptPose).xyz+direction*.001;
    float distance=gOptRange;float2 uv;float3 normal,tangent,bitangent;bool complete;
    int id=optClosest(origin,direction,distance,uv,normal,tangent,bitangent,complete);
    if(!complete || id>0)return 0;
    float bandDistance=gOptRange;
    if(gOptBandVisible>.5 && optMesh(gOptBandRecords,
        gOptBandInverse,origin,direction,bandDistance,uv,normal,tangent,bitangent,complete)) {
        if(!complete)return 0;
        float opacity=optRepeat(txOptBandDiffuse,uv).a;
        return lerp(gOptGlassTransmission,gOptBandTransmission,saturate(opacity));
    }
    return 1;
}
float4 main(PS_IN pin) {
    float4 hit=txOptHit.SampleLevel(samPointClamp,pin.Tex,0);
    float4 previous=txOptPrevious.SampleLevel(samPointClamp,pin.Tex,0);
    if(hit.a<.5)return 0;
    float3 n=optUnOct(txOptSurface.SampleLevel(samPointClamp,pin.Tex,0).rg);
    float z=1-2*(gOptSample+.5)/32;
    float angle=gOptSample*2.39996323;
    float3 direction=float3(sqrt(saturate(1-z*z))*cos(angle),z,sqrt(saturate(1-z*z))*sin(angle));
    if(gOptVisibilityPass<.5) {
        // Uniform sphere -> real SH L1 coefficients, normalization is 4pi/N.
        float visibility=optVisibility(hit.xyz,direction);
        return previous+visibility*float4(.28209479,.48860251*direction.xyz)*(12.5663706/32);
    }
    // Eight cosine weighted hemisphere rays around the interpolated normal.
    float radius=sqrt((gOptSample+.5)/8),phi=gOptSample*2.39996323;
    float3 tangent=normalize(cross(abs(n.y)<.9?float3(0,1,0):float3(1,0,0),n));
    direction=tangent*(radius*cos(phi))+cross(n,tangent)*(radius*sin(phi))+n*sqrt(1-radius*radius);
    return previous+float4(0,0,0,optVisibility(hit.xyz+n*.001,direction)/8);
}
