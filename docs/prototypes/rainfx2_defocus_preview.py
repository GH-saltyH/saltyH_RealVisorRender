# rev5 preview: pupil (aperture) defocus + physical refraction. Mirrors visor.hlsl rev5.
import numpy as np, sys
from PIL import Image
from scipy.ndimage import gaussian_filter
bgp=sys.argv[1]; out=sys.argv[2]; aps=[float(a) for a in sys.argv[3].split(',')]
W,H=960,540
B=np.asarray(Image.open(bgp).convert('RGB').resize((W,H)),np.float32)/255
B=B**2.2
pxmm=14.0; fovY=np.radians(60); fovK=1/(2*np.tan(fovY/2))
rng=np.random.default_rng(5); N=1400
cx=rng.uniform(0,W,N); cy=rng.uniform(0,H,N)
r=np.clip(rng.exponential(0.30,N),0.05,2.2)   # radius mm
seed=rng.integers(0,16,N)
yy,xx=np.mgrid[0:H,0:W].astype(np.float32)
def blur(img,s): return np.stack([gaussian_filter(img[...,i],s) for i in range(3)],-1) if s>0.3 else img
lum=lambda c:(c*[0.2126,0.7152,0.0722]).sum(-1)
def render(ap, bevel=1.0, domeK=0.25, aspect=0.5, maxH=1.2, contour=0.12, gain=1.0):
    rb=max(ap*0.5, 0.7/pxmm)
    F=np.zeros((H,W)); Sx=np.zeros((H,W)); Sy=np.zeros((H,W)); S2=np.zeros((H,W)); L=np.zeros((H,W)); G=np.zeros((H,W))
    for i in range(N):
        R=(r[i]*(1+contour)+rb)*pxmm
        x0,x1=int(max(cx[i]-R,0)),int(min(cx[i]+R+1,W)); y0,y1=int(max(cy[i]-R,0)),int(min(cy[i]+R+1,H))
        if x0>=x1 or y0>=y1: continue
        dx=(xx[y0:y1,x0:x1]-cx[i])/pxmm; dy=(yy[y0:y1,x0:x1]-cy[i])/pxmm
        d=np.hypot(dx,dy)+1e-6; ux,uy=dx/d,dy/d
        a=np.arctan2(dy,dx); ph=np.modf(np.array([.137,.611,.853])*(seed[i]+1)*7.31)[0]*6.2832
        rE=r[i]*(1+contour*(0.55*np.sin(2*a+ph[0])+0.3*np.sin(3*a+ph[1])+0.15*np.sin(5*a+ph[2])))
        lo=np.abs(rE-rb); hi=rE+rb
        t=np.clip((hi-d)/np.maximum(hi-lo,1e-6),0,1); f=t*t*(3-2*t)*np.minimum(1,(rE/rb)**2)
        dc=0.5*(np.maximum(d-rb,-rE)+np.minimum(d+rb,rE))   # signed centroid along dir
        ad=np.abs(dc); sg=np.sign(dc)
        e=np.minimum(bevel,rE); xr=np.clip((rE-ad)/e,0,1); hg=min(r[i]*aspect,maxH); q=np.clip(ad/rE,0,1)
        sm=hg*6*xr*(1-xr)/e+hg*domeK*2*q/rE; sm=sm/np.maximum(1,sm/1.5)
        sx=-ux*sg*sm; sy=-uy*sg*sm
        sl=sm
        F[y0:y1,x0:x1]+=f; Sx[y0:y1,x0:x1]+=f*sx; Sy[y0:y1,x0:x1]+=f*sy; S2[y0:y1,x0:x1]+=f*sl*sl
        L[y0:y1,x0:x1]+=f*np.clip((sl-1.0)/0.6,0,1)
        fac=np.clip(-sy/np.maximum(sl,1e-6),0,1)    # screen up = -y
        G[y0:y1,x0:x1]+=f*fac**4*np.clip((sl-0.5)/0.6,0,1)
    n=np.maximum(F,1e-6); Fc=np.clip(F,0,1)
    mx,my=Sx/n,Sy/n; sp=np.sqrt(np.maximum(S2/n-mx*mx-my*my,0))
    th=0.333*gain
    ox=mx*th*fovK*H; oy=my*th*fovK*H        # px offset (texture mapped 1:1 to screen here)
    blurpx=sp*th*fovK*H*0.5+ap*0.0
    out=np.zeros_like(B)
    levels=[0,1,2,4,8,16,32]; Bl=[blur(B,s) for s in levels]
    lvl=np.clip(np.log2(np.maximum(blurpx,1))+1,0,len(levels)-1)
    li=np.floor(lvl).astype(int); lf=lvl-li; li2=np.minimum(li+1,len(levels)-1)
    px=np.clip(xx+ox,0,W-1).astype(int); py=np.clip(yy+oy,0,H-1).astype(int)
    cd=np.zeros_like(B)
    for k in range(len(levels)):
        m=(li==k)[...,None]*(1-lf)[...,None]+(li2==k)[...,None]*lf[...,None]*(li2!=li)[...,None]+(li==k)[...,None]*(li2==li)[...,None]*lf[...,None]
        cd+=Bl[k][py,px]*m
    Bb=Bl[5]
    l=np.maximum(lum(cd),1e-5); lb=np.maximum(lum(Bb),1e-5)
    cd=cd*(np.clip(l,lb*0.55,lb*1.45)/l)[...,None]
    cd=cd*(1-0.5*(L/n))[...,None]
    cd=cd+np.array([.6,.63,.66])*(0.45*G/n)[...,None]
    o=B*(1-Fc[...,None])+cd*Fc[...,None]
    return np.clip(o,0,1)**(1/2.2)
imgs=[render(a) for a in aps]
Image.fromarray((np.concatenate(imgs,0)*255).astype(np.uint8)).save(out)
