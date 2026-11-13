"""H3 micro layer vs spray strength over time (docs/RAINFX_V2_H3_ATLAS_SPEC.md section 3 / 4, 2026-11-12).
Runs the spec's haze model on a 12 x 12 mm visor patch and renders it with the spec's runtime rules, for three spray
strengths (rows) at five times (columns); a drop wipes a diagonal path (N2 halo) at t = 6 s.
Haze model (units of G_sat = saturation water depth of the finest caps), per pixel, supply patchy (impact clusters):
    dG_f/dt = S M(x) - G_f / tau_c - k_f G_f            (fresh fine water: white veil)
    dG_c/dt = G_f / tau_c - k_c G_c                     (coarsened water: micro-drop clusters)
    G_c > G_top (pieces reach a_max) -> the excess leaves as cell drops (counted, not drawn here)
Runtime: coverage phi(G_c) up to phi_max at G_sat; above, a_eff = a_min G_c / G_sat (self-similar coarsening) chooses
the atlas octave (scale s = a_eff / atlas piece p50), mip from the pixel footprint; resolved fraction
w_det = clamp(log2(a_eff / R_res) + 0.5) (R_res 25 um = half a 1080p pixel on the visor); drawn pieces: rank < phi /
phi_max (soft); unresolved part = white scatter; G_f adds its own veil. CSP windscreen shading for the pieces.
Usage: python rainfx2_h3_spray_coverage_sim.py OUTDIR"""
import os, sys
import numpy as np, cv2
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'tools'))
from rainfx2_bake_microdrops import bake, mips
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
rng = np.random.default_rng(4)

# ---------- atlas (spec defaults: rmax = a_max 0.3, alpha 1.5, D 2.2, zmix 0.5, gaps 50 %) ----------
res = bake(dict(size=1024))
TX, TN = res['prm']['texel'], 1024
T = TX * TN
P50 = res['stats']['pieceR_p50']
chain = mips(res)                                            # [(nx, ny, h, cov, rank)] per mip

# ---------- patch / scene ----------
W, PX = 240, 0.05                                            # 12 mm at ~50 um / px
yy, xx = (np.mgrid[0:W, 0:W].astype(np.float32) + 0.5) * PX
src = cv2.imread(os.path.join(HERE, 'rainfx2_sheet_bg.png')).astype(np.float32) / 255
SCR = cv2.resize(src, (1920, 1200), interpolation=cv2.INTER_CUBIC)
OX, OY = 760, 300
scene = SCR[OY:OY + W, OX:OX + W]
SCRB = cv2.GaussianBlur(SCR, (0, 0), 6)
amb = 0.55 * cv2.GaussianBlur(SCR, (0, 0), 40)[OY:OY + W, OX:OX + W] + 0.45 * np.array([0.82, 0.82, 0.80], np.float32)
SKY, ROAD = np.array([0.86, 0.86, 0.84], np.float32), np.array([0.2, 0.22, 0.2], np.float32)

# ---------- haze model ----------
PHIMAX, A_MIN, R_RES, TAU_C, K_F, K_C = 0.55, 0.015, 0.025, 1.5, 1 / 3.0, 1 / 30.0
G_TOP = 0.3 * P50 / res['stats']['pieceR_max'] / A_MIN     # top octave: largest piece = a_max
M = cv2.resize(rng.random((5, 5)).astype(np.float32), (W, W), interpolation=cv2.INTER_CUBIC)
M = np.clip(0.45 + 1.1 * M, 0.3, 1.6)                       # patchy supply (impact clusters / exposure)
a, b = np.array([1.0, 11.0]), np.array([10.0, 1.5])
ab = b - a; t = np.clip(((xx - a[0]) * ab[0] + (yy - a[1]) * ab[1]) / (ab @ ab), 0, 1)
dpath = np.hypot(xx - (a[0] + ab[0] * t), yy - (a[1] + ab[1] * t))
r_w = 0.9
s_ = np.clip((dpath - r_w - 0.1) / (r_w * 1.5 + 0.4 - r_w - 0.1), 0, 1)
WIPE = 1 - s_ * s_ * (3 - 2 * s_)


def run(S, times, tw=6.0, dt=0.05):
    Gf = np.zeros((W, W), np.float32); Gc = np.zeros((W, W), np.float32); births = 0.0; out = {}; tt = 0.0
    for tk in times:
        while tt < tk - 1e-9:
            Gf += dt * (S * M - Gf / TAU_C - K_F * Gf)
            Gc += dt * (Gf / TAU_C - K_C * Gc)
            births += float(np.maximum(Gc - G_TOP, 0).sum())
            Gc = np.minimum(Gc, G_TOP)
            tt += dt
            if abs(tt - tw) < dt / 2:
                Gf *= 1 - WIPE; Gc *= 1 - WIPE
        out[tk] = (Gf.copy(), Gc.copy(), births)
    return out


def sample(level_s, field, bias=0.0):
    lod = np.log2(max(PX / (TX * level_s), 1e-6)) + bias
    m0 = int(np.clip(np.floor(lod), 0, len(chain) - 1)); m1 = min(m0 + 1, len(chain) - 1); f = float(np.clip(lod - m0, 0, 1))
    def at(m, k, interp):
        arr = chain[m][k]; n = arr.shape[0]; sc = n / TN
        u = ((xx / level_s) % T / TX * sc - 0.5).astype(np.float32); v = ((yy / level_s) % T / TX * sc - 0.5).astype(np.float32)
        return cv2.remap(arr.astype(np.float32), u, v, interp, borderMode=cv2.BORDER_WRAP)
    if field == 'rank':
        return at(m0, 4, cv2.INTER_NEAREST)
    return (1 - f) * at(m0, field, cv2.INTER_LINEAR) + f * at(m1, field, cv2.INTER_LINEAR)


LEVELS = [2.0 ** l for l in np.arange(-3.0, 0.01, 0.5)]
ATL = [(s, sample(s, 0), sample(s, 1), sample(s, 3), sample(s, 'rank')) for s in LEVELS]


def render(Gf, Gc, exclusive=True):
    phi = np.minimum(1 - np.exp(-Gc * -np.log(1 - PHIMAX)), PHIMAX)
    aeff = A_MIN * np.maximum(Gc, 1.0)
    sc = np.clip(aeff / P50, LEVELS[0], LEVELS[-1])
    L = np.log2(sc)
    nx = np.zeros((W, W), np.float32); ny = np.zeros_like(nx); vis = np.zeros_like(nx)
    for i, (s, ax, ay, ac, ar) in enumerate(ATL):
        w = np.clip(1 - np.abs(L - np.log2(s)) / 0.5, 0, 1)
        if w.max() <= 0: continue
        v = np.clip((phi / PHIMAX - ar) / 0.08 + 0.5, 0, 1) * ac
        nx += w * ax * v; ny += w * ay * v; vis += w * v
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    mx = (np.arange(W)[None, :] + OX - nx * 0.3 * 1080).astype(np.float32)
    my = (np.arange(W)[:, None] + OY - ny * 0.3 * 1080).astype(np.float32)
    scr = cv2.remap(SCRB, np.broadcast_to(mx, nx.shape).copy(), np.broadcast_to(my, nx.shape).copy(), cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    up = np.clip(-ny * 1.6 + 0.5, 0, 1)[..., None]
    env = (SKY * up + ROAD * (1 - up)) * 0.7
    wS = np.clip((nz - 0.3) * 10, 0, 1)[..., None]
    cdrop = env * (1 - wS) + scr * wS + SKY * ((1 - nz) ** 3 * np.clip(-ny, 0, 1) * 1.5)[..., None]
    wdet = np.clip(np.log2(aeff / R_RES) + 0.5, 0, 1)[..., None]
    D = wdet * vis[..., None]                                 # resolved drop pieces
    U = (1 - wdet) * phi[..., None]                           # unresolved caps: white scatter
    phf = np.minimum(1 - np.exp(-Gf * -np.log(1 - PHIMAX)), PHIMAX)[..., None]
    if not exclusive:                                         # first version: veil laid over the drops too
        out = scene * (1 - D) + cdrop * D
        out = out * (1 - U) + amb * U
        return out * (1 - phf) + amb * phf
    # EXCLUSIVE (user 2026-11-12): a drop has taken up the micro caps under it -> no veil on a piece; the veil lives in
    # the gaps only, thinned by the local piece density (a zone that has turned into drops is clear: the pieces' rims
    # take up the fresh fine water that lands next to them -- the depletion zone of a breath figure)
    Dloc = cv2.blur(D[..., 0], (5, 5))[..., None]             # ~0.25 mm neighbourhood
    V = 1 - (1 - U) * (1 - phf)                               # gap veil (unresolved + fresh fine)
    V = V * np.clip(1 - 1.3 * Dloc, 0, 1)
    gap = scene * (1 - V) + amb * V
    return gap * (1 - D) + cdrop * D


OCT = [(l, sample(2.0 ** l, 0, -1), sample(2.0 ** l, 1, -1), sample(2.0 ** l, 3, -1), sample(2.0 ** l, 'rank'))
       for l in range(-4, 2)]


def render_crisp(Gf, Gc):
    """H3-2b (visor 2026-11-13): no alpha in the piece path -- octave mix and w_det through the rank, coverage thresholded
    at 0.5 (one mip sharper), coarse octave on top; veil only in the gaps (exclusive rule)."""
    phi = np.minimum(1 - np.exp(-Gc * -np.log(1 - PHIMAX)), PHIMAX)
    rel = phi / PHIMAX
    aeff = A_MIN * np.maximum(Gc, 1.0)
    L = np.clip(np.log2(aeff / P50), -4, 0); L0 = np.floor(L); fL = L - L0
    wdet = np.clip(np.log2(aeff / R_RES) + 0.5, 0, 1)
    D = np.zeros((W, W), np.float32); gx = np.zeros_like(D); gy = np.zeros_like(D); cl = np.zeros_like(D)
    for k in (1, 0):
        Lk = L0 + k; wk = fL if k == 1 else 1 - fL
        for l, ax, ay, ac, ar in OCT:
            m = Lk == l
            if not m.any(): continue
            relK = rel * wdet * wk
            vis = np.clip((relK - ar) / 0.03 + 0.5, 0, 1) * np.clip((ac - 0.5) * 4 + 0.5, 0, 1) * m
            add = vis * (1 - D)
            nz = np.sqrt(np.clip(1 - ax * ax - ay * ay, 0, 1))
            gx += add * (-ax / np.maximum(nz, 0.15)); gy += add * (-ay / np.maximum(nz, 0.15))
            D += add; cl += m * wk * ac * rel * wdet
    gx /= np.maximum(D, 1e-4); gy /= np.maximum(D, 1e-4)
    l = np.sqrt(1 + gx * gx + gy * gy); nx, ny = -gx / l, -gy / l; nz = 1 / l
    mx = (np.arange(W)[None, :] + OX - nx * 0.3 * 1080).astype(np.float32)
    my = (np.arange(W)[:, None] + OY - ny * 0.3 * 1080).astype(np.float32)
    scr = cv2.remap(SCRB, np.broadcast_to(mx, nx.shape).copy(), np.broadcast_to(my, nx.shape).copy(), cv2.INTER_LINEAR, borderMode=cv2.BORDER_REFLECT)
    up = np.clip(-ny * 1.6 + 0.5, 0, 1)[..., None]
    env = (SKY * up + ROAD * (1 - up)) * 0.7
    wS = np.clip((nz - 0.3) * 10, 0, 1)[..., None]
    cdrop = env * (1 - wS) + scr * wS + SKY * ((1 - nz) ** 3 * np.clip(-ny, 0, 1) * 1.5)[..., None]
    phf = np.minimum(1 - np.exp(-Gf * -np.log(1 - PHIMAX)), PHIMAX)
    V = 1 - (1 - (1 - wdet) * phi) * (1 - phf)
    V = (V * np.clip(1 - 1.3 * cl, 0, 1))[..., None]
    gap = scene * (1 - V) + amb * V
    D = D[..., None]
    return gap * (1 - D) + cdrop * D


def label(img, lines):
    img = (np.clip(img, 0, 1) * 255).astype(np.uint8).copy()
    cv2.rectangle(img, (0, 0), (W, 6 + 12 * len(lines)), (0, 0, 0), -1)
    for k, s in enumerate(lines):
        cv2.putText(img, s, (3, 13 + 12 * k), cv2.FONT_HERSHEY_SIMPLEX, 0.33, (255, 255, 255), 1, cv2.LINE_AA)
    return img


TIMES = [1.0, 3.0, 5.9, 7.0, 12.0]
rows = []
for S, name in ((0.3, 'light spray'), (1.0, 'medium spray'), (3.0, 'heavy spray')):
    o = run(S, TIMES)
    tiles = [label(scene, ['%s  S = %.1f G_sat/s' % (name, S), 'no water'])]
    for tk in TIMES:
        Gf, Gc, bth = o[tk]
        ae = A_MIN * max(float(np.median(Gc)), 1.0)
        tiles.append(label(render(Gf, Gc), ['t %.1f s%s' % (tk, '  (wiped at 6 s)' if tk > 6 else ''),
                                            'G_f %.2f G_c %.2f a_eff %.3f mm' % (float(np.median(Gf)), float(np.median(Gc)), ae),
                                            'to cell drops %.2f mm3' % (bth * (PX ** 2) * 0.0038)]))
    rows.append(np.hstack(tiles))
cv2.imwrite(os.path.join(OUT, 'rainfx2_h3_spray_coverage.png'), np.vstack(rows))
# before / after (2x, game pixels kept): medium and heavy at 5.9 s
cmp_tiles = []
for S, name in ((1.0, 'medium'), (3.0, 'heavy')):
    Gf, Gc, _ = run(S, [5.9])[5.9]
    z = lambda im: cv2.resize(im[40:200, 40:200], (320, 320), interpolation=cv2.INTER_NEAREST)
    for ex, tag in ((False, 'before: veil over drops'), (True, 'after: drops clear, veil in gaps')):
        im = z(render(Gf, Gc, ex))
        im = (np.clip(im, 0, 1) * 255).astype(np.uint8).copy()
        cv2.rectangle(im, (0, 0), (320, 18), (0, 0, 0), -1)
        cv2.putText(im, '%s 5.9 s  %s' % (name, tag), (4, 13), cv2.FONT_HERSHEY_SIMPLEX, 0.38, (255, 255, 255), 1, cv2.LINE_AA)
        cmp_tiles.append(im)
cv2.imwrite(os.path.join(OUT, 'rainfx2_h3_exclusive_veil.png'), np.hstack(cmp_tiles))
# H3-2b old (alpha pieces, F power-cut atlas look) vs new (crisp pieces), same haze states, 1.5x nearest
rows2 = []
for S, tk, name in ((0.3, 12.0, 'light 12 s'), (1.0, 3.0, 'medium 3 s'), (1.0, 5.9, 'medium 5.9 s'), (3.0, 3.0, 'heavy 3 s')):
    Gf, Gc, _ = run(S, [tk])[tk]
    z = lambda im: cv2.resize(im, (360, 360), interpolation=cv2.INTER_NEAREST)
    a1 = (np.clip(z(render(Gf, Gc, True)), 0, 1) * 255).astype(np.uint8).copy()
    a2 = (np.clip(z(render_crisp(Gf, Gc)), 0, 1) * 255).astype(np.uint8).copy()
    for im, tag in ((a1, 'before: alpha pieces'), (a2, 'after: crisp layered pieces')):
        cv2.rectangle(im, (0, 0), (360, 18), (0, 0, 0), -1)
        cv2.putText(im, '%s  %s' % (name, tag), (4, 13), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (255, 255, 255), 1, cv2.LINE_AA)
    rows2.append(np.hstack([a1, a2]))
cv2.imwrite(os.path.join(OUT, 'rainfx2_h3_crisp_compare.png'), np.vstack([np.hstack(rows2[:2]), np.hstack(rows2[2:])]))
print('atlas', res['stats'], 'G_top', G_TOP)
