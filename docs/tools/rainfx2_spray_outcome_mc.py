"""RAINFX_V2_SPRAY_RAIN_REF.md section 16 (SP1): spray droplets through the rain impact outcome. usage: python rainfx2_spray_outcome_mc.py"""
# SP1 check: spray droplets (lognormal median 0.09 mm, sigma_g 2, <= 0.8 mm) landing with the rain impact outcome
# (Mundo K, Bird halves ignored, resA 0.5 stuck share, residue piece d (K0/K)^0.4 X, fragment law fragA 0.88 [0.35, 3]).
import numpy as np, math
rng=np.random.default_rng(2); N=400000
K0=58; shapeK=2.0944; rmin=0.04
def fragX(u,a=0.88,lo=0.35,hi=3.0):
    return (lo**-a+(hi**-a-lo**-a)*u)**(-1/a)
d=np.minimum(np.exp(np.log(0.09)+math.log(2.0)*rng.standard_normal(N)),0.8)
V=math.pi/6*d**3
r_whole=(V/shapeK)**(1/3)
print(f"S1b now (whole deposit): visible mass share {V[r_whole>=rmin].sum()/V.sum():.3f}, visible births per droplet {np.mean(r_whole>=rmin):.2f}, p50 r {np.median(r_whole[r_whole>=rmin]):.3f} mm")
for kmh in (100,150,200,250):
  for kv in (1.0,0.6):
    v=kmh/3.6*kv*0.9
    We=13.8889*v*v*d; Re=1000*v*d; K=np.sqrt(We)*Re**0.25; kr=np.minimum(K0/K,1)
    fRes=np.where(K>K0, kr**0.5, 1.0)
    dc=np.where(K>K0, d*kr**0.4*fragX(rng.random(N)), d)
    Vc=np.minimum(math.pi/6*dc**3, fRes*V)
    rc=(Vc/shapeK)**(1/3); vis=rc>=rmin
    stuck=(fRes*V).sum()
    print(f"{kmh} km/h x{kv}: splash {np.mean(K>K0)*100:4.0f}% | stuck {stuck/V.sum():.2f} of spray mass: visible drops {Vc[vis].sum()/V.sum():.3f}, sub-visible -> G {(stuck-Vc[vis].sum())/V.sum():.3f} | visible births per droplet {vis.mean():.3f}, p50 r {np.median(rc[vis]) if vis.any() else 0:.3f}")
