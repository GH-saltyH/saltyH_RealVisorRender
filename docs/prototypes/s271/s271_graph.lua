-- Retain existing acceptance gates; add a reason mask to refused receipts only.
local M={}
function M.new(d,seed,options)
 local g=d.Graph.new(d,seed,options);local bind=g.bind;local receiptBody
 function g:bind(...)
  local r=bind(self,...)
  for _,p in ipairs(r.passes)do if p.kind=='jointReceipt'then
   if not receiptBody then
   local s=p.shader
   local mark=' float4 sum=0,scale=0,initial=0,final=0,incident=0,exit=0;'
   local code=[[
 uint reason=0;
 if(source.r!=1||!all(isfinite(source))||!all(isfinite(token)))reason|=1u;
 if(txHeadCheck.Load(int3(0,0,0)).r!=0)reason|=2u;
 if(!all(txSourceCheckpoint.Load(int3(0,0,0))==token)||checkpoint.x!=1||checkpoint.y!=token.z||checkpoint.z!=gDt||checkpoint.w!=1)reason|=4u;
 if(txHeadHeader.Load(int3(0,3,0)).w!=gDt||!all(txPhysics.Load(int3(0,0,0))==token))reason|=8u;
 if(!all(flow==float4(264,1,gSerial,1))||!all(clock==float4(1,gDt,gDt,0)))reason|=16u;
 if(txFrameGuard.Load(int3(0,0,0)).r!=1)reason|=256u;
 if(txSourceGuard.Load(int3(0,0,0)).r!=1)reason|=512u;
 ]]
   assert(s:find(mark,1,true));s=s:gsub(mark:gsub('([^%w])','%%%1'),function()return code..mark end,1)
   local a='  if(i==3u)ok=ok&&all(v.yzw==0);'
   assert(s:find(a,1,true));s=s:gsub(a:gsub('([^%w])','%%%1'),function()return a..'\n  if(!all(isfinite(v))||v.r<0||((i==4u||i==5u)&&v.r!=0)||(i==3u&&!all(v.yzw==0)))reason|=32u;'end,1)
   a=' ok=ok&&all(abs(sum)<=max(scale*(128*1.1920928955078125e-7),1e-9));'
   assert(s:find(a,1,true));s=s:gsub(a:gsub('([^%w])','%%%1'),function()return a..'\n if(!all(abs(sum)<=max(scale*(128*1.1920928955078125e-7),1e-9)))reason|=64u;'end,1)
   a='  before=isfinite(time.y)&&time.y>=0?time.y:0;'
   assert(s:find(a,1,true));s=s:gsub(a:gsub('([^%w])','%%%1'),function()return a..'\n  if(!all(previous==float4(267,1,gSerial-1,1))||time.x!=1||!all(isfinite(time))||time.y<0)reason|=128u;'end,1)
   s=s:gsub('else result=float4%(sum.yzw,ok%?0:1%);','else result=float4(sum.yzw,ok?0:(reason>0?reason:1024u));',1)
   receiptBody=s
   end
   p.shader=receiptBody;p.cacheKey=271002;p.textures.txFrameGuard='p_frameGuard';p.textures.txSourceGuard='j_sourceGuard'
  end end
  return r
 end
 return g
end
return M
