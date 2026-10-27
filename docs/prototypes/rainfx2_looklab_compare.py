"""rev23 look lab, offline: the v2 drop lens rule (visor.hlsl r2DropLens, rev22 defaults) rendered
over a reference frame, next to the reference. Scene = reference frame with its drops blurred out
(median 15 + gaussian 4), so both halves see the same background. Isolated drops (no union),
sizes from the look-lab distribution (pdf ~ r^-1.88), positions Poisson.

usage: python rainfx2_looklab_compare.py ref_frame.png out.jpg [--near 0.14 --far 0.69 --farmix 0.7
       --edge 0.35 --contact 55 --scale 1.0]
"""
import argparse, math
import numpy as np
from PIL import Image
from scipy import ndimage as nd

ap = argparse.ArgumentParser()
ap.add_argument('ref'); ap.add_argument('out')
ap.add_argument('--near', type=float, default=0.14); ap.add_argument('--far', type=float, default=0.69)
ap.add_argument('--farmix', type=float, default=1.0); ap.add_argument('--farmip', type=float, default=5.0)
ap.add_argument('--edge', type=float, default=0.0); ap.add_argument('--glint', type=float, default=0.10)
ap.add_argument('--contact', type=float, default=75.0); ap.add_argument('--scale', type=float, default=1.0)
ap.add_argument('--count', type=int, default=900)
ap.add_argument('--env', type=int, default=1); ap.add_argument('--ground', type=float, default=0.05)
ap.add_argument('--rmax', type=float, default=25.0)
ap.add_argument('--e0', type=float, default=-0.3); ap.add_argument('--e1', type=float, default=0.3)
ap.add_argument('--k0', type=float, default=0.3); ap.add_argument('--k1', type=float, default=0.9); ap.add_argument('--seed', type=int, default=3)
a = ap.parse_args()

ref = np.asarray(Image.open(a.ref).convert('RGB'), float) / 255.0
H, W, _ = ref.shape
scene = np.stack([nd.median_filter(ref[..., c], 15) for c in range(3)], -1)
scene = np.stack([nd.gaussian_filter(scene[..., c], 4) for c in range(3)], -1)

def blur(img, mip):  # half-res source mip m ~ box of 2^(m+1) full-res px -> gaussian sigma
    s = 0.5 * 2 ** (mip + 1)
    return np.stack([nd.gaussian_filter(img[..., c], s) for c in range(3)], -1)
near_img, far_img = blur(scene, 2.75), blur(scene, a.farmip)
veil = scene[: H // 4].reshape(-1, 3).mean(0)          # sky / fog colour

def sample(img, x, y):  # mirrored
    x = np.abs(x); y = np.abs(y)
    x = np.where(x > W - 1, 2 * (W - 1) - x, x); y = np.where(y > H - 1, 2 * (H - 1) - y, y)
    return img[np.clip(y, 0, H - 1).astype(int), np.clip(x, 0, W - 1).astype(int)]

rng = np.random.default_rng(a.seed)
alpha = 0.88
lo, hi = 1.5 ** -alpha, a.rmax ** -alpha                    # radius px range (3..90 px sizes)
out = scene.copy()
sth = math.sin(math.radians(a.contact))
for _ in range(a.count):
    R = (lo + (hi - lo) * rng.random()) ** (-1 / alpha) * a.scale
    cx, cy = rng.random() * W, rng.random() * H
    e = 0.22 * rng.random(); ang = rng.random() * math.pi
    x0, x1 = int(max(cx - 1.4 * R - 2, 0)), int(min(cx + 1.4 * R + 2, W - 1))
    y0, y1 = int(max(cy - 1.4 * R - 2, 0)), int(min(cy + 1.4 * R + 2, H - 1))
    if x1 <= x0 or y1 <= y0: continue
    yy, xx = np.mgrid[y0:y1 + 1, x0:x1 + 1].astype(float)
    qx, qy = xx - cx, yy - cy
    u = np.array([math.cos(ang), math.sin(ang)])
    qa = qx * u[0] + qy * u[1]; s1 = e / (1 + e)
    qx2, qy2 = qx - u[0] * qa * s1, qy - u[1] * qa * s1
    rho = np.sqrt(qx2 ** 2 + qy2 ** 2) / R
    cov = np.clip((1.0 - rho) * R / 1.5 + 0.5, 0, 1)        # 1.5 px AA band
    m = cov > 0
    if not m.any(): continue
    rs = np.clip(rho, 0, 1) * sth
    sl = np.minimum(rs / np.sqrt(np.maximum(1 - rs * rs, 0.04)), 5.0)
    dl = np.sqrt(qx2 ** 2 + qy2 ** 2) + 1e-6
    dx, dy = -qx2 / dl, -qy2 / dl                          # toward the centre
    nx = xx + dx * sl * a.near * H; ny = yy + dy * sl * a.near * H
    c = sample(near_img, nx, ny)
    fx = xx + dx * sl * a.far * H; fy = yy + dy * sl * a.far * H
    kk = np.clip((sl - a.k0) / (a.k1 - a.k0), 0, 1)
    k = (a.farmix * kk * kk * (3 - 2 * kk))[..., None]
    if a.env:
        # rev23 far view = directional environment: the steep rim refracts the ray far off the
        # screen; looking down (top rim) it meets ground / car interior (dark), looking up (bottom
        # rim) the sky. facing = component of the deflection toward screen-up.
        up = -dy                                            # +1: rim deflects toward screen up
        t = np.clip((up - a.e0) / (a.e1 - a.e0), 0, 1); t = t * t * (3 - 2 * t)
        env = veil * a.ground + (veil - veil * a.ground) * t[..., None]
        c = c * (1 - k) + env * k
    else:
        c = c * (1 - k) + sample(far_img, fx, fy) * k
    c = c * (1 - a.edge * np.clip((sl - 0.7) / 0.6, 0, 1))[..., None]
    facing = np.clip(-dy, 0, 1)                            # screen up = -y
    c = c + veil * (a.glint * facing ** 4 * np.clip((sl - 0.5) / 0.6, 0, 1))[..., None]
    w = cov[..., None]
    out[y0:y1 + 1, x0:x1 + 1] = out[y0:y1 + 1, x0:x1 + 1] * (1 - w) + c * w
img = np.concatenate([ref, np.ones((H, 8, 3)), np.clip(out, 0, 1)], 1)
Image.fromarray((img * 255).astype(np.uint8)).save(a.out, quality=90)
print('saved', a.out)
