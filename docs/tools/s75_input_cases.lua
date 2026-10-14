-- Execute actual P0 factory with adversarial API snapshots, then physical-unit invariants.
local function near(a,b,e) assert(type(a)=='number' and math.abs(a-b)<(e or 1e-10),tostring(a)..' vs '..tostring(b)) end
local enum={LightSnow=9,Snow=10,HeavySnow=11,LightSleet=12,Sleet=13,HeavySleet=14,Hail=32}
local sensorH,sensorP=0,0
local api={WeatherType=enum,
    getAirHumidity=function() sensorH=sensorH+1;return .8 end,
    getAirPressure=function() sensorP=sensorP+1;return 101.325 end,
    getConditionsSet=function() error('Raw weather API must not be polled') end}
local p=factory({api=api})
local s={frame=1,dt=1/60,rainIntensity=0,rainWetness=0,rainWater=0,ambientTemperature=20,
    windVelocityKmh={x=36,y=-18},weatherType=15,
    weatherConditions={rainIntensity=.6,rainWetness=.8,rainWater=1,humidity=0,pressure=101325,
        currentType=15,upcomingType=15,transition=0}}
local car={position={x=0,y=1,z=0},velocity={x=10,y=0,z=-5},acceleration={x=0,y=1,z=0},
    side={x=1,y=0,z=0},up={x=0,y=1,z=0},look={x=0,y=0,z=1},angularVelocity={x=0,y=0,z=0}}
assert(p:update(s,car,-1)==p)
assert(p.sources.intensity=='sim' and p.intensity==0 and p.trackWater==0 and p.trackWetness==0)
assert(p.humidity==0 and p.humidityValid and p.dewPointC==nil and p.dewPointStatus=='dry limit')
assert(sensorH==0 and sensorP==0,'A valid zero must not fall back')
near(p.windX,10);near(p.windZ,-5);near(p.airSpeedMS,0)
assert(p.airY==0 and p.sources.humidity=='conditions' and p.sources.pressure=='conditions')
near(p.rawWorldAccelerationY,9.80665)
assert(not p.physicsReady and p.gravityConvention=='unverified' and p.rotationUnits=='unverified')
local verified=factory({api=api,gExcludesGravity=true});verified:update(s,car,-1)
assert(verified.inertiaVerified and verified.gravityConvention=='excludes gravity (P0 observed)')
near(verified.inertiaY,-9.80665);assert(not verified.physicsReady)
local count=p.updates;s.rainIntensity=1;p:update(s,car,-1);assert(p.updates==count and p.intensity==0)
s.frame=2;p:update(s,car,-1);assert(p.intensity==1)
s.frame=3;p:update(s,car,0);assert(p.intensity==0 and p.overrideActive and p.sources.intensity=='test override')
s.frame=4;p:update(s,car,1);assert(p.intensity==1 and p.liquidIntensity==1)
local allSolid=0
for _,id in pairs(enum) do
    s.frame=s.frame+1;s.weatherConditions.currentType=id;s.weatherConditions.upcomingType=id
    p:update(s,car,-1);assert(p.liquidFraction==0 and p.liquidIntensity==0)
    allSolid=allSolid+1
end
assert(allSolid==7)
s.weatherConditions.currentType=7;s.weatherConditions.upcomingType=10;s.weatherConditions.transition=.25
s.frame=s.frame+1;p:update(s,car,-1);near(p.liquidIntensity,.75)
s.weatherConditions.currentType=10;s.weatherConditions.upcomingType=7
s.frame=s.frame+1;p:update(s,car,-1);near(p.liquidIntensity,.25)
s.weatherConditions.currentType=99;s.weatherConditions.upcomingType=99
s.frame=s.frame+1;p:update(s,car,-1);assert(p.liquidIntensity==1,'Unknown enum must not discard live liquid channels')
-- Filter fallback, paired non-finite values, finite bounds, zero puddles, ideal density.
s.rainIntensity=0/0;s.weatherConditions.rainIntensity=.48
s.rainWetness=math.huge;s.weatherConditions.rainWetness=.2
s.rainWater=nil;s.weatherConditions.rainWater=0
s.frame=s.frame+1;p:update(s,car,-1)
assert(p.intensity==.48 and p.sources.intensity=='conditions' and p.trackWetness==.2 and p.trackWater==0)
assert(p.invalidMask==3)
s.rainIntensity=0/0;s.weatherConditions.rainIntensity=0/0
s.rainWetness=nil;s.weatherConditions.rainWetness=nil
s.frame=s.frame+1;p:update(s,car,-1);assert(p.intensity==0 and p.invalidMask==1 and not p.intensityValid)
s.rainIntensity=5;s.weatherConditions.humidity=100;s.weatherConditions.pressure=0
s.frame=s.frame+1;p:update(s,car,-1)
assert(p.intensity==1 and p.clampedMask==49 and not p.humidityValid and not p.pressureValid and p.dewPointC==nil)
-- Missing structure/sensors are conservative and identifiable, not fabricated observations.
local empty=factory({api={}});empty:update({frame=1,dt=0},nil,-1)
assert(empty.intensity==0 and not empty.temperatureValid and not empty.humidityValid and not empty.pressureValid)
assert(not empty.velocityValid and not empty.basisValid and not empty.phaseKnown and not empty.solidEnumAvailable)
assert(empty.sources.humidity=='fallback' and empty.airDensity>0 and empty.dewPointC==nil)
assert(type(empty:format())=='string')
local fallback=factory({api=api})
local noConditions={frame=1,dt=1/60,ambientTemperature=20,rainIntensity=.2}
fallback:update(noConditions,car,-1)
near(fallback.humidity,.8);near(fallback.pressurePa,101325)
assert(fallback.sources.pressure=='API fallback' and fallback.sources.humidity=='API fallback')
local h,pres=sensorH,sensorP
for i=2,10 do noConditions.frame=i;fallback:update(noConditions,car,-1) end
assert(sensorH==h and sensorP==pres,'Fallback queries must be bounded to 5 Hz')
noConditions.frame=11;noConditions.weatherConditions={humidity=0,pressure=101325}
fallback:update(noConditions,car,-1);assert(fallback.humidity==0 and fallback.sources.humidity=='conditions')
local failed=factory({api={WeatherType=enum,getAirHumidity=function() error('not supported') end,
    getAirPressure=function() return 0/0 end}})
failed:update(noConditions,car,-1);assert(not failed.physicsReady)
noConditions.weatherConditions=nil;noConditions.frame=12
failed:update(noConditions,car,-1);assert(failed.sources.humidity=='fallback')
-- Dew point is only an estimate, not an effect trigger or a visor temperature.
s.rainIntensity=0;s.weatherConditions={humidity=1,pressure=101325,currentType=15,upcomingType=15,transition=0}
s.frame=s.frame+1;p:update(s,car,-1);near(p.dewPointC,20)
s.weatherConditions.humidity=.5;s.frame=s.frame+1;p:update(s,car,-1);near(p.dewPointC,9.261106630534236,1e-8)
assert(p.airDensity>1.19 and p.airDensity<1.21 and p.airDensityMeasuredInputs)
-- Raw G conversion and bounded stationary accumulation, including a rotated car basis.
car.velocity={x=0,y=0,z=0};car.acceleration={x=1,y=.5,z=-2}
car.side={x=0,y=0,z=-1};car.look={x=1,y=0,z=0}
s.frame=s.frame+1;p:update(s,car,-1)
near(p.rawWorldAccelerationX,-2*9.80665);near(p.rawWorldAccelerationY,.5*9.80665)
near(p.rawWorldAccelerationZ,-9.80665)
for i=1,1000 do s.frame=s.frame+1;p:update(s,car,-1) end
assert(p.stationaryCount==256 and p.stationaryGx==1 and p.stationaryGy==.5 and p.stationaryGz==-2)
assert(p.gravityConvention=='unverified' and not p.physicsReady)
p:resetStationary();assert(p.stationaryCount==0 and p.stationaryGx==0)
assert(s.rainIntensity==0 and s.weatherConditions.humidity==.5 and car.acceleration.x==1)
local units=unitsFactory()
local maxVolumeError=0
for _,d in ipairs({0,.1,.25,.65,1.15,1.55,2.25,4.5,6.3}) do
    local v=units.volumeMM3(d);near(units.equivalentDiameterMM(v),d)
    for _,theta in ipairs({10,30,60,90,110,150,175}) do
        local a=units.contactRadiusMM(v,theta)
        local e=math.abs(units.capVolumeMM3(a,theta)-v)
        maxVolumeError=math.max(e,maxVolumeError);assert(e<1e-10)
        if theta==90 then near(2*a,d*2^(1/3)) end
    end
end
near(units.massKG(units.volumeMM3(2.25))/units.massKG(units.volumeMM3(.65)),(2.25/.65)^3)
near(units.massKG(1),998.2e-9)
near(units.weber(1,2),998.2*4*.001/.0728)
assert(units.pinningN(1,80,80)==0 and units.pinningN(1,80,110)>0)
assert(units.volumeMM3(-1)==nil and units.massKG(0/0)==nil and units.contactRadiusMM(1,0)==nil)
assert(units.contactRadiusMM(1,180)==nil and units.pinningN(1,110,80)==nil and units.weber(1,-1)==nil)
-- UV skew/scale do not affect the physical displacement, and no appearance gain participates.
local maxMetricError=0
for _,scale in ipairs({.5,1,2}) do
    for _,a in ipairs({.3,.6826666666666666,2}) do
        for _,b in ipairs({-.2,0,.7}) do
            local c=.17066666666666666
            local x,y=units.metricPlane(.03,-.02,a,b,c,scale)
            local U,V=units.metricOffset(x,y,a,b,c,scale)
            maxMetricError=math.max(maxMetricError,math.abs(U-.03),math.abs(V+.02))
            near(U,.03);near(V,-.02)
        end
    end
end
local x,y,area=units.metricCalibration(4096*.001/6,0,1024*.001/6,1,4096,1024)
near(x,6);near(y,6);near(area,1/36)
assert(units.metricOffset(1,1,1,0,0,1)==nil and units.metricPlane(1,1,1,0,1,0)==nil)
-- No canvas, stamp arrays, slot iteration or frame-retained objects in this observer.
local function advance(n) for i=1,n do s.frame=s.frame+1;p:update(s,car,-1) end end
advance(5000) -- Warm this exact LuaJIT call site before checking retained memory.
collectgarbage('collect');local before=collectgarbage('count');local t0=os.clock()
advance(40000)
local elapsed=os.clock()-t0;collectgarbage('collect');local growth=collectgarbage('count')-before
assert(growth<16,'Observer retained '..tostring(growth)..' KiB')
return {solid_types=allSolid,zero_missing_nan_range_contract=true,weather_phase_blend=true,
    pressure_kpa_to_pa=true,bounded_fallback_queries=true,raw_g_basis_and_no_auto_promotion=true,
    cap_geometry_max_error_mm3=maxVolumeError,metric_roundtrip_max_error=maxMetricError,
    observer_40000_updates_seconds=elapsed,observer_retained_growth_KiB=growth,
    whole_luajit_syntax=true,live_physics_not_changed=true}
