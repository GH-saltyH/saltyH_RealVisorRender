"""Actual geometry runtime: hash gate, all five transforms, source independence."""
from pathlib import Path
import runpy
root=Path(__file__).resolve().parents[2]
env=runpy.run_path(str(root/'docs/tools/check_baked_housing.py'));lua=env['lua']
source=(root/'realvisor.lua').read_text(encoding='utf-8-sig')
lua.globals().appFolder=root.as_posix()
lua.execute('''
    cfg={RUNTIME={MODEL_PATH='visors/visor_lando_2025Champion_maxquality_diet_face.kn5',
        RAIN_VISOR_LAYER_E1_PRIMARY_MODE=6,RAIN_VISOR_LAYER_E1_PRIMARY_TRACE_RANGE=1.5,
        RAIN_VISOR_LAYER_E1_SOURCE_MODE=0,RAIN_VISOR_LAYER_BORDER_GREY=.2,
        RAIN_VISOR_LAYER_E1_GEOMETRY_WIDTH=512,RAIN_VISOR_LAYER_E1_COLOUR_TOLERANCE=.003,
        RAIN_VISOR_LAYER_E1_PRIMARY_GAIN=10,RAIN_VISOR_LAYER_E1_PRIMARY_THRESHOLD=1,
        RAIN_VISOR_LAYER_E1_PRIMARY_KNEE=.5,RAIN_VISOR_LAYER_E1_PRIMARY_MEAN_FLOOR=.02}}
    io.checksumSHA256=function(path,callback) checks=(checks or 0)+1;hashCallback=callback end
    sim={cameraPosition={},cameraLook={},cameraUp={},cameraFOV=90}
    ac={getSim=function() return sim end}
    function vec2(x,y) return {x=x,y=y} end
    function vec3(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},
        {__sub=function(a,b) return vec3(a.x-b.x,a.y-b.y,a.z-b.z) end}) end
    sim.cameraPosition=vec3(0,0,0)
    function rgbm() return {} end
    render={AntialiasingMode={None=0},TextureFormat={R16G16B16A16={Float=1}}}
    axisRollNode={getWorldTransformationRaw=function() return {transformPoint=function() return {} end} end}
    rainDynamicSceneCopyState={e1Primary={},e1Geometry={},mainTargetWidth=1280,mainTargetHeight=720}
    geometryMeshes={}
    for _,name in ipairs({'GLASS_INT_OVERLAY','BODY_FRAME','BODY_GLASSLINE','BODY_FABRIC','DRIVER_FACE','DRIVER_BALAKLAVA'}) do
        local mesh=refs({{visible=false}})
        function mesh:getWorldTransformationRaw() return {inverse=function() return name..'-inverse' end} end
        geometryMeshes[name]={targetMesh=mesh,visible=true}
    end
    rainDynamicSceneCopyState.visorLayerEditor=function(name) return geometryMeshes[name] end
    rainDynamicSceneCopyState.e1SourceEditor=rainDynamicSceneCopyState.visorLayerEditor
    function ac.GeometryShot(callbacks,size)
        local shot={size=size,callbacks=callbacks}
        for _,name in ipairs({'setSky','setParticles','setClearColor','setClippingPlanes'}) do shot[name]=function() end end
        function shot:update() updates=(updates or 0)+1;return not pending end
        function shot:dispose() self.disposed=true end
        return shot
    end
''')
a=source.index('rainDynamicSceneCopyState.e1GeometryValidate = function()')
b=source.index('render.onSceneReady',a);lua.execute(source[a:b])
lua.globals().expected_hash=(root/'texture/GLASS/E1_GEOMETRY/manifest.verify').read_text().splitlines()[1]
lua.execute('''
    local s=rainDynamicSceneCopyState
    assert(not s.e1GeometryValidate() and checks==1)
    hashCallback(nil,expected_hash);assert(s.e1GeometryValidate() and checks==1)
    s.e1Geometry.dataModel=nil;assert(not s.e1GeometryValidate())
    hashCallback(nil,'wrong');assert(not s.e1GeometryValidate())
    s.e1Geometry.dataModel=nil;s.e1GeometryValidate();hashCallback(nil,expected_hash)
''')
a=source.index('rainDynamicSceneCopyState.e1GeometryUpdate = function()')
b=source.index('-- Preserve materials and render states authored in KN5.',a)
lua.execute(source[a:b])
lua.execute('''
    local s=rainDynamicSceneCopyState;local r=cfg.RUNTIME
    s.e1GeometryUpdate();assert(s.e1Geometry.ready and updates==1)
    local p=s.e1Geometry.params
    for _,prefix in ipairs({'Frame','Rubber','Fabric','Face','Balaklava'}) do
        assert(p.values['gE1'..prefix..'Visible']==1)
        assert(p.values['gE1'..prefix..'Inverse'])
        assert(p.textures['txE1'..prefix..'Nodes'] and p.textures['txE1'..prefix..'Triangles'])
    end
    r.RAIN_VISOR_LAYER_E1_SOURCE_OFFSET=99;r.RAIN_VISOR_LAYER_E1_SOURCE_FOV=10
    r.RAIN_VISOR_LAYER_E1_SOURCE_SLOT=2;r.RAIN_VISOR_LAYER_E1_SOURCE_PITCH=30
    s.e1GeometryUpdate();assert(s.e1Geometry.ready and updates==2)
    assert(p.values.gE1Range==1.5 and p.values.gE1Mode==6)
    assert(not p.values.gE1Projection and not p.textures.txE1Depth)
    s.e1Geometry.ready=false;pending=true;s.e1GeometryUpdate();assert(not s.e1Geometry.ready)
    pending=false;r.RAIN_VISOR_LAYER_E1_PRIMARY_MODE=0
    s.e1GeometryUpdate();assert(updates==4 and s.e1Geometry.ready) -- final now connected
    r.RAIN_VISOR_LAYER_E1_SOURCE_MODE=2;s.e1GeometryUpdate();assert(updates==4 and not s.e1Geometry.ready)
    r.RAIN_VISOR_LAYER_E1_SOURCE_MODE=0;r.RAIN_VISOR_LAYER_E1_MULTIVIEW=true
    local function slot(frame) return {ready=true,nativeCapture=true,origin=vec3(1,2,3),
        view={},projection={},shot={},positionShot={},frame=frame} end
    s.e1Multi={frame=10,slots={slot(10),slot(9),slot(10)}}
    s.e1GeometryUpdate();p=s.e1Geometry.params
    assert(p.values.gE1SourceActive0==1 and p.values.gE1SourceActive1==0 and p.values.gE1SourceActive2==1)
    assert(p.textures.txE1Colour1==false and p.textures.txE1Depth1==false)
    assert(p.textures.txE1Colour2==s.e1Multi.slots[3].shot)
    assert(p.values.gE1EyeToSource2.x==-1 and p.values.gE1EyeToSource2.y==-2)
    s.e1Multi.slots[1]=nil;s.e1Source=slot(10)
    s.e1GeometryUpdate();assert(p.values.gE1SourceActive0==0) -- no fallback to selected global slot
    r.RAIN_VISOR_LAYER_E1_MULTIVIEW=false;s.e1GeometryUpdate()
    assert(p.values.gE1SourceActive0==1 and p.values.gE1SourceActive1==0 and p.values.gE1SourceActive2==0)
    r.RAIN_VISOR_LAYER_E1_MULTIVIEW=true;r.RAIN_VISOR_LAYER_E1_REFLECTION_CAMERA=true
    s.e1GeometryUpdate()
    assert(p.textures.txE1Colour0==s.e1Source.shot and p.values.gE1SourceActive0==1)
    assert(p.values.gE1SourceActive1==0 and p.values.gE1SourceActive2==0)
    s.e1Source.ready=false;s.e1GeometryUpdate();assert(p.values.gE1SourceActive0==0)
    s.e1Source.ready=true;r.RAIN_VISOR_LAYER_E1_REFLECTION_CAMERA=false;r.RAIN_VISOR_LAYER_E1_MULTIVIEW=false
    r.RAIN_VISOR_LAYER_E1_HIGHLIGHT_FIXED_REFERENCE=true;r.RAIN_VISOR_LAYER_E1_HIGHLIGHT_ISOLATION=.75
    s.e1GeometryUpdate();assert(p.values.gE1FixedReference==1 and p.values.gE1Isolation==.75)
''')
print('PASS: hash gate, five transforms, geometry independence, final/checker gate, current-frame native slots, stale/missing slot exclusion, single-source restore')

# Execute the actual final composite without triggering another geometry trace.
a=source.index('rainDynamicSceneCopyState.e1GeometryDraw = function()')
b=source.index('rainDynamicSceneCopyState.e1PrimaryUI = function()',a)
lua.execute('''
    render.CullMode={None=0};render.DepthMode={ReadOnly=0};render.BlendMode={BlendPremultiplied=0}
    render.setCullMode=function() end;render.setDepthMode=function() end;render.setBlendMode=function() end
    render.getRenderTargetSize=function() return vec2(1280,720) end
    render.mesh=function(p) compositeParams=p;if drawFail then error('draw failed') end;return true end
    cfg.RUNTIME.RAIN_VISOR_LAYER_E1_PRIMARY_RESOLVE_BLUR=1.5
    rainDynamicSceneCopyState.e1Primary.attempts=0
''')
lua.execute(source[a:b])
lua.execute('''
    local s=rainDynamicSceneCopyState;local n=updates
    local mesh=geometryMeshes.GLASS_INT_OVERLAY.targetMesh
    assert(not mesh:isVisible(1))
    s.e1GeometryDraw()
    assert(updates==n and not mesh:isVisible(1))
    assert(compositeParams.values.gE1Final==1 and compositeParams.values.gE1Blur==1.5)
    assert(compositeParams.values.gE1InvBuffer.x==1/512)
    drawFail=true;s.e1GeometryDraw()
    assert(not mesh:isVisible(1) and s.e1Primary.status:find('Geometry error'))
''')
print('PASS: actual final composite resolution/blur, no retrace, success/failure visibility restore')

# Actual UI must not expose captured-depth-only controls in BVH mode.
a=source.index('rainDynamicSceneCopyState.e1PrimaryUI = function()')
b=source.index('-- s49 scene-shadow probe instance.',a)
lua.execute('''
    drawFail=false;labels={};checkboxes={}
    ui={separator=function() end,text=function() end,textWrapped=function() end,image=function() end,
        button=function() return false end,
        checkbox=function(label) checkboxes[label]=true;return false end,
        slider=function(label,value,lo,hi) labels[label]=hi;return value,false end,
        ExtraCanvas=function() return {updateSceneWithShader=function(_,p) previewHDR=p.values.gPreviewHDR;return true end} end}
    cfg.RUNTIME.RAIN_VISOR_LAYER_E1_PRIMARY=true;cfg.RUNTIME.RAIN_VISOR_LAYER_E1_GEOMETRY_TRACE=true
''')
lua.execute(source[a:b])
lua.execute('''
    rainDynamicSceneCopyState.e1PrimaryUI()
    assert(not labels['Primary source blur MIP'] and not labels['Primary trace sample budget'])
    assert(not labels['Primary reflection trace scale'] and not checkboxes['Primary near-field depth parallax'])
    assert(labels['Highlight fixed reference (HDR luminance)']==200 and labels['Primary HDR gain']==100)
    assert(labels['Highlight baseline removal']==1 and previewHDR==1)
''')
print('PASS: actual BVH UI hides unused controls, exposes highlight controls, opaque HDR preview path')
