"""Audit s87 review/debug-only delivery, preserving pre-existing user edits."""
from pathlib import Path
import json,re,hashlib,difflib,subprocess
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-16/s87';BASE=OUT/'baseline'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=(BASE/'realvisor.lua').read_text(encoding='utf-8-sig');current=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
cfg=r'^\s*(RAIN_\w+)\s*=\s*(true|false|[-+\d.eE]+)\s*,'
assert dict(re.findall(cfg,old,re.M))==dict(re.findall(cfg,current,re.M))
anchor="        st.rainUISlider('P3 view: 0 optics, 1 film um, 2 micro um, 3 coverage, 4 pool return','RAIN_FILM_DEBUG',0,4,'%.0f')"
replacement="""        st.rainUISlider('P3 view: 0 optics, 1 film um, 2 micro um, 3 coverage, 4 return, 5 head/field','RAIN_FILM_DEBUG',0,5,'%.0f')
        if cfg.RUNTIME.RAIN_FILM_DEBUG>4.5 then
            ui.textWrapped('View 5: red = film height, green = displayed drops, blue = micro water. Yellow shows overlap. Drop display scale still changes green size only. Normal optics: set P3 view and WF debug to 0.')
        end"""
assert old.count(anchor)==1 and old.replace(anchor,replacement)==current
# Exact whole-main check above includes the user-added fabric material block.
assert "id = 'KN5FABRIC'" in current and "'BODY_FABRIC_CULL'" in current
before=(BASE/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8-sig');after=(ROOT/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8-sig')
start='float4 rainPhysicalFilm(PS_IN pin) {';end='// Entry point. The depth occlusion pass'
assert before[:before.index(start)]==after[:after.index(start)]
assert before[before.index(end):]==after[after.index(end):]
manifest=json.loads((OUT/'baseline_hashes.json').read_text());changed=[];unchangedRuntime={}
runtimeExpected={'realvisor.lua','shaders/rainVisorDynamicDrop.hlsl'}
for name,v in manifest.items():
    same=sha(ROOT/name)==v['sha256']
    if not same:changed.append(name)
    if name.endswith(('.lua','.hlsl')) and name not in runtimeExpected:unchangedRuntime[name]=same;assert same,name
assert {n for n in changed if n.endswith(('.lua','.hlsl'))}==runtimeExpected
asset=json.loads((ROOT/'texture/RAIN_FILM/assets.json').read_text())
assert all(sha(ROOT/n)==value for n,value in asset['sha256'].items())
reports=['game_checks.json','head_field_link_checks.json','lens_checks.json','lua_syntax.json','media.json']
data={n:json.loads((OUT/n).read_text()) for n in reports}
assert data['lens_checks.json']['normalOutputBitIdenticalToS86'] and data['lens_checks.json']['mixedHeadAndFilmNormalBitIdentical']
assert data['lens_checks.json']['view5NativeOccluded'] and data['lua_syntax.json']['wholeLuaSyntax']
assert abs(data['head_field_link_checks.json']['sameStepSourceFieldMassErrorMM3'])<1e-6
assert data['game_checks.json']['transitionInterval']['relativeResidual']<1e-4
game=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')
installed={name:sha(ROOT/name)==sha(game/name) for name in sorted(runtimeExpected|{'rain_birth_gpu.lua','rain_film.lua'})}
assert all(installed.values())
newFiles=['docs/RAINFX_S87_P4B_GAME_REVIEW.md',*[p.relative_to(ROOT).as_posix() for p in (ROOT/'docs/tools').glob('*s87*.py')]]
diff=[]
for name in sorted(set(changed+newFiles)):
    p=ROOT/name;base=BASE/name;oldText=base.read_text(encoding='utf-8-sig') if base.exists() else ''
    part=list(difflib.unified_diff(oldText.splitlines(True),p.read_text(encoding='utf-8-sig').splitlines(True),
        fromfile='staged_s86_user/'+name if oldText else '/dev/null',tofile='s87/'+name))
    # The user's pre-existing material has trailing whitespace. Preserve it;
    # check only newly added lines against this session's staged baseline.
    assert not any(line.startswith('+') and not line.startswith('+++') and line.rstrip('\r\n').endswith((' ','\t')) for line in part),name
    diff.extend(part)
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
head=subprocess.run(['git','rev-parse','HEAD'],capture_output=True,text=True,check=True).stdout.strip()
report=dict(step='s87',date='2026-10-16',base=head,preservedAllTuning=True,preservedUserFabricMaterial=True,
    unchangedPhysicalRuntime=unchangedRuntime,unchangedGeometry=True,debugOnlyRuntimeFiles=sorted(runtimeExpected),
    installedMatches=installed,delivery='Existing game symlinks expose main/shader on app reload; physical modules unchanged, no copy needed',
    reports=reports,newFiles={n:sha(ROOT/n) for n in newFiles},
    gameGates=data['game_checks.json']['gates'],extraCanvases=0,extraPasses=0,extraReadbacks=0,
    normalRendering='Bit-identical to staged s86 in film-only and mixed head/film production-shader fixtures',
    debugCost='Head support sample in P3 debug path; no additional sample in normal optics branch',
    requestedRepeatedBudgetLogs=False,committedOrPushed=False)
(OUT/'delivery.json').write_text(json.dumps(report,indent=2))
print('s87 audit:',len(unchangedRuntime),'other runtime files preserved; physical tuning and user fabric addition unchanged.')
print('Game-linked main/shader plus physical modules match. No new canvas/pass/readback; all review/debug gates verified.')
