"""Trail target prototype (docs/RAINFX_V2_TRAIL_REVIEW2.md). A 48 x 32 mm visor patch at 0.1 mm / px, 240 km/h chase, 3 s:
drops of r 0.3-1.0 mm born at random, running up-stream at P.speed (physics.lua table) with a slow wander, each losing its
trail water by the current rule (r2TrailRule). Columns:
  now      : every trail is a pinned parabolic line, drawn as a continuous cylinder lens while h > trailMinMM (evaporation
             0.003 mm/s, pearling off): rods = the head's whole path, for seconds;
  TR (dry) : the line is drawn only over the head's last frame (its breakup time t_b = hw / V_d is 0.5-9 ms < a frame); its
             water becomes a row of beads (Rayleigh-Plateau spacing 9 hw, bead r from the line section) = micro-drop pieces;
  TR (wet) : wet surface (theta_r(wet) < the line edge angle 24 deg): the rivulet is pinned inside the hysteresis window ->
             it stays a continuous line (the thick-trail reference), evaporating.
Usage: python rainfx2_trail_target_proto.py OUT_PNG"""
import sys, os, math
import numpy as np, cv2
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1]
PIX, W, H = 0.1, 480, 320
rng = np.random.default_rng(7)
src = cv2.imread(os.path.join(HERE, 'rainfx2_sheet_bg.png')).astype(np.float32) / 255
SCR = cv2.resize(src, (int(src.shape[1] * 1080 / src.shape[0]), 1080), interpolation=cv2.INTER_CUBIC)
scene = SCR[300:300 + H, 820:820 + W].copy()
blur = cv2.GaussianBlur(SCR, (0, 0), 24)[300:300 + H, 820:820 + W]
yy, xx = (np.mgrid[0:H, 0:W].astype(np.float32) + 0.5) * PIX
thR, wetK, LL, wK, slopeM, tMin, evap, shapeK = 28.0, 0.35, 5.0, 0.5, 0.45, 0.012, 0.003, 1.0076
SPEED = {0.2: 0.087, 0.3: 0.159, 0.5: 0.347, 1.0: 0.774}
def vOf(r):
    ks = sorted(SPEED); 
    if r <= ks[0]: return SPEED[ks[0]] * r / ks[0]
    for a, b in zip(ks, ks[1:]):
        if r <= b: return SPEED[a] + (SPEED[b] - SPEED[a]) * (r - a) / (b - a)
    return SPEED[ks[-1]]
def rule(r, v, wet):
    th = math.radians(thR) * (1 - wetK * wet)
    caS = th ** 3 / (9 * math.log(max(r * 1e6, 10))); ca = v / 72.0; s = ca / caS
    if s <= 1: return 0.0, 0.0, th
    hw = 0.5 * wK * r * math.sqrt(1 - 1 / s)
    return min(LL * r * ca ** (2 / 3), 0.5 * hw * slopeM), hw, th
def simulate(wet, T=3.0, dt=1 / 60, rate=9.0):
    drops, segs = [], []          # segs: (x0, y0, x1, y1, h0, hw, born)
    t = 0.0
    while t < T:
        for _ in range(rng.poisson(rate * dt)):
            drops.append([rng.uniform(2, 46), rng.uniform(24, 32), shapeK * rng.uniform(0.3, 1.0) ** 3, rng.uniform(-0.3, 0.3)])
        for d in drops:
            r = (d[2] / shapeK) ** (1 / 3); v = vOf(r)
            d[3] += rng.normal(0, 0.15); d[3] = max(min(d[3], 0.5), -0.5)
            dx, dy = math.sin(d[3]) * v * 1000 * dt, -math.cos(d[3]) * v * 1000 * dt
            h, hw, th = rule(r, v, wet)
            if h > 0:
                L = math.hypot(dx, dy); d[2] -= 4 / 3 * h * hw * L
                segs.append((d[0], d[1], d[0] + dx, d[1] + dy, h, hw, t, th))
            d[0] += dx; d[1] += dy
        drops = [d for d in drops if d[2] > shapeK * 0.08 ** 3 and -5 < d[1] < 40]
        t += dt
    return drops, segs, t
def lens(img, mask, nx, ny):
    # simple plano-convex stand-in: scene displaced against the slope from the blurred scene, dark rim, sky glint
    sl = np.sqrt(nx * nx + ny * ny)
    mx = np.clip(xx / PIX - nx * 18, 0, W - 1).astype(np.float32); my = np.clip(yy / PIX - ny * 18, 0, H - 1).astype(np.float32)
    c = cv2.remap(blur, mx, my, cv2.INTER_LINEAR) * (1 - 0.55 * np.clip((sl - 0.55) / 0.4, 0, 1))[..., None]
    c += (0.5 * np.clip(-ny, 0, 1) ** 4 * (sl > 0.6))[..., None]
    m = mask[..., None]
    return img * (1 - m) + c * m
def draw_disc(cx, cy, r, M, NX, NY):
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / max(r, 1e-3)
    m = np.clip((1 - d) * r / PIX + 0.5, 0, 1)
    upd = m > M; M[upd] = m[upd]
    k = np.clip(d, 0, 0.999); nx = (xx - cx) / max(r, 1e-3) / np.sqrt(1 - k * k + 0.04); ny = (yy - cy) / max(r, 1e-3) / np.sqrt(1 - k * k + 0.04)
    NX[upd] = (nx * 0.5)[upd]; NY[upd] = (ny * 0.5)[upd]
def draw_line(x0, y0, x1, y1, hw, M, NX, NY, k=1.0):
    ax, ay = x1 - x0, y1 - y0; L2 = ax * ax + ay * ay + 1e-9
    u = np.clip(((xx - x0) * ax + (yy - y0) * ay) / L2, 0, 1)
    px, py = xx - (x0 + u * ax), yy - (y0 + u * ay); d = np.sqrt(px * px + py * py)
    m = np.clip((hw - d) / PIX + 0.5, 0, 1) * k
    upd = m > M; M[upd] = m[upd]
    q = np.clip(d / max(hw, 1e-3), 0, 0.999)
    NX[upd] = (px / max(hw, 1e-3) * 0.45 / np.sqrt(1 - q * q + 0.1))[upd]; NY[upd] = (py / max(hw, 1e-3) * 0.45 / np.sqrt(1 - q * q + 0.1))[upd]
def render(mode, wet):
    drops, segs, tEnd = simulate(wet)
    M = np.zeros((H, W), np.float32); NX = np.zeros_like(M); NY = np.zeros_like(M)
    nRod = 0
    for (x0, y0, x1, y1, h, hw, born, th) in segs:
        age = tEnd - born; hNow = h - evap * age
        fresh = age < 1.5 / 60
        stable = math.atan(2 * h / hw) >= th                     # pinned inside the hysteresis window
        if mode == 'now' or (mode != 'now' and (fresh or stable)):
            if hNow > tMin:
                draw_line(x0, y0, x1, y1, hw, M, NX, NY, min((hNow - tMin) / 0.03, 1.0)); nRod += 1
        else:                                                     # beads of the line (Rayleigh-Plateau row)
            L = math.hypot(x1 - x0, y1 - y0); lam = 9 * hw
            rb0 = (lam * 4 / 3 * h * hw / shapeK) ** (1 / 3)
            n = int(L / lam + rng.uniform())
            for i in range(n):
                f = (i + rng.uniform(0.2, 0.8)) / max(L / lam, 1e-3)
                if f > 1: break
                rb = rb0 * rng.uniform(0.75, 1.2)
                draw_disc(x0 + f * (x1 - x0) + rng.normal(0, 0.3 * hw), y0 + f * (y1 - y0), rb, M, NX, NY)
    for d in drops:
        r = (d[2] / shapeK) ** (1 / 3); draw_disc(d[0], d[1], r, M, NX, NY)
    return lens(scene, M, NX, NY), nRod
def lab(im, t):
    im = (np.clip(im, 0, 1) * 255).astype(np.uint8)
    im = cv2.resize(im, (W * 2, H * 2), interpolation=cv2.INTER_LINEAR)
    cv2.rectangle(im, (0, 0), (im.shape[1], 22), (0, 0, 0), -1)
    cv2.putText(im, t, (6, 16), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1, cv2.LINE_AA)
    return im
tiles = []
for mode, wet, name in (('now', 0.3, 'now (wet 0.3): pinned rods, whole path, seconds'),
                        ('tr', 0.3, 'TR dry (wet 0.3): fresh tail + bead rows'),
                        ('tr', 0.8, 'TR wet (wet 0.8): stable rivulets stay continuous')):
    rng = np.random.default_rng(7)
    im, n = render(mode, wet)
    tiles.append(lab(im, name))
cv2.imwrite(OUT, np.vstack(tiles))
print('written', OUT)
