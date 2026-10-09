SamplerState e1MaterialSampler {Filter=MIN_MAG_MIP_LINEAR;AddressU=WRAP;AddressV=WRAP;AddressW=WRAP;};
// Independent local-space BVHs. Source UV is the hit housing triangle UV.
// No camera capture depth or INT/EXT/COATING UV correspondence is used.
float4 e1Record(Texture2D data, int index) {
    return data.Load(int3(index & 1023, index >> 10, 0));
}
// Each candidate projects the SAME BVH hit, never traces capture depth.
// Validate bilinear taps independently so a neighbouring mesh cannot lend colour.
float4 e1Colour(Texture2D colour,Texture2D depth,float4x4 view,float4x4 projection,
    float3 hitRelative,float expectedID,float active,out float meanLum) {
    meanLum=0;
    if(active<0.5) return 0;
    float3 vp=mul(float4(hitRelative,0),view).xyz;
    float4 clip=mul(float4(vp,1),projection);
    if(clip.w<=0) return 0;
    float2 uv=float2(clip.x/clip.w*0.5+0.5,0.5-clip.y/clip.w*0.5);
    if(any(uv<=0) || any(uv>=1)) return 0;
    uint width,height,levels;
    colour.GetDimensions(0,width,height,levels);
    float2 grid=uv*float2(width,height)-0.5;
    int2 base=(int2)floor(grid);float2 blend=frac(grid);
    float3 radiance=0;float support=0;
    [unroll] for(int y=0;y<2;y++) [unroll] for(int x=0;x<2;x++) {
        int2 pixel=base+int2(x,y);
        if(any(pixel<0) || pixel.x>=(int)width || pixel.y>=(int)height) continue;
        float4 metric=depth.Load(int3(pixel,0));
        if(metric.a<0.5 || abs(metric.g-expectedID)>0.001
            || abs(metric.r-abs(vp.z))>gE1ColourTolerance) continue;
        float4 c=colour.Load(int3(pixel,0));
        if(c.a<0.01) continue;
        float weight=(x==0?1-blend.x:blend.x)*(y==0?1-blend.y:blend.y);
        radiance+=max(c.rgb,0)/max(c.a,0.01)*weight;
        support+=weight;
    }
    if(support<=0.001) return 0;
    float edge=saturate(min(min(uv.x,uv.y),min(1-uv.x,1-uv.y))*min(width,height)/4);
    float4 average=colour.SampleLevel(e1MaterialSampler,float2(0.5,0.5),levels-1);
    meanLum=dot(max(average.rgb,0)/max(average.a,0.001),float3(0.2126,0.7152,0.0722));
    return float4(radiance/support,support*edge);
}
bool e1Box(float3 origin, float3 direction, float3 lo, float3 hi, float best) {
    float first=0.0005,last=best;
    [unroll] for(int axis=0;axis<3;axis++) {
        if(direction[axis]==0) {
            if(origin[axis]<lo[axis] || origin[axis]>hi[axis]) return false;
        } else {
            float a=(lo[axis]-origin[axis])/direction[axis];
            float b=(hi[axis]-origin[axis])/direction[axis];
            first=max(first,min(a,b));last=min(last,max(a,b));
        }
    }
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
    [loop] for (int iteration=0;iteration<65536 && node<total;iteration++) {
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
    if(gE1FaceVisible>0.5) {
        if(e1Mesh(txE1FaceNodes,txE1FaceTriangles,gE1FaceInverse,origin,ray,best,candidate,done)) {material=3;uv=candidate;}
        complete=complete && done;
    }
    if(gE1BalaklavaVisible>0.5) {
        if(e1Mesh(txE1BalaklavaNodes,txE1BalaklavaTriangles,gE1BalaklavaInverse,origin,ray,best,candidate,done)) {material=4;uv=candidate;}
        complete=complete && done;
    }
    if(gE1Mode>5.5 && gE1Mode<6.5) {
        float3 c=!complete?float3(0,0,1):material>=0?float3(0,1,0):float3(1,0,0);
        return float4(c*0.7,0.7);
    }
    if(gE1Mode>8.5 && (!complete || material<0))
        return float4(!complete?float3(0,0,1):float3(1,0,0),1);
    if(!complete || material<0) return float4(0,0,0,gE1Mode<0.5?length(pin.PosC):0);
    float cosine=saturate(abs(dot(normal,eyeDirection)));
    float f=0.05135+0.94865*pow(1-cosine,5);
    float3 color=material==0?float3(1,0.15,0.05):material==1?float3(0.05,1,0.15)
        :material==2?float3(0.1,0.2,1):material==3?float3(1,1,0):float3(1,0,1);
    if(gE1Mode>0.5 && gE1Mode<1.5) return float4(0,1,0,1);
    if(gE1Mode>1.5 && gE1Mode<2.5) return float4(f.xxx,1);
    if(gE1Mode>7.5 && gE1Mode<8.5) return float4(saturate((origin+ray*best-gE1LocalOrigin)/gE1Range*0.5+0.5),1);
    if(gE1Mode>6.5 && gE1Mode<7.5) return float4((best/max(gE1Range,0.001)).xxx,1);
    if(gE1Mode>4.5 && gE1Mode<5.5) return float4(frac(uv),0,1);
    if(gE1Checker>0.5 && gE1Mode>2.5 && gE1Mode<3.5) {
        float checker=fmod(floor(uv.x*16)+floor(uv.y*16),2);
        return float4(color*lerp(0.3,1,checker),1);
    }
    float3 hitRelative=pin.PosC+ray*best;
    float mean0,mean1,mean2;
    float4 c0=e1Colour(txE1Colour0,txE1Depth0,gE1View0,gE1Projection0,
        hitRelative+gE1EyeToSource0,material+1,gE1SourceActive0,mean0);
    float4 c1=e1Colour(txE1Colour1,txE1Depth1,gE1View1,gE1Projection1,
        hitRelative+gE1EyeToSource1,material+1,gE1SourceActive1,mean1);
    float4 c2=e1Colour(txE1Colour2,txE1Depth2,gE1View2,gE1Projection2,
        hitRelative+gE1EyeToSource2,material+1,gE1SourceActive2,mean2);
    float total=c0.a+c1.a+c2.a;
    if(gE1Mode>8.5 && gE1Mode<9.5)
        return float4(total>0.001?float3(0,1,0):float3(1,0.5,0),1);
    if(gE1Mode>9.5)
        return float4(total<=0.001?float3(1,0.5,0):c0.a>=c1.a && c0.a>=c2.a?float3(1,0,0)
            :c1.a>=c2.a?float3(0,1,0):float3(0,0,1),1);
    if(total<=0.001) return float4(0,0,0,gE1Mode<0.5?length(pin.PosC):0);
    float3 image=(c0.rgb*c0.a+c1.rgb*c1.a+c2.rgb*c2.a)/total;
    float meanLum=(mean0*c0.a+mean1*c1.a+mean2*c2.a)/total;
    float lum=dot(image,float3(0.2126,0.7152,0.0722));
    float reference=gE1FixedReference>0.5 ? max(gE1MeanFloor,0.001) : max(meanLum,gE1MeanFloor);
    float q=lum/reference;
    float gate=smoothstep(gE1Threshold,gE1Threshold+max(max(gE1Knee,0.001),fwidth(q)),q);
    float coverage=saturate(total);
    if(gE1Mode>3.5) return float4(gate.xxx*coverage,coverage);
    if(gE1Mode>2.5) return float4(image*coverage,coverage);
    float excess=max(lum-reference*gE1Threshold,0)/max(lum,0.001);
    float highlight=lerp(1,excess,saturate(gE1Isolation));
    return float4(image*highlight*coverage*gate*f*max(gE1Gain,0),length(pin.PosC));
}
