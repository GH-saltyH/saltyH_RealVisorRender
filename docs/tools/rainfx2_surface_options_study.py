"""B3h game review (docs/RAINFX_V2_TRAIL_REVIEW3.md section 32): how much can option A (analytic one height field) improve, and
what does option B (a solved height map) give? One sliding head + tail (the B3h prototype's big drop), same lens shading.
  A0  B3h as in game: spherical cap + circular-arc tail section, smooth max k = 0.04 mm
  A1  same, k = 0.15 mm (wider fillet)
  A2  same, k = 0.30 mm
  B*  capillary surface on the SAME footprint: Laplace pressure is one value in connected water -> lap(h) = -p, h = 0 on the
      contact line (small-slope Young-Laplace), p from the head apex (disc: p R^2 / 4 = h_cap). Solved on grids of 0.05 (ref),
      0.15, 0.30 mm and sampled bicubic at the render pixels (a texture the visor would read).
Metric: largest change of the surface angle between neighbours (deg per 0.1 mm) on three sections along the tail (centre line,
0.35 w0, 0.6 w0 off it), inside the water but away from the contact line (H > 0.08 h_cap) -- creases / seams, not rims.
usage: python rainfx2_surface_options_study.py [out.png]
"""
import sys
import numpy as np
from scipy import ndimage, sparse
from scipy.sparse.linalg import spsolve
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
sys.path.insert(0, __file__.rsplit('/', 1)[0])
import rainfx2_heightfield_lens_proto as P

d = P.drops()[0]
x, a, b, W, Rr = P.head_x(d)
hc = d['R'] * (1 - np.cos(P.TH)) / np.sin(P.TH)
rho2 = x / 0.65
cap = np.where(rho2 < 1, hc * (np.sqrt(np.clip(1 - rho2 * np.sin(P.TH) ** 2, 0, None)) - np.cos(P.TH)) / (1 - np.cos(P.TH)), 0)
w, ht, nk, bt, on = P.tail_geom(d, W, Rr)
Rc = (w * w + ht * ht) / np.maximum(2 * ht, 1e-6)
sec = np.clip(np.where(on & (np.abs(bt) < w), np.sqrt(np.clip(Rc * Rc - bt * bt, 0, None)) - (Rc - ht), 0), 0, None)


def lse(A, B, k):                                  # game: max + k ln(1 + exp(-|A - B| / k)), only where water
    m = np.maximum(A, B); return np.where((A > 0) | (B > 0), m + k * np.log1p(np.exp(-np.abs(A - B) / k)) - k * np.log(2) * ((A > 0) & (B > 0) == 0) * 0, 0)


def surf_A(k):
    H = np.where((cap > 0) & (sec > 0), lse(cap, sec, k), np.maximum(cap, sec))
    return H


foot = (cap > 0) | (sec > 0)


def solve_B(step):
    """lap h = -p on the footprint (sampled at 'step' mm), h = 0 outside; bicubic back to the render grid."""
    f = max(int(round(step / P.PX)), 1)
    m = foot[::f, ::f]
    ny, nx = m.shape
    idx = -np.ones(m.shape, int); idx[m] = np.arange(m.sum())
    p = 4 * hc / d['R'] ** 2
    rows, cols, vals = [], [], []
    rhs = np.full(m.sum(), -p * step * step)
    for (j, i), n in np.ndenumerate(idx):
        if n < 0: continue
        rows.append(n); cols.append(n); vals.append(-4.0)
        for dj, di in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            jj, ii = j + dj, i + di
            if 0 <= jj < ny and 0 <= ii < nx and idx[jj, ii] >= 0:
                rows.append(n); cols.append(idx[jj, ii]); vals.append(1.0)
    A = sparse.csr_matrix((vals, (rows, cols)), shape=(m.sum(), m.sum()))
    h = np.zeros(m.shape); h[m] = spsolve(A, rhs)
    if f == 1: return h
    yy, xx = np.mgrid[0:foot.shape[0], 0:foot.shape[1]] / f
    hf = ndimage.map_coordinates(h, [yy, xx], order=3, mode='nearest')
    return np.where(foot, np.clip(hf, 0, None), 0)


def crease(H):
    gy, gx = np.gradient(H, P.PX); ang = np.degrees(np.arctan(np.hypot(gx, gy)))
    M = P.M; Nn = P.NRM
    w0 = W * np.sqrt(max(1 - (1 - 0.5 * min(W, Rr) / Rr) ** 2, 0))
    out = []
    for off in (0.0, 0.35 * w0, 0.6 * w0):
        s = np.arange(-d['R'] * 1.5, d['L'], 0.1)
        pts = d['p'][None] - s[:, None] * M[None] + off * Nn[None]
        jj, ii = pts[:, 1] / P.PX, pts[:, 0] / P.PX
        av = ndimage.map_coordinates(ang, [jj, ii], order=1); hv = ndimage.map_coordinates(H, [jj, ii], order=1)
        ok = hv > 0.08 * hc
        dv = np.abs(np.diff(av)); dv[~(ok[1:] & ok[:-1])] = 0
        out.append(dv.max())
    return out


cases = [('A0 game B3h (k 0.04 mm)', surf_A(0.04)), ('A1 k 0.15 mm', surf_A(0.15)), ('A2 k 0.30 mm', surf_A(0.30))]
for st in (0.05, 0.15, 0.30):
    cases.append((f'B capillary map, {st:.2f} mm texels', solve_B(st)))
ref = cases[3][1]
rows = []
for name, H in cases:
    c = crease(H)
    err = np.nanmax(np.abs(np.degrees(np.arctan(np.hypot(*np.gradient(H, P.PX)))) - np.degrees(np.arctan(np.hypot(*np.gradient(ref, P.PX)))))[(ref > 0.08 * hc)]) if name.startswith('B') else np.nan
    rows.append((name, c, err))
    print(f'{name:34s} crease (deg/0.1 mm) centre {c[0]:5.1f}  0.35w0 {c[1]:5.1f}  0.6w0 {c[2]:5.1f}   max angle err vs 0.05 mm: {err:5.1f}')
zy, zx = slice(int(2.5 / P.PX), int(12.5 / P.PX)), slice(int(1.0 / P.PX), int(11.0 / P.PX))
fig, ax = plt.subplots(2, 3, figsize=(18, 12))
for k, (name, H) in enumerate([cases[0], cases[2], cases[3], cases[4], cases[5]]):
    gy, gx = np.gradient(H, P.PX)
    g = np.stack([gx, gy], -1); g /= np.maximum(np.linalg.norm(g, axis=-1, keepdims=True), 1e-9)
    img = P.shade(H > 0, np.hypot(gx, gy), g)
    a_ = ax.ravel()[k]; a_.imshow(img[zy, zx]); a_.set_title(name); a_.axis('off')
a_ = ax.ravel()[5]
s = np.arange(-d['R'] * 1.5, d['L'], 0.025)
pts = d['p'][None] - s[:, None] * P.M[None]
for name, H in [cases[0], cases[2], cases[3]]:
    a_.plot(s, ndimage.map_coordinates(H, [pts[:, 1] / P.PX, pts[:, 0] / P.PX], order=1), label=name)
a_.set_xlabel('mm behind the head centre (centre line)'); a_.set_ylabel('height mm'); a_.legend(); a_.set_title('centre-line height')
plt.tight_layout(); plt.savefig(sys.argv[1] if len(sys.argv) > 1 else 'rainfx2_surface_options_study.png', dpi=80)


# ---- A3: analytic CAPILLARY union (one pressure per connected water): smooth union of the FOOTPRINTS (signed distance to the
# contact line, d), local inscribed radius rho (head R / tail w, blended with the same weights), and one surface curvature:
# sphere of radius Rs in the head, cylinder Rs / 2 in the rivulet (equal Laplace pressure 2 / Rs) -> h(d) = Rc (sqrt(1 - ((rho -
# d) / Rc)^2) - sqrt(1 - (rho / Rc)^2)); zero slope where d = rho (medial line) -> no crease at the junction or along the tail.
def surf_A3(kd=0.35):
    Rs = d['R'] / np.sin(P.TH)
    dh = (1 - np.sqrt(np.clip(rho2, 0, 4))) * d['R']                  # head: distance to its contact line (footprint scale)
    dt = np.where(on, w - np.abs(bt), -10.0)                         # tail: distance to its edges
    hm = np.clip(0.5 + 0.5 * (dh - dt) / kd, 0, 1)                    # polynomial smooth max of the inside distances
    D = dt * (1 - hm) + dh * hm + kd * hm * (1 - hm)
    rho = np.maximum(w, 1e-3) * (1 - hm) + d['R'] * hm
    Rc = np.maximum((Rs / 2) * (1 - hm) + Rs * hm, rho / np.sin(P.TH))   # a section never steeper than the head's contact angle
    Dc = np.clip(D, -0.3, rho)
    H = Rc * (np.sqrt(np.clip(1 - ((rho - Dc) / Rc) ** 2, 0, None)) - np.sqrt(np.clip(1 - (rho / Rc) ** 2, 0, None)))
    return np.where(D > 0, np.clip(H, 0, None), 0)


H3 = surf_A3()
c = crease(H3)
print(f'{"A3 capillary analytic union":34s} crease (deg/0.1 mm) centre {c[0]:5.1f}  0.35w0 {c[1]:5.1f}  0.6w0 {c[2]:5.1f}')
gy, gx = np.gradient(H3, P.PX)
g = np.stack([gx, gy], -1); g /= np.maximum(np.linalg.norm(g, axis=-1, keepdims=True), 1e-9)
img3 = P.shade(H3 > 0, np.hypot(gx, gy), g)
gy, gx = np.gradient(cases[0][1], P.PX)
g = np.stack([gx, gy], -1); g /= np.maximum(np.linalg.norm(g, axis=-1, keepdims=True), 1e-9)
img0 = P.shade(cases[0][1] > 0, np.hypot(gx, gy), g)
fig, ax = plt.subplots(1, 3, figsize=(18, 6))
ax[0].imshow(img0[zy, zx]); ax[0].set_title('A0 game B3h'); ax[1].imshow(img3[zy, zx]); ax[1].set_title('A3 capillary analytic union')
s = np.arange(-d['R'] * 1.5, d['L'], 0.025); pts = d['p'][None] - s[:, None] * P.M[None]
for nm, H in (('A0', cases[0][1]), ('A3', H3), ('B 0.05 mm', cases[3][1])):
    ax[2].plot(s, ndimage.map_coordinates(H, [pts[:, 1] / P.PX, pts[:, 0] / P.PX], order=1), label=nm)
ax[2].legend(); ax[2].set_title('centre-line height (mm)')
for a_ in ax[:2]: a_.axis('off')
plt.tight_layout(); plt.savefig('docs/images/rainfx2_surface_a3_proto.png', dpi=80)


# ---- A4: A0 with the tail MATCHED to the head: the neck starts at the head-cap height where it leaves the head (instead of a
# fixed 0.6 h_cap) and the union fillet is k = 0.1 mm -- the best a local (per-primitive) composition can do without a solve.
def surf_A4(k=0.10):
    dIn = 0.5 * min(W, Rr); rr = 1 - dIn / Rr
    hN = hc * (np.sqrt(1 - rr * rr * np.sin(P.TH) ** 2) - np.cos(P.TH)) / (1 - np.cos(P.TH))
    ht4 = np.where(on, ht + (hN - 0.6 * hc) * (1 - nk) * np.clip(ht / np.maximum(0.6 * hc, 1e-6), 0, 1), 0)
    Rc4 = (w * w + ht4 * ht4) / np.maximum(2 * ht4, 1e-6)
    sec4 = np.clip(np.where(on & (np.abs(bt) < w), np.sqrt(np.clip(Rc4 * Rc4 - bt * bt, 0, None)) - (Rc4 - ht4), 0), 0, None)
    both = (cap > 0) & (sec4 > 0)
    m = np.maximum(cap, sec4)
    return np.where(both, m + k * np.log1p(np.exp(-np.abs(cap - sec4) / k)) * np.minimum(cap, sec4) / np.maximum(np.minimum(cap, sec4) + k, 1e-6), m)


H4 = surf_A4()
c = crease(H4)
print(f'{"A4 matched neck + fillet 0.1 mm":34s} crease (deg/0.1 mm) centre {c[0]:5.1f}  0.35w0 {c[1]:5.1f}  0.6w0 {c[2]:5.1f}')
