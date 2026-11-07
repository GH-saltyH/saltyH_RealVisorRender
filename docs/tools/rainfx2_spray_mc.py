"""S1b / S2a calibration Monte Carlo (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 9).
One-drop-per-cell visor patch (1.15 mm cells), spray droplets as Poisson arrivals of a lognormal DSD (median 0.09 mm,
sigma_g 2), merge on landing, neighbour coalescence when footprints touch, shedding above r_shed (0.35 mm at 240 km/h,
F-series U_c law). Spray on the visor ramps 0.002 -> 0.063 mm/s over 5 s (game values 130 -> 240 km/h, wetness 10 %,
linear road-water law) x 'scale'. Reference frame 337 (dense 0.2-0.5 mm drops at the onset of flow) <-> scale 0.05-0.1.
"""
import numpy as np, math, sys
rng=np.random.default_rng(1)
cs=1.15; NX,NY=120,60; A=cs*cs
shapeK=1.007; rmin=0.04
def rad(V): return np.cbrt(V/shapeK)
def run(scale, Dn=0.09, sg=2.0, T=5.0, fps=60, rshed=0.35, rnuc=None):
    s=math.log(sg)
    V=np.zeros((NY,NX)); px=rng.random((NY,NX)); py=rng.random((NY,NX))
    shed=0.0
    for f in range(int(T*fps)):
        t=f/fps
        mms=scale*(0.002+(0.063-0.002)*t/T)       # mm/s on the visor (game values 130->240 km/h)
        EV=math.pi/6*Dn**3*math.exp(4.5*s*s)
        N=mms/EV*A/fps                            # droplets per cell per frame (all sizes)
        n=rng.poisson(N,(NY,NX))
        idx=np.nonzero(n)
        for y,x in zip(*idx):
            for _ in range(min(n[y,x],8)):
                D=Dn*math.exp(s*rng.standard_normal()); v=math.pi/6*D**3
                if V[y,x]>0: V[y,x]+=v
                elif rad(v)>=rmin: V[y,x]=v; px[y,x]=rng.random(); py[y,x]=rng.random()
                # sub-visible on empty cell: lost to evaporation (kept small)
        # simple: merge if centres closer than r1+r2
        X=(np.arange(NX)[None,:]+px)*cs; Y=(np.arange(NY)[:,None]+py)*cs
        for dy,dx in ((0,1),(1,0)):
            ra=rad(V[:NY-dy,:NX-dx]); rb=rad(V[dy:,dx:])
            d=np.hypot(X[:NY-dy,:NX-dx]-X[dy:,dx:],Y[:NY-dy,:NX-dx]-Y[dy:,dx:])
            m=(V[:NY-dy,:NX-dx]>0)&(V[dy:,dx:]>0)&(d<ra+rb)
            ys,xs=np.nonzero(m)
            for y,x in zip(ys,xs):
                if V[y,x]>0 and V[y+dy,x+dx]>0:
                    V[y,x]+=V[y+dy,x+dx]; V[y+dy,x+dx]=0
        big=rad(V)>rshed; shed+=V[big].sum(); V[big]=0
    r=rad(V[V>0])
    dens=len(r)/(NX*NY*A)*100
    depth=V.sum()/(NX*NY*A)
    return dens, np.percentile(2*r,[10,50,90]), depth, shed/(NX*NY*A), (V>0).mean()
for sc in [1.0,0.3,0.1,0.05,0.02]:
    d,p,dep,sh,occ=run(sc)
    print(f'scale {sc:5.2f}: drops/cm2 {d:6.1f} occ {occ:.2f} diam p10/50/90 {p[0]:.3f}/{p[1]:.3f}/{p[2]:.3f} mm  retained {dep*1000:.1f} um  shed {sh*1000:.1f} um')
