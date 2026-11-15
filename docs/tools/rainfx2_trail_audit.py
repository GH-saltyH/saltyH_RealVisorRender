"""Trail audit (docs/RAINFX_V2_TRAIL_REVIEW2.md). The current trail rule (common.hlsl r2TrailRule, defaults of init.lua) for
drops of radius r moving at v (physics.lua P.speed table of the chase), and what a physical residue does with it:
  current : a parabolic line of half-width hw, depth h0, pinned, visible while h > trailMinMM, decaying only by evaporation
            (trailEvapMMs, pearling off since PL1) -> a continuous lens 'rod' of length v x T_vis behind every trailing head;
  physics : a line whose apparent edge angle atan(2 h0 / hw) is below the receding angle cannot stay -- its contact lines
            recede at the dewetting speed V_d = (gamma / mu) theta_r^3 / (9 ln(hw / lambda)) (the same Cox-Voinov law that
            decides the trail), so it breaks within t_b ~ hw / V_d into a row of beads (Rayleigh-Plateau, spacing ~9 hw)."""
import math
thR, wetK, LL, wK, slope, tMin, evap = 28.0, 0.35, 5.0, 0.5, 0.45, 0.012, 0.003
shapeK = 1.0076   # cap(60 deg)
def rule(r, v, wet):
    th = math.radians(thR) * (1 - wetK * wet)
    caS = th ** 3 / (9 * math.log(max(r * 1e6, 10)))
    ca = v / 72.0; s = ca / caS
    if s <= 1: return 0, 0, s, th
    hw = 0.5 * wK * r * math.sqrt(1 - 1 / s)
    h = min(LL * r * ca ** (2 / 3), 0.5 * hw * slope)
    return h, hw, s, th
# chase speeds (P.speed, 240 km/h; 110 km/h) and a sliding drop at rest
cases = [("240 km/h", [(0.2, 0.087), (0.3, 0.159), (0.5, 0.347), (1.0, 0.774)]),
         ("110 km/h", [(0.5, 0.014), (1.0, 0.088), (1.5, 0.186)]),
         ("rest, sliding", [(1.5, 0.045), (2.0, 0.08)])]
print("r mm  v m/s  wet | s=Ca/Ca*  hw mm  h0 um | now: T_vis s  rod mm  head path mm | phys: V_d mm/s  t_b ms  tail mm  bead r mm  spacing mm")
for name, rows in cases:
    print(name)
    for r, v in rows:
        for wet in (0.3, 0.8):
            h, hw, s, th = rule(r, v, wet)
            if h <= 0:
                print(f"  {r:.1f}  {v:.3f}  {wet:.1f} | {s:5.2f}  dry"); continue
            V = shapeK * r ** 3; lossPerMM = 4 / 3 * h * hw
            path = V / lossPerMM
            Tvis = max(h - tMin, 0) / evap
            rod = min(v * 1000 * Tvis, path) if h > tMin else 0
            Vd = 72.0 * th ** 3 / (9 * math.log(max(hw * 1e6, 10))) * 1000      # mm/s
            tb = hw / Vd * 1000
            lam = 9 * hw; rb = (lam * lossPerMM / shapeK) ** (1 / 3)
            print(f"  {r:.1f}  {v:.3f}  {wet:.1f} | {s:5.2f}  {hw:.3f}  {h*1000:5.1f} | {Tvis:5.1f}  {rod:6.0f}  {path:6.0f} | {Vd:6.1f}  {tb:5.1f}  {v*tb:5.1f}  {rb:.3f}  {lam:.2f}")
