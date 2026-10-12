from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
for name in ('check_baked_housing.py','check_visor_optics.py','check_e1_geometry_runtime.py','check_e1_geometry.py',
             'check_e1_multiview.py','check_e1_resolve.py','check_material_settings.py'):
    p=ROOT/'docs/tools'/name;s=p.read_text(encoding='utf-8-sig')
    for a,b in {'GLASS_COATING_OVERLAY':'GLASS_COAT_FX','GLASS_EXT_OVERLAY':'GLASS_EXT_FX','GLASS_INT_OVERLAY':'GLASS_INT_FX','GLASS_RAINFX_OVERLAY':'GLASS_RAINFX',
                'BODY_GLASSLINE':'BAND_INNER','BODY_FABRIC':'BODY_FABRIC_TRACE','BODY_FRAME':'FRAME_MAIN'}.items():s=s.replace(a,b)
    if name=='check_baked_housing.py':
        s=s.replace("render={on=function() end}","render={on=function() end,CullMode={None=2}}")
        s=s.replace("'ensureUniqueMaterials','setCullMode','setTransparent'","'ensureUniqueMaterials','setTransparent'")
        s=s.replace("        local names=",'''        function methods:setCullMode(mode)
            for _,m in ipairs(self) do assert(m.name=='FRAME_MAIN' and mode==2);m.cull=mode end
        end
        local names=''')
        s=s.replace("'DRIVER_FACE','DRIVER_BALAKLAVA','GLASS_COAT_FX'","'CAM','CAM_COVER','CAM_FABRIC','DRIVER_FACE','DRIVER_BALAKLAVA','GLASS_COAT_FX'")
        s=s.replace("if name:find('BODY_') then", "if not name:find('DRIVER_') then")
        s=s.replace("{mesh='BODY_FABRIC_TRACE',mat='FABRIC'}", "{mesh='BODY_FABRIC_TRACE',mat='FABRIC'},{mesh='CAM',mat='CAM'},{mesh='CAM_COVER',mat='CAM'},{mesh='CAM_FABRIC',mat='CAM'}")
        s=s.replace('assert(#native==3)','assert(#native==6)')
        s=s.replace('assert(not editors[name].visible)','assert(editors[name].visible)')
        s=s.replace('assert(not editors[name].targetMesh[1].visible and not editors[name].targetMesh[1].shadows)',
                    'assert(editors[name].targetMesh[1].visible and editors[name].targetMesh[1].shadows)')
        s=s.replace('#selected==5','#selected==8').replace('#opticsRefs==5','#opticsRefs==8')
        s=s.replace('DRIVER_BALAKLAVA=true}', 'DRIVER_BALAKLAVA=true,CAM=true,CAM_COVER=true,CAM_FABRIC=true}')
    if name=='check_visor_optics.py':
        s=s.replace("'Balaklava','Band'","'Balaklava','Cam','CamCover','CamFabric','Band'")
        s=s.replace("'face','balaklava','band'","'face','balaklava','cam','camCover','camFabric','band'")
        s=s.replace("'face','balaklava']","'face','balaklava','cam','camCover','camFabric']")
        s=s.replace("'DRIVER_FACE','DRIVER_BALAKLAVA'","'DRIVER_FACE','DRIVER_BALAKLAVA','CAM','CAM_COVER','CAM_FABRIC'")
        s=s.replace('p.values.gOptMaterialID<=5','p.values.gOptMaterialID<=8')
        s=s.replace('assert(materialDraws==10);for id=1,5','assert(materialDraws==16);for id=1,8')
        # Native legacy overlay names are ordinary native objects now too.
        s=s.replace("local native=name=='FRAME_MAIN' or name=='FRAME_MAIN_MIRROR'",
                    "local native=name=='FRAME_MAIN' or name=='FRAME_MAIN_MIRROR' or name=='FRAME_MAIN_OVERLAY'")
    if name=='check_e1_geometry_runtime.py':
        s=s.replace("'DRIVER_FACE','DRIVER_BALAKLAVA'","'DRIVER_FACE','DRIVER_BALAKLAVA','CAM','CAM_COVER','CAM_FABRIC'")
        s=s.replace("'Fabric','Face','Balaklava'","'Fabric','Face','Balaklava','Cam','CamCover','CamFabric'")
        s=s.replace("assert(p.textures['txE1'..prefix..'Nodes'])", "assert(p.values['gE1'..prefix..'Records'])")
        s=s.replace("assert(p.textures['txE1'..prefix..'Triangles'])", "assert(p.textures.txE1Geometry)")
    if name=='check_e1_geometry.py':
        s=s.replace("['Frame','Rubber','Fabric','Face','Balaklava']","['Frame','Rubber','Fabric','Face','Balaklava','Cam','CamCover','CamFabric']")
        s=s.replace("header+=f'Texture2D txE1{key}Nodes,txE1{key}Triangles;float4x4 gE1{key}Inverse;float gE1{key}Visible;\\n'",
                    "header+=f'float3 gE1{key}Records;float4x4 gE1{key}Inverse;float gE1{key}Visible;\\n'")
        s=s.replace("header+='Texture2D txE1FrameDiffuse", "header+='Texture2D txE1Geometry,txE1FrameDiffuse")
    p.write_text(s,encoding='utf-8',newline='\n')
