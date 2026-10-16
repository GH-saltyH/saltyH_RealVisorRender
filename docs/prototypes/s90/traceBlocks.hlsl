float4 main(PS_IN pin) {
    int row=min((int)(pin.Tex.y*gTraceRows),(int)gTraceRows-1);
    int block=min((int)(pin.Tex.x*gTraceBlockCount),(int)gTraceBlockCount-1);
    int lo=block*16,hi=min(lo+16,(int)gTraceLanes);
    float first=trFace(lo,row),last=trFace(hi,row),slope=(last-first)/(float)(hi-lo);
    bool valid=true,finite=isfinite(first)&&isfinite(last)&&isfinite(slope);float error=0;
    [loop]for(int i=lo;i<hi;++i)valid=valid&&trSupported(i,row);
    [loop]for(int j=lo;j<=hi;++j) {
        float sample=trFace(j,row);finite=finite&&isfinite(sample);
        error=max(error,abs(sample-(first+slope*(j-lo))));
    }
    float4 result=0;
    if(finite)result=float4(first,slope,error,valid&&error<=gTraceAffineTolerance ? 1 : 0);
    return result;
}
