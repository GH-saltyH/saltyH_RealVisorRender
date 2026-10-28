"""Helmet aerodynamics for visor drops (docs/RAINFX_V2_REV46_REVIEW.md section 3).

Compares, per car speed / angle from the stagnation point / drop radius, the critical radius above
which a sessile drop is swept, under
  rev46 : tangential air = U sin(theta) x airSurface 0.15, drag 0.25 rho Cd pi r^2 u^2
  model : helmet ~ sphere (R_h), potential outer flow u_e = 1.5 U sin(theta),
          laminar stagnation boundary layer delta = 2.4 sqrt(nu / a), a = 1.5 U / R_h (Hiemenz),
          air at the drop top u_h = u_e * f(h / delta), f(x) = min(1, 2x - x^2), cap height h = 0.6 r,
          drag 0.25 rho Cd pi r^2 u_h^2  +  pressure-gradient force V rho u_e du_e/ds
          (du_e/ds = 1.5 U cos(theta) / R_h), against pinning 2 gamma r dcos.
Stagnation wander (buffeting): theta_eff = sqrt(theta^2 + sigma^2) as the typical instantaneous angle.
usage: python rainfx2_helmet_aero.py
"""
import math

rho, mu, gamma, dcos, Cd = 1.2, 1.8e-5, 0.072, 0.18, 1.0
nu = mu / rho
Rh = 0.13


def forces(U, th, r, model, sigma=0.0):
    V = 2.0944 * r ** 3                      # cap volume (m^3), hemisphere-ish
    pin = 2 * gamma * r * dcos
    if model == 'rev46':
        u = 0.15 * U * math.sin(th)
        return 0.25 * rho * Cd * math.pi * r * r * u * u, pin
    th = math.sqrt(th * th + sigma * sigma)
    ue = 1.5 * U * math.sin(th)
    a = 1.5 * U / Rh
    delta = 2.4 * math.sqrt(nu / a)
    x = 0.6 * r / delta
    uh = ue * min(1.0, 2 * x - x * x) if x < 1 else ue
    Fd = 0.25 * rho * Cd * math.pi * r * r * uh * uh
    Fp = V * rho * ue * 1.5 * U * math.cos(th) / Rh
    return Fd + Fp, pin


def rcrit(U, th, model, sigma=0.0):
    lo, hi = 1e-5, 5e-3
    if forces(U, th, hi, model, sigma)[0] <= forces(U, th, hi, model, sigma)[1]:
        return float('inf')
    for _ in range(50):
        m = 0.5 * (lo + hi)
        F, P = forces(U, th, m, model, sigma)
        if F > P:
            hi = m
        else:
            lo = m
    return hi * 1000


print('critical radius (mm) above which a drop is swept; delta = stagnation boundary layer')
for kmh in (50, 100, 200, 300):
    U = kmh / 3.6
    a = 1.5 * U / Rh
    print('%3d km/h  delta %.2f mm' % (kmh, 2.4 * math.sqrt(nu / a) * 1000))
    for deg in (2, 10, 20, 35, 50):
        th = math.radians(deg)
        r46 = rcrit(U, th, 'rev46')
        rm = rcrit(U, th, 'model')
        rw = rcrit(U, th, 'model', math.radians(10))
        print('   theta %2d deg   rev46 %6s   sphere+BL+dp/ds %6s   + wander 10 deg %6s' % (
            deg, '-' if r46 == float('inf') else '%.2f' % r46,
            '-' if rm == float('inf') else '%.2f' % rm, '-' if rw == float('inf') else '%.2f' % rw))
