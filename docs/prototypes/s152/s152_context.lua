-- Read-only main-app context capture. No canvases, solver, stock or clock writes.
local M={}
local function cp(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=cp(x)end;return o end
local function finite(x)return type(x)=='number'and x==x and math.abs(x)<math.huge end
local function need(v,s)if not v then error(s,0)end end
local function path(v)return type(v)=='string'and #v>0 and not v:find('[:\\]')and v:sub(1,1)~='/'and not v:find('..',1,true)end
local ranges={
 RAIN_PHYSICS_CONTACT_ANGLE_DEG={.1,179.9},RAIN_PHYSICS_LOCAL_AIR_FRACTION={0,1},RAIN_PHYSICS_VISCOUS_SHAPE={0,10000},
 RAIN_PHYSICS_ATTACHED_CD={0,100},RAIN_PHYSICS_STATIC_SPAN_BARE_DEG={0,179},RAIN_PHYSICS_STATIC_SPAN_COAT_DEG={0,179},
 RAIN_PHYSICS_DYNAMIC_SPAN_BARE_DEG={0,179},RAIN_PHYSICS_DYNAMIC_SPAN_COAT_DEG={0,179},
 RAIN_RATE_AT_INTENSITY_1_MM_H={0,1000},RAIN_RATE_INTENSITY_POWER={.01,10},RAIN_PHYSICS_DSD_SEED_OVERRIDE={0,4},
 RAIN_GPU_STATE_RAIN_OVERRIDE={-1,1},RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM={1e-6,1},
 RAIN_BIRTH_EXPOSURE={0,1},RAIN_BIRTH_INCIDENT_AIR_FRACTION={0,1},RAIN_BIRTH_TANGENT_IMPULSE_FRACTION={0,1},
 RAIN_BIRTH_MIN_PERSISTENT_MM={.001,10},RAIN_BIRTH_WET_OVERRIDE={0,1},RAIN_FILM_WET_HEIGHT_UM={.001,100000},
 RAIN_FILM_FLOW_CF={0,1},RAIN_FILM_DEPOSIT_BARE={0,1},RAIN_FILM_DEPOSIT_COAT={0,1},RAIN_FILM_MIN_SPEED_MM_S={0,10000},
 RAIN_FILM_SHEAR_WIDEN={0,100},RAIN_FILM_EVAP_DRY_UM_S={0,1000},RAIN_FILM_MICRO_JOIN_UM={.001,100000},RAIN_AIRFLOW_DOWNWARD_GAIN={0,100}}
local bools={'RAIN_FORCE_GRAVITY_ENABLED','RAIN_FORCE_INERTIA_ENABLED','RAIN_FORCE_AIRFLOW_ENABLED','RAIN_FORCE_AIRFLOW_INCLUDE_WIND','RAIN_AIRFLOW_DOWNWARD_MODE','RAIN_BIRTH_NORMAL_REVERSED'}
function M.settings(runtime)
 local r={};for n,lim in pairs(ranges)do local v=runtime[n];need(finite(v)and v>=lim[1]and v<=lim[2],'invalid setting '..n);r[n]=v end
 for _,n in ipairs(bools)do need(type(runtime[n])=='boolean','invalid setting '..n);r[n]=runtime[n]end
 need(path(runtime.MODEL_PATH),'relative model path');r.MODEL_PATH=runtime.MODEL_PATH
 -- Overrides need their own provenance policy; never silently ignore them.
 need(r.RAIN_GPU_STATE_RAIN_OVERRIDE<0,'rain override unsupported in context capture')
 need(r.RAIN_PHYSICS_DSD_SEED_OVERRIDE==0,'DSD override unsupported in context capture')
 return r
end
local function digest(checksum,text)
 local v=checksum(text);need(type(v)=='string','checksum result');if #v==32 then v=v:gsub('.',function(x)return string.format('%02x',x:byte())end)else v=v:lower()end
 need(#v==64 and not v:find('[^0-9a-f]'),'SHA256 result');return v
end
function M.new(d)
 local assets=cp(d.assets);local phase='idle';local errorText;local used=false;local enabled=false;local serial=0;local pending=0;local proof;local result;local files={};local failures={}
 local function live()local x=d.live();need(type(x)=='table'and x.runtime and x.surface,'live context unavailable');return x end
 local function fail(s)phase='fault';errorText=tostring(s)end
 local function start()
  need(enabled and not used,'enable unused capture');local x=live();local r=M.settings(x.runtime)
  need(x.surface.ready and x.surface.model==r.MODEL_PATH,'surface verification pending')
  used=true;serial=serial+1;local generation=serial;phase='verifying_assets';files={};failures={};proof={modelPath=r.MODEL_PATH}
  local expected=cp(assets.files);expected[r.MODEL_PATH]=assets.modelHash
  local names={};for n,h in pairs(expected)do need(path(n)and type(h)=='string'and #h==64,'asset manifest');names[#names+1]=n end;table.sort(names);pending=#names
  for _,n in ipairs(names)do
   local name,wanted=n,expected[n];local called=false
   local ok,why=pcall(d.hashFile,name,function(err,actual)
    if generation~=serial or called then return end;called=true
    if err or type(actual)~='string'or actual:lower()~=wanted then failures[name]=tostring(err or 'hash mismatch')else files[name]=wanted end
    pending=pending-1
   end)
   if not ok and not called then called=true;failures[name]=tostring(why);pending=pending-1 end
  end
  return true
 end
 local function capture()
  local x=live();local r=M.settings(x.runtime)
  need(x.surface.ready and x.surface.model==r.MODEL_PATH and r.MODEL_PATH==proof.modelPath,'geometry owner changed')
  need(x.mesh and x.count>=1 and x.count<=4096 and x.count==math.floor(x.count),'rain mesh/count unavailable')
  local mesh=x.mesh;local sampler=d.Inputs.new(d.api,{gExcludesGravity=true,rateAtOne=r.RAIN_RATE_AT_INTENSITY_1_MM_H,ratePower=r.RAIN_RATE_INTENSITY_POWER})
  local sample,why=sampler:capture(function(frame,index)
   need(index==0,'main physical path currently uses car 0')
   local rows=d.poseRows(mesh);return{scope='visor_model_world_v1',frame=frame,rows=rows}
  end)
  need(sample,why);local current=live();need(current.mesh==mesh and current.surface==x.surface and current.runtime.MODEL_PATH==r.MODEL_PATH,'capture owner changed')
  local again=M.settings(current.runtime);for k,v in pairs(r)do need(again[k]==v,'material changed during capture')end
  need(current.surface.ready and current.surface.model==r.MODEL_PATH and current.count==x.count,'geometry changed during capture')
  local Base=d.Packet;local f=Base.f32;local theta=r.RAIN_PHYSICS_CONTACT_ANGLE_DEG
  local mask=(r.RAIN_FORCE_GRAVITY_ENABLED and 1 or 0)+(r.RAIN_FORCE_INERTIA_ENABLED and 2 or 0)+(r.RAIN_FORCE_AIRFLOW_ENABLED and 4 or 0)
  local p=Base.compose(sample,{epoch=152,headCount=x.count,fieldWidth=assets.width,fieldHeight=assets.height,theta=theta,airFraction=r.RAIN_PHYSICS_LOCAL_AIR_FRACTION,forceMask=mask,localAreaM2=assets.localAreaM2,exposure=r.RAIN_BIRTH_EXPOSURE},d.api.checksumSHA256)
  local e=sample.environment;local wind=r.RAIN_FORCE_AIRFLOW_INCLUDE_WIND and 1 or 0
  local ax,ay,az=e.windX*wind-e.velocityX,-e.velocityY,e.windZ*wind-e.velocityZ
  local air=math.sqrt(ax*ax+ay*ay+az*az)*r.RAIN_PHYSICS_LOCAL_AIR_FRACTION
  -- Match the existing estimated evaporation law, retaining its stated limits.
  local t=math.max(-20,math.min(e.temperatureC,50));local evap=r.RAIN_FILM_EVAP_DRY_UM_S*(1-e.humidity)*math.exp(17.625*t/(243.04+t)-17.625*20/(243.04+20))*(1+.5*math.sqrt(air))
  local rows=p.rows;local function row(i,v)local out={};for j,n in ipairs(v)do out[j]=f(n)end;rows[i+1]=out end
  row(4,{sample.supply.numberDensityM3,assets.localAreaM2*sample.physicalScale^2,r.RAIN_BIRTH_EXPOSURE,r.RAIN_BIRTH_INCIDENT_AIR_FRACTION})
  row(6,{e.airX,e.airY,e.airZ,r.RAIN_BIRTH_TANGENT_IMPULSE_FRACTION})
  row(7,{998.2,.0728,.001002,r.RAIN_BIRTH_MIN_PERSISTENT_MM})
  row(8,{r.RAIN_BIRTH_WET_OVERRIDE,0,r.RAIN_FILM_WET_HEIGHT_UM,r.RAIN_BIRTH_NORMAL_REVERSED and -1 or 1})
  row(9,{math.min(theta+r.RAIN_PHYSICS_STATIC_SPAN_BARE_DEG*.5,179.9),math.min(theta+r.RAIN_PHYSICS_STATIC_SPAN_COAT_DEG*.5,179.9),theta,0})
  row(19,{e.inertiaX,e.inertiaY,e.inertiaZ,mask});row(20,{ax,ay,az,r.RAIN_PHYSICS_LOCAL_AIR_FRACTION})
  row(22,{theta,r.RAIN_PHYSICS_STATIC_SPAN_BARE_DEG,r.RAIN_PHYSICS_STATIC_SPAN_COAT_DEG,r.RAIN_PHYSICS_ATTACHED_CD})
  row(23,{r.RAIN_PHYSICS_DYNAMIC_SPAN_BARE_DEG,r.RAIN_PHYSICS_DYNAMIC_SPAN_COAT_DEG,r.RAIN_PHYSICS_VISCOUS_SHAPE,r.RAIN_AIRFLOW_DOWNWARD_MODE and 1 or 0})
  row(24,{r.RAIN_AIRFLOW_DOWNWARD_GAIN,.05,1,0})
  row(25,{r.RAIN_FILM_DEPOSIT_BARE,r.RAIN_FILM_DEPOSIT_COAT,r.RAIN_FILM_MIN_SPEED_MM_S*.001,r.RAIN_FILM_SHEAR_WIDEN})
  row(26,{evap,air,1,0})
  local a=r.RAIN_FORCE_AIRFLOW_ENABLED and r.RAIN_PHYSICS_LOCAL_AIR_FRACTION or 0
  local inertia=r.RAIN_FORCE_INERTIA_ENABLED and 1 or 0
  row(35,{e.inertiaX*inertia,e.inertiaY*inertia-(r.RAIN_FORCE_GRAVITY_ENABLED and 9.80665 or 0),e.inertiaZ*inertia,998.2})
  row(36,{ax*a,ay*a,az*a,e.airDensity});row(37,{.001002,r.RAIN_FILM_FLOW_CF,evap,.05})
  row(38,{1,0,0,0})
  local names={};for n in pairs(r)do names[#names+1]=n end;table.sort(names);local material={'RealVisor/s152/material_v1\n'}
  for _,n in ipairs(names)do material[#material+1]=n..'='..(type(r[n])=='number'and string.format('%.17g',r[n])or tostring(r[n]))..'\n'end
  local geometry={'RealVisor/s152/assets_v1\n'};local paths={};for n in pairs(files)do paths[#paths+1]=n end;table.sort(paths);for _,n in ipairs(paths)do geometry[#geometry+1]=n..'='..files[n]..'\n'end
  local physicalUnit=.001/r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM/sample.physicalScale
  -- Actual KN5 units govern physics. Display-only gains are intentionally absent.
  local unitRows={{physicalUnit,r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM,sample.physicalScale^2,assets.localAreaM2*sample.physicalScale^2},
   {r.RAIN_FILM_MICRO_JOIN_UM,r.RAIN_AIRFLOW_DOWNWARD_MODE and 1 or 0,r.RAIN_AIRFLOW_DOWNWARD_GAIN,0}}
  local canonical={'RealVisor/s152/header_rows_v1\n'};for _,v in ipairs(rows)do for _,n in ipairs(v)do canonical[#canonical+1]=Base.hex32(n)end end
  for _,v in ipairs(unitRows)do for j,n in ipairs(v)do v[j]=f(n);canonical[#canonical+1]=Base.hex32(v[j])end end
  p.canonical=table.concat(canonical);p.contentKey=digest(d.api.checksumSHA256,p.canonical);p.scope='main_app_context_diagnostic_v1';p.materialSource='runtime_settings_snapshot_v1'
  p.settings=r;p.geometryFiles=cp(files);p.geometryKey=digest(d.api.checksumSHA256,table.concat(geometry));p.materialKey=digest(d.api.checksumSHA256,table.concat(material));p.unitRows=unitRows
  local pose={'RealVisor/s152/pose_v1\n'};for _,v in ipairs(sample.pose.rows)do for _,n in ipairs(v)do pose[#pose+1]=Base.hex32(n)end end;p.poseKey=digest(d.api.checksumSHA256,table.concat(pose))
  p.geometryScope='verified_files_only';p.resourceLeaseVerified=false;p.actualGpuExercised=false;p.sourceTickScope='diagnostic_reference_only';p.environment=cp(e)
  p.limitations={'No GPU resource/geometry lease or completion proof','One CPU render-frame snapshot; no solver/stock/clock publication','Airborne birth supply retains existing wind; SI include-wind toggle is separate','No retained wet-field input; source wetOn=0 and poolOn=0','Field transport has no downward-air variant; setting is retained in auxiliary rows only'}
  result=p;phase='captured_cpu'
 end
 local api={}
 function api:setEnabled(v)enabled=v==true;if not enabled then serial=serial+1;if phase=='verifying_assets'then phase='cancelled';pending=0 end end end
 function api:start()local ok,a=pcall(start);if not ok then fail(a);return false end;return a end
 function api:tick()
  if not enabled or phase~='verifying_assets'or pending~=0 then return end
  if next(failures)then local names={};for n in pairs(failures)do names[#names+1]=n end;table.sort(names);fail('asset verification: '..names[1]);return end
  local ok,why=pcall(capture);if not ok then fail(why)end
 end
 function api:status()return{phase=phase,error=errorText,enabled=enabled,used=used,pending=pending,strictCompletion=false,solverAdmission=false,publicClockAdvanced=false,actualGpuExercised=false}end
 function api:result()return cp(result)end
 return api
end
return M
