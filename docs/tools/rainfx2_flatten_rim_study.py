"""Does the game's drop FLATTENING remove the rim light / dark split? (docs/RAINFX_V2_TRAIL_REVIEW3.md section 37)
Game rule (visor r2AddDrop): resting spread f = baseSpread + spreadVarK smoothstep(0.15, 0.8, r)(0.35 + 0.65 pin)(1 + 0.3 wet),
lens rim angle th_eff = contactDeg / f^1.5 x (1 - wetFlatten x film), top flattening beta = 0.85 (f - 1).
Physics (gravity, Bond = (r / 2.7 mm)^2): the top flattens but the edge keeps the Young contact angle.
Render: perpendicular view (section 36 rig: physical 3D refraction, Fresnel, TIR dark, world sky / ground, view 10 deg above
the horizon). Profiles r = 1.2 mm: (a) game f = 1.0 / 1.4 / 1.65, (b) physical flattening (same beta, rim = contact angle),
(c) CSP-like: flat plateau to 0.5 r, steep rim (edge normal nz 0.3, ~72 deg).
usage: python rainfx2_flatten_rim_study.py [out.png]
"""
import sys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
sys.path.insert(0, __file__.rsplit('/', 1)[0])
import rainfx2_rim_asymmetry_study as R

REF, n, r = R.REF, 260, 1.2
x1 = (np.arange(n) - n / 2 + 0.5) * REF
X, Y = np.meshgrid(x1, x1); d = np.hypot(X, Y)


def cap(th):
    Rs = r / np.sin(th)
    return np.clip(np.sqrt(np.clip(Rs * Rs - d * d, 0, None)) - Rs * np.cos(th), 0, None)


def flat(th, b):                                   # flattened top, rim slope = tan(th) at d = r
    x = (d / r) ** 2
    A = np.tan(th) * r / (2 + 2 * b)
    return np.where(d < r, A * (1 - (1 - b) * x - b * x * x), 0)


def csp():                                         # plateau to 0.5 r, linear edge, steep rim (CSP pfxWindscreen_ps profile)
    s = np.clip((r - d) / (0.5 * r), 0, 1)
    return np.where(d < r, np.tan(np.radians(72)) * 0.5 * r * (s * s * (3 - 2 * s)) * 0.6, 0)


cases = []
for th in (45, 60):
    for f in (1.0, 1.4, 1.65):
        te = th / f ** 1.5; b = 0.85 * (f - 1)
        cases.append((f'game th {th} f {f}: rim {te:.0f} deg', flat(np.radians(te), b)))
    cases.append((f'physical th {th}, beta 0.5: rim {th} deg', flat(np.radians(th), 0.5)))
cases.append(('CSP-like plateau + steep rim', csp()))
cols = 4
rows = (len(cases) + cols - 1) // cols
fig, ax = plt.subplots(rows, cols, figsize=(4 * cols, 4 * rows))
for k, (name, H) in enumerate(cases):
    img = R.render(H, 0, 0, up_tilt_deg=10)
    m = H > 1e-4
    rim = m & (d > 0.8 * r)
    top, bot = rim & (Y > 0), rim & (Y < 0)
    print(f'{name:40s} upper rim dark {(img[top] < 0.2).mean() * 100:4.0f}%  lower rim bright {(img[bot] > 0.5).mean() * 100:4.0f}%')
    a = ax.ravel()[k]; a.imshow(np.flipud(img), cmap='gray', vmin=0, vmax=0.9); a.set_title(name, fontsize=8); a.axis('off')
for a in ax.ravel()[len(cases):]: a.axis('off')
plt.tight_layout(); plt.savefig(sys.argv[1] if len(sys.argv) > 1 else 'rainfx2_flatten_rim_study.png', dpi=70)
