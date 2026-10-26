-- Source/raster momentum sums can cancel. Carry their absolute leaf terms in
-- unused edge-cap YZW channels; retain the original water bound and edge cap R.
local M={}
local eps='128*1.1920928955078125e-7'
local oldBound='max((abs(total(8))+abs(total(9)))*'..eps..',1e-9)'
M.bound=[[
float4 sourceComparisonBound(){
 float4 scale=abs(total(8))+abs(total(9));
 scale.yzw=max(scale.yzw,total(10).yzw);
 return max(scale*128*1.1920928955078125e-7,1e-9);
}
]]
local head='if(bank==8u||bank==10u){v=txSources.Load(int3(i,0,0))+txSources.Load(int3(i,3,0))+txSources.Load(int3(i,4,0));if(bank==10u&&txSources.Load(int3(i,7,0)).g==0)v=0;}'
local fixedHead=[[
if(bank==8u||bank==10u){
 float4 a=txSources.Load(int3(i,0,0)),b=txSources.Load(int3(i,3,0)),c=txSources.Load(int3(i,4,0));
 v=a+b+c;
 if(bank==10u){if(txSources.Load(int3(i,7,0)).g==0)v=0;v.yzw=abs(a.yzw)+abs(b.yzw)+abs(c.yzw);}
}]]
local field='if(bank==0u)v=txOriginalFilm.Load(int3(p,0))+txOriginalMicro.Load(int3(p,0));'
local fixedField=field..[[
   if(bank==10u)v=float4(0,abs(txRaster.Load(int3(p,0)).yzw)+abs(txRaster.Load(int3(p+int2(0,(int)gGrid.y),0)).yzw));
]]
local function replace(s,a,b)
 local out,n={},0;local at=1
 while true do local i,j=s:find(a,at,true);if not i then out[#out+1]=s:sub(at);break end
  out[#out+1]=s:sub(at,i-1)..b;at=j+1;n=n+1
 end
 return table.concat(out),n
end
function M.shader(s)
 if s:find(head,1,true)then
  local n;s,n=replace(s,head,fixedHead);assert(n==1,'single deposition source sum')
  s,n=replace(s,field,fixedField);assert(n==1,'single deposition raster sum')
  return s,'totals'
 end
 if s:find('float4 outsidePacket(){',1,true)then
  local n;s,n=replace(s,'float4 outsidePacket(){',M.bound..'float4 outsidePacket(){');assert(n==1)
  s,n=replace(s,oldBound,'sourceComparisonBound()');assert(n>=2,'outside, admission and diagnostics share bound')
  return s,'gate'
 end
 return s,nil
end
function M.wrap(graph)
 if graph.productDepositionBound then return graph end
 local bind=graph.bind;local bodies={};local patched=setmetatable({},{__mode='k'})
 function graph:bind(...)
  local r=bind(self,...);local totals,gates=0,0
  for _,p in ipairs(r.passes)do
   if not patched[p]then
    local entry=bodies[p.shader]
    if entry==nil then local body,kind=M.shader(p.shader);entry=kind and{body=body,kind=kind}or false;bodies[p.shader]=entry end
    if entry then p.shader=entry.body;p.cacheKey=p.cacheKey+29000000;patched[p]=entry.kind end
   end
   if patched[p]=='totals'then totals=totals+1 elseif patched[p]=='gate'then gates=gates+1 end
  end
  assert(totals==1 and gates>=2,'all deposition sum/commit/decision paths patched')
  return r
 end
 graph.productDepositionBound=true;return graph
end
return M
