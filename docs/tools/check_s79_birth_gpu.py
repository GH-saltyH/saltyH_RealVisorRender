"""Actual P2 event/state/meta/reduction programs, FXC /WX and D3D11 WARP."""
from pathlib import Path
import re,json,math,hashlib,difflib,sys,tempfile
sys.dont_write_bytecode=True
import numpy as np
from check_s75_inputs import load_lua
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-14/s79'
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text()
env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')};exec(base[:base.index('report=[]')],env)
env['OUT']=OUT;render=env['render'];inline=env['inline']
env['types'].update({'gBirthWeights':'float4','gBirthAirWorld':'float3','gBirthObjectToWorld':'float4x4',
    'gRainObjectToWorld':'float4x4','gRainAcceleration':'float3','gRainAirVelocityWorld':'float3',
    'gRainSiInertiaWorld':'float3','gRainSiAirWorld':'float3','gRainStateSingleDropPosition':'float2',
    'gRainWetPathTexel':'float2'})
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
metric=(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text();core=(ROOT/'shaders/rainPhysicsSI.hlsl').read_text()
def code(name):return (ROOT/f'shaders/{name}.hlsl').read_text()
def helpers(text,key):return re.sub(r'SamplerState\s+\w+\s*\{.*?\};','',inline(text,key),flags=re.S).split('        float4 main(PS_IN pin) {')[0]
stateCode=metric+core+helpers(source,'local rainStateUpdateParams =')+code('rainStateEntry')
metaCode=metric+core+helpers(source,'local rainStateMetaUpdateParams =')+code('rainMetaEntry')
eventCode=metric+core+code('rainBirthEvent')
baseline=OUT/'baseline';old=(baseline/'realvisor.lua').read_text(encoding='utf-8-sig')
oldState=metric+core+helpers(old,'local rainStateUpdateParams =')+(baseline/'shaders/rainStateEntry.hlsl').read_text()
oldMeta=metric+core+helpers(old,'local rainStateMetaUpdateParams =')+(baseline/'shaders/rainMetaEntry.hlsl').read_text()
N=128;ref=6/4096
du=np.zeros((8,32,4),np.float32);du[:,:,0]=1;du[:,:,3]=100
dv=np.zeros_like(du);dv[:,:,1]=1;mask=np.ones_like(du)
normal=np.ones_like(du)*.5;normal[:,:,2]=1;normal[:,:,3]=1
sites=np.tile(np.array([.5,.5,0,1],np.float32),(1,8192,1))
state=np.tile(np.array([.5,-.5,0,0],np.float32),(1,N,1))
meta=np.zeros_like(state);meta[:,:,3]=28 # generation 7, dead, V=0
d=.65;V=math.pi*d**3/6;fall=4.1665*d-.0833
dsd=np.zeros((2,128,4),np.float32);dsd[0,63:]=1;dsd[1,:,0]=d;dsd[1,:,1]=V;dsd[1,:,2]=fall
impact=np.tile(np.array([.5,.2,.1,.2],np.float32),(4,32,1))
textures={'txRainDu':du,'txRainDv':dv,'txRainBoundaryMask':mask,'txBirthNormal':normal,
    'txBirthSites':sites,'txBirthDsd':dsd,'txBirthImpact':impact,'txRainState':state,'txRainStateMeta':meta}
values={'gBirthCount':N,'gBirthTick':1,'gBirthDt':.01,'gBirthAreaM2':1,'gBirthNumberDensity':N/(10*.01),
    'gBirthWeights':(0,1,0,0),'gBirthObjectToWorld':np.eye(4).ravel(),'gBirthNormalSign':1,
    'gBirthAirWorld':(1,0,-10),'gBirthIncidentAirFraction':1,'gBirthExposure':1,
    'gBirthRhoWater':998.2,'gBirthGamma':.0728,'gBirthMu':.001002,'gBirthTheta':90,
    'gBirthTangentFraction':.25,'gBirthMinPersistentMM':.25,'gBirthWetOverride':0,
    'gBirthAdvanceBare':100,'gBirthAdvanceCoat':92,
    'gRainReferencePerMM':ref,'gRainMetersPerUnit':.001/ref}
motion={'gRainStateCount':N,'gRainStateInit':0,'gRainStateDeltaTime':.01,'gRainStateLifecycle':1,
    'gRainStatePhysics':0,'gRainBirthOn':1,'gRainSiOn':1,'gRainSiTheta':90,
    'gRainStatePhysicalDiameterUVPerMM':ref,'gRainStatePhysicalRadiusUVPerMM':ref/2,
    'gRainObjectToWorld':np.eye(4).ravel(),'gRainStateSingleDropPosition':(.5,-.5),
    'gRainReferencePerMM':ref,'gRainMetersPerUnit':.001/ref}
reports=[]
events=render('actual_birth_event',eventCode,textures,values,(N,4))
assert np.allclose(events[0,:,2],V*.5,rtol=1e-6) and np.all(events[0,:,3]==9),events[:,0]
assert np.allclose(events[1,:,:2],[.25,-fall*.25],rtol=1e-6)
assert np.allclose(events[2],[V,V*.2,V*.1,V*.2],rtol=1e-6)
assert np.allclose(events[3],[0,0,V*.5,1],rtol=1e-6)
assert np.allclose(events[1,:,3],998.2*100*d*.001/.0728,rtol=1e-6)
newTx={**textures,'txRainBirthEvent':events}
newState=render('actual_birth_state_commit',stateCode,newTx,motion,(N,1))
newMeta=render('actual_birth_volume_commit',metaCode,newTx,motion,(N,1))
assert np.allclose(newState[0,:,:2],[.5,-.5]) and np.allclose(newState[0,:,2:],[.25,-fall*.25])
assert np.allclose(newMeta[0,:,1],V*.5) and np.all(newMeta[0,:,3]==33)
radius=(6*(V*.5)/(math.pi*4))**(1/3)*ref
assert np.allclose(newMeta[0,:,0],radius,rtol=1e-6)
init=render('P2_empty_meta_init',metaCode,newTx,{**motion,'gRainStateInit':1},(N,1))
assert np.max(abs(init))==0
deadAgain=newMeta.copy();deadAgain[:,:,0:3]=0;deadAgain[:,:,3]=32
stale=render('event_cannot_repeat_generation',metaCode,{**newTx,'txRainStateMeta':deadAgain},motion,(N,1))
assert np.max(stale[:,:,1])==0 and np.all(stale[:,:,3]==32)
reports.append(dict(case='actual same-event state/volume commit, empty initialization, no stale generation replay',volumeMM3=V))
# Budget the same bank commit, then a full-slot arrival, then edge runoff.
def budget(label,event,metas,previous):
    blocks=math.ceil(metas.shape[1]/64)
    reduced=render(label+'_blocks',code('rainBirthBlocks'),{'txBirthEvent':event,'txRainNewMeta':metas},
                   {'gBirthCount':metas.shape[1],'gBirthBlocks':blocks},(blocks,2))
    totals=render(label+'_totals',code('rainBirthTotals'),{'txBirthBlocks':reduced,'txBirthPreviousTotals':previous},
                  {'gBirthBlocks':blocks},(1,4))
    v=totals[:2,0].ravel();residual=v[0]-sum(v[1:7])
    assert abs(residual)<max(1e-4,float(v[0])*5e-6),(label,v,residual)
    return totals,residual
totals,residual=budget('first_birth',events,newMeta,np.zeros((4,1,4),np.float32))
busyEvents=render('occupied_slot_arrival',eventCode,{**textures,'txRainState':newState,'txRainStateMeta':newMeta},values,(N,4))
assert np.max(busyEvents[0,:,2:])==0 and np.allclose(busyEvents[3,:,0],V*.5)
busyMeta=render('occupied_slot_commit',metaCode,{**newTx,'txRainBirthEvent':busyEvents,'txRainStateMeta':newMeta},motion,(N,1))
totals,residual=budget('occupied_arrival',busyEvents,busyMeta,totals)
exitState=state.copy();exitState[:,:,:2]=2
exitEvents=render('exit_volume_event',eventCode,{**textures,'txRainState':exitState,'txRainStateMeta':busyMeta},values,(N,4))
assert np.allclose(exitEvents[3,:,1],V*.5)
exitMeta=render('exit_meta_commit',metaCode,{**newTx,'txRainBirthEvent':exitEvents,'txRainState':exitState,'txRainStateMeta':busyMeta},motion,(N,1))
assert np.max(exitMeta[:,:,1])==0
totals,residual=budget('edge_exit',exitEvents,exitMeta,totals)
stats=render('manual_R32_staging',code('rainBirthStats'),{'txBirthTotals':totals},{},(8,1))
assert np.array_equal(stats[0,:,0],totals[:2,0].ravel())
reports.append(dict(case='persistent source/film/micro/bounce/capacity/edge/drop inventory balance and stats staging',
                    finalTotalsMM3=totals[:2,0].ravel().tolist(),residualMM3=float(residual)))
# At lambda=3, two expected excess packets go to unresolved continuum, no loop.
overflow=render('bounded_lambda3',eventCode,textures,{**values,'gBirthNumberDensity':values['gBirthNumberDensity']*3},(N,4))
assert np.allclose(overflow[2,:,0],V*3,rtol=1e-6) and np.allclose(overflow[3,:,0],V*2,rtol=1e-6)
_,residual=budget('overflow',overflow,newMeta,np.zeros((4,1,4),np.float32))
micro=render('microscopic_route',eventCode,textures,{**values,'gBirthMinPersistentMM':1},(N,4))
assert np.max(micro[0,:,2:])==0 and np.allclose(micro[2,:,2],V*.6)
_,residual=budget('micro_only',micro,np.zeros_like(meta),np.zeros((4,1,4),np.float32))
reports.append(dict(case='bounded high-rate overflow and microscopic source route conserve volume',passed=True))
# Normal, incidence and SI Jacobian invariance; scalar speed never replaces dot.
grazing=render('grazing_velocity',eventCode,textures,{**values,'gBirthAirWorld':(80,0,0)},(N,4))
assert np.max(grazing[2])==0
backSites=sites.copy();backSites[:,:,2]=-1
back=render('authored_outward_orientation',eventCode,{**textures,'txBirthSites':backSites},values,(N,4))
assert np.max(back[2])==0
flip=render('explicit_outward_calibration',eventCode,{**textures,'txBirthSites':backSites},
            {**values,'gBirthNormalSign':-1},(N,4))
assert np.array_equal(flip,events)
u=du.copy();v=dv.copy();u[:,:,0]=.5;v[:,:,0]=.2;v[:,:,1]=.3
skew=render('skewed_birth_impulse',eventCode,{**textures,'txRainDu':u,'txRainDv':v},values,(N,4))
worldX=skew[1,:,0]*.5+skew[1,:,1]*.2;worldY=skew[1,:,1]*.3
assert np.allclose(worldX,.25,atol=2e-6) and np.allclose(worldY,-fall*.25,atol=2e-6)
for ratio in (.5,2):
    invariant=render('reference_'+str(ratio),eventCode,textures,{**values,'gRainReferencePerMM':ref*ratio,
        'gRainMetersPerUnit':.001/(ref*ratio)},(N,4))
    assert np.array_equal(invariant,events)
reports.append(dict(case='actual authored/explicit outward normal, grazing rejection and raw SI skew/reference invariance',passed=True))
rotation=np.array([[0,0,-1,0],[0,1,0,0],[1,0,0,0],[0,0,0,1]],np.float32)
rotated=render('rotated_outward_incidence',eventCode,textures,{**values,
    'gBirthObjectToWorld':rotation.T.ravel(),'gBirthAirWorld':(-10,0,-1)},(N,4))
assert np.allclose(rotated,events,rtol=2e-6,atol=1e-6)
scaled=np.eye(4,dtype=np.float32);scaled[:3,:3]*=2
scaleEvent=render('physical_scale2',eventCode,textures,{**values,
    'gBirthObjectToWorld':scaled.T.ravel(),'gBirthAreaM2':4},(N,4))
assert np.allclose(scaleEvent[2,:,0],V*4,rtol=1e-6)
assert np.allclose(scaleEvent[1,:,:2]*2,events[1,:,:2],rtol=1e-6)
reports.append(dict(case='rotated world incidence and physical scale2 area4/UV-velocity-half',passed=True))
# Established P1/legacy programs remain numerically identical when P2 is OFF.
alive=np.zeros_like(meta);alive[:,:,0]=.65*2**(1/3)*ref/2;alive[:,:,1]=V;alive[:,:,2]=2;alive[:,:,3]=1
for si in (0,1):
    for kind,current,previous in [('state',stateCode,oldState),('meta',metaCode,oldMeta)]:
        vals={**motion,'gRainBirthOn':0,'gRainSiOn':si,'gRainStatePhysics':0,'gRainStateAgeMin':8,'gRainStateAgeMax':18}
        tx={**textures,'txRainStateMeta':alive}
        a=render(f'off_{si}_{kind}',current,tx,vals,(N,1));b=render(f'ref_{si}_{kind}',previous,tx,vals,(N,1))
        assert np.array_equal(a,b),(si,kind)
reports.append(dict(case='P2 OFF legacy and P1 state/meta are bit-identical to acc0c63',passed=True))
# Production macro combination and actual SI volume/momentum merge, no birth supply.
vols=[math.pi*.65**3/6,math.pi*2.25**3/6]
mergeState=np.array([[[.5,-.5,.03,0],[.5001,-.5,-.02,0]]],np.float32)
mergeMeta=np.array([[[.65*2**(1/3)*ref/2,vols[0],2,1],[2.25*2**(1/3)*ref/2,vols[1],2,1]]],np.float32)
command=np.array([[[0,1/255,64/255,1],[0,0,64/255,1]]],np.float32)
tx={**textures,'txRainState':mergeState,'txRainStateMeta':mergeMeta,'txRainMergeCmd':command}
val={**motion,'gRainStateCount':2,'gRainStateDeltaTime':0,'gRainMergeEnabled':1,'gRainMergeReach':1.15,
     'gRainMergeMaxDiameterMM':.1,'gRainWetPathTexel':(.01,.04),'gRainWetPathGain':.3,'gRainWetPathMinSpeed':.001}
defines='#define RAIN_MERGE_CODE\n#define RAIN_WETPATH_CODE\n'
a=render('P2_macros_state',defines+stateCode,tx,val,(2,1));b=render('P2_macros_meta',defines+metaCode,tx,val,(2,1))
assert b[0,0,1]==0 and math.isclose(float(b[0,1,1]),sum(vols),rel_tol=1e-6)
assert math.isclose(float(a[0,1,2]),(.03*vols[0]-.02*vols[1])/sum(vols),rel_tol=1e-5)
reports.append(dict(case='P2 production merge/wetpath macros /WX compile and conserve V/momentum',passed=True))
# Maximum normal production slots: event pass is 4096x4, no hidden stamp cap.
fullState=np.tile(state[0,0],(1,4096,1));fullMeta=np.zeros_like(fullState)
full=render('4096_slot_event',eventCode,{**textures,'txRainState':fullState,'txRainStateMeta':fullMeta},
    {**values,'gBirthCount':4096,'gBirthNumberDensity':4096/(10*.01)},(4096,4))
assert np.allclose(full[0,:,2],V*.5)
reports.append(dict(case='4096-slot immutable event execution, finite values and no CPU stamp limit',passed=True))
# Real offline DSD CDF, with arrival-speed weighting on an upward plane.
asset=(ROOT/'texture/RAIN_BIRTH/dsd.dds').read_bytes()
actualDsd=np.frombuffer(asset,'<f4',offset=148).reshape(2,128,4)
helperCode=eventCode[:eventCode.index('float4 main(PS_IN pin)')]
endpoint=render('CDF_float_endpoint',helperCode+'float4 main(PS_IN pin) {return rbDsd(16777215.0/16777216.0);}',
    {**textures,'txBirthDsd':actualDsd},{**values,'gBirthWeights':(.3,.6999999,0,0)},(1,1))
assert endpoint[0,0,0]<=4.5,endpoint
upU=du.copy();upV=dv.copy();upV[:,:,:3]=[0,0,-1] # cross = world up
upSites=sites.copy();upSites[:,:,2]=1
physicalCount=4096;prob=np.diff(np.r_[0,actualDsd[0,:,2].astype(np.float64)])
speed=actualDsd[1,:,2].astype(np.float64);volume=actualDsd[1,:,1].astype(np.float64)
density=.3*physicalCount/(float(speed.max())*.01)
expectedVolume=density*.01*float(np.dot(prob,volume*speed))*16
expectedCount=density*.01*float(np.dot(prob,speed))*16
observedV=0;observedN=0
for tick in range(16):
    result=render('DSD_arrivals_'+str(tick),eventCode,{**textures,'txBirthDsd':actualDsd,
        'txRainDu':upU,'txRainDv':upV,'txBirthSites':upSites,'txRainState':fullState,'txRainStateMeta':fullMeta},
        {**values,'gBirthCount':physicalCount,'gBirthNumberDensity':density,'gBirthTick':tick,'gBirthAirWorld':(0,0,0),
         'gBirthWeights':(0,0,1,0)},(physicalCount,4))
    observedV+=float(result[2,:,0].sum(dtype=np.float64));observedN+=float(result[3,:,3].sum())
assert abs(observedV/expectedVolume-1)<.06,(observedV,expectedVolume)
assert abs(observedN/expectedCount-1)<.035,(observedN,expectedCount)
probability=.3*speed/float(speed.max())
volumeSigma=math.sqrt(65536*(float(np.dot(prob,probability*volume**2))-float(np.dot(prob,probability*volume))**2))
volumeZ=(observedV-expectedVolume)/volumeSigma
assert abs(volumeZ)<4
reports.append(dict(case='real 128-bin DSD and terminal-speed encounter rejection sample statistics, 65536 proposals',
    volumeRatio=observedV/expectedVolume,countRatio=observedN/expectedCount,volumeZScore=volumeZ))
# Small increments survive a large long-session total under actual FXC optimization.
large=np.zeros((4,1,4),np.float32);large[0,0,0]=1e8
tiny=np.zeros((2,1,4),np.float32);tiny[0,0,0]=.5
for i in range(17):
    large=render('Kahan_'+str(i),code('rainBirthTotals'),{'txBirthBlocks':tiny,'txBirthPreviousTotals':large},
                 {'gBirthBlocks':1},(1,4))
assert large[0,0,0]>1e8 and large[2,0,0]!=0,large[:,0]
reports.append(dict(case='precise GPU Kahan retains sub-ULP supply against 1e8 mm3 cumulative total',
    increment=float(large[0,0,0]-1e8),compensation=float(large[2,0,0])))
OUT.mkdir(exist_ok=True)
(OUT/'gpu_checks.json').write_text(json.dumps(dict(compiler='FXC ps_5_0 /Ges /WX',checks=reports),indent=2))
print('s79 GPU:',len(reports),'checks passed')
