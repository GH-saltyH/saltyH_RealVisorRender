-- P0: independent weather/units observer. No Smear, state or render side effects.
-- SDK: ac.StateSim + filtered weatherConditions (ac.ConditionsSet).
return function(d)
    d=d or {}
    local api=d.api or {};local types=api.WeatherType or {}
    local solid={}
    for _,key in ipairs({'LightSnow','Snow','HeavySnow','LightSleet','Sleet','HeavySleet','Hail'}) do
        if type(types[key])=='number' then solid[types[key]]=true end
    end
    local st={updates=0,elapsed=0,slowAt=-1,invalidMask=0,clampedMask=0,
        sources={},stationaryCount=0,stationaryGx=0,stationaryGy=0,stationaryGz=0,
        gravityConvention=d.gExcludesGravity==true and 'excludes gravity (P0 observed)' or 'unverified',
        rotationUnits='unverified',physicsReady=false}
    local function finite(x) return type(x)=='number' and x==x and x>-math.huge and x<math.huge end
    local function clamp(x,lo,hi) return math.max(lo,math.min(hi,x)) end
    local function mark(value,flag) return math.floor(value/flag)%2==0 and value+flag or value end
    local function vector(v)
        if v and finite(v.x) and finite(v.y) and finite(v.z) then return v.x,v.y,v.z,true end
        return 0,0,0,false
    end
    local function read(self,key,a,b,fallback,lo,hi,flag)
        local v,source=a,'sim'
        if not finite(v) then
            if v~=nil then self.invalidMask=mark(self.invalidMask,flag) end
            v,source=b,'conditions'
        end
        if not finite(v) then
            if v~=nil then self.invalidMask=mark(self.invalidMask,flag) end
            self.sources[key]='fallback';return fallback,false
        end
        local valid=v>=lo and v<=hi
        if not valid then self.clampedMask=mark(self.clampedMask,flag) end
        self.sources[key]=source
        return clamp(v,lo,hi),valid
    end
    local function liquid(t) return solid[t] and 0 or 1 end
    function st:resetStationary()
        self.stationaryCount=0;self.stationaryGx=0;self.stationaryGy=0;self.stationaryGz=0
    end
    function st:update(sim,car,override)
        if not sim then return self end
        if sim.frame~=nil and self.frame==sim.frame then return self end
        self.frame=sim.frame;self.updates=self.updates+1
        self.invalidMask=0;self.clampedMask=0
        local c=sim.weatherConditions
        self.dt=finite(sim.dt) and math.max(sim.dt,0) or 0
        self.elapsed=self.elapsed+math.min(self.dt,.25)
        self.intensity,self.intensityValid=read(self,'intensity',sim.rainIntensity,c and c.rainIntensity,0,0,1,1)
        self.rawIntensity=c and finite(c.rainIntensity) and c.rainIntensity or nil
        self.overrideActive=finite(override) and override>=0
        if self.overrideActive then self.intensity=clamp(override,0,1);self.sources.intensity='test override' end
        self.trackWetness,self.trackWetnessValid=read(self,'trackWetness',sim.rainWetness,c and c.rainWetness,0,0,1,2)
        self.trackWater,self.trackWaterValid=read(self,'trackWater',sim.rainWater,c and c.rainWater,0,0,1,4)
        self.temperatureC,self.temperatureValid=read(self,'temperature',sim.ambientTemperature,
            c and c.temperatures and c.temperatures.ambient,20,-40,60,8)
        self.currentType=c and finite(c.currentType) and c.currentType
            or (finite(sim.weatherType) and sim.weatherType or nil)
        self.upcomingType=c and finite(c.upcomingType) and c.upcomingType or self.currentType
        self.transition=c and finite(c.transition) and clamp(c.transition,0,1) or 0
        self.phaseKnown=self.currentType~=nil
        self.solidEnumAvailable=solid[types.Snow or -1]==true and solid[types.Sleet or -1]==true
        self.liquidFraction=liquid(self.currentType)*(1-self.transition)+liquid(self.upcomingType)*self.transition
        self.liquidIntensity=self.intensity*self.liquidFraction
        -- Slow fallback sensors are optional and cached. A valid zero wins.
        if self.elapsed>=self.slowAt then
            self.slowAt=self.elapsed+.2
            local pos=car and car.position
            self.apiHumidity=nil;self.apiPressurePa=nil
            if pos and not (c and finite(c.humidity)) and type(api.getAirHumidity)=='function' then
                local ok,v=pcall(api.getAirHumidity,pos)
                if ok and finite(v) then self.apiHumidity=v end
            end
            if pos and not (c and finite(c.pressure)) and type(api.getAirPressure)=='function' then
                local ok,v=pcall(api.getAirPressure,pos)
                if ok and finite(v) then self.apiPressurePa=v*1000 end -- API kPa -> Pa
            end
        end
        self.humidity,self.humidityValid=read(self,'humidity',c and c.humidity,self.apiHumidity,.5,0,1,16)
        if self.sources.humidity=='sim' then self.sources.humidity='conditions'
        elseif self.sources.humidity=='conditions' then self.sources.humidity='API fallback' end
        self.pressurePa,self.pressureValid=read(self,'pressure',c and c.pressure,self.apiPressurePa,101325,20000,120000,32)
        if self.sources.pressure=='sim' then self.sources.pressure='conditions'
        elseif self.sources.pressure=='conditions' then self.sources.pressure='API fallback' end
        self.dewPointC=nil
        if self.humidityValid and self.temperatureValid and self.humidity>0 then
            -- Water-vapour Magnus approximation, Alduchov/Eskridge 1996.
            local g=math.log(self.humidity)+17.625*self.temperatureC/(243.04+self.temperatureC)
            self.dewPointC=243.04*g/(17.625-g)
        end
        self.dewPointStatus=self.dewPointC and 'estimated; visor temperature unavailable'
            or (self.humidityValid and self.humidity==0 and 'dry limit' or 'inputs unavailable')
        -- Ideal moist-air density estimate; not a measurement at the visor.
        local vapour=self.humidityValid and self.temperatureValid
            and self.humidity*610.94*math.exp(17.625*self.temperatureC/(243.04+self.temperatureC)) or 0
        vapour=math.min(vapour,self.pressurePa*.9)
        local tk=self.temperatureC+273.15
        self.airDensity=(self.pressurePa-vapour)/(287.05*tk)+vapour/(461.5*tk)
        self.airDensityMeasuredInputs=self.pressureValid and self.temperatureValid and self.humidityValid
        local wind=sim.windVelocityKmh
        self.windValid=wind~=nil and finite(wind.x) and finite(wind.y)
        self.windX=self.windValid and wind.x/3.6 or 0;self.windY=0
        self.windZ=self.windValid and wind.y/3.6 or 0 -- SDK game-space vec2 (x,z)
        self.velocityX,self.velocityY,self.velocityZ,self.velocityValid=vector(car and car.velocity)
        self.airX=self.windX-self.velocityX;self.airY=-self.velocityY;self.airZ=self.windZ-self.velocityZ
        self.airSpeedMS=math.sqrt(self.airX*self.airX+self.airY*self.airY+self.airZ*self.airZ)
        self.carSpeedMS=math.sqrt(self.velocityX*self.velocityX+self.velocityY*self.velocityY+self.velocityZ*self.velocityZ)
        self.carGx,self.carGy,self.carGz,self.carGValid=vector(car and car.acceleration)
        local sx,sy,sz,side=vector(car and car.side)
        local ux,uy,uz,up=vector(car and car.up)
        local lx,ly,lz,look=vector(car and car.look)
        self.basisValid=side and up and look
        self.rawWorldGx=sx*self.carGx+ux*self.carGy+lx*self.carGz
        self.rawWorldGy=sy*self.carGx+uy*self.carGy+ly*self.carGz
        self.rawWorldGz=sz*self.carGx+uz*self.carGy+lz*self.carGz
        self.rawWorldAccelerationX=self.rawWorldGx*9.80665
        self.rawWorldAccelerationY=self.rawWorldGy*9.80665
        self.rawWorldAccelerationZ=self.rawWorldGz*9.80665
        self.inertiaVerified=d.gExcludesGravity==true and self.carGValid and self.basisValid
        self.inertiaX=-self.rawWorldAccelerationX;self.inertiaY=-self.rawWorldAccelerationY
        self.inertiaZ=-self.rawWorldAccelerationZ
        -- Observe the stationary convention; never silently subtract gravity or
        -- promote a guessed convention to the new physics engine.
        if self.velocityValid and self.carSpeedMS<.15 and self.carGValid then
            self.stationaryCount=math.min(self.stationaryCount+1,256)
            local a=1/self.stationaryCount
            self.stationaryGx=self.stationaryGx+(self.carGx-self.stationaryGx)*a
            self.stationaryGy=self.stationaryGy+(self.carGy-self.stationaryGy)*a
            self.stationaryGz=self.stationaryGz+(self.carGz-self.stationaryGz)*a
        end
        self.rotationX,self.rotationY,self.rotationZ,self.rotationPresent=vector(car and car.angularVelocity)
        self.physicsReady=false -- P0 observer only; no unverified force feeds
        return self
    end
    function st:format()
        return string.format('Rain P0 frame=%s I=%.6f raw=%s liquid=%.6f type=%s>%s t=%.3f wet=%.4f water=%.4f\n'
            ..'RH=%.4f (%s) T=%.3f C (%s) p=%.2f Pa (%s) dew=%s rho=%.6f kg/m3\n'
            ..'wind=(%.4f,%.4f,%.4f) m/s air=(%.4f,%.4f,%.4f) m/s car=%.4f m/s\n'
            ..'car G=(%.5f,%.5f,%.5f) raw world xg=(%.5f,%.5f,%.5f) m/s2\n'
            ..'inertia=(%.5f,%.5f,%.5f) m/s2 verified=%s\n'
            ..'stationary n=%d mean G=(%.5f,%.5f,%.5f) convention=%s rotation=%s invalid=%d capped=%d',
            tostring(self.frame),self.intensity or 0,tostring(self.rawIntensity),self.liquidIntensity or 0,
            tostring(self.currentType),tostring(self.upcomingType),self.transition or 0,self.trackWetness or 0,self.trackWater or 0,
            self.humidity or .5,self.sources.humidity or 'pending',self.temperatureC or 20,self.sources.temperature or 'pending',
            self.pressurePa or 101325,self.sources.pressure or 'pending',tostring(self.dewPointC),self.airDensity or 0,
            self.windX or 0,self.windY or 0,self.windZ or 0,self.airX or 0,self.airY or 0,self.airZ or 0,self.carSpeedMS or 0,
            self.carGx or 0,self.carGy or 0,self.carGz or 0,self.rawWorldAccelerationX or 0,self.rawWorldAccelerationY or 0,
            self.rawWorldAccelerationZ or 0,self.inertiaX or 0,self.inertiaY or 0,self.inertiaZ or 0,
            tostring(self.inertiaVerified),self.stationaryCount,self.stationaryGx,self.stationaryGy,self.stationaryGz,
            self.gravityConvention,self.rotationUnits,self.invalidMask,self.clampedMask)
    end
    return st
end
