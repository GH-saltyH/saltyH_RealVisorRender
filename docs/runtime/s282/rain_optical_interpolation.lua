-- Delayed display interpolation. Solver time/stock remain untouched.
-- Paired immutable optical snapshots, same fraction for head and film.
local M={}
M.copy=[[
float4 main(PS_IN pin){return txInput.Load(int3(min((int2)(pin.Tex*float2(gWidth,gHeight)),int2(gWidth-1,gHeight-1)),0));}
]]
M.phase=[[
float opticalFraction(){
 float4 a=txOldSelection.Load(int3(0,0,0)),b=txSelection.Load(int3(0,0,0));
 float span=b.w-a.w;
 if(gHistory<.5||a.z!=1||b.z!=1||b.y<=a.y||b.y-a.y>4||span<=0||!isfinite(span))return 1;
 return saturate(gAge/span);
}
]]
M.head=M.phase..[[
bool alive(float4 m){return all(isfinite(m))&&m.g>0&&m.a-4*floor(m.a*.25)==1;}
void displayHead(uint i,out float4 s,out float4 m){
 float4 a=txOldState.Load(int3(i,0,0)),b=txState.Load(int3(i,0,0));
 float4 am=txOldMeta.Load(int3(i,0,0)),bm=txMeta.Load(int3(i,0,0));
 float t=opticalFraction();bool av=alive(am),bv=alive(bm);s=b;m=bm;
 if(t>=1)return;
 if(av&&bv&&floor(am.a*.25)==floor(bm.a*.25)){
  s=lerp(a,b,t);m.gb=lerp(am.gb,bm.gb,t);
  float2 uv=float2(s.x,s.y+1);uint w,h;txBoundary.GetDimensions(w,h);
  int2 p=clamp((int2)(uv*float2(w,h)),int2(0,0),int2(w-1,h-1));
  if(any(uv<0)||any(uv>1)||txBoundary.Load(int3(p,0)).a<.5)s=t<.5?a:b;
 }else if(!av&&bv){m.g=bm.g*t;}
 else if(av&&!bv){s=a;m=am;m.g=am.g*(1-t);}
 // Never connect two different generations occupying the same slot.
 if(m.g>0){float q=tan(clamp(gTheta,.1,179.9)*.00872664625997165);
  m.r=pow(m.g*1.90985931710274/(q*(3+q*q)),1.0/3.0)*gReferencePerMM;
 }else{m=0;s=0;}
}
]]
M.state=M.head..[[float4 main(PS_IN pin){uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1);float4 s,m;displayHead(i,s,m);return s;}]]
M.meta=M.head..[[float4 main(PS_IN pin){uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1);float4 s,m;displayHead(i,s,m);return m;}]]
M.film=M.phase..[[
float4 main(PS_IN pin){int2 p=min((int2)(pin.Tex*float2(gWidth,gHeight)),int2(gWidth-1,gHeight-1));
 return lerp(txOldFilm.Load(int3(p,0)),txFilm.Load(int3(p,0)),opticalFraction());}
]]
function M.new(d,v,selection,state,meta,film,width,height)
 local resources,bytes=0,0;local function make(w,h)
  resources=resources+1;bytes=bytes+w*h*16;return d.backend.create({width=w,height=h,format='rgba32f'},286,resources)
 end
 local oldSel,oldState,oldMeta,oldFilm=make(1,1),make(v.headCount,1),make(v.headCount,1),make(width,height)
 local outState,outMeta,outFilm=make(v.headCount,1),make(v.headCount,1),make(width,height)
 local function packet(body,tx,values,key)
  local vs={};for k,x in pairs(values)do vs[k]=d.backend.make('number',x)end
  return{async=true,directValuesExchange=false,blendMode=d.backend.opaque,cacheKey=key,shader=body,textures=tx,values=vs,defines={}}
 end
 local copies={};for _,r in ipairs({{oldSel,selection,1,1},{oldState,state,v.headCount,1},{oldMeta,meta,v.headCount,1},{oldFilm,film,width,height}})do
  copies[#copies+1]={r[1],packet(M.copy,{txInput=r[2]},{gWidth=r[3],gHeight=r[4]},286104)}
 end
 local tx={txOldSelection=oldSel,txSelection=selection,txOldState=oldState,txState=state,txOldMeta=oldMeta,txMeta=meta,txBoundary=v.boundary}
 local function values()return{gAge=0,gHistory=0,gCount=v.headCount,gTheta=d.theta,gReferencePerMM=d.referencePerMM}end
 local statePass=packet(M.state,tx,values(),286101);local metaPass=packet(M.meta,tx,values(),286102)
 local filmPass=packet(M.film,{txOldSelection=oldSel,txSelection=selection,txOldFilm=oldFilm,txFilm=film},{gAge=0,gHistory=0,gWidth=width,gHeight=height},286103)
 local passes={{outState,statePass},{outMeta,metaPass},{outFilm,filmPass}}
 local age,span,lastSerial=0,1/32,nil;local history=false;local compiled=false;local useCurrent=true;local captures,draws=0,0
 local api={}
 function api:advance(dt)if type(dt)=='number'and dt==dt and dt>0 then age=age+dt end end
 function api:capture()
  for _,p in ipairs(copies)do if not d.backend.draw(p[1],p[2])then return false end end
  captures=captures+1;return true
 end
 function api:published(serial)
  if lastSerial and serial~=lastSerial then
   history=true;age=math.max(0,age-span);span=math.max(1/32,math.min((serial-lastSerial)/32,.125))
  elseif not lastSerial then age=0 end
  lastSerial=serial
 end
 function api:resolve()
  if compiled and(not history or age>=span)then useCurrent=true;return true end
  for _,p in ipairs(passes)do p[2].values.gAge=d.backend.make('number',age);p[2].values.gHistory=d.backend.make('number',history and 1 or 0)
   if not d.backend.draw(p[1],p[2])then return false end;draws=draws+1
  end
  compiled=true;useCurrent=not history;return true
 end
 function api:result()return{state=useCurrent and state or outState,meta=useCurrent and meta or outMeta,film=useCurrent and film or outFilm}end
 function api:status()return{resources=resources,descriptorBytes=bytes,archiveDraws=4,renderDraws=3,age=age,span=span,
  captures=captures,draws=draws,readbacks=0,history=history,delayed=true,physicsChanged=false}end
 return api
end
return M
