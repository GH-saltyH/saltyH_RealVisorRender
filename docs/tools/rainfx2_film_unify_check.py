"""Unified thin-water rule check (docs/RAINFX_V2_FILM_UNIFY_RESEARCH.md). One surface, one contact-line law for every flat water
feature (trail line, remnant patch, sheet): a static film thinner than the puddle height e_c = 2 l_c sin(theta_r / 2) is
not an equilibrium on a partially wetting coat -- it retracts from its edges at the dewetting speed
V_d = (gamma / mu) theta^3 / (9 ln(W / lambda)) (Cox-Voinov / de Gennes; the same law as the trail threshold) and pinches
into beads; it persists only while supply q refills it faster: q >= h 2 V_d / W (the W1g 'fed' rule with the rate derived)."""
import math
lc = 2.7      # capillary length (mm), gravity normal to the face
for thr in (18, 28, 50):
    th = math.radians(thr)
    ec = 2 * lc * math.sin(th / 2)
    print(f"theta_r {thr:2d} deg: puddle height e_c {ec:.2f} mm (every film thinner than this dewets unless fed / flowing)")
    print("   feature            W mm   h mm |  V_d mm/s  unfed life ms | supply to hold it (mm/s)  (= rate x h, rate /s)")
    for name, W, h in (("trail line", 0.24, 0.026), ("thick trail", 0.5, 0.055), ("remnant patch", 2.0, 0.05),
                       ("lamella patch", 6.0, 0.04), ("sheet strip", 15.0, 0.15), ("wide sheet", 40.0, 0.3)):
        Vd = 72000.0 * th ** 3 / (9 * math.log(W * 1e6))
        life = W / (2 * Vd) * 1000
        rate = 2 * Vd / W
        print(f"   {name:16s} {W:6.2f} {h:6.3f} | {Vd:8.1f}  {life:10.1f}   | {h * rate:8.3f}  ({rate:.1f} /s)")

# Appendix (section 7): film speed and Furmidge mobility length vs car speed (shear tau = 1/2 rho Cf U^2, U = outer flow,
# gravity on a 30 deg face), and the flux-scheme speed cap of the current sheet pass.
print()
dcos = math.cos(math.radians(50)) - math.cos(math.radians(70))
for kmh in (0, 50, 110, 200, 240):
    U = kmh / 3.6; tau = 0.5 * 1.2 * 0.005 * U * U
    row = f"{kmh:3d} km/h tau {tau:5.2f} Pa |"
    for h in (0.02, 0.05, 0.1, 0.3):
        v = 0.5 * tau * h + 9.81 * 0.5 * h * h / 3
        Lc = 0.072 * dcos / (tau + 1000 * 9.81 * 0.5 * h * 1e-3) * 1000
        row += f"  h {h:.2f}: v {v:.3f} m/s, L_c {Lc:5.1f} mm"
    print(row)
print(f"flux CFL cap (0.24 texel / substep x 8 substeps x 60 fps x 0.59 mm): {0.24 * 0.59e-3 * 8 * 60:.3f} m/s")
