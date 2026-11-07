"""RAINFX_V2_SPRAY_RAIN_REF.md section 16 (FW1): one splash deposit replayed through the sheet-off film path. usage: python rainfx2_film_fountain_sim.py [seed] [V0 mm^3]"""
# Offline replay of the sheet-off film W path (field.hlsl): advect (back-trace) + 5-tap diffusion 0.6/frame + dewet event
# (cells: cell-mean film >= filmBeadMM -> bead, rate dewetRate per cell). One splash deposit, no other supply.
import numpy as np, sys
rng=np.random.default_rng(int(sys.argv[1]) if len(sys.argv)>1 else 3)
fps=75; dt=1/fps; tex=0.58; k=2            # field texel mm, texels per cell (cell 1.16 mm)
N=160; W=np.zeros((N,N))
V0=float(sys.argv[2]) if len(sys.argv)>2 else 1.5    # mm^3 film left by one splash
R=1.2                                                 # mm deposit radius
y,x=np.mgrid[0:N,0:N]; c=40
blob=np.exp(-(((x-c)**2+(y-c)**2)*tex*tex)/(2*(R/2)**2)); W=blob/blob.sum()*V0/(tex*tex)   # depth mm
vel=np.array([0.0,10.0])   # mm/s (down), ~1 cm/s film law at 200 km/h (shear + gravity, h 0.04 mm)
diff=0.6; bead=0.04; rate=4.0
births=[]
for f in range(int(6*fps)):
    # advect by integer-free shift (bilinear back-trace)
    sh=vel*dt/tex
    from scipy.ndimage import shift
    W=shift(W,(sh[1],sh[0]),order=1,mode='constant')
    c4=(np.roll(W,1,0)+np.roll(W,-1,0)+np.roll(W,1,1)+np.roll(W,-1,1))/4
    W=W*(1-diff)+c4*diff
    cm=W.reshape(N//k,k,N//k,k).mean(axis=(1,3))
    ev=(rng.random(cm.shape)<rate*dt)&(cm>=bead)
    for (cy,cx) in zip(*np.nonzero(ev)):
        v=W[cy*k:(cy+1)*k,cx*k:(cx+1)*k].sum()*tex*tex
        W[cy*k:(cy+1)*k,cx*k:(cx+1)*k]=0
        births.append((f*dt,cy*k*tex,cx*k*tex,v))
vis=(W>=0.08).sum()
print(f"V0 {V0} mm^3: beads {len(births)}, film left {W.sum()*tex*tex:.3f} mm^3 (visible texels at the end {vis})")
for b in births[:40]: print(f"  t {b[0]:.2f}s  y {b[1]-c*tex:+5.1f} mm  x {b[2]-c*tex:+5.1f} mm  bead r {((b[3]/2.0944)**(1/3)):.2f} mm")
