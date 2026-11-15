"""Unified thin-water + drainage prototype (docs/RAINFX_V2_FILM_UNIFY_RESEARCH.md sections 2 / 7). 60 x 40 mm visor patch,
field texel 0.59 mm (the game field), 60 fps. One water layer h for every flat water (lamella patches, sheets, trail lines);
caps (drops / beads) are entities. Rules (one surface: receding angle theta_r, advancing theta_a = theta_r + 20 deg):
  scene    : controlled test (the supply model is not under test): at t = 0 three sheet patches (W 4 / 10 / 20 mm,
             h 0.06-0.15 mm) and 14 running drops (r 0.3-1.0 mm); a FED band (left 15 mm, spray landing on water at
             q 1 mm/s = an extreme spray plume) and rain residue caps born at the impact rate. Water thinner than 1.5 um is
             micro water (-> haze 'to haze');
  mobility : a connected water body moves as a whole when its length along the forcing >= L_c = gamma dcos / (tau + rho g h)
             (Furmidge), at v(h) = tau h / 2 mu + rho g_t h^2 / 3 mu, mass-conserving forward splat (any Courant number);
  drainage : water carried past the visor edge leaves; across the flow it drifts toward the thicker neighbour (gathering);
  dewetting: every film edge recedes at V_d = (gamma / mu) theta_r^3 / (9 ln(W / lambda)) (Cox-Voinov), the rim collects
             the water; a body shrunk to <= 3 texels becomes a cap (bead / drop entity) -- mass conserving;
  drops    : a cap on film water joins it; caps run at P.speed (physics.lua table) when above the depin size and leave their trail water (r2TrailRule)
             into h as a line; the same dewetting turns it into beads.
'now' row (approximate current build): isolated bodies pinned below 0.3 mm, transport capped at 0.068 m/s (Courant 0.24 x 8
substeps), unconnected film < 0.1 mm decays exp(-3 t) (lost), trail lines pinned (drawn as rods, evaporation only).
Usage: python rainfx2_film_drain_proto.py OUT_DIR [kmh]"""
import sys, os, math
import numpy as np, cv2
from scipy import ndimage
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1]; KMH = float(sys.argv[2]) if len(sys.argv) > 2 else 240
DX, NX, NY, DT = 0.59, 102, 68, 1 / 60
PIX = 0.1; W, H = int(NX * DX / PIX), int(NY * DX / PIX)
shapeK = 1.0076; GAM, MU = 0.072, 1e-3
src = cv2.imread(os.path.join(HERE, 'rainfx2_sheet_bg.png')).astype(np.float32) / 255
SCR = cv2.resize(src, (int(src.shape[1] * 1080 / src.shape[0]), 1080), interpolation=cv2.INTER_CUBIC)
scene = SCR[250:250 + H, 760:760 + W].copy(); blur = cv2.GaussianBlur(SCR, (0, 0), 20)[250:250 + H, 760:760 + W]
yy, xx = (np.mgrid[0:H, 0:W].astype(np.float32) + 0.5) * PIX
U = KMH / 3.6; TAU = 0.5 * 1.2 * 0.005 * U * U
GT = 9.81 * 0.5                                         # gravity along the face (30 deg), +y = down the screen
FLOW_UP = U > 5                                          # air drives water up (-y); at rest gravity down (+y)
SPEED = {0.1: 0.02, 0.2: 0.087, 0.3: 0.159, 0.5: 0.347, 1.0: 0.774} if KMH > 200 else {0.5: 0.0, 1.0: 0.0, 1.5: 0.045, 2.0: 0.08}
def vDrop(r):
    ks = sorted(SPEED)
    if r <= ks[0]: return SPEED[ks[0]] * r / ks[0]
    for a, b in zip(ks, ks[1:]):
        if r <= b: return SPEED[a] + (SPEED[b] - SPEED[a]) * (r - a) / (b - a)
    return SPEED[ks[-1]]
def trailRule(r, v, thr):
    th = math.radians(thr); caS = th ** 3 / (9 * math.log(max(r * 1e6, 10))); ca = v / 72; s = ca / caS
    if s <= 1: return 0.0, 0.0
    hw = 0.25 * r * math.sqrt(1 - 1 / s); return min(5 * r * ca ** (2 / 3), 0.225 * hw), hw
def run(thr, mode, tShots, seed=3):
    rng = np.random.default_rng(seed)
    h = np.zeros((NY, NX)); drops = []; rods = []
    th = math.radians(thr); dcos = math.cos(th) - math.cos(th + math.radians(20))
    t, shots, k = 0.0, {}, 0
    ledger = dict(supplied=0.0, drained=0.0, lost=0.0)
    gy0, gx0 = np.mgrid[0:NY, 0:NX]
    for (cx, cy, Wp, Lp, hp) in ((40, 30, 4, 6, 0.06), (24, 24, 10, 8, 0.1), (46, 14, 20, 10, 0.15)):
        m = (np.abs((gx0 + 0.5) * DX - cx) < Wp / 2) & (np.abs((gy0 + 0.5) * DX - cy) < Lp / 2)
        h[m] += hp; ledger['supplied'] += hp * m.sum() * DX * DX
    for _ in range(14):
        r0 = rng.uniform(0.3, 1.0); drops.append([rng.uniform(18, 58), rng.uniform(4, 38), shapeK * r0 ** 3, rng.uniform(-0.3, 0.3)])
        ledger['supplied'] += shapeK * r0 ** 3
    fedBand = (gx0 + 0.5) * DX < 15
    rateImp = (0.071 if KMH > 200 else 0.008) * NX * DX * NY * DX * DT        # Thunderstorm impacts / frame (front, x0.85)
    qSpray = 0.12 if KMH > 200 else 0.0                                         # mm/s on wetted texels (chase)
    vR = (U if KMH > 5 else 6.0) * 0.85
    while k <= int(max(tShots) / DT + 0.5):
        # --- supply: impacts (lamella + residue drop), spray on water
        for _ in range(rng.poisson(rateImp)):                                    # rain residue caps (one per impact)
            d = rng.exponential(0.8) + 0.3; V = math.pi / 6 * d ** 3
            Re, We = 1000 * vR * d, 13.89 * vR * vR * d
            K = math.sqrt(We) * Re ** 0.25; fRes = min((58 / K) ** 0.5, 1.0)
            vRes = V * fRes * 0.4
            if (vRes / shapeK) ** (1 / 3) >= 0.04:
                drops.append([rng.uniform(0, NX * DX), rng.uniform(0, NY * DX), vRes, rng.uniform(-0.3, 0.3)]); ledger['supplied'] += vRes
        add = np.where(fedBand, (1.0 if KMH > 5 else 0.2) * DT, 0.0)             # extreme spray plume (rest: crown runoff)
        h += add; ledger['supplied'] += add.sum() * DX * DX
        # --- mobility + transport
        lab, n = ndimage.label(h > 0.002)
        if n:
            idx = np.arange(1, n + 1)
            sl = ndimage.find_objects(lab)
            hMean = ndimage.mean(h, lab, idx)
            v = np.zeros_like(h)
            for i, s in enumerate(sl):
                Lx = (s[0].stop - s[0].start) * DX
                Lc = GAM * dcos / (TAU + 1000 * GT * hMean[i] * 1e-3) * 1000
                mobile = (Lx >= Lc) if mode == 'unified' else (hMean[i] >= 0.3 or (s[0].stop - s[0].start) * (s[1].stop - s[1].start) > 60)
                if mobile:
                    msk = lab[s] == i + 1
                    v[s][msk] = 0.5 * TAU * h[s][msk] + GT * h[s][msk] ** 2 / 3          # m/s (h mm)
            if mode == 'now': v = np.minimum(v, 0.068)
            dy = v * 1000 * DT / DX * (-1 if FLOW_UP else 1)
            ys, xs = np.nonzero(h > 0)
            ty = ys + dy[ys, xs]; tx = xs.astype(float)
            # gathering: drift across the flow toward the thicker neighbour (W1r)
            hl = np.roll(h, 1, 1); hr = np.roll(h, -1, 1)
            tx = tx + 0.3 * np.sign(hr - hl)[ys, xs] * (v[ys, xs] > 0)
            mass = h[ys, xs].copy()
            h2 = np.zeros_like(h)
            y0 = np.floor(ty).astype(int); fy = ty - y0; x0 = np.floor(tx).astype(int); fx = tx - x0
            for oy, wy in ((0, 1 - fy), (1, fy)):
                for ox, wx in ((0, 1 - fx), (1, fx)):
                    yy2, xx2 = y0 + oy, x0 + ox; w = wy * wx * mass
                    inside = (yy2 >= 0) & (yy2 < NY) & (xx2 >= 0) & (xx2 < NX)
                    np.add.at(h2, (yy2[inside], xx2[inside]), w[inside])
                    ledger['drained'] += w[~inside].sum() * DX * DX
            h = h2
        # --- dewetting / thin-film rule
        if mode == 'unified':
            Vd = 72000.0 * th ** 3 / (9 * math.log(5e6))                              # mm/s
            steps = Vd * DT / DX; nS = int(steps); frac = steps - nS
            for st in range(nS + (1 if frac > 0 else 0)):
                f = 1.0 if st < nS else frac
                wetm = h > 0.002
                edge = wetm & ~ndimage.binary_erosion(wetm)
                if not edge.any(): break
                nb = np.stack([np.roll(h, 1, 0), np.roll(h, -1, 0), np.roll(h, 1, 1), np.roll(h, -1, 1)])
                tgt = np.argmax(nb, 0); best = nb.max(0)
                mv = np.where(edge & (best > h * 0.999), h * f, 0.0)
                h -= mv
                for j, (ry, rx) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
                    sel = np.where(tgt == j, mv, 0.0)
                    h += np.roll(np.roll(sel, -ry, 0), -rx, 1)
            lab, n = ndimage.label(h > 0.002)
            if n:
                area = ndimage.sum(np.ones_like(h), lab, np.arange(1, n + 1))
                vol = ndimage.sum(h, lab, np.arange(1, n + 1)) * DX * DX
                cen = ndimage.center_of_mass(h, lab, np.arange(1, n + 1))
                for i in range(n):
                    if area[i] <= 3:
                        drops.append([(cen[i][1] + 0.5) * DX, (cen[i][0] + 0.5) * DX, vol[i], 0.0]); h[lab == i + 1] = 0
            tiny = (h > 0) & (h <= 0.0015); ledger['lost'] += h[tiny].sum() * DX * DX; h[tiny] = 0   # -> haze (micro)
        else:
            lab, n = ndimage.label(h > 0.002)
            area = ndimage.sum(np.ones_like(h), lab, np.arange(1, n + 1)) if n else []
            con = np.zeros_like(h, bool)
            for i in range(n):
                if area[i] > 60: con[lab == i + 1] = True
            thin = (h < 0.1) & ~con & (h > 0)
            ledger['lost'] += (h[thin] * (1 - math.exp(-3 * DT))).sum() * DX * DX; h[thin] *= math.exp(-3 * DT)
        # --- caps (drops / beads): a cap sitting on film water joins it (water touching water merges); run; leave trail water
        nd = []
        for d in drops:
            ix, iy = int(d[0] / DX), int(d[1] / DX)
            if mode == 'unified' and 0 <= ix < NX and 0 <= iy < NY and h[iy, ix] > 0.01:
                h[iy, ix] += d[2] / (DX * DX); continue
            r = (d[2] / shapeK) ** (1 / 3); v = vDrop(r)
            if v > 0:
                d[3] = max(min(d[3] + rng.normal(0, 0.15), 0.5), -0.5)
                ddx, ddy = math.sin(d[3]) * v * 1000 * DT, (-1 if FLOW_UP else 1) * math.cos(d[3]) * v * 1000 * DT
                h0, hw = trailRule(r, v, thr if mode == 'unified' else 28)
                L = math.hypot(ddx, ddy)
                if h0 > 0:
                    dv = min(4 / 3 * h0 * hw * L, 0.5 * d[2]); d[2] -= dv
                    if mode == 'unified':
                        nseg = max(int(L / DX * 2), 1)
                        for q in range(nseg):
                            px, py = d[0] + ddx * (q + 0.5) / nseg, d[1] + ddy * (q + 0.5) / nseg
                            ix, iy = int(px / DX), int(py / DX)
                            if 0 <= ix < NX and 0 <= iy < NY: h[iy, ix] += dv / nseg / (DX * DX)
                    else:
                        rods.append((d[0], d[1], d[0] + ddx, d[1] + ddy, hw, h0, k * DT))
                d[0] += ddx; d[1] += ddy
            if -2 < d[1] < NY * DX + 2 and d[2] > shapeK * 0.04 ** 3: nd.append(d)
            elif d[2] > 0: ledger['drained'] += d[2]
        drops = nd
        for tS in tShots:
            if abs(k * DT - tS) < DT / 2: shots[tS] = (h.copy(), [list(x) for x in drops], list(rods), dict(ledger))
        t += DT; k += 1
    return shots
def render(h, drops, rods, tNow):
    M = np.zeros((H, W), np.float32); NXn = np.zeros_like(M); NYn = np.zeros_like(M)
    hp = cv2.resize(h.astype(np.float32), (W, H), interpolation=cv2.INTER_CUBIC)
    gy, gx = np.gradient(cv2.GaussianBlur(hp, (0, 0), 2), PIX)                  # physical slope (mm / mm)
    film = np.clip((hp - 0.006) / 0.006, 0, 1)
    M = film.copy(); NXn = gx * 1.2; NYn = gy * 1.2
    rim = np.clip(np.hypot(gx, gy) * 2, 0, 1) * film
    for (x0, y0, x1, y1, hw, h0, born) in rods:
        if h0 - 0.003 * (tNow - born) <= 0.012: continue
        ax, ay = x1 - x0, y1 - y0; L2 = ax * ax + ay * ay + 1e-9
        bx0, bx1 = int(max(min(x0, x1) / PIX - 6, 0)), int(min(max(x0, x1) / PIX + 6, W)); by0, by1 = int(max(min(y0, y1) / PIX - 6, 0)), int(min(max(y0, y1) / PIX + 6, H))
        if bx1 <= bx0 or by1 <= by0: continue
        X, Y = xx[by0:by1, bx0:bx1], yy[by0:by1, bx0:bx1]
        u = np.clip(((X - x0) * ax + (Y - y0) * ay) / L2, 0, 1); px, py = X - (x0 + u * ax), Y - (y0 + u * ay)
        dd = np.hypot(px, py); m = np.clip((max(hw, 0.08) - dd) / PIX + 0.5, 0, 1)
        sub = M[by0:by1, bx0:bx1]; upd = m > sub; sub[upd] = m[upd]
        NXn[by0:by1, bx0:bx1][upd] = (px / max(hw, 0.08) * 0.5)[upd]; NYn[by0:by1, bx0:bx1][upd] = (py / max(hw, 0.08) * 0.5)[upd]
    for d in drops:
        r = (d[2] / shapeK) ** (1 / 3)
        bx0, bx1 = int(max(d[0] / PIX - r / PIX - 3, 0)), int(min(d[0] / PIX + r / PIX + 3, W)); by0, by1 = int(max(d[1] / PIX - r / PIX - 3, 0)), int(min(d[1] / PIX + r / PIX + 3, H))
        if bx1 <= bx0 or by1 <= by0: continue
        X, Y = xx[by0:by1, bx0:bx1], yy[by0:by1, bx0:bx1]
        q = np.hypot(X - d[0], Y - d[1]) / r; m = np.clip((1 - q) * r / PIX + 0.5, 0, 1)
        sub = M[by0:by1, bx0:bx1]; upd = m > sub; sub[upd] = m[upd]
        k2 = np.clip(q, 0, 0.98); f = 0.55 / np.sqrt(1 - k2 * k2 + 0.05)
        NXn[by0:by1, bx0:bx1][upd] = ((X - d[0]) / r * f)[upd]; NYn[by0:by1, bx0:bx1][upd] = ((Y - d[1]) / r * f)[upd]
    sl = np.hypot(NXn, NYn)
    mx = np.clip(xx / PIX - NXn * 22, 0, W - 1).astype(np.float32); my = np.clip(yy / PIX - NYn * 22, 0, H - 1).astype(np.float32)
    sharp = cv2.remap(scene, mx, my, cv2.INTER_LINEAR); soft = cv2.remap(blur, mx, my, cv2.INTER_LINEAR)
    c = (sharp * 0.6 + soft * 0.4) * (1 - 0.35 * np.clip((sl - 0.8) / 0.4, 0, 1))[..., None]
    c = c + (0.45 * np.clip(-NYn / np.maximum(sl, 1e-3), 0, 1) ** 4 * (sl > 0.6))[..., None] + 0.12 * rim[..., None]
    m3 = M[..., None]
    return scene * (1 - m3) + c * m3
def lab(im, t):
    im = (np.clip(im, 0, 1) * 255).astype(np.uint8)
    cv2.rectangle(im, (0, 0), (im.shape[1], 30), (0, 0, 0), -1)
    for i, s in enumerate(t.split('\n')):
        cv2.putText(im, s, (5, 12 + 13 * i), cv2.FONT_HERSHEY_SIMPLEX, 0.38, (255, 255, 255), 1, cv2.LINE_AA)
    return im
SHOTS = (0.02, 0.08, 0.25, 1.0)
rows = [('now', 28, 'current (approx)'), ('unified', 28, 'unified theta_r 28'), ('unified', 40, 'unified theta_r 40'), ('unified', 50, 'unified theta_r 50')]
sheet = []
for mode, thr, name in rows:
    sh = run(thr, mode, SHOTS)
    tiles = []
    for tS in SHOTS:
        h, drops, rods, led = sh[tS]
        filmV = h.sum() * DX * DX; capV = sum(d[2] for d in drops)
        tiles.append(lab(render(h, drops, rods, tS), f"{name}  {KMH:.0f} km/h  t {tS:.2f} s\nfilm {filmV:.1f} caps {capV:.1f} drained {led['drained']:.1f} to haze/lost {led['lost']:.1f} mm3 (in {led['supplied']:.1f})"))
        print(name, tS, 'film', round(filmV, 2), 'caps', round(capV, 2), 'n caps', len(drops), {k: round(v, 2) for k, v in led.items()})
    sheet.append(np.hstack(tiles))
cv2.imwrite(os.path.join(OUT, f'rainfx2_film_drain_{int(KMH)}.png'), np.vstack(sheet))
