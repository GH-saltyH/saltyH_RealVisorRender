// Integer-width tent basis has exact partition of unity on the cell lattice.
// The line integral is quadratic on at most seven intervals; Simpson is exact
// on each. No per-frame normalization loop or CPU stamps.
float pfBasis(float2 p,float2 cell,float2 support) {
    float2 tent=saturate(1-abs(p-cell)/support);
    return tent.x*tent.y/(support.x*support.y);
}
float pfLine(float2 a,float2 b,float2 cell,float2 support) {
    if(any(max(a,b)+support<cell)||any(min(a,b)-support>cell))return 0;
    float2 d=b-a;
    float3 rx=abs(d.x)>1e-9 ? saturate((cell.x+float3(-support.x,0,support.x)-a.x)/d.x) : 1;
    float3 ry=abs(d.y)>1e-9 ? saturate((cell.y+float3(-support.y,0,support.y)-a.y)/d.y) : 1;
    float t=0,total=0;
    [loop] for(uint j=0u;j<7u;++j) {
        float next=1;
        next=min(next,rx.x>t ? rx.x : 1);next=min(next,rx.y>t ? rx.y : 1);next=min(next,rx.z>t ? rx.z : 1);
        next=min(next,ry.x>t ? ry.x : 1);next=min(next,ry.y>t ? ry.y : 1);next=min(next,ry.z>t ? ry.z : 1);
        float mid=(t+next)*.5;
        total+=(next-t)*(pfBasis(a+d*t,cell,support)+4*pfBasis(a+d*mid,cell,support)
            +pfBasis(a+d*next,cell,support))/6;
        t=next;if(t>=1)break;
    }
    return total;
}
void rgEval(int i,float2 cell,inout float4 acc) {
    float4 bounds=txFilmDescriptors.Load(int3(i,4,0));
    if(any(cell<bounds.xy)||any(cell>bounds.zw))return;
    float4 transfer=txFilmDescriptors.Load(int3(i,1,0));
    if(transfer.x>0) {
        float4 path=txFilmDescriptors.Load(int3(i,0,0));
        acc.r+=transfer.x*pfLine(path.xy,path.zw,cell,max(transfer.yz,1));
    }
    float4 birth=txFilmDescriptors.Load(int3(i,2,0));
    if(birth.z+birth.w>0) {
        float2 support=max(txFilmDescriptors.Load(int3(i,3,0)).xy,1);
        acc.rg+=birth.zw*pfBasis(birth.xy,cell,support);
    }
}
float4 pfTransportFlux(int2 inner) {
    if(any(inner<0)||any(inner>=(int2)gFilmGrid))return 0;
    return txFilmFlux.Load(int3(inner,0));
}
float4 pfResolve(float2 cell,float4 fresh) {
    int2 p=(int2)cell,inner=p-(int)gFilmPad;
    float4 old=txFilmPrevious.Load(int3(p,0));
    if(gFilmFlowOn>.5) {
        float4 outgoing=pfTransportFlux(inner);
        precise float remainX=old.r-(outgoing.x+outgoing.y);
        precise float remainY=remainX-(outgoing.z+outgoing.w);
        float arriving=pfTransportFlux(inner+int2(-1,0)).y
            +pfTransportFlux(inner+int2(1,0)).x
            +pfTransportFlux(inner+int2(0,-1)).w
            +pfTransportFlux(inner+int2(0,1)).z;
        old.r=max(remainY,0)+arriving;
    }
    float2 incoming=max(fresh.rg,0),water=max(old.rg,0)+incoming;
    if(water.x+water.y<=0)return float4(0,0,old.ba);
    float area=0;
    float coat=0,coverage=0;
    if(all(inner>=0)&&all(inner<(int2)gFilmGrid)) {
        float4 metric=txFilmCells.Load(int3(inner,0));area=metric.r*gFilmScale2;coat=metric.b;coverage=saturate(metric.g);
    }
    if(area<=0)return float4(0,0,old.b,old.a+water.x+water.y); // Explicit cumulative runoff.
    float runoff=(incoming.x+incoming.y)*(1-coverage);
    water=max(old.rg,0)+incoming*coverage; // Do not squeeze a whole kernel into a partial boundary cell.
    float cap=area*gFilmMicroJoinUM*(1+saturate(coat))*.001;
    float joined=max(water.y-cap,0);water.x+=joined;water.y-=joined;
    float evap=min(water.x+water.y,area*gFilmEvapUMS*.001*gFilmDt);
    float fraction=evap/max(water.x+water.y,1e-30);
    precise float2 next=water*(1-fraction);
    float removed=(water.x-next.x)+(water.y-next.y);
    return float4(next,old.b+removed,old.a+runoff);
}
