import numpy as np
W,Rr,Lv,hwR=1.2,2.0,8.0,0.3
dIn=0.5*min(W,Rr); xe=1-dIn/Rr; w0=W*np.sqrt(max(0,1-xe*xe))
def prof(a):
    nk=np.clip((a+dIn)/(2.1*W),0,1); nk=nk*nk*(3-2*nk)
    w=w0+(hwR-w0)*nk
    w*=np.sqrt(np.clip((a+2*dIn)/dIn,0,1))
    te=np.clip((Lv-a)/(0.25*Lv),0,1); w*=te**0.7
    return np.minimum(w,3.9)
tex=1.18; A=np.linspace(-2*dIn,Lv,3000)
worst=[]
for a0 in A:
    d=(prof(a0+0.1)-prof(a0-0.1))*5; d=np.clip(d,-1.99,1.99)
    for al in np.linspace(-1.2*tex,1.2*tex,25):
        a=a0+al
        if a<-2*dIn or a>Lv: continue
        e=prof(a0)+d*min(al,Lv-a0)-prof(a)
        worst.append((e,a0,al))
worst=np.array(worst)
for name,m in [('cap (a<-dIn)',worst[:,1]<-dIn),('neck',(worst[:,1]>=-dIn)&(worst[:,1]<2.1*W-dIn)),('rivulet',(worst[:,1]>=2.1*W-dIn)&(worst[:,1]<0.75*Lv)),('end taper',worst[:,1]>=0.75*Lv)]:
    print(f'{name:12s} over-predict max {worst[m,0].max():.2f} mm, under {worst[m,0].min():.2f} mm')
print('w0',round(w0,2),'dIn',dIn)
