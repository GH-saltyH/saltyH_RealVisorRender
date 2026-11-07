"""J1 2-D drop trajectory simulator (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 19). Re-implements the r2Predict / r2DropVelocity
/ r2Steer rules on a 50 x 36 mm patch around the visor centre (sphere helmet R 130 mm, stagnation 35 deg above, kU 0.8):
U_c(V) air load (+ T1 frozen turbulence), gravity, coat pinning x pin noise x defects (head side samples), static / kinetic,
friction speed (F - Fpin) / (0.3 r), relaxation dropTau, defect steering x drive (clamp +-0.5).
J1 adds: (1) sparse strong defects (area p, pin x (1 + kappa S)), averaged over the contact width; (2) ESCAPE: a stopped drop
advances where its contact line is free -- head directions +-30 / +-60 deg are tested, it moves along the best one whose force
component beats the pinning there.
usage: python rainfx2_stickslip_2d.py OUTDIR [kmh]
"""
import sys, math, numpy as np
from PIL import Image, ImageDraw
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
KMH = float(sys.argv[2]) if len(sys.argv) > 2 else 240.0
G, PINC, SHK, FRIC = 0.072, 0.18, 2.0944, 0.3
R, KU, ELEV = 130.0, 0.8, math.radians(35)
DEFMM, DEFK, DEFPIN = 1.2, 5.0, 0.35

def hash2(ix, iy, s):
    h = (ix * 374761393 + iy * 668265263 + s * 2147483647) & 0xffffffff
    h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
    return (h ^ (h >> 16)) / 4294967295.0
def vnoise(x, y, s):
    ix, iy = math.floor(x), math.floor(y); fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = hash2(ix, iy, s), hash2(ix + 1, iy, s); c, d = hash2(ix, iy + 1, s), hash2(ix + 1, iy + 1, s)
    return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy

def basis(x, y):
    az, el = x / R, y / R
    n = np.array([math.sin(az) * math.cos(el), math.sin(el), math.cos(az) * math.cos(el)])
    ex = np.array([math.cos(az), 0, -math.sin(az)])
    ey = np.array([-math.sin(az) * math.sin(el), math.cos(el), -math.cos(az) * math.sin(el)])
    return n, ex, ey
def outer(x, y, U):
    n, ex, ey = basis(x, y)
    a1 = np.array([0, 0, -1.0]) * math.cos(ELEV) - np.array([0, 1.0, 0]) * math.sin(ELEV)
    cn = -n.dot(a1); sm = min(max((cn + 0.1) / 0.3, 0), 1); sm = sm * sm * (3 - 2 * sm)
    ut = (a1 - n * n.dot(a1)) * 1.5 * KU * U * sm
    g = np.array([0, -9.81, 0]); gt = g - n * n.dot(g)
    return np.array([ut.dot(ex), ut.dot(ey)]), np.array([gt.dot(ex), gt.dot(ey)]), sm

SHED = [25.0, 0.08]
RADII = (0.1, 0.2, 0.4)
def Uc(r): return SHED[0] * (SHK * r ** 3 / 10) ** -SHED[1]

class Cfg:
    def __init__(s, kappa=0.0, thr=0.74, smm=0.4, escape=False, turb=0.15, name='', bl=False, dyn=False, kp=0.0):
        # thr: value-noise level above which a spot is a strong defect (0.74 = 15 % of the area, 0.79 = 10 %)
        # bl: F2a boundary-layer growth from the stagnation point (Thwaites delta(theta), load calibrated at theta 45)
        # dyn: F2b dynamic retention (Cox-Voinov receding / advancing angles with Ca, theta_r 28 deg as the trail rule)
        s.kappa, s.thr, s.smm, s.escape, s.turb, s.name, s.bl, s.dyn, s.kp = kappa, thr, smm, escape, turb, name, bl, dyn, kp
DTAB = [1.0, 0.733, 0.766, 0.826, 0.928, 1.10, 1.42, 2.49]     # delta99(theta) / delta99(0), 0..105 deg (rainfx2_helmet_bl.py)
def dtab(thdeg):
    x = min(max(thdeg / 15.0, 0), 6.999); i = int(x); f = x - i
    return DTAB[i] * (1 - f) + DTAB[i + 1] * f
def Bp(x): return x * (2 - x) if x < 1 else 1.0
THR, KLN = math.radians(28), None
def fret_unit(v, r, pinf):
    # retention / (2 gamma r): pinf x dcos_static + dynamic growth of the receding / advancing cosines
    ca = v * 1e-3 / 0.072
    K = 9 * math.log(max(r * 1e6, 10))
    tr3 = THR ** 3 - K * ca
    thr = tr3 ** (1 / 3) if tr3 > 0 else 0.0
    tha = math.acos(max(min(math.cos(THR) - PINC, 1), -1))
    thad = (tha ** 3 + K * ca) ** (1 / 3)
    return pinf * PINC + (math.cos(thr) - math.cos(THR)) + (math.cos(tha) - math.cos(min(thad, 3.0)))

def defect_c(x, y, r, cfg):
    c = DEFPIN * (2 * vnoise(x / DEFMM + 31.7, y / DEFMM + 11.3, 7) - 1)
    if cfg.kappa > 0:
        nW = max(1, int(round(2 * r / cfg.smm)))
        S = 0
        for j in range(nW):                       # strong defects averaged over the contact width (both axes)
            for k in range(nW):
                ox, oy = (-r + 2 * r * (j + 0.5) / nW), (-r + 2 * r * (k + 0.5) / nW)
                v = vnoise((x + ox) / cfg.smm + 5.1, (y + oy) / cfg.smm + 9.7, 11)
                S += max(0.0, (v - cfg.thr) / (1 - cfg.thr)) ** 2
        c += cfg.kappa * S / (nW * nW)
    return c

def step_drop(d, t, dt, U, cfg):
    x, y, r = d['x'], d['y'], d['r']
    ue, gt, sm = outer(x, y, U)
    if cfg.turb > 0:
        tt = t * 4.0
        nT = np.array([vnoise(x / 15 + tt, y / 15 + 17.3, 3), vnoise(x / 15 + 41.9, y / 15 + tt + 7.7, 5)]) * 2 - 1
        ue = ue + nT * cfg.turb * KU * U * 1.7 * sm
    m = 1e-6 * SHK * r ** 3
    uL = np.linalg.norm(ue)
    Fa = (G * 2 * r * 1e-3 * PINC * uL / Uc(r) ** 2) * ue
    if cfg.bl:
        n, _, _ = basis(x, y)
        a1 = np.array([0, 0, -1.0]) * math.cos(ELEV) - np.array([0, 1.0, 0]) * math.sin(ELEV)
        th = math.degrees(math.acos(max(min(-n.dot(a1), 1), -1)))
        dS = 2.4 * math.sqrt(1.5e-5 / (1.5 * KU * U / (R * 1e-3))) * 1000
        Fa = Fa * (Bp(0.6 * r / (dS * dtab(th))) / Bp(0.6 * r / (dS * dtab(45.0)))) ** 2
    if cfg.kp > 0:   # F3: pressure-gradient push V rho u_e du_e/ds along the mean outer flow (stagnation flow)
        n, _, _ = basis(x, y)
        a1 = np.array([0, 0, -1.0]) * math.cos(ELEV) - np.array([0, 1.0, 0]) * math.sin(ELEV)
        cn = -n.dot(a1); sn = math.sqrt(max(1 - cn * cn, 0))
        ue0 = 1.5 * KU * U
        ued, _, _ = outer(x, y, U)
        ul = np.linalg.norm(ued)
        if ul > 1e-6 and cn > 0:
            Fa = Fa + cfg.kp * (SHK * r ** 3 * 1e-9) * 1.2 * ue0 * (ue0 / (R * 1e-3)) * sn * cn * (ued / ul)
    F = m * gt + Fa
    Fm = np.linalg.norm(F)
    pinN = 0.9 + 0.2 * vnoise(x / 4.0 + 53.1, y / 4.0, 1)
    mv = d['v']
    moving = np.linalg.norm(mv) > 1e-6
    def pin_at(px, py, dirv):
        side = np.array([-dirv[1], dirv[0]])
        hx, hy = px + dirv[0] * r, py + dirv[1] * r
        cL = defect_c(hx + side[0] * r, hy + side[1] * r, r, cfg)
        cR = defect_c(hx - side[0] * r, hy - side[1] * r, r, cfg)
        f = max(1 + 0.5 * (cL + cR), 0.05) * pinN * (0.9 if moving else 1.0)
        return G * 2 * r * 1e-3 * PINC * f, cL - cR, side
    dirF = F / max(Fm, 1e-12)
    dirH = mv / np.linalg.norm(mv) if moving else dirF
    Fp, dc, side = pin_at(x, y, dirH)
    vt = np.zeros(2)
    if Fm > Fp:
        sp = (Fm - Fp) / (FRIC * r * 1e-3)
        if cfg.dyn:
            pinf = Fp / (G * 2 * r * 1e-3 * PINC)
            lo, hi = 0.0, sp
            for _ in range(14):
                mid = 0.5 * (lo + hi)
                if (Fm - G * 2 * r * 1e-3 * fret_unit(mid, r, pinf)) / (FRIC * r * 1e-3) > mid: lo = mid
                else: hi = mid
            sp = lo
        drive = Fp / Fm
        lat = np.clip(-DEFK * dc / math.sqrt(max(1, 2 * r / DEFMM)) * drive, -0.5, 0.5)
        dd = dirF + side * lat; dd /= np.linalg.norm(dd)
        vt = dd * sp
    elif cfg.escape:
        best = None
        for a in (30, -30, 60, -60):
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            dv = np.array([dirF[0] * ca - dirF[1] * sa, dirF[0] * sa + dirF[1] * ca])
            Fpa, _, _ = pin_at(x, y, dv)
            marg = Fm * ca - Fpa
            if marg > 0 and (best is None or marg > best[0]): best = (marg, dv)
        if best: vt = best[1] * best[0] / (FRIC * r * 1e-3)
    k = 1 - math.exp(-dt / 0.04)
    d['v'] = mv + (vt - mv) * k if np.linalg.norm(vt) > 0 else np.zeros(2)   # pinned: stops (shader returns 0)
    d['x'] += d['v'][0] * 1000 * dt; d['y'] += d['v'][1] * 1000 * dt

def run(cfg, U, T=2.0, dt=1 / 240, x0=0.0):
    drops = []
    rng = np.random.default_rng(3)
    for r in RADII:
        for i in range(8):
            drops.append(dict(x=x0 + rng.uniform(-18, 18), y=rng.uniform(-4, 14), r=r, v=np.zeros(2), path=[], x0=x0))
    t = 0
    while t < T:
        for d in drops:
            if abs(d['x'] - d['x0']) < 25 and abs(d['y']) < 18:
                step_drop(d, t, dt, U, cfg)
            d['path'].append((d['x'], d['y']))
        t += dt
    return drops

def stats(drops, dt=1 / 240):
    out = {}
    for r in RADII:
        sp, stuck, turns, stops = [], 0, [], 0; n = 0
        for d in drops:
            if d['r'] != r: continue
            P = np.array(d['path']); V = np.diff(P, axis=0) / dt
            s = np.linalg.norm(V, axis=1); inside = (np.abs(P[1:, 0] - d['x0']) < 25) & (np.abs(P[1:, 1]) < 18)
            s = s[inside]
            if len(s) < 10: continue
            n += len(s); sp.append(s.mean()); stuck += (s < 1.0).sum()
            mov = s > 1.0
            stops += np.sum(mov[:-1] & ~mov[1:])
            ang = np.arctan2(V[inside][:, 1], V[inside][:, 0])[mov]
            if len(ang) > 2: turns.append(np.degrees(np.std(np.unwrap(ang))))
        out[r] = (np.mean(sp) if sp else 0, stuck / max(n, 1), stops / max(n * dt, 1e-9) * 1.0, np.mean(turns) if turns else 0)
    return out

def draw(drops, path, title, dt=1 / 240):
    W, H, s = 1000, 720, 20.0
    im = Image.new('RGB', (W, H), (245, 245, 245)); dr = ImageDraw.Draw(im)
    col = {0.1: (40, 120, 220), 0.2: (40, 170, 60), 0.4: (220, 70, 40), 0.5: (220, 70, 40), 1.0: (120, 40, 160)}
    for d in drops:
        P = d['path']
        for k in range(0, len(P), 4):                       # a dot every 1/60 s: dense = slow / stuck
            x, y = P[k]
            x = x - d['x0']
            if abs(x) > 25 or abs(y) > 18: continue
            px, py = W / 2 + x * s, H / 2 - y * s
            rr = max(1.5, d['r'] * s)
            dr.ellipse([px - rr, py - rr, px + rr, py + rr], outline=col[d['r']])
    dr.text((10, 10), title + '  (dots every 1/60 s; blue r 0.1, green 0.2, red 0.4 mm; 1 mm = 20 px)', fill=(0, 0, 0))
    im.save(path)

if __name__ == '__main__':
    U = KMH / 3.6
    cfgs = [Cfg(kappa=4.0, escape=True, name='J1 (kappa 4) = game now'),
            Cfg(kappa=4.0, escape=True, bl=True, dyn=True, name='F2 (BL + dynamic retention) + J1 kappa 4'),
            Cfg(kappa=2.0, escape=True, bl=True, dyn=True, name='F2 + J1 kappa 2'),
            Cfg(kappa=1.0, escape=True, bl=True, dyn=True, name='F2 + J1 kappa 1')]
    for i, c in enumerate(cfgs):
        for zone, x0 in (('centre', 0.0), ('side az ~55', 125.0)):
            dr = run(c, U, x0=x0)
            st = stats(dr)
            draw(dr, f'{OUT}/f2_{int(KMH)}_{i}_{zone[:4]}.png', f'{int(KMH)} km/h {zone}: {c.name}')
            print(f'{int(KMH)} {zone:11s} {c.name}: ' + ' | '.join(f'r {r}: {v[0]:.0f} mm/s, stuck {v[1]*100:.0f}%, stops {v[2]:.1f}/s' for r, v in st.items()))
