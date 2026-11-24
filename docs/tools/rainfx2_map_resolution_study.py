"""Map-pipeline evaluation (docs/RAINFX_V2_TRAIL_REVIEW3.md section 33): how fine must a WATER HEIGHT MAP be to carry the
visor's water forms, if the map stores continuous height (not a footprint mask) and is read bicubic (as a lens would)?
Features (reference 0.0125 mm): spherical caps r = 0.15 / 0.3 / 0.6 / 1.2 / 2.4 mm (60 deg), rivulets of half-width 0.15 / 0.3 /
0.6 mm (circular section, 25 deg edges), a film sheet 30 um with a soft edge. The map at step s = box average of the reference,
reconstructed by cubic B-spline interpolation. Reported per feature: angle error in the body (h > 30 % of its max), the rim
angle (contact angle seen at the outer 10 % of the radius) and the contact-line shift (where h crosses 1 um).
usage: python rainfx2_map_resolution_study.py
"""
import numpy as np
from scipy import ndimage

REF = 0.0125
TH, TR = np.radians(60), np.radians(25)


def cap(r, n):
    x = (np.arange(n) - n / 2 + 0.5) * REF
    X, Y = np.meshgrid(x, x); d = np.hypot(X, Y)
    Rs = r / np.sin(TH)
    return np.clip(np.sqrt(np.clip(Rs * Rs - d * d, 0, None)) - Rs * np.cos(TH), 0, None), d, r


def rivulet(hw, n):
    x = (np.arange(n) - n / 2 + 0.5) * REF
    X, Y = np.meshgrid(x, x); d = np.abs(Y)
    Rc = hw / np.sin(TR)
    return np.clip(np.sqrt(np.clip(Rc * Rc - d * d, 0, None)) - Rc * np.cos(TR), 0, None), d, hw


def film(n):
    x = (np.arange(n) - n / 2 + 0.5) * REF
    X, Y = np.meshgrid(x, x)
    w = 1.5
    return 0.03 * np.clip(1 - np.exp(-(w - np.abs(Y)) / 0.05), 0, 1) * (np.abs(Y) < w), np.abs(Y), w


def measure(H, d, R, step):
    f = int(round(step / REF))
    n = (H.shape[0] // f) * f
    Hc = H[:n, :n].reshape(n // f, f, n // f, f).mean(axis=(1, 3))
    c = ndimage.spline_filter(Hc, order=3)
    yy, xx = (np.mgrid[0:n, 0:n] + 0.5) / f - 0.5
    Hr = ndimage.map_coordinates(c, [yy, xx], order=3, prefilter=False, mode='nearest')
    Hs = H[:n, :n]; ds = d[:n, :n]
    a_ref = np.degrees(np.arctan(np.hypot(*np.gradient(Hs, REF))))
    a_map = np.degrees(np.arctan(np.hypot(*np.gradient(Hr, REF))))
    body = Hs > 0.3 * Hs.max()
    rim = (ds > 0.9 * R) & (ds < R) & (Hs > 0)
    e_body = np.abs(a_map - a_ref)[body].mean()
    rim_ref, rim_map = a_ref[rim].mean(), a_map[rim].mean()
    line = lambda h: ds[(h > 1e-3)].max() if (h > 1e-3).any() else 0
    return e_body, rim_ref, rim_map, line(Hr) - line(Hs)


n = 768
feats = [(f'cap r {r:.2f}', cap(r, n)) for r in (0.15, 0.3, 0.6, 1.2, 2.4)] + \
        [(f'rivulet hw {w:.2f}', rivulet(w, n)) for w in (0.15, 0.3, 0.6)] + [('film 30 um', film(n))]
print(f'{"feature":16s} {"step":>5s} {"body err":>8s} {"rim ref":>8s} {"rim map":>8s} {"line shift":>10s}')
for name, (H, d, R) in feats:
    for st in (0.05, 0.1, 0.15, 0.3, 0.59):
        e, rr, rm, sh = measure(H, d, R, st)
        print(f'{name:16s} {st:5.2f} {e:7.1f}d {rr:7.1f}d {rm:7.1f}d {sh * 1000:8.0f}um')
