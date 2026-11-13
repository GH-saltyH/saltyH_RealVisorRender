"""H3 overlap-cut x drop size comparison (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 29.9).
Rows: pattern scale s (drop radii x s: octave -1 ... +0.5), columns: border band B (0 / 0.18 / 0.35), last column the
user's photo. Every panel is 15 x 15 mm at the game pixel scale (~50 um / px, 300 px, shown 1:1) with a 1 mm bar.
Labels give the VISIBLE size per panel: equivalent radius sqrt(area / pi) of the region each drop owns after the cut
(drops >= 2 px area), p50 / p90 / max in mm -> how cutting changes the apparent sizes.
Usage: python rainfx2_overlap_size_grid.py OUTDIR"""
import numpy as np, cv2, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
src = open(os.path.join(HERE, 'rainfx2_overlap_cut_sim.py'), encoding='utf-8').read()
exec(src[:src.index('\nS = 360')])                              # breath figure, bake, scene, shade, label
sh = np.array([[i * T, j * T] for i in range(3) for j in range(3)], float)
pos = (pos[None] + sh[:, None]).reshape(-1, 2); rad = np.tile(rad, 9); noise = np.tile(noise, (9, 1))   # 38.4 mm periodic

P, VIEW, SSH = 300, 15.0, 4                                    # panel px, view mm, shading texels per game px
def panel(s, B):
    win = VIEW / s; px = 0.05 / SSH / s                         # pattern mm window and texel -> radii appear x s
    H, ID = bake(2.0, 2.0, win, px, B)
    img = cv2.resize(shade(H, px, 0.3 * 1080 * SSH), (P, P), interpolation=cv2.INTER_AREA)
    ids, cnt = np.unique(ID[ID >= 0], return_counts=True)
    req = np.sqrt(cnt * (px * s) ** 2 / np.pi)                  # owned-area equivalent radius on the visor (mm)
    req = req[cnt * (px * s / 0.05) ** 2 >= 2.0]                # visible: >= 2 game px of area
    return img, np.percentile(req, [50, 90]), req.max(), len(req) / VIEW ** 2

def put(img, lines, col=(255, 255, 255)):
    img = (np.clip(img, 0, 1) * 255).astype(np.uint8).copy() if img.dtype != np.uint8 else img.copy()
    cv2.rectangle(img, (0, 0), (P, 14 * len(lines) + 6), (0, 0, 0), -1)
    for k, t in enumerate(lines):
        cv2.putText(img, t, (4, 14 + 14 * k), cv2.FONT_HERSHEY_SIMPLEX, 0.38, col, 1, cv2.LINE_AA)
    cv2.rectangle(img, (P - 30, P - 14), (P - 10, P - 10), (255, 255, 255), -1)            # 1 mm = 20 px
    cv2.putText(img, '1 mm', (P - 66, P - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.36, (255, 255, 255), 1, cv2.LINE_AA)
    return img

ref = cv2.imread(os.path.join(HERE, '..', 'reference_frames', 'microdrop_ref_window.png'))
refp = cv2.resize(ref[300:540, 420:660], (P, P)) if ref is not None else np.zeros((P, P, 3), np.uint8)
rows = []
for s, oct_ in ((0.5, '-1'), (0.71, '-0.5'), (1.0, '0'), (1.41, '+0.5')):
    tiles = []
    for B in (0.0, 0.18, 0.35):
        img, (p50, p90), mx, dens = panel(s, B)
        tiles.append(put(img, ['scale x%.2f (oct %s)  B %.2f' % (s, oct_, B),
                               'visible r p50 %.2f p90 %.2f max %.2f mm' % (p50, p90, mx),
                               '%.0f drops / cm2' % (dens * 100)]))
        print(s, B, p50, p90, mx, dens * 100)
    tiles.append(put(refp, ['user photo (crop)', 'scale unknown'], (200, 255, 200)))
    rows.append(np.hstack(tiles))
cv2.imwrite(os.path.join(OUT, 'rainfx2_h3_overlap_size_grid.png'), np.vstack(rows))
