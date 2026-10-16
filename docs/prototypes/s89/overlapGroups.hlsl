// Fixed two-level bounding hierarchy. A group contains at most 16 leaves.
float4 main(PS_IN pin) {
    int row=min((int)(pin.Tex.y*gTestRows),(int)gTestRows-1);
    int group=min((int)(pin.Tex.x*gTestGroups),(int)gTestGroups-1);
    float low=1e30,high=-1e30,count=0;
    [loop]for(int i=0;i<16;++i) {
        int leaf=group*16+i;if(leaf>=(int)gTestLeaves)break;
        float4 bounds=txTestLeaves.Load(int3(leaf,row,0));
        if(bounds.z<=0)continue;
        low=min(low,bounds.x);high=max(high,bounds.y);count+=bounds.z;
    }
    return float4(low,high,count,0);
}
