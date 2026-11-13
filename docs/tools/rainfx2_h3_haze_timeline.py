"""H3-3 haze timeline check (docs/RAINFX_V2_H3_ATLAS_SPEC.md 8g): replicates W.impactKeep + the spray expectation loop
(init.lua) and the haze pass ODE (haze.hlsl) at one texel, before (8f: small spray pieces = cell drops, only fine
fragments feed the haze) and after (8g: pieces < a_max feed the coarse water G_c). Prints the time to the first resolved
piece, to the top octave and the steady state, for the user's chase numbers (spray 0.022 mm/s on the visor, median
0.062 mm, 240 km/h)."""
import math
P = dict(shapeK=1.0076, minRadiusMM=0.04, splashK0=58, resA=0.5, resB=0.4, fragA=0.88, fragLo=0.35, fragHi=3.0,
         hazeRMaxMM=0.08, sprayDsdSigma=2.0, sprayDMaxMM=0.8)
def fragQ(p):
    a, lo, hi = p['fragA'], p['fragLo'], p['fragHi']
    loP, hiP = lo ** -a, hi ** -a
    q = [(loP + (i - 0.5) / 8 * (hiP - loP)) ** (-1 / a) for i in range(1, 9)]
    return q, lo ** (3 - a), hi ** (3 - a), lo, hi
def impactKeep(d, v, p, split):
    V = math.pi / 6 * d ** 3
    vmin = p['shapeK'] * p['minRadiusMM'] ** 3; vsp = p['shapeK'] * split ** 3
    K = math.sqrt(13.8889 * v * v * d) * max(1000 * v * d, 1e-3) ** 0.25
    if K <= p['splashK0']:
        sm = V >= vmin and V < vsp
        return (V, V, 0, V if sm else 0, V * (V / p['shapeK']) ** (1 / 3) if sm else 0) if V >= vmin else (V, 0, V, 0, 0)
    kr = p['splashK0'] / K
    st = kr ** p['resA'] * V; dr = d * kr ** p['resB']
    vhz = p['shapeK'] * p['hazeRMaxMM'] ** 3
    q, l3, h3, lo, hi = fragQ(p); a = p['fragA']
    e = eh = es = er = 0
    for x in q:
        vp = min(math.pi / 6 * (dr * x) ** 3, st)
        if vp >= vmin:
            e += vp; eh += vp if vp < vhz else 0; es += vp if vp < vsp else 0
            er += vp * (vp / p['shapeK']) ** (1 / 3) if vp < vsp else 0
    xHz = (6 * vhz / math.pi) ** (1 / 3) / max(dr, 1e-6)
    fm = (min(max(xHz, lo), hi) ** (3 - a) - l3) / max(h3 - l3, 1e-12)
    return st, e / 8, max(st * min(max(fm, 0), 1) - eh / 8, 0), es / 8, er / 8
def shares(Dn, vI, split, p=P):
    sl = math.log(p['sprayDsdSigma']); EV = Es = Ec = Er = 0
    for i in range(1, 25):
        z = -3.5 + (i - 0.5) * 7 / 24; w = math.exp(-0.5 * z * z)
        d = min(Dn * math.exp(sl * z), p['sprayDMaxMM'])
        _, eK, hK, eS, eR = impactKeep(d, vI, p, split)
        EV += w * math.pi / 6 * d ** 3; Es += w * hK; Ec += w * eS; Er += w * eR
    return Es / EV, Ec / EV, (Er / Ec if Ec > 0 else 0.015)
def run(fine_mms, coarse_mms, T=40.0, dt=1 / 60, RH=0.9, Ts=20.0, a_in=None):
    a, phimax = 0.015, 0.55
    sat = -math.log(1 - phimax) * P['shapeK'] * a / math.pi
    top = sat * 0.2125 / a
    rhoSat = 611.2 * math.exp(17.67 * Ts / (Ts + 243.5)) / (461.5 * (Ts + 273.15))
    evapD = 4 * 2.5e-5 * rhoSat * (1 - RH) / 1000 * 1e6
    kF = min(evapD / (P['shapeK'] * a * a), 5.0)
    kPhi = math.pi / (P['shapeK'] * a); tau = 0.5; cover = 0.76
    Gf = Gc = 0.0; t = 0.0; first = topT = None; births = 0.0
    while t < T:
        perA = sat / a                                  # water depth that saturates the coverage, per mm of cap radius
        aC = max(a_in, Gc / perA) if a_in else a * max(Gc / sat, 1.0)   # 8g: pieces arrive at a_in, grow once saturated
        Gf *= math.exp(-kF * dt); Gc *= math.exp(-kF * dt * (a / aC) ** 2)
        relC = min(1 - math.exp(-math.pi * Gc / (P['shapeK'] * aC)), phimax) / phimax; onP = relC * cover
        sup = fine_mms * dt
        Gc += sup * onP + coarse_mms * dt; Gf += sup * (1 - onP)
        relF = min(1 - math.exp(-kPhi * Gf), phimax) / phimax
        dC = Gf * (1 - math.exp(-dt / tau * relF * relF)); Gf -= dC; Gc += dC
        Gf = min(Gf, 2 * sat)
        if Gc > top: births += Gc - top; Gc = top     # (the nucleus takes the excess; capped here for the timeline)
        aEff = max(a_in, Gc / perA) if a_in else a * max(Gc / sat, 1.0)
        # first resolved piece: largest piece r_max s >= 1 px (0.1 mm at the DLSS internal resolution)
        s = min(aEff / 0.2125, 1.0)
        if first is None and 0.30 * s >= 0.1 and relC > 0.02: first = t
        if topT is None and Gc >= top * 0.999: topT = t
        t += dt
    return dict(sat=sat, top=top, kF=kF, Gf=Gf / sat, Gc=Gc / sat, aEff=aEff, first=first, top_t=topT, toCells=births)
if __name__ == '__main__':
    mms, Dn, vI = 0.022 * 0.6, 0.062, 66.7 * 0.8 * 0.9      # visor spray x exposure ~0.6, median, impact speed (m/s)
    for name, split, law in (('8f (pieces = cell drops)', 0.0, False), ('8g pieces->G_c, a_min law', 0.3, False),
                             ('8g pieces->G_c, arrival size', 0.3, True)):
        hs, cs, ain = shares(Dn, vI, split)
        for RH in (0.9, 0.98):
            r = run(mms * hs, mms * cs, RH=RH, a_in=ain if law else None)
            if law and RH == 0.9: print('   arriving coarse piece radius (volume-weighted) %.3f mm' % ain)
            print('%-28s RH %.2f  fine share %.3f coarse share %.3f -> steady G_f %.2f G_c %.2f sat, a_eff %.3f mm, '
                  'first resolved %s s, top %s s, kF %.2f /s' % (name, RH, hs, cs, r['Gf'], r['Gc'], r['aEff'],
                  None if r['first'] is None else round(r['first'], 1), None if r['top_t'] is None else round(r['top_t'], 1), r['kF']))
