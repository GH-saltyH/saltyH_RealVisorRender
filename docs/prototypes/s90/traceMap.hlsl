float4 main(PS_IN pin) {
    int2 p=min((int2)(pin.Tex*gTraceGrid),(int2)gTraceGrid-1);
    int lane=gTraceAxis<.5 ? p.x : p.y,row=gTraceAxis<.5 ? p.y : p.x;
    if(txTracePackets.Load(int3(p,0)).r<=0)return float4(lane,lane+1,0,0);
    float2 run=trRun(p);
    if(run.x<0)return float4(lane,lane+1,3,0);
    float4 a=trAdvance((float)lane,row,run),b=trAdvance((float)lane+1,row,run);
    float status=max(a.y,b.y),visits=max(a.z,b.z);
    if(status==0 && b.x<=a.x)status=2;
    if(status>0)return float4(lane,lane+1,status,visits);
    return float4(a.x,b.x,0,visits);
}
