"""Bake independent local-space housing BVHs; never transfer glass UVs.

RGBA32F DDS records, stackless depth-first traversal, leaves <= 8 triangles.
Run from any directory. Runtime supplies each mesh's actual world transform.
"""
from pathlib import Path
import hashlib
import json
import re
import struct
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / 'visors/visor_lando_2025Champion_maxquality_diet.kn5'
OUT = ROOT / 'texture/GLASS/E1_GEOMETRY'
WIDTH = 1024


def dds(path, records):
    height = (len(records) + WIDTH - 1) // WIDTH
    data = np.zeros((height * WIDTH, 4), dtype='<f4')
    data[:len(records)] = records
    header = [124, 0x100f, height, WIDTH, WIDTH*16, 0, 1] + [0]*11
    header += [32, 4, struct.unpack('<I', b'DX10')[0], 0, 0, 0, 0, 0]
    header += [0x1000, 0, 0, 0, 0]
    path.write_bytes(b'DDS '+struct.pack('<31I', *header)
                    + struct.pack('<5I', 2, 3, 0, 1, 0) + data.tobytes())


def mesh(blob, name):
    matches = []
    for match in re.finditer(name.encode(), blob):
        if struct.unpack_from('<I', blob, match.start()-8)[0] != 2:
            continue
        p = match.end()
        count = struct.unpack_from('<I', blob, p+8)[0]
        vertices = np.frombuffer(blob, '<f4', count*11, p+12).reshape(count, 11).copy()
        p += 12 + count*44
        count = struct.unpack_from('<I', blob, p)[0]
        indices = np.frombuffer(blob, '<u2', count, p+4).reshape(-1, 3).copy()
        assert indices.max() < len(vertices) and np.isfinite(vertices).all()
        matches.append((vertices, indices))
    assert len(matches) == 1, (name, len(matches))
    return matches[0]


def build(vertices, indices):
    tri = vertices[indices, :3]
    uv = vertices[indices, 6:8]
    minimum, maximum = tri.min(1), tri.max(1)
    centers = (minimum+maximum)*0.5
    nodes, order = [], []

    def visit(ids):
        index = len(nodes)
        nodes.append(None)
        lo, hi = minimum[ids].min(0), maximum[ids].max(0)
        meta = -1
        if len(ids) <= 8:
            meta = len(order)*16+len(ids)
            order.extend(ids.tolist())
        else:
            axis = np.ptp(centers[ids], axis=0).argmax()
            ids = ids[np.argsort(centers[ids, axis], kind='stable')]
            mid = len(ids)//2
            visit(ids[:mid])
            visit(ids[mid:])
        nodes[index] = (lo-1e-6, hi+1e-6, meta, len(nodes))
        return index

    visit(np.arange(len(tri)))
    order = np.array(order)
    assert len(np.unique(order)) == len(tri)
    assert max(n[2] for n in nodes) < 2**24
    packed = np.zeros((len(nodes)*2, 4), np.float32)
    for index, (lo, hi, meta, escape) in enumerate(nodes):
        packed[index*2] = [*lo, meta]
        packed[index*2+1] = [*hi, escape]
        assert escape > index
    records = np.zeros((len(tri), 4, 4), np.float32)
    records[:, :3, :3] = tri[order]
    records[:, :3, 3] = uv[order, :, 0]
    records[:, 3, :3] = uv[order, :, 1]
    return packed, records.reshape(-1, 4), len(nodes)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    blob = MODEL.read_bytes()
    manifest = {'model': str(MODEL.relative_to(ROOT)), 'sha256': hashlib.sha256(blob).hexdigest(),
                'width': WIDTH, 'meshes': {}}
    for name, key in [('BODY_FRAME', 'frame'), ('BODY_GLASSLINE', 'rubber'),
                      ('BODY_FABRIC', 'fabric')]:
        vertices, indices = mesh(blob, name)
        nodes, triangles, count = build(vertices, indices)
        dds(OUT/f'{key}_nodes.dds', nodes)
        dds(OUT/f'{key}_triangles.dds', triangles)
        manifest['meshes'][key] = {'name': name, 'vertices': len(vertices),
                                 'triangles': len(indices), 'nodes': count}
        print(key, manifest['meshes'][key])
    (OUT/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    main()
