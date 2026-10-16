// Same immutable P2 event used by head birth, donor flux, field debit and optics.
float poolTransfer(int2 padded) {
    if(gPoolOn<.5)return 0;
    int2 p=padded-(int)gFilmPad;
    if(any(p<0)||any(p>=(int2)gFilmGrid))return 0;
    uint tile=(uint)p.y/16u*poolTilesX()+(uint)p.x/16u,owner=poolOwner(tile);
    if(owner>=(uint)gPoolCount)return 0;
    float transferred=txFilmBirthEvent.Load(int3(owner,4,0)).z;
    if(transferred<=0)return 0;
    float2 born=txFilmBirthEvent.Load(int3(owner,0,0)).xy;
    int2 source=(int2)floor(float2(born.x,born.y+1)*gFilmGrid);
    return all(source==p) ? transferred : 0;
}
float poolAvailable(int2 p) {
    return max(txFilmPrevious.Load(int3(p,0)).r,0)-poolTransfer(p);
}
