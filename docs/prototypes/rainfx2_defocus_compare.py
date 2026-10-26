# Defocus options for the WF drop lens (docs/RAINFX_V2_DEFOCUS_PLAN.md).
# Distance-based CoC: camera focused at zf, entrance pupil A. Visor distance z grows from the
# right edge (near the onboard lens) to the left. c_obj = A|zf-z|/zf (mm on the visor),
# c_px = c_obj * pxPerMM(z), pxPerMM ~ 1/z.
import numpy as np, sys
from PIL import Image, ImageDraw
from scipy.ndimage import gaussian_filter
exec(open(__file__.replace('rainfx2_defocus_compare.py','rainfx2_wf_lens_compare.py')).read().split("imgs=[")[0].replace("bgp=sys.argv[1]; out=sys.argv[2]","bgp=sys.argv[1]; out=sys.argv[2]"))
A=1.2; zf=0.12
zL,zR=0.12,0.025                       # visor distance at left / right screen edge (m)
z=zL+(zR-zL)*(xx/W)                     # per pixel
pxmm=PXMM*0.06/z                        # same drops, px/mm grows toward the camera (drop sizes kept for clarity)
c_px=A*np.abs(zf-z)/zf*pxmm             # CoC diameter in px
print('CoC px left %.1f right %.1f'%(c_px[:, :10].mean(), c_px[:, -10:].mean()))
def wf_layer():
    # sharp WF lens: returns colour c (everywhere), inside alpha, U, slope, |grad U| px
    P=np.ones((H,W),np.float32); Gx=np.zeros((H,W),np.float32); Gy=np.zeros((H,W),np.float32); RW=np.zeros((H,W),np.float32); HW=np.zeros((H,W),np.float32)
    def kern(cx,cy,R):
        Rk=1.24*R*PXMM; x0,x1=int(max(cx-Rk,0)),int(min(cx+Rk+1,W)); y0,y1=int(max(cy-Rk,0)),int(min(cy+Rk+1,H))
        dx=xx[y0:y1,x0:x1]-cx; dy=yy[y0:y1,x0:x1]-cy
        h=np.clip(1-(dx*dx+dy*dy)/(Rk*Rk),0,1); act=h>0
        gx=np.where(act,-2*dx/(Rk*Rk),0); gy=np.where(act,-2*dy/(Rk*Rk),0); sl=(slice(y0,y1),slice(x0,x1))
        Gx[sl]=Gx[sl]*(1-h)+gx*P[sl]; Gy[sl]=Gy[sl]*(1-h)+gy*P[sl]; P[sl]*=(1-h); RW[sl]+=h*R*PXMM; HW[sl]+=h
    for (x,y,r,s) in D:
        kern(x,y,r)
        if r>0.5:
            for k in range(1+(s%2)):
                a=(s*2.39996+k*2.1)%(2*np.pi); kern(x+np.cos(a)*0.55*r*PXMM,y+np.sin(a)*0.55*r*PXMM,r*(0.45+0.1*k))
    U=1-P; Rpx=RW/np.maximum(HW,1e-6); sx=Gx*Rpx; sy=Gy*Rpx; sl=np.hypot(sx,sy); g=np.hypot(Gx,Gy)
    return U,sx,sy,sl,g,Rpx
U,sx,sy,sl,g,Rpx=wf_layer()
def shade(sx,sy,sl,extra_mip=0.0):
    c=sample(MIPS,xx+sx*0.69*H,yy+sy*0.69*H,3.0+1.5*np.clip(sl/1.5,0,1)+extra_mip)
    c*=(1-0.75*np.clip((sl-0.7)/0.6,0,1))[...,None]; c+=fog*(0.45*glint_facing(sx,sy,sl))[...,None]; return c
def smooth(e): e=np.clip(e,0,1); return e*e*(3-2*e)
sd=(U-0.35)/np.maximum(g,1e-6)          # signed distance to the silhouette (px), >0 inside
inside=smooth(sd/1.5+0.5)
csharp=shade(sx,sy,sl)
def varblur(img,sig):                   # spatially varying gaussian (per-pixel sigma)
    levels=[0,1,2,3,4.5,6.5,9,13]; stack=[img if s==0 else (np.stack([gaussian_filter(img[...,k],s) for k in range(img.shape[-1])],-1)) for s in levels]
    sig=np.clip(sig,0,levels[-1]); out=np.zeros_like(img)
    for i in range(len(levels)-1):
        a,b=levels[i],levels[i+1]; t=np.clip((sig-a)/(b-a),0,1); m=((sig>=a)&(sig<b))|((i==len(levels)-2)&(sig>=b))
        out+=np.where(m[...,None],stack[i]*(1-t[...,None])+stack[i+1]*t[...,None],0)
    return out
# (1) sharp
o1=B*(1-inside[...,None])+csharp*inside[...,None]
# (2) ground truth: blur the premultiplied drop layer by the CoC (colour domain)
L=np.concatenate([csharp*inside[...,None],inside[...,None]],-1); Lb=varblur(L,c_px/2.355*1.2)
o2=B*(1-Lb[...,3:])+Lb[...,:3]
# (3) D-C cheap: keep the lens; soften the silhouette by CoC; blur the refracted image by CoC x lens minification
magn=0.69*H*1.3/np.maximum(Rpx,1)
insideC=smooth((sd+0.5*c_px)/np.maximum(1.5,2*c_px)+0.5)*np.clip(Rpx/np.maximum(Rpx+0.5*c_px,1e-3),0,1)**2
cC=shade(sx,sy,sl,np.log2(1+c_px*0.35*magn)*0.5)
o3=B*(1-insideC[...,None])+cC*insideC[...,None]
# (4) rev17-like mean ray: average the SLOPE over the CoC, then shade once (the failure mode)
S=np.stack([sx*inside,sy*inside,inside],-1); Sb=varblur(S,c_px/2.355*1.2); n=np.maximum(Sb[...,2],1e-4)
mx,my=Sb[...,0]/n,Sb[...,1]/n; c4=shade(mx,my,np.hypot(mx,my)); a4=np.clip(Sb[...,2],0,1)
o4=B*(1-a4[...,None])+c4*a4[...,None]
names=['1 sharp WF lens (no defocus)','2 reference: blur the drop COLOUR layer by CoC (distance-based)','3 D-C cheap: lens kept, edge + image blurred by CoC','4 rev17-like: average the SLOPE (rays) over CoC']
tiles=[]
for t,a in zip(names,[o1,o2,o3,o4]):
    im=Image.fromarray((np.clip(a,0,1)**(1/2.2)*255).astype(np.uint8)); ImageDraw.Draw(im).rectangle((0,0,760,34),fill=0); ImageDraw.Draw(im).text((10,8),t+'   (left: far/sharp, right: near the lens)',fill=(255,255,0)); tiles.append(im)
o=Image.new('RGB',(W,H*4))
for i,t in enumerate(tiles): o.paste(t,(0,H*i))
o.resize((W//2,H*2)).save('defocus.jpg',quality=88)
z2=Image.new('RGB',(2*700,4*360))
for i,t in enumerate(tiles):
    z2.paste(t.crop((150,250,850,610)),(0,360*i)); z2.paste(t.crop((1150,500,1850,860)),(700,360*i))
z2.save('defocus_zoom.jpg',quality=90)
