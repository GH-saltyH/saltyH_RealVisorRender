float4 main(PS_IN pin) {
    uint index=min((uint)(pin.Tex.x*16),15u),row=index>>2u;
    float4 result=0;float3 compensation=0;
    [loop]for(int y=0;y<2;++y) [loop]for(int x=0;x<5;++x) {
        float4 value=txFilmFlowBlocks.Load(int3(x,y+row*2,0));
        if(row<2) {
            precise float3 adjusted=value.yzw-compensation;
            precise float3 next=result.yzw+adjusted;
            compensation=(next-result.yzw)-adjusted;result.yzw=next;result.x=max(result.x,value.x);
        }
        else if(value.x>result.x)result=value;
    }
    return result[index&3u];
}
