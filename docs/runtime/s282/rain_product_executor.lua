-- Product derivative: owned roots exported only after a live accepted audit.
-- Consumers choose the newest complete GPU receipt, never a CPU-selected bank.
local M={}
local function cp(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=cp(v)end;return r end
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
function M.new(d,graph)
 assert(d.backend.scope=='private_ordered_status_v1','private ordered backend')
 local handles,slots,records={},{},{};local previousContext;local names={};for n in pairs(graph.resources)do names[#names+1]=n end;table.sort(names)
 local prepared=false;local seen={};local position=1;local serial=0;local consumed=0;local active;local warmed=false;local fault;local stopped=false;local cancelled=false;local lastNow
 local draws,retries,duplicates,reuses=0,0,0,0;local advanced=0;local submittedSeconds=0;local submitted=0;local rejected=false
 local bindMS,packetMS,maxPacketMS,liveRetries,warmupRetries=0,0,0,0,0
 local diagnosticWarnings=0;local lastDiagnostic
 local bytes=graph.descriptorBytes+32*160*4;assert(bytes<=192*1048576,'owned workspace cap;external inputs excluded')
 local function fail(e)fault=tostring(e);if active then active.quarantined=true end end
 local function freeSlot()for _,s in ipairs(slots)do if not s.job and not s.quarantined then return s end end end
 local api={descriptorBytes=bytes}
 function api:prepare()
  if prepared then return true end
  local at=d.clock();local created=0
  local ok,e=pcall(function()
   while created<8 and d.clock()-at<.003 do
    if position<=#names then local n=names[position];local c=assert(d.backend.create(cp(graph.resources[n]),1,position));assert(not seen[c],'unique workspace');seen[c]=true;handles[n]=c
    else
     local i=position-#names;if i>32 then prepared=true;break end
     local c=assert(d.backend.create({name='s269 audit '..i,width=160,height=1,format='r32f'},1,position));assert(not seen[c],'unique audit storage');seen[c]=true;slots[i]={canvas=c,uses=0}
    end
    position=position+1;created=created+1
   end
  end)
  if not ok then fail(e);return false,fault end
  return prepared and true or nil,'preparing'
 end
 function api:canSubmit()return prepared and not fault and not stopped and not active and freeSlot()~=nil end
 function api:submit(dt,lease)
  if not api:canSubmit()then return false,fault or'busy/stopped'end
  assert(type(lease)=='table'and type(lease.valid)=='function'and lease:valid(),'owned immutable input lease')
  assert(serial<1048575,'bounded serial');local id=serial+1;local at=d.clock();local recipe=graph:bind(dt,id,lease.context,function(role,expected)
   local actual=handles[role]and graph.resources[role]or(lease.textures[role]and lease.descriptors and lease.descriptors[role])
   return lease:valid()and actual and actual.width==expected.width and actual.height==expected.height and actual.format==expected.format
  end);bindMS=math.max(bindMS,(d.clock()-at)*1000);local slot=assert(freeSlot())
  local params={}
  serial=id;submittedSeconds=submittedSeconds+dt
  local job={serial=id,dt=dt,lease=lease,recipe=recipe,params=params,cursor=1,slot=slot,pending=0};job.previousContext=previousContext;previousContext=lease.context;records[id]=job;slot.job=job
  local tx={};for n,role in pairs(recipe.audit.textures)do tx[n]=assert(handles[role]or lease.textures[role],role)end;job.auditParams={async=true,directValuesExchange=false,blendMode=d.backend.opaque,cacheKey=283999,shader=d.snapshot,defines={},values=cp(recipe.audit.values),textures=tx}
  if slot.uses>0 then reuses=reuses+1 end;active=job;return true,id
 end
 function api:pump(now,outerDeadline,callCeiling)
  if fault or cancelled then return 0 end;if not finite(now)or(lastNow and now<lastNow)then fail('monotonic clock');return 0 end;lastNow=now
  for _,j in pairs(records)do if j.waitAt and not j.finished and now-j.waitAt>5 then j.slot.quarantined=true;fail('private audit timeout');return 0 end end
  if not active then return 0 end
  local calls=0;local deadline=math.min(d.clock()+.003,outerDeadline or math.huge);local job=active
  local ok,e=pcall(function()
   assert(job.lease:valid(),'input lease invalidated before submission')
   while active and calls<math.min(256,callCeiling or 256)and d.clock()<deadline do
    local p=job.recipe.passes[job.cursor];local target,params
    if p then
     target=handles[p.target];params=job.params[job.cursor]
     if not params then
      local at=d.clock();local tx={};for n,source in pairs(p.textures)do tx[n]=assert(handles[source]or(source=='zeroReceipt'and handles.receiptB)or job.lease.textures[source],source)end
      for _,source in pairs(tx)do assert(source~=target,'read/write alias')end
      local values={};for n,v in pairs(p.values)do local kind=type(v)=='table'and(#v==2 and'vec2'or'vec4')or'number';values[n]=d.backend.make(kind,cp(v))end
      params={async=true,directValuesExchange=false,blendMode=d.backend.opaque,cacheKey=p.cacheKey,shader=p.shader,defines={},textures=tx,values=values};job.params[job.cursor]=params
      local ms=(d.clock()-at)*1000;packetMS=packetMS+ms;maxPacketMS=math.max(maxPacketMS,ms)
      -- Preparation uses the same budget as draws. Retain a pending packet verbatim.
      if d.clock()>=deadline then break end
     end
    else target=job.slot.canvas;params=job.auditParams end
    local accepted=d.backend.draw(target,params);calls=calls+1;assert(type(accepted)=='boolean','known draw result')
    if not accepted then if warmed then liveRetries=liveRetries+1 else warmupRetries=warmupRetries+1 end;retries=retries+1;job.pending=job.pending+1;job.pendingSince=job.pendingSince or now;assert(now-job.pendingSince<(warmed and 5 or 60),string.format('shader pending timeout key=%s pass=%s elapsed=%.3fs',tostring(params.cacheKey),p and p.kind or 'audit',now-job.pendingSince));break end
    draws=draws+1;job.pending=0;job.pendingSince=nil
    if p then job.params[job.cursor]=nil;job.cursor=job.cursor+1 else
     active=nil;submitted=submitted+1;job.waitAt=now;job.recipe=nil;job.params=nil;job.auditParams=nil;job.slot.uses=job.slot.uses+1
     local once=false
     d.backend.readStatus(job.slot.canvas,function(err,words)
      if once then duplicates=duplicates+1;return end;once=true
      if err or type(words)~='table'or #words~=160 then job.slot.quarantined=true;fail(err or'audit shape');return end
      for _,x in ipairs(words)do if not finite(x)then job.slot.quarantined=true;fail('finite audit');return end end
      if words[1]~=267 or words[2]~=1 or words[3]~=job.serial then job.slot.quarantined=true;fail('audit identity');return end
      job.words={};for i=1,16 do job.words[i]=words[i]end;job.details=words[4]==0 and cp(words)or nil;job.finished=true
      job.sourceMask=words[126]
     end)
    end
   end
  end)
  if not ok then job.slot.quarantined=true;fail(e)end;return calls
 end
 function api:take()
  if fault or cancelled then return nil,fault or'cancelled'end
  local job=records[consumed+1];if not job or not job.finished then return nil,'pending'end
  if not job.lease:valid()then job.slot.quarantined=true;fail('input lease lost before audit retirement');return nil,fault end
  local good,accepted=graph:validate(job.words,job.serial,job.dt,advanced)
  if not good or(rejected and accepted)then job.slot.quarantined=true;fail(not good and accepted or'accepted suffix after rejection');return nil,fault end
  if job.lease.release then
   local ok,why=pcall(job.lease.release,job.lease)
   if not ok then job.slot.quarantined=true;fail(why);return nil,fault end
  end
  consumed=consumed+1;records[consumed]=nil;job.slot.job=nil
  if accepted then
   advanced=advanced+job.dt
   local mask=job.sourceMask or 0
   if math.floor(mask/128)%2==1 or math.floor(mask/256)%2==1 then
    diagnosticWarnings=diagnosticWarnings+1
    lastDiagnostic={serial=job.serial,sourceMask=mask,momentumResidual={job.words[13],job.words[14],job.words[15]}}
   end
  else rejected=true;stopped=true end
  return{serial=job.serial,accepted=accepted,words=cp(job.words),details=not accepted and cp(job.details)or nil,context=not accepted and cp(job.lease.context)or nil,previousContext=not accepted and cp(job.previousContext)or nil}
 end
 function api:resetWarmup()
  assert(serial==1 and consumed==1 and not active and not fault and not stopped,'one accepted warmup drained')
  assert(next(records)==nil and advanced>0,'warmup receipt accepted')
  serial=0;consumed=0;submitted=0;advanced=0;submittedSeconds=0;warmed=true;previousContext=nil;diagnosticWarnings=0;lastDiagnostic=nil
 end
 function api:visualInputs()
  if not warmed or consumed<1 or advanced<=0 or fault or rejected or cancelled then return nil end
  local v={scope='owned_gpu_commit_pair_v1',headCount=graph.headCount,retainedUntilSessionEnd=true,submittedSerial=submitted}
  for _,bank in ipairs({'A','B'})do
   v[bank]={};for _,n in ipairs({'state','meta','film','micro','receipt'})do v[bank][n]=assert(handles[bank..'_'..n])end
  end
  v.areas=assert(handles.scalarAreas);v.boundary=assert(handles.p_boundary)
  if graph.trailExport then
   local export=graph:trailExport();v.trails={scope=export.scope,capacity=export.capacity,tile=export.tile,words=export.words,
    claimDomain=export.claimDomain,descriptorBytes=export.descriptorBytes,cohorts={}}
   for i,s in ipairs(export.ring)do v.trails.cohorts[i]={geometry=assert(handles[s.geometry]),claim=assert(handles[s.claim]),marker=assert(handles[s.marker]),mask=assert(handles[s.mask]),summary=assert(handles[s.summary])}end
  end
  return v
 end
 function api:frozenFailureInputs(id)
  -- The first refused transaction and every submitted suffix select the old
  -- committed values. After cancellation no solver submission can resume.
  if not rejected or not cancelled or id~=consumed then return nil end
  local bank=id%2==1 and'B'or'A';local other=bank=='A'and'B'or'A'
  local v={scope='cancelled_refused_stock_v1',bank=bank,serial=id,headCount=graph.headCount,textures={}}
  for _,n in ipairs({'film','micro','heads','state','meta','ledger','pose','receipt'})do v.textures[n]=assert(handles[bank..'_'..n])end
  v.textures.otherReceipt=assert(handles[other..'_receipt']);return v
 end
 function api:cancel()stopped=true;cancelled=true;for _,s in ipairs(slots)do if s.job then s.quarantined=true end end;active=nil end
 function api:status()
  local held,retainedRecipes=0,0;for _,job in pairs(records)do held=held+1;if job.recipe then retainedRecipes=retainedRecipes+1 end end
  local trail=graph.trailExport and graph:trailExport()
  return{prepared=prepared,active=active~=nil,fault=fault,stopped=stopped,submitted=submitted,audited=consumed,pending=held,
   trailExport=trail and{capacity=trail.capacity,descriptorBytes=trail.descriptorBytes,recurringDraws=trail.recurringDraws}or nil,
   diagnosticWarnings=diagnosticWarnings,lastDiagnostic=cp(lastDiagnostic),
   submittedSeconds=submittedSeconds,advancedSeconds=advanced,debtSeconds=submittedSeconds-advanced,draws=draws,retries=retries,
   templateHits=graph.cacheStatus and graph:cacheStatus().hits or 0,templateBuilds=graph.cacheStatus and graph:cacheStatus().builds or 0,duplicates=duplicates,reuses=reuses,maxBindMS=bindMS,totalPacketMS=packetMS,maxPacketMS=maxPacketMS,liveRetries=liveRetries,warmupRetries=warmupRetries,retainedRecipes=retainedRecipes,resources=#names+32,descriptorBytes=bytes,publicClockAdvanced=false,rendererAccess=false}
 end
 return api
end
return M
