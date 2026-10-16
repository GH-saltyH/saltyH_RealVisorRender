// OFFLINE 16-cell inclusive prefix of (volume, world momentum xyz).
// Axis 0 = rows, 1 = columns. Outside-domain primitives use zero/clamped totals.
int2 fpPixel(int lane,int row) {return gTestAxis<.5 ? int2(lane,row) : int2(row,lane);}
float4 main(PS_IN pin) {
    int2 p=min((int2)(pin.Tex*gTestGrid),(int2)gTestGrid-1);
    int lane=gTestAxis<.5 ? p.x : p.y;
    int row=gTestAxis<.5 ? p.y : p.x;
    float4 sum=0;
    [loop]for(int i=(lane>>4)*16;i<=lane;++i)sum+=txTestPackets.Load(int3(fpPixel(i,row),0));
    return sum;
}
