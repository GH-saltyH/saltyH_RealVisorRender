from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'shaders/e1HousingGeometry.hlsl';stamp=p.stat().st_mtime_ns;s=p.read_text()
s=s.replace('bool e1Mesh(Texture2D nodes,Texture2D triangles,float4x4 inverseWorld,','bool e1Mesh(float3 records,float4x4 inverseWorld,')
s=re.sub(r'e1Record\(nodes,([^\)]+)\)',r'e1Record(txE1Geometry,(int)records.x+\1)',s)
s=re.sub(r'e1Record\(triangles,([^\)]+)\)',r'e1Record(txE1Geometry,(int)records.y+\1)',s)
for key in ['Frame','Rubber','Fabric','Face','Balaklava']:
    s=s.replace(f'txE1{key}Nodes,txE1{key}Triangles',f'gE1{key}Records')
anchor='    if(gE1Mode>5.5 && gE1Mode<6.5) {'
extra=''
for key,mid in [('Cam',5),('CamFabric',7)]:
    extra+=f'''    if(gE1{key}Visible>.5) {{
        if(e1Mesh(gE1{key}Records,gE1{key}Inverse,origin,ray,best,candidate,done)) {{material={mid};uv=candidate;}}
        complete=complete&&done;
    }}
'''
# CAM_COVER is a transparent native capture participant, not an opaque BVH
# blocker. Its blend is present in native colour at the CAM hit.
assert anchor in s;s=s.replace(anchor,extra+anchor)
assert p.stat().st_mtime_ns==stamp;p.write_text(s,newline='\n')
p=ROOT/'realvisor.lua';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
anchor="    local T=appFolder..'/texture/GLASS/E1_GEOMETRY/'\n    for _,pair"
assert s.count(anchor)==1;s=s.replace(anchor,"    local T=appFolder..'/texture/GLASS/E1_GEOMETRY/'\n    local records=dofile(T..'optics_materials.lua')\n    p.textures.txE1Geometry=T..'optics_geometry.dds'\n    for _,pair")
old="""        p.textures['txE1'..pair[2]..'Nodes']=T..pair[1]..'_nodes.dds'
        p.textures['txE1'..pair[2]..'Triangles']=T..pair[1]..'_triangles.dds'"""
assert old in s;s=s.replace(old,"        local rec=records[pair[1]].records\n        v['gE1'..pair[2]..'Records']=vec3(rec[1],rec[2],rec[3])")
old="or item.mat=='FRAME' and 1 or item.mat=='RUBBER' and 2 or 3"
assert s.count(old)==1;s=s.replace(old,"or item.mesh=='CAM' and 6 or item.mesh=='CAM_COVER' and 7 or item.mesh=='CAM_FABRIC' and 8\n                    or item.mat=='FRAME' and 1 or item.mat=='RUBBER' and 2 or 3")
# Register once. Optional, independently gated, one water-only draw per mirror
# camera. Never advance physics or run glass/E1 captures in a mirror callback.
s+='''
-- sNN 2026-10-12: water-only mirror pass; all other FX omitted.
render.on('mirror.track.transparent',function()
    local st=rainDynamicSceneCopyState
    if cfg.RUNTIME.RAIN_MIRROR_WATER==false or not cfg.RUNTIME.RAIN_ENABLED
        or not st.surface.ready or not rainDynamicSurfaceMesh then return end
    local editor=st.visorLayerEditor('GLASS_RAINFX')
    if not editor or editor.visible==false then return end
    local sim=ac.getSim();if not sim then return end
    if not st.mirrorWaterShader then
        local f=assert(io.open(appFolder..'/shaders/rainMirrorWater.hlsl','rb'))
        st.mirrorWaterShader=f:read('*a');f:close()
    end
    if not st.birthMaskRead then return end
    render.setCullMode(render.CullMode.None)
    render.setDepthMode(render.DepthMode.ReadOnly)
    render.setBlendMode(render.BlendMode.BlendPremultiplied)
    rainDynamicSurfaceMesh:setVisible(true,false)
    local ok,err=pcall(render.mesh,{mesh=rainDynamicSurfaceMesh,transform='original',shader=st.mirrorWaterShader,
        textures={txMirrorHeads=st.birthMaskRead,txMirrorTrails=st.waterTrailRead or st.birthMaskRead,
            txMirrorBoundary=textureRainBoundaryMask},
        values={gMirrorLightDirection=-sim.lightDirection,gMirrorLightColor=sim.lightColor}})
    rainDynamicSurfaceMesh:setVisible(false,false)
    if not ok then st.mirrorWaterError=tostring(err) end
end)
'''
anchor='        RAIN_SURFACE_COAT_ADHESION ='
assert s.count(anchor)==1;s=s.replace(anchor,'        RAIN_MIRROR_WATER = true,\n'+anchor)
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8',newline='\n')
# Clear-cover alpha remains in native capture, not an opaque geometry blocker.
p=ROOT/'shaders/visorOpticsTrace.hlsl';s=p.read_text();s=s.replace(' OPT_MESH(CamCover,7)','');p.write_text(s)
