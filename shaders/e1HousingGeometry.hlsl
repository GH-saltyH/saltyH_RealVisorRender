SamplerState e1MaterialSampler {Filter=MIN_MAG_MIP_LINEAR;AddressU=WRAP;AddressV=WRAP;AddressW=WRAP;};
// Independent local-space BVHs. Source UV is the hit housing triangle UV.
// No camera capture depth or INT/EXT/COATING UV correspondence is used.
float4 e1Record(Texture2D data, int index) {
    return data.Load(int3(index & 1023, index >> 10, 0));
}
bool e1Box(float3 origin, float3 direction, float3 lo, float3 hi, float best) {
    float3 safe = float3(abs(direction.x)>1e-8?direction.x:1e-8,
        abs(direction.y)>1e-8?direction.y:1e-8,abs(direction.z)>1e-8?direction.z:1e-8);
    float3 a=(lo-origin)/safe,b=(hi-origin)/safe;
    float3 enter=min(a,b),exit=max(a,b);
    float first=max(max(enter.x,enter.y),max(enter.z,0.0005));
    float last=min(min(exit.x,exit.y),min(exit.z,best));
    return last>=first;
}
bool e1Mesh(Texture2D nodes,Texture2D triangles,float4x4 inverseWorld,
    float3 origin,float3 direction,inout float best,out float2 uv,out bool complete) {
    float3 o=mul(float4(origin,1),inverseWorld).xyz;
    // Keep transformed direction unnormalised: t remains world metres.
    float3 d=mul(float4(direction,0),inverseWorld).xyz;
    int node=0;
    int total=(int)e1Record(nodes,1).w;
    bool found=false;
    uv=0;
    [loop] for (int iteration=0;iteration<1024 && node<total;iteration++) {
        float4 a=e1Record(nodes,node*2),b=e1Record(nodes,node*2+1);
        if (!e1Box(o,d,a.xyz,b.xyz,best)) {node=(int)b.w;continue;}
        if (a.w<0) {node++;continue;}
        int start=(int)a.w >> 4,count=(int)a.w & 15;
        [loop] for(int k=0;k<count;k++) {
            int record=(start+k)*4;
            float4 va=e1Record(triangles,record),vb=e1Record(triangles,record+1),vc=e1Record(triangles,record+2);
            float3 ab=vb.xyz-va.xyz,ac=vc.xyz-va.xyz;
            float3 p=cross(d,ac);
            float det=dot(ab,p);
            if(abs(det)<1e-10) continue;
            float3 offset=o-va.xyz;
            float u=dot(offset,p)/det;
            if(u<0 || u>1) continue;
            float3 q=cross(offset,ab);
            float v=dot(d,q)/det;
            if(v<0 || u+v>1) continue;
            float t=dot(ac,q)/det;
            if(t<=0.0005 || t>=best) continue;
            float3 weights=float3(1-u-v,u,v);
            float3 vy=e1Record(triangles,record+3).xyz;
            uv=float2(dot(weights,float3(va.w,vb.w,vc.w)),dot(weights,vy));
            best=t;found=true;
        }
        node=(int)b.w;
    }
    complete=node>=total;
    return found;
}
float4 main(PS_IN pin) {
    float3 eyeDirection=normalize(-pin.PosC),normal=normalize(pin.NormalW);
    float3 ray=reflect(-eyeDirection,normal);
    float3 origin=pin.PosC+gE1Eye;
    float best=gE1Range;
    int material=-1;
    float2 uv=0,candidate=0;
    bool complete=true,done;
    if(gE1FrameVisible>0.5) {
        if(e1Mesh(txE1FrameNodes,txE1FrameTriangles,gE1FrameInverse,origin,ray,best,candidate,done)) {material=0;uv=candidate;}
        complete=complete && done;
    }
    if(gE1RubberVisible>0.5) {
        if(e1Mesh(txE1RubberNodes,txE1RubberTriangles,gE1RubberInverse,origin,ray,best,candidate,done)) {material=1;uv=candidate;}
        complete=complete && done;
    }
    if(gE1FabricVisible>0.5) {
        if(e1Mesh(txE1FabricNodes,txE1FabricTriangles,gE1FabricInverse,origin,ray,best,candidate,done)) {material=2;uv=candidate;}
        complete=complete && done;
    }
    if(gE1Mode>5.5) {
        float3 c=!complete?float3(0,0,1):material>=0?float3(0,1,0):float3(1,0,0);
        return float4(c*0.7,0.7);
    }
    if(!complete || material<0) return 0;
    float cosine=saturate(abs(dot(normal,eyeDirection)));
    float f=0.05135+0.94865*pow(1-cosine,5);
    float3 color=material==0?float3(1,0.15,0.05):material==1?float3(0.05,1,0.15):float3(0.1,0.2,1);
    if(gE1Mode<1.5) return float4(0,1,0,1); // final is gated by Lua
    if(gE1Mode<2.5) return float4(f.xxx,1);
    if(gE1Mode>4.5) return float4(frac(uv),0,1);
    if(gE1Checker>0.5) {
        float checker=fmod(floor(uv.x*16)+floor(uv.y*16),2);
        return float4(color*lerp(0.3,1,checker),1);
    }
    // Geometry validation albedo, not a lit/normal-mapped radiance model yet.
    float3 albedo=material==0?txE1FrameDiffuse.SampleLevel(e1MaterialSampler,uv,0).rgb
        :material==1?gE1RubberGrey.xxx:txE1FabricDiffuse.SampleLevel(e1MaterialSampler,uv,0).rgb;
    return float4(albedo/(1+max(albedo,0)),1);
}
