// One leaf = 16 source cells. First row bank: destination min/max and wet count.
// Second row bank: source-local runoff packet, including signed momentum xyz.
float4 main(PS_IN pin) {
    int bank=min((int)(pin.Tex.y*2),1);
    int row=min((int)(frac(pin.Tex.y*2)*gTestRows),(int)gTestRows-1);
    int leaf=min((int)(pin.Tex.x*gTestLeaves),(int)gTestLeaves-1);
    float low=1e30,high=-1e30,count=0;
    float4 lost=0,correction=0;
    [loop]for(int i=0;i<16;++i) {
        int lane=leaf*16+i;if(lane>=(int)gTestLanes)break;
        int2 p=ovPixel(lane,row);
        float4 packet=txTestPackets.Load(int3(p,0));
        if(packet.r<=0)continue;
        float2 interval=txTestIntervals.Load(int3(p,0)).rg;
        low=min(low,interval.x);high=max(high,interval.y);count+=1;
        float fraction=saturate(ovInside(interval,0,gTestLanes));
        ovAdd(packet*(1-fraction),lost,correction);
    }
    return bank==0 ? float4(low,high,count,0) : lost;
}
