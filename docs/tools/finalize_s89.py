"""Audit s89 video review, offline overlap prototype and debug-only runtime change."""
from pathlib import Path
import difflib,hashlib,json,re,subprocess
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-16/s89';BASE=OUT/'baseline'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((OUT/'baseline_hashes.json').read_text())
runtimeExpected={'realvisor.lua','shaders/rainVisorDynamicDrop.hlsl'}
changes=[];preserved={}
for name,entry in manifest.items():
    same=sha(ROOT/name)==entry['sha256']
    if not same:changes.append(name)
    if name.endswith(('.lua','.hlsl')) and name not in runtimeExpected:
        assert same,name;preserved[name]=same
assert set(changes)==runtimeExpected|{'docs/README.md','docs/RAINFX_ROADMAP.md'}
old=(BASE/'realvisor.lua').read_text(encoding='utf-8-sig');new=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
cfg=r'^\s*(RAIN_\w+)\s*=\s*(true|false|[-+\d.eE]+)\s*,'
assert dict(re.findall(cfg,old,re.M))==dict(re.findall(cfg,new,re.M))
oldUI="st.rainUISlider('P3 view: 0 optics, 1 film um, 2 micro um, 3 coverage, 4 return, 5 head/field','RAIN_FILM_DEBUG',0,5,'%.0f')"
newUI="st.rainUISlider('P3 view: 0 optics, 1 film um, 2 micro um, 3 coverage, 4 return, 5 mixed, 6 isolated','RAIN_FILM_DEBUG',0,6,'%.0f')"
oldLegend='View 5: red = film height, green = displayed drops, blue = micro water. Yellow shows overlap. Drop display scale still changes green size only. Normal optics: set P3 view and WF debug to 0.'
newLegend='Views 5/6: red = film height, green = displayed drops, blue = micro water. Red/blue use log2(1 + um) / log2(1001). Purple combines film and micro; it is not film alone. View 5 transmits 15% of the scene even at zero water. View 6 blocks scene transmission in this pass; later visor optics still apply. Drop display scale changes green size only. Normal optics: set P3 view and WF debug to 0.'
assert old.count(oldUI)==old.count(oldLegend)==1
assert old.replace(oldUI,newUI).replace(oldLegend,newLegend)==new
before=(BASE/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8-sig')
after=(ROOT/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8-sig')
anchor='        result=gDynamicDropP3Debug>4.5 ? float4(link,.85)'
replacement='''        // View 6 removes scene transmission in this pass. Later E2/E3 optics
        // can still modify the diagnostic; this never changes water or depth.
        result=gDynamicDropP3Debug>4.5 ? float4(link,gDynamicDropP3Debug>5.5 ? 1 : .85)'''
assert before.count(anchor)==1 and before.replace(anchor,replacement)==after
for folder in ('RAIN_GEOMETRY','RAIN_BIRTH','RAIN_FILM'):
    p=ROOT/'texture'/folder/'assets.json'
    if p.exists():
        for name,value in json.loads(p.read_text())['sha256'].items():assert sha(ROOT/name)==value,name
reports={name:json.loads((OUT/name).read_text()) for name in ['lens_checks.json','overlap_checks.json','lua_syntax.json','media.json']}
lens=reports['lens_checks.json'];overlap=reports['overlap_checks.json']
assert all(lens[k] for k in ('view5BitIdentical','view6SceneIndependent','view6EmptyBlack','view6NativeExcluded',
    'view6NoSolidDepth','normalBitIdenticalToS87','mixedNormalBitIdenticalToS87'))
assert reports['lua_syntax.json']['wholeLuaSyntax']
assert len(overlap['checks'])==8 and overlap['arithmeticGatePassed'] and not overlap['runtimeIntegrated']
assert overlap['thinTranslationMaxErrorMM3']<1e-9
assert len(reports['media.json']['reviewSamplesSeconds'])==13
game=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')
installed={n:sha(ROOT/n)==sha(game/n) for n in runtimeExpected|{'rain_film.lua','rain_birth_gpu.lua'}}
assert all(installed.values())
newFiles=[ROOT/'docs/RAINFX_S89_VIDEO_AND_POSITIVE_REMAP.md',
    *sorted((ROOT/'docs/prototypes/s89').glob('*.hlsl')),*sorted((ROOT/'docs/tools').glob('*s89*.py'))]
diff=[]
for name in sorted(changes):
    diff.extend(difflib.unified_diff((BASE/name).read_text(encoding='utf-8-sig').splitlines(True),
        (ROOT/name).read_text(encoding='utf-8-sig').splitlines(True),fromfile='staged_s87/'+name,tofile='s89/'+name))
for p in newFiles:
    diff.extend(difflib.unified_diff([],p.read_text(encoding='utf-8-sig').splitlines(True),fromfile='/dev/null',tofile=p.relative_to(ROOT).as_posix()))
assert not any(s.startswith('+') and not s.startswith('+++') and s.rstrip('\r\n').endswith((' ','\t')) for s in diff)
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
review=dict(source='E:/_db_Media/Rec_Encoded/OBS_SOURCES_QHD/film um check.mp4',
    reviewedSamplesSeconds=reports['media.json']['reviewSamplesSeconds'],nativeDetailFramesSeconds=[3,15],
    assessed='Direction/distribution response is expected from current projected force model. Does not pass physical timing or unified head/film motion.',
    inferredView='Likely view5 from green heads plus purple film/micro; UI not visible, exact number unconfirmed.',
    cautions=['Background transmission and downstream optics affect visible colour','Whole debug mesh extent is not wet coverage',
        '13 samples are not all-frame glitch or per-drop trajectory certification'])
(OUT/'video_review.json').write_text(json.dumps(review,indent=2))
report=dict(step='s89',date='2026-10-16',head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
    preservedPhysicalRuntime=preserved,preservedTuningAndUserMaterials=True,geometryUnchanged=True,
    changedRuntimeFiles=sorted(runtimeExpected),newFiles={p.relative_to(ROOT).as_posix():sha(p) for p in newFiles},
    actualGameExtraPasses=0,actualGameExtraTextures=0,actualGameExtraReadbacks=0,
    normalOutput='Film-only and mixed head/film bit-identical to staged s87 GPU fixtures',
    offlineRemap='Positive conservative overlap arithmetic passes; full physical transport and runtime adoption pending',
    installedHashesMatch=installed,delivery='Existing main/shader game symlinks; app reload exposes view6; physical modules unchanged',
    gamePerformanceMeasured=False,requestedRepeatedGameLogs=False,committedOrPushed=False)
(OUT/'delivery.json').write_text(json.dumps(report,indent=2))
print('s89:',len(preserved),'other runtime files plus all tuning/materials preserved; existing game symlinks match.')
print('Production full /WX optics, scene isolation/native/depth, normal equivalence and offline overlap gates verified.')
