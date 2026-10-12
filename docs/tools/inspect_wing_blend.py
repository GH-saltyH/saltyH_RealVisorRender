"""Read wing topology, UVs and material bindings without saving the blend file."""
import bpy
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
out = root / 'docs/diagnostics/2026-10-11/native-wing'
out.mkdir(parents=True, exist_ok=True)
records = []
for obj in bpy.data.objects:
    if obj.type != 'MESH' or 'wing' not in obj.name.lower():
        continue
    mesh = obj.data
    rec = dict(name=obj.name, vertices=len(mesh.vertices), faces=len(mesh.polygons),
               materials=[], uv_layers=[u.name for u in mesh.uv_layers])
    for slot in obj.material_slots:
        mat = slot.material
        if mat is None:
            continue
        rec['materials'].append(dict(name=mat.name, images=[
            dict(node=n.name, image=n.image.name, path=n.image.filepath)
            for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image]
            if mat.use_nodes else []))
    if mesh.uv_layers.active:
        rec['uv'] = [list(v.uv) for v in mesh.uv_layers.active.data]
        rec['polygons'] = [list(p.loop_indices) for p in mesh.polygons]
    records.append(rec)
(out/'blend_wing_inventory.json').write_text(json.dumps(records), encoding='utf-8')
print(json.dumps([{k:v for k,v in r.items() if k not in ('uv','polygons')} for r in records], indent=2))
