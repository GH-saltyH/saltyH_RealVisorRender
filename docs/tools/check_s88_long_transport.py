"""Offline tiled-prefix long-travel remap: useful reference AND rejection cases."""
from pathlib import Path
import json,sys
sys.dont_write_bytecode=True
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-16/s88'
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text()
env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')};exec(base[:base.index('report=[]')],env)
env['OUT']=OUT;env['types'].update({n:'float2' for n in ('gTestGrid','gTestBlocks','gTestFaces')})
render=env['render']
code=lambda n:(ROOT/f'docs/prototypes/s88/{n}.hlsl').read_text()
def step(label,packets,travel,axis=0):
    H,W=packets.shape[:2];N=W if axis==0 else H;rows=H if axis==0 else W
    faces=(W+1,H) if axis==0 else (W,H+1)
    blocks=((N+15)//16,rows)
    v=dict(gTestGrid=(W,H),gTestFaces=faces,gTestBlocks=blocks,gTestAxis=axis)
    local=render(label+'_local',code('filmPrefixLocal'),{'txTestPackets':packets},v,(W,H))
    tiles=render(label+'_blocks',code('filmPrefixBlocks'),{'txTestLocal':local},v,blocks)
    if np.isscalar(travel):
        t=np.zeros((faces[1],faces[0],4),np.float32);t[:,:,0]=travel
    else:t=travel
    flux=render(label+'_flux',code('filmPrefixFlux'),{'txTestPackets':packets,'txTestLocal':local,
        'txTestBlocks':tiles,'txTestTravel':t},v,faces)
    result=render(label+'_gather',code('filmPrefixGather'),{'txTestPackets':packets,'txTestFlux':flux},v,(W,H))
    runoff=(flux[:,-1]-flux[:,0]).sum(axis=0,dtype=np.float64) if axis==0 else (flux[-1]-flux[0]).sum(axis=0,dtype=np.float64)
    error=result.sum(axis=(0,1),dtype=np.float64)+runoff-packets.sum(axis=(0,1),dtype=np.float64)
    return result,runoff,error

initial=np.zeros((16,256,4),np.float32)
initial[3:13,80:120]=(.125,.025,-.0125,0)
cases=[]
for distance in (0,1,17.25,60.25,-60.25,300,-300):
    actual,loss,error=step('uniform_'+str(distance),initial,distance)
    yy,xx=np.indices(initial.shape[:2]);at=xx-distance
    lo=np.floor(at).astype(int);frac=at-lo
    left=initial[yy,np.clip(lo,0,255)]*(lo>=0)[:,:,None]*(lo<256)[:,:,None]
    right=initial[yy,np.clip(lo+1,0,255)]*(lo+1>=0)[:,:,None]*(lo+1<256)[:,:,None]
    expected=left*(1-frac)[:,:,None]+right*frac[:,:,None]
    assert np.allclose(actual,expected,rtol=1e-4,atol=6e-7),(distance,np.max(abs(actual-expected)))
    assert np.min(actual[:,:,0])>=-1e-6 and np.max(abs(error))<1e-4,(distance,error)
    cases.append(dict(travelCells=distance,maxError=float(np.max(abs(actual-expected))),
        ledgerError=error.tolist(),runoff=loss.tolist()))

horizontal,_,_=step('two_axes_x',initial,60.25)
vertical,loss,error=step('two_axes_y',horizontal,4.5,1)
twoAxisError=error.copy()
assert np.max(abs(error))<1e-4 and np.min(vertical[:,:,0])>=-1e-6
assert loss[0]>0

# Arbitrary face velocities can reverse the ordering of departure points.
# Telescoping water conservation survives, but positivity fails dramatically.
flat=np.zeros_like(initial);flat[:,:,0]=.125
travel=np.zeros((16,257,4),np.float32);travel[:,128:,0]=60
bad,loss,error=step('crossing_departure_faces',flat,travel)
assert np.max(abs(error))<1e-4 and bad[:,:,0].min() < -1

# Global accumulated float32 mass can erase small wet traces in subtraction.
# Keep this as a rejection fixture rather than hiding it in relative total error.
wide=np.zeros((1,1024,4),np.float32);wide[0,0,0]=1e6;wide[0,64:128,0]=.001
precision,_,err=step('large_pool_small_trace',wide,17.25)
thin=precision[0,64:160,0]
index=np.arange(64,160)-17.25
thinExpected=np.clip(np.minimum(index+1,128)-np.maximum(index,64),0,1)*.001
affected=int(np.count_nonzero(abs(thin-thinExpected)>.0001))
assert affected>0
report=dict(step='s88',compiler='FXC ps_5_0 /Ges /WX + D3D11 WARP',
    uniformTranslationCases=cases,twoAxisLedgerError=twoAxisError.tolist(),
    arbitraryFaceVelocity=dict(minimumVolumeMM3=float(bad[:,:,0].min()),ledgerError=error.tolist(),positivityPassed=False),
    dynamicRange=dict(affectedThinCells=affected,totalThinCells=len(thin),thinPacketMM3=.001,
        maximumTranslationErrorMM3=float(np.max(abs(thin-thinExpected))),ledgerError=err.tolist()),
    extraPassesPerAxis=4,axisCount=2,
    rawScratchEstimateBytes=dict(localPrefix=1024*256*16,blockPrefixMax=64*256*16,
        faceFluxMax=1025*256*16,axisIntermediate=1024*256*16),
    runtimeIntegrated=False,gameTimingMeasured=False,arbitraryFlowTimeGatePassed=False,
    decision='Keep as arbitrary-Courant uniform-flow reference. Reject uncorrected remap for game: crossing characteristics and float32 thin-stock errors need treatment.',
    note='Two-axis splitting is not a curved-surface momentum/pressure solver; runoff carries momentum but no external-source stage is included.')
(OUT/'long_transport_checks.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
