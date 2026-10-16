"""Audit offline-only s88. Fail if any production runtime or staged tuning changed."""
from pathlib import Path
import difflib,hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-16/s88'
BASE=OUT/'baseline'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((OUT/'baseline_hashes.json').read_text())
changed=[];runtime={}
for name,entry in manifest.items():
    same=sha(ROOT/name)==entry['sha256']
    if name.endswith(('.lua','.hlsl')):
        runtime[name]=same;assert same,('Runtime changed',name)
    elif not same:changed.append(name)
assert set(changed)=={'docs/README.md','docs/RAINFX_ROADMAP.md'}
for folder in ('RAIN_GEOMETRY','RAIN_BIRTH','RAIN_FILM'):
    asset=ROOT/'texture'/folder/'assets.json'
    if asset.exists():
        entries=json.loads(asset.read_text())['sha256']
        for name,entry in entries.items():assert sha(ROOT/name)==entry,(name,'asset hash')
inertia=json.loads((OUT/'inertia_checks.json').read_text())
long=json.loads((OUT/'long_transport_checks.json').read_text())
assert not inertia['runtimeIntegrated'] and not inertia['transportTimeGatePassed']
assert len(inertia['checks'])==10
assert not long['runtimeIntegrated'] and not long['arbitraryFlowTimeGatePassed']
assert long['arbitraryFaceVelocity']['minimumVolumeMM3']<0
assert long['dynamicRange']['affectedThinCells']>0
files=[ROOT/'docs/RAINFX_S88_FILM_TRANSPORT_CANDIDATES.md',
    *sorted((ROOT/'docs/prototypes/s88').glob('*.hlsl')),
    *sorted((ROOT/'docs/tools').glob('*s88*.py'))]
diff=[]
for name in changed:
    diff.extend(difflib.unified_diff((BASE/name).read_text(encoding='utf-8-sig').splitlines(True),
        (ROOT/name).read_text(encoding='utf-8-sig').splitlines(True),fromfile='s87_staged/'+name,tofile='s88/'+name))
for p in files:
    assert p.exists()
    text=p.read_text(encoding='utf-8-sig')
    assert all(not line.endswith((' ','\t')) for line in text.splitlines()),p
    diff.extend(difflib.unified_diff([],text.splitlines(True),fromfile='/dev/null',tofile=p.relative_to(ROOT).as_posix()))
assert not any(line.startswith('+') and not line.startswith('+++') and line.rstrip('\r\n').endswith((' ','\t')) for line in diff)
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
report=dict(step='s88',date='2026-10-16',
    head=subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip(),
    productionRuntimeUnchanged=runtime,preservedAllUserTuningAndMaterials=True,
    changedExistingDocs=changed,artifacts={p.relative_to(ROOT).as_posix():sha(p) for p in files},
    inertiaCandidate='Numerical closure gates pass; warm CFL adoption gate fails. Not installed.',
    longTravelCandidate='Uniform reference passes; arbitrary-flow positivity and thin-stock precision adoption gates fail. Not installed.',
    actualGameExtraPasses=0,actualGameExtraBytes=0,newRuntimeAPIs=0,
    gameReloadRequired=False,requestedRepeatedGameLogs=False,committedOrPushed=False)
(OUT/'delivery.json').write_text(json.dumps(report,indent=2))
print('s88 audit:',len(runtime),'production runtime files unchanged; tuning/materials/assets preserved.')
print('Two offline GPU candidates and their rejection cases recorded. Game remains s87; no reload/install required.')
