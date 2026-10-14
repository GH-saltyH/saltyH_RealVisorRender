"""Stage and verify the branch/scope documentation change; runtime remains unchanged."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'docs/diagnostics/2026-10-14/s74'
DOCS = ['docs/README.md', 'docs/RAINFX_ROADMAP.md',
        'docs/RAINFX_S73_PHYSICS_WEATHER_REFACTOR_DESIGN.md']
FILES = ['realvisor.lua', 'rain_trails.lua', 'rain_surface.lua', 'settings.ini', 'settings_mats.ini', *DOCS]
FILES += [p.relative_to(ROOT).as_posix() for p in (ROOT/'shaders').glob('*.hlsl')]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def main():
    assert git('branch','--show-current') == 'codex/rainfx-physics-weather'
    parent = git('rev-parse', 'HEAD')
    assert parent.startswith('0c092e0'), 'Unexpected implementation starting commit'
    if sys.argv[1] == 'stage':
        assert not (OUT/'baseline_manifest.json').exists(), 'Do not overwrite baseline'
        manifest = {}
        for name in FILES:
            src = ROOT/name
            if not src.is_file():
                continue
            dst = OUT/'baseline'/name
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            manifest[name] = {'sha256':sha(src), 'mtime_ns':src.stat().st_mtime_ns}
        (OUT/'baseline_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
        print('Staged '+str(len(manifest))+' files at '+parent)
        return
    manifest = json.loads((OUT/'baseline_manifest.json').read_text())
    unchanged = {name:sha(ROOT/name)==meta['sha256'] for name,meta in manifest.items() if name not in DOCS}
    assert all(unchanged.values()), unchanged
    assert all((ROOT/name).stat().st_mtime_ns==meta['mtime_ns'] for name,meta in manifest.items() if name not in DOCS)
    design = (ROOT/DOCS[2]).read_text(encoding='utf-8-sig')
    assert '| smear (보류) |' in design
    assert 'local impact film (배제)' in design
    assert 'smear mask 의도 유지' not in design
    scope = (ROOT/'docs/RAINFX_S74_CORE_IMPLEMENTATION_SCOPE.md').read_text(encoding='utf-8-sig')
    assert 'RAIN_DYNAMIC_IMPACT_SHEET_ENABLED' in scope
    assert 'RAIN_DYNAMIC_SMEAR_ENABLED' in scope
    assert '물리적 충돌' in scope
    record = {'step':'s74','scope':'implementation branch and approved core-first scope; documentation only',
              'branch':git('branch','--show-current'),'legacy_parent_commit':parent,
              'runtime_settings_shaders_unchanged':unchanged,
              'deferred':['smear','legacy local impact film'],
              'core_impact_retained':True,
              'changed_docs_sha256':{name:sha(ROOT/name) for name in [*DOCS,'docs/RAINFX_S74_CORE_IMPLEMENTATION_SCOPE.md']}}
    (OUT/'delivery.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
    print(json.dumps({'branch':record['branch'],'parent':parent,'runtime_files_unchanged':len(unchanged)},indent=2))


if __name__ == '__main__':
    main()
