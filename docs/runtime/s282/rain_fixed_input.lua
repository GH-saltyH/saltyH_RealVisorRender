-- Actual captured contexts -> owned fixed-step inputs. Nonlinear source terms
-- use a density-weighted coherent source and midpoint air; linear terms integrate.
local M={}
local function cp(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=cp(v)end;return r end
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local names={'inertiaX','inertiaY','inertiaZ','bodyX','bodyY','bodyZ','evaporation'}
function M.new(d,seed,initial)
 local reference=cp(seed);local units=reference.unitRows[1];local initial=initial or seed
 assert(reference.configuredScale>0 and reference.appliedScale>0,'physical scale provenance')
 local channels={};for _,key in ipairs(names)do channels[#channels+1]={key=key,rateUnit=key=='evaporation'and'um/s'or'm/s2',integralUnit=key=='evaporation'and'um'or'm/s',nonnegative=key=='evaporation'}end
 channels[#channels+1]={key='numberDensity',rateUnit='1/m3',integralUnit='s/m3',nonnegative=true}
 local cadence=d.Cadence.new({epoch=d.epoch or 1,hz=32,capacity=16,maxDebtSeconds=.5,channels=channels,snapshotWeightChannel='numberDensity'})
 local function aligned(c)
  assert(c.geometryKey==reference.geometryKey and c.materialKey==reference.materialKey,'geometry/material reset required')
  assert(c.configuredScale==reference.configuredScale and c.appliedScale==reference.appliedScale,'configured scale reset required')
  assert(c.rows[2][4]==reference.rows[2][4],'fixed head count')
  for j=1,4 do assert(c.rows[12][j]==reference.rows[12][j],'fixed field shape')end
  local u=c.unitRows[1];local epsilon=8*2^-23
  assert(u[2]==units[2]and u[3]>0 and math.abs(u[3]-units[3])<=math.max(u[3],units[3])*epsilon,'physical calibration change')
  assert(math.abs(u[1]*math.sqrt(u[3])*u[2]-.001)<=.001*epsilon,'inconsistent physical unit')
  assert(math.abs(u[4]/u[3]-units[4]/units[3])<=math.abs(units[4]/units[3])*epsilon,'physical area change')
  local p={};local factor=math.sqrt(units[3]/u[3]);for i=1,4 do p[i]=cp(c.rows[i+13]);if i<=3 then for j=1,3 do p[i][j]=p[i][j]*factor end end end
  -- Validate rigid pose and use its endpoints without averaging matrix entries.
  d.Pose.resolve({from=p,to=p,fraction=0});return p
 end
 local previousPose=aligned(initial);local offered=0
 local calibration=reference.geometryKey..':'..reference.materialKey
 for _,v in ipairs(units)do calibration=calibration..':'..d.Packet.hex32(v)end
 local api={cadence=cadence}
 function api:offer(c)
  if c.rawDt==0 then return cadence:offer({epoch=d.epoch or 1,frame=c.frame,rawDt=0})end
  local ok,s=pcall(function()
   assert(c.scope=='main_app_context_diagnostic_v1'and finite(c.rawDt)and c.rawDt>0 and c.rawDt<=.25,'coherent captured input')
   assert(type(c.contentKey)=='string'and #c.contentKey==64,'captured content identity')
   assert(c.rows[2][1]==d.Packet.f32(c.frame)and c.rows[43][3]==d.Packet.f32(c.rawDt),'captured frame/time provenance')
   local p=aligned(c);local rates={}
   for i=1,3 do rates[names[i]]=c.rows[20][i];rates[names[i+3]]=c.rows[36][i]end
   rates.evaporation=c.rows[27][1];rates.numberDensity=c.rows[5][1]
   return{epoch=d.epoch or 1,frame=c.frame,rawDt=c.rawDt,geometryKey=c.geometryKey,materialKey=c.materialKey,
    calibrationKey=calibration,rates=rates,poseStart=previousPose,poseEnd=p,snapshot=c}
  end)
  if not ok then return false,tostring(s)end
  local accepted,why=cadence:offer(s)
  if accepted then previousPose=s.poseEnd;offered=offered+1 end;return accepted,why
 end
 function api:context(ticket)
  assert(ticket.snapshot and(ticket.snapshotRule=='midpoint_coherent_snapshot'or ticket.snapshotRule=='partial_end_snapshot'),'coherent temporal source snapshot')
  local c=cp(ticket.snapshot);local f=d.Packet.f32;local token={234,1,ticket.serial,1};local previous={234,1,ticket.serial-1,1}
  local endPose=d.Pose.resolve(ticket.poseEnd);local dt=ticket.seconds;assert(dt>0 and dt<=.05,'solver dt')
  c.originalContentKey=c.contentKey;c.contentKey=nil;c.canonical=nil;c.poseKey=nil
  c.frame=ticket.lastFrame;c.frameAfter=ticket.lastFrame;c.rawDt=ticket.rawSeconds;c.representedDt=dt;c.token=cp(token)
  c.startTick=ticket.startTick;c.endTick=ticket.endTick;c.unitRows[1]=cp(units)
  for _,i in ipairs({1,19,29,35,40})do c.rows[i]=cp(token)end
  for _,i in ipairs({18,30})do c.rows[i]=cp(previous)end
  c.rows[2][1]=f(c.frame);c.rows[2][3]=dt;c.rows[32][4]=dt;c.rows[41][1]=dt
  c.rows[3]={math.floor(ticket.startTick/65536),ticket.startTick%65536,math.floor(ticket.endTick/65536),ticket.endTick%65536}
  for i=1,4 do c.rows[i+13]={};for j=1,4 do c.rows[i+13][j]=f(endPose[i][j])end end
  for i=1,3 do c.rows[20][i]=f(ticket.integrals[names[i]]/dt);c.rows[36][i]=f(ticket.integrals[names[i+3]]/dt)end
  local source=ticket.sourceSnapshot or ticket.snapshot
  c.rows[5][1]=f(ticket.integrals.numberDensity/dt);c.rows[6]=cp(source.rows[6]);c.rows[7]=cp(source.rows[7])
  local evap=f(ticket.integrals.evaporation/dt);c.rows[27][1]=evap;c.rows[38][3]=evap
  c.rows[5][2]=units[4];c.rows[43]={f(c.frame),c.rows[43][2],f(ticket.rawSeconds),f(ticket.rawSeconds-dt)};c.rows[50][1]=f(c.frame)
  local words={};for _,group in ipairs({c.rows,c.unitRows})do for _,row in ipairs(group)do for _,v in ipairs(row)do assert(f(v)==v,'finite FP32 context');words[#words+1]=d.Packet.hex32(v)end end end
  c.capturedContentKey=d.hashText('RealVisor/fixed-input/v1\n'..table.concat(words));assert(type(c.capturedContentKey)=='string'and #c.capturedContentKey==64,'derived header identity')
  c.captureScope='fixed_engine_interval_v1'
  c.limitations={'Density-weighted temporal source and midpoint-air approximation','Endpoint geometry; no exact spatial incident-time integral','No optical publication from this adapter'}
  c.sourceTickScope='fixed_cadence_physics_v1';c.fixedInterval={firstFrame=ticket.firstFrame,lastFrame=ticket.lastFrame,
   selectedFrame=ticket.snapshot.frame,sourceRule='density_time_weighted_source_sample',sourceFrame=source.frame,airRule=ticket.snapshotRule,nonlinearApproximation='density_weighted_source_and_midpoint_air_endpoint_geometry',rawSeconds=ticket.rawSeconds,modelSeconds=dt}
  return c
 end
 function api:resume(reference)
  local nextPose=aligned(reference)
  cadence:resumeFrame(reference.frame);previousPose=nextPose
 end
 function api:status()return{offered=offered,cadence=cadence:status(),nonlinearSourceApproximation='density_weighted_source_and_midpoint_air',GPUAllocated=false}end
 return api
end
return M
