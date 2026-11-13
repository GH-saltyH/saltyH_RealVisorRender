"""H3 impact lamella sweep (I1) check -- docs/RAINFX_V2_H3_ATLAS_SPEC.md section 8l.
0-D haze texel with the haze.hlsl rules (fine G_f / coarse G_c, cap law, E2 coarsening, evaporation, supply onto pieces,
G_c above G_top -> cell drops) at the chase-sim supplies (section 8i, RH 0.95), 'now' vs I1: every spray impact spreads a
lamella of beta_max d (Roisman 2009) that gathers the fine caps under it into its own deposit -> G_f joins G_c at the
overrun rate nA = sprayMMs x (sum A / sum V) over the spray DSD (the same lognormal / impact speed as init.lua).
Prints the steady state and the regrowth of a wiped texel (60 fps)."""
import math
sat, aMin, K0cap, pm, kF, tau, top = 0.0038, 0.015, 1.0076, 0.55, 0.38, 0.5, 0.0544
kPhi = math.pi / (K0cap * aMin)
def beta(d, v):
    d *= 1e-3; Re = 1000 * v * d / 1e-3; We = 1000 * v * v * d / 0.072
    return max(0.87 * Re ** 0.2 - 0.40 * Re ** 0.4 * We ** -0.5, 1.0)
def area_per_vol(kmh):
    v = kmh / 3.6; Dn = min(max(0.39 * 12 * 0.072 / (1.2 * v * v) * 1000, 0.02), 0.8); vI = v * 0.8 * 0.9
    sl = math.log(2.0); SA = SV = 0
    for i in range(24):
        z = -3.5 + (i + 0.5) * 7 / 24; w = math.exp(-0.5 * z * z); d = min(Dn * math.exp(sl * z), 0.8)
        SA += w * math.pi / 4 * (beta(d, vI) * d) ** 2; SV += w * math.pi / 6 * d ** 3
    return SA / SV
FINE = {200: 0.04, 240: 0.08}   # fine share of the spray mass (W.impactKeep over the DSD, rainfx2 defaults)
# chase sim (8i): scene, km/h, fine mm/s, coarse mm/s, arrival radius mm
SC = [("Rain", 200, 0.0005, 0.0009, 0.171), ("Rain", 240, 0.0042, 0.0034, 0.145),
      ("Thunderstorm", 200, 0.0009, 0.0015, 0.169), ("Thunderstorm", 240, 0.0067, 0.0049, 0.144),
      ("Heavy Thunderstorm", 240, 0.0108, 0.0074, 0.142), ("Heavy Rain", 200, 0.0033, 0.0056, 0.170),
      ("Heavy Rain", 240, 0.0145, 0.0110, 0.145)]
def phis(gf, gc, aIn):
    aC = max(aIn, gc * aMin / sat)
    pf = min(1 - math.exp(-kPhi * gf), pm)
    pc = min(1 - math.exp(-math.pi * gc / (K0cap * aC)), pm)
    return pf, pc, aC
def step(gf, gc, sf, scs, aIn, nA, dt):
    aC = max(aIn, gc * aMin / sat); aRel = aC / aMin
    gf *= math.exp(-kF * dt); gc *= math.exp(-kF * dt / (aRel * aRel))
    relC = min(1 - math.exp(-math.pi * gc / (K0cap * aC)), pm) / pm; onP = relC * 0.76
    gc += sf * dt * onP + scs * dt; gf += sf * dt * (1 - onP)
    relF = min(1 - math.exp(-kPhi * gf), pm) / pm
    dC = gf * (1 - math.exp(-dt / tau * relF * relF)); gf -= dC; gc += dC
    if nA > 0:                                        # I1: lamellae gather the fine caps under them
        dI = gf * (1 - math.exp(-nA * dt)); gf -= dI; gc += dI
    gc = min(gc, top)                                 # excess -> cell drops (nucleation)
    return gf, gc
print(f"{'scene':26s} {'nA/s':>5s} | now: phiF phiC  veil | I1: phiF phiC  veil | regrow to veil 0.1 (frames) now / I1")
for n, kmh, sf, scs, aIn in SC:
    nA = sf / FINE[kmh] * area_per_vol(kmh)
    out = []
    for var in (0, nA):
        gf = gc = 0; dt = 1 / 60
        for _ in range(int(20 / dt)): gf, gc = step(gf, gc, sf, scs, aIn, var, dt)
        pf, pc, _ = phis(gf, gc, aIn); veil = 1 - (1 - pf) * (1 - pc)
        # regrowth: fresh texel, frames until the fine veil alone reaches 0.1
        g1 = g2 = 0; fr = '-'
        for i in range(1, 1200):
            g1, g2 = step(g1, g2, sf, scs, aIn, var, dt)
            if phis(g1, g2, aIn)[0] >= 0.1: fr = i; break
        out.append((pf, pc, veil, fr))
    a, b = out
    print(f"{n + ' ' + str(kmh):26s} {nA:5.1f} | {a[0]:5.2f} {a[1]:5.2f} {a[2]:5.2f} | {b[0]:5.2f} {b[1]:5.2f} {b[2]:5.2f} | {a[3]} / {b[3]}")
