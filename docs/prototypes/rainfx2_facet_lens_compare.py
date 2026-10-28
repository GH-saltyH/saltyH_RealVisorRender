"""Offline check of the drop lens look (docs/RAINFX_V2_CORE.md section 54, user rev41 review item 5).

Ray-traces one sessile drop (spherical cap, contact angle theta, n = 1.333) on a visor plane in front
of the eye, looking at a far scene given as an image (vertical FOV 56 deg, like the game camera):
  eye ray -> flat contact face (refract in) -> cap (refract out, TIR -> dark interior) -> scene.
Variants (columns, --modes):
  A smooth cap, footprint-filtered (16 samples / px)          = physical reference
  B rev36-rev41 side-view band (rimSharp 3: only the outer third of the radius is tilted) = the
    'flat aluminium' interior of the rev41 review
  C low-poly cap: polar facets (rings x sectors, seeded twist), one normal per facet
  D like C, then a disc blur (defocus) of 2.5 px
  E rev43 shader rule: physical cap, ONE image, off-frame directions compressed into the frame
  F rev43 low-poly: seeded hexagon outline, 3 flat rings, same one-image rule
Rows: drop placed at several screen heights (sky / horizon / ground behind it).

usage: python rainfx2_facet_lens_compare.py scene.png out.png [--r 34]
"""
import argparse
import math
import numpy as np
from PIL import Image, ImageFilter

ap = argparse.ArgumentParser()
ap.add_argument('scene')
ap.add_argument('out')
ap.add_argument('--r', type=float, default=34.0, help='drop radius on screen, px')
ap.add_argument('--theta', type=float, default=55.0)
ap.add_argument('--modes', default='ABEF', help='A smooth physical, B rev41 band, C/D rev42 polar facets, E rev43 one-image, F rev43 low-poly')
ap.add_argument('--rings', type=int, default=4)
ap.add_argument('--sectors', type=int, default=8)
a = ap.parse_args()

scene = np.asarray(Image.open(a.scene).convert('RGB'), np.float32) / 255.0
H, W = scene.shape[:2]
fy = (H / 2) / math.tan(math.radians(28.0))          # px per unit tangent
n_w = 1.333
th = math.radians(a.theta)


def look(d, compress=False):
    """Scene colour for unit directions d (..., 3), camera looks +z, y up.
    compress: rev43 shader rule -- off-frame directions squeezed continuously into the frame."""
    z = np.maximum(d[..., 2], 1e-3)
    px = W / 2 + d[..., 0] / z * fy
    py = H / 2 - d[..., 1] / z * fy
    if compress:
        ux, uy = px / W - 0.5, py / H - 0.5
        ux = np.where(d[..., 2] < 0.05, np.sign(ux) * 4, ux)
        uy = np.where(d[..., 2] < 0.05, np.sign(uy) * 4, uy)
        k = lambda u: u / np.sqrt(np.sqrt(1 + (np.abs(u) / 0.49) ** 4))
        px, py = (k(ux) + 0.5) * W, (k(uy) + 0.5) * H
    out = (d[..., 2] < 0.05) | (px < 0) | (px >= W) | (py < 0) | (py >= H)
    xi = np.clip(px, 0, W - 1).astype(int)
    yi = np.clip(py, 0, H - 1).astype(int)
    c = scene[yi, xi]
    # off screen: simple environment, sky above, dim ground below
    env = np.where(d[..., 1:2] > 0, np.array([0.80, 0.83, 0.86]), np.array([0.18, 0.18, 0.19]))
    return np.where(out[..., None], env, c)


def refract(i, n, eta):
    ci = -np.sum(i * n, -1, keepdims=True)
    k = 1 - eta * eta * (1 - ci * ci)
    t = eta * i + (eta * ci - np.sqrt(np.maximum(k, 0))) * n
    return t, k[..., 0]


def drop_tile(cx, cy, mode, R, seed=3):
    S = 4
    size = int(R * 2.6)
    yy, xx = np.mgrid[0:size * S, 0:size * S].astype(np.float32)
    lx = (xx + 0.5) / S - size / 2                      # px from the drop centre
    ly = (yy + 0.5) / S - size / 2
    rr = np.sqrt(lx * lx + ly * ly) / R                 # radial fraction
    inside = rr < 1
    # eye ray through this pixel
    sx, sy = cx + lx, cy + ly
    v = np.stack([(sx - W / 2) / fy, -(sy - H / 2) / fy, np.ones_like(sx)], -1)
    v /= np.linalg.norm(v, axis=-1, keepdims=True)
    base = look(v)
    # cap geometry: sphere radius Rc = R / sin(theta); slope from the radial fraction
    rq, phi = rr.copy(), np.arctan2(-ly, lx)            # phi: screen angle, y up
    if mode == 'F':                                     # rev43 polygon + flat rings
        rng = np.random.default_rng(seed)
        ns = 6
        rot = rng.uniform(0, 2 * math.pi)
        stp = 2 * math.pi / ns
        sec = np.floor((phi - rot) / stp)
        m = rot + (sec + 0.5) * stp
        sA = math.sqrt(ns * math.tan(stp / 2) / math.pi) * (1 + 0.14 * (rng.uniform(size=ns + 2)[(sec % ns).astype(int)] - 0.5))
        dp = np.maximum(lx * np.cos(m) + (-ly) * np.sin(m), 0) * sA / R
        inside = dp < 1
        rings = 3
        ring = np.minimum(np.floor(dp * rings), rings - 1)
        rq = ring / rings                               # each flat band at its inner slope
        phi = m
    if mode in ('C', 'D'):
        rng = np.random.default_rng(seed)
        twist = rng.uniform(0, 2 * math.pi)
        ring = np.minimum(np.floor(rr * a.rings), a.rings - 1)
        rq = (ring + 0.5) / a.rings
        nsec = np.maximum(1, np.round(a.sectors * (ring + 0.5) / a.rings * 2)).astype(np.float32)
        nsec = np.where(ring == 0, 1.0, nsec)
        step = 2 * math.pi / nsec
        phi = (np.floor((phi - twist * ring) / step) + 0.5) * step + twist * ring
        rq = np.where(ring == 0, 0.0, rq)
    if mode == 'B':
        rq = np.clip((rq - (1 - 1 / 3.0)) * 3.0, 0, 1)
    s = np.clip(rq * math.sin(th), 0, 0.9999)
    tilt = np.arcsin(s)                                  # cap surface angle at this radius
    # outward normal: visor normal (+z) tilted away from the centre
    N = np.stack([np.sin(tilt) * np.cos(phi), np.sin(tilt) * np.sin(phi), np.cos(tilt)], -1)
    vw, _ = refract(v, np.array([0, 0, -1.0]), 1 / n_w)  # into the water through the flat face
    vo, k = refract(vw, -N, n_w)                          # out through the cap
    col = look(vo, compress=(mode in ('E', 'F')))
    tir = (k < 0)[..., None]
    col = np.where(tir, (col * 0.35) if mode in ('E', 'F') else base * 0.25, col)
    col = np.where(inside[..., None], col, base)
    img = col.reshape(size, S, size, S, 3).mean((1, 3))
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
    if mode == 'D':
        im = im.filter(ImageFilter.GaussianBlur(1.6))
    return im


rows = [0.30, 0.45, 0.55, 0.70]
R = a.r
tile = int(R * 2.6)
canvas = Image.new('RGB', (tile * len(a.modes), tile * len(rows)), (0, 0, 0))
for j, fyr in enumerate(rows):
    cx, cy = W * 0.35, H * fyr
    for i, m in enumerate(a.modes):
        canvas.paste(drop_tile(cx, cy, m, R), (i * tile, j * tile))
canvas = canvas.resize((canvas.width * 2, canvas.height * 2), Image.NEAREST)
canvas.save(a.out)
print('saved', a.out)
