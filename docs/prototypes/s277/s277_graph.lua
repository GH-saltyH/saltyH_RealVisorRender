-- A zero pool debit is the identity; do not divide/reconstruct momentum.
local M={}
local before='float fraction=old.r>0?remaining/old.r:0;float4 retained=float4(remaining,old.yzw*fraction);debit=old-retained;'
local after='float4 retained=old;debit=0;if(requested>0){float fraction=remaining/old.r;retained=float4(remaining,old.yzw*fraction);debit=old-retained;}'
function M.cell(body)
 local i,j=body:find(before,1,true);if not i then return body,false end
 assert(not body:find(before,j+1,true),'single source cell implementation')
 return body:sub(1,i-1)..after..body:sub(j+1),true
end
function M.new(d,seed,options)
 local g=d.ApprovalGraph.new(d,seed,options);local bind=g.bind;local shaders={}
 function g:bind(...)
  local r=bind(self,...);local changed=0
  for _,p in ipairs(r.passes)do
   local key=p.cacheKey;local body=shaders[key]
   if body==nil then local fixed,edit=M.cell(p.shader);body=edit and fixed or false;shaders[key]=body end
   if body then p.shader=body;p.cacheKey=key+6000000;changed=changed+1 end
  end
  assert(changed==8,'source cell status/totals/six commits share one identity rule')
  return r
 end
 return g
end
return M
