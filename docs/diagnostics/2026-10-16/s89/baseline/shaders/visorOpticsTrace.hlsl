// Change-only BVH bake. Algorithm follows e1HousingGeometry.hlsl; vertex
// normals use the SAME packed triangle order as the existing BVH.
float4 optRecord(Texture2D data,int index) {return data.Load(int3(index&1023,index>>10,0));}
float2 optOct(float3 n) {
    n/=max(abs(n.x)+abs(n.y)+abs(n.z),1e-8);
    return n.z>=0?n.xy:(1-abs(n.yx))*float2(n.x>=0?1:-1,n.y>=0?1:-1);
}
float3 optUnOct(float2 p) {
    float3 n=float3(p,1-abs(p.x)-abs(p.y));
    if(n.z<0)n.xy=(1-abs(n.yx))*float2(n.x>=0?1:-1,n.y>=0?1:-1);
    return normalize(n);
}
bool optBox(float3 o,float3 d,float3 lo,float3 hi,float best) {
    float first=.0005,last=best;
    [unroll]for(int axis=0;axis<3;axis++) {
        if(d[axis]==0) {if(o[axis]<lo[axis] || o[axis]>hi[axis])return false;}
        else {float a=(lo[axis]-o[axis])/d[axis],b=(hi[axis]-o[axis])/d[axis];
            first=max(first,min(a,b));last=min(last,max(a,b));}
    }
    return last>=first;
}
float3 optWorldVector(float3 v,float4x4 inverseWorld) {
    float3 a=inverseWorld[0].xyz,b=inverseWorld[1].xyz,c=inverseWorld[2].xyz;
    float determinant=dot(a,cross(b,c));
    return float3(dot(v,cross(b,c)),dot(v,cross(c,a)),dot(v,cross(a,b)))/determinant;
}
bool optMesh(float3 records,float4x4 inverseWorld,
    float3 origin,float3 direction,inout float best,out float2 uv,out float3 normal,
    out float3 tangent,out float3 bitangent,out bool complete) {
    float3 o=mul(float4(origin,1),inverseWorld).xyz,d=mul(float4(direction,0),inverseWorld).xyz;
    int nodeBase=(int)records.x,triBase=(int)records.y,normalBase=(int)records.z;
    int node=0,total=(int)optRecord(txOptGeometry,nodeBase+1).w;bool found=false;uv=0;normal=0;tangent=0;bitangent=0;
    [loop]for(int iteration=0;iteration<65536 && node<total;iteration++) {
        float4 a=optRecord(txOptGeometry,nodeBase+node*2),b=optRecord(txOptGeometry,nodeBase+node*2+1);
        if(!optBox(o,d,a.xyz,b.xyz,best)){node=(int)b.w;continue;}
        if(a.w<0){node++;continue;}
        int start=(int)a.w>>4,count=(int)a.w&15;
        [loop]for(int k=0;k<count;k++) {
            int triIndex=start+k,record=triBase+triIndex*4;
            float4 va=optRecord(txOptGeometry,record),vb=optRecord(txOptGeometry,record+1),vc=optRecord(txOptGeometry,record+2);
            float3 ab=vb.xyz-va.xyz,ac=vc.xyz-va.xyz,p=cross(d,ac);float det=dot(ab,p);
            if(abs(det)<1e-10)continue;
            float3 offset=o-va.xyz;float u=dot(offset,p)/det;
            if(u<0 || u>1)continue;
            float3 q=cross(offset,ab);float v=dot(d,q)/det;
            if(v<0 || u+v>1)continue;
            float t=dot(ac,q)/det;if(t<=.0005 || t>=best)continue;
            float3 weights=float3(1-u-v,u,v),vy=optRecord(txOptGeometry,record+3).xyz;
            uv=float2(dot(weights,float3(va.w,vb.w,vc.w)),dot(weights,vy));
            float3 n=optRecord(txOptGeometry,normalBase+triIndex*3).xyz*weights.x
                +optRecord(txOptGeometry,normalBase+triIndex*3+1).xyz*weights.y
                +optRecord(txOptGeometry,normalBase+triIndex*3+2).xyz*weights.z;
            // Inverse transpose to world, also supports uniform model scale.
            normal=normalize(mul(n,(float3x3)transpose(inverseWorld)));
            // UV basis comes from this triangle, never neighbouring screen
            // pixels (which may hit another triangle, UV island or mesh).
            float2 du1=float2(vb.w-va.w,vy.y-vy.x),du2=float2(vc.w-va.w,vy.z-vy.x);
            float uvDet=du1.x*du2.y-du1.y*du2.x;
            tangent=0;bitangent=0;
            if(abs(uvDet)>1e-12) {
                tangent=optWorldVector((ab*du2.y-ac*du1.y)/uvDet,inverseWorld);
                bitangent=optWorldVector((ac*du1.x-ab*du2.x)/uvDet,inverseWorld);
            }
            best=t;found=true;
        }
        node=(int)b.w;
    }
    complete=node>=total;return found;
}
int optClosest(float3 origin,float3 direction,inout float distance,out float2 uv,out float3 normal,
    out float3 tangent,out float3 bitangent,out bool complete) {
    int id=0;uv=0;normal=0;tangent=0;bitangent=0;complete=true;float2 candidate;float3 n,t,b;bool done;
    #define OPT_MESH(KEY,ID) if(gOpt##KEY##Visible>.5){ \
        if(optMesh(gOpt##KEY##Records,gOpt##KEY##Inverse, \
            origin,direction,distance,candidate,n,t,b,done)){id=ID;uv=candidate;normal=n;tangent=t;bitangent=b;}complete=complete&&done;}
    OPT_MESH(Frame,1) OPT_MESH(Rubber,2) OPT_MESH(Fabric,3) OPT_MESH(Face,4) OPT_MESH(Balaklava,5) OPT_MESH(Cam,6) OPT_MESH(CamFabric,8)
    #undef OPT_MESH
    return id;
}
float3 optMapNormal(float3 n,float3 tangent,float3 bitangent,float2 xy) {
    float3 t=tangent-n*dot(n,tangent);
    if(dot(t,t)<1e-20 || dot(bitangent,bitangent)<1e-20)return n;
    t=normalize(t);
    float3 b=cross(n,t);
    b*=dot(b,bitangent)<0?-1:1;
    float3 result=t*xy.x+b*xy.y+n*sqrt(saturate(1-dot(xy,xy)));
    return dot(result,result)>1e-12?normalize(result):n;
}
float4 optRepeatMip(Texture2D image,float2 uv,uint mip) {
    uint w,h,levels;image.GetDimensions(mip,w,h,levels);
    float2 size=float2(w,h),grid=uv*size-.5,base=floor(grid),blend=frac(grid);
    int2 a=(int2)(base-floor(base/size)*size),b=(int2)((base+1)-floor((base+1)/size)*size);
    return lerp(lerp(image.Load(int3(a,mip)),image.Load(int3(b.x,a.y,mip)),blend.x),
        lerp(image.Load(int3(a.x,b.y,mip)),image.Load(int3(b,mip)),blend.x),blend.y);
}
float4 optRepeat(Texture2D image,float2 uv) {return optRepeatMip(image,uv,0);}
float4 optMaterialSample(Texture2D image,float2 uv) {
    uint w,h,levels;image.GetDimensions(0,w,h,levels);
    float footprint=max(length(ddx(uv)*float2(w,h)),length(ddy(uv)*float2(w,h)));
    uint mip=(uint)clamp(floor(log2(max(footprint,1))),0,(float)levels-1);
    return optRepeatMip(image,uv,mip);
}
