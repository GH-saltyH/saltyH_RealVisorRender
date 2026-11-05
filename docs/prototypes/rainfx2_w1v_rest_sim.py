"""W1v rest-state check (docs/RAINFX_V2_WATER_SHEET_PLAN.md 9.7): fixed environment, field-B rules of the shader port
(stamps + recoil + residual->drop, W1c thin diffusion, ResMMs onto h>=hc, keep / dissolve, connectivity, sheet flow with
Furmidge pin / front / smoothing, bead pass). Drops are not simulated (births are a sink only). Visor vertical, at rest,
intensity 1.0, exposure E. Usage: python rainfx2_w1v_rest_sim.py [variant]"""
import sys, numpy as np
rng = np.random.default_rng(1)
V = sys.argv[1] if len(sys.argv) > 1 else 'current'
NX, NY = 128, 128; tex = 0.58; cellk = 2                       # texel mm, texels per cell
dt = 1/60; T = float(sys.argv[2]) if len(sys.argv) > 2 else 30.0; E = 0.6
flux = 0.0278*E; stick = 0.613; filmRate = flux*(1-stick)*0.54; resMMs = flux*stick
D = 0.644; impRate = 0.0278/(np.pi*D**3)                        # per mm^2 per s (full exposure)
hc, keep, pinMM, front, thin, evap = 0.10, 0.04, 0.3, 0.22, 2.3*(68/60)**3, 0.003
fBk = 0.25*(0.4+0.6*0.8); th = np.radians(68); c, s = np.cos(th), np.sin(th)
gC = np.pi*(2-3*c+c**3)/(3*s**3); tau = min(0.12*(40/68)**3, 0.35)
h = np.zeros((NY, NX)); lams = []; drops_born = 0.0; added = 0.0
yy, xx = np.mgrid[0:NY, 0:NX]; X = (xx+0.5)*tex; Y = (yy+0.5)*tex
def stage(L, k):
    if k < 0: return 0.0
    e = 0.0 if k >= 23 else np.exp(-k*dt/tau)
    rho = L['rhoR'] + (1-L['rhoR'])*e; m = 1 - fBk*(1-e)
    a, b = L['a']*rho, L['b']*rho; cy = L['y'] + L['sh'] + (1-rho)*0.35*L['a']
    q = np.sqrt(((X-L['x'])/b)**2 + ((Y-cy)/a)**2)
    soft = 1 - np.clip((q-0.9)/0.2, 0, 1)
    w = soft; tot = w.sum()*tex*tex
    return m*L['v']*w/max(tot, 1e-9)                             # area-normalised (rim profile irrelevant for mass)
for f in range(int(T/dt)):
    # registry: new impacts (cells 2x2 texels)
    n = rng.poisson(impRate*E*NX*NY*tex*tex*dt)
    for _ in range(n):
        d = min(rng.exponential(D), 3.5); wD = d**3/(6*D**3)
        vU = filmRate/(impRate*E)*wD                           # unresolved water of this impact (mm^3)
        Rs = max(0.5*d*0.87*(1000*6*d)**0.2, 0.6*1.16); a, b = Rs*1.34, Rs/1.34
        kw = min(1, 2.2/(a*1.6)); a, b = a*kw, b*kw
        rc = (vU*(1-fBk)/gC)**(1/3)
        lams.append(dict(x=rng.uniform(0, NX*tex), y=rng.uniform(0, NY*tex), a=a, b=b, sh=0.15*Rs*0.8*kw,
                         rhoR=np.clip(rc/np.sqrt(a*b), 0.15, 1), v=vU, age=-1, vR=resMMs/(impRate*E)*wD))
    hP = h.copy()
    # connectivity (5x5 cells share of cells with mean >= hc)
    cm = hP.reshape(NY//2, 2, NX//2, 2).mean((1, 3)) >= hc
    from scipy.ndimage import uniform_filter, maximum_filter
    con_c = uniform_filter(cm.astype(float), 5, mode='constant') >= 1.3*np.pi*1.5**2/(25*1.344)
    con = np.kron(con_c, np.ones((2, 2))) > 0
    # W1c thin diffusion between thin neighbours
    thinm = hP < hc
    ex = np.zeros_like(h)
    for sy, sx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        hj = np.roll(hP, (sy, sx), (0, 1)); tj = np.roll(thinm, (sy, sx), (0, 1))
        ex += np.where(tj, hj-hP, 0)
    h = h + np.where(thinm, 0.25*0.6*ex, 0)
    # resolved rain onto h >= hc (W1g/W1u rule) -- cells births suppressed there
    if V not in ('noResOnPatch', 'both'):
        h += np.where(hP >= hc, resMMs*dt, 0); added += (hP >= hc).sum()*resMMs*dt*tex*tex
    else:
        h += np.where((hP >= hc) & con, resMMs*dt, 0)
    # stamps / recoil / residual -> drop
    lamHere = np.zeros_like(h, bool); keepL = []
    for L in lams:
        L['age'] += 1; k = L['age']
        if k == 0: added += L['v']
        kN = k
        if k == 23:
            kN = -1; drops_born += L['v']*(1-fBk)
        P = stage(L, kN) - stage(L, k-1)
        h += P; lamHere |= (stage(L, kN) > 0) if kN >= 0 else False
        if k < 23: keepL.append(L)
    lams = keepL; h = np.maximum(h, 0)
    # keep / dissolve
    ring = 0.25*(np.roll(hP, 2, 0)+np.roll(hP, -2, 0)+np.roll(hP, 2, 1)+np.roll(hP, -2, 1))
    sheetHere = (h >= hc) & con
    kp = (h >= hc) | ((h >= keep) & (h >= 1.3*ring)) | lamHere
    h = np.where(sheetHere, h, np.where(kp, np.maximum(h-evap*dt, 0), h*np.exp(-dt*thin)))
    # bead pass (W1t/W1v): cell mean >= keep, 5x5 max, patch texels (>=keep) inside inner 3x3 cells, rate 6/s
    if V in ('current', 'bead3x3', 'noResOnPatch', 'both'):
        cmn = h.reshape(NY//2, 2, NX//2, 2).mean((1, 3))
        ismax = (cmn >= keep) & (cmn >= maximum_filter(cmn, 5, mode='constant')) & (rng.random(cmn.shape) < 6*dt)
        for cy, cx in zip(*np.nonzero(ismax)):
            y0, x0 = (cy-2)*2, (cx-2)*2
            if y0 < 0 or x0 < 0 or y0+10 > NY or x0+10 > NX: continue
            win = h[y0:y0+10, x0:x0+10]; pm = win >= keep
            inner = np.zeros_like(pm); inner[2:8, 2:8] = True
            if V == 'current' and (pm & ~inner).any(): continue
            take = pm & inner
            drops_born += (win*take).sum()*tex*tex; win[take] = 0
    # sheet flow, gravity down (+y), 8 substeps
    for _ in range(8):
        hs = h; wet = False
        hRes = np.where(con, 0.0, pinMM); hm = np.maximum(hs-hRes, 0)
        v = np.minimum(3270*hm**2, 250)                       # mm/s
        o = np.minimum(v*dt/8/tex, 0.24)*hm
        dn = np.roll(hs, -1, 0); dnc = np.roll(con, -1, 0)
        o = np.where((dn < hc) & (hs < front), 0, o); o[-1, :] = o[-1, :]  # bottom edge drains
        h = hs - o + np.roll(o, 1, 0); h[0, :] = hs[0, :] - o[0, :]
        both = hs >= hc
        for sy, sx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            hj = np.roll(hs, (sy, sx), (0, 1)); bj = np.roll(both, (sy, sx), (0, 1))
            h += np.where(both & bj, 0.12*(hj-hs)/1, 0)/1
    if f % 300 == 299:
        print('%s t=%4.1fs  area h>=0.04 %4.1f%%  h>=0.1 %4.1f%%  h>=0.3 %4.1f%%  mean %.4f mm  drops born %.1f mm3' %
              (V, (f+1)*dt, 100*(h >= 0.04).mean(), 100*(h >= 0.1).mean(), 100*(h >= 0.3).mean(), h.mean(), drops_born))
np.save('/tmp/claude-0/h_%s.npy' % V, h)
