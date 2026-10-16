float4 main(PS_IN pin) {
    int2 block=min((int2)(pin.Tex*gFilmReductionSize),(int2)gFilmReductionSize-1);
    float4 total=0,compensation=0;
    [loop]for(int y=0;y<16;++y) [loop]for(int x=0;x<16;++x) {
        int2 p=block*16+int2(x,y);
        if(all(p<(int2)gFilmPaddedSize)) {
            precise float4 adjusted=txFilmCurrent.Load(int3(p,0))-compensation;
            precise float4 next=total+adjusted;
            compensation=(next-total)-adjusted;total=next;
        }
    }
    return total;
}
