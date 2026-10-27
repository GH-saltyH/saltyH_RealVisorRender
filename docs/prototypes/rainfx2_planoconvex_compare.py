"""rev24 physical plano-convex drop lens, offline vs the reference (물방울형태및흐름 frame).

Camera at the origin looking +z (vertical FOV fov). A flat visor patch at distance dist with outward
normal n (tilted by --pitch / --yaw, the reference is a SIDE view of a window). Drops = spherical caps
(radius R, contact angle theta) on the outer face. Per pixel ray V:
  plano face (water side, flat):  Vw = refract(V, -n, 1/1.333)
  curved face (cap normal nD):     Vo = refract(Vw, -nD, 1.333)   (TIR -> internal reflection)
Vo -> background: inside the screen = scene image at that direction (scene at infinity), outside =
sky / ground by world-up component. TIR -> ray goes back into the car: dark interior.
Scene = reference frame with its own drops median-filtered away.

usage: python rainfx2_planoconvex_compare.py ref.png out.jpg [--pitch -20 --yaw 50 --theta 75]
"""
import argparse, math
import numpy as np
from PIL import Image
from scipy import ndimage as nd

ap = argparse.ArgumentParser()
ap.add_argument('ref'); ap.add_argument('out')
ap.add_argument('--fov', type=float, default=60); ap.add_argument('--dist', type=float, default=0.10)
ap.add_argument('--pitch', type=float, default=-15); ap.add_argument('--yaw', type=float, default=45)
ap.add_argument('--theta', type=float, default=75); ap.add_argument('--count', type=int, default=1400)
ap.add_argument('--rmin', type=float, default=0.25); ap.add_argument('--rmax', type=float, default=4.0)
ap.add_argument('--ground', type=float, default=0.12); ap.add_argument('--interior', type=float, default=0.05)
ap.add_argument('--blur', type=float, default=1.5); ap.add_argument('--sag', type=float, default=0.25)
ap.add_argument('--seed', type=int, default=4)
a = ap.parse_args()

ref = np.asarray(Image.open(a.ref).convert('RGB'), float) / 255.0
H, W, _ = ref.shape
scene = np.stack([nd.gaussian_filter(nd.median_filter(ref[..., c], 15), a.blur) for c in range(3)], -1)
sky = scene[: H // 5].reshape(-1, 3).mean(0)
f = 0.5 * H / math.tan(math.radians(a.fov) * 0.5)

def rot(p, y):
    p, y = math.radians(p), math.radians(y)
    Rx = np.array([[1, 0, 0], [0, math.cos(p), -math.sin(p)], [0, math.sin(p), math.cos(p)]])
    Ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    return Ry @ Rx
Rm = rot(a.pitch, a.yaw)
n = Rm @ np.array([0, 0, 1.0])            # outward visor normal (away from the eye)
tu = Rm @ np.array([1.0, 0, 0]); tv = Rm @ np.array([0, -1.0, 0])   # tv = visor "up"
P0 = n * a.dist                           # plane point

yy, xx = np.mgrid[0:H, 0:W].astype(float)
V = np.stack([(xx - W / 2) / f, -(yy - H / 2) / f, np.ones_like(xx)], -1)   # y up
V /= np.linalg.norm(V, axis=-1, keepdims=True)
t = (P0 @ n) / (V @ n)
X = V * t[..., None]
u = (X - P0) @ tu * 1000; v = (X - P0) @ tv * 1000    # mm on the visor

def refract(I, N, eta):
    c = -(I * N).sum(-1, keepdims=True)
    k = 1 - eta * eta * (1 - c * c)
    T = eta * I + (eta * c - np.sqrt(np.maximum(k, 0))) * N
    return T, (k[..., 0] > 0)

def env(D):
    # inside the screen: scene image at that direction; outside: sky / ground by world up
    z = np.maximum(D[..., 2], 1e-3)
    px = W / 2 + D[..., 0] / z * f; py = H / 2 - D[..., 1] / z * f
    inside = (D[..., 2] > 0.2) & (px >= 0) & (px < W) & (py >= 0) & (py < H)
    img = scene[np.clip(py, 0, H - 1).astype(int), np.clip(px, 0, W - 1).astype(int)]
    up = np.clip(D[..., 1] * 2.5 + 0.5, 0, 1)[..., None]
    out = sky * a.ground + (sky - sky * a.ground) * up
    return np.where(inside[..., None], img, out)

rng = np.random.default_rng(a.seed)
al = 0.88; lo, hi = a.rmin ** -al, a.rmax ** -al
umin, umax, vmin, vmax = np.percentile(u, 1), np.percentile(u, 99), np.percentile(v, 1), np.percentile(v, 99)
out = scene.copy()
th = math.radians(a.theta)
gdir = np.array([-(np.array([0, 1.0, 0]) @ tu), -(np.array([0, 1.0, 0]) @ tv)])   # gravity in (u,v)
gl = np.linalg.norm(gdir); gdir = gdir / gl if gl > 1e-6 else np.array([0, -1.0])
for _ in range(a.count):
    R = (lo + (hi - lo) * rng.random()) ** (-1 / al)
    cu, cv = umin + (umax - umin) * rng.random(), vmin + (vmax - vmin) * rng.random()
    du, dv = u - cu, v - cv
    m = (np.abs(du) < 1.6 * R) & (np.abs(dv) < 1.6 * R)
    if not m.any(): continue
    q = np.stack([du[m], dv[m]], -1)
    # gravity sag (Bond number ~ R^2): the top (against gravity) stretches thin, the bottom stays round
    k = a.sag * min(1.0, (R / 1.5) ** 2)
    along = q @ gdir
    s2 = np.where(along < 0, k / (1 + k), 0.0)
    q2 = q - gdir[None] * (along * s2)[:, None]
    # spherical cap: base radius R, sphere radius Rs = R / sin(theta)
    Rs = R / math.sin(th); rr = np.linalg.norm(q2, axis=-1)
    inside = rr < R
    if not inside.any(): continue
    hgrad = rr / np.sqrt(np.maximum(Rs * Rs - rr * rr, 1e-9))     # |dh/dr| = tan(local angle)
    d2 = q2 / np.maximum(rr, 1e-9)[:, None]
    # chain rule through the sag transform: grad wrt q = A^T grad wrt q2
    g2 = -d2 * hgrad[:, None]                                     # dh/dq2 (height falls outward)
    g = g2 - gdir[None] * ((g2 @ gdir) * s2)[:, None]
    nD = n[None] - (g[:, :1] * tu[None] + g[:, 1:] * tv[None])
    nD /= np.linalg.norm(nD, axis=-1, keepdims=True)
    Vm = V[m]
    Vw, _ = refract(Vm, -n[None].repeat(len(Vm), 0), 1 / 1.333)
    Vo, ok = refract(Vw, -nD, 1.333)
    c = env(Vo[:, None, :])[:, 0]
    c = np.where(ok[:, None], c, sky * a.interior)
    # Fresnel transmission loss at grazing exit
    cosx = np.clip((Vw * nD).sum(-1), 0, 1)
    c = c * (0.85 + 0.15 * cosx[:, None])
    cov = np.clip((R - rr) / max(R * 0.08, 0.02), 0, 1) * inside
    o = out[m]
    out[m] = o * (1 - cov[:, None]) + c * cov[:, None]
img = np.concatenate([ref, np.ones((H, 8, 3)), np.clip(out, 0, 1)], 1)
Image.fromarray((img * 255).astype(np.uint8)).save(a.out, quality=90)
print('saved', a.out)
