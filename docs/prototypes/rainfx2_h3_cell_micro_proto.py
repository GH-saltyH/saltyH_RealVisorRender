"""H3 prototype: cell drops (simulated layer, r 0.25-2.5 mm) + baked micro-drop layer (overlap-cut atlas) on one visor patch.
(docs/RAINFX_V2_SPRAY_RAIN_REF.md section 29.10)
Panels: 1 scene without water | 2 composite | 3 colour-coded layers | 4 3x zoom of the composite.
- Scene: the game screenshot behind the visor (rainfx2_sheet_bg.png) at screen scale; the visor patch is 40 x 30 mm at
  ~50 um / px (800 x 600).
- Micro layer: the overlap-cut breath-figure atlas (rainfx2_overlap_cut_sim.py: growth + coalescence, border band B,
  max composite), read like the runtime at scale s (octave), each micro drop shown when its rank < local coverage
  (haze amount x wipe). Wiped by every cell drop's N2 halo (clean to r + 0.1, 0 at 1.5 r + 0.4 mm) and along the paths
  of the moving drops.
- Cell drops: SZ2-like size mix (fragment law, X^-1.88), cap height with gravity flattening above the capillary length,
  outline noise, a downward sag; three moving drops elongated along their path.
- Shading for both layers: CSP windscreen (interior refracts the scene by ~0.3 screen x normal at a size-dependent mip,
  steep rim = environment by world direction x0.7, reflection (1 - nz)^3).
Usage: python rainfx2_h3_cell_micro_proto.py OUTDIR [scale B]"""
import numpy as np, cv2, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
SCALE = float(sys.argv[2]) if len(sys.argv) > 2 else 0.6
BORD = float(sys.argv[3]) if len(sys.argv) > 3 else 0.25
src = open(os.path.join(HERE, 'rainfx2_overlap_cut_sim.py'), encoding='utf-8').read()
exec(src[:src.index('\nS = 360')])                              # pos, rad, noise, bake(), T
rng2 = np.random.default_rng(5)

# ---------------- micro atlas (periodic 12.8 mm tile) ----------------
APX = 0.0125
sh = np.array([[i * T, j * T] for i in (-1, 0, 1) for j in (-1, 0, 1)], float)
pos0, rad0, noi0 = pos, rad, noise
pos = (pos0[None] + sh[:, None]).reshape(-1, 2); rad = np.tile(rad0, 9); noise = np.tile(noi0, (9, 1))
AH, AID = bake(0.0, 0.0, T, APX, BORD)
AID = np.where(AID >= 0, AID % len(rad0), -1)
gyA = (np.roll(AH, -1, 0) - np.roll(AH, 1, 0)) / (2 * APX); gxA = (np.roll(AH, -1, 1) - np.roll(AH, 1, 1)) / (2 * APX)
ARANK = np.where(AID >= 0, (np.sin(AID * 12.9898 + 4.1) * 43758.5453) % 1.0, 2.0).astype(np.float32)

# ---------------- screen / visor patch ----------------
PX, WV, HV, SS = 0.05, 800, 600, 2                             # mm / px, patch px, shading supersample
bgsrc = cv2.imread(os.path.join(HERE, 'rainfx2_sheet_bg.png')).astype(np.float32) / 255
SCR = cv2.resize(bgsrc, (1920 * SS, 1200 * SS), interpolation=cv2.INTER_CUBIC)       # the screen
OX, OY = 560 * SS, 260 * SS                                    # patch origin on the screen (horizon / barrier / car)
REFR = 0.3 * 1080 * SS
MIPS = [SCR] + [cv2.GaussianBlur(SCR, (0, 0), s) for s in (2 * SS, 5 * SS, 10 * SS)]
sky, ground = np.array([0.86, 0.86, 0.84], np.float32), np.array([0.20, 0.22, 0.20], np.float32)
H_, W_ = HV * SS, WV * SS
yy, xx = (np.mgrid[0:H_, 0:W_].astype(np.float32) + 0.5) * (PX / SS)
scene = SCR[OY:OY + H_, OX:OX + W_]

def seg_dist(a, b):
    ab = b - a; t = np.clip(((xx - a[0]) * ab[0] + (yy - a[1]) * ab[1]) / max(ab @ ab, 1e-9), 0, 1)
    return np.hypot(xx - (a[0] + ab[0] * t), yy - (a[1] + ab[1] * t))

def halo_w(d, r, k=0.5, hin=0.1, hout=0.4):
    s = np.clip((d - r - hin) / (r * (1 + k) + hout - r - hin), 0, 1)
    return 1 - s * s * (3 - 2 * s)

# ---------------- cell drops ----------------
def frag_r(n):                                                 # radius from the fragment law (0.55 mm x X), 0.3-2.5 mm
    a, lo, hi = 0.88, 0.35, 3.0
    u = rng2.random(n); X = (lo ** -a + u * (hi ** -a - lo ** -a)) ** (-1 / a)
    return np.clip(0.55 * X * np.exp(rng2.normal(0, 0.15, n)), 0.0, 2.5)
L, Hmm = WV * PX, HV * PX
n_still = 40
cells = [dict(c=np.array([18.0, 8.0]), r=2.3, a=np.array([18.0, 8.0]), mov=False),
         dict(c=np.array([31.0, 21.0]), r=1.9, a=np.array([31.0, 21.0]), mov=False)]
tries = 0
while len(cells) < n_still + 2 and tries < 5000:
    tries += 1
    r = frag_r(1)[0]; c = np.array([rng2.uniform(0, L), rng2.uniform(0, Hmm)])
    if r < 0.3: continue                                     # below the cell drawing size: micro layer
    if all(np.hypot(*(c - d['c'])) > (r + d['r']) * 1.25 for d in cells):
        cells.append(dict(c=c, r=r, a=c.copy(), mov=False))
for (x0, y0, x1, y1, r) in ((6.0, 2.0, 9.5, 22.0, 1.3), (27.0, 4.0, 25.0, 17.0, 0.9), (35.0, 9.0, 36.5, 27.5, 1.7)):
    cells.append(dict(c=np.array([x1, y1]), r=r, a=np.array([x0, y0]), mov=True))

Hc = np.zeros((H_, W_), np.float32); CID = np.full((H_, W_), -1, np.int32)
wipe = np.zeros((H_, W_), np.float32)
for i, d in enumerate(cells):
    r, c = d['r'], d['c']
    wipe = np.maximum(wipe, halo_w(seg_dist(d['a'], c), r * (0.8 if d['mov'] else 1.0)))
    dx, dy = xx - c[0], yy - c[1]
    if d['mov']:                                               # elongated along the motion (head ahead, tail behind)
        m = (c - d['a']) / np.hypot(*(c - d['a']))
        u = dx * m[0] + dy * m[1]; v = -dx * m[1] + dy * m[0]
        dx, dy = u / 1.45, v / 0.8
    else:
        dy = dy / (1.0 + 0.12 * min(r / 1.5, 1.0)) - 0.08 * r   # gravity sag: longer, centre of mass low
    th = np.arctan2(dy, dx); k = rng2.normal(0, 1, 4)
    rim = 1 + 0.06 * (k[0] * np.cos(2 * th + k[1]) + k[2] * np.cos(3 * th + k[3]))
    rho = np.hypot(dx, dy) / (r * rim)
    hk = 0.75 / (1 + (r / 2.7) ** 2)                            # flatter above the capillary length
    cap = (r * hk * np.sqrt(np.clip(1 - rho * rho, 0, 1)) ** 0.7).astype(np.float32)
    win = cap > Hc
    Hc = np.where(win, cap, Hc); CID = np.where(win & (cap > 0), i, CID)

# ---------------- micro layer sampled at scale s ----------------
u = ((xx / SCALE) % T / APX).astype(np.float32); v = ((yy / SCALE) % T / APX).astype(np.float32)
smp = lambda a: cv2.remap(a.astype(np.float32), u, v, cv2.INTER_LINEAR, borderMode=cv2.BORDER_WRAP)
smpN = lambda a: cv2.remap(a.astype(np.float32), u, v, cv2.INTER_NEAREST, borderMode=cv2.BORDER_WRAP)
mgx, mgy = smp(gxA) * 1.0, smp(gyA) * 1.0                       # slopes are scale-free (self-similar)
mH, mRank = smp(AH) * SCALE, smpN(ARANK)
nz_ = cv2.resize(rng2.random((6, 8)).astype(np.float32), (W_, H_), interpolation=cv2.INTER_CUBIC)
haze = np.clip(0.55 + 0.45 * nz_ + 0.25 * (yy / Hmm - 0.5), 0, 1)   # haze amount: patchy, more low on the visor
phi = haze * (1 - wipe)
mVis = np.clip((phi - mRank) / 0.08 + 0.5, 0, 1) * (mH > 1e-5)   # rank threshold, soft (no pops)

def shade(gx, gy, mip_idx, cov, refr=REFR):
    nx, ny = -gx, -gy
    l = np.sqrt(1 + nx * nx + ny * ny); nx, ny, nz = nx / l, ny / l, 1 / l
    mx = (np.arange(W_)[None, :] + OX - nx * refr).astype(np.float32)
    my = (np.arange(H_)[:, None] + OY - ny * refr).astype(np.float32)
    mx = np.broadcast_to(mx, nx.shape).astype(np.float32); my = np.broadcast_to(my, nx.shape).astype(np.float32)
    scr = cv2.remap(MIPS[mip_idx], mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    up = np.clip(-ny * 1.6 + 0.5, 0, 1)[..., None]
    env = (sky * up + ground * (1 - up)) * 0.7
    wS = np.clip((nz - 0.3) * 10, 0, 1)[..., None]
    col = env * (1 - wS) + scr * wS + sky * (((1 - nz) ** 3) * np.clip(-ny, 0, 1) * 1.5)[..., None]
    return col, cov[..., None]

gyC, gxC = np.gradient(Hc, PX / SS)
cMicro, aMicro = shade(mgx, mgy, 2, mVis, 0.12 * 1080 * SS)   # micro lens: smaller net shift at its mip
cCell, aCell = shade(gxC, gyC, 1, (Hc > 1e-5).astype(np.float32))
comp = scene * (1 - aMicro) + cMicro * aMicro
comp = comp * (1 - aCell) + cCell * aCell
comp = cv2.resize(comp, (WV, HV), interpolation=cv2.INTER_AREA)
orig = cv2.resize(scene, (WV, HV), interpolation=cv2.INTER_AREA)

# ---------------- colour-coded ----------------
grey = cv2.cvtColor(cv2.cvtColor(scene, cv2.COLOR_BGR2GRAY), cv2.COLOR_GRAY2BGR) * 0.45
code = grey.copy()
code = code * (1 - 0.8 * mVis[..., None]) + np.array([0.95, 0.85, 0.2], np.float32) * (0.8 * mVis[..., None])   # micro: cyan (BGR)
hz = ((wipe > 0.02) & (wipe < 0.98))[..., None]
code = np.where(hz, code * 0.5 + np.array([0.2, 0.75, 0.2], np.float32) * 0.5, code)                             # halo edge: green
classes = [(0.5, (0.2, 0.9, 1.0)), (1.0, (0.1, 0.55, 1.0)), (1.8, (0.15, 0.15, 0.95)), (9.0, (0.9, 0.3, 0.9))]
for i, d in enumerate(cells):
    col = next(np.array(cc, np.float32) for lim, cc in classes if d['r'] < lim)
    if d['mov']: col = np.array([1.0, 0.45, 0.2], np.float32)                                                 # moving: blue
    m = (CID == i)[..., None]
    code = np.where(m, col, code)
code = cv2.resize(code, (WV, HV), interpolation=cv2.INTER_AREA)

def label(img, lines, legend=None):
    img = (np.clip(img, 0, 1) * 255).astype(np.uint8).copy()
    cv2.rectangle(img, (0, 0), (WV, 8 + 16 * len(lines)), (0, 0, 0), -1)
    for k, t in enumerate(lines):
        cv2.putText(img, t, (6, 18 + 16 * k), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (255, 255, 255), 1, cv2.LINE_AA)
    if legend:
        y = HV - 10 - 18 * len(legend)
        cv2.rectangle(img, (0, y - 6), (330, HV), (0, 0, 0), -1)
        for k, (t, c) in enumerate(legend):
            cv2.rectangle(img, (8, y + 18 * k), (22, y + 18 * k + 12), tuple(int(255 * x) for x in c), -1)
            cv2.putText(img, t, (30, y + 18 * k + 11), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (255, 255, 255), 1, cv2.LINE_AA)
    cv2.rectangle(img, (WV - 110, HV - 16), (WV - 30, HV - 11), (255, 255, 255), -1)
    cv2.putText(img, '4 mm', (WV - 150, HV - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.42, (255, 255, 255), 1, cv2.LINE_AA)
    return img

rs = np.array([d['r'] for d in cells])
legend = [('micro layer (atlas, rank <= haze)', (0.95, 0.85, 0.2)), ('wipe halo edge', (0.2, 0.75, 0.2)),
          ('cell drop r < 0.5 mm', classes[0][1]), ('cell drop 0.5-1.0 mm', classes[1][1]),
          ('cell drop 1.0-1.8 mm', classes[2][1]), ('cell drop > 1.8 mm', classes[3][1]), ('moving cell drop', (1.0, 0.45, 0.2))]
p1 = label(orig, ['1 scene (no water)  40 x 30 mm visor patch, ~50 um / px'])
p2 = label(comp, ['2 composite: micro atlas x%.2f, B %.2f + %d cell drops (r %.2f-%.2f mm)' % (SCALE, BORD, len(cells), rs.min(), rs.max())])
p3 = label(code, ['3 layers colour-coded'], legend)
zx, zy, zw = 260, 180, 266
p4 = label(cv2.resize(comp[zy:zy + 200, zx:zx + zw], (WV, HV), interpolation=cv2.INTER_NEAREST),
           ['4 composite 3x zoom (game pixels kept)'])
cv2.imwrite(os.path.join(OUT, 'rainfx2_h3_cell_micro_proto.png'), np.vstack([np.hstack([p1, p2]), np.hstack([p3, p4])]))
print('cells', len(cells), 'r', np.round(np.sort(rs), 2))
