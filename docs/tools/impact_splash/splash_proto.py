import numpy as np, math
from PIL import Image
N=160; yy,xx=np.mgrid[0:N,0:N].astype(np.float32)+0.5
def frac(x): return x-math.floor(x)
P=dict(SPREAD=1.8,HOLLOW=0.45,BREAK=0.55,SCATTER=1.4)
def sstep(a,b,x):
    k=max(0,min(1,(x-a)/max(b-a,1e-4))); return k*k*(3-2*k)
def render(t,E,Rf=10.0,ks=1.24):
    G=np.zeros((N,N),np.float32)
    def quad(cx,cy,rx,ry,ux,uy,code,en,amp):
        nonlocal G
        dx=xx-cx; dy=yy-cy; a=(dx*ux+dy*uy)/(rx*ks); b=(-dx*uy+dy*ux)/(ry*ks)
        h=np.clip(1-(a*a+b*b),0,1)*amp; G=G+h-G*h
    sa,sb=0.37,0.71; x=y=N/2
    s=1-(1-t)**2; Rp=Rf*(1+P['SPREAD']*E*s)
    ac=(1-sstep(0.05,P['HOLLOW'],t))*(1-0.45*s)
    if ac>0.02: quad(x,y,Rp*0.8,Rp*0.8*(0.88+0.12*frac(sb*2.9)),math.cos(sa*6.28),math.sin(sa*6.28),0,0,ac)
    ringOn=sstep(0,0.18,t); brk=max(0,min(1,(t-P['BREAK'])/(1-P['BREAK'])))
    n=int(math.floor(10+12*E*(0.5+0.5*frac(sb*3.7))+0.5))
    for k in range(1,n+1):
        h1=frac(sa*17.13+k*0.7548776662); h2=frac(sb*11.71+k*0.5698402911); h3=frac((sa+sb)*7.77+k*0.4142135623)
        if h3>=brk*0.6:
            a=(k+0.6*(h1-0.5))/n*math.pi*2+sa*6.28; ca,sn=math.cos(a),math.sin(a)
            d=Rp*(0.88+0.24*h2)+Rf*P['SCATTER']*E*brk*(0.4+h2)
            rr=max(0.85,Rf*(0.30+0.18*h1)*(1-0.55*brk)*(0.8+0.4*E))
            along=rr*(1+(0.8+0.6*h2)*(1-brk))
            quad(x+ca*d,y+sn*d,along,rr,-sn,ca,0,1,ringOn)
    if t>0.25:
        m=int(math.floor(2+6*E*frac(sa*4.9)+0.5)); fly=(t-0.25)/0.75
        for k in range(1,m+1):
            h1=frac(sb*13.3+k*0.6180339887); h2=frac(sa*19.9+k*0.3819660113); a=h1*math.pi*2
            d=Rp*(1.05+0.9*h2*fly); rr=max(0.85,Rf*(0.08+0.14*h2))
            quad(x+math.cos(a)*d,y+math.sin(a)*d,rr,rr,1,0,0,1,1)
    back=max(0,min(1,(t-0.7)/0.3)); bodyAmp=back*back*(3-2*back)
    if bodyAmp>0.005: quad(x,y,Rf*0.65,Rf*0.65,1,0,0,0,bodyAmp)
    gy,gx=np.gradient(G); inside=np.clip((G-0.3)/0.1,0,1)
    shade=0.5+np.clip(gx*Rf*0.6,-0.5,0.5)
    return np.where(inside[...,None]>0, np.stack([shade*0.8+0.1]*3,-1)*inside[...,None]+0.15*(1-inside[...,None]), 0.15)
rows=[]
for E in (0.4,1.0):
    rows.append(np.hstack([render(t,E) for t in (0.05,0.2,0.4,0.6,0.8,1.0)]))
img=np.vstack(rows); Image.fromarray((np.clip(img,0,1)*255).astype(np.uint8)).save('splash_proto.png'); print('ok')
