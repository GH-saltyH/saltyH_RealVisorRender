#!/usr/bin/env python3
"""NumPy reference of the RainFX v2 GPU passes (cells P1, field P2, optics P3).

Line-by-line port of rainfx2/shaders/{common,cells,field,optics}.hlsl on the real
GLASS_RAINFX metric (texture/RAIN_GEOMETRY/du.dds, dv.dds). It checks the shader
logic offline: units, UV projection on the minimal-stretch layout, gather mass
balance, boundary absorption and the regime response. It is not a CSP test.

    python docs/prototypes/rainfx2_reference.py [--frames 600] [--out tmp/rainfx2_ref]
"""
import argparse, os, json, numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GEO = os.path.join(ROOT, 'texture', 'RAIN_GEOMETRY')


def load_rgba32(path, w=2048, h=512):
    b = open(path, 'rb').read()
    return np.frombuffer(b[148:], dtype=np.float32)[:w * h * 4].reshape(h, w, 4).copy()


P = dict(cellsU=512, cellsV=128, substeps=2, shapeK=2.0944, pinCoat=0.18, pinGlass=0.35,
         pinNoiseMin=0.6, pinNoiseMax=1.4, friction=0.06, dragCd=1.0, rhoAir=1.2, airSurface=0.35,
         vMax=1.0, trailLoss=0.02, evap=1e-4, minRadiusMM=0.08, maxRadiusMM=2.2,
         terminalSpeed=6.0, exposure=0.5, stickSlow=0.8, stickFast=0.4, microK=6.0, minDrawMM=0.35)


class Geo:
    def __init__(s):
        s.du = load_rgba32(os.path.join(GEO, 'du.dds'))
        s.dv = load_rgba32(os.path.join(GEO, 'dv.dds'))
        n = np.cross(s.du[..., :3], s.dv[..., :3])
        s.n = n / (np.linalg.norm(n, axis=2, keepdims=True) + 1e-12)
        s.valid = s.du[..., 3] >= 1

    def tap(s, arr, t):  # nearest texel, t in [0,1]^2 (N,2)
        h, w = arr.shape[:2]
        x = np.clip((t[:, 0] * w).astype(int), 0, w - 1)
        y = np.clip((t[:, 1] * h).astype(int), 0, h - 1)
        return arr[y, x]

    def valid_t(s, t):
        inside = np.all((t >= 0) & (t <= 1), axis=1)
        return inside & s.tap(s.valid, t)


def radius_mm(v):
    return np.cbrt(np.maximum(v, 0) / P['shapeK'])


def rand(cx, cy, k):
    x = (cx.astype(np.uint64) * 73856093) ^ (cy.astype(np.uint64) * 19349663) ^ (np.uint64(k) * np.uint64(83492791))
    x = (x * np.uint64(6364136223846793005) + np.uint64(1442695040888963407)) & np.uint64(0xFFFFFFFFFFFF)
    return ((x >> np.uint64(24)) & np.uint64(0xFFFFFF)).astype(np.float64) / 16777216.0


def velocity(geo, t, rmm, pin, accel, air):
    du = geo.tap(geo.du, t)[:, :3]
    dvA = geo.tap(geo.dv, t)
    dv = dvA[:, :3]
    n = geo.tap(geo.n, t)
    r = rmm * 1e-3
    mass = 1e-6 * P['shapeK'] * rmm ** 3
    g = accel[None] - n * (n @ accel)[:, None]
    a = (air[None] - n * (n @ air)[:, None]) * P['airSurface']
    al = np.linalg.norm(a, axis=1)
    F = mass[:, None] * g + (0.25 * P['rhoAir'] * P['dragCd'] * np.pi * r * r * al)[:, None] * a
    Fm = np.linalg.norm(F, axis=1)
    pinCos = P['pinGlass'] + (P['pinCoat'] - P['pinGlass']) * np.clip(dvA[:, 3], 0, 1)
    Fpin = 0.072 * 2 * r * pinCos * pin
    moving = Fm > Fpin
    speed = np.where(moving, np.minimum((Fm - Fpin) / (P['friction'] * np.maximum(r, 1e-5)), P['vMax']), 0)
    v = F * (speed / np.maximum(Fm, 1e-30))[:, None]
    A = (du * du).sum(1); B = (du * dv).sum(1); C = (dv * dv).sum(1)
    det = np.maximum(A * C - B * B, 1e-20)
    pu = (du * v).sum(1); pv = (dv * v).sum(1)
    return np.stack([C * pu - B * pv, A * pv - B * pu], 1) / det[:, None], speed


def step(geo, S, dt, accel, air, impact, meanD, stick, rainDir, frame, sub):
    W, H = P['cellsU'], P['cellsV']
    cells = np.array([W, H], float)
    ys, xs = np.nonzero(S[..., 2] > 0)
    st = S[ys, xs]
    cell = np.stack([xs, ys], 1).astype(float)
    t = (cell + st[:, :2]) / cells
    rmm = radius_mm(st[:, 2])
    pin = P['pinNoiseMin'] + (P['pinNoiseMax'] - P['pinNoiseMin']) * rand(xs, ys, 911)
    vt, speed = velocity(geo, t, rmm, pin, accel, air)
    dc = vt * dt * cells
    vol = st[:, 2] - P['trailLoss'] * speed * dt * 1000 * rmm * rmm - P['evap'] * dt * np.pi * rmm * rmm
    dest = cell + st[:, :2] + dc
    alive = (np.abs(dc).max(1) <= 1.99) & geo.valid_t(dest / cells) & (radius_mm(vol) >= P['minRadiusMM'])
    shed = int((np.abs(dc).max(1) > 1.99).sum())
    N = np.zeros((H, W, 4))
    d = dest[alive]; v = vol[alive]; disp = dc[alive]
    ci = np.floor(d).astype(int)
    np.add.at(N[..., 2], (ci[:, 1], ci[:, 0]), v)
    np.add.at(N[..., 0], (ci[:, 1], ci[:, 0]), (d[:, 0] - ci[:, 0]) * v)
    np.add.at(N[..., 1], (ci[:, 1], ci[:, 0]), (d[:, 1] - ci[:, 1]) * v)
    occ = N[..., 2] > 0
    N[..., 0] = np.where(occ, N[..., 0] / np.maximum(N[..., 2], 1e-30), 0.5)
    N[..., 1] = np.where(occ, N[..., 1] / np.maximum(N[..., 2], 1e-30), 0.5)
    lost_edge = float(vol[~alive & (np.abs(dc).max(1) <= 1.99)].sum())
    # births
    gy, gx = np.mgrid[0:H, 0:W]
    tc = (np.stack([gx, gy], -1) + 0.5) / cells
    tcf = tc.reshape(-1, 2)
    du = geo.tap(geo.du, tcf)[:, :3]; dv = geo.tap(geo.dv, tcf)[:, :3]
    area = np.linalg.norm(np.cross(du, dv), axis=1) / (W * H)
    n = geo.tap(geo.n, tcf)
    expo = np.clip(-(n @ rainDir), 0, 1)
    lam = impact * area * expo * P['exposure'] * dt
    seed = frame * 8 + sub
    u0 = rand(gx.ravel(), gy.ravel(), seed)
    born = (u0 < lam) & geo.valid_t(tcf)
    u1 = rand(gy.ravel(), gx.ravel(), seed + 101)
    dd = np.clip(-np.log(np.maximum(1 - u1, 1e-6)) * meanD, 0.1, 3.5)
    bv = 0.5235988 * dd ** 3 * stick * born
    bp = np.stack([rand(gx.ravel(), gy.ravel(), seed + 202), rand(gx.ravel(), gy.ravel(), seed + 303)], 1)
    Nf = N.reshape(-1, 4)
    tot = Nf[:, 2] + bv
    for k in (0, 1):
        Nf[:, k] = np.where(born, (Nf[:, k] * Nf[:, 2] + bp[:, k] * bv) / np.maximum(tot, 1e-30), Nf[:, k])
    Nf[:, 2] = tot
    vmax = P['shapeK'] * P['maxRadiusMM'] ** 3
    Nf[:, 2] = np.minimum(Nf[:, 2], vmax)
    Nf[:, :2] = np.clip(Nf[:, :2], 0, 1) * 0.999
    stats = dict(drops=int(occ.sum()), moving=int((speed > 0).sum()), shed=shed, born=int(born.sum()),
                 meanSpeed=float(speed[speed > 0].mean()) if (speed > 0).any() else 0.0, lostEdge=lost_edge,
                 volIn=float(st[:, 2].sum()), volMoved=float(v.sum()))
    return Nf.reshape(H, W, 4), stats


def optics(S, size=(1024, 256)):
    W, H = P['cellsU'], P['cellsV']
    cellmm = np.array([602.0 / W, 146.3 / H])
    ow, oh = size
    yy, xx = np.mgrid[0:oh, 0:ow]
    pc = np.stack([(xx + 0.5) / ow * W, (yy + 0.5) / oh * H], -1)
    c0 = np.floor(pc).astype(int)
    h = np.zeros((oh, ow)); cov = np.zeros((oh, ow))
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            sx = np.clip(c0[..., 0] + dx, 0, W - 1); sy = np.clip(c0[..., 1] + dy, 0, H - 1)
            st = S[sy, sx]
            r = radius_mm(st[..., 2]); rd = np.maximum(r, P['minDrawMM']); k = r * r / (rd * rd)
            d = np.linalg.norm((pc - (np.stack([sx, sy], -1) + st[..., :2])) * cellmm, axis=-1)
            ins = (d < rd) & (st[..., 2] > 0)
            h = np.maximum(h, np.where(ins, np.sqrt(np.maximum(rd * rd - d * d, 0)) * k, 0))
            cov = np.maximum(cov, np.where(ins, np.clip((rd - d) / 0.15, 0, 1) * k, 0))
    return h, cov


def weather(rain_intensity, speed_rel):
    R = rain_intensity * 100
    D = max(0.15, R ** 0.21 / 4.1) if R > 0 else 0.3
    flux = R / 3.6e6 / P['terminalSpeed'] * speed_rel
    impact = flux / (np.pi * D ** 3 * 1e-9)
    k = min(max((speed_rel - 10) / 60, 0), 1)
    return R, D, impact, P['stickSlow'] + (P['stickFast'] - P['stickSlow']) * k


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--frames', type=int, default=600)
    ap.add_argument('--out', default=os.path.join(ROOT, 'tmp', 'rainfx2_ref'))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    geo = Geo()
    # Object axes of this KN5 (measured): x across, z along V (vertical), y = depth.
    # Upright visor: gravity -z(object up = +z assumed), oncoming air along -y.
    regimes = {'C_light_slow': (0.02, 15.0), 'B_medium_fast': (0.08, 60.0), 'A_heavy': (0.4, 55.0)}
    report = {}
    from PIL import Image
    for name, (ri, v) in regimes.items():
        S = np.zeros((P['cellsV'], P['cellsU'], 4))
        accel = np.array([0, 0, -9.81]); air = np.array([0, -v, 0])
        rainVel = np.array([0, -v, -P['terminalSpeed']]); sr = np.linalg.norm(rainVel)
        R, D, impact, stick = weather(ri, sr)
        dt = 1 / 60 / P['substeps']
        worst = 0.0
        for f in range(a.frames):
            for sub in range(P['substeps']):
                S, st = step(geo, S, dt, accel, air, impact, D, stick, rainVel / sr, f, sub)
        h, cov = optics(S)
        r = radius_mm(S[..., 2][S[..., 2] > 0])
        report[name] = dict(rate_mm_h=R, meanD=D, impactRate=impact, stick=stick, **st,
                            radius_p50=float(np.median(r)) if r.size else 0, radius_p95=float(np.percentile(r, 95)) if r.size else 0,
                            coverage=float((cov > 0.5).mean()))
        img = np.stack([np.clip(cov, 0, 1), np.clip(h / 1.5, 0, 1), geo.valid[::2, ::2][:256, :1024] * 0.25], -1)
        Image.fromarray((img * 255).astype(np.uint8)).save(os.path.join(a.out, name + '_optics.png'))
        print(name, json.dumps({k: (round(x, 4) if isinstance(x, float) else x) for k, x in report[name].items()}))
    json.dump(report, open(os.path.join(a.out, 'report.json'), 'w'), indent=1)


if __name__ == '__main__':
    main()
