-- CSP supplies samLinearClamp at s8. Keep offline producer sources unchanged.
local M={}
function M.shader(body)
 local result,n=body:gsub('SamplerState%s+samLinearClamp%s*;','')
 assert(not result:find('SamplerState%s+samLinearClamp%f[%W]'),'unexpected reserved sampler declaration')
 return result,n
end
function M.wrap(backend)
 local out={};for k,v in pairs(backend)do out[k]=v end
 local packets=setmetatable({},{__mode='k'});local shaders={}
 out.draw=function(canvas,p)
  local q=packets[p]
  if not q then
   local body=shaders[p.shader];if not body then body=M.shader(p.shader);shaders[p.shader]=body end
   if body==p.shader then q=p else
    q={};for k,v in pairs(p)do q[k]=v end;q.shader=body
    q.cacheKey=p.cacheKey+10000000
   end
   packets[p]=q
  end
  return backend.draw(canvas,q)
 end
 return out
end
return M
