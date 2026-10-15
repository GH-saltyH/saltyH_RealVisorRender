"""s83 tuning/source/installation audit. Does not commit or modify the game."""
from pathlib import Path
import json,re,hashlib,difflib,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s83'
old=(OUT/'baseline/realvisor.lua').read_text(encoding='utf-8-sig')
new=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
pattern=r'^\s*(RAIN_\w+)\s*=\s*(true|false|[-+\d.eE]+)\s*,'
before=dict(re.findall(pattern,old,re.M));after=dict(re.findall(pattern,new,re.M))
assert all(after[k]==v for k,v in before.items()),'Existing tuning changed'
assert sorted(set(after)-set(before))==['RAIN_FILM_FLOW_CF','RAIN_PHYSICS_P4_TRANSPORT_PREVIEW']
assert after['RAIN_PHYSICS_P4_TRANSPORT_PREVIEW']=='false'
previous=json.loads((ROOT/'docs/diagnostics/2026-10-15/s81/delivery.json').read_text())
assert hashlib.sha256((ROOT/'texture/RAIN_FILM/cells.dds').read_bytes()).hexdigest()==previous['sources']['texture/RAIN_FILM/cells.dds']['sha256']
assets=json.loads((ROOT/'texture/RAIN_FILM/assets.json').read_text())
assert assets['flowConnectedUV'] and assets['flowDiscontinuousEdges']==0 and assets['flowDegenerateCells']==0
reports=['gpu_checks.json','binding_checks.json','flow_binding_checks.json','p3_regression/gpu_checks.json']
assert all((OUT/p).exists() for p in reports)
game=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')
names=['realvisor.lua','rain_film.lua','rain_birth_gpu.lua','texture/RAIN_FILM/geometry.lua','texture/RAIN_FILM/assets.json','texture/RAIN_FILM/cells.dds']
names += [p.relative_to(ROOT).as_posix() for p in (ROOT/'shaders').glob('rainFilm*.hlsl')]
hashes={}
for name in names:
    path=ROOT/name;sha=hashlib.sha256(path.read_bytes()).hexdigest()
    target=game/name;installed=target.exists() and hashlib.sha256(target.read_bytes()).hexdigest()==sha
    if '--installed' in sys.argv:assert installed,name
    hashes[name]=dict(sha256=sha,installedMatch=installed)
diff=[];base=OUT/'baseline'
for path in sorted(base.rglob('*')):
    if not path.is_file():continue
    name=path.relative_to(base).as_posix();current=ROOT/name
    if path.suffix.lower() not in ('.lua','.hlsl','.md','.py','.json'):continue
    diff.extend(difflib.unified_diff(path.read_text(encoding='utf-8-sig').splitlines(True),
        current.read_text(encoding='utf-8-sig').splitlines(True),fromfile='s82/'+name,tofile='s83/'+name))
for path in sorted((ROOT/'shaders').glob('rainFilmFlow*.hlsl')):
    name=path.relative_to(ROOT).as_posix()
    assert not (base/name).exists()
    diff.extend(difflib.unified_diff([],path.read_text().splitlines(True),fromfile='/dev/null',tofile='s83/'+name))
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
report=dict(date='2026-10-15',step='s83',branch=subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(),
    baseCommit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    preservedExistingTuning=True,newKeys=sorted(set(after)-set(before)),cellDDSUnchanged=True,
    flowConnectedUV=assets['flowConnectedUV'],sources=hashes,steadyAddedBytes=1024*256*16,
    steadyAddedPasses=1,manualLimiterBytes=66*18*16+5*2*16+4*4,
    reports=reports,gameGate='pending: same elapsed-time P3/P4 cost, water budget and Courant/quality',
    remaining=['persistent field float32 long accumulation','high-CFL time accuracy','paired head absorption','pressure/contact line solver'])
(OUT/'delivery.json').write_text(json.dumps(report,indent=2))
print('s83 audit:',report['branch'],'existing tuning/cell DDS preserved; added storage4MiB, one pass')
print('Installed matches:',sum(v['installedMatch'] for v in hashes.values()),'/',len(hashes))
