"""M3 size ceiling (docs/RAINFX_V2_MOTION_REVIEW.md section 7): the radius at which a resting drop starts to
move, per visor point, from the shader force law (rainfx2_visor_flowmap.force). A pinned drop grows by
coalescence (impacts, merges) until it reaches r_crit and leaves -> r_crit is the local size ceiling of the
resting population (the large-drop tail of the size distribution), independent of the supply.
Map: visor seen from the front, azimuth -70..70 deg (left = driver left), elevation 20..-30 deg.
usage: python rainfx2_rcrit_map.py out.png
"""
import math
import sys
import numpy as np
from PIL import Image, ImageDraw
import importlib.util

spec = importlib.util.spec_from_file_location('fm', __file__.rsplit('/', 1)[0] + '/rainfx2_visor_flowmap.py')
fm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fm)


def rcrit(phi, lam, U, elev, latG=0.0):
    lo, hi = 0.02, 3.0
    def moves(r):
        _, st = fm.force(phi, lam, U, r, elev, 0.0, latG)
        return st > 0
    if not moves(hi):
        return hi
    if moves(lo):
        return lo
    for _ in range(22):
        m = 0.5 * (lo + hi)
        if moves(m):
            hi = m
        else:
            lo = m
    return hi


def col(r):
    # r_crit mm -> colour: <= 0.2 blue, 0.5 green, 1.0 yellow, >= 1.5 red
    t = min(max((r - 0.1) / 1.4, 0.0), 1.0)
    stops = [(0, (40, 70, 200)), (0.3, (40, 180, 90)), (0.65, (240, 220, 40)), (1.0, (230, 50, 40))]
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            k = (t - t0) / (t1 - t0)
            return tuple(int(c0[i] + (c1[i] - c0[i]) * k) for i in range(3))
    return stops[-1][1]


def main(outp):
    cases = [(U, e) for U in (0.0, 24.4, 44.4, 69.4) for e in (12, 35)]
    W, H = 300, 110
    img = Image.new('RGB', (2 * (W + 10) + 10, 4 * (H + 34) + 40), (18, 18, 18))
    dr = ImageDraw.Draw(img)
    lines = []
    for k, (U, e) in enumerate(cases):
        ox, oy = 10 + (k % 2) * (W + 10), 10 + (k // 2) * (H + 34)
        nx, ny = 29, 11
        R = np.zeros((ny, nx))
        for j, ld in enumerate(np.linspace(20, -30, ny)):
            for i, phd in enumerate(np.linspace(-70, 70, nx)):
                R[j, i] = rcrit(math.radians(phd), math.radians(ld), U, math.radians(e))
        cw, ch = W / nx, H / ny
        for j in range(ny):
            for i in range(nx):
                dr.rectangle((ox + i * cw, oy + 16 + j * ch, ox + (i + 1) * cw, oy + 16 + (j + 1) * ch), fill=col(R[j, i]))
        txt = '%3.0f km/h stag %d: r_crit p50 %.2f mm, area r_crit>0.5 mm %2.0f%%' % (U * 3.6, e, np.median(R), 100 * np.mean(R > 0.5))
        dr.text((ox, oy), txt, fill=(230, 230, 230))
        lines.append(txt)
    y = 4 * (H + 34) + 14
    for i, (lab, r) in enumerate((('0.2', 0.2), ('0.5', 0.5), ('1.0', 1.0), ('>=1.5 mm', 1.5))):
        dr.rectangle((10 + i * 120, y, 30 + i * 120, y + 14), fill=col(r))
        dr.text((34 + i * 120, y + 1), lab, fill=(220, 220, 220))
    img.save(outp)
    print('\n'.join(lines))


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'rainfx2_rcrit_map.png')
