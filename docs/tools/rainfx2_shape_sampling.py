"""Empirical drop SHAPE sampling from a reference video (docs/RAINFX_V2_SHAPE_STATE_PLAN.md section 6).

Drops on a window seen against a bright, defocused background: each drop is a closed region of high local
contrast (dark refracted rim + bright interior). Per frame: local contrast |I - G_8(I)| -> threshold ->
close -> fill holes -> label; per region (area >= minPx): equivalent radius, aspect (major/minor of the
second moments), orientation vs screen vertical, solidity (area / convex hull area; < 0.85 = lobed, peanut,
merged), eccentric mass (centroid offset from the box centre along the major axis = teardrop / comma).
Classes:
  round       aspect < 1.25, solidity >= 0.92
  ellipse     1.25 <= aspect < 2,  solidity >= 0.90
  elongated   aspect >= 2 (vertical = |orientation| < 30 deg from screen vertical, else lateral)
  lobed       solidity < 0.85 (peanut / merged / irregular puddle)
  teardrop    any of the above with |eccentric mass| > 0.12 of the major length
usage: python rainfx2_shape_sampling.py video.mp4 outdir [--t0 0 --t1 10 --step 0.5 --roi x0 y0 x1 y1]
Writes outdir/shape_stats.txt, outdir/shape_overlay_*.jpg (class colours) and outdir/shape_gallery.jpg.
"""
import argparse
import os
import subprocess
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as nd
from skimage import measure, morphology

ap = argparse.ArgumentParser()
ap.add_argument('video')
ap.add_argument('outdir')
ap.add_argument('--t0', type=float, default=0.0)
ap.add_argument('--t1', type=float, default=10.0)
ap.add_argument('--step', type=float, default=0.5)
ap.add_argument('--roi', nargs=4, type=float, default=[0.0, 0.0, 1.0, 0.55])
ap.add_argument('--thr', type=float, default=10.0)
ap.add_argument('--minPx', type=int, default=40)
a = ap.parse_args()
os.makedirs(a.outdir, exist_ok=True)

COL = {'round': (60, 200, 255), 'ellipse': (90, 255, 90), 'elong-vert': (255, 220, 0), 'elong-lat': (255, 140, 0),
       'lobed': (255, 60, 200)}


def frame(t):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-ss', str(t), '-i', a.video, '-frames:v', '1', '-f', 'image2pipe',
                          '-vcodec', 'png', '-'], capture_output=True).stdout
    from io import BytesIO
    return Image.open(BytesIO(raw)).convert('RGB')


rows = []
gallery = {k: [] for k in COL}
t = a.t0
k = 0
while t < a.t1:
    im = frame(t)
    W, H = im.size
    x0, y0, x1, y1 = int(a.roi[0] * W), int(a.roi[1] * H), int(a.roi[2] * W), int(a.roi[3] * H)
    crop = im.crop((x0, y0, x1, y1))
    g = np.asarray(crop.convert('L'), np.float32)
    # a drop = dark refracted rim (one side) + bright interior / highlight; the rim alone is a crescent, so the
    # footprint is the closed union of both, and shape measures use its convex hull (contour) and the region
    lc = g - nd.gaussian_filter(g, 10.0)
    m = (lc < -a.thr) | (lc > 0.6 * a.thr)
    m = nd.binary_closing(m, morphology.disk(3))
    m = nd.binary_fill_holes(m)
    m = nd.binary_opening(m, morphology.disk(2))
    lab = measure.label(m)
    ov = crop.copy()
    dr = ImageDraw.Draw(ov)
    for p in measure.regionprops(lab):
        if p.area < a.minPx or p.area > 0.004 * m.size:
            continue
        maj, mi = p.axis_major_length, max(p.axis_minor_length, 1e-3)
        asp = maj / mi
        sol = p.solidity
        ori = np.degrees(p.orientation)              # skimage: angle between row axis (vertical) and major axis
        cy, cx = p.centroid
        by0, bx0, by1, bx1 = p.bbox
        ecc = ((cy - (by0 + by1) / 2) * np.cos(p.orientation) + (cx - (bx0 + bx1) / 2) * np.sin(p.orientation)) / max(maj, 1)
        if sol < 0.85:
            cls = 'lobed'
        elif asp >= 2.0:
            cls = 'elong-vert' if abs(ori) < 30 else 'elong-lat'
        elif asp >= 1.25:
            cls = 'ellipse'
        else:
            cls = 'round'
        tear = abs(ecc) > 0.12
        rows.append((t, np.sqrt(p.area / np.pi), asp, sol, ori, ecc, cls, tear))
        dr.rectangle((bx0, by0, bx1, by1), outline=COL[cls], width=2 if tear else 1)
        if len(gallery[cls]) < 12 and p.area > 150:
            pad = 6
            gallery[cls].append(crop.crop((max(bx0 - pad, 0), max(by0 - pad, 0), bx1 + pad, by1 + pad)).resize((72, 72)))
    if k < 4:
        ov.save(os.path.join(a.outdir, 'shape_overlay_%d.jpg' % k), quality=88)
    k += 1
    t += a.step

R = np.array([r[1] for r in rows])
lines = ['frames %d, regions %d (radius px p25 %.1f p50 %.1f p90 %.1f)' % (k, len(rows), *np.percentile(R, [25, 50, 90]))]
bins = [(0, 6), (6, 10), (10, 16), (16, 1e9)]
lines.append('class share by equivalent radius (px):  ' + '  '.join('%s' % (b,) for b in bins))
for cls in COL:
    sh = []
    for lo, hi in bins:
        sel = [r for r in rows if lo <= r[1] < hi]
        sh.append(100.0 * sum(1 for r in sel if r[6] == cls) / max(len(sel), 1))
    tot = 100.0 * sum(1 for r in rows if r[6] == cls) / max(len(rows), 1)
    lines.append('  %-11s total %5.1f %%   by size %s' % (cls, tot, '  '.join('%5.1f' % v for v in sh)))
tear = [r for r in rows if r[7]]
lines.append('teardrop / comma (eccentric mass > 0.12): %.1f %%' % (100.0 * len(tear) / max(len(rows), 1)))
el = [r for r in rows if r[2] >= 1.25]
if el:
    ang = np.array([abs(r[4]) for r in el])
    lines.append('orientation of non-round drops (deg from vertical): <30 %.0f %%, 30-60 %.0f %%, >60 %.0f %%' % (
        100 * np.mean(ang < 30), 100 * np.mean((ang >= 30) & (ang < 60)), 100 * np.mean(ang >= 60)))
A = np.array([r[2] for r in rows])
S = np.array([r[3] for r in rows])
lines.append('aspect p50 %.2f p90 %.2f | solidity p10 %.2f p50 %.2f' % (np.percentile(A, 50), np.percentile(A, 90),
                                                                     np.percentile(S, 10), np.percentile(S, 50)))
open(os.path.join(a.outdir, 'shape_stats.txt'), 'w').write('\n'.join(lines) + '\n')
print('\n'.join(lines))
gw = Image.new('RGB', (12 * 76 + 120, len(COL) * 76), (20, 20, 20))
gd = ImageDraw.Draw(gw)
for i, cls in enumerate(COL):
    gd.text((4, i * 76 + 30), cls, fill=COL[cls])
    for j, c in enumerate(gallery[cls]):
        gw.paste(c, (120 + j * 76, i * 76 + 2))
gw.save(os.path.join(a.outdir, 'shape_gallery.jpg'), quality=90)
