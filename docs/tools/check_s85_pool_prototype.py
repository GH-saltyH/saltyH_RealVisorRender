"""Offline pooled-film -> free-head transfer: /WX WARP and actual P4 donor/gather.

No runtime code or game installation is changed. This proves paired volume and
bounded ownership only, not full physical classification or real-game speed.
"""
from pathlib import Path
import sys,json,math
import numpy as np
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s85'
env={'__file__':str(ROOT/'docs/tools/check_s81_film_gpu.py')}
exec((ROOT/'docs/tools/check_s81_film_gpu.py').read_text().split('reports=[]',1)[0],env)
env['env']['OUT']=OUT
render=env['render'];code=env['code'];core=env['core'];metric=env['metric']
env['env']['types'].update(gFilmObjectToWorld='float4x4',gFilmAccelerationWorld='float3',gFilmAirWorld='float3')
W,H,P=64,32,16;tiles=W*H//256
v={**env['values'],'gFilmGrid':(W,H),'gFilmPaddedSize':(W+2*P,H+2*P),
   'gTilesY':(H+2*P)//16,'gFilmReductionSize':((W+2*P)//16,(H+2*P)//16),
   'gPoolCount':tiles,'gPoolTick':0,'gPoolTheta':90,'gPoolMinDMM':.25,
   'gFilmFlowOn':1,'gFilmObjectToWorld':np.eye(4).ravel(),'gFilmAccelerationWorld':(0,-9.80665,0),
   'gFilmAirWorld':(0,0,0),'gFilmAirRho':1.2,'gFilmFlowCf':.005,'gFilmFlowCFL':.8,
   'gFilmAirDownward':0,'gFilmAirDownwardGain':1,'gFilmDt':1/60}
cells=np.zeros((H,W,4),np.float32);cells[:,:,:]=(.25,1,0,1)
field=np.zeros((H+2*P,W+2*P,4),np.float32)
pool=(ROOT/'docs/prototypes/s85_pool_transfer.hlsl').read_text()
candidateShader=core+pool+'''float4 main(PS_IN pin) {
    return poolCandidate((uint)(pin.Tex.x*poolTileCount()));
}'''
acceptShader=core+pool+'''float4 main(PS_IN pin) {
    return poolAccept((uint)(pin.Tex.x*gPoolCount));
}'''
debitShader=core+pool+'''float4 main(PS_IN pin) {
    int2 p=(int2)(pin.Tex*gFilmPaddedSize);
    float4 water=txFilmPrevious.Load(int3(p,0));water.r=poolAvailable(p);return water;
}'''
reports=[]
def candidate(name,old,c=cells,vals=v):
    return render(name,candidateShader,{'txFilmPrevious':old,'txFilmCells':c},vals,(tiles,1))
def accept(name,candidates,count=tiles,tick=0,busy=False,rain=False):
    meta=np.zeros((1,count,4),np.float32);meta[:,:,3]=4*17
    births=np.zeros((4,count,4),np.float32)
    if busy:meta[:,:,:]=(.001,1,1,4*17+1)
    if rain:births[0,:,2:]=(.5,19)
    return render(name,acceptShader,{'txPoolCandidates':candidates,'txRainStateMeta':meta,'txBirthEvent':births},
                  {**v,'gPoolCount':count,'gPoolTick':tick},(count,1))
def debit(name,old,accepted,tick=0):
    return render(name,debitShader,{'txFilmPrevious':old,'txPoolAccepted':accepted},
                  {**v,'gPoolCount':accepted.shape[1],'gPoolTick':tick},(W+2*P,H+2*P))

# Latest reported peak cell masses, without pretending this synthetic field is
# the user's actual spatial height distribution.
review=json.loads((OUT/'regime_review.json').read_text())
initial=field.copy();initial[P:P+H,P:P+W,0]=.00025 # 1 um precursor
initial[:,:,1:]=(.0002,.00001,.00001) # all other channels preserved
points=[(8,8),(40,24)]
for (x,y),row in zip(points,review['evidence']):initial[P+y,P+x,0]=row['derived']['worstCellVolumeMM3']
chosen=candidate('two_reported_mass_peaks',initial)
assert np.count_nonzero(chosen[0,:,3])==2
accepted=accept('paired_accept',chosen);after=debit('paired_debit',initial,accepted)
absorbed=float(accepted[0,:,2].sum(dtype=np.float64))
error=float(after.sum(dtype=np.float64)+absorbed-initial.sum(dtype=np.float64))
assert abs(error)<1e-6 and after.min()>=0
assert np.array_equal(after[:,:,1:],initial[:,:,1:])
reports.append(dict(case='two supplied peak masses in synthetic localized field; paired full transfer',
                    transferredMM3=absorbed,residualMM3=error,capDiameterMM=[float((6*x/math.pi)**(1/3)) for x in accepted[0,:,2] if x>0]))
for label,kwargs in [('occupied',dict(busy=True)),('rain_priority',dict(rain=True))]:
    a=accept(label,chosen,**kwargs);d=debit(label+'_debit',initial,a)
    assert not np.any(a) and np.array_equal(d,initial)
reports.append(dict(case='occupied slots / same-frame airborne head priority cause no debit or water loss'))

for label,make in [('uniform_thick_sheet',lambda a: a.__setitem__((slice(P,P+H),slice(P,P+W),0),.5)),
                  ('connected_ridge',lambda a: a.__setitem__((slice(P,P+H),P+8,0),4)),
                  ('thin_trail',lambda a: a.__setitem__((P+8,P+8,0),.001)),
                  ('tiny_drop',lambda a: a.__setitem__((P+8,P+8,0),.0001))]:
    f=field.copy();make(f);c=candidate(label,f)
    assert not np.any(c),label
reports.append(dict(case='uniform 2mm sheet, connected ridge, thin trail and sub-minimum drop are not reclassified'))
for label,coverage,area in [('unsupported',0,0),('partial_cell',.25,.0625)]:
    c=cells.copy()
    for x,y in points:c[y,x,:2]=(area,coverage)
    assert not np.any(candidate(label,initial,c))
reports.append(dict(case='unsupported/partial topology skipped rather than squeezed into a persistent head'))

# Every tile has a candidate. Exercise capacity greater/less than tile count,
# rotating groups, and the partial final group. No duplicate accepted cell.
allPeaks=field.copy()
for tile in range(tiles):allPeaks[P+(tile//4)*16+8,P+(tile%4)*16+8,0]=2
allChosen=candidate('all_regions',allPeaks)
for count in (1,7,8,9,40):
    visited=set()
    for tick in range(tiles*math.ceil(count/tiles)):
        # One WARP check per distinct capacity/group boundary; inverse ownership
        # arithmetic is additionally checked over all ticks below.
        owners={}
        group=tick%math.ceil(count/tiles)
        for tile in range(tiles):
            owner=group*tiles+(tile+tiles-tick%tiles)%tiles
            if owner<count:owners[owner]=tile;visited.add(tile)
        assert len(set(owners.values()))==len(owners)
        if tick in (0,1,math.ceil(count/tiles)-1):
            a=accept(f'owners_{count}_{tick}',allChosen,count=count,tick=tick)
            actual={i for i in range(count) if a[0,i,3]>0}
            assert actual==set(owners)
            d=debit(f'owners_debit_{count}_{tick}',allPeaks,a,tick)
            assert d.min()>=0 and abs(float(d.sum(dtype=np.float64)+a[0,:,2].sum(dtype=np.float64)-allPeaks.sum(dtype=np.float64)))<1e-6
    assert len(visited)==tiles
reports.append(dict(case='unique rotating ownership, partial groups and no capacity-dependent duplicate debit',counts=[1,7,8,9,40]))

# Run ACTUAL P4 donor/gather on the reduced stock. The candidate event is read
# by both flux and resolve, so it cannot also spend the same absorbed water.
geoU=np.zeros((H*2,W*2,4),np.float32);geoU[:,:,:]=(.032,0,0,100)
geoV=np.zeros_like(geoU);geoV[:,:,:]=(0,.016,0,0)
geo={'txRainDu':geoU,'txRainDv':geoV,'txRainBoundaryMask':np.ones_like(geoU)}
flow=code('rainFilmFlow')
anchor='float volume=max(txFilmPrevious.Load(int3(p,0)).r,0);';assert flow.count(anchor)==1
flow=flow.replace(anchor,'float volume=poolAvailable(p);')
flux=render('paired_actual_donor',metric+core+pool+flow+code('rainFilmFlowPass'),
            {**geo,'txFilmCells':cells,'txFilmPrevious':initial,'txPoolAccepted':accepted},v,(W,H))
resolve=env['resolve'];anchor='float4 old=txFilmPrevious.Load(int3(p,0));';assert resolve.count(anchor)==1
resolve=resolve.replace(anchor,anchor+'old.r=poolAvailable(p);')
empty=np.zeros((5,1,4),np.float32);empty[4,0]=[1e9,1e9,-1e9,-1e9]
mask=render('paired_bins',code('rainFilmBin'),{'txFilmDescriptors':empty},v,(int(v['gMaskW']),int(v['gTilesY'])))
summary=render('paired_summary',env['inline'](env['source'],'rainDynamicSceneCopyState.gpuHeadsSummaryPass ='),
               {'txMask':mask},v,(int(v['gSummaryW']),int(v['gTilesY'])))
gathered=render('paired_actual_gather',core+pool+resolve,{'txFilmDescriptors':empty,'txMask':mask,'txSummary':summary,
    'txFilmPrevious':initial,'txFilmFlux':flux,'txFilmCells':cells,'txPoolAccepted':accepted},v,(W+2*P,H+2*P))
error=float(gathered.sum(dtype=np.float64)+absorbed-initial.sum(dtype=np.float64))
assert abs(error)<1e-6 and gathered.min()>=0
reports.append(dict(case='paired reclassification plus actual production donor/gather does not double-spend mass',residualMM3=error))
(OUT/'pool_prototype_checks.json').write_text(json.dumps(dict(compiler='FXC ps_5_0 /Ges /WX + D3D11 WARP',
    checks=reports,installedInGame=False,additionalGameSteadyPasses=0,
    limitation='The production pending/epoch/birth-position/counter handshake is specified but not yet implemented by this standalone prototype.'),indent=2))
print('P4b offline prototype:',len(reports),'gates passed; game runtime unchanged')
