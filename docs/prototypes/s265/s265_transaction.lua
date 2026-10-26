-- Private transactional wrapper. Provisional work never aliases committed roots.
local M={}
M.commit=[[
float4 main(PS_IN pin){
 int2 p=min((int2)(pin.Tex*float2(gGrid.x,gGrid.y*4)),int2(gGrid.x-1,gGrid.y*4-1));
 float4 token=txReceipt.Load(int3(0,0,0)),clock=txReceipt.Load(int3(1,0,0));
 bool accept=all(token==gToken)&&clock.x==1&&all(isfinite(clock))&&clock.y>=0&&clock.z>0&&clock.w==0;
 float4 result=0;
 if(accept)result=txCandidate.Load(int3(p,0));
 else if(gHasPrior==1||p.y<(int)gGrid.y)result=txPrior.Load(int3(p,0));
 return result;
}
]]
M.snapshot=[[
float4 main(PS_IN pin){uint i=min((uint)(pin.Tex.x*16),15u);float4 r=txReceipt.Load(int3(i/4u,0,0));return float4(r[i%4u],0,0,1);}
]]
local function cp(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=cp(v)end;return r end
function M.new(Core,w,h,absorb)
 local cache=Core:compile(w,h,absorb);local resources=cp(cache.resources)
 resources.committedA={width=w,height=h*4,format='rgba32f'};resources.committedB=cp(resources.committedA)
 local bytes=cache.descriptorBytes+w*h*16*8
 local api={resources=resources,descriptorBytes=bytes}
 function api:bind(dt,serial)
  local hasPrior=serial>1;local recipe=cache:bind(dt,hasPrior,serial)
  local previous=serial%2==1 and'committedB'or'committedA';local target=serial%2==1 and'committedA'or'committedB'
  local priorReceipt=serial%2==1 and'receiptB'or'receiptA'
  for _,p in ipairs(recipe.passes)do
   for name,id in pairs(p.textures)do
    if id=='prior'then p.textures[name]=hasPrior and previous or'initial'
    elseif id=='priorReceipt'then p.textures[name]=hasPrior and priorReceipt or'zeroReceipt'end
   end
   if p.kind=='receipt'then p.values.gToken={265,1,serial,1};p.values.gPrevious={265,1,serial-1,1}end
   p.cacheKey=265000+({force=1,velocity=2,flux=3,gather=4,tiles=5,reduce=6,receipt=7})[p.kind]
  end
  recipe.passes[#recipe.passes+1]={kind='commit',target=target,textures={txReceipt=recipe.receipt,txCandidate='state',txPrior=hasPrior and previous or'initial'},
   values={gGrid={w,h},gToken={265,1,serial,1},gHasPrior=hasPrior and 1 or 0},shader=M.commit,cacheKey=265008}
  recipe.final=target;recipe.serial=serial;return recipe
 end
 function api:validate(words,serial,dt,before)
  if type(words)~='table'or #words~=16 then return false,'receipt shape'end
  for _,x in ipairs(words)do if type(x)~='number'or x~=x or math.abs(x)==math.huge then return false,'finite receipt'end end
  local accept=words[5]
  if words[1]~=265 or words[2]~=1 or words[3]~=serial or(accept~=0 and accept~=1)or words[4]~=accept then return false,'receipt identity'end
  local tolerance=math.max(1e-7,math.abs(before+dt)*16*2^-23)
  if math.abs(words[6]-(before+dt*accept))>tolerance or math.abs(words[7]-dt*accept)>tolerance or math.abs(words[8]-dt*(1-accept))>tolerance then return false,'receipt time'end
  if accept==1 and(words[13]~=0 or words[16]~=0 or words[9]<0 or words[10]<0 or words[11]<0)then return false,'accepted diagnostics'end
  local waterTolerance=1e-6+(math.abs(words[9])+math.abs(words[10])+math.abs(words[11]))*1e-6
  if accept==1 and(math.abs(words[9]-words[10]-words[11])>waterTolerance or math.abs(words[12])>waterTolerance)then return false,'water summary'end
  return true,accept==1
 end
 return api
end
return M
