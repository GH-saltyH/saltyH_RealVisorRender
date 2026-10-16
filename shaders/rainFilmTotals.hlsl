// Manual current inventory/cumulative cell-loss snapshot. Source/head losses
// come from the matching published P2 budget bank.
float4 main(PS_IN pin) {
    uint row=min((uint)(pin.Tex.y*4),3u);
    float4 result=0;
    if(row==2u) {
        float4 a=txFilmBirthTotals.Load(int3(0,0,0)),b=txFilmBirthTotals.Load(int3(0,1,0));
        result=float4(a.x,a.w,b.y,b.z);
    } else if(row==3u) {
        float4 a=txFilmBirthTotals.Load(int3(0,4,0)),b=txFilmBirthTotals.Load(int3(0,1,0));
        result=float4(a.xy,b.x,b.w);
    } else if(row==1u) {
        result.x=txFilmBirthTotals.Load(int3(0,4,0)).w; // Cumulative internal return.
    } else {
    float4 delta=0,compensation=0;
    [loop]for(uint y=0u;y<(uint)gFilmReductionSize.y;++y)
        [loop]for(uint x=0u;x<(uint)gFilmReductionSize.x;++x) {
            precise float4 adjusted=txFilmBlocks.Load(int3(x,y,0))-compensation;
            precise float4 next=delta+adjusted;
            compensation=(next-delta)-adjusted;delta=next;
        }
    // Losses live cumulatively in each physical cell. Reduction is requested
    // only for a manual snapshot, so no full-field budget scan runs every frame.
    result=row==0u ? delta : 0;
    }
    return result;
}
