-- Keep red acceptance decisions; retain the first per-head failure in G/B.
local M={statusWidth=160}
M.reduce=[[
float4 main(PS_IN pin){
 uint i=min((uint)(pin.Tex.x*gWidth),(uint)gWidth-1u),n=(uint)gInputCount;float bad=0,code=0,index=0;
 [unroll]for(uint j=0;j<16u;++j){uint k=i*16u+j;if(k<n){float4 v=txInput.Load(int3(k,(int)gStatusRow,0));
  if(!all(isfinite(v))||v.r!=0){if(bad==0){code=all(isfinite(v))?(gStatusRow>0?v.r:v.g):7;index=all(isfinite(v))?(gStatusRow>0?v.g:v.b):k;}bad=1;}
 }}return float4(bad,code,index,0);
}
]]
M.snapshot=[[
float4 main(PS_IN pin){
 uint i=min((uint)(pin.Tex.x*160),159u),row=i/4u,component=i%4u;
 uint slot=min((uint)max(txDecision.Load(int3(0,0,0)).b,0),(uint)gCount-1u);float4 v=0;
 if(row<4u)v=txReceipt.Load(int3(row,0,0));
 else if(row==4u)v=txDecision.Load(int3(0,0,0));
 else if(row==5u)v=txOldState.Load(int3(slot,0,0));
 else if(row==6u)v=txOldMeta.Load(int3(slot,0,0));
 else if(row<12u)v=txEvents.Load(int3(slot,row-7u,0));
 else if(row<18u)v=txOwnership.Load(int3(slot,row-12u,0));
 else if(row==18u)v=txPostForce.Load(int3(slot,0,0));
 else if(row<23u)v=txTrace.Load(int3(slot,row-19u,0));
 else if(row==23u)v=txPreMeta.Load(int3(slot,0,0));
 else if(row<29u)v=txDescriptors.Load(int3(slot,row-24u,0));
 else if(row==29u)v=txFinalMeta.Load(int3(slot,0,0));
 else if(row==30u)v=txDecoded.Load(int3(slot,13,0));
 else if(row<34u)v=txMergeConfig.Load(int3(0,row-31u,0));
 float word=v[component];return i<16u?word:(isfinite(word)?word:3.402823466e38);
}
]]
function M.new(d,seed,options)
 local g=d.DiagnosticGraph.new(d,seed,options);local bind=g.bind;local guardBody
 function g:bind(...)
  local r=bind(self,...);local byTarget={};local guard
  for _,p in ipairs(r.passes)do
   byTarget[p.target]=p
   if p.kind:find('^head_')and p.values.gInputCount then p.shader=M.reduce;p.cacheKey=p.cacheKey+3000000 end
   if p.kind=='sourceGuard'then guard=p end
  end
  local exported=assert(byTarget[guard.textures.txHeadReceipt]);local decode=assert(byTarget[exported.textures.txDecoded]);local traced=assert(byTarget[decode.textures.txTrace]);local tx=decode.textures
  guard.textures.txHeadDecision=assert(exported.textures.txDecision)
  if not guardBody then
   local old='return float4(context()?1:0,(float)reason,receipt.r,receipt.z);'
   assert(guard.shader:find(old,1,true));guardBody=guard.shader:gsub(old:gsub('([^%w])','%%%1'),function()return 'float4 decision=txHeadDecision.Load(int3(0,0,0));return float4(context()?1:0,(float)reason,decision.g,decision.b);'end,1)
  end
  guard.shader=guardBody;guard.cacheKey=2731999
  r.audit={textures={txReceipt=r.receipt,txDecision=exported.textures.txDecision,txDecoded=exported.textures.txDecoded,txOldState=tx.txOldState,txOldMeta=tx.txOldMeta,txEvents=tx.txEvents,txOwnership=tx.txOwnership,txTrace=tx.txTrace,txPreMeta=tx.txPreMeta,txDescriptors=tx.txDescriptors,txFinalMeta=tx.txFinalMeta,txPostForce=traced.textures.txPostForce,txMergeConfig='p_mergeConfig'},values={gCount=seed.rows[2][4]}}
  return r
 end
 return g
end
return M
