"""Read-only runtime audit and numerical fixtures for the s73 DESIGN (not a runtime test)."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import math
import re
import shutil

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/diagnostics/2026-10-14/s73'
FILES = ['realvisor.lua', 'rain_surface.lua', 'rain_trails.lua', 'lib.lua',
         'settings.ini', 'settings_mats.ini', 'docs/README.md', 'docs/RAINFX_ROADMAP.md',
         'docs/RAINFX_S72_TRAIL_SAMPLING_AND_DIAMETER.md']
FILES += [str(p.relative_to(ROOT)).replace('\\', '/') for p in (ROOT/'shaders').glob('*.hlsl')]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for name in FILES:
        src = ROOT/name
        if not src.is_file():
            continue
        dst = OUT/'baseline'/name
        if dst.exists():
            raise RuntimeError('Baseline already exists; do not overwrite: '+name)
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        manifest[name] = {'sha256': sha(src), 'mtime_ns': src.stat().st_mtime_ns}
    (OUT/'baseline_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    text = (ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
    def value(key):
        hits = re.findall(r'^\s*'+re.escape(key)+r'\s*=\s*([-+\d.eE]+)\s*,', text, re.M)
        assert len(hits) == 1, (key, hits)
        return float(hits[0])
    keys = ['RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM', 'RAIN_PHYSICS_ACCEL_SCALE',
            'RAIN_FLOW_ACCELERATION', 'RAIN_ADHESION_MIN', 'RAIN_ADHESION_MAX',
            'RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_1MM', 'RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_EXPONENT',
            'RAIN_GPU_STATE_MOBILE_SPEED_MULTIPLIER', 'RAIN_GPU_STATE_MOVING_FORCE_GAIN',
            'RAIN_NEW_TRAIL_MODEL_DIAMETER_SCALE', 'RAIN_NEW_TRAIL_OUTPUT_DIAMETER_SCALE',
            'RAIN_GPU_SIZE_MIN_HEAVY', 'RAIN_GPU_SIZE_MAX_HEAVY', 'RAIN_GPU_SIZE_BIAS']
    config = {key: value(key) for key in keys}
    ref = config[keys[0]]
    assert ref == 6/4096
    numeric = []
    rho, gamma, viscosity = 998.2, .0728, .001002  # approximate pure water at 20 C
    for diameter in [.1, .25, .65, 1.15, 1.55, 2.25, 4.5, 6.3]:
        d = diameter*.001
        volume = math.pi*d**3/6
        # Spherical cap at illustrative 90-degree equilibrium angle, not a measured visor.
        a = (3*volume/(2*math.pi))**(1/3)
        delta_cos = math.cos(math.radians(70))-math.cos(math.radians(110))
        retention = gamma*2*a*delta_cos
        mass = rho*volume
        numeric.append({'equivalent_diameter_mm': diameter, 'volume_mm3': volume*1e9,
                        'mass_mg': mass*1e6, 'cap_footprint_mm_theta90': 2*a*1000,
                        'legacy_mass_profile': 1+8*min(1,max(0,(diameter**3-.5**3)/(6**3-.5**3))),
                        'illustrative_pinning_N': retention, 'weight_N': mass*9.80665,
                        'weight_over_pinning_vertical': mass*9.80665/retention,
                        'We_normal_v2ms': rho*4*d/gamma,
                        'We_normal_v10ms': rho*100*d/gamma})
    # These coefficients are an explicit game proposal, not a measured atmospheric DSD.
    components = [( .1, .5, .25), (.5, 2., 1.15), (2., 6.3, 2.75)]
    profiles = {'drizzle':[.90,.10,0], 'rain':[.65,.30,.05],
                'thunderstorm':[.55,.35,.10], 'hurricane':[.75,.23,.02]}
    mixtures = {}
    for name, weights in profiles.items():
        log_moments = []
        for low, high, mode in components:
            lo, hi, peak = map(math.log, (low,high,mode))
            bins = 4096
            mass_pdf = []
            for j in range(bins):
                x = lo+(hi-lo)*(j+.5)/bins
                p = 2*(x-lo)/((hi-lo)*(peak-lo)) if x<peak else 2*(hi-x)/((hi-lo)*(hi-peak))
                mass_pdf.append((math.exp(x),p))
            norm = sum(p for d,p in mass_pdf)
            log_moments.append([sum(d**k*p for d,p in mass_pdf)/norm for k in (1,3)])
        nmean = sum(w*m[0] for w,m in zip(weights,log_moments))
        vtotal = sum(w*m[1] for w,m in zip(weights,log_moments))
        mixtures[name] = {'number_weights':weights, 'number_mean_mm':nmean,
                          'volume_fraction_by_component':[w*m[1]/vtotal for w,m in zip(weights,log_moments)]}
    film_example = []
    for v in [.01,.1,1]:
        ca = viscosity*v/gamma
        h = .5e-3*ca**(2/3)  # illustrative coefficient 1, drop scale, not plate LLD law
        film_example.append({'speed_ms':v,'capillary_number':ca,'illustrative_h_um':h*1e6,
                             'volume_mm3_width1mm_path10mm':h*1e6*.001*10})
    old = ROOT/'docs/diagnostics/2026-10-13/s72/baseline/realvisor.lua'
    delivery = ROOT/'docs/diagnostics/2026-10-13/s72/delivery.json'
    prior_hash = json.loads(delivery.read_text())['installed_sources_matching_sha256']['realvisor.lua']
    audit = {'kind':'design audit and analytic fixtures; no CSP/GPU or real-game validation',
             'date':'2026-10-14','config':config,
             'calibration':{'u_per_mm':ref,'v_per_mm_nominal_4to1':ref*4,'pixels_per_mm_4096':ref*4096,
                            'meters_per_reference_unit':.001/ref,
                            'legacy_cap_1mm_ms':config[keys[5]]*.001/ref},
             'current_realvisor_matches_s72_delivery':sha(ROOT/'realvisor.lua')==prior_hash,
             'water_20C_fixtures':numeric,'DSD_seed_log_triangular_components':components,
             'DSD_seed_moments':mixtures,'film_illustration':film_example}
    if old.exists():
        diff = ''.join(difflib.unified_diff(old.read_text(encoding='utf-8-sig').splitlines(True),
                     text.splitlines(True),fromfile='s72 pre-change baseline',tofile='s73 design baseline'))
        (OUT/'against_s72_prechange.diff').write_text(diff,encoding='utf-8')
    (OUT/'audit.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
    print(json.dumps({'calibration':audit['calibration'],'seed_mixtures':mixtures,
                      'runtime_changed_since_s72':not audit['current_realvisor_matches_s72_delivery'],
                      'snapshotted_files':len(manifest)},indent=2))


if __name__ == '__main__':
    main()
