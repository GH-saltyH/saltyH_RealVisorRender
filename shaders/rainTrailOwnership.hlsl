// Volume budget per existing coarse cell. Detail is a replacement, never extra
// water. Shader helper only; the product renderer does not call this yet.
float2 rainTrailOwnership(float stockMM3,float recentClaimMM3){
  float stock=isfinite(stockMM3)?max(stockMM3,0):0;
  float claim=isfinite(recentClaimMM3)?clamp(recentClaimMM3,0,stock):0;
  return float2(stock-claim,claim); // coarse remainder, detail budget
}
// Child weights must be summed over this SAME parent cell, not the whole atlas.
// If geometry cannot resolve a child shape, use uniform weights as fallback.
float rainTrailChildVolume(float budget,float weight,float parentWeight,float childCount){
  return parentWeight>1e-30 ? budget*max(weight,0)/parentWeight : budget/max(childCount,1);
}
