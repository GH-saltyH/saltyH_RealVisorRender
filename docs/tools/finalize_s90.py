"""Audit offline s90 delivery: zero production runtime/tuning/geometry mutation."""
from pathlib import Path
import json,hashlib,difflib,subprocess,ast
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-16/s90';BASE=OUT/'baseline'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((OUT/'baseline_hashes.json').read_text());runtime={};changed=[]
for name,entry in manifest.items():
    same=sha(ROOT/name)==entry['sha256']
    if name.endswith(('.lua','.hlsl')):assert same,name;runtime[name]=same
    if not same:changed.append(name)
assert set(changed)=={'docs/README.md','docs/RAINFX_ROADMAP.md'}
for folder in ('RAIN_GEOMETRY','RAIN_BIRTH','RAIN_FILM'):
    asset=ROOT/'texture'/folder/'assets.json'
    if asset.exists():
        for name,value in json.loads(asset.read_text())['sha256'].items():assert sha(ROOT/name)==value,name
reports={n:json.loads((OUT/n).read_text()) for n in ['characteristic_checks.json','force_geometry_checks.json','admission_front_checks.json']}
char=reports['characteristic_checks.json'];real=reports['force_geometry_checks.json'];gate=reports['admission_front_checks.json']
assert char['characteristicGatePassed'] and char['prescribedDensityGatePassed'] and char['limitedLinearReconstruction']
profiles=char['checks'][-1]['results'];assert len(profiles)==6
assert max(x['relativeProfileL1'] for x in profiles)<.003
assert max(abs(x['ledgerError']) for x in profiles)<1e-4
assert real['predictorAndRemapBridgePassed'] and abs(real['volumeResidualMM3'])<1e-5
assert max(map(abs,real['momentumResidualWithBoundaryAndWall']))<1e-6
assert real['displayCoefficientsIndependent']
assert gate['GPUAxisAdmissionPassed'] and not gate['dryFront']['freeBoundaryGatePassed']
assert all(x['oldPacketBitIdentical'] and x['lossZero'] and x['recipientVisitsZero'] for x in gate['rejectedCases'])
assert not any(r['runtimeIntegrated'] for r in reports.values())
files=[ROOT/'docs/RAINFX_S90_CHARACTERISTICS_AND_CURVED_TRANSPORT.md',
    *sorted((ROOT/'docs/prototypes/s90').glob('*.hlsl')),
    *sorted((ROOT/'docs/tools').glob('*s90*.py'))]
for p in files:
    if p.suffix=='.py':ast.parse(p.read_text(encoding='utf-8-sig'),str(p))
diff=[]
for name in sorted(changed):
    diff.extend(difflib.unified_diff((BASE/name).read_text(encoding='utf-8-sig').splitlines(True),
        (ROOT/name).read_text(encoding='utf-8-sig').splitlines(True),fromfile='staged_s89/'+name,tofile='s90/'+name))
for p in files:
    diff.extend(difflib.unified_diff([],p.read_text(encoding='utf-8-sig').splitlines(True),fromfile='/dev/null',tofile=p.relative_to(ROOT).as_posix()))
assert not any(s.startswith('+') and not s.startswith('+++') and s.rstrip('\r\n').endswith((' ','\t')) for s in diff)
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
report=dict(step='s90',date='2026-10-16',head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
    preservedRuntimeFiles=runtime,preservedTuningAndUserMaterials=True,geometryAssetsUnchanged=True,
    changedExistingDocs=changed,newFiles={p.relative_to(ROOT).as_posix():sha(p) for p in files},
    reports=list(reports),newRuntimeAPIs=0,actualGameExtraPasses=0,actualGameExtraBytes=0,
    implemented='Frozen velocity characteristic generation, limited linear source reconstruction, component runoff, GPU axis admission, SI real-mesh packet/momentum bridge',
    acceptedGates=['Frozen-field paths','Prescribed equal-time density profiles','Real-mesh synthetic water/momentum+wall','GPU axis arithmetic admission'],
    openGates=['Physical dry-front velocity extension/contact-line closure','Coupled variable-height/velocity evolution','Complete app source/head/clock atomic publication','Fused pass/storage layout and actual game ms'],
    dryFrontGatePassed=False,gameTimingMeasured=False,gameReloadRequired=False,requestedRepeatedGameLogs=False,committedOrPushed=False)
(OUT/'delivery.json').write_text(json.dumps(report,indent=2))
print('s90:',len(runtime),'production runtime files unchanged; tuning/materials/assets preserved.')
print('Frozen paths, limited reconstruction, curved mesh and GPU axis admission verified. Dry-front gate remains open; no game install.')
