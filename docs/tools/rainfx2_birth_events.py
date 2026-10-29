"""Birth / impact event finder for a reference video (docs/RAINFX_V2_SHAPE_STATE_PLAN.md section 9).

Drops on the window stay fixed in the frame (phone on the glass). A new local-contrast region that is
absent in the 4 frames before t and present in all 4 frames after t+2 is an event (impact, push-off,
trail). Events are deduplicated (10 frames, 40 px) and the largest are shown as crop sequences at
-4, 0, +2, +4, +8, +16, +30, +60 frames.
usage: python rainfx2_birth_events.py video.mp4 out.jpg [--ymax 620] [--count 16]
"""
import argparse, json, subprocess
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as nd
from skimage import measure

ap = argparse.ArgumentParser()
ap.add_argument('video'); ap.add_argument('out')
ap.add_argument('--ymax', type=int, default=620); ap.add_argument('--count', type=int, default=16)
a = ap.parse_args()
info = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height',
                       '-of', 'csv=p=0', a.video], capture_output=True, text=True).stdout.strip().split(',')
W, H = int(info[0]), int(info[1])
w2, h2 = W // 2, H // 2
raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', a.video, '-vf', 'scale=%d:%d' % (w2, h2), '-f', 'rawvideo',
                      '-pix_fmt', 'gray', '-'], capture_output=True).stdout
n = len(raw) // (w2 * h2)
fr = np.frombuffer(raw, np.uint8)[:n * w2 * h2].reshape(n, h2, w2)
C = np.empty((n, h2, w2), np.uint8)
for i in range(n):
    f = fr[i].astype(np.float32)
    C[i] = np.clip(nd.uniform_filter(np.abs(f - nd.gaussian_filter(f, 3)), 3), 0, 255)
ev = []
for t in range(4, n - 8, 2):
    m = (C[t + 2:t + 6].min(0) > 9) & (C[t - 4:t - 1].max(0) < 4)
    lab, _ = nd.label(m)
    for p in measure.regionprops(lab):
        if p.area >= 8:
            y, x = p.centroid
            ev.append(dict(t=t, x=int(x * 2), y=int(y * 2), area=int(p.area * 4)))
ev.sort(key=lambda e: -e['area'])
kept = []
for e in ev:
    if not any(abs(e['t'] - k['t']) < 10 and abs(e['x'] - k['x']) < 40 and abs(e['y'] - k['y']) < 40 for k in kept):
        kept.append(e)
print('events', len(kept))
raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', a.video, '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-'], capture_output=True).stdout
frame = lambda i: np.frombuffer(raw, np.uint8, W * H * 3, max(0, min(n - 1, i)) * W * H * 3).reshape(H, W, 3)
sel = [e for e in kept if e['y'] < a.ymax and 60 < e['x'] < W - 60][:a.count]
offs, cs, sc = [-4, 0, 2, 4, 8, 16, 30, 60], 110, 2
img = Image.new('RGB', (len(offs) * cs * sc + 90, len(sel) * cs * sc), (20, 20, 20))
d = ImageDraw.Draw(img)
for r, e in enumerate(sel):
    d.text((4, r * cs * sc + 10), 't=%d\n(%d,%d)\nA%d' % (e['t'], e['x'], e['y'], e['area']), fill=(220, 220, 220))
    for c, o in enumerate(offs):
        x0, y0 = min(max(e['x'] - cs // 2, 0), W - cs), min(max(e['y'] - cs // 2, 0), H - cs)
        img.paste(Image.fromarray(frame(e['t'] + o)[y0:y0 + cs, x0:x0 + cs]).resize((cs * sc, cs * sc)), (90 + c * cs * sc, r * cs * sc))
img.save(a.out, quality=88)
json.dump(kept, open(a.out + '.json', 'w'))
