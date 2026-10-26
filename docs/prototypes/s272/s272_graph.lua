-- Preserve the source gate's acceptance bit; expose its individual comparisons.
local M={}
M.guard=[[
float4 main(PS_IN pin){
 float4 token=txSourceHeader.Load(int3(0,0,0)),shape=txSourceHeader.Load(int3(0,1,0)),stamp=txSourceHeader.Load(int3(0,2,0));
 float4 mode=txSourceHeader.Load(int3(0,3,0)),previous=txSourceHeader.Load(int3(0,4,0));
 float4 published=txPublished.Load(int3(0,0,0)),phase=txPublished.Load(int3(0,1,0));
 float4 hh=txHeadHeader.Load(int3(0,0,0)),hg=txHeadHeader.Load(int3(0,4,0)),hf=txHeadHeader.Load(int3(0,2,0));
 float4 receipt=txHeadReceipt.Load(int3(0,0,0));uint reason=0;
 if(!(all(isfinite(token))&&integerValue(token.x)&&token.x>0&&integerValue(token.y)&&token.y>0&&integerValue(token.z)&&token.z>0&&token.w==1))reason|=1u;
 if(!(all(previous==published)&&all(previous.xy==token.xy)&&previous.z+1==token.z&&previous.w==1))reason|=2u;
 if(!all(phase==float4(2,previous.z,0,1)))reason|=4u;
 if(!all(receipt==token))reason|=8u;
 if(!all(hh==token))reason|=16u;
 if(!(all(shape==float4(gGrid,hg.z,gCount))&&all(hg.xy==gGrid)&&hg.z>=1&&hg.z<=16&&floor(hg.z)==hg.z))reason|=32u;
 if(!(all(isfinite(stamp))&&integerValue(stamp.x)&&stamp.x<=1048575&&stamp.y==hf.y&&integerValue(stamp.z)&&stamp.z>0&&stamp.w==1))reason|=64u;
 if(!(all(mode==float4(1,1,16,0))&&txHeadHeader.Load(int3(0,3,0)).w>0&&txHeadHeader.Load(int3(0,3,0)).w<=.05))reason|=128u;
 return float4(context()?1:0,(float)reason,receipt.r,receipt.z);
}
]]
function M.new(d,seed,options)
 local graph=d.PreviousGraph.new(d,seed,options);local bind=graph.bind;local guardBody,receiptBody
 function graph:bind(...)
  local r=bind(self,...)
  for _,p in ipairs(r.passes)do
   if p.kind=='sourceGuard'then
    if not guardBody then local i=assert(p.shader:find('float4 main%(PS_IN pin%)'),'source guard entry');guardBody=p.shader:sub(1,i-1)..M.guard end
    p.shader=guardBody;p.cacheKey=2721999
   elseif p.kind=='jointReceipt'then
    if not receiptBody then
     local tail='else result=float4(sum.yzw,ok?0:(reason>0?reason:1024u));'
     assert(p.shader:find(tail,1,true),'refused receipt diagnostic location')
     receiptBody=p.shader:gsub(tail:gsub('([^%w])','%%%1'),function()return 'else {float3 detail=txSourceGuard.Load(int3(0,0,0)).gba;result=float4(ok?sum.yzw:detail,ok?0:(reason>0?reason:1024u));}'end,1)
    end
    p.shader=receiptBody;p.cacheKey=272002
   end
  end
  return r
 end
 return graph
end
return M
