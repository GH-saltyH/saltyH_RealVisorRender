-- P2 bounded GPU source and cumulative reservoir budget. No CPU drop stamping.
return function(d)
    local r=d.runtime;local st={epoch=0,tick=0,ready=false,pending=false}
    local function code(name)
        local f=assert(io.open(d.folder..'/shaders/'..name..'.hlsl','rb'));local s=f:read('*a');f:close()
        return '#line 1 "RealVisor/'..name..'.hlsl"\n'..s
    end
    st.eventCode=d.surface.shader..d.core..code('rainBirthEvent')
    st.blockCode=code('rainBirthBlocks');st.totalCode=code('rainBirthTotals');st.statsCode=code('rainBirthStats')
    local folder=d.folder..'/texture/RAIN_BIRTH/'
    local geometry=assert(loadfile(folder..'geometry.lua'))()
    assert(geometry.version=='rain-birth-v1','P2 geometry contract version mismatch')
    local f=assert(io.open(d.surface.root..'surface.verify','rb'))
    local model=(f:read('*l') or ''):gsub('\r$','');local mask=(f:read('*l') or ''):gsub('\r$','');f:close()
    assert(model==geometry.modelHash and mask==geometry.maskHash,'P2 physical area is stale: rebuild birth assets')
    st.localAreaM2=geometry.areaM2
    -- Four small async checks once, never scan full geometry atlases on frame updates.
    st.assetPending=0
    for _,expected in pairs(geometry.hashes) do st.assetPending=st.assetPending+1 end
    for relative,expected in pairs(geometry.hashes) do
        local path,hash=relative,expected
        io.checksumSHA256(d.folder..'/'..path,function(err,actual)
            if err or actual~=hash then st.assetError='P2 asset/source mismatch: '..path..'; rebuild birth assets and reload' end
            st.assetPending=st.assetPending-1
        end)
    end
    st.eventParams={async=true,blendMode=render.BlendMode.Opaque,shader=st.eventCode,values={
        gBirthCount=1,gBirthTick=0,gBirthBlocks=1,gBirthDt=0,gBirthAreaM2=geometry.areaM2,
        gBirthNumberDensity=0,gBirthWeights=vec4(1,0,0,0),gBirthAirWorld=vec3(),
        gBirthObjectToWorld=mat4x4.identity(),gBirthNormalSign=1,gBirthExposure=1,
        gBirthIncidentAirFraction=1,gBirthTangentFraction=0,gBirthWetOverride=0,gBirthMinPersistentMM=.25,
        gBirthRhoWater=998.2,gBirthMu=.001002,gBirthGamma=.0728,gBirthTheta=90,
        gBirthAdvanceBare=100,gBirthAdvanceCoat=92},textures={
        txBirthDsd=folder..'dsd.dds',txBirthImpact=folder..'impact_estimated.dds',
        txBirthSites=folder..'sites.dds',
        txRainState=false,txRainStateMeta=false}}
    d.surface:bind(st.eventParams)
    st.blockParams={async=true,blendMode=render.BlendMode.Opaque,shader=st.blockCode,
        values={gBirthCount=1,gBirthBlocks=1},textures={txBirthEvent=false,txRainNewMeta=false}}
    st.totalParams={async=true,blendMode=render.BlendMode.Opaque,shader=st.totalCode,
        values={gBirthBlocks=1},textures={txBirthBlocks=false,txBirthPreviousTotals=false}}
    st.statsParams={async=true,blendMode=render.BlendMode.Opaque,shader=st.statsCode,
        textures={txBirthTotals=false},values={}}
    local function canvas(w,h,format,name)
        local c=ui.ExtraCanvas(vec2(w,h),1,render.AntialiasingMode.None,format)
        c:setName(name);c:clear(rgbm(0,0,0,0));return c
    end
    function st:dispose()
        self.epoch=self.epoch+1
        for _,name in ipairs({'events','blocks','totalsA','totalsB','stats'}) do
            if self[name] then self[name]:dispose();self[name]=nil end
        end
        self.count=nil;self.tick=0;self.ready=false;self.preparedFrame=nil;self.read=nil
        self.pending=false;self.logPending=false;self.logValues=nil;self.budgetFrame=nil;self.frame=nil
        self.eventParams.textures.txRainState=false;self.eventParams.textures.txRainStateMeta=false
        self.blockParams.textures.txBirthEvent=false;self.blockParams.textures.txRainNewMeta=false
        self.totalParams.textures.txBirthBlocks=false;self.totalParams.textures.txBirthPreviousTotals=false
        self.statsParams.textures.txBirthTotals=false
    end
    function st:prepare(state,meta,count,sim,transform,model)
        self.preparedFrame=nil
        self.budgetFrame=nil
        if self.frame==sim.frame then return false end
        if self.assetPending>0 or self.assetError then self.pending=true;return false end
        if count<1 or count>4096 or count~=math.floor(count) then
            self.error='P2 preview supports 1..4096 integer slots';return false
        end
        self.error=nil
        if self.count~=count then
            self:dispose();self.blockCount=math.ceil(count/64)
            self.events=canvas(count,4,render.TextureFormat.R32G32B32A32.Float,'P2 immutable birth events')
            self.blocks=canvas(self.blockCount,2,render.TextureFormat.R32G32B32A32.Float,'P2 budget reduction')
            self.totalsA=canvas(1,4,render.TextureFormat.R32G32B32A32.Float,'P2 budget A')
            self.totalsB=canvas(1,4,render.TextureFormat.R32G32B32A32.Float,'P2 budget B')
            self.read=self.totalsA;self.count=count
        end
        local p=self.eventParams;local v=p.values
        v.gBirthCount=count;v.gBirthTick=self.tick;v.gBirthDt=math.max(sim.dt or 0,0)
        v.gBirthAreaM2=self.localAreaM2*d.surface.scale^2;v.gBirthNumberDensity=model.numberDensityM3
        v.gBirthWeights:set(model.weights[1],model.weights[2],model.weights[3],model.weights[4])
        v.gBirthAirWorld:set(model.airX,model.airY,model.airZ);v.gBirthObjectToWorld=transform
        v.gBirthNormalSign=r.RAIN_BIRTH_NORMAL_REVERSED and -1 or 1
        v.gBirthExposure=r.RAIN_BIRTH_EXPOSURE;v.gBirthIncidentAirFraction=r.RAIN_BIRTH_INCIDENT_AIR_FRACTION
        v.gBirthTangentFraction=r.RAIN_BIRTH_TANGENT_IMPULSE_FRACTION
        v.gBirthWetOverride=r.RAIN_BIRTH_WET_OVERRIDE;v.gBirthMinPersistentMM=r.RAIN_BIRTH_MIN_PERSISTENT_MM
        v.gBirthTheta=r.RAIN_PHYSICS_CONTACT_ANGLE_DEG
        v.gBirthAdvanceBare=math.min(179.9,math.max(.1,v.gBirthTheta+r.RAIN_PHYSICS_STATIC_SPAN_BARE_DEG*.5))
        v.gBirthAdvanceCoat=math.min(179.9,math.max(.1,v.gBirthTheta+r.RAIN_PHYSICS_STATIC_SPAN_COAT_DEG*.5))
        p.textures.txRainState=state;p.textures.txRainStateMeta=meta;d.surface:bind(p)
        if d.measure('P2 birth events',self.events.updateWithShader,self.events,p)==false then self.pending=true;return false end
        self.preparedFrame=sim.frame;self.pending=false;return true
    end
    function st:budget(newMeta,sim)
        if self.preparedFrame~=sim.frame then return false end
        local p=self.blockParams;p.values.gBirthCount=self.count;p.values.gBirthBlocks=self.blockCount
        p.textures.txBirthEvent=self.events;p.textures.txRainNewMeta=newMeta
        if d.measure('P2 budget blocks',self.blocks.updateWithShader,self.blocks,p)==false then self.pending=true;return false end
        local p=self.totalParams;p.values.gBirthBlocks=self.blockCount
        p.textures.txBirthBlocks=self.blocks;p.textures.txBirthPreviousTotals=self.read
        self.write=self.read==self.totalsA and self.totalsB or self.totalsA
        if d.measure('P2 budget totals',self.write.updateWithShader,self.write,p)==false then self.pending=true;return false end
        self.budgetFrame=sim.frame;return true
    end
    function st:publish(sim)
        if self.budgetFrame~=sim.frame or self.frame==sim.frame then return false end
        self.read=self.write;self.tick=(self.tick+1)%1048576;self.ready=true;self.frame=sim.frame;self.pending=false
        self.publishedAreaM2=self.eventParams.values.gBirthAreaM2
        self.budgetFrame=nil;self.preparedFrame=nil
        return true
    end
    function st:logBudget()
        if not self.ready or self.logPending then return false end
        if not self.stats then self.stats=canvas(8,1,render.TextureFormat.R32.Float,'P2 manual budget readback') end
        self.statsParams.textures.txBirthTotals=self.read
        if self.stats:updateWithShader(self.statsParams)==false then return false end
        self.logPending=true;local epoch=self.epoch;local frame=self.frame;local area=self.publishedAreaM2
        self.stats:accessData(function(err,data)
            if epoch~=self.epoch then if data then data:dispose() end;return end
            self.logPending=false
            if err or not data then if data then data:dispose() end;d.log('P2 budget readback failed: '..tostring(err));return end
            local v=self.logValues or {};for i=1,8 do v[i]=data:floatValue(i-1,0) end
            data:dispose();self.logValues=v
            local residual=v[1]-v[2]-v[3]-v[4]-v[5]-v[6]-v[7]
            d.log(string.format('Rain P2 frame=%s mm3 input=%.6f film-reserve=%.6f micro-reserve=%.6f bounce=%.6f capacity=%.6f exit=%.6f drops=%.6f residual=%.6f arrivals=%.0f area=%.6f m2',
                tostring(frame),v[1],v[2],v[3],v[4],v[5],v[6],v[7],residual,v[8],area))
        end)
        return true
    end
    return st
end
