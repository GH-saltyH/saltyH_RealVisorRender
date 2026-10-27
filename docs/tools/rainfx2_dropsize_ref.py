"""Drop size distribution of a reference frame (docs/RAINFX_V2_DROP_PIPELINE_PLAN.md section 2).

Drops on a bright background show as dark crescents: local darkness Y - blur(sigma 15) < -12,
connected components, size = longest bounding-box side (px). Prints percentiles, a log-binned
histogram and the density. Works on v2 Debug 0 PNGs as well (same rule) for side-by-side numbers.

usage: python rainfx2_dropsize_ref.py frame1.png [frame2.png ...] [--crop x0 y0 x1 y1]
"""
import argparse
import numpy as np
from PIL import Image
from scipy import ndimage as nd

ap = argparse.ArgumentParser()
ap.add_argument('frames', nargs='+')
ap.add_argument('--crop', nargs=4, type=int, default=None)
ap.add_argument('--thr', type=float, default=12.0)
a = ap.parse_args()

sizes, dens, width = [], [], None
for f in a.frames:
    y = np.asarray(Image.open(f).convert('L'), float)
    if a.crop:
        x0, y0, x1, y1 = a.crop
        y = y[y0:y1, x0:x1]
    width = y.shape[1]
    dark = (y - nd.gaussian_filter(y, 15)) < -a.thr
    dark = nd.binary_opening(dark, iterations=1)
    lab, n = nd.label(dark)
    s = [max(o[0].stop - o[0].start, o[1].stop - o[1].start) for o in nd.find_objects(lab)]
    s = [v for v in s if v >= 3]
    sizes += s
    dens.append(len(s) / y.size * 1e4)
s = np.array(sizes, float)
print('frames %d  drops %d  per 100x100 px %.1f  (crop width %d px)' % (len(a.frames), len(s), np.mean(dens), width))
print('percentiles px:', {q: round(float(np.percentile(s, q)), 1) for q in (25, 50, 75, 90, 97, 99)})
print('relative to p50:', {q: round(float(np.percentile(s, q) / np.percentile(s, 50)), 2) for q in (75, 90, 97, 99)})
edges = [3, 5, 8, 12, 18, 27, 40, 60, 100, 200]
h, _ = np.histogram(s, bins=edges)
print('histogram (1.5x bins):', list(zip(edges[:-1], h.tolist())))
