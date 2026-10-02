"""Smear mask texture template, contract v7 (docs/RAINFX_SMEAR_MASK.md).

R = reveal order (low first), smooth low-frequency blobs.
G = class patch map: irregular cellular patches, each painted at one class
    level (k + 0.5) / N, sharp-ish borders (~1.5 px blur), plus a sparse
    speckle of other levels (reads as noise from far away).
    Levels are written for G processing CONTRAST 1, PIVOT 0.5, GAMMA 1
    (identity), or pre-inverted for a given contrast/pivot with --contrast.
B = 0 (unused), A = 255. The whole texture tiles seamlessly (wrap everywhere),
so it can be repeated with SMEAR_R_TILING / SMEAR_G_TILING (v8).

usage: python3 smear_v7_template.py out.png [--size 2048] [--classes 5]
       [--cell 48] [--contrast 1.0 --pivot 0.5] [--seed 7]
"""
import argparse
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

ap = argparse.ArgumentParser()
ap.add_argument('out')
ap.add_argument('--size', type=int, default=2048)
ap.add_argument('--classes', type=int, default=5)
ap.add_argument('--cell', type=float, default=48.0, help='mean patch size, texels')
ap.add_argument('--warp', type=float, default=1.4, help='edge warp, x cell')
ap.add_argument('--speckle', type=float, default=0.04, help='share of speckle texels')
ap.add_argument('--blur', type=float, default=1.5, help='G border blur, texels')
ap.add_argument('--contrast', type=float, default=1.0)
ap.add_argument('--pivot', type=float, default=0.5)
ap.add_argument('--seed', type=int, default=7)
a = ap.parse_args()
rng = np.random.default_rng(a.seed)
S, N = a.size, a.classes


def fbm(shape, scale, octaves=4):
    """Isotropic fbm: gaussian-filtered white noise per octave (wraps)."""
    out = np.zeros(shape)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        s = max(scale / (2 ** o), 1.0)
        n = ndimage.gaussian_filter(rng.standard_normal(shape), s * 0.5,
                                    mode='wrap')
        n /= n.std() + 1e-9
        out += amp * n
        tot += amp
        amp *= 0.5
    out /= tot
    return (out - out.min()) / (out.max() - out.min())


# R: smooth reveal order (big blobs), equalised to a uniform 0..1 spread.
r = fbm((S, S), S / 5.0, 4)
r = np.argsort(np.argsort(r.ravel())).reshape(S, S) / (S * S - 1.0)

# G: cellular patches with warped borders.
yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
wx = (fbm((S, S), a.cell * 1.5, 4) - 0.5) * a.cell * a.warp * 2.0
wy = (fbm((S, S), a.cell * 1.5, 4) - 0.5) * a.cell * a.warp * 2.0
npts = int((S / a.cell) ** 2)
pts = rng.uniform(0, S, (npts, 2))
tree = cKDTree(pts, boxsize=S)
q = np.stack([(yy + wy) % S, (xx + wx) % S], -1).reshape(-1, 2)
_, idx = tree.query(q)
cls = rng.integers(0, N, npts)[idx].reshape(S, S)
# Speckle: isolated texels / tiny clusters of another class.
sp = rng.random((S, S)) < a.speckle
sp = ndimage.binary_dilation(sp, iterations=1) & (rng.random((S, S)) < 0.5)
cls = np.where(sp, rng.integers(0, N, (S, S)), cls)

gp = (cls + 0.5) / N                       # wanted G' (class centre)
g = a.pivot + (gp - a.pivot) / a.contrast  # pre-invert the G processing
g = ndimage.gaussian_filter(g, a.blur, mode="wrap") if a.blur > 0 else g

img = np.zeros((S, S, 4), np.uint8)
img[..., 0] = np.clip(r * 255 + 0.5, 0, 255)
img[..., 1] = np.clip(g * 255 + 0.5, 0, 255)
img[..., 3] = 255
Image.fromarray(img, 'RGBA').save(a.out)
Image.fromarray(img[..., 1]).save(a.out.replace('.png', '_G.png'))
Image.fromarray(img[..., 0]).save(a.out.replace('.png', '_R.png'))
lv = [round(float(a.pivot + ((k + 0.5) / N - a.pivot) / a.contrast) * 255) for k in range(N)]
print('G levels (8-bit):', lv)
