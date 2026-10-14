from pathlib import Path
import hashlib,json,re,difflib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s69';BASE=OUT/'baseline'
GAME=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig');old=(BASE/'realvisor.lua').read_text(encoding='utf-8-sig')
def defaults(text):
    d={}
    for k,v in re.findall(r'\b(RAIN_\w+)\s*=\s*(true|false|-?\d+(?:\.\d+)?)\s*,',text):d.setdefault(k,v)
    return d
assert defaults(source)==defaults(old),'An existing runtime scalar tuning value changed'
a=old.index('local function updateMotion(dt)');b=old.index('rainDynamicSceneCopyState.visorClearMotion',a)
c=source.index('local function updateMotion(dt)');d=source.index('rainDynamicSceneCopyState.visorClearMotion',c)
assert source[c:d]==old[a:b],'G-force physics changed'
assert digest(GAME/'realvisor.lua')==digest(ROOT/'realvisor.lua')
unchanged=['settings.ini','settings_mats.ini','rain_trails.lua','rain_surface.lua','native_glass_occlusion.lua',
    'native_glass_state.lua','visor_optics.lua','material_settings.lua']
unchanged += [p.relative_to(ROOT).as_posix() for p in (ROOT/'shaders').glob('*.hlsl')]
for name in unchanged:assert digest(ROOT/name)==digest(BASE/name),name
names=['realvisor.lua','docs/README.md','docs/RAINFX_ROADMAP.md','docs/RAINFX_S69_MOTION_AND_MEMORY.md']
records={};diff=[]
for name in names:
    p=ROOT/name;records[name]={'sha256':digest(p),'mtime_ns':p.stat().st_mtime_ns}
    before=(BASE/name).read_text(encoding='utf-8-sig') if (BASE/name).exists() else ''
    diff.extend(difflib.unified_diff(before.splitlines(True),p.read_text(encoding='utf-8-sig').splitlines(True),
        fromfile='s68/'+name,tofile='s69/'+name))
report={'step':'s69','files':records,'installed_realvisor_matches':True,'scalar_tuning_preserved':True,
    'gforce_motion_function_unchanged':True,'unchanged_files':unchanged,
    'checks':['splash_memory_checks.json','merge_benchmark.json','motion_checks.json'],
    'actual_game_visibility_memory_fps_verified':False,'reload_required':True}
(OUT/'delivery.json').write_text(json.dumps(report,indent=2));(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
print('PASS: linked game source verified; current tuning/G-force/GPU programs/settings preserved')
