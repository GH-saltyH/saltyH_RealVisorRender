"""Audit s85 review/prototype delivery. No game writes, git staging or commits."""
from pathlib import Path
import difflib,hashlib,json,re,subprocess

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/diagnostics/2026-10-15/s85';BASE=OUT/'baseline'
baseline=json.loads((OUT/'baseline_hashes.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
runtime={name:sha(ROOT/name)==value['sha256'] for name,value in baseline.items()
         if name.endswith(('.lua','.hlsl'))}
assert all(runtime.values()),[k for k,v in runtime.items() if not v]
cfg=r'^\s*(RAIN_\w+)\s*=\s*(true|false|[-+\d.eE]+)\s*,'
assert dict(re.findall(cfg,(BASE/'realvisor.lua').read_text(encoding='utf-8-sig'),re.M))==dict(
    re.findall(cfg,(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig'),re.M))
assets=json.loads((ROOT/'texture/RAIN_FILM/assets.json').read_text())
assert all(sha(ROOT/name)==value for name,value in assets['sha256'].items())
review=json.loads((OUT/'regime_review.json').read_text())
checks=json.loads((OUT/'pool_prototype_checks.json').read_text())
assert len(review['evidence'])==2 and len(checks['checks'])==6 and not checks['installedInGame']
assert all(row['budget']['frame']==row['flow']['frame'] for row in review['evidence'])
newNames=['docs/RAINFX_S85_P4_REGIME_AND_POOL_TRANSFER.md','docs/prototypes/s85_pool_transfer.hlsl',
          'docs/tools/review_s85_p4_regime.py','docs/tools/check_s85_pool_prototype.py','docs/tools/finalize_s85.py']
changed=[name for name,data in baseline.items() if sha(ROOT/name)!=data['sha256']]
assert set(changed)=={'docs/README.md','docs/RAINFX_ROADMAP.md','docs/RAINFX_S84_P4_GAME_REVIEW.md'}
diff=[]
for name in sorted(changed+newNames):
    p=ROOT/name;old=(BASE/name).read_text(encoding='utf-8-sig') if (BASE/name).exists() else ''
    diff.extend(difflib.unified_diff(old.splitlines(True),p.read_text(encoding='utf-8-sig').splitlines(True),
        fromfile='s84/'+name if old else '/dev/null',tofile='s85/'+name))
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
branch=subprocess.run(['git','branch','--show-current'],capture_output=True,text=True,check=True).stdout.strip()
head=subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip()
report=dict(date='2026-10-15',step='s85',branch=branch,head=head,
    runtimeUnchanged=runtime,preservedAllTuning=True,physicalGeometryAssetsUnchanged=True,
    installedNewGameBuild=False,committedOrPushed=False,steadyGameAddedBytes=0,steadyGameAddedPasses=0,
    changedDocuments=changed,newFiles={name:sha(ROOT/name) for name in newNames},
    reports=['regime_review.json','pool_prototype_checks.json'],
    result='Paired diagnostics explain severe quasi-steady mobility outside its regime; offline conserved localized pool-to-head feasibility passes, production integration pending.',
    integrationEstimate=dict(extraPayloadBytesAt4096=80*1024,candidatePasses=1,
        acceptance='Fold into existing P2 event, fifth row; extra flux/gather texture reads and event work.',gameMilliseconds='not measured'),
    next='Implement preserved rain position/internal return counter/paired field+flux debit/atomic publish; retain time-accuracy gate and assess remaining continuous-film mobility.')
(OUT/'delivery.json').write_text(json.dumps(report,indent=2))
print('s85:',len(runtime),'runtime files and physical assets unchanged; tuning preserved.')
print('Paired snapshots: 2. Offline /WX WARP gates: 6. No game installation/commit/push.')
