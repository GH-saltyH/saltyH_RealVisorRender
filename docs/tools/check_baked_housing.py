"""LuaJIT syntax and baked housing/capture isolation regression checks."""
from pathlib import Path
import sys, tempfile, zipfile

root = Path(__file__).resolve().parents[2]
source = (root/'realvisor.lua').read_text(encoding='utf-8-sig')
with tempfile.TemporaryDirectory(prefix='housing_check_', dir=root/'docs/tools', ignore_cleanup_errors=True) as tmp:
    for wheel in (Path.home()/'AppData/Local/pip/Cache/http-v2').rglob('*.body'):
        try:
            with zipfile.ZipFile(wheel) as z:
                if any('lupa/luajit21' in n for n in z.namelist()):
                    z.extractall(tmp)
                    break
        except zipfile.BadZipFile:
            pass
    sys.path.insert(0, tmp)
    from lupa.luajit21 import LuaRuntime
    lua = LuaRuntime()
    lua.execute('assert(loadstring(...))', source)
    print('PASS: whole LuaJIT syntax')
    lua.execute('''
        rainDynamicSceneCopyState={nativeHousing={}}
        cfg={RUNTIME={MODEL_PATH='test.kn5'}}
        render={on=function() end,CullMode={None=2}}
        local methods={}
        function refs(items)
            return setmetatable(items or {},{__index=methods})
        end
        function methods:setVisible(v) for _,m in ipairs(self) do m.visible=v end end
        function methods:setShadows(v) for _,m in ipairs(self) do m.shadows=v end end
        function methods:clone() local t={} for i,m in ipairs(self) do t[i]=m end return refs(t) end
        function methods:append(other) for _,m in ipairs(other) do self[#self+1]=m end return self end
        function methods:at(i) return refs({self[i]}) end
        function methods:isVisible(i) return self[i].visible end
        function methods:isCastingShadows(i) return self[i].shadows end
        function methods:assignMaterialFrom(other)
            for i,m in ipairs(self) do m.material=other[i].material end
        end
        for _,name in ipairs({'applyShaderReplacements','setMaterialTexture','setMaterialProperty',
            'ensureUniqueMaterials','setTransparent','setBlendMode','setDepthMode'}) do
            methods[name]=function() error('Unexpected baked material/render-state mutation: '..name) end
        end
        function methods:setCullMode(mode)
            for _,m in ipairs(self) do assert(m.name=='FRAME_MAIN' and mode==render.CullMode.None);m.cull=mode end
        end
        local names={'FRAME_MAIN','BAND_INNER','BODY_FABRIC_TRACE',
            'FRAME_MAIN_OVERLAY','BAND_INNER_OVERLAY','BODY_FABRIC_TRACE_OVERLAY',
            'CAM','CAM_COVER','CAM_FABRIC','DRIVER_FACE','DRIVER_BALAKLAVA','GLASS_COAT_FX','FRAME_MAIN_MIRROR','UNRELATED'}
        function model()
            local m={meshes={},pose={value=0}}
            m.pose.set=function(self,other) self.value=other.value end
            for _,name in ipairs(names) do
                m.meshes[name]=refs({{name=name,visible=true,shadows=true,material=name..'-original'}})
            end
            function m:findMeshes(name)
                if name~='*' then return self.meshes[name] or refs() end
                local r=refs();for _,v in pairs(self.meshes) do r:append(v) end;return r
            end
            function m:setVisible(v) self.visible=v end
            function m:getTransformationRaw() return self.pose end
            function m:dispose() self.disposed=true end
            return m
        end
        visor=model()
        axisRollNode={loadKN5=function() capture=model();return capture end}
        editors={}
        for _,name in ipairs(names) do
            if not name:find('DRIVER_') then editors[name]={meshName=name,targetMesh=visor:findMeshes(name),visible=true} end
        end
        rainDynamicSceneCopyState.visorLayerEditor=function(name) return editors[name] end
        rainDynamicSceneCopyState.visorLayerDefs=function() return {housing={
            {mesh='FRAME_MAIN',mat='FRAME'},{mesh='BAND_INNER',mat='RUBBER'},
            {mesh='BODY_FABRIC_TRACE',mat='FABRIC'},{mesh='CAM',mat='CAM'},{mesh='CAM_COVER',mat='CAM'},{mesh='CAM_FABRIC',mat='CAM'}}} end
    ''')
    start=source.index('    rainDynamicSceneCopyState.captureUpdate=function(')
    end=source.index('    -- Stage 3:',start)
    lua.execute(source[start:end])
    start=source.index('rainDynamicSceneCopyState.nativeHousingEnsure = function()')
    end=source.index('render.onSceneReady',start)
    lua.execute(source[start:end])
    start=source.index('rainDynamicSceneCopyState.e1ReflectionActors = function()')
    end=source.index('rainDynamicSceneCopyState.e1SourceDepthDraw = function(',start)
    lua.execute(source[start:end])
    lua.execute('''
        local st=rainDynamicSceneCopyState
        local native=st.nativeHousingEnsure()
        assert(#native==6)
        for _,name in ipairs({'FRAME_MAIN_OVERLAY','BAND_INNER_OVERLAY','BODY_FABRIC_TRACE_OVERLAY'}) do
            assert(editors[name].visible)
            assert(editors[name].targetMesh[1].visible and editors[name].targetMesh[1].shadows)
        end
        local selected=st.nativeCaptureRefs(true)
        assert(#selected==8 and selected~=capture)
        local allowed={FRAME_MAIN=true,BAND_INNER=true,BODY_FABRIC_TRACE=true,DRIVER_FACE=true,DRIVER_BALAKLAVA=true,CAM=true,CAM_COVER=true,CAM_FABRIC=true}
        for _,m in ipairs(selected) do assert(allowed[m.name] and m.material==m.name..'-original') end
        for name,ref in pairs(capture.meshes) do
            assert(not ref[1].shadows)
            assert(not ref[1].visible) -- allowlist selection must not leak a scene draw
        end
        assert(visor.meshes.DRIVER_FACE[1].visible and visor.meshes.DRIVER_BALAKLAVA[1].visible)
        for _,actor in ipairs(st.e1ReflectionActors()) do assert(actor.two==true) end
        st.nativeCaptureHide();assert(not capture.visible)
        local shot={update=function()
            assert(capture.visible)
            assert(st.nativeCaptureActive==1)
            -- Simulate a scene callback dispatched by the nested native shot.
            st.nativeCaptureHide()
            assert(capture.visible)
            for name,ref in pairs(capture.meshes) do
                assert(ref[1].visible==(allowed[name] or false))
            end
            return true
        end}
        assert(st.nativeCaptureUpdate(shot,selected)==true)
        assert(st.nativeCaptureActive==0)
        assert(not capture.visible)
        for _,m in ipairs(selected) do assert(not m.visible) end
        cfg.RUNTIME.RAIN_VISOR_LAYER_E1_SOURCE_PREVIEW=true
        st.nativeCapturePrepare()
        assert(capture.visible)
        for name,ref in pairs(capture.meshes) do assert(ref[1].visible==(allowed[name] or false)) end
        assert(st.nativeCaptureUpdate(shot,selected)==true and not capture.visible)
        -- Simulate native engine transforms updating only visible renderables.
        -- A late visibility toggle at shot:update cannot repair a stale frame.
        for _,position in ipairs({10,250,-90}) do
            visor.pose.value=position
            st.nativeCapturePrepare()
            assert(capture.pose.value==position)
            for _,ref in pairs(capture.meshes) do
                if capture.visible and ref[1].visible then ref[1].cachedPose=capture.pose.value end
            end
            local movingShot={update=function()
                st.nativeCaptureHide() -- nested scene callback must not interrupt capture
                for _,m in ipairs(selected) do assert(m.cachedPose==position and m.visible) end
                return true
            end}
            assert(st.nativeCaptureUpdate(movingShot,selected)==true)
            assert(not capture.visible)
            for _,ref in pairs(capture.meshes) do assert(not ref[1].visible) end
        end
        cfg.RUNTIME.RAIN_VISOR_LAYER_E1_SOURCE_MODE=2
        st.nativeCapturePrepare();assert(not capture.visible)
        for _,ref in pairs(capture.meshes) do assert(not ref[1].visible) end
        cfg.RUNTIME.RAIN_VISOR_LAYER_E1_SOURCE_MODE=0
        shot.update=function() error('capture failed') end
        assert(not pcall(st.nativeCaptureUpdate,shot,selected))
        assert(st.nativeCaptureActive==0)
        assert(not capture.visible)
        for _,m in ipairs(selected) do assert(not m.visible) end
        shot.update=function() return false end
        assert(st.nativeCaptureUpdate(shot,selected)==false and not capture.visible)
        for _,m in ipairs(selected) do assert(not m.visible) end
        cfg.RUNTIME.RAIN_VISOR_OPTICS_ENABLED=true
        cfg.RUNTIME.RAIN_VISOR_OPTICS_NATIVE_SOURCE=true;cfg.RUNTIME.RAIN_VISOR_OPTICS_TIER=2
        local opticsRefs=st.nativeCaptureRefs(true,'opticsSource')
        assert(#opticsRefs==8 and not st.nativeCaptureModel.opticsSource.prepared)
        st.nativeCapturePrepare()
        assert(st.nativeCaptureModel.opticsSource.prepared and not st.nativeCaptureModel.source.prepared)
        assert(st.nativeCaptureModel.opticsSource.root.visible)
        local colourShot={update=function()
            for _,m in ipairs(opticsRefs) do assert(m.visible and allowed[m.name]) end
            return true
        end}
        assert(st.nativeCaptureUpdate(colourShot,opticsRefs))
        assert(not st.nativeCaptureModel.opticsSource.root.visible)
        assert(visor.meshes.DRIVER_FACE[1].visible and visor.meshes.DRIVER_BALAKLAVA[1].visible)
        cfg.RUNTIME.RAIN_VISOR_OPTICS_NATIVE_SOURCE=false;st.nativeCapturePrepare()
        assert(not st.nativeCaptureModel.opticsSource.prepared)
        editors.BODY_FABRIC_TRACE.targetMesh=refs()
        assert(#st.nativeHousingEnsure()==5 and st.nativeHousingStatus:find('BODY_FABRIC_TRACE'))
        visor=model();visor.meshes.DRIVER_FACE=nil;visor.meshes.DRIVER_BALAKLAVA=nil
        assert(#st.e1ReflectionActors()==0)
        assert(#st.nativeCaptureRefs(true)==5)
    ''')
    print('PASS: authored materials; capture allowlist; moving native transform preparation; capture cleanup/nested callbacks; checker mode; optional/missing meshes')
