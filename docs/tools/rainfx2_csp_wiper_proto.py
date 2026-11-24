"""CSP windscreen rain + wiper water-path prototype (docs/RAINFX_V2_CSP_WIPER_STUDY.md; checked against the DXBC of
lights-patch-v0.3.1-preview2 dwrite.dll, section 4 of the study).

A NumPy re-implementation of the logic of the CSP windscreen rain (acc-shaders `custom/particles/windscreen/pfxWindscreen_*`
and `custom/rain/accRainWindscreen_*`), simplified to a flat 2D windscreen in its UV space:

  particles (pfxWindscreen_cs_simulate)  drops: pos, velocity, size, sticky, life, moved (pushed by a wiper), squished
    - acceleration = projected world velocity (air + gravity) + noise side push; a drop is held while sticky > 0;
      sticky decays with time, local water velocity, local density; size shrinks with the distance moved
    - "force moving raindrops to trails of other raindrops": sample trail(v) = sat(z - 2a) ahead-left / ahead-right
      and steer toward the wetter side
    - under a wiper: moving blade -> the drop is pushed with 5-25 % of the blade velocity (moved); 0.2 % become
      'squished' (dragged with the blade, leave a dirty trail); a drop hit by the blade adds dirt to the blade's
      1D dirt buffer at its blade position (rwWiperDirt)
  water map (pfxWindscreen_ps + accRainWindscreen_move / waterFade)  RGBA: xy = drop velocity, z = water left (trail),
    a = drops now. Every frame: advect by the velocity field (x 0.002), a = sat(a 1.08 - 0.04) - 0.005 (drops
    disappear fast), z fades slowly with a noise-varied rate and is cleared under the blade (x (1 - wiper.a));
    the particles are splatted on top (z = 1 for drops not pushed by the wiper, a = 1)
  wiper traces (accRainWindscreen_finalizeTraces)  x = max(new, previous - fadeSlow - wiperNow x fadeFast x 10 + edge):
    new = lerp(0.1, 0.5, noise(blade position, time)) x dirt(blade position) x [the blade was here last frame] x 0.7
    -> thin water streaks parallel to the blade motion behind a dirty blade, + a bow wave at the edge of the sweep
  surface for the lens = max(z, traces), normals from its gradient (accRainWindscreen_finalize)

usage: python rainfx2_csp_wiper_proto.py out_dir
"""
import os
import sys
import numpy as np
from scipy import ndimage
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

W, H = 480, 270                    # water map (UV of the windscreen)
FPS = 60.0
DT = 1.0 / FPS
RNG = np.random.default_rng(7)
SCALE = 1.0                        # gScale
NOISE = ndimage.gaussian_filter(RNG.random((H, W)), 3)
NOISE = (NOISE - NOISE.min()) / (NOISE.max() - NOISE.min())
NOISE1D = ndimage.gaussian_filter1d(RNG.random(512), 2)
NOISE1D = (NOISE1D - NOISE1D.min()) / (NOISE1D.max() - NOISE1D.min())

# wiper: one blade, pivot below the screen, sweeping +-50 deg, 1.1 s per sweep
PIVOT = np.array([0.30, -0.15])    # uv (y up)
R0, R1 = 0.25, 0.95                # blade from / to (uv units from the pivot)
SWEEP = np.radians(50)
PERIOD = 2.2
DIRT_CHANCE = 0.005                # 0.3.1-preview2 pfxWindscreen_cs_simulate: dirt / squish chance is a parameter (cb8[7].w)


def wiper_angle(t, on):
    if not on:
        return None
    ph = (t % PERIOD) / PERIOD
    s = -np.cos(2 * np.pi * ph)                    # -1 .. 1 .. -1
    return np.radians(5) + SWEEP * (s + 1)          # 5 .. 105 deg


def wiper_map(ang, ang_prev):
    """a = blade coverage, vx / vy = blade velocity (uv/s), z = position along the blade (0..1)."""
    a = np.zeros((H, W)); vx = np.zeros((H, W)); vy = np.zeros((H, W)); z = np.zeros((H, W))
    if ang is None:
        return a, vx, vy, z
    ys, xs = np.mgrid[0:H, 0:W]
    u = (xs + 0.5) / W
    v = 1 - (ys + 0.5) / H
    dx, dy = (u - PIVOT[0]) * (W / H), v - PIVOT[1]           # square metric
    rr = np.hypot(dx, dy)
    th = np.arctan2(dy, dx)
    d_th = np.angle(np.exp(1j * (th - (np.pi - ang))))
    width = 0.012 / np.maximum(rr, 0.05)                      # ~0.012 uv wide rubber
    cov = (np.abs(d_th) < width) & (rr > R0) & (rr < R1)
    a[cov] = 1
    omega = -(ang - ang_prev) / DT                            # rad/s, sign: rotation of the blade
    vxx = -np.sin(th) * rr * omega / (W / H)
    vyy = np.cos(th) * rr * omega
    vx[cov] = vxx[cov]; vy[cov] = -vyy[cov]                   # map y goes down
    z[cov] = ((rr - R0) / (R1 - R0))[cov]
    return a, vx, vy, z


class Drops:
    def __init__(self, n=6000):
        self.pos = np.zeros((n, 2)); self.vel = np.zeros((n, 2)); self.size = np.zeros(n); self.sticky = np.zeros(n)
        self.life = np.zeros(n); self.moved = np.zeros(n); self.squished = np.zeros(n); self.rand = RNG.random(n)

    def emit(self, count):
        dead = np.flatnonzero(self.life <= 0)[:count]
        k = len(dead)
        self.pos[dead] = RNG.random((k, 2))
        self.vel[dead] = 0
        self.size[dead] = RNG.random(k) * 1.1
        self.sticky[dead] = np.where(RNG.random(k) < 0.6, 1 - 0.8 * RNG.random(k) ** 2, 0)
        self.life[dead] = 7.0
        self.moved[dead] = 0; self.squished[dead] = 0; self.rand[dead] = RNG.random(k)


def sample(img, p):
    """bilinear sample at uv p (N, 2), x right, y down."""
    x = np.clip(p[:, 0] * W - 0.5, 0, W - 1.001); y = np.clip(p[:, 1] * H - 0.5, 0, H - 1.001)
    return ndimage.map_coordinates(img, [y, x], order=1, mode='nearest')


def run(seconds=8.0, wipers_from=2.0, air=np.array([0.05, -0.1]), grav=np.array([0.0, 0.9]), out=None):
    """air / grav: projected accelerations in uv/s^2 (y down). Returns frames to render."""
    D = Drops()
    vel = np.zeros((H, W, 2)); z = np.zeros((H, W)); a = np.zeros((H, W)); traces = np.zeros((H, W))
    dirt = np.zeros(256)
    wprev = np.zeros((H, W)); wz_prev = np.zeros((H, W))
    ang_prev = wiper_angle(0, False)
    frames = {}
    n = int(seconds * FPS)
    for i in range(n):
        t = i * DT
        on = t >= wipers_from
        ang = wiper_angle(t, on)
        wa, wvx, wvy, wz = wiper_map(ang, ang_prev if ang_prev is not None else ang)
        ang_prev = ang
        D.emit(12)
        alive = D.life > 0
        # --- water map: move pass (advect by velocity, drop coverage fades fast) + waterFade (trail z) ---
        ys, xs = np.mgrid[0:H, 0:W]
        src_y = ys + vel[..., 1] * 0.002 * H; src_x = xs + vel[..., 0] * 0.002 * W
        a = ndimage.map_coordinates(a, [src_y, src_x], order=1, mode='constant')
        speed = np.hypot(vel[..., 0], vel[..., 1])
        a = np.clip(a * 1.08 - 0.04, 0, 1) - 0.005 * (1 - np.clip(speed, 0, 1))
        a = np.clip(a, 0, 1)
        fade = np.where(NOISE * 30 - 10 > 0.5, 0.02, 0.004)       # gFadeFast / gFadeNormal by noise
        z = np.maximum(z - fade, 0) * (1 - wa)
        vel *= 0
        # --- particles ---
        idx = np.flatnonzero(alive)
        p = D.pos[idx]
        wa_p = sample(wa, p); wvx_p = sample(wvx, p); wvy_p = sample(wvy, p); wz_p = sample(wz, p)
        under = wa_p > 0.5
        wv = np.stack([wvx_p, wvy_p], 1)
        fast = np.hypot(wv[:, 0], wv[:, 1]) > 0.02
        # dirt: a drop hit by the moving blade (0.2 %) adds to the blade's dirt at its position
        hit = under & fast & ((D.rand[idx] * 77.2527 + 0.69199) % 1 < DIRT_CHANCE)   # 0.3.1-preview2: chance = cb8[7].w (repo: fixed 0.2 %)
        np.add.at(dirt, np.clip((wz_p[hit] * 255).astype(int), 0, 255), np.clip((wv[hit] ** 2).sum(1) - 0.0, 0, 0.25) + 0.25)
        push = under & fast
        k = idx[push]
        frac = 0.05 + 0.20 * (D.rand[k] * 3773.79 % 1)
        D.vel[k] = wv[push] * frac[:, None] + D.vel[k] * (1 / (1 + DT * 40))
        D.pos[k] += 1.5 * wv[push] * DT
        D.moved[k] = 1; D.sticky[k] = 0
        stop = idx[under & ~fast]
        D.vel[stop] = 0; D.sticky[stop] = 1; D.life[stop] -= DT
        free = idx[~under]
        D.moved[free] = np.clip(D.moved[free] - 0.5, 0, 1)
        # free drops: gravity + air, noise side push, sticky, trail attraction
        f = free[D.moved[free] == 0]
        if len(f):
            pf = D.pos[f]
            accel = np.tile(air + grav, (len(f), 1))
            nz = sample(NOISE, pf * 2.3 % 1) * 2 - 1
            side = np.stack([-accel[:, 1], accel[:, 0]], 1) / max(np.linalg.norm(air + grav), 1e-6)
            accel += side * (np.sign(nz) * np.clip(np.abs(nz) * 5 - 3.5, 0, 1))[:, None] * np.linalg.norm(air + grav) * 0.6
            adir = accel / np.maximum(np.linalg.norm(accel, axis=1, keepdims=True), 1e-9)
            perp = np.stack([adir[:, 1], -adir[:, 0]], 1)
            trail = np.clip(z - 2 * a, 0, 1)
            trail_b = ndimage.gaussian_filter(trail, 2)
            c = pf + adir * 0.02
            tl = sample(trail_b, c + perp * 0.01); tr = sample(trail_b, c - perp * 0.01)
            accel += perp * (tl - tr)[:, None] * 2.0                 # steer to the wetter side (trails of other drops)
            locv = sample(np.hypot(vel[..., 0], vel[..., 1]), pf)
            dens = np.clip(sample(ndimage.gaussian_filter(a, 4), pf) * 2.5 - 1.5, 0, 1)
            loosen = 0.1 + 1.7 * D.size[f]
            D.sticky[f] = np.clip(D.sticky[f] - DT * 0.15 - np.clip(locv * 3 * loosen - 0.1, 0, None) - dens * 0.02 * loosen
                                  - np.maximum(np.linalg.norm(accel, axis=1) * 0.004 - 0.001, 0) * 3, -0.2, 1)
            free_go = D.sticky[f] <= 0
            D.vel[f] = D.vel[f] / (1 + 20 * dens[:, None] * DT)
            D.vel[f] += np.where(free_go[:, None], accel * 1.0, 0) * DT
            D.size[f] = np.maximum(D.size[f] - np.linalg.norm(D.vel[f], axis=1) * DT * 3, 0)
            mv = D.vel[f] * DT
            D.pos[f] += mv
        D.life[idx] -= DT * 0.25
        out_ = (D.pos[:, 0] < 0) | (D.pos[:, 0] > 1) | (D.pos[:, 1] < 0) | (D.pos[:, 1] > 1) | (D.size < 0.02)
        D.life[out_] = 0
        # --- splat the drops into the water map (z = water, a = drop now, xy = velocity) ---
        idx = np.flatnonzero(D.life > 0)
        px = (D.pos[idx, 0] * W).astype(int); py = (D.pos[idx, 1] * H).astype(int)
        rad = np.clip((0.6 + 2.2 * D.size[idx]) * 1.3, 0.6, 4).astype(int)
        moving = D.moved[idx] > 0.1
        for r in np.unique(rad):
            sel = rad == r
            for oy in range(-r, r + 1):
                for ox in range(-r, r + 1):
                    if ox * ox + oy * oy > r * r:
                        continue
                    yy = np.clip(py[sel] + oy, 0, H - 1); xx = np.clip(px[sel] + ox, 0, W - 1)
                    a[yy, xx] = 1
                    z[yy, xx] = np.maximum(z[yy, xx], np.where(moving[sel], 0, 0.98))
                    vel[yy, xx] = D.vel[idx[sel]] * 10
        # --- wiper traces (finalizeTraces): streaks behind a dirty blade + bow wave at the swept edge ---
        bladePos = np.clip((wz_prev * 255).astype(int), 0, 255)
        nz1 = NOISE1D[((bladePos * 13) // 10 + int(t * 6)) % 512]
        dirtS = dirt[bladePos]
        new = (0.1 + 0.4 * nz1) * np.minimum(dirtS, 1) * np.clip(wprev * 10, 0, 1) * 0.7
        edge = np.clip(np.sqrt(ndimage.gaussian_filter(wa, 6)) - 0.2, 0, 1) * np.clip(ndimage.gaussian_filter(a, 3) * 10 - 0.1, 0, 1)
        traces = np.maximum(new, traces - 0.0015 - np.maximum(wprev, wa) * 0.02 * 10 + edge * 0.02 * 4)
        traces = np.clip(traces, 0, 1)
        dirt = np.maximum(0, dirt * 0.995 - 0.0005)
        wprev, wz_prev = wa, wz
        if out is not None and i in out:
            frames[i] = (z.copy(), a.copy(), traces.copy(), wa.copy(), dirt.copy())
    return frames


def background():
    yy, xx = np.mgrid[0:H, 0:W] / np.array([H, W])[:, None, None]
    sky = np.array([0.62, 0.70, 0.74]); road = np.array([0.20, 0.22, 0.24])
    m = 1 / (1 + np.exp(-(yy - 0.55) * 30))
    img = sky * (1 - m[..., None]) + road * m[..., None]
    for k in range(12):
        x0 = 0.05 + k * 0.08
        img[(np.abs(xx - x0) < 0.004) & (yy < 0.55) & (yy > 0.25)] = [0.3, 0.32, 0.33]
    img[np.abs(yy - 0.75 - 0.05 * np.sin(xx * 9)) < 0.006] = [0.85, 0.85, 0.8]
    return ndimage.gaussian_filter(img, (1.2, 1.2, 0))


def render(z, traces, wa):
    """accRainWindscreen_finalize: height = max(water, traces), normal from its gradient -> refraction."""
    hgt = np.maximum(ndimage.gaussian_filter(z, 1.0), traces * 0.6)
    gy, gx = np.gradient(hgt)
    bg = background()
    ys, xs = np.mgrid[0:H, 0:W]
    sx = np.clip(xs - gx * 60, 0, W - 1); sy = np.clip(ys - gy * 60, 0, H - 1)
    out = np.stack([ndimage.map_coordinates(bg[..., c], [sy, sx], order=1) for c in range(3)], -1)
    s2 = gx * gx + gy * gy
    out *= (1 - 0.6 * np.clip(s2 * 150, 0, 1))[..., None]
    out = out * (1 - 0.15 * np.clip(hgt, 0, 1)[..., None]) + 0.12 * np.clip(hgt, 0, 1)[..., None]
    out[wa > 0.5] = [0.05, 0.05, 0.05]                      # the blade
    return np.clip(out, 0, 1)


def main():
    od = sys.argv[1] if len(sys.argv) > 1 else '.'
    os.makedirs(od, exist_ok=True)
    picks = [int(s * FPS) for s in (1.9, 2.6, 3.2, 4.4, 5.4, 7.9)]
    fr = run(8.0, 2.0, out=set(picks))
    fig, axs = plt.subplots(3, 2, figsize=(14, 12))
    for ax, i in zip(axs.flat, picks):
        z, a, tr, wa, dirt = fr[i]
        ax.imshow(render(z, tr, wa)); ax.set_title(f't = {i / FPS:.1f} s ({"wiper on" if i / FPS >= 2 else "wiper off"})'); ax.axis('off')
    plt.tight_layout(); plt.savefig(os.path.join(od, 'csp_wiper_proto.png'), dpi=70)
    # layers of one frame after a sweep
    z, a, tr, wa, dirt = fr[picks[3]]
    fig, axs = plt.subplots(1, 4, figsize=(20, 3.6))
    for ax, img, ttl in zip(axs, (a, np.clip(z - 2 * a, 0, 1), tr, None),
                            ('a: drops now (fast fade)', 'trail(z - 2a): water left, drops steer to it', 'wiper traces (dirty blade streaks + edge)', 'blade dirt (1D, along the rubber)')):
        if img is None:
            ax.plot(dirt); ax.set_xlabel('blade position (0 = pivot end .. 255 = tip)')
        else:
            ax.imshow(img, cmap='magma', vmin=0, vmax=1); ax.axis('off')
        ax.set_title(ttl, fontsize=9)
    plt.tight_layout(); plt.savefig(os.path.join(od, 'csp_wiper_layers.png'), dpi=70)


if __name__ == '__main__':
    main()
