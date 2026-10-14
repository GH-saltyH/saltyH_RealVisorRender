struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};
Texture2D txTrailDescriptors;

float gCount;
float gMaskW;
float gSize;
float2 gTile;
float gTilesY;
float gWords;
float ntBits(uint base,float2 low,float2 high) {
    uint bits=0u;
    [loop] for(uint b=0u;b<24u;++b) {
        uint i=base+b;if(i>=(uint)gCount)break;
        float4 box=txTrailDescriptors.Load(int3(i,3,0));
        if(all(box.zw>=low)&&all(box.xy<=high)) {
            float4 path=txTrailDescriptors.Load(int3(i,0,0));
            float2 padding=(box.zw-box.xy-abs(path.zw-path.xy))*.5;
            float2 travel=path.zw-path.xy;
            float2 safe=float2(travel.x>=0 ? max(travel.x,1e-9) : min(travel.x,-1e-9),
                travel.y>=0 ? max(travel.y,1e-9) : min(travel.y,-1e-9));
            float2 a=(low-padding-path.xy)/safe,z=(high+padding-path.xy)/safe;
            float2 enter=min(a,z),leave=max(a,z);
            if(max(max(enter.x,enter.y),0)<=min(min(leave.x,leave.y),1)) bits|=1u<<b;
        }
    }
    return float(bits);
}
float4 main(PS_IN pin):SV_TARGET {
    uint x=(uint)floor(pin.Tex.x*gMaskW),y=(uint)floor(pin.Tex.y*gTilesY);
    uint tile=x/(uint)gWords,word=x-tile*(uint)gWords;
    float2 low=float2(tile,y)*gTile/gSize,high=low+gTile/gSize;
    uint base=word*96u;
    return float4(ntBits(base,low,high),ntBits(base+24u,low,high),ntBits(base+48u,low,high),ntBits(base+72u,low,high));
}
