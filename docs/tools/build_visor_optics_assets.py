"""Export optics smooth normals and authored KN5 material textures. KN5 unchanged."""
from pathlib import Path
import struct, json, hashlib, re
import numpy as np
import build_e1_housing_bvh as bvh
from kn5_assets import KN5

def export(model=bvh.MODEL):
    parsed=KN5(model)
    blob=model.read_bytes();p=6
    assert blob[:6]==b'sc6969'
    def u32():
        nonlocal p
        v=struct.unpack_from('<I',blob,p)[0];p+=4;return v
    def string():
        nonlocal p
        n=u32();v=blob[p:p+n].decode('utf-8');p+=n;return v
    version=u32()
    if version>5:u32()
    textures={}
    for _ in range(u32()):
        u32();name=string();size=u32();textures[name]=blob[p:p+size];p+=size
    materials=[]
    for _ in range(u32()):
        name=string();shader=string();p+=6
        properties={}
        for _ in range(u32()):
            key=string();values=struct.unpack_from('<10f',blob,p);p+=40;properties[key]=values[0]
        slots={}
        for _ in range(u32()):
            slot=string();u32();slots[slot]=string()
        materials.append(dict(name=name,shader=shader,properties=properties,slots=slots))
    output=bvh.OUT;pending=[];meta={};atlas=[];record_count=0
    for name,key in bvh.MESHES+[('GLASS_EXT_FX','band')]:
        vertices,indices=bvh.mesh(blob,name)
        nodes,triangles,count,order=bvh.build(vertices,indices,with_order=True)
        assert count<=65536
        normals=np.zeros((len(indices)*3,4),np.float32)
        normals[:,:3]=vertices[indices[order],3:6].reshape(-1,3)
        assert np.isfinite(normals).all()
        # Locate the exact mesh record to obtain its authored material index.
        matches=[m for m in re.finditer(name.encode(),blob)
            if m.start()>=8 and struct.unpack_from('<II',blob,m.start()-8)==(2,len(name))]
        assert len(matches)==1
        start=matches[0].end()+12+len(vertices)*44
        material_id=struct.unpack_from('<I',blob,start+4+len(indices)*6)[0]
        material=materials[material_id];paths={}
        if key=='band':
            material=materials[parsed.meshes['GLASS_EXT_MRR']['material']]
            # Textures are reprojected offline onto FX UVs by build_fx_atlases.py.
        for slot in ('txDiffuse','txNormal','txMaps'):
            filename=material['slots'].get(slot)
            if filename:
                assert filename in textures,(name,slot,filename)
                data=textures[filename]
                extension='.png' if data.startswith(b'\x89PNG') else '.dds'
                assert data.startswith((b'\x89PNG',b'DDS ')),(name,slot,'unsupported texture encoding')
                relative=f'{key}_{slot}{extension}';pending.append((relative,data));paths[slot]=relative
        meta[key]=dict(mesh=name,material=material['name'],textures=paths,properties=material['properties'])
        meta[key]['bounds']=np.concatenate((vertices[:,:3].min(axis=0),vertices[:,:3].max(axis=0))).tolist()
        offsets=[]
        for records in (nodes,triangles,normals):
            offsets.append(record_count);atlas.append(records);record_count+=len(records)
        meta[key]['records']=offsets
        pending.append((f'{key}_normals.dds',normals))
        if key=='band':
            pending.extend([('band_nodes.dds',nodes),('band_triangles.dds',triangles)])
        print(name,material['name'],paths)
    assert record_count<2**24 and (record_count+bvh.WIDTH-1)//bvh.WIDTH<=16384
    pending.append(('optics_geometry.dds',np.concatenate(atlas)))
    # All validation precedes writes.
    output.mkdir(parents=True,exist_ok=True)
    for name,data in pending:
        if isinstance(data,bytes):(output/name).write_bytes(data)
        else:bvh.dds(output/name,data)
    meta['sha256']=hashlib.sha256(blob).hexdigest()
    (output/'optics_materials.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
    lines=['return {']
    for _,key in bvh.MESHES+[('GLASS_EXT_FX','band')]:
        paths=meta[key]['textures']
        fields=[slot+'='+json.dumps(path) for slot,path in paths.items()]
        fields.append('records={'+','.join(map(str,meta[key]['records']))+'}')
        fields.append('bounds={'+','.join(map(str,meta[key]['bounds']))+'}')
        lines.append(key+'={'+','.join(fields)+'},')
    lines.append('}')
    (output/'optics_materials.lua').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    (output/'optics.verify').write_text(meta['sha256']+'\n',encoding='utf-8')
    return meta

if __name__=='__main__':export()
