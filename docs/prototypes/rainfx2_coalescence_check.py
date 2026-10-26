# rev6 check: one-drop-per-cell population with/without claim/merge coalescence (static visor,
# births only, sliding of large drops straight down). Mirrors claim.hlsl / merge.hlsl.
import numpy as np
from PIL import Image
W,H=160,64; cs=1.17; K=2.0944; rmax=2.2; vmax=K*rmax**3
rng=np.random.default_rng(1)
def radius(v): return np.cbrt(np.maximum(v,0)/K)
def step_births(P,V,lam,mean_d=0.6,stick=0.6):
    hit=rng.random((H,W))<lam
    d=np.clip(rng.exponential(mean_d,(H,W)),0.1,3.5); bv=0.5236*d**3*stick
    bp=rng.random((H,W,2))
    nv=V+bv*hit
    P[:]=np.where(hit[...,None],(P*V[...,None]+bp*(bv*hit)[...,None])/np.maximum(nv,1e-9)[...,None],P)
    V[:]=np.minimum(nv,vmax)
def slide(P,V):
    # drops above ~1.6 mm move down 0.5 cell/step; gather into dest cell (merge on meeting)
    r=radius(V); mv=(r>1.6)&(V>0)
    P2=P.copy(); P2[...,1]+=0.5*mv
    nV=np.zeros_like(V); nP=np.zeros_like(P)
    yy,xx=np.mgrid[0:H,0:W]
    dy=np.floor(P2[...,1]).astype(int); dx=np.floor(P2[...,0]).astype(int)
    ty=yy+dy; tx=xx+dx; ok=(V>0)&(ty>=0)&(ty<H)&(tx>=0)&(tx<W)
    np.add.at(nV,(ty[ok],tx[ok]),V[ok])
    np.add.at(nP,(ty[ok],tx[ok]),((P2-np.stack([dx,dy],-1))*V[...,None])[ok])
    V[:]=np.minimum(nV,vmax); P[:]=np.where(nV[...,None]>0,nP/np.maximum(nV,1e-9)[...,None],0.5)
def coalesce(P,V,k=1.0):
    r=radius(V); idx=np.arange(H*W).reshape(H,W).astype(float)
    bestV=np.zeros((H,W)); bestI=-np.ones((H,W)); best=np.zeros((H,W,2),int)
    for y in range(-2,3):
        for x in range(-2,3):
            if x==0 and y==0: continue
            Vs=np.full((H,W),0.0); Ps=np.zeros((H,W,2)); Is=np.full((H,W),-1.0)
            ys=slice(max(0,-y),H-max(0,y)); yd=slice(max(0,y),H-max(0,-y) if max(0,-y) else H)
            xs=slice(max(0,-x),W-max(0,x)); xd=slice(max(0,x),W-max(0,-x) if max(0,-x) else W)
            Vs[ys,xs]=V[yd,xd]; Ps[ys,xs]=P[yd,xd]; Is[ys,xs]=idx[yd,xd]
            d=np.hypot((x+Ps[...,0]-P[...,0])*cs,(y+Ps[...,1]-P[...,1])*cs)
            rank=(Vs>V)|((Vs==V)&(Is>idx))
            ok=(V>0)&(Vs>0)&rank&(d<k*(r+radius(Vs)))
            better=ok&((Vs>bestV)|((Vs==bestV)&(Is>bestI)))
            bestV=np.where(better,Vs,bestV); bestI=np.where(better,Is,bestI)
            best[better]=(x,y)
    claimed=bestI>=0
    nV=np.where(claimed,0,V); nP=P*nV[...,None]
    yy,xx=np.mgrid[0:H,0:W]
    ty=yy+best[...,1]; tx=xx+best[...,0]
    np.add.at(nV,(ty[claimed],tx[claimed]),V[claimed])
    np.add.at(nP,(ty[claimed],tx[claimed]),((P+best)*V[...,None])[claimed])
    V[:]=np.minimum(nV,vmax); P[:]=np.where(nV[...,None]>0,np.clip(nP/np.maximum(nV,1e-9)[...,None],-0.75,1.749),0.5)
    # relocation (P1 gather) for off-cell centroids
    slide_reloc(P,V)
def slide_reloc(P,V):
    P0=P.copy(); P0[...,1]-=0  # no motion, just relocate
    nV=np.zeros_like(V); nP=np.zeros_like(P)
    yy,xx=np.mgrid[0:H,0:W]
    dy=np.floor(P0[...,1]).astype(int); dx=np.floor(P0[...,0]).astype(int)
    ty=yy+dy; tx=xx+dx; ok=(V>0)&(ty>=0)&(ty<H)&(tx>=0)&(tx<W)
    np.add.at(nV,(ty[ok],tx[ok]),V[ok]); np.add.at(nP,(ty[ok],tx[ok]),((P0-np.stack([dx,dy],-1))*V[...,None])[ok])
    V[:]=nV; P[:]=np.where(nV[...,None]>0,nP/np.maximum(nV,1e-9)[...,None],0.5)
def run(coal,steps=600,lam=0.02):
    P=np.full((H,W,2),0.5); V=np.zeros((H,W))
    for i in range(steps):
        step_births(P,V,lam); slide(P,V)
        if coal: coalesce(P,V)
    return P,V
def draw(P,V,s=6):
    img=np.zeros((H*s,W*s)); yy,xx=np.mgrid[0:H*s,0:W*s]/s
    r=radius(V)/cs
    for y in range(H):
        for x in range(W):
            if V[y,x]<=0: continue
            cx,cy=x+P[y,x,0],y+P[y,x,1]; R=r[y,x]
            y0,y1=int(max((cy-R)*s,0)),int(min((cy+R)*s+1,H*s)); x0,x1=int(max((cx-R)*s,0)),int(min((cx+R)*s+1,W*s))
            sub=(xx[y0:y1,x0:x1]-cx)**2+(yy[y0:y1,x0:x1]-cy)**2<R*R
            img[y0:y1,x0:x1]=np.maximum(img[y0:y1,x0:x1],sub*(0.5+0.5*min(R/1.5,1)))
    return img
a=run(False); b=run(True)
for n,(P,V) in (('off',a),('on',b)):
    r=radius(V[V>0]); print(n,'drops',len(r),'cover %.2f'%(np.pi*(r**2).sum()/(H*W*cs*cs)),'r mean %.2f p90 %.2f max %.2f'%(r.mean(),np.percentile(r,90),r.max()),'vol %.0f'%V.sum())
im=np.concatenate([draw(*a),np.ones((8,W*6)),draw(*b)],0)
Image.fromarray((im*255).astype(np.uint8)).save('rainfx2_coalescence_check.png')
