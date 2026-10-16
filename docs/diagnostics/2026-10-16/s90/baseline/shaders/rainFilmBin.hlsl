float pfBits(uint base,float2 low,float2 high) {
    uint bits=0u;
    [loop] for(uint b=0u;b<24u;++b) {
        uint i=base+b;if(i>=(uint)gCount)break;
        float4 box=txFilmDescriptors.Load(int3(i,4,0));
        if(all(box.zw>=low)&&all(box.xy<=high))bits|=1u<<b;
    }
    return float(bits);
}
float4 main(PS_IN pin) {
    uint x=(uint)floor(pin.Tex.x*gMaskW),y=(uint)floor(pin.Tex.y*gTilesY);
    uint tile=x/(uint)gWords,word=x-tile*(uint)gWords,base=word*96u;
    float2 low=float2(tile,y)*gTile-.5,high=low+gTile;
    return float4(pfBits(base,low,high),pfBits(base+24u,low,high),
                  pfBits(base+48u,low,high),pfBits(base+72u,low,high));
}
