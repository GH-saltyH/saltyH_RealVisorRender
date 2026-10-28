"""Drop persistence on the visor, from a video (docs/RAINFX_V2_REV47B_REVIEW.md).

Onboard 'driver's eye' cameras sit behind the visor, so water on the visor is fixed in the frame
unless it slides, while the scene behind it moves and shakes. A drop-like blob (difference of
Gaussians, both polarities) that is found again within `tol` px after a lag of 0.1 / 0.25 / 0.5 / 1 s
is a drop that stayed; the persistence curve P(lag) therefore measures how long water rests on the
visor -- independent of the camera scale. For blobs that moved, the displacement to the nearest blob
one frame later (within `reach` px) gives the visible sliding speed in frame heights per second.

All frames are rescaled to 720 px height. Use an ROI with little scene detail (sky / distant track)
so that static scene features do not count as drops.

usage: python rainfx2_drop_persistence.py video.mp4 --t0 5 --t1 12 --roi x0 y0 x1 y1 (fractions)
"""
import argparse
import subprocess
import numpy as np
from scipy import ndimage as nd

ap = argparse.ArgumentParser()
ap.add_argument('video')
ap.add_argument('--t0', type=float, default=0)
ap.add_argument('--t1', type=float, default=10)
ap.add_argument('--roi', nargs=4, type=float, default=[0.1, 0.1, 0.9, 0.5])
ap.add_argument('--thr', type=float, default=6.0)
ap.add_argument('--tol', type=float, default=2.5)
ap.add_argument('--reach', type=float, default=14.0)
a = ap.parse_args()

info = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
                       'stream=width,height,r_frame_rate', '-of', 'csv=p=0', a.video],
                      capture_output=True, text=True).stdout.strip().split(',')
w, h = int(info[0]), int(info[1])
num, den = info[2].split('/')
fps = float(num) / float(den)
if fps > 100:
    fps = 30.0
H = 720
W = int(round(w * H / h / 2) * 2)
n = int((a.t1 - a.t0) * fps)
raw = subprocess.run(['ffmpeg', '-v', 'error', '-ss', str(a.t0), '-i', a.video, '-frames:v', str(n),
                      '-vf', 'scale=%d:%d' % (W, H), '-f', 'rawvideo', '-pix_fmt', 'gray', '-'],
                     capture_output=True).stdout
n = len(raw) // (W * H)
fr = np.frombuffer(raw, np.uint8)[:n * W * H].reshape(n, H, W).astype(np.float32)
x0, y0, x1, y1 = int(a.roi[0] * W), int(a.roi[1] * H), int(a.roi[2] * W), int(a.roi[3] * H)


def blobs(img):
    d = nd.gaussian_filter(img, 1.5) - nd.gaussian_filter(img, 6.0)
    m = np.abs(d) > a.thr
    lab, k = nd.label(m)
    if k == 0:
        return np.zeros((0, 2))
    c = np.array(nd.center_of_mass(m, lab, range(1, k + 1)))
    sz = nd.sum(m, lab, range(1, k + 1))
    c = c[(sz >= 4) & (sz <= 400)]
    return c


B = [blobs(f[y0:y1, x0:x1]) for f in fr]


def nearest(p, q):
    if len(p) == 0 or len(q) == 0:
        return np.full(len(p), np.inf)
    d = np.sqrt(((p[:, None, :] - q[None, :, :]) ** 2).sum(-1))
    return d.min(1)


print('%s  fps %.0f  frames %d  roi %s  blobs/frame %.0f' % (a.video.split('/')[-1][:60], fps, n, a.roi,
                                                            np.mean([len(b) for b in B])))
for lag in (0.1, 0.25, 0.5, 1.0):
    k = max(1, int(round(lag * fps)))
    vals = []
    for i in range(0, n - k, max(1, k // 2)):
        d = nearest(B[i], B[i + k])
        if len(d):
            vals.append(np.mean(d <= a.tol))
    print('  persistence after %.2f s: %.2f' % (lag, np.mean(vals) if vals else float('nan')))
sp = []
for i in range(n - 1):
    d = nearest(B[i], B[i + 1])
    sp += list(d[(d > a.tol) & (d <= a.reach)])
sp = np.array(sp) * fps / H
if len(sp):
    print('  moving blobs: %.1f per frame, speed p50 %.2f p90 %.2f frame heights / s' % (
        len(sp) / max(n - 1, 1), np.percentile(sp, 50), np.percentile(sp, 90)))
