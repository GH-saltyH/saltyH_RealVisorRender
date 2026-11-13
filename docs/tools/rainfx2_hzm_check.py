"""N3 reach-mask exactness check (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 27).
Replicates hzm.hlsl (segment-rectangle distance <= r2HaloOut + qL) and haze.hlsl's r2SweepFrac (N2 halo) on random drops /
moves and counts (texel, drop) pairs with a non-zero sweep whose bit is clear (must be 0), plus the mean set bits per cell."""
import numpy as np
CELLS = np.array([512.0, 128.0]); HAZE = np.array([2048.0, 512.0])
CS = np.array([602.0, 146.3]) / CELLS
HK, HIN, HOUT = 0.5, 0.1, 0.25
def seg(p, a, b):
    ab = b - a; l2 = ab @ ab
    k = np.clip((p - a) @ ab / l2, 0, 1) if l2 > 1e-10 else 0.0
    return np.linalg.norm(p - (a + ab * k))
def rin(r): return r + HIN
def rout(r): return max(r * (1 + HK) + HOUT, rin(r) + 1e-3)
def ss(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)
def sweep(f, b, mv, r):
    tc = (f + 0.5) / HAZE * CELLS; q = 0.25 * CELLS / HAZE
    a, bb = (b - mv) * CS, b * CS
    qL = np.linalg.norm(q * CS); d0 = seg(tc * CS, a, bb)
    if d0 - qL >= rout(r): return 0.0
    if d0 + qL <= rin(r): return 1.0
    n = 0
    for o in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        n += 1 - ss(rin(r), rout(r), seg((tc + np.array(o) * q) * CS, a, bb))
    return n / 4
def boxd(p, lo, hi): return np.linalg.norm(np.maximum(np.maximum(lo - p, p - hi), 0))
def segbox(a, b, lo, hi):
    ab = b - a; t0, t1 = 0.0, 1.0
    for k in range(2):
        if abs(ab[k]) < 1e-9:
            if a[k] < lo[k] or a[k] > hi[k]: t0 = 2.0
        else:
            u0, u1 = (lo[k] - a[k]) / ab[k], (hi[k] - a[k]) / ab[k]
            t0 = max(t0, min(u0, u1)); t1 = min(t1, max(u0, u1))
    if t0 <= t1: return 0.0
    d = min(boxd(a, lo, hi), boxd(b, lo, hi))
    for c in (lo, hi, np.array([lo[0], hi[1]]), np.array([hi[0], lo[1]])): d = min(d, seg(c, a, b))
    return d
rng = np.random.default_rng(7)
qL = np.linalg.norm(0.25 * CELLS / HAZE * CS)
miss = pairs = bits = 0; N = 4000
for _ in range(N):
    c0 = np.array([200, 60]); lo = c0 * CS; hi = lo + CS
    dxy = rng.integers(-2, 3, 2); s = c0 + dxy
    b = s + rng.random(2); r = np.exp(rng.uniform(np.log(0.04), np.log(3.0)))
    mv = rng.normal(0, 1.0, 2) * (rng.random() < 0.6)
    on = segbox((b - mv) * CS, b * CS, lo, hi) <= (rout(r) + qL) * 1.001 + 1e-4
    bits += on
    for y in range(4):
        for x in range(4):
            f = c0 * 4 + np.array([x, y])
            w = sweep(f, b, mv, r)
            if w > 0:
                pairs += 1
                if not on: miss += 1
print('drops %d  bit set %.1f %%  (texel, drop) pairs swept %d  missed %d' % (N, 100 * bits / N, pairs, miss))
