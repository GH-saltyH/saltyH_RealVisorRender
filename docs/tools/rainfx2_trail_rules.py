"""rev47l trail rule check (docs/RAINFX_V2_TRAIL_RULES.md): which drops slide dry, which leave a rivulet,
its width / depth, for the shader's speed law (r2DropVelocity) and rule (r2TrailRule).

Speed: helmet aero (sphere outer flow, stagnation boundary layer, pressure gradient) + gravity on a vertical
face (quadrature sum), pinning gamma 2r dcos (mean heterogeneity, kinetic 0.6 once moving);
creeping v = vMax (1 - exp(-vq / vScale)), vq = (F - Fpin) / (friction r); blown (air > shedK Fpin):
v = max(min(creep, runbackMax), min(runbackK u_top excess, runbackMax)).
Rule: Ca = U / 72, Ca* = theta_r^3 / (9 ln(r / 1 nm)), theta_r = thetaR (1 - wetK wet);
trail when Ca > Ca*: hw = 0.5 widthK r sqrt(1 - Ca*/Ca), h0 = min(LL r Ca^(2/3), 0.5 hw slopeMax).

usage: python rainfx2_trail_rules.py [--thetaR 25 --wetK 0.35 --LL 5]
"""
import argparse
import math

ap = argparse.ArgumentParser()
ap.add_argument('--thetaR', type=float, default=28.0)
ap.add_argument('--wetK', type=float, default=0.35)
ap.add_argument('--LL', type=float, default=5.0)
ap.add_argument('--widthK', type=float, default=0.5)
ap.add_argument('--slopeMax', type=float, default=0.45)
a = ap.parse_args()

P = dict(shapeK=2.0944, gamma=0.072, pinCoat=0.18, kinetic=0.6, friction=0.15, Cd=1.0, rho=1.2, vMax=0.08,
         vScale=0.25, shedK=2.0, aeroKU=0.35, helmetR=0.13, runbackK=0.003, runbackMax=0.06, nu=1.5e-5)


def speed(rMM, kmh, thetaDeg, gTan=9.81):
    r = rMM * 1e-3
    U = kmh / 3.6
    ue0 = 1.5 * P['aeroKU'] * U
    a_ = ue0 / P['helmetR']
    delta = min(2.4 * math.sqrt(P['nu'] / a_) * 1000, 50) if a_ > 1e-3 else 50
    th = math.radians(thetaDeg)
    ue = ue0 * math.sin(th)
    x = 0.6 * rMM / delta
    uh = ue * (x * (2 - x) if x < 1 else 1)
    Fa = 0.25 * P['rho'] * P['Cd'] * math.pi * r * r * uh * uh + P['shapeK'] * rMM ** 3 * 1e-9 * P['rho'] * ue * a_ * math.cos(th)
    Fg = 1e-6 * P['shapeK'] * rMM ** 3 * gTan
    F = math.hypot(Fa, Fg)
    Fpin = P['gamma'] * 2 * r * P['pinCoat'] * P['kinetic']
    if F <= Fpin:
        return 0.0
    vq = (F - Fpin) / (P['friction'] * r)
    creep = P['vMax'] * (1 - math.exp(-vq / P['vScale']))
    if Fa > P['shedK'] * Fpin:
        exc = max(0.0, 1 - P['shedK'] * Fpin / Fa)
        return max(min(creep, P['runbackMax']), min(P['runbackK'] * uh * exc, P['runbackMax']))
    return creep


def rule(rMM, U, wet):
    th = math.radians(a.thetaR) * (1 - a.wetK * wet)
    caS = th ** 3 / (9 * math.log(max(rMM * 1e6, 10)))
    ca = U / 72
    s = ca / caS if caS > 0 else 0
    if s <= 1:
        return 0, 0, s
    hw = 0.5 * a.widthK * rMM * math.sqrt(1 - 1 / s)
    return min(a.LL * rMM * ca ** (2 / 3), 0.5 * hw * a.slopeMax), hw, s


print('threshold speed U* (mm/s) by wetness:', ', '.join(
    'wet %.1f -> %.0f' % (w, 72e3 * (math.radians(a.thetaR) * (1 - a.wetK * w)) ** 3 / (9 * math.log(1e6))) for w in (0, 0.3, 0.6, 1.0)))
for kmh, wet, theta in ((0, 0.2, 0), (0, 0.6, 0), (100, 0.4, 30), (250, 0.6, 20), (250, 0.6, 50)):
    print('\n%3d km/h  wet %.1f  %2d deg from stagnation' % (kmh, wet, theta))
    print('   r mm   U mm/s   Ca/Ca*   trail    hw mm   h0 um   lost /10mm')
    for rMM in (0.15, 0.25, 0.4, 0.6, 0.8, 1.0, 1.3, 1.5):
        U = speed(rMM, kmh, theta)
        h0, hw, s = rule(rMM, U, wet)
        V = P['shapeK'] * rMM ** 3
        lost = 4 / 3 * h0 * hw * 10 / V if V > 0 else 0
        print('  %5.2f  %7.1f  %7.2f   %-6s  %6.3f  %6.1f   %5.1f %%' % (
            rMM, U * 1000, s, 'yes' if h0 > 0 else 'dry', hw, h0 * 1000, 100 * lost))
