"""Raindrop residue radius distribution (cells.hlsl impact cell): resA 0.5 / SZ1 resACoat 1.9 / SZ2 fragment law.
Marshall-Palmer-type DSD of weather.lua W.supply, impact speed sqrt(U^2+vt^2) x exposure. usage: python rainfx2_residue_mc.py [R mm/h]
RAINFX_V2_SPRAY_RAIN_REF.md section 14."""
import numpy as np, math, sys
rng=np.random.default_rng(1)
NG=160; dD=6.0/NG
def vt(D): return np.maximum(9.65-10.3*np.exp(-0.6*D),0.1)
def dsd(R):
    D0=0.895*R**0.21; lam=3.67/D0; mu=0
    for _ in range(40):
        mu=min(max(-0.016*lam*lam+1.213*lam-1.957,-1),6); lam=(3.67+mu)/D0
    D=(np.arange(NG)+0.5)*dD; n=D**mu*np.exp(-lam*D)
    return D,n,mu,lam
K0=58; resA=0.5; resB=0.4; fragA=0.88; lo,hi=0.35,3.0; shapeK=2.0944
def fragX(u):
    a=fragA; loP=lo**-a; hiP=hi**-a
    return (loP+(hiP-loP)*u)**(-1/a)
def run(R, U, expo, N=400000, label=''):
    D,n,mu,lam=dsd(R)
    vt0=vt(np.array([1.0]))[0]*0+ 6.5  # terminalSpeed placeholder (only for h2)
    h2=max(U*U-0,0)
    vr=np.sqrt(h2+vt(D)**2)
    St=1000*(D*1e-3)**2*vr/(18*1.8e-5*0.13); eta=np.where(vr>1,(St/(St+0.25))**2,1)
    w=n*vt(D)/vt(D)*vr*eta
    p=w/w.sum(); d=rng.choice(D,N,p=p)+ (rng.random(N)-0.5)*dD
    vImp=np.maximum(np.sqrt(U*U+vt(d)**2)*expo,0.3)
    We=13.8889*vImp**2*d; Re=1000*vImp*d; K=np.sqrt(We)*Re**0.25
    kr=np.minimum(K0/K,1)
    V=math.pi/6*d**3
    def r_of(v): return (v/shapeK)**(1/3)
    A=r_of(kr**0.5*V); B=r_of(kr**1.9*V)
    dc=d*kr**resB*fragX(rng.random(N))
    Vc=np.where(K<=K0, V, np.minimum(math.pi/6*dc**3, kr**0.5*V))
    C=r_of(Vc)
    out={}
    for nm,r in (('A old resA0.5',A),('B SZ1 1.9',B),('C SZ2 frag',C)):
        q=np.percentile(r,[50,90,99,99.9]); 
        out[nm]=r
        print(f"{label:22s} {nm:14s} p50 {q[0]:.3f} p90 {q[1]:.3f} p99 {q[2]:.3f} p99.9 {q[3]:.3f} max {r.max():.2f}  >0.5mm {np.mean(r>0.5)*100:5.2f}%  >0.7 {np.mean(r>0.7)*100:5.2f}%  >1.0 {np.mean(r>1.0)*100:5.3f}%")
    # impact rate per m2/s
    n0=R/(6*math.pi*1e-4*(n*D**3*vt(D)).sum()*dD)
    rate=(n0*w*dD).sum()
    print(f"{label:22s} impacts/m2/s (normal incidence) {rate:.0f}; meanD {np.mean(d):.2f} mm; P(d>2) {np.mean(d>2)*100:.1f}%")
    return out
R=float(sys.argv[1]) if len(sys.argv)>1 else 10
for U,e,lab in ((0,0.5,'rest e0.5'),(0,0.3,'rest e0.3'),(13.3,0.9,'48 km/h e0.9'),(66.7,0.9,'240 km/h e0.9')):
    run(R,U,e,label=f'R{R} {lab}')
