import numpy as np
from PIL import Image
from scipy import ndimage as nd
rng=np.random.default_rng(3)
im=np.asarray(Image.open('/root/.claude/uploads/84e3dfb8-6ccb-51b5-b2ec-2c288053336f/b9eea4de-image.png').convert('RGB'),np.float32)/255
bg=im[380:880,440:873]; H,W,_=bg.shape
yy,xx=np.mgrid[0:H,0:W].astype(np.float32)
# flow direction (down-right, like the screenshots)
fd=np.array([0.55,0.83]); fd/=np.linalg.norm(fd); fn=np.array([-fd[1],fd[0]])
along=xx*fd[0]+yy*fd[1]; across=xx*fn[0]+yy*fn[1]
def noise(s,sc):
    n=nd.gaussian_filter(rng.standard_normal(s),sc,mode='wrap'); return n/n.std()
# rivulets: several centre lines (across offsets) with wandering + varying width
h=np.zeros((H,W),np.float32)
for c in [80,170,240,330,400,470]:
    wob=noise((H,W),25)*6
    width=(14+6*noise((H,W),30)).clip(5,24)
    d=(across-c+wob)
    prof=np.clip(1-(d/width)**2,0,None)            # dome cross-section
    # thickness pulses travelling along the flow (beads / surges)
    puls=0.75+0.25*np.sin(along/22+noise((H,W),20)*1.5)
    h=np.maximum(h,prof*width/12*puls)
# thin film between rivulets: flow-stretched ripple
rip=nd.gaussian_filter(rng.standard_normal((H,W)),(1,1))
ripA=nd.zoom(rng.standard_normal((H//6+2,W//6+2)),6,order=3)[:H,:W]
film=0.10*(0.5+0.5*np.tanh(ripA))
h=np.maximum(h,film)
inside=np.clip((h-0.03)/0.05,0,1)
gy,gx=np.gradient(nd.gaussian_filter(h,1.0))
def samp(img,ox,oy,sig=0):
    src=nd.gaussian_filter(img,(sig,sig,0)) if sig>0 else img
    return np.stack([nd.map_coordinates(src[...,k],[np.clip(yy+oy,0,H-1),np.clip(xx+ox,0,W-1)],order=1) for k in range(3)],-1)
# --- current model: small slope offset (heads rule on a flat-topped canvas),
#     heavy blur (scene mip 3 + trail blur), tone compress toward bg, veil
cur=samp(bg,-gx*3,-gy*3,sig=5)
bgb=nd.gaussian_filter(bg,(10,10,0)); cur=bgb+(cur-bgb)*0.5
cur=cur*0.88+np.array([0.62,0.66,0.70])*0.12
A=inside[...,None]*0.85
outC=bg*(1-A)+cur*A
# --- proposed: thickness-gradient refraction, sharp, rim effects
K=70.0                                    # px per unit slope
g=np.sqrt(gx*gx+gy*gy)
ox=-gx*K; oy=-gy*K                        # look toward thick side -> inverted, stretched across
pro=samp(bg,ox,oy,sig=0.6)
pro=np.where((g>0.18)[...,None],samp(bg,ox*1.8,oy*1.8,sig=1.2),pro)   # dramatic edge refraction
rim=np.clip((g-0.10)/0.25,0,1)
light=np.clip(-(gx*fn[0]*0+gy*1.0)/ (g+1e-4),0,1)                     # lower-facing edge sees sky
pro=pro*(1-0.35*rim[...,None])+np.array([0.85,0.88,0.92])*(0.45*rim*light**4)[...,None]
pro=pro*0.97+0.03                                                      # nearly clear water
A2=inside[...,None]*0.95
outP=bg*(1-A2)+pro*A2
cy,cx=150,40; c=lambda a: np.kron(a[cy:cy+300,cx:cx+330],np.ones((2,2,1)))
row=np.concatenate([c(bg),c(outC),c(outP)],1)
Image.fromarray((row.clip(0,1)*255).astype(np.uint8)).save('trail_proto.png')
print('ok')
