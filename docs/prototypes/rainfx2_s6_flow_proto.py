"""rev48-S6 prototype (docs/RAINFX_V2_SHAPE_STATE_PLAN.md section 18): zig-zag paths on a heterogeneous
surface (F1) and head / tail deformation in turns (F2), with the shader's speed law and shape state.

F1 defect field D(x) in [0, 1], static on the visor: two value-noise octaves (defMM, 0.4 defMM).
   The HEAD (p + dir r) samples D across the drop width: lateral steer = -defK (D(h + side r) - D(h - side r))
   x saturate(drive) (pinning gradient pushes the contact line toward the weaker side), and the pinning at the
   head is scaled by 1 + defPin (2 D - 1) (stick-slip). Old model: meander = value of a 6 mm noise (not gradient).
F2 shape state when moving (axis phi, anisotropy e, bend b), heading psi, misalignment dl = wrap90(psi - phi):
   axis turns toward the heading over tailTau (the receding tail is pinned, the head leads),
   e target = motion e + tailStretch |sin dl| (head goes ahead, tail stays: diagonal stretch),
   b target = s crescentK sin(dl) (s = sign(d . u1)): the body bows to the OUTSIDE of the turn,
   snap: |dl| > snapDeg -> tail lets go: tailTau -> 0.04 s, b -> 0 (2-3 frames, no pop).
   Visor: the thick apex (asymmetric cap) moves toward the outer front (frontK |b|).
usage: python rainfx2_s6_flow_proto.py out.png
"""
import math
import sys
import numpy as np
from PIL import Image, ImageDraw

rng = np.random.default_rng(7)
H = np.random.default_rng(3).random((4096,))


def hash2(ix, iy):
    return H[(ix * 73856093 ^ iy * 19349663) % 4096]


def vnoise(x, y):
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = hash2(ix, iy) + (hash2(ix + 1, iy) - hash2(ix, iy)) * fx
    b = hash2(ix, iy + 1) + (hash2(ix + 1, iy + 1) - hash2(ix, iy + 1)) * fx
    return a + (b - a) * fy


DEF_MM = 1.2


def D(x, y):
    return 0.65 * vnoise(x / DEF_MM, y / DEF_MM) + 0.35 * vnoise(x / (0.4 * DEF_MM) + 17.3, y / (0.4 * DEF_MM) + 5.1)


P = dict(gamma=0.072, pinCoat=0.18, kinetic=0.6, friction=0.15, vMax=0.08, vScale=0.25, shapeK=2.0944,
         dropTau=0.04, meander=0.35, meanderMM=6.0, defK=6.0, defPin=0.35,
         motionK=0.6, motionV=0.04, relaxMove=0.12, slugTau=0.6,
         tailTau=0.25, tailStretch=0.2, crescentK=0.9, snapDeg=40.0)
DT = 1 / 60


def speed(rmm, pinMul):
    r = rmm * 1e-3
    F = 1e-6 * P['shapeK'] * rmm ** 3 * 9.81
    Fpin = P['gamma'] * 2 * r * P['pinCoat'] * P['kinetic'] * pinMul
    if F <= Fpin:
        return 0.0, 1.0
    vq = (F - Fpin) / (P['friction'] * r)
    return P['vMax'] * (1 - math.exp(-vq / P['vScale'])), Fpin / F


def run(x0, rmm, new, T=4.0, gdir=(0.0, 1.0)):
    p = np.array([x0, 2.0])
    v = np.array([0.0, 0.0])
    st = dict(phi=math.pi / 2, e=0.0, b=0.0)
    out = []
    d = np.array(gdir)
    for i in range(int(T / DT)):
        head = p + d * rmm
        side = np.array([-d[1], d[0]])
        if new:
            pin = 0.6 + 0.8 * vnoise(p[0] / 4 + 53, p[1] / 4)       # the old 4 mm pin field stays
            pin *= 1 + P['defPin'] * (2 * D(*head) - 1)
            sp, drive = speed(rmm, pin)
            lat = -P['defK'] * (D(*(head + side * rmm)) - D(*(head - side * rmm))) * min(drive, 1)
        else:
            pin = 0.6 + 0.8 * vnoise(p[0] / 4 + 53, p[1] / 4)
            sp, drive = speed(rmm, pin)
            lat = P['meander'] * (2 * vnoise(p[0] / P['meanderMM'], p[1] / P['meanderMM']) - 1) * min(drive, 1)
        lat = max(-0.5, min(0.5, lat))
        dirT = np.array(gdir) + side * lat
        dirT /= np.linalg.norm(dirT)
        vT = dirT * sp * 1000                                              # mm/s
        v = v + (vT - v) * (1 - math.exp(-DT / P['dropTau']))
        if sp == 0 and np.linalg.norm(v) < 3:
            v[:] = 0
        p = p + v * DT
        vms = np.linalg.norm(v) * 1e-3
        if vms > 2e-3:
            d = v / np.linalg.norm(v)
            shape_step(st, d, vms, new)
        out.append((p.copy(), dict(st), d.copy(), vms))
    return out


def wrap90(a):
    return (a + math.pi / 2) % math.pi - math.pi / 2


def shape_step(st, d, vms, new):
    A = 1 + P['motionK'] * min(vms / P['motionV'], 1)
    eM = min(0.5 * (A * A - 1) / (A * A + 1), 0.45)
    psi = math.atan2(d[1], d[0])
    if not new:                                           # rev48-S5: tensor lerp toward the motion ellipse
        k = 1 - math.exp(-DT / P['relaxMove'])
        e = max(eM, st['e'] * math.exp(-DT / P['slugTau']))
        m0 = np.array([st['e'] * math.cos(2 * st['phi']), st['e'] * math.sin(2 * st['phi'])])
        mt = np.array([e * math.cos(2 * psi), e * math.sin(2 * psi)])
        m = m0 + (mt - m0) * k
        st['e'] = float(np.linalg.norm(m))
        st['phi'] = 0.5 * math.atan2(m[1], m[0])
        st['b'] *= 1 - k
        return
    u1 = np.array([math.cos(st['phi']), math.sin(st['phi'])])
    dl = wrap90(psi - st['phi'])
    s = 1.0 if np.dot(d, u1) >= 0 else -1.0
    snap = abs(dl) > math.radians(P['snapDeg'])
    tau = 0.04 if snap else P['tailTau']
    kr = 1 - math.exp(-DT / tau)
    phiN = st['phi'] + dl * kr
    eS = 0.0 if snap else P['tailStretch'] * abs(math.sin(dl))
    # the slug memory (E3) holds the drop's own length, not the turn stretch (else it ratchets up)
    eT = min(max(eM, (st['e'] - eS) * math.exp(-DT / P['slugTau'])) + eS, 0.45)
    bT = 0.0 if snap else s * P['crescentK'] * math.sin(dl)
    k = 1 - math.exp(-DT / (0.04 if snap else P['relaxMove']))
    st['e'] += (eT - st['e']) * k
    st['b'] += (bT - st['b']) * k
    # keep the visor's u1 convention (phi in (-90, 90]); a wrap flips u1, so the bend flips with it
    phiW = wrap90(phiN)
    if abs(phiW - phiN) > 1:
        st['b'] = -st['b']
    st['phi'] = phiW


def outline(c, rmm, st, d, vms, new, px):
    e = st['e']
    A = math.sqrt((0.5 + e) / (0.5 - e))
    a, bmin = rmm * math.sqrt(A), rmm / math.sqrt(A)
    u = np.array([math.cos(st['phi']), math.sin(st['phi'])])
    vv = np.array([-u[1], u[0]])
    kk = 0.6 * min(vms / 0.04, 1)
    pts = []
    for t in np.linspace(0, 2 * math.pi, 64, endpoint=False):
        q = np.array([a * math.cos(t), bmin * math.sin(t)])
        aa = q[0] / a
        P2 = u * q[0] + vv * q[1] + vv * (st['b'] * bmin * aa * aa)
        if np.dot(P2, d) < 0:                              # rear half stretches (teardrop)
            P2 = P2 + d * np.dot(P2, d) * kk
        pts.append(tuple((c + P2) * px))
    return pts


def main(outp):
    W, Hh, PX = 60.0, 60.0, 9
    img = Image.new('RGB', (int(2 * W * PX) + 40, int(Hh * PX) + 40), (16, 16, 16))
    dr = ImageDraw.Draw(img)
    g = np.array([[D(x / PX, y / PX) for x in range(int(W * PX))] for y in range(int(Hh * PX))])
    gi = Image.fromarray((40 + 50 * g).astype(np.uint8)).convert('RGB')
    for k, new in enumerate((False, True)):
        ox = 10 + k * (int(W * PX) + 20)
        img.paste(gi, (ox, 30))
        dr.text((ox + 4, 8), 'rev48-S5: 6 mm meander + tensor lerp' if not new else 'S6: F1 defect steering + F2 tail lag / crescent / snap', fill=(230, 230, 230))
        for j, (x0, rmm) in enumerate(((8, 1.0), (16, 1.2), (24, 0.95), (33, 1.1), (42, 1.3), (51, 1.0))):
            path = run(x0, rmm, new)
            pts = [(ox + q[0] * PX, 30 + q[1] * PX) for q, *_ in path if q[1] < Hh - 1]
            if len(pts) > 1:
                dr.line(pts, fill=(90, 160, 255), width=1)
            for i in range(0, len(path), 9):
                q, st, d, vms = path[i]
                if q[1] > Hh - 2:
                    break
                o = [(ox + x, 30 + y) for x, y in outline(q, rmm, st, d, vms, new, PX)]
                dr.polygon(o, outline=(255, 90, 60))
    # filmstrip: one drop (r 1 mm, 30 mm/s), straight -> 35 deg turn at 0.33 s -> back at 1.0 s, every 0.1 s;
    # arrow = heading, yellow dot = thick apex (S6: pushed to the outer front by the bend)
    SC, CW = 18.0, 66
    Z = Image.new('RGB', (img.size[0], 2 * 92 + 20), (16, 16, 16))
    zd = ImageDraw.Draw(Z)
    for k, new in enumerate((False, True)):
        y0 = 10 + k * 92
        zd.text((8, y0), 'S5' if not new else 'S6', fill=(230, 230, 230))
        st = dict(phi=0.0, e=0.0, b=0.0)
        rmm, vms = 1.0, 0.03
        n = 0
        for i in range(int(1.6 / DT)):
            ang = 0.0 if i < 20 else (math.radians(-35) if i < 60 else 0.0)
            d = np.array([math.cos(ang), math.sin(ang)])
            shape_step(st, d, vms, new)
            if i % 6 == 5:
                cx, cy = 40 + n * CW, y0 + 46
                o = [(cx + x, cy + y) for x, y in outline(np.zeros(2), rmm, st, d, vms, new, SC)]
                zd.polygon(o, outline=(255, 90, 60))
                zd.line((cx, cy, cx + d[0] * 26, cy + d[1] * 26), fill=(90, 160, 255))
                u = np.array([math.cos(st['phi']), math.sin(st['phi'])]); vv = np.array([-u[1], u[0]])
                out = -vv * np.sign(st['b']) if (new and abs(st['b']) > 1e-3) else np.zeros(2)
                ad = d + out * 1.2 * abs(st['b']); ad = ad / np.linalg.norm(ad)
                zd.ellipse((cx + ad[0] * 9 - 2, cy + ad[1] * 9 - 2, cx + ad[0] * 9 + 2, cy + ad[1] * 9 + 2), fill=(255, 230, 80))
                n += 1
    full = Image.new('RGB', (img.size[0], img.size[1] + Z.size[1]), (16, 16, 16))
    full.paste(img, (0, 0)); full.paste(Z, (0, img.size[1]))
    full.save(outp)
    # statistics: lateral excursion and turn count per drop
    for new in (False, True):
        lat, turns = [], []
        for x0 in np.linspace(5, 55, 24):
            path = run(x0, 1.1, new, T=4)
            xs = np.array([q[0] for q, *_ in path])
            hd = np.array([math.atan2(d[1], d[0]) for _, _, d, _ in path])
            dx = np.sign(np.diff(xs[::6]))
            turns.append(int(np.sum(dx[1:] * dx[:-1] < 0)))
            lat.append(float(xs.max() - xs.min()))
        print('%-4s lateral range mm p50 %.1f  direction reversals (0.1 s) p50 %d  mean %.1f' % (
            'S6' if new else 'S5', np.median(lat), np.median(turns), np.mean(turns)))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'rainfx2_s6_flow_proto.png')
