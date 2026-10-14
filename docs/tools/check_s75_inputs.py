"""P0 input-contract checks in LuaJIT and guarded implementation snapshot."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'docs/diagnostics/2026-10-14/s75'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def snapshot():
    assert subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip()=='codex/rainfx-physics-weather'
    parent=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    assert parent.startswith('3975491')
    assert not (OUT/'baseline_manifest.json').exists()
    names=['realvisor.lua','rain_surface.lua','rain_trails.lua','settings.ini','settings_mats.ini',
           'docs/README.md','docs/RAINFX_ROADMAP.md','docs/RAINFX_S73_PHYSICS_WEATHER_REFACTOR_DESIGN.md']
    names += [p.relative_to(ROOT).as_posix() for p in (ROOT/'shaders').glob('*.hlsl')]
    manifest={}
    for name in names:
        p=ROOT/name
        if not p.is_file():continue
        dst=OUT/'baseline'/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst)
        manifest[name]={'sha256':sha(p),'mtime_ns':p.stat().st_mtime_ns}
    (OUT/'baseline_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('Staged '+str(len(manifest))+' files at '+parent)


def load_lua(folder):
    for wheel in (Path.home()/'AppData/Local/pip/Cache/http-v2').rglob('*.body'):
        try:
            with zipfile.ZipFile(wheel) as z:
                if any('lupa/luajit21' in name for name in z.namelist()):
                    z.extractall(folder);sys.path.insert(0,folder)
                    from lupa.luajit21 import LuaRuntime
                    return LuaRuntime()
        except zipfile.BadZipFile:pass
    raise RuntimeError('Cached LuaJIT runtime not found')


def main():
    if len(sys.argv)>1 and sys.argv[1]=='snapshot':snapshot();return
    with tempfile.TemporaryDirectory(prefix='s75_luajit_',ignore_cleanup_errors=True) as folder:
        lua=load_lua(folder)
        for name in ('realvisor.lua','rain_environment.lua','rain_physics_units.lua'):
            lua.execute('assert(loadstring(...))',(ROOT/name).read_text(encoding='utf-8-sig'))
        lua.globals().factory=lua.execute((ROOT/'rain_environment.lua').read_text(encoding='utf-8'))
        lua.globals().unitsFactory=lua.execute((ROOT/'rain_physics_units.lua').read_text(encoding='utf-8'))
        checks=Path(__file__).with_name('s75_input_cases.lua').read_text(encoding='utf-8')
        report=lua.execute(checks)
        result={k:v for k,v in report.items()}
        source=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
        # Execute the actual main-loop hook and popup callback, including partial readiness.
        start=source.index('rainDynamicSceneCopyState.physicsInputsUpdate=function()')
        end=source.find('\nrainDynamicSceneCopyState.siShader=',start)
        if end<0:end=source.index('\nrainStateUpdateParams.shader =',start)
        hook=source[start:end]
        start=source.index("rainDynamicSceneCopyState.rainUIPanels['physics_inputs']=function()")
        end=source.index('\nrainDynamicSceneCopyState.rainUISlider =',start)
        panel=source[start:end]
        lua.execute('''
            appNameDebug='[test]'; loads=0; logged=0; lines=0; clickLog=false
            cfg={RUNTIME={RAIN_GPU_STATE_RAIN_OVERRIDE=-1,RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM=6/4096}}
            ac={WeatherType={Snow=10,Sleet=13,Hail=32,LightSnow=9,HeavySnow=11,LightSleet=12,HeavySleet=14},
                getSim=function() return {frame=1,dt=1/60,rainIntensity=0} end,getCar=function() return nil end,
                log=function() logged=logged+1 end}
            ui={checkbox=function() return false end,
                text=function(t) assert(type(t)=='string');lines=lines+1 end,
                textWrapped=function(t) assert(type(t)=='string');lines=lines+1 end,
                separator=function() end,sameLine=function() end,
                button=function(label) return clickLog and label=='Log input snapshot' end}
            rainDynamicSceneCopyState={rainUIPanels={},rainUISlider=function() end,surface={ready=false},
                loadRuntimeModule=function(name)
                    loads=loads+1
                    if name=='rain_environment.lua' then return factory end
                    if name=='rain_physics_units.lua' then return unitsFactory end
                    error('Unexpected module')
                end}
        ''')
        lua.execute(hook);lua.execute(panel)
        lua.execute('''
            local st=rainDynamicSceneCopyState
            for i=1,200 do st.physicsInputsUpdate();st.rainUIPanels.physics_inputs() end
            assert(loads==2 and st.physicsInputs.updates==1 and logged==0)
            clickLog=true;st.rainUIPanels.physics_inputs();assert(logged==1);clickLog=false
            st.surface={ready=true,scale=1,metric=function() return 4096*.001/6,0,1024*.001/6 end}
            st.rainUIPanels.physics_inputs()
            st.surface.metric=function() return nil end;st.rainUIPanels.physics_inputs()
            st.physicsInputs=nil
            st.loadRuntimeModule=function() return nil,'missing module' end
            local before=lines;st.rainUIPanels.physics_inputs();assert(lines==before+1)
            assert(lines>0)
        ''')
        result['actual_lazy_hook_and_ui_callback']=True
        result['manual_log_only_and_once_per_frame']=True
        baseline=json.loads((OUT/'baseline_manifest.json').read_text())
        unchanged={name:sha(ROOT/name)==meta['sha256'] for name,meta in baseline.items()
                   if not name.startswith('docs/') and name!='realvisor.lua'}
        assert all(unchanged.values()),unchanged
        old=(OUT/'baseline/realvisor.lua').read_text(encoding='utf-8-sig')
        p1_binding='rainDynamicSceneCopyState.stateEntryShader=' in source
        stripped=source
        begin=stripped.index('-- P0 observer: independent inputs, no live state/shader/Smear mutation.')
        end=stripped.index('rainStateUpdateParams.shader =',begin)
        stripped=stripped[:begin]+stripped[end:]
        begin=stripped.index("rainDynamicSceneCopyState.rainUIPanels['physics_inputs']=function()")
        end=stripped.index('rainDynamicSceneCopyState.rainUISlider =',begin)
        stripped=stripped[:begin]+stripped[end:]
        for added in ('    rainDynamicSceneCopyState.physicsInputsUpdate()\n',
                      "    rainDynamicSceneCopyState.rainUIGroup('Weather inputs and physical units (P0)', 'physics_inputs')\n"):
            assert stripped.count(added)==1
            stripped=stripped.replace(added,'',1)
        if not p1_binding:
            assert stripped==old,'Unexpected change outside P0 observer/UI integration'
            result['legacy_source_except_observer_ui_identical']=True
        else:
            result.pop('live_physics_not_changed',None)
            result['scope']='P0 observer/unit/UI checks; active shader routing is checked by s77'
            result['P1_opt_in_binding_present']=True
        import difflib
        (OUT/'source.diff').write_text(''.join(difflib.unified_diff(old.splitlines(True),source.splitlines(True),
            fromfile='3975491/realvisor.lua',tofile='s75/realvisor.lua')),encoding='utf-8')
        result.update({'shader_settings_surface_trail_unchanged':unchanged,
                       'actual_CSP_gravity_convention_verified_by_user':True,
                       'actual_game_SI_preview_basic_motion_verified_by_user':True})
        game=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')
        installed={name:sha(game/name)==sha(ROOT/name) for name in
                   ['realvisor.lua','rain_environment.lua','rain_physics_units.lua']}
        assert all(installed.values()),installed
        result['installed_sources_match']=installed
        (OUT/'checks.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
        print(json.dumps(result,indent=2))


if __name__=='__main__':main()
