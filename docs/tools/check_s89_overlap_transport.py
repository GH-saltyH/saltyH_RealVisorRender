"""Positive source-local conservative interval overlap. GPU arithmetic/complexity gate.

Destination intervals are supplied test inputs, NOT a solved film dynamics model.
"""
from pathlib import Path
import json,sys
sys.dont_write_bytecode=True
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-16/s89'
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text()
env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')};exec(base[:base.index('report=[]')],env)
env['OUT']=OUT;env['types']['gTestGrid']='float2';render=env['render']
code=lambda n:(ROOT/f'docs/prototypes/s89/{n}.hlsl').read_text()
common=code('overlapCommon')

def mapped(W,H,travel=0,stretch=1,axis=0):
    lanes=W if axis==0 else H
    yy,xx=np.indices((H,W));i=xx if axis==0 else yy
    a=np.zeros((H,W,4),np.float32);a[:,:,0]=stretch*i+travel;a[:,:,1]=stretch*(i+1)+travel
    return a

def step(label,packets,intervals,axis=0,stats=False):
    H,W=packets.shape[:2];lanes=W if axis==0 else H;rows=H if axis==0 else W
    assert np.isfinite(intervals).all() and np.all(intervals[:,:,1]>intervals[:,:,0]),'Invalid map: reject before publishing'
    leaves=(lanes+15)//16;groups=(leaves+15)//16
    v=dict(gTestGrid=(W,H),gTestLanes=lanes,gTestRows=rows,gTestLeaves=leaves,gTestGroups=groups,gTestAxis=axis,gTestDebug=0)
    tx={'txTestPackets':packets,'txTestIntervals':intervals}
    leaf=render(label+'_leaves',common+code('overlapLeaves'),tx,v,(leaves,rows*2))
    group=render(label+'_groups',common+code('overlapGroups'),{'txTestLeaves':leaf},v,(groups,rows))
    tx.update(txTestLeaves=leaf,txTestGroups=group)
    result=render(label+'_gather',common+code('overlapGather'),tx,v,(W,H))
    runoff=leaf[rows:].sum(axis=(0,1),dtype=np.float64)
    residual=result.sum(axis=(0,1),dtype=np.float64)+runoff-packets.sum(axis=(0,1),dtype=np.float64)
    assert np.min(result[:,:,0])>=0
    work=None
    if stats:
        a=render(label+'_work',common+code('overlapGather'),tx,{**v,'gTestDebug':1},(W,H))
        work=dict(meanLeafTests=float(a[:,:,0].mean()),maxLeafTests=float(a[:,:,0].max()),
            meanSourceTests=float(a[:,:,1].mean()),maxSourceTests=float(a[:,:,1].max()),
            meanContributors=float(a[:,:,2].mean()),maxContributors=float(a[:,:,2].max()))
    return result,runoff,residual,work

def oracle(packets,intervals,axis=0):
    # Double reference, source-local integration with identical input endpoints.
    a=packets if axis==0 else packets.transpose(1,0,2)
    b=intervals if axis==0 else intervals.transpose(1,0,2)
    H,W=a.shape[:2];r=np.zeros_like(a,dtype=np.float64);lost=np.zeros(4,np.float64)
    for y in range(H):
        for i in range(W):
            if a[y,i,0]<=0:continue
            lo,hi=map(float,b[y,i,:2]);width=hi-lo
            inside=max(min(hi,W)-max(lo,0),0)/width
            lost+=a[y,i]*(1-min(inside,1))
            for x in range(max(0,int(np.floor(lo))),min(W,int(np.ceil(hi)))):
                overlap=max(min(hi,x+1)-max(lo,x),0)/width
                r[y,x]+=a[y,i]*overlap
    return (r if axis==0 else r.transpose(1,0,2)),lost

checks=[]
W,H=256,8;initial=np.zeros((H,W,4),np.float32);initial[2:6,80:120]=(.125,.025,-.0125,.003125)
for travel in (0,1,17.25,60.25,-60.25,300,-300):
    m=mapped(W,H,travel)
    result,loss,error,work=step('translation_'+str(travel),initial,m)
    ref,refLoss=oracle(initial,m)
    assert np.allclose(result,ref,rtol=2e-6,atol=2e-8) and np.allclose(loss,refLoss,rtol=2e-6,atol=1e-7)
    assert np.max(abs(error))<2e-6,(travel,error)
checks.append('uniform +/-60.25 and out-of-domain +/-300-cell translations preserve positive volume and signed momentum')

# The s88 crossing-departure case now uses each donor's own translated support.
# This proves remap positivity/conservation, NOT correctness of these trajectories.
flat=np.zeros((H,W,4),np.float32);flat[:,:,:]=(.125,.025,-.0125,0)
m=mapped(W,H);m[:,128:,:2]+=60
result,loss,error,work=step('sharp_donor_velocity',flat,m)
reference,_=oracle(flat,m)
assert np.allclose(result,reference,rtol=2e-6,atol=2e-8) and np.max(abs(error))<1e-5
checks.append('sharp donor travel change has positive stock; no global primitive subtraction or max(0) correction')

# Arbitrary overlap, opposite velocities, strong compression and boundaries.
rng=np.random.default_rng(89)
packets=np.zeros((H,W,4),np.float32);packets[:,:,0]=10**rng.uniform(-6,-1,(H,W))
packets[:,:,1:]=packets[:,:,:1]*rng.uniform(-2,2,(H,W,3))
interval=mapped(W,H);interval[:,:,:2]+=rng.uniform(-100,100,(H,W,1))
interval[:,:,1]=interval[:,:,0]+rng.uniform(.02,20,(H,W))
result,loss,error,work=step('mixed_overlap',packets,interval,stats=True)
ref,refLoss=oracle(packets,interval)
assert np.allclose(result,ref,rtol=3e-6,atol=1e-7)
assert np.max(abs(error))<1e-4 and np.allclose(loss,refLoss,rtol=3e-6,atol=1e-6)
mixedWork=work
checks.append('unordered positive-width intervals, opposing momentum, compression/expansion and explicit boundary ledger match double overlap reference')

# Exact affine frozen velocity trajectories: x'=exp(lambda*dt)*x + constant.
# Supplying BOTH endpoints resolves volume compression, unlike centre-only splats.
affine=[]
for rate in (-2.,2.):
    for hz in (30,60,144):
        factor=np.exp(rate/hz);m=mapped(W,H,travel=(1-factor)*128,stretch=factor)
        result,loss,error,_=step('affine_'+str(rate)+'_'+str(hz),initial,m)
        ref,_=oracle(initial,m)
        assert np.allclose(result,ref,rtol=3e-6,atol=1e-7) and np.max(abs(error))<1e-5
        affine.append(dict(rate=rate,hz=hz,ledgerError=error.tolist(),maximumReferenceError=float(np.max(abs(result-ref)))))
checks.append('supplied analytic compression/expansion endpoints at 30/60/144Hz match spatial reference; not a time-dependent PDE convergence gate')

# Large prefix-free pool no longer erases distant tiny translations.
wide=np.zeros((1,1024,4),np.float32);wide[0,0,0]=1e6;wide[0,64:128,0]=.001
m=mapped(1024,1,17.25);result,loss,error,work=step('large_pool_thin_trace',wide,m,stats=True)
ref,_=oracle(wide,m)
thinError=float(np.max(abs(result[0,64:160,0]-ref[0,64:160,0])))
assert thinError<1e-9 and np.max(abs(error))<1e-5
thinWork=work
checks.append('large separated pool plus .001mm3 trace retains local translation, unlike s88 global float32 primitive')

# Non-power-of-two / final partial leaves, column orientation and empty water.
odd=np.zeros((19,73,4),np.float32);odd[3:16,17:60]=(.125,.05,-.025,0)
a,la,ea,_=step('odd_x',odd,mapped(73,19,-17.25))
b,lb,eb,_=step('odd_y',a,mapped(73,19,6.75,axis=1),axis=1)
ref,refLoss=oracle(a,mapped(73,19,6.75,axis=1),1)
assert np.allclose(b,ref,rtol=2e-6,atol=1e-7) and np.max(abs(ea))+np.max(abs(eb))<1e-5
empty,loss,error,_=step('empty',np.zeros_like(odd),mapped(73,19,200))
assert np.max(abs(empty))==0 and np.max(abs(loss))==0
checks.append('partial leaves, two axes, empty wet support and explicit runoff')

# Report real work for typical uniform flow and worst compressed support.
prod=np.zeros((1,1024,4),np.float32);prod[:,:,0]=.125
result,loss,error,typicalWork=step('production_row_uniform',prod,mapped(1024,1,60.25),stats=True)
assert np.max(abs(error))<1e-5
compression=mapped(1024,1,travel=512.25,stretch=.0004)
result,loss,error,worstWork=step('crowded_destination',prod,compression,stats=True)
assert np.max(abs(error))<1e-3 and worstWork['maxSourceTests']==1024
checks.append('work counts expose full-row gather under extreme concentration; no skipped contributors or hidden budget clipping')

expanded=np.zeros((1,256,4),np.float32);expanded[:,:,0]=.125
wideIntervals=np.zeros_like(expanded);wideIntervals[:,:,0]=-256;wideIntervals[:,:,1]=512
result,loss,error,expandedWork=step('overlapping_wide_intervals',expanded,wideIntervals,stats=True)
assert np.max(abs(error))<1e-4 and expandedWork['meanSourceTests']==256
checks.append('adversarial broad overlapping intervals expose quadratic row work; candidate is not universally low cost')

report=dict(step='s89',compiler='FXC ps_5_0 /Ges /WX + D3D11 WARP',checks=checks,
    affineFrozenIntervalReferences=affine,thinTranslationMaxErrorMM3=thinError,
    work=dict(uniform1024=typicalWork,largePoolThin=thinWork,mixed=mixedWork,extremeCompression=worstWork,broadOverlap256=expandedWork),
    rawScratchAt1024x256Bytes=dict(intervalRG32=1024*256*8,leafBoundsAndLossRGBA32=64*256*2*16,
        groupBoundsRGBA32=4*256*16,resultRGBA32=1024*256*16),
    remapPassesPerAxis=3,axes=2,trajectoryPassesIncluded=False,runtimeIntegrated=False,gameTimingMeasured=False,
    arithmeticGatePassed=True,fullTransportTimeGatePassed=False,
    decision='Retain as positive conservative arithmetic candidate; production trajectory generation, curved support, variable-flow convergence and worst-case GPU cost remain open.',
    limits=['Finite positive-width input intervals are required; no runtime invalid-map publication path implemented',
            'Arbitrary interval crossings conserve positive water but can represent unphysical multistream trajectories',
            'Double oracle validates arithmetic, not a solution to the physical film equations',
            'No contact-line/capillary-pressure solver, no pool/epoch/runtime integration',
            'Recipient accumulation can still lose sub-ULP water where huge and tiny packets truly coincide',
            'Extreme concentration needs up to 1024 source tests per destination per axis; do not silently cap this loop'])
(OUT/'overlap_checks.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:report[k] for k in ('checks','thinTranslationMaxErrorMM3','work','decision')},indent=2))
