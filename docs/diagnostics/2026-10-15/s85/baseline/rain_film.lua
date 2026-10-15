-- P3 spatial volume, paired head transfer, explicit evaporation/runoff.
-- All canvases are persistent; no CPU drop stamps or automatic readbacks.
return function(d)
    local r=d.runtime;local st={epoch=0,ready=false,pending=false}
    local geometry=assert(loadfile(d.folder..'/texture/RAIN_FILM/geometry.lua'))()
    assert(geometry.version=='rain-film-v1' and geometry.width==1024 and geometry.height==256 and geometry.pad==16,'P3 field contract mismatch')
    local f=assert(io.open(d.surface.root..'surface.verify','rb'))
    local model=(f:read('*l') or ''):gsub('\r$','');local mask=(f:read('*l') or ''):gsub('\r$','');f:close()
    assert(model==geometry.modelHash and mask==geometry.maskHash,'P3 cell area stale: rebuild film cells')
    st.assetPending=true
    io.checksumSHA256(d.folder..'/texture/RAIN_FILM/cells.dds',function(err,hash)
        st.assetPending=false
        if err or hash~=geometry.cellsHash then st.assetError='P3 cells hash mismatch: rebuild film cells and reload' end
    end)
    local function code(name)
        local f=assert(io.open(d.folder..'/shaders/'..name..'.hlsl','rb'))
        local s=f:read('*a');f:close();return '#line 1 "RealVisor/'..name..'.hlsl"\n'..s
    end
    local traversal=d.traversal
    local function replace(old,new)
        local a,b=traversal:find(old,1,true)
        assert(a,'P3 sparse traversal contract missing: '..old)
        assert(not traversal:find(old,b+1,true),'P3 traversal anchor is not unique')
        traversal=traversal:sub(1,a-1)..new..traversal:sub(b+1)
    end
    replace('    if(rainValid(float2(pin.Tex.x,pin.Tex.y-1))<.5) return 0;','')
    replace('    float2 px = tex * gSize;','    float2 px = floor(tex*gFilmPaddedSize);')
    replace('    acc *= rainValid(float2(pin.Tex.x,pin.Tex.y-1));','')
    replace('    return acc;','    return pfResolve(px,acc);')
    local values={gFilmCount=1,gFilmGrid=vec2(1024,256),gFilmPad=16,gFilmPaddedSize=vec2(1056,288),
        gFilmReductionSize=vec2(66,18),gFilmScale2=1,gFilmDt=0,gFilmMotionDt=0,gFilmTheta=90,
        gFilmMu=.001002,gFilmGamma=.0728,gFilmAirMS=0,gFilmEvapUMS=0,gFilmMicroJoinUM=20,
        gFilmDepositBare=.35,gFilmDepositCoat=.05,gFilmMinSpeedMS=.001,gFilmWiden=.5,
        gFilmFlowOn=0,gFilmFlowCf=.005,gFilmFlowCFL=.8,gFilmFlowReduce=0,
        gFilmObjectToWorld=mat4x4.identity(),gFilmAccelerationWorld=vec3(0,-9.80665,0),
        gFilmAirWorld=vec3(),gFilmAirRho=1.2,gFilmAirDownward=0,gFilmAirDownwardGain=1,
        gCount=1,gTile=vec2(32,32),gTilesX=33,gTilesY=9,gWords=1,gMaskW=33,
        gSummaryW=33,gSummaryWords=1,gSparseWords=1,gFlipY=0,gDebug=0}
    st.values=values
    local function params(shader,tx) return {async=true,blendMode=render.BlendMode.Opaque,values=values,shader=shader,textures=tx} end
    st.descriptorParams=params(d.surface.shader..d.core..code('rainFilmDescriptor'),{
        txFilmNewState=false,txFilmNewMeta=false,txFilmOldState=false,txFilmOldMeta=false,txFilmBirthEvent=false})
    st.metaParams=params(d.core..code('rainFilmMeta'),{txFilmNewMeta=false,txFilmDescriptors=false})
    d.surface:bind(st.descriptorParams);d.surface:bind(st.metaParams)
    st.binParams=params(code('rainFilmBin'),{txFilmDescriptors=false})
    st.summaryParams=params(d.summary,{txMask=false})
    st.resolveParams=params(code('rainFilmResolve')..traversal,{txFilmDescriptors=false,txMask=false,txSummary=false,
        txFilmPrevious=false,txFilmFlux=false,txFilmCells=d.folder..'/texture/RAIN_FILM/cells.dds'})
    local flowCode=d.surface.shader..d.core..code('rainFilmFlow')
    st.flowParams=params(flowCode..code('rainFilmFlowPass'),{
        txFilmPrevious=false,txFilmCells=d.folder..'/texture/RAIN_FILM/cells.dds'})
    st.flowBlocksParams=params(flowCode..code('rainFilmFlowBlocks'),{
        txFilmPrevious=false,txFilmFlowBlocks=false,txFilmCells=d.folder..'/texture/RAIN_FILM/cells.dds'})
    d.surface:bind(st.flowParams);d.surface:bind(st.flowBlocksParams)
    st.flowCoarseParams=params(flowCode..code('rainFilmFlowBlocks'),{
        txFilmPrevious=false,txFilmFlowBlocks=false,txFilmCells=d.folder..'/texture/RAIN_FILM/cells.dds'})
    d.surface:bind(st.flowCoarseParams)
    local flowValues={};for key,value in pairs(values) do flowValues[key]=value end
    flowValues.gFilmReductionSize=vec2(5,2);flowValues.gFilmPaddedSize=vec2(66,18)
    flowValues.gFilmFlowReduce=1;st.flowCoarseParams.values=flowValues
    st.flowStatsParams=params(code('rainFilmFlowStats'),{txFilmFlowBlocks=false})
    st.blocksParams=params(code('rainFilmBlocks'),{txFilmCurrent=false})
    st.blocksSecondParams=params(code('rainFilmBlocks'),{txFilmCurrent=false})
    local secondValues={};for key,value in pairs(values) do secondValues[key]=value end
    secondValues.gFilmReductionSize=vec2(5,2);secondValues.gFilmPaddedSize=vec2(66,18)
    st.blocksSecondParams.values=secondValues
    st.totalsParams=params(code('rainFilmTotals'),{txFilmBlocks=false,txFilmBirthTotals=false})
    local totalValues={};for key,value in pairs(values) do totalValues[key]=value end
    totalValues.gFilmReductionSize=vec2(5,2);st.totalsParams.values=totalValues
    st.opticsParams=params(code('rainFilmOptics'),{txFilmCurrent=false,txFilmCells=d.folder..'/texture/RAIN_FILM/cells.dds'})
    st.statsParams=params(code('rainFilmStats'),{txFilmTotals=false})
    local function canvas(w,h,format,name)
        local c=ui.ExtraCanvas(vec2(w,h),1,render.AntialiasingMode.None,format)
        c:setName(name);c:clear(rgbm(0,0,0,0));return c
    end
    function st:dispose()
        self.epoch=self.epoch+1
        for _,name in ipairs({'descriptors','metaScratch','mask','summary','a','b','blocks','blocksSecond','totals','opticsA','opticsB','stats',
            'flux','flowBlocks','flowCoarse','flowStats'}) do
            if self[name] then self[name]:dispose();self[name]=nil end
        end
        self.count=nil;self.ready=false;self.pending=false;self.read=nil;self.optics=nil;self.birthRead=nil
        self.write=nil;self.opticsWrite=nil;self.pendingBirthTotals=nil
        self.frame=nil;self.preparedFrame=nil;self.budgetFrame=nil;self.logPending=false;self.flowLogPending=false;self.flowMode=nil
        self.publishedSeconds=0;self.publishedSteps=0;self.previousLog=nil
        for _,p in ipairs({self.descriptorParams,self.metaParams,self.binParams,self.summaryParams,self.resolveParams,
            self.blocksParams,self.blocksSecondParams,self.totalsParams,self.opticsParams,self.statsParams,
            self.flowParams,self.flowBlocksParams,self.flowCoarseParams,self.flowStatsParams}) do
            for key in pairs(p.textures) do if type(p.textures[key])~='string' then p.textures[key]=false end end
        end
    end
    function st:prepare(oldState,oldMeta,newState,newMeta,events,count,sim,inputs,motionDt,motion)
        self.preparedFrame=nil;self.budgetFrame=nil
        if self.assetPending or self.assetError then self.pending=true;return false end
        if self.frame==sim.frame or count<1 or count>4096 or count~=math.floor(count) then return false end
        local flowMode=r.RAIN_PHYSICS_P4_TRANSPORT_PREVIEW==true
        assert(not flowMode or geometry.flowConnectedUV==true,'P4 requires the connected-UV film bake: rebuild film cells')
        if self.count~=count or self.flowMode~=flowMode then
            self:dispose();local words=math.ceil(count/96)
            local v=self.values;v.gWords=words;v.gMaskW=33*words;v.gSummaryWords=math.ceil(words/96);v.gSummaryW=33*v.gSummaryWords
            self.descriptors=canvas(count,5,render.TextureFormat.R32G32B32A32.Float,'P3 conservative descriptors')
            self.metaScratch=canvas(count,1,render.TextureFormat.R32G32B32A32.Float,'P3 paired volume commit')
            self.mask=canvas(v.gMaskW,9,render.TextureFormat.R32G32B32A32.Float,'P3 sparse tiles')
            self.summary=canvas(v.gSummaryW,9,render.TextureFormat.R32G32B32A32.Float,'P3 sparse summary')
            self.a=canvas(1056,288,render.TextureFormat.R32G32B32A32.Float,'P3 field A')
            self.b=canvas(1056,288,render.TextureFormat.R32G32B32A32.Float,'P3 field B');self.read=self.a
            self.opticsA=canvas(1024,256,render.TextureFormat.R16G16B16A16.Float,'P3 physical height A')
            self.opticsB=canvas(1024,256,render.TextureFormat.R16G16B16A16.Float,'P3 physical height B');self.optics=self.opticsA
            if flowMode then self.flux=canvas(1024,256,render.TextureFormat.R32G32B32A32.Float,'P4 donor face flux') end
            self.count=count;self.flowMode=flowMode
        end
        local v=self.values;v.gFilmCount=count;v.gCount=count
        v.gFilmScale2=d.surface.scale^2;v.gFilmDt=math.max(sim.dt or 0,0);v.gFilmMotionDt=math.max(motionDt or 0,0)
        v.gFilmTheta=r.RAIN_PHYSICS_CONTACT_ANGLE_DEG
        v.gFilmDepositBare=r.RAIN_FILM_DEPOSIT_BARE;v.gFilmDepositCoat=r.RAIN_FILM_DEPOSIT_COAT
        v.gFilmMinSpeedMS=r.RAIN_FILM_MIN_SPEED_MM_S*.001;v.gFilmWiden=r.RAIN_FILM_SHEAR_WIDEN
        v.gFilmMicroJoinUM=r.RAIN_FILM_MICRO_JOIN_UM
        v.gFilmAirMS=math.sqrt((inputs.airX or 0)^2+(inputs.airY or 0)^2+(inputs.airZ or 0)^2)*r.RAIN_PHYSICS_LOCAL_AIR_FRACTION
        -- Estimated ventilation/dryness law. Track wetness/water never fills this field.
        local rh=math.max(0,math.min(inputs.humidity or .5,1));local t=math.max(-20,math.min(inputs.temperatureC or 20,50))
        local thermal=math.exp(17.625*t/(243.04+t)-17.625*20/(243.04+20))
        v.gFilmEvapUMS=r.RAIN_FILM_EVAP_DRY_UM_S*(1-rh)*thermal*(1+.5*math.sqrt(v.gFilmAirMS))
        self.evapUMS=v.gFilmEvapUMS
        v.gFilmFlowOn=flowMode and 1 or 0
        if flowMode then
            assert(motion and motion.gRainObjectToWorld,'P4 requires the P1 world transform/force inputs')
            v.gFilmObjectToWorld=motion.gRainObjectToWorld
            v.gFilmFlowCf=r.RAIN_FILM_FLOW_CF;v.gFilmFlowCFL=.8
            local mask=motion.gRainForceMask or 7
            local gravity=math.floor(mask)%2;local inertia=math.floor(mask/2)%2;local air=math.floor(mask/4)%2
            local force=motion.gRainSiInertiaWorld
            v.gFilmAccelerationWorld:set(inertia*(force and force.x or 0),
                inertia*(force and force.y or 0)-9.80665*gravity,inertia*(force and force.z or 0))
            local wind=motion.gRainSiAirWorld;local k=(motion.gRainSiAirFraction or 0)*air
            v.gFilmAirWorld:set((wind and wind.x or 0)*k,(wind and wind.y or 0)*k,(wind and wind.z or 0)*k)
            v.gFilmAirRho=motion.gRainSiRhoAir or 1.2
            v.gFilmAirDownward=motion.gRainAirflowDownwardMode or 0
            v.gFilmAirDownwardGain=motion.gRainAirflowDownwardGain or 1
            d.surface:bind(self.flowParams)
            self.flowParams.textures.txFilmPrevious=self.read
        end
        d.surface:bind(self.descriptorParams);d.surface:bind(self.metaParams)
        local tx=self.descriptorParams.textures
        tx.txFilmNewState=newState;tx.txFilmNewMeta=newMeta;tx.txFilmOldState=oldState;tx.txFilmOldMeta=oldMeta;tx.txFilmBirthEvent=events
        local tx=self.metaParams.textures;tx.txFilmNewMeta=newMeta;tx.txFilmDescriptors=self.descriptors
        self.binParams.textures.txFilmDescriptors=self.descriptors
        self.summaryParams.textures.txMask=self.mask
        local tx=self.resolveParams.textures
        tx.txFilmDescriptors=self.descriptors;tx.txMask=self.mask;tx.txSummary=self.summary;tx.txFilmPrevious=self.read
        tx.txFilmFlux=self.flux or false
        self.write=self.read==self.a and self.b or self.a
        self.opticsWrite=self.optics==self.opticsA and self.opticsB or self.opticsA
        self.opticsParams.textures.txFilmCurrent=self.write
        if not self:step('P3 descriptors',self.descriptors,self.descriptorParams) then return false end
        if not self:step('P3 paired meta',self.metaScratch,self.metaParams) then return false end
        if not self:step('P3 sparse tiles',self.mask,self.binParams) then return false end
        if not self:step('P3 sparse summary',self.summary,self.summaryParams) then return false end
        if flowMode and not self:step('P4 face flux',self.flux,self.flowParams) then return false end
        if not self:step('P3 field deposition',self.write,self.resolveParams) then return false end
        if not self:step('P3 physical height',self.opticsWrite,self.opticsParams) then return false end
        self.preparedFrame=sim.frame;self.pending=false;return true
    end
    function st:step(key,target,p)
        if d.measure(key,target.updateWithShader,target,p)==false then self.pending=true;return false end
        return true
    end
    function st:logFlow()
        if not self.ready or not self.flowMode or self.flowLogPending then return false end
        if not self.flowBlocks then
            self.flowBlocks=canvas(66,72,render.TextureFormat.R32G32B32A32.Float,'P4 manual Courant blocks')
            self.flowCoarse=canvas(5,8,render.TextureFormat.R32G32B32A32.Float,'P4 manual Courant coarse')
            self.flowStats=canvas(16,1,render.TextureFormat.R32.Float,'P4 manual Courant readback')
        end
        d.surface:bind(self.flowBlocksParams)
        self.flowBlocksParams.textures.txFilmPrevious=self.read
        self.flowCoarseParams.textures.txFilmFlowBlocks=self.flowBlocks
        self.flowStatsParams.textures.txFilmFlowBlocks=self.flowCoarse
        if not self:step('P4 manual Courant blocks',self.flowBlocks,self.flowBlocksParams) then return false end
        if not self:step('P4 manual Courant coarse',self.flowCoarse,self.flowCoarseParams) then return false end
        if self.flowStats:updateWithShader(self.flowStatsParams)==false then return false end
        self.flowLogPending=true;local epoch=self.epoch;local frame=self.frame;local dt=self.values.gFilmDt
        self.flowStats:accessData(function(err,data)
            if epoch~=self.epoch then if data then data:dispose() end;return end
            self.flowLogPending=false
            if err or not data then if data then data:dispose() end;d.log('P4 limiter readback failed');return end
            local a={};for i=1,16 do a[i]=data:floatValue(i-1,0) end;data:dispose()
            d.log(string.format('Rain P4 current-field estimate frame=%s dt=%.6f maxCourant=%.6f limitedCells=%.0f wetCells=%.0f limitedFilmMM3=%.6f limit=0.8 totalFilmMM3=%.6f limitedMassShare=%.6f massWeightedVelocityRetained=%.6f maxFilmUM=%.6f above1mmFilmMM3=%.6f worstCell=(%.0f,%.0f) worstFilmUM=%.6f worstAreaMM2=%.9f worstStrideUM=%.6f worstAccelMS2=%.6f',
                tostring(frame),dt,a[1],a[2],a[3],a[4],a[6],a[6]>0 and a[4]/a[6] or 0,
                a[6]>0 and a[7]/a[6] or 1,a[5],a[8],a[10],a[11],a[12],a[14],a[15],a[16]))
        end)
        return true
    end
    function st:logSnapshot()
        if self.logPending or (self.flowMode and self.flowLogPending) then return false end
        local ok=self:logBudget()
        if ok and self.flowMode then return self:logFlow() end
        return ok
    end
    function st:budget(birthTotals,sim)
        if self.preparedFrame~=sim.frame then return false end
        self.pendingBirthTotals=birthTotals
        self.budgetFrame=sim.frame;return true
    end
    function st:publish(sim,provisionalMeta)
        assert(self.budgetFrame==sim.frame and self.frame~=sim.frame,'P3 atomic publication gate')
        local finalMeta=self.metaScratch;self.metaScratch=provisionalMeta
        self.read=self.write;self.optics=self.opticsWrite;self.birthRead=self.pendingBirthTotals
        self.publishedSeconds=self.publishedSeconds+self.values.gFilmDt
        self.publishedSteps=self.publishedSteps+1
        self.ready=true;self.pending=false;self.frame=sim.frame;self.preparedFrame=nil;self.budgetFrame=nil
        return finalMeta
    end
    function st:logBudget()
        if not self.ready or self.logPending then return false end
        if not self.blocks then
            self.blocks=canvas(66,18,render.TextureFormat.R32G32B32A32.Float,'P3 manual field reduction')
            self.blocksSecond=canvas(5,2,render.TextureFormat.R32G32B32A32.Float,'P3 manual coarse reduction')
            self.totals=canvas(1,4,render.TextureFormat.R32G32B32A32.Float,'P3 manual field totals')
        end
        if not self.stats then self.stats=canvas(16,1,render.TextureFormat.R32.Float,'P3 manual budget readback') end
        self.blocksParams.textures.txFilmCurrent=self.read
        self.blocksSecondParams.textures.txFilmCurrent=self.blocks
        self.totalsParams.textures.txFilmBlocks=self.blocksSecond;self.totalsParams.textures.txFilmBirthTotals=self.birthRead
        if not self:step('P3 manual field blocks',self.blocks,self.blocksParams) then return false end
        if not self:step('P3 manual coarse blocks',self.blocksSecond,self.blocksSecondParams) then return false end
        if not self:step('P3 manual field totals',self.totals,self.totalsParams) then return false end
        self.statsParams.textures.txFilmTotals=self.totals
        if self.stats:updateWithShader(self.statsParams)==false then return false end
        self.logPending=true;local epoch=self.epoch;local frame=self.frame
        local seconds=self.publishedSeconds;local steps=self.publishedSteps;local transport=self.flowMode and 'P4' or 'P3'
        self.stats:accessData(function(err,data)
            if epoch~=self.epoch then if data then data:dispose() end;return end
            self.logPending=false
            if err or not data then if data then data:dispose() end;d.log('P3 budget readback failed: '..tostring(err));return end
            local v={};for i=1,16 do v[i]=data:floatValue(i-1,0) end;data:dispose();self.logValues=v
            local residual=v[9]-v[10]-v[11]-v[12]-v[13]-v[1]-v[2]-v[3]-v[4]
            local prev=self.previousLog;local interval=seconds-(prev and prev.seconds or 0)
            local inputRate=interval>0 and (v[9]-(prev and prev.input or 0))/interval or 0
            local residualDelta=residual-(prev and prev.residual or 0)
            d.log(string.format('Rain P3 frame=%s mm3 input=%.6f film=%.6f micro=%.6f drops=%.6f bounce=%.6f exit=%.6f headEvap=%.6f fieldEvap=%.6f runoff=%.6f trailTransferred=%.6f residual=%.6f arrivals=%.0f publishedSeconds=%.6f steps=%d intervalSeconds=%.6f inputRate=%.6f mm3/s residualDelta=%.6f mm3 transport=%s',
                tostring(frame),v[9],v[1],v[2],v[12],v[10],v[11],v[13],v[3],v[4],v[14],residual,v[16],
                seconds,steps,interval,inputRate,residualDelta,transport))
            self.previousLog={seconds=seconds,input=v[9],residual=residual}
        end)
        return true
    end
    return st
end
