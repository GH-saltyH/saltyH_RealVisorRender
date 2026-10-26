-- First-order conservative donor-cell transport; explicit capped advection.
-- Caller supplies validated cell velocity (cells/s), never display diameter.
local M={}
M.common=[[
bool inside(int2 p){return all(p>=0)&&all(p<(int2)gGrid);}
bool valid(int2 p){return inside(p)&&txRuns.Load(int3(p,0)).r>=0;}
bool connected(int2 p,int2 q){
 if(!valid(p)||!valid(q))return false;
 float4 a=txRuns.Load(int3(p,0)),b=txRuns.Load(int3(q,0));
 return p.y==q.y?all(a.rg==b.rg):all(a.ba==b.ba);
}
int2 direction(uint k){return k==0?int2(-1,0):k==1?int2(1,0):k==2?int2(0,-1):int2(0,1);}
]]
M.flux=M.common..[[
float face(int2 p,int2 q,uint k){
 float2 v=txVelocity.Load(int3(p,0)).rg;
 float m=txState.Load(int3(p,0)).r;
 if(connected(p,q)){
  float other=txState.Load(int3(q,0)).r;
  if(other>0){precise float2 a=m*v;precise float2 b=other*txVelocity.Load(int3(q,0)).rg;v=(a+b)/(m+other);}
 }else if(gAbsorb==0)v=float2(0,0);
 return k==0?-v.x:k==1?v.x:k==2?-v.y:v.y;
}
float4 main(PS_IN pin){
 int2 outp=min((int2)(pin.Tex*float2(gGrid.x*2,gGrid.y)),int2(gGrid.x*2-1,gGrid.y-1));
 bool diagnostic=outp.x>=(int)gGrid.x;int2 p=int2((uint)outp.x%(uint)gGrid.x,outp.y);
 if(!valid(p))return 0;
 float4 state=txState.Load(int3(p,0));float2 velocity=txVelocity.Load(int3(p,0)).rg;
 bool bad=!all(isfinite(state))||state.r<0||!all(isfinite(velocity));
 float4 f=0;
 if(!bad&&state.r>0){[unroll]for(uint k=0;k<4;k++)f[k]=max(face(p,p+direction(k),k),0)*gDt;}
 float raw=f.x+f.y+f.z+f.w;
 // This is a deliberate advection-speed approximation, not a dropped dt.
 float scale=raw>gMaxOut?gMaxOut/max(raw,1e-30):1;
 if(!isfinite(raw)){bad=true;f=0;scale=1;raw=0;}
 return diagnostic?float4(raw>gMaxOut?state.r:0,raw,state.r,bad?1:0):f*scale;
}
]]
M.gather=M.common..[[
float4 fraction(int2 p){return txFlux.Load(int3(p,0));}
float4 packet(int2 p,uint bank){return txState.Load(int3(p+int2(0,bank*(int)gGrid.y),0));}
float4 main(PS_IN pin){
 int2 raw=min((int2)(pin.Tex*float2(gGrid.x,gGrid.y*4)),int2(gGrid.x-1,gGrid.y*4-1));
 uint bank=(uint)raw.y/(uint)gGrid.y;int2 p=int2(raw.x,(uint)raw.y%(uint)gGrid.y);
 if(!valid(p))return 0;
 float4 f=fraction(p),value=packet(p,bank%2);float outSum=f.x+f.y+f.z+f.w;
 if(bank>=2){float escaped=0;[unroll]for(uint k=0;k<4;k++)if(!connected(p,p+direction(k)))escaped+=f[k];float4 prior=gAccumulateExit==1?packet(p,bank):float4(0,0,0,0);return prior+value*escaped;}
 float4 result=value*(1-outSum);
 [unroll]for(uint k=0;k<4;k++){
  int2 q=p+direction(k);if(connected(p,q))result+=packet(q,bank)*fraction(q)[k^1u];
 }
 return result;
}
]]
function M.recipe(w,h,dt,absorb)
 assert(w>=1 and w<=4096 and h>=1 and h<=1024 and w==math.floor(w)and h==math.floor(h),'grid')
 assert(type(dt)=='number'and dt==dt and dt>0 and dt<=.05,'bounded represented dt')
 assert(type(absorb)=='boolean','boundary policy')
 return {width=w,height=h,dt=dt,absorb=absorb,maxOut=.95,passes=2,
  transientBytes=w*h*16*6,outputLayout='End/Mean/exitEnd/exitMean',
  fluxValues={gGrid={w,h},gDt=dt,gAbsorb=absorb and 1 or 0,gMaxOut=.95},
  gatherValues={gGrid={w,h},gAccumulateExit=0}}
end
function M.plan(w,h,dt,absorb)
 local r=M.recipe(w,h,dt,absorb)
 local n=dt<=1/60 and 4 or dt<=1/30 and 8 or 16
 local passes={};local previous='input'
 for i=1,n do
  local target=i%2==1 and 'stateA'or 'stateB'
  passes[#passes+1]={kind='flux',target='flux',state=previous,values={gGrid={w,h},gDt=dt/n,gAbsorb=absorb and 1 or 0,gMaxOut=.95}}
  passes[#passes+1]={kind='gather',target=target,state=previous,flux='flux',values={gGrid={w,h},gAccumulateExit=i==1 and 0 or 1}}
  previous=target
 end
 -- Ordered draw reuse only; no CPU acknowledgement between these passes.
 return {passes=passes,substeps=n,representedDt=dt,substepDt=dt/n,final=previous,
  resources={flux={width=w*2,height=h,format='rgba32f'},stateA={width=w,height=h*4,format='rgba32f'},stateB={width=w,height=h*4,format='rgba32f'}},
  descriptorBytes=w*h*16*10,scope='candidate_advection_only',CPUCompletionBetweenPasses=false}
end
return M
