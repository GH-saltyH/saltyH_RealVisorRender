from wf import *
import sys
def drop_shape(f,cx,cy,R,seed,vel=(0,0),energy=0.0,tear=0.0):
    r=np.random.default_rng(seed)
    sp=np.hypot(*vel); ang=np.arctan2(vel[1],vel[0]) if sp>1e-6 else r.uniform(0,np.pi)
    stretch=min(sp*0.35,0.8)
    f.stamp(cx,cy,R*(1+stretch*0.6),R*(1-stretch*0.25),ang,size=R)
    for k in range(r.integers(1,4)):                       # per-life irregular lobes
        a=r.uniform(0,2*np.pi); d=R*r.uniform(0.25,0.55); rr=R*r.uniform(0.45,0.75)
        f.stamp(cx+np.cos(a)*d,cy+np.sin(a)*d,rr,size=R)
    if tear>0:                                             # impact at speed: torn sheet + fingers
        n=int(4+6*tear)
        for k in range(n):
            a=ang+r.normal(0,1.1); d=R*r.uniform(0.8,1.9)*(0.7+tear)
            rr=R*r.uniform(0.15,0.4); L=r.uniform(1.0,2.6)
            f.stamp(cx+np.cos(a)*d,cy+np.sin(a)*d,rr*L,rr,a,size=rr*1.2,energy=1)
        for k in range(3):
            a=r.uniform(0,2*np.pi); d=R*r.uniform(0.3,0.8)
            f.stamp(cx+np.cos(a)*d,cy+np.sin(a)*d,R*r.uniform(0.5,0.8),size=R)
def simulate(frames=90, decaySec=1.4, noiseAmp=0.9, driving=False, seed=3):
    r=np.random.default_rng(seed)
    f=Field(); tr=Field(); noise=value_noise(2.2,seed+1)
    statics=[(r.uniform(20,FW-20),r.uniform(20,FH-20),r.uniform(1.2,3.2),i) for i in range(260)]
    # merge pairs
    for i in range(12):
        x,y,R=r.uniform(40,FW-40),r.uniform(40,FH-40),r.uniform(2.5,4)
        statics+= [(x,y,R,1000+i),(x+R*1.7,y+r.uniform(-1,1),R*0.8,2000+i)]
    movers=[dict(x=r.uniform(40,FW-40),y=r.uniform(20,FH*0.5),R=r.uniform(3.5,6),vx=r.uniform(-0.2,0.2),vy=r.uniform(0.9,1.8) if not driving else -r.uniform(1.0,2.2),seed=5000+i) for i in range(10)]
    tears=[(r.uniform(60,FW-60),r.uniform(60,FH-60),r.uniform(4,7),9000+i) for i in range(4)] if driving else []
    dt=1/60; k=np.exp(-dt*2.0/decaySec*2.3)
    for t in range(frames):
        f=Field()                                   # heads: full redraw each frame
        tr.decay(k,noiseAmp,noise)                  # trails: persistent, noisy decay
        for (x,y,R,sd) in statics: drop_shape(f,x,y,R,sd)
        for m in movers:
            m['x']+=m['vx']+0.3*np.sin(t*0.13+m['seed']); m['y']+=m['vy']
            drop_shape(f,m['x'],m['y'],m['R'],m['seed'],(m['vx'],m['vy']))
            # the moving head leaves a thinner liquid track behind it
            tr.stamp(m['x']-m['vx']*1.5,m['y']-m['vy']*1.5,m['R']*0.45,size=m['R']*0.6)
        age=t/frames
        for (x,y,R,sd) in tears:
            if t>frames-25: drop_shape(f,x,y,R,sd,(0,-2.0),tear=1.0)
    return f,tr
if __name__=='__main__':
    driving=len(sys.argv)>1 and sys.argv[1]=='drive'
    f,tr=simulate(driving=driving)
    comb=Field(); comb.G=np.maximum(f.G,tr.G); sel=f.G>=tr.G
    comb.R=np.where(sel,f.R,tr.R); comb.B=np.where(sel,f.B,tr.B)
    np.savez('wf_field_%s.npz'%('drive' if driving else 'still'),G=comb.G,R=comb.R,B=comb.B)
    out=shade(comb,scene)
    img=Image.fromarray((tonemap(out)*255).astype(np.uint8)); img.save('wf_%s.png'%('drive' if driving else 'still'))
    img.crop((560,200,1160,560)).resize((1200,720),Image.LANCZOS).save('wf_%s_zoom.png'%('drive' if driving else 'still'))
