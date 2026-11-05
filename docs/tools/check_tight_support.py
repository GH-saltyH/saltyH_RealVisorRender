"""PERF-7: numerical check of r2SupportCore (cand.hlsl; visor r2SupportMM, rec.hlsl) against a NumPy port of r2AddDrop -> r2Kernel.
For random drops (all shape-state / lamella / neck / wobble / bend branches) it samples offsets q and reports the
largest |q| / B with kernel h > 0. Must stay < 1 (the bound is a proof; this guards the port against slips).
Usage: python docs/tools/check_tight_support.py [drops] [samples]"""
import sys
import numpy as np

rng = np.random.default_rng(7)
K = 1.24                        # gR2KernelScale
WOB_AMP, WOB_HZ = 0.08, 8.0
WOB_C = 0.25 * 1.2 * np.pi / (2 * 0.072 * 1.0) * 1e-3
SAG_K, NECK_K, NECK_T = 0.25, 1.5, 0.12
FING_K, RIM_K, IMP_K, IMP_MAX = 0.25, 0.6, 0.15, 1.8
SHP_ON = True


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def norm(v):
    return v / max(np.linalg.norm(v), 1e-12)


def add_drop_h(q, d, air, shp_on, wob_amp, fing_k, imp_max):
    """h of r2Kernel (> 0 means P / G / RW / HW change) for offsets q (N x 2)."""
    q = q.copy()
    h1 = (d['seed'] * 0.7548776662 + 0.31) % 1.0
    h2 = (d['seed'] * 0.6180339887 + 0.17) % 1.0
    shE = np.hypot(*d['sh'])
    shA = min(np.sqrt((0.5 + shE) / max(0.5 - shE, 0.05)), d['aMax'])
    hm = np.array(d['harm'])
    sphi = 0.5 * np.arctan2(d['sh'][1], d['sh'][0])
    bendS = d['bend']
    if d['e'] > 1e-3 and shp_on:
        q += air['iDir'] * (d['sft'] * min(1 + air['iA'], 2))
        AL = min(1 + IMP_K * air['iA'], imp_max)
        u = np.array([np.cos(sphi), np.sin(sphi)]); dd = air['iDir']; wD = 1 - d['e']; e = d['e']
        qa = wD * (u[0] ** 2 / shA + u[1] ** 2 * shA) + e * (dd[0] ** 2 / AL + dd[1] ** 2 * AL)
        qc = wD * (u[1] ** 2 / shA + u[0] ** 2 * shA) + e * (dd[1] ** 2 / AL + dd[0] ** 2 * AL)
        qb = wD * (u[0] * u[1] * (1 / shA - shA)) + e * (dd[0] * dd[1] * (1 / AL - AL))
        qm = 0.5 * (qa + qc); qd = np.sqrt(0.25 * (qa - qc) ** 2 + qb * qb)
        shA = min(min(np.sqrt((qm + qd) / max(qm - qd, 1e-6)), 4.0), d['aMax'])
        sphi = 0.5 * np.arctan2(-2 * qb, qc - qa)
        hm = hm * wD; bendS *= wD
    rk0 = K * d['r']; rkS = rk0
    H = np.zeros(3)
    if shp_on:
        u1 = np.array([np.cos(sphi), np.sin(sphi)]); s1 = 1 - 1 / shA
        rkS = rk0 / np.sqrt(shA)
        vv = np.array([-u1[1], u1[0]])
        aa = (q @ u1) / max(rk0 * np.sqrt(shA), 1e-4)
        ah = aa if d['bmode'] == 0 else (np.maximum(aa, 0) if d['bmode'] == 1 else np.maximum(-aa, 0))
        q = q - np.outer(bendS * rkS * ah * ah, vv)
        q = q - np.outer((q @ u1) * s1, u1)
        H = np.array([hm[0], hm[1], 3 * (d['harmPh'] - sphi)])
    else:
        ang = h2 * np.pi; u1 = np.array([np.cos(ang), np.sin(ang)])
        e1 = 0.22 * h1; s1 = e1 / (1 + e1)
        q = q - np.outer((q @ u1) * s1, u1)
    kSag = SAG_K * np.clip(d['r'] ** 2 / 2.25, 0, 1) * (1 - d['e'])
    slide = d['k'] > kSag
    u2 = d['m'] if slide else air['gdir']
    kk = d['k'] if slide else kSag
    if 0 <= d['ch'] < NECK_T:
        u2 = -d['nk']; kk = max(kk, NECK_K * (1 - d['ch'] / NECK_T))
    a = q @ u2
    s2 = np.where(a < 0, kk / (1 + kk), 0.0)
    q = q - u2[None, :] * (a * s2)[:, None]
    ratio = WOB_C * d['r'] * air['u2']
    A = wob_amp * smoothstep(0.1, 0.8, ratio)
    w = 2 * np.pi * WOB_HZ * (0.8 + 0.4 * h1) * d['time']
    ph = d['seed'] * 2.39996 + h2 * 2 * np.pi
    s3 = A * (0.65 * np.sin(w + ph) + 0.35 * np.sin(1.73 * w + 2 * ph))
    q = q - air['dir'] * (A * 0.3 * d['r'] * np.sin(w + ph + 1))
    q = q - np.outer((q @ air['dir']) * s3, air['dir'])
    # r2Kernel
    SPy = fing_k * np.clip(d['fx'], 0, 1) * (0.3 + 0.7 * np.clip(0.5 * air['iA'], 0, 1)) if d['fx'] > 1e-3 else 0.0
    ln = np.maximum(np.linalg.norm(q, axis=1), 1e-12)
    qq = q / ln[:, None]
    dR = np.ones(len(q))
    if abs(H[0]) + H[1] > 1e-3:
        ca = qq @ u1; sa = qq[:, 1] * u1[0] - qq[:, 0] * u1[1]
        c2 = ca * ca - sa * sa; c3 = ca * (4 * ca * ca - 3); s3_ = sa * (3 - 4 * sa * sa)
        dR = np.maximum(1 + H[0] * c2 + H[1] * (c3 * np.cos(H[2]) + s3_ * np.sin(H[2])), 0.3)
    if SPy > 1e-3:
        cd = qq @ air['iDir']
        psi = np.arctan2(qq[:, 0] * air['iDir'][1] - qq[:, 1] * air['iDir'][0], cd)
        fg = np.clip(np.cos(8 * psi + H[2]), 0, 1)
        dR = dR * (1 + SPy * fg ** 3 * np.clip(0.25 + 0.75 * cd, 0, 1))
    beta = 0.85 * np.clip(d['f'] - 1, 0, 1)
    x = np.sum(q * q, axis=1) / (rkS * rkS * dR * dR)
    h = 1 - (1 - beta) * x - beta * x * x
    if d['fx'] > 1e-3:
        h = np.where(h > 0, h, (1 - RIM_K) * h + RIM_K * 6.75 * x * x * (1 - x))   # lerp only matters for the sign
    return h


def support(d, air, shp_on, wob_amp, fing_k, imp_max):     # = r2SupportMM (reachMM 0)
    rk0 = K * d['r']
    A = wob_amp * smoothstep(0.1, 0.8, WOB_C * d['r'] * air['u2'])
    if A >= 0.95: return 1e9
    kk = max(d['k'], SAG_K * np.clip(d['r'] ** 2 / 2.25, 0, 1) * (1 - d['e']))
    if 0 <= d['ch'] < NECK_T: kk = max(kk, NECK_K * (1 - d['ch'] / NECK_T))
    kk = max(kk, 0)
    fing = max(fing_k, 0) * np.clip(d['fx'], 0, 1) if d['fx'] > 1e-3 else 0.0
    Y = 0.3 * A * d['r']
    if shp_on:
        X = rk0 * (1 + abs(d['harm'][0]) + abs(d['harm'][1])) * (1 + fing) / (1 - A)
        shE = np.hypot(*d['sh'])
        shA = min(np.sqrt((0.5 + shE) / max(0.5 - shE, 0.05)), d['aMax'])
        if d['e'] > 1e-3:
            aL = max(imp_max, 1 / max(imp_max, 1e-3)); shA = min(min(max(shA, aL), 4), d['aMax'])
        shA = max(shA, 1); sq = np.sqrt(shA); k1 = 1 + kk
        B = k1 * (X * sq + Y * shA) + abs(d['bend']) * k1 * k1 * (X + Y * sq) ** 2 / max(rk0, 1e-6)
        if d['e'] > 1e-3: B += 2 * abs(d['sft'])
    else:
        X = rk0 * (1 + fing) / (1 - A); B = 1.22 * (1 + kk) * (X + Y)
    return B * 1.002 + 1e-4


def rand_dir():
    a = rng.uniform(0, 2 * np.pi); return np.array([np.cos(a), np.sin(a)])


def main():
    n_drops = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
    n_q = int(sys.argv[2]) if len(sys.argv) > 2 else 4000
    worst, worst_d, legacy_ratio = 0.0, None, []
    for i in range(n_drops):
        shp_on = SHP_ON if i % 10 else False
        wob_amp = WOB_AMP if i % 7 else rng.uniform(0, 0.6)
        fing_k = FING_K if i % 5 else rng.uniform(0, 1.0)
        imp_max = IMP_MAX if i % 9 else rng.uniform(0.5, 4.0)
        r = float(np.exp(rng.uniform(np.log(0.03), np.log(3.0))))
        e = 0.0 if rng.random() < 0.6 else rng.uniform(0, 1)
        d = dict(r=r, k=rng.choice([0.0, rng.uniform(0, 4)]), e=e, sft=rng.uniform(0, 0.5 * r) if e else 0.0,
                 sh=rand_dir() * rng.uniform(0, 0.49), harm=(rng.uniform(-0.5, 0.5), rng.uniform(0, 0.4)),
                 harmPh=rng.uniform(-3, 3), bend=rng.uniform(-1.2, 1.2), bmode=int(rng.integers(0, 3)),
                 aMax=rng.choice([100.0, rng.uniform(1, 5)]), ch=rng.choice([-1.0, rng.uniform(0, 0.2)]),
                 nk=rand_dir(), m=rand_dir() if rng.random() < 0.7 else np.zeros(2), fx=rng.choice([0.0, rng.uniform(0, 2)]),
                 f=rng.uniform(1, 3), seed=float(rng.integers(0, 64)), time=rng.uniform(0, 100))
        air = dict(dir=rand_dir(), u2=rng.choice([0.0, rng.uniform(0, 3000)]), gdir=rand_dir(), iDir=rand_dir(),
                   iA=rng.uniform(0, 12))
        B = support(d, air, shp_on, wob_amp, fing_k, imp_max)
        if B >= 1e8: continue
        # q: uniform disc out to 2 B plus a ring around B
        rad = np.concatenate([2 * B * np.sqrt(rng.random(n_q // 2)), B * rng.uniform(0.8, 1.3, n_q // 2)])
        ang = rng.uniform(0, 2 * np.pi, n_q)
        q = np.stack([rad * np.cos(ang), rad * np.sin(ang)], 1)
        h = add_drop_h(q, d, air, shp_on, wob_amp, fing_k, imp_max)
        inside = h > 0
        if inside.any():
            m = np.max(rad[inside]) / B
            if m > worst: worst, worst_d = m, (d, air, shp_on)
            legacy = 1.3 * K * r * 1.35 * 2.0 * np.sqrt(np.sqrt((0.5 + np.hypot(*d['sh'])) / max(0.5 - np.hypot(*d['sh']), 0.05)))
            legacy_ratio.append(B / legacy)
    print('drops %d, samples/drop %d' % (n_drops, n_q))
    print('max |q|/B with h > 0: %.4f  (must be < 1)' % worst)
    lr = np.array(legacy_ratio)
    print('B / legacy reach: median %.2f  p90 %.2f  (area ratio median %.2f)' % (np.median(lr), np.percentile(lr, 90), np.median(lr) ** 2))
    if worst >= 1.0:
        print('FAILED', worst_d); sys.exit(1)
    print('OK')


if __name__ == '__main__':
    main()
