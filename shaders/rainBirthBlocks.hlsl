// 64-slot GPU reductions. Row 0 source/pools; row 1 capacity/exit/inventory/count.
float4 main(PS_IN pin) {
    uint blocks=(uint)max(gBirthBlocks,1),block=min((uint)(pin.Tex.x*blocks),blocks-1u);
    uint row=min((uint)(pin.Tex.y*2),1u);float4 total=0;
    [loop] for(uint j=0u;j<64u;++j) {
        uint i=block*64u+j;
        if(i<(uint)gBirthCount) {
            float4 event=txBirthEvent.Load(int3(i,row+2u,0));
            if(row==1u) {
                float4 meta=txRainNewMeta.Load(int3(i,0,0));
                float status=meta.a-4*floor(meta.a*.25);
                event.z=status>.5 && status<1.5 ? max(meta.g,0) : 0;
            }
            total+=event;
        }
    }
    return total;
}
