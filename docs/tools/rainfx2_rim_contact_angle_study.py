"""Rim light / dark split at a PERPENDICULAR view (docs/RAINFX_V2_TRAIL_REVIEW3.md section 36). User reference: camera square
to the glass, drops show a thick dark upper rim and a thin bright lower rim, contact angle looks gentle. Section 35 blamed the
oblique view -- wrong. Test: same physical lens (3D refraction, Fresnel, TIR -> dark), view along the glass normal, the world
behind the glass = sky above the horizon / dark ground below (the camera frame itself shows only sky: the view points
'elev' above the horizon), contact angle 25 / 35 / 45 / 60 deg.
usage: python rainfx2_rim_contact_angle_study.py [out.png]
"""
import sys
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
sys.path.insert(0, __file__.rsplit('/', 1)[0])
import rainfx2_rim_asymmetry_study as R

REF = R.REF


def cap(r, n, th):
    x = (np.arange(n) - n / 2 + 0.5) * REF
    X, Y = np.meshgrid(x, x); d = np.hypot(X, Y)
    Rs = r / np.sin(th)
    return np.clip(np.sqrt(np.clip(Rs * Rs - d * d, 0, None)) - Rs * np.cos(th), 0, None), Y


angles = (25, 35, 45, 60)
elevs = (10, 25)
fig, ax = plt.subplots(len(elevs), len(angles), figsize=(4 * len(angles), 4 * len(elevs)))
for i, el in enumerate(elevs):
    for j, a in enumerate(angles):
        H, Y = cap(0.6, 200, np.radians(a))
        img = R.render(H, 0, 0, up_tilt_deg=el)          # view along the glass normal; normal points 'el' above the horizon
        m = H > 1e-4
        rim = m & (np.hypot(*np.meshgrid((np.arange(200) - 99.5) * REF, (np.arange(200) - 99.5) * REF)) > 0.8 * 0.6)
        top, bot = rim & (Y > 0), rim & (Y < 0)          # render(): +y = world up; shown flipped so up is up on screen
        tir = np.degrees(np.arcsin(1 / 1.333))
        print(f'elev {el:2d}  theta {a:2d}  upper rim dark {(img[top] < 0.2).mean() * 100:4.0f}%  lower rim bright {(img[bot] > 0.5).mean() * 100:4.0f}%'
              f'  lower rim dark {(img[bot] < 0.2).mean() * 100:4.0f}%   (TIR needs > {tir:.1f} deg)')
        ax[i, j].imshow(np.flipud(img), cmap='gray', vmin=0, vmax=0.9); ax[i, j].axis('off')
        ax[i, j].set_title(f'theta {a} deg, view {el} deg above horizon', fontsize=9)
plt.tight_layout(); plt.savefig(sys.argv[1] if len(sys.argv) > 1 else 'rainfx2_rim_contact_angle_study.png', dpi=70)
