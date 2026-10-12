"""One-time guarded edits: capture membership, physical micro bake, controls."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];p=ROOT/'realvisor.lua'
s=p.read_text(encoding='utf-8');mtime=p.stat().st_mtime_ns
def change(a,b,n=1):
    global s
    assert s.count(a)==n,(a[:75],s.count(a),n)
    s=s.replace(a,b)
change('    rainDynamicSceneCopyState.surface:bind(rainStateMetaUpdateParams)\n\n    rainStateUpdateParams.values.gRainStateBoundaryMargin',
       '    rainDynamicSceneCopyState.surface:bind(rainStateMetaUpdateParams)\n    rainStateUpdateParams.values.gRainCoatAdhesion=cfg.RUNTIME.RAIN_SURFACE_COAT_ADHESION\n    rainStateUpdateParams.values.gRainGlassExtraDrag=cfg.RUNTIME.RAIN_SURFACE_GLASS_EXTRA_DRAG\n\n    rainStateUpdateParams.values.gRainStateBoundaryMargin')
change("        st.mesh=st.root:findMeshes('BODY_FRAME_MIRROR')","        st.mesh=st.root:findMeshes('FRAME_MAIN')")
change("'BODY_FRAME_MIRROR found' or 'BODY_FRAME_MIRROR missing'","'FRAME_MAIN found' or 'FRAME_MAIN missing'")
change('physical BODY_FRAME_MIRROR caster','physical FRAME_MAIN caster')
change('    st.mesh:setVisible(true,false)\n    st.mesh:setShadows(true)',
       "    local ed=rainDynamicSceneCopyState.e1SourceEditor('FRAME_MAIN')\n    st.mesh:setVisible(not ed or ed.visible~=false,false)\n    st.mesh:setShadows(not ed or ed.visible~=false)")
change('    local casterCount,meshCount=0,0','    local casterCount,meshCount=0,0\n    local members={}')
change('        if enabled then\n            -- Preserve the KN5 shader',
       '        if enabled then\n            members[#members+1]=item.mesh\n            -- Preserve the KN5 shader')
change('    st.casterCount,st.meshCount=casterCount,meshCount',
       '    st.captureKey=table.concat(members,"|")\n    st.casterCount,st.meshCount=casterCount,meshCount')
change('        return refs,source and source.root,source and source.prepared',
       '        return refs,source and source.root,source and source.prepared,source and source.captureKey')
change('or (nativeCapture and (st.nativeGeneration~=rainDynamicSceneCopyState.nativeHousing.generation',
       "or (nativeCapture and (st.captureKey~=rainDynamicSceneCopyState.nativeCaptureModel.source.captureKey\n            or st.nativeGeneration~=rainDynamicSceneCopyState.nativeHousing.generation")
change('        st.nativeGeneration=rainDynamicSceneCopyState.nativeHousing.generation',
       '        st.nativeGeneration=rainDynamicSceneCopyState.nativeHousing.generation\n        st.captureKey=rainDynamicSceneCopyState.nativeCaptureModel.source.captureKey')
change('    if st.shot and (st.w~=w or st.h~=h or st.generation~=generation',
       '    if st.shot and (st.w~=w or st.h~=h or st.generation~=generation\n        or st.captureKey~=rainDynamicSceneCopyState.nativeCaptureModel.housing.captureKey')
change('        st.refs=refs;st.w=w;st.h=h;st.generation=generation',
       '        st.refs=refs;st.w=w;st.h=h;st.generation=generation\n        st.captureKey=rainDynamicSceneCopyState.nativeCaptureModel.housing.captureKey')
change('    if st.owner==visor and st.captureRefs then return st end\n    if st.root then st.root:dispose() end\n    if not axisRollNode or not visor then return nil end\n    st.root=axisRollNode:loadKN5({filename=cfg.RUNTIME.MODEL_PATH,forceRenderableOn=true})\n    st.owner=visor;st.prepared=false;st.root:ensureUniqueMaterials()',
       '''    local names={'FRAME_MAIN','BAND_INNER','BODY_FABRIC_TRACE','DRIVER_FACE','DRIVER_BALAKLAVA','CAM','CAM_FABRIC'}
    local flags={}
    for _,name in ipairs(names) do
        local ed=rainDynamicSceneCopyState.e1SourceEditor(name)
        flags[#flags+1]=ed and ed.visible==false and '0' or '1'
    end
    local key=table.concat(flags)
    if st.owner==visor and st.captureKey==key then return st.captureRefs and st or nil end
    if not axisRollNode or not visor then return nil end
    if st.owner~=visor or not st.root then
        if st.root then st.root:dispose() end
        st.root=axisRollNode:loadKN5({filename=cfg.RUNTIME.MODEL_PATH,forceRenderableOn=true})
        st.owner=visor;st.prepared=false;st.root:ensureUniqueMaterials()
    end
    st.captureKey=key''')
change("    for _,name in ipairs({'FRAME_MAIN','BAND_INNER','BODY_FABRIC_TRACE','DRIVER_FACE','DRIVER_BALAKLAVA','CAM','CAM_FABRIC'}) do\n        local ref=st.root:findMeshes(name)\n        if ref and #ref>0 then",
       "    for index,name in ipairs(names) do\n        local ref=st.root:findMeshes(name)\n        if flags[index]=='1' and ref and #ref>0 then")
change('-- sNN 2026-10-12:','-- s61 2026-10-12:')
change('-- Stage 2: use the real GLASS_EXT_DUMMY KN5 mesh','-- Stage 2: use the real GLASS_RAINFX KN5 mesh')
change('-- GLASS_EXT_DUMMY KN5 mesh.','-- GLASS_RAINFX KN5 mesh.')
# Static micro generation uses physical metric kernels on a rectangular cell grid.
change('                        values = {\n                            gMicroPatternGrid = patternGrid,',
       "                        textures={txRainDu=rainDynamicSceneCopyState.surface.root..'du.dds',\n                            txRainDv=rainDynamicSceneCopyState.surface.root..'dv.dds',\n                            txRainBoundaryMask=textureRainBoundaryMask},\n                        values = {\n                            gMicroPatternGrid = patternGrid,\n                            gMicroGridUV=vec2(patternGrid,patternGrid/4),\n                            gRainMetersPerUnit=rainDynamicSceneCopyState.surface:unit(),")
change('                        shader = [[\n                            float3 hashMicroCell',
       '                        shader = rainDynamicSceneCopyState.surface.shader..[[\n                            float3 hashMicroCell')
change('float2 p = pin.Tex * gMicroPatternGrid;','float2 p = pin.Tex * gMicroGridUV;')
change('                                    [unroll] for (int y = -1; y <= 1; ++y)',
       '                                    [loop] for (int y = -2; y <= 2; ++y)')
change('                                        [unroll] for (int x = -1; x <= 1; ++x)',
       '                                        [loop] for (int x = -2; x <= 2; ++x)')
change('                                            float2 local = (p - center) / radius;',
       '''                                            float2 uvCenter=center/gMicroGridUV;
                                            float2 rawCenter=float2(uvCenter.x,uvCenter.y-1);
                                            float2 local = rainMetricPlane(rawCenter,pin.Tex-uvCenter)*gMicroPatternGrid/radius;
                                            if(rainValid(rawCenter)<.5)continue;''')
change("        ui.text(string.format('Visor surface renderer: micro pattern %s | birth canvas %s',",
       "        ui.text('Surface geometry: '..tostring(rainDynamicSceneCopyState.surface.status))\n        wfCheck('Water in mirrors (no glass optics capture)', 'RAIN_MIRROR_WATER')\n        wfSlider('Coating adhesion factor','RAIN_SURFACE_COAT_ADHESION',0.05,1.0,'%.2f')\n        wfSlider('Bare glass extra drag','RAIN_SURFACE_GLASS_EXTRA_DRAG',0.0,5.0,'%.2f')\n        wfSlider('Coating trail retention','RAIN_SURFACE_COAT_RETENTION',0.1,1.0,'%.2f')\n        ui.text(string.format('Visor surface renderer: micro pattern %s | birth canvas %s',")
assert p.stat().st_mtime_ns==mtime;p.write_text(s,encoding='utf-8')

p=ROOT/'visor_optics.lua';s=p.read_text(encoding='utf-8');mtime=p.stat().st_mtime_ns
change('useTexture and 2048 or 512,useTexture and 2048 or 512',
       'useTexture and 2048 or 512,useTexture and 512 or 128')
change('if self.probeOwner~=probe.root then','if self.probeOwner~=probe.root or self.probeKey~=probe.captureKey then')
change('self.probeOwner=probe.root;self.probeReady=false',
       'self.probeOwner=probe.root;self.probeKey=probe.captureKey;self.probeReady=false')
change('local refs,owner,prepared=d.sourceEnsure()','local refs,owner,prepared,members=d.sourceEnsure()')
change('self.sourceOwner~=owner or self.sourceWidth~=width',
       'self.sourceOwner~=owner or self.sourceWidth~=width or self.sourceMembers~=members')
change('self.sourceWidth=width;self.sourceOwner=owner',
       'self.sourceWidth=width;self.sourceOwner=owner;self.sourceMembers=members')
assert p.stat().st_mtime_ns==mtime;p.write_text(s,encoding='utf-8')
print('Capture membership invalidation, physical micro texture and controls updated')
