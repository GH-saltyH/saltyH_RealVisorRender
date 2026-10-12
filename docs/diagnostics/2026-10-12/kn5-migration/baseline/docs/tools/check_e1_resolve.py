"""Check reflection resolve lifecycle and failure visibility using LuaJIT."""
from pathlib import Path
import runpy

root=Path(__file__).resolve().parents[2]
env=runpy.run_path(str(root/'docs/tools/check_baked_housing.py'))
lua=env['lua']
source=(root/'realvisor.lua').read_text(encoding='utf-8-sig')
lua.execute('''
    function vec2(x,y) return {x=x,y=y} end
    function vector(x) return setmetatable({x=x,y=0,z=0,clone=function(self) return vector(self.x) end},
        {__sub=function(a,b) return vector(a.x-b.x) end}) end
    function rgbm() return {} end
    cfg={RUNTIME={RAIN_VISOR_LAYER_E1_PRIMARY=true,RAIN_VISOR_LAYER_E1_PRIMARY_MODE=0,
        RAIN_VISOR_LAYER_E1_SOURCE_MODE=0,RAIN_VISOR_LAYER_E1_PRIMARY_RESOLVE_BLUR=1.5,
        RAIN_VISOR_LAYER_E1_PRIMARY_RESOLVE_SCALE=0.75}}
    sim={cameraPosition=vector(0),cameraLook=vector(1),cameraUp=vector(0),cameraFOV=90}
    ac={getSim=function() return sim end}
    render={onSceneReady=function(f) sceneReady=f end,
        AntialiasingMode={None=0},TextureFormat={R16G16B16A16={Float=1}},
        CullMode={None=0},DepthMode={ReadOnly=0},BlendMode={BlendPremultiplied=0},
        setCullMode=function() end,setDepthMode=function() end,setBlendMode=function() end}
    intRef=refs({{visible=false}});ed={targetMesh=intRef,visible=true}
    rainDynamicSceneCopyState={e1Primary={},e1Source={ready=true},mainTargetWidth=1600,mainTargetHeight=900,
        visorLayerEditor=function() return ed end,
        e1PrimaryDraw=function(capture)
            assert(capture and rainDynamicSceneCopyState.e1Primary.resolving)
            traced=(traced or 0)+1
            if fail then error('capture failed') end
        end}
    function ac.GeometryShot(callbacks,size)
        shots=(shots or 0)+1
        local shot={size=size}
        for _,name in ipairs({'setName','setSky','setParticles','setClearColor','setClippingPlanes'}) do
            shot[name]=function() end
        end
        shot.update=function() callbacks.opaque();return not pending end
        shot.dispose=function(self) self.disposed=true end
        shot.viewMatrix=function() return {clone=function(self) return self end} end
        shot.projectionMatrix=shot.viewMatrix
        return shot
    end
''')
start=source.index('rainDynamicSceneCopyState.e1PrimaryResolve = {')
end=source.index('-- Geometry verification path:',start)
lua.execute(source[start:end])
lua.execute('''
    local st=rainDynamicSceneCopyState.e1PrimaryResolve
    sceneReady();assert(st.ready and shots==1 and traced==1 and st.w==1200 and st.h==675)
    sim.cameraPosition=vector(20)
    sceneReady();assert(st.ready and shots==1 and traced==2 and st.eye.x==20)
    render.mesh=function(p) assert(intRef[1].visible and p.textures.txResolve==st.shot);return true end
    rainDynamicSceneCopyState.e1PrimaryResolveDraw();assert(not intRef[1].visible)
    render.mesh=function() error('draw failed') end
    rainDynamicSceneCopyState.e1PrimaryResolveDraw()
    assert(not intRef[1].visible and rainDynamicSceneCopyState.e1Primary.status:find('error'))
    local previous=st.shot
    rainDynamicSceneCopyState.mainTargetWidth=1920
    sceneReady();assert(previous.disposed and st.w==1440 and shots==2 and st.ready)
    fail=true;sceneReady()
    assert(not st.ready and not st.shot and not rainDynamicSceneCopyState.e1Primary.resolving)
    fail=false;pending=true;sceneReady()
    assert(not st.ready and not st.shot and not rainDynamicSceneCopyState.e1Primary.resolving)
    pending=false;sceneReady();assert(st.ready)
    previous=st.shot
    cfg.RUNTIME.RAIN_VISOR_LAYER_E1_PRIMARY_RESOLVE_BLUR=0
    sceneReady();assert(previous.disposed and not st.shot and not st.ready)
    assert(not intRef[1].visible)
''')
print('PASS: one trace per frame, moving camera, resize/disposal, failed/pending cleanup, main visibility restoration and blur bypass')
