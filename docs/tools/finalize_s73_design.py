"""Verify the published s73 design against baseline guards; no runtime edits."""
from pathlib import Path
import hashlib
import json
import math

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'docs/diagnostics/2026-10-14/s73'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    manifest = json.loads((OUT/'baseline_manifest.json').read_text())
    registry = {'docs/README.md', 'docs/RAINFX_ROADMAP.md'}
    for name, meta in manifest.items():
        if name in registry:
            continue
        p = ROOT/name
        assert sha(p) == meta['sha256'], 'Changed after audit: '+name
        assert p.stat().st_mtime_ns == meta['mtime_ns'], 'Restaged mtime required: '+name
    edits = {
        'docs/README.md': [
            ('# RealVisor RainFX — docs index and working rules (2026-10-13)',
             '# RealVisor RainFX — docs index and working rules (2026-10-14)'),
            ('| `RAINFX_S72_TRAIL_SAMPLING_AND_DIAMETER.md` | ACTIVE |',
             '| `RAINFX_S73_PHYSICS_WEATHER_REFACTOR_DESIGN.md` | ACTIVE | design only: audited 6 px/mm calibration, volume/SI physics, independent display gain, CSP weather adapter, virtual impact and shared effect state; staged implementation and cost gates |\r\n| `RAINFX_S72_TRAIL_SAMPLING_AND_DIAMETER.md` | ACTIVE |')],
        'docs/RAINFX_ROADMAP.md': [
            ('# RainFX roadmap (accepted items, not scheduled) — updated 2026-10-13',
             '# RainFX roadmap (accepted items, not scheduled) — updated 2026-10-14'),
            ('## Latest s72 Trail sampling/model calibration (2026-10-13)',
             '## Latest s73 Physics/weather refactor design (2026-10-14)\r\n\r\n'
             'Design only; runtime and user tuning unchanged. Verified the user\'s updated\r\n'
             '6 px/mm at 4096x1024 reference. Audited mixed SI/normalized masses, reference\r\n'
             'force/speed calibration and trail-only diameter x3. Proposed volume-based\r\n'
             'surface state, contact-angle pinning, independent display-size gain,\r\n'
             'filtered CSP weather/phase adapter, estimated DSD/flux and birth-only\r\n'
             'virtual impact. Track water and RH have separate physical roles; effect\r\n'
             'gates share actual local water state. Reuse existing GPU slots/sparse\r\n'
             'sweeps; film transport/absorption/children follow explicit cost gates.\r\n'
             's72 remains the live implementation until the staged model is implemented.\r\n'
             'See `RAINFX_S73_PHYSICS_WEATHER_REFACTOR_DESIGN.md`.\r\n\r\n'
             '## Latest s72 Trail sampling/model calibration (2026-10-13)')]
    }
    replacements = {}
    for name, pairs in edits.items():
        original = (OUT/'baseline'/name).read_bytes()
        text = original.decode('utf-8')
        newline = '\r\n' if '\r\n' in text else '\n'
        for before, after in pairs:
            assert text.count(before) == 1, (name, before)
            text = text.replace(before, after.replace('\r\n', newline), 1)
        replacements[name] = text.encode('utf-8')
    audit = json.loads((OUT/'audit.json').read_text())
    c = audit['calibration']
    assert c['pixels_per_mm_4096'] == 6
    assert c['v_per_mm_nominal_4to1']*1024 == 6
    examples = {d['equivalent_diameter_mm']:d for d in audit['water_20C_fixtures']}
    ratio = examples[2.25]['mass_mg']/examples[.65]['mass_mg']
    assert math.isclose(ratio, (2.25/.65)**3, rel_tol=1e-12)
    assert math.isclose(examples[1.15]['cap_footprint_mm_theta90']/1.15, 2**(1/3), rel_tol=1e-12)
    for group in audit['DSD_seed_moments'].values():
        assert math.isclose(sum(group['number_weights']), 1)
        assert math.isclose(sum(group['volume_fraction_by_component']), 1)
    # The registry was edited through apply_patch; verify its exact guarded result.
    for name, payload in replacements.items():
        assert (ROOT/name).read_bytes() == payload, 'Unexpected registry diff: '+name
    runtime = {name: sha(ROOT/name) == meta['sha256'] for name,meta in manifest.items()
               if not name.startswith('docs/')}
    assert all(runtime.values())
    record = {'step':'s73', 'date':'2026-10-14', 'scope':'design only',
              'runtime_settings_shaders_unchanged':runtime,
              'numeric_checks':{'mm_to_atlas_pixels':True,'mass_cubic_scaling':True,
                                'spherical_cap_geometry':True,'mixture_normalization':True},
              'mass_ratio_2p25_to_0p65_mm':ratio,
              'changed_docs_sha256':{name:sha(ROOT/name) for name in
                  [*edits,'docs/RAINFX_S73_PHYSICS_WEATHER_REFACTOR_DESIGN.md']},
              'actual_CSP_GPU_and_game_validation':False}
    (OUT/'delivery.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    print(json.dumps({'runtime_files_unchanged':len(runtime),'mass_ratio':ratio,
                      'docs_published':list(record['changed_docs_sha256']),
                      'scope':'design only'},indent=2))


if __name__ == '__main__':
    main()
