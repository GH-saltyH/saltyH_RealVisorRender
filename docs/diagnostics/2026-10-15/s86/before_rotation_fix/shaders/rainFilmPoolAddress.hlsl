// P4b bounded, unique region -> slot ownership. Counts and tick are integers.
uint poolTilesX() {return ((uint)gFilmGrid.x+15u)/16u;}
uint poolTileCount() {return poolTilesX()*(((uint)gFilmGrid.y+15u)/16u);}
uint poolOwner(uint tile) {
    uint tiles=poolTileCount(),count=(uint)max(gPoolCount,1),tick=(uint)gPoolTick;
    uint group=tick%((count+tiles-1u)/tiles);
    return group*tiles+(tile+tiles-tick%tiles)%tiles;
}
