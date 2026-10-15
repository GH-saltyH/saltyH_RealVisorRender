"""Preserved P2 stamp tuning and installed s81 source/asset delivery audit."""
from pathlib import Path
import re,json,hashlib,difflib,subprocess
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s81'
old=(OUT/'baseline/realvisor.lua').read_text(encoding='utf-8-sig');new=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
pattern=r'^\s*(RAIN_\w+)\s*=\s*(true|false|[-+\d.eE]+)\s*,'
before=dict(re.findall(pattern,old,re.M));after=dict(re.findall(pattern,new,re.M))
assert all(after[k]==v for k,v in before.items()),'Pre-existing tuning changed'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()=='1ad4a95f48d7b683f38b9134bf6c202eb363780e'
diff=[]
for file in sorted((OUT/'baseline').rglob('*')):
    if not file.is_file():continue
    name=file.relative_to(OUT/'baseline').as_posix();current=ROOT/name
    assert current.exists(),name
    diff.extend(difflib.unified_diff(file.read_text(encoding='utf-8-sig').splitlines(True),
        current.read_text(encoding='utf-8-sig').splitlines(True),fromfile='1ad4a95/'+name,tofile='s81/'+name))
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
game=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')
paths=['realvisor.lua','rain_birth_gpu.lua','rain_film.lua','rain_birth_model.lua','rain_surface.lua','rain_physics_units.lua','rain_environment.lua']
paths += [p.relative_to(ROOT).as_posix() for p in (ROOT/'shaders').glob('rainFilm*.hlsl')]
paths += [f'shaders/{n}.hlsl' for n in ('rainBirthEvent','rainBirthBlocks','rainBirthTotals','rainBirthStats','rainVisorDynamicDrop')]
paths += [p.relative_to(ROOT).as_posix() for p in (ROOT/'texture/RAIN_FILM').iterdir() if p.is_file()]
hashes={}
for name in paths:
    actual=hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
    installed=hashlib.sha256((game/name).read_bytes()).hexdigest()
    assert actual==installed,name
    hashes[name]=dict(sha256=actual,installedMatch=True)
names=['gpu_checks.json','lens_checks.json','binding_checks.json','legacy/s79_gpu_regression/gpu_checks.json','legacy/s79_binding_regression/binding_checks.json']
assert all((OUT/n).is_file() for n in names)
sizes=dict(count=4096,descriptorBytes=4096*5*16,metaScratchBytes=4096*16,
    fieldBytes=2*1056*288*16,opticsBytes=2*1024*256*8,staticCellBytes=1024*256*16,
    sparseBytes=33*9*(43+1)*16,manualDiagnosticBytes=66*18*16+5*2*16+64+64)
sizes['steadyBytes']=sum(sizes[k] for k in ('descriptorBytes','metaScratchBytes','fieldBytes','opticsBytes','staticCellBytes','sparseBytes'))
(OUT/'delivery.json').write_text(json.dumps(dict(baseCommit='1ad4a95f48d7b683f38b9134bf6c202eb363780e',
    preservedExistingTuning=True,newRuntimeKeys=sorted(set(after)-set(before)),sources=hashes,storage=sizes,
    steadyAdditionalPasses=6,fieldBudgetOnlyOnManualRequest=True,gameVerification='pending',reports=names),indent=2))
print('s81 delivery: P2 tuning/HEAD preserved; all installed source/asset hashes match; GPU/Lua reports saved')
