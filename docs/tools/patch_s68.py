from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def patch(name,edit):
    p=ROOT/name;stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
    def one(a,b):
        nonlocal s
        assert s.count(a)==1,(name,a[:100],s.count(a));s=s.replace(a,b)
    edit(one)
    assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8',newline='\r\n')
def native(one):
    one("        if ui.treeNode('Native glass render states') then", "        ui.treeNode('Native glass render states',function()")
    one('            ui.treePop()\n        end','        end)')
patch('native_glass_state.lua',native)
def main(one):
    one('    -- Stage 3: persistent GPU state -> async CPU readback -> dynamic vertices.', '''    -- A simulation frame can contain more than one rendered view (captures,
    -- VR eyes, pause/redraw). Completion belongs to a main view, not sim.frame.
    rainDynamicSceneCopyState.beginMainView=function()
        local st=rainDynamicSceneCopyState
        if (st.offscreenCaptureActive or 0)>0 then return end
        local sim=ac.getSim();if not sim then return end
        local size=render.getRenderTargetSize()
        st.mainViewSerial=(st.mainViewSerial or 0)+1
        st.mainViewFrame=sim.frame;st.mainViewW=math.floor(size.x);st.mainViewH=math.floor(size.y)
        st.mainViewKey=table.concat({sim.frame,st.mainViewSerial,st.mainViewW,st.mainViewH},':')
    end
    rainDynamicSceneCopyState.renderViewKey=function()
        local st=rainDynamicSceneCopyState
        if (st.offscreenCaptureActive or 0)>0 then return nil end
        local sim=ac.getSim();if not sim then return nil end
        local size=render.getRenderTargetSize();local w,h=math.floor(size.x),math.floor(size.y)
        if st.mainViewFrame==sim.frame then
            if w~=st.mainViewW or h~=st.mainViewH then
                st.viewSkipReason='Different render target: '..w..'x'..h;return nil
            end
            st.viewSkipReason=nil;return st.mainViewKey
        end
        return table.concat({sim.frame,'untracked',w,h},':')
    end
    render.on('main.track.opaque',rainDynamicSceneCopyState.beginMainView)
    -- Stage 3: persistent GPU state -> async CPU readback -> dynamic vertices.''')
    one('        RAIN_VISOR_LAYER_OPTICS_BRIGHTNESS = 0.73,','''        RAIN_VISOR_LAYER_OPTICS_BRIGHTNESS = 0.73,
        RAIN_VISOR_LAYER_OPTICS_CONVEX_TINT = 0.0, -- 0 clear, 1 black; authored convex area only''')
    one("        sl('Masked optics brightness', 'RAIN_VISOR_LAYER_OPTICS_BRIGHTNESS', 0.0, 2.0, '%.2f')", "        sl('Masked optics brightness (effect gain)', 'RAIN_VISOR_LAYER_OPTICS_BRIGHTNESS', 0.0, 2.0, '%.2f')\n        sl('Convex region tint darkness', 'RAIN_VISOR_LAYER_OPTICS_CONVEX_TINT', 0.0, 1.0, '%.2f')\n        ui.textWrapped('Convex tint: 0 clear / 1 black. Uses the authored convex region including its crown; keeps the central window clear.')")
    one('    v.gLayerOpticsBrightness = r.RAIN_VISOR_LAYER_OPTICS_BRIGHTNESS','    v.gLayerOpticsBrightness = r.RAIN_VISOR_LAYER_OPTICS_BRIGHTNESS\n    v.gLayerOpticsConvexTint = r.RAIN_VISOR_LAYER_OPTICS_CONVEX_TINT')
    one("    local shader = vl.shader\n    if not shader then return end\n    local sim = ac.getSim()", "    local shader = vl.shader\n    if not shader then return false end\n    if not ov.internalSource and ov.viewKey and item.drawViewKey==ov.viewKey then return true end\n    local sim = ac.getSim()")
    one("    local p = item.params\n    p.shader = ov.internalSource", "    local p = item.params\n    p.async=true\n    p.shader = ov.internalSource")
    one("    if not ov.internalSource and r.RAIN_VISOR_LAYER_E1_SURFACE_TEST and item.mesh == rainDynamicSceneCopyState.e1SurfaceTarget() then\n        rainDynamicSceneCopyState.e1SurfaceDraw('slot')\n    end\nend", "    if not ov.internalSource and r.RAIN_VISOR_LAYER_E1_SURFACE_TEST and item.mesh == rainDynamicSceneCopyState.e1SurfaceTarget() then\n        rainDynamicSceneCopyState.e1SurfaceDraw('slot')\n    end\n    if not ok or err==false then return false end\n    if not ov.internalSource then item.drawViewKey=ov.viewKey end\n    return true\nend")
    one("    local vl = rainDynamicSceneCopyState.visorLayer\n    if not vl.shader then\n        for _, sh in ipairs(shaders) do\n            if sh.ID == 'RAINFXVISORLAYER' and sh.LOADED then vl.shader = sh.HLSL end\n        end\n        if not vl.shader then vl.status = 'shader not loaded'; return end", "    local vl = rainDynamicSceneCopyState.visorLayer\n    local viewKey=rainDynamicSceneCopyState.renderViewKey();if not viewKey then return false end\n    if not vl.shader then\n        for _, sh in ipairs(shaders) do\n            if sh.ID == 'RAINFXVISORLAYER' and sh.LOADED then vl.shader = sh.HLSL end\n        end\n        if not vl.shader then vl.status = 'shader not loaded'; return false end")
    one('    local src = vl.fallbackSourceFrame==ac.getSim().frame and vl.fallbackSource','    local src = vl.fallbackSourceViewKey==viewKey and vl.fallbackSource')
    one('    sov.src, sov.hdr = src, true','    sov.src, sov.hdr = src, true\n    sov.viewKey=viewKey\n    local drawReady=true')
    one('            vl.err=st.nativeGlass.error;return -- no unoccluded fallback over native glass', "            vl.err=st.nativeGlass.error;vl.status='Native glass mask preparing';return false -- preserve exterior ownership")
    one('            rainDynamicSceneCopyState.visorLayerDrawItem(item, sov)\n        end\n    end\n    local afterRain', '            if rainDynamicSceneCopyState.visorLayerDrawItem(item, sov)==false then drawReady=false end\n        end\n    end\n    local afterRain')
    one('                rainDynamicSceneCopyState.visorLayerDrawItem(item, sov)\n            end\n            if phase', '                if rainDynamicSceneCopyState.visorLayerDrawItem(item, sov)==false then drawReady=false end\n            else drawReady=false\n            end\n            if phase')
    one("    vl.status = 'scene stack drawn'\n    vl[phase=='pre' and 'preFrame' or 'postFrame']=ac.getSim().frame", "    vl.status = drawReady and 'scene stack drawn' or 'Glass shader/source preparing'\n    if not drawReady then return false end\n    vl[phase=='pre' and 'preFrame' or 'postFrame']=ac.getSim().frame\n    vl[phase=='pre' and 'preViewKey' or 'postViewKey']=viewKey")
    one('    if st.visorLayer.postFrame~=sim.frame then','    local viewKey=st.renderViewKey();if not viewKey then return end\n    if st.visorLayer.postViewKey~=viewKey then')
    one('            if vl.fallbackSourceFrame~=sim.frame then','            if vl.fallbackSourceViewKey~=viewKey then')
    one('                vl.fallbackSourceFrame=sim.frame\n            end\n            if st.visorLayer.preFrame~=sim.frame then st.visorSceneStack(\'pre\') end', "                vl.fallbackSourceFrame=sim.frame;vl.fallbackSourceViewKey=viewKey\n            end\n            if st.visorLayer.preViewKey~=viewKey then st.visorSceneStack('pre') end")
    one('        and rainDynamicSceneCopyState.lastSmokeDrawFrame == sim.frame','        and rainDynamicSceneCopyState.lastSmokeDrawViewKey == rainDynamicSceneCopyState.renderViewKey()')
    one('    rainDynamicSceneCopyState.prepareWaitLogged = false\n\n    local rainDynamicDropShader', '    rainDynamicSceneCopyState.prepareWaitLogged = false\n    local drawViewKey=rainDynamicSceneCopyState.renderViewKey();if not drawViewKey then return end\n\n    local rainDynamicDropShader')
    one('        rainDynamicSceneCopyState.lastSmokeDrawFrame = sim.frame','        rainDynamicSceneCopyState.lastSmokeDrawFrame = sim.frame\n        rainDynamicSceneCopyState.lastSmokeDrawViewKey = drawViewKey')
    one("    local sceneStackOk,sceneStackError = pcall(rainDynamicSceneCopyState.measure,'Glass pre',rainDynamicSceneCopyState.visorSceneStack,'pre')\n    if not sceneStackOk then rainDynamicSceneCopyState.visorLayer.err='Glass pre: '..tostring(sceneStackError) end", "    local sceneStackOk,sceneStackResult = pcall(rainDynamicSceneCopyState.measure,'Glass pre',rainDynamicSceneCopyState.visorSceneStack,'pre')\n    if not sceneStackOk then rainDynamicSceneCopyState.visorLayer.err='Glass pre: '..tostring(sceneStackResult) end\n    sceneStackOk=sceneStackOk and sceneStackResult~=false")
    one("    if rainDynamicSceneCopyState.nativeGlassState then rainDynamicSceneCopyState.nativeGlassState:ui() end", "    if rainDynamicSceneCopyState.nativeGlassState then rainDynamicSceneCopyState.nativeGlassState:ui() end\n    do\n        local st=rainDynamicSceneCopyState;local vl=st.visorLayer;local n=st.nativeGlass\n        ui.textWrapped('FX view '..tostring(st.mainViewKey)..' | pre '..tostring(vl.preViewKey)..' | post '..tostring(vl.postViewKey))\n        if st.viewSkipReason then ui.textWrapped(st.viewSkipReason) end\n        if n then ui.textWrapped('Native mask: '..(n.ready and 'ready' or 'pending')..' / updates '..n.updates..' / '..tostring(n.error or vl.status)) end\n        if vl.err then ui.textWrapped('Glass: '..tostring(vl.err)) end\n    end")
patch('realvisor.lua',main)
def shader(one):
    one('        float bandReplace = bandFloor * saturate(gLayerBandOpacity);', '''        // Tint transmission across the authored convex area, including the
        // flat crown. It stays independent of relief/refraction effect gain.
        opticalImage*=1-saturate(gLayerOpticsConvexTint)*saturate(lensField.a);
        float bandReplace = bandFloor * saturate(gLayerBandOpacity);''')
patch('shaders/rainVisorLayer.hlsl',shader)
print('s68 patched view-scoped FX completion, callback UI and independent convex tint')
