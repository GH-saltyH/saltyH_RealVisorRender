"""Actual mask module refresh with moving eye; no captures in main submissions."""
from pathlib import Path
import runpy,json
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s69'
env=runpy.run_path(str(ROOT/'docs/tools/check_s68_runtime.py'));lua=env['lua']
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
factory=lua.execute((ROOT/'native_glass_occlusion.lua').read_text(encoding='utf-8'));lua.globals().nativeFactory=factory
lua.execute('''
    local s=rainDynamicSceneCopyState
    cfg.RUNTIME.RAIN_VISOR_LAYER_E1_SURFACE_TEST=false;cfg.RUNTIME.RAIN_VISOR_OPTICS_ENABLED=false
    phase='scene-ready';movingEye=0;nativeDraws=0;fxDraws=0;maskPending=false
    local previousEditor=s.visorLayerEditor;nativeEditors={}
    for _,name in ipairs({'GLASS_EXT_MRR','GLASS_COAT_MRR','GLASS_INT_MRR','GLASS_STICKER_MRR'}) do
        nativeEditors[name]={visible=true,targetMesh=refs({{visible=true,shadows=false}})}
    end
    s.visorLayerEditor=function(name) return nativeEditors[name] or previousEditor(name) end
    s.nativeGlassLocalFrame=function() return vec3(movingEye,0,0),vec3(0,0,1),vec3(0,1,0) end
    local oldShot=ac.GeometryShot
    ac.GeometryShot=function(callback,...)
        local shot=oldShot(callback,...);local update=shot.update
        shot.setName=function() end
        shot.update=function(self,...)
            assert(phase=='scene-ready','GeometryShot update must precede main rendering')
            return update(self,...)
        end
        return shot
    end
    render.mesh=function(p)
        if not p.values then nativeDraws=nativeDraws+1;assert(phase=='scene-ready');return not maskPending end
        assert(phase=='main');fxDraws=fxDraws+1;return true
    end
    s.nativeGlass=nativeFactory({owner=function() return visor end,
        editor=function(name) return s.visorLayerEditor(name) end,
        localFrame=s.nativeGlassLocalFrame,captureUpdate=s.captureUpdate})
    for i=1,360 do
        sim.frame=500+i;movingEye=.02*math.sin(i*.13)
        phase='scene-ready';assert(s.nativeGlassPrepare() and s.nativeGlassPreparedFrame==sim.frame,
            tostring(s.visorLayer.err)..'/'..tostring(s.nativeGlass.error))
        local captures=nativeDraws
        phase='main';s.beginMainView();assert(s.visorSceneStack('pre') and s.visorSceneStack('post'))
        assert(nativeDraws==captures,'Moving FX submissions must never refresh a mask capture')
    end
    assert(nativeDraws==360*4 and fxDraws==360*3)
    local updates=s.nativeGlass.updates
    for i=1,50 do
        sim.frame=sim.frame+1;phase='scene-ready';assert(s.nativeGlassPrepare())
        phase='main';s.beginMainView();assert(s.visorSceneStack('post'))
    end
    assert(s.nativeGlass.updates==updates,'A settled/pause pose still reuses its mask')
    sim.frame=sim.frame+1;movingEye=.025;maskPending=true;phase='scene-ready'
    assert(not s.nativeGlassPrepare() and not s.nativeGlassPreparedFrame)
    phase='main';s.beginMainView();assert(s.visorSceneStack('post')==false)
    sim.frame=sim.frame+1;maskPending=false;phase='scene-ready';assert(s.nativeGlassPrepare())
    phase='main';s.beginMainView();assert(s.visorSceneStack('post'))
''')
a=source.index('rainDynamicSceneCopyState.visorSceneStack = function(');b=source.index('-- Glass and the routing test',a)
assert '.nativeGlass.update' not in source[a:b] and 'GeometryShot(' not in source[a:b]
report={'moving_frames':360,'maximum_motion_m':.02,'fx_submissions_during_motion':1080,
    'native_captures_in_main_stage':0,'settled_frames_reused':50,'pending_retry':True,
    'actual_game_gforce_visibility_verified':False}
(OUT/'motion_checks.json').write_text(json.dumps(report,indent=2))
print('PASS: actual moving mask capture runs only before main; 360 moving frames retain FX, settled cache and pending retry',report)
