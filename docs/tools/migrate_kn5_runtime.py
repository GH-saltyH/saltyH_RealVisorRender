"""One-shot guarded migration from the session snapshot. Not a model baker."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
def replace(s,a,b,n=1):
    assert s.count(a)==n,(a[:100],s.count(a),n)
    return s.replace(a,b)
def function(s,name,new):
    m=re.search(r'        (?:float\d?|void) '+name+r'\([^)]*\)\s*\{',s)
    assert m,name
    depth=1;i=m.end()
    while depth:
        depth+=(s[i]=='{')-(s[i]=='}');i+=1
    return s[:m.start()]+new+s[i:]
def save(p,s,stat):
    assert p.stat().st_mtime_ns==stat
    p.write_text(s,encoding='utf-8',newline='\n')

p=ROOT/'realvisor.lua';stat=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8-sig')
for a,b in {'GLASS_COATING_OVERLAY':'GLASS_COAT_FX','GLASS_EXT_OVERLAY':'GLASS_EXT_FX','GLASS_INT_OVERLAY':'GLASS_INT_FX','GLASS_RAINFX_OVERLAY':'GLASS_RAINFX',
            "'BODY_FRAME'":"'FRAME_MAIN'","'BODY_GLASSLINE'":"'BAND_INNER'","'BODY_FABRIC'":"'BODY_FABRIC_TRACE'"}.items():
    assert a in s,a;s=s.replace(a,b)
s=replace(s,"'/texture/GLASS_EXT_RAINFX_surfaceNormal_objectSpace_2K.dds'","'/texture/RAINFX_ObjNormal_BoundaryMask.dds'")
s=replace(s,"'/texture/GLASS_EXT_RAINFX_boundaryMask_2K.dds'","'/texture/RAINFX_ObjNormal_BoundaryMask.dds'")
s=replace(s,"'/texture/test_objectSpace.dds'","'/texture/RAINFX_ObjNormal_BoundaryMask.dds'")
s=replace(s,'local function initializeRainGPUState()','''local function initializeRainGPUState()
    if not rainDynamicSceneCopyState.surface:validate() then return false end
    rainDynamicSceneCopyState.surface:bind(rainStateUpdateParams)
    rainDynamicSceneCopyState.surface:bind(rainStateMetaUpdateParams)''')
# Attach shared HLSL after config and both parameter tables exist; no new chunk locals.
s=replace(s,'local function initializeRainGPUState()','''rainDynamicSceneCopyState.surface = dofile(appFolder..'/rain_surface.lua')(appFolder,cfg.RUNTIME)
rainStateUpdateParams.shader = rainDynamicSceneCopyState.surface.shader..rainStateUpdateParams.shader
rainStateMetaUpdateParams.shader = rainDynamicSceneCopyState.surface.shader..rainStateMetaUpdateParams.shader
local function initializeRainGPUState()''')
for name in ('rainStateBoundaryMask',):
    s=function(s,name,'        float rainStateBoundaryMask(float2 position) { return rainValid(position); }')
    # The metadata shader contains another identical helper.
    prefix=s.index('local rainStateMetaUpdateParams')
    s=s[:prefix]+function(s[prefix:],name,'        float rainStateBoundaryMask(float2 position) { return rainValid(position); }')
s=function(s,'rainStateProjectForce','''        float2 rainStateProjectForce(float3 forceWorld, float2 position) {
            return rainMetricProject(position,mul(forceWorld,transpose((float3x3)gRainObjectToWorld)));
        }''')
s=function(s,'rainStateSurfaceForce','''        float2 rainStateSurfaceForce(float2 position,float radius,out float forceMagnitude) {
            float3 normalWorld=rainStateNormalWorld(position),airWorld;
            float3 forceWorld=rainStateExternalForceWorld(normalWorld,radius,airWorld);
            // Optional downward airflow is a physical gravity-tangent component.
            // UV V can face any direction; never force a signed V movement.
            if(gRainStateLifecycle>.5 && gRainAirflowDownwardMode>.5) {
                float3 down=float3(0,-1,0);down-=normalWorld*dot(down,normalWorld);
                float l=length(down);
                if(l>1e-6) forceWorld+=down/l*min(length(airWorld)*.30*gRainAirflowDownwardGain,
                    max(gRainStateGravity*gRainPhysicsAccelScale,.1)*(1+min(length(gRainAirVelocityWorld)/20,4)*gRainAirflowDownwardGain));
            }
            forceWorld-=normalWorld*dot(forceWorld,normalWorld);
            forceMagnitude=length(forceWorld);
            return rainStateProjectForce(forceWorld,position);
        }''')
# Prefer geometry-derived normal if authored object-map axes differ. The
# provided RGB normal is calibrated offline separately; boundary always uses A.
s=replace(s,'samLinearRain, p, 0.0','samLinearRain, float2(p.x,p.y+1.0), 0.0')
s=replace(s,'dot(delta, delta) - otherMeta.r * otherMeta.r','pow(rainMetricLength(candidate,delta),2.0) - otherMeta.r * otherMeta.r')
s=replace(s,'float2 velocity,\n            float radius,\n            float mobile\n        )','float2 velocity,\n            float radius,\n            float mobile, float2 position\n        )')
s=replace(s,'float speed =\n                length(velocity);','float speed =\n                rainMetricLength(position,velocity);')
s=replace(s,'max(gRainStateMobileThresholdUV, 0.0011),\n                    length(velocity))','max(gRainStateMobileThresholdUV, 0.0011),\n                    rainMetricLength(position,velocity))')
s=replace(s,'                    radius,\n                    mobile\n                );','                    radius,\n                    mobile, position\n                );')
s=replace(s,'                    mass\n                );','                    mass\n                ) * lerp(1.0,gRainCoatAdhesion,rainCoating(position));')
s=replace(s,'            position =\n                rainStateIntegratePosition(','            velocity *= exp(-gRainGlassExtraDrag*(1-rainCoating(position))*dt);\n            position =\n                rainStateIntegratePosition(')
s=replace(s,'gRainWetPathTexel = 1.0 / 1024.0,','gRainWetPathTexel = vec2(1.0 / 1024.0,1.0 / 256.0),\n        gRainCoatAdhesion = 0.55, gRainGlassExtraDrag = 1.5,')
s=replace(s,'float wt = gRainWetPathTexel;','float2 wt = gRainWetPathTexel;')
s=s.replace('float2(wt, 0.0)','float2(wt.x, 0.0)').replace('float2(0.0, wt)','float2(0.0, wt.y)')
s=replace(s,'        1.0 / math.max(rainDynamicSceneCopyState.waterTrailSize or 1024, 1)','        vec2(1.0,4.0) / math.max(rainDynamicSceneCopyState.waterTrailSize or 1024, 1)')
s=replace(s,'txRainBoundaryMask.SampleLevel(samLinearClamp, p, 0).r','txRainBoundaryMask.SampleLevel(samLinearClamp, p, 0).a')
# Remove forced hiding of native meshes; all non-FX objects honour Visible.
s=replace(s,"        local retired=editor.meshName=='BODY_FRAME_OVERLAY' or editor.meshName=='BODY_GLASSLINE_OVERLAY'\n            or editor.meshName=='BODY_FABRIC_OVERLAY'\n        editor.visible = not retired and visibleValue ~= 0\n        if retired and editor.targetMesh and #editor.targetMesh>0 then editor.targetMesh:setShadows(false) end",'        editor.visible = visibleValue ~= 0')
s=replace(s,"    if meshName=='BODY_FRAME_OVERLAY' or meshName=='BODY_GLASSLINE_OVERLAY'\n        or meshName=='BODY_FABRIC_OVERLAY' then return {retired=true} end\n",'')
s=replace(s,"            local retired=e.meshName=='BODY_FRAME_OVERLAY' or e.meshName=='BODY_GLASSLINE_OVERLAY'\n                or e.meshName=='BODY_FABRIC_OVERLAY'\n            local hideThis = retired or (hide and drawn[e.meshName])",'            local hideThis = hide and drawn[e.meshName]')
s=replace(s,'if retired or drawn[e.meshName] then','if drawn[e.meshName] then')
a=s.index("    for _,name in ipairs({'BODY_FRAME_OVERLAY'",s.index('nativeHousingEnsure = function()'));b=s.index('    local union',a);s=s[:a]+s[b:]
s=replace(s,'                st[item.mesh]={ref=ref}','                st[item.mesh]={ref=ref}\n                if item.mesh==\'FRAME_MAIN\' then ref:setCullMode(render.CullMode.None) end')
s=replace(s,'            copy:assignMaterialFrom(ed.targetMesh)','            copy:assignMaterialFrom(ed.targetMesh)\n            if item.mesh==\'FRAME_MAIN\' then copy:setCullMode(render.CullMode.None) end')
s=replace(s,'                    ref:setVisible(true,false)\n                    st.actors[#st.actors+1]={mesh=name,mat=\'FACE\',two=true,targetMesh=ref,visible=true}',"                    st.actors[#st.actors+1]={mesh=name,mat='FACE',two=true,targetMesh=ref,visible=ref:isVisible(1)}")
s=replace(s,"set.GLASS_RAINFX_OVERLAY = true",'set.GLASS_RAINFX = true') if 'set.GLASS_RAINFX_OVERLAY = true' in s else s
# Alpha-zero original FX sheets are never useful in mirrors. Keep native MRR,
# frame, fabric, camera and all other objects' authored visibility intact.
a=s.index('-- s51 mirror / main pass switching');b=s.index('rainDynamicSceneCopyState.visorLayerDrawItem =',a)
s=s[:a]+'''-- FX sheets have no native mirror colour/shadow role.
rainDynamicSceneCopyState.visorLayerPassSwitch = function()
    rainDynamicSceneCopyState.visorLayerSceneHide(true)
end
render.on('mirror.track.opaque',rainDynamicSceneCopyState.visorLayerPassSwitch)
'''+s[b:]
# Native capture assets and FX own UV texture assets.
paths={'BODY_FRAME/BODY_FRAME_1K_txDiff.dds':'GLASS/E1_GEOMETRY/frame_txDiffuse.dds',
 'BODY_FRAME/BODY_FRAME_1K_txNormal.dds':'GLASS/E1_GEOMETRY/frame_txNormal.dds',
 'BODY_FRAME/BODY_INT_BORDER_GLASSLINE_2K_txNormal.dds':'GLASS/E1_GEOMETRY/rubber_txNormal.dds',
 'BODY_FRAME/BODY_INT_FABRIC_2K_txDiff.dds':'GLASS/E1_GEOMETRY/fabric_txDiffuse.dds',
 'BODY_FRAME/BODY_INT_FABRIC_4K_txNormal.dds':'GLASS/E1_GEOMETRY/fabric_txNormal.dds',
 'BODY_FRAME/BODY_INT_FABRIC_2K_txMaps.dds':'GLASS/E1_GEOMETRY/fabric_txMaps.png',
 'GLASS/GLASS_EXT_BAND_WITH_ALPHAMASK.dds':'GLASS/FX/ext_txDiffuse.png',
 'GLASS/GLASS_INT_EXT_4k_txNormal.dds':'GLASS/FX/int_txNormal.png',
 'GLASS/GLASS_INT_OUTLINE_MASK.png':'GLASS/FX/int_outline.png',
 'GLASS/GLASS_INT_LENS_FIELD.dds':'GLASS/FX/int_lens.dds'}
for a,b in paths.items():assert a in s,a;s=s.replace(a,b)
s=replace(s,"              nrm = T .. 'GLASS/FX/int_txNormal.png' },","              nrm = T .. 'GLASS/FX/ext_txNormal.png' },")
s=replace(s,"                maps = T .. 'GLASS/E1_GEOMETRY/fabric_txMaps.png' },","""                maps = T .. 'GLASS/E1_GEOMETRY/fabric_txMaps.png' },
            {mesh='CAM',two=true,mat='CAM',tex=T..'GLASS/E1_GEOMETRY/cam_txDiffuse.dds'},
            {mesh='CAM_COVER',two=true,mat='CAM',tex=T..'GLASS/E1_GEOMETRY/camCover_txDiffuse.dds'},
            {mesh='CAM_FABRIC',two=true,mat='CAM',tex=T..'GLASS/E1_GEOMETRY/camFabric_txDiffuse.dds',
                nrm=T..'GLASS/E1_GEOMETRY/camFabric_txNormal.dds',maps=T..'GLASS/E1_GEOMETRY/camFabric_txMaps.dds'},""")
s=s.replace("'FRAME_MAIN','BAND_INNER','BODY_FABRIC_TRACE','DRIVER_FACE','DRIVER_BALAKLAVA'","'FRAME_MAIN','BAND_INNER','BODY_FABRIC_TRACE','DRIVER_FACE','DRIVER_BALAKLAVA','CAM','CAM_COVER','CAM_FABRIC'")
s=replace(s,"{'face','Face','DRIVER_FACE'},{'balaklava','Balaklava','DRIVER_BALAKLAVA'}}","{'face','Face','DRIVER_FACE'},{'balaklava','Balaklava','DRIVER_BALAKLAVA'},\n        {'cam','Cam','CAM'},{'camCover','CamCover','CAM_COVER'},{'camFabric','CamFabric','CAM_FABRIC'}}")
s=s.replace('Five-mesh BVH','Eight-mesh BVH').replace('five-mesh BVH','eight-mesh BVH')
# Fix actual physical surface area weighting and tiny triangles rejected by a
# former fixed square-atlas determinant threshold.
s=replace(s,'if math.abs(determinant) > 0.0000001 then','if math.abs(determinant) > 1e-12 then')
s=replace(s,'local uvArea = math.abs(determinant) * 0.5','local uvArea = (v1.pos-v0.pos):cross(v2.pos-v0.pos):length() * 0.5')
save(p,s,stat)

p=ROOT/'visor_optics.lua';stat=p.stat().st_mtime_ns;s=p.read_text()
s=s.replace("{'Frame','Rubber','Fabric','Face','Balaklava'}","{'Frame','Rubber','Fabric','Face','Balaklava','Cam','CamCover','CamFabric'}")
s=s.replace("{'frame','rubber','fabric','face','balaklava'}","{'frame','rubber','fabric','face','balaklava','cam','camCover','camFabric'}")
for a,b in {'BODY_FRAME':'FRAME_MAIN','BODY_GLASSLINE':'BAND_INNER','BODY_FABRIC':'BODY_FABRIC_TRACE','GLASS_EXT_OVERLAY':'GLASS_EXT_FX','GLASS_INT_OVERLAY':'GLASS_INT_FX'}.items():s=s.replace(a,b)
s=s.replace("'DRIVER_FACE','DRIVER_BALAKLAVA'","'DRIVER_FACE','DRIVER_BALAKLAVA','CAM','CAM_COVER','CAM_FABRIC'")
s=replace(s,"'/texture/GLASS/GLASS_INT_EXT_4k_txNormal.dds'","'/texture/GLASS/FX/int_txNormal.png'")
s=replace(s,'root..material.txNormal',"root..(material.txNormal or 'neutral_normal.png')")
s=replace(s,'root..(material.txMaps or material.txNormal)',"root..(material.txMaps or material.txNormal or 'neutral_normal.png')")
save(p,s,stat)
p=ROOT/'shaders/visorOpticsTrace.hlsl';stat=p.stat().st_mtime_ns;s=p.read_text();s=replace(s,'OPT_MESH(Balaklava,5)','OPT_MESH(Balaklava,5) OPT_MESH(Cam,6) OPT_MESH(CamCover,7) OPT_MESH(CamFabric,8)');save(p,s,stat)
