// OFFLINE conservative flux-form semi-Lagrangian primitive.
// Uniform velocity is positive/conservative at arbitrary Courant. General
// velocity does NOT ensure positivity: characteristic departure faces can cross.
float4 fpPrimitive(float x,int row) {
    int count=gTestAxis<.5 ? (int)gTestGrid.x : (int)gTestGrid.y;
    float at=clamp(x,0,(float)count);
    int lane=min((int)floor(at),count-1);
    int2 p=gTestAxis<.5 ? int2(lane,row) : int2(row,lane);
    float4 local=txTestLocal.Load(int3(p,0));
    float4 block=txTestBlocks.Load(int3(lane>>4,row,0));
    float4 cell=txTestPackets.Load(int3(p,0));
    return block+local-cell*(lane+1-at);
}
float4 main(PS_IN pin) {
    int2 p=min((int2)(pin.Tex*gTestFaces),(int2)gTestFaces-1);
    int face=gTestAxis<.5 ? p.x : p.y;
    int row=gTestAxis<.5 ? p.y : p.x;
    float travel=txTestTravel.Load(int3(p,0)).r;
    return fpPrimitive((float)face,row)-fpPrimitive(face-travel,row);
}
