"""Actual SI predictor -> curved-mesh frozen tracing -> volume/momentum remap.

Synthetic water and forces on the real bake, not reconstructed replay textures.
"""
from pathlib import Path
import json,sys
sys.dont_write_bytecode=True
import numpy as np
from PIL import Image
from s90_transport_reference import ROOT,OUT,render,env,code,runs_from_mask,prepare,trace,remap

def shader(name):return (ROOT/f'shaders/{name}.hlsl').read_text(encoding='utf-8-sig')
def asset(name):return np.frombuffer((ROOT/f'texture/RAIN_GEOMETRY/{name}.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
metric=shader('rainSurfaceMetric');core=shader('rainPhysicsSI')
common=metric+core+shader('rainFilmPoolAddress')+shader('rainFilmPoolAvailable')
predictCode=common+code('s88','rainFilmInertia')+code('s88','rainFilmInertiaPass')
packetCode=common+code('s90','tracePacket')
commitCode=metric+core+code('s90','traceVelocityCommit')
W,H=1024,256
cells=np.frombuffer((ROOT/'texture/RAIN_FILM/cells.dds').read_bytes(),'<f4',offset=148).reshape(H,W,4)
du,dv=asset('du'),asset('dv')
mask=np.asarray(Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').convert('RGBA'),np.float32)/255
geo={'txRainDu':du,'txRainDv':dv,'txRainBoundaryMask':mask}
u,v=du[1::2,1::2,:3],dv[1::2,1::2,:3]
normals=np.cross(u,v);length=np.linalg.norm(normals,axis=2);valid=(cells[:,:,0]>0)&(length>1e-10)
normals/=np.maximum(length[:,:,None],1e-30)
runs=runs_from_mask(valid)
field=np.zeros((H+32,W+32,4),np.float32)
field[16:H+16,16:W+16,0]=cells[:,:,0]*.1
field[16:H+16,16:W+16,0][~valid]=0
velocity=np.zeros((H,W,4),np.float32)
events=np.zeros((5,4096,4),np.float32)
# One accepted pool event, same owner/address arithmetic as production.
yy,xx=np.where(valid & (np.indices(valid.shape)[1]>300) & (np.indices(valid.shape)[1]<700))
x,y=int(xx[len(xx)//2]),int(yy[len(yy)//2]);tile=(y//16)*64+x//16
debit=np.float32(field[16+y,16+x,0]*.4)
events[0,tile,:2]=[(x+.5)/W,(y+.5)/H-1];events[4,tile,2]=debit
values=dict(gFilmGrid=(W,H),gFilmPad=16,gFilmScale2=1,gFilmDt=1/60,gFilmMu=.001002,
    gFilmObjectToWorld=np.eye(4,dtype=np.float32).ravel(),gFilmAccelerationWorld=(0,-9.80665,0),
    gFilmAirWorld=(5,0,-10),gFilmAirRho=1.186541,gFilmFlowCf=.005,
    gFilmAirDownward=0,gFilmAirDownwardGain=1,gPoolOn=1,gPoolCount=4096,gPoolTick=0)
tx={**geo,'txFilmPrevious':field,'txFilmCells':cells,'txFilmVelocity':velocity,'txFilmBirthEvent':events}
pred=render('actual_mesh_SI_predictor',predictCode,tx,values,(W,H))
packet=render('actual_mesh_world_packet',packetCode,{**tx,'txFilmPredicted':pred},values,(W,H))
expected=field[16:H+16,16:W+16,0].copy();expected[y,x]-=debit
assert np.array_equal(packet[:,:,0],expected)
sourceMass=float(packet[:,:,0].sum(dtype=np.float64))
assert np.max(abs(pred))>0 and np.min(packet[:,:,0])>=0

current=packet;lostTotal=np.zeros(4);stepData=[]
for axis in (0,1):
    prepared=prepare(pred,runs,axis)
    mapping=trace(current,prepared,values['gFilmDt'])
    current,lost,error,work=remap(current,mapping,runs,axis,stats=True)
    lostTotal+=lost
    assert np.max(abs(error))<max(sourceMass*1e-6,1e-5),error
    assert np.max(abs(current[~valid]))==0
    stepData.append(dict(axis=axis,maxVisits=float(mapping[:,:,3].max()),
        averageWetVisits=float(mapping[:,:,3][packet[:,:,0]>0].mean()),
        meanCandidateTests=float(work[:,:,1].mean()),maxCandidateTests=float(work[:,:,1].max()),
        runoffPacket=lost.tolist(),ledgerError=error.tolist()))
    print('real mesh axis',axis,'passed',flush=True)

sourceTotal=packet.sum(axis=(0,1),dtype=np.float64)
finalTotal=current.sum(axis=(0,1),dtype=np.float64)
assert np.max(abs(finalTotal+lostTotal-sourceTotal))<sourceMass*1e-6
nextVelocity=render('curved_wall_projection',commitCode,{**geo,'txTraceCurrent':current},
    {**values,'gTraceWallDebug':0},(W,H))
reaction=render('curved_wall_reaction',commitCode,{**geo,'txTraceCurrent':current},
    {**values,'gTraceWallDebug':1},(W,H))
tangent=(u*nextVelocity[:,:,:1]+v*nextVelocity[:,:,1:2])*current[:,:,:1]
reactionSum=reaction[:,:,:3].sum(axis=(0,1),dtype=np.float64)
momentumResidual=tangent.sum(axis=(0,1),dtype=np.float64)+reactionSum+lostTotal[1:]-sourceTotal[1:]
assert np.max(abs(momentumResidual))<sourceMass*1e-6
assert np.max(abs(np.sum(tangent*normals,axis=2)))<1e-6

# Optical/display values are outside this predictor/packet/trace contract.
other=render('display_invariant_force_prediction',predictCode,tx,{**values,
    'gDynamicDropP2DisplayScale':2,'gRainDisplayDiameterGain':.25},(W,H))
assert np.array_equal(other,pred)
np.save(OUT/'actualmesh_static_runs.npy',runs)
report=dict(step='s90',compiler='FXC ps_5_0 /Ges /WX + D3D11 WARP',
    actualMeshAndCells=True,syntheticField='100um film on all metric-valid real cells, zero old velocity, gravity and specified local air; one synthetic pool debit',
    validCells=int(valid.sum()),poolDebitMM3=float(debit),sourceMassMM3=sourceMass,
    axes=stepData,volumeResidualMM3=float(finalTotal[0]+lostTotal[0]-sourceTotal[0]),
    momentumResidualWithBoundaryAndWall=momentumResidual.tolist(),wallReaction=reactionSum.tolist(),
    displayCoefficientsIndependent=True,predictorAndRemapBridgePassed=True,runtimeIntegrated=False,
    limits=['One frozen-force synthetic step, not actual game textures or a full coupled film trajectory',
        'Static cell support cannot resolve holes smaller than bake cells',
        'No physical free-boundary velocity extension into dry cells implemented',
        'No pressure/contact-line or actual game performance claim'])
(OUT/'force_geometry_checks.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
