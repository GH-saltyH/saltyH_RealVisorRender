-- Continuous admitted input -> compact GPU transaction -> ordered time settlement.
local M={};local Q=1048576
local function cp(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=cp(v)end;return r end
function M.warmup(seed)
 local c=cp(seed);local n=math.floor(c.rawDt*Q+.5);assert(n>0 and n<=52428,'warmup dt')
 c.capturedContentKey=c.contentKey;c.contentKey=nil;c.token={234,1,1,1};for _,i in ipairs({1,19,29,35,40})do c.rows[i]=cp(c.token)end
 for _,i in ipairs({18,30})do c.rows[i]={234,1,0,1}end
 c.rows[2][3]=n/Q;c.rows[32][4]=n/Q;c.rows[41][1]=n/Q;c.rows[3]={0,0,math.floor(n/65536),n%65536};return c
end
function M.new(d)
 local engine=d.Executor.new({backend=d.backend,clock=d.clock,snapshot=d.snapshot},d.graph)
 local phase='idle';local errorText;local stream,projection;local jobs={};local submitting;local start;local maxPump=0;local maxPrepare=0;local lastWords;local firstRefused;local warmup=false
 local maxAge,maxDebt,maxFrameLag=0,0,0
 local function fail(e)phase='fault';errorText=tostring(e);engine:cancel();if stream then stream:cancel()end end
 local function lease(c)
  local released=false;return{context=cp(c),textures=d.files,descriptors=d.fileDescriptors,valid=function()return not released end,release=function()assert(not released,'once-only input retirement');released=true end}
 end
 local api={}
 function api:start()assert(phase=='idle','one run');start=d.clock();phase='preparing'end
 function api:pump()
  if phase=='idle'or phase=='observed'or phase=='stopped'or phase=='fault'or phase=='cancelled'then return end
  local at=d.clock();local measured=phase~='preparing'and phase~='warming'
  local ok,e=pcall(function()
   assert(at-start<60,'bounded session')
   if phase=='preparing'then
    local ready,why=engine:prepare();assert(ready~=false,why);maxPrepare=math.max(maxPrepare,(d.clock()-at)*1000)
    if ready then local c=M.warmup(d.seed);assert(engine:submit(c.rows[2][3],lease(c)));phase='warming'end
    return
   end
   if phase=='capturing'then
    stream:tick(at);local s=stream:status()
    if s.phase~='capturing'then phase='stopping';errorText=s.error
    elseif s.capture.rawSeconds>=3 then stream:drain();phase='draining'end
   end
   local deadline=at+.003;local remaining=256
   for work=1,4 do
    if work>1 and(d.clock()>=deadline or remaining==0)then break end
    if(phase=='capturing'or phase=='draining')and not submitting and engine:canSubmit()then
     local ticket,why=stream:reserve()
     if ticket then
      local staged,reason=projection:stage(ticket.context);assert(staged,reason);local c=projection:commitAdmission(staged)
      for q=1,4 do projection:acceptQuarter(c.token[3],q)end
      local good,id=engine:submit(c.rows[2][3],lease(c));assert(good,id);jobs[id]=ticket;submitting={id=id,source=c.frame}
     elseif why~='empty'and why~='busy'then phase='stopping';errorText=stream:status().error or why end
    end
    local spent=engine:pump(at,deadline,remaining);remaining=remaining-spent;local es=engine:status();assert(not es.fault,es.fault)
    if submitting and es.submitted>=submitting.id then
     stream:submitted(assert(jobs[submitting.id]));maxFrameLag=math.max(maxFrameLag,d.frame()-submitting.source);submitting=nil
    end
    if es.active or not engine:canSubmit()or phase=='warming'or phase=='stopping'then break end
   end
   for _=1,32 do
    local result=engine:take();if not result then break end;lastWords=cp(result.words)
    if phase=='warming'then
     assert(result.accepted,'warmup ledger refused');warmup=true;engine:resetWarmup();stream=d.createLive();assert(stream:start());projection=d.Projection.new(d.Packet,d.seed);phase='capturing';lastWords=nil
    else
     local ticket=assert(jobs[result.serial],'owned time ticket');jobs[result.serial]=nil;stream:acknowledge(ticket,result.accepted)
     if not result.accepted then if not firstRefused then firstRefused={serial=result.serial,words=cp(result.words),details=cp(result.details),context=cp(result.context or ticket.context),previousContext=cp(result.previousContext)}end;phase='stopping';errorText=stream:status().error end
    end
   end
   local es=engine:status();assert(not es.fault,es.fault)
   if stream then
    local s=stream:status();maxAge=math.max(maxAge,s.oldestAgeSeconds);maxDebt=math.max(maxDebt,s.queue.retainedDebtSeconds)
    assert(math.abs(s.queue.advancedSeconds-es.advancedSeconds)<1e-12,'GPU audit/source time agreement')
    if(phase=='draining'or phase=='stopping')and not es.active and es.pending==0 then phase=phase=='draining'and s.drained and'observed'or'stopped'end
   end
  end)
  if measured then maxPump=math.max(maxPump,(d.clock()-at)*1000)end
  if not ok then fail(e)end
 end
 function api:cancel()phase='cancelled';engine:cancel();if stream then stream:cancel()end end
 function api:status()return{phase=phase,error=errorText,engine=engine:status(),stream=stream and stream:status(),warmup=warmup,maxPumpMS=maxPump,maxPrepareMS=maxPrepare,maxSourceAge=maxAge,maxDebt=maxDebt,maxSubmitFrameLag=maxFrameLag,lastWords=cp(lastWords),firstRefused=cp(firstRefused),publicClockAdvanced=false,rendererAccess=false}end
 return api
end
return M
