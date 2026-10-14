"""Delivery diff, preserved tuning, and read-only verification of installed sources."""
from pathlib import Path
import re,json,hashlib,difflib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s80'
baseline=OUT/'baseline'
old=(baseline/'realvisor.lua').read_text(encoding='utf-8-sig')
new=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
pattern=r'^\s*(RAIN_\w+)\s*=\s*(true|false|[-+\d.eE]+)\s*,'
assert re.findall(pattern,old,re.M)==re.findall(pattern,new,re.M),'User tuning changed'
diff=[]
for file in sorted(baseline.rglob('*')):
    if not file.is_file():continue
    name=file.relative_to(baseline).as_posix();current=ROOT/name
    assert current.exists(),name
    diff.extend(difflib.unified_diff(file.read_text(encoding='utf-8-sig').splitlines(True),
        current.read_text(encoding='utf-8-sig').splitlines(True),fromfile='s79/'+name,tofile='s80/'+name))
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
GAME=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')
paths=['realvisor.lua','rain_birth_gpu.lua','rain_birth_model.lua','rain_environment.lua','rain_physics_units.lua',
       'shaders/rainStateEntry.hlsl','shaders/rainMetaEntry.hlsl','shaders/rainBirthEvent.hlsl',
       'shaders/rainBirthBlocks.hlsl','shaders/rainBirthTotals.hlsl','shaders/rainBirthStats.hlsl']
hashes={}
for name in paths:
    local=hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
    installed=hashlib.sha256((GAME/name).read_bytes()).hexdigest()
    assert local==installed,name
    hashes[name]=dict(sha256=local,installedMatch=True)
(OUT/'installed_sources.json').write_text(json.dumps(dict(preservedRuntimeTuning=True,sources=hashes),indent=2))
print('s80: tuning preserved; installed source hashes match; delivery diff saved')
