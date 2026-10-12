from pathlib import Path
import hashlib,json,shutil,difflib
root=Path(__file__).resolve().parents[2]
out=root/'docs/diagnostics/2026-10-12/s66/baseline'
assert not out.exists(),'Do not overwrite baseline'
out.mkdir(parents=True)
names=['realvisor.lua','rain_surface.lua','native_glass_state.lua','native_glass_occlusion.lua','visor_optics.lua','material_settings.lua','settings.ini','settings_mats.ini']
names += [p.relative_to(root).as_posix() for p in (root/'shaders').glob('*.hlsl')]
names += [p.relative_to(root).as_posix() for p in (root/'docs').glob('*.md')]
manifest={}
previous=root/'docs/diagnostics/2026-10-12/s65/delivery.json'
old=json.loads(previous.read_text())['files']
for name in names:
    p=root/name;target=out/name;target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(p,target)
    manifest[name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'mtime_ns':p.stat().st_mtime_ns}
    if name in old and old[name]['sha256']!=manifest[name]['sha256']: print('Changed since s65:',name)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2))
installed=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')
for name in names[:8]:
    p=installed/name
    if p.exists():
        target=out/'installed'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
        h=hashlib.sha256(p.read_bytes()).hexdigest()
        print('Installed:',name,'same' if h==manifest[name]['sha256'] else 'DIFFERENT')
    else:print('Installed MISSING:',name)
