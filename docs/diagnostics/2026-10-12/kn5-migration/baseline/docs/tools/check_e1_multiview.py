"""Actual Lua multiview orchestration: anchors, isolation, failures, disposal."""
from pathlib import Path
import runpy

root=Path(__file__).resolve().parents[2]
env=runpy.run_path(str(root/'docs/tools/check_baked_housing.py'))
lua=env['lua']
source=(root/'realvisor.lua').read_text(encoding='utf-8-sig')
lua.execute('''
    local mt={__add=function(a,b) return vec3(a.x+b.x,a.y+b.y,a.z+b.z) end}
    function vec3(x,y,z) return setmetatable({x=x,y=y,z=z},mt) end
    pose={x=10}
    function pose:inverse() return {transformPoint=function(_,p) return vec3(p.x-self.x,p.y,p.z) end} end
    function pose:transformPoint(p) return vec3(p.x+self.x,p.y,p.z) end
    axisRollNode={getWorldTransformationRaw=function() return pose end}
    sim={cameraPosition=vec3(10,0,0)};ac={getSim=function() return sim end}
    cfg={RUNTIME={RAIN_VISOR_LAYER_E1_MULTIVIEW=true,RAIN_VISOR_LAYER_E1_PRIMARY=true,
        RAIN_VISOR_LAYER_E1_SOURCE_SLOT=0,RAIN_VISOR_LAYER_E1_SOURCE_SPACING=.03,
        RAIN_VISOR_LAYER_E1_SOURCE_OFFSET=.15,RAIN_VISOR_LAYER_E1_SOURCE_QUALITY=2,
        RAIN_VISOR_LAYER_E1_SIDE_QUALITY=1,RAIN_VISOR_LAYER_E1_SOURCE_HEIGHT=.02}}
    rainDynamicSceneCopyState={}
''')
a=source.index('rainDynamicSceneCopyState.e1Source = {')
b=source.index('-- Geometry data pass:',a)
lua.execute(source[a:b])
lua.execute('''
    disposed=0;calls=0
    function resource() return {dispose=function() disposed=disposed+1 end} end
    rainDynamicSceneCopyState.e1SourceUpdate=function(st,origin,quality)
        calls=calls+1
        if origin then
            assert(not rainDynamicSceneCopyState.e1Source.ready) -- no stale source in nested render callbacks
            st.origin=origin;st.quality=quality
            st.shot=st.shot or resource();st.positionShot=st.positionShot or resource()
            if failQuality==quality then error('failed slot') end
        end
        st.updates=st.updates+1;st.ready=true
    end
''')
a=source.index('rainDynamicSceneCopyState.e1MultiUpdate = function()')
b=source.index('render.onSceneReady',a)
lua.execute(source[a:b])
lua.execute('''
    local s=rainDynamicSceneCopyState;local r=cfg.RUNTIME;local m=s.e1Multi
    s.e1MultiUpdate()
    assert(calls==3 and s.e1Source==m.slots[1])
    assert(m.slots[1].quality==2 and m.slots[2].quality==1)
    assert(math.abs(m.slots[2].origin.x-9.97)<1e-9)
    assert(math.abs(m.slots[3].origin.x-10.03)<1e-9)
    assert(m.slots[1].origin.z==.15)
    for _,slot in ipairs(m.slots) do assert(slot.origin.y==.02) end
    sim.cameraPosition=vec3(99,0,0);pose.x=20;r.RAIN_VISOR_LAYER_E1_SOURCE_SLOT=2
    s.e1MultiUpdate()
    assert(s.e1Source==m.slots[3] and math.abs(s.e1Source.origin.x-20.03)<1e-9)
    assert(m.slots[1].frame==m.slots[3].frame and m.slots[3].frame==2)
    failQuality=1;s.e1MultiUpdate()
    assert(m.slots[1].ready and not s.e1Source.ready and not s.e1Source.shot)
    assert(disposed==4) -- two resources per failed side; centre survives
    failQuality=nil;m.anchor=nil;r.RAIN_VISOR_LAYER_E1_ANCHOR_SAVED=false;s.e1MultiUpdate()
    assert(math.abs(m.slots[1].origin.x-99)<1e-9) -- explicit reanchor
    r.RAIN_VISOR_LAYER_E1_MULTIVIEW=false;s.e1MultiUpdate()
    assert(#m.slots==0 and not m.anchor and s.e1Source==m.single and s.e1Source.ready)
    assert(disposed==10)
    r.RAIN_VISOR_LAYER_E1_MULTIVIEW=true;s.e1MultiUpdate()
    s.e1SourceDispose()
    assert(#m.slots==0 and s.e1Source==m.single and not m.single.ready and disposed==16)
    local savedX=r.RAIN_VISOR_LAYER_E1_ANCHOR_X
    sim.cameraPosition=vec3(500,0,0)
    s.e1MultiUpdate()
    assert(m.anchor.x==savedX) -- reload/dispose restores saved local anchor
    s.e1SourceDispose();r.RAIN_VISOR_LAYER_E1_ANCHOR_SAVED=false
    r.RAIN_VISOR_LAYER_NATIVE_HOUSING=true
    s.nativeCaptureModel={source={prepared=false}}
    s.nativeHousingEnsure=function() end;s.nativeCaptureRefs=function() end
    local before=calls;s.e1MultiUpdate()
    assert(calls==before and not m.anchor and not s.e1Source.ready)
    s.nativeCaptureModel.source.prepared=true;s.e1MultiUpdate()
    assert(calls==before+3 and m.anchor and s.e1Source.ready)
''')
print('PASS: three independent slots, helmet anchor, manual selection, frame IDs, isolated failures, reset, toggle/dispose')
# The real metric draw must use the explicit slot view, not the published one.
a=source.index('rainDynamicSceneCopyState.e1SourceDepthDraw = function(')
b=source.index('rainDynamicSceneCopyState.e1SourceUpdate = function(',a)
lua.execute('''
    target=refs({{visible=false}})
    rainDynamicSceneCopyState.e1SourceEditor=function() return {targetMesh=target} end
    render={CullMode={None=0},DepthMode={Normal=1,ReadOnly=0},BlendMode={Opaque=1,BlendPremultiplied=0},
        setCullMode=function() end,setDepthMode=function() end,setBlendMode=function() end,
        mesh=function(p) recordedView=p.values.gE1CaptureView;recordedID=p.values.gE1SurfaceId;return true end}
''')
lua.execute(source[a:b])
lua.execute('''
    local slot={view='side-view',items={{mesh='DRIVER_FACE'}}}
    rainDynamicSceneCopyState.e1Source.view='wrong-global-view'
    rainDynamicSceneCopyState.e1SourceDepthDraw(slot)
    assert(recordedView=='side-view' and recordedID==4 and not target:isVisible(1))
''')
print('PASS: actual metric-depth draw binds selected slot matrix/mesh ID and restores visibility')

# Execute the actual camera-axis rotation, including the positive-down sign.
lua.execute('''
    local mt=getmetatable(vec3(0,0,0))
    mt.__unm=function(a) return vec3(-a.x,-a.y,-a.z) end
    mt.__sub=function(a,b) return vec3(a.x-b.x,a.y-b.y,a.z-b.z) end
    mt.__mul=function(a,b) return vec3(a.x*b,a.y*b,a.z*b) end
    function dot(a,b) return a.x*b.x+a.y*b.y+a.z*b.z end
''')
a=source.index('    local pitch=math.rad(r.RAIN_VISOR_LAYER_E1_SOURCE_PITCH)')
b=source.index('    st.side =',a)
rotation=source[a:b]
lua.execute('''
    local r={RAIN_VISOR_LAYER_E1_SOURCE_PITCH=10}
    local st={};local forward=vec3(0,0,1);local up=vec3(0,1,0)
''' + rotation + '''
    assert(st.look.y<0 and st.look.z<0)
    assert(math.abs(dot(st.look,st.up))<1e-12)
    assert(math.abs(dot(st.look,st.look)-1)<1e-12)
    assert(math.abs(dot(st.up,st.up)-1)<1e-12)
''')
print('PASS: actual pitched camera axes look down and remain orthonormal')
lua.execute('''
    local r={RAIN_VISOR_LAYER_E1_SOURCE_PITCH=10}
    local st={};local forward=vec3(0,0,1);local up=vec3(0,1,0)
    local cameraOverride={origin=vec3(.03,.02,.2),look=vec3(1,0,0),up=vec3(0,1,0)}
    local origin=vec3(0,0,0)
''' + rotation + '''
    assert(origin==cameraOverride.origin and st.look==cameraOverride.look and st.up==cameraOverride.up)
''')
print('PASS: source camera override replaces origin and both colour/depth camera axes')

# The real single-source updater must defer GeometryShot allocation until the
# registered native copy has participated in the engine update preparation.
a=source.index('rainDynamicSceneCopyState.e1SourceUpdate = function(')
b=source.index('-- Each slot owns its view/depth/colour.',a)
lua.execute(source[a:b])
lua.execute('''
    local s=rainDynamicSceneCopyState;local r=cfg.RUNTIME
    s.visorLayer={shader=true};s.nativeHousing={generation=0}
    s.nativeHousingEnsure=function() return {} end
    s.nativeCaptureRefs=function() return {} end
    s.nativeCaptureModel={source={prepared=false}}
    r.RAIN_VISOR_LAYER_NATIVE_HOUSING=true;r.RAIN_VISOR_LAYER_E1_SOURCE_MODE=0
    local cold={updates=0,calls=0}
    s.e1SourceUpdate(cold)
    assert(not cold.ready and not cold.shot and cold.status:find('engine preparation'))
''')
print('PASS: actual cold single-source update defers shot creation until native preparation')

# Actual reflected-eye camera mathematics and orchestration, not a replica.
lua.execute('''
    local mt=getmetatable(vec3(0,0,0));mt.__index={}
    function mt.__index:dot(v) return dot(self,v) end
    function mt.__index:normalize()
        local length=math.sqrt(dot(self,self));return self*(1/length)
    end
    function pose:transformVector(v) return v end
    sim.cameraPosition=vec3(20.03,.02,0)
    sim.cameraLook=vec3(0,0,1);sim.cameraUp=vec3(0,1,0)
    local r=cfg.RUNTIME
    r.RAIN_VISOR_LAYER_E1_REFLECTION_PLANE_Z=.10
    r.RAIN_VISOR_LAYER_E1_REFLECTION_PLANE_PITCH=0
    r.RAIN_VISOR_LAYER_E1_REFLECTION_PLANE_YAW=0
''')
a=source.index('rainDynamicSceneCopyState.e1ReflectionCamera = function()')
b=source.index('rainDynamicSceneCopyState.e1MultiUpdate = function()',a)
lua.execute(source[a:b])
lua.execute('''
    local s=rainDynamicSceneCopyState;local r=cfg.RUNTIME
    local camera=s.e1ReflectionCamera()
    assert(math.abs(camera.origin.z-.2)<1e-12 and camera.origin.x==sim.cameraPosition.x)
    assert(camera.look.z==-1 and camera.up.y==1)
    r.RAIN_VISOR_LAYER_E1_REFLECTION_PLANE_PITCH=17
    r.RAIN_VISOR_LAYER_E1_REFLECTION_PLANE_YAW=23
    camera=s.e1ReflectionCamera()
    assert(math.abs(dot(camera.look,camera.up))<1e-12)
    assert(math.abs(dot(camera.look,camera.look)-1)<1e-12)
    local pitch=math.rad(17);local yaw=math.rad(23)
    local normal=vec3(math.sin(yaw)*math.cos(pitch),-math.sin(pitch),math.cos(yaw)*math.cos(pitch))
    local point=pose:transformPoint(vec3(0,0,.1))
    assert(math.abs(dot(camera.origin-point,normal)+dot(sim.cameraPosition-point,normal))<1e-12)
    r.RAIN_VISOR_LAYER_E1_REFLECTION_CAMERA=true;r.RAIN_VISOR_LAYER_E1_MULTIVIEW=true
    local calls=0
    s.e1SourceUpdate=function(st,origin,quality,override)
        assert(st==s.e1Multi.single and not st.ready and #s.e1Multi.slots==0)
        assert(origin==override.origin and quality==r.RAIN_VISOR_LAYER_E1_SOURCE_QUALITY)
        calls=calls+1;st.ready=true
    end
    s.e1MultiUpdate();assert(calls==1 and s.e1Source==s.e1Multi.single)
    sim.cameraPosition=sim.cameraPosition+vec3(.05,0,0)
    local nextCamera=s.e1ReflectionCamera()
    assert(math.abs(nextCamera.origin.x-camera.origin.x)>.001)
    s.e1MultiUpdate();assert(calls==2)
''')
print('PASS: actual reflected eye/axes, tilted plane signed distance, moving camera, single capture overrides multiview')
