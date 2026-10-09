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
        render={on=function() end}
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
            'ensureUniqueMaterials','setCullMode','setTransparent','setBlendMode','setDepthMode'}) do
            methods[name]=function() error('Unexpected baked material/render-state mutation: '..name) end
        end
        local names={'BODY_FRAME','BODY_GLASSLINE','BODY_FABRIC',
            'BODY_FRAME_OVERLAY','BODY_GLASSLINE_OVERLAY','BODY_FABRIC_OVERLAY',
            'DRIVER_FACE','DRIVER_BALAKLAVA','GLASS_COATING_OVERLAY','BODY_FRAME_MIRROR','UNRELATED'}
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
            if name:find('BODY_') then editors[name]={meshName=name,targetMesh=visor:findMeshes(name),visible=true} end
        end
        rainDynamicSceneCopyState.visorLayerEditor=function(name) return editors[name] end
        rainDynamicSceneCopyState.visorLayerDefs=function() return {housing={
            {mesh='BODY_FRAME',mat='FRAME'},{mesh='BODY_GLASSLINE',mat='RUBBER'},
            {mesh='BODY_FABRIC',mat='FABRIC'}}} end
    ''')
    start=source.index('rainDynamicSceneCopyState.nativeHousingEnsure = function()')
    end=source.index('render.onSceneReady',start)
    lua.execute(source[start:end])
    start=source.index('rainDynamicSceneCopyState.e1ReflectionActors = function()')
    end=source.index('rainDynamicSceneCopyState.e1SourceDepthDraw = function()',start)
    lua.execute(source[start:end])
    lua.execute('''
        local st=rainDynamicSceneCopyState
        local native=st.nativeHousingEnsure()
        assert(#native==3)
        for _,name in ipairs({'BODY_FRAME_OVERLAY','BODY_GLASSLINE_OVERLAY','BODY_FABRIC_OVERLAY'}) do
            assert(not editors[name].visible)
            assert(not editors[name].targetMesh[1].visible and not editors[name].targetMesh[1].shadows)
        end
        local selected=st.nativeCaptureRefs(true)
        assert(#selected==5 and selected~=capture)
        local allowed={BODY_FRAME=true,BODY_GLASSLINE=true,BODY_FABRIC=true,DRIVER_FACE=true,DRIVER_BALAKLAVA=true}
        for _,m in ipairs(selected) do assert(allowed[m.name] and m.material==m.name..'-original') end
        for name,ref in pairs(capture.meshes) do
            assert(not ref[1].shadows)
            assert(not ref[1].visible) -- allowlist selection must not leak a scene draw
        end
        assert(not visor.meshes.DRIVER_FACE[1].visible and not visor.meshes.DRIVER_BALAKLAVA[1].visible)
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
        editors.BODY_FABRIC.targetMesh=refs()
        assert(#st.nativeHousingEnsure()==2 and st.nativeHousingStatus:find('BODY_FABRIC'))
        visor=model();visor.meshes.DRIVER_FACE=nil;visor.meshes.DRIVER_BALAKLAVA=nil
        assert(#st.e1ReflectionActors()==0)
        assert(#st.nativeCaptureRefs(true)==2)
    ''')
    print('PASS: authored materials; capture allowlist; moving native transform preparation; capture cleanup/nested callbacks; checker mode; optional/missing meshes')
