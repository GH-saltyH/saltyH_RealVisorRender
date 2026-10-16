// GPU-wide arithmetic admission. Ordered, nonoverlapping retained intervals
// prevent the arbitrary broad-overlap N^2 case. A rejected axis returns old
// packets and zero loss; this is a measured frozen-axis fallback, not accurate time.
float4 main(PS_IN pin) {
    float status=0,active=0;
    [loop]for(int row=0;row<(int)gTestRows;++row) {
        float previous=-1e30;
        [loop]for(int group=0;group<(int)gTestGroups;++group) {
            float4 bounds=txTestGroups.Load(int3(group,row,0));
            status=max(status,bounds.w);
            if(bounds.z>0) {
                if(bounds.x<previous)status=max(status,4);
                previous=max(previous,bounds.y);active+=bounds.z;
            }
        }
    }
    return float4(status==0 ? 1 : 0,status,active,0);
}
