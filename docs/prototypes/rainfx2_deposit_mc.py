#!/usr/bin/env python3
"""RainFX v2 deposition Monte Carlo (docs/RAINFX_V2_DEPOSITION_MODEL.md).

Literature-driven estimate of the drop population that a visor patch carries for a given
weather / speed / spray state, independent of the game shaders:

  supply   rain DSD: constrained gamma (Zhang, Vivekanandan & Brandes 2001), D0 from the rain rate
           (Marshall-Palmer D0 = 3.67 / Lambda_MP), N0 from the rate (fall speed Atlas 1973)
           spray: lognormal fine droplets (tyre spray: number mean ~70-90 um, Shearman / Borg & Vevang,
           Gaylard 2017 review), liquid water content LWC_s
  impinge  flux per size = N(D) |v_rel . n| x collection efficiency eta(Stokes) at the helmet
  outcome  RainFX R2 rule: deposition below K0 = 58, else residual (K0/K)^0.3 + satellites
  surface  spherical caps at theta (R3), coalescence on contact (union), removal when gravity + air
           exceed Furmidge pinning (R6b drag, shedU10); a sliding drop sweeps its path off the patch

Outputs per case: drops / cm^2 (r >= rVis), coverage, radius p50 / p90 / p99, mean standing depth, and the
time to reach 90 % of the steady coverage. Pure numpy + python, ~seconds per case.
"""
import math, random, argparse
import numpy as np

RHO, GAM, MU, RHO_A, MU_A = 1000.0, 0.072, 1e-3, 1.2, 1.8e-5


def vt(Dmm):                                          # Atlas 1973 (m/s)
    return np.maximum(9.65 - 10.3 * np.exp(-0.6 * Dmm), 0.1)


def capK(deg):
    t = math.tan(math.radians(deg) / 2)
    return math.pi / 6 * t * (3 + t * t)


def dsd(R, Dgrid):
    """Constrained-gamma DSD for rain rate R (mm/h): returns N(D) (m^-3 mm^-1) on Dgrid (mm)."""
    D0 = 3.67 * R ** 0.21 / 4.1                       # MP median volume diameter
    lam = 3.67 / D0
    for _ in range(30):                               # mu-Lambda (Zhang 2001), Lambda D0 = 3.67 + mu
        mu = -0.016 * lam * lam + 1.213 * lam - 1.957
        lam = (3.67 + mu) / D0
    shape = Dgrid ** mu * np.exp(-lam * Dgrid)
    # rain rate R = 6 pi 1e-4 sum N D^3 v dD  (mm/h with N m^-3 mm^-1, D mm, v m/s)
    dD = Dgrid[1] - Dgrid[0]
    r_unit = 6 * math.pi * 1e-4 * np.sum(shape * Dgrid ** 3 * vt(Dgrid)) * dD
    return shape * (R / r_unit), mu, lam, D0


def eta(Dmm, U, Rh=0.13):
    """Impingement efficiency of drops on the helmet (Langmuir-type fit on the Stokes number)."""
    if U < 1:
        return np.ones_like(Dmm)
    St = RHO * (Dmm * 1e-3) ** 2 * U / (18 * MU_A * Rh)
    return (St / (St + 0.25)) ** 2


def run(R=20.0, Vcar=0.0, wind=5.0, spray_lwc=0.0, spray_dmm=0.09, T=40.0, seed=1, theta=60.0, dcos=0.18,
        shedU10=20.0, aeroKU=0.35, tilt=25.0, L=40.0, rvis=0.05, verbose=False):
    rng = np.random.default_rng(seed)
    random.seed(seed)
    K = capK(theta)
    # visor normal (unit, x forward, z up): tilted back by `tilt` from vertical
    tr = math.radians(tilt)
    n = np.array([math.cos(tr), 0.0, math.sin(tr)])
    # drag coefficient calibrated so a 10 uL drop depins at shedU10 (R6b)
    rRef = (10 / K) ** (1 / 3) * 1e-3
    Cd = 2 * GAM * dcos / (0.25 * RHO_A * math.pi * rRef * shedU10 ** 2)
    Uair = 1.5 * aeroKU * Vcar                         # outer flow over the visor (rev47 aero)
    gsin = 9.81 * math.cos(tr)                         # tangential gravity on the tilted visor
    # supply: per-size impact rate per mm^2 per s
    Dg = np.linspace(0.05, 6.0, 240)
    dD = Dg[1] - Dg[0]
    rates, sizes = [], []
    if R > 0:
        N, mu, lam, D0 = dsd(R, Dg)
        v = np.stack([np.full_like(Dg, Vcar + wind), np.zeros_like(Dg), -vt(Dg)], axis=1)   # relative to the visor
        vn = np.abs(v @ n)
        f = N * vn * eta(Dg, max(Uair, Vcar)) * dD * 1e-6        # m^-3 mm^-1 * m/s * mm -> per m^2 s -> per mm^2 s
        rates.append(f); sizes.append(Dg)
    if spray_lwc > 0:
        # lognormal number distribution, median spray_dmm, sigma_g 1.8 (fine tyre spray)
        sg = math.log(1.8)
        pdf = np.exp(-(np.log(Dg / spray_dmm)) ** 2 / (2 * sg * sg)) / (Dg * sg * math.sqrt(2 * math.pi))
        vol = np.sum(pdf * math.pi / 6 * (Dg * 1e-3) ** 3) * dD     # m^3 per drop (mean)
        ntot = spray_lwc * 1e-3 / RHO / vol                          # drops per m^3 (LWC in g/m^3)
        f = ntot * pdf * max(Vcar, 1.0) * n[0] * eta(Dg, max(Uair, Vcar)) * dD * 1e-6
        rates.append(f); sizes.append(Dg)
    rate = np.sum(rates, axis=0)
    # patch size: at least 12 mm, at most ~20000 impacts over the run (heavy supply -> smaller patch, same stats)
    L = float(min(L, max(12.0, math.sqrt(20000.0 / max(rate.sum() * T, 1e-9)))))
    total = rate.sum() * L * L                         # impacts per s on the patch
    # very dense supply (spray, cloudburst at speed): deposit PARCELS of m same-size drops at one point (they meet
    # within a frame anyway); only the sub-visible end of the distribution is coarse-grained
    parcel = max(1.0, total * T / 30000.0)
    total /= parcel
    cdf = np.cumsum(rate) / max(rate.sum(), 1e-30)
    vrel = math.sqrt((Vcar + wind) ** 2)
    # drop store
    xs, ys, Vs = [], [], []
    cell = 2.0
    grid = {}

    def rad(V):
        return (V / K) ** (1 / 3)

    def key(x, y):
        return (int(x // cell), int(y // cell))

    def add(x, y, V):
        xs.append(x); ys.append(y); Vs.append(V)
        i = len(Vs) - 1
        grid.setdefault(key(x, y), set()).add(i)
        return i

    def remove(i):
        grid[key(xs[i], ys[i])].discard(i)
        Vs[i] = 0.0

    def neighbours(x, y, reach):
        kx, ky = key(x, y)
        s = int(math.ceil(reach / cell))
        for a in range(kx - s, kx + s + 1):
            for b in range(ky - s, ky + s + 1):
                for j in grid.get((a, b), ()):
                    yield j

    def moves(V):
        r = rad(V) * 1e-3
        Fg = RHO * V * 1e-9 * gsin
        uh = Uair
        Fa = 0.25 * RHO_A * Cd * math.pi * r * r * uh * uh
        Fp = GAM * 2 * r * dcos * random.uniform(0.6, 1.4)
        return Fg + Fa > Fp

    def settle(i):
        # coalesce with every touching drop (cascade), then test sliding
        while True:
            r = rad(Vs[i])
            hit = None
            for j in neighbours(xs[i], ys[i], r + 3.5):
                if j != i and Vs[j] > 0:
                    rj = rad(Vs[j])
                    if (xs[i] - xs[j]) ** 2 + (ys[i] - ys[j]) ** 2 < (r + rj) ** 2:
                        hit = j
                        break
            if hit is None:
                break
            j = hit
            V = Vs[i] + Vs[j]
            x = (xs[i] * Vs[i] + xs[j] * Vs[j]) / V
            y = (ys[i] * Vs[i] + ys[j] * Vs[j]) / V
            remove(i); remove(j)
            i = add(x % L, y % L, V)
        if moves(Vs[i]):
            # slides off: sweeps a band of its width down / along the air to the patch edge
            r = rad(Vs[i])
            x0, y0 = xs[i], ys[i]
            remove(i)
            for j in list(neighbours(x0, y0, L)):
                if Vs[j] > 0 and abs(xs[j] - x0) < r + rad(Vs[j]) and ys[j] < y0:
                    remove(j)
        return

    t, dt = 0.0, 1 / 60
    hist = []
    nImp = 0
    while t < T:
        k = rng.poisson(total * dt)
        for _ in range(k):
            u = rng.random()
            D = Dg[min(np.searchsorted(cdf, u), len(Dg) - 1)] + (rng.random() - 0.5) * dD
            D = max(D, 0.02)
            vT = float(vt(np.array([D]))[0])
            vi = abs(float(np.dot(np.array([Vcar + wind, 0, -vT]), n)))
            vi = max(vi, 0.3)
            We = RHO * vi * vi * D * 1e-3 / GAM
            Re = RHO * vi * D * 1e-3 / MU
            Kk = math.sqrt(We) * Re ** 0.25
            Vd = math.pi / 6 * D ** 3 * parcel
            x, y = rng.random() * L, rng.random() * L
            if Kk <= 58:
                Vres = Vd
                sats = []
            else:
                fres = (58 / Kk) ** 0.3
                Vres = Vd * fres
                dres = D * (58 / Kk) ** 0.4
                nsat = int(min(0.5 * (1 - fres) * (D / dres) ** 3, 12))
                Pl = We * Re ** -0.4
                Rl = 0.5 * D * Re ** 0.2 * math.sqrt(Pl) / (1.24 + math.sqrt(Pl))
                sats = [(x + Rl * math.cos(a), y + Rl * math.sin(a), math.pi / 6 * dres ** 3 * parcel)
                        for a in rng.random(nsat) * 2 * math.pi]
            if rad(Vres) >= 0.02:
                settle(add(x, y, Vres))
            for sx, sy, sv in sats:
                if rad(sv) >= 0.02:
                    settle(add(sx % L, sy % L, sv))
            nImp += 1
        t += dt
        if int(t * 60) % 30 == 0:
            Va = np.array(Vs)
            Va = Va[Va > 0]
            rr = rad(Va)
            vis = rr >= rvis
            cov = np.sum(math.pi * rr[vis] ** 2) / (L * L)
            hist.append((t, cov))
    Va = np.array(Vs)
    Va = Va[Va > 0]
    rr = rad(Va)
    vis = rr[rr >= rvis]
    covs = np.array(hist)
    covEnd = covs[-1, 1] if len(covs) else 0
    t90 = next((tt for tt, c in covs if c >= 0.9 * covEnd), T) if covEnd > 0 else T
    res = dict(parcel=parcel, R=R, V=Vcar * 3.6, spray=spray_lwc, impacts_mm2s=total / (L * L), n_cm2=len(vis) / (L * L) * 100,
               cov=covEnd, p50=np.percentile(vis, 50) if len(vis) else 0,
               p90=np.percentile(vis, 90) / max(np.percentile(vis, 50), 1e-9) if len(vis) else 0,
               p99=np.percentile(vis, 99) / max(np.percentile(vis, 50), 1e-9) if len(vis) else 0,
               rmax=vis.max() if len(vis) else 0, depth_um=np.sum(Va) / (L * L) * 1000, t90=t90)
    return res


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--T', type=float, default=40.0)
    a = ap.parse_args()
    cases = []
    for R in (1, 5, 20, 60):
        for Vk in (0, 100, 250):
            cases.append(dict(R=R, Vcar=Vk / 3.6))
    for lwc, Vk in ((0.3, 150), (1.0, 150), (3.0, 150)):
        cases.append(dict(R=5, Vcar=Vk / 3.6, spray_lwc=lwc))
    print('R mm/h  V km/h  spray g/m3 | impacts/mm2s  drops/cm2  cover  p50 mm  p90/p50  p99/p50  rmax  depth um  t90 s')
    for c in cases:
        r = run(T=a.T, **c)
        print('%5.0f %7.0f %8.1f | %10.3f %9.1f %6.3f %6.3f %8.2f %8.2f %5.2f %8.1f %6.1f' % (
            r['R'], r['V'], r['spray'], r['impacts_mm2s'], r['n_cm2'], r['cov'], r['p50'], r['p90'], r['p99'],
            r['rmax'], r['depth_um'], r['t90']), flush=True)
