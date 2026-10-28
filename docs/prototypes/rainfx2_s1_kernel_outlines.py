import numpy as np, math
from PIL import Image
K=1.24
def drop(A,phi,a2,a3,bend,r=1.0,ph3=0.7,N=200,ext=3.2):
    y,x=np.mgrid[0:N,0:N]/N*2*ext-ext
    q=np.stack([x,y],-1)
    u=np.array([math.cos(phi),math.sin(phi)]); v=np.array([-u[1],u[0]])
    rk0=K*r; rkS=rk0/math.sqrt(A); s1=1-1/A
    aa=(q@u)/(rk0*math.sqrt(A))
    q=q - v*(bend*rkS*aa*aa)[...,None]
    q=q - u*((q@u)*s1)[...,None]
    rr=np.maximum((q**2).sum(-1),1e-12); qq=q/np.sqrt(rr)[...,None]
    ca=qq@u; sa=qq[...,1]*u[0]-qq[...,0]*u[1]
    c2=ca*ca-sa*sa; c3=ca*(4*ca*ca-3); s3=sa*(3-4*sa*sa)
    dR=np.maximum(1+a2*c2+a3*(c3*math.cos(ph3)+s3*math.sin(ph3)),0.3)
    h=1-rr/(rkS*rkS*dR*dR)
    return (h>0.35).astype(np.uint8)*255
cases=[(1.2,0.3,0.03,0.02,0),(1.6,math.pi/2,0.05,0.04,0),(2.4,0.4,0.04,0,0.9),(2.8,1.2,0.04,0,-1.1),(1.7,0.2,0.3,0,0),(1.4,1.0,0.25,0.15,0),(1.0,0,0,0.18,0)]
im=np.concatenate([drop(*c) for c in cases],1)
Image.fromarray(im).save('s1_outlines.png')
for c in cases: m=drop(*c); print(c, 'area ratio %.2f'%(m.mean()/255/(math.pi*1.0**2/(6.4**2))))
