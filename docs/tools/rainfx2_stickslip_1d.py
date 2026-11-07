"""RAINFX_V2_SPRAY_RAIN_REF.md section 18 (J1): 1-D run of a drop over the defect field, current vs a sparse strong-defect tail."""
# J1 check: 1-D drop run over the defect field (common.hlsl r2Predict: pin x (1 + defPin (2 D - 1)), static / kinetic 0.9,
# v = 0.087 (F/Fpin_coat - pin) m/s (friction 0.3), T1 cross term) -- current field vs a sparse strong-defect tail.
import numpy as np, math
rng=np.random.default_rng(5)
def vnoise1d(n, scale, seed):
    r=np.random.default_rng(seed); g=r.random(int(n/scale)+3)
    x=np.arange(n)/scale; i=x.astype(int); f=x-i; f=f*f*(3-2*f)
    return g[i]*(1-f)+g[i+1]*f
L=4000; dx=0.01                     # mm grid, 40 mm track
D=vnoise1d(L,1.2/dx,1)              # existing defect field (1.2 mm)
D2=vnoise1d(L,0.4/dx,2)             # J1 sparse strong defects (0.4 mm)
def Uc(r): return 25*(2.0944*r**3/10)**-0.08
def run(r, u, kappa=0.0, p=0.15, T=3.0, I=0.15):
    phi0=(u/Uc(r))**2; x=1.0; t=0; dt=1/600; moving=False; stuck=0; stops=0; xs=[]
    tn=vnoise1d(int(T/dt)+10, (1/4.0)/dt, 3)*2-1
    nW=max(1,int(round(2*r/0.4)))    # strong defects averaged over the contact width
    for k in range(int(T/dt)):
        i=int(x/dx)%L
        pin=1+0.35*(2*D[i]-1)
        if kappa>0:
            js=[(i+int((-r+2*r*(j+0.5)/nW)/dx))%L for j in range(nW)]
            S=np.mean([max(0,(D2[j]-(1-p))/p)**2 for j in js])
            pin*=1+kappa*S
        phi=phi0*(1+2*I*tn[k]*1.7*0.4)   # u_e.u' cross term, RMS-matched
        lim=pin*(0.9 if moving else 1.0)
        if phi>lim:
            v=0.087*(phi-lim); 
            if not moving: moving=True
        else:
            if moving: stops+=1
            moving=False; v=0; stuck+=1
        x+=v*1000*dt
        if x>39: break
        t+=dt
    return phi0, (x-1)/max(t,dt)/1000, stuck*dt/max(t,dt), stops/max(t,dt)
for kmh,theta in ((200,50),(240,60)):
    u=1.2*kmh/3.6*math.sin(math.radians(theta))
    print(f"{kmh} km/h theta {theta}: u_e {u:.0f} m/s")
    for r in (0.1,0.2,0.4):
        a=run(r,u); b=run(r,u,kappa=4.0)
        print(f"  r {r}: F/Fpin {a[0]:.2f} | now: mean {a[1]*100:5.1f} cm/s stuck {a[2]*100:3.0f}% stops {a[3]:4.1f}/s | J1 (15% strong, x5): mean {b[1]*100:5.1f} cm/s stuck {b[2]*100:3.0f}% stops {b[3]:4.1f}/s")
print("--- scan (240 km/h theta 60 / 200 km/h theta 50)")
for kappa in (1.0,1.5,2.0,3.0):
    row=[]
    for kmh,theta in ((200,50),(240,60)):
        u=1.2*kmh/3.6*math.sin(math.radians(theta))
        for r in (0.1,0.2,0.4):
            b=run(r,u,kappa=kappa); row.append(f"{kmh}/{r}: {b[1]*100:4.1f}cm/s {b[2]*100:2.0f}% {b[3]:3.1f}/s")
    print(f"kappa {kappa}: "+" | ".join(row))
