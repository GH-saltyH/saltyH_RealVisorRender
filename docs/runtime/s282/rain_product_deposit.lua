-- Minimal product: moving heads deposit paths; field remains in place and dries.
-- No active-film force/advection or synthetic success receipt for removed work.
local M={}
M.ledger=[[
float4 main(PS_IN pin){
 return txSourceLedger.Load(int3(0,min((uint)(pin.Tex.y*8),7u),0));
}
]]
local flowLine=' float4 flow=txFlowReceipt.Load(int3(0,0,0)),clock=txFlowReceipt.Load(int3(1,0,0));'
local flowCheck='&&all(flow==float4(264,1,gSerial,1))&&all(clock==float4(1,gDt,gDt,0))'
local flowReason=' if(!all(flow==float4(264,1,gSerial,1))||!all(clock==float4(1,gDt,gDt,0)))reason|=16u;'
local function once(s,a,b)
 local i,j=s:find(a,1,true);assert(i,'known transport receipt clause')
 assert(not s:find(a,j+1,true),'unique transport receipt clause')
 return s:sub(1,i-1)..b..s:sub(j+1)
end
function M.receipt(s)
 s=once(s,flowLine,'');s=once(s,flowCheck,'');s=once(s,flowReason,'')
 assert(not s:find('txFlowReceipt',1,true),'removed transport is not consulted')
 return s
end
function M.pin(s)
 local anchor='ok=packetValid(next)&&packetValid(nextMicro)'
 if not s:find('void sourceCell(',1,true)then return s,false end
 -- A stationary film reservoir transfers its remaining tangential momentum
 -- to the surface, instead of retaining a velocity that is never advected.
 return once(s,anchor,'wall.yzw+=next.yzw;next.yzw=0;\n   '..anchor),true
end
function M.wrap(graph)
 if graph.productDepositOnly then return graph end
 -- Exclude never-submitted optional transport resources before executor allocates.
 local removedResources=0
 for name in pairs(graph.resources)do if name:find('^j_flow_')then graph.resources[name]=nil;removedResources=removedResources+1 end end
 assert(removedResources>0,'optional flow workspace identified')
 local bytes=0;for _,s in pairs(graph.resources)do bytes=bytes+s.width*s.height*(s.format=='r32f'and 4 or 16)end
 graph.descriptorBytes=bytes
 local bind=graph.bind;local patched=setmetatable({},{__mode='k'});local bodies={};local stats
 function graph:bind(...)
  local r=bind(self,...)
  if patched[r]then return r end
  local film
  for _,p in ipairs(r.passes)do if p.kind=='source'and p.values.gKind==0 then assert(not film);film=p.target end end
  assert(film,'checked source film root')
  local out={};local removed,ledger,receipt,selected=0,0,0,0
  for _,p in ipairs(r.passes)do
   if p.target:find('^j_flow_')then removed=removed+1
   else
    if p.shader:find('void sourceCell(',1,true)then
     local body=bodies[p.shader]
     if not body then body=M.pin(p.shader);bodies[p.shader]=body end
     p.shader=body;p.cacheKey=p.cacheKey+32000000
    end
    if p.kind=='jointLedger'then
     p.shader=M.ledger;p.cacheKey=p.cacheKey+32000000
     p.textures={txSourceLedger=assert(p.textures.txSourceLedger)};ledger=ledger+1
    elseif p.kind=='jointReceipt'then
     bodies.receipt=bodies.receipt or M.receipt(p.shader);p.shader=bodies.receipt;p.cacheKey=p.cacheKey+32000000
     p.textures.txFlowReceipt=nil;receipt=receipt+1
    elseif p.kind=='committed_film'then p.textures.txCandidate=film;selected=selected+1 end
    assert(not p.target:find('^j_flow_'))
    for _,role in pairs(p.textures)do assert(not role:find('^j_flow_'),'no dangling optional flow input')end
    out[#out+1]=p
   end
  end
  assert(removed>0 and ledger==1 and receipt==1 and selected==1,'minimal commit path complete')
  r.passes=out;patched[r]=true
  stats={mode='deposit_decay_only',activeFilmTransport=false,removedPasses=removed,
   recipeDraws=#out,removedResources=removedResources,descriptorBytes=bytes}
  return r
 end
 function graph:productMode()return stats end
 graph.productDepositOnly=true;return graph
end
return M
