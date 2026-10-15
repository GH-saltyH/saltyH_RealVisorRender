// Manual-only four-row diagnostic. Never participates in physical transport.
// Rows 0/1: MAX first channel, SUM the others. Rows 2/3: whole record at MAX C.
float4 ffCellInfo(int2 p) {
    int2 inner=p-(int)gFilmPad;
    if(any(inner<0)||any(inner>=(int2)gFilmGrid))return 0;
    float area=txFilmCells.Load(int3(inner,0)).r*gFilmScale2;
    float volume=max(txFilmPrevious.Load(int3(p,0)).r,0);
    if(area<=0||volume<=0)return 0;
    float2 uv=(inner+.5)/gFilmGrid;float3 u,v;rainMetric(float2(uv.x,uv.y-1),u,v);
    float3 uw=mul(u,(float3x3)gFilmObjectToWorld),vw=mul(v,(float3x3)gFilmObjectToWorld);
    float3 n=cross(uw,vw);n/=max(length(n),1e-20);
    float3 sx=uw/gFilmGrid.x,sy=vw/gFilmGrid.y;
    float a=dot(sx,sx),b=dot(sx,sy),c=dot(sy,sy);
    float largest=.5*(a+c+sqrt(max((a-c)*(a-c)+4*b*b,0)));
    float stride=sqrt(max((a*c-b*b)/max(largest,1e-30),0))*1e6;
    return float4(volume/area*1000,area,stride,length(rainSiTangent(gFilmAccelerationWorld,n)));
}
float4 main(PS_IN pin) {
    int row=min((int)(pin.Tex.y*4),3);
    float2 tileUV=float2(pin.Tex.x,frac(pin.Tex.y*4));
    int2 block=min((int2)(tileUV*gFilmReductionSize),(int2)gFilmReductionSize-1);
    float4 result=0;float3 compensation=0;
    [loop]for(int y=0;y<16;++y) [loop]for(int x=0;x<16;++x) {
        int2 p=block*16+int2(x,y);
        if(any(p>=(int2)gFilmPaddedSize))continue;
        float4 value=0;
        if(gFilmFlowReduce>.5)value=txFilmFlowBlocks.Load(int3(p+int2(0,row*(int)gFilmPaddedSize.y),0));
        else {
            FilmFlow f=ffEvaluate(p);
            float volume=max(txFilmPrevious.Load(int3(p,0)).r,0);
            if(row==0)value=float4(f.courant,f.courant>gFilmFlowCFL ? 1 : 0,volume>0 ? 1 : 0,
                f.courant>gFilmFlowCFL ? volume : 0);
            else {
                float4 info=ffCellInfo(p);
                if(row==1)value=float4(info.x,volume,volume*min(1,gFilmFlowCFL/max(f.courant,1e-30)),info.x>1000 ? volume : 0);
                else if(row==2)value=float4(f.courant,p-(int)gFilmPad,info.x);
                else value=float4(f.courant,info.yzw);
            }
        }
        if(row<2) {
            precise float3 adjusted=value.yzw-compensation;
            precise float3 next=result.yzw+adjusted;
            compensation=(next-result.yzw)-adjusted;result.yzw=next;result.x=max(result.x,value.x);
        }
        else if(value.x>result.x)result=value;
    }
    return result;
}
