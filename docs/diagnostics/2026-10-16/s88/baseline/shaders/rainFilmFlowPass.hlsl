float4 main(PS_IN pin) {
    int2 p=min((int2)(pin.Tex*gFilmGrid),(int2)gFilmGrid-1)+(int)gFilmPad;
    return ffEvaluate(p).flux;
}
