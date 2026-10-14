// Persistent budget. Kahan compensation prevents tiny rain inputs disappearing
// against a long-session total. Inventory is a current snapshot, never summed.
float4 main(PS_IN pin) {
    uint row=min((uint)(pin.Tex.y*4),3u),base=row%2u;float4 delta=0;
    [loop] for(uint i=0u;i<(uint)gBirthBlocks;++i)delta+=txBirthBlocks.Load(int3(i,base,0));
    float4 previous=txBirthPreviousTotals.Load(int3(0,base,0));
    float4 compensation=txBirthPreviousTotals.Load(int3(0,base+2u,0));
    precise float4 corrected=delta-compensation;
    precise float4 next=previous+corrected;
    precise float4 residual=(next-previous)-corrected;
    if(base==1u) {next.z=delta.z;residual.z=0;}
    return row<2u ? next : residual;
}
