float4 main(PS_IN pin) {
    int2 p=min((int2)(pin.Tex*gTestGrid),(int2)gTestGrid-1);
    int cell=gTestAxis<.5 ? p.x : p.y,row=gTestAxis<.5 ? p.y : p.x;
    float lo=(float)cell,hi=lo+1;
    float4 sum=0,correction=0;
    float leaves=0,tests=0,contributors=0;
    [loop]for(int group=0;group<(int)gTestGroups;++group) {
        float4 gb=txTestGroups.Load(int3(group,row,0));
        if(gb.z<=0 || gb.y<=lo || gb.x>=hi)continue;
        [loop]for(int i=0;i<16;++i) {
            int leaf=group*16+i;if(leaf>=(int)gTestLeaves)break;
            leaves+=1;
            float4 lb=txTestLeaves.Load(int3(leaf,row,0));
            if(lb.z<=0 || lb.y<=lo || lb.x>=hi)continue;
            [loop]for(int j=0;j<16;++j) {
                int lane=leaf*16+j;if(lane>=(int)gTestLanes)break;
                tests+=1;
                int2 source=ovPixel(lane,row);
                float2 interval=txTestIntervals.Load(int3(source,0)).rg;
                if(interval.y<=lo || interval.x>=hi)continue;
                float4 packet=txTestPackets.Load(int3(source,0));
                if(packet.r<=0)continue;
                contributors+=1;
                ovAdd(packet*ovInside(interval,lo,hi),sum,correction);
            }
        }
    }
    // Manual-only operation count; normal mode returns the conserved packet.
    return gTestDebug>.5 ? float4(leaves,tests,contributors,0) : sum;
}
