// Offline conservative source-interval remap. Caller must supply finite,
// positive-width destination intervals; deriving those trajectories is separate.
int2 ovPixel(int lane,int row) {return gTestAxis<.5 ? int2(lane,row) : int2(row,lane);}
void ovAdd(float4 value,inout float4 sum,inout float4 correction) {
    float4 y=value-correction;
    float4 t=sum+y;
    correction=(t-sum)-y;
    sum=t;
}
float ovInside(float2 interval,float lo,float hi) {
    return max(min(interval.y,hi)-max(interval.x,lo),0)/(interval.y-interval.x);
}
