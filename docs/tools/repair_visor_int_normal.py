"""Rebuild the renewed visor's raised rim as one smooth, integrable height field.

Only Pillow and NumPy are required. The source RGBA/UV footprint is preserved;
the source file is never overwritten. Image-Y normal polarity is measured from
the user's lower-left reference rather than guessed from GL/DX naming.
"""
from pathlib import Path
import hashlib
import json
import math
import struct
import zlib
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
TEX = ROOT / 'ModelWorks/_2_blender_f1-helmet-lando_2025championWinner/texture/리뉴얼'
SOURCE = TEX / 'GLASS_INT_txNormal.png'
DEST = TEX / 'GLASS_INT_txNormal_convex_continuous_v1.png'
MASTER = TEX / 'GLASS_INT_txNormal_convex_continuous_v1_16bit.png'
QA = ROOT / 'docs/diagnostics/2026-10-11/normal-repair'


def component(mask, seed=None):
    """Four-connected component using row runs, not a pixel-sized Python queue."""
    h, w = mask.shape
    seen = np.zeros_like(mask)
    if seed is None:
        seed = tuple(np.argwhere(mask)[0])
    todo = [seed]
    while todo:
        y, x = todo.pop()
        if not mask[y, x] or seen[y, x]:
            continue
        lo = x
        while lo and mask[y, lo - 1] and not seen[y, lo - 1]:
            lo -= 1
        hi = x
        while hi + 1 < w and mask[y, hi + 1] and not seen[y, hi + 1]:
            hi += 1
        seen[y, lo:hi + 1] = True
        for yy in (y - 1, y + 1):
            if 0 <= yy < h:
                row = mask[yy, lo:hi + 1] & ~seen[yy, lo:hi + 1]
                starts = np.flatnonzero(row & ~np.r_[False, row[:-1]])
                todo.extend((yy, lo + int(xx)) for xx in starts)
    return seen


def contour(mask):
    """Subpixel marching squares on a slightly smoothed binary region."""
    field = np.asarray(Image.fromarray(mask.astype('uint8') * 255)
                       .filter(ImageFilter.GaussianBlur(1.2)), dtype=np.float32)
    level = 127.5
    b = field >= level
    cells = ((b[:-1, :-1] != b[:-1, 1:]) |
             (b[:-1, 1:] != b[1:, 1:]) |
             (b[1:, 1:] != b[1:, :-1]) |
             (b[1:, :-1] != b[:-1, :-1]))
    points, neighbours = {}, {}
    for y, x in np.argwhere(cells):
        corners = [(int(x), int(y)), (int(x + 1), int(y)),
                   (int(x + 1), int(y + 1)), (int(x), int(y + 1))]
        hits = []
        for i in range(4):
            a, c = corners[i], corners[(i + 1) % 4]
            va, vc = field[a[1], a[0]], field[c[1], c[0]]
            if (va >= level) == (vc >= level):
                continue
            key = tuple(sorted((a, c)))
            t = float((level - va) / (vc - va))
            points[key] = np.array(a) + t * (np.array(c) - a)
            hits.append(key)
        if len(hits) != 2:
            raise ValueError('Ambiguous rim boundary; inspect source geometry')
        a, c = hits
        neighbours.setdefault(a, []).append(c)
        neighbours.setdefault(c, []).append(a)
    assert all(len(v) == 2 for v in neighbours.values()), 'Contour must be closed'
    remaining = set(points)
    loops = []
    while remaining:
        first = min(remaining)
        previous, current = None, first
        loop = []
        while True:
            loop.append(points[current])
            remaining.discard(current)
            nxt = next(n for n in neighbours[current] if n != previous)
            previous, current = current, nxt
            if current == first:
                break
        loops.append(np.array(loop))
    raw = max(loops, key=len)
    closed = np.vstack((raw, raw[0]))
    arc = np.r_[0., np.cumsum(np.linalg.norm(np.diff(closed, axis=0), axis=1))]
    samples = np.linspace(0, arc[-1], math.ceil(arc[-1] / 3), endpoint=False)
    curve = np.stack([np.interp(samples, arc, closed[:, i]) for i in range(2)], axis=1)
    # Suppress the source's stitch-sized notches along the rim (18 px arc-length
    # sigma), without replacing its large-scale curved outline with a rectangle.
    weights = np.exp(-.5 * (np.arange(-18, 19) / 6.) ** 2)
    weights /= weights.sum()
    return sum(weight * np.roll(curve, shift, axis=0)
               for shift, weight in zip(range(-18, 19), weights))


def polygon_mask(shape, curve):
    """Classify pixel centres against the SAME smooth curve used for distance."""
    result = np.zeros(shape, dtype=bool)
    a, b = curve, np.roll(curve, -1, axis=0)
    for y in range(shape[0]):
        crossing = (a[:, 1] > y) != (b[:, 1] > y)
        aa, bb = a[crossing], b[crossing]
        xs = np.sort(aa[:, 0] + (y-aa[:, 1]) * (bb[:, 0]-aa[:, 0]) / (bb[:, 1]-aa[:, 1]))
        for lo, hi in zip(xs[::2], xs[1::2]):
            result[y, max(0, math.ceil(lo)):min(shape[1], math.ceil(hi))] = True
    return result


def distance_to_curve(shape, curve, reach=80):
    """Exact point-to-segment distances near the rim, with no raster stair steps."""
    result = np.full(shape, float(reach), dtype=np.float32)
    h, w = shape
    for a, b in zip(curve, np.roll(curve, -1, axis=0)):
        lo = np.maximum(np.floor(np.minimum(a, b) - reach).astype(int), 0)
        hi = np.minimum(np.ceil(np.maximum(a, b) + reach).astype(int) + 1, (w, h))
        xx = np.arange(lo[0], hi[0], dtype=np.float32)[None, :]
        yy = np.arange(lo[1], hi[1], dtype=np.float32)[:, None]
        delta = b - a
        t = np.clip(((xx - a[0]) * delta[0] + (yy - a[1]) * delta[1]) /
                    max(float(delta @ delta), 1e-12), 0, 1)
        dist = np.sqrt((xx - a[0] - t * delta[0]) ** 2 +
                       (yy - a[1] - t * delta[1]) ** 2)
        patch = result[lo[1]:hi[1], lo[0]:hi[0]]
        np.minimum(patch, dist, out=patch)
    return result


def decode(rgb):
    n = rgb.astype(np.float32) / 127.5 - 1
    return n / np.maximum(np.linalg.norm(n, axis=2, keepdims=True), 1e-8)


def save_rgba16(path, pixels):
    """Lossless 16-bit/channel PNG without an sRGB/gamma color transform tag."""
    h, w = pixels.shape[:2]
    rows = pixels.astype('>u2').view('uint8').reshape(h, w * 8)
    filtered = np.zeros((h, w * 8 + 1), dtype='uint8')
    filtered[:, 1:] = rows
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data))
    compressed = zlib.compress(filtered.tobytes(), 9)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' +
        chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 16, 6, 0, 0, 0)) +
        chunk(b'IDAT', compressed) + chunk(b'IEND', b''))
    # Verify actual file contents, not merely the array passed to the writer.
    data = path.read_bytes()
    assert data[24:26] == bytes((16, 6))
    offset, payload = 8, bytearray()
    while offset < len(data):
        size = struct.unpack('>I', data[offset:offset+4])[0]
        tag = data[offset+4:offset+8]
        content = data[offset+8:offset+8+size]
        assert zlib.crc32(tag + content) == struct.unpack('>I', data[offset+8+size:offset+12+size])[0]
        if tag == b'IDAT':
            payload.extend(content)
        offset += size + 12
    decoded = np.frombuffer(zlib.decompress(payload), dtype='uint8').reshape(h, w*8+1)
    assert np.all(decoded[:, 0] == 0)
    restored = decoded[:, 1:].copy().view('>u2').reshape(h, w, 4)
    assert np.array_equal(restored, pixels)


def main(contour_transform=None):
    QA.mkdir(parents=True, exist_ok=True)
    original = np.array(Image.open(SOURCE).convert('RGBA'))
    assert original.shape == (1024, 4096, 4)
    # Isolate the closed inner rim; preserve the outer silhouette and its details.
    x0, y0, x1, y1 = 880, 260, 3200, 950
    crop = original[y0:y1, x0:x1]
    xy_error = np.max(np.abs(crop[:, :, :2].astype(float) - (128, 127)), axis=2)
    mask = (xy_error > 5) & (crop[:, :, 3] == 255)
    closed = Image.fromarray(mask.astype('uint8') * 255).filter(ImageFilter.MaxFilter(19))
    closed = np.asarray(closed.filter(ImageFilter.MinFilter(19))) > 127
    # The central clear opening is enclosed by the rim, even where the original
    # tangent normal goes through neutral or changes discontinuously.
    inner = component(~closed, (300, 1100))
    outside = component(~closed, (0, 0))
    outer = ~outside
    ring = outer & ~inner
    assert 70000 < ring.sum() < 350000, int(ring.sum())
    inner_curve, outer_curve = contour(inner), contour(outer)
    if contour_transform is not None:
        inner_curve = contour_transform(inner_curve, 'inner')
        outer_curve = contour_transform(outer_curve, 'outer')
    inner = polygon_mask(ring.shape, inner_curve)
    outer = polygon_mask(ring.shape, outer_curve)
    ring = outer & ~inner
    di = distance_to_curve(ring.shape, inner_curve)
    do = distance_to_curve(ring.shape, outer_curve)
    di[inner] *= -1
    do[~outer] *= -1
    q = di / np.maximum(di + do, 1e-8)
    # Use the known lower-left straight portion, avoiding its broken joins.
    reference_x = range(1120, 1310, 5)
    original_n = decode(original[:, :, :3])
    profiles = []
    widths = []
    polarity = []
    t = np.linspace(0, 1, 257)
    for x in reference_x:
        z = np.flatnonzero(ring[:, x - x0])
        z = z[z > 350]
        if not len(z):
            continue
        a, b = int(z.min()) + y0, int(z.max()) + y0
        # Signed lower-left normal points inward at the inner edge and outward
        # at the outer edge. Preserve this image-channel convention.
        n = original_n[a:b + 1, x]
        radial = np.linalg.norm(n[:, :2], axis=1) / np.maximum(n[:, 2], .15)
        profile = np.interp(t, np.linspace(0, 1, len(radial)), radial)
        profiles.append(profile)
        widths.append(b - a)
        polarity.append(float(n[:max(2, len(n)//3), 1].mean()))
    assert profiles
    # Symmetric positive raised strip. Reference magnitudes are pooled to remove
    # the source's per-triangle tangential rotation and quantization noise.
    slope = np.median(profiles, axis=0)
    slope = (slope + slope[::-1]) * .5
    profile_kernel = np.exp(-.5 * (np.arange(-5, 6) / 1.3) ** 2)
    profile_kernel /= profile_kernel.sum()
    smooth = np.convolve(np.pad(slope, (5, 5), mode='edge'), profile_kernel,
                         mode='valid')
    width = float(np.median(widths))
    height_profile = np.zeros_like(t)
    for i in range(1, len(t)//2 + 1):
        height_profile[i] = height_profile[i-1] + .5 * (smooth[i-1] + smooth[i]) * width / 256
    height_profile[len(t)//2 + 1:] = height_profile[:len(t)//2][::-1]
    # Round the steep start/end of the raised strip into the neutral plane.
    hp = np.pad(height_profile, (12, 12))
    kernel = np.exp(-.5 * (np.arange(-9, 10) / 2.5) ** 2)
    kernel /= kernel.sum()
    hp = np.convolve(hp, kernel, mode='same')[12:-12]
    hp -= hp[0]
    hp = np.maximum(hp, 0)
    # A short smoothstep collar makes height AND slope vanish at both boundaries.
    collar = np.minimum(t, 1-t) / .045
    collar = np.clip(collar, 0, 1)
    hp *= collar * collar * (3 - 2 * collar)
    height = np.interp(q, t, hp).astype('float32')
    height[~ring] = 0
    spatial_kernel = np.exp(-.5 * (np.arange(-3, 4) / .8) ** 2)
    spatial_kernel /= spatial_kernel.sum()
    for axis in (0, 1):
        padded = np.pad(height, ((3, 3), (0, 0)) if axis == 0 else ((0, 0), (3, 3)))
        height = sum(weight * (padded[i:i+height.shape[0], :] if axis == 0 else
                               padded[:, i:i+height.shape[1]])
                     for i, weight in enumerate(spatial_kernel))
    dy, dx = np.gradient(height)
    # Source reference uses the same negative gradient sign for image X and Y.
    y_sign = -1 if np.median(polarity) < 0 else 1
    n = np.stack((-dx, y_sign * dy, np.ones_like(dx)), axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    encoded = np.rint((n + 1) * 127.5).clip(0, 255).astype('uint8')
    result = original.copy()
    opaque = crop[:, :, 3] == 255
    result[y0:y1, x0:x1, :3][opaque] = encoded[opaque]
    Image.fromarray(result).save(DEST)
    master = original.astype('uint16') * 257
    precise = np.rint((n + 1) * 32767.5).clip(0, 65535).astype('uint16')
    master[y0:y1, x0:x1, :3][opaque] = precise[opaque]
    save_rgba16(MASTER, master)
    assert np.array_equal(master[:, :, 3], original[:, :, 3].astype('uint16') * 257)
    Image.fromarray(np.rint(height / max(float(height.max()), 1e-8) * 65535)
                    .astype('uint16')).save(QA / 'rim_height_16bit.png')
    Image.fromarray(ring.astype('uint8') * 255).save(QA / 'rim_support.png')
    # Compare under four directional lights. These are texture-space diagnostic
    # renders, not a claim that the unchanged KN5/material has been game-tested.
    images = [original, result]
    board = Image.new('RGB', (1600, 760), '#242424')
    draw = ImageDraw.Draw(board)
    for row, img in enumerate(images):
        label = 'ORIGINAL' if row == 0 else 'CONTINUOUS CONVEX / SOURCE CHANNEL POLARITY'
        draw.text((12, row * 380 + 8), label, fill='white')
        thumb = Image.fromarray(img).convert('RGB').resize((1580, 395))
        board.paste(thumb.crop((0, 85, 1580, 365)), (10, row * 380 + 28))
        normals = decode(img[:, :, :3])
        for light_i, light in enumerate(((1,0,1),(-1,0,1),(0,1,1),(0,-1,1))):
            light = np.array(light, dtype=float) / math.sqrt(2)
            shade = np.clip(.16 + .84 * np.maximum(normals @ light, 0), 0, 1)
            gray = np.rint(shade * 255).astype('uint8')
            rgb = np.repeat(gray[:, :, None], 3, axis=2)
            rgb[img[:, :, 3] == 0] = 0
            panel = Image.fromarray(rgb[y0:y1, x0:x1]).resize((385, 114))
            board.paste(panel, (12 + 397 * light_i, row * 380 + 262))
    board.save(QA / 'comparison.png')
    # Quantized length, scalar-height integrability, and convex sign consistency.
    stored = result[y0:y1, x0:x1, :3].astype('float32') / 127.5 - 1
    lengths = np.linalg.norm(stored, axis=2)
    qy, qx = np.gradient(q)
    radial_n = n[:, :, 0] * qx + n[:, :, 1] * qy * (-y_sign)
    relevant = ring & (np.hypot(dx, dy) > .025)
    wrong_inner = relevant & (q < .45) & (radial_n >= 0)
    wrong_outer = relevant & (q > .55) & (radial_n <= 0)
    curl = np.gradient(dx, axis=0) - np.gradient(dy, axis=1)
    checks = {
        'source': str(SOURCE.relative_to(ROOT)), 'output': str(DEST.relative_to(ROOT)),
        'master': str(MASTER.relative_to(ROOT)),
        'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'output_sha256': hashlib.sha256(DEST.read_bytes()).hexdigest(),
        'resolution': [4096, 1024], 'alpha_identical': bool(np.array_equal(original[:,:,3], result[:,:,3])),
        'pixels_outside_edit_roi_identical': bool(np.array_equal(original[:y0], result[:y0]) and
            np.array_equal(original[y1:], result[y1:]) and np.array_equal(original[:,:x0], result[:,:x0]) and
            np.array_equal(original[:,x1:], result[:,x1:])),
        'reference_median_width_px': width, 'raised_height_px': float(height.max()),
        'image_y_gradient_normal_sign': y_sign, 'contour_lengths': [len(inner_curve), len(outer_curve)],
        'inner_wrong_direction_pixels': int(wrong_inner.sum()),
        'outer_wrong_direction_pixels': int(wrong_outer.sum()),
        'height_gradient_curl_max': float(np.abs(curl).max()),
        'edited_unit_length_max_error_8bit': float(np.abs(lengths[opaque] - 1).max()),
        'normal_max_tilt_degrees': float(np.degrees(np.arccos(n[:,:,2])).max()),
        'edited_unit_length_max_error_16bit': float(np.abs(np.linalg.norm(
            precise.astype(float) / 32767.5 - 1, axis=2)[opaque] - 1).max()),
    }
    (QA / 'validation.json').write_text(json.dumps(checks, indent=2, ensure_ascii=False), encoding='utf-8')
    print(json.dumps(checks, indent=2, ensure_ascii=False))
    Image.fromarray(((wrong_inner | wrong_outer)*255).astype('uint8')).save(QA / 'direction_failures.png')
    assert checks['alpha_identical'] and checks['pixels_outside_edit_roi_identical']
    assert checks['edited_unit_length_max_error_8bit'] < .008
    assert checks['edited_unit_length_max_error_16bit'] < .00003
    assert checks['height_gradient_curl_max'] < 1e-5
    assert checks['inner_wrong_direction_pixels'] == checks['outer_wrong_direction_pixels'] == 0


if __name__ == '__main__':
    main()
