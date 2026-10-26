-- Consume owned producer packets instead of rebinding/recomputing their inputs.
local M={}
local function replace(s,a,b)local i,j=s:find(a,1,true);assert(i,'known owned decoder expression');return s:sub(1,i-1)..b..s:sub(j+1)end
function M.decoder(s)
 s=replace(s,'ns=txNewState.Load(int3(i,0,0))','ns=txTrace.Load(int3(i,0,0))')
 s=replace(s,'float3 ov=0,nv=0;bool oldVelocity=true,newVelocity=true;\n   if(oa)oldVelocity=velocity(os,true,ov);',
  'float4 observedOld=txOwnership.Load(int3(i,5,0));float3 nv=0;bool oldVelocity=all(isfinite(observedOld))&&observedOld.r==om.g&&(om.g>0||all(observedOld.yzw==0)),newVelocity=true;')
 s=replace(s,'float4 oldHead=packet(om.g,ov),','float4 oldHead=observedOld,')
 return 'Texture2D<float4> txOldTransform;\nTexture2D<float4> txNewState;\n'..s
end
function M.new(d,seed,options)
 local g=d.CaptureGraph.new(d,seed,options);local bind=g.bind;local body
 function g:bind(...)
  local r=bind(self,...);local targets={};for _,p in ipairs(r.passes)do targets[p.target]=p end
  for _,p in ipairs(r.passes)do if p.cacheKey==268209 then
   local state=assert(targets[p.textures.txNewState],'owned new-state copy')
   local stateBody=state.shader:gsub('^Texture2D<float4> txFrameGuard;\n','')
   assert(stateBody==d.HeadSources.state and state.textures.txTrace==p.textures.txTrace,'new state must be the unchanged trace copy')
   if not body then body=M.decoder(p.shader)end
   p.shader=body;p.textures.txOldTransform=nil;p.textures.txNewState=nil;p.cacheKey=274209
   local n=0;for _ in pairs(p.textures)do n=n+1 end;assert(n<=14,'compact head decoder binding bound')
  end end
  return r
 end
 return g
end
return M
