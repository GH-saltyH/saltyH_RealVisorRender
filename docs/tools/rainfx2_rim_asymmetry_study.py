"""Why the prototype rim is a full black ring while real drops show a bright rim part and a dark (shadow-like) part
(docs/RAINFX_V2_TRAIL_REVIEW3.md section 35). Full 3D refraction per pixel: the eye ray V crosses the flat contact face
(refract air -> water), meets the water surface with normal N = normalize(-dH/dx, -dH/dy, 1), and leaves (refract water -> air,
Fresnel transmission) toward a world environment (sky above the horizon, dark ground below, poles on the sky). Total internal
reflection -> the ray goes back into the helmet (dark interior). Cases: view along the visor normal (the section 34 prototype)
and oblique views (the eye sees most of the visor obliquely: 20 / 40 deg, tilted down and sideways).
usage: python rainfx2_rim_asymmetry_study.py [out.png]
"""
import sys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

REF = 0.0125
TH = np.radians(60)
NW = 1.333


def cap(r, n):
    x = (np.arange(n) - n / 2 + 0.5) * REF
    X, Y = np.meshgrid(x, x); d = np.hypot(X, Y)
    Rs = r / np.sin(TH)
    return np.clip(np.sqrt(np.clip(Rs * Rs - d * d, 0, None)) - Rs * np.cos(TH), 0, None)


def refract(I, Nn, eta):                       # I, Nn unit (Nn against I), returns (T, ok)
    c = -np.sum(I * Nn, -1, keepdims=True)
    k = 1 - eta * eta * (1 - c * c)
    T = eta * I + (eta * c - np.sqrt(np.clip(k, 0, None))) * Nn
    return T / np.maximum(np.linalg.norm(T, axis=-1, keepdims=True), 1e-9), k[..., 0] > 0, c[..., 0]


def fresnel_t(ci, ct, n1, n2):
    rs = ((n1 * ci - n2 * ct) / (n1 * ci + n2 * ct)) ** 2
    rp = ((n1 * ct - n2 * ci) / (n1 * ct + n2 * ci)) ** 2
    return 1 - 0.5 * (rs + rp)


def env(D, up):                                 # world: 'up' = world up in visor coords
    e = np.arcsin(np.clip(np.sum(D * up, -1), -1, 1))
    sky = 0.75 + 0.1 * np.clip(e / 1.2, 0, 1)
    az = np.arctan2(D[..., 0], D[..., 2])
    sky = np.where((np.abs((az * 6 / np.pi) % 1 - 0.5) < 0.04) & (e > 0) & (e < 0.35), 0.35, sky)
    ground = 0.12 + 0.05 * np.exp(-((e + 0.25) / 0.05) ** 2)
    m = 1 / (1 + np.exp(-e / 0.02))
    return ground * (1 - m) + sky * m


def render(H, view_tilt_deg, view_side_deg, up_tilt_deg=20):
    gy, gx = np.gradient(H, REF)
    Nn = np.stack([-gx, -gy, np.ones_like(H)], -1); Nn /= np.linalg.norm(Nn, axis=-1, keepdims=True)
    t, s = np.radians(view_tilt_deg), np.radians(view_side_deg)
    V = np.array([np.sin(s) * np.cos(t), -np.sin(t), np.cos(s) * np.cos(t)]); V /= np.linalg.norm(V)
    ut = np.radians(up_tilt_deg)
    up = np.array([0, np.cos(ut), np.sin(ut)])         # visor leans back: its outward normal looks up_tilt above the horizon
    Vb = np.broadcast_to(V, H.shape + (3,))
    nz = np.broadcast_to(np.array([0, 0, -1.0]), H.shape + (3,))
    Vw, _, _ = refract(Vb, nz, 1 / NW)                  # through the flat contact face (polycarbonate omitted: parallel slab)
    Vo, ok, ci = refract(Vw, -Nn, NW)                   # leave through the water surface
    ct = np.sqrt(np.clip(1 - NW * NW * (1 - ci * ci), 0, 1))
    T = np.where(ok, fresnel_t(ci, ct, NW, 1.0), 0)
    img = np.where(ok, T * env(Vo, up), 0) + (1 - T) * 0.05   # reflected part / TIR: back into the helmet (dark)
    flat = env(Vb, up)
    return np.where(H > 1e-4, img, flat)


n = 240
H1 = cap(0.6, n)
try:
    sys.path.insert(0, __file__.rsplit('/', 1)[0])
    import rainfx2_surface_options_study as S
    from scipy import ndimage
    H2 = ndimage.zoom(S.cases[3][1], 0.025 / REF, order=1)
except Exception:
    H2 = cap(1.0, n)
views = [(0, 0, 'normal view (sec. 34)'), (20, 0, 'oblique 20 deg down'), (40, 0, 'oblique 40 deg down'), (30, 30, 'oblique 30 down + 30 side')]
fig, ax = plt.subplots(2, len(views), figsize=(4.2 * len(views), 8.4))
for j, (t, s, lab) in enumerate(views):
    for i, H in enumerate((H1, H2)):
        img = render(H, t, s)
        m = H > 1e-4
        bright = (img[m] > 0.5).mean(); dark = (img[m] < 0.2).mean()
        ax[i, j].imshow(img, cmap='gray', vmin=0, vmax=0.9); ax[i, j].axis('off')
        ax[i, j].set_title(f'{lab}\nbright {bright * 100:.0f}%  dark {dark * 100:.0f}%', fontsize=9)
        print(f'{["cap r 0.6", "teardrop"][i]:10s} {lab:28s} bright {bright * 100:4.0f}%  dark {dark * 100:4.0f}%')
plt.tight_layout(); plt.savefig(sys.argv[1] if len(sys.argv) > 1 else 'rainfx2_rim_asymmetry_study.png', dpi=70)


# section 34 re-check with the oblique view (20 deg down): does a height MAP keep the bright / dark rim split?
import rainfx2_physical_shading_study as PS
print('map fidelity, oblique 20 deg down (cap r 0.6 / teardrop):')
for st in (REF, 0.05, 0.15, 0.30):
    row = []
    for H in (H1, H2):
        Hm = PS.carry(H, st)
        img = render(Hm, 20, 0); m = Hm > 1e-4
        row.append(f'bright {(img[m] > 0.5).mean() * 100:3.0f}% dark {(img[m] < 0.2).mean() * 100:3.0f}%')
    print(f'  {"exact" if st <= REF else f"map {st:.2f}":10s} ' + '   '.join(row))
