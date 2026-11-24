"""Why our drop images look metallic / torn while CSP's blend with the background (docs/RAINFX_V2_TRAIL_REVIEW3.md section 48).
Physics: a water cap is a strong lens, f = Rs / (n - 1) (Rs = R / sin theta: 1.4 mm -> f ~ 4 mm). A camera (or eye) focused far
looks through it at the inverted image of the scene, which the drop forms ~f in front of itself, i.e. far OUT OF FOCUS for the
camera: angular blur of the in-drop image beta ~ D_eff / f, D_eff = min(camera entrance pupil, drop chord). Helmet / phone cam
pupil 1-2.5 mm, eye 3-4 mm -> beta 0.25-0.6 rad (15-35 deg) against an image that spans +-25 deg: the in-drop image is a soft,
low-contrast copy whose tone is the average of what the drop looks at -- the reference 'opposite-tone blurred disc'.
Renders one row of drops (R 0.4 / 0.8 / 1.6 mm, 58 deg) over a game frame used as the scene at infinity, perpendicular view:
  A  sharp physical lens, scene read at the footprint mip (current game: minified, aliased, metallic)
  B  + image blur beta = D_eff / f (pupil 1.5 mm)
  C  CSP-like: small screen offset 0.25 n_xy, blurred sample, steep rim = env (sky/ground mean) x 0.7
usage: python rainfx2_drop_image_blur_proto.py scene.png out.png
"""
import sys
import numpy as np
from scipy import ndimage
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from PIL import Image

N_W, TH = 1.333, np.radians(58)
scene = np.asarray(Image.open(sys.argv[1]).convert('RGB'), float) / 255.0
H, W = scene.shape[:2]
pyr = [scene]
for k in range(1, 9): pyr.append(ndimage.gaussian_filter(scene, (2 ** k * 0.6, 2 ** k * 0.6, 0)))
PX_MM = 0.02                                   # visor mm per screen px (drop on the visor)
K = H / (2 * np.tan(np.radians(30)))           # screen px per tan (60 deg vertical fov)


def sample(y, x, mip):
    mip = np.clip(mip, 0, 8); m0 = np.floor(mip).astype(int); t = (mip - m0)[..., None]
    out = np.zeros(y.shape + (3,))
    for k in np.unique(m0):
        sel = m0 == k
        a = np.stack([ndimage.map_coordinates(pyr[k][..., c], [y[sel], x[sel]], order=1, mode='nearest') for c in range(3)], -1)
        b = np.stack([ndimage.map_coordinates(pyr[min(k + 1, 8)][..., c], [y[sel], x[sel]], order=1, mode='nearest') for c in range(3)], -1)
        out[sel] = a * (1 - t[sel]) + b * t[sel]
    return out


def drop(img, cy, cx, R, mode, pupil=1.5):
    r = int(R / PX_MM) + 2
    yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
    d = np.hypot(yy, xx) * PX_MM
    m = d < R
    Rs = R / np.sin(TH)
    s = d / Rs                                                     # sin of the surface angle
    al = np.arcsin(np.clip(s, 0, 0.9999))
    sn = N_W * np.sin(al)
    dev = np.where(sn < 1, np.arcsin(np.clip(sn, 0, 1)) - al, np.pi / 2 - al)
    ux, uy = -xx / np.maximum(np.hypot(xx, yy), 1e-6), -yy / np.maximum(np.hypot(xx, yy), 1e-6)
    if mode == 'C':
        nxy = np.sin(al)
        sy, sx = cy + yy + 0.25 * H * nxy * uy * 0.5, cx + xx + 0.25 * H * nxy * ux * 0.5
        col = sample(sy, sx, np.full(sy.shape, 2.5))
        steep = np.clip((np.cos(al) < 0.3 + 0.1) * 1.0, 0, 1)
        col = col * (1 - steep[..., None]) + 0.7 * scene.mean((0, 1)) * steep[..., None]
    else:
        sy, sx = cy + K * np.tan(dev) * uy, cx + K * np.tan(dev) * ux
        g = np.gradient(np.tan(dev) * K, PX_MM)                     # footprint: scene px per drop px
        foot = np.hypot(*g) * PX_MM + 1
        mip = np.log2(np.maximum(foot, 1))
        if mode == 'B':
            f = Rs / (N_W - 1)
            beta = min(pupil, 2 * R) / f
            mip = np.maximum(mip, np.log2(max(beta * K, 1)))
        col = sample(sy, sx, mip)
        col = np.where((sn >= 1)[..., None], col * 0.35, col)
    reg = img[cy - r:cy + r + 1, cx - r:cx + r + 1]
    reg[m] = col[m]


fig, ax = plt.subplots(3, 1, figsize=(12, 9))
for k, (mode, t) in enumerate([('A', 'A: sharp physical lens (current): minified, high-contrast, aliased'),
                               ('B', 'B: + in-drop image defocus beta = min(pupil 1.5 mm, chord) / f, f = Rs / (n - 1)'),
                               ('C', 'C: CSP-like: small screen offset, blurred, steep rim = env x 0.7')]):
    img = scene.copy()
    for i, R in enumerate((0.4, 0.8, 1.6, 0.8, 0.4)):
        drop(img, H // 2, int(W * (0.15 + 0.17 * i)), R, mode)
    ax[k].imshow(np.clip(img[H // 2 - 110:H // 2 + 110], 0, 1)); ax[k].set_title(t, fontsize=9); ax[k].axis('off')
plt.tight_layout(); plt.savefig(sys.argv[2], dpi=90)
for R in (0.4, 0.8, 1.6):
    Rs = R / np.sin(TH); f = Rs / (N_W - 1)
    print(f'R {R} mm: f {f:.1f} mm, beta(pupil 1.5) {min(1.5, 2 * R) / f:.2f} rad = {np.degrees(min(1.5, 2 * R) / f):.0f} deg, '
          f'image span ~ +-{np.degrees(np.arcsin(N_W * np.sin(TH)) - TH) if N_W * np.sin(TH) < 1 else 40:.0f} deg')
