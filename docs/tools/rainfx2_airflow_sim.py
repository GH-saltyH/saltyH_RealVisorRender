"""Offline drop motion under relative wind (docs/RAINFX_V2_CORE.md section 53).

Mirrors the per-drop rule of rainfx2/shaders/common.hlsl (r2DropVelocity / r2Predict) for one drop
at a time on a flat visor patch:
  F = m g_t + 0.25 rho Cd pi r^2 |u| u,  u = airSurface * (sin(theta) U e_t + gust),
  moves if |F| > Fpin = 2 gamma r dcos * noise, v = (|F| - Fpin) / (friction r), capped at vMax,
  shed (removed) if the uncapped v > vShed.
theta = angle between the visor normal and the relative air (0 = stagnation centre).
Gusts: turbK * airSurface * U, smooth random 2D value of correlation time turbTau.
Pinning noise: rev40 per 1.2 mm cell (white) or rev41 smooth field (meanderMM scale).
Prints, per car speed / visor position / radius: fraction of drops that move within 2 s, that shed,
mean visible speed and the distance travelled before shedding or 2 s.

usage: python rainfx2_airflow_sim.py [--rev 40|41]
"""
import argparse
import math
import random

ap = argparse.ArgumentParser()
ap.add_argument('--rev', type=int, default=42)
ap.add_argument('--n', type=int, default=200)
a = ap.parse_args()

P = dict(shapeK=2.0944, gamma=0.072, pinCoat=0.18, noiseMin=0.6, noiseMax=1.4, pinKinetic=0.6,
         friction=0.15, Cd=1.0, rhoAir=1.2, airSurface=0.15)
if a.rev == 40:
    P.update(vMax=0.5, vShed=1.2, turbK=0.5, turbTau=0.06, smoothPin=False, gTan=0.7 * 9.81)
elif a.rev == 41:
    P.update(vMax=0.30, vShed=0.45, turbK=1.0, turbTau=0.06, smoothPin=True, gTan=0.7 * 9.81)
else:   # rev42: creep (tanh at vMax) or blown off (air drag > shedK x pinning), air turned down
    P.update(vMax=0.03, vShed=1e9, shedK=2.0, airDown=0.5, turbK=0.6, turbTau=0.2, smoothPin=True, gTan=0.7 * 9.81)

CELL = 1.2e-3
DT = 1 / 240


def run(U, sinT, rMM, rng):
    r = rMM * 1e-3
    m = 1e-6 * P['shapeK'] * rMM ** 3
    # mean surface air along +x (downstream), gravity along -y (down the visor)
    ux = P['airSurface'] * sinT * U
    gust_amp = P['turbK'] * P['airSurface'] * U
    g0 = [rng.uniform(-1, 1), rng.uniform(-1, 1)]
    g1 = [rng.uniform(-1, 1), rng.uniform(-1, 1)]
    tg = 0.0
    x = y = 0.0
    moving = False
    moved_ever = False
    dist = 0.0
    vsum = vn = 0
    pin_cells = {}
    t = 0.0
    while t < 2.0:
        tg += DT / P['turbTau']
        while tg >= 1:
            tg -= 1
            g0, g1 = g1, [rng.uniform(-1, 1), rng.uniform(-1, 1)]
        f = tg * tg * (3 - 2 * tg)
        gx = (g0[0] + (g1[0] - g0[0]) * f) * gust_amp
        gy = (g0[1] + (g1[1] - g0[1]) * f) * gust_amp
        axv, ayv = ux + gx, gy - P.get('airDown', 0.0) * abs(ux)
        al = math.hypot(axv, ayv)
        k = 0.25 * P['rhoAir'] * P['Cd'] * math.pi * r * r * al
        Fx, Fy = k * axv, k * ayv - m * P['gTan']
        Fm = math.hypot(Fx, Fy)
        Fa = k * al
        if P['smoothPin']:
            # smooth heterogeneity: value noise over ~6 mm (stick-slip without per-cell jumps)
            key = (round(x / 6e-3, 1), round(y / 6e-3, 1))
            if key not in pin_cells:
                pin_cells[key] = rng.uniform(P['noiseMin'], P['noiseMax'])
            noise = pin_cells[key]
        else:
            key = (int(math.floor(x / CELL)), int(math.floor(y / CELL)))
            if key not in pin_cells:
                pin_cells[key] = rng.uniform(P['noiseMin'], P['noiseMax'])
            noise = pin_cells[key]
        if moving:
            noise *= P['pinKinetic']
        Fpin = P['gamma'] * 2 * r * P['pinCoat'] * noise
        if Fm <= Fpin:
            moving = False
        else:
            v = (Fm - Fpin) / (P['friction'] * r)
            if 'shedK' in P:
                if Fa > P['shedK'] * Fpin:
                    return True, True, v, dist, t
                v = P['vMax'] * math.tanh(v / P['vMax'])
            if v > P['vShed']:
                return moved_ever or True, True, (vsum / vn if vn else v), dist, t
            v = min(v, P['vMax'])
            x += Fx / Fm * v * DT
            y += Fy / Fm * v * DT
            dist += v * DT
            vsum += v
            vn += 1
            moving = moved_ever = True
        t += DT
    return moved_ever, False, (vsum / vn if vn else 0.0), dist, 2.0


rng = random.Random(7)
print('rev%d  vMax %.2f vShed %.2f turbK %.2f smoothPin %s' % (a.rev, P['vMax'], P['vShed'], P['turbK'], P['smoothPin']))
print('%-7s %-6s %-5s | %-6s %-6s %-9s %-9s %-7s' % ('km/h', 'pos', 'r mm', 'move', 'shed', 'v m/s', 'path mm', 't shed'))
for kmh in (100, 200, 300):
    U = kmh / 3.6
    for name, sinT in (('centre', 0.0), ('mid', 0.35), ('side', 0.75)):
        for rMM in (0.05, 0.1, 0.2, 0.4, 0.8, 1.5):
            mv = sh = 0
            vs = ds = ts = 0.0
            for _ in range(a.n):
                moved, shed, v, d, t = run(U, sinT, rMM, rng)
                mv += moved
                sh += shed
                vs += v
                ds += d
                ts += t if shed else 0
            print('%-7d %-6s %-5.2f | %-6.2f %-6.2f %-9.3f %-9.1f %-7s' % (
                kmh, name, rMM, mv / a.n, sh / a.n, vs / a.n, ds / a.n * 1000,
                ('%.2f' % (ts / sh)) if sh else '-'))
