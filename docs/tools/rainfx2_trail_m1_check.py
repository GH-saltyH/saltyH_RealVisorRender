"""Trail rule (common.hlsl r2TrailRule) vs the M1 aerodynamic trim radius on the visor (sphere helmet, kU 0.8, stagnation 35 deg).
RAINFX_V2_SPRAY_RAIN_REF.md section 15. usage: python rainfx2_trail_m1_check.py"""
import math
shapeK=2.0944; g=0.072; pin=0.18
def Uc(r): return 25*(shapeK*r**3/10)**-0.08
def rc_aero(ue, delta):
    k=1.2*2e-3/0.072; rc=3.0
    for _ in range(30):
        xb=0.6*rc/delta; u=ue*(xb*(2-xb) if xb<1 else 1)
        rc*=min(1, 12/max(k*u*u*rc,1e-9))**(1/3)
    return rc
def trail(r, v, wet, thR=28, wetK=0.35, widthK=0.5, LL=5, slope=0.45):
    th=math.radians(thR)*(1-wetK*wet); caS=th**3/(9*math.log(max(r*1e6,10))); ca=v/72
    s=ca/caS
    if s<=1: return s,0,0
    hw=0.5*widthK*r*math.sqrt(1-1/s); h=LL*r*ca**(2/3); return s,hw,min(h,0.5*hw*slope)
for kmh in (160,240):
    U=kmh/3.6; ue0=1.2*U; a=ue0/0.13; delta=2.4*math.sqrt(1.5e-5/a)*1000
    for thd in (35,60):
        ue=ue0*math.sin(math.radians(thd)); rcA=rc_aero(ue,delta)
        print(f"{kmh} km/h theta {thd}: ue {ue:.0f} m/s, M1 r_c {rcA:.2f} mm")
        for r in (0.15,0.25,0.4,0.6):
            ratio=(ue/Uc(r))**2; v=max(0.0864*(ratio-0.9),0)
            out=[]
            for wet in (0,1):
                s,hw,h=trail(r,v,wet); out.append(f"wet{wet}: s {s:.2f} 2hw {2*hw*1000:.0f}um h {h*1000:.0f}um")
            print(f"   r {r}: F/Fpin {ratio:.2f} v {v*100:.1f} cm/s | "+" | ".join(out)+("  [r > M1 r_c]" if r>rcA else ""))
