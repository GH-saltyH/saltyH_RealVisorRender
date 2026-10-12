"""Record final s65 delivery, dependencies and changes against its snapshot."""
from pathlib import Path
import hashlib,json,difflib,re,subprocess
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s65'
paths=['realvisor.lua','rain_surface.lua','shaders/rainVisorDynamicDrop.hlsl',
 'native_glass_state.lua','native_glass_occlusion.lua','visor_optics.lua','material_settings.lua',
 'settings.ini','settings_mats.ini']
manifest={}
for name in paths:
    p=ROOT/name;assert p.is_file(),name
    manifest[name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'mtime_ns':p.stat().st_mtime_ns}
    if (OUT/'baseline'/name).exists():
        old=(OUT/'baseline'/name).read_text(encoding='utf-8');new=p.read_text(encoding='utf-8')
        diff=''.join(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='s64/'+name,tofile='s65/'+name))
        if diff:(OUT/(Path(name).name+'.diff')).write_text(diff,encoding='utf-8')
for name in ['rain_surface.lua','visor_optics.lua','material_settings.lua','native_glass_state.lua','native_glass_occlusion.lua']:
    assert (ROOT/name).stat().st_size>0
baseline=(OUT/'baseline/realvisor.lua').read_text(encoding='utf-8')
current=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
def settings(s):
    return {k:v for k,v in re.findall(r'^\s+(RAIN_\w+)\s*=\s*([-+\d.]+|true|false)\s*[,\n]',s,re.M)}
before,after=settings(baseline),settings(current)
changed={k:(v,after.get(k)) for k,v in before.items() if v!=after.get(k)}
assert changed=={'RAIN_GPU_HEADS_SPARSE_WORDS':('false','true')},changed
fxc='C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe'
assembly={}
for n in ('rainVisorDynamicDrop','rainDepthCoverage'):
    p=subprocess.run([fxc,'/nologo','/dumpbin',str(OUT/'shaders'/(n+'.cso'))],capture_output=True,text=True)
    assert p.returncode==0
    assembly[n]={'bytes':(OUT/'shaders'/(n+'.cso')).stat().st_size,
        'snapshot_texture_retained':'txDynamicSnapshot' in p.stdout}
assert assembly['rainVisorDynamicDrop']['snapshot_texture_retained']
assert not assembly['rainDepthCoverage']['snapshot_texture_retained']
(OUT/'delivery.json').write_text(json.dumps({'files':manifest,'numeric_tuning_unchanged':True,
 'runtime_default_change':changed,'required_lua_modules':paths[1:7],
 'compiled_programs':assembly,'game_fps_measured':False},indent=2),encoding='utf-8')
print(json.dumps({'numeric_tuning_unchanged':True,'compiled_programs':assembly,'required_modules_present':True}))
