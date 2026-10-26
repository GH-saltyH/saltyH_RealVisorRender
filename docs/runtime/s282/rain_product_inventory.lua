-- Product-only inventory continuity comparison. Physical stocks are unchanged.
-- A signed momentum sum is ill-conditioned near cancellation. Use the existing
-- ledger's absolute-term scale for momentum, as in the other closure gates.
-- The nonnegative water-volume component retains its original bound exactly.
local M={}
local old='max((abs(txPreviousLedger.Load(int3(0,1,0)))+abs(total(0)))*128*1.1920928955078125e-7,1e-9)'
local replacement='max(inventoryComparisonScale*128*1.1920928955078125e-7,1e-9)'
M.scale=[[
 float4 inventoryComparisonScale=abs(txPreviousLedger.Load(int3(0,1,0)))+abs(total(0));
 inventoryComparisonScale.yzw=max(inventoryComparisonScale.yzw,oldScale.yzw);
]]
function M.shader(body)
 local marker='float4 inventoryError=';local n=0
 local at=1;local out={}
 while true do
  local i,j=body:find(marker,at,true);if not i then out[#out+1]=body:sub(at);break end
  out[#out+1]=body:sub(at,i-1)..M.scale..marker;at=j+1;n=n+1
 end
 if n==0 then return body,0 end
 body=table.concat(out);local result={};at=1;local bounds=0
 while true do
  local i,j=body:find(old,at,true);if not i then result[#result+1]=body:sub(at);break end
  result[#result+1]=body:sub(at,i-1)..replacement;at=j+1;bounds=bounds+1
 end
 assert(bounds==n,'Every inventory test and diagnostic must share the bound')
 return table.concat(result),n
end
function M.wrap(graph)
 if graph.productInventoryBound then return graph end
 local bind=graph.bind;local patched=setmetatable({},{__mode='k'});local bodies={}
 function graph:bind(...)
  local r=bind(self,...);local count=0
  for _,p in ipairs(r.passes)do
   if not patched[p]then
    local entry=bodies[p.shader]
    if entry==nil then local s,n=M.shader(p.shader);entry=n>0 and s or false;bodies[p.shader]=entry end
    if entry then p.shader=entry;p.cacheKey=p.cacheKey+28000000;patched[p]=true end
   end
   if patched[p]then count=count+1 end
  end
  assert(count>0,'Product source inventory comparison must be present');return r
 end
 graph.productInventoryBound=true;return graph
end
return M
