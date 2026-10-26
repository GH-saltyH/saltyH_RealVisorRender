-- s239 version: retained row encoder; capture/time/reset rules unchanged.
-- One verified bootstrap; coherent per-frame CPU inputs. No solver/GPU resources.
local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function cp(t)if type(t)~='table'then return t end;local r={};for k,v in pairs(t)do r[k]=cp(v)end;return r end
function M.new(d,options)
 local epoch=options.epoch;assert(finite(epoch)and epoch==math.floor(epoch)and epoch>0 and epoch<=1048575,'time epoch')
 local phase='idle';local used=false;local reason;local boot,started,seed,settings,binding,sampler,previous,composer
 local samples,duplicates,paused,pausedFrames,assetProofs=0,0,0,0,0;local rawSum,correction=0,0
 local replayOrigin,replayElapsed;local firstFrame,lastFrame
 local function stamp()
  local s=assert(d.api.getSim(),'sim unavailable')
  assert(finite(s.frame)and s.frame==math.floor(s.frame)and s.frame>=1 and s.frame<=16777215,'frame unavailable')
  assert(finite(s.dt)and s.dt>=0 and s.dt<=.25,'frame dt outside capture bound')
  assert(type(s.isReplayActive)=='boolean'and type(s.isPaused)=='boolean','clock mode unavailable')
  assert(s.focusedCar==0,'focused car reset required')
  local r={frame=s.frame,dt=s.dt,replay=s.isReplayActive,paused=s.isPaused,car=s.focusedCar}
  if r.replay then
   assert(finite(s.replayCurrentFrame)and s.replayCurrentFrame>=0 and s.replayCurrentFrame==math.floor(s.replayCurrentFrame),'replay cursor unavailable')
   assert(finite(s.replayFrameMs)and s.replayFrameMs>0 and finite(s.replayPlaybackRate)and s.replayPlaybackRate>=0,'replay timebase unavailable')
   r.replayFrame=s.replayCurrentFrame;r.replayStep=s.replayFrameMs*.001;r.replayRate=s.replayPlaybackRate
  end
  return r
 end
 local function checkBinding()
  local x=d.live();assert(x.mesh==binding.mesh and x.surface==binding.surface and x.count==binding.count and x.surface.ready and x.surface.model==settings.MODEL_PATH,'geometry binding reset required')
  assert(x.configuredScale==binding.configuredScale and x.appliedScale==binding.appliedScale,'scale setting reset required')
  for n,v in pairs(settings)do assert(x.runtime[n]==v,'physical setting reset required: '..n)end
  return x
 end
 local function sameStamp(a,b)
  for _,n in ipairs({'frame','dt','replay','paused','car','replayFrame','replayStep','replayRate'})do assert(a[n]==b[n],'clock changed during capture')end
 end
 local api={}
 function api:start()
  if used then return false,'one_shot_used'end;used=true
  local ok,why=pcall(function()boot=d.bootstrap();boot:setEnabled(true);assert(boot:start(),boot:status().error);started=d.clock();phase='verifying_assets'end)
  if not ok then phase='fault';reason=tostring(why);return false,reason end;return true
 end
 function api:tick()
  if phase~='verifying_assets'and phase~='capturing'then return nil,phase end
  local ok,payload,kind=pcall(function()
   if phase=='verifying_assets'then
    local pending=boot:status();assert(pending.phase~='fault',pending.error)
    if pending.pending>0 then assert(d.clock()-started<=10,'asset verification timeout')end
    local initial=assert(d.api.getSim(),'sim unavailable')
    if initial.dt==0 or(finite(initial.dt)and initial.dt>.05)then return nil,'waiting_bootstrap_frame'end
    boot:tick();local status=boot:status();assert(status.phase~='fault',status.error)
    if status.phase~='captured_cpu'then return nil,'verifying_assets'end
    seed=assert(boot:result());settings=cp(seed.settings);local x=d.live()
    assert(finite(x.configuredScale)and x.configuredScale>0 and finite(x.appliedScale)and x.appliedScale>0,'scale provenance unavailable')
    binding={mesh=x.mesh,surface=x.surface,count=x.count,configuredScale=x.configuredScale,appliedScale=x.appliedScale};checkBinding()
    previous=stamp();assert(previous.frame==seed.frame,'bootstrap frame changed')
    if previous.replay then replayOrigin=previous.replayFrame;replayElapsed=0 end
    sampler=d.Inputs.new(d.api,{gExcludesGravity=true,rateAtOne=settings.RAIN_RATE_AT_INTENSITY_1_MM_H,ratePower=settings.RAIN_RATE_INTENSITY_POWER})
    composer=d.Compose.new({api=d.api,Packet=d.Packet,settings=settings,assets=d.assets,seed=seed},d.composeOptions)
    assetProofs=1;phase='capturing';boot:setEnabled(false);return nil,'primed'
   end
   local current=stamp();local x=checkBinding()
   assert(current.replay==previous.replay,'replay mode reset required')
   assert(current.frame==previous.frame or current.frame==previous.frame+1,'frame gap/rewind reset required')
   if current.replay then
    assert(current.replayStep==previous.replayStep,'replay timebase reset required')
    assert(current.replayFrame>=previous.replayFrame,'replay rewind reset required')
    if current.dt==0 then assert(current.replayFrame==previous.replayFrame,'paused replay seek reset required')end
    local elapsed=replayElapsed+(current.frame~=previous.frame and current.dt or 0)
    assert(math.abs((current.replayFrame-replayOrigin)*current.replayStep-elapsed)<=2*current.replayStep+1e-6,'replay jump/stall reset required')
   end
   if current.dt==0 then
    paused=paused+1
    if current.frame==previous.frame then return nil,'paused_repeat'end
    local frame=d.Packet.f32(current.frame);local key=d.api.checksumSHA256('RealVisor/s238/pause/'..epoch..'/'..current.frame)
    if #key==32 then key=key:gsub('.',function(c)return string.format('%02x',c:byte())end)else key=key:lower()end
    assert(#key==64 and not key:find('[^0-9a-f]'),'pause checksum')
    local p={scope='zero_time_pause_v1',frame=current.frame,rawDt=0,timeEpoch=epoch,contentKey=key,
     rows={[2]={frame,0,0,x.count},[43]={frame,0,0,0}}}
    sameStamp(current,stamp());checkBinding();previous=current;pausedFrames=pausedFrames+1;lastFrame=current.frame
    return p,'paused'
   end
   assert(not current.paused,'pause flag/dt conflict')
   if current.frame==previous.frame then assert(current.dt==previous.dt,'duplicate frame dt changed');duplicates=duplicates+1;return nil,'duplicate'end
   local sample,why=sampler:capture(function(frame,index)
    assert(frame==current.frame and index==0,'capture frame/car');return{scope='visor_model_world_v1',frame=frame,rows=d.poseRows(x.mesh)}
   end);assert(sample,why);assert(sample.rawDt==current.dt,'capture dt changed');sameStamp(current,stamp());checkBinding()
   local p=composer:compose(sample)
   p.timeEpoch=epoch;p.configuredScale=binding.configuredScale;p.appliedScale=binding.appliedScale
   if current.replay then replayElapsed=replayElapsed+current.dt end
   previous=current;samples=samples+1;firstFrame=firstFrame or current.frame;lastFrame=current.frame
   local y=current.dt-correction;local t=rawSum+y;correction=(t-rawSum)-y;rawSum=t
   return p,'captured'
  end)
  if not ok then reason=tostring(payload);phase=reason:find('reset required',1,true)and'reset_required'or'fault';if boot then boot:setEnabled(false)end;return nil,phase end
  return payload,kind
 end
 function api:stop()if phase~='fault'and phase~='reset_required'then phase='stopped'end;if boot then boot:setEnabled(false)end end
 function api:status()return{phase=phase,error=reason,epoch=epoch,used=used,assetProofs=assetProofs,samples=samples,duplicates=duplicates,pausedCallbacks=paused,pausedFrames=pausedFrames,
  seedFrame=seed and seed.frame,firstFrame=firstFrame,lastFrame=lastFrame,rawSeconds=rawSum,replay=previous and previous.replay,
  identity=composer and composer:status(),resetRequired=phase=='reset_required',GPUAllocated=false,publicClockAdvanced=false,actualCspExercised=false}end
 return api
end
return M
