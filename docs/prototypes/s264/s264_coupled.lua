-- Compact force/advection/ledger plan. No legacy Reference.recipe construction.
local M={}
function M.new(Force,Flux)
 local cut=assert(Force.consumer:find('// Two bands:',1,true))
 local helpers=Force.consumer:sub(1,cut-1)
 local api={}
 function api:physics(rows)
  assert(type(rows)=='table'and #rows==5,'five physical rows');local copy={}
  for i,row in ipairs(rows)do
   assert(type(row)=='table'and #row==4,'physical row width');copy[i]={}
   for j,x in ipairs(row)do assert(type(x)=='number'and x==x and math.abs(x)<math.huge,'finite physics');copy[i][j]=x end
  end
  assert(copy[2][4]>0 and copy[3][4]>=0 and copy[4][1]>=0 and copy[4][2]>=0,'positive density/nonnegative viscosity and shear')
  assert(copy[4][4]>0 and copy[4][4]<=1,'physical dt cap')
  return copy
 end
 function api:validateLedger(rows)
  if type(rows)~='table'or #rows~=6 then return false,'ledger shape'end
  for _,row in ipairs(rows)do
   if type(row)~='table'or #row~=4 then return false,'ledger row'end
   for _,x in ipairs(row)do if type(x)~='number'or x~=x or math.abs(x)==math.huge then return false,'finite ledger'end end
  end
  if rows[6][1]~=0 or rows[6][4]~=0 then return false,'invalid force/flux/state'end
  for i=1,3 do if rows[i][1]<0 then return false,'negative inventory'end end
  if rows[4][1]~=0 or rows[5][1]~=0 then return false,'force changed mass'end
  for j=1,4 do
   local residual=rows[2][j]+rows[3][j]+rows[5][j]-rows[1][j]-rows[4][j]
   local scale=0;for i=1,5 do scale=scale+math.abs(rows[i][j])end
   if math.abs(residual)>(j==1 and 1e-6 or 1e-5)+scale*(j==1 and 1e-6 or 8e-6)then return false,'water/momentum closure'end
  end
  return true
 end
 api.force=helpers..[[
float4 main(PS_IN pin){
 uint bank=min((uint)(pin.Tex.y*5),4u);int2 p=int2(min((uint)(pin.Tex.x*gGrid.x),(uint)gGrid.x-1),(uint)(pin.Tex.y*gGrid.y*5)%(uint)gGrid.y);
 float4 old=txState.Load(int3(p,0));float4 end=old,average=old,impulse=0,wall=0;
 float bad=packetValid(old)?0:1;
 if(old.r>0&&bad==0){
  float3 normal;float area;
  if(resolvedMetric(p,normal,area)){
   float3 velocity=tangent(old.yzw/old.r,normal),air=tangent(physicsRow(2).xyz,normal);
   float3 tau=.5*physicsRow(2).w*physicsRow(3).y*length(air)*air;
   float3 next=velocity,mean=velocity;
   relaxFilm(velocity,tangent(physicsRow(1).xyz,normal),tau,old.r/area*.001,gDt,next,mean);
   end=float4(old.r,next*old.r);average=float4(old.r,mean*old.r);
   impulse=float4(0,end.yzw-velocity*old.r);wall=float4(0,old.yzw-velocity*old.r);
   if(!packetValid(end)||!packetValid(average))bad=1;
  }else bad=1;
 }
 if(bad!=0){end=float4(-1,0,0,0);average=end;}
 if(bank<2)return bank==0?end:average;
 float4 previous=gHasLedger==1?txState.Load(int3(p+int2(0,(bank-1)*(int)gGrid.y),0)):float4(0,0,0,0);
 return previous+(bank==3?impulse:bank==4?wall:float4(0,0,0,0));
}
]]
 api.velocity=[[
float4 main(PS_IN pin){
 int2 p=min((int2)(pin.Tex*gGrid),(int2)gGrid-1);int h=(int)gGrid.y;
 float4 m=txForce.Load(int3(p+int2(0,h),0));if(m.r<=0)return float4(0,0,0,m.r<0?1:0);
 float3 u=txMetric.Load(int3(p,0)).xyz,v=txMetric.Load(int3(p+int2(0,h),0)).xyz;
 float4 gram=txMetric.Load(int3(p+int2(0,2*h),0));float3 velocity=m.yzw/m.r;
 float2 result=float2(gram.b*dot(u,velocity)-gram.g*dot(v,velocity),gram.r*dot(v,velocity)-gram.g*dot(u,velocity))/max(gram.a,1e-20)*gGrid;
 return float4(result,0,gram.a>1e-20&&all(isfinite(result))?0:1);
}
]]
 api.flux=Flux.flux
 api.gather=Flux.common..[[
float4 main(PS_IN pin){
 uint bank=min((uint)(pin.Tex.y*4),3u);int2 p=int2(min((uint)(pin.Tex.x*gGrid.x),(uint)gGrid.x-1),(uint)(pin.Tex.y*gGrid.y*4)%(uint)gGrid.y);
 if(!valid(p))return 0;
 if(bank>=2)return txForce.Load(int3(p+int2(0,(bank+1)*(int)gGrid.y),0));
 float4 value=txForce.Load(int3(p,0)),f=txFlux.Load(int3(p,0));
 if(bank==1){float escaped=0;[unroll]for(uint k=0;k<4;k++)if(!connected(p,p+direction(k)))escaped+=f[k];return txForce.Load(int3(p+int2(0,2*(int)gGrid.y),0))+value*escaped;}
 float4 result=value*(1-f.x-f.y-f.z-f.w);
 [unroll]for(uint k=0;k<4;k++){int2 q=p+direction(k);if(connected(p,q))result+=txForce.Load(int3(q,0))*txFlux.Load(int3(q,0))[k^1u];}
 return result;
}
]]
 api.tiles=[[
float4 main(PS_IN pin){
 uint row=min((uint)(pin.Tex.y*6),5u);int2 tile=int2((uint)(pin.Tex.x*gTiles.x),(uint)(pin.Tex.y*gTiles.y*6)%(uint)gTiles.y);
 float4 total=0,correction=0;
 [loop]for(int y=0;y<16;y++)[loop]for(int x=0;x<16;x++){
  int2 p=tile*16+int2(x,y);if(any(p>=(int2)gGrid))continue;
  float4 value=0;
  if(row==0)value=txInitial.Load(int3(p,0));
  else if(row<5)value=txState.Load(int3(p+int2(0,(row-1)*(int)gGrid.y),0));
  else{
   float4 state=txState.Load(int3(p,0)),diag=txFlux.Load(int3(p+int2((int)gGrid.x,0),0));
   bool ok=all(isfinite(state))&&state.r>=0&&(state.r>0||all(state.yzw==0));
   value=float4(ok?0:1,diag.x,diag.z,diag.w+txVelocity.Load(int3(p,0)).w);
  }
  float4 delta=value-correction,next=total+delta;correction=(next-total)-delta;total=next;
 }
 return total;
}
]]
 api.reduce=[[
float4 main(PS_IN pin){
 uint row=min((uint)(pin.Tex.y*6),5u);int2 tile=int2((uint)(pin.Tex.x*gOutput.x),(uint)(pin.Tex.y*gOutput.y*6)%(uint)gOutput.y);
 float4 total=0,correction=0;
 [loop]for(int y=0;y<16;y++)[loop]for(int x=0;x<16;x++){
  int2 p=tile*16+int2(x,y);if(any(p>=(int2)gInput))continue;
  float4 delta=txLedger.Load(int3(p+int2(0,row*(int)gInput.y),0))-correction,next=total+delta;correction=(next-total)-delta;total=next;
 }
 return total;
}
]]
 api.receipt=[[
float4 main(PS_IN pin){
 uint row=min((uint)(pin.Tex.x*4),3u);float4 initial=txLedger.Load(int3(0,0,0)),end=txLedger.Load(int3(0,1,0)),exit=txLedger.Load(int3(0,2,0));
 float4 impulse=txLedger.Load(int3(0,3,0)),wall=txLedger.Load(int3(0,4,0)),diag=txLedger.Load(int3(0,5,0));
 float4 residual=end+exit+wall-initial-impulse,scale=abs(initial)+abs(end)+abs(exit)+abs(impulse)+abs(wall);
 bool ok=all(isfinite(initial))&&all(isfinite(end))&&all(isfinite(exit))&&all(isfinite(impulse))&&all(isfinite(wall))&&all(isfinite(diag));
 ok=ok&&initial.r>=0&&end.r>=0&&exit.r>=0&&impulse.r==0&&wall.r==0&&diag.x==0&&diag.w==0;
 ok=ok&&all(abs(residual)<=float4(1e-6,1e-5,1e-5,1e-5)+scale*float4(1e-6,8e-6,8e-6,8e-6))&&isfinite(gDt)&&gDt>0&&gDt<=.05;
 float before=0;
 if(gHasPrior==1){
  float4 token=txPriorReceipt.Load(int3(0,0,0)),clock=txPriorReceipt.Load(int3(1,0,0));
  ok=ok&&all(token==gPrevious)&&clock.x==1&&isfinite(clock.y)&&clock.y>=0;
  before=isfinite(clock.y)&&clock.y>=0?clock.y:0;
 }
 float4 result=0;
 if(row==0)result=float4(gToken.xyz,ok?1:0);
 else if(row==1)result=float4(ok?1:0,before+(ok?gDt:0),ok?gDt:0,ok?0:gDt);
 else if(row==2)result=float4(initial.r,end.r,exit.r,residual.r);
 else result=diag;
 return result;
}
]]
 function api:compile(w,h,absorb)
  Flux.recipe(w,h,.01,absorb)
  local resources={force={width=w,height=h*5},velocity={width=w,height=h},flux={width=w*2,height=h},state={width=w,height=h*4},receiptA={width=4,height=1},receiptB={width=4,height=1}}
  local templates={}
  for _,n in ipairs({4,8,16})do
   local passes={}
   for i=1,n do
    local input=i==1 and'prior'or'state'
    passes[#passes+1]={kind='force',target='force',textures={txState=input,txMetric='metric',txAreas='areas',txPhysics='physics'},substep=i}
    passes[#passes+1]={kind='velocity',target='velocity',textures={txForce='force',txMetric='metric'}}
    passes[#passes+1]={kind='flux',target='flux',textures={txState='force',txVelocity='velocity',txRuns='runs'}}
    passes[#passes+1]={kind='gather',target='state',textures={txForce='force',txFlux='flux',txRuns='runs'}}
   end
   local tw,th=math.ceil(w/16),math.ceil(h/16);local rid='ledger0'
   resources[rid]={width=tw,height=th*6}
   passes[#passes+1]={kind='tiles',target=rid,textures={txInitial='initial',txState='state',txFlux='flux',txVelocity='velocity'},values={gTiles={tw,th}}}
   local level=0
   while tw>1 or th>1 do
    local nw,nh=math.ceil(tw/16),math.ceil(th/16);local nextid='ledger'..(level+1)
    resources[nextid]={width=nw,height=nh*6}
    passes[#passes+1]={kind='reduce',target=nextid,textures={txLedger=rid},values={gInput={tw,th},gOutput={nw,nh}}}
    rid=nextid;tw,th=nw,nh;level=level+1
   end
   templates[n]={passes=passes,ledger=rid}
  end
  local bytes=0;for _,r in pairs(resources)do r.format='rgba32f';bytes=bytes+r.width*r.height*16 end
  local result={resources=resources,descriptorBytes=bytes,templates=templates}
  function result:bind(dt,hasLedger,serial)
   Flux.recipe(w,h,dt,absorb);assert(type(hasLedger)=='boolean','explicit retained ledger')
   assert(type(serial)=='number'and serial==math.floor(serial)and serial>=1 and serial<=1048575,'bounded interval identity')
   local n=dt<=1/60 and 4 or dt<=1/30 and 8 or 16;local source=templates[n];local passes={}
   for j,p in ipairs(source.passes)do
    local values={};if p.values then for k,v in pairs(p.values)do values[k]=type(v)=='table'and{v[1],v[2]}or v end end
    if p.kind~='reduce'then values.gGrid={w,h}end
    if p.kind=='force'then values.gDt=dt/n;values.gHasLedger=(hasLedger or p.substep>1)and 1 or 0 end
    if p.kind=='flux'then values.gDt=dt/n;values.gAbsorb=absorb and 1 or 0;values.gMaxOut=.95 end
    local tx={};for k,v in pairs(p.textures)do tx[k]=v end
    passes[j]={kind=p.kind,target=p.target,textures=tx,values=values,shader=api[p.kind]}
   end
   local receipt=serial%2==1 and'receiptA'or'receiptB'
   passes[#passes+1]={kind='receipt',target=receipt,textures={txLedger=source.ledger,txPriorReceipt='priorReceipt'},shader=api.receipt,
    values={gDt=dt,gHasPrior=hasLedger and 1 or 0,gToken={264,1,serial,1},gPrevious={264,1,serial-1,1}}}
   return{passes=passes,substeps=n,representedDt=dt,ledger=source.ledger,receipt=receipt,final='state'}
  end
  return result
 end
 return api
end
return M
