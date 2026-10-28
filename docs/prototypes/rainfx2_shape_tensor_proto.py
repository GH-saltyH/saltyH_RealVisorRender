"""rev47k research: low-cost drop SHAPE STATE (docs/RAINFX_V2_SHAPE_STATE_PLAN.md).

One analytic kernel per drop, as in the visor shader (dome h = 1 - x, plano-convex lens), whose contour is
  q' = M^-1/2 q / (1 + delta(phi))      (M: 2x2 shape tensor, unit area; delta: contour harmonics)
  delta(phi) = sum_k a_k cos(k phi + p_k)  +  tail * max(0, cos(phi - phi_t))^4   (impact / slide tail)
so every shape class of the review (oblique impact splat torn downward, steep round splat with fingers,
merged elongated puddle, wide flat puddle, sliding ellipse) is the SAME kernel with 4-6 numbers per drop.
The lens is the physical one (flat contact face in, cap out, n = 1.333, TIR -> dark), scene at infinity.

usage: python rainfx2_shape_tensor_proto.py scene.png out.png
"""
import argparse
import math
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as nd

ap = argparse.ArgumentParser()
ap.add_argument('scene')
ap.add_argument('out')
ap.add_argument('--pxmm', type=float, default=26.0, help='screen px per visor mm (near-eye ~25-35)')
ap.add_argument('--seed', type=int, default=3)
a = ap.parse_args()
rng = np.random.default_rng(a.seed)

src = np.asarray(Image.open(a.scene).convert('RGB'), np.float32) / 255.0
scene = np.stack([nd.median_filter(src[..., c], 9) for c in range(3)], -1)
SH, SW = scene.shape[:2]
FOCAL = 1354.0                         # px per unit tangent (game frame 1440 px high, 56 deg FOV)


def sample(x, y):
    xi = np.clip(x, 0, SW - 1).astype(int)
    yi = np.clip(y, 0, SH - 1).astype(int)
    return scene[yi, xi]


def drop_field(Wp, Hp, drops):
    """Union of shaped dome kernels -> height (mm) and its gradient, as the shader's metaball union."""
    yy, xx = np.mgrid[0:Hp, 0:Wp].astype(np.float32) / a.pxmm
    P = np.ones((Hp, Wp), np.float32)
    hmax = np.zeros((Hp, Wp), np.float32)
    for d in drops:
        qx, qy = xx - d['x'], yy - d['y']
        # shape tensor: aspect A along angle ang, unit area
        A, ang = d.get('A', 1.0), d.get('ang', 0.0)
        c, s = math.cos(ang), math.sin(ang)
        u = (qx * c + qy * s) / math.sqrt(A)
        v = (-qx * s + qy * c) * math.sqrt(A)
        phi = np.arctan2(v, u)
        delta = np.zeros_like(u)
        for k, amp, ph in d.get('harm', []):
            delta += amp * np.cos(k * phi + ph)
        if d.get('tail', 0) > 0:      # tail toward local angle 0 (= along the tensor axis, sign by tailDir)
            delta += d['tail'] * np.maximum(np.cos(phi - d.get('tailDir', 0.0)), 0) ** 4
        R = d['r'] * 1.24 * (1.0 + delta)
        x = (u * u + v * v) / np.maximum(R * R, 1e-6)
        h = np.clip(1.0 - x, 0, 1)
        P *= 1.0 - h
        # physical height: cap of contact angle theta over radius r
        hmax = np.maximum(hmax, h * d['r'] * math.tan(math.radians(d.get('theta', 55)) * 0.5))
    U = 1.0 - P
    cov = np.clip((U - 0.35) / 0.08 + 0.5, 0, 1)
    gy, gx = np.gradient(hmax, 1.0 / a.pxmm)
    return cov, gx, gy


def render(Wp, Hp, drops, ox, oy):
    cov, gx, gy = drop_field(Wp, Hp, drops)
    yy, xx = np.mgrid[0:Hp, 0:Wp].astype(np.float32)
    bx, by = xx + ox, yy + oy
    base = sample(bx, by)
    # plano-convex lens, view ray along +z: cap normal N = (-gx, -gy, 1)
    nz = 1.0 / np.sqrt(1 + gx * gx + gy * gy)
    Nx, Ny = -gx * nz, -gy * nz
    eta = 1.333                                      # water -> air through the cap (ray (0,0,1) inside)
    k = 1.0 - eta * eta * (1 - nz * nz)
    sk = np.sqrt(np.maximum(k, 0))
    m = eta * nz - sk                                # T = eta I - m No,  No = (Nx, Ny, nz)
    vx, vy, vz = -m * Nx, -m * Ny, np.maximum(eta - m * nz, 0.05)
    lx, ly = bx + vx / vz * FOCAL, by + vy / vz * FOCAL
    col = sample(lx, ly)
    tir = np.clip((0.04 - k) / 0.08, 0, 1)
    col = col * (1 - 0.65 * tir)[..., None]
    up = np.clip(gy, 0, None) / (1 + np.abs(gy))     # rim facing up catches sky light
    col = col + 0.25 * (up ** 3)[..., None]
    out = base * (1 - cov[..., None]) + col * cov[..., None]
    return np.clip(out, 0, 1)


def harm(lo, hi, n, amp):
    return [(int(k), amp * rng.uniform(0.4, 1.0) / k ** 0.5, rng.uniform(0, 6.283)) for k in rng.integers(lo, hi, n)]


DOWN = math.pi / 2                     # +y on screen = down (gravity)
panels = []
# 1 current: round + seeded ellipse
panels.append(('1 current (rev47): round, seeded ellipse 1-1.22',
               [dict(x=3 + 6 * (i % 2), y=3 + 3 * (i // 2), r=r, A=1 + 0.22 * rng.random(), ang=rng.uniform(0, 3.14))
                for i, r in enumerate([1.0, 0.6, 1.4, 0.8, 0.5, 1.1])]))
# 2 impact at rest: incidence ~80 deg -> aspect ~3 down, tail down, fingers downstream, satellites below
d2 = []
for i, (x, y, r) in enumerate([(3, 2.5, 0.9), (8.5, 3.0, 0.7), (5.5, 8.5, 1.1)]):
    # blunt, finger-edged front downstream (local angle 0 = down), narrow upstream end
    d2.append(dict(x=x, y=y, r=r, A=2.2, ang=DOWN, tail=0.35, tailDir=0.0, harm=harm(2, 5, 3, 0.07), theta=45))
    for j in range(rng.integers(2, 5)):             # lamella fingers broke off: satellites downstream
        d2.append(dict(x=x + rng.normal(0, 0.5 * r), y=y + r * rng.uniform(1.8, 3.0), r=r * rng.uniform(0.15, 0.3), theta=50))
panels.append(('2 impact at rest (incidence ~80 deg): splat torn downward', d2))
# 3 impact at speed: near-normal -> round, radial fingers, satellites all around
d3 = []
for (x, y, r) in [(3, 3, 0.9), (8, 4, 0.6), (5, 8.5, 1.2)]:
    # fingers detach as satellites; on the drop only low modes survive (high modes relax ~1/k faster)
    d3.append(dict(x=x, y=y, r=r, A=1.1, ang=rng.uniform(0, 3), harm=harm(2, 6, 3, 0.07), theta=45))
    for j in range(rng.integers(3, 6)):
        an = rng.uniform(0, 6.283)
        d3.append(dict(x=x + math.cos(an) * r * 1.9, y=y + math.sin(an) * r * 1.9, r=r * rng.uniform(0.12, 0.25)))
panels.append(('3 impact at speed (near-normal): round splat, radial satellites', d3))
# 4 coalescence: merged tensor (second moments), irregular low harmonics, relaxing
d4 = [dict(x=3.5, y=3, r=1.3, A=2.2, ang=0.4, harm=harm(2, 4, 2, 0.12), theta=50),
      dict(x=7.5, y=7, r=1.0, A=1.6, ang=2.2, harm=harm(2, 4, 2, 0.10), theta=50),
      dict(x=3, y=8.5, r=0.9, A=1.15, ang=1.0, harm=harm(2, 3, 1, 0.05), theta=55)]
panels.append(('4 merged: elongated on the merge axis, relaxing', d4))
# 5 wide puddle: low contact angle, big irregular contour
d5 = [dict(x=5.5, y=5, r=2.6, A=1.5, ang=0.2, harm=harm(2, 5, 4, 0.10), theta=30),
      dict(x=2, y=9, r=0.6, theta=50), dict(x=9.5, y=9.2, r=0.5, theta=50)]
panels.append(('5 wide puddle: low contact angle 30 deg, irregular contour', d5))
# 6 sliding: stretched along motion, tail behind
d6 = [dict(x=3 + 3 * i, y=2.5 + 2.5 * i, r=r, A=1.6, ang=DOWN, tail=0.5, tailDir=math.pi, theta=45, harm=harm(2, 4, 1, 0.04))
      for i, r in enumerate([1.1, 0.8, 1.3])]
panels.append(('6 sliding: ellipse along motion + tail behind (runback / gravity)', d6))

Wp = Hp = int(11.5 * a.pxmm)
gap, title = 8, 22
img = Image.new('RGB', (3 * Wp + 4 * gap, 2 * (Hp + title) + 3 * gap), (24, 24, 24))
dr = ImageDraw.Draw(img)
for i, (name, drops) in enumerate(panels):
    ox = int(rng.uniform(0.15 * SW, 0.55 * SW))
    oy = int(rng.uniform(0.08 * SH, 0.30 * SH))
    out = render(Wp, Hp, drops, ox, oy)
    cx, cy = gap + (i % 3) * (Wp + gap), gap + (i // 3) * (Hp + title + gap)
    img.paste(Image.fromarray((out * 255).astype(np.uint8)), (cx, cy + title))
    dr.text((cx + 2, cy + 4), name, fill=(230, 230, 230))
img.save(a.out)
print('saved', a.out, img.size)
