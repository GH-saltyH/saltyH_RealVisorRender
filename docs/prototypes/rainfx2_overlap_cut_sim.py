"""H3 overlap-cut visualisation (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 29.8).
Same breath-figure drop set, drawn with a growing border band B (each drop drawn to r (1 + B), height = MAX over drops):
  B = 0     : drops end at their own rim -> separate circles
  B = 0.18  : neighbours overlap inside the bands and cut each other along the equal-height crease (H3 default)
  B = 0.35 / 0.6 : stronger cutting -> packed polygonal cells
Columns: owner map (which drop wins each texel: the cut shapes), lit relief close-up (3 x 3 mm, 6 um / px),
game scale (12 x 12 mm at ~50 um / px) over a dark road under a bright sky (the user's photo situation),
with the CSP windscreen shading (interior refracts the scene by ~0.3 screen x normal, steep rim = environment x0.7).
Usage: python rainfx2_overlap_cut_sim.py OUTDIR"""
import numpy as np, cv2, os, sys
from scipy.spatial import cKDTree
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
rng = np.random.default_rng(11)
T = 12.8

def breath_figure(steps=32):                                   # growth + coalescence + renucleation (as the atlas sim)
    pos = rng.uniform(0, T, (4000, 2)); r = np.full(4000, 0.012)
    for it in range(steps):
        r = r * 1.045 + 0.0008
        for _ in range(6):
            pairs = cKDTree(pos, boxsize=T).query_pairs(2 * r.max())
            if not pairs: break
            pairs = np.array(list(pairs))
            d = pos[pairs[:, 0]] - pos[pairs[:, 1]]; d -= T * np.round(d / T)
            pairs = pairs[np.hypot(d[:, 0], d[:, 1]) < (r[pairs[:, 0]] + r[pairs[:, 1]]) * 0.98]
            if len(pairs) == 0: break
            used = np.zeros(len(r), bool); keep = np.ones(len(r), bool)
            for a, b in pairs:
                if used[a] or used[b]: continue
                used[a] = used[b] = True
                va, vb = r[a] ** 3, r[b] ** 3
                db = pos[b] - pos[a]; db -= T * np.round(db / T)
                pos[a] = (pos[a] + db * vb / (va + vb)) % T; r[a] = (va + vb) ** (1 / 3); keep[b] = False
            pos, r = pos[keep], r[keep]
        cand = rng.uniform(0, T, (2500, 2))
        dd, ii = cKDTree(pos, boxsize=T).query(cand)
        free = cand[dd > r[ii] + 0.03]
        pos = np.vstack([pos, free]); r = np.concatenate([r, np.full(len(free), 0.012)])
    return pos, r

pos, rad = breath_figure()
noise = rng.normal(0, 1, (len(rad), 4))                        # fixed outline noise per drop (same in every row)

def bake(x0, y0, size, px, B):
    """height (max composite) and owner id over the window [x0, x0 + size) mm at px mm / texel."""
    n = int(round(size / px))
    H = np.zeros((n, n), np.float32); ID = np.full((n, n), -1, np.int32)
    sel = np.where((pos[:, 0] > x0 - 1) & (pos[:, 0] < x0 + size + 1) & (pos[:, 1] > y0 - 1) & (pos[:, 1] < y0 + size + 1))[0]
    for i in sel[np.argsort(rad[sel])]:
        cx, cy, r = pos[i, 0], pos[i, 1], rad[i]
        rr = r * (1 + B) * 1.25
        j0, j1 = int(max((cx - rr - x0) / px, 0)), int(min((cx + rr - x0) / px + 1, n))
        i0, i1 = int(max((cy - rr - y0) / px, 0)), int(min((cy + rr - y0) / px + 1, n))
        if i0 >= i1 or j0 >= j1: continue
        ys, xs = np.mgrid[i0:i1, j0:j1]
        dx = x0 + (xs + 0.5) * px - cx; dy = y0 + (ys + 0.5) * px - cy
        th = np.arctan2(dy, dx); k = noise[i]
        rim = 1 + 0.10 * (k[0] * np.cos(2 * th + k[1]) + k[2] * np.cos(3 * th + k[3]))
        rho = np.hypot(dx, dy) / (r * rim)
        cap = (r * 0.8 * np.sqrt(np.clip(1 - (rho / (1 + B)) ** 2, 0, 1)) ** 0.6).astype(np.float32)
        win = cap > H[i0:i1, j0:j1]
        H[i0:i1, j0:j1] = np.where(win, cap, H[i0:i1, j0:j1])
        ID[i0:i1, j0:j1] = np.where(win & (cap > 0), i, ID[i0:i1, j0:j1])
    return H, ID

def owner_img(ID):
    pal = rng.random((len(rad), 3)).astype(np.float32) * 0.7 + 0.3
    img = np.where(ID[..., None] >= 0, pal[np.maximum(ID, 0)], 0.05)
    edge = (np.abs(np.diff(ID, axis=0, append=ID[-1:])) + np.abs(np.diff(ID, axis=1, append=ID[:, -1:]))) > 0
    img[edge] = 0.0
    return img

def scene(gy, h):                                              # bright sky above the window, dark road behind it
    t = np.clip(gy / h, -2, 1.5)
    return (np.array([0.92, 0.93, 0.95], np.float32) * np.clip(0.35 - t, 0, 1)[..., None]
            + np.array([0.13, 0.14, 0.14], np.float32) * np.clip(t + 0.65, 0, 1)[..., None])

def shade(H, px, refr_px):
    gy, gx = np.gradient(H, px)
    nx, ny = -gx, -gy
    l = np.sqrt(1 + nx * nx + ny * ny); nx, ny, nz = nx / l, ny / l, 1 / l
    n = H.shape[0]
    Y = np.arange(n, dtype=np.float32)[:, None] * np.ones((1, n), np.float32)
    bg = scene(Y, n)
    scr = scene(Y - ny * refr_px, n) * (1 + 0.15 * nx[..., None])           # interior: scene shifted by the lens
    up = np.clip(-ny * 1.6 + 0.5, 0, 1)[..., None]
    env = (np.array([0.92, 0.93, 0.95], np.float32) * up + np.array([0.13, 0.14, 0.14], np.float32) * (1 - up)) * 0.7
    wS = np.clip((nz - 0.3) * 10, 0, 1)[..., None]
    c = env * (1 - wS) + scr * wS + (np.array([1, 1, 1], np.float32) * ((1 - nz) ** 3 * np.clip(-ny, 0, 1) * 1.2)[..., None])
    a = (H > 1e-5).astype(np.float32)[..., None]
    return bg * (1 - a) + c * a

def label(img, t, w):
    img = (np.clip(img, 0, 1) * 255).astype(np.uint8).copy()
    cv2.rectangle(img, (0, 0), (w, 20), (0, 0, 0), -1)
    cv2.putText(img, t, (5, 14), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (255, 255, 255), 1, cv2.LINE_AA)
    return img

S = 360
rows = []
for B in (0.0, 0.18, 0.35, 0.6):
    Hz, IDz = bake(4.0, 4.0, 3.0, 0.006, B)                   # close-up 3 mm (500 texels)
    own = cv2.resize(owner_img(IDz), (S, S), interpolation=cv2.INTER_NEAREST)
    rel = cv2.resize(shade(Hz, 0.006, 0.3 * 1080 * 0.05 / 0.006 * (500 / 960)), (S, S), interpolation=cv2.INTER_AREA)
    Hg, _ = bake(0.4, 0.4, 12.0, 0.0125, B)                    # 12 mm, shaded at 12.5 um then area-averaged to 50 um / px
    gam = cv2.resize(shade(Hg, 0.0125, 0.3 * 1080 * 4), (240, 240), interpolation=cv2.INTER_AREA)
    gam = cv2.resize(gam, (S, S), interpolation=cv2.INTER_NEAREST)   # shown 1.5x (nearest) so the game pixels stay visible
    rows.append(np.hstack([label(own, 'B %.2f  owner map (3 mm)' % B, S), label(rel, 'B %.2f  relief close-up (3 mm)' % B, S),
                           label(gam, 'B %.2f  game scale 12 mm (~50 um/px)' % B, S)]))
cv2.imwrite(os.path.join(OUT, 'rainfx2_h3_overlap_cut.png'), np.vstack(rows))
ref = cv2.imread(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'reference_frames', 'microdrop_ref_window.png'))
if ref is not None:
    # octave -1 (drops half the baked size: the same pattern over 24 mm in 240 px) + a light optical blur (0.7 px)
    sh = np.array([[0, 0], [T, 0], [0, T], [T, T]])
    pos = (pos[None] + sh[:, None]).reshape(-1, 2); rad = np.tile(rad, 4); noise = np.tile(noise, (4, 1))   # periodic 2 x 2 tile
    Hh, _ = bake(0.4, 0.4, 24.0, 0.025, 0.18)
    half = cv2.resize(shade(Hh, 0.025, 0.3 * 1080 * 4), (240, 240), interpolation=cv2.INTER_AREA)
    half = cv2.GaussianBlur(half, (0, 0), 0.7)
    half = cv2.resize(half, (S, S), interpolation=cv2.INTER_NEAREST)
    cv2.imwrite(os.path.join(OUT, 'rainfx2_h3_overlap_ref.png'),
                np.hstack([rows[1][:, 2 * S:], label(half, 'B 0.18  octave -1 + 0.7 px blur', S),
                           label(cv2.resize(ref[300:540, 420:660], (S, S)).astype(np.float32) / 255, 'user photo (crop)', S)]))
print('drops', len(rad))
