-- Bounded travel approximation: exhausting the walk budget retains the last
-- valid position and transported velocity. Never invent an exit or lose water.
-- Physical input time still advances; rare fast heads can under-travel.
local M={}
local before='if(remaining>1e-7 && speed>1e-9)return captureTrace(position,velocity,remaining,dt,3);'
local after=[[
if(remaining>1e-7 && speed>1e-9){
 Trace limited=captureTrace(position,velocity,remaining,dt,0);
 limited.info.w=2;return limited;
}
]]
function M.shader(s)
 local i,j=s:find(before,1,true);if not i then return s,false end
 assert(not s:find(before,j+1,true),'one bounded trace implementation')
 return s:sub(1,i-1)..after..s:sub(j+1),true
end
function M.wrap(graph)
 if graph.productTraceLimit then return graph end
 local bind=graph.bind;local bodies={};local patched=setmetatable({},{__mode='k'})
 function graph:bind(...)
  local r=bind(self,...);local count=0
  for _,p in ipairs(r.passes)do
   if not patched[p]then
    local entry=bodies[p.shader]
    if entry==nil then local s,changed=M.shader(p.shader);entry=changed and s or false;bodies[p.shader]=entry end
    if entry then p.shader=entry;p.cacheKey=p.cacheKey+30000000;patched[p]=true end
   end
   if patched[p]then count=count+1 end
  end
  assert(count==1,'single head trace budget policy');return r
 end
 graph.productTraceLimit=true;return graph
end
return M
