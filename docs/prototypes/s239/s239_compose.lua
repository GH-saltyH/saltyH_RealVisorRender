-- Existing s152 physical rows; material/assets hashes are retained from bootstrap.
local M={}
local function cp(v)if type(v)~='table'then return v end;local o={};for k,x in pairs(v)do o[k]=cp(x)end;return o end
local function need(v,s)assert(v,s)end
local function digest(checksum,text)
 local v=checksum(text);need(type(v)=='string','checksum result');if #v==32 then v=v:gsub('.',function(x)return string.format('%02x',x:byte())end)else v=v:lower()end
 need(#v==64 and not v:find('[^0-9a-f]'),'SHA256 result');return v
end
local function compose(d,sample,identity)
 local r,assets,files=d.settings,d.assets,d.seed.geometryFiles
 local x={count=d.seed.rows[2][4]}
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
  local physicalUnit=.001/r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM/sample.physicalScale
  -- Actual KN5 units govern physics. Display-only gains are intentionally absent.
  local unitRows={{physicalUnit,r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM,sample.physicalScale^2,assets.localAreaM2*sample.physicalScale^2},
   {r.RAIN_FILM_MICRO_JOIN_UM,r.RAIN_AIRFLOW_DOWNWARD_MODE and 1 or 0,r.RAIN_AIRFLOW_DOWNWARD_GAIN,0}}
  for _,v in ipairs(unitRows)do for j,n in ipairs(v)do v[j]=f(n)end end
  p.canonical,p.contentKey,p.poseKey=identity(rows,unitRows)
  p.scope='main_app_context_diagnostic_v1';p.materialSource='runtime_settings_snapshot_v1'
  p.settings=cp(r);p.geometryFiles=cp(files);p.geometryKey=d.seed.geometryKey;p.materialKey=d.seed.materialKey;p.unitRows=unitRows
  p.geometryScope='verified_files_only';p.resourceLeaseVerified=false;p.actualGpuExercised=false;p.sourceTickScope='persistent_capture_cpu_v1';p.environment=cp(e)
  p.limitations={'No GPU resource/geometry lease or completion proof','One CPU render-frame snapshot; no solver/stock/clock publication','Airborne birth supply retains existing wind; SI include-wind toggle is separate','No retained wet-field input; source wetOn=0 and poolOn=0','Field transport has no downward-air variant; setting is retained in auxiliary rows only'}
 p.captureScope='persistent_engine_capture_cpu_v1';return p
end
-- Cache only private scalar witnesses and immutable row strings, never caller
-- tables. Equality distinguishes signed zero; all input rows are finite FP32.
local function equal(a,b)return a==b and(a~=0 or 1/a==1/b)end
function M.new(d,options)
 options=options or{};local clock=options.clock;local cache={};local frames,encoded,reused=0,0,0
 local last;local begin;local api={}
 local function identity(rows,units)
  assert(#rows==50 and #units==2,'physical header shape')
  local buildEnd=clock and clock();local text={};local fresh,hits=0,0
  for i=1,52 do
   local row=i<=50 and rows[i]or units[i-50];local saved=cache[i]
   if saved and equal(row[1],saved[1])and equal(row[2],saved[2])and equal(row[3],saved[3])and equal(row[4],saved[4])then
    text[i]=saved[5];hits=hits+1
   else
    local hex=d.Packet.hex32(row[1])..d.Packet.hex32(row[2])..d.Packet.hex32(row[3])..d.Packet.hex32(row[4])
    cache[i]={row[1],row[2],row[3],row[4],hex};text[i]=hex;fresh=fresh+1
   end
  end
  local canonical='RealVisor/s152/header_rows_v1\n'..table.concat(text)
  -- Pose rows14..17 already contain the exact FP32 version of sample.pose.
  local pose='RealVisor/s152/pose_v1\n'..text[14]..text[15]..text[16]..text[17]
  local encodeEnd=clock and clock()
  local key=digest(d.api.checksumSHA256,canonical);local poseKey=digest(d.api.checksumSHA256,pose)
  local hashEnd=clock and clock()
  frames=frames+1;encoded=encoded+fresh;reused=reused+hits
  last={rowsEncoded=fresh,rowsReused=hits}
  if clock then last.buildSeconds=buildEnd-begin;last.encodeSeconds=encodeEnd-buildEnd;last.hashSeconds=hashEnd-encodeEnd;last.hashEnd=hashEnd end
  return canonical,key,poseKey
 end
 function api:compose(sample)
  begin=clock and clock();local p=compose(d,sample,identity)
  if clock then local finish=clock();last.tailSeconds=finish-last.hashEnd;last.hashEnd=nil;last.totalSeconds=finish-begin end
  return p
 end
 function api:status()return{frames=frames,rowsEncoded=encoded,rowsReused=reused,cacheSlots=#cache,headerHashes=frames,poseHashes=frames,last=cp(last),timingEnabled=clock~=nil}end
 return api
end
-- Compatibility entry point is deliberately uncached. Live owners retain new().
function M.compose(d,sample)return M.new(d):compose(sample)end
return M
