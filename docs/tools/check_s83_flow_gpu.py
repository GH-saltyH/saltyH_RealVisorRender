"""Production P4a flux/gather and manual precision: FXC /WX + D3D11 WARP."""
from pathlib import Path
import json,sys
import numpy as np
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s83'
prefix=(ROOT/'docs/tools/check_s81_film_gpu.py').read_text().split('reports=[]',1)[0]
env={'__file__':str(ROOT/'docs/tools/check_s81_film_gpu.py')};exec(prefix,env)
env['env']['OUT']=OUT
render=env['render'];code=env['code'];step=env['fieldStep'];values=env['values'];cells=env['cells'];field=env['field']
P,W,H=env['P'],env['W'],env['H'];size=env['size']
env['env']['types'].update(gFilmObjectToWorld='float4x4',gFilmAccelerationWorld='float3',gFilmAirWorld='float3')
geoU=np.zeros((H*2,W*2,4),np.float32);geoU[:,:,:]=[.032,0,0,100]
geoV=np.zeros_like(geoU);geoV[:,:,:]=[0,.008,0,0]
geo={'txRainDu':geoU,'txRainDv':geoV,'txRainBoundaryMask':np.ones_like(geoU)}
cells=cells.copy();cells[:,:,0]=.25
values={**values,'gFilmFlowOn':1,'gFilmObjectToWorld':np.eye(4).ravel(),
        'gFilmAccelerationWorld':(0,-9.80665,0),'gFilmAirWorld':(0,0,0),
        'gFilmAirRho':1.2,'gFilmFlowCf':.005,'gFilmFlowCFL':.8,'gFilmAirDownward':0,
        'gFilmAirDownwardGain':1,'gFilmFlowReduce':0,'gFilmDt':.01}
flowCode=env['metric']+env['core']+code('rainFilmFlow')
empty=np.zeros((5,1,4),np.float32);empty[4,0]=[1e9,1e9,-1e9,-1e9]
def flux(label,old,v=values):
    raw=render(label,flowCode+code('rainFilmFlowPass'),{**geo,'txFilmCells':cells,'txFilmPrevious':old},v,(W,H))
    return np.pad(raw,((P,P),(P,P),(0,0))) # Test comparisons include the zero-flux halo.
def gather(label,old,q,v=values,c=cells):
    # Build empty sparse traversal once per fixture, using the production bin/summary.
    vv={**v,'gCount':1,'gWords':1,'gMaskW':int(v['gTilesX']),'gSummaryW':int(v['gTilesX'])}
    mask=render(label+'_bins',code('rainFilmBin'),{'txFilmDescriptors':empty},vv,(int(vv['gMaskW']),int(vv['gTilesY'])))
    summary=render(label+'_summary',env['inline'](env['source'],'rainDynamicSceneCopyState.gpuHeadsSummaryPass ='),
                   {'txMask':mask},vv,(int(vv['gSummaryW']),int(vv['gTilesY'])))
    return render(label+'_gather',env['resolve'],{'txFilmDescriptors':empty,'txMask':mask,'txSummary':summary,
        'txFilmPrevious':old,'txFilmFlux':q[P:P+H,P:P+W],'txFilmCells':c},vv,size)
def centroid(a):
    yy,xx=np.indices(a.shape[:2]);m=a[:,:,0].sum(dtype=np.float64)
    return np.array([(xx*a[:,:,0]).sum()/m,(yy*a[:,:,0]).sum()/m])
reports=[]
initial=field.copy();initial[P+5:P+10,P+20:P+28,0]=.025
initial[P+5:P+10,P+20:P+28,1]=.001
q=flux('gravity_faces',initial)
assert q[:,:,2].sum()>0 and q[:,:,[0,1,3]].sum()==0
gravity=gather('gravity_gather',initial,q)
assert centroid(gravity)[1]<centroid(initial)[1]
assert np.array_equal(gravity[:,:,1],initial[:,:,1])
assert abs(gravity.sum(dtype=np.float64)-initial.sum(dtype=np.float64))<1e-6
reports.append(dict(case='gravity moves film downhill, micro stays pinned; paired donor/gather conservation',
                    centroidBefore=centroid(initial).tolist(),centroidAfter=centroid(gravity).tolist()))
normal=flux('normal_force_no_flow',initial,{**values,'gFilmAccelerationWorld':(0,0,-9.80665),'gFilmAirWorld':(0,0,50)})
assert np.max(normal)==0
opposite=flux('reverse_acceleration',initial,{**values,'gFilmAccelerationWorld':(0,9.80665,0)})
assert np.array_equal(opposite[:,:,3],q[:,:,2])
two=initial.copy();two[:,:,0]*=2
slow=flux('thin_film_unlimited',initial,{**values,'gFilmDt':.0001})
twice=flux('height_squared_speed',two,{**values,'gFilmDt':.0001})
assert np.all(abs(twice-slow*8)<=np.spacing(initial[:,:,0,None])*16+1e-12) # Matched float32 debit quantization.
reports.append(dict(case='normal forces do not move film, acceleration reversal, gravity velocity scales h^2'))
air=flux('tangent_air',initial,{**values,'gFilmAccelerationWorld':(0,0,0),'gFilmAirWorld':(5,0,0)})
assert air[:,:,1].sum()>0 and air[:,:,[0,2,3]].sum()==0
down=flux('downward_override',initial,{**values,'gFilmAccelerationWorld':(0,0,0),'gFilmAirWorld':(0,5,0),'gFilmAirDownward':1})
assert down[:,:,2].sum()>0 and down[:,:,3].sum()==0
reports.append(dict(case='tangential air shear and explicit P1 downward override'))
huge={**values,'gFilmDt':10,'gFilmAccelerationWorld':(1000,-1000,0)}
limited=flux('huge_courant_limited',initial,huge)
assert np.all(limited.sum(axis=2)<=initial[:,:,0]*.800001)
remain=gather('limited_gather',initial,limited,huge)
assert np.min(remain)>=0 and abs(remain.sum(dtype=np.float64)-initial.sum(dtype=np.float64))<1e-6
reports.append(dict(case='two-axis severe CFL bounded at 0.8 with positive/conserved stock'))
edge=field.copy();edge[P,P+20:P+28,0]=.025
edgeQ=flux('edge_flux',edge,huge)
edgeResult=gather('edge_runoff',edge,edgeQ,huge)
assert edgeResult[:,:,3].sum()>0
assert abs(edgeResult.sum(dtype=np.float64)-edge.sum(dtype=np.float64))<1e-6
holes=cells.copy();holes[4:12,20:28,0]=0
holeResult=gather('unsupported_recipient',initial,q,c=holes)
assert holeResult[:,:,3].sum()>0 and abs(holeResult.sum(dtype=np.float64)-initial.sum(dtype=np.float64))<1e-6
reports.append(dict(case='halo and unsupported recipients explicitly record runoff'))
prior=initial.copy();mass=float(initial.sum(dtype=np.float64))
for i in range(20):
    old=prior;prior=gather('closed_'+str(i),old,flux('closed_flux_'+str(i),old,huge),huge)
assert abs(float(prior.sum(dtype=np.float64))-mass)/mass<1e-5
reports.append(dict(case='20 actual nonlinear transport steps close stock+runoff ledger',
                    residualMM3=float(prior.sum(dtype=np.float64)-mass)))
noFlow=gather('P4_off',initial,q,{**values,'gFilmFlowOn':0})
baseline=(OUT/'baseline/shaders/rainFilmResolve.hlsl').read_text()+env['traversal']
mask=render('off_bins',code('rainFilmBin'),{'txFilmDescriptors':empty},values,(int(values['gMaskW']),int(values['gTilesY'])))
summary=render('off_summary',env['inline'](env['source'],'rainDynamicSceneCopyState.gpuHeadsSummaryPass ='),{'txMask':mask},values,
    (int(values['gSummaryW']),int(values['gTilesY'])))
oldOutput=render('s81_off_baseline',baseline,{'txFilmPrevious':initial,'txFilmCells':cells,'txFilmDescriptors':empty,
    'txMask':mask,'txSummary':summary},values,size)
assert np.array_equal(noFlow,oldOutput)
reports.append(dict(case='P4 OFF field update is bit-identical to delivered s81'))
blocks=render('limiter_blocks',flowCode+code('rainFilmFlowBlocks'),{**geo,'txFilmPrevious':initial,'txFilmCells':cells},huge,
              (int(values['gFilmReductionSize'][0]),int(values['gFilmReductionSize'][1])*4))
coarseValues={**huge,'gFilmPaddedSize':values['gFilmReductionSize'],'gFilmReductionSize':(5,2),'gFilmFlowReduce':1}
coarse=render('limiter_coarse',flowCode+code('rainFilmFlowBlocks'),{'txFilmFlowBlocks':blocks},coarseValues,(5,8))
stats=render('limiter_readback',code('rainFilmFlowStats'),{'txFilmFlowBlocks':coarse},{},(16,1))[0,:,0]
assert stats[0]>values['gFilmFlowCFL'] and stats[1]==40 and stats[2]==40 and abs(stats[3]-1)<1e-6
reports.append(dict(case='manual MAX/SUM limiter reduction and current 16-float readback (s84)',values=stats.tolist()))
# Kahan snapshots improve diagnostics without adding steady state storage/passes.
rng=np.random.default_rng(83)
snapshot=np.zeros((288,1056,4),np.float32)
snapshot[:,:,:]=10**rng.uniform(-9,-.2,snapshot.shape)
sv={**values,'gFilmPaddedSize':(1056,288),'gFilmReductionSize':(66,18)}
def reduceField(label,program):
    b=render(label+'_fine',program,{'txFilmCurrent':snapshot},sv,(66,18))
    c=render(label+'_coarse',program,{'txFilmCurrent':b},{**sv,'gFilmPaddedSize':(66,18),'gFilmReductionSize':(5,2)},(5,2))
    return c.sum(axis=(0,1),dtype=np.float64)
exact=snapshot.sum(axis=(0,1),dtype=np.float64)
new=reduceField('compensated_snapshot',code('rainFilmBlocks'))
old=reduceField('old_snapshot',(OUT/'baseline/shaders/rainFilmBlocks.hlsl').read_text())
assert np.max(abs(new-exact))<np.max(abs(old-exact))
reports.append(dict(case='manual compensated field snapshot versus double precision sum',
                    oldMaxErrorMM3=float(np.max(abs(old-exact))),newMaxErrorMM3=float(np.max(abs(new-exact)))))
(OUT/'gpu_checks.json').write_text(json.dumps(dict(compiler='FXC ps_5_0 /Ges /WX, D3D11 WARP',checks=reports),indent=2))
print('P4 GPU:',len(reports),'production checks passed')
