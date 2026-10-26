-- Fixed32Hz private owner. Host supplies the existing owned GPU graph/backend.
-- No public texture publication until the optical consumer has a commit contract.
local M={}
local function cp(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=cp(v)end;return r end
function M.new(d)
 local wallClock=d.clock;local pausedAt;local pausedWall=0;local lastActiveWall
 d.clock=function()return(pausedAt or wallClock())-pausedWall end
 local engine=d.Executor.new({backend=d.backend,clock=d.clock,snapshot=d.snapshot},d.graph)
 local phase='idle';local errorText;local capture,adapter;local jobs={};local submitting;local start;local lastWords
 local rejected;local maxPumpMS=0;local firstRefused;local closePending=false
 local lastWeather
 local previousPhase;local needsCapture=false;local rebasePending=false;local retiredCaptureRaw=0;local pauseCycles=0;local captureRestarts=0
 local excludedRaw,excludedFrames,lastExcludedFrame,lastCapturedFrame=0,0,nil,nil
 local function exclude(sim)
  if not sim or sim.frame==lastExcludedFrame or sim.frame==lastCapturedFrame then return end
  lastExcludedFrame=sim.frame;excludedFrames=excludedFrames+1
  if type(sim.dt)=='number'and sim.dt==sim.dt and sim.dt>=0 and sim.dt<=.25 then excludedRaw=excludedRaw+sim.dt end
 end
 local function archiveCapture()
  if capture then retiredCaptureRaw=retiredCaptureRaw+(capture:status().rawSeconds or 0);capture:stop();capture=nil end
 end
 -- Capture continues while a full cadence waits for ordinary audit retirement.
 -- Hold immutable engine frames briefly; never merge/drop their time or inputs.
 local staged={};local stagedSeconds=0;local peakStaged=0;local peakStagedSeconds=0
 local capacityRetries,recoveredFrames=0,0;local lastCapacityReason
 local function pressure(e)return type(e)=='string'and(e:match('entry_capacity$')or e:match('time_capacity$'))end
 local function recount()stagedSeconds=0;for _,c in ipairs(staged)do stagedSeconds=stagedSeconds+c.rawDt end end
 local function defer(c,e)
  if #staged>=16 or stagedSeconds+c.rawDt>.5+1e-12 then
   rejected=c;capture:stop();errorText='capture staging capacity; '..tostring(e);phase='overloaded';return false
  end
  staged[#staged+1]=c;recount();peakStaged=math.max(peakStaged,#staged);peakStagedSeconds=math.max(peakStagedSeconds,stagedSeconds);return true
 end
 local function retryStaged()
  if not adapter then return end
  while #staged>0 do
   local ok,e=adapter:offer(staged[1])
   if not ok then
    if pressure(e)then capacityRetries=capacityRetries+1;lastCapacityReason=e;return end
    error(e)
   end
   table.remove(staged,1);recount();recoveredFrames=recoveredFrames+1
  end
 end
 local function fail(why)
  errorText=tostring(why);phase='fault';engine:cancel();if capture then capture:stop()end
 end
 local function lease(c)
  local released=false;return{context=c,textures=d.files,descriptors=d.fileDescriptors,valid=function()return not released end,
   release=function()assert(not released,'once-only input retirement');released=true end}
 end
 local function retire()
  for _=1,32 do
   local result=engine:take();if not result then break end;lastWords=cp(result.words)
   if phase=='warming'then
    assert(result.accepted,'warmup refused');engine:resetWarmup();capture=d.createCapture();assert(capture:start());phase='starting_inputs';lastWords=nil
   else
    local ticket=assert(jobs[result.serial],'owned fixed work');jobs[result.serial]=nil
    adapter.cadence:acknowledge(ticket,result.accepted)
    if not result.accepted then firstRefused=result;fail('GPU refusal; fixed work and source retained');break end
   end
  end
 end
 local api={}
 function api:start()assert(phase=='idle','one runtime epoch');start=d.clock();lastActiveWall=wallClock();phase='preparing'end
 function api:pump()
  if phase=='idle'or phase=='fault'or phase=='stopped'or phase=='stopped_with_subtick'or phase=='cancelled'then return end
  local sim=d.api and d.api.getSim and d.api.getSim()
  if sim and sim.isWindowForeground==false then
   if not pausedAt then
    pausedAt=lastActiveWall or wallClock();previousPhase=phase;pauseCycles=pauseCycles+1
    needsCapture=phase=='running'or phase=='starting_inputs'or phase=='repriming'or phase=='resuming'
    if needsCapture then archiveCapture()end
    phase='background_paused'
   end
   exclude(sim);return
  elseif pausedAt then
   pausedWall=pausedWall+wallClock()-pausedAt;pausedAt=nil
   phase=needsCapture and'resuming'or previousPhase;previousPhase=nil
  end
  local at=d.clock();local ok,why=pcall(function()
   if phase=='preparing'or phase=='warming'then assert(at-start<60,'bounded startup')end
   if phase=='preparing'then
    local ready,e=engine:prepare();assert(ready~=false,e)
    if ready then local c=d.warmup(d.seed);assert(engine:submit(c.rows[2][3],lease(c)));phase='warming'end
    return
   end
   retire();local state=engine:status();assert(not state.fault,state.fault)
   if phase=='fault'then return end
   if phase=='starting_inputs'or phase=='running'or phase=='repriming'then
    retryStaged()
    local reprime=phase=='repriming'
    local sample=capture:tick();local cs=capture:status()
    if not sample and reprime then exclude(sim)end
    assert(cs.phase~='fault'and cs.phase~='reset_required',cs.error)
    if capture:reference()and(not adapter or rebasePending)then
     if adapter then adapter:resume(capture:reference())else adapter=d.Input.new(d,d.seed,capture:reference())end
     rebasePending=false;needsCapture=false;phase='running'
    end
    if sample then
     lastCapturedFrame=sample.frame
     if sample.environment then
      local e=sample.environment
      lastWeather={frame=sample.frame,rain=e.intensity,liquid=e.liquidIntensity,wetness=e.trackWetness,water=e.trackWater,
       humidity=e.humidity,temperature=e.temperatureC,windMS=math.sqrt(e.windX^2+e.windY^2+e.windZ^2),
       density=sample.rows[5][1],evapUMS=sample.rows[27][1]}
     end
     assert(adapter,'primed actual input reference')
     if #staged>0 then defer(sample,lastCapacityReason)
     else
      local accepted,e=adapter:offer(sample)
      if not accepted then
       if pressure(e)then capacityRetries=capacityRetries+1;lastCapacityReason=e;defer(sample,e)
       else error(e)end
      end
     end
    end
   end
   if phase=='draining'or phase=='resuming'then retryStaged()end
   if phase=='resuming'then exclude(sim)end
   if closePending and adapter and #staged==0 then local closed,e=adapter.cadence:close();if closed then closePending=false elseif e~='entry_capacity'then error(e)end end
   local deadline=at+.003;local remaining=256
   for work=1,4 do
    if work>1 and(d.clock()>=deadline or remaining==0)then break end
    if(phase=='running'or phase=='draining'or phase=='resuming')and adapter and not submitting and engine:canSubmit()then
     local ticket,e=adapter.cadence:reserve()
     if ticket then
      local c=adapter:context(ticket);local accepted,id=engine:submit(c.rows[2][3],lease(c));assert(accepted,id)
      assert(id==ticket.serial,'fixed-step identity');jobs[id]=ticket;submitting=id
     else assert(e=='empty'or e=='busy',e)end
    end
    local spent=engine:pump(at,deadline,remaining);remaining=remaining-spent
    state=engine:status();assert(not state.fault,state.fault)
    if submitting and state.submitted>=submitting then adapter.cadence:submitted(assert(jobs[submitting]));submitting=nil end
    if state.active or not engine:canSubmit()or phase=='warming'or phase=='overloaded'then break end
   end
   retire();state=engine:status();assert(not state.fault,state.fault)
   if phase=='running'or phase=='draining'or phase=='resuming'then retryStaged()end
   if phase=='resuming'and #staged==0 and not state.active and state.pending==0 and(not adapter or adapter.cadence:status().heldSteps==0)then
    capture=d.createCapture();assert(capture:start());captureRestarts=captureRestarts+1;rebasePending=adapter~=nil;phase='repriming'
   end
   if adapter then
    local q=adapter.cadence:status();assert(math.abs(q.auditedSeconds-state.advancedSeconds)<1e-12,'audit/physical time agreement')
    if phase=='draining'and not closePending and not state.active and state.pending==0 and q.heldSteps==0 then phase=q.drained and'stopped'or'stopped_with_subtick'end
   end
  end)
  maxPumpMS=math.max(maxPumpMS,(d.clock()-at)*1000);lastActiveWall=wallClock();if not ok then fail(why)end
 end
 function api:stop()
  if phase=='background_paused'and adapter then previousPhase='draining';needsCapture=false;closePending=true
  elseif(phase=='running'or phase=='resuming'or phase=='repriming')and adapter then if capture then capture:stop()end;phase='draining';closePending=true
  elseif phase~='idle'and phase~='fault'and phase~='stopped'and phase~='stopped_with_subtick'then
   engine:cancel();if capture then capture:stop()end;phase='cancelled'
   if pausedAt then pausedWall=pausedWall+wallClock()-pausedAt;pausedAt=nil end
  end
 end
 function api:visualInputs()
  if phase~='running'and phase~='draining'and phase~='stopped'and phase~='stopped_with_subtick'and phase~='background_paused'and phase~='resuming'and phase~='repriming'then return nil end
  return engine:visualInputs()
 end
 function api:frozenFailureInputs()
  if phase~='fault'or not firstRefused then return nil end
  return engine:frozenFailureInputs(firstRefused.serial)
 end
 function api:status()
  local input=adapter and adapter:status();local debt=input and input.cadence.retainedDebtSeconds or 0
  local cs=capture and capture:status();if cs then cs.currentCaptureRawSeconds=cs.rawSeconds;cs.rawSeconds=retiredCaptureRaw+(cs.rawSeconds or 0)
  elseif retiredCaptureRaw>0 then cs={phase='suspended',rawSeconds=retiredCaptureRaw}end
  return{phase=phase,error=errorText,engine=engine:status(),input=input,capture=cs,capturedWeather=cp(lastWeather),
   background={paused=pausedAt~=nil,cycles=pauseCycles,captureRestarts=captureRestarts,excludedRawSeconds=excludedRaw,excludedFrames=excludedFrames,pausedWallSeconds=pausedWall+(pausedAt and wallClock()-pausedAt or 0),policy='freeze_model_reprime_current_pose'},
   staging={frames=#staged,seconds=stagedSeconds,peakFrames=peakStaged,peakSeconds=peakStagedSeconds,maxFrames=16,maxSeconds=.5,retries=capacityRetries,recoveredFrames=recoveredFrames,lastReason=lastCapacityReason},
   retainedTotalDebtSeconds=debt+stagedSeconds+(rejected and rejected.rawDt or 0),
   rejectedRawSeconds=rejected and rejected.rawDt or 0,lastWords=cp(lastWords),firstRefused=firstRefused,
   maxPumpMS=maxPumpMS,publicClockAdvanced=false,opticalPublication=false}
 end
 return api
end
return M
