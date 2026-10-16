// One conservative localized excess per region. Uniform sheets/ridges stay film.
float poolHeight(int2 p) {
    if(any(p<0)||any(p>=(int2)gFilmGrid))return -1;
    float4 cell=txFilmCells.Load(int3(p,0));
    if(cell.r<=0||cell.g<1)return -1;
    return max(txFilmPrevious.Load(int3(p+(int)gFilmPad,0)).r,0)/(cell.r*gFilmScale2);
}
float4 main(PS_IN pin) {
    if(gPoolHasField<.5)return 0;
    uint tile=min((uint)(pin.Tex.x*poolTileCount()),poolTileCount()-1u);
    uint2 start=uint2(tile%poolTilesX(),tile/poolTilesX())*16u;
    float highest=0;int2 peak=-1;
    [loop] for(uint y=0u;y<16u;++y) [loop] for(uint x=0u;x<16u;++x) {
        int2 p=(int2)(start+uint2(x,y));float h=poolHeight(p);
        if(h>highest) {highest=h;peak=p;}
    }
    if(highest<=0)return 0;
    float4 neighbours=float4(poolHeight(peak+int2(-1,0)),poolHeight(peak+int2(1,0)),
                             poolHeight(peak+int2(0,-1)),poolHeight(peak+int2(0,1)));
    if(any(neighbours<0))return 0;
    float background=max(max(neighbours.x,neighbours.y),max(neighbours.z,neighbours.w));
    float area=txFilmCells.Load(int3(peak,0)).r*gFilmScale2;
    float volume=max(txFilmPrevious.Load(int3(peak+(int)gFilmPad,0)).r,0);
    precise float remaining=volume-min(volume,max(highest-background,0)*area);
    precise float actual=volume-remaining;
    if(actual<=0||rainSiEquivalentDiameterMM(actual)<gPoolMinDMM)return 0;
    float radius=rainSiContactRadiusMM(actual,gPoolTheta);
    if(highest-background<=rainSiCapHeightMM(radius,gPoolTheta)
        ||3.141592653589793*radius*radius<=area)return 0;
    return float4(peak,actual,1);
}
