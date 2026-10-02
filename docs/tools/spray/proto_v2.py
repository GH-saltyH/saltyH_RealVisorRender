import numpy as np, sys
sys.path.insert(0,'/tmp/claude-0/h')
from harness import tonemap
from PIL import Image
from scipy.ndimage import gaussian_filter, map_coordinates
sc=np.load('/tmp/claude-0/h/scene.npy')[::2,::2].astype(np.float32)  # 540x960
H,W=sc.shape[:2]
blurs={m:np.stack([gaussian_filter(sc[...,c],2**m*0.5) for c in range(3)],-1) for m in range(0,9)}
def samp(uvx,uvy,mip):
    mip=np.clip(mip,0,8); m0=np.floor(mip).astype(int); fr=mip-m0
    out=np.zeros(uvx.shape+(3,),np.float32)
    X=np.clip(uvx*W-0.5,0,W-1); Y=np.clip(uvy*H-0.5,0,H-1)
    for m in range(9):
        w=np.where(m0==m,1-fr,0)+np.where(m0+1==m,fr,0)
        if w.max()==0: continue
        for c in range(3): out[...,c]+=w*map_coordinates(blurs[m][...,c],[Y,X],order=1)
    return out
def hsh(x,y):
    px=np.mod(x*123.34,1.0);py=np.mod(y*456.21,1.0)
    d=px*(px+45.32)+py*(py+45.32);px=px+d;py=py+d;return np.mod(px*py,1.0)
def vn(x,y):
    ix,iy=np.floor(x),np.floor(y);fx,fy=x-ix,y-iy;ux=fx*fx*(3-2*fx);uy=fy*fy*(3-2*fy)
    a,b,c,d=hsh(ix,iy),hsh(ix+1,iy),hsh(ix,iy+1),hsh(ix+1,iy+1);return a+(b-a)*ux+(c-a)*uy+(a-b-c+d)*ux*uy
def vnd(x,y):
    ix,iy=np.floor(x),np.floor(y);fx,fy=x-ix,y-iy;ux=fx*fx*(3-2*fx);uy=fy*fy*(3-2*fy);dx=6*fx*(1-fx);dy=6*fy*(1-fy)
    a,b,c,d=hsh(ix,iy),hsh(ix+1,iy),hsh(ix,iy+1),hsh(ix+1,iy+1);k=a-b-c+d
    return a+(b-a)*ux+(c-a)*uy+k*ux*uy, dx*((b-a)+k*uy), dy*((c-a)+k*ux)
def ss(a,b,x): t=np.clip((x-a)/(b-a),0,1); return t*t*(3-2*t)
P=dict(nx=0.5,ny=1.05,up=0.6,FA=18,FL=5,warp=0.8,wsp=3.0,refr=18,mip=4.0,smip=1.5,loss=0.35,glint=0.3,veil=0.18,op=0.75,
 bc=3.5,bd=0.35,br=0.9,brad=0.42,bel=0.6,bcl=0.6,bpile=0.9)
fog=np.array([0.75,0.78,0.82],np.float32)*1.2
def render(t,phase,level=1.0,full=H):
    yy,xx=np.mgrid[0:H,0:W].astype(np.float32); u=(xx+.5)/W; v=(yy+.5)/H; asp=W/H
    qx=(u-P['nx'])*asp; qy=v-P['ny']; dist=np.hypot(qx,qy)+1e-6
    fx=qx/dist; fy=qy/dist-P['up']; n=np.hypot(fx,fy); fx/=n; fy/=n; px,py=-fy,fx
    a=(qx*px+qy*py)*P['FA']; b=(qx*fx+qy*fy)*P['FL']-phase; ws=P['wsp']*t
    wx=vn(a*.37,b*.37+ws)-.5; wy=vn(a*.37+5.2,b*.37-ws*.8)-.5
    ax=a+wx*2*P['warp']; bx=b+wy*2*P['warp']
    h1,g1x,g1y=vnd(ax,bx); h2,g2x,g2y=vnd(ax*2.07+3.1,bx*2.07-ws*1.3)
    h=h1*.65+h2*.35; gx=g1x*.65+g2x*.35*2.07; gy=g1y*.65+g2y*.35*2.07
    thick=ss(.25,.85,h); k=0.4+0.6*thick
    sx=(px*gx+fx*gy)*k; sy=(py*gx+fy*gy)*k
    bcx=qx*P['bc']; bcy=qy*P['bc']; bix,biy=np.floor(bcx),np.floor(bcy); bfx,bfy=bcx-bix-.5,bcy-biy-.5
    hA,hB,hC,hD=hsh(bix+11.3,biy+11.3),hsh(bix+27.1,biy+27.1),hsh(bix+43.7,biy+43.7),hsh(bix+61.9,biy+61.9)
    el=P['bel']; R=min(P['brad'],0.5*min(el,1)/1.35); LR=R*1.35/min(el,1); life=np.mod(t*P['br']*(0.6+0.8*hB)+hC,1.0); act=(hA<P['bd']*(0.5+0.5*level)).astype(np.float32)
    dx=bfx-(hC-.5)*max(1-2*LR,0); dy=bfy-(hD-.5)*max(1-2*LR,0)
    ddx=dx*px+dy*py; ddy=(dx*fx+dy*fy)*P['bel']
    rad=R*(1-np.exp(-life*10)); st=act*(1-life)**2*ss(0,0.04,life)*(1-ss(.4,.5,np.maximum(abs(bfx),abs(bfy))))
    rr=np.hypot(ddx,ddy)/np.maximum(rad,1e-3); clear=st*(1-ss(.55,1,rr)); rx=(rr-1.05)/.22; pile=st*np.exp(-rx*rx)
    dl=np.hypot(dx,dy)+1e-6; ox,oy=dx/dl,dy/dl
    sx=sx*(1-clear)+ox*(-2*rx*pile*P['bpile']); sy=sy*(1-clear)+oy*(-2*rx*pile*P['bpile'])
    thick=np.clip(thick*(1-clear)+pile,0,1)
    sl=np.hypot(sx,sy)
    uvx=np.clip(u+sx*P['refr']/W*2,0,1); uvy=np.clip(v+sy*P['refr']/H*2,0,1)   # *2: half-res proto
    mip=np.maximum(P['mip']*(1-.6*clear)+P['smip']*np.clip(sl/1.5,0,1)-1,0)   # -1: half-res
    col=samp(uvx,uvy,mip)
    col*=(1-P['loss']*ss(.7,1.6,sl))[...,None]
    fac=np.clip(-sy/np.maximum(sl,1e-4),0,1)
    col+=fog*(P['glint']*fac**4*ss(.6,1.4,sl))[...,None]
    vv=(P['veil']*(0.5+0.5*thick)*(1-clear))[...,None]; col=col*(1-vv)+fog*vv
    al=np.clip(P['op']*(1-P['bcl']*clear)*(0.8+0.2*thick),0,1)[...,None]
    return tonemap(sc*(1-al)+col*al)
imgs=[render(0.0,0.0),render(0.25,2.0),render(0.9,7.2)]
top=np.hstack([tonemap(sc),imgs[0]]); bot=np.hstack(imgs[1:])
Image.fromarray((np.clip(np.vstack([top,bot]),0,1)*255).astype(np.uint8)).save('spray_v2_proto.png')
