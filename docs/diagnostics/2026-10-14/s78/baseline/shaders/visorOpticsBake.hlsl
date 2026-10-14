float4 main(PS_IN pin) {
    float3 origin=pin.PosC+gOptEye,n=normalize(pin.NormalW);
    // E2/E3 relief belongs to its own optical layer. Its atlas seams must not
    // redirect cached reflection rays or contaminate the geometric Fresnel.
    #if OPT_BAKE_PASS == 3
    return float4(optOct(normalize(mul(float4(n,0),gOptPoseInverse).xyz)),length(pin.PosC),1);
    #else
    float3 ray=reflect(normalize(pin.PosC),n),hitN,tangent,bitangent;float2 uv;bool complete;
    float distance=gOptRange;int id=optClosest(origin,ray,distance,uv,hitN,tangent,bitangent,complete);
    #if OPT_BAKE_PASS == 0
    if(id==0 || !complete)return 0;
    #else
    // Each material draw owns only its nearest-hit pixels. Discard retains
    // pixels already written by other IDs in this capture. Normal depth
    // testing keeps the nearest INT sheet across all five material draws.
    clip(id==gOptMaterialID && complete ? 1 : -1);
    #endif
    float3 hit=origin+ray*distance;
    #if OPT_BAKE_PASS == 0
    return float4(mul(float4(hit,1),gOptPoseInverse).xyz,id);
    #elif OPT_BAKE_PASS == 2
    float4 albedo=optMaterialSample(txOptDiffuse,uv);float rough=gOptRoughness;
    if(gOptHasMaps>.5){float gloss=optMaterialSample(txOptMaps,uv).g;
        rough=sqrt(2/(max(2/max(rough*rough,.001)-2,0)*max(gloss,.01)+2));}
    return float4(pow(max(albedo.rgb,0),2.2),rough);
    #else
    float2 bump=optMaterialSample(txOptNormal,uv).rg*2-1;
    // Orient smooth normals towards the incident reflection; interior meshes
    // can be authored with opposite winding. Original KN5 is never modified.
    if(dot(hitN,-ray)<0)hitN=-hitN;
    bump.y=-bump.y;hitN=optMapNormal(hitN,tangent,bitangent,bump*gOptMaterialNormal);
    float3 localN=normalize(mul(float4(hitN,0),gOptPoseInverse).xyz);
    // Coverage/material ID lives in Hit.a; retain the authored specular
    // strength here instead. txMaps R = specular, G = gloss.
    float specular=gOptMaterialSpecular;
    if(gOptHasMaps>.5)specular*=max(optMaterialSample(txOptMaps,uv).r,0);
    return float4(optOct(localN),distance,specular);
    #endif
    #endif
}
