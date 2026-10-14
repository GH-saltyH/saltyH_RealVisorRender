from pathlib import Path
import json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s67/baseline'
assert not OUT.exists();OUT.mkdir(parents=True)
files=['realvisor.lua','visor_optics.lua','rain_surface.lua','material_settings.lua','native_glass_occlusion.lua','native_glass_state.lua','settings.ini','settings_mats.ini']
files += [p.relative_to(ROOT).as_posix() for p in (ROOT/'shaders').glob('*.hlsl')]
files += [p.relative_to(ROOT).as_posix() for p in (ROOT/'docs').glob('*.md')]
manifest={}
for name in files:
    p=ROOT/name;q=OUT/name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
    manifest[name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'mtime_ns':p.stat().st_mtime_ns}
game=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')
for name in ('settings.ini','settings_mats.ini','native_glass_occlusion.lua'):
    q=OUT/'installed'/name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(game/name,q)
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('s67 immutable source and live installed settings snapshot saved')
