"""Register the s72 investigation and verified source delivery."""
from pathlib import Path
import json,hashlib,difflib,re
root=Path(__file__).resolve().parents[2];out=root/'docs/diagnostics/2026-10-13/s72'
source=(root/'realvisor.lua').read_text(encoding='utf-8')
before=(out/'baseline/realvisor.lua').read_text(encoding='utf-8')
def profile(s):return dict(re.findall(r'^\s*(RAIN_GPU_SIZE_[A-Z_]+|RAIN_DYNAMIC_MICRO_PATTERN_DIAMETER_MM)\s*=\s*([^,\r\n]+)',s,re.M))
assert profile(source)==profile(before),'Current screen-size profile changed'
lens=json.loads((out/'lens_checks.json').read_text());assert lens['3']['alpha_max']>.8 and lens['bare_max']==0
files=['realvisor.lua','rain_trails.lua','shaders/rainTrailDescriptor.hlsl','shaders/rainTrailResolve.hlsl','shaders/rainVisorDynamicDrop.hlsl']
delivered={}
for p in files:
    data=(root/p).read_bytes();installed=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')/p
    assert installed.read_bytes()==data,('Game source differs',p)
    delivered[p]=hashlib.sha256(data).hexdigest()
docs=['docs/README.md','docs/RAINFX_ROADMAP.md','docs/RAINFX_S70_TRAIL_VISIBILITY.md']
raw={p:(root/p).read_bytes() for p in docs};mt={p:(root/p).stat().st_mtime_ns for p in docs}
for p in docs:assert raw[p]==(out/'baseline'/p).read_bytes(),('Concurrent docs update',p)
texts={p:b.decode('utf-8').replace('\r\n','\n') for p,b in raw.items()}
def change(p,a,b):
    assert texts[p].count(a)==1,(p,a);texts[p]=texts[p].replace(a,b,1)
change('docs/README.md','| `RAINFX_S71_SMEAR_RED_REGION.md` | ACTIVE |',
       '| `RAINFX_S72_TRAIL_SAMPLING_AND_DIAMETER.md` | ACTIVE | carried phase, pixel integration/bandlimit, trail derivative floor; model diameter ×3 with compensated thin output, wide sheets, preserved head/micro profile; cost and GPU checks, game verification pending |\n| `RAINFX_S71_SMEAR_RED_REGION.md` | ACTIVE |')
change('docs/README.md','| `RAINFX_S70_TRAIL_VISIBILITY.md` | ACTIVE | evaluated current saved trail thickness/optics; ordinary films are suppressed by subpixel deposition, opacity and weak displacement; corrections pending |',
       '| `RAINFX_S70_TRAIL_VISIBILITY.md` | REFERENCE | diagnosis of weak ordinary-film optics; sampling/model calibration implemented and evaluated in s72 |')
change('docs/RAINFX_ROADMAP.md','## Latest s71 Smear red-region correction (2026-10-13)', '''## Latest s72 Trail sampling/model calibration (2026-10-13)

User confirms current head/micro size profile is appropriate, but observes rough
traces and no thick-film response at those diameters. Reproduced segment phase
resets and unresolved noise/ripple frequencies; added carried generation phase,
projected pixel integration/bandlimit and a half-history-texel derivative floor.
Water-model diameter ×3 / thin-output compensation 1/3 retains accepted head,
micro and thin/wipe sizes; developed sheets use model width and radius-scaled
thickness. Deposited ordinary-film history reaches the production lens (alpha
0.953, bare-visor contribution zero in the controlled test). Additional metadata
384 KiB, no new full-atlas pass; actual 4096-slot model-width candidates +0.148%.
Actual game FPS and remaining true trajectory/chord corners need confirmation.
See `RAINFX_S72_TRAIL_SAMPLING_AND_DIAMETER.md`; this follows the s70 diagnosis.

## Latest s71 Smear red-region correction (2026-10-13)''')
change('docs/RAINFX_S70_TRAIL_VISIBILITY.md','Status: ACTIVE — evaluation complete; optical calibration and subpixel deposition corrections remain to implement.',
       'Status: REFERENCE — evaluation followed by s72 sampling and water-model calibration; game confirmation tracked there.')
change('docs/RAINFX_S70_TRAIL_VISIBILITY.md','## User result and scope', '''## Follow-up (2026-10-13)

s72 implements carried phase, subpixel integration/bandlimit, derivative support
and a separate water-model diameter/output calibration. Actual deposited normal
film now reaches production refraction in controlled GPU checks. See
`RAINFX_S72_TRAIL_SAMPLING_AND_DIAMETER.md` for changes, cost and verification limits.
The numbers and unchanged-runtime statement below describe the original s70
evaluation; they are retained as the historical diagnosis.

## User result and scope''')
for p in docs:assert (root/p).stat().st_mtime_ns==mt[p] and (root/p).read_bytes()==raw[p],('Concurrent edit',p)
for p in docs:(root/p).write_bytes((texts[p].replace('\n','\r\n') if b'\r\n' in raw[p] else texts[p]).encode('utf-8'))
diff=[]
for p in files+docs+['docs/tools/check_s67_runtime.py','docs/tools/check_s67_gpu.py','docs/tools/bench_s67_candidates.py']:
    old=(out/'baseline'/p).read_text(encoding='utf-8').splitlines(True);new=(root/p).read_text(encoding='utf-8').splitlines(True)
    diff.extend(difflib.unified_diff(old,new,fromfile='s72-before/'+p,tofile='s72-after/'+p))
(out/'source.diff').write_text(''.join(diff),encoding='utf-8')
(out/'delivery.json').write_text(json.dumps({'step':'s72','date':'2026-10-13','installed_sources_matching_sha256':delivered,
    'head_micro_birth_profile_unchanged':True,'core_physics_programs_unchanged':True,
    'water_model_scale':3,'thin_output_scale':1/3,'developed_sheet_uses_model_width':True,
    'actual_game_fps_and_trajectory_validation_pending':True},indent=2))
print('PASS: s72 registered, staged docs guarded, accepted profile retained and installed source hashes verified')
