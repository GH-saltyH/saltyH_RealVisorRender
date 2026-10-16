"""S86 tuning/source/assets/tests/install audit. Never commits or pushes."""
from pathlib import Path
import difflib,hashlib,json,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s86';BASE=OUT/'baseline'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=(BASE/'realvisor.lua').read_text(encoding='utf-8-sig');new=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
pattern=r'^\s*(RAIN_\w+)\s*=\s*(true|false|[-+\d.eE]+)\s*,'
oldCfg=dict(re.findall(pattern,old,re.M));newCfg=dict(re.findall(pattern,new,re.M))
assert newCfg.pop('RAIN_PHYSICS_P4_POOL_PREVIEW')=='false';assert oldCfg==newCfg
expected={'realvisor.lua','rain_birth_gpu.lua','rain_film.lua','shaders/rainBirthEvent.hlsl',
    'shaders/rainBirthBlocks.hlsl','shaders/rainFilmDescriptor.hlsl','shaders/rainFilmFlow.hlsl',
    'shaders/rainFilmResolve.hlsl','shaders/rainFilmOptics.hlsl','shaders/rainFilmTotals.hlsl','shaders/rainVisorDynamicDrop.hlsl'}
baseline=json.loads((OUT/'baseline_hashes.json').read_text());changed=[];runtimeUnchanged={}
for name,data in baseline.items():
    same=sha(ROOT/name)==data['sha256']
    if not same:changed.append(name)
    if name.endswith(('.hlsl','.lua')) and name not in expected:runtimeUnchanged[name]=same;assert same,name
assert set(name for name in changed if name.endswith(('.lua','.hlsl')))==expected
for name in ('settings.ini','settings_mats.ini'):
    assert not subprocess.run(['git','diff','--',name],capture_output=True,text=True,check=True).stdout
assetManifest=json.loads((ROOT/'texture/RAIN_FILM/assets.json').read_text())
assert all(sha(ROOT/name)==value for name,value in assetManifest['sha256'].items())
reports=['pool_gpu_checks.json','pool_binding_checks.json','realmesh_checks.json','birth_off_checks.json',
         'lens_checks.json','s81_gpu_regression.json','s83_gpu_regression.json']
data={name:json.loads((OUT/name).read_text()) for name in reports}
assert len(data['pool_gpu_checks.json']['checks'])==8
assert data['pool_binding_checks.json']['resetLiveBanks']==0
assert data['lens_checks.json']['poolDebugDoesNotAffectOptics']
assert data['realmesh_checks.json']['acceptedHeads']==2
assert len(data['birth_off_checks.json']['cases'])==8
assert len(data['s81_gpu_regression.json']['checks'])==13 and len(data['s83_gpu_regression.json']['checks'])==9
newRuntime=['shaders/rainFilmPoolAddress.hlsl','shaders/rainFilmPoolAvailable.hlsl','shaders/rainFilmPoolCandidate.hlsl']
newDocs=['docs/RAINFX_S86_P4B_POOL_RETURN.md','docs/tools/rain_shader_source.py',
    *[p.relative_to(ROOT).as_posix() for p in (ROOT/'docs/tools').glob('*s86*.py')]]
changedTools=['docs/tools/check_s79_birth_gpu.py','docs/tools/check_s81_film_gpu.py']
diff=[]
for name in sorted(set(changed+newRuntime+newDocs+changedTools)):
    p=ROOT/name;before=BASE/name
    if name in changedTools:before=OUT/'before_test_headers'/p.name
    oldText=before.read_text(encoding='utf-8-sig') if before.exists() else ''
    diff.extend(difflib.unified_diff(oldText.splitlines(True),p.read_text(encoding='utf-8-sig').splitlines(True),
        fromfile='a23527e/'+name if oldText else '/dev/null',tofile='s86/'+name))
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
game=Path('D:/Games/Assetto Corsa/apps/lua/realvisor');sources={}
for name in sorted(expected|set(newRuntime)):
    match=(game/name).exists() and sha(game/name)==sha(ROOT/name)
    if '--installed' in sys.argv:assert match,name
    sources[name]=dict(sha256=sha(ROOT/name),installedMatch=match)
branch=subprocess.run(['git','branch','--show-current'],capture_output=True,text=True,check=True).stdout.strip()
head=subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip()
assert head.startswith('a23527e') and branch=='codex/rainfx-physics-weather'
record=dict(step='s86',date='2026-10-15',branch=branch,base=head,preservedExistingTuning=True,
    newDefaultOffFlag='RAIN_PHYSICS_P4_POOL_PREVIEW',physicalGeometryAssetsUnchanged=True,
    unchangedOtherRuntime=runtimeUnchanged,sourceFiles=sources,changedDocuments=[n for n in changed if n.endswith('.md')],
    newDocument='docs/RAINFX_S86_P4B_POOL_RETURN.md',reports=reports,
    extraSteadyPasses=1,extraPayloadBytesAt4096=81920,steadyReadbacksAdded=0,drawPassesAdded=0,
    actualGameCost='unmeasured',gameGate='pending: classification, source/field ledger, limiter change, look and cost',
    open='Broad film pressure/inertia transport, field momentum closure and long float32 accuracy',
    committedOrPushed=False)
(OUT/'delivery.json').write_text(json.dumps(record,indent=2))
print('s86 audit: existing tuning/geometry and',len(runtimeUnchanged),'other runtime files preserved.')
print('GPU/Lua/full-shader/regression reports verified. Installed',sum(x['installedMatch'] for x in sources.values()),'/',len(sources))
