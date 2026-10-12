"""Save a read-only baseline for concurrent-edit-safe migration patches."""
from pathlib import Path
import hashlib,json,shutil
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/diagnostics/2026-10-12/kn5-migration/baseline'
files=[ROOT/n for n in ['realvisor.lua','visor_optics.lua','material_settings.lua','settings_mats.ini']]
files+=list((ROOT/'shaders').glob('*.hlsl'))
files+=list((ROOT/'docs/tools').glob('build_*'))+list((ROOT/'docs/tools').glob('check_*'))
OUT.mkdir(parents=True,exist_ok=True)
manifest={}
for path in files:
    rel=path.relative_to(ROOT).as_posix();target=OUT/rel
    if not target.exists():target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,target)
    manifest[rel]=dict(sha256=hashlib.sha256(target.read_bytes()).hexdigest(),mtime_ns=target.stat().st_mtime_ns)
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('Baseline saved:',len(manifest),'files')
