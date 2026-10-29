"""P0 water-sheet prototype (docs/RAINFX_V2_WATER_SHEET_PLAN.md section 5).

One engine, three forms of the same water: DROPS (entities, r <= rSheet), the SHEET height field h (field
texels of 0.6 mm, no size limit) and the mass ledger linking them. Checks: mass conservation, sheet outline /
waves, pops at the drop <-> sheet transitions, and the look against the wide-water-flow reference.

Physics (SI inside, mm for h / r):
  sheet flux  q = h^3 rho g_t / (3 mu) + h^2 tau / (2 mu)    (gravity + air shear, lubrication), upwind
              face fluxes, speed capped by uMax (CFL / game substeps), + weak smoothing (surface tension)
  front       a wet texel spills into a DRY neighbour only when h >= hFront (advancing contact angle):
              thin edges stay pinned -> fronts, fingers, rivulets emerge
  dewetting   a thin isolated wet patch (local max of h < hDewet) gathers its 3x3 water into a drop
  drops       slide when gravity + air > pinning (shader law, simplified), merge on contact
  drop->sheet a drop touching sheet water (h >= hJoin under its footprint) or growing above rSheet is
              rasterised into h as its own cap profile (same height = same lens -> no pop)
  impacts     raindrops: on sheet water (h >= hJoin) -> volume into h + agitation a; on dry glass -> a drop
              unresolved share of the rain -> thin film deposited uniformly into h (it dewets into beads)
Render: total height H = max(sheet h (bicubic), drop caps); normal from grad H; refraction of a background
frame, rim darkening by slope, one specular light; agitation and wind waves perturb the sheet surface.
usage: python rainfx2_sheet_proto.py outdir
"""
import math
import os
import sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as nd

OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
os.makedirs(OUT, exist_ok=True)
DX = 0.6                    # mm per field texel
NX, NY = 80, 50             # 48 x 30 mm patch of the visor side
RS = 6                      # render px per texel
FPS, SUB = 60, 8
RHO, MU, G, GAM = 1000.0, 1e-3, 9.81, 0.072

P = dict(hFront=0.22, hJoin=0.10, hBead=0.04, beadRate=4.0, hDewet=0.035, rSheet=1.4, uMax=0.25, smooth=0.12, absorbK=0.5,
         pin=0.072 * 2 * 0.18, pinKin=0.6, vMaxDrop=0.08, aTau=0.08, waveK=0.25)


def bg_image():
    im = Image.open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'rainfx2_sheet_bg.png')).convert('RGB')
    return np.asarray(im.resize((NX * RS, NY * RS)), np.float32) / 255.0


class World:
    def __init__(self, flux_mms, resolved, shear_pa, shear_dir, seed=1, dmean=0.6):
        self.rng = np.random.default_rng(seed)
        self.h = np.zeros((NY, NX))          # sheet water (mm)
        self.a = np.zeros((NY, NX))          # agitation (impact disturbance), decays
        self.drops = []                      # [x mm, y mm, r mm, vx, vy]
        self.flux, self.res, self.tau = flux_mms, resolved, shear_pa
        self.tdir = np.array(shear_dir) / np.linalg.norm(shear_dir)
        self.dmean = dmean
        self.led = dict(rain=0.0, out=0.0)
        self.events = []                     # (kind, x, y) for the pop check
        self.t = 0.0

    # ---------- ledger ----------
    def water(self):
        vs = sum(2.0944 * d[2] ** 3 for d in self.drops)
        return self.h.sum() * DX * DX + vs

    # ---------- sheet ----------
    def sheet_step(self, dt):
        h = self.h
        hm = h * 1e-3
        # depth-averaged velocity (m/s): gravity down (+y) and air shear along tdir
        ug = RHO * G * hm * hm / (3 * MU)
        us = self.tau * hm / (2 * MU)
        ux = us * self.tdir[0]
        uy = ug + us * self.tdir[1]
        sp = np.hypot(ux, uy)
        k = np.minimum(1.0, P['uMax'] / np.maximum(sp, 1e-9))
        ux, uy = ux * k, uy * k
        c = dt * 1000.0 / DX                                  # texels per (m/s)
        out = np.zeros_like(h)
        inn = np.zeros_like(h)
        for (vx, sx, sy) in ((ux, 1, 0), (-ux, -1, 0), (uy, 0, 1), (-uy, 0, -1)):
            f = np.clip(vx, 0, None) * c * h                   # mm moved out of the cell toward (sx, sy)
            f = np.minimum(f, 0.24 * h)
            dst = np.roll(np.roll(h, -sy, 0), -sx, 1)
            # pinned front: no spill into dry glass below hFront
            f = np.where((dst < P['hJoin']) & (h < P['hFront']), 0.0, f)
            # edge of the patch: water leaving the domain (lower / right edge) is lost to the ledger
            out += f
            moved = np.roll(np.roll(f, sy, 0), sx, 1)
            if sx == 1:
                self.led['out'] += f[:, -1].sum() * DX * DX; moved[:, 0] = 0
            if sx == -1:
                self.led['out'] += f[:, 0].sum() * DX * DX; moved[:, -1] = 0
            if sy == 1:
                self.led['out'] += f[-1, :].sum() * DX * DX; moved[0, :] = 0
            if sy == -1:
                self.led['out'] += f[0, :].sum() * DX * DX; moved[-1, :] = 0
            inn += moved
        h = h - out + inn
        # surface tension: smooth only inside wet water (mass conserving 5-point exchange)
        wet = h >= P['hJoin']
        # face exchange between wet neighbours only (antisymmetric -> exact mass)
        fx = np.where(wet[:, 1:] & wet[:, :-1], (h[:, 1:] - h[:, :-1]) * P['smooth'], 0.0)
        fy = np.where(wet[1:, :] & wet[:-1, :], (h[1:, :] - h[:-1, :]) * P['smooth'], 0.0)
        h = h.copy()
        h[:, :-1] += fx; h[:, 1:] -= fx
        h[:-1, :] += fy; h[1:, :] -= fy
        self.h = np.maximum(h, 0.0)
        self.a *= math.exp(-dt / P['aTau'])
        # advect agitation with the sheet (cheap: shift by mean flow)
        if self.a.max() > 0:
            self.a = nd.shift(self.a, (float(np.mean(uy[wet]) if wet.any() else 0) * c,
                                        float(np.mean(ux[wet]) if wet.any() else 0) * c), order=1, mode='constant')

    def dewet(self, dt):
        """film between hBead and hJoin that is not part of a sheet beads up (rev47j rule: event rate beadRate),
        gathering its 3x3 water into one drop -- mass conserving"""
        h = self.h
        core = nd.maximum_filter(h, 5) >= P['hJoin']
        cand = (h >= P['hBead']) & ~core & (h >= nd.maximum_filter(h, 3) - 1e-12)
        cand &= self.rng.random(h.shape) < P['beadRate'] * dt
        ys, xs = np.nonzero(cand)
        for y, x in zip(ys, xs):
            y0, y1, x0, x1 = max(y - 1, 0), min(y + 2, NY), max(x - 1, 0), min(x + 2, NX)
            v = h[y0:y1, x0:x1].sum() * DX * DX
            if v < 2.0944 * 0.05 ** 3:
                continue
            h[y0:y1, x0:x1] = 0
            self.drops.append([(x + 0.5) * DX, (y + 0.5) * DX, (v / 2.0944) ** (1 / 3), 0.0, 0.0])

    # ---------- drops ----------
    def cap_profile(self, d):
        """sheet texels covered by the drop and its cap height there (mm), volume-normalised"""
        x, y, r = d[0], d[1], d[2]
        R = int(math.ceil(r / DX)) + 1
        cx, cy = int(x / DX), int(y / DX)
        ys = np.arange(max(cy - R, 0), min(cy + R + 1, NY))
        xs = np.arange(max(cx - R, 0), min(cx + R + 1, NX))
        if len(ys) == 0 or len(xs) == 0:
            return None
        Y, X = np.meshgrid((ys + 0.5) * DX, (xs + 0.5) * DX, indexing='ij')
        q = np.clip(1 - ((X - x) ** 2 + (Y - y) ** 2) / (r * r), 0, None)
        w = q ** 0.5 * r                                     # hemispherical cap height
        if w.sum() <= 0:
            w = np.zeros_like(w); w[min(cy - ys[0], len(ys) - 1), min(cx - xs[0], len(xs) - 1)] = 1
        return ys, xs, w

    def drop_to_sheet(self, d, kind):
        cp = self.cap_profile(d)
        if cp is None:
            return
        ys, xs, w = cp
        v = 2.0944 * d[2] ** 3
        self.h[np.ix_(ys, xs)] += w / w.sum() * v / (DX * DX)
        self.events.append((kind, d[0], d[1]))

    def drops_step(self, dt):
        keep = []
        for d in self.drops:
            r = d[2]
            rm = r * 1e-3
            m = 1e-6 * 2.0944 * r ** 3
            Fg = np.array([0.0, m * G])
            u = 0.6 * math.sqrt(2 * self.tau / (1.2 * 0.005))  # air at the drop top ~ shear velocity scale
            Fa = 0.25 * 1.2 * math.pi * rm * rm * u * u * self.tdir
            F = Fg + Fa
            Fp = P['pin'] * rm * (P['pinKin'] if abs(d[3]) + abs(d[4]) > 0 else 1.0)
            if np.linalg.norm(F) > Fp:
                v = P['vMaxDrop'] * (1 - math.exp(-(np.linalg.norm(F) - Fp) / (0.15 * rm) / 0.25))
                dv = F / np.linalg.norm(F) * v
            else:
                dv = np.zeros(2)
            d[3] += (dv[0] - d[3]) * (1 - math.exp(-dt / 0.04))
            d[4] += (dv[1] - d[4]) * (1 - math.exp(-dt / 0.04))
            d[0] += d[3] * dt * 1000
            d[1] += d[4] * dt * 1000
            if not (0 <= d[0] < NX * DX and 0 <= d[1] < NY * DX):
                self.led['out'] += 2.0944 * r ** 3
                continue
            cp = self.cap_profile(d)
            if r > P['rSheet']:
                self.drop_to_sheet(d, 'big')
                continue
            if cp is not None:
                ys, xs, w = cp
                sub = self.h[np.ix_(ys, xs)]
                if (sub[w > 0] >= P['hJoin']).any():
                    # coalescence with the sheet over ~2-3 frames: the drop hands over absorbK of its volume per
                    # frame (as its own cap profile) and shrinks, the rest goes at once below r 0.15 mm
                    v = 2.0944 * d[2] ** 3
                    if d[2] < 0.15 or P['absorbK'] >= 1.0:
                        self.drop_to_sheet(d, 'join')
                        continue
                    dv = v * P['absorbK']
                    self.h[np.ix_(ys, xs)] += w / w.sum() * dv / (DX * DX)
                    d[2] = ((v - dv) / 2.0944) ** (1 / 3)
                    self.events.append(('join', d[0], d[1]))
                    d[3] *= 0.5; d[4] *= 0.5                    # held by the sheet while it drains
                    keep.append(d)
                    continue
                # thinner film under the footprint is collected by the drop (sweep, rule_merge 3)
                vc = (sub * (w > 0)).sum() * DX * DX
                if vc > 0:
                    sub[w > 0] = 0
                    self.h[np.ix_(ys, xs)] = sub
                    d[2] = ((2.0944 * d[2] ** 3 + vc) / 2.0944) ** (1 / 3)
            keep.append(d)
        # drop-drop merge (overlap), largest absorbs (KD-tree)
        from scipy.spatial import cKDTree
        keep.sort(key=lambda d: -d[2])
        if len(keep) > 1:
            pts = np.array([[d[0], d[1]] for d in keep])
            tree = cKDTree(pts)
            alive = [True] * len(keep)
            rmax = max(d[2] for d in keep)
            for i, d in enumerate(keep):
                if not alive[i]:
                    continue
                for j in tree.query_ball_point(pts[i], d[2] + rmax):
                    if j <= i or not alive[j]:
                        continue
                    e = keep[j]
                    if math.hypot(d[0] - e[0], d[1] - e[1]) < d[2] + e[2]:
                        v = d[2] ** 3 + e[2] ** 3
                        wgt = e[2] ** 3 / v
                        d[0] += (e[0] - d[0]) * wgt; d[1] += (e[1] - d[1]) * wgt
                        d[2] = v ** (1 / 3)
                        alive[j] = False
            keep = [d for i, d in enumerate(keep) if alive[i]]
        self.drops = keep

    # ---------- rain ----------
    def rain_step(self, dt):
        area = NX * NY * DX * DX
        vol = self.flux * dt * area                          # mm^3 this step
        self.led['rain'] += vol
        unres = vol * (1 - self.res)
        self.h += unres / area                               # thin film everywhere (dewets into beads)
        vres = vol * self.res
        n = self.rng.poisson(vres / (math.pi * self.dmean ** 3))   # E[V] = pi D^3 (exponential DSD)
        left = vres
        for _ in range(n):
            d = min(self.rng.exponential(self.dmean), 3.0)
            v = math.pi / 6 * d ** 3
            v = min(v, left)
            if v <= 0:
                break
            left -= v
            x, y = self.rng.uniform(0, NX * DX), self.rng.uniform(0, NY * DX)
            ix, iy = int(x / DX), int(y / DX)
            if self.h[iy, ix] >= P['hJoin']:
                R = max(int(0.5 * d * 4 / DX), 1)            # lamella ~ 4 d
                y0, y1, x0, x1 = max(iy - R, 0), min(iy + R + 1, NY), max(ix - R, 0), min(ix + R + 1, NX)
                Y, X = np.mgrid[y0:y1, x0:x1]
                g = np.exp(-((X - ix) ** 2 + (Y - iy) ** 2) / (0.5 * R * R + 0.5))
                self.h[y0:y1, x0:x1] += g / g.sum() * v / (DX * DX)
                self.a[y0:y1, x0:x1] = np.maximum(self.a[y0:y1, x0:x1], g / g.max())
                self.events.append(('impact', x, y))
            elif v >= 2.0944 * 0.05 ** 3:
                self.drops.append([x, y, (v / 2.0944) ** (1 / 3), 0.0, 0.0])
            else:
                self.h[iy, ix] += v / (DX * DX)
        self.h += left / area                                # remainder (rounding of the Poisson draw)

    def step(self):
        dt = 1.0 / FPS / SUB
        for _ in range(SUB):
            self.rain_step(dt)
            self.sheet_step(dt)
        self.drops_step(1.0 / FPS)
        self.dewet(1.0 / FPS)
        self.t += 1.0 / FPS


# ---------- render ----------
def bicubic_up(h):
    return nd.zoom(h, RS, order=3, mode='nearest')


def height_map(w):
    H = np.clip(bicubic_up(w.h), 0, None)
    # sheet waves: wind-driven surface waves ~ h and shear, plus impact agitation
    yy, xx = np.mgrid[0:NY * RS, 0:NX * RS].astype(np.float32)
    ph = w.t * 6.0
    wav = (np.sin((xx * 0.21 + yy * 0.13) - ph * 3.1) + 0.6 * np.sin(xx * 0.37 - yy * 0.29 + ph * 2.3)
           + 0.4 * np.sin(xx * 0.11 + yy * 0.43 - ph * 4.7))
    A = bicubic_up(w.a)
    amp = P['waveK'] * np.minimum(H, 0.6) * (0.25 + 1.5 * np.clip(A, 0, 1))
    Hs = np.where(H > P['hJoin'], H + amp * wav * 0.5, H)
    for d in w.drops:
        x, y, r = d[0] / DX * RS, d[1] / DX * RS, d[2] / DX * RS
        x0, x1, y0, y1 = int(max(x - r - 1, 0)), int(min(x + r + 2, NX * RS)), int(max(y - r - 1, 0)), int(min(y + r + 2, NY * RS))
        if x1 <= x0 or y1 <= y0:
            continue
        Y, X = np.mgrid[y0:y1, x0:x1]
        q = 1 - ((X - x) ** 2 + (Y - y) ** 2) / (r * r)
        cap = np.sqrt(np.clip(q, 0, None)) * d[2]
        Hs[y0:y1, x0:x1] = np.maximum(Hs[y0:y1, x0:x1], cap)
    return Hs


def render(w, bg):
    H = height_map(w)
    gy, gx = np.gradient(H, DX / RS)                       # mm/mm
    wet = H > 0.012
    k = 28.0                                               # refraction offset px per unit slope (drop lens scale)
    Hh, Ww = H.shape
    yy, xx = np.mgrid[0:Hh, 0:Ww]
    sx = np.clip(xx - k * gx, 0, Ww - 1).astype(int)
    sy = np.clip(yy - k * gy, 0, Hh - 1).astype(int)
    img = bg.copy()
    ref = bg[sy, sx]
    slope = np.hypot(gx, gy)
    rim = np.clip(1 - 0.55 * np.clip(slope - 0.25, 0, 2), 0.25, 1)[..., None]
    spec = np.clip((-gx * 0.5 - gy * 0.8) * 1.6 - 0.35, 0, 1) ** 3
    img = np.where(wet[..., None], ref * rim + spec[..., None] * 0.6, img)
    return np.clip(img, 0, 1)


def run(name, flux, res, tau, sdir, T=4.0, seed=1, dmean=0.6, snaps=(0.5, 1.5, 2.5, 4.0)):
    w = World(flux, res, tau, sdir, seed, dmean)
    bg = bg_image()
    frames, hist = [], []
    prevH = None
    pops = []
    base = []
    nsteps = int(T * FPS)
    w0 = 0.0
    for i in range(nsteps):
        ev0 = len(w.events)
        w.step()
        Hn = height_map(w)
        if prevH is not None:
            # baseline: per-frame height change at random wet points (the flowing / waving sheet itself)
            wy, wx = np.nonzero((Hn > P['hJoin']) | (prevH > P['hJoin']))
            if len(wy):
                sel = w.rng.integers(0, len(wy), min(20, len(wy)))
                for yy, xx in zip(wy[sel], wx[sel]):
                    s = (slice(max(yy - 12, 0), yy + 12), slice(max(xx - 12, 0), xx + 12))
                    base.append(float(np.abs(Hn[s] - prevH[s]).max()))
        if prevH is not None and len(w.events) > ev0:
            for kind, x, y in w.events[ev0:]:
                if kind == 'impact':
                    continue
                cx, cy = int(x / DX * RS), int(y / DX * RS)
                s = (slice(max(cy - 12, 0), cy + 12), slice(max(cx - 12, 0), cx + 12))
                pops.append(float(np.abs(Hn[s] - prevH[s]).max()))
        if Hn is not None:
            prevH = Hn
        err = w.water() + w.led['out'] - w.led['rain']
        hist.append((w.t, w.h.sum() * DX * DX, sum(2.0944 * d[2] ** 3 for d in w.drops), w.led['out'], w.led['rain'], err,
                     float((w.h >= P['hJoin']).mean())))
        if any(abs(w.t - s) < 0.5 / FPS for s in snaps):
            frames.append((w.t, render(w, bg)))
    return w, frames, hist, pops, base


def main():
    scen = [
        ('heavy_highspeed', 0.20, 0.3, 1.2, (0.6, 0.8)),    # Heavy 250 km/h side: 0.2 mm/s, shear 1.2 Pa down-right
        ('veryWet_spray', 0.60, 0.3, 1.2, (0.6, 0.8)),      # spray / hurricane following a car
        ('light_highspeed', 0.016, 0.3, 1.2, (0.6, 0.8)),   # Light 250 km/h
        ('heavy_stopped', 0.02, 0.8, 0.0, (1.0, 0.0)),      # Heavy at rest: 0.02 mm/s, gravity only
    ]
    rows = []
    lines = []
    for name, flux, res, tau, sdir in scen:
        w, frames, hist, pops, base = run(name, flux, res, tau, sdir)
        H = np.array(hist)
        rel = np.abs(H[:, 5]).max() / max(H[-1, 4], 1e-9)
        pp = np.percentile(pops, [50, 95]) if pops else (0, 0)
        bb = np.percentile(base, [50, 95]) if base else (0, 0)
        lines.append('%-16s flux %.3f mm/s: rain %.0f mm3, sheet %.0f, drops %.0f (%d), out %.0f, cover %.0f%%, mass err %.1e (rel), '
                     'transition dH p50 %.3f p95 %.3f mm (n %d) vs sheet itself p50 %.3f p95 %.3f, impacts on sheet %d' % (
                         name, flux, H[-1, 4], H[-1, 1], H[-1, 2], len(w.drops), H[-1, 3], 100 * H[-1, 6], rel,
                         pp[0], pp[1], len(pops), bb[0], bb[1], sum(1 for e in w.events if e[0] == 'impact')))
        strip = np.concatenate([f for _, f in frames], 1)
        im = Image.fromarray((strip * 255).astype(np.uint8))
        dr = ImageDraw.Draw(im)
        for k, (t, _) in enumerate(frames):
            dr.text((k * NX * RS + 6, 4), '%s  t %.1f s' % (name, t), fill=(255, 255, 0))
        rows.append(im)
    Wd = max(r.size[0] for r in rows)
    sheet = Image.new('RGB', (Wd, sum(r.size[1] for r in rows)))
    y = 0
    for r in rows:
        sheet.paste(r, (0, y)); y += r.size[1]
    sheet.save(os.path.join(OUT, 'rainfx2_sheet_proto.jpg'), quality=90)
    open(os.path.join(OUT, 'rainfx2_sheet_proto.txt'), 'w').write('\n'.join(lines) + '\n')
    print('\n'.join(lines))


if __name__ == '__main__':
    main()
