-- Read-only optical snapshots. All passes execute together after the solver pump.
-- Receipt copy is the LAST write of each bank transaction. The older receipt
-- therefore cannot select a bank whose roots are currently being overwritten.
local M={}
M.select=[[
float4 main(PS_IN pin){
 float4 a=txReceiptA.Load(int3(0,0,0)),b=txReceiptB.Load(int3(0,0,0));
 bool va=all(isfinite(a))&&a.x==267&&a.y==1&&a.z>=1&&a.z<=1048575&&floor(a.z)==a.z&&(a.w==0||a.w==1);
 bool vb=all(isfinite(b))&&b.x==267&&b.y==1&&b.z>=1&&b.z<=1048575&&floor(b.z)==b.z&&(b.w==0||b.w==1);
 float4 result=0;
 if(va&&(!vb||a.z>b.z))result=float4(1,a.z,a.w,txReceiptA.Load(int3(1,0,0)).y);
 else if(vb)result=float4(2,b.z,b.w,txReceiptB.Load(int3(1,0,0)).y);
 return result;
}
]]
M.head=[[
float4 main(PS_IN pin){
 float4 choice=txSelection.Load(int3(0,0,0));float4 result=0;
 uint i=min((uint)(pin.Tex.x*gCount),(uint)gCount-1);
 if(choice.z==1){
  float4 value=choice.x==1?txInputA.Load(int3(i,0,0)):txInputB.Load(int3(i,0,0));
  if(all(isfinite(value))){
   result=value;
   if(gMeta==1){
    // Radius is derived for display from canonical mm3, never decoded from R.
    float t=tan(clamp(gTheta,.1,179.9)*.00872664625997165);
    result.r=pow(max(value.g,0)*1.90985931710274/(t*(3+t*t)),1.0/3.0)*gReferencePerMM;
   }
  }
 }
 return result;
}
]]
M.film=[[
float4 main(PS_IN pin){
 int2 p=min((int2)(pin.Tex*float2(1024,256)),int2(1023,255));
 float4 choice=txSelection.Load(int3(0,0,0));float4 result=0;
 float area=txAreas.Load(int3(p,0)).r;
 if(choice.z==1&&isfinite(area)&&area>0){
  float f=choice.x==1?txFilmA.Load(int3(p,0)).r:txFilmB.Load(int3(p,0)).r;
  float m=choice.x==1?txMicroA.Load(int3(p,0)).r:txMicroB.Load(int3(p,0)).r;
  if(isfinite(f)&&isfinite(m))result=float4(min(max(float2(f,m),0)*1000/area,60000),0,0);
 }
 return result;
}
]]
function M.new(d)
 local input,selection,state,meta,film;local detail,temporal;local passes;local lastFrame;local ready=false;local errorText;local lastSubmitted,lastGain;local rebuilds,reuses=0,0
 local archived=false;local publicationPending=false
 local function make(desc,id)return d.backend.create(desc,282,id)end
 local function packet(shader,tx,values,key)
  local v={};for k,x in pairs(values or{})do v[k]=d.backend.make(type(x)=='table'and'vec4'or'number',x)end
  return{async=true,directValuesExchange=false,blendMode=d.backend.opaque,cacheKey=key,shader=shader,textures=tx,values=v,defines={}}
 end
 local api={}
 function api:resolve(owner,frame,dt)
  if lastFrame==frame then return ready end;lastFrame=frame
  local v=owner:visualInputs();if not v then ready=false;return false end
  local gain=d.displayGain and d.displayGain()or .31748021039364
  if temporal then temporal:advance(dt)end
  if ready and v.submittedSerial and v.submittedSerial==lastSubmitted and gain==lastGain then
   reuses=reuses+1;ready=not temporal or temporal:resolve();return ready
  end
  if ready and temporal and not archived then
   if not temporal:capture()then errorText='Optical history shaders preparing';ready=false;return false end
   archived=true
  end
  ready=false
  assert(v.scope=='owned_gpu_commit_pair_v1'and v.retainedUntilSessionEnd,'owned optical lease')
  if not input then
   input=v;selection=make({width=1,height=1,format='rgba32f'},1)
   state=make({width=v.headCount,height=1,format='rgba32f'},2);meta=make({width=v.headCount,height=1,format='rgba32f'},3)
   film=make({width=1024,height=256,format='rgba32f'},4)
   local hv={gCount=v.headCount,gMeta=0,gTheta=d.theta,gReferencePerMM=d.referencePerMM}
   local mv={gCount=v.headCount,gMeta=1,gTheta=d.theta,gReferencePerMM=d.referencePerMM}
   passes={
    {selection,packet(M.select,{txReceiptA=v.A.receipt,txReceiptB=v.B.receipt},{},282001)},
    {state,packet(M.head,{txSelection=selection,txInputA=v.A.state,txInputB=v.B.state},hv,282002)},
    {meta,packet(M.head,{txSelection=selection,txInputA=v.A.meta,txInputB=v.B.meta},mv,282003)},
    {film,packet(M.film,{txSelection=selection,txFilmA=v.A.film,txFilmB=v.B.film,txMicroA=v.A.micro,txMicroB=v.B.micro,txAreas=v.areas},{},282004)}}
   if v.trails then
    assert(d.folder,'fine optical sources folder')
    local f=assert(io.open(d.folder..'/shaders/rainTrailLine.hlsl','rb'));local line=f:read('*a');f:close()
    local module=dofile(d.folder..'/docs/runtime/s282/rain_trail_optics.lua')
    detail=module.new({backend=d.backend,line=line,displayGain=d.displayGain},v,selection,film)
   end
   if v.boundary then
    local module=dofile(d.folder..'/docs/runtime/s282/rain_optical_interpolation.lua')
    temporal=module.new(d,v,selection,state,meta,detail and detail:result()or film,detail and 4096 or 1024,detail and 1024 or 256)
   end
  end
  if not publicationPending then
   -- Retry archive before any current snapshot writes, including async startup.
   if temporal and lastSubmitted and not archived then
    if not temporal:capture()then errorText='Optical history shaders preparing';return false end;archived=true
   end
  for _,p in ipairs(passes)do if not d.backend.draw(p[1],p[2])then errorText='Optical shaders preparing';return false end end
  if detail and not detail:resolve()then errorText='Fine trail optical shaders preparing';return false end
   if temporal then
    if not lastSubmitted and not temporal:capture()then errorText='Optical history shaders preparing';return false end
    temporal:published(v.submittedSerial)
   end
   lastSubmitted=v.submittedSerial;lastGain=gain;publicationPending=true
  end
  if temporal and not temporal:resolve()then errorText='Optical interpolation shaders preparing';return false end
  publicationPending=false;archived=false
  errorText=nil;ready=true;rebuilds=rebuilds+1;return true
 end
 function api:result()if ready then local t=temporal and temporal:result();return{state=t and t.state or state,meta=t and t.meta or meta,film=t and t.film or(detail and detail:result()or film),count=input.headCount,scope='committed_optical_snapshot_v1',fineTrail=detail~=nil}end end
 function api:status()local s=detail and detail:status();local t=temporal and temporal:status();return{ready=ready,error=errorText,resources=(passes and 4 or 0)+(s and s.resources or 0)+(t and t.resources or 0),fineTrail=s,interpolation=t,rebuilds=rebuilds,reuses=reuses,readonly=true,readbacks=0,physicsGainUsed=false}end
 return api
end
return M
