-- Shared source-cell lifecycle: physical micro coalescence and field evaporation.
-- Same passes/roots/ledger; no new simulation, optical gain or weather preset.
local M={}
M.helpers=[[
float4 rvFieldEvaporate(float4 before,float fraction,out float4 removed){
 removed=0;if(before.r<=0||fraction<=0)return before;
 precise float remaining=max(before.r-min(before.r,before.r*fraction),0);
 if(remaining==before.r)return before;
 float4 next=remaining>0?float4(remaining,before.yzw*(remaining/before.r)):0;
 removed=before-next;return next;
}
void rvFieldLifecycle(int2 p,float4 cell,inout float4 film,inout float4 micro,out float4 evaporated){
 // Product cells retain the validated coating in A=1+coat, not a new texture.
 float coat=cell.a-1;
 float capacity=cell.r*gFieldMicroJoinMM*(1+saturate(coat));
 float requested=max(micro.r-capacity,0);
 if(requested>0){
  precise float candidate=film.r+requested;
  precise float added=candidate-film.r;
  precise float remaining=max(micro.r-added,0);
  precise float removed=micro.r-remaining;
  // A transfer is admitted only when both stored volumes represent it.
  if(added>0&&added<=micro.r&&removed==added){film.r=candidate;micro.r=remaining;}
 }
 float total=film.r+micro.r;
 float fraction=total>0?min(cell.r*gFieldEvapDepthMM,total)/total:0;
 float4 filmLoss,microLoss;
 film=rvFieldEvaporate(film,fraction,filmLoss);
 micro=rvFieldEvaporate(micro,fraction,microLoss);
 evaporated=filmLoss+microLoss;
}
]]
local function replace(s,a,b)
 local out,n={},0;local at=1
 while true do local i,j=s:find(a,at,true);if not i then out[#out+1]=s:sub(at);break end
  out[#out+1]=s:sub(at,i-1)..b;at=j+1;n=n+1
 end
 return table.concat(out),n
end
function M.shader(s)
 local adapter='return ok?float4(area,raw.g,1,1):float4(-1,0,0,0);'
 if s:find(adapter,1,true)then
  local n;s,n=replace(s,adapter,'return ok?float4(area,raw.g,1,1+raw.b):float4(-1,0,0,0);');assert(n==1)
  return s,'cells'
 end
 if not s:find('void sourceCell(',1,true)then return s,false end
 local n;s,n=replace(s,'void sourceCell(',M.helpers..'void sourceCell(');assert(n==1)
 s,n=replace(s,'out float4 debit,out float code)','out float4 debit,out float4 fieldEvap,out float code)');assert(n==1)
 s,n=replace(s,'float4 film,micro,wall,runoff,raw,debit;','float4 film,micro,wall,runoff,raw,debit,fieldEvap;');assert(n>=1)
 s,n=replace(s,'wall,runoff,raw,debit,code);','wall,runoff,raw,debit,fieldEvap,code);')
 s=replace(s,'wall,runoff,raw,debit,bad);','wall,runoff,raw,debit,fieldEvap,bad);')
 s,n=replace(s,'next=0;nextMicro=0;wall=0;runoff=0;debit=0;code=1;','next=0;nextMicro=0;wall=0;runoff=0;debit=0;fieldEvap=0;code=1;');assert(n==1)
 s,n=replace(s,'cell.a==1','cell.a>=1&&cell.a<=2');assert(n==1)
 local anchor='wall=float4(0,debit.yzw+oldMicro.yzw+micro.yzw*cell.g);runoff=(incoming+micro)*(1-cell.g);'
 s,n=replace(s,anchor,anchor..'\n   rvFieldLifecycle(p,cell,next,nextMicro,fieldEvap);');assert(n==1)
 s,n=replace(s,'packetValid(debit);','packetValid(debit)&&packetValid(fieldEvap);');assert(n==1)
 s,n=replace(s,'raw=0;debit=0;}','raw=0;debit=0;fieldEvap=0;}');assert(n==1)
 if s:find('uint bank=min((uint)(pin.Tex.y*11)',1,true)then
  s,n=replace(s,'bank==5u||bank==7u','bank==5u||bank==6u||bank==7u');assert(n==1)
  s,n=replace(s,'if(bank==5u)v=wall;','if(bank==5u)v=wall;if(bank==6u)v=fieldEvap;');assert(n==1)
 end
 return s,'lifecycle'
end
function M.wrap(graph)
 if graph.productFieldLifecycle then return graph end
 local bind=graph.bind;local bodies={};local patched=setmetatable({},{__mode='k'})
 function graph:bind(dt,serial,c,...)
  local r=bind(self,dt,serial,c,...);local count,cells=0,0
  local evap=c.rows[27][1];local join=c.unitRows[2][1]
  assert(evap>=0 and evap<math.huge and join>0 and join<math.huge,'field lifecycle units')
  for _,p in ipairs(r.passes)do
   if not patched[p]then
    local entry=bodies[p.shader]
    if entry==nil then local s,kind=M.shader(p.shader);entry=kind and{body=s,kind=kind}or false;bodies[p.shader]=entry end
    if entry then p.shader=entry.body;p.cacheKey=p.cacheKey+31000000;patched[p]=entry.kind end
   end
   if patched[p]=='lifecycle'then
    p.values.gFieldEvapDepthMM=evap*.001*dt;p.values.gFieldMicroJoinMM=join*.001;count=count+1
    local bindings=0;for _ in pairs(p.textures)do bindings=bindings+1 end
    assert(bindings<=(p.textures.txPoolDebit and 15 or 14),'field lifecycle binding margin; below CSP16 limit')
   end
   if patched[p]=='cells'then cells=cells+1 end
  end
  assert(count==8 and cells==1,'validated cells plus status/totals/six commits share field lifecycle');return r
 end
 graph.productFieldLifecycle=true;return graph
end
return M
