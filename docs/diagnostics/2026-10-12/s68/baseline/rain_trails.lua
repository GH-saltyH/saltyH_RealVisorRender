-- Unified physical trail + wipe history, published atomically with GPU heads.
return function(d)
    local r=d.runtime;local st={ready=false,wet=0,updates=0}
    local function code(name)
        local f=assert(io.open(d.folder..'/shaders/'..name..'.hlsl','rb'))
        local s=f:read('*a');f:close();return '#line 1 "RealVisor/'..name..'.hlsl"\n'..s
    end
    st.descriptorCode=code('rainTrailDescriptor');st.binCode=code('rainTrailBin')
    st.resolveCode=code('rainTrailResolve')
    local traversal,substitutions=d.traversal:gsub('    return acc;','    return ntResolve(pin.Tex,acc);',1)
    assert(substitutions==1,'New Trail sparse traversal output missing')
    st.resolveProgram=d.surface.shader..st.resolveCode..traversal
    function st:dispose()
        for _,name in ipairs({'descriptors','mask','summary','a','b'}) do
            if self[name] then self[name]:dispose();self[name]=nil end
        end
        self.ready=false;self.read=nil;self.frame=nil;self.key=nil
    end
    local function canvas(w,h,format,name)
        local c=ui.ExtraCanvas(vec2(w,h),1,render.AntialiasingMode.None,format)
        c:setName(name);c:clear(rgbm(0,0,0,0));return c
    end
    function st:environment(sim,state)
        if self.environmentFrame==sim.frame then return end
        self.environmentFrame=sim.frame
        local rain=math.max(0,math.min(1,r.RAIN_GPU_STATE_RAIN_OVERRIDE>=0 and r.RAIN_GPU_STATE_RAIN_OVERRIDE or sim.rainIntensity or 0))
        local density=math.max(state.smearDensity or 0,0)
        local facing=math.max(0,math.min(state.smearFacing or 0,1))
        self.shear=math.max(0,math.min((state.smearAirKmh or 0)/200,1))*facing
        -- Track puddles are only an optional spray proxy, not visor water.
        self.supply=math.max(0,math.min(.65*rain+.35*math.min(density,1)
            +r.RAIN_NEW_TRAIL_TRACK_SPRAY_GAIN*(sim.rainWater or 0)*math.min((state.smearCarKmh or 0)/200,1)*facing,1))
        local dt=math.max(sim.dt or 0,0)
        local tau=self.supply>self.wet and r.RAIN_NEW_TRAIL_WET_RISE_SECONDS
            or r.RAIN_NEW_TRAIL_WET_DRY_SECONDS/(1+self.shear)
        self.wet=self.wet+(self.supply-self.wet)*(1-math.exp(-dt/math.max(tau,.1)))
        self.density=density;self.phase=state.ripplePhase or 0
    end
    function st:prepare(inputs,headValues,sim,state)
        self:environment(sim,state)
        local count=math.floor(headValues.gCount);local size=math.max(128,math.floor(r.RAIN_DYNAMIC_WATER_FIELD_TRAIL_SIZE))
        size=math.min(size,4096);local tile=32
        local nx,ny=math.ceil(size/tile),math.ceil(size/(tile*4))
        local words=math.ceil(count/96);local summaryWords=math.ceil(words/96)
        local key=table.concat({count,size},':')
        if self.key~=key then
            self:dispose();self.key=key;self.size=size
            state.waterTrailRead=nil;state.waterTrailReady=false
            state.trailMaskRead=nil;state.trailMaskFrame=nil
            self.descriptors=canvas(count,4,render.TextureFormat.R32G32B32A32.Float,'New Trail slot descriptors')
            self.mask=canvas(nx*words,ny,render.TextureFormat.R32G32B32A32.Float,'New Trail sparse tiles')
            self.summary=canvas(nx*summaryWords,ny,render.TextureFormat.R32G32B32A32.Float,'New Trail sparse summary')
            self.a=canvas(size,math.floor(size/4),render.TextureFormat.R16G16B16A16.Float,'New Trail history A')
            self.b=canvas(size,math.floor(size/4),render.TextureFormat.R16G16B16A16.Float,'New Trail history B')
            self.read=self.a
        end
        local v=self.values or {};for k,value in pairs(headValues) do v[k]=value end
        local ref=r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM
        v.gNewTrailBirthHold=r.RAIN_GPU_STATE_BIRTH_HOLD_SECONDS;v.gNewTrailLifecycle=inputs.lifecycle and 1 or 0
        v.gNewTrailWet=self.wet;v.gNewTrailShear=self.shear;v.gNewTrailSupply=self.supply;v.gNewTrailDensity=self.density
        v.gNewTrailMinSpeed=r.RAIN_NEW_TRAIL_MIN_SPEED_MM_S*ref
        v.gNewTrailFullSpeed=math.max(r.RAIN_NEW_TRAIL_FULL_SPEED_MM_S,r.RAIN_NEW_TRAIL_MIN_SPEED_MM_S+.1)*ref
        v.gNewTrailMinDropMM=r.RAIN_NEW_TRAIL_MIN_DROP_MM;v.gNewTrailMinDiameterMM=r.RAIN_NEW_TRAIL_MIN_FOOTPRINT_MM
        v.gNewTrailWidthD=r.RAIN_DYNAMIC_WATER_FIELD_TRAIL_WIDTH;v.gNewTrailWipeD=r.RAIN_DYNAMIC_TRAIL_MASK_WIPE_WIDTH_SCALE
        v.gNewTrailWiden=r.RAIN_DYNAMIC_WATER_FIELD_SHEET_WIDEN;v.gNewTrailHeight=r.RAIN_NEW_TRAIL_HEIGHT
        v.gNewTrailSeconds=r.RAIN_DYNAMIC_WATER_FIELD_TRAIL_SECONDS;v.gNewTrailWipeSeconds=r.RAIN_DYNAMIC_TRAIL_MASK_SECONDS
        v.gNewTrailSheetEnabled=r.RAIN_DYNAMIC_WATER_FIELD_SHEET_ENABLED and 1 or 0
        v.gNewTrailWaterEnabled=r.RAIN_DYNAMIC_WATER_FIELD_ENABLED and r.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED and 1 or 0
        v.gNewTrailWipeEnabled=r.RAIN_DYNAMIC_TRAIL_MASK_ENABLED and 1 or 0
        v.gNewTrailDensityMin=r.RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_MIN;v.gNewTrailDensityFull=math.max(r.RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_FULL,v.gNewTrailDensityMin+.001)
        v.gNewTrailNoise=r.RAIN_DYNAMIC_WATER_FIELD_TRAIL_NOISE;v.gNewTrailBeadCycles=r.RAIN_NEW_TRAIL_BEAD_CYCLES_D
        v.gNewTrailSheetRipple=r.RAIN_NEW_TRAIL_SHEET_RIPPLE;v.gNewTrailPhase=self.phase
        v.gNewTrailDt=math.max(sim.dt or 0,0);v.gNewTrailHeadSize=headValues.gSize
        v.gNewTrailDiffuse=1-math.exp(-math.max(r.RAIN_DYNAMIC_WATER_FIELD_TRAIL_DIFFUSE,0)*4*60*v.gNewTrailDt)
        v.gNewTrailPixelUV=vec2(1/size,4/size)
        local tx={txRainState=inputs.state,txRainStateMeta=inputs.meta,txRainPreviousState=inputs.previousState,
            txRainPreviousMeta=inputs.previousMeta,txRainDropMetric=inputs.metric,txOverride=inputs.override,
            txRainDu=d.surface.root..'du.dds',txRainDv=d.surface.root..'dv.dds',txRainBoundaryMask=d.boundary,
            txTrailPrevious=self.read}
        if d.measure('New Trail descriptors',self.descriptors.updateWithShader,self.descriptors,{async=true,blendMode=render.BlendMode.Opaque,
            textures=tx,values=v,shader=self.descriptorCode})==false then self.pending=true;return false end
        v.gSize=size;v.gTile=vec2(tile,tile*4);v.gTilesX=nx;v.gTilesY=ny;v.gWords=words
        v.gMaskW=nx*words;v.gSummaryW=nx*summaryWords;v.gSummaryWords=summaryWords;v.gSparseWords=1;v.gFlipY=0;v.gDebug=0
        if d.measure('New Trail tiles',self.mask.updateWithShader,self.mask,{async=true,blendMode=render.BlendMode.Opaque,
            textures={txTrailDescriptors=self.descriptors},values=v,shader=self.binCode})==false then self.pending=true;return false end
        if d.measure('New Trail summary',self.summary.updateWithShader,self.summary,{async=true,blendMode=render.BlendMode.Opaque,
            textures={txMask=self.mask},values=v,shader=d.summary})==false then self.pending=true;return false end
        self.values=v;self.write=self.read==self.a and self.b or self.a
        local txResolve={txTrailDescriptors=self.descriptors,txTrailPrevious=self.read,txMask=self.mask,txSummary=self.summary,
            txRainDu=d.surface.root..'du.dds',txRainDv=d.surface.root..'dv.dds',txRainBoundaryMask=d.boundary}
        if d.measure('New Trail resolve',self.write.updateWithShader,self.write,{async=true,blendMode=render.BlendMode.Opaque,
            textures=txResolve,values=v,shader=self.resolveProgram})==false then self.pending=true;return false end
        self.preparedFrame=sim.frame;self.pending=false;return true
    end
    function st:publish(sim,state)
        if self.preparedFrame~=sim.frame then return false end
        self.read=self.write;self.ready=true;self.frame=sim.frame;self.updates=self.updates+1
        state.waterTrailRead=self.read;state.waterTrailReady=true;state.waterTrailSize=self.size
        state.trailMaskRead=self.read;state.trailMaskFrame=sim.frame;state.trailMaskSize=self.size
        state.newTrailActive=true
        return true
    end
    return st
end
