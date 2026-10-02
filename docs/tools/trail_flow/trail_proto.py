import numpy as np, sys
sys.path.insert(0,'/tmp/claude-0/h')
from harness import tonemap
from PIL import Image
from scipy.ndimage import gaussian_filter, map_coordinates, zoom
N=256  # trail texels (a 1/4 crop of the 1024 canvas)
sc=np.load('/tmp/claude-0/h/scene.npy').astype(np.float32)[200:200+768,600:600+768]  # 768 px crop -> 3 px / texel
P=768
def hsh(x,y):
    px=np.mod(x*123.34,1.0);py=np.mod(y*456.21,1.0); d=px*(px+45.32)+py*(py+45.32); px=px+d;py=py+d; return np.mod(px*py,1.0)
def vn(x,y):
    ix,iy=np.floor(x),np.floor(y);fx,fy=x-ix,y-iy;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy)
    a,b,c,d=hsh(ix,iy),hsh(ix+1,iy),hsh(ix,iy+1),hsh(ix+1,iy+1);return (a*(1-fx)+b*fx)*(1-fy)+(c*(1-fx)+d*fx)*fy
yy,xx=np.mgrid[0:N,0:N].astype(np.float32)+0.5
def union(G,h):  return G+h-G*h
def dome(G,cx,cy,rx,ry,ux,uy,amp):
    dx=xx-cx; dy=yy-cy; a=(dx*ux+dy*uy)/rx; b=(-dx*uy+dy*ux)/ry
    h=np.clip(1-(a*a+b*b),0,1)*amp; return union(G,h)
def ribbon(G,x0,y0,x1,y1,hw,amp):
    sx,sy=x1-x0,y1-y0; L=np.hypot(sx,sy)+1e-6; ux,uy=sx/L,sy/L
    dx=xx-x0; dy=yy-y0; a=dx*ux+dy*uy; b=(-dx*uy+dy*ux)/hw
    h=np.clip(1-b*b,0,1)*((a>=0)&(a<L))*amp; return union(G,h)
def run(mode,D,noise=0.75,frames=40):
    G=np.zeros((N,N),np.float32); rng=np.random.default_rng(3)
    drops=[dict(x=rng.uniform(20,120),y=rng.uniform(150,250),vx=rng.uniform(1.5,3),vy=-rng.uniform(2,4),R=rng.uniform(2.0,3.5)) for _ in range(9)]
    decay=np.exp(-(1/60)*1.05/0.46); cells=203/4
    for f in range(frames):
        n=vn(xx/N*cells*0+xx*cells/N*4/4, yy*cells/N)  # same cell density as 203 per full UV
        k=decay**np.maximum(0.05,1+noise*(n*2-1)*0.6)
        G=G*k
        if D>0:
            Gp=np.pad(G,1,mode='edge'); av=(Gp[:-2,1:-1]+Gp[2:,1:-1]+Gp[1:-1,:-2]+Gp[1:-1,2:])*0.25
            G=G+(av-G)*4*D
        G[G<0.02]=0
        for d in drops:
            x0,y0=d['x'],d['y']; d['x']+=d['vx']; d['y']+=d['vy']
            sp=np.hypot(d['vx'],d['vy']); ux,uy=d['vx']/sp,d['vy']/sp; rr=d['R']*0.78*1.6
            if mode=='dome':
                L=sp; G=dome(G,(x0+d['x'])/2,(y0+d['y'])/2,(L*0.5/1.24+rr)*1.24,rr*1.24,ux,uy,0.55)
            else:
                G=ribbon(G,x0,y0,d['x'],d['y'],rr*1.24,0.55)
    return G
def shade(G,tone,gstep):
    # upsample bilinear to pixels, gradient by central difference at gstep texels
    s=P/N
    py,px=np.mgrid[0:P,0:P].astype(np.float32)+0.5; tu=px/s-0.5; tv=py/s-0.5
    tap=lambda ox,oy: map_coordinates(G,[tv+oy,tu+ox],order=1,mode='nearest')
    h=tap(0,0); gx=(tap(gstep,0)-tap(-gstep,0))/(2*gstep); gy=(tap(0,gstep)-tap(0,-gstep))/(2*gstep)
    inside=np.clip((h-0.30)/0.10,0,1)
    R=3.0  # radius in texels for the slope scaling
    sx,sy=gx*R,gy*R; sl=np.hypot(sx,sy)
    mip=3.0+1.5*np.clip(sl/1.5,0,1)
    blur={m:np.stack([gaussian_filter(sc[...,c],2**m*0.5) for c in range(3)],-1) for m in (3,4,5)}
    def samp(u,v,m):
        out=0
        for mm in (3,4,5):
            w=np.clip(1-abs(m-mm),0,1)
            if w.max()>0: out=out+w[...,None]*np.stack([map_coordinates(blur[mm][...,c],[np.clip(v,0,P-1),np.clip(u,0,P-1)],order=1) for c in range(3)],-1)
        return out
    col=samp(px+sx*0.35*P*0.5,py+sy*0.35*P*0.5,mip)
    w=np.array([0.2126,0.7152,0.0722])
    if tone:
        bg=np.stack([gaussian_filter(sc[...,c],2**4.5*0.5) for c in range(3)],-1)
        col=bg+(col-bg)*0.5
    col*=(1-0.75*np.clip((sl-0.7)/0.6,0,1))[...,None]
    fac=np.clip(-sy/np.maximum(sl,1e-4),0,1); col+=np.array([0.9,0.93,1.0])*(0.45*fac**4*np.clip((sl-0.5)/0.6,0,1))[...,None]
    if tone:
        l=np.maximum(col@w,1e-5); lb=np.maximum(bg@w,1e-5); t=np.clip(l,lb*0.55,lb*1.45); col*=(t/l)[...,None]
    a=(inside*0.97)[...,None]
    return tonemap(sc*(1-a)+col*a)
cases=[('dome',0.0,False,0.5),('ribbon',0.05,True,1.0),('ribbon',0.10,True,1.0)]
imgs=[]
for mode,D,tone,gs in cases:
    G=run(mode,D); imgs.append(shade(G,tone,gs))
out=np.hstack(imgs)
Image.fromarray((np.clip(out,0,1)*255).astype(np.uint8)).save('trail_proto.png')
print('done')
