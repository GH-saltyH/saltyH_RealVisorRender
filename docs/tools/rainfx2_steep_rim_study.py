"""Steep rim like CSP? (docs/RAINFX_V2_TRAIL_REVIEW3.md section 43). Perpendicular view, r 1.2 mm, view 10 deg above the
horizon (section 36 rig). Profiles: arrested cap 33 deg (the game's big / merged drops), caps 45 / 60 / 90 deg (hydrophobic
visor coat), CSP disc (plateau to 0.5 r + steep rim, edge normal nz 0.3 ~ 72 deg). Shading: (P) physical lens (3D refraction,
Fresnel, TIR -> helmet interior), (C) CSP ksWindscreenFX: nz > 0.3 small screen offset, steep rim = world environment in the
bent direction Vb = normalize(V + 0.5 (1 - nz)(-V - N)) x 0.7.
usage: python rainfx2_steep_rim_study.py [out.png] [reference.png]
"""
import sys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
sys.path.insert(0, __file__.rsplit('/', 1)[0])
import rainfx2_rim_asymmetry_study as R

REF, n, r = R.REF, 240, 1.2
x1 = (np.arange(n) - n / 2 + 0.5) * REF
X, Y = np.meshgrid(x1, x1); d = np.hypot(X, Y)


def cap(th):
    th = np.radians(th); Rs = r / np.sin(th)
    return np.clip(np.sqrt(np.clip(Rs * Rs - d * d, 0, None)) - Rs * np.cos(th), 0, None)


def csp():
    s = np.clip((r - d) / (0.5 * r), 0, 1)
    return np.where(d < r, np.tan(np.radians(72)) * 0.5 * r * (s * s * (3 - 2 * s)) * 0.6, 0)


def shade_csp(H, el=10):
    gy, gx = np.gradient(H, REF)
    N = np.stack([-gx, -gy, np.ones_like(H)], -1); N /= np.linalg.norm(N, axis=-1, keepdims=True)
    nz = N[..., 2]
    V = np.array([0, 0, 1.0])
    ut = np.radians(el); up = np.array([0, np.cos(ut), np.sin(ut)])
    Vb = V + 0.5 * (1 - nz)[..., None] * (-V - N); Vb /= np.linalg.norm(Vb, axis=-1, keepdims=True)
    c_env = R.env(Vb * np.array([-1, 1, 1]), up) * 0.7
    c_scr = R.env(np.broadcast_to(V, H.shape + (3,)) + 0.25 * np.stack([-N[..., 0], -N[..., 1], 0 * nz], -1), up)
    w = np.clip((nz - 0.3) * 10, 0, 1)
    img = c_env * (1 - w) + c_scr * w
    return np.where(H > 1e-4, img, R.env(np.broadcast_to(V, H.shape + (3,)), up))


cases = [('arrested cap 33 (game big drops)', cap(33)), ('cap 45', cap(45)), ('cap 60', cap(60)), ('cap 90 (hydrophobic)', cap(89)),
         ('CSP disc (plateau + 72 deg rim)', csp())]
fig, ax = plt.subplots(2, len(cases) + 1, figsize=(3.6 * (len(cases) + 1), 7.4))
for j, (name, H) in enumerate(cases):
    P = np.flipud(R.render(H, 0, 0, up_tilt_deg=10)); C = np.flipud(shade_csp(H))
    ax[0, j].imshow(P, cmap='gray', vmin=0, vmax=0.9); ax[0, j].set_title('P: ' + name, fontsize=8)
    ax[1, j].imshow(C, cmap='gray', vmin=0, vmax=0.9); ax[1, j].set_title('C (CSP shading): ' + name, fontsize=8)
if len(sys.argv) > 2:
    ax[0, -1].imshow(plt.imread(sys.argv[2])); ax[0, -1].set_title('reference (glass, square view)', fontsize=8)
for a in ax.ravel(): a.axis('off')
plt.tight_layout(); plt.savefig(sys.argv[1] if len(sys.argv) > 1 else 'rainfx2_steep_rim_study.png', dpi=70)


# ---- (P2) physical lens with the INTERNAL REFLECTION continued: a TIR ray reflects at the cap, crosses the drop and leaves through
# the opposite side of the cap (normal mirrored about the drop axis, same radius); a second TIR there -> exit through the flat
# contact face into the helmet (dark). The rim then shows the world in the reflected direction, not black.
def render_p2(H, el=10):
    gy, gx = np.gradient(H, REF)
    N = np.stack([-gx, -gy, np.ones_like(H)], -1); N /= np.linalg.norm(N, axis=-1, keepdims=True)
    ut = np.radians(el); up = np.array([0, np.cos(ut), np.sin(ut)])
    V = np.broadcast_to(np.array([0, 0, 1.0]), H.shape + (3,))
    Vw, _, _ = R.refract(V, np.broadcast_to(np.array([0, 0, -1.0]), H.shape + (3,)), 1 / R.NW)
    Vo, ok, ci = R.refract(Vw, -N, R.NW)
    ct = np.sqrt(np.clip(1 - R.NW ** 2 * (1 - ci * ci), 0, 1))
    T = np.where(ok, R.fresnel_t(ci, ct, R.NW, 1.0), 0)
    Rr = Vw - 2 * np.sum(Vw * N, -1, keepdims=True) * N                       # internal reflection
    N2 = N * np.array([-1, -1, 1])                                             # opposite side of the cap
    Vo2, ok2, ci2 = R.refract(Rr, -N2, R.NW)
    ct2 = np.sqrt(np.clip(1 - R.NW ** 2 * (1 - ci2 * ci2), 0, 1))
    T2 = np.where(ok2 & (Rr[..., 2] > 0), R.fresnel_t(np.abs(ci2), ct2, R.NW, 1.0), 0)
    refl = T2 * R.env(Vo2, up) + (1 - T2) * 0.05
    img = np.where(ok, T * R.env(Vo, up), 0) + (1 - T) * refl
    return np.where(H > 1e-4, img, R.env(V, up))


fig, ax = plt.subplots(1, len(cases) + 1, figsize=(3.6 * (len(cases) + 1), 3.8))
for j, (name, H) in enumerate(cases):
    ax[j].imshow(np.flipud(render_p2(H)), cmap='gray', vmin=0, vmax=0.9); ax[j].set_title('P2: ' + name, fontsize=8)
if len(sys.argv) > 2: ax[-1].imshow(plt.imread(sys.argv[2])); ax[-1].set_title('reference', fontsize=8)
for a in ax: a.axis('off')
plt.tight_layout(); plt.savefig((sys.argv[1] if len(sys.argv) > 1 else 'x.png').replace('.png', '_p2.png'), dpi=70)
