# Offline comparison: legacy Water-Field drop rule vs RainFX v2 (rev17) bevel rule.
# Same drops, same background, same screen mapping. docs/RAINFX_V2_WF_LENS_PLAN.md
import numpy as np, sys
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter, map_coordinates
bgp=sys.argv[1]; out=sys.argv[2]
W,H=1920,1080
B=(np.asarray(Image.open(bgp).convert('RGB').resize((W,H),Image.LANCZOS),np.float32)/255)**2.2
PXMM=20.0
rng=np.random.default_rng(7)
# drops: (x,y,r_mm,seed); a few touching pairs to show merging
D=[]
for i in range(70):
    D.append((rng.uniform(40,W-40),rng.uniform(40,H-40),float(np.clip(rng.lognormal(np.log(0.55),0.55),0.25,2.2)),int(rng.integers(0,16))))
for (x,y) in [(400,300),(1300,700),(900,450)]:
    D.append((x,y,1.4,3)); D.append((x+1.9*PXMM*1.1,y+8,1.0,9))
fog=np.array([0.62,0.66,0.70])**2.2
# mip pyramid approximated by gaussian blur at sigma 0.6*2^m (screen px, full-res)
MIPS=[B]+[np.stack([gaussian_filter(B[...,c],0.6*2**m) for c in range(3)],-1) for m in range(1,10)]
def sample(img_mips,x,y,mip):
    mip=np.clip(mip,0,9); m0=np.floor(mip).astype(int); f=mip-m0; m1=np.minimum(m0+1,9)
    out=np.zeros(x.shape+(3,),np.float32)
    for m in np.unique(np.concatenate([m0.ravel(),m1.ravel()])):
        w=np.where(m0==m,1-f,0)+np.where(m1==m,f,0)
        if not np.any(w): continue
        s=np.stack([map_coordinates(img_mips[m][...,c],[np.clip(y,0,H-1),np.clip(x,0,W-1)],order=1) for c in range(3)],-1)
        out+=s*w[...,None]
    return out
yy,xx=np.mgrid[0:H,0:W].astype(np.float32)
screenUp=np.array([0,-1.0])
def glint_facing(sx,sy,sl):
    f=np.clip((sx*screenUp[0]+sy*screenUp[1])/np.maximum(sl,1e-4),0,1); return f**4*np.clip((sl-0.5)/0.6,0,1)
def render_wf(lobes=True):
    # union U = 1 - prod(1-h_i); grad U = sum grad h_i prod_{j!=i}(1-h_j); radius code weighted by h
    P=np.ones((H,W),np.float32); Gx=np.zeros((H,W),np.float32); Gy=np.zeros((H,W),np.float32); RW=np.zeros((H,W),np.float32); HW=np.zeros((H,W),np.float32)
    def kern(cx,cy,R):
        Rk=1.24*R*PXMM; x0,x1=int(max(cx-Rk,0)),int(min(cx+Rk+1,W)); y0,y1=int(max(cy-Rk,0)),int(min(cy+Rk+1,H))
        dx=xx[y0:y1,x0:x1]-cx; dy=yy[y0:y1,x0:x1]-cy
        h=np.clip(1-(dx*dx+dy*dy)/(Rk*Rk),0,1); act=h>0
        gx=np.where(act,-2*dx/(Rk*Rk),0); gy=np.where(act,-2*dy/(Rk*Rk),0)
        sl=(slice(y0,y1),slice(x0,x1))
        Gx[sl]=Gx[sl]*(1-h)+gx*P[sl]; Gy[sl]=Gy[sl]*(1-h)+gy*P[sl]; P[sl]*=(1-h)
        RW[sl]+=h*R*PXMM; HW[sl]+=h
    for (x,y,r,s) in D:
        kern(x,y,r)
        if lobes and r>0.5:
            n=1+(s%2)
            for k in range(n):
                a=(s*2.39996+k*2.1)%(2*np.pi); kern(x+np.cos(a)*0.55*r*PXMM,y+np.sin(a)*0.55*r*PXMM,r*(0.45+0.1*k))
    U=1-P; Rpx=RW/np.maximum(HW,1e-6)
    sx=Gx*Rpx; sy=Gy*Rpx; sl=np.hypot(sx,sy)        # dimensionless, points to centre
    fw=np.abs(np.gradient(U,axis=0))+np.abs(np.gradient(U,axis=1))
    w=np.maximum(fw*0.75,0.004)
    inside=np.clip((U-(0.35-w))/(2*w),0,1); inside=inside*inside*(3-2*inside)
    ox=sx*0.69*H; oy=sy*0.69*H                      # REFRACTION 0.69 shot heights at slope 1 (aspect: square px)
    mip=3.0+1.5*np.clip(sl/1.5,0,1)
    c=sample(MIPS,xx+ox,yy+oy,mip)
    c*=(1-0.75*np.clip((sl-0.7)/0.6,0,1))[...,None]
    c+=fog*(0.45*glint_facing(sx,sy,sl))[...,None]
    return B*(1-inside[...,None])+c*inside[...,None]
def render_v2(bevel=1.5,domeK=0.25,contour=0.25,toneMin=0.85,dropVeil=0.2,edgeLoss=0.2):
    best=np.zeros((H,W),np.float32); cov=np.zeros((H,W),np.float32); sx=np.zeros((H,W),np.float32); sy=np.zeros((H,W),np.float32)
    for (x,y,r,s) in D:
        R=r*PXMM; Rk=R*(1+contour)+2; x0,x1=int(max(x-Rk,0)),int(min(x+Rk+1,W)); y0,y1=int(max(y-Rk,0)),int(min(y+Rk+1,H))
        dx=(xx[y0:y1,x0:x1]-x)/PXMM; dy=(yy[y0:y1,x0:x1]-y)/PXMM; d=np.hypot(dx,dy)+1e-6
        a=np.arctan2(dy,dx); ph=np.modf(np.array([.137,.611,.853])*(s+1)*7.31)[0]*6.2832
        rE=r*(1+contour*(0.55*np.sin(2*a+ph[0])+0.3*np.sin(3*a+ph[1])+0.15*np.sin(5*a+ph[2])))
        e=np.minimum(bevel,rE); xr=np.clip((rE-d)/e,0,1); hR=xr*xr*(3-2*xr)
        hg=min(r*0.5,1.2); q=np.clip(d/rE,0,1); h=hg*(hR+domeK*(1-q*q))
        sm=hg*6*xr*(1-xr)/e+hg*domeK*2*q/rE; sm=sm/np.maximum(1,sm/1.5)
        f=np.clip((rE-d)/(0.6/PXMM*2)+0.5,0,1)
        sl_=(slice(y0,y1),slice(x0,x1)); take=(h>best[sl_])&(f>0)
        best[sl_]=np.where(take,h,best[sl_]); cov[sl_]=np.maximum(cov[sl_],f)
        sx[sl_]=np.where(take,-dx/d*sm,sx[sl_]); sy[sl_]=np.where(take,-dy/d*sm,sy[sl_])
    sl=np.hypot(sx,sy)
    k=0.333*0.87*H                                     # physical (n-1) * fovK, screen px per unit slope
    c=sample(MIPS,xx+sx*k,yy+sy*k,np.full((H,W),0.5,np.float32))
    bg=MIPS[4]; lum=lambda v:(v*[0.2126,0.7152,0.0722]).sum(-1)
    l=np.maximum(lum(c),1e-5); lb=np.maximum(lum(bg),1e-5); lbUp=np.maximum(lb,lum(fog)*0.25)
    c=c*(np.clip(l,lb*toneMin,lbUp*1.45)/l)[...,None]
    c*=(1-edgeLoss*np.clip((sl-1.0)/0.6,0,1))[...,None]
    c+=fog*(0.45*glint_facing(sx,sy,sl))[...,None]
    veil=bg*0.75+fog*0.25
    c=c*(1-dropVeil)+veil*dropVeil
    return B*(1-cov[...,None])+c*cov[...,None]
imgs=[('v2 rev17 bevel 1.5',render_v2(1.5)),('v2 rev17 bevel 0.32',render_v2(0.32)),('legacy Water Field rule (dome union + lobes)',render_wf())]
tiles=[]
for t,a in imgs:
    im=Image.fromarray((np.clip(a,0,1)**(1/2.2)*255).astype(np.uint8)); ImageDraw.Draw(im).rectangle((0,0,520,34),fill=0); ImageDraw.Draw(im).text((10,8),t,fill=(255,255,0)); tiles.append(im)
o=Image.new('RGB',(W,H*3))
for i,t in enumerate(tiles): o.paste(t,(0,H*i))
o.resize((W//2,H*3//2)).save(out,quality=88)
# zoom strip
z=Image.new('RGB',(3*600,400))
for i,t in enumerate(tiles): z.paste(t.crop((1150,500,1750,900)),(600*i,0))
z.save(out.replace('.jpg','_zoom.jpg'),quality=90)
