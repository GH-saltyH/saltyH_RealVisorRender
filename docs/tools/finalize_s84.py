"""Audit manual-only s84 change and installed delivery; no game writes/commits."""
from pathlib import Path
import json,re,hashlib,difflib,sys
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s84';BASE=OUT/'baseline'
old=(BASE/'realvisor.lua').read_text(encoding='utf-8-sig');new=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
pattern=r'^\s*(RAIN_\w+)\s*=\s*(true|false|[-+\d.eE]+)\s*,'
assert dict(re.findall(pattern,old,re.M))==dict(re.findall(pattern,new,re.M))
expected=old.replace("if ui.button('Log P3 actual water budget') then st.physicalFilmGPU:logBudget() end",
    "if ui.button('Log P3 actual water budget') then st.physicalFilmGPU:logSnapshot() end")
expected=expected.replace('    local p,u=st.physicsInputs,st.physicsUnits    \n','    local p,u=st.physicsInputs,st.physicsUnits\n')
assert expected==new
filmOld=(BASE/'rain_film.lua').read_text();filmNew=(ROOT/'rain_film.lua').read_text()
for begin,end in [('    function st:prepare(','    function st:step('),('    function st:budget(','    function st:logBudget(')]:
    assert filmOld[filmOld.index(begin):filmOld.index(end)]==filmNew[filmNew.index(begin):filmNew.index(end)]
unchanged={}
for p in (BASE/'shaders').glob('*.hlsl'):
    name=p.relative_to(BASE).as_posix()
    if p.stem in ('rainFilmFlowBlocks','rainFilmFlowStats'):continue
    unchanged[name]=p.read_bytes()==(ROOT/name).read_bytes();assert unchanged[name],name
reports=['game_checks.json','diagnostic_gpu_checks.json','binding_checks.json','flow_binding_checks.json','paired_snapshot_checks.json','media.json']
assert all((OUT/p).exists() for p in reports)
paths=['realvisor.lua','rain_film.lua','shaders/rainFilmFlowBlocks.hlsl','shaders/rainFilmFlowStats.hlsl']
game=Path('D:/Games/Assetto Corsa/apps/lua/realvisor');hashes={}
for name in paths:
    sha=hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
    match=(game/name).exists() and hashlib.sha256((game/name).read_bytes()).hexdigest()==sha
    if '--installed' in sys.argv:assert match,name
    hashes[name]=dict(sha256=sha,installedMatch=match)
diff=[]
for p in sorted(BASE.rglob('*')):
    if not p.is_file():continue
    name=p.relative_to(BASE).as_posix();current=ROOT/name
    diff.extend(difflib.unified_diff(p.read_text(encoding='utf-8-sig').splitlines(True),
        current.read_text(encoding='utf-8-sig').splitlines(True),fromfile='s83/'+name,tofile='s84/'+name))
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
report=dict(date='2026-10-15',step='s84',preservedAllTuning=True,physicalPrepareBudgetPublishUnchanged=True,
    unchangedPhysicalAndRenderShaders=unchanged,sources=hashes,steadyAddedPasses=0,steadyAddedBytes=0,
    manualPayloadBytes=76736,manualAddedBytes=57552,reports=reports,
    gameResult={'waterBudget':'supplied intervals pass','performance':'user observes comparable P3/P4 FPS',
                'transportTimeAccuracy':'fails high Courant gate; root-case peak thickness/metric decomposition pending'},
    requestedNext='Two individual same-frame snapshots, stationary and 137kmh, using Log P3 actual water budget')
(OUT/'delivery.json').write_text(json.dumps(report,indent=2))
print('s84 audit: tuning and all steady shaders/prepare/publication unchanged; manual-only diagnostics')
print('Installed matches:',sum(v['installedMatch'] for v in hashes.values()),'/',len(hashes))
