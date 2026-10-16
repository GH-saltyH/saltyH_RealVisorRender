"""GPU axis admission/bounded gather tests, including a known dry-front rejection."""
from pathlib import Path
import sys,json
sys.dont_write_bytecode=True
import numpy as np
from s90_transport_reference import ROOT,OUT,runs_from_mask,prepare,trace,remap,velocity_from_cells
W,H=1024,1;runs=runs_from_mask(np.ones((H,W),bool))
p=np.zeros((H,W,4),np.float32);p[:,:,:]=(.125,.025,-.0125,0)
prepared=prepare(velocity_from_cells(np.full((H,W),60.25*60,np.float32)),runs)
m=trace(p,prepared,1/60)
result,lost,error,work=remap(p,m,runs,stats=True)
assert np.max(abs(error))<1e-4
assert work[:,:,1].sum()<=16*(W+2*((W+15)//16))

# Reject before recipient enumeration: no bad interval is partially applied.
rejections=[]
for name,bad in [('traversal',trace(p,prepared,1/60,max_visits=1,allow_reject=True)),
                 ('broad_overlap',np.tile(np.array([-1024,2048,0,0],np.float32),(H,W,1)))]:
    result,lost,error,workBad=remap(p,bad,runs,stats=True,allow_reject=True)
    assert np.array_equal(result,p) and np.max(abs(lost))==0 and np.max(abs(workBad))==0
    rejections.append(dict(case=name,oldPacketBitIdentical=True,lossZero=True,recipientVisitsZero=True))

# Freeze-axis fallback is safe for mass but NOT a valid physical time solution.
# No claim of complete app source/head/clock atomic publication is made here.
W,H=256,1;runs=runs_from_mask(np.ones((H,W),bool))
wet=np.zeros((H,W,4),np.float32);wet[:,90:100]=(.125,.025,-.0125,0)
u=np.zeros((H,W),np.float32);u[:,90:100]=240
front=trace(wet,prepare(velocity_from_cells(u),runs),1/60)
actual=float(front[0,99,1]);freeStream=104.
assert actual<101 and freeStream-actual>3
report=dict(step='s90',compiler='FXC ps_5_0 /Ges /WX + D3D11 WARP',
    GPUAxisAdmissionPassed=True,rejectedCases=rejections,
    orderedUniformRow=dict(sumSourceTests=float(work[:,:,1].sum()),maxSourceTests=float(work[:,:,1].max()),
        analyticalUpperBoundSourceTests=16*(1024+2*64)),
    dryFront=dict(velocityCellsPerSecond=240,dt=1/60,initialRightEdge=100,
        tracedRightEdge=actual,uniformFreeFlightRightEdge=freeStream,freeBoundaryGatePassed=False,
        reason='Eulerian velocity=0 in dry cells creates a false stagnation layer. A physically defined velocity extension/front closure is required.'),
    runtimeIntegrated=False,completeAppAtomicPublicationImplemented=False,
    decision='Do not install frozen Eulerian velocity transport until dry-front closure and full app transaction are implemented. GPU arithmetic fallback is not accurate elapsed transport time.')
(OUT/'admission_front_checks.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
