import numpy as np, sys
sys.path.insert(0,'/tmp/claude-0/h')
from harness import tonemap
from PIL import Image
from scipy.ndimage import gaussian_filter
def hsh(x,y):
    px=np.mod(x*123.34,1.0);py=np.mod(y*456.21,1.0); d=px*(px+45.32)+py*(py+45.32); px=px+d;py=py+d; return np.mod(px*py,1.0)
def vn(x,y):
    ix,iy=np.floor(x),np.floor(y);fx,fy=x-ix,y-iy;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy)
    a,b,c,d=hsh(ix,iy),hsh(ix+1,iy),hsh(ix,iy+1),hsh(ix+1,iy+1);return (a*(1-fx)+b*fx)*(1-fy)+(c*(1-fx)+d*fx)*fy
def ss(a,b,x): t=np.clip((x-a)/(b-a),0,1); return t*t*(3-2*t)
P=dict(mc=5.0,mw=0.6,cov=0.55,soft=0.06,ms=0.9,fc=420.0,fp=40.0,fcon=0.85,base=0.18,bc=700.0)
W=1200; H=800
yy,xx=np.mgrid[0:H,0:W].astype(np.float32); u=xx/W*0.9; v=yy/H*0.6+0.2   # ~2700 px per visor UV
def smear(I):
    px,py=u*P['mc'],v*P['mc']
    wx=vn(px*0.5,py*0.5)-0.5; wy=vn(px*0.5+5.2,py*0.5+5.2)-0.5
    ax,ay=px+wx*2*P['mw'],py+wy*2*P['mw']
    n=vn(ax,ay)*0.55+vn(ax*2.03+3.1,ay*2.03+3.1)*0.30+vn(ax*4.11+7.7,ay*4.11+7.7)*0.15
    t=0.80-0.65*P['cov']*I; m=ss(t-P['soft'],t+P['soft'],n)
    qx,qy=u*P['fc'],v*P['fc']; qwx=(vn(u*23,v*23)-0.5)*9; qwy=(vn(u*23+9.4,v*23+9.4)-0.5)*9
    r=1-abs(vn(qx+qwx,qy+qwy)*2-1); r=r**3
    patch=ss(0.35,0.75,vn(u*P['fp']+2.7,v*P['fp']+2.7))
    fill=1+(np.clip(r*patch*1.6,0,1)-1)*P['fcon']
    b=(1-abs(vn(u*P['bc']+3.3,v*P['bc']+3.3)*2-1))**4
    return m, np.clip(m*fill*P['ms']+P['base']*b,0,1)
sc=np.load('/tmp/claude-0/h/scene.npy').astype(np.float32)[140:140+H,300:300+W]
blur=np.stack([gaussian_filter(sc[...,c],16) for c in range(3)],-1)
fog=np.array([0.75,0.78,0.82])*1.2
turb=blur*0.65+fog*0.35
rows=[]
for I in (0.5,1.0):
    m,d=smear(I)
    a=np.clip(d*0.35,0,1)[...,None]
    img=tonemap(sc*(1-a)+turb*a)
    dbg=np.stack([m*0.8,d,np.full_like(d,0.15)],-1)
    rows.append(np.hstack([img,dbg]))
Image.fromarray((np.clip(np.vstack(rows),0,1)*255).astype(np.uint8)).resize((1200,800)).save('smear_proto.png')
m,d=smear(1.0); print('cov', (m>0.5).mean())
