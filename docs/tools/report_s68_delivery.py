from pathlib import Path
import hashlib,json,difflib,re
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s68';BASE=OUT/'baseline'
GAME=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
names=['realvisor.lua','native_glass_state.lua','shaders/rainVisorLayer.hlsl']
records={};diff=[]
for name in names+['docs/README.md','docs/RAINFX_ROADMAP.md','docs/RAINFX_S68_VIEW_AND_CONVEX_TINT.md']:
    p=ROOT/name;records[name]={'source_sha256':digest(p),'mtime_ns':p.stat().st_mtime_ns}
    if name in names:
        installed=GAME/name;assert digest(installed)==digest(p),name
        records[name].update(installed_sha256=digest(installed),installed_matches=True)
    old=(BASE/name).read_text(encoding='utf-8-sig') if (BASE/name).exists() else ''
    diff.extend(difflib.unified_diff(old.splitlines(True),p.read_text(encoding='utf-8-sig').splitlines(True),
        fromfile='s67/'+name,tofile='s68/'+name))
def defaults(p):
    d={}
    for k,v in re.findall(r'\b(RAIN_\w+)\s*=\s*(true|false|-?\d+(?:\.\d+)?)\s*,',p.read_text(encoding='utf-8-sig')):d.setdefault(k,v)
    return d
before=defaults(BASE/'realvisor.lua');after=defaults(ROOT/'realvisor.lua')
assert all(after[k]==v for k,v in before.items()),'An existing scalar tuning value changed'
unchanged=['settings.ini','settings_mats.ini','rain_trails.lua','native_glass_occlusion.lua','visor_optics.lua',
    'shaders/rainSurfaceMetric.hlsl','shaders/rainTrailDescriptor.hlsl','shaders/rainTrailResolve.hlsl',
    'shaders/rainVisorDynamicDrop.hlsl']
for name in unchanged:assert digest(ROOT/name)==digest(BASE/name),name
report={'step':'s68','files':records,'existing_scalar_tuning_preserved':True,'unchanged_files':unchanged,
    'installed_settings_current':{n:digest(GAME/n) for n in ('settings.ini','settings_mats.ini')},
    'runtime_checks':'runtime_checks.json','tint_checks':'tint_gpu_checks.json',
    'actual_automatic_driving_trigger_confirmed':False,'actual_game_recovery_verified':False,'reload_required':True}
(OUT/'delivery.json').write_text(json.dumps(report,indent=2))
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
print('PASS: all three installed changed runtime files match source; existing tuning/settings/trail programs preserved')
