"""FILM S2 stick check (2026-11-13): does a joined drop-sized film disk at rest move, and why not?
Replicates field.hlsl (r2FilmShedH edge retreat, B clip at gR2FilmMaxMM) + film.hlsl (upwind, Courant cap, Furmidge
mobility) on a 2-D grid, gravity along +y, no supply (heavy rain at rest is unfed: q << h * fedRate)."""
import math, numpy as np
TX, TY = 602.0 / 1024, 146.3 / 256           # texel mm
WET, HMAX, SUB, DT = 0.02, 2.0, 4, 1 / 60
def vd(h):                                     # r2DewetSpeedMMs(5 mm, wet), mm/s
    th = math.radians(40) * (1 - 0.35 * min(h / 0.2, 1)); return 72000 * th ** 3 / (9 * math.log(5e6))
def shed(H, front_ok=True):
    out = np.zeros_like(H); dst = np.full(H.shape, -1)
    P = np.pad(H, 1)
    nb = [P[1:-1, 2:], P[1:-1, :-2], P[2:, 1:-1], P[:-2, 1:-1]]    # +x -x +y -y (axis0 = y)
    best = np.max(nb, 0); arg = np.argmax(nb, 0); mn = np.min(nb, 0)
    for (y, x), h in np.ndenumerate(H):
        if h <= 0 or best[y, x] < WET: continue
        if h < WET: out[y, x], dst[y, x] = 1, arg[y, x]; continue
        # receding edge only (option): the dry neighbour is the DOWNSTREAM one (+y) -> advancing front, no retreat
        if not front_ok and (y + 1 >= H.shape[0] or H[y + 1, x] < WET): continue
        if mn[y, x] < WET and best[y, x] > h:
            out[y, x], dst[y, x] = min(1, vd(h) * DT / min(TX, TY)), arg[y, x]
    N = H.copy(); off = [(0, 1), (0, -1), (1, 0), (-1, 0)]
    for (y, x), s in np.ndenumerate(out):
        if s > 0:
            dy, dx = off[dst[y, x]]; m = s * H[y, x]; N[y, x] -= m; N[y + dy, x + dx] += m
    return N
def mobility(H):
    Lc = 72 * 0.18 / np.maximum(1000 * 9.81 * 0.5 * H * 1e-3, 1e-3)
    need = np.minimum(np.ceil(Lc / TY), 8)
    mob = np.zeros_like(H)
    for (y, x), h in np.ndenumerate(H):
        if h < WET: continue
        run = 1 + sum(1 for i in range(1, 8) if all(0 <= y + k < H.shape[0] and H[y + k, x] >= WET for k in range(1, i + 1)))
        run += sum(1 for j in range(1, 8) if all(0 <= y - k and H[y - k, x] >= WET for k in range(1, j + 1)))
        mob[y, x] = run >= need[y, x]
    return mob
def mobility_vol(H, tau=0.0):
    """F5 (Furmidge per unit width on the window water along the flow axis, +-7 texels, gaps included):
    tau L + rho g_t A >= gamma pinCoat  (A = sum h dx, L = wet length); no per-texel run, no peak penalty"""
    mob = np.zeros_like(H); P = np.pad(H, ((14, 14), (0, 0)))
    for (y, x), h in np.ndenumerate(H):
        if h < WET: continue
        w = P[y:y + 29:2, x]; A = w.sum() * 2 * TY * 1e-6; L = (w >= WET).sum() * 2 * TY * 1e-3   # shader: stride 2, +-14
        mob[y, x] = tau * L + 1000 * 9.81 * A >= 0.072 * 0.18
    # one decision per body: a texel joins a passing texel of its window (shader: second tap ring of the same window)
    return mob                                  # shader: no dilation (the 16 mm window covers bodies up to ~8 mm)
def transport(H, frame_mob=False):
    mob0 = (mobility_vol(H) if frame_mob == 'vol' else mobility(H)) if frame_mob else None
    for _ in range(SUB):
        if frame_mob:   # body decision of the frame start, carried with the water (upwind) through the substeps
            v = 3.27 * H * H; c = np.minimum(v * 1000 * DT / SUB / TY, 1.0)
            q = c * H * mob0; H = H - q; H[1:] += q[:-1]
            got = np.zeros_like(mob0, bool); got[1:] = q[:-1] > 0
            mob0 = np.where(got | ((H >= WET) & (mob0 > 0)), 1.0, 0.0); continue   # F5: the body's decision travels with its water
        v = 3.27 * H * H                       # m/s, gravity +y (lubrication), filmFlowK 1
        c = np.minimum(v * 1000 * DT / SUB / TY, 1.0)
        Lc = 72 * 0.18 / np.maximum(1000 * 9.81 * 0.5 * H * 1e-3, 1e-3)
        need = np.minimum(np.ceil(Lc / TY), 8)
        mob = np.zeros_like(H)
        for (y, x), h in np.ndenumerate(H):
            if h < WET: continue
            run = 1 + sum(1 for i in range(1, 8) if all(0 <= y + k < H.shape[0] and H[y + k, x] >= WET for k in range(1, i + 1)))
            run += sum(1 for j in range(1, 8) if all(0 <= y - k and H[y - k, x] >= WET for k in range(1, j + 1)))
            mob[y, x] = run >= need[y, x]
        q = c * H * mob
        H = H - q; H[1:] += q[:-1]
    return H
def disk(r=2.2, V=9.8):
    H = np.zeros((40, 24)); cy, cx = 10, 12
    for (y, x), _ in np.ndenumerate(H):
        d2 = ((y - cy) * TY) ** 2 + ((x - cx) * TX) ** 2
        H[y, x] = max(1 - d2 / r / r, 0) ** 0.5
    return H * V / (H.sum() * TX * TY)
def patch(h=0.2, w=5.0, l=8.0):
    H = np.zeros((60, 24)); ny, nx = int(l / TY), int(w / TX)
    H[5:5 + ny, 12 - nx // 2:12 - nx // 2 + nx] = h; return H
def run(H, ret, clip, front_ok=True, fm=False, frames=60):
    V0 = H.sum(); y0 = None
    for f in range(frames):
        if ret: H = shed(H, front_ok)
        if clip: H = np.minimum(H, HMAX)
        H = transport(H, fm)
        y = (H.sum(1) * np.arange(H.shape[0])).sum() / max(H.sum(), 1e-9); y0 = y if y0 is None else y0
    print('   %-44s centroid %.2f mm/s, wet area %.1f mm2, max h %.2f, mass %.0f%%'
          % (lab, (y - y0) * TY, (H >= WET).sum() * TX * TY, H.max(), 100 * H.sum() / V0))
if __name__ == '__main__':
    print('F5 final (window force balance once per frame, carried; thin films only -- thicker water is a drop, F1/F3)')
    for h, l in ((0.05, 8), (0.1, 8), (0.1, 16), (0.15, 12), (0.2, 8), (0.25, 8), (0.3, 8)):
        H = np.pad(patch(h, 5, l), ((0, 300), (0, 0))); y0 = (H.sum(1) * np.arange(H.shape[0])).sum() / H.sum()
        for f in range(10): H = transport(H, 'vol')
        y = (H.sum(1) * np.arange(H.shape[0])).sum() / H.sum()
        print('  %.2f mm x %2d mm (A %.2f mm2, pin needs 1.32 at rest): %3.0f mm/s (law %3.0f, Courant cap 137), max h %.2f'
              % (h, l, h * l, (y - y0) * TY * 6, 3.27 * h * h * 1000, H.max()))
