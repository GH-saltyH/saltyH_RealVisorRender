"""Read-only game audit and workspace delivery record; never writes tuning."""
from pathlib import Path
import json,hashlib,difflib,re
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s67'
BASE=OUT/'baseline';GAME=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
runtime_files=['realvisor.lua','visor_optics.lua','material_settings.lua','native_glass_occlusion.lua',
 'native_glass_state.lua','rain_surface.lua','rain_trails.lua','shaders/rainVisorDynamicDrop.hlsl',
 'shaders/rainTrailDescriptor.hlsl','shaders/rainTrailBin.hlsl','shaders/rainTrailResolve.hlsl']
doc_files=['docs/RAINFX_S67_NEW_TRAIL.md','docs/README.md','docs/RAINFX_ROADMAP.md',
 'docs/RAINFX_S66_STARTUP_AND_GLASS_DIAGNOSIS.md']
records={};diff=[]
for name in runtime_files+doc_files:
    source=ROOT/name
    records[name]={'source_sha256':digest(source),'mtime_ns':source.stat().st_mtime_ns}
    baseline=BASE/name
    if name in runtime_files:
        installed=GAME/name
        records[name].update(installed=installed.exists(),installed_sha256=digest(installed),
         linked_source=installed.is_symlink() or installed.parent.is_symlink())
        assert digest(installed)==digest(source),name
    old=baseline.read_text(encoding='utf-8-sig') if baseline.exists() else ''
    diff.extend(difflib.unified_diff(old.splitlines(True),source.read_text(encoding='utf-8-sig').splitlines(True),
     fromfile='s66/'+name,tofile='s67/'+name))
def initial_values(path):
    values={}
    for k,v in re.findall(r'\b(RAIN_\w+)\s*=\s*(true|false|-?\d+(?:\.\d+)?)\s*,',path.read_text(encoding='utf-8-sig')):
        values.setdefault(k,v)
    return values
before=initial_values(BASE/'realvisor.lua');after=initial_values(ROOT/'realvisor.lua')
changes={k:{'snapshot':v,'retained_current':after[k]} for k,v in before.items() if after[k]!=v}
# These tuning edits were already present alongside the interrupted work.
# None of the s67 patch scripts changes these existing scalar declarations.
retained_keys={'RAIN_GPU_STATE_COUNT','RAIN_DYNAMIC_TRAIL_REFRACT_PX',
 'RAIN_DYNAMIC_TRAIL_GRAD_WIDE_TEXELS','RAIN_DYNAMIC_TRAIL_GRAD_MIX',
 'RAIN_DYNAMIC_TRAIL_PROFILE_RANGE','RAIN_DYNAMIC_TRAIL_SLOPE_MAX'}
assert set(changes)<=retained_keys,changes
settings={}
for name in ('settings.ini','settings_mats.ini'):
    assert digest(ROOT/name)==digest(BASE/name),name
    settings[name]={'source_unchanged':True,'installed_sha256':digest(GAME/name),
      'installed_changed_since_baseline':digest(GAME/name)!=digest(BASE/'installed'/name)}
report={'step':'s67','date':'2026-10-12','files':records,'settings':settings,
 'source_tuning_edits_retained':changes,'other_existing_scalar_defaults_unchanged':True,
 'installed_added_module':'rain_trails.lua',
 'verification':{'rain_variants':28,'optics_variants':13,'warnings':0,
  'runtime':'runtime_checks.json','lens':'lens_checks.json','trail':'trail_gpu_checks.json',
  '4096_actual_bakes':'4096_candidate_checks.json'},'actual_game_fps_verified':False,
 'reload_required':True}
(OUT/'delivery.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
print('PASS: all 11 installed runtime files match source; latest source tuning retained; source settings untouched')
