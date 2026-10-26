-- Source rejection detail in unused channels; original red decisions unchanged.
local M={}
local function once(s,a,b)local i,j=s:find(a,1,true);assert(i,'known source contract');return s:sub(1,i-1)..b..s:sub(j+1)end
function M.source(s)
 s=once(s,'float code=1;','float code=1;uint detail=0;')
 local a=assert(s:find('  bool ok=all(head',1,true));local b=assert(s:find('  code=ok?0:2;',a,true))
 local section=s:sub(a,b-1);local bit=0
 section=section:gsub('bool ok=([^;]+);',function(expr)bit=bit+1;return 'bool ok='..expr..';if(!ok)detail|=1u;'end,1)
 section=section:gsub('ok=ok&&([^;]+);',function(expr)bit=bit+1;return 'ok=ok&&('..expr..');if(!('..expr..'))detail|='..string.format('%d',2^(bit-1))..'u;'end)
 s=s:sub(1,a-1)..section..s:sub(b)
 s=once(s,'?1:0,0,0);','?1:0,(float)detail,(float)i);')
 return s
end
function M.decision(s)
 local entry='float4 main(PS_IN pin){return float4(ledgerAdmission()?1:0,0,0,0);}'
 local diagnostic=[[
float4 main(PS_IN pin){
 bool accepted=ledgerAdmission();uint mask=0;
 if(!context())mask|=1u;
 float status=txStatus.Load(int3(0,0,0)).r;if(status!=0)mask|=2u;
 [unroll]for(uint j=0;j<11u;j++)if(!all(isfinite(total(j))))mask|=4u;
 float4 tail=outsidePacket(),bound=max((abs(total(8))+abs(total(9)))*128*1.1920928955078125e-7,1e-9);
 if(!packetValid(tail)||tail.r>total(10).r+bound.r)mask|=8u;
 float4 sum=0,oldSum=0,newSum=0,scale=0,oldScale=0,newScale=0;
 [unroll]for(uint k=0;k<8u;k++){
  float4 v=stepRow(k),old=txPreviousLedger.Load(int3(0,k,0)),next=cumulativeRow(k);
  if(!ledgerPacket(k,v)||!ledgerPacket(k,old)||!ledgerPacket(k,next))mask|=16u;
  float sign=(k==0u||k==2u||k==4u)?-1:((k==3u)?0:1);
  sum+=v*sign;oldSum+=old*sign;newSum+=next*sign;scale+=abs(v);oldScale+=abs(old);newScale+=abs(next);
 }
 float4 inventoryError=txPreviousLedger.Load(int3(0,1,0))-total(0);
 if(!all(abs(inventoryError)<=max((abs(txPreviousLedger.Load(int3(0,1,0)))+abs(total(0)))*128*1.1920928955078125e-7,1e-9)))mask|=32u;
 if(!all(abs(sum)<=max(scale*128*1.1920928955078125e-7,1e-9)))mask|=64u;
 if(!all(abs(oldSum)<=max(oldScale*128*1.1920928955078125e-7,1e-9)))mask|=128u;
 if(!all(abs(newSum)<=max(newScale*128*1.1920928955078125e-7,1e-9)))mask|=256u;
 return float4(accepted?1:0,(float)mask,status,0);
}]]
 return once(s,entry,diagnostic)
end
function M.new(d,seed,options)
 local g=d.IntegrationGraph.new(d,seed,options);local bind=g.bind;local bodies={}
 function g:bind(...)
  local r=bind(self,...);local decision,sources
  for _,p in ipairs(r.passes)do
   if p.cacheKey==2691003 then
    bodies.source=bodies.source or M.source(p.shader);p.shader=bodies.source;p.cacheKey=275003;sources=p
   elseif p.shader:find('float4 main(PS_IN pin){return float4(ledgerAdmission()?1:0,0,0,0);}',1,true)then
    bodies.decision=bodies.decision or M.decision(p.shader);p.shader=bodies.decision;p.cacheKey=275004;decision=p
   end
  end
  assert(sources and decision,'source producer and decision retained')
  -- This run targets source approval. Keep the receipt and seven source inputs;
  -- do not push the SDK boundary back up to sixteen textures.
  local decoded=r.audit.textures.txDecoded
  r.audit.textures={txReceipt=r.receipt,txDecoded=decoded,txSourcePackets=sources.target,
   txSourceDecision=decision.target,txSourceTotals=decision.textures.txTotals,
   txSourceLedger=decision.textures.txPreviousLedger,txSourceOriginal=sources.textures.txOriginalHeads}
  return r
 end
 return g
end
return M
