"""Reference study (docs/RAINFX_V2_TRAIL_REVIEW3.md section 40): HeavyRain ~100 km/h helmet-cam video. Do large drops look
flatter (weaker contrast) than small ones? Frames every 2 s; drops = blobs of the high-pass luminance (image - gaussian 20 px)
with |hp| > 0.035; per blob: equivalent diameter (px) and contrast (mean hp), split by the local background (bright = sky,
dark = cockpit / halo). usage: python rainfx2_ref_drop_contrast.py video.mp4
"""
import sys, subprocess, tempfile, glob, os
import numpy as np
from scipy import ndimage
from PIL import Image

v = sys.argv[1]
d = tempfile.mkdtemp()
subprocess.run(['ffmpeg', '-v', 'error', '-i', v, '-vf', 'fps=1/2', os.path.join(d, 'f%03d.png')], check=True)
rows = []
for f in sorted(glob.glob(os.path.join(d, '*.png'))):
    L = np.asarray(Image.open(f).convert('L'), float) / 255.0
    bg = ndimage.gaussian_filter(L, 20); hp = L - bg
    for sgn in (1, -1):
        lab, n = ndimage.label(sgn * hp > 0.035)
        if n == 0: continue
        idx = np.arange(1, n + 1)
        area = ndimage.sum(np.ones_like(L), lab, idx); con = ndimage.mean(hp, lab, idx); b = ndimage.mean(bg, lab, idx)
        for A, C, B in zip(area, con, b):
            if A >= 12: rows.append((2 * np.sqrt(A / np.pi), C, B))
r = np.array(rows)
print(f'blobs {len(r)}')
for name, m in (('bright background (sky, bg > 0.6)', r[:, 2] > 0.6), ('dark background (cockpit, bg < 0.35)', r[:, 2] < 0.35)):
    print(name)
    for lo, hi in ((4, 8), (8, 14), (14, 24), (24, 40), (40, 80)):
        k = m & (r[:, 0] >= lo) & (r[:, 0] < hi)
        if k.sum() < 3: continue
        dark = (r[k, 1] < 0).mean()
        print(f'  diameter {lo:2d}-{hi:2d} px: n {k.sum():4d}  darker than bg {dark * 100:3.0f}%  |contrast| {np.abs(r[k, 1]).mean():.3f}')
