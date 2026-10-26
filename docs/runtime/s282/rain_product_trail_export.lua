-- Preserve accepted trail-only geometry and coarse contribution in a fixed GPU
-- ring. This is a read-only display sidecar: no physical input/stock/gate changes.
local M={capacity=16}
M.geometry=[[
float4 main(PS_IN pin){
 uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1),row=min((uint)(pin.Tex.y*2),1u);
 if(!all(txReceipt.Load(int3(0,0,0))==float4(267,1,gSerial,1)))return 0;
 float4 packet=txSources.Load(int3(i,0,0)),path=txSources.Load(int3(i,1,0));
 if(packet.r<=0||!all(isfinite(packet))||!all(isfinite(path)))return 0;
 if(row==0)return path;
 float2 uv=(path.zw+.5)/gGrid;
 int2 p=clamp((int2)(uv*float2(2048,512)),int2(0,0),int2(2047,511));
 float3 u=txDu.Load(int3(p,0)).xyz,v=txDv.Load(int3(p,0)).xyz;
 float a=dot(u,u),b=dot(u,v),c=dot(v,v),det=a*c-b*b;
 float radius=txPreMeta.Load(int3(i,0,0)).r*gMetersPerUnit*gWiden;
 if(!isfinite(radius)||radius<=0||det<=1e-20)return 0;
 float2 extent=radius*sqrt(float2(c,a)/det)*gGrid;
 return all(isfinite(extent))?float4(extent,packet.r,gSerial):0;
}
]]
M.marker=[[
float4 main(PS_IN pin){
 float4 receipt=txReceipt.Load(int3(0,0,0));
 if(!all(receipt==float4(267,1,gSerial,1)))return 0;
 return float4(gSerial,txReceipt.Load(int3(1,0,0)).y,gDt,1);
}
]]
M.invalidate='float4 main(PS_IN pin){return 0;}'
M.copy='float4 main(PS_IN pin){return txInput.Load(int3((int2)(pin.Tex*gSize),0));}'
M.bin=[[
float trailBits(uint base,float2 low,float2 high){uint bits=0;
 [loop]for(uint b=0;b<24;b++){uint i=base+b;if(i>=(uint)gCount)break;
  float4 path=txGeometry.Load(int3(i,0,0)),info=txGeometry.Load(int3(i,1,0));
  // Cover the full legal display gain range, not just the physical footprint.
  float2 support=max(info.xy*4,float2(.125,.125))*1.87082869338697;
  if(info.z>0&&all(max(path.xy,path.zw)+support>=low)&&all(min(path.xy,path.zw)-support<=high))bits|=1u<<b;
 }return(float)bits;}
float4 main(PS_IN pin){uint x=(uint)(pin.Tex.x*gMaskW),y=(uint)(pin.Tex.y*gTilesY);
 uint tile=x/(uint)gWords,base=(x-tile*(uint)gWords)*96;
 float2 low=float2(tile,y)*gTile-.5,high=low+gTile;
 return float4(trailBits(base,low,high),trailBits(base+24,low,high),trailBits(base+48,low,high),trailBits(base+72,low,high));}
]]
local function once(s,a,b)
 local i,j=s:find(a,1,true);assert(i,'known production trail raster clause')
 assert(not s:find(a,j+1,true),'unique trail raster clause')
 return s:sub(1,i-1)..b..s:sub(j+1)
end
function M.claim(s)
 -- Reuse the exact integer tent / integrated line and existing sparse bins.
 -- Do not estimate trail as a difference of total film inventories.
 s=once(s,'float4 v=txSources.Load(int3(i,bank==0u?3:4,0))*w;','float4 v=0;')
 s=once(s,'uint bank=min((uint)(pin.Tex.y*2),1u);int2 cell=min((int2)(float2(pin.Tex.x,frac(pin.Tex.y*2))*gGrid),(int2)gGrid-1);',
  'uint bank=0u;int2 cell=min((int2)(pin.Tex*gGrid),(int2)gGrid-1);\n if(!all(txTrailReceipt.Load(int3(0,0,0))==float4(267,1,gSerial,1)))return 0;')
 s=once(s,'return all(isfinite(total))?total:float4(-1,0,0,0);',
  'float coverage=txTrailCells.Load(int3(cell,0)).g;\n return all(isfinite(total))&&isfinite(coverage)?float4(max(total.r,0)*saturate(coverage),0,0,0):0;')
 return s
end
function M.wrap(graph)
 if graph.productTrailExport then return graph end
 local n=graph.headCount;local capacity=M.capacity;local ring={}
 for i=1,capacity do
  local prefix='display_trail_'..i..'_'
  ring[i]={geometry=prefix..'geometry',claim=prefix..'claim',marker=prefix..'marker',mask=prefix..'mask',summary=prefix..'summary'}
  graph.resources[ring[i].geometry]={width=n,height=2,format='rgba32f'}
  graph.resources[ring[i].claim]={width=1024,height=256,format='r32f'}
  graph.resources[ring[i].marker]={width=1,height=1,format='rgba32f'}
  graph.resources[ring[i].mask]={width=32*math.ceil(n/96),height=8,format='rgba32f'}
  graph.resources[ring[i].summary]={width=32,height=8,format='rgba32f'}
 end
 local extra=capacity*(n*2*16+1024*256*4+16+(32*math.ceil(n/96)*8+32*8)*16)
 graph.descriptorBytes=graph.descriptorBytes+extra
 local bind=graph.bind;local entries=setmetatable({},{__mode='k'});local body
 function graph:bind(dt,serial,c,...)
  local r=bind(self,dt,serial,c,...);local entry=entries[r]
  if not entry then
   local byTarget={};local gather;local cells
   for _,p in ipairs(r.passes)do
    byTarget[p.target]=p
    if p.shader:find('void evaluate(int i,float2 cell,uint bank',1,true)then assert(not gather);gather=p end
    if p.shader:find('void sourceCell(',1,true)and p.textures.txCells then
     assert(not cells or cells==p.textures.txCells,'shared validated source cells');cells=p.textures.txCells
    end
   end
   assert(gather,'one production sparse source raster')
   local decoded=assert(byTarget[r.audit.textures.txDecoded]);local preMeta=assert(decoded.textures.txPreMeta)
   local receipt
   for _,p in ipairs(r.passes)do if p.kind=='receiptCopy'then receipt=p.textures.txInput end end
   assert(type(receipt)=='string','joint receipt before final receipt copy')
   body=body or M.claim(gather.shader)
   local g={kind='trailGeometry',shader=M.geometry,cacheKey=284001,textures={
    txReceipt=receipt,txSources=gather.textures.txSources,txPreMeta=preMeta,txDu='fileDu',txDv='fileDv'},values={gCount=n,gGrid={1024,256}}}
   local q={kind='trailClaim',shader=body,cacheKey=284002,textures={txSources=gather.textures.txSources,
    txMask=gather.textures.txMask,txSummary=gather.textures.txSummary,txTrailCells=cells,txTrailReceipt=receipt},
    values={gCount=n,gGrid={1024,256},gTile=gather.values.gTile,gWords=gather.values.gWords}}
   assert(q.textures.txTrailCells,'same validated coverage as source transaction')
   local marker={kind='trailMarker',shader=M.marker,cacheKey=284003,textures={txReceipt=receipt},values={}}
   local sourceSummary=assert(byTarget[gather.textures.txSummary])
   local mask={kind='trailMask',shader=M.bin,cacheKey=284006,textures={},values={gCount=n,gTile=32,gWords=math.ceil(n/96),gMaskW=32*math.ceil(n/96),gTilesY=8}}
   local summary={kind='trailSummary',shader=sourceSummary.shader,cacheKey=284007,textures={},values={gSummaryW=32,gTilesY=8,gSummaryWords=1,gWords=math.ceil(n/96)}}
   local invalidate={kind='trailInvalidate',shader=M.invalidate,cacheKey=284004,textures={},values={}}
   entry={original=r.passes,geometry=g,claim=q,marker=marker,mask=mask,summary=summary,invalidate=invalidate};entries[r]=entry
  end
  local slot=ring[(serial-1)%capacity+1];local out={}
  for _,p in ipairs(entry.original)do out[#out+1]=p end
  -- Invalidate BEFORE either texture is overwritten. Publish marker LAST.
  -- No consumer may use a stale marker with partially replaced geometry/claim.
  local function invalidate(target)
   out[#out+1]={kind='trailInvalidate',target=target,shader=M.invalidate,cacheKey=284004,textures={},values={}}
  end
  if serial==1 then for _,s in ipairs(ring)do invalidate(s.marker)end else invalidate(slot.marker)end
  local g,q,m=entry.geometry,entry.claim,entry.marker
  g.target=slot.geometry;q.target=slot.claim;m.target=slot.marker
  entry.mask.target=slot.mask;entry.summary.target=slot.summary
  entry.mask.textures.txGeometry=slot.geometry;entry.summary.textures.txMask=slot.mask
  g.values.gSerial=serial;g.values.gMetersPerUnit=c.unitRows[1][1]
  g.values.gWiden=1+c.rows[26][4]*math.min(c.rows[27][2]/30,1)
  q.values.gSerial=serial;m.values.gSerial=serial;m.values.gDt=dt
  out[#out+1]=g;out[#out+1]=q;out[#out+1]=entry.mask;out[#out+1]=entry.summary;out[#out+1]=m;r.passes=out
  return r
 end
 function graph:trailExport()return{scope='accepted_trail_cohort_ring_v1',capacity=capacity,ring=ring,
  descriptorBytes=extra,recurringDraws=6,firstDraws=capacity+5,tile=32,words=math.ceil(n/96),
  claimDomain='accepted incoming trail after coverage before field drying',physicalStockChanged=false}end
 graph.productTrailExport=true;return graph
end
return M
