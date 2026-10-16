"""Frozen-field time/geometry/operator gates. No physical runtime installation."""
from pathlib import Path
import sys,json
sys.dont_write_bytecode=True
import numpy as np
from s90_transport_reference import ROOT,OUT,render,common,code,runs_from_mask,prepare,trace,remap,velocity_from_cells,exact_cell_gaussian

reports=[];W,H=1024,1
runs=runs_from_mask(np.ones((H,W),bool));packets=np.ones((H,W,4),np.float32);packets[:,:,1:]=0
u=np.full((H,W),60.25*60,np.float32);prepared=prepare(velocity_from_cells(u),runs)
m=trace(packets,prepared,1/60)
idx=np.arange(W)
assert np.allclose(m[0,:,0],idx+60.25,rtol=0,atol=2e-4)
assert np.max(m[:,:,3])<=6
reports.append(dict(case='unlimited-C uniform60.25-cell trace via exact affine blocks',maxVisits=float(m[:,:,3].max()),maxError=float(np.max(abs(m[0,:,0]-idx-60.25)))))

# Same continuous affine velocity must preserve characteristic order. Ignore
# boundary-extrapolation cells in the analytic comparison, not in tracing.
affine=[]
for a in (-4.,4.):
    u=np.tile(a*(np.arange(W)+.5-512),(H,1)).astype(np.float32)
    prepared=prepare(velocity_from_cells(u),runs)
    for hz in (30,60,144):
        dt=1/hz;m=trace(packets,prepared,dt)
        expected=512+(np.arange(W+1)-512)*np.exp(a*dt)
        error=float(np.max(abs(m[0,200:800,:2]-np.stack([expected[200:800],expected[201:801]],axis=1))))
        assert error<.0015 and np.all(m[0,1:,0]>=m[0,:-1,1]-.0003)
        affine.append(dict(rate=a,hz=hz,maxEndpointErrorCells=error,maxVisits=float(m[:,:,3].max())))
reports.append(dict(case='compression/expansion endpoints from sampled velocity; no prescribed map',results=affine))

# Converging velocity reaches no finite-time crossing of a stagnation point.
u=np.tile(-20*(np.arange(W)+.5-512),(H,1)).astype(np.float32)
m=trace(packets,prepare(velocity_from_cells(u),runs),.05)
assert m[0,510,1]<512 and m[0,512,0]==512 and m[0,512,1]>512
reports.append(dict(case='opposed flows retain order at stagnation point'))

# A one-cell hole must absorb outgoing source mass, even if the continued
# outflow interval lands on another valid component.
W,H=256,3;mask=np.ones((H,W),bool);mask[:,110]=False;run=runs_from_mask(mask)
p=np.zeros((H,W,4),np.float32);p[:,90:100]=(.125,.025,-.0125,0)
u=np.full((H,W),60.25*60,np.float32)
prepared=prepare(velocity_from_cells(u),run)
m=trace(p,prepared,1/60);result,lost,error,_=remap(p,m,run)
assert np.max(abs(result))==0 and abs(lost[0]-p[:,:,0].sum())<1e-6
assert np.max(abs(error))<1e-6
reports.append(dict(case='long paths cannot teleport across a one-cell hole',runoffMM3=float(lost[0]),ledgerError=error.tolist()))

# Partial escape: proper fraction remains in the original connected region.
p[:]=0;p[:,100:110]=(.125,.025,-.0125,0)
u[:]=5.25*60
m=trace(p,prepare(velocity_from_cells(u),run),1/60);result,lost,error,_=remap(p,m,run)
assert np.sum(result[:,111:,0])==0 and np.max(abs(error))<1e-6
assert abs(lost[0]-.125*3*5.25)<1e-6
reports.append(dict(case='partial escape and signed momentum have explicit component runoff',ledgerError=error.tolist()))

# Failure paths produce a status rather than publish partially advanced water.
W,H=256,1;run=runs_from_mask(np.ones((H,W),bool));p=np.ones((H,W,4),np.float32);p[:,:,1:]=0
u=np.full((H,W),60.25*60,np.float32)
rejected=trace(p,prepare(velocity_from_cells(u),run),1/60,max_visits=1,allow_reject=True)
assert np.any(rejected[:,:,2]==1)
try:remap(p,rejected,run)
except AssertionError:pass
else:raise AssertionError('Rejected map was consumed')
u=np.zeros((H,W),np.float32);u[:,60]=np.inf
invalid=trace(p,prepare(velocity_from_cells(u),run),1/60,allow_reject=True)
assert np.any(invalid[:,:,2]==3)
reports.append(dict(case='bounded traversal/nonfinite input status rejects candidate before remap',runtimeGPUAtomicGateImplemented=False))

# Eulerian transport of a smooth density over equal elapsed time. Velocity
# is prescribed; this is not coupled h/force-pressure evolution.
W,H=256,1;run=runs_from_mask(np.ones((H,W),bool));T=.2;timeCases=[]
for a in (0.,-4.):
    u=np.full((H,W),100,np.float32) if a==0 else np.tile(a*(np.arange(W)+.5-128),(H,1)).astype(np.float32)
    prepared=prepare(velocity_from_cells(u),run)
    centre=100 if a==0 else 128;sigma=16
    targetCentre=centre+100*T if a==0 else centre
    targetSigma=sigma if a==0 else sigma*np.exp(a*T)
    expected=exact_cell_gaussian(W,targetCentre,targetSigma)
    for hz in (30,60,144):
        p=np.zeros((H,W,4),np.float32);p[0,:,0]=exact_cell_gaussian(W,centre,sigma)
        startMass=float(p[:,:,0].sum(dtype=np.float64));lostSum=0.;elapsed=0;maxVisits=0
        while elapsed<T-1e-10:
            dt=min(1/hz,T-elapsed)
            m=trace(p,prepared,dt);maxVisits=max(maxVisits,float(m[:,:,3].max()))
            p,lost,error,_=remap(p,m,run);lostSum+=lost[0];elapsed+=dt
        mass=float(p[:,:,0].sum(dtype=np.float64));centroid=float((p[0,:,0]*(np.arange(W)+.5)).sum()/mass)
        l1=float(np.sum(abs(p[0,:,0]-expected)))
        assert abs(mass+lostSum-startMass)<1e-4 and abs(centroid-targetCentre)<.01 and l1<.003,(a,hz,l1,centroid)
        timeCases.append(dict(velocityRate=a,hz=hz,elapsed=elapsed,centroidCells=centroid,targetCentreCells=targetCentre,
            relativeProfileL1=l1,ledgerError=mass+lostSum-startMass,maxTraceVisits=maxVisits))
    print('equal-time velocity rate',a,'passed',flush=True)
reports.append(dict(case='30/60/144Hz equal elapsed prescribed-field density transport',results=timeCases))

(OUT/'characteristic_checks.json').write_text(json.dumps(dict(step='s90',compiler='FXC ps_5_0 /Ges /WX + D3D11 WARP',
    checks=reports,characteristicGatePassed=True,prescribedDensityGatePassed=True,
    frozenVelocityOnly=True,limitedLinearReconstruction=True,pressureContactLineImplemented=False,runtimeIntegrated=False,
    staticRuns='Offline connected row/column intervals; no geometry assets modified',
    remaining=['Coupled variable-height/velocity/free-boundary evolution','Final GPU acceptance/epoch/budget handshake','Worst-case cost and actual game timing']),indent=2))
print(json.dumps(reports,indent=2))
