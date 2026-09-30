# Water-field prototype: soft kernels -> union height (G), weighted size (R),
# threshold silhouette, slope-driven screen refraction (consistent rule).
import numpy as np
from PIL import Image, ImageDraw
from harness import *
scene=np.load('scene.npy'); mips=build_mips(scene)
TEX=2.5            # screen px per field texel (low-res look)
FW,FH=int(W/TEX),int(H/TEX)
rng=np.random.default_rng(7)
def kernel_alpha(r2,p=1.0): return np.clip(1-r2,0,1)**p
class Field:
    def __init__(s): s.G=np.zeros((FH,FW)); s.R=np.zeros((FH,FW)); s.B=np.zeros((FH,FW))
    def stamp(s,cx,cy,rx,ry=None,ang=0.0,size=None,energy=0.0,scale=1.24,amp=1.0):
        # cx,cy,rx,ry in field texels; visible radius ~ rx (threshold 0.35)
        ry=rx if ry is None else ry; ax,ay=rx*scale,ry*scale
        m=int(max(ax,ay))+2; x0,x1=max(int(cx)-m,0),min(int(cx)+m+1,FW); y0,y1=max(int(cy)-m,0),min(int(cy)+m+1,FH)
        if x0>=x1 or y0>=y1: return
        yy,xx=np.mgrid[y0:y1,x0:x1]+0.5; dx=xx-cx; dy=yy-cy
        c,sn=np.cos(ang),np.sin(ang); u=(dx*c+dy*sn)/ax; v=(-dx*sn+dy*c)/ay
        a=kernel_alpha(u*u+v*v)*amp
        sz=(size if size is not None else rx)/16.0
        g=s.G[y0:y1,x0:x1]; s.G[y0:y1,x0:x1]=a+g*(1-a)
        s.R[y0:y1,x0:x1]=sz*a+s.R[y0:y1,x0:x1]*(1-a)
        s.B[y0:y1,x0:x1]=energy*a+s.B[y0:y1,x0:x1]*(1-a)
    def decay(s,k,noiseAmp=0.0,noise=None):
        f=k if noise is None else k**(1+noiseAmp*(noise*2-1))
        s.G*=f; s.R*=f; s.B*=f
def value_noise(cell,seed=1):
    r=np.random.default_rng(seed); gw,gh=int(FW/cell)+2,int(FH/cell)+2
    g=r.random((gh,gw)); im=Image.fromarray((g*255).astype(np.uint8)).resize((int(gw*cell),int(gh*cell)),Image.BICUBIC)
    return np.asarray(im)[:FH,:FW]/255.0
def up(a):  # bilinear upsample field->screen
    im=Image.fromarray(a.astype(np.float32),mode='F').resize((W,H),Image.BILINEAR); return np.asarray(im)
P=dict(thr=0.35, K=0.35, mip=3.0, mipSlope=1.5, edgeLoss=0.75, lossStart=0.7, lossEnd=1.3,
       glint=0.45, opacity=0.97, energyTear=0.0, aa=1.0)
def shade(field,frame,P=P):
    G=field.G; eps=1e-4
    gy,gx=np.gradient(G)                           # per field texel
    size=field.R/np.maximum(G,eps)*16.0             # radius in texels (weighted)
    sx=up(gx*size); sy=up(gy*size)                  # dimensionless slope (screen dir == field dir here)
    Gs=up(G)
    w=P['aa']*0.5*np.maximum(np.abs(np.gradient(Gs)[0])+np.abs(np.gradient(Gs)[1]),1e-3)
    inside=np.clip((Gs-P['thr'])/(2*w)+0.5,0,1)
    m=inside>0.001; ys,xs=np.nonzero(m)
    s=np.stack([sx[m],sy[m]],1); smag=np.linalg.norm(s,axis=1)
    uv=np.stack([(xs+0.5)/W,(ys+0.5)/H],1)
    off=s*P['K']*np.array([H/W,1.0])               # toward the drop centre => inverted field
    col=sample(mips,uv+off,P['mip']+P['mipSlope']*np.clip(smag,0,1.5))
    loss=P['edgeLoss']*np.clip((smag-P['lossStart'])/(P['lossEnd']-P['lossStart']),0,1)
    col*= (1-loss)[:,None]
    # glint: slope facing the (upper-left) sky light
    upv=np.array([0.0,-1.0])                     # s points to the centre: bottom rim -> up
    facing=np.clip((s@upv)/np.maximum(smag,1e-4),0,1)**4*np.clip((smag-0.5)/0.6,0,1)
    sky=sample(mips,np.array([[0.5,0.05]]),np.array([8.0]))[0]
    col+= sky*(P['glint']*facing)[:,None]
    a=inside[m]*P['opacity']
    out=frame.copy(); out[ys,xs]=out[ys,xs]*(1-a[:,None])+col*a[:,None]
    return out
