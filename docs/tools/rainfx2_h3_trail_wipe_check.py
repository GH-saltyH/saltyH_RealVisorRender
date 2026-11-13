"""H3 trail wipe check (docs/RAINFX_V2_H3_ATLAS_SPEC.md section 8k).
A: haze regrowth on a wiped texel (haze.hlsl rules: supply, evaporation, E2 coarsening) at the chase-sim fine supply.
B: trail wipe completeness of the 5x5-cell window (hzm / haze / cells take-up look only at drops whose END cell is within
   +-2 cells of the texel's cell) for a drop moving M cells per frame (frame move <= substeps x gatherCells 1.95)."""
import math
sat = 0.0038; a = 0.015; K = math.pi / (1.0076 * a); pm = 0.55; kF = 0.38; dt = 1 / 60; tau = 0.5
print('A. regrowth after a full wipe (60 fps)')
for n, s, phS in [("Rain 240", 0.0042, 0.32), ("Thunderstorm 200", 0.0009, 0.11), ("Thunderstorm 240", 0.0067, 0.39),
                  ("Heavy Thunderstorm 240", 0.0108, 0.43), ("Heavy Rain 240", 0.0145, 0.41)]:
    g = 0; out = {}
    for i in range(1, 600):
        g *= math.exp(-kF * dt); g += s * dt
        rel = min(1 - math.exp(-K * g), pm) / pm; g -= g * (1 - math.exp(-dt / tau * rel * rel))
        ph = min(1 - math.exp(-K * g), pm)
        if i == 1: out['f1'] = ph
        for th in (0.1, 0.2, 0.5 * phS):
            if ph >= th and th not in out: out[th] = i
    print(f"  {n:24s} phiF after 1 frame {out['f1']:.3f} | 0.1 @{out.get(0.1,'-')} f, 0.2 @{out.get(0.2,'-')} f, "
          f"half of the surround ({0.5*phS:.2f}) @{out.get(0.5*phS,'-')} f")
cell = 1.176; tex = cell / 4; r = 0.5; rIn = r + 0.1; rOut = r * 1.5 + 0.4
def segd(p, a, b):
    ab = (b[0] - a[0], b[1] - a[1]); L = ab[0] ** 2 + ab[1] ** 2
    t = 0 if L == 0 else max(0, min(1, ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / L))
    return math.hypot(p[0] - a[0] - t * ab[0], p[1] - a[1] - t * ab[1])
print('B. haze left in the trail core of an r 0.5 mm drop (no regrowth)')
for M in (1.5, 2.3, 3.0, 3.9, 4.9, 7.8):
    ang = math.radians(20); step = (M * cell * math.sin(ang), M * cell * math.cos(ang))
    G = {}; pos = (10.3 * cell, 10.4 * cell)
    for f in range(30):
        a0 = pos; b = (pos[0] + step[0], pos[1] + step[1]); pos = b
        cb = (int(b[0] // cell), int(b[1] // cell))
        for ty in range(int((min(a0[1], b[1]) - rOut) // tex), int((max(a0[1], b[1]) + rOut) // tex) + 1):
            for tx in range(int((min(a0[0], b[0]) - rOut) // tex), int((max(a0[0], b[0]) + rOut) // tex) + 1):
                p = ((tx + .5) * tex, (ty + .5) * tex); ct = (int(p[0] // cell), int(p[1] // cell))
                if max(abs(ct[0] - cb[0]), abs(ct[1] - cb[1])) > 2: continue
                d = segd(p, a0, b); x = min(max((d - rIn) / (rOut - rIn), 0), 1)
                G[(tx, ty)] = G.get((tx, ty), 1.0) * (x * x * (3 - 2 * x))
    st = (10.3 * cell + 2 * step[0], 10.4 * cell + 2 * step[1]); en = (10.3 * cell + 28 * step[0], 10.4 * cell + 28 * step[1])
    core = [G.get((tx, ty), 1.0) for ty in range(int(st[1] // tex), int(en[1] // tex))
            for tx in range(int((st[0] - 3) // tex), int((en[0] + 3) // tex))
            if segd(((tx + .5) * tex, (ty + .5) * tex), st, en) <= r]
    print(f"  move {M:.1f} cells/frame ({M*cell*60/1000:.2f} m/s): haze left {sum(core)/len(core):.2f}, "
          f"untouched texels {sum(1 for g in core if g > 0.99)/len(core):.0%}")

# C. T1 (section 8m): the same path, swept per substep (wm.hlsl: cumulative segment, +-2 cell window around each substep
#    end, 4-bit union) vs the frame-end gather
def run(M, ns, mode):
    ang = math.radians(20); step = (M * cell * math.sin(ang), M * cell * math.cos(ang)); G = {}; pos = (10.3 * cell, 10.4 * cell)
    for f in range(30):
        a0 = pos
        ends = [(a0[0] + step[0] * (i + 1) / ns, a0[1] + step[1] * (i + 1) / ns) for i in range(ns)] if mode == 'T1' else [(a0[0] + step[0], a0[1] + step[1])]
        U = {}
        for b in ends:
            cb = (int(b[0] // cell), int(b[1] // cell))
            for ty in range(int((min(a0[1], b[1]) - rOut) // tex), int((max(a0[1], b[1]) + rOut) // tex) + 1):
                for tx in range(int((min(a0[0], b[0]) - rOut) // tex), int((max(a0[0], b[0]) + rOut) // tex) + 1):
                    p = ((tx + .5) * tex, (ty + .5) * tex); ct = (int(p[0] // cell), int(p[1] // cell))
                    if max(abs(ct[0] - cb[0]), abs(ct[1] - cb[1])) > 2: continue
                    x = min(max((segd(p, a0, b) - rIn) / (rOut - rIn), 0), 1); s = 1 - x * x * (3 - 2 * x)
                    u = U.get((tx, ty), 0)
                    U[(tx, ty)] = round((1 - (1 - u) * (1 - round(s * 15) / 15)) * 15) / 15 if mode == 'T1' else 1 - (1 - u) * (1 - s)
        for kk, u in U.items(): G[kk] = G.get(kk, 1.0) * (1 - u)
        pos = ends[-1]
    st = (10.3 * cell + 2 * step[0], 10.4 * cell + 2 * step[1]); en = (10.3 * cell + 28 * step[0], 10.4 * cell + 28 * step[1])
    core = [G.get((tx, ty), 1.0) for ty in range(int(st[1] // tex), int(en[1] // tex))
            for tx in range(int((st[0] - 3) // tex), int((en[0] + 3) // tex)) if segd(((tx + .5) * tex, (ty + .5) * tex), st, en) <= r]
    return sum(core) / len(core), sum(1 for g in core if g > 0.99) / len(core)
print('C. T1 substep wipe mask vs frame-end gather')
for M, ns in ((3.9, 2), (4.9, 3), (7.8, 4)):
    for mode in ('frame', 'T1'):
        l, u = run(M, ns, mode)
        print(f"  move {M} cells/frame, {ns} substeps, {mode:5s}: haze left {l:.3f}, untouched {u:.0%}")
