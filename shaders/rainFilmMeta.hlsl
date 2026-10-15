float4 main(PS_IN pin) {
    uint i=min((uint)(pin.Tex.x*gFilmCount),(uint)gFilmCount-1u);
    float4 meta=txFilmNewMeta.Load(int3(i,0,0)),transfer=txFilmDescriptors.Load(int3(i,1,0));
    if(meta.a-4*floor(meta.a*.25)==1 && transfer.x+transfer.w>0) {
        precise float remaining=max(meta.g-transfer.x,0);
        meta.g=max(remaining-transfer.w,0);
        meta.r=rainSiContactRadiusMM(meta.g,gFilmTheta)*gRainReferencePerMM;
        if(meta.g<=0) {meta.r=0;meta.b=0;meta.a=4*floor(meta.a*.25);}
    }
    return meta;
}
