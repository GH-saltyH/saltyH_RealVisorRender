"""Numerical txMaps for supplied Alcantara diffuse/normal, native MultiMap.

UV layout is read from BODY_FABRIC and visually checked against intact normal
microtexture islands. Input DDS and existing model/materials are never modified.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from build_e1_housing_bvh import MODEL, mesh
from build_face_skin_textures import ROOT, TEX, PROFILE as FACE_PROFILE, write_dds


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def blur(a, radius):
    return np.asarray(Image.fromarray(np.uint8(np.clip(np.rint(a), 0, 255)))
                      .filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32)


def standardized(a, mask):
    values = a[mask]
    center = float(np.median(values))
    scale = max(float(np.std(values)), 1e-3)
    return np.clip((a-center)/scale, -2, 2)/2


def verify_dds(path, expected):
    data = path.read_bytes()
    header = struct.unpack_from('<31I', data, 4)
    h, w, count = header[2], header[3], header[6]
    assert data[:4] == b'DDS ' and (w, h) == (2048, 2048) and count == 12
    assert header[18:26] == (32, 0x41, 0, 32, 0xFF, 0xFF00, 0xFF0000, 0xFF000000)
    offset = 128
    for level in range(count):
        pixels = np.frombuffer(data, np.uint8, count=h*w*4, offset=offset).reshape(h, w, 4)
        assert np.all(pixels[..., 3] == 255)
        assert pixels[..., 2].max() <= 6
        if level == 0:
            assert np.array_equal(pixels[..., :3], expected)
        offset += w*h*4
        h, w = max(1, h//2), max(1, w//2)
    assert offset == len(data)
    assert np.array_equal(np.asarray(Image.open(path).convert('RGB')), expected)
    return {'dimensions': [2048, 2048], 'mip_levels': count, 'bytes': len(data), 'base_pixels_match_png': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', type=Path, default=MODEL)
    parser.add_argument('--output-dir', type=Path, default=TEX)
    parser.add_argument('--version', default='v1')
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    diffuse_path = TEX / 'BODY_INT_FABRIC_2K_txDiff.dds'
    normal_path = TEX / 'BODY_INT_FABRIC_4K_txNormal.dds'
    inputs = [diffuse_path, normal_path, args.model]
    before = {str(p): sha(p) for p in inputs}
    diffuse = Image.open(diffuse_path).convert('RGB')
    normal = Image.open(normal_path).convert('RGB')
    assert diffuse.size == (2048, 2048) and normal.size == (4096, 4096)
    size = 2048
    vertices, triangles = mesh(args.model.read_bytes(), 'BODY_FABRIC')
    uv = vertices[:, 6:8].copy()
    # Stored V is [-1,0]; repeat sampling maps this to [0,1]. Keeping the upper
    # boundary at 1 (instead of modulo 0) avoids a triangle across the atlas.
    assert uv[:, 0].min() > -.001 and uv[:, 0].max() < 1.001
    assert uv[:, 1].min() >= -1.001 and uv[:, 1].max() <= .001
    uv[:, 1] += 1
    uv *= size
    mask_im = Image.new('L', (size, size))
    draw = ImageDraw.Draw(mask_im)
    for tri in triangles:
        draw.polygon([tuple(p) for p in uv[tri]], fill=255)
    mask = np.asarray(mask_im) > 0
    assert .35 < mask.mean() < .8
    # Variation tapers to an ordinary fabric value at boundaries; the padding
    # never inherits the radial stretched normals or black/zero specular seams.
    inner = mask_im.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(2))
    weight = np.asarray(inner, dtype=np.float32)/255*mask
    d = np.asarray(diffuse, dtype=np.float32)
    n = np.asarray(normal.resize((size, size), Image.Resampling.BOX), dtype=np.float32)
    lum = d @ np.array([.2126, .7152, .0722], np.float32)
    micro = standardized(blur(lum, .65)-blur(lum, 3), mask)
    nap = standardized(blur(lum, 10)-blur(lum, 42), mask)
    # Local RG variance represents fiber disturbance, not view-dependent N.Z.
    energy = np.zeros((size, size), np.float32)
    for c in range(2):
        residual = n[..., c]-blur(n[..., c], 3)
        energy += residual*residual
    energy = np.sqrt(energy/2)
    fuzz = standardized(blur(np.minimum(energy, 40)*5, 2)/5, mask)
    base = np.array([32, 64, 3], np.float32)
    maps = np.empty_like(d); maps[:] = base
    maps[..., 0] += (7*micro+4*nap+3*fuzz)*weight
    maps[..., 1] += (5*micro+3*nap-8*fuzz)*weight
    maps[..., 2] += (1*nap+.8*fuzz)*weight
    maps = np.uint8(np.clip(np.rint(maps), 0, 255))
    assert maps[..., 0].min() >= 18 and maps[..., 0].max() <= 46
    assert maps[..., 1].min() >= 48 and maps[..., 1].max() <= 80
    assert maps[..., 2].max() <= 6
    assert np.all(maps[~mask] == (32, 64, 3))

    stem = f'BODY_INT_FABRIC_2K_txMaps_alcantara_{args.version}'
    png = args.output_dir / f'{stem}.png'
    dds = args.output_dir / f'{stem}.dds'
    Image.fromarray(maps).save(png)
    assert np.array_equal(np.asarray(Image.open(png)), maps)
    write_dds(dds, maps)
    mask_path = args.output_dir / f'BODY_INT_FABRIC_2K_UV_alcantara_{args.version}.png'
    mask_im.save(mask_path)

    props = dict(FACE_PROFILE)
    props.update(ksAmbient=.05, ksDiffuse=.30, ksSpecular=.35, ksSpecularEXP=40,
                 fresnelC=.02, fresnelEXP=3, fresnelMaxLevel=.12)
    ini = args.output_dir / f'BODY_INT_FABRIC_alcantara_{args.version}.material.ini'
    lines = ['; Standalone template. Use the new model\'s mtBODY_FABRIC material index.',
             '; MATERIAL_0 is a placeholder. txDetail disabled to keep the supplied diffuse.',
             '[MATERIAL_0]', 'NAME=mtBODY_FABRIC', 'SHADER=ksPerPixelMultiMap',
             'ALPHABLEND=0', 'ALPHATEST=0', 'DEPTHMODE=0', f'VARCOUNT={len(props)}']
    for i, (name, value) in enumerate(props.items()):
        lines += [f'VAR_{i}_NAME={name}', f'VAR_{i}_FLOAT1={value}', f'VAR_{i}_FLOAT2=0,0',
                  f'VAR_{i}_FLOAT3=0,0,0', f'VAR_{i}_FLOAT4=0,0,0,0']
    lines.append('RESCOUNT=4')
    for i, (name, filename) in enumerate([('txDiffuse', diffuse_path.name), ('txNormal', normal_path.name),
                                         ('txMaps', dds.name), ('txDetail', 'NULL.dds')]):
        lines += [f'RES_{i}_NAME={name}', f'RES_{i}_SLOT={i}', f'RES_{i}_TEXTURE={filename}']
    ini.write_text('\n'.join(lines)+'\n', encoding='utf-8')

    # Neutral illumination demonstration: directly supplied normals, a fixed
    # light and simplified Blinn-Phong. It is NOT a ksEditor/game screenshot.
    vec = n*2/255-1
    vec /= np.maximum(np.linalg.norm(vec, axis=2, keepdims=True), 1e-6)
    light = np.array([.55, -.25, .797], np.float32); light /= np.linalg.norm(light)
    half = light+np.array([0, 0, 1], np.float32); half /= np.linalg.norm(half)
    ndl = np.maximum(vec @ light, 0)
    ndh = np.maximum(vec @ half, 0)
    exp = maps[..., 1]/255*props['ksSpecularEXP']+1
    spec = np.power(ndh, exp)*maps[..., 0]/255*props['ksSpecular']
    color = np.power(d/255, 2.2)*(.15+.85*ndl[..., None])+spec[..., None]
    shade = np.uint8(np.clip(np.power(np.maximum(color, 0), 1/2.2)*255, 0, 255))
    shade[~mask] = (28, 28, 28)
    overlay = np.uint8(n*.65 + np.stack((mask*255, mask*0, mask*0),axis=-1)*.35)
    preview = Image.new('RGB', (1536, 1140), (24, 24, 24)); draw = ImageDraw.Draw(preview)
    enhanced = np.uint8(np.clip(128+(maps.astype(np.float32)-base)*7, 0, 255))
    tiles = [('Source diffuse (unchanged)', np.uint8(d)), ('Native txMaps RGB (actual data)', maps),
             ('Normal + exact BODY_FABRIC UV overlay', overlay), ('Map variation (display amplified 7x)', enhanced),
             ('UV islands / padding', np.repeat(np.asarray(mask_im)[..., None], 3, axis=2)),
             ('Approximate fixed-light preview (not game render)', shade)]
    for i, (label, arr) in enumerate(tiles):
        x, y = (i%3)*512, (i//3)*570
        draw.text((x+8, y+12), label, fill=(235,235,235))
        preview.paste(Image.fromarray(arr).resize((512,512), Image.Resampling.LANCZOS), (x,y+40))
    preview_path = args.output_dir / f'BODY_INT_FABRIC_alcantara_{args.version}_preview.jpg'
    preview.save(preview_path, quality=94)

    for p in inputs:
        assert sha(p) == before[str(p)], f'Input changed: {p}'
    manifest = {'workflow': 'Deterministic NumPy/Pillow under existing user authorization; no image_gen pixels.',
                'inputs_sha256': before, 'input_sizes': {'diffuse': list(diffuse.size), 'normal': list(normal.size)},
                'mesh': 'BODY_FABRIC', 'mesh_vertices': len(vertices), 'mesh_triangles': len(triangles),
                'uv_conversion': '(stored U, stored V + 1); verified against normal microtexture islands',
                'uv_coverage_fraction': float(mask.mean()), 'padding_RGB': base.astype(int).tolist(),
                'maps_channels': ['specular intensity', 'gloss/exponent multiplier', 'environment reflection'],
                'maps_min': maps.min(axis=(0,1)).tolist(), 'maps_max': maps.max(axis=(0,1)).tolist(),
                'maps_mean_on_uv': maps[mask].mean(axis=0).tolist(), 'recommended_properties': props,
                'dds_validation': verify_dds(dds, maps),
                'limitation': 'Native isotropic MultiMap approximation; no measured Alcantara BRDF, fiber retroreflection or anisotropic sheen lobe.',
                'sources': ['https://www.cs.cornell.edu/~srm/publications/TOG12-cloth.html',
                            'https://www.alcantara.com/the-material/',
                            'https://gitlab.com/ac-custom-shaders-patch/public/acc-shaders/-/blob/master/recreated/include_new/base/utils_ps.fx'],
                'outputs': [{'path': str(p), 'bytes': p.stat().st_size, 'sha256': sha(p)}
                            for p in [png, dds, mask_path, ini, preview_path]]}
    manifest_path = args.output_dir / f'BODY_INT_FABRIC_alcantara_{args.version}.json'
    manifest_path.write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k: manifest[k] for k in ['uv_coverage_fraction', 'maps_min', 'maps_max',
                                             'maps_mean_on_uv', 'dds_validation']}, indent=2))
    print(f'Manifest: {manifest_path}')


if __name__ == '__main__':
    main()
