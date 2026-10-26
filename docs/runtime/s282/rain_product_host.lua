-- Continuous product preview. Default OFF; one owned epoch per app reload.
return function(d)
 local function load(s,n)return dofile(d.folder..'/docs/prototypes/'..s..'/'..n..'.lua')end
 -- CSP exposes this callable as cdata on some builds (s245 compatibility).
 local rawClock=os.preciseClock;local function clock()return rawClock()end
 local Packet=dofile(d.folder..'/docs/probes/s151/s151_header_packet.lua')
 local Context,Assets=load('s152','s152_context'),load('s152','s152_assets')
 local Failure=dofile(d.folder..'/docs/runtime/s282/rain_product_failure.lua')
 local backend=load('s273','s273_csp').new({opaque=render.BlendMode.Opaque,vec2=vec2,vec3=vec3,vec4=vec4,
  createCanvas=function(s)return ui.ExtraCanvas(vec2(s.width,s.height),1,render.AntialiasingMode.None,s.format=='r32f'and render.TextureFormat.R32.Float or render.TextureFormat.R32G32B32A32.Float,0)end})
 local enabled,used=false,false;local phase='idle';local owner,context,seed,visual;local errorText;local started;local files=0;local images;local lastFrame,lastOutput,lastForeground
 local failureSaved=false;local failureWriteError;local failurePath=d.folder..'/docs/diagnostics/runtime/rain_product_failure.txt'
 local admissionSaved=false;local admissionWriteError;local admissionPath=d.folder..'/docs/diagnostics/runtime/rain_product_overload.txt'
 local frozenRequested=false;local frozenWriteError;local frozenPath=d.folder..'/docs/diagnostics/runtime/frozen_current/'
 local function preserveFrozen(s)
  if frozenRequested or frozenWriteError or not s.firstRefused then return end
  local ok,e=pcall(function()
   local v=assert(owner:frozenFailureInputs(),'Cancelled rejected stock unavailable')
   local lines={'RealVisor frozen stock request v1','serial='..v.serial,'bank='..v.bank,'headCount='..v.headCount,'requestedUnix='..os.time()}
   -- Standard CSP DDS export, only after failure. ZippedDDS writes in a worker
   -- thread; the offline reader verifies format/shape and matching stock ledger.
   for _,name in ipairs({'film','micro','heads','state','meta','ledger','pose','receipt','otherReceipt'})do
    local path=frozenPath..name..'.zip';v.textures[name]:save(path,ac.ImageFormat.ZippedDDS);lines[#lines+1]=name..'='..name..'.zip'
   end
   assert(io.save(frozenPath..'request.txt',table.concat(lines,'\n')..'\n',true),'Frozen stock request record failed')
  end)
  if ok then frozenRequested=true else frozenWriteError=tostring(e)end
 end
 local function preserveFailure(s)
  if s.phase=='overloaded'and not admissionSaved and not admissionWriteError then
   local ok,e=pcall(function()assert(io.save(admissionPath,Failure.admission(s),true),'Could not save retained admission report')end)
   if ok then admissionSaved=true else admissionWriteError=tostring(e)end
  end
  if not s.firstRefused or failureSaved or failureWriteError then return end
  local ok,e=pcall(function()assert(io.save(failurePath,Failure.encode(s,Packet),true),'Could not save retained failure report')end)
  if ok then failureSaved=true else failureWriteError=tostring(e)end
  preserveFrozen(s)
 end
 local function pose(mesh)local m=mesh:getWorldTransformationRaw();local rows={};for i=1,4 do local v=m['row'..i];rows[i]={v.x,v.y,v.z,v.w}end;return rows end
 local function hashFile(n,fn)files=files+1;io.checksumSHA256(d.folder..'/'..n,fn)end
 local function fail(e)errorText=tostring(e);phase='fault';if owner then owner:stop()end;if context then context:setEnabled(false)end end
 local function begin()
  started=clock();context=Context.new({api=ac,Inputs=dofile(d.folder..'/docs/probes/s151/s151_engine_inputs.lua'),Packet=Packet,assets=Assets,live=d.live,poseRows=pose,hashFile=hashFile})
  context:setEnabled(true);assert(context:start());phase='capturing_seed'
 end
 local api={}
 function api:isEnabled()return enabled and used end
 function api:status()return{enabled=enabled,phase=phase,error=errorText,runtime=owner and owner:status(),visual=visual and visual:status()}end
 function api:tick(sim)
  if not enabled or not used or phase=='fault'or phase=='cancelled'or phase=='overloaded'then return nil end
  if lastFrame==sim.frame and lastForeground==sim.isWindowForeground then return lastOutput end;lastFrame=sim.frame;lastForeground=sim.isWindowForeground;lastOutput=nil
  local output;local ok,why=pcall(function()
   if phase=='capturing_seed'then
    assert(clock()-started<60,'seed verification timeout');if sim.dt==0 then return end
    context:tick();local s=context:status();assert(s.phase~='fault',s.error);if s.phase~='captured_cpu'then return end
    seed=assert(context:result());context:setEnabled(false);local live=d.live();seed.configuredScale=live.configuredScale;seed.appliedScale=live.appliedScale
    images={};for _,r in ipairs({
     {'fileDu','texture/RAIN_GEOMETRY/du.dds',2048,512,'rgba32f'},
     {'fileDv','texture/RAIN_GEOMETRY/dv.dds',2048,512,'rgba32f'},
     {'fileCells','texture/RAIN_FILM/cells.dds',1024,256,'rgba32f'},
     {'fileMask','texture/RAINFX_ObjNormal_BoundaryMask.dds',4096,1024,'bc3_unorm'},
     {'fileSites','texture/RAIN_BIRTH/sites.dds',8192,1,'rgba32f'},
     {'fileDsd','texture/RAIN_BIRTH/dsd.dds',128,2,'rgba32f'},
     {'fileImpact','texture/RAIN_BIRTH/impact_estimated.dds',32,4,'rgba32f'}})do
     assert(seed.geometryFiles[r[2]]==Assets.files[r[2]],'verified file identity')
     images[#images+1]={name=r[1],path=d.folder..'/'..r[2],width=r[3],height=r[4],format=r[5]}
    end;phase='loading_files'
   end
   if phase=='loading_files'then
    local textures,descriptors={},{};for _,r in ipairs(images)do if not ui.isImageReady(r.path)then return end;local size=ui.imageSize(r.path);assert(size.x==r.width and size.y==r.height,'verified image dimensions');textures[r.name]=r.path;descriptors[r.name]={width=r.width,height=r.height,format=r.format} end
    local at=clock();local Transaction=load('s265','s265_transaction')
    local function preload(s,n)local m=load(s,n);package.preload[n]=function()return m end;package.loaded[n]=m;return m end
    preload('s146','s146_sources');local Birth=preload('s146','s146_birth')
    local HeadSources=preload('s148','s148_sources');local Heads=preload('s148','s148_heads')
    preload('s144','s144_sources');preload('s167','s167_sources');preload('s167','s167_handoff')
    local function hashText(s)local h=ac.checksumSHA256(s);if #h==32 then return h:gsub('.',function(x)return string.format('%02x',string.byte(x))end)end;return h:lower()end
    local graph=load('s278','s278_graph').new({RetentionGraph=load('s277','s277_graph'),ApprovalGraph=load('s275','s275_graph'),IntegrationGraph=load('s274','s274_graph'),CaptureGraph=load('s273','s273_graph'),DiagnosticGraph=load('s272','s272_graph'),PreviousGraph=load('s271','s271_graph'),Graph=load('s269','s269_graph'),Core=load('s264','s264_coupled').new(load('s156','s156_sources'),load('s263','s263_flux')),
     Cohort=load('s268','s268_cohort'),Producer=load('s268','s268_producer'),Bindings=load('s268','s268_bindings'),
     Birth=Birth,Heads=Heads,HeadSources=HeadSources,Cells=load('s170','s170_cells'),Joint=load('s267','s267_joint'),Cache=load('s154','s154_sources'),Packet=Packet,hashText=hashText,
     BindingUtil=load('s269','s269_bindings_util'),SourceBindings=load('s269','s269_bindings')},seed)
    assert(graph.descriptorBytes+32*160*4+graph.readonlyFileBytes<=256*1048576,'complete static memory bound')
    local delegate=load('s274','s274_sdk').wrap(load('s270','s270_sdk').wrap(backend))
    owner=dofile(d.folder..'/docs/runtime/s282/rain_product_pipeline.lua').new({
     folder=d.folder,api=ac,live=d.live,graph=graph,seed=seed,backend=delegate,clock=clock,
     files=textures,fileDescriptors=descriptors,hashFile=hashFile,hashText=hashText})
    visual=dofile(d.folder..'/docs/runtime/s282/rain_product_visual.lua').new({folder=d.folder,backend=backend,theta=seed.rows[23][1],referencePerMM=seed.unitRows[1][2],
     displayGain=function()local r=d.live().runtime;return(r.RAIN_PHYSICS_DISPLAY_DIAMETER_GAIN or .7937005259840998)*(r.RAIN_BIRTH_DISPLAY_SCALE or .4)end})

    owner:start();phase='preparing'
   end
   if owner then owner:pump();local s=owner:status();phase=s.phase;errorText=s.error;preserveFailure(s)
    if phase~='fault'and phase~='overloaded'and visual:resolve(owner,sim.frame,sim.dt)then output=visual:result()end
   end
  end)
  if not ok then fail(why);return nil end;lastOutput=output;return output
 end
 function api:ui()
  if ui.checkbox('Enable continuous physical RainFX preview',enabled)then
   enabled=not enabled
   if not enabled and owner then owner:stop()end
   if not enabled and context then context:setEnabled(false)end
   if not enabled and used then phase='cancelled' end
  end
  if not enabled then return end
  ui.textWrapped('s282 product preview: fixed 32 Hz physics with frame-rate display interpolation. Dry start; no Smear/local impact-film overlay. Regional film-to-drop return enabled (material calibration provisional); returned drops use the same SI motion and exits. Merge is not implemented. Resources remain until session ends. Disable other diagnostics. One start per app reload.')
  if not used and ui.button('Start continuous physical RainFX')then used=true;local ok,e=pcall(begin);if not ok then fail(e)end end
  if owner and(phase=='running'or phase=='background_paused'or phase=='resuming'or phase=='repriming')and ui.button('Stop physical RainFX')then owner:stop()end
  ui.text('State: '..phase)
  if seed and seed.rows and seed.rows[23]and seed.rows[24]and seed.rows[26]then
   local shape,dynamic,deposit=seed.rows[23],seed.rows[24],seed.rows[26]
   ui.text(string.format('Captured material: theta %.1f deg; static span bare/coat %.1f / %.1f deg; dynamic %.1f / %.1f deg',shape[1],shape[2],shape[3],dynamic[1],dynamic[2]))
   ui.text(string.format('Captured trail beta bare/coat %.3f / %.3f (estimated coefficients)',deposit[1],deposit[2]))
   ui.textWrapped('Physical material is captured at start; reload before changing it. Low pinning compared with bare glass does not imply less pinning than the current coated region. Display gains are separate.')
  end
  if owner then ui.textWrapped('Mode: deposit + drying. Drops move and leave paths; active film transport is excluded from this product baseline.')end
  if owner then ui.textWrapped('Field drying and micro-to-film joining are enabled. Rates follow captured weather; joining follows the configured physical height and coating.')end
  if owner then ui.textWrapped('Very fast drops can under-travel when the bounded surface walk is exhausted; water is retained at the last valid position.')end
  if phase=='fault'or phase=='overloaded'or phase=='cancelled'then ui.textWrapped('Physical output is disabled; legacy rendering resumes. Owned resources and any unprocessed physical time remain retained. Reload the app before another start.')end
  if owner then local s=owner:status();local e=s.engine;local q=s.input and s.input.cadence
   ui.text(string.format('Submitted %d; audited %d; pending %d; resources %d (+ optical snapshots)',e.submitted,e.audited,e.pending,e.resources))
   ui.text(string.format('Advanced %.3fs; debt %.3fs; max pump %.3f ms',e.advancedSeconds,s.retainedTotalDebtSeconds or(q and q.retainedDebtSeconds or 0),s.maxPumpMS))
   if e.trailExport then local t=e.trailExport
    ui.text(string.format('Trail source export: %d cohorts; %.2f MiB; +%d draws/interval',t.capacity,t.descriptorBytes/1048576,t.recurringDraws))
    ui.textWrapped('Accepted trail geometry, sparse bins and coarse contribution are retained for fine optical reconstruction.')
   end
   if s.capturedWeather then local w=s.capturedWeather
    ui.text(string.format('Captured frame %d: rain %.3f / liquid %.3f; RH %.3f; T %.1f C; wind %.1f km/h',w.frame,w.rain,w.liquid,w.humidity,w.temperature,w.windMS*3.6))
    ui.text(string.format('Supply density %.2f /m3; evaporation %.5f um/s; track wet/water %.3f / %.3f (observed only)',w.density,w.evapUMS,w.wetness,w.water))
    ui.textWrapped('Captured input is not the last GPU-applied state. Track wetness/water do not directly create visor water; retained film can take a long time to dry.')
   end
   if e.diagnosticWarnings>0 then ui.text(string.format('Cumulative momentum diagnostic warnings %d; last serial %d (not a physical-state failure)',e.diagnosticWarnings,e.lastDiagnostic.serial))end
   if s.staging then ui.text(string.format('Input staging %d /16; %.3fs /0.500s; recovered frames %d',s.staging.frames,s.staging.seconds,s.staging.recoveredFrames))end
   if s.background and s.background.cycles>0 then ui.text(string.format('Background pauses %d; excluded input %.3fs; wall pause %.3fs',s.background.cycles,s.background.excludedRawSeconds,s.background.pausedWallSeconds))end
   if phase=='background_paused'or phase=='resuming'or phase=='repriming'then ui.textWrapped('Physical model paused outside the foreground. Existing water is retained; background rain time is not simulated. Returning drains captured work and re-primes the current visor pose.')end
   local f=Failure.summary(s.firstRefused)
   if f then
    ui.text(string.format('First refused %d; reason %g; context %g; head %g / slot %g',f.serial,f.reason,f.context,f.headCode,f.headSlot))
    ui.text(string.format('Source mask %g; aggregate status %g; source head %g / mask %g / slot %g',f.sourceMask,f.aggregateStatus,f.sourceHeadCode,f.sourceHeadMask,f.sourceHeadSlot))
    if failureSaved then ui.textWrapped('Retained failure saved: '..failurePath)end
    if failureWriteError then ui.textWrapped(failureWriteError)end
    if frozenRequested then ui.textWrapped('Frozen stock DDS export requested; data verification pending.')end
    if frozenWriteError then ui.textWrapped(frozenWriteError)end
   end
   if admissionSaved then ui.textWrapped('Retained admission saved: '..admissionPath)end
   if admissionWriteError then ui.textWrapped(admissionWriteError)end
   if ui.button('Log physical RainFX summary')then ac.log(string.format('[RealVisor product s282] state=%s submitted=%d audited=%d pending=%d advanced=%.9g debt=%.9g resources=%d maxPumpMS=%.9g fileChecks=%d stagingFrames=%d stagingSeconds=%.9g recovered=%d',phase,e.submitted,e.audited,e.pending,e.advancedSeconds,s.retainedTotalDebtSeconds or(q and q.retainedDebtSeconds or 0),e.resources,s.maxPumpMS,files,s.staging and s.staging.frames or 0,s.staging and s.staging.seconds or 0,s.staging and s.staging.recoveredFrames or 0))end
  end
  if errorText then ui.textWrapped(errorText)end
  if visual then local v=visual:status();if v.error then ui.text(v.error)end
   if v.interpolation then local t=v.interpolation;ui.text(string.format('Display interpolation: frame-rate heads + film; %.2f ms interval; %.1f MiB; +4 archive / +3 frame draws',t.span*1000,t.descriptorBytes/1048576))end
   if v.fineTrail then local t=v.fineTrail;ui.text(string.format('Fine trail optics: %dx%d; %d draws/new state; %.1f MiB workspace',t.width,t.height,t.draws,t.descriptorBytes/1048576))
    ui.text(string.format('Optical rebuilds %d; cached frames %d; detail history 0.50s (water remains in film)',v.rebuilds,v.reuses))end
  end
 end
 return api
end
