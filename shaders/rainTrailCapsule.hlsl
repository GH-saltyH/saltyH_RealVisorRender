// Display-only Gaussian capsule. Coordinates and radii share field-texel units.
// Returns mm3 per field-texel^2 and its x/y derivatives. Physical stock is NEVER
// updated here. Caller must replace the corresponding coarse trail contribution,
// not layer this over it. This helper alone is not integrated in product optics.
float3 rainTrailCapsule(float2 uvPoint, float2 start, float2 end,
                       float2 radius, float volumeMM3) {
  float2 k=max(radius,1e-6);
  float2 axis=(end-start)/k, p=(uvPoint-start)/k;
  float l2=dot(axis,axis);
  float t=saturate(dot(p,axis)/max(l2,1e-20));
  float2 e=p-t*axis;
  // Integral of exp(-2 distance^2): rectangular strip plus two half-discs.
  float norm=k.x*k.y*(1.2533141373155*sqrt(l2)+1.5707963267949);
  float density=max(volumeMM3,0)*exp(-2*dot(e,e))/norm;
  return float3(density,-4*e/k*density);
}
