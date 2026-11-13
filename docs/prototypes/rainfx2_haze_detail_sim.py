"""H2 haze detail evaluation (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 28).
Renders a 24 x 24 mm visor patch at the game's pixel scale (~50 um / px: visor ~50 mm from the eye, 60 deg / 1080 px)
behind which a scene is seen, with the haze drawn as
  A  flat   : current H1 -- phi(G) uniform scatter (G smooth)
  B  H2a    : G built from discrete deposition patches (spray / rain impact fragment clusters, Poisson in space), phi(G)
  C  H2b    : A + baked breath-figure micro grain (polydisperse caps, rank threshold -> coverage = phi, per-cap shading)
  D  H2a+b  : both
for an unsaturated (mean phi 0.30) and a saturated (0.55) state, each with one drop path wiped with the N2 halo.
Scatter composite as in visor.hlsl: out = bg (1 - k phi) + amb k phi, amb = blurred scene toward the sky veil."""
import numpy as np, cv2, os, sys
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
rng = np.random.default_rng(3)
PX = 0.05            # mm per display pixel
SS = 4               # supersampling of the micro-grain raster (12.5 um)
W = 480              # display pixels (24 mm)
L = W * PX
PHIMAX, A_MM, SHK = 0.55, 0.015, 1.0
bg = cv2.imread(os.path.join(os.path.dirname(__file__), 'rainfx2_sheet_bg.png'))[30:170, 250:390].astype(np.float32) / 255
bg = cv2.resize(bg, (W, W), interpolation=cv2.INTER_CUBIC)
veil = np.array([0.80, 0.80, 0.78], np.float32)
amb = 0.55 * cv2.GaussianBlur(bg, (0, 0), 25) + 0.45 * veil

def phi_of(h): return np.minimum(1 - np.exp(-np.pi * h / (SHK * A_MM)), PHIMAX)
def h_for(phi): return -np.log(1 - phi) * SHK * A_MM / np.pi

yy, xx = np.mgrid[0:W, 0:W].astype(np.float32) * PX + PX / 2
def wipe_weight(r=0.6, k=0.5, hin=0.1, hout=0.4):          # one drop path (N2 halo), diagonal
    a, b = np.array([3.0, 20.0]), np.array([19.0, 6.0])
    ab = b - a; t = np.clip(((xx - a[0]) * ab[0] + (yy - a[1]) * ab[1]) / (ab @ ab), 0, 1)
    d = np.hypot(xx - (a[0] + ab[0] * t), yy - (a[1] + ab[1] * t))
    rin, rout = r + hin, r * (1 + k) + hout
    s = np.clip((d - rin) / (rout - rin), 0, 1)
    return 1 - s * s * (3 - 2 * s), d

def patch_field(mean_h):
    """H2a: Poisson deposition patches. A spray / rain impact leaves its sub-visible fragments in a cluster
    (crown / fingering ring) of radius ~ 0.4-2 mm; volume per patch from the SP1 haze share of one impact."""
    vP = 3.0e-3                                   # mm^3 of sub-visible water per patch (0.2-0.6 mm spray droplet, fine share)
    n = rng.poisson(mean_h * (L + 8) ** 2 / vP)
    g = np.zeros((W, W), np.float32)
    cx, cy = rng.uniform(-4, L + 4, n), rng.uniform(-4, L + 4, n)
    R = np.exp(rng.normal(np.log(1.0), 0.45, n))
    for x0, y0, r in zip(cx, cy, R):              # ring-ish cluster: gaussian blob + ring
        i0, i1 = int(max((y0 - 3 * r) / PX, 0)), int(min((y0 + 3 * r) / PX, W))
        j0, j1 = int(max((x0 - 3 * r) / PX, 0)), int(min((x0 + 3 * r) / PX, W))
        if i0 >= i1 or j0 >= j1: continue
        d = np.hypot(xx[i0:i1, j0:j1] - x0, yy[i0:i1, j0:j1] - y0) / r
        f = 0.5 * np.exp(-d * d) + 0.5 * np.exp(-((d - 1.0) / 0.3) ** 2)
        g[i0:i1, j0:j1] += f
    g *= mean_h / g.mean()
    return g

def grain_texture():
    """H2b: baked breath figure (saturated, phi 0.55): polydisperse caps (lognormal radius, median 15 um, tail to
    80 um -- hazeRMaxMM), each with a rank u (order in which it appears as phi rises) and a shade (cap tilt / glint)."""
    S = W * SS; px = PX / SS
    rank = np.full((S, S), 2.0, np.float32); shade = np.zeros((S, S), np.float32)
    meanA = np.pi * 0.015 ** 2 * np.exp(2 * 0.5 ** 2)
    n = int(-np.log(1 - PHIMAX) / meanA * L * L)
    rad = np.clip(np.exp(rng.normal(np.log(0.015), 0.5, n)), 0.006, 0.08)
    order = np.argsort(rad)                       # small first, large on top
    cx, cy = rng.uniform(0, L, n), rng.uniform(0, L, n)
    u = rng.random(n).astype(np.float32)
    sh = (0.9 + 0.2 * rng.random(n)).astype(np.float32)
    for i in order:
        c = (int(cx[i] / px), int(cy[i] / px)); r = max(int(round(rad[i] / px)), 1)
        cv2.circle(rank, c, r, float(u[i]), -1)
        cv2.circle(shade, c, r, float(sh[i] * (1.0 + 0.3 * (rad[i] > 0.04))), -1)   # large caps catch the sky
    return rank, shade

def render(phi, grain=None):
    k = 1.0
    if grain is None:
        a = (k * phi)[..., None]
        return bg * (1 - a) + amb * a
    rank, shade = grain
    phiS = cv2.resize(phi, (W * SS, W * SS), interpolation=cv2.INTER_LINEAR)
    vis = np.clip((phiS / PHIMAX - rank) / 0.08 + 0.5, 0, 1)   # soft rank threshold: caps fade in / out (no pops)
    cov = vis * (rank < 1.5)
    sc = cov * shade
    covD = cv2.resize(cov, (W, W), interpolation=cv2.INTER_AREA)
    scD = cv2.resize(sc, (W, W), interpolation=cv2.INTER_AREA)
    # mean coverage of the raster at full rank = PHIMAX (Poisson) -> covD ~ phi in expectation
    return bg * (1 - k * covD[..., None]) + amb * (k * scD[..., None])

def label(img, t):
    img = (np.clip(img, 0, 1) * 255).astype(np.uint8).copy()
    cv2.rectangle(img, (0, 0), (W, 22), (0, 0, 0), -1)
    cv2.putText(img, t, (6, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.48, (255, 255, 255), 1, cv2.LINE_AA)
    return img

grain = grain_texture()
wipe, _ = wipe_weight()
def defocus(img, dmm):                            # thin-lens blur disc on the visor plane (aperture x (1 - z_v / z_f))
    r = int(round(dmm / 2 / PX)); k = np.zeros((2 * r + 1, 2 * r + 1), np.float32)
    cv2.circle(k, (r, r), r, 1.0, -1); k /= k.sum()
    return cv2.filter2D(img, -1, k)
rows = []
for target, blur in ((0.30, 0.0), (0.30, 1.5), (0.55, 0.0)):
    hm = h_for(min(target, 0.549)) * (1.0 if target < 0.5 else 1.6)
    flat = np.full((W, W), hm, np.float32) * (1 - wipe)
    pat = patch_field(hm) * (1 - wipe)
    ims = [render(phi_of(flat)), render(phi_of(pat)), render(phi_of(flat), grain), render(phi_of(pat), grain)]
    if blur > 0: ims = [defocus(im, blur) for im in ims]
    tag = 'phi %.2f %s' % (target, 'defocus 1.5 mm' if blur else 'pinhole')
    names = ['A flat (now)', 'B H2a deposition patches', 'C H2b micro grain', 'D H2a + H2b']
    rows.append(np.hstack([label(im, '%s | %s' % (nm, tag)) for im, nm in zip(ims, names)]))
cv2.imwrite(os.path.join(OUT, 'rainfx2_h2_haze_detail.png'), np.vstack(rows))
print('ok')
