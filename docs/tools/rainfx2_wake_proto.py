"""W0 wake-film prototype (docs/RAINFX_V2_TRAIL_REVIEW3.md section 5).

A head drop runs along a curved path over a 0.59 mm height field (the game's field). Behind its rear contact line it
lays a wake film (Landau-Levich / Bretherton deposit) whose half-width follows the Cox-Voinov excess s = Ca / Ca*(theta*):
  Ca* = theta*^3 / (9 ln(r / 1 nm)),  hw = r sqrt(1 - 1/s),  h0 = cLL r Ca^(2/3)   (parabolic section, (4/3) h0 hw per mm)
The head loses the deposited volume. The film then
  - flows with the air shear (u = tau h / 2 mu, mass-conserving upwind),
  - retreats at its edges where the edge angle is below theta* (Cox-Voinov dewetting speed, water moves inward),
  - drops residue below 6 um (R2d -> haze).
Rendering: bicubic upsample of the field (as the game samples it), the head as a spherical cap (contact angle 60 deg),
one water surface = smooth max of head and film; refraction offset ~ slope, edge darkening ~ slope^2, optional defocus.
Old model for comparison: straight per-frame line segments (hw = 0.25 r), only the last one connected, older ones bead rows.

usage: python rainfx2_wake_proto.py out.png [ref1.png ref2.png]
"""
import sys
import numpy as np
from scipy import ndimage
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

DX = 0.59                      # mm, field texel
W_MM, H_MM = 40.0, 28.0
NX, NY = int(W_MM / DX), int(H_MM / DX)
UP = 10                        # render upsampling (0.074 mm / px)
MU, TAU = 1e-3, 13.3           # Pa s, Pa (240 km/h, Cf 0.005)
CLL = 1.34                     # Bretherton / Landau-Levich coefficient (game trailLL = 5.0)
CONTACT = np.radians(60.0)
SHAPEK = np.pi * (2 - 3 * np.cos(CONTACT) + np.cos(CONTACT) ** 3) / (3 * np.sin(CONTACT) ** 3)


def path(u):                   # u in [0, 1] -> mm, an S curve along the air direction (down-right)
    x = 4 + 32 * u
    y = 4 + 19 * u + 3.0 * np.sin(2 * np.pi * u * 1.1)
    return np.array([x, y])


def simulate(theta_deg, r0, speed, t_end, retreat=True, snap_times=()):
    th = np.radians(theta_deg)
    h = np.zeros((NY, NX))
    xs = (np.arange(NX) + 0.5) * DX
    ys = (np.arange(NY) + 0.5) * DX
    X, Y = np.meshgrid(xs, ys)
    # arc-length parametrisation
    uu = np.linspace(0, 1, 4000)
    P = np.array([path(u) for u in uu])
    sl = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))])
    vol = SHAPEK * r0 ** 3
    dt = 0.0005
    t, s_mm = 0.0, 0.0
    air = (P[-1] - P[0]) / np.linalg.norm(P[-1] - P[0])
    snaps = {}
    lost = 0.0
    while t < t_end - 1e-9:
        r = (max(vol, 0) / SHAPEK) ** (1 / 3)
        s_new = min(s_mm + speed * dt, sl[-1] - 1e-3)
        p0 = np.array([np.interp(s_mm, sl, P[:, 0]), np.interp(s_mm, sl, P[:, 1])])
        p1 = np.array([np.interp(s_new, sl, P[:, 0]), np.interp(s_new, sl, P[:, 1])])
        d = p1 - p0
        ds = np.linalg.norm(d)
        if ds > 1e-6 and r > 0.15:
            dirv = d / ds
            ca = speed / 72000.0                              # U / (gamma / mu), mm/s -> m/s / 72
            cas = th ** 3 / (9 * np.log(r * 1e6))
            sR = ca / cas
            if sR > 1:
                hw = r * np.sqrt(1 - 1 / sR)
                h0 = CLL * r * ca ** (2 / 3)
                a, b = p0 - dirv * r, p1 - dirv * r            # rear contact line sweep
                ab = b - a
                tt = np.clip(((X - a[0]) * ab[0] + (Y - a[1]) * ab[1]) / max(ab @ ab, 1e-12), 0, 1)
                dd = np.hypot(X - (a[0] + ab[0] * tt), Y - (a[1] + ab[1] * tt))
                prof = np.where(dd < hw, h0 * (1 - (dd / hw) ** 2), 0)
                before = h.sum()
                h = np.maximum(h, prof)
                laid = (h.sum() - before) * DX * DX
                vol -= laid
                lost += laid
        # film flow with the air shear (upwind, conservative)
        u = TAU * (h * 1e-3) / (2 * MU) * 1e3                 # mm/s
        for k, (sx, sy) in enumerate(((1, 0), (0, 1))):
            c = air[k]
            if abs(c) < 1e-6:
                continue
            flux = np.clip(u * abs(c) * dt / DX, 0, 0.9) * h  # depth leaving downstream
            sh = (0, int(np.sign(c))) if sx else (int(np.sign(c)), 0)
            moved = np.roll(flux, sh, axis=(0, 1))
            if sx:
                (moved[:, 0] if c > 0 else moved[:, -1])[:] = 0
            else:
                (moved[0, :] if c > 0 else moved[-1, :])[:] = 0
            h = h - flux + moved
        # edge retreat (dewetting) where the edge angle is below theta*
        if retreat:
            wet = h > 0.006
            nb = [np.roll(h, s, axis=a) for a in (0, 1) for s in (1, -1)]
            edge = wet & np.any([n <= 0.006 for n in nb], axis=0)
            ang = np.arctan(h / DX)
            v = 72000.0 * np.clip(th ** 3 - ang ** 3, 0, None) / (9 * np.log(2e6))   # mm/s
            f = np.where(edge, np.clip(v * dt / DX, 0, 1), 0)
            give = f * h
            stack = np.stack(nb)
            best = np.argmax(stack, axis=0)                   # inward neighbour (most water)
            h = h - give
            for i, (a, s) in enumerate(((0, 1), (0, -1), (1, 1), (1, -1))):
                h += np.roll(np.where(best == i, give, 0), -s, axis=a)
        h[h < 0.006] = 0                                      # R2d residue -> haze
        s_mm = s_new
        t += dt
        for ts in snap_times:
            if abs(t - ts) < dt / 2:
                snaps[ts] = (h.copy(), p1.copy(), (max(vol, 0) / SHAPEK) ** (1 / 3), dirv if ds > 1e-6 else air)
    return h, p1, (max(vol, 0) / SHAPEK) ** (1 / 3), snaps, lost


def old_model(r0, speed, t_end):
    """rev47j-R2: one straight line per 13 ms frame (hw 0.25 r); the last one connected, older ones bead rows."""
    lines, frame = [], 1 / 75
    uu = np.linspace(0, 1, 4000)
    P = np.array([path(u) for u in uu])
    sl = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))])
    n = int(t_end / frame)
    pos = lambda s: np.array([np.interp(s, sl, P[:, 0]), np.interp(s, sl, P[:, 1])])
    for i in range(n):
        a, b = pos(speed * frame * i), pos(speed * frame * (i + 1))
        dirv = (b - a) / max(np.linalg.norm(b - a), 1e-6)
        lines.append((a - dirv * r0, b - dirv * r0, i == n - 1))
    return lines, pos(speed * frame * n), dirv


def tail_drop(r0, speed, t, theta_deg, tail_share=0.35):
    """Concept B: the drop at Ca > Ca*(theta*) is a head + an ATTACHED tail (rivulet drop, Podgorski 2001 / Le Grand 2005):
    the tail lies on the head's own path (its last L mm), moves with the head, tapers from the head width to 0.
    L = r * 4 * (s - 1) (free fit, <= 8 r); the tail holds tail_share of the volume (its end pinches off pearls)."""
    th = np.radians(theta_deg)
    uu = np.linspace(0, 1, 4000)
    P = np.array([path(u) for u in uu])
    sl = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=1))])
    sh = speed * t
    pos = lambda q: np.array([np.interp(q, sl, P[:, 0]), np.interp(q, sl, P[:, 1])])
    ca = speed / 72000.0
    sR = ca / (th ** 3 / (9 * np.log(r0 * 1e6)))
    L = min(r0 * 4.0 * max(sR - 1, 0), 8 * r0)
    return pos(sh), L, sh, pos, sR


def render_tail(r0, speed, t, theta_deg, defocus=0.0):
    p, L, sh, pos, sR = tail_drop(r0, speed, t, theta_deg)
    ny, nx = NY * UP, NX * UP
    px = DX / UP
    Y, X = (np.mgrid[0:ny, 0:nx] + 0.5) * px
    Rs = r0 / np.sin(CONTACT)
    hc = Rs * (1 - np.cos(CONTACT))
    surf = np.zeros((ny, nx))
    n = 60
    for i in range(n + 1):                                   # tail = chain of caps along the path, tapering (one surface)
        xi = i / n
        q = pos(max(sh - r0 * 0.6 - xi * L, 0))
        w = r0 * 0.75 * (1 - xi) ** 0.8
        if w < 0.08:
            continue
        hh = hc * 0.55 * (1 - xi) ** 0.6
        d2 = (X - q[0]) ** 2 + (Y - q[1]) ** 2
        surf = np.maximum(surf, np.where(d2 < w * w, hh * (1 - d2 / (w * w)), 0))
    d2 = (X - p[0]) ** 2 + (Y - p[1]) ** 2
    surf = np.maximum(surf, np.where(d2 < r0 * r0, np.sqrt(np.clip(Rs * Rs - d2, 0, None)) - (Rs - hc), 0))
    surf = ndimage.gaussian_filter(surf, 1.5)                # meniscus smoothing between head and tail
    return shade(surf, defocus), sR, L


def background(nx, ny):
    yy, xx = np.mgrid[0:ny, 0:nx] / np.array([ny, nx])[:, None, None]
    img = np.zeros((ny, nx, 3))
    sky = np.array([0.62, 0.70, 0.72])
    dark = np.array([0.16, 0.18, 0.19])
    m = 1 / (1 + np.exp(-(yy - 0.42 - 0.08 * np.sin(xx * 5)) * 40))
    img = sky * (1 - m[..., None]) + dark * m[..., None]
    for k in range(9):                                       # poles / structure
        x0 = 0.08 + k * 0.11
        img[(np.abs(xx - x0 - 0.15 * yy) < 0.006) & (yy < 0.45)] = [0.25, 0.27, 0.28]
    img[(np.abs(yy - 0.62 - 0.1 * xx) < 0.01)] = [0.75, 0.75, 0.72]          # a light edge on the dark part
    rng = np.random.default_rng(3)
    for _ in range(40):
        cx, cy, rr = rng.random(), 0.45 + 0.5 * rng.random(), 0.01 + 0.02 * rng.random()
        img[(xx - cx) ** 2 + (yy - cy) ** 2 < rr ** 2] = 0.3 + 0.4 * rng.random()
    return ndimage.gaussian_filter(img, (2, 2, 0))


def render(hfield, heads, lines=None, defocus=0.0):
    hf = ndimage.zoom(hfield, UP, order=3)
    hf = np.clip(hf, 0, None)
    ny, nx = hf.shape
    px = DX / UP
    Y, X = (np.mgrid[0:ny, 0:nx] + 0.5) * px
    surf = hf.copy()
    Rs = None
    for (p, r, dirv) in heads:                               # spherical caps
        Rs = r / np.sin(CONTACT)
        hc = Rs * (1 - np.cos(CONTACT))
        d2 = (X - p[0]) ** 2 + (Y - p[1]) ** 2
        cap = np.where(d2 < r * r, np.sqrt(np.clip(Rs * Rs - d2, 0, None)) - (Rs - hc), 0)
        surf = np.maximum(surf, cap)                         # head and film: one water surface (union of heights)
    if lines:
        for (a, b, fresh) in lines:
            ab = b - a
            r = heads[0][1]
            hw = 0.25 * r
            if fresh:
                tt = np.clip(((X - a[0]) * ab[0] + (Y - a[1]) * ab[1]) / max(ab @ ab, 1e-12), 0, 1)
                dd = np.hypot(X - (a[0] + ab[0] * tt), Y - (a[1] + ab[1] * tt))
                h0 = 0.45 * hw / 2
                surf = np.maximum(surf, np.where(dd < hw, h0 * (1 - (dd / hw) ** 2), 0))
            else:                                            # bead row, spacing 9 hw
                L = np.linalg.norm(ab)
                n = max(int(L / (9 * hw)), 1)
                for j in range(n):
                    c = a + ab * (j + 0.5) / n
                    rb = 0.3 * r
                    d2 = (X - c[0]) ** 2 + (Y - c[1]) ** 2
                    Rb = rb / np.sin(CONTACT)
                    surf = np.maximum(surf, np.where(d2 < rb * rb, np.sqrt(np.clip(Rb * Rb - d2, 0, None)) - Rb * np.cos(CONTACT), 0))
    return shade(surf, defocus), surf


def shade(surf, defocus=0.0):
    ny, nx = surf.shape
    px = DX / UP
    Y, X = (np.mgrid[0:ny, 0:nx] + 0.5) * px
    gy, gx = np.gradient(surf, px)
    bg = background(nx, ny)
    K = 4.0 / px                                      # px of shift per unit slope (visor-scene distance)
    sx = np.clip(X / px - K * gx, 0, nx - 1)
    sy = np.clip(Y / px - K * gy, 0, ny - 1)
    out = np.stack([ndimage.map_coordinates(bg[..., c], [sy - 0.5, sx - 0.5], order=1) for c in range(3)], -1)
    s2 = gx * gx + gy * gy
    out *= (1 - 0.55 * np.clip(s2 / (1 + s2), 0, 1))[..., None]          # edge darkening (Fresnel / TIR at steep slope)
    out += 0.25 * np.clip(-(gx * 0.5 + gy * 0.8) / np.sqrt(1 + s2), 0, 1)[..., None] ** 6   # highlight
    if defocus > 0:
        out = ndimage.gaussian_filter(out, (defocus, defocus, 0))
    return np.clip(out, 0, 1)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'wake_proto.png'
    refs = sys.argv[2:4]
    r0, speed, t_end = 1.7, 350.0, 0.10
    rows = []
    lines, pOld, dOld = old_model(r0, speed, t_end)
    rows.append(('current model: straight line per frame (hw 0.25 r), older lines = bead rows',
                 render(np.zeros((NY, NX)), [(pOld, r0, dOld)], lines=lines)[0]))
    for name, th in (('A wake film (Landau-Levich deposit in the field), theta* 15 deg', 15.0),
                     ('A wake film, theta* 33 deg (heavy-rain haze estimate)', 33.0)):
        h, p, r, snaps, lost = simulate(th, r0, speed, t_end)
        print(f'{name}: head r {r0:.2f} -> {r:.2f} mm, laid {lost:.2f} mm3, film left {h.sum() * DX * DX:.2f} mm3, max h {h.max():.3f} mm')
        rows.append((f'{name}\nmax film {h.max() * 1000:.0f} um', render(h, [(p, r, None)])[0]))
    for th in (15.0, 33.0):
        img, sR, L = render_tail(r0, speed, t_end, th)
        print(f'B attached tail theta* {th}: s = {sR:.2f}, tail {L:.1f} mm')
        rows.append((f'B attached tail (rivulet drop), theta* {th:.0f} deg: s = {sR:.2f}, tail {L:.1f} mm', img))
    img, sR, L = render_tail(r0, speed, t_end, 15.0, defocus=6.0)
    rows.append(('B, theta* 15 deg, defocused (eye on the road, like the reference)', img))
    n = len(rows) + len(refs)
    cols = 3
    nr = (n + cols - 1) // cols
    fig = plt.figure(figsize=(16, 4.3 * nr))
    k = 1
    for i, rp in enumerate(refs):
        ax = fig.add_subplot(nr, cols, k); k += 1
        ax.imshow(plt.imread(rp)); ax.set_title(f'reference {i + 1}'); ax.axis('off')
    for title, img in rows:
        ax = fig.add_subplot(nr, cols, k); k += 1
        ax.imshow(img); ax.set_title(title, fontsize=9); ax.axis('off')
    plt.tight_layout()
    plt.savefig(out, dpi=80)
    fig2, axs = plt.subplots(1, 3, figsize=(16, 4.4))
    for ax, ts in zip(axs, (0.04, 0.07, 0.10)):
        img, sR, L = render_tail(r0, speed, ts, 15.0)
        ax.imshow(img); ax.set_title(f'B over time: t = {ts * 1000:.0f} ms (tail moves with the head)'); ax.axis('off')
    plt.tight_layout()
    plt.savefig(out.replace('.png', '_time.png'), dpi=80)


if __name__ == '__main__':
    main()
