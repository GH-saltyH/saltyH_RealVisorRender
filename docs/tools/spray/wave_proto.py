import numpy as np, sys
sys.path.insert(0,'/tmp/claude-0/h'); sys.path.insert(0,'/tmp/claude-0/sp')
from harness import tonemap
from PIL import Image
from scipy.ndimage import map_coordinates
exec(open('proto2.py').read().split("P=dict")[0])  # scene, samp, hsh, vn, ss
fog=np.array([0.75,0.78,0.82],np.float32)*1.2
W,Hh=480,270
P=dict(restore=0.02,c2=0.45,damp=0.975,hdecay=0.995,tdecay=0.996,tgain=0.08,tslope=10.0,cell=8.0,aniso=1.8,rate=40.0,strength=1.6,rad=1.5,dn=0.6,dcells=3.0,
 gcell=60.0,grate=0.08,gstr=2.5,drift=0.35/60,nose=(0.5,1.05),up=0.6,steps=2,slope=3.0,refr=24,mip=2.5,smip=1.5,loss=0.3,glint=0.35,veil=0.12,op=0.8)
yy,xx=np.mgrid[0:Hh,0:W].astype(np.float32); u=(xx+.5)/W; v=(yy+.5)/Hh; asp=W/Hh
qx=(u-P['nose'][0])*asp; qy=v-P['nose'][1]; d=np.hypot(qx,qy)+1e-6
fx=qx/d; fy=qy/d-P['up']; n=np.hypot(fx,fy); fx/=n; fy/=n
fux=fx/asp; fuy=fy
st=np.zeros((Hh,W,3),np.float32)
def tap(img,uu,vv): return map_coordinates(img,[np.clip(vv*Hh-.5,0,Hh-1),np.clip(uu*W-.5,0,W-1)],order=1,mode='nearest')
seed=0
def step(st,dts,level,t):
    global seed; seed=(seed+1)%997
    su=u-fux*P['drift']; sv=v-fuy*P['drift']
    h=tap(st[...,0],su,sv); vel=tap(st[...,1],su,sv); th=tap(st[...,2],su,sv)
    tx,ty=1/W,1/Hh
    lap=tap(st[...,0],su-tx,sv)+tap(st[...,0],su+tx,sv)+tap(st[...,0],su,sv-ty)+tap(st[...,0],su,sv+ty)-4*h
    vel=(vel+P['c2']*lap-P['restore']*h)*P['damp']; h=(h+vel)*P['hdecay']; th=th*P['tdecay']
    px=xx+.5; py=yy+.5; cs=P['cell']; cix=np.floor(px/cs); ciy=np.floor(py/cs); cfx=px-cix*cs; cfy=py-ciy*cs
    hA=hsh(cix+seed*0.713,ciy+seed*1.37)
    dens=1+P['dn']*(vn(u*P['dcells']+t*0.3,v*P['dcells'])*2-1)
    prob=P['rate']*dts*level
    hB=hsh(cix+seed*2.31+3.7,ciy+seed*0.57+3.7); hC=hsh(cix+seed*1.11+9.1,ciy+seed*3.3+9.1); hD=hsh(cix+seed*0.37+5.5,ciy+seed*2.9+5.5)
    rad=P['rad']*(0.5+hD); m=np.maximum(cs-4*rad*P['aniso'],0)
    c0x=cs*.5+(hB-.5)*m; c0y=cs*.5+(hC-.5)*m
    ddx=cfx-c0x; ddy=cfy-c0y; ea=(ddx*(-fy)+ddy*fx)/P['aniso']; eb=ddx*fx+ddy*fy; r2=(ea*ea+eb*eb)/(rad*rad); on=(hA<prob*dens)
    g=np.exp(-r2)*on; gw=np.exp(-r2*0.5)*on
    vel-=P['strength']*(g-0.5*gw)*(0.5+hD); th+=P['tgain']*g*(0.5+hD)
    gs=P['gcell']; gix=np.floor(px/gs); giy=np.floor(py/gs); gfx=px-gix*gs; gfy=py-giy*gs
    gA=hsh(gix+seed*0.913+1.3,giy+seed*1.77+1.3); gB=hsh(gix+seed*1.913+4.3,giy+seed*0.77+4.3)
    R=gs*0.25*(0.6+0.8*gB); r=np.hypot(gfx-gs*.5,gfy-gs*.5)
    act=(gA<P['grate']*dts*level)
    core=np.exp(-(r/(0.6*R))**2); ring=np.exp(-((r-R)/(0.25*R))**2)
    vel+=P['gstr']*(ring-2.46*core)*act; th*=1-0.8*core*act
    return np.stack([np.clip(h,-4,4),np.clip(vel,-4,4),np.clip(th,0,2)],-1)
def shade(st):
    H2,W2=sc.shape[:2]
    yy2,xx2=np.mgrid[0:H2,0:W2].astype(np.float32); uu=(xx2+.5)/W2; vv=(yy2+.5)/H2
    tx,ty=1/W,1/Hh
    hx=(tap(st[...,0],uu+tx,vv)-tap(st[...,0],uu-tx,vv))*.5; hy=(tap(st[...,0],uu,vv+ty)-tap(st[...,0],uu,vv-ty))*.5
    T=tap(st[...,2],uu,vv)
    tx2=(tap(st[...,2],uu+tx,vv)-tap(st[...,2],uu-tx,vv))*.5; ty2=(tap(st[...,2],uu,vv+ty)-tap(st[...,2],uu,vv-ty))*.5
    k=P['slope']*(0.5+0.5*T); sx,sy=hx*k+P['tslope']*tx2,hy*k+P['tslope']*ty2; sl=np.hypot(sx,sy)
    col=samp(np.clip(uu+sx*P['refr']/W2*2,0,1),np.clip(vv+sy*P['refr']/H2*2,0,1),np.maximum(P['mip']+P['smip']*np.clip(sl/1.5,0,1)-1,0))
    col*=(1-P['loss']*ss(.7,1.6,sl))[...,None]
    fac=np.clip(-sy/np.maximum(sl,1e-4),0,1); col+=fog*(P['glint']*fac**4*ss(.6,1.4,sl))[...,None]
    thick=np.clip(T*0.5,0,1); vvv=(P['veil']*(0.5+0.5*thick))[...,None]; col=col*(1-vvv)+fog*vvv
    al=(P['op']*(0.8+0.2*thick))[...,None]
    return tonemap(sc*(1-al)+col*al), sl
if __name__=='__main__':
    dt=1/60; t=0; frames=[]
    for f in range(150):
        for s in range(P['steps']):
            st=step(st,dt/P['steps'],1.0,t); 
        t+=dt
        if f in (60,62,64,149): frames.append(shade(st))
    print('h std',st[...,0].std(),'T mean',st[...,2].mean(),'slope p50/p95',np.percentile(frames[-1][1],[50,95]))
    img=np.vstack([np.hstack([frames[0][0],frames[1][0]]),np.hstack([frames[2][0],frames[3][0]])])
    Image.fromarray((np.clip(img,0,1)*255).astype(np.uint8)).save('wave_proto.png')
    Image.fromarray((np.clip(st[...,0]*0.5+0.5,0,1)*255).astype(np.uint8)).resize((960,540)).save('wave_h.png')
