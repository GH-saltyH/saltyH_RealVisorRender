# rev11 film (W) prototype: splash supply (3x3 kernel), semi-Lagrangian advection, drain.
# Render: refraction from grad(h) (taps at max(texel, rb)), scatter blur + veil by coverage.
import numpy as np, sys
from PIL import Image
from scipy.ndimage import map_coordinates, gaussian_filter
rng=np.random.default_rng(2)
FW,FH=256,96; tex=0.59                      # field texels, mm/texel
fps=60; dt=1/fps
R=float(sys.argv[1]) if len(sys.argv)>1 else 40   # mm/h
speed=float(sys.argv[2]) if len(sys.argv)>2 else 60 # m/s
filmK=float(sys.argv[3]) if len(sys.argv)>3 else 1.0
flowK=float(sys.argv[4]) if len(sys.argv)>4 else 4.0
DIFF=float(sys.argv[6]) if len(sys.argv)>6 else 0.5
GAIN=float(sys.argv[7]) if len(sys.argv)>7 else 6
VEIL=float(sys.argv[8]) if len(sys.argv)>8 else 0.35
D=max(0.15,R**0.21/4.1); stick=0.8+(0.4-0.8)*min(max((speed-10)/60,0),1)
flux=R/3.6e6/6*np.hypot(speed,6)            # m/s water
Vmean=np.pi*D**3                            # mm3
impacts=flux/(Vmean*1e-9)                   # /m2/s
area=tex*tex*1e-6
rate=flux*1000*0.6*(1-stick)*filmK          # mm/s film supply (exposure 0.6), filmK = spray multiplier
Dsp=0.25 if filmK>1 else D                   # spray droplets are small
lam=min(rate/(np.pi*Dsp**3/(tex*tex))*dt,1.0)  # splashes per texel per frame
dep=rate*dt/max(lam,1e-9)
# film velocity: air shear along +x(tex u) + gravity down (+y)
ut=0.35*speed; tau=0.5*1.2*0.005*ut*ut
def vel(h):
    hm=h*1e-3; vx=tau*hm/2e-3; vy=1000*9.81*hm*hm/3e-3
    return np.minimum(vx*flowK,1.0)*1000/tex, np.minimum(vy*flowK,1.0)*1000/tex   # texel/s
W=np.zeros((FH,FW)); yy,xx=np.mgrid[0:FH,0:FW].astype(float)
k=np.array([[1,2,1],[2,4,2],[1,2,1]])/16
from scipy.ndimage import convolve
for i in range(fps*6):
    vx,vy=vel(W)
    W=map_coordinates(W,[yy-vy*dt,xx-vx*dt],order=1,mode='constant')
    hit=(rng.random((FH,FW))<lam).astype(float)
    W+=convolve(hit,k,mode='constant')*dep
    # surface-tension smoothing: 5-tap cross blend (diffusion), field-pass friendly
    Wc=(np.roll(W,1,0)+np.roll(W,-1,0)+np.roll(W,1,1)+np.roll(W,-1,1))*0.25
    W=W+(Wc-W)*DIFF
    W*=np.exp(-dt*0.5); W=np.minimum(W,0.5)
print('R %.0f speed %.0f: D %.2f stick %.2f lam %.4f dep %.3f mm  W mean %.4f p90 %.4f max %.3f mm  v(0.05mm) %.3f m/s'%(R,speed,D,stick,lam,dep,W.mean(),np.percentile(W,90),W.max(),tau*5e-5/2e-3*flowK))
np.save('W.npy',W)
# render over A background, field mapped to 960x360 screen region (3.75 px/texel)
bg=np.asarray(Image.open(sys.argv[9] if len(sys.argv)>9 else 'background.png').convert('RGB').resize((960,540)),np.float32)/255
bg=bg**2.2
Hs,Ws=360,960; sx=Ws/FW
Wu=map_coordinates(W,[yy2:=np.mgrid[0:Hs,0:Ws][0]/sx, np.mgrid[0:Hs,0:Ws][1]/sx],order=1)
Wu=gaussian_filter(Wu,1.5)                  # pupil footprint smoothing (rb ~ 0.6 mm)
gy,gx=np.gradient(Wu,1/sx*tex)              # mm/mm
th=0.333; fovK=0.87; px=th*fovK*540         # px per unit slope
cov=np.clip((Wu-0.005)/0.025,0,1)
ox=gx*px*GAIN; oy=gy*px*GAIN                      # filmRefract gain 6 (waves steeper than resolved)
Y,X=np.mgrid[0:Hs,0:Ws]; Y=Y+90
def blur(img,s): return np.stack([gaussian_filter(img[...,c],s) for c in range(3)],-1)
B1=blur(bg,2.0)
samp=np.stack([map_coordinates(B1[...,c],[np.clip(Y+oy,0,539),np.clip(X+ox,0,959)],order=1) for c in range(3)],-1)
veil=np.array([.55,.6,.62])**2.2
B2=blur(bg,6.0); samp=samp*0.5+np.stack([map_coordinates(B2[...,c],[np.clip(Y+oy,0,539),np.clip(X+ox,0,959)],order=1) for c in range(3)],-1)*0.5
film=samp*(1-VEIL*cov[...,None])+veil*VEIL*cov[...,None]
out=bg.copy(); reg=out[90:450]
out[90:450]=reg*(1-cov[...,None])+film*cov[...,None]
Image.fromarray((np.clip(out,0,1)**(1/2.2)*255).astype(np.uint8)).save(sys.argv[5] if len(sys.argv)>5 else 'film.png')
