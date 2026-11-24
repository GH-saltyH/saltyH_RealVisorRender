"""Does the drop's shading (dark crescent / bright core) emerge from physical refraction alone, and how much surface
fidelity does that need? (docs/RAINFX_V2_TRAIL_REVIEW3.md section 34)
Same physical lens for every case (visor r2DropLens: normal incidence, exit through the water surface, n 1.333, scene at
infinity, TIR -> dark interior), no crescent term. Surfaces: exact spherical caps (r 0.3 / 0.6 / 1.2 mm, 60 deg) and a teardrop
(head + tail, B 0.05 capillary solution of section 32), and the same surfaces carried by a height map of 0.05 / 0.15 / 0.30 mm
(box average, bicubic read). Measures per drop: share of its area that is dark (luma < 0.25: TIR or looking at the ground)
and the luma contrast inside the drop (p95 - p5).
usage: python rainfx2_physical_shading_study.py [out.png]
"""
import sys
import numpy as np
from scipy import ndimage
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

REF = 0.0125
TH = np.radians(60)
N = 1.333


def bg(ny, nx):                                           # sky above, dark ground below, some structure (as the visor sees it)
    yy, xx = np.mgrid[0:ny, 0:nx] / np.array([ny, nx])[:, None, None]
    m = 1 / (1 + np.exp(-(yy - 0.5) * 30))
    img = 0.72 * (1 - m) + 0.14 * m
    img[(np.abs(xx * 12 % 1 - 0.5) < 0.03) & (yy < 0.5)] = 0.35
    img[np.abs(yy - 0.7) < 0.01] = 0.8
    return ndimage.gaussian_filter(img, 1.0)


def cap(r, n):
    x = (np.arange(n) - n / 2 + 0.5) * REF
    X, Y = np.meshgrid(x, x); d = np.hypot(X, Y)
    Rs = r / np.sin(TH)
    return np.clip(np.sqrt(np.clip(Rs * Rs - d * d, 0, None)) - Rs * np.cos(TH), 0, None)


def carry(H, step):
    if step <= REF: return H
    f = int(round(step / REF)); n = (H.shape[0] // f) * f
    Hc = H[:n, :n].reshape(n // f, f, n // f, f).mean(axis=(1, 3))
    c = ndimage.spline_filter(Hc, order=3)
    yy, xx = (np.mgrid[0:H.shape[0], 0:H.shape[1]] + 0.5) / f - 0.5
    return np.clip(ndimage.map_coordinates(c, [yy, xx], order=3, prefilter=False, mode='nearest'), 0, None)


def shade(H, K):
    gy, gx = np.gradient(H, REF)
    s = np.hypot(gx, gy); al = np.arctan(s)
    sn = N * np.sin(al)
    tir = sn >= 1
    dev = np.where(tir, 0, np.arcsin(np.clip(sn, 0, 1)) - al)
    ux, uy = -gx / np.maximum(s, 1e-9), -gy / np.maximum(s, 1e-9)       # convex lens: rays bend toward the centre (uphill)
    B = bg(4 * H.shape[0], 4 * H.shape[1])
    cy, cx = np.mgrid[0:H.shape[0], 0:H.shape[1]] + np.array([1.5 * H.shape[0], 1.5 * H.shape[1]])[:, None, None]
    sy, sx = cy - K * np.tan(dev) * uy, cx - K * np.tan(dev) * ux
    img = ndimage.map_coordinates(B, [sy, sx], order=1, mode='nearest')
    img = np.where(tir, 0.35 * 0.14, img)                               # TIR: light from the car interior
    return img, H > 1e-4


n = 320
K = 6000.0                                                              # px of the scene per radian (far scene)
cases = [('cap r 0.30', cap(0.3, n)), ('cap r 0.60', cap(0.6, n)), ('cap r 1.20', cap(1.2, 2 * n))]
try:
    sys.path.insert(0, __file__.rsplit('/', 1)[0])
    import rainfx2_surface_options_study as S                           # the B 0.05 teardrop of section 32
    T = S.cases[3][1]
    f = int(round(0.025 / REF))
    T = ndimage.zoom(T, 0.025 / REF, order=1)
    cases.append(('teardrop (B 0.05)', T))
except Exception as e:
    print('teardrop skipped:', e)
steps = (REF, 0.05, 0.15, 0.30)
fig, ax = plt.subplots(len(cases), len(steps), figsize=(4 * len(steps), 4 * len(cases)))
print(f'{"surface":18s} ' + ' '.join(f'{("exact" if s <= REF else f"map {s:.2f}"):>18s}' for s in steps))
for i, (name, H) in enumerate(cases):
    row = []
    for j, st in enumerate(steps):
        img, m = shade(carry(H, st), K)
        dark = (img[m] < 0.25).mean(); con = np.percentile(img[m], 95) - np.percentile(img[m], 5)
        row.append(f'dark {dark * 100:4.0f}% c {con:4.2f}')
        ax[i, j].imshow(np.where(m, img, 0.5), cmap='gray', vmin=0, vmax=0.8); ax[i, j].axis('off')
        ax[i, j].set_title(f'{name}, {"exact" if st <= REF else f"map {st:.2f} mm"}', fontsize=9)
    print(f'{name:18s} ' + ' '.join(f'{r:>18s}' for r in row))
plt.tight_layout(); plt.savefig(sys.argv[1] if len(sys.argv) > 1 else 'rainfx2_physical_shading_study.png', dpi=70)
