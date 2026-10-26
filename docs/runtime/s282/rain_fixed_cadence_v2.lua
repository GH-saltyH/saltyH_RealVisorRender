-- Product scheduler: integrate declared rates, not arbitrary shader-header rows.
-- No CSP/GPU dependency. A runtime adapter must supply physically valid rates.
local M={};local Q=1048576
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function cp(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=cp(v)end;return r end
local function equal(a,b)
 if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not equal(v,b[k])then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function add(a,k,v)local y=v-(a.error[k]or 0);local n=(a.sum[k]or 0)+y;a.error[k]=(n-(a.sum[k]or 0))-y;a.sum[k]=n end
local function accumulator()return{sum={},error={}}end
local function pose(p)
 assert(type(p)=='table'and #p==4,'four pose rows')
 for _,row in ipairs(p)do assert(type(row)=='table'and #row==4,'four pose components');for _,v in ipairs(row)do assert(finite(v),'finite pose')end end
 assert(p[1][4]==0 and p[2][4]==0 and p[3][4]==0 and p[4][4]==1,'affine pose')
 local function dot(a,b)return a[1]*b[1]+a[2]*b[2]+a[3]*b[3]end
 local scale=dot(p[1],p[1]);assert(finite(scale)and scale>0,'nondegenerate rigid pose')
 local tolerance=math.max(scale*64*2^-23,1e-12)
 assert(math.abs(dot(p[2],p[2])-scale)<=tolerance and math.abs(dot(p[3],p[3])-scale)<=tolerance,'uniform pose scale')
 assert(math.abs(dot(p[1],p[2]))<=tolerance and math.abs(dot(p[1],p[3]))<=tolerance and math.abs(dot(p[2],p[3]))<=tolerance,'orthogonal pose basis')
 -- Do not average or normalize a rigid basis here; the adapter owns interpolation.
end
function M.new(options)
 local o=cp(options);assert(type(o)=='table','cadence options')
 local hz=o.hz or 32;local cap=o.capacity or 16;local debt=o.maxDebtSeconds or .5
 assert(hz==math.floor(hz)and hz>=21 and hz<=120,'bounded simulation frequency')
 assert(cap==math.floor(cap)and cap>=1 and cap<=16 and finite(debt)and debt>0 and debt<=.5,'bounded pending work')
 assert(type(o.epoch)=='number'and o.epoch>=1 and o.epoch<=1048575 and o.epoch==math.floor(o.epoch),'epoch')
 assert(type(o.channels)=='table'and #o.channels>=1 and #o.channels<=32,'declared rate channels')
 local schema={};for _,v in ipairs(o.channels)do
  assert(type(v.key)=='string'and #v.key>0 and not schema[v.key]and type(v.rateUnit)=='string'and #v.rateUnit>0 and type(v.integralUnit)=='string'and #v.integralUnit>0,'rate channel units')
  schema[v.key]=v
 end
 local weightKey=o.snapshotWeightChannel;if weightKey then assert(schema[weightKey]and schema[weightKey].nonnegative,'nonnegative source weight channel')end
 local weightedSnapshot,weightSum,randomState=nil,0,nil
 local phase='open';local geometry,material,calibration,lastFrame;local timeline=accumulator();local received=accumulator();local accepted=accumulator()
 local slots={};local partial=accumulator();local firstPose,lastPose,firstFrame,endFrame,contributors;local selectedSnapshot,lastSnapshot
 local emitted=0;local endTick=0;local emittedRaw=0;local auditedTick,submittedTick=0,0;local active;local samples=0;local peak=0;local reason
 local function deadline(index)return math.floor(index*Q/hz+.5)end
 local function seal(ticks,rawFinish,tail)
  assert(ticks>endTick and ticks-endTick<=52428,'bounded solver interval')
  emitted=emitted+1
  local r={epoch=o.epoch,serial=emitted,startTick=endTick,endTick=ticks,seconds=(ticks-endTick)/Q,
   rawSeconds=partial.sum.seconds or 0,integrals=cp(partial.sum),poseBegin=firstPose,poseEnd=lastPose,
   firstFrame=firstFrame,lastFrame=endFrame,contributors=contributors,geometryKey=geometry,materialKey=material,calibrationKey=calibration,
   channelUnits=cp(o.channels),
   sourceSnapshot=weightedSnapshot,snapshotWeight=weightSum,
   snapshot=tail and lastSnapshot or selectedSnapshot,snapshotRule=tail and 'partial_end_snapshot'or'midpoint_coherent_snapshot',
   posePolicy='rigid_interpolation_required',physicalUnitsDeclared=true}
  r.integrals.seconds=nil;slots[#slots+1]={step=r,submitted=false};peak=math.max(peak,#slots);endTick=ticks;emittedRaw=rawFinish
  partial=accumulator();weightedSnapshot=nil;weightSum=0;randomState=nil;selectedSnapshot=nil;lastSnapshot=nil;firstPose=nil;lastPose=nil;firstFrame=nil;endFrame=nil;contributors=0
 end
 local function endpoint(s,f)return{from=cp(s.poseStart),to=cp(s.poseEnd),fraction=math.max(0,math.min(1,f))}end
 local api={}
 function api:offer(s)
  if phase~='open'then return false,phase end
  local ok,after,correction=pcall(function()
   assert(type(s)=='table'and s.epoch==o.epoch,'epoch reset required')
   assert(finite(s.frame)and s.frame==math.floor(s.frame)and s.frame>=1 and s.frame<=16777215,'source frame')
   assert(finite(s.rawDt)and s.rawDt>=0 and s.rawDt<=.25,'source dt')
   if lastFrame then assert(s.frame==lastFrame+1 or(s.frame==lastFrame and s.rawDt==0),'frame gap/duplicate requires reset')end
   if s.rawDt==0 then return false end
   assert(type(s.geometryKey)=='string'and type(s.materialKey)=='string'and type(s.calibrationKey)=='string','physical identities')
   assert(not geometry or(s.geometryKey==geometry and s.materialKey==material and s.calibrationKey==calibration),'physical identity reset required')
   pose(s.poseStart);pose(s.poseEnd);assert(type(s.rates)=='table','rates')
   for k in pairs(s.rates)do assert(schema[k],'undeclared rate')end
   for k,v in pairs(schema)do assert(finite(s.rates[k])and math.abs(s.rates[k])<=3.402823466e38 and(not v.nonnegative or s.rates[k]>=0),'finite signed/nonnegative rate: '..k)end
   local before=timeline.sum.seconds or 0;local y=s.rawDt-(timeline.error.seconds or 0);local finish=before+y
   assert(finish>before and finish*Q<2^40,'timeline precision/bound')
   local n=emitted+1;local count=0;while n/hz<=finish do count=count+1;n=n+1;assert(count<=cap,'entry_capacity')end
   assert(#slots+count<=cap,'entry_capacity');assert(finish-auditedTick/Q<=debt,'time_capacity')
   return finish,(finish-before)-y
  end)
  if not ok then reason=tostring(after);return false,reason end
  if after==false then lastFrame=s.frame;return true,'paused'end
  local before=timeline.sum.seconds or 0;timeline.sum.seconds=after;timeline.error.seconds=correction
  geometry=geometry or s.geometryKey;material=material or s.materialKey;calibration=calibration or s.calibrationKey
  for k in pairs(schema)do add(received,k,s.rates[k]*s.rawDt)end
  local at=before;local snapshot=s.snapshot and cp(s.snapshot)
  while at<after do
   local boundary=(emitted+1)/hz;local finish=math.min(after,boundary);local seconds=finish-at
   assert(seconds>0,'cadence progress')
   local midpoint=(emitted+.5)/hz
   if at<=midpoint and finish>=midpoint and not selectedSnapshot then selectedSnapshot=snapshot end
   lastSnapshot=snapshot
   if weightKey then
    local weight=s.rates[weightKey]*seconds
    if weight>0 then
     weightSum=weightSum+weight;randomState=randomState or((o.epoch*104729+(emitted+1)*8191)%2147483647)
     if randomState==0 then randomState=1 end;randomState=(randomState*48271)%2147483647
     if not weightedSnapshot or randomState/2147483647<weight/weightSum then weightedSnapshot=snapshot end
    end
   end
   firstPose=firstPose or endpoint(s,(at-before)/(after-before));lastPose=endpoint(s,(finish-before)/(after-before))
   firstFrame=firstFrame or s.frame;endFrame=s.frame;contributors=(contributors or 0)+1
   add(partial,'seconds',seconds);for k in pairs(schema)do add(partial,k,s.rates[k]*seconds)end
   at=finish;if finish==boundary then seal(deadline(emitted+1),finish)end
  end
  samples=samples+1;lastFrame=s.frame;reason=nil;return true,'integrated'
 end
 function api:reserve()
  if active then return nil,'busy'end;if phase=='failed'then return nil,reason end
  for _,slot in ipairs(slots)do if not slot.submitted then active=slot;return cp(slot.step)end end
  return nil,'empty'
 end
 function api:submitted(ticket)
  assert(active and equal(active.step,ticket),'owned unmodified reservation')
  assert(ticket.startTick==submittedTick,'ordered submission');submittedTick=ticket.endTick;active.submitted=true;active=nil
 end
 function api:acknowledge(ticket,good)
  assert(phase~='failed'and type(good)=='boolean','accepted prefix only')
  local slot=slots[1];assert(slot and slot.submitted and equal(slot.step,ticket),'ordered exact audit')
  if not good then phase='failed';reason='GPU refusal; elapsed time and input integrals retained';return end
  assert(ticket.startTick==auditedTick,'ordered physical time');auditedTick=ticket.endTick
  for k,v in pairs(ticket.integrals)do add(accepted,k,v)end;table.remove(slots,1)
 end
 function api:close()
  if phase~='open'then return false,phase end
  local raw=timeline.sum.seconds or 0;local tick=math.floor(raw*Q+.5)
  if firstPose and tick>endTick then
   if #slots>=cap then return false,'entry_capacity'end
   seal(tick,raw,true)
  end
  phase='closed';return true
 end
 function api:resumeFrame(frame)
  assert(phase=='open'and not active and #slots==0,'drain captured work before explicit resume')
  assert(finite(frame)and frame==math.floor(frame)and(not lastFrame or frame>=lastFrame),'resume source frame')
  -- Explicit model pause: preserve partial integrals/ticks; only frame identity
  -- is re-primed. Unobserved background frames do not become simulated time.
  lastFrame=frame
 end
 function api:status()
  local raw=timeline.sum.seconds or 0;local queued={};for k in pairs(schema)do queued[k]=0 end
  for _,slot in ipairs(slots)do for k,v in pairs(slot.step.integrals)do queued[k]=queued[k]+v end end
  return{phase=phase,error=reason,hz=hz,capacity=cap,rawSeconds=raw,auditedSeconds=auditedTick/Q,
   submittedSeconds=submittedTick/Q,queuedSeconds=(endTick-auditedTick)/Q,unsealedSeconds=raw-emittedRaw,
   quantizationRemainderSeconds=emittedRaw-endTick/Q,
   retainedDebtSeconds=(endTick-auditedTick)/Q+(firstPose and(partial.sum.seconds or 0)or 0),heldSteps=#slots,peakSteps=peak,active=active~=nil,samples=samples,
   emitted=emitted,receivedIntegrals=cp(received.sum),acceptedIntegrals=cp(accepted.sum),queuedIntegrals=queued,
   partialIntegrals=cp(partial.sum),subtickRetained=firstPose~=nil,
   drained=phase=='closed'and #slots==0 and not firstPose,publicClockAdvanced=false,GPUAllocated=false}
 end
 return api
end
return M
