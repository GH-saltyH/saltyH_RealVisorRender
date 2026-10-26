-- One coherent engine observation; no engine writes or solver admission.
local Environment=require('rain_environment');local Birth=require('rain_birth_model');local M={}
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function cp(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=cp(x)end;return t end
local function vector(v)assert(v and finite(v.x)and finite(v.y)and finite(v.z),'engine vector');return{x=v.x,y=v.y,z=v.z}end
function M.new(api,options)
 options=options or{};local environment=Environment({api=api,gExcludesGravity=options.gExcludesGravity==true});local birth=Birth();local previous
 local function take(poseProvider)
  local sim=assert(api.getSim(),'sim unavailable');local frame=sim.frame;local dt=sim.dt
  if not finite(frame)or frame~=math.floor(frame)or frame<1 or frame>16777215 then return nil,'frame_unavailable'end
  if not finite(dt)or dt<0 then return nil,'invalid_dt'end
  if dt==0 then return nil,'paused'end
  if dt>.05 then return nil,'interval_too_long'end -- never truncate elapsed time
  if previous==frame then return nil,'duplicate_frame'end
  local index=sim.focusedCar;if not finite(index)or index<0 or index~=math.floor(index)then return nil,'car_unavailable'end
  local car=api.getCar(index);if not car then return nil,'car_unavailable'end
  local c=sim.weatherConditions;local weather
  if c then weather={rainIntensity=c.rainIntensity,rainWetness=c.rainWetness,rainWater=c.rainWater,humidity=c.humidity,pressure=c.pressure,currentType=c.currentType,upcomingType=c.upcomingType,transition=c.transition,temperatures=c.temperatures and{ambient=c.temperatures.ambient}or nil}end
  local s={frame=frame,dt=dt,rainIntensity=sim.rainIntensity,rainWetness=sim.rainWetness,rainWater=sim.rainWater,ambientTemperature=sim.ambientTemperature,weatherType=sim.weatherType,weatherConditions=weather,windVelocityKmh=sim.windVelocityKmh and{x=sim.windVelocityKmh.x,y=sim.windVelocityKmh.y}or nil}
  local vehicle={};for _,n in ipairs({'position','velocity','acceleration','side','up','look'})do vehicle[n]=vector(car[n])end
  local pose
  if poseProvider then pose=poseProvider(frame,index)
  else local p=vehicle.position;local a,b,c=vehicle.side,vehicle.up,vehicle.look;pose={scope='car_reference_only',frame=frame,rows={{a.x,a.y,a.z,0},{b.x,b.y,b.z,0},{c.x,c.y,c.z,0},{p.x,p.y,p.z,1}}}end
  if sim.frame~=frame then return nil,'frame_changed'end
  assert(type(pose)=='table'and pose.frame==frame and(pose.scope=='car_reference_only'or pose.scope=='visor_model_world_v1'),'pose provenance')
  assert(type(pose.rows)=='table'and #pose.rows==4,'pose rows')
  local lengths={}
  for i,row in ipairs(pose.rows)do assert(#row==4,'pose row');for _,v in ipairs(row)do assert(finite(v),'pose finite')end;if i<=3 then lengths[i]=row[1]^2+row[2]^2+row[3]^2;assert(row[4]==0,'pose basis w')else assert(row[4]==1,'pose affine w')end end
  assert(lengths[1]>1e-12 and math.abs(lengths[1]-lengths[2])<=lengths[1]*1e-4 and math.abs(lengths[1]-lengths[3])<=lengths[1]*1e-4,'uniform physical scale')
  for i=1,2 do for j=i+1,3 do local a,b=pose.rows[i],pose.rows[j];assert(math.abs(a[1]*b[1]+a[2]*b[2]+a[3]*b[3])<=lengths[1]*1e-4,'pose orthogonality')end end
  local a,b,c=pose.rows[1],pose.rows[2],pose.rows[3];assert(a[1]*(b[2]*c[3]-b[3]*c[2])-a[2]*(b[1]*c[3]-b[3]*c[1])+a[3]*(b[1]*c[2]-b[2]*c[1])>0,'pose handedness')
  local e=environment:update(s,vehicle)
  if not(e.windValid and e.velocityValid and e.inertiaVerified and e.phaseKnown and e.solidEnumAvailable and e.airDensityMeasuredInputs and e.intensityValid and e.trackWetnessValid and e.trackWaterValid)or e.invalidMask~=0 or e.clampedMask~=0 then return nil,'unverified_engine_inputs'end
  birth:update(e,options.rateAtOne or 20,options.ratePower or 1,0)
  local sample={scope='engine_observation_v1',frame=frame,frameAfter=sim.frame,carIndex=index,rawDt=dt,pose=cp(pose),environment={},supply={weights=cp(birth.weights),numberDensityM3=birth.numberDensityM3,rateMMH=birth.rateMMH},physicalScale=math.sqrt(lengths[1]),strictCompletion=false,solverAdmission=false}
  for _,n in ipairs({'intensity','trackWetness','trackWater','humidity','temperatureC','pressurePa','airDensity','liquidFraction','liquidIntensity','windX','windY','windZ','velocityX','velocityY','velocityZ','airX','airY','airZ','carSpeedMS','inertiaX','inertiaY','inertiaZ','currentType','upcomingType','transition','invalidMask','clampedMask'})do sample.environment[n]=e[n]end
  previous=frame;return sample,'captured'
 end
 return{capture=function(_,poseProvider)local ok,a,b=pcall(take,poseProvider);if not ok then return nil,tostring(a)end;return a,b end}
end
return M
