// P4b bounded, unique region -> slot ownership. Counts and tick are integers.
uint poolTilesX() {return ((uint)gFilmGrid.x+15u)/16u;}
uint poolTileCount() {return poolTilesX()*(((uint)gFilmGrid.y+15u)/16u);}
uint poolRotation() {
    uint groups=((uint)max(gPoolCount,1)+poolTileCount()-1u)/poolTileCount();
    // Advance region rotation after a complete slot-group cycle. Using tick
    // directly aliases groups/regions at common counts such as 4096 slots.
    return ((uint)gPoolTick/groups)%poolTileCount();
}
uint poolOwner(uint tile) {
    uint tiles=poolTileCount(),count=(uint)max(gPoolCount,1),tick=(uint)gPoolTick;
    uint group=tick%((count+tiles-1u)/tiles);
    return group*tiles+(tile+tiles-poolRotation())%tiles;
}
