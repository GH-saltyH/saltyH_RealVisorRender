"""Actual P3 programs: /WX WARP, conserved deposition, units and source ledger."""
from pathlib import Path
import re,json,sys,math
sys.dont_write_bytecode=True
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s81';OUT.mkdir(exist_ok=True)
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text();env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')}
exec(base[:base.index('report=[]')],env);env['OUT']=OUT;render=env['render'];inline=env['inline']
env['types'].update({n:'float2' for n in ('gFilmGrid','gFilmPaddedSize','gFilmReductionSize','gTile','gDynamicDropP3Grid')})
env['types'].update({n:'float3' for n in ('gRainObjectToWorld','gBirthAirWorld')})
from rain_shader_source import source as code
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
metric=code('rainSurfaceMetric');core=code('rainPhysicsSI')
common=metric+core
descriptor=common+code('rainFilmDescriptor');postmeta=core+code('rainFilmMeta')
traversal=inline(source,'rainDynamicSceneCopyState.gpuHeadsPassB =').split('void rgWalk(',1)[1]
traversal='void rgWalk('+traversal
for old,new in [('    if(rainValid(float2(pin.Tex.x,pin.Tex.y-1))<.5) return 0;',''),
    ('    float2 px = tex * gSize;','    float2 px = floor(tex*gFilmPaddedSize);'),
    ('    acc *= rainValid(float2(pin.Tex.x,pin.Tex.y-1));',''),('    return acc;','    return pfResolve(px,acc);')]:
    assert traversal.count(old)==1;traversal=traversal.replace(old,new)
resolve=code('rainFilmResolve')+traversal
W,H,P=64,16,16;size=(W+2*P,H+2*P)
values=dict(gFilmGrid=(W,H),gFilmPad=P,gFilmPaddedSize=size,gFilmScale2=1,gFilmDt=.02,gFilmMotionDt=.02,
    gFilmTheta=90,gFilmMu=.001002,gFilmGamma=.0728,gFilmAirMS=0,gFilmEvapUMS=0,gFilmMicroJoinUM=20,
    gFilmDepositBare=.35,gFilmDepositCoat=.05,gFilmMinSpeedMS=.001,gFilmWiden=.5,
    gRainReferencePerMM=6/4096,gRainMetersPerUnit=.001/(6/4096),gFilmCount=1,gCount=1,
    gTile=(16,16),gTilesX=size[0]//16,gTilesY=size[1]//16,gWords=1,gMaskW=size[0]//16,
    gSummaryW=size[0]//16,gSummaryWords=1,gSparseWords=1,gFlipY=0,gDebug=0,
    gFilmReductionSize=(size[0]//16,size[1]//16))
cells=np.zeros((H,W,4),np.float32);cells[:,:,0]=.25;cells[:,:,1]=1;cells[:,:,3]=1
field=np.zeros((size[1],size[0],4),np.float32)
def fieldStep(label,descriptors,old=field,cells=cells,vals=values):
    val={**vals,'gCount':descriptors.shape[1]};val['gWords']=math.ceil(descriptors.shape[1]/96)
    val['gMaskW']=int(val['gTilesX'])*val['gWords'];val['gSummaryWords']=math.ceil(val['gWords']/96)
    val['gSummaryW']=int(val['gTilesX'])*val['gSummaryWords']
    tile=render(label+'_bins',code('rainFilmBin'),{'txFilmDescriptors':descriptors},val,(val['gMaskW'],int(val['gTilesY'])))
    summary=render(label+'_summary',inline(source,'rainDynamicSceneCopyState.gpuHeadsSummaryPass ='),{'txMask':tile},val,(val['gSummaryW'],int(val['gTilesY'])))
    result=render(label+'_resolve',resolve,{'txFilmDescriptors':descriptors,'txMask':tile,'txSummary':summary,
        'txFilmPrevious':old,'txFilmCells':cells},val,size)
    return result
reports=[]
for j,(a,b,k) in enumerate([((22.1,23.2),(64.3,25.6),(1,1)),((31.7,24.1),(36.9,30.2),(3,2)),
                           ((16,16),(16,16),(16,16)),((78.8,19.2),(78.9,28.5),(1,4)),
                           ((20,16),(70,30),(16,3))]):
    d=np.zeros((5,1,4),np.float32);d[0,0]=[*a,*b];d[1,0]=[1.25,*k,0]
    d[2,0]=[36.2,26.9,3,2];d[3,0]=[3,4,0,0]
    d[4,0]=[min(a[0],b[0])-k[0],min(a[1],b[1])-k[1],max(a[0],b[0])+k[0],max(a[1],b[1])+k[1]]
    d[4,0,:2]=np.minimum(d[4,0,:2],d[2,0,:2]-d[3,0,:2]);d[4,0,2:]=np.maximum(d[4,0,2:],d[2,0,:2]+d[3,0,:2])
    result=fieldStep('partition_'+str(j),d)
    summed=result.sum(axis=(0,1),dtype=np.float64);error=float(summed.sum()-6.25)
    assert abs(error)<6.25e-6,(j,summed,error)
    assert np.min(result)>=0
    if j in (2,3):assert summed[3]>0
    reports.append(dict(case='actual sparse conservative point/swept lattice deposition',path=[a,b],kernel=k,
                        sumMM3=summed.tolist(),residualMM3=error))
# Supported interior holes route the rejected share to runoff, never renormalize.
holes=cells.copy();holes[:,32:40,0]=0
evapValues={**values,'gFilmEvapUMS':2}
wet=fieldStep('holes_and_evap',d,cells=holes,vals=evapValues)
assert abs(float(wet.sum(dtype=np.float64))-6.25)<6.25e-6
assert wet[:,:,2].sum()>0 and wet[:,:,3].sum()>0
reports.append(dict(case='holes/halo runoff + current-step evaporation preserve source',sumMM3=float(wet.sum(dtype=np.float64))))
partial=cells.copy();partial[:,32:40,0]*=.25;partial[:,32:40,1]=.25
partialResult=fieldStep('partial_boundary',d,cells=partial)
assert abs(float(partialResult.sum(dtype=np.float64))-6.25)<6.25e-6 and partialResult[:,:,3].sum()>0
reports.append(dict(case='partial boundary coverage debits rejected footprint as runoff',sumMM3=float(partialResult.sum(dtype=np.float64))))
many=np.zeros((5,4096,4),np.float32)
many[2,:,:]=[36.2,26.9,.001,.0005];many[3,:,:]=[3,4,0,0];many[4,:,:]=[33.2,22.9,39.2,30.9]
crowded=fieldStep('all_4096_sources',many)
crowdedExpected=float(many[2,:,2:].sum(dtype=np.float64))
crowdedError=float(crowded.sum(dtype=np.float64)-crowdedExpected)
assert abs(crowdedError)/crowdedExpected<1e-4,(crowdedError,crowdedExpected)
reports.append(dict(case='all 4096 descriptors resolve through final sparse word, dense overlapping sources',
                    expectedMM3=crowdedExpected,residualMM3=crowdedError))
# Descriptor drives actual metadata; born, pinned and merged positions cannot
# emit a false old-to-new segment. Codec/physical-scale/display independence.
du=np.zeros((8,32,4),np.float32);du[:,:,0]=.2;du[:,:,3]=100
dv=np.zeros_like(du);dv[:,:,1]=.2;mask=np.ones_like(du)
V=math.pi*1.15**3/6;ref=6/4096
oldState=np.array([[[.4,-.5,0,0]]],np.float32);newState=np.array([[[.42,-.5,0,0]]],np.float32)
meta=np.array([[[1.15*2**(1/3)*ref/2,V,2,1]]],np.float32)
events=np.zeros((4,1,4),np.float32)
tx={'txRainDu':du,'txRainDv':dv,'txRainBoundaryMask':mask,'txFilmOldState':oldState,'txFilmNewState':newState,
    'txFilmOldMeta':meta,'txFilmNewMeta':meta,'txFilmBirthEvent':events}
desc=render('physical_descriptor',descriptor,tx,values,(1,5))
assert 0<desc[1,0,0]<V and desc[1,0,3]==0
post=render('physical_meta',postmeta,{'txFilmNewMeta':meta,'txFilmDescriptors':desc},values,(1,1))
assert abs(float(meta[0,0,1]-post[0,0,1]-desc[1,0,0]))<1e-7
actualfield=fieldStep('physical_paired_deposit',desc)
assert abs(float(actualfield.sum(dtype=np.float64)+post[0,0,1]-V))<1e-6
for label,changes in [('pinned',{'txFilmNewState':oldState}),('born',{'txFilmOldMeta':np.zeros_like(meta)}),
                      ('merged',{'txFilmNewMeta':meta*np.array([1,2,1,1],np.float32)})]:
    result=render(label+'_no_false_path',descriptor,{**tx,**changes},values,(1,5))
    assert result[1,0,0]==0,label
for ratio in (.5,2):
    recoded=meta.copy();recoded[:,:,0]*=ratio
    result=render('reference_'+str(ratio),descriptor,{**tx,'txFilmOldMeta':recoded,'txFilmNewMeta':recoded},{**values,'gRainReferencePerMM':ref*ratio,
                  'gRainMetersPerUnit':.001/(ref*ratio)},(1,5))
    assert np.allclose(result,desc,rtol=2e-6,atol=2e-6)
evapDesc=render('actual_head_evap',descriptor,tx,{**values,'gFilmEvapUMS':5},(1,5))
evapMeta=render('actual_head_evap_commit',postmeta,{'txFilmNewMeta':meta,'txFilmDescriptors':evapDesc},values,(1,1))
assert evapDesc[1,0,3]>0 and abs(float(meta[0,0,1]-evapMeta[0,0,1]-sum(evapDesc[1,0,[0,3]])))<1e-7
reports.append(dict(case='actual descriptor/head debit, pinned/birth/merge skip, reference invariant, quantized evaporation',
                    depositedMM3=float(desc[1,0,0]),headEvapMM3=float(evapDesc[1,0,3])))
# Actual extended P2 + field budget, including incident capacity and head debit.
events[0,0,:2]=(.5,-.5);events[1,0,2]=1;events[2,0]=[1,.2,.1,.3];events[3,0]=[.1,0,.3,1]
baseMeta=meta.copy();baseMeta[0,0,1]=.3
baseMeta[0,0,0]=(.3*3/(2*math.pi))**(1/3)*ref
sourceDesc=render('birth_field_descriptor',descriptor,{**tx,'txFilmOldMeta':np.zeros_like(meta),
    'txFilmNewMeta':baseMeta,'txFilmBirthEvent':events},values,(1,5))
assert np.allclose(sourceDesc[2,0,2:],[.3,.1])
sourceField=fieldStep('birth_field_deposition',sourceDesc)
birthBlocks=render('extended_birth_blocks',code('rainBirthBlocks'),{'txBirthEvent':events,'txRainNewMeta':baseMeta,
    'txBirthTransfers':sourceDesc},{'gBirthCount':1,'gBirthBlocks':1,'gBirthFilmOn':1},(1,3))
birthTotals=render('extended_birth_totals',code('rainBirthTotals'),{'txBirthBlocks':birthBlocks,
    'txBirthPreviousTotals':np.zeros((6,1,4),np.float32)},{'gBirthBlocks':1,'gBirthFilmOn':1},(1,6))
# A .3 retained + .2 film + .1 micro + .3 bounce + .1 capacity birth is closed.
blocks=render('actual_field_blocks',code('rainFilmBlocks'),{'txFilmCurrent':sourceField},values,(6,3))
coarse=render('manual_coarse_blocks',code('rainFilmBlocks'),{'txFilmCurrent':blocks},
              {**values,'gFilmReductionSize':(1,1),'gFilmPaddedSize':(6,3)},(1,1))
assert np.allclose(coarse[0,0],blocks.sum(axis=(0,1),dtype=np.float64),rtol=1e-6,atol=1e-8)
totals=render('actual_field_totals',code('rainFilmTotals'),{'txFilmBlocks':blocks,'txFilmBirthTotals':birthTotals,
    'txFilmPreviousTotals':np.zeros((4,1,4),np.float32)},values,(1,4))
v=totals[:,0].ravel();residual=v[8]-v[9]-v[10]-v[11]-v[12]-sum(v[:4])
assert abs(float(residual))<1e-6,(v,residual)
stats=render('actual_field_R32_stats',code('rainFilmStats'),{'txFilmTotals':totals},{},(16,1))
assert np.array_equal(stats[0,:,0],v)
optics=render('actual_physical_height',code('rainFilmOptics'),{'txFilmCurrent':sourceField,'txFilmCells':cells},values,(W,H))
expected=sourceField[P:P+H,P:P+W,:2]/.25*1000
assert np.allclose(optics[:,:,:2],expected,rtol=1e-6)
reports.append(dict(case='actual P2/field budget+capacity, raw float staging and volume/area um optics',residualMM3=float(residual)))
manualTotals=render('manual_two_level_totals',code('rainFilmTotals'),{'txFilmBlocks':coarse,'txFilmBirthTotals':birthTotals},
                    {**values,'gFilmReductionSize':(1,1)},(1,4))
assert np.allclose(manualTotals,totals,rtol=1e-6,atol=1e-8)
# Next atomic step transfers an existing head's water and evaporates part of
# both inventories. The extended P2 and P3 totals must describe the same step.
nextTx={**tx,'txFilmOldState':np.array([[[.5,-.5,0,0]]],np.float32),
        'txFilmNewState':np.array([[[.52,-.5,0,0]]],np.float32),
        'txFilmOldMeta':baseMeta,'txFilmNewMeta':baseMeta,'txFilmBirthEvent':np.zeros_like(events)}
nextValues={**values,'gFilmEvapUMS':5}
stepDesc=render('next_step_transfers',descriptor,nextTx,nextValues,(1,5))
stepMeta=render('next_step_paired_meta',postmeta,{'txFilmNewMeta':baseMeta,'txFilmDescriptors':stepDesc},values,(1,1))
assert stepDesc[1,0,0]>0 and stepDesc[1,0,3]>0
nextField=fieldStep('next_step_field',stepDesc,old=sourceField,vals=nextValues)
nextBirthBlocks=render('next_step_birth_blocks',code('rainBirthBlocks'),{'txBirthEvent':np.zeros_like(events),
    'txRainNewMeta':stepMeta,'txBirthTransfers':stepDesc},{'gBirthCount':1,'gBirthBlocks':1,'gBirthFilmOn':1},(1,3))
nextBirthTotals=render('next_step_birth_totals',code('rainBirthTotals'),{'txBirthBlocks':nextBirthBlocks,
    'txBirthPreviousTotals':birthTotals},{'gBirthBlocks':1,'gBirthFilmOn':1},(1,6))
assert nextBirthTotals[4,0,0]>0 and nextBirthTotals[4,0,1]>0
nextBlocks=render('next_step_field_blocks',code('rainFilmBlocks'),{'txFilmCurrent':nextField},values,(6,3))
nextTotals=render('next_step_field_totals',code('rainFilmTotals'),{'txFilmBlocks':nextBlocks,
    'txFilmBirthTotals':nextBirthTotals,'txFilmPreviousTotals':totals},values,(1,4))
q=nextTotals[:,0].ravel();residual=q[8]-q[9]-q[10]-q[11]-q[12]-sum(q[:4])
assert abs(float(residual))<1e-6,(q,residual)
birthStats=render('extended_P2_R32_stats',code('rainBirthStats'),{'txBirthTotals':nextBirthTotals},{'gBirthFilmOn':1},(12,1))
assert np.array_equal(birthStats[0,:,0],np.r_[nextBirthTotals[:2,0].ravel(),nextBirthTotals[4,0]])
reports.append(dict(case='multi-step paired head trail/evap + current/cumulative field loss and 12-float P2 staging',residualMM3=float(residual)))
# Actual P2 birth/impact consumes previous physical-height optics only at an
# incident packet; wet material fractions must conserve the same source.
birthPrefix=(ROOT/'docs/tools/check_s79_birth_gpu.py').read_text().split('events=render(',1)[0]
birthEnv={'__file__':str(ROOT/'docs/tools/check_s79_birth_gpu.py')};exec(birthPrefix,birthEnv)
birthEnv['env']['OUT']=OUT
impact=np.frombuffer((ROOT/'texture/RAIN_BIRTH/impact_estimated.dds').read_bytes(),'<f4',offset=148).reshape(4,32,4)
bt={**birthEnv['textures'],'txBirthImpact':impact,'txBirthWetHeight':np.ones((8,32,4),np.float32)*20}
bv={**birthEnv['values'],'gBirthWetHeightUM':20}
dry=birthEnv['render']('dry_impact_source',birthEnv['eventCode'],bt,{**bv,'gBirthWetOn':0},(128,4))
wet=birthEnv['render']('wet_impact_source',birthEnv['eventCode'],bt,{**bv,'gBirthWetOn':1},(128,4))
assert np.all(wet[2,:,1]>dry[2,:,1]) and np.array_equal(wet[2,:,0],dry[2,:,0])
assert np.allclose(wet[2,:,0],wet[0,:,2]+wet[2,:,1]+wet[2,:,2]+wet[2,:,3]+wet[3,:,0],rtol=1e-6)
reports.append(dict(case='actual previous wet-height input alters estimated impact partition without changing source',
                    dryFilmMM3=float(dry[2,0,1]),wetFilmMM3=float(wet[2,0,1])))
# Closed no-source drying: current field + accumulated losses remain constant.
empty=np.zeros((5,1,4),np.float32);empty[4,0]=[1e9,1e9,-1e9,-1e9]
prior=sourceField;initial=float(sourceField.sum(dtype=np.float64))
for j in range(12):
    prior=fieldStep('closed_dry_'+str(j),empty,old=prior,vals={**values,'gFilmDt':1,'gFilmEvapUMS':1})
    assert abs(float(prior.sum(dtype=np.float64))-initial)<1e-5
reports.append(dict(case='12-second no-source dry inventory+cumulative-cell-loss balance',residualMM3=float(prior.sum(dtype=np.float64)-initial)))
(OUT/'gpu_checks.json').write_text(json.dumps(dict(compiler='FXC ps_5_0 /Ges /WX, D3D11 WARP',checks=reports),indent=2))
print('s81 GPU:',len(reports),'conservative field/descriptor/ledger checks passed')
