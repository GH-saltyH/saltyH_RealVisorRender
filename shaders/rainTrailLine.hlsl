// Display-only, normalized line deposition convolved with a compact C1 kernel.
// Field-texel coordinates; radius is Gaussian-equivalent standard support scale.
// Does NOT change SI stock. Replace matching coarse trail, never add both.
// Same straight line, width and volume/length give the same profile when split.
float rainTrailK(float x) {
  float a=max(1-x*x,0);
  return abs(x)<1 ? .9375*a*a : 0;
}
float rainTrailDK(float x) {
  return abs(x)<1 ? -3.75*x*(1-x*x) : 0;
}
float rainTrailCDF(float x) {
  float t=clamp(x,-1,1),t2=t*t;
  return saturate(.5+.9375*t*(1+t2*(-.666666666666667+.2*t2)));
}
float3 rainTrailLine(float2 uvPoint,float2 start,float2 end,
                     float2 radius,float volumeMM3) {
  // Compact quartic variance=1/7; old exp(-2*x*x) variance=1/4.
  float2 k=max(radius,1e-6)*1.3228756555323;
  float2 axis=(end-start)/k,p=(uvPoint-start)/k;
  float len=length(axis);
  float2 along=len>1e-8 ? axis/len : float2(1,0);
  float2 across=float2(-along.y,along.x);
  float u=dot(p,along),v=dot(p,across);
  float f,df;
  if(len<.05){
    // Two-point quadrature avoids subtracting almost equal CDFs near rest.
    float a=u-len*.211324865405187,b=u-len*.788675134594813;
    f=.5*(rainTrailK(a)+rainTrailK(b));
    df=.5*(rainTrailDK(a)+rainTrailDK(b));
  }else{
    f=max(rainTrailCDF(u)-rainTrailCDF(u-len),0)/len;
    df=(rainTrailK(u)-rainTrailK(u-len))/len;
  }
  float kv=rainTrailK(v),dkv=rainTrailDK(v);
  float scale=max(volumeMM3,0)/(k.x*k.y);
  float2 grad=(along*(df*kv)+across*(f*dkv))/k;
  return scale*float3(f*kv,grad);
}
