"""Read-only install audit and exact s66 source/settings delivery manifest."""
from pathlib import Path
import hashlib,json,difflib,re,subprocess
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s66'
GAME=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
required=['realvisor.lua','rain_surface.lua','native_glass_state.lua','native_glass_occlusion.lua','visor_optics.lua','material_settings.lua']
required += ['shaders/'+p.name for p in (ROOT/'shaders').glob('*.hlsl')]
report={}
for name in required:
    p=GAME/name;src=ROOT/name
    report[name]={'installed':p.exists(),'source_sha256':sha(src),
        'installed_sha256':sha(p) if p.exists() else None,
        'linked_source':p.resolve()==src.resolve()}
missing=[k for k,v in report.items() if not v['installed']]
different=[k for k,v in report.items() if v['installed'] and v['installed_sha256']!=v['source_sha256']]
assert different==[],different
for n in ('settings.ini','settings_mats.ini'):
    # Workspace settings must remain exactly at the turn-start baseline.
    assert sha(ROOT/n)==sha(OUT/'baseline'/n)
model=ROOT/'visors/visor_lando_2025Champion_maxquality_diet_face.kn5'
assert model.open('rb').read(6)==b'sc6969'
assert sha(model)=='2596f63e20a02bc0608bfc11270f892d500f45b499a1b2331045b361d83031b9'
assert (GAME/'texture').resolve()==(ROOT/'texture').resolve()
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
requiredAssets=set(re.findall(r"appFolder\s*\.\.\s*'/(texture/[^']+)'",source))
assert all((GAME/p).exists() for p in requiredAssets),[p for p in requiredAssets if not (GAME/p).exists()]
changes={}
for name in ('realvisor.lua','visor_optics.lua','native_glass_occlusion.lua','shaders/rainVisorDynamicDrop.hlsl'):
    changes[name]={'sha256':sha(ROOT/name),'mtime_ns':(ROOT/name).stat().st_mtime_ns}
    a=(OUT/'baseline'/name).read_text(encoding='utf-8').splitlines(True)
    b=(ROOT/name).read_text(encoding='utf-8').splitlines(True)
    path=OUT/(name.replace('/','_')+'.diff')
    path.write_text(''.join(difflib.unified_diff(a,b,fromfile='s66 baseline/'+name,tofile=name)),encoding='utf-8')
report={'files':report,'changes':changes,'missing':missing,'different':different,
    'installed_settings':{n:sha(GAME/n) for n in ('settings.ini','settings_mats.ini')},
    'model_sha256':sha(model),'model_resolved':str(model.resolve()),'texture_link':str((GAME/'texture').resolve())}
fxc='C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe'
for key,path in [('before',OUT/'gpuHeadsPassB.cso'),('after',OUT/'shaders/gpuHeadsPassB.cso')]:
    r=subprocess.run([fxc,'/nologo','/dumpbin',str(path)],capture_output=True,text=True,check=True)
    report['kernel_'+key]={'instruction_slots':int(re.search(r'Approximately (\d+) instruction slots',r.stdout).group(1)),'bytecode_bytes':path.stat().st_size}
(OUT/'delivery.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('Missing runtime modules:',missing,'other file mismatches:',different)
print('Authored KN5, linked textures and literal runtime asset paths verified; workspace settings unchanged')
print('kernel:',report['kernel_before'],report['kernel_after'])
