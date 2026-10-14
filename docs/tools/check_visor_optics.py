"""Compile all optics passes, test the actual Lua cache and bake lifecycle."""
from pathlib import Path
import re, runpy, subprocess, tempfile, json, struct, hashlib
import numpy as np
root=Path(__file__).resolve().parents[2]
folder=root/'shaders'
trace=(folder/'visorOpticsTrace.hlsl').read_text()
parts={name:(folder/(name+'.hlsl')).read_text() for name in
       ['visorOpticsBake','visorOpticsVisibility','visorOpticsMask','visorOpticsBright','visorOpticsSun','visorOpticsProbe','visorOpticsStats','rainVisorOptics']}
text=trace+'\n'+'\n'.join(parts.values())
textures=set(re.findall(r'\btxOpt\w+',text))
values=set(re.findall(r'\bgOpt\w+',text))
textures.discard('txOpt');values.discard('gOpt')
for key in ['Frame','Rubber','Fabric','Face','Balaklava','Cam','CamCover','CamFabric','Band']:
    values.update('gOpt'+key+x for x in ['Inverse','Visible','Records'])
types={}
for key in ['Pose','PoseInverse','BakePose','BakeView','BakeProjection','BakePoseInverse','BakeViewInverse','BakeProjectionInverse','SourceView','SourceProjection']:
    types['gOpt'+key]='float4x4'
for key in ['Frame','Rubber','Fabric','Face','Balaklava','Cam','CamCover','CamFabric','Band']:types['gOpt'+key+'Inverse']='float4x4'
for key in ['Frame','Rubber','Fabric','Face','Balaklava','Cam','CamCover','CamFabric','Band']:types['gOpt'+key+'Records']='float3'
for key in ['Eye','EyeLocal','BakeEye','LocalLight','Sun','Tint','Sky','Horizon','CameraSide','CameraUp','LightWorld','SourceOriginLocal','OpeningLocal','WorldUpLocal']:
    types['gOpt'+key]='float3'
for key in ['SunUV','InvTarget','EyeDeltaProjection','ProjectionScale','BrightInvSource','NativePixelScale']:types['gOpt'+key]='float2'
header='struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;};\n'
header+='SamplerState samPointClamp,samLinearClamp;\n'
header+='\n'.join(types.get(key,'float')+' '+key+';' for key in sorted(values))+'\n'
fxc='C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe'
with tempfile.TemporaryDirectory(prefix='optics_compile_',dir=root/'docs/tools') as tmp:
    passes=[]
    for index in range(4):
        bindings=['txOptGeometry','txOptVisorNormal']
        if index==1:bindings+=['txOptNormal','txOptMaps']
        if index==2:bindings+=['txOptDiffuse','txOptMaps']
        passes.append((f'OpticsBake{index}',f'#define OPT_BAKE_PASS {index}\n'+trace+'\n'+parts['visorOpticsBake'],bindings))
    for name,code in parts.items():
        if name=='visorOpticsBake':continue
        if name=='visorOpticsVisibility':
            code=trace+'\n'+code
            bindings=['txOptGeometry','txOptBandDiffuse','txOptHit','txOptSurface','txOptPrevious']
        elif name=='rainVisorOptics':
            code='#define OPT_LIGHTING 0\n'+code
            bindings=['txOptScene','txOptMask','txOptSunVisibility','txOptBright','txOptHit','txOptSurface','txOptGlass','txOptSH','txOptAO','txOptRadiance','txOptNativeDepth']
        elif name=='visorOpticsMask':
            passes.append(('OpticsMaskTexture','#define OPT_MASK_TEXTURE 1\n'+code,['txOptPattern']))
            code='#define OPT_MASK_TEXTURE 0\n'+code;bindings=[]
        else:bindings=sorted(set(re.findall(r'\btxOpt\w+',code)))
        passes.append((name,code,bindings))
    passes.append(('OpticsLighting','#define OPT_LIGHTING 1\n'+parts['rainVisorOptics'],
                   ['txOptHit','txOptSurface','txOptMaterial','txOptAO','txOptSH','txOptSunVisibility','txOptScene','txOptGlass','txOptNative','txOptNativeDepth']))
    for name,code,bindings in passes:
        assert len(bindings)<=11,(name,bindings)
        code=code.replace('main(PS_IN pin)','main(PS_IN pin):SV_TARGET')
        path=Path(tmp)/(name+'.hlsl');path.write_text(header+'\n'.join('Texture2D '+key+';' for key in bindings)+'\n'+code)
        subprocess.run([fxc,'/nologo','/T','ps_5_0','/E','main','/Ges','/WX','/Fo',str(Path(tmp)/(name+'.cso')),str(path)],check=True)
print('PASS: all thirteen optics shader variants compile with only their actual texture bindings (maximum 11, limit 11)')

meta=json.loads((root/'texture/GLASS/E1_GEOMETRY/optics_materials.json').read_text())
manifest=json.loads((root/'texture/GLASS/E1_GEOMETRY/manifest.json').read_text())
atlas=np.frombuffer((root/'texture/GLASS/E1_GEOMETRY/optics_geometry.dds').read_bytes(),'<f4',offset=148).reshape(-1,4)
assert np.isfinite(atlas).all()
for key in ['frame','rubber','fabric','face','balaklava','cam','camCover','camFabric','band']:
    for kind,start in zip(['nodes','triangles','normals'],meta[key]['records']):
        original=np.frombuffer((root/f'texture/GLASS/E1_GEOMETRY/{key}_{kind}.dds').read_bytes(),'<f4',offset=148).reshape(-1,4)
        if kind=='nodes':count=int(original[1,3])*2
        elif key=='band':count=(meta[key]['records'][2]-meta[key]['records'][1])//4*(4 if kind=='triangles' else 3)
        else:count=manifest['meshes'][key]['triangles']*(4 if kind=='triangles' else 3)
        assert np.array_equal(atlas[start:start+count],original[:count]),(key,kind)
assert meta['sha256']==manifest['sha256']==hashlib.sha256((root/manifest['model']).read_bytes()).hexdigest()
for key in ['frame','rubber','fabric','face','balaklava','cam','camCover','camFabric']:
    data=np.frombuffer((root/f'texture/GLASS/E1_GEOMETRY/{key}_normals.dds').read_bytes(),'<f4',offset=148).reshape(-1,4)
    assert np.isfinite(data).all() and len(data)>=manifest['meshes'][key]['triangles']*3
    for name in meta[key]['textures'].values():assert (root/'texture/GLASS/E1_GEOMETRY'/name).read_bytes().startswith((b'DDS ',b'\x89PNG'))
assert abs(sum([.30,.24,.18,.12,.09,.07])-1)<1e-12
assert .04**2==.0016
print('PASS: current model hashes, smooth-normal buffers, authored material textures, PSF energy and F^2')

env=runpy.run_path(str(root/'docs/tools/check_baked_housing.py'));lua=env['lua']
lua.globals().appFolder=root.as_posix()
source=(root/'realvisor.lua').read_text(encoding='utf-8-sig')
runtime={}
for key,value in re.findall(r'(RAIN_VISOR_OPTICS_\w+)\s*=\s*([\w.]+)',source):
    runtime[key]=value=='true' if value in ['true','false'] else float(value)
runtime['MODEL_PATH']=manifest['model'];runtime['RAIN_VISOR_LAYER_SUN_BOUNCE']=.19;runtime['RAIN_VISOR_LAYER_BOUNCE_BASE']=.29
lua.globals().optRuntime=lua.table_from(runtime);lua.globals().optFolder=root.as_posix();lua.globals().optHash=meta['sha256']
lua.execute('''
    local mt={};mt.__index={}
    function vec3(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},mt) end
    mt.__add=function(a,b) return vec3(a.x+b.x,a.y+b.y,a.z+b.z) end
    mt.__sub=function(a,b) return vec3(a.x-b.x,a.y-b.y,a.z-b.z) end
    mt.__mul=function(a,b) return vec3(a.x*b,a.y*b,a.z*b) end
    mt.__unm=function(a) return vec3(-a.x,-a.y,-a.z) end
    function mt.__index:clone() return vec3(self.x,self.y,self.z) end
    function mt.__index:dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
    function mt.__index:cross(b)
        assert(not self.readOnly,'attempt to write to constant location')
        local x,y,z=self.y*b.z-self.z*b.y,self.z*b.x-self.x*b.z,self.x*b.y-self.y*b.x
        self.x,self.y,self.z=x,y,z;return self
    end
    function mt.__index:normalize()
        assert(not self.readOnly,'attempt to write to constant location')
        local k=1/math.sqrt(self:dot(self));self.x,self.y,self.z=self.x*k,self.y*k,self.z*k;return self
    end
    function constVec(x,y,z) local v=vec3(x,y,z);v.readOnly=true;return v end
    function vec2(x,y) return {x=x,y=y} end
    function rgb(r,g,b) return {r=r,g=g,b=b} end
    function rgbm(r,g,b,a) return {r=r,g=g,b=b,a=a} end
    world=vec3();motion=vec3()
    function matrix(offset)
        return {transformPoint=function(_,p) return p+offset end,transformVector=function(_,p) return p:clone() end,
            inverse=function() return matrix(-offset) end,clone=function() return matrix(offset:clone()) end}
    end
    sim={cameraPosition=constVec(0,0,0),cameraLook=constVec(0,0,1),cameraUp=constVec(0,1,0),cameraFOV=90,dt=.016,
        lightDirection=constVec(0,-1,0),lightColor=rgb(10,10,10),skyColor=rgb(1,1,1),horizonColor=rgb(1,1,1)}
    assert(not pcall(function() sim.cameraUp:cross(sim.cameraLook) end))
    ac={getSim=function() return sim end}
    function checkBindings(p)
        local count=0;for _ in pairs(p.textures) do count=count+1 end
        assert(count<=11,'Too many textures: '..count)
        bindingMaximum=math.max(bindingMaximum or 0,count)
        if p.values.gOptMaterialID then
            assert(count<=4 and p.values.gOptMaterialID>=1 and p.values.gOptMaterialID<=8)
            materialDraws=(materialDraws or 0)+1
            materialIDs=materialIDs or {};materialIDs[p.values.gOptMaterialID]=true
            assert(currentDepth==1,'Multi-material capture must keep nearest INT depth')
        end
    end
    render={AntialiasingMode={None=0},TextureFormat={R16G16B16A16={Float=1},R32G32B32A32={Float=2},R8G8B8A8={UNorm=3},R32={Float=4}},
        CullMode={None=0},DepthMode={Normal=1,ReadOnly=0,Off=2},BlendMode={Opaque=1,BlendPremultiplied=0},ShadersType={Main=1},
        setCullMode=function() end,setDepthMode=function(v) currentDepth=v end,setBlendMode=function() end,
        getRenderTargetSize=function() return vec2(1280,720) end,
        mesh=function(p) checkBindings(p);drawParams=p;if meshFail then error('mesh failed') end;return not meshPending end}
    captured=0;canvasUpdates=0;disposed=0
    function resource()
        return {dispose=function() disposed=disposed+1 end,clear=function() end,mipsUpdate=function() return true end,
            updateSceneWithShader=function(self,p)
                assert(p.blendMode==render.BlendMode.Opaque,'Optics data must overwrite, including alpha-zero pixels')
                checkBindings(p);canvasUpdates=canvasUpdates+1;self.params=p;return not pending
            end,
            accessData=function(self,callback) readbackCallback=callback;readbacks=(readbacks or 0)+1 end}
    end
    ui={ExtraCanvas=function() return resource() end}
    function ac.GeometryShot(callbacks)
        local shot=resource()
        for _,name in ipairs({'setSky','setParticles','setClearColor','setClippingPlanes','setOriginalLighting','setShadersType','setOpaqueAlphaFix','setTransparentPass'}) do shot[name]=function() end end
        function shot:update(origin,look,up,fov)
            self.camera={origin=origin,look=look,up=up,fov=fov}
            captured=captured+1;if callbacks.opaque then callbacks.opaque() end;return not pending
        end
        function shot:viewMatrix() return matrix(vec3()) end
        function shot:projectionMatrix() return matrix(vec3()) end
        return shot
    end
    meshes={}
    for _,name in ipairs({'GLASS_INT_FX','GLASS_EXT_FX','FRAME_MAIN','BAND_INNER','BODY_FABRIC_TRACE','DRIVER_FACE','DRIVER_BALAKLAVA','CAM','CAM_COVER','CAM_FABRIC'}) do
        local ref=refs({{visible=false}})
        function ref:getWorldTransformationRaw() return matrix(world+motion) end
        function ref:getMaterialPropertyValue(key) return key=='ksSpecular' and (self.specular or .5) or 16 end
        meshes[name]={targetMesh=ref,visible=true}
    end
    clock=0;os.clock=function() return clock end
    dependency={folder=optFolder,runtime=optRuntime,editor=function(name) return meshes[name] end,
        pose=function() return matrix(world+motion) end,motionWorld=function() return motion end,
        width=function() return 1280 end,height=function() return 720 end,profileKey=function() return 'profile' end,
        validate=function() return true end,validationStatus=function() return 'valid' end,modelHash=function() return optHash end,
        dirty=function() end}
''')
factory=lua.execute((root/'visor_optics.lua').read_text());lua.globals().optics=factory(lua.globals().dependency)
lua.execute('''
    optics:updateBake();assert(optics.step==1 and not optics.ready and captured==1,optics.status..' step='..optics.step..' captured='..captured)
    local firstKey=optics.key
    for i=1,43 do clock=clock+.016;optics:updateBake() end
    assert(optics.step==44 and not optics.ready and captured==4)
    assert(materialDraws==16);for id=1,8 do assert(materialIDs[id]) end
    optics:updateBake();assert(optics.ready)
    for _,p in ipairs(optics.bakeParams.surface) do
        assert(p.values.gOptMaterialSpecular==.5 and p.textures.txOptMaps)
    end
    for i=1,10 do optics:updateBake() end
    assert(captured==4 and optics.bakes==1 and optics.key==firstKey)
    world=vec3(10,2,3);sim.cameraPosition=world:clone();optics:updateBake()
    assert(optics.ready and optics.key==firstKey and optics.bakes==1)
    motion=vec3(.015,0,0);optics:updateBake()
    assert(optics.ready and optics.key==firstKey and optics.bakes==1)
    optics:draw(resource(),8)
    assert(optics.sunA.params.values.gOptSunBlend==1,'Light visibility must not lag the current frame')
    assert(optics.lighting.values.gOptBounceBase==.29)
    assert(optics.lighting.textures.txOptGlass==optics.glass and optics.lighting.values.gOptEyeLocal==optics.eyeLocal)
    assert(optics.lighting.values.gOptBakeProjectionInverse and optics.lighting.values.gOptBakeViewInverse and optics.lighting.values.gOptBakePoseInverse)
    assert(drawParams.values.gOptInteriorReady==1 and drawParams.values.gOptTier==2)
    assert(drawParams.values.gOptEyeDeltaProjection.x<0)
    assert(not meshes.GLASS_INT_FX.targetMesh:isVisible(1))
    local draws=optics.draws
    for tier=0,2 do
        optRuntime.RAIN_VISOR_OPTICS_TIER=tier;optics:draw(resource(),8)
        assert(optics.drawTier==tier and optics.draws==draws+tier+1)
        assert(sim.cameraUp.x==0 and sim.cameraUp.y==1 and sim.cameraUp.z==0)
        assert(sim.cameraLook.x==0 and sim.cameraLook.y==0 and sim.cameraLook.z==1)
    end
    local oldRadiance=optics.radiance;optics:draw(resource(),8)
    assert(optics.radiance==oldRadiance and captured==4)
    assert(not readbacks,'Diagnostics must not run unless explicitly requested')
    optics.statsRequested=true;optics:draw(resource(),8)
    assert(optics.statsPending and readbacks==1)
    local received={dispose=function(self) self.disposed=true end,floatValue=function(_,x,y) assert(y==0);return x+.25 end}
    readbackCallback(nil,received)
    assert(not optics.statsPending and received.disposed and optics.stats[1]==.25 and optics.stats[6]==5.25 and optics.stats[9]==8.25 and optics.stats[10]==9.25)
    optics:draw(resource(),8);assert(readbacks==1,'No automatic readback per frame')
    optics.statsRequested=true;optics:draw(resource(),8)
    local staleCallback=readbackCallback
    optics:disposeBake();received.disposed=false;staleCallback(nil,received)
    assert(received.disposed and not optics.stats and not optics.statsPending,'Stale readback must not restore disposed bake data')
    sim.cameraFOV=100;optics:updateBake();assert(not optics.ready and not optics.hit)
    clock=clock+.3;optics:updateBake();assert(optics.bakes==2 and optics.step==1)
    pending=true;local ok=pcall(function() optics:updateBake() end)
    assert(ok and optics.step==1);pending=false
    meshPending=true;local previousStep=optics.step
    ok=pcall(function() optics:updateBake() end)
    assert(ok and optics.step==previousStep and optics.capturePending.surface and optics.pending)
    meshPending=false
    meshFail=true;ok=pcall(function() optics:updateBake() end)
    assert(not ok and optics.step==1 and not meshes.GLASS_INT_FX.targetMesh:isVisible(1));meshFail=false
    optRuntime.RAIN_VISOR_OPTICS_TIER=0;optics:updateBake();assert(not optics.hit and not optics.ready)
    optics:draw(resource(),8);assert(drawParams.values.gOptInteriorReady==0 and drawParams.values.gOptTier==0)
    optics:dispose();assert(not optics.mask and not optics.bright and not optics.sunA and not optics.hit)
    local probe={root={},prepared=false,captureRefs=meshes.FRAME_MAIN.targetMesh}
    dependency.probeEnsure=function() return probe end
    dependency.probeUpdate=function(shot,refs,origin,look,up,fov) return shot:update(origin,look,up,fov) end
    optics:updateExternalProbe();assert(not optics.probeReady and not optics.probeShot)
    probe.prepared=true;optics:updateExternalProbe();assert(optics.probeReady and optics.probeShot and optics.probeExpected)
    local before=captured;optics:updateExternalProbe();assert(captured==before)
    clock=clock+.2;pending=true;ok=pcall(function() optics:updateExternalProbe() end)
    assert(ok and not optics.probeReady);pending=false
    optics:updateExternalProbe();assert(optics.probeReady)
    optics:draw(resource(),8);assert(optics.sunA.params.values.gOptProbeReady==1)
    assert(optics.sunA.params.textures.txOptProbe==optics.probeShot)
    optics:dispose();assert(not optics.probeShot and not optics.probeExpected)
    assert(bindingMaximum==10)
''')
print('PASS: actual Lua 44-step bake, steady cache/no trace, world motion, 15mm parallax, FOV invalidation, pending/failure cleanup, T0 and native scalar probe')
print('PASS: const CSP-style mutating vectors reproduce the old failure; all three tiers composite without mutating camera inputs')

# Real integration's local-frame calculator avoids cancellation of large world
# positions. Exercise it, then add world-transform jitter for 700 update ticks.
start=source.index('rainDynamicSceneCopyState.opticsLocalFrame = function()')
end=source.index('rainDynamicSceneCopyState.cachedOptics =',start)
lua.execute(source[start:end])
lua.execute('''
    function localNode(offset) return {getTransformationRaw=function() return matrix(offset) end} end
    offsetNode=localNode(vec3(.1,.02,-.03));scaleNode=localNode(vec3())
    axisPitchNode=localNode(vec3());axisYawNode=localNode(vec3());axisRollNode=localNode(vec3())
    local eye,look,up=rainDynamicSceneCopyState.opticsLocalFrame()
    assert(math.abs(eye.x+.1)<1e-8 and math.abs(eye.y+.02)<1e-8 and math.abs(eye.z-.03)<1e-8)
    assert(look.z==1 and up.y==1)
    dependency.localFrame=rainDynamicSceneCopyState.opticsLocalFrame
    dependency.localTransform=function(ref) return matrix(ref.localOffset or vec3()) end
    dependency.rootTransform=function() return matrix(vec3()) end
    dependency.probeEnsure=nil;dependency.probeUpdate=nil
    optRuntime.RAIN_VISOR_OPTICS_TIER=2
''')
lua.globals().stableOptics=factory(lua.globals().dependency)
lua.execute('''
    for tick=1,700 do
        clock=clock+.016
        world=vec3(2000+tick*.07,100,1500)
        motion=vec3(math.sin(tick)*.015,math.cos(tick)*.005,0)
        sim.cameraPosition=world+vec3((tick%2)*.0003,0,0)
        stableOptics:updateBake()
    end
    assert(stableOptics.ready and stableOptics.bakes==1 and stableOptics.completedBakes==1)
    local unchanged=stableOptics.key
    for i=1,8 do stableOptics:updateBake() end
    assert(stableOptics.key==unchanged and stableOptics.completedBakes==1)
    sim.cameraFOV=105;stableOptics:updateBake()
    assert(not stableOptics.ready and stableOptics.lastInvalidation:find('Camera FOV'))
    clock=clock+.3
    for i=1,45 do clock=clock+.016;stableOptics:updateBake() end
    assert(stableOptics.ready and stableOptics.bakes==2 and stableOptics.completedBakes==2)
    meshes.FRAME_MAIN.targetMesh.localOffset=vec3(.01,0,0);stableOptics:updateBake()
    assert(not stableOptics.ready and stableOptics.lastInvalidation:find('FRAME_MAIN local transform'))
    clock=clock+.3
    for i=1,45 do clock=clock+.016;stableOptics:updateBake() end
    assert(stableOptics.ready and stableOptics.bakes==3 and stableOptics.completedBakes==3)
    meshes.FRAME_MAIN.visible=false;stableOptics:updateBake()
    assert(not stableOptics.ready and stableOptics.lastInvalidation:find('FRAME_MAIN visibility'))
    stableOptics:dispose();meshes.FRAME_MAIN.visible=true
    local materialKey=stableOptics:cacheKey(sim,dependency.pose())
    meshes.FRAME_MAIN.targetMesh.specular=.75
    assert(stableOptics:cacheKey(sim,dependency.pose())~=materialKey,'Material specular edits must rebake the strength mask')
    meshes.FRAME_MAIN.targetMesh.specular=nil
''')
print('PASS: actual camera-attached local-frame integration, 700 moving/noisy world updates keep one completed bake; FOV/local mesh/visibility edits invalidate with reason')

# Verify script.update's native-sheet hiding before engine preparation, across
# enabled/disabled optics, while preserving native housing/mirror visibility.
start=source.index('rainDynamicSceneCopyState.visorLayerDrawnSet = function()')
end=source.index('-- FX sheets have no native mirror colour/shadow role.',start)
lua.execute(source[start:end])
lua.execute('''
    MATERIAL_EDITORS={};sceneEditors={}
    for _,name in ipairs({'GLASS_COAT_FX','GLASS_INT_FX','GLASS_EXT_FX','GLASS_RAINFX',
        'FRAME_MAIN_OVERLAY','FRAME_MAIN','FRAME_MAIN_MIRROR'}) do
        local e={meshName=name,visible=true,targetMesh=refs({{visible=true,shadows=true}})}
        MATERIAL_EDITORS[#MATERIAL_EDITORS+1]=e;sceneEditors[name]=e
    end
    rainDynamicSceneCopyState.visorLayer={}
    rainDynamicSceneCopyState.visorLayerDefs=function() return {glass={
        {mesh='GLASS_COAT_FX'},{rain=true},{mesh='GLASS_INT_FX'},{mesh='GLASS_EXT_FX'}}} end
    cfg={RUNTIME=optRuntime}
    optRuntime.RAIN_VISOR_LAYER=true;optRuntime.RAIN_VISOR_SCENE_STACK=true
    optRuntime.RAIN_VISOR_OVERLAY=false;optRuntime.RAIN_ENABLED=true
    optRuntime.RAIN_DYNAMIC_SURFACE_STATE_ENABLED=true
''')
start=source.index('-- Hide native DUMMY sheets before engine render-list/shadow preparation,')
end=source.index('-- After camera tracking, offset, motion and calibration.',start)
hide_code=source[start:end]
for enabled in (True,False):
    lua.globals().optRuntime['RAIN_VISOR_OPTICS_ENABLED']=enabled
    lua.execute(hide_code)
    lua.execute('''
        for name,e in pairs(sceneEditors) do
            local native=name=='FRAME_MAIN' or name=='FRAME_MAIN_MIRROR' or name=='FRAME_MAIN_OVERLAY'
            assert(e.visible and e.targetMesh:isVisible(1)==native)
            assert(e.targetMesh:isCastingShadows(1)==native)
        end
    ''')
lua.execute('''
    optRuntime.RAIN_VISOR_OPTICS_ENABLED=true
    meshes.GLASS_EXT_FX.visible=nil
    local before=stableOptics:cacheKey(sim,dependency.pose())
    meshes.GLASS_EXT_FX.visible=true
    assert(stableOptics:cacheKey(sim,dependency.pose())==before)
    meshes.GLASS_EXT_FX.targetMesh:setVisible(true)
    assert(stableOptics:cacheKey(sim,dependency.pose())==before)
    meshes.GLASS_EXT_FX.targetMesh:setVisible(false)
    assert(stableOptics:cacheKey(sim,dependency.pose())==before)
''')
print('PASS: main-update hides all native DUMMY/rain sheets and disables their shadows with optics on/off; native housing/mirror and logical visibility retained; temporary mesh visibility does not invalidate cache')

# Execute the actual integration helper: mutate only the isolated probe copy,
# prepare it for engine transforms, keep legacy source disabled, and hide it.
lua.execute('''
    rainDynamicSceneCopyState.visorLayerEditor=dependency.editor
    cfg={RUNTIME=optRuntime};optRuntime.RAIN_VISOR_LAYER_NATIVE_HOUSING=true
    optRuntime.RAIN_VISOR_LAYER_E1_PRIMARY=true;optRuntime.RAIN_VISOR_LAYER_E1_SOURCE_MODE=0
    visor=model();rainDynamicSceneCopyState.nativeCaptureModel={}
    axisRollNode={loadKN5=function()
        probeCopy=model()
        function probeCopy:ensureUniqueMaterials() self.unique=true end
        for _,ref in pairs(probeCopy.meshes) do
            function ref:setMaterialTexture(name,value) self[1].textures=self[1].textures or {};self[1].textures[name]=value end
            function ref:setMaterialProperty(name,value) self[1].properties=self[1].properties or {};self[1].properties[name]=value end
        end
        return probeCopy
    end}
''')
a=source.index('rainDynamicSceneCopyState.opticsProbeEnsure = function()')
b=source.index('rainDynamicSceneCopyState.cachedOptics =',a)
lua.execute(source[a:b])
lua.execute('''
    local s=rainDynamicSceneCopyState;local probe=s.opticsProbeEnsure()
    assert(probe.root.unique and #probe.captureRefs==7 and not probe.root.visible and not probe.prepared)
    assert(probe.root.meshes.FRAME_MAIN[1].properties.ksDiffuse==.05)
    local sameRoot=probe.root
    meshes.CAM.visible=false;probe=s.opticsProbeEnsure()
    assert(probe.root==sameRoot and #probe.captureRefs==6)
    meshes.CAM.visible=true;probe=s.opticsProbeEnsure()
    assert(probe.root==sameRoot and #probe.captureRefs==7)
    assert(not visor.meshes.FRAME_MAIN[1].properties)
    assert(not probe.root.meshes.DRIVER_FACE[1].visible and not probe.root.meshes.DRIVER_FACE[1].shadows)
    local legacy=model();s.nativeCaptureModel.source={root=legacy,owner=visor,captureRefs=legacy:findMeshes('FRAME_MAIN')}
    s.nativeCapturePrepare();assert(probe.prepared and probe.root.visible)
    assert(not s.nativeCaptureModel.source.prepared and not legacy.visible)
    s.nativeCaptureHide();assert(not probe.root.visible and not probe.captureRefs:isVisible(1))
''')
print('PASS: actual isolated probe material mutation, seven-mesh visible allowlist, native preparation, legacy source suppression and main visibility cleanup')

# Actual source lifecycle: wait for engine registration, capture two aligned
# passes, propagate pending/failure, resize/dispose; genuine 4K bake dimensions.
lua.execute('''
    dependency.localFrame=function() return vec3(),vec3(0,0,1),vec3(0,1,0) end
    dependency.sourceEnsure=function() return meshes.FRAME_MAIN.targetMesh,sourceOwner,sourcePrepared,sourceMembers end
    dependency.probeUpdate=function(shot,refs,origin,look,up,fov)
        sourceCamera={origin=origin:clone(),look=look:clone(),up=up:clone(),fov=fov}
        return shot:update(origin,look,up,fov)
    end
    dependency.sourceDepthDraw=function(st)
        assert(st.sourceView and st.sourceProjection and st.sourceOrigin and st.sourceOriginLocal)
        metricCalls=(metricCalls or 0)+1
    end
    sourceOwner={};sourcePrepared=false;sourceMembers='all visible'
    optRuntime.RAIN_VISOR_OPTICS_ENABLED=true;optRuntime.RAIN_VISOR_OPTICS_NATIVE_SOURCE=true
    optRuntime.RAIN_VISOR_OPTICS_TIER=2;optRuntime.RAIN_VISOR_OPTICS_WIDTH=4096
''')
lua.globals().sourceOptics=factory(lua.globals().dependency)
lua.globals().materialsForTest=lua.execute((root/'texture/GLASS/E1_GEOMETRY/optics_materials.lua').read_text())
lua.execute('''
    sourceOptics:updateNativeSource();assert(not sourceOptics.sourceReady and not sourceOptics.sourceShot)
    sourcePrepared=true;sourceOptics:updateNativeSource()
    assert(sourceOptics.sourceReady and sourceOptics.sourceWidth==1536 and metricCalls==1)
    local membershipShot=sourceOptics.sourceShot;sourceMembers='camera hidden'
    sourceOptics:updateNativeSource();assert(sourceOptics.sourceShot~=membershipShot)
    assert(sourceOptics.sourceShot.camera.origin==sourceOptics.sourceDepth.camera.origin
        and sourceOptics.sourceShot.camera.look==sourceOptics.sourceDepth.camera.look
        and sourceOptics.sourceShot.camera.up==sourceOptics.sourceDepth.camera.up
        and sourceOptics.sourceShot.camera.fov==sourceOptics.sourceDepth.camera.fov)
    assert(sourceCamera.fov==120 and sourceCamera.look.z==-1 and sourceCamera.up.y==1)
    local b=assert(materialsForTest.face.bounds)
    assert(math.abs(sourceCamera.origin.y-world.y-motion.y-(b[2]+b[5])*.5)<1e-6,
        'Fit source camera must follow actual face height, not eye height')
    optRuntime.RAIN_VISOR_OPTICS_SOURCE_AUTO_FIT=false;sourceOptics:updateNativeSource()
    assert(math.abs(sourceCamera.origin.y-world.y-motion.y)<1e-6)
    optRuntime.RAIN_VISOR_OPTICS_SOURCE_AUTO_FIT=true;sourceOptics:updateNativeSource()
    sourceOptics:startBake(sim,dependency.pose(),'4K test',vec3())
    assert(sourceOptics.w==4096 and sourceOptics.h==2304 and sourceOptics.mips==13)
    for _,p in ipairs(sourceOptics.bakeParams.hit) do assert(p.values.gOptNormalStrength==0) end
    local oldShot=sourceOptics.sourceShot;optRuntime.RAIN_VISOR_OPTICS_SOURCE_WIDTH=2048
    sourceOptics:updateNativeSource();assert(sourceOptics.sourceShot~=oldShot and sourceOptics.sourceWidth==2048)
    pending=true;local ok=pcall(function() sourceOptics:updateNativeSource() end)
    assert(ok and not sourceOptics.sourceReady);pending=false
    sourceOptics:updateNativeSource();assert(sourceOptics.sourceReady)
    optRuntime.RAIN_VISOR_OPTICS_NATIVE_SOURCE=false;sourceOptics:updateNativeSource();assert(not sourceOptics.sourceReady)
    sourceOptics:dispose();assert(not sourceOptics.sourceShot and not sourceOptics.sourceDepth and not sourceOptics.hit)
''')
print('PASS: native HDR/metric source lifecycle, preparation/pending/resize/disable/disposal, geometry normals and actual 4096x2304 bake')

# Run the real main-scene stack and draw helper, not a duplicate expression.
# Cached on/off and every tier must retain the same E2/E3 input and controls.
a=source.index('rainDynamicSceneCopyState.measure = function(')
b=source.index('local function updateRainGPUState',a)
lua.execute(source[a:b])
layers={}
for key,value in re.findall(r'^\s+(RAIN_VISOR_LAYER_\w+)\s*=\s*([\w.]+)',source,re.M):
    try: layers[key]=value=='true' if value in ['true','false'] else float(value)
    except ValueError: pass
lua.globals().layerDefaults=lua.table_from(layers)
lua.execute('''
    for key,value in pairs(layerDefaults) do optRuntime[key]=value end
    cfg.RUNTIME=optRuntime
    local colors={};colors.__index=colors
    colors.__mul=function(c,k) return rgb(c.r*k,c.g*k,c.b*k) end
    function rgb(r,g,b) return setmetatable({r=r,g=g,b=b},colors) end
    sim.cameraSide=vec3(1,0,0)
    sim.frame=1
    render.BlendMode.BlendAccurate=2
    function ui.ExtraCanvas(size,mips)
        local c=resource();c.sizeValue=size;c.levels=mips
        function c:copyFrom(src) assert(src=='dynamic::hdr');self.copies=(self.copies or 0)+1;return self end
        function c:setName(name) self.name=name;return self end
        function c:mipsUpdate() return not (failCached and self.name=='Cached optics HDR source') end
        function c:dispose() self.disposed=true end
        return c
    end
    local s=rainDynamicSceneCopyState
    s.visorLayer={shader='test layer shader',defs={housing={},glass={
        {rain=true},{mesh='GLASS_INT_FX',kind=3}}}}
    s.mainTargetWidth=1280;s.mainTargetHeight=720;s.toneReady=false;s.geometryShot='unchanged scene'
    s.visorLayerEditor=dependency.editor
    s.e1PrimaryDraw=function() end;s.e1SurfaceDraw=function() end
    initialized=true;activeEnableMode=1
    s.nativeGlass={ready=true,updates=0,update=function() return true end,
        bind=function(_,p,prefix)
            p.textures['tx'..prefix..'NativeDepth']=false;p.values['g'..prefix..'NativeOn']=0
            p.values['g'..prefix..'NativePixelScale']=vec2(1,1)
        end}
    optRuntime.RAIN_VISOR_SCENE_STACK=true;optRuntime.RAIN_VISOR_OVERLAY=false
    optRuntime.RAIN_VISOR_LAYER_OPTICS=true;optRuntime.RAIN_VISOR_LAYER_E1_SURFACE_TEST=false
    optRuntime.RAIN_VISOR_LAYER_OPTICS_INTERIOR=true
    optRuntime.RAIN_VISOR_LAYER_OPTICS_INTERIOR_SOFT_PX=4
    optRuntime.RAIN_VISOR_LAYER_OPTICS_INTERIOR_SOFT_AMOUNT=.5
    optRuntime.RAIN_VISOR_OPTICS_NATIVE_SOURCE=false;optRuntime.RAIN_VISOR_OPTICS_DEBUG=0
''')
lua.globals().rainDynamicSceneCopyState.cachedOptics=factory(lua.globals().dependency)
a=source.index('rainDynamicSceneCopyState.visorLayerDrawItem = function(')
b=source.index('-- Stage 2:',a)
lua.execute(source[a:b])
a=source.index('rainDynamicSceneCopyState.nativeGlassPrepare=function()')
b=source.index('render.onSceneReady(rainDynamicSceneCopyState.nativeGlassPrepare)',a)
lua.execute(source[a:b])

a=source.index('rainDynamicSceneCopyState.visorOpticsCapture = function(')
b=source.index('-- Glass and the routing test',a)
lua.execute(source[a:b])
lua.execute('''
    local s=rainDynamicSceneCopyState;local r=optRuntime;local vl=s.visorLayer
    local function post() assert(s.nativeGlassPrepare());s.beginMainView();return s.visorSceneStack('post') end
    r.RAIN_VISOR_OPTICS_ENABLED=false;post()
    local base=vl.opticsSource;local item=vl.defs.glass[2];local p=item.params
    assert(p.values.gLayerOptics==1 and p.textures.txLayerSource==base and vl.opticsMips==6)
    local normal,refraction,blur=p.values.gLayerOpticsNormal,p.values.gLayerOpticsRefractionPx,p.values.gLayerOpticsInteriorSoftPx
    for tier=0,2 do
        r.RAIN_VISOR_OPTICS_ENABLED=true;r.RAIN_VISOR_OPTICS_TIER=tier;post()
        assert(vl.opticsSource==base and p.textures.txLayerSource==base and vl.opticsMips==6)
        assert(p.values.gLayerOptics==1 and p.values.gLayerOpticsNormal==normal
            and p.values.gLayerOpticsRefractionPx==refraction and p.values.gLayerOpticsInteriorSoftPx==blur)
        assert(vl.cachedSceneSource~=base and vl.cachedSceneMips==11)
        assert(s.cachedOptics.composite.textures.txOptScene==vl.cachedSceneSource)
        assert(not base.disposed)
    end
    failCached=true;post();assert(vl.opticsReady and not vl.cachedSceneReady)
    assert(p.textures.txLayerSource==base and p.values.gLayerOptics==1);failCached=false
    local extra=vl.cachedSceneSource
    r.RAIN_VISOR_OPTICS_REFLECTION_GAIN=0;r.RAIN_VISOR_OPTICS_DOUBLE_GAIN=0;r.RAIN_VISOR_OPTICS_EFFECT_GAIN=0
    local draws=s.cachedOptics.draws;local updates=canvasUpdates
    for tier=0,2 do
        r.RAIN_VISOR_OPTICS_TIER=tier;assert(not s.cachedOptics:needsComposite())
        post();s.cachedOptics:draw(resource(),10)
        assert(s.cachedOptics.draws==draws and canvasUpdates==updates)
        assert(p.textures.txLayerSource==base and p.values.gLayerOptics==1)
    end
    assert(extra.disposed and not vl.cachedSceneSource)
    r.RAIN_VISOR_LAYER_OPTICS=false;r.RAIN_VISOR_OPTICS_EFFECT_GAIN=1
    post();assert(p.values.gLayerOptics==0 and p.textures.txLayerSource=='unchanged scene')
    r.RAIN_VISOR_OPTICS_ENABLED=false;post();assert(not vl.cachedSceneSource)
''')
print('PASS: actual scene stack preserves E2/E3 sources/parameters across cached toggles and tiers; failed cached capture cannot suppress E2/E3; zero gains skip captures/draws; E2/E3 remains independently switchable')
