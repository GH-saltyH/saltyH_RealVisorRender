// Conservative limited linear reconstruction inside each source interval.
// The same positive weight applies to volume and all momentum components.
float trFraction(int2 source,float2 interval,float lo,float hi) {
    float q0=saturate((lo-interval.x)/(interval.y-interval.x));
    float q1=saturate((hi-interval.x)/(interval.y-interval.x));
    float weight=max(q1-q0,0);
    if(gTraceLinear>.5 && q1>q0) {
        float mass=txTestPackets.Load(int3(source,0)).r;
        float4 own=txTraceRuns.Load(int3(source,0));
        float2 run=gTestAxis<.5 ? own.rg : own.ba;
        int lane=gTestAxis<.5 ? source.x : source.y;
        int2 axis=gTestAxis<.5 ? int2(1,0) : int2(0,1);
        float left=mass,right=mass;
        if(lane>(int)run.x)left=txTestPackets.Load(int3(source-axis,0)).r;
        if(lane+1<(int)run.y)right=txTestPackets.Load(int3(source+axis,0)).r;
        float dl=mass-left,dr=right-mass,slope=0;
        if((dl>0&&dr>0)||(dl<0&&dr<0))slope=sign(dl)*min(min(abs(dl),abs(dr)),2*max(mass,0));
        // Difference of squares factored to avoid unnecessary cancellation.
        weight*=(1+.5*(slope/max(mass,1e-30))*(q1+q0-1));
    }
    return weight;
}
