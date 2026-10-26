#!/usr/bin/env python3
"""Offline prototype of the proposed GPU 'cell-gather' visor rain model.

Everything here maps 1:1 to pixel-shader passes (no compute, no vertex upload, no readback):
  P1  cell state update (birth, pin/slide, trail loss, predict, 3x3 gather+merge)
  P2  surface field update (micro haze M, trace T) at 2x cell resolution
  P3  optical atlas (analytic spherical caps from 3x3 cells) -> normal/coverage
  P4  visor composite (refraction + defocus + haze) over a background frame
Units: SI. Visor patch 0.30 m x 0.15 m.
"""
import numpy as np, sys, json
from PIL import Image, ImageFilter

GW, GH = 128, 64                     # drop cells (P1)
VIS_W, VIS_H = 0.12, 0.06            # m (part of the visor that covers the view)
CELL = VIS_W / GW                    # ~2.34 mm
FW, FH = GW * 2, GH * 2              # surface field (P2)
rng = np.random.default_rng(7)

def hash01(*a):
    return rng.random(a[0].shape) if a else rng.random()

class Sim:
    def __init__(s):
        z = lambda: np.zeros((GH, GW))
        s.vol = z(); s.px = z(); s.py = z(); s.vx = z(); s.vy = z()
        s.M = np.zeros((FH, FW)); s.T = np.zeros((FH, FW))
        s.pinNoise = 0.6 + 0.8 * rng.random((GH, GW))   # static coating irregularity (P1 reads a fixed texture)
        s.segs = None

    @staticmethod
    def radius(vol):  # contact angle ~90 deg -> hemisphere: V = 2/3 pi r^3
        return np.cbrt(np.maximum(vol, 0) * 1.5 / np.pi)

    def step(s, dt, P):
        vol = s.vol
        # ---- birth: impacts per cell = flux * cellArea * dt (Poisson approx), DSD sample ----
        lam = P['impactRate'] * CELL * CELL * dt
        born = rng.random(vol.shape) < lam
        # exponential DSD of impact diameter (mm) with mean depending on rain rate
        d = rng.exponential(P['meanDiam'], vol.shape).clip(0.1, 3.0) * 1e-3
        bvol = np.pi / 6 * d ** 3 * P['stickFrac']      # part of impact volume that stays as a drop
        bx = rng.random(vol.shape); by = rng.random(vol.shape)
        nv = vol + bvol * born
        w = np.where(nv > 0, bvol * born / np.maximum(nv, 1e-30), 0)
        s.px = s.px * (1 - w) + bx * w; s.py = s.py * (1 - w) + by * w
        vol = nv
        s.impactMicro = born.astype(float)
        # ---- forces on drop (tangent plane, visor-local x right, y down) ----
        r = s.radius(vol)
        m = 1000 * vol
        gx, gy = P['gTan']                             # gravity + inertial accel projected (m/s^2)
        ax, ay = P['airTan']                           # tangential airflow velocity at surface (m/s)
        Fdrag = 0.5 * 1.2 * 0.8 * np.pi * r * r        # * |u| u
        un = np.hypot(ax, ay)
        Fx = m * gx + Fdrag * un * ax
        Fy = m * gy + Fdrag * un * ay
        Fpin = P['pinK'] * r * s.pinNoise              # contact-angle hysteresis ~ gamma * r * (cos r - cos a)
        Fm = np.hypot(Fx, Fy)
        moving = (Fm > Fpin) & (vol > 0)
        k = np.where(moving, (Fm - Fpin) / np.maximum(Fm, 1e-30), 0)
        mob = P['mobility'] / np.maximum(r, 1e-5)      # viscous contact-line friction ~ r
        s.vx = np.where(moving, Fx * k * mob, 0); s.vy = np.where(moving, Fy * k * mob, 0)
        sp = np.hypot(s.vx, s.vy)
        # ---- trail loss (residue) and evaporation ----
        loss = P['trailLoss'] * sp * dt * r * r * moving
        vol = np.maximum(vol - loss - P['evap'] * dt * r * r, 0)
        vol = np.where(s.radius(vol) < 0.08e-3, 0, vol)  # tiny residue -> becomes trace/micro only
        # ---- predict new position in cell units (CFL clamp 1 cell/step) ----
        dxc = np.clip(s.vx * dt / CELL, -0.999, 0.999); dyc = np.clip(s.vy * dt / CELL, -0.999, 0.999)
        nx = s.px + dxc; ny = s.py + dyc
        ox = np.floor(nx).astype(int); oy = np.floor(ny).astype(int)   # -1,0,1
        lx = nx - ox; ly = ny - oy
        # segments for P2 (in field coordinates) before moving
        jj, ii = np.mgrid[0:GH, 0:GW]
        s.segs = dict(x0=(ii + s.px) * 2, y0=(jj + s.py) * 2, x1=(ii + nx) * 2, y1=(jj + ny) * 2,
                      r=s.radius(vol) / CELL * 2, on=(vol > 0) & moving)
        # ---- 3x3 gather + merge (what every destination cell computes in the shader) ----
        acc_v = np.zeros_like(vol); acc_x = np.zeros_like(vol); acc_y = np.zeros_like(vol)
        acc_vx = np.zeros_like(vol); acc_vy = np.zeros_like(vol)
        for sy in (-1, 0, 1):
            for sx in (-1, 0, 1):
                sel = (ox == sx) & (oy == sy) & (vol > 0)
                v = np.where(sel, vol, 0)
                # source cell (j,i) sends to (j+sy, i+sx); destination gathers by shifting back
                def mv(a):
                    a = np.roll(a, (sy, sx), (0, 1))
                    if sy == 1: a[0, :] = 0
                    if sy == -1: a[-1, :] = 0
                    if sx == 1: a[:, 0] = 0
                    if sx == -1: a[:, -1] = 0
                    return a
                vv = mv(v)
                acc_v += vv; acc_x += mv(v * lx); acc_y += mv(v * ly)
                acc_vx += mv(v * s.vx); acc_vy += mv(v * s.vy)
        s.lost = vol.sum() - acc_v.sum()               # drops leaving the visor edges
        ok = acc_v > 0
        s.px = np.where(ok, acc_x / np.maximum(acc_v, 1e-30), 0)
        s.py = np.where(ok, acc_y / np.maximum(acc_v, 1e-30), 0)
        s.vx = np.where(ok, acc_vx / np.maximum(acc_v, 1e-30), 0)
        s.vy = np.where(ok, acc_vy / np.maximum(acc_v, 1e-30), 0)
        s.vol = acc_v
        s.field(dt, P)

    def field(s, dt, P):
        # P2: micro haze from fine impacts/mist, clearance by shear and by drop passage, trace residue
        up = np.kron(s.impactMicro, np.ones((2, 2)))
        s.M += (P['microRate'] * dt + 0.15 * up * P['microPerImpact']) * (1 - s.M)
        s.M *= np.exp(-dt * (P['microEvap'] + P['shearClear'] * s.shearMask))
        s.T *= np.exp(-dt * P['traceDecay'])
        sg = s.segs
        yy, xx = np.mgrid[0:FH, 0:FW] + 0.5
        cov = np.zeros((FH, FW))
        # per field texel: segments from the 3x3 drop cells around it (here brute-force on active ones)
        idx = np.argwhere(sg['on'])
        for (j, i) in idx:
            x0, y0, x1, y1, rr = sg['x0'][j, i], sg['y0'][j, i], sg['x1'][j, i], sg['y1'][j, i], sg['r'][j, i]
            ys, ye = max(int(min(y0, y1) - rr - 2), 0), min(int(max(y0, y1) + rr + 2), FH)
            xs, xe = max(int(min(x0, x1) - rr - 2), 0), min(int(max(x0, x1) + rr + 2), FW)
            if ys >= ye or xs >= xe: continue
            X = xx[ys:ye, xs:xe]; Y = yy[ys:ye, xs:xe]
            dx, dy = x1 - x0, y1 - y0; L2 = dx * dx + dy * dy + 1e-9
            t = np.clip(((X - x0) * dx + (Y - y0) * dy) / L2, 0, 1)
            dd = np.hypot(X - (x0 + t * dx), Y - (y0 + t * dy))
            c = np.clip(1 - dd / max(rr * 0.9, 0.35), 0, 1)
            cov[ys:ye, xs:xe] = np.maximum(cov[ys:ye, xs:xe], c)
        s.M *= 1 - cov * 0.95                           # path collects micro droplets -> clear lane
        s.T = np.maximum(s.T, cov * P['traceAmount'])

    def optical(s, scale=4):
        """P3: analytic caps from 3x3 cells into an atlas of (GW*scale x GH*scale)."""
        AW, AH = GW * scale, GH * scale
        yy, xx = (np.mgrid[0:AH, 0:AW] + 0.5) / scale
        h = np.zeros((AH, AW)); gx = np.zeros((AH, AW)); gy = np.zeros((AH, AW))
        jc = np.floor(yy).astype(int); ic = np.floor(xx).astype(int)
        r = s.radius(s.vol) / CELL
        for sy in (-1, 0, 1):
            for sx in (-1, 0, 1):
                j = np.clip(jc + sy, 0, GH - 1); i = np.clip(ic + sx, 0, GW - 1)
                cx = i + s.px[j, i]; cy = j + s.py[j, i]; rr = r[j, i]
                dx = xx - cx; dy = yy - cy; d2 = dx * dx + dy * dy
                inside = (d2 < rr * rr) & (rr > 0)
                hh = np.where(inside, np.sqrt(np.maximum(rr * rr - d2, 0)), 0)
                take = hh > h
                inv = np.where(inside, 1 / np.maximum(hh, 0.05 * np.maximum(rr, 1e-6)), 0)
                gx = np.where(take, -dx * inv, gx); gy = np.where(take, -dy * inv, gy)
                h = np.maximum(h, hh)
        return h, gx, gy

def composite(sim, bg, P, out_w=768):
    h, gx, gy = sim.optical()
    AH, AW = h.shape
    H = int(out_w * AH / AW)
    bgi = bg.resize((out_w, H), Image.BILINEAR)
    B = np.asarray(bgi, dtype=np.float32) / 255
    blur = lambda img, s: np.asarray(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(s)), dtype=np.float32) / 255
    # defocus of the optical atlas (visor ~4 cm from the eye, focus at infinity): blur normals/coverage
    def up(a, s):
        im = Image.fromarray(a.astype(np.float32)).resize((out_w, H), Image.BILINEAR)
        im = np.asarray(im)
        if s > 0:
            from numpy.fft import fft2, ifft2
            ky = np.fft.fftfreq(H)[:, None]; kx = np.fft.fftfreq(out_w)[None, :]
            im = np.real(ifft2(fft2(im) * np.exp(-2 * (np.pi * s) ** 2 * (kx * kx + ky * ky))))
        return im
    cov = up((h > 0).astype(float), P['defocus'])
    nx = up(np.clip(gx, -3, 3), P['defocus']); ny = up(np.clip(gy, -3, 3), P['defocus'])
    M = up(sim.M, 2.0); T = up(sim.T, 1.5)
    yy, xx = np.mgrid[0:H, 0:out_w]
    k = P['refrPx'] * out_w / 768
    sx = np.clip(xx + nx * k * cov, 0, out_w - 1).astype(int)
    sy = np.clip(yy + ny * k * cov, 0, H - 1).astype(int)
    Bb1 = blur(B, 2.0); Bb2 = blur(B, 7.0)
    refr = Bb1[sy, sx]                                  # drops sample a slightly blurred (mip) scene
    out = B * (1 - cov[..., None]) + refr * cov[..., None]
    out += cov[..., None] * 0.05 * np.clip(np.hypot(nx, ny), 0, 1)[..., None]   # rim/fresnel glint
    hz = np.clip(M * P['hazeK'] + T * 0.25, 0, 1)[..., None]
    veil = Bb2 * 0.85 + 0.15 * Bb2.mean((0, 1))
    out = out * (1 - hz) + veil * hz
    return np.clip(out, 0, 1)

REGIMES = {
    # rain rate R (mm/h) = CSP rainIntensity*100 ; v = car speed ; impacts scale with v_rel/v_terminal
    'C_light_slow': dict(R=2.0, v=25, spray=0.0, T=10.0),
    'B_medium_fast': dict(R=8.0, v=65, spray=0.15, T=10.0),
    'A_heavy_spray': dict(R=40.0, v=60, spray=1.0, T=10.0),
}

def params(R, v, spray, **_):
    vt = 6.0                                          # terminal fall speed of mm-size drops (m/s)
    lwc_flux = R / 3.6e6                              # m3 water per m2 per s on a horizontal surface
    vrel = np.hypot(v, vt)
    exposure = 0.25                                   # visor sits behind the halo/cowl: partial exposure
    volFlux = lwc_flux / vt * vrel * exposure + spray * 2.0e-5   # m3/m2/s reaching the visor
    meanD = 0.35 + 0.25 * np.log1p(R / 5)             # mm, shifts with intensity
    meanVol = np.pi / 6 * (2 * meanD * 1e-3) ** 3     # E[d^3]=6 mean^3 for exponential
    impactRate = volFlux / meanVol                    # impacts / m2 / s
    air = 0.10 * v                                    # tangential surface airflow (boundary layer)
    return dict(impactRate=impactRate, meanDiam=meanD, stickFrac=0.55 if v > 40 else 0.8,
                gTan=(0.0, 9.81 * 0.6), airTan=(0.25 * air, -air),       # diagonal up-drift at speed
                pinK=0.036, mobility=3.0e-3, trailLoss=0.6, evap=2e-6,
                microRate=0.002 * R * (v / 30) + 0.4 * spray, microPerImpact=0.6,
                microEvap=0.05, shearClear=0.02 * v, traceDecay=0.5, traceAmount=0.5,
                defocus=1.2, refrPx=14.0, hazeK=0.75)

if __name__ == '__main__':
    bg = Image.open(sys.argv[1]).convert('RGB')
    w, h = bg.size; bg = bg.crop((0, int(h * 0.15), w, int(h * 0.15) + int(w / 2)))
    tiles = []; report = {}
    for name, rg in REGIMES.items():
        S = Sim(); P = params(**rg)
        yy = (np.mgrid[0:FH, 0:FW][0] + 0.5) / FH
        S.shearMask = np.clip((yy - 0.18) / 0.3, 0, 1)   # top band = separated/stagnant flow -> haze survives
        dt = 1 / 120; n = int(rg['T'] / dt)
        vol_in = 0; lost = 0; conserv_err = 0
        for it in range(n):
            before = S.vol.sum()
            S.step(dt, P)
            lost += S.lost
        drops = int((S.vol > 0).sum()); moving = int((np.hypot(S.vx, S.vy) > 0).sum())
        report[name] = dict(P={k: (float(v) if np.isscalar(v) else v) for k, v in P.items()}, drops=drops, moving=moving,
                            meanM=float(S.M.mean()), maxR_mm=float(Sim.radius(S.vol).max() * 1e3))
        tiles.append(composite(S, bg, P))
        print(name, report[name]['drops'], 'drops', moving, 'moving', 'M=%.2f' % report[name]['meanM'], 'rmax=%.2fmm' % report[name]['maxR_mm'])
    base = np.asarray(bg.resize((768, 384)), dtype=np.float32) / 255
    img = np.concatenate([base] + tiles, 0)
    Image.fromarray((img * 255).astype(np.uint8)).save(sys.argv[2])
    json.dump(report, open(sys.argv[2] + '.json', 'w'), indent=1, default=str)
