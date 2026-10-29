"""Visor drop-motion map from the shader force law (common.hlsl r2DropVelocity), for the motion review
(docs/RAINFX_V2_MOTION_REVIEW.md). Helmet = sphere (R 0.13 m); visor = azimuth -70..70 deg, elevation
-30..20 deg, seen from the front (left of the map = driver's left). Per point and drop radius: outer flow
u_e = 1.5 kU U sin(theta) along the tangential projection of the (tilted) air direction, drop-top speed
through the stagnation boundary layer, drag + pressure-gradient force, gravity minus the car acceleration
(lateral g in turns), pinning gamma 2r dcos. Arrow = direction of the net force where the drop MOVES
(red: runback = air > shedK x pinning, orange: creeping), grey dot = pinned.
Scenarios: stagnation elevation, buffeting off, head (gaze) yaw, lateral g.
usage: python rainfx2_visor_flowmap.py out.png
"""
import math
import sys
import numpy as np
from PIL import Image, ImageDraw

P = dict(aeroKU=0.35, helmetR=0.13, rho=1.2, Cd=1.0, shapeK=2.0944, gamma=0.072, pinCoat=0.18, shedK=2.0, nu=1.5e-5)


def force(phi, lam, U, rmm, elev, gazeYaw=0.0, latG=0.0, longG=0.0, kU=None):
    kU = P['aeroKU'] if kU is None else kU
    n = np.array([math.sin(phi) * math.cos(lam), math.sin(lam), math.cos(phi) * math.cos(lam)])
    up = np.array([0.0, 1.0, 0.0])
    # air flows toward -z (head frame); gaze yaw turns the head right by gazeYaw -> air comes from the left
    ah = np.array([-math.sin(-gazeYaw), 0.0, -math.cos(-gazeYaw)])
    a1 = ah * math.cos(elev) - up * math.sin(elev)
    cn = -n.dot(a1)
    ue0 = 1.5 * kU * U
    sm = min(max((cn + 0.1) / 0.3, 0.0), 1.0)
    sm = sm * sm * (3 - 2 * sm)
    ut = (a1 - n * n.dot(a1)) * ue0 * sm
    aD = ue0 / P['helmetR']
    delta = min(2.4 * math.sqrt(P['nu'] / aD) * 1000, 50) if aD > 1e-3 else 50
    x = 0.6 * rmm / delta
    uh = ut * (x * (2 - x) if x < 1 else 1.0)
    r = rmm * 1e-3
    Fa = 0.25 * P['rho'] * P['Cd'] * math.pi * r * r * np.linalg.norm(uh) * uh \
        + ut * (P['shapeK'] * rmm ** 3 * 1e-9 * P['rho'] * aD * max(cn, 0.0))
    m = 1e-6 * P['shapeK'] * rmm ** 3
    acc = np.array([0.0, -9.81, 0.0]) - np.array([latG, 0.0, longG]) * 9.81   # inertial: -a_car (x right, z fwd)
    g = acc - n * n.dot(acc)
    F = Fa + m * g
    Fpin = P['gamma'] * 2 * r * P['pinCoat']
    e_phi = np.array([math.cos(phi), 0.0, -math.sin(phi)])
    e_lam = np.array([-math.sin(phi) * math.sin(lam), math.cos(lam), -math.cos(phi) * math.sin(lam)])
    st = 0 if np.linalg.norm(F) <= Fpin else (2 if np.linalg.norm(Fa) > P['shedK'] * Fpin else 1)
    return np.array([F.dot(e_phi), -F.dot(e_lam)]), st      # map: x right, y DOWN


SCEN = [
    ('A current: 160 km/h straight, stag 12 deg', dict(U=44.4, elev=12, r=0.5)),
    ('B proposed: 160 km/h straight, stag 35 deg', dict(U=44.4, elev=35, r=0.5)),
    ('C current: 88 km/h straight', dict(U=24.4, elev=12, r=1.0)),
    ('D current: 88 km/h RIGHT turn, 2 g', dict(U=24.4, elev=12, r=1.0, latG=2.0)),
    ('E proposed: 88 km/h right turn, 2 g (stag 35)', dict(U=24.4, elev=35, r=1.0, latG=2.0)),
    ('F proposed: + gaze into the turn 15 deg', dict(U=24.4, elev=35, r=1.0, latG=2.0, gazeYaw=15)),
    ('G current: 250 km/h straight', dict(U=69.4, elev=12, r=0.5)),
    ('H proposed: 250 km/h straight', dict(U=69.4, elev=35, r=0.5)),
]


def main(outp):
    W, H = 560, 230
    img = Image.new('RGB', (2 * W + 30, 4 * (H + 30) + 10), (18, 18, 18))
    dr = ImageDraw.Draw(img)
    for k, (name, s) in enumerate(SCEN):
        ox, oy = 10 + (k % 2) * (W + 10), 10 + (k // 2) * (H + 30)
        rmm = s['r']
        dr.text((ox, oy), name + '  (r %.1f mm)' % rmm, fill=(230, 230, 230))
        oy += 16
        dr.rectangle((ox, oy, ox + W, oy + H), outline=(70, 70, 70))
        cnt = [0, 0, 0]
        for i, phd in enumerate(np.linspace(-70, 70, 15)):
            for j, ld in enumerate(np.linspace(20, -30, 6)):
                f, stt = force(math.radians(phd), math.radians(ld), s['U'], rmm, math.radians(s['elev']),
                               math.radians(s.get('gazeYaw', 0)), s.get('latG', 0.0))
                cnt[stt] += 1
                cx, cy = ox + (phd + 75) / 150 * W, oy + (20 - ld + 5) / 60 * H
                if stt == 0:
                    dr.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=(120, 120, 120))
                    continue
                d = f / (np.linalg.norm(f) + 1e-20) * 15
                col = (255, 70, 50) if stt == 2 else (255, 170, 40)
                dr.line((cx, cy, cx + d[0], cy + d[1]), fill=col, width=2)
                dr.ellipse((cx + d[0] - 2, cy + d[1] - 2, cx + d[0] + 2, cy + d[1] + 2), fill=col)
        dr.text((ox + 4, oy + H - 14), 'pinned %d  creep %d  runback %d   (left = driver left, centre = visor centre)' % tuple(cnt), fill=(180, 180, 180))
    img.save(outp)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'rainfx2_visor_flowmap.png')
