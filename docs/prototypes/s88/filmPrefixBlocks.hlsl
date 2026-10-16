// OFFLINE exclusive prefix of tile totals. At production dimensions each
// block reads at most 63 (row) / 15 (column) tile endpoints, not whole rows.
float4 main(PS_IN pin) {
    int2 p=min((int2)(pin.Tex*gTestBlocks),(int2)gTestBlocks-1);
    int count=gTestAxis<.5 ? (int)gTestGrid.x : (int)gTestGrid.y;
    float4 sum=0;
    [loop]for(int i=0;i<p.x;++i) {
        int lane=min(i*16+15,count-1);
        int2 at=gTestAxis<.5 ? int2(lane,p.y) : int2(p.y,lane);
        sum+=txTestLocal.Load(int3(at,0));
    }
    return sum;
}
