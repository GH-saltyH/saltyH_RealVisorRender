import numpy as np
from PIL import Image
W,H=1920,1080
rng=np.random.default_rng(3)
def smooth(e0,e1,x):
    t=np.clip((x-e0)/(e1-e0),0,1); return t*t*(3-2*t)
def make_scene():
    y,x=np.mgrid[0:H,0:W]; u=x/W; v=y/H
    img=np.zeros((H,W,3))
    # overcast sky
    n=np.zeros((H,W))
    for s,a in [(64,0.5),(32,0.3),(16,0.2)]:
        g=rng.random((H//s+2,W//s+2)); gi=np.array(Image.fromarray((g*255).astype(np.uint8)).resize((W+2*s,H+2*s),Image.BICUBIC))[:H,:W]/255
        n+=a*(gi-0.5)
    sky=(1.0+0.25*(0.42-v))*(1+0.12*n)
    img[:]=sky[...,None]*np.array([0.86,0.92,1.0])
    # far buildings silhouettes
    hb=0.30+0.12*np.array(Image.fromarray((rng.random(40)*255).astype(np.uint8)[None,:]).resize((W,1),Image.NEAREST))[0]/255
    bmask=(v>hb[None,:])&(v<0.47)
    img[bmask]=np.array([0.30,0.31,0.33])
    # trees / overpass pillar
    pil=(u>0.55)&(u<0.62)&(v>0.05)&(v<0.47); img[pil]=[0.22,0.22,0.23]
    beam=(u>0.45)&(u<0.75)&(v>0.05)&(v<0.12); img[beam]=[0.20,0.20,0.21]
    # road
    road=v>=0.47; rv=(v-0.47)/0.53
    img[road]=(0.30-0.12*rv[road])[:,None]*np.array([1,1,1.03])
    lane=road&(np.abs((u-0.5)-(v-0.47)*0.9)<0.004+0.01*rv); img[lane]=0.35
    # dark car ahead
    car=(u>0.38)&(u<0.60)&(v>0.40)&(v<0.63); img[car]=[0.045,0.045,0.05]
    win=(u>0.41)&(u<0.57)&(v>0.41)&(v<0.48); img[win]=[0.02,0.02,0.025]
    for cx in (0.40,0.58):
        tl=((u-cx)*W)**2+((v-0.55)*H)**2<14**2; img[tl]=[9.0,0.35,0.25]
    # white car right
    wc=(u>0.70)&(u<0.86)&(v>0.44)&(v<0.61); img[wc]=[0.55,0.56,0.58]
    # yellow streetlight + headlights
    for (cx,cy,rr,c) in [(0.25,0.18,16,[12,8,1.5]),(0.80,0.52,9,[10,10,9]),(0.84,0.52,9,[10,10,9])]:
        m=((u-cx)*W)**2+((v-cy)*H)**2<rr**2; img[m]=c
    # dashboard / hood (inside cockpit shot)
    dash=v>0.86; img[dash]=[0.012,0.012,0.013]
    return img
def build_mips(img):
    m=[img]
    while min(m[-1].shape[:2])>1:
        a=m[-1]; h,w=a.shape[0]//2*2,a.shape[1]//2*2; a=a[:h,:w]
        m.append(0.25*(a[0::2,0::2]+a[1::2,0::2]+a[0::2,1::2]+a[1::2,1::2]))
    return m
def bilinear(a,uv):
    h,w=a.shape[:2]
    x=np.clip(uv[:,0],0,1)*w-0.5; y=np.clip(uv[:,1],0,1)*h-0.5
    x0=np.floor(x).astype(int); y0=np.floor(y).astype(int); fx=(x-x0)[:,None]; fy=(y-y0)[:,None]
    x0c=np.clip(x0,0,w-1);x1c=np.clip(x0+1,0,w-1);y0c=np.clip(y0,0,h-1);y1c=np.clip(y0+1,0,h-1)
    return (a[y0c,x0c]*(1-fx)*(1-fy)+a[y0c,x1c]*fx*(1-fy)+a[y1c,x0c]*(1-fx)*fy+a[y1c,x1c]*fx*fy)
def sample(mips,uv,mip):
    mip=np.clip(np.broadcast_to(mip,(uv.shape[0],)),0,len(mips)-1)
    out=np.zeros((uv.shape[0],3)); lo=np.floor(mip).astype(int); f=(mip-lo)[:,None]
    for l in np.unique(lo):
        s=lo==l; a=bilinear(mips[l],uv[s]); b=bilinear(mips[min(l+1,len(mips)-1)],uv[s])
        out[s]=a*(1-f[s])+b*f[s]
    return out
def tonemap(x):
    x=x*0.75; a,b,c,d,e=2.51,0.03,2.43,0.59,0.14
    return np.clip((x*(a*x+b))/(x*(c*x+d)+e),0,1)**(1/2.2)
LW=np.array([0.2126,0.7152,0.0722])
