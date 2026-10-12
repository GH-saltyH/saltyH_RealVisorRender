"""Author UV-aligned skin data textures from the supplied diffuse (Pillow + NumPy).

This is heuristic microrelief, not measured skin depth. No AI pixels are used.
Run from any directory; existing diffuse, KN5 and FBX material settings stay intact.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
TEX = ROOT / 'ModelWorks/_2_blender_f1-helmet-lando_2025championWinner/texture'
STEM = 'Driver_face_HQ'
PROFILE = {
    'ksAmbient': 0.08, 'ksDiffuse': 0.25,
    'ksSpecular': 0.25, 'ksSpecularEXP': 120,
    'ksEmissive': 0, 'ksAlphaRef': 0,
    'fresnelC': 0.028, 'fresnelEXP': 5, 'fresnelMaxLevel': 0.04,
    'nmObjectSpace': 0, 'isAdditive': 0, 'useDetail': 0,
    'detailUVMultiplier': 1, 'shadowBiasMult': 0,
    'damageZones': 0, 'dirt': 0, 'sunSpecular': 0, 'sunSpecularEXP': 0,
}


def blur(a, radius):
    # Pillow GaussianBlur supports L, not F; quantization is explicit.
    im = Image.fromarray(np.uint8(np.clip(np.rint(a), 0, 255)))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32)


def encode_normal(n):
    n = n / np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-8)
    return np.uint8(np.clip(np.rint(n * 127.5 + 127.5), 0, 255))


def write_dds(path, rgb, normal=False):
    """Legacy RGBA8 UNORM DDS: no sRGB transform, full chain, normalized normals.

    Use uncompressed RGB normals to preserve shallow slopes (no BC artifacts).
    Float mip filtering avoids accumulating 8-bit rounding at every mip.
    """
    h, w = rgb.shape[:2]
    count = int(np.floor(np.log2(max(w, h)))) + 1
    header = [124, 0x2100F, h, w, w * 4, 0, count] + [0] * 11
    header += [32, 0x41, 0, 32, 0xFF, 0xFF00, 0xFF0000, 0xFF000000]
    header += [0x401008, 0, 0, 0, 0]
    assert len(header) == 31
    a = rgb.astype(np.float32)
    # Exact 128 midpoint keeps a flat patch flat through normal mip reduction.
    if normal:
        a = (a - 128) / 127
        a = a / np.maximum(np.linalg.norm(a, axis=-1, keepdims=True), 1e-8)
    with path.open('wb') as f:
        f.write(b'DDS ' + struct.pack('<31I', *header))
        for level in range(count):
            if normal:
                n = a / np.maximum(np.linalg.norm(a, axis=-1, keepdims=True), 1e-8)
                encoded = np.uint8(np.clip(np.rint(n * 127 + 128), 0, 255))
                if level == 0:
                    encoded = rgb  # Base DDS pixels match PNG exactly.
            else:
                encoded = np.uint8(np.clip(np.rint(a), 0, 255))
            rgba = np.concatenate((encoded, np.full((*encoded.shape[:2], 1), 255, np.uint8)), axis=2)
            f.write(rgba.tobytes())
            if level + 1 < count:
                size = (max(1, a.shape[1] // 2), max(1, a.shape[0] // 2))
                a = np.stack([np.asarray(Image.fromarray(a[..., c]).resize(size, Image.Resampling.BOX))
                              for c in range(3)], axis=-1)
    return count


def material_ini(path, version):
    lines = ['; Standalone ksEditor material template. Copy this material block into',
             '; the NEW model FBX.ini using that model\'s mtHQFACE material index.',
             '; MATERIAL_0 here is a placeholder, not the old model\'s index.',
             '[MATERIAL_0]', 'NAME=mtHQFACE', 'SHADER=ksPerPixelMultiMap',
             'ALPHABLEND=0', 'ALPHATEST=0', 'DEPTHMODE=0', f'VARCOUNT={len(PROFILE)}']
    for i, (name, value) in enumerate(PROFILE.items()):
        lines += [f'VAR_{i}_NAME={name}', f'VAR_{i}_FLOAT1={value}',
                  f'VAR_{i}_FLOAT2=0,0', f'VAR_{i}_FLOAT3=0,0,0', f'VAR_{i}_FLOAT4=0,0,0,0']
    resources = [('txDiffuse', f'{STEM}_diff.png'),
                 ('txNormal', f'{STEM}_txNormal_skin_sweat_DX_{version}.dds'),
                 ('txMaps', f'{STEM}_txMaps_skin_sweat_{version}.dds'),
                 ('txDetail', 'NULL.dds')]
    lines.append('RESCOUNT=4')
    for i, (name, texture) in enumerate(resources):
        lines += [f'RES_{i}_NAME={name}', f'RES_{i}_SLOT={i}', f'RES_{i}_TEXTURE={texture}']
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def verify_dds(path, expected):
    blob = path.read_bytes()
    hdr = struct.unpack_from('<31I', blob, 4)
    h, w, count = hdr[2], hdr[3], hdr[6]
    assert blob[:4] == b'DDS ' and (w, h) == (expected.shape[1], expected.shape[0])
    assert count == 13 and hdr[18:26] == (32, 0x41, 0, 32, 0xFF, 0xFF00, 0xFF0000, 0xFF000000)
    pos = 128
    for level in range(count):
        pixels = np.frombuffer(blob, np.uint8, count=w*h*4, offset=pos).reshape(h, w, 4)
        assert np.all(pixels[..., 3] == 255)
        if level == 0:
            assert np.array_equal(pixels[..., :3], expected)
        pos += w*h*4
        w, h = max(1, w//2), max(1, h//2)
    assert pos == len(blob)
    with Image.open(path) as im:
        assert np.array_equal(np.asarray(im.convert('RGB')), expected)
    return {'mip_count': count, 'bytes': len(blob), 'png_base_pixels_match': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=TEX / f'{STEM}_diff.png')
    parser.add_argument('--output-dir', type=Path, default=TEX)
    parser.add_argument('--version', default='v1')
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    source_hash = hashlib.sha256(args.source.read_bytes()).hexdigest()
    source = Image.open(args.source).convert('RGB')
    assert source.size == (4096, 2048), 'Masks are calibrated to this specific 2:1 atlas.'
    rgb = np.asarray(source, dtype=np.float32)
    h, w = rgb.shape[:2]
    yy, xx = np.mgrid[:h, :w].astype(np.float32)
    xx /= w; yy /= h

    def region(cx, cy, sx, sy):
        return np.exp(-0.5 * (((xx-cx)/sx)**2 + ((yy-cy)/sy)**2))

    lum = rgb @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    island_im = Image.fromarray(np.uint8(rgb.max(axis=2) > 8) * 255)
    island_im = island_im.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))
    island = np.asarray(island_im) > 0
    # Suppress black-background silhouette gradients within the island boundary.
    inner = island_im.filter(ImageFilter.MinFilter(17)).filter(ImageFilter.GaussianBlur(12))
    edge = np.asarray(inner, dtype=np.float32) / 255 * island
    eyes = np.maximum(region(.302, .444, .059, .019), region(.698, .444, .059, .019))
    eyes = np.clip(eyes*2, 0, 1)
    brows = np.maximum(region(.300, .335, .10, .029), region(.700, .335, .10, .029))
    brows *= np.clip((105 - lum)/65, 0, 1)
    nostrils = np.maximum(region(.433, .733, .028, .017), region(.564, .733, .028, .017))
    nostrils *= np.clip((90 - lum)/55, 0, 1)
    lips = region(.500, .886, .135, .024)
    nose = np.maximum(region(.501, .660, .049, .043), .62*region(.501, .525, .026, .104))
    forehead = region(.500, .205, .24, .135)

    maps = np.empty_like(rgb); maps[:] = (64, 55, 4)
    # Region-based material parameters: photographed shadows are not roughness.
    def mix(target, weight):
        nonlocal maps
        weight = np.clip(weight, 0, 1)[..., None]
        maps = maps*(1-weight) + np.array(target, np.float32)*weight
    mix((85, 90, 6), forehead)
    mix((145, 165, 10), nose)
    mix((90, 95, 5), lips)
    mix((20, 32, 0), brows)
    mix((14, 24, 0), nostrils)
    mix((55, 85, 4), eyes)
    fine = np.clip((blur(lum, 1.3) - blur(lum, 6.0))*.18, -3, 3)
    fine *= edge*(1-eyes)*(1-.6*nose)
    maps[..., 0] += fine
    maps[..., 1] += fine*.7
    maps[..., 2] = np.clip(maps[..., 2], 0, 12)
    # Analytic material field continues through padding; no black outside-UV map.
    maps = np.uint8(np.clip(np.rint(maps), 0, 255))

    height = (blur(lum, 1.3) - blur(lum, 6.0)) / np.maximum(blur(lum, 18), 48)
    height *= edge*(1-eyes)*(1-.6*nose)*(1-.25*forehead)*(1-.8*nostrils)
    dy, dx = np.gradient(height)
    q = float(np.quantile(np.abs(np.stack((dx[island], dy[island]))), .95))
    gain = .038/max(q, 1e-6)
    # DX green: raster +Y/down derivative; GL variant has reversed tangent Y.
    nx = np.clip(-dx*gain, -.09, .09)*edge*(1-eyes)
    ny = np.clip(dy*gain, -.09, .09)*edge*(1-eyes)
    normals = encode_normal(np.stack((nx, ny, np.ones_like(nx)), axis=-1))
    normals[~island] = (128, 128, 255)
    gl = encode_normal(np.stack((nx, -ny, np.ones_like(nx)), axis=-1))
    gl[~island] = (128, 128, 255)
    map_name = f'{STEM}_txMaps_skin_sweat_{args.version}'
    normal_name = f'{STEM}_txNormal_skin_sweat_DX_{args.version}'
    paths = []
    for name, arr, is_normal in [(map_name, maps, False), (normal_name, normals, True)]:
        png = args.output_dir / f'{name}.png'
        Image.fromarray(arr).save(png)
        assert np.array_equal(np.asarray(Image.open(png)), arr)
        dds = args.output_dir / f'{name}.dds'
        write_dds(dds, arr, is_normal)
        paths += [png, dds]
    gl_path = args.output_dir / f'{STEM}_txNormal_skin_sweat_GL_{args.version}.png'
    Image.fromarray(gl).save(gl_path); paths.append(gl_path)
    ini = args.output_dir / f'{STEM}_skin_sweat_{args.version}.material.ini'
    material_ini(ini, args.version); paths.append(ini)

    preview = Image.new('RGB', (1536, 864), (25, 25, 25))
    draw = ImageDraw.Draw(preview)
    magnified = np.uint8(np.clip(128+(normals.astype(np.float32)-128)*4, 0, 255))
    tiles = [('Original diffuse (unchanged)', np.uint8(rgb)), ('txMaps: R spec / G gloss / B reflection', maps),
             ('R: specular strength', np.repeat(maps[..., 0:1], 3, axis=2)),
             ('G: specular exponent multiplier', np.repeat(maps[..., 1:2], 3, axis=2)),
             ('B: reflection (display amplified 12x)', np.repeat(np.minimum(maps[..., 2:3].astype(np.uint16)*12, 255).astype(np.uint8), 3, axis=2)),
             ('DX normal (RG display amplified 4x)', magnified)]
    for i, (label, arr) in enumerate(tiles):
        x, y = (i%2)*768, (i//2)*288
        draw.text((x+12, y+9), label, fill=(235, 235, 235))
        preview.paste(Image.fromarray(arr).resize((768, 256), Image.Resampling.LANCZOS), (x, y+30))
    preview_path = args.output_dir / f'{STEM}_skin_sweat_{args.version}_preview.jpg'
    preview.save(preview_path, quality=94); paths.append(preview_path)

    decoded = normals.astype(np.float32)*2/255-1
    norm_error = float(np.max(np.abs(np.linalg.norm(decoded, axis=-1)-1)))
    assert norm_error < .006
    assert np.all(normals[~island] == (128, 128, 255))
    assert maps[..., 2].max() <= 12 and maps[..., 0].min() >= 10
    assert hashlib.sha256(args.source.read_bytes()).hexdigest() == source_hash
    region_values = {}
    for name, cx, cy in [('cheek', .23, .68), ('forehead', .5, .205), ('nose_tip', .501, .66)]:
        values = maps[int(cy*h), int(cx*w)].tolist()
        region_values[name] = {'RGB_u8': values, 'specular_strength': PROFILE['ksSpecular']*values[0]/255,
                               'specular_exponent': PROFILE['ksSpecularEXP']*values[1]/255+1}
    manifest = {
        'source': str(args.source), 'source_sha256': source_hash, 'dimensions': [w, h],
        'workflow': 'User-authorized deterministic Python. AI drafts are not used in final data.',
        'channel_encoding': {'R': 'specular strength', 'G': 'specular exponent multiplier', 'B': 'environment reflection'},
        'normal_encoding': 'tangent space, DX/down-positive green derivative; GL comparison PNG provided',
        'normal_method': 'diffuse luminance bandpass 1.3-6 px / local luminance; no macro depth reconstruction',
        'normal_slope_gain': gain, 'normal_max_component': .09, 'normal_length_max_error_u8': norm_error,
        'material_properties': PROFILE, 'sampled_regions': region_values,
        'maps_min': maps.min(axis=(0, 1)).tolist(), 'maps_max': maps.max(axis=(0, 1)).tolist(),
        'normal_min': normals.min(axis=(0, 1)).tolist(), 'normal_max': normals.max(axis=(0, 1)).tolist(),
        'dds': {name: verify_dds(args.output_dir / f'{name}.dds', arr)
                for name, arr in [(map_name, maps), (normal_name, normals)]},
        'outputs': [{'path': str(p), 'bytes': p.stat().st_size, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
                    for p in paths],
    }
    manifest_path = args.output_dir / f'{STEM}_skin_sweat_{args.version}.json'
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: manifest[k] for k in ['dimensions', 'sampled_regions', 'maps_min', 'maps_max',
                                             'normal_min', 'normal_max', 'normal_length_max_error_u8', 'dds']}, indent=2))
    print(f'Manifest: {manifest_path}')


if __name__ == '__main__':
    main()
