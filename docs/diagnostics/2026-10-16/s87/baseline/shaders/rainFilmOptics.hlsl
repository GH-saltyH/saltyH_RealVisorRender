// Physical micrometres, not max-composited 0-1 optical trail amplitude.
float4 main(PS_IN pin) {
    int2 inner=min((int2)(pin.Tex*gFilmGrid),(int2)gFilmGrid-1);
    float area=txFilmCells.Load(int3(inner,0)).r*gFilmScale2;
    float2 water=txFilmCurrent.Load(int3(inner+(int)gFilmPad,0)).rg;
    float2 heightUM=area>0 ? water/area*1000 : 0;
    // The half-float optical texture is a bounded read-only representation.
    // Inventory remains uncapped float32 mm3 in the physical field.
    float returnedUM=area>0 ? poolTransfer(inner+(int)gFilmPad)/area*1000 : 0;
    // B is a display-only last-published-step return marker, never inventory.
    return float4(min(heightUM,60000),min(returnedUM,60000),0);
}
