"""rev48-S6b check (docs/RAINFX_V2_SHAPE_STATE_PLAN.md section 20): the S6 weaving glitch and the hook turn.

1) Weaving: S6 steered with lat = -defK 2 r (grad D . side), defK 6 -> |lat| ~ 5-18 for r 0.5-1.5 mm: the
   +-0.5 clamp is hit almost always, the heading jumps between +-27 deg at every defect (bang-bang).
   S6b: the contact-line force asymmetry across the HEAD over the pinning-to-drive ratio,
   lat = defK defPin (D(head + side r) - D(head - side r)) drive / sqrt(max(1, 2r / defMM)) (a wide contact
   line averages more defects), clamp +-0.35.
2) Turn shape: S6 rotated the whole ellipse (tailTau) and bowed it symmetrically -> 'the original shape
   rotates, the head under-turns'. S6b: the stored axis is the TAIL (rotates over tailTau), the HEAD half bends
   onto the heading at once: one-sided bend at the head end, tip slope = tan(dl) -> a gentle hook (L) that
   straightens as the tail is pulled onto the new path.
usage: python rainfx2_s6b_flow_proto.py out.png
"""
import math
import sys
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, __file__.rsplit('/', 1)[0])
import rainfx2_s6_flow_proto as S

DT = S.DT
DEFMM = 1.2


def grad(x, y, h=1e-3):
    return np.array([(S.D(x + h, y) - S.D(x - h, y)) / (2 * h), (S.D(x, y + h) - S.D(x, y - h)) / (2 * h)])


def run(x0, rmm, law, T=4.0):
    p = np.array([x0, 2.0]); v = np.zeros(2); d = np.array([0.0, 1.0]); out = []
    for i in range(int(T / DT)):
        side = np.array([-d[1], d[0]]); head = p + d * rmm
        pin = 0.6 + 0.8 * S.vnoise(p[0] / 4 + 53, p[1] / 4)
        if law == 's6':
            pin *= 1 + 0.35 * (2 * S.D(*head) - 1)
            sp, drive = S.speed(rmm, pin)
            lat = -6.0 * 2 * rmm * grad(*head).dot(side) * min(drive, 1)
            lat = max(-0.5, min(0.5, lat))
        else:
            dl, dr = S.D(*(head + side * rmm)), S.D(*(head - side * rmm))
            pin *= 1 + 0.35 * (dl + dr - 1)
            sp, drive = S.speed(rmm, pin)
            lat = -5.0 * 0.35 * (dl - dr) * min(drive, 1) / math.sqrt(max(1.0, 2 * rmm / DEFMM))
            lat = max(-0.35, min(0.35, lat))
        dT = np.array([0.0, 1.0]) + side * lat; dT /= np.linalg.norm(dT)
        v = v + (dT * sp * 1000 - v) * (1 - math.exp(-DT / 0.04))
        if sp == 0 and np.linalg.norm(v) < 3:
            v[:] = 0
        p = p + v * DT
        if np.linalg.norm(v) > 2:
            d = v / np.linalg.norm(v)
        out.append((p.copy(), d.copy(), lat))
    return out


def hook_outline(rmm, e, phi, b, mode, d, vms, sc):
    A = math.sqrt((0.5 + e) / (0.5 - e)); a, bm = rmm * math.sqrt(A), rmm / math.sqrt(A)
    u = np.array([math.cos(phi), math.sin(phi)]); vv = np.array([-u[1], u[0]])
    kk = 0.6 * min(vms / 0.04, 1); pts = []
    for t in np.linspace(0, 2 * math.pi, 72, endpoint=False):
        x, y = a * math.cos(t), bm * math.sin(t)
        aa = x / a
        if mode == 0:
            off = b * bm * aa * aa
        else:
            ah = aa if mode == 1 else -aa
            off = b * bm * max(ah, 0.0) ** 2
        P2 = u * x + vv * (y + off)
        if P2.dot(d) < 0:
            P2 = P2 + d * P2.dot(d) * kk
        pts.append(tuple(P2 * sc))
    return pts


def step_s6b(st, d, vms, tailTau=0.25, snapDeg=40, hookK=2.0, stretch=0.2):
    A = 1 + 0.6 * min(vms / 0.04, 1); eM = min(0.5 * (A * A - 1) / (A * A + 1), 0.45)
    psi = math.atan2(d[1], d[0]); phi = st['phi']; dl = S.wrap90(psi - phi)
    snap = abs(dl) > math.radians(snapDeg)
    kr = 1 - math.exp(-DT / (0.06 if snap else tailTau))
    phiN = phi + dl * kr
    eS = 0 if snap else stretch * abs(math.sin(dl))
    eT = min(max(eM, max(st['e'] - eS, 0) * math.exp(-DT / 0.6)) + eS, 0.45)
    k = 1 - math.exp(-DT / (0.06 if snap else 0.12))
    st['e'] += (eT - st['e']) * k
    dlN = S.wrap90(psi - phiN)                        # what is left for the head after the tail moved
    Ae = math.sqrt((0.5 + st['e']) / (0.5 - st['e']))
    s = 1.0 if d.dot([math.cos(phi), math.sin(phi)]) >= 0 else -1.0
    bT = s * hookK * 0.5 * Ae * math.tan(max(-0.9, min(0.9, dlN)))
    kh = 1 - math.exp(-DT / 0.03)                     # the head follows its heading within ~2 frames
    st['b'] += (bT - st['b']) * kh
    st['mode'] = 1 if s > 0 else 2
    phiW = S.wrap90(phiN)
    if abs(phiW - phiN) > 1:
        st['b'] = -st['b']; st['mode'] = 3 - st['mode']
    st['phi'] = phiW


def main(outp):
    # 1) weaving statistics, r 0.5 / 1.0 / 1.5 mm
    lines = []
    for law in ('s6', 's6b'):
        for rmm in (0.5, 1.0, 1.5):
            hd, sat, lr = [], 0, []
            for x0 in np.linspace(5, 55, 16):
                o = run(x0, rmm, law, T=3)
                ang = [math.degrees(math.atan2(dd[0], dd[1])) for _, dd, _ in o]
                hd += ang
                sat += sum(1 for *_, l in o if abs(l) >= (0.5 if law == 's6' else 0.35) - 1e-6)
                xs = [q[0] for q, *_ in o]; lr.append(max(xs) - min(xs))
            n = 16 * int(3 / DT)
            lines.append('%-4s r %.1f mm: heading rms %4.1f deg, |dheading/frame| p95 %4.1f deg, lat clamped %3.0f %%, lateral range p50 %.1f mm' % (
                law, rmm, np.sqrt(np.mean(np.square(hd))), np.percentile(np.abs(np.diff(hd)), 95), 100 * sat / n, np.median(lr)))
    print('\n'.join(lines))
    # 2) images: paths (r 1.5) and hook filmstrip
    W, H, PX = 60, 60, 6
    img = Image.new('RGB', (max(2 * W * PX + 30, 1480), H * PX + 30 + 230), (16, 16, 16)); dr = ImageDraw.Draw(img)
    for k, law in enumerate(('s6', 's6b')):
        ox = 10 + k * (W * PX + 10)
        dr.text((ox, 6), 'in-game S6 law (r 1.5 mm)' if law == 's6' else 'S6b law (r 1.5 mm)', fill=(230, 230, 230))
        dr.rectangle((ox, 22, ox + W * PX, 22 + H * PX), outline=(60, 60, 60))
        for x0 in np.linspace(6, 54, 8):
            o = run(x0, 1.5, law, T=4)
            pts = [(ox + q[0] * PX, 22 + q[1] * PX) for q, *_ in o if q[1] < H]
            if len(pts) > 1:
                dr.line(pts, fill=(255, 90, 60), width=2)
    y0 = H * PX + 40
    for k, name in enumerate(('S6: whole ellipse rotates + symmetric bow', 'S6b: tail axis lags, head hooks onto the heading')):
        yy = y0 + k * 105
        dr.text((10, yy), name + '  (30 deg turn at t 0, every 2 frames)', fill=(230, 230, 230))
        st = dict(phi=0.0, e=0.22, b=0.0, mode=0)
        n = 0
        for i in range(int(0.75 / DT)):
            ang = 0.0 if i < 4 else math.radians(-30)
            d = np.array([math.cos(ang), math.sin(ang)])
            if k == 0:
                st2 = dict(phi=st['phi'], e=st['e'], b=st['b'])
                S.shape_step(st2, d, 0.03, True); st.update(st2); st['mode'] = 0
            else:
                step_s6b(st, d, 0.03)
            if i % 2 == 1 and n < 20:
                cx, cy = 45 + n * 72, yy + 58
                o = [(cx + x, cy + y) for x, y in hook_outline(1.0, st['e'], st['phi'], st['b'], st['mode'], d, 0.03, 22)]
                dr.polygon(o, outline=(255, 90, 60))
                dr.line((cx, cy, cx + d[0] * 30, cy + d[1] * 30), fill=(90, 160, 255))
                n += 1
    img.save(outp)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'rainfx2_s6b_flow_proto.png')
