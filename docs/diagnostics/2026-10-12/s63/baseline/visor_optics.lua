-- Cached geometry + live HDR optics. Inject scene dependencies; no main
-- material replacement or per-frame reflection BVH trace. Native HDR colour
-- supplements light at depth-checked cached hits without erasing the image.
return function(d)
    local st={step=0,status='Waiting for optics',bakes=0,completedBakes=0,draws=0}
    local keys={'Frame','Rubber','Fabric','Face','Balaklava','Cam','CamCover','CamFabric'}
    local names={'FRAME_MAIN','BAND_INNER','BODY_FABRIC_TRACE','DRIVER_FACE','DRIVER_BALAKLAVA','CAM','CAM_COVER','CAM_FABRIC'}
    local files={'frame','rubber','fabric','face','balaklava','cam','camCover','camFabric'}
    local root=d.folder..'/texture/GLASS/E1_GEOMETRY/'
    local r=d.runtime
    local materials=dofile(root..'optics_materials.lua')
    local shaders={}
    local function shader(name)
        if not shaders[name] then
            local f=assert(io.open(d.folder..'/shaders/'..name..'.hlsl','rb'))
            shaders[name]=f:read('*a');f:close()
        end
        return shaders[name]
    end
    local function canvas(w,h,mips,format)
        return ui.ExtraCanvas(vec2(w,h),mips,render.AntialiasingMode.None,format or render.TextureFormat.R16G16B16A16.Float)
    end
    local function safeDraw(params)
        local mesh=params.mesh;local visible=mesh:isVisible(1)
        render.setCullMode(render.CullMode.None);render.setBlendMode(render.BlendMode.Opaque)
        render.setDepthMode(render.DepthMode.Normal)
        local ok,result=pcall(function() mesh:setVisible(true,false);return render.mesh(params) end)
        mesh:setVisible(visible,false)
        render.setBlendMode(render.BlendMode.BlendPremultiplied);render.setDepthMode(render.DepthMode.ReadOnly)
        if not ok then error(result) end
        return result
    end
    local function requireUpdate(value) if value==false then error('Optics shader/capture pending') end end
    function st:disposeBake()
        self.statsGeneration=(self.statsGeneration or 0)+1;self.statsPending=false
        for _,name in ipairs({'hit','surface','material','glass','shA','shB','aoA','aoB','radiance'}) do
            if self[name] then self[name]:dispose();self[name]=nil end
        end
        self.ready=false;self.step=0;self.key=nil;self.completedKey=nil;self.stats=nil
    end
    function st:dispose()
        self:disposeBake()
        self.statsGeneration=(self.statsGeneration or 0)+1;self.statsPending=false;self.statsRequested=false
        for _,name in ipairs({'mask','bright','sunA','sunB','probeShot','probeExpected','statsCanvas','sourceShot','sourceDepth'}) do
            if self[name] then self[name]:dispose();self[name]=nil end
        end
        self.maskKey=nil;self.sunReady=false;self.probeReady=false;self.probeOwner=nil;self.sourceReady=false
    end
    local function property(ref,key,fallback)
        local ok,v=pcall(function() return ref:getMaterialPropertyValue(key) end)
        return ok and type(v)=='number' and v or fallback
    end
    local function bindScene(p,pose)
        p.textures.txOptGeometry=root..'optics_geometry.dds'
        p.values.gOptPose=pose;p.values.gOptPoseInverse=pose:inverse()
        p.values.gOptRange=r.RAIN_VISOR_OPTICS_TRACE_RANGE
        for i,key in ipairs(keys) do
            local e=d.editor(names[i]);assert(e and e.targetMesh and #e.targetMesh==1,'Optics requires one mesh: '..names[i])
            local ref=e.targetMesh
            p.values['gOpt'..key..'Inverse']=ref:getWorldTransformationRaw():inverse()
            p.values['gOpt'..key..'Visible']=e.visible~=false and 1 or 0
            local records=assert(materials[files[i]].records,'Rebuild optics assets: missing geometry offsets')
            p.values['gOpt'..key..'Records']=vec3(records[1],records[2],records[3])
        end
        local band=d.editor('GLASS_EXT_FX');assert(band and band.targetMesh and #band.targetMesh==1,'Missing visor band mesh')
        p.values.gOptBandInverse=band.targetMesh:getWorldTransformationRaw():inverse()
        p.values.gOptBandVisible=band.visible~=false and 1 or 0
        local records=assert(materials.band.records,'Rebuild optics assets: missing band offsets')
        p.values.gOptBandRecords=vec3(records[1],records[2],records[3])
        p.values.gOptNormalStrength=0 -- cached reflection uses the geometric INT normal
        p.values.gOptMaterialNormal=r.RAIN_VISOR_OPTICS_MATERIAL_NORMAL
        p.values.gOptBandTransmission=r.RAIN_VISOR_OPTICS_BAND_TRANSMISSION
        p.values.gOptGlassTransmission=r.RAIN_VISOR_OPTICS_GLASS_TRANSMISSION
    end
    local function bindBake(p,pose,pass,id)
        bindScene(p,pose)
        p.textures.txOptVisorNormal=d.folder..'/texture/GLASS/FX/int_txNormal.dds'
        if id then
            local material=materials[files[id]]
            p.values.gOptMaterialID=id
            if pass==1 then
                p.textures.txOptNormal=root..(material.txNormal or 'neutral_normal.png')
                p.textures.txOptMaps=root..(material.txMaps or material.txNormal or 'neutral_normal.png')
                p.values.gOptHasMaps=material.txMaps and 1 or 0
                p.values.gOptMaterialSpecular=math.max(property(d.editor(names[id]).targetMesh,'ksSpecular',0),0)
            end
            if pass==2 then
                p.textures.txOptDiffuse=root..material.txDiffuse
                p.textures.txOptMaps=root..(material.txMaps or material.txDiffuse)
                p.values.gOptHasMaps=material.txMaps and 1 or 0
                p.values.gOptRoughness=math.sqrt(2/(math.max(property(d.editor(names[id]).targetMesh,'ksSpecularEXP',16),0)+2))
            end
        end
    end
    local function q(v) return math.abs(v)<.00005 and '0.0000' or string.format('%.4f',v) end
    local function vectorKey(v) return q(v.x)..','..q(v.y)..','..q(v.z) end
    function st:cacheKey(sim,pose)
        local inverse=pose:inverse()
        local neutralEye,look,up
        if d.localFrame then neutralEye,look,up=d.localFrame() end
        if not neutralEye then
            local motion=inverse:transformVector(d.motionWorld())
            neutralEye=inverse:transformPoint(sim.cameraPosition)+motion
            look=inverse:transformVector(sim.cameraLook);up=inverse:transformVector(sim.cameraUp)
        end
        local key={d.profileKey(),r.MODEL_PATH,d.modelHash(),vectorKey(neutralEye),vectorKey(look),
            vectorKey(up),q(sim.cameraFOV),tostring(d.width()),tostring(d.height()),
            q(sim.cameraClipNear or .0035),
            tostring(r.RAIN_VISOR_OPTICS_WIDTH),'triangle-tangent-v4-band-mask',q(r.RAIN_VISOR_OPTICS_MATERIAL_NORMAL),
            q(r.RAIN_VISOR_OPTICS_BAND_TRANSMISSION),q(r.RAIN_VISOR_OPTICS_GLASS_TRANSMISSION),q(r.RAIN_VISOR_OPTICS_TRACE_RANGE)}
        local labels={'Profile','Model path','Model hash','Local eye','Local look','Local up','Camera FOV','Target width','Target height',
            'Near clip','Bake width','Visor normal','Material normal','Band transmission','Glass transmission','Trace range'}
        local function transformKey(matrix,label,worldSpace)
            for _,point in ipairs({vec3(),vec3(1,0,0),vec3(0,1,0),vec3(0,0,1)}) do
                local p=matrix:transformPoint(point)
                key[#key+1]=vectorKey(worldSpace and inverse:transformPoint(p) or p)
                labels[#key]=label
            end
        end
        if d.rootTransform then transformKey(d.rootTransform(),'Model local transform',false) end
        for _,name in ipairs({'GLASS_INT_FX','GLASS_EXT_FX','FRAME_MAIN','BAND_INNER','BODY_FABRIC_TRACE','DRIVER_FACE','DRIVER_BALAKLAVA','CAM','CAM_COVER','CAM_FABRIC'}) do
            local e=d.editor(name);key[#key+1]=name..tostring(e and e.visible~=false or false)
            labels[#key]=name..' visibility'
            if e and e.targetMesh and #e.targetMesh==1 then
                -- Use authored local transforms in the camera-attached runtime.
                -- Multiplying world/inverse world matrices introduces float
                -- jitter at track-scale coordinates even when geometry is fixed.
                local matrix=d.localTransform and d.localTransform(e.targetMesh) or e.targetMesh:getWorldTransformationRaw()
                transformKey(matrix,name..' local transform',not d.localTransform)
                key[#key+1]=q(property(e.targetMesh,'ksSpecularEXP',16))
                labels[#key]=name..' material exponent'
                key[#key+1]=q(property(e.targetMesh,'ksSpecular',0))
                labels[#key]=name..' material specular'
            end
        end
        return table.concat(key,'|'),neutralEye,key,labels
    end
    function st:startBake(sim,pose,key,neutralEye)
        materials=dofile(root..'optics_materials.lua')
        self:disposeBake();self.key=key;self.eyeLocal=neutralEye:clone()
        self.bakePose=pose:clone()
        -- Remove G-force from the initial bake eye; do not bake transient motion.
        self.bakeEye=pose:transformPoint(neutralEye)
        self.w=math.max(128,math.min(4096,math.floor(r.RAIN_VISOR_OPTICS_WIDTH+.5)))
        self.h=math.max(64,math.floor(self.w*d.height()/math.max(d.width(),1)+.5))
        self.mips=math.floor(math.log(math.max(self.w,self.h))/math.log(2))+1
        local code=shader('visorOpticsTrace')..'\n'..shader('visorOpticsBake')
        self.bakeParams={}
        for pass,name in ipairs({'hit','surface','material','glass'}) do
            local draws={}
            for id=1,(name=='surface' or name=='material') and #keys or 1 do
                local p={async=false,transform='original',mesh=d.editor('GLASS_INT_FX').targetMesh,
                    shader='#define OPT_BAKE_PASS '..(pass-1)..'\n'..code,textures={},values={gOptEye=self.bakeEye}}
                bindBake(p,pose,pass-1,(name=='surface' or name=='material') and id or nil)
                draws[#draws+1]=p
            end
            self.bakeParams[name]=draws
            local format=name=='hit' and render.TextureFormat.R32G32B32A32.Float
                or name=='material' and render.TextureFormat.R8G8B8A8.UNorm or render.TextureFormat.R16G16B16A16.Float
            self[name]=ac.GeometryShot({opaque=function()
                for _,p in ipairs(draws) do requireUpdate(safeDraw(p)) end
            end},vec2(self.w,self.h),1,true,
                render.AntialiasingMode.None,format)
            self[name]:setSky(false);self[name]:setParticles(false);self[name]:setClearColor(rgbm(0,0,0,0))
            self[name]:setClippingPlanes(math.max(sim.cameraClipNear or .0035,.001),sim.cameraClipFar or 1000)
        end
        self.bakeLook=sim.cameraLook:clone();self.bakeUp=sim.cameraUp:clone();self.bakeFov=sim.cameraFOV
        self.bakes=self.bakes+1;self.status='Baking reflection hit/material buffers'
    end
    function st:updateBake()
        if not r.RAIN_VISOR_OPTICS_ENABLED or r.RAIN_VISOR_OPTICS_TIER<1 then
            if self.hit then self:disposeBake() end;return
        end
        self.ready=false
        if not d.validate() then self.status=d.validationStatus();return end
        local f=io.open(root..'optics.verify','rb')
        if not f then self.status='Missing optics assets: run build_visor_optics_assets.py';return end
        local opticsHash=(f:read('*l') or ''):gsub('%s+$','');f:close()
        if opticsHash~=d.modelHash() then self.status='Optics assets/model hash mismatch; rebuild optics assets';return end
        local pose=d.pose();if not pose then self.status='Waiting for helmet pose';return end
        local sim=ac.getSim();local key,eye,parts,labels=self:cacheKey(sim,pose)
        if key~=self.pendingKey then
            if self.pendingParts then
                for i=1,math.max(#parts,#self.pendingParts) do
                    if parts[i]~=self.pendingParts[i] then
                        self.lastInvalidation=(labels[i] or 'Cache input')..': '..tostring(self.pendingParts[i])..' -> '..tostring(parts[i]);break
                    end
                end
            else self.lastInvalidation='Initial bake' end
            self.pendingParts=parts
            self.pendingKey=key;self.changedAt=os.clock()
            if self.key and self.key~=key then self:disposeBake() end
        end
        if self.key~=key then
            if self.bakes>0 and os.clock()-self.changedAt<.2 then self.status='Waiting for stable optics profile';return end
            self:startBake(sim,pose,key,eye)
        end
        if self.step<4 then
            local name=({'hit','surface','material','glass'})[self.step+1]
            -- Head/world motion can continue while baking. Place the canonical
            -- eye and axes back into the current helmet frame for each pass.
            local inverse=self.bakePose:inverse()
            local look=pose:transformVector(inverse:transformVector(self.bakeLook)):normalize()
            local up=pose:transformVector(inverse:transformVector(self.bakeUp)):normalize()
            local eyeWorld=pose:transformPoint(self.eyeLocal)
            for id,p in ipairs(self.bakeParams[name]) do
                bindBake(p,pose,self.step,(name=='surface' or name=='material') and id or nil)
                p.values.gOptEye=eyeWorld
            end
            requireUpdate(self[name]:update(eyeWorld,look,up,self.bakeFov))
            if name=='hit' then
                self.bakePose=pose:clone();self.bakeEye=eyeWorld:clone()
                self.bakeLook=look:clone();self.bakeUp=up:clone()
                self.view=self.hit:viewMatrix():clone();self.projection=self.hit:projectionMatrix():clone()
            end
            self.step=self.step+1
            if self.step==4 then
                self.shA=canvas(self.w,self.h,1);self.shB=canvas(self.w,self.h,1)
                self.aoA=canvas(self.w,self.h,1);self.aoB=canvas(self.w,self.h,1)
                self.shA:clear(rgbm(0,0,0,0));self.aoA:clear(rgbm(0,0,0,0))
                self.visibilityParams={async=false,blendMode=render.BlendMode.Opaque,shader=shader('visorOpticsTrace')..'\n'..shader('visorOpticsVisibility'),textures={},values={}}
            end
            return
        end
        if self.step<44 then
            local sample=self.step-4;local ao=sample>=32;local index=ao and sample-32 or sample
            local a,b=ao and self.aoA or self.shA,ao and self.aoB or self.shB
            local p=self.visibilityParams;bindScene(p,pose)
            p.textures.txOptBandDiffuse=d.folder..'/texture/GLASS/FX/ext_txBand.png'
            p.textures.txOptPrevious=a;p.textures.txOptHit=self.hit;p.textures.txOptSurface=self.surface
            p.values.gOptSample=index;p.values.gOptVisibilityPass=ao and 1 or 0
            requireUpdate(b:updateSceneWithShader(p))
            if ao then self.aoA,self.aoB=b,a else self.shA,self.shB=b,a end
            self.step=self.step+1;self.status=string.format('Optics bake %d/44 (SH 32 rays, AO 8 rays)',self.step)
            return
        end
        if not self.radiance then self.radiance=canvas(self.w,self.h,self.mips) end
        if self.completedKey~=self.key then self.completedBakes=self.completedBakes+1;self.completedKey=self.key end
        self.ready=true;self.status='Optics bake cached; lighting only each frame'
    end
    function st:updateMask()
        local useTexture=r.RAIN_VISOR_OPTICS_PATTERN_TEXTURE
        local key=tostring(useTexture)..'|'..q(r.RAIN_VISOR_OPTICS_DUST_DENSITY)..'|'..q(r.RAIN_VISOR_OPTICS_SCRATCH_DENSITY)..'|'..q(r.RAIN_VISOR_OPTICS_SEED)
        if key==self.maskKey and self.mask then return end
        if key~=self.pendingMaskKey then self.pendingMaskKey=key;self.maskChanged=os.clock() end
        if self.mask and os.clock()-self.maskChanged<.2 then return end
        if self.mask and self.maskTexture~=useTexture then self.mask:dispose();self.mask=nil end
        self.maskTexture=useTexture
        self.mask=self.mask or canvas(useTexture and 2048 or 512,useTexture and 512 or 128,useTexture and 12 or 10,
            useTexture and render.TextureFormat.R8G8B8A8.UNorm or nil)
        requireUpdate(self.mask:updateSceneWithShader({async=false,blendMode=render.BlendMode.Opaque,
            shader='#define OPT_MASK_TEXTURE '..(useTexture and '1' or '0')..'\n'..shader('visorOpticsMask'),
            textures=useTexture and {txOptPattern=d.folder..'/texture/GLASS/visor_contamination_rgba.dds'} or {},values={
            gOptSeed=r.RAIN_VISOR_OPTICS_SEED,gOptDensity=r.RAIN_VISOR_OPTICS_DUST_DENSITY,
            gOptScratchDensity=r.RAIN_VISOR_OPTICS_SCRATCH_DENSITY}}))
        requireUpdate(self.mask:mipsUpdate());self.maskKey=key
    end
    function st:updateExternalProbe()
        if not d.probeEnsure then return end
        local probe=d.probeEnsure()
        if not probe or not probe.prepared then self.probeReady=false;return end
        if self.probeOwner~=probe.root or self.probeKey~=probe.captureKey then
            if self.probeShot then self.probeShot:dispose();self.probeExpected:dispose() end
            self.probeOwner=probe.root;self.probeKey=probe.captureKey;self.probeReady=false
            self.probeShot=ac.GeometryShot(probe.captureRefs,vec2(32,32),6,true,
                render.AntialiasingMode.None,render.TextureFormat.R16G16B16A16.Float)
            self.probeShot:setOriginalLighting(true);self.probeShot:setShadersType(render.ShadersType.Main)
            self.probeShot:setOpaqueAlphaFix(true)
            self.probeExpectedParams={mesh=probe.captureRefs,async=false,transform='original',
                shader=shader('visorOpticsProbe'),textures={},values={}}
            self.probeExpected=ac.GeometryShot({opaque=function() requireUpdate(safeDraw(self.probeExpectedParams)) end},
                vec2(32,32),6,true,render.AntialiasingMode.None,render.TextureFormat.R16G16B16A16.Float)
            for _,shot in ipairs({self.probeShot,self.probeExpected}) do
                shot:setSky(false);shot:setParticles(false);shot:setClearColor(rgbm(0,0,0,0));shot:setClippingPlanes(.001,2)
            end
        end
        if self.probeTime and os.clock()-self.probeTime<.1 and self.probeReady then return end
        self.probeReady=false
        local sim=ac.getSim();local light=(-sim.lightDirection):normalize();local pose=d.pose()
        if not pose then return end
        local center=pose:transformPoint(vec3())
        local origin=center+light*.5;local up=math.abs(light.y)<.9 and vec3(0,1,0) or vec3(1,0,0)
        up=(up-light*up:dot(light)):normalize()
        self.probeExpectedParams.values.gOptLightWorld=light
        requireUpdate(d.probeUpdate(self.probeShot,probe.captureRefs,origin,-light,up,75))
        requireUpdate(d.probeUpdate(self.probeExpected,probe.captureRefs,origin,-light,up,75))
        requireUpdate(self.probeShot:mipsUpdate());requireUpdate(self.probeExpected:mipsUpdate())
        self.probeReady=true;self.probeTime=os.clock()
    end
    function st:updateSun(sim)
        local light=(-sim.lightDirection):normalize()
        -- CSP vec3:cross()/normalize() mutate their receiver. Sim vectors are
        -- const views; writing cameraUp throws before *any* tier can draw.
        local side=sim.cameraUp:clone():cross(sim.cameraLook):normalize()
        local z=light:dot(sim.cameraLook);local tan=math.tan(math.rad(sim.cameraFOV)*.5)
        local aspect=d.width()/math.max(d.height(),1)
        local sunUV=vec2(.5+light:dot(side)/math.max(z,.0001)/tan/aspect*.5,
            .5-light:dot(sim.cameraUp)/math.max(z,.0001)/tan*.5)
        local onScreen=z>0 and sunUV.x>0 and sunUV.x<1 and sunUV.y>0 and sunUV.y<1
        local now=os.clock()
        if not self.shadowTime or now-self.shadowTime>.1 then
            self.shadowTime=now;self.externalShadow=1;self.shadowStatus='No track raycast available'
            if physics and physics.raycastTrack then
                local ok,distance=pcall(physics.raycastTrack,sim.cameraPosition+light*.3,light,5000)
                if ok then self.externalShadow=distance and distance>=0 and 0 or 1;self.shadowStatus='Track collision shadow scalar' end
            end
        end
        self.sunA=self.sunA or canvas(1,1,1);self.sunB=self.sunB or canvas(1,1,1)
        if not self.sunReady then self.sunA:clear(rgbm(self.externalShadow,self.externalShadow,self.externalShadow,1)) end
        requireUpdate(self.sunB:updateSceneWithShader({async=false,blendMode=render.BlendMode.Opaque,shader=shader('visorOpticsSun'),
            textures={txOptDepth='dynamic::depth',txOptPrevious=self.sunA,txOptProbe=self.probeReady and self.probeShot or false,
                txOptProbeExpected=self.probeReady and self.probeExpected or false},values={gOptExternalShadow=self.externalShadow,
                gOptProbeReady=self.probeReady and 1 or 0,gOptSunLum=.2126*sim.lightColor.r+.7152*sim.lightColor.g+.0722*sim.lightColor.b,
                gOptProbeGain=r.RAIN_VISOR_OPTICS_SHADOW_PROBE_GAIN,
                gOptSunOnScreen=onScreen and 1 or 0,gOptSunUV=sunUV,gOptInvTarget=vec2(1/d.width(),1/d.height()),
                gOptReversedDepth=r.RAIN_DYNAMIC_SHOT_TONE_FRAME_DEPTH_REVERSED and 1 or 0,
                gOptSunBlend=1}})) -- current-frame visibility; no delayed light trigger
        self.sunA,self.sunB=self.sunB,self.sunA;self.sunReady=true
        if self.probeReady then self.shadowStatus='Native engine-shadow scalar probe (32x32, 10 Hz)' end
        return light,side
    end
    function st:updateNativeSource()
        self.sourceReady=false
        self.sourceStatus='Native HDR source disabled (no capture cost)'
        if not (r.RAIN_VISOR_OPTICS_ENABLED and r.RAIN_VISOR_OPTICS_TIER>=1
            and r.RAIN_VISOR_OPTICS_NATIVE_SOURCE and d.sourceEnsure) then return end
        local refs,owner,prepared,members=d.sourceEnsure()
        if not refs or not prepared then self.sourceStatus='Native source waiting for engine preparation';return end
        local width=math.max(256,math.min(4096,math.floor(r.RAIN_VISOR_OPTICS_SOURCE_WIDTH+.5)))
        local height=math.floor(width*2/3+.5)
        if self.sourceShot and (self.sourceOwner~=owner or self.sourceWidth~=width or self.sourceMembers~=members) then
            self.sourceShot:dispose();self.sourceDepth:dispose();self.sourceShot=nil;self.sourceDepth=nil
        end
        if not self.sourceShot then
            self.sourceShot=ac.GeometryShot(refs,vec2(width,height),1,true,render.AntialiasingMode.None,
                render.TextureFormat.R16G16B16A16.Float)
            self.sourceShot:setOriginalLighting(true);self.sourceShot:setShadersType(render.ShadersType.Main)
            self.sourceShot:setOpaqueAlphaFix(true);self.sourceShot:setTransparentPass(true)
            self.sourceDepth=ac.GeometryShot({opaque=function() d.sourceDepthDraw(self) end},vec2(width,height),1,true,
                render.AntialiasingMode.None,render.TextureFormat.R32G32B32A32.Float)
            for _,shot in ipairs({self.sourceShot,self.sourceDepth}) do
                shot:setSky(false);shot:setParticles(false);shot:setClearColor(rgbm(0,0,0,0));shot:setClippingPlanes(.001,2)
            end
            self.sourceWidth=width;self.sourceOwner=owner;self.sourceMembers=members
        end
        local pose=d.pose();if not pose then return end
        local sim=ac.getSim();local eye=d.localFrame and d.localFrame() or pose:inverse():transformPoint(sim.cameraPosition)
        local pitch=math.rad(r.RAIN_VISOR_OPTICS_SOURCE_PITCH)
        local anchor=eye
        if r.RAIN_VISOR_OPTICS_SOURCE_AUTO_FIT and materials.face.bounds then
            local bounds=materials.face.bounds
            local center=vec3((bounds[1]+bounds[4])*.5,(bounds[2]+bounds[5])*.5,(bounds[3]+bounds[6])*.5)
            local face=d.editor('DRIVER_FACE')
            if face and face.targetMesh and #face.targetMesh==1 then
                -- Use the actual face transform; model vertex Y is not the
                -- canonical player's eye height. Put the source in front of
                -- the face and look backwards through the visor opening.
                anchor=pose:inverse():transformPoint(face.targetMesh:getWorldTransformationRaw():transformPoint(center))
                anchor=anchor+vec3(0,0,.18)
            end
        end
        local originLocal=anchor+vec3(0,r.RAIN_VISOR_OPTICS_SOURCE_HEIGHT,r.RAIN_VISOR_OPTICS_SOURCE_OFFSET)
        local origin=pose:transformPoint(originLocal)
        local look=pose:transformVector(vec3(0,-math.sin(pitch),-math.cos(pitch))):normalize()
        local up=pose:transformVector(vec3(0,math.cos(pitch),-math.sin(pitch))):normalize()
        requireUpdate(d.probeUpdate(self.sourceShot,refs,origin,look,up,r.RAIN_VISOR_OPTICS_SOURCE_FOV))
        self.sourceView=self.sourceShot:viewMatrix():clone();self.sourceProjection=self.sourceShot:projectionMatrix():clone()
        self.sourceOrigin=origin:clone();self.sourceOriginLocal=originLocal:clone()
        requireUpdate(self.sourceDepth:update(origin,look,up,r.RAIN_VISOR_OPTICS_SOURCE_FOV))
        self.sourceReady=true
        self.sourceStatus=string.format('Native HDR source %dx%d: supplemental light, four-tap depth/ID confidence; BVH image retained',width,height)
    end
    function st:updateBright(scene,maxMip)
        local w,h=math.max(1,math.floor(d.width()/2)),math.max(1,math.floor(d.height()/2))
        local mips=math.floor(math.log(math.max(w,h))/math.log(2))+1
        if self.bright and (self.brightW~=w or self.brightH~=h) then self.bright:dispose();self.bright=nil end
        self.bright=self.bright or canvas(w,h,mips)
        self.brightW=w;self.brightH=h
        self.brightMaxMip=mips-1
        requireUpdate(self.bright:updateSceneWithShader({async=false,blendMode=render.BlendMode.Opaque,shader=shader('visorOpticsBright'),
            textures={txOptScene=scene,txOptAverage=scene},values={gOptSceneMaxMip=maxMip,
                gOptBrightInvSource=vec2(1/d.width(),1/d.height()),
                gOptBrightThreshold=r.RAIN_VISOR_OPTICS_GHOST_THRESHOLD,gOptBrightRelative=r.RAIN_VISOR_OPTICS_BRIGHT_RELATIVE}}))
        requireUpdate(self.bright:mipsUpdate())
    end
    function st:needsComposite()
        if not r.RAIN_VISOR_OPTICS_ENABLED then return false end
        if r.RAIN_VISOR_OPTICS_DEBUG>0 then return true end
        local interior=r.RAIN_VISOR_OPTICS_TIER>=1 and
            (r.RAIN_VISOR_OPTICS_REFLECTION_GAIN>0 or r.RAIN_VISOR_OPTICS_DOUBLE_GAIN>0)
        local glare=r.RAIN_VISOR_OPTICS_EFFECT_GAIN>0 and
            (r.RAIN_VISOR_OPTICS_DUST_GAIN>0 or r.RAIN_VISOR_OPTICS_SMUDGE_GAIN>0
                or r.RAIN_VISOR_OPTICS_SUN_DUST_GAIN>0 or r.RAIN_VISOR_OPTICS_TIER>=2 and
                (r.RAIN_VISOR_OPTICS_GHOST_GAIN>0 or r.RAIN_VISOR_OPTICS_SCRATCH_GAIN>0))
        return interior or glare
    end
    function st:draw(scene,maxMip)
        if not self:needsComposite() then return end
        self:updateMask();local sim=ac.getSim();local pose=d.pose();if not pose then return end
        local e=d.editor('GLASS_INT_FX');if not e or not e.targetMesh or #e.targetMesh~=1 or e.visible==false then return end
        self:updateBright(scene,maxMip)
        local light,side=self:updateSun(sim);local inverse=pose:inverse()
        local localLight=inverse:transformVector(light):normalize()
        local opening=self.bakeLook and self.bakePose:inverse():transformVector(self.bakeLook):normalize()
            or inverse:transformVector(sim.cameraLook):normalize()
        local worldUp=inverse:transformVector(vec3(0,1,0)):normalize()
        local sun=rgb(sim.lightColor.r,sim.lightColor.g,sim.lightColor.b)
        local tint=rgb(r.RAIN_VISOR_OPTICS_TINT_R,r.RAIN_VISOR_OPTICS_TINT_G,r.RAIN_VISOR_OPTICS_TINT_B)
        if self.ready and r.RAIN_VISOR_OPTICS_TIER>=1 then
            self.lighting=self.lighting or {async=false,blendMode=render.BlendMode.Opaque,shader='#define OPT_LIGHTING 1\n'..shader('rainVisorOptics'),textures={},values={}}
            local p=self.lighting;p.textures={txOptHit=self.hit,txOptSurface=self.surface,txOptMaterial=self.material,
                txOptSH=self.shA,txOptAO=self.aoA,txOptSunVisibility=self.sunA,txOptScene=scene,txOptGlass=self.glass,
                txOptNative=self.sourceReady and self.sourceShot or false,txOptNativeDepth=self.sourceReady and self.sourceDepth or false}
            p.values={gOptLocalLight=localLight,gOptSun=sun,gOptTint=tint,gOptPose=pose,
                gOptOpeningLocal=opening,gOptWorldUpLocal=worldUp,
                gOptOpeningCosLo=r.RAIN_VISOR_LAYER_SHADOW_COS_LO or -.05,
                gOptOpeningCosHi=r.RAIN_VISOR_LAYER_SHADOW_COS_HI or .35,
                gOptEyeLocal=self.eyeLocal,gOptBakeProjectionInverse=self.projection:inverse(),
                gOptBakeViewInverse=self.view:inverse(),gOptBakePoseInverse=self.bakePose:inverse(),
                gOptSky=sim.skyColor or rgb(1,1,1),gOptHorizon=sim.horizonColor or sim.fogColor or rgb(1,1,1),
                gOptSceneMaxMip=maxMip,gOptAmbient=r.RAIN_VISOR_OPTICS_AMBIENT,gOptAmbientAO=r.RAIN_VISOR_OPTICS_AMBIENT_AO,
                gOptBounce=r.RAIN_VISOR_LAYER_SUN_BOUNCE,
                gOptBounceBase=r.RAIN_VISOR_LAYER_BOUNCE_BASE or .29,
                gOptNativeReady=self.sourceReady and 1 or 0,gOptSourceView=self.sourceView or pose,
                gOptSourceProjection=self.sourceProjection or pose,gOptSourceOriginLocal=self.sourceOriginLocal or vec3(),
                gOptDebug=r.RAIN_VISOR_OPTICS_DEBUG}
            requireUpdate(self.radiance:updateSceneWithShader(p));requireUpdate(self.radiance:mipsUpdate())
            if self.statsRequested and not self.statsPending then self:readStats(scene,maxMip,localLight) end
        end
        self.composite=self.composite or {async=false,transform='original',shader='#define OPT_LIGHTING 0\n'..shader('rainVisorOptics'),textures={},values={}}
        local p=self.composite;p.mesh=e.targetMesh
        p.textures={txOptScene=scene,txOptMask=self.mask,txOptSunVisibility=self.sunA,
            txOptBright=self.bright,
            txOptHit=self.ready and self.hit or false,txOptSurface=self.ready and self.surface or false,
            txOptGlass=self.ready and self.glass or false,txOptSH=self.ready and self.shA or false,
            txOptAO=self.ready and self.aoA or false,txOptRadiance=self.ready and self.radiance or false}
        local target=render.getRenderTargetSize();local h=d.height();local tan=math.tan(math.rad(sim.cameraFOV)*.5)
        local delta=self.ready and inverse:transformPoint(sim.cameraPosition)-self.eyeLocal or vec3()
        local cameraDelta=self.ready and self.view:transformVector(self.bakePose:transformVector(delta)) or vec3()
        p.values={gOptEye=sim.cameraPosition,gOptPose=pose,gOptPoseInverse=inverse,
            gOptBakePose=self.bakePose or pose,gOptBakeEye=self.bakeEye or sim.cameraPosition,
            gOptBakeView=self.view or pose,gOptBakeProjection=self.projection or pose,
            gOptEyeDeltaProjection=vec2(cameraDelta.x/tan/(d.width()/h)*.5,-cameraDelta.y/tan*.5),
            gOptInvTarget=vec2(1/target.x,1/target.y),gOptProjectionScale=vec2(.5/tan/(d.width()/h),.5/tan),
            gOptCameraSide=side,gOptCameraUp=sim.cameraUp,gOptLightWorld=light,gOptLocalLight=localLight,
            gOptSun=sun,gOptTier=r.RAIN_VISOR_OPTICS_TIER,gOptInteriorReady=self.ready and 1 or 0,
            gOptNormalStrength=0,gOptSceneMaxMip=maxMip,gOptRadianceMaxMip=(self.mips or 1)-1,
            gOptMaskAngularScale=(self.maskTexture and 256 or 64)/tan,gOptReflectionAngularScale=(self.h or 256)*.5/tan,
            gOptBakeScale=target.x/(self.w or 512),gOptPupil=r.RAIN_VISOR_OPTICS_PUPIL,
            gOptDefocus=r.RAIN_VISOR_OPTICS_DEFOCUS_MIP,gOptReflectionBlur=r.RAIN_VISOR_OPTICS_REFLECTION_BLUR,
            gOptThickness=r.RAIN_VISOR_OPTICS_THICKNESS,gOptReflectionGain=r.RAIN_VISOR_OPTICS_REFLECTION_GAIN,
            gOptDoubleGain=r.RAIN_VISOR_OPTICS_DOUBLE_GAIN,gOptDustGain=r.RAIN_VISOR_OPTICS_DUST_GAIN,
            gOptSmudgeGain=r.RAIN_VISOR_OPTICS_SMUDGE_GAIN,gOptSunDustGain=r.RAIN_VISOR_OPTICS_SUN_DUST_GAIN,
            gOptAnisotropy=r.RAIN_VISOR_OPTICS_ANISOTROPY,gOptGhostShift=r.RAIN_VISOR_OPTICS_GHOST_SHIFT,
            gOptGhostMip=r.RAIN_VISOR_OPTICS_GHOST_MIP,gOptGhostThreshold=r.RAIN_VISOR_OPTICS_GHOST_THRESHOLD,
            gOptGhostGain=r.RAIN_VISOR_OPTICS_GHOST_GAIN,gOptScratchGain=r.RAIN_VISOR_OPTICS_SCRATCH_GAIN,
            gOptScratchStep=r.RAIN_VISOR_OPTICS_SCRATCH_STEP,gOptDebug=r.RAIN_VISOR_OPTICS_DEBUG,
            gOptEffectGain=r.RAIN_VISOR_OPTICS_EFFECT_GAIN,gOptDebugGain=r.RAIN_VISOR_OPTICS_DEBUG_GAIN,
            gOptBrightMaxMip=self.brightMaxMip,
            gOptDebugOverlay=r.RAIN_VISOR_OPTICS_DEBUG_OVERLAY and 1 or 0}
        local visible=e.targetMesh:isVisible(1)
        render.setBlendMode(render.BlendMode.BlendPremultiplied);render.setDepthMode(render.DepthMode.ReadOnly);render.setCullMode(render.CullMode.None)
        local ok,result=pcall(function() e.targetMesh:setVisible(true,false);return render.mesh(p) end)
        e.targetMesh:setVisible(visible,false)
        if not ok then error(result) end;requireUpdate(result)
        self.draws=self.draws+1;self.drawTier=r.RAIN_VISOR_OPTICS_TIER
    end
    function st:readStats(scene,maxMip,localLight)
        self.statsCanvas=self.statsCanvas or canvas(10,1,1,render.TextureFormat.R32.Float)
        requireUpdate(self.statsCanvas:updateSceneWithShader({async=false,blendMode=render.BlendMode.Opaque,shader=shader('visorOpticsStats'),textures={
            txOptHit=self.hit,txOptAO=self.aoA,txOptSH=self.shA,txOptSunVisibility=self.sunA,
            txOptScene=scene,txOptRadiance=self.radiance},values={gOptSceneMaxMip=maxMip,gOptLocalLight=localLight,
                gOptRadianceMaxMip=(self.mips or 1)-1}}))
        self.statsRequested=false;self.statsPending=true;self.statsError=nil
        local generation=self.statsGeneration or 0;local key=self.key
        self.statsCanvas:accessData(function(err,data)
            if generation~=(self.statsGeneration or 0) then if data then data:dispose() end;return end
            self.statsPending=false
            if err then self.statsError=err;if data then data:dispose() end;return end
            if not data then self.statsError='No diagnostics data returned';return end
            if key==self.key then
                self.stats={};for i=0,9 do self.stats[i+1]=data:floatValue(i,0) end
            end
            data:dispose()
        end)
    end
    function st:ui()
        ui.separator();ui.text('Cached visor optics (HDR)')
        local changed=false
        if ui.checkbox('Enable cached visor optics',r.RAIN_VISOR_OPTICS_ENABLED) then
            r.RAIN_VISOR_OPTICS_ENABLED=not r.RAIN_VISOR_OPTICS_ENABLED;changed=true
            if not r.RAIN_VISOR_OPTICS_ENABLED then self:dispose() end
        end
        if not r.RAIN_VISOR_OPTICS_ENABLED then if changed then d.dirty() end;return end
        if ui.checkbox('Native HDR interior source (local lights)',r.RAIN_VISOR_OPTICS_NATIVE_SOURCE) then
            r.RAIN_VISOR_OPTICS_NATIVE_SOURCE=not r.RAIN_VISOR_OPTICS_NATIVE_SOURCE;changed=true
        end
        for _,item in ipairs({{'Fit native source to face','SOURCE_AUTO_FIT'},
            {'Prebaked dust / scratch pattern','PATTERN_TEXTURE'},{'Effect debug over scene (16-18)','DEBUG_OVERLAY'}}) do
            local key='RAIN_VISOR_OPTICS_'..item[2]
            if ui.checkbox(item[1],r[key]) then r[key]=not r[key];changed=true end
        end
        for _,s in ipairs({
            {'Tier: 0 dust / 1 interior / 2 ghosts + scratches','TIER',0,2,'%.0f'},
            {'Debug mode','DEBUG',0,19,'%.0f'},
            {'Effect debug display gain (16-18)','DEBUG_GAIN',1,20,'%.1f'},
            {'Final + debug effect gain','EFFECT_GAIN',0,20,'%.2f'},
            {'Bright source / scene mean threshold','BRIGHT_RELATIVE',1,10,'%.2f'},
            {'Bake width','WIDTH',128,4096,'%.0f px'}, {'Trace range','TRACE_RANGE',.1,3,'%.2f m'},
            {'Material normal influence (estimated lighting)','MATERIAL_NORMAL',0,2,'%.2f'},
            {'Native source width','SOURCE_WIDTH',256,4096,'%.0f px'},
            {'Native source offset','SOURCE_OFFSET',0,.15,'%.3f m'},
            {'Native source height','SOURCE_HEIGHT',-.1,.1,'%.3f m'},
            {'Native source pitch','SOURCE_PITCH',-45,45,'%.1f deg'},
            {'Native source FOV','SOURCE_FOV',60,150,'%.1f deg'},
            {'Band transmission','BAND_TRANSMISSION',0,1,'%.2f'}, {'Glass transmission','GLASS_TRANSMISSION',0,1,'%.2f'},
            {'Tint red','TINT_R',0,1,'%.2f'},{'Tint green','TINT_G',0,1,'%.2f'},{'Tint blue','TINT_B',0,1,'%.2f'},
            {'Interior ambient fill (AO weighted)','AMBIENT',0,2,'%.2f'}, {'Reflection gain','REFLECTION_GAIN',0,10,'%.2f'},
            {'Ambient AO weighting','AMBIENT_AO',0,1,'%.2f'},
            {'Fallback interior sun bounce','RAIN_VISOR_LAYER_SUN_BOUNCE',0,1,'%.2f'},
            {'Fallback indirect sun base','RAIN_VISOR_LAYER_BOUNCE_BASE',0,1,'%.2f'},
            {'Reflection blur (additional MIP)','REFLECTION_BLUR',0,5,'%.2f'}, {'Internal double-image gain','DOUBLE_GAIN',0,5,'%.2f'},
            {'Visor thickness','THICKNESS',0,.010,'%.4f m'}, {'Pupil diameter','PUPIL',0,.008,'%.4f m'},
            {'Mask defocus (additional MIP)','DEFOCUS_MIP',0,6,'%.2f'},
            {'Dust density','DUST_DENSITY',0,2,'%.2f'}, {'Dust glare gain','DUST_GAIN',0,.2,'%.3f'},
            {'Smudge glare gain','SMUDGE_GAIN',0,.2,'%.3f'}, {'Analytic sun scatter gain','SUN_DUST_GAIN',0,.2,'%.4f'},
            {'Scatter anisotropy','ANISOTROPY',0,.95,'%.2f'}, {'External ghost gain','GHOST_GAIN',0,5,'%.2f'},
            {'Ghost shift','GHOST_SHIFT',0,100,'%.1f px'}, {'Ghost blur MIP','GHOST_MIP',0,8,'%.2f'},
            {'Bright source HDR threshold','GHOST_THRESHOLD',0,100,'%.2f'}, {'Scratch density','SCRATCH_DENSITY',0,2,'%.2f'},
            {'Scratch gain','SCRATCH_GAIN',0,.2,'%.3f'}, {'Scratch fan step','SCRATCH_STEP',0,20,'%.2f px'},
            {'Mask seed','SEED',0,100,'%.0f'},
            {'Shadow probe calibration','SHADOW_PROBE_GAIN',.1,4,'%.2f'},
        }) do
            local key=s[2]:match('^RAIN_') and s[2] or 'RAIN_VISOR_OPTICS_'..s[2]
            local value,edit=ui.slider(s[1],r[key],s[3],s[4],s[5])
            if edit then r[key]=(s[2]=='TIER' or s[2]=='DEBUG' or s[2]=='WIDTH' or s[2]=='SEED') and math.floor(value+.5) or value;changed=true end
        end
        ui.textWrapped('Debug: 0 final / 1 IDs / 2 AO / 3 SH / 4-7 mask / 8 PSF sum / 9 CoC / 10 HDR radiance / 11 sun visibility / 12 HDR reflection / 13 HDR glare + ghosts + scratches / 14 native source coverage / 15 ambient fill / 16 dust / 17 ghosts / 18 scratches / 19 extracted bright sources')
        ui.textWrapped('Cached E1 uses geometric INT normals; E2/E3 stays independent. Dust and smudge scatter apply in every tier; ghosts and scratches require tier 2. Zero reflection, double-image and Final effect gains bypass the additional draw. Effect debug gain 1 + over-scene preview compares Final energy. Prebaked pattern seed is fixed at 17.')
        if self.w then
            ui.text(string.format('Actual bake: %dx%d | %d MIPs | buffers ~%.0f MiB',self.w,self.h,self.mips,
                self.w*self.h*(36+32+8*4/3)/1048576))
        end
        ui.textWrapped(self.sourceStatus or 'Native source pending')
        if self.sourceReady and self.sourceShot then
            ui.text('Native source colour (unprojected)');ui.image(self.sourceShot,vec2(256,171))
        end
        if ui.button('Rebake cached optics') then
            self:disposeBake();self.pendingKey=nil;self.pendingParts=nil;self.completedKey=nil
            if d.recheck then d.recheck() end
        end
        ui.textWrapped(self.error or self.status)
        ui.text(string.format('Bake starts: %d | completed: %d | progress: %d/44',self.bakes,self.completedBakes,self.step))
        ui.text(string.format('Composite draws: %d | last tier: %s',self.draws,tostring(self.drawTier or '-')))
        ui.textWrapped('Last cache change: '..(self.lastInvalidation or 'None'))
        ui.textWrapped(self.shadowStatus or 'Sun visibility pending')
        if self.ready and ui.button('Read lighting diagnostics') then self.statsRequested=true end
        if self.statsPending or self.statsRequested then ui.text('Lighting diagnostics pending') end
        if self.statsError then ui.textWrapped('Lighting diagnostics: '..self.statsError) end
        if self.stats then
            local s=self.stats
            ui.text(string.format('Sampled hit %.1f%% | AO %.3f | SH %.3f | external sun %.3f',s[1]*100,s[2],s[3],s[4]))
            ui.text(string.format('HDR mean: scene %.3f | hit radiance %.3f',s[5],s[6]))
            ui.text(string.format('Hit radiance MIP 1 / 2 / 4: %.3f / %.3f / %.3f',s[7],s[8],s[9]))
            ui.text(string.format('Native source coverage on sampled hits: %.1f%%',s[10]*100))
        end
        if self.mask then ui.image(self.mask,vec2(256,256)) end
        if changed then d.dirty() end
    end
    return st
end
