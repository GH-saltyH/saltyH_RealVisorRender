# B3g review (docs/RAINFX_V2_TRAIL_REVIEW3.md section 30): head + tail junction, CURRENT per-primitive lens union (visor r2Kernel /
# r2DropLens: P = prod(1 - h_i), G blended, lens radius / angle = h-weighted Rmm, sth -> cap slope) vs ONE HEIGHT FIELD
# (H = smooth union of physical heights, refraction from grad H). Output: surface slope (tan) maps + a section along the tail.
import numpy as np, matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt
mm = 0.02; x = np.arange(-4, 10, mm); y = np.arange(-3, 3, mm); X, Y = np.meshgrid(x, y)
R, th = 1.6, np.radians(60); hc = R * (1 - np.cos(th)) / np.sin(th)          # head: contact radius, angle, apex height
Ws = R; dIn = 0.5 * R; w0 = Ws * np.sqrt(1 - (1 - dIn / R) ** 2); hwR = 0.3 * Ws; L = 8.0
a = X - R                                                                     # arc behind the rear edge (tail along +x)
nk = np.clip((a + dIn) / (2.1 * Ws), 0, 1); nk = nk * nk * (3 - 2 * nk)
w = (w0 + (hwR - w0) * nk) * np.sqrt(np.clip((a + 2 * dIn) / dIn, 0, 1)) * np.clip((L - a) / (0.25 * L), 0, 1) ** 0.7
hR = 0.25 * hwR * 0.45; hN = 0.6 * hc; ht = hN + (hR - hN) * nk
# ---- current: two kernels (k = 1.24, threshold 0.35), lens slope from rho * sth (cap model)
def kern(d2, Rk, beta=0.0):
    xk = d2 / Rk ** 2; h = 1 - (1 - beta) * xk - beta * xk * xk
    return np.clip(h, 0, None), xk
hH, _ = kern(X ** 2 + Y ** 2, 1.24 * R)
beta = 0.85 * nk; ct = 0.65; xt = np.where(beta > 1e-3, (-(1 - beta) + np.sqrt((1 - beta) ** 2 + 4 * beta * ct)) / (2 * np.maximum(beta, 1e-3)), ct)
Rt = np.maximum(w, 1e-3) / np.sqrt(xt); hT, _ = kern(Y ** 2, Rt, beta); hT[(a < -2 * dIn) | (a > L) | (w < 0.02)] = 0
P = (1 - hH) * (1 - hT); U = 1 - P
gy, gx = np.gradient(U, mm); G = np.hypot(gx, gy)
sthH = np.sin(th); tn = np.minimum(2 * ht / np.maximum(w, 1e-3), 1); sthT = tn / np.sqrt(1 + tn * tn)
HW = hH + hT + 1e-9; Rmm = (hH * R + hT * w) / HW; sth = (hH * sthH + hT * sthT) / HW
rs = np.clip(G * Rmm * (1.24 ** 2 / 2) * sth, 0, 0.999); slopeA = rs / np.sqrt(1 - rs * rs); slopeA[U < 0.35] = np.nan
# ---- one height field: spherical cap head + tail section of its own depth, smooth max (k = 0.05 mm)
Rs = R / np.sin(th); capH = np.sqrt(np.clip(Rs ** 2 - X ** 2 - Y ** 2, 0, None)) - (Rs - hc); capH[capH < 0] = 0
tailH = np.where(w > 0.02, ht * np.clip(1 - (Y / np.maximum(w, 1e-3)) ** 2, 0, None), 0); tailH[(a < -2 * dIn) | (a > L)] = 0
k = 0.05; Hs = k * np.log(np.exp(capH / k) + np.exp(tailH / k) - 1 + 1e-12); Hs = np.maximum(Hs, 0)
hy, hx = np.gradient(Hs, mm); slopeB = np.hypot(hx, hy); slopeB[Hs < 1e-3] = np.nan
fig, ax = plt.subplots(3, 1, figsize=(10, 9))
for i, (S, t) in enumerate([(slopeA, 'current: per-primitive lens union (slope from rho x sth)'), (slopeB, 'one height field: smooth union, slope = |grad H|')]):
    im = ax[i].imshow(np.arctan(S) * 57.3, extent=[x[0], x[-1], y[0], y[-1]], origin='lower', cmap='magma', vmin=0, vmax=70)
    ax[i].set_title(t); plt.colorbar(im, ax=ax[i], label='surface angle (deg)')
j = len(y) // 2 + int(0.35 * w0 / mm)                                      # a section near the neck edge
ax[2].plot(x, np.arctan(slopeA[j]) * 57.3, label='current'); ax[2].plot(x, np.arctan(slopeB[j]) * 57.3, label='height field')
ax[2].axvline(R, ls=':', c='k'); ax[2].set_xlabel('mm along the tail (head centre 0, rear edge dotted)'); ax[2].set_ylabel('deg'); ax[2].legend()
ax[2].set_title('section y = 0.35 w0 (neck flank)')
plt.tight_layout(); plt.savefig('docs/images/rainfx2_surface_union_proto.png', dpi=90)
print('current max jump along section (deg/0.1 mm):', np.nanmax(np.abs(np.diff(np.arctan(slopeA[j]) * 57.3)[::5])))
print('height field max jump:', np.nanmax(np.abs(np.diff(np.arctan(slopeB[j]) * 57.3)[::5])))
