"""Drop MOTION FIELD from a video (docs/RAINFX_V2_MOTION_REVIEW.md): where and which way the drops on the
visor move, per screen region, to compare game recordings with the references.

Drops are small, high-contrast blobs at a fixed scale (difference of Gaussians); the visor is fixed to the
camera, so a drop moves a few px per frame while the scene behind it either stays put (cockpit) or moves
smoothly. Per frame pair (t, t + k): DoG blobs in both frames, mutual nearest neighbours within maxPx;
displacement minus the local background motion (median Farneback flow of the block, which follows the
scene) -> drop motion. Aggregated per cell of a gx x gy grid: count, mean vector, share of moving blobs,
circular mean direction (deg, 0 = right, 90 = DOWN on screen).
usage: python rainfx2_flowfield.py video out_prefix --t0 10 --t1 20 [--k 3 --step 0.25 --gx 3 --gy 3
       --roi x0 y0 x1 y1 (fractions) --scale 640 --sig 2.0 --thr 6 --maxPx 12]
Writes out_prefix.txt (grid table) and out_prefix.jpg (frame with the mean vectors).
"""
import argparse
import math
import subprocess
import numpy as np
import cv2

ap = argparse.ArgumentParser()
ap.add_argument('video')
ap.add_argument('out')
ap.add_argument('--t0', type=float, default=0.0)
ap.add_argument('--t1', type=float, default=10.0)
ap.add_argument('--k', type=int, default=3)
ap.add_argument('--step', type=float, default=0.25)
ap.add_argument('--gx', type=int, default=3)
ap.add_argument('--gy', type=int, default=3)
ap.add_argument('--roi', nargs=4, type=float, default=[0, 0, 1, 1])
ap.add_argument('--scale', type=int, default=640)
ap.add_argument('--sig', type=float, default=2.0)
ap.add_argument('--thr', type=float, default=6.0)
ap.add_argument('--maxPx', type=float, default=12.0)
ap.add_argument('--fps', type=float, default=0)
a = ap.parse_args()

cap = cv2.VideoCapture(a.video)
fps = a.fps or cap.get(cv2.CAP_PROP_FPS) or 60.0


def grab(fi):
    cap.set(cv2.CAP_PROP_POS_FRAMES, fi)
    ok, im = cap.read()
    if not ok:
        return None
    h, w = im.shape[:2]
    s = a.scale / w
    im = cv2.resize(im, (a.scale, int(h * s)), interpolation=cv2.INTER_AREA)
    H, W = im.shape[:2]
    x0, y0, x1, y1 = int(a.roi[0] * W), int(a.roi[1] * H), int(a.roi[2] * W), int(a.roi[3] * H)
    return im[y0:y1, x0:x1]


def blobs(g):
    g = g.astype(np.float32)
    d = cv2.GaussianBlur(g, (0, 0), a.sig) - cv2.GaussianBlur(g, (0, 0), a.sig * 2.5)
    ad = np.abs(d)
    mx = cv2.dilate(ad, np.ones((5, 5), np.uint8))
    ys, xs = np.nonzero((ad >= mx) & (ad > a.thr))
    return np.stack([xs, ys], 1).astype(np.float32)


acc = None
first = None
fi = int(a.t0 * fps)
fend = int(a.t1 * fps)
stepF = max(int(a.step * fps), 1)
while fi + a.k < fend:
    A, B = grab(fi), grab(fi + a.k)
    if A is None or B is None:
        break
    if first is None:
        first = A.copy()
    H, W = A.shape[:2]
    if acc is None:
        acc = dict(n=np.zeros((a.gy, a.gx)), mv=np.zeros((a.gy, a.gx)), vx=np.zeros((a.gy, a.gx)),
                   vy=np.zeros((a.gy, a.gx)), cx=np.zeros((a.gy, a.gx)), cy=np.zeros((a.gy, a.gx)))
    ga, gb = cv2.cvtColor(A, cv2.COLOR_BGR2GRAY), cv2.cvtColor(B, cv2.COLOR_BGR2GRAY)
    fl = cv2.calcOpticalFlowFarneback(ga, gb, None, 0.5, 3, 31, 3, 5, 1.1, 0)
    pa, pb = blobs(ga), blobs(gb)
    if len(pa) and len(pb):
        d2 = ((pa[:, None, :] - pb[None, :, :]) ** 2).sum(-1) if len(pa) * len(pb) < 4e6 else None
        if d2 is not None:
            ia = d2.argmin(1)
            ib = d2.argmin(0)
            for i, j in enumerate(ia):
                if ib[j] != i or d2[i, j] > a.maxPx ** 2:
                    continue
                x, y = pa[i]
                bx0, by0 = int(max(x - 24, 0)), int(max(y - 24, 0))
                blk = fl[by0:int(y + 24), bx0:int(x + 24)].reshape(-1, 2)
                bg = np.median(blk, 0) if len(blk) else np.zeros(2)
                v = (pb[j] - pa[i]) - bg
                c, r = min(int(x / W * a.gx), a.gx - 1), min(int(y / H * a.gy), a.gy - 1)
                acc['n'][r, c] += 1
                L = np.hypot(*v)
                if L > 0.6:                                  # moving (beyond detection jitter)
                    acc['mv'][r, c] += 1
                    acc['vx'][r, c] += v[0]
                    acc['vy'][r, c] += v[1]
                    acc['cx'][r, c] += v[0] / L
                    acc['cy'][r, c] += v[1] / L
    fi += stepF

lines = ['%s  t %.1f-%.1f s  k %d  grid %dx%d  (dir deg: 0 right, 90 down; speed px/frame at width %d)' % (
    a.video.split('/')[-1], a.t0, a.t1, a.k, a.gx, a.gy, a.scale)]
img = first.copy() if first is not None else np.zeros((10, 10, 3), np.uint8)
H, W = img.shape[:2]
for r in range(a.gy):
    row = []
    for c in range(a.gx):
        n, m = acc['n'][r, c], acc['mv'][r, c]
        if m < 3:
            row.append('   n%4d  moving%3.0f%%  -' % (n, 100 * m / max(n, 1)))
            continue
        vx, vy = acc['vx'][r, c] / m / a.k, acc['vy'][r, c] / m / a.k
        R = math.hypot(acc['cx'][r, c], acc['cy'][r, c]) / m          # direction coherence 0..1
        ang = math.degrees(math.atan2(acc['cy'][r, c], acc['cx'][r, c]))
        row.append('   n%4d  moving%3.0f%%  dir %4.0f  coh %.2f  v %.2f' % (n, 100 * m / max(n, 1), ang, R, math.hypot(vx, vy)))
        cxp, cyp = int((c + 0.5) * W / a.gx), int((r + 0.5) * H / a.gy)
        s = 0.35 * min(W / a.gx, H / a.gy) * R
        cv2.arrowedLine(img, (cxp, cyp), (int(cxp + s * math.cos(math.radians(ang))), int(cyp + s * math.sin(math.radians(ang)))),
                        (0, 255, 255), 2, tipLength=0.3)
        cv2.putText(img, '%d%%' % (100 * m / max(n, 1)), (cxp - 14, cyp + 18), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 255, 0), 1)
    lines.append(' |'.join(row))
for c in range(1, a.gx):
    cv2.line(img, (int(c * W / a.gx), 0), (int(c * W / a.gx), H), (80, 80, 80), 1)
for r in range(1, a.gy):
    cv2.line(img, (0, int(r * H / a.gy)), (W, int(r * H / a.gy)), (80, 80, 80), 1)
open(a.out + '.txt', 'w').write('\n'.join(lines) + '\n')
cv2.imwrite(a.out + '.jpg', img)
print('\n'.join(lines))
