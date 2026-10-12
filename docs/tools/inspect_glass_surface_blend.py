"""Read current glass UV and smoothing metadata. Never save the source blend."""
import bpy
import json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
out=root/'docs/diagnostics/2026-10-11/glass-smooth-v2'
out.mkdir(parents=True,exist_ok=True)
records=[]
for obj in bpy.data.objects:
    if obj.type!='MESH':continue
    materials=[s.material.name if s.material else '' for s in obj.material_slots]
    if not any(any(key in n.upper() for key in ['GLASS_EXT','GLASS_COAT','GLASS_STICKER']) for n in materials):continue
    mesh=obj.data
    r=dict(name=obj.name,materials=materials,vertices=len(mesh.vertices),faces=len(mesh.polygons),
           smooth_faces=sum(p.use_smooth for p in mesh.polygons),
           has_custom_normals=mesh.has_custom_normals,hide_render=obj.hide_render,
           uv_layers=[u.name for u in mesh.uv_layers],images=[])
    for slot in obj.material_slots:
        mat=slot.material
        if mat and mat.node_tree:
            r['images'] += [dict(name=n.image.name,path=n.image.filepath) for n in mat.node_tree.nodes
                            if n.type=='TEX_IMAGE' and n.image]
    if mesh.uv_layers.active:
        r['uv']=[list(v.uv) for v in mesh.uv_layers.active.data]
        r['polygons']=[list(p.loop_indices) for p in mesh.polygons]
    records.append(r)
(out/'blend_inventory.json').write_text(json.dumps(records),encoding='utf-8')
print(json.dumps([{k:v for k,v in r.items() if k not in ['uv','polygons']} for r in records],indent=2))
