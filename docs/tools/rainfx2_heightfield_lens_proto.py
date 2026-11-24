"""B3h prototype (docs/RAINFX_V2_TRAIL_REVIEW3.md section 31): ONE WATER HEIGHT FIELD vs the current per-primitive lens union.

Same drops, same lens physics (normal incidence through the flat contact face, exit through the water surface, n = 1.333,
scene at infinity, total internal reflection dims the image 0.35 -- visor r2DropLens), two ways to get the surface:
  current : kernels h = 1 - (1-b) x - b x^2 (x = |q'|^2 / Rk^2), union P = prod(1 - h_i), U = 1 - P, silhouette U = 0.35,
            exit slope from the cap model rho * sin(theta) with rho = |grad U| Rmm 1.24^2 / 2, Rmm / sin(theta) = h-weighted
            averages of the primitives (head R / 60 deg, tail hw / its edge angle)  -> section 30: seam at the junction
  height  : physical heights (mm): heads = spherical-cap profile over the same footprint transform (ellipse, rear stretch,
            B3f round front), tail = circular-arc section of its own depth; smooth max (k 0.04 mm); exit slope = |grad H|.
Heads: sliding (aspect 1.4 along the motion, rear stretch k, round front) with tails (B3c-g profile); resting drops round.
usage: python rainfx2_heightfield_lens_proto.py [out.png] [reference.jpg]
"""
import sys
import numpy as np
from scipy import ndimage
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

PX = 0.025                                   # mm / px
W_MM, H_MM = 22.0, 15.0
TH = np.radians(60.0)                        # head contact angle
N_W = 1.333
Y, X = (np.mgrid[0:int(H_MM / PX), 0:int(W_MM / PX)] + 0.5) * PX
M = np.array([0.55, 0.835]); M /= np.linalg.norm(M)          # motion direction (down-right on the image)
NRM = np.array([-M[1], M[0]])


def background(ny, nx):
    yy, xx = np.mgrid[0:ny, 0:nx] / np.array([ny, nx])[:, None, None]
    sky, dark = np.array([0.66, 0.70, 0.72]), np.array([0.15, 0.16, 0.17])
    m = 1 / (1 + np.exp(-(yy - 0.45 - 0.06 * np.sin(xx * 6)) * 35))
    img = sky * (1 - m[..., None]) + dark * m[..., None]
    for k in range(12):
        x0 = 0.05 + k * 0.085
        img[(np.abs(xx - x0 - 0.12 * yy) < 0.004) & (yy < 0.47)] = [0.30, 0.31, 0.32]
    img[np.abs(yy - 0.66 - 0.12 * xx) < 0.008] = [0.80, 0.78, 0.72]
    rng = np.random.default_rng(5)
    for _ in range(60):
        cx, cy, rr = rng.random(), 0.48 + 0.5 * rng.random(), 0.006 + 0.015 * rng.random()
        img[(xx - cx) ** 2 + (yy - cy) ** 2 < rr ** 2] = 0.25 + 0.5 * rng.random()
    return ndimage.gaussian_filter(img, (1.5, 1.5, 0))


BG = background(3 * X.shape[0], 3 * X.shape[1])               # scene seen through the visor (larger than the patch)


def drops():
    rng = np.random.default_rng(11)
    out = [dict(p=np.array([7.0, 9.5]), R=1.7, A=1.4, k=0.30, L=8.0, s=4.0),       # sliding heads with tails
           dict(p=np.array([15.5, 11.0]), R=1.2, A=1.3, k=0.25, L=5.5, s=2.5),
           dict(p=np.array([17.5, 4.0]), R=0.9, A=1.2, k=0.15, L=2.5, s=1.4)]
    for _ in range(70):                                                          # resting drops
        R = 0.15 + 0.6 * rng.random() ** 2
        out.append(dict(p=np.array([rng.random() * W_MM, rng.random() * H_MM]), R=R, A=1.0, k=0.0, L=0.0, s=0.0))
    return out


def head_x(d):
    """normalized kernel distance x (visor r2AddDrop: ellipse along M, rear stretch 1 + k, B3f round front) and the
    drawn rear radius / side half-width of the silhouette (U = 0.35 -> x = 0.65)."""
    q = np.stack([X - d['p'][0], Y - d['p'][1]], -1)
    a, b = q @ M, q @ NRM
    rk0 = 1.24 * d['R']
    xr = ((a / (1 + d['k'])) ** 2 / d['A'] + d['A'] * b * b) / rk0 ** 2      # rear half: ellipse (A along M) + stretch
    xf = d['A'] * (a * a + b * b) / rk0 ** 2                                   # front half: round, same across width
    x = np.where(a < 0, xr, xf if d['k'] > 0 else xr)
    W = np.sqrt(0.65) * rk0 / np.sqrt(d['A'])
    Rr = np.sqrt(0.65) * rk0 * np.sqrt(d['A']) * (1 + d['k'])
    return x, a, b, W, Rr


def tail_geom(d, W, Rr):
    """B3c-g profile along the straight path behind the head: (w, h, nk) at every pixel."""
    q = np.stack([X - d['p'][0], Y - d['p'][1]], -1)
    s = -(q @ M)                                   # distance behind the head centre along the path
    b = q @ NRM
    r = d['R']
    a = s - Rr                                     # behind the drawn rear edge
    Lv = d['L'] - max(Rr - r, 0)
    dIn = 0.5 * min(W, Rr); xe = 1 - dIn / Rr; w0 = W * np.sqrt(max(1 - xe * xe, 0))
    hwR = max(0.3 * W * np.sqrt(1 - 1 / max(d['s'], 1.0001)), 0.2 * W)
    hc = r * (1 - np.cos(TH)) / np.sin(TH)
    hR = max(0.02 * r, 0.25 * hwR * 0.45)
    nk = np.clip((a + dIn) / (2.1 * W), 0, 1); nk = nk * nk * (3 - 2 * nk)
    w = (w0 + (hwR - w0) * nk) * np.sqrt(np.clip((a + 2 * dIn) / dIn, 0, 1))
    te = np.clip((Lv - a) / (0.25 * Lv), 0, 1); w = w * te ** 0.7
    w = w * (1 + 0.15 * nk * np.sin(2 * np.pi * s / (9 * hwR) + 1.3))
    h = (0.6 * hc + (hR - 0.6 * hc) * nk) * te
    on = (a > -2 * dIn) & (a < Lv) & (w > 0.02)
    return np.where(on, w, 0), np.where(on, h, 0), nk, b, on


def surf_current(ds):
    P = np.ones_like(X); RW = np.zeros_like(X); SW = np.zeros_like(X); HW = np.zeros_like(X) + 1e-9
    for d in ds:
        x, a, b, W, Rr = head_x(d)
        h = np.clip(1 - x, 0, None)
        P *= 1 - h; RW += h * d['R']; SW += h * np.sin(TH); HW += h
        if d['L'] > 0:
            w, ht, nk, bt, on = tail_geom(d, W, Rr)
            beta = 0.85 * nk
            xt = np.where(beta > 1e-3, (-(1 - beta) + np.sqrt((1 - beta) ** 2 + 4 * beta * 0.65)) / (2 * np.maximum(beta, 1e-3)), 0.65)
            Rk = np.maximum(w, 1e-3) / np.sqrt(xt)
            xk = bt ** 2 / Rk ** 2
            hk = np.where(on, np.clip(1 - (1 - beta) * xk - beta * xk * xk, 0, None), 0)
            tn = np.minimum(2 * ht / np.maximum(w, 1e-3), 1)
            P *= 1 - hk; RW += hk * w; SW += hk * tn / np.sqrt(1 + tn * tn); HW += hk
    U = 1 - P
    gy, gx = np.gradient(U, PX)
    rho = np.hypot(gx, gy) * (RW / HW) * (1.24 ** 2 / 2)
    rs = np.clip(rho * SW / HW, 0, 0.999)
    slope = rs / np.sqrt(1 - rs * rs)
    g = np.stack([gx, gy], -1); g /= np.maximum(np.linalg.norm(g, axis=-1, keepdims=True), 1e-9)
    return U > 0.35, slope, g                       # g points to the drop centre (uphill)


def surf_height(ds):
    H = np.zeros_like(X); kS = 0.04
    def smax(A, B): return kS * np.logaddexp(A / kS, B / kS) - kS * np.log(2) * np.exp(-np.abs(A - B) / kS)
    for d in ds:
        x, a, b, W, Rr = head_x(d)
        rho2 = x / 0.65                                       # 1 at the drawn contact line
        hc = d['R'] * (1 - np.cos(TH)) / np.sin(TH)
        cap = np.where(rho2 < 1, hc * (np.sqrt(np.clip(1 - rho2 * np.sin(TH) ** 2, 0, None)) - np.cos(TH)) / (1 - np.cos(TH)), 0)
        H = np.maximum(H, cap) if d['L'] == 0 else smax(H, cap)
        if d['L'] > 0:
            w, ht, nk, bt, on = tail_geom(d, W, Rr)
            Rc = (w * w + ht * ht) / np.maximum(2 * ht, 1e-6)        # circular-arc section, apex ht, half-width w
            sec = np.where(on & (np.abs(bt) < w), np.sqrt(np.clip(Rc * Rc - bt * bt, 0, None)) - (Rc - ht), 0)
            H = smax(H, np.clip(sec, 0, None))
    H = np.clip(H - 1e-4, 0, None)
    gy, gx = np.gradient(H, PX)
    slope = np.hypot(gx, gy)
    g = np.stack([gx, gy], -1); g /= np.maximum(np.linalg.norm(g, axis=-1, keepdims=True), 1e-9)
    return H > 0, slope, g


def shade(mask, slope, g):
    al = np.arctan(slope)
    sn = N_W * np.sin(al)
    tir = np.clip((sn - 0.96) / 0.08, 0, 1)
    dev = np.arcsin(np.clip(sn, 0, 1)) - al
    K = 0.55 * BG.shape[1] / 1.2                    # px per radian of the scene
    cy, cx = (np.mgrid[0:X.shape[0], 0:X.shape[1]] + X.shape[0])
    cx = cx + X.shape[1] - X.shape[0]
    sy = cy + K * np.tan(dev) * g[..., 1]
    sx = cx + K * np.tan(dev) * g[..., 0]
    img = np.stack([ndimage.map_coordinates(BG[..., c], [sy, sx], order=1, mode='nearest') for c in range(3)], -1)
    img *= (1 - 0.65 * tir)[..., None]
    base = BG[X.shape[0]:2 * X.shape[0], X.shape[1]:2 * X.shape[1]]
    m = ndimage.gaussian_filter(mask.astype(float), 0.7)[..., None]
    return np.clip(base * (1 - m) + img * m, 0, 1)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'rainfx2_heightfield_lens_proto.png'
    ds = drops()
    A = shade(*surf_current(ds)); B = shade(*surf_height(ds))
    n = 3 if len(sys.argv) > 2 else 2
    fig, axs = plt.subplots(2, n, figsize=(7 * n, 10.4))
    ax = axs[0]
    ax[0].imshow(A); ax[0].set_title('current: per-primitive lens union (B3g)')
    ax[1].imshow(B); ax[1].set_title('B3h: one height field, refraction from grad H')
    zy, zx = slice(int(2.5 / PX), int(12.5 / PX)), slice(int(1.0 / PX), int(11.0 / PX))      # the big head + tail
    axs[1][0].imshow(A[zy, zx]); axs[1][0].set_title('current (zoom: head / tail junction)')
    axs[1][1].imshow(B[zy, zx]); axs[1][1].set_title('B3h (zoom)')
    if n == 3:
        ax[2].imshow(plt.imread(sys.argv[2]), cmap='gray'); ax[2].set_title('reference (flow study)')
        axs[1][2].axis('off')
    for a in axs.ravel(): a.axis('off')
    plt.tight_layout(); plt.savefig(out, dpi=95)
    print('saved', out)


if __name__ == '__main__':
    main()
