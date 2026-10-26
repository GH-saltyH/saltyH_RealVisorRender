-- Source raster + compact transport + joint physical inventory commit.
-- Producer/source inputs remain immutable until the final receipt is consumed.
local M={}
M.headCheck=[[
float4 main(PS_IN pin){
 uint tile=(uint)(pin.Tex.x*gTiles);float bad=0;
 [unroll]for(uint k=0;k<16u;k++){
  uint i=tile*16u+k;if(i>=(uint)gCount)continue;
  float4 state=txState.Load(int3(i,0,0)),meta=txMeta.Load(int3(i,0,0)),head=txHeads.Load(int3(i,0,0));
  float4 old=txOldMeta.Load(int3(i,0,0)),oldHead=txOldHeads.Load(int3(i,0,0)),oldState=txOldState.Load(int3(i,0,0));
  bool ok=all(isfinite(state))&&all(isfinite(meta))&&all(isfinite(oldState))&&all(isfinite(old))&&
   meta.g==head.r&&old.g==oldHead.r&&all(meta.rgb>=0)&&all(old.rgb>=0)&&meta.a>=0&&old.a>=0&&
   meta.a<16384&&old.a<16384&&floor(meta.a)==meta.a&&floor(old.a)==old.a;
  bad+=ok?0:1;
 }return float4(bad,0,0,0);
}
]]
M.reduceHeads=[[
float4 main(PS_IN pin){uint tile=(uint)(pin.Tex.x*gOutput);float bad=0;[unroll]for(uint k=0;k<16u;k++){uint i=tile*16u+k;if(i<(uint)gInput)bad+=txInput.Load(int3(i,0,0)).r;}return float4(bad,0,0,0);}
]]
M.ledger=[[
float4 main(PS_IN pin){
 uint row=min((uint)(pin.Tex.y*8),7u);float4 value=txSourceLedger.Load(int3(0,row,0));
 if(row==1u)value+=txFlowLedger.Load(int3(0,1,0))-txFlowLedger.Load(int3(0,0,0));
 else if(row==4u)value+=txFlowLedger.Load(int3(0,3,0));
 else if(row==5u)value+=txFlowLedger.Load(int3(0,4,0));
 else if(row==7u)value+=txFlowLedger.Load(int3(0,2,0));
 return value;
}
]]
M.receipt=[[
float4 main(PS_IN pin){
 uint row=min((uint)(pin.Tex.x*4),3u);
 float4 source=txSourceDecision.Load(int3(0,0,0)),token=txSourceHeader.Load(int3(0,0,0));
 float4 checkpoint=txSourceCheckpoint.Load(int3(0,1,0));
 float4 flow=txFlowReceipt.Load(int3(0,0,0)),clock=txFlowReceipt.Load(int3(1,0,0));
 bool ok=source.r==1&&all(isfinite(source))&&all(isfinite(token))&&txHeadCheck.Load(int3(0,0,0)).r==0&&
  all(txSourceCheckpoint.Load(int3(0,0,0))==token)&&checkpoint.x==1&&checkpoint.y==token.z&&checkpoint.z==gDt&&checkpoint.w==1&&
  txHeadHeader.Load(int3(0,3,0)).w==gDt&&all(txPhysics.Load(int3(0,0,0))==token)&&all(flow==float4(264,1,gSerial,1))&&all(clock==float4(1,gDt,gDt,0));
 float4 sum=0,scale=0,initial=0,final=0,incident=0,exit=0;
 [unroll]for(uint i=0;i<8u;i++){
  float4 v=txJointLedger.Load(int3(0,i,0));ok=ok&&all(isfinite(v))&&v.r>=0;
  if(i==4u||i==5u)ok=ok&&v.r==0;
  if(i==3u)ok=ok&&all(v.yzw==0);
  float sign=(i==0u||i==2u||i==4u)?-1:(i==3u?0:1);sum+=v*sign;scale+=abs(v);
  if(i==0u)initial=v;else if(i==1u)final=v;else if(i==2u)incident=v;else if(i==6u||i==7u)exit+=v;
 }
 ok=ok&&all(abs(sum)<=max(scale*(128*1.1920928955078125e-7),1e-9));
 float before=0;
 if(gHasPrior==1){
  float4 previous=txPriorReceipt.Load(int3(0,0,0)),time=txPriorReceipt.Load(int3(1,0,0));
  ok=ok&&all(previous==float4(267,1,gSerial-1,1))&&time.x==1&&all(isfinite(time))&&time.y>=0;
  before=isfinite(time.y)&&time.y>=0?time.y:0;
 }
 float4 result=0;
 if(row==0u)result=float4(267,1,gSerial,ok?1:0);
 else if(row==1u)result=float4(ok?1:0,before+(ok?gDt:0),ok?gDt:0,ok?0:gDt);
 else if(row==2u)result=float4(initial.r+incident.r,final.r,exit.r,sum.r);
 else result=float4(sum.yzw,ok?0:1);
 return result;
}
]]
M.select=[[
float4 main(PS_IN pin){
 bool accept=all(txReceipt.Load(int3(0,0,0))==float4(267,1,gSerial,1))&&txReceipt.Load(int3(1,0,0)).x==1;
 int2 p=min((int2)(pin.Tex*gSize),(int2)gSize-1);return accept?txCandidate.Load(int3(p,0)):txOld.Load(int3(p,0));
}
]]
M.checkpoint=[[
float4 main(PS_IN pin){uint row=min((uint)(pin.Tex.y*2),1u);float4 token=txSource.Load(int3(0,0,0));return row==0u?token:float4(2,token.z,0,1);}
]]
local function cp(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=cp(v)end;return r end
function M.validate(words,serial,dt,before)
 if type(words)~='table'or #words~=16 then return false,'receipt shape'end
 for _,v in ipairs(words)do if type(v)~='number'or v~=v or math.abs(v)==math.huge then return false,'finite receipt'end end
 local a=words[5];if(a~=0 and a~=1)or words[1]~=267 or words[2]~=1 or words[3]~=serial or words[4]~=a then return false,'receipt identity'end
 local tolerance=math.max(1e-7,math.abs(before+dt)*16*2^-23)
 if math.abs(words[6]-before-dt*a)>tolerance or math.abs(words[7]-dt*a)>tolerance or math.abs(words[8]-dt*(1-a))>tolerance then return false,'receipt time'end
 local waterTolerance=1e-9+(math.abs(words[9])+math.abs(words[10])+math.abs(words[11]))*128*2^-23
 if a==1 and(words[16]~=0 or words[9]<0 or words[10]<0 or words[11]<0 or math.abs(words[9]-words[10]-words[11])>waterTolerance or math.abs(words[12])>waterTolerance)then return false,'joint water summary'end
 return true,a==1
end
function M.recipe(Core,source,packet,w,h,count,dt,serial)
 assert(type(serial)=='number'and serial==math.floor(serial)and serial>=1 and serial<=1048575,'interval serial')
 assert(source.resources[5].width==w and source.resources[5].height==h and source.resources[12].width==count,'source layout')
 local r={resources={},passes={},roots={},imports={},scope='joint_physical_source_transport_v1'}
 local function resource(id,desc)r.resources[id]=cp(desc);return id end
 for i,d in ipairs(source.resources)do local id='source'..i;resource(id,d);if d.imported then r.imports[i]=id end end
 for i,p in ipairs(source.passes)do
  local tx={};for k,v in pairs(p.textures)do tx[k]='source'..v end
  r.passes[#r.passes+1]={kind='source',target='source'..p.target,textures=tx,values=cp(packet.passes[i]),shader=p.shader,cacheKey=p.cacheKey}
 end
 local function root(n)return'source'..assert(source.roots[n],n)end
 local cache=Core:compile(w,h,true);local flow=cache:bind(dt,false,serial)
 for n,d in pairs(cache.resources)do resource('flow_'..n,d)end
 local external={metric={w,h*3},areas={w,h},runs={w,h},physics={1,5},priorReceipt={4,1}}
 for _,n in ipairs({'oldState','oldMeta','newState','newMeta'})do external[n]={count,1}end
 for n,size in pairs(external)do resource(n,{width=size[1],height=size[2],format='rgba32f',imported=true})end
 for _,p in ipairs(flow.passes)do
  local tx={};for n,v in pairs(p.textures)do
   tx[n]=(v=='prior'or v=='initial')and root('film')or external[v]and v or'flow_'..v
  end
  -- Each interval starts from its once-applied source candidate; no replay.
  r.passes[#r.passes+1]={kind=p.kind,target='flow_'..p.target,textures=tx,values=cp(p.values),shader=p.shader,cacheKey=267100+({force=1,velocity=2,flux=3,gather=4,tiles=5,reduce=6,receipt=7})[p.kind]}
 end
 local function add(n,size,shader,tx,values,key)
  resource(n,{width=size[1],height=size[2],format='rgba32f'})
  r.passes[#r.passes+1]={kind=n,target=n,shader=shader,textures=tx,values=values,cacheKey=key}
 end
 local tiles=math.ceil(count/16);local checked='headCheck0'
 add(checked,{tiles,1},M.headCheck,{txState='newState',txMeta='newMeta',txHeads=root('heads'),txOldMeta='oldMeta',txOldHeads='source12',txOldState='oldState'},{gCount=count,gTiles=tiles},267005)
 local level=0
 while tiles>1 do local nextSize=math.ceil(tiles/16);local target='headCheck'..(level+1)
  add(target,{nextSize,1},M.reduceHeads,{txInput=checked},{gInput=tiles,gOutput=nextSize},267006);tiles=nextSize;checked=target;level=level+1
 end
 add('jointLedger',{1,8},M.ledger,{txSourceLedger=root('cumulativeLedger'),txFlowLedger='flow_'..flow.ledger},{},267001)
 add('jointReceipt',{4,1},M.receipt,{txSourceDecision=root('decision'),txSourceHeader='source9',txSourceCheckpoint=root('sourceCheckpoint'),txHeadHeader='source3',txPhysics='physics',txHeadCheck=checked,txFlowReceipt='flow_'..flow.receipt,txJointLedger='jointLedger',txPriorReceipt='priorReceipt'},
  {gDt=dt,gSerial=serial,gHasPrior=serial>1 and 1 or 0},267002)
 add('candidateCheckpoint',{1,2},M.checkpoint,{txSource='source9'},{},267003)
 local list={{'film',{w,h},'flow_state','source5'},{'micro',{w,h},root('micro'),'source6'},{'heads',{count,1},root('heads'),'source12'},
  {'ledger',{1,8},'jointLedger','source10'},{'checkpoint',{1,2},'candidateCheckpoint','source11'},
  {'state',{count,1},'newState','oldState'},{'meta',{count,1},'newMeta','oldMeta'}}
 for _,v in ipairs(list)do add('committed_'..v[1],v[2],M.select,{txReceipt='jointReceipt',txCandidate=v[3],txOld=v[4]},{gSize=v[2],gSerial=serial},267004);r.roots[v[1]]='committed_'..v[1]end
 -- The selector point-loads only H End rows of the compact 4H candidate.
 r.roots.receipt='jointReceipt';r.roots.sourceDecision=root('decision')
 r.ownedBytes=0;r.importBytes=0;for _,d in pairs(r.resources)do local bytes=d.width*d.height*(d.format=='r32f'and 4 or 16);if d.imported then r.importBytes=r.importBytes+bytes else r.ownedBytes=r.ownedBytes+bytes end end
 return r
end
function M.compile(Core,source,packet,w,h,count)
 -- Build fixed plans once, never rebuild source graphs in a frame callback.
 local templates={};for _,v in ipairs({{4,.01},{8,.025},{16,.04}})do templates[v[1]]=M.recipe(Core,source,packet,w,h,count,v[2],1)end
 local first=templates[4];local api={resources=first.resources,roots=first.roots,imports=first.imports,ownedBytes=first.ownedBytes,importBytes=first.importBytes}
 function api:bind(dt,serial)
  assert(type(dt)=='number'and dt==dt and dt>0 and dt<=.05,'bounded input dt')
  assert(type(serial)=='number'and serial==math.floor(serial)and serial>=1 and serial<=1048575,'interval identity')
  local n=dt<=1/60 and 4 or dt<=1/30 and 8 or 16;local t=templates[n];local passes={};local receipt=serial%2==1 and'flow_receiptA'or'flow_receiptB'
  for i,p in ipairs(t.passes)do
   local q={kind=p.kind,target=p.target,shader=p.shader,cacheKey=p.cacheKey,textures=cp(p.textures),values=cp(p.values)}
   if q.kind=='force'then q.values.gDt=dt/n end
   if q.kind=='flux'then q.values.gDt=dt/n end
   if q.kind=='receipt'then q.target=receipt;q.values.gDt=dt;q.values.gToken={264,1,serial,1};q.values.gPrevious={264,1,serial-1,1}end
   if q.kind=='jointReceipt'then q.textures.txFlowReceipt=receipt;q.values.gDt=dt;q.values.gHasPrior=serial>1 and 1 or 0 end
   if q.values.gSerial then q.values.gSerial=serial end
   passes[i]=q
  end
  return{resources=api.resources,roots=api.roots,imports=api.imports,passes=passes,ownedBytes=api.ownedBytes,importBytes=api.importBytes,scope=t.scope}
 end
 return api
end
return M
