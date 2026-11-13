"""H3 micro-drop atlas prototype (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 29).
1) BAKE: a tileable breath-figure pattern by growth + coalescence + renucleation in the gaps (periodic 12.8 mm tile):
   polydisperse drops with big drops surrounded by small ones (the depletion structure of a real coat).
   Height = MAX over drops of a cap profile drawn a border band wider than the drop (rim noise x0.85-1.15, slight
   ellipse) -> neighbours CUT each other along a crease inside the overlapping border bands, so shapes are polygonal /
   irregular, not circles (the CSP windscreen 'max stamp' idea).
   Stored per texel: normal xy, height, rank (the coarsening order a drop appears in), at 12.5 um.
2) RENDER at the game's pixel scale (~50 um / px) with the CSP windscreen shading (visor.hlsl r2CspWater path):
   flat interior refracts the scene by a small normal offset, steep rim takes the environment by world direction x0.7,
   reflection (1 - nz)^3. Water depth h of the haze layer chooses the OCTAVE (self-similar coarsening: mean radius ~ h at
   constant coverage) -- two octaves cross-faded, fine octaves fall to sub-pixel and mip into the flat scatter (B fog).
Usage: python rainfx2_microdrop_atlas_sim.py OUTDIR"""
import numpy as np, cv2, os, sys
from scipy.spatial import cKDTree
from scipy.ndimage import uniform_filter
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
rng = np.random.default_rng(11)
T = 12.8                      # tile mm
TEX = 1024                    # texels (12.5 um)

# ---------------- 1. breath figure growth / coalescence ----------------
def breath_figure(steps=32):
    pos = rng.uniform(0, T, (4000, 2)); r = np.full(4000, 0.012); u = rng.random(4000)
    for it in range(steps):
        r = r * 1.045 + 0.0008                                 # condensation growth (all drops)
        for _ in range(6):                                     # merge touching drops (volume, centre of mass)
            tr = cKDTree(pos, boxsize=T)
            pairs = tr.query_pairs(2 * r.max())
            if not pairs: break
            pairs = np.array(list(pairs))
            d = pos[pairs[:, 0]] - pos[pairs[:, 1]]; d -= T * np.round(d / T)
            hit = np.hypot(d[:, 0], d[:, 1]) < (r[pairs[:, 0]] + r[pairs[:, 1]]) * 0.98
            pairs = pairs[hit]
            if len(pairs) == 0: break
            used = np.zeros(len(r), bool); keep = np.ones(len(r), bool)
            for a, b in pairs:
                if used[a] or used[b]: continue
                used[a] = used[b] = True
                va, vb = r[a] ** 3, r[b] ** 3
                db = pos[b] - pos[a]; db -= T * np.round(db / T)
                pos[a] = (pos[a] + db * vb / (va + vb)) % T
                r[a] = (va + vb) ** (1 / 3); u[a] = min(u[a], u[b]); keep[b] = False
            pos, r, u = pos[keep], r[keep], u[keep]
        if True:                                               # renucleation in the free surface (every step: continuous sizes)
            cand = rng.uniform(0, T, (2500, 2))
            dd, ii = cKDTree(pos, boxsize=T).query(cand)
            free = cand[dd > r[ii] + 0.03]
            pos = np.vstack([pos, free]); r = np.concatenate([r, np.full(len(free), 0.012)])
            u = np.concatenate([u, rng.random(len(free))])
    return pos, r

pos, rad = breath_figure()
cov = np.pi * (rad ** 2).sum() / T ** 2
print('drops %d  coverage %.2f  r p10/p50/p90/max %.3f %.3f %.3f %.3f mm' % (len(rad), cov, *np.percentile(rad, [10, 50, 90]), rad.max()))

# ---------------- 2. bake: max composite with border band (cut) ----------------
px = T / TEX
H = np.zeros((TEX, TEX), np.float32)
BORDER = 0.18                                                  # border band (x r): drawn wider so neighbours OVERLAP and cut
ang = np.linspace(0, 2 * np.pi, 9)[:-1]
for (cx, cy), r in zip(pos, rad):
    rr = r * (1 + BORDER)
    n = int(np.ceil(rr / px)) + 2
    i0, j0 = int(cy / px) - n, int(cx / px) - n
    ys, xs = np.mgrid[i0:i0 + 2 * n + 1, j0:j0 + 2 * n + 1]
    dx = (xs + 0.5) * px - cx; dy = (ys + 0.5) * px - cy
    th = np.arctan2(dy, dx)
    k = rng.normal(0, 1, 4)                                    # rim noise: low-order Fourier outline x0.85-1.15
    rim = 1 + 0.10 * (k[0] * np.cos(2 * th + k[1]) + k[2] * np.cos(3 * th + k[3]))
    rho = np.hypot(dx, dy) / (r * rim)
    cap = r * 0.8 * np.sqrt(np.clip(1 - (rho / (1 + BORDER)) ** 2, 0, 1)) ** 0.6   # steep rim (coated visor, ~80 deg)
    yi, xi = ys % TEX, xs % TEX
    H[yi, xi] = np.maximum(H[yi, xi], cap.astype(np.float32))
gy, gx = np.gradient(H, px)
N = np.dstack([-gx, -gy, np.ones_like(H)]); N /= np.linalg.norm(N, axis=2, keepdims=True)
COV = (H > 1e-4).astype(np.float32)
cv2.imwrite(os.path.join(OUT, 'atlas_height.png'), (H / H.max() * 255).astype(np.uint8))

# ---------------- 3. render ----------------
PX = 0.05; W = 480; SS = 2                                     # 24 mm panel (game ~50 um / px), 2x supersampled shading
bgsrc = cv2.imread(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'rainfx2_sheet_bg.png')).astype(np.float32) / 255
SC = W / 140.0 * SS                                            # the 140 px source crop fills the panel
BIG = cv2.resize(bgsrc, (int(bgsrc.shape[1] * SC), int(bgsrc.shape[0] * SC)), interpolation=cv2.INTER_CUBIC)
BIGB = cv2.GaussianBlur(BIG, (0, 0), 6 * SS)                    # the scene through a tiny lens: minified -> blurred (mip)
sky, ground = np.array([0.86, 0.86, 0.84], np.float32), np.array([0.20, 0.22, 0.20], np.float32)
yy, xx = (np.mgrid[0:W * SS, 0:W * SS].astype(np.float32) + 0.5) * (PX / SS)
REFR = 0.30 * 1080 * SS                                        # CSP: uv offset ~0.3 x screen per unit normal (cspRefract)

def sample_atlas(scale, lodpx):
    u = (xx / scale) % T / px; v = (yy / scale) % T / px
    k = max(1, int(round(lodpx)))
    def f(a):
        a2 = uniform_filter(a, k, mode='wrap') if k > 1 else a
        return cv2.remap(a2, u.astype(np.float32), v.astype(np.float32), cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)
    return f(N[..., 0].copy()), f(N[..., 1].copy()), f(COV)

def shade(nx, ny, cov, wipe, org):
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    oy, ox = org
    gx = (np.arange(W * SS)[None, :] + ox).astype(np.float32); gy = (np.arange(W * SS)[:, None] + oy).astype(np.float32)
    bg = BIG[oy:oy + W * SS, ox:ox + W * SS]
    mx = (gx - nx * REFR).astype(np.float32); my = (gy - ny * REFR).astype(np.float32)
    scr = cv2.remap(BIGB, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    up = np.clip(-ny * 1.6 + 0.5, 0, 1)[..., None]
    env = (sky * up + ground * (1 - up)) * 0.7
    wS = np.clip((nz - 0.3) * 10, 0, 1)[..., None]
    c = env * (1 - wS) + scr * wS + sky * (((1 - nz) ** 3) * np.clip(-ny, 0, 1) * 1.5)[..., None]
    a = (cov * (1 - wipe))[..., None]
    return bg * (1 - a) + c * a

def wipe_mask(r=0.6, k=0.5, hin=0.1, hout=0.4):
    a, b = np.array([4.0, 22.0]), np.array([10.0, 2.0])
    ab = b - a; t = np.clip(((xx - a[0]) * ab[0] + (yy - a[1]) * ab[1]) / (ab @ ab), 0, 1)
    d = np.hypot(xx - (a[0] + ab[0] * t), yy - (a[1] + ab[1] * t))
    s = np.clip((d - r - hin) / (r * (1 + k) + hout - r - hin), 0, 1)
    return 1 - s * s * (3 - 2 * s)

def octave_render(level, wipe, org):
    """level: log2 of the pattern scale (0 = baked size). Two octaves cross-faded (self-similar coarsening)."""
    l0 = np.floor(level); f = level - l0
    out = 0
    for l, wgt in ((l0, 1 - f), (l0 + 1, f)):
        if wgt <= 0: continue
        s = 2.0 ** l
        lod = (PX / SS) / (px * s)                             # atlas texels per shading sample
        nx, ny, cv = sample_atlas(s, lod)
        out = out + wgt * shade(nx, ny, cv, wipe, org)
    return cv2.resize(out, (W, W), interpolation=cv2.INTER_AREA)

def label(img, t):
    img = (np.clip(img, 0, 1) * 255).astype(np.uint8).copy()
    cv2.rectangle(img, (0, 0), (W, 22), (0, 0, 0), -1)
    cv2.putText(img, t, (6, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.46, (255, 255, 255), 1, cv2.LINE_AA)
    return img

wipe = wipe_mask()
O1 = (int(30 * SC), int(250 * SC))                              # sky / trees / barrier (the H2 crop)
O2 = (int(150 * SC), int(40 * SC))                              # dark cockpit / car body below (dark background)
tiles = []
for lv, name, org in ((-2.0, 'octave -2 (fine: mips to fog)', O1), (-1.0, 'octave -1', O1),
                      (0.0, 'octave 0 (baked size)', O1), (0.6, 'octave +0.6 (coarse)', O1),
                      (0.0, 'octave 0, dark background', O2)):
    tiles.append(label(octave_render(lv, wipe, org), name))
ref = cv2.imread(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'reference_frames', 'microdrop_ref_window.png'))
ref = cv2.resize(ref[260:560, 380:680], (W, W)) if ref is not None else np.zeros((W, W, 3), np.uint8)
tiles.append(label(ref.astype(np.float32) / 255, 'reference (user photo, crop)'))
sheet = np.vstack([np.hstack(tiles[:3]), np.hstack(tiles[3:])])
cv2.imwrite(os.path.join(OUT, 'rainfx2_h3_microdrop_atlas.png'), sheet)
z = cv2.resize(tiles[3][120:280, 200:360], (480, 480), interpolation=cv2.INTER_NEAREST)
cv2.imwrite(os.path.join(OUT, 'rainfx2_h3_microdrop_zoom.png'), np.hstack([z, cv2.resize(ref[120:280, 200:360], (480, 480))]))
print('ok')
