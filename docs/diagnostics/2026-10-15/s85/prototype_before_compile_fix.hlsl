// OFFLINE P4b feasibility prototype. Not loaded by the game.
// One candidate per 16x16 region; conservative/localized subset only.
uint poolTilesX() {return ((uint)gFilmGrid.x+15u)/16u;}
uint poolTileCount() {return poolTilesX()*(((uint)gFilmGrid.y+15u)/16u);}
uint poolOwner(uint tile) {
    uint tiles=poolTileCount(),count=(uint)gPoolCount,tick=(uint)gPoolTick;
    uint group=tick%((count+tiles-1u)/tiles);
    return group*tiles+(tile+tiles-tick%tiles)%tiles;
}
float poolHeight(int2 p) {
    if(any(p<0)||any(p>=(int2)gFilmGrid))return -1;
    float4 cell=txFilmCells.Load(int3(p,0));
    if(cell.r<=0||cell.g<1)return -1; // Boundary/partial topology left to film.
    return max(txFilmPrevious.Load(int3(p+(int)gFilmPad,0)).r,0)/(cell.r*gFilmScale2);
}
float4 poolCandidate(uint tile) {
    uint2 start=uint2(tile%poolTilesX(),tile/poolTilesX())*16u;
    float highest=0;int2 peak=-1;
    // Select first maximum deterministically; only inspect its surroundings.
    // A rejected maximum can mask a smaller peak in this region: bounded work.
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
    if(actual<=0||rainSiDiameterMM(actual)<gPoolMinDMM)return 0;
    float radius=rainSiContactRadiusMM(actual,gPoolTheta);
    // Reject uniform sheets/ridges and broad shallow caps. This is a subgrid
    // classification proposal, not a proof of a detached physical droplet.
    if(highest-background<=rainSiCapHeightMM(radius,gPoolTheta)
        ||3.141592653589793*radius*radius<=area)return 0;
    return float4(peak,actual,1);
}
float4 poolAccept(uint index) {
    uint tiles=poolTileCount(),tick=(uint)gPoolTick;
    uint tile=(index%tiles+tick%tiles)%tiles;
    if(poolOwner(tile)!=index)return 0;
    float4 candidate=txPoolCandidates.Load(int3(tile,0,0));
    float4 meta=txRainStateMeta.Load(int3(index,0,0));
    float generation=floor(meta.a*.25),status=meta.a-generation*4;
    // Existing rain birth has priority. No head capacity => no field debit.
    if(candidate.w<.5||status!=0||meta.g>0||txBirthEvent.Load(int3(index,0,0)).z>0)return 0;
    return float4(candidate.xyz,fmod(generation+1,4096)+1);
}
float poolAvailable(int2 padded) {
    float volume=max(txFilmPrevious.Load(int3(padded,0)).r,0);
    int2 p=padded-(int)gFilmPad;
    if(any(p<0)||any(p>=(int2)gFilmGrid))return volume;
    uint tile=(uint)p.y/16u*poolTilesX()+(uint)p.x/16u,owner=poolOwner(tile);
    if(owner>=(uint)gPoolCount)return volume;
    float4 accepted=txPoolAccepted.Load(int3(owner,0,0));
    if(accepted.w<=0||any((int2)accepted.xy!=p))return volume;
    // Source/epoch must match at publication. Prototype uses one immutable bank.
    return volume-accepted.z;
}
