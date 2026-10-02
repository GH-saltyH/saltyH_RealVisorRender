import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates
N=256; dt=1/60
def hsh(x,y):
    px=np.mod(x*123.34,1.0);py=np.mod(y*456.21,1.0); d=px*(px+45.32)+py*(py+45.32); px=px+d;py=py+d; return np.mod(px*py,1.0)
def vn(x,y):
    ix,iy=np.floor(x),np.floor(y);fx,fy=x-ix,y-iy;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy)
    a,b,c,d=hsh(ix,iy),hsh(ix+1,iy),hsh(ix,iy+1),hsh(ix+1,iy+1);return (a*(1-fx)+b*fx)*(1-fy)+(c*(1-fx)+d*fx)*fy
yy,xx=np.mgrid[0:N,0:N].astype(np.float32)+0.5; u=xx/N; v=yy/N
st=np.zeros((N,N,3),np.float32)
flow=np.array([0.05,0.10])  # UV/s (right, down)
rng=np.random.default_rng(1)
drops=[[rng.uniform(0,1),rng.uniform(0,0.4)] for _ in range(14)]
def tap(img,uu,vv): return map_coordinates(img,[np.clip(vv*N-.5,0,N-1),np.clip(uu*N-.5,0,N-1)],order=1,mode='nearest')
frames=[]
t=0; seed=0
for f in range(360):
    t+=dt; seed=(seed+1)%997
    # trail canvas stand-in: thin lines at drops moving along flow*1.3
    trail=np.zeros((N,N),np.float32)
    for d in drops:
        d[0]+=flow[0]*1.3*dt; d[1]+=flow[1]*1.3*dt
        if d[1]>1: d[0],d[1]=rng.uniform(0,1),0
        trail=np.maximum(trail,np.clip(1-((u-d[0])**2+(v-d[1])**2)/(0.012**2),0,1))
    n1=vn(u*9+t*0.5,v*9); n2=vn(u*15.3+9.1,v*15.3-t*0.4); var=0.6
    perp=np.array([-flow[1],flow[0]])
    fx=flow[0]*(1-var+2*var*n1)+perp[0]*(n2-.5)*var; fy=flow[1]*(1-var+2*var*n1)+perp[1]*(n2-.5)*var
    su,sv=u-fx*dt,v-fy*dt; T=1/N
    c=[tap(st[...,k],su,sv) for k in range(3)]
    sheet,erase,foam=c
    sR=tap(st[...,0],su+T,sv); sL=tap(st[...,0],su-T,sv); sD=tap(st[...,0],su,sv+T); sU=tap(st[...,0],su,sv-T)
    front=np.clip((abs(sR-sL)+abs(sD-sU))*2,0,1)
    sheet=sheet+trail*3.0*dt+0.2*dt*(0.3+1.4*vn((u-flow[0]*t)*7,(v-flow[1]*t)*7+t*0.05))
    sheet*=np.exp(-dt/1.6)
    cx,cy=np.floor(u*N),np.floor(v*N)
    hit=(hsh(cx+seed*0.713,cy+seed*1.37)<0.04*dt).astype(np.float32)
    ss=np.clip((sheet-0.175)/(0.525-0.175),0,1); ss=ss*ss*(3-2*ss)
    erase=np.maximum(erase,ss); erase=np.maximum(erase,hit*(0.6+0.4*hsh(cx+5.3,cy+5.3))); erase=np.clip(erase-0.2*dt,0,1)
    sp=np.hypot(fx,fy); foam=foam*np.exp(-dt/0.6)+2*dt*front*np.clip(sp*20,0,1)*np.clip(sheet,0,1)
    st=np.stack([np.clip(sheet,0,2),erase,np.clip(foam,0,1)],-1)
    if f in (60,180,359):
        g=np.floor(np.stack([u,v],-1)*N*2); gr=hsh(g[...,0]+0.37,g[...,1]+0.37); gr2=hsh(g[...,0]+11.9,g[...,1]+11.9)
        up=lambda a: np.kron(a,np.ones((2,2)))
        S=up(st[...,0]); E=up(st[...,1]); F=up(st[...,2])
        gr=np.kron(gr,np.ones((1,1)))  # grain already at N*2? recompute at 2N res
        yy2,xx2=np.mgrid[0:2*N,0:2*N]; g1=hsh(xx2+0.37,yy2+0.37); g2=hsh(xx2+11.9,yy2+11.9)
        sheetOn=np.clip((S-0.35)/0.3,0,1)>g1; eraseOn=E>g2; foamOn=F>g2
        img=np.zeros((2*N,2*N,3)); img[...]=0.25
        micro=(hsh(np.floor(xx2/4),np.floor(yy2/4))>0.8)&((xx2%4)>0)&((yy2%4)>0)  # stand-in micro dots
        img[micro & ~eraseOn]=0.7
        img[sheetOn]=[0.2,0.35,0.6]
        img[(sheetOn|micro)&foamOn]=0.95
        frames.append(img)
Image.fromarray((np.hstack(frames)*255).astype(np.uint8)).save('fl_proto.png'); print('ok', st[...,0].mean(), st[...,1].mean(), st[...,2].mean())
