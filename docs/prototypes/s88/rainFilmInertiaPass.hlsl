float4 main(PS_IN pin) {
    int2 inner=min((int2)(pin.Tex*gFilmGrid),(int2)gFilmGrid-1);
    return fiPredict(inner);
}
