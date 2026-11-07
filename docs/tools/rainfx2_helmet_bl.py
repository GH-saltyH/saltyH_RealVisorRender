"""Laminar boundary layer over the helmet front (sphere, potential outer flow u_e = 1.5 kU U sin(theta)) by Thwaites' method
with the Mangler (axisymmetric) form: theta_m^2 = 0.45 nu / (r0^2 u_e^6) int r0^2 u_e^5 ds, lambda = theta_m^2 u_e' / nu,
tau_w = mu u_e / theta_m l(lambda), l = (lambda + 0.09)^0.62, delta99 ~ theta_m x H-dependent factor (Blasius: 7.5 theta_m).
Prints delta(theta) / delta(0) (the shader table), tau_w shape, separation. docs/RAINFX_V2_SPRAY_RAIN_REF.md section 21.
usage: python rainfx2_helmet_bl.py"""
import math, numpy as np
R, nu = 0.13, 1.5e-5
def run(U):
    th = np.linspace(1e-4, math.radians(110), 4000); s = R * th
    ue = 1.5 * U * np.sin(th); r0 = R * np.sin(th); due = 1.5 * U * np.cos(th) / R
    integ = np.concatenate([[0], np.cumsum(0.5 * (r0[1:]**2 * ue[1:]**5 + r0[:-1]**2 * ue[:-1]**5) * np.diff(s))])
    tm2 = 0.45 * nu * integ / np.maximum(r0**2 * ue**6, 1e-30)
    tm2[0] = 0.45 * nu / (4 * due[0])                     # stagnation limit (axisymmetric: 0.45/(2*... ) -> 0.0566 nu/a scale)
    lam = tm2 * due / nu
    tm = np.sqrt(tm2)
    l = np.where(lam > -0.09, (lam + 0.09) ** 0.62, 0)
    tau = 1.8e-5 * ue / tm * l
    # delta99 / theta_m from the Thwaites H(lambda) (Cebeci & Bradshaw fit) -> approx delta99 = theta_m (H + 4.8) (Pohlhausen-like)
    H = np.where(lam >= 0, 2.61 - 3.75 * lam + 5.24 * lam**2, 2.088 + 0.0731 / (lam + 0.14))
    d99 = tm * (H + 4.8)
    return th, ue, tm, lam, tau, d99
for U in (44.4, 66.7):
    th, ue, tm, lam, tau, d99 = run(U)
    sep = th[np.argmax(lam < -0.09)] if np.any(lam < -0.09) else None
    print(f"U {U:.1f} m/s (kU 1): delta99 at stagnation {d99[1]*1000:.3f} mm, separation {math.degrees(sep):.0f} deg" if sep else "")
    for deg in (0, 15, 30, 45, 60, 75, 90, 100):
        i = np.argmin(abs(th - math.radians(max(deg, 0.01))))
        print(f"  theta {deg:3d}: u_e/U {ue[i]/U:.2f}  delta99 {d99[i]*1000:.3f} mm ({d99[i]/d99[1]:.2f} x stag)  tau_w/tau_45 {tau[i]/tau[np.argmin(abs(th-math.radians(45)))]:.2f}  lambda {lam[i]:+.3f}")
th, ue, tm, lam, tau, d99 = run(66.7)
knots = [d99[np.argmin(abs(th - math.radians(k * 15)))] / d99[1] for k in range(8)]
print("table delta(theta)/delta(0) at 0,15,...,105 deg:", ", ".join(f"{k:.3f}" for k in knots))
