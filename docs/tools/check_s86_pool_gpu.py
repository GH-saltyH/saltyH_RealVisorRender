"""Actual P4b source/state/meta/field/optics/budgets: FXC /Ges /WX, D3D11 WARP."""
from pathlib import Path
import sys,json,math
import numpy as np
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s86'

def code(name):
    s=(ROOT/f'shaders/{name}.hlsl').read_text()
    if name=='rainBirthEvent':s=code('rainFilmPoolAddress')+s
    if name in ('rainFilmResolve','rainFilmFlow','rainFilmOptics'):
        s=code('rainFilmPoolAddress')+code('rainFilmPoolAvailable')+s
    return s

prefix=(ROOT/'docs/tools/check_s81_film_gpu.py').read_text().split('reports=[]',1)[0]
prefix=prefix.replace("def code(name):return (ROOT/f'shaders/{name}.hlsl').read_text()",'')
e={'__file__':str(ROOT/'docs/tools/check_s81_film_gpu.py'),'code':code};exec(prefix,e)
e['env']['OUT']=OUT;render=e['render'];metric=e['metric'];core=e['core']
birthPrefix=(ROOT/'docs/tools/check_s79_birth_gpu.py').read_text().split('reports=[]',1)[0]
birthPrefix=birthPrefix.replace("def code(name):return (ROOT/f'shaders/{name}.hlsl').read_text()",'')
b={'__file__':str(ROOT/'docs/tools/check_s79_birth_gpu.py'),'code':code};exec(birthPrefix,b)
e['env']['types'].update(b['env']['types'])
e['env']['types'].update(gFilmObjectToWorld='float4x4',gFilmAccelerationWorld='float3',gFilmAirWorld='float3')
W,H,P,N=64,32,16,128;size=(W+2*P,H+2*P);tiles=W*H//256
v={**e['values'],**b['values'],**b['motion'],'gFilmGrid':(W,H),'gFilmPaddedSize':size,
   'gFilmReductionSize':(size[0]//16,size[1]//16),'gTilesY':size[1]//16,
   'gFilmCount':N,'gCount':N,'gBirthCount':N,'gBirthFilmOn':1,'gBirthBlocks':2,
   'gWords':2,'gMaskW':12,'gSummaryWords':1,'gSummaryW':6,
   'gPoolOn':1,'gPoolCount':N,'gPoolTick':1,'gPoolHasField':1,'gPoolTheta':90,'gPoolMinDMM':.25,
   'gBirthNumberDensity':0,'gFilmFlowOn':1,'gFilmObjectToWorld':np.eye(4).ravel(),
   'gFilmAccelerationWorld':(0,-9.80665,0),'gFilmAirWorld':(0,0,0),'gFilmAirRho':1.2,
   'gFilmFlowCf':.005,'gFilmFlowCFL':.8,'gFilmAirDownward':0,'gFilmAirDownwardGain':1,
   'gFilmDt':.01,'gFilmMotionDt':.01}
cells=np.zeros((H,W,4),np.float32);cells[:,:,:]=(.25,1,0,1)
initial=np.zeros((size[1],size[0],4),np.float32);initial[P:P+H,P:P+W,0]=.00025
initial[P+8,P+8,0]=4.3942978;initial[P+24,P+40,0]=1.9266605
geoU=np.zeros((H*2,W*2,4),np.float32);geoU[:,:,:]=(.032,0,0,100)
geoV=np.zeros_like(geoU);geoV[:,:,:]=(0,.016,0,0)
geo={'txRainDu':geoU,'txRainDv':geoV,'txRainBoundaryMask':np.ones_like(geoU)}
state=np.tile(np.array([.5,-.5,0,0],np.float32),(1,N,1))
meta=np.zeros_like(state);meta[:,:,3]=28
sites=b['sites'].copy();sites[:,:,:2]=(.75,.25)
sourceTx={**b['textures'],**geo,'txBirthSites':sites}
candidateCode=core+code('rainFilmPoolAddress')+code('rainFilmPoolCandidate')
eventCode=metric+core+code('rainBirthEvent')
descriptorCode=metric+core+code('rainFilmDescriptor')
flowCode=metric+core+code('rainFilmFlow')
reports=[]

def candidates(label,field,values=v,c=cells):
    return render(label,candidateCode,{'txFilmPrevious':field,'txFilmCells':c},values,(tiles,1))

def events(label,candidate,oldState=state,oldMeta=meta,values=v,impact=None):
    textures={**sourceTx,'txRainState':oldState,'txRainStateMeta':oldMeta,'txPoolCandidates':candidate}
    if impact is not None:textures['txBirthImpact']=impact
    count=int(values['gBirthCount'])
    return render(label,eventCode,textures,values,(count,5 if values['gPoolOn'] else 4))

def source_commit(label,ev,oldState=state,oldMeta=meta,values=v):
    tx={**geo,'txRainState':oldState,'txRainStateMeta':oldMeta,'txRainBirthEvent':ev}
    ns=render(label+'_state',b['stateCode'],tx,values,(int(values['gBirthCount']),1))
    nm=render(label+'_meta',b['metaCode'],tx,values,(int(values['gBirthCount']),1))
    return ns,nm

def field_commit(label,ev,ns,nm,old=initial,os=state,om=meta,values=v):
    tx={**geo,'txFilmNewState':ns,'txFilmNewMeta':nm,'txFilmOldState':os,'txFilmOldMeta':om,'txFilmBirthEvent':ev}
    desc=render(label+'_desc',descriptorCode,tx,values,(int(values['gBirthCount']),5))
    corrected=render(label+'_paired_meta',core+code('rainFilmMeta'),{'txFilmNewMeta':nm,'txFilmDescriptors':desc},values,(int(values['gBirthCount']),1))
    bins=render(label+'_bins',code('rainFilmBin'),{'txFilmDescriptors':desc},values,(int(values['gMaskW']),int(values['gTilesY'])))
    summary=render(label+'_summary',e['inline'](e['source'],'rainDynamicSceneCopyState.gpuHeadsSummaryPass ='),
                   {'txMask':bins},values,(int(values['gSummaryW']),int(values['gTilesY'])))
    tx={'txFilmPrevious':old,'txFilmCells':cells,'txFilmBirthEvent':ev}
    q=render(label+'_flux',flowCode+code('rainFilmFlowPass'),{**geo,**tx},values,(W,H))
    field=render(label+'_resolve',e['resolve'],{**tx,'txFilmDescriptors':desc,'txMask':bins,'txSummary':summary,
                 'txFilmFlux':q},values,size)
    optics=render(label+'_optics',code('rainFilmOptics'),{**tx,'txFilmCurrent':field},values,(W,H))
    return field,corrected,desc,optics,q

def budget(label,ev,corrected,desc,field,previous,values=v):
    blocks=render(label+'_birth_blocks',code('rainBirthBlocks'),{'txBirthEvent':ev,'txRainNewMeta':corrected,'txBirthTransfers':desc},
                  values,(int(values['gBirthBlocks']),3))
    totals=render(label+'_birth_totals',code('rainBirthTotals'),{'txBirthBlocks':blocks,'txBirthPreviousTotals':previous},values,(1,6))
    x=totals[:2,0].ravel();extra=totals[4,0]
    p2=float(x[0]-sum(x[1:7],np.float64(0))-extra[0]+extra[3])
    fb=render(label+'_field_blocks',code('rainFilmBlocks'),{'txFilmCurrent':field},values,
              (int(values['gFilmReductionSize'][0]),int(values['gFilmReductionSize'][1])))
    ft=render(label+'_field_totals',code('rainFilmTotals'),{'txFilmBlocks':fb,'txFilmBirthTotals':totals},values,(1,4))
    fs=render(label+'_field_stats',code('rainFilmStats'),{'txFilmTotals':ft},values,(16,1))[0,:,0]
    p3=float(fs[8]-sum(fs[9:13],np.float64(0))-sum(fs[:4],np.float64(0)))
    assert abs(p2)<1e-4 and abs(p3)<1e-4,(label,p2,p3,fs)
    assert abs(float(fs[4])-float(extra[3]))<1e-6
    return totals,p2,p3

c=candidates('actual_candidate',initial);ev=events('rain_off_pool_birth',c)
assert np.count_nonzero(ev[4,:,2])==2
accepted=ev[4,:,2]>0
assert np.array_equal(ev[0,accepted,2],ev[4,accepted,2]) and np.all(ev[0,accepted,3]==9)
assert np.max(abs(ev[1,accepted,:2]))==0 and np.max(abs(ev[2]))==0
ns,nm=source_commit('actual_pool_commit',ev)
assert np.array_equal(nm[0,accepted,1],ev[4,accepted,2])
assert np.allclose(ns[0,accepted,:2],ev[0,accepted,:2],atol=1e-7)
assert np.all(nm[0,accepted,3]==33)
field,cm,desc,optics,q=field_commit('pool_return',ev,ns,nm)
assert field.min()>=0 and q.min()>=0
transferred=float(ev[4,:,2].sum(dtype=np.float64))
assert abs(float(field.sum(dtype=np.float64)+cm[:,:,1].sum(dtype=np.float64)-initial.sum(dtype=np.float64)))<1e-5
assert np.count_nonzero(optics[:,:,2])==2
assert abs(float((optics[:,:,2]*cells[:,:,0]*.001).sum(dtype=np.float64))-transferred)<1e-5
assert desc[1,:,0].max()==0 # newly born heads cannot leave a false swept trail
previous=np.zeros((6,1,4),np.float32);previous[0,0,:2]=initial[:,:,0].sum(dtype=np.float64)
totals,p2err,p3err=budget('returned_budget',ev,cm,desc,field,previous)
reports.append(dict(case='actual no-rain pool source -> generation-matched P1 state/meta -> paired field/flux/optics/P2/P3',
    returnedMM3=transferred,p2ResidualMM3=p2err,p3ResidualMM3=p3err))

zero=candidates('no_published_field',initial,{**v,'gPoolHasField':0});assert np.max(abs(zero))==0
for label,options in [('busy',{'oldMeta':np.tile(np.array([.001,1,1,29],np.float32),(1,N,1))}),
                      ('retired',{'oldMeta':np.tile(np.array([0,0,0,30],np.float32),(1,N,1))}),
                      ('rain_priority',{'values':{**v,'gBirthNumberDensity':b['values']['gBirthNumberDensity']}})]:
    out=events(label,c,**options);assert np.max(abs(out[4,:,2]))==0,label
reports.append(dict(case='empty/reset field, busy/retired slots and same-frame rain attached priority do not return water'))

# Same-frame rain film arrives elsewhere while head is born from this pool.
# Row 4 must preserve the rain centre; beta/Weber describe the rain incident.
filmOnly=np.tile(np.array([0,.6,.2,.2],np.float32),(4,32,1))
rainV={**v,'gBirthNumberDensity':b['values']['gBirthNumberDensity']}
re=events('pool_and_rain_film',c,values=rainV,impact=filmOnly)
assert np.count_nonzero(re[4,:,2])==2 and np.all(re[4,:,:2]==np.array([.75,-.75],np.float32))
rs,rm=source_commit('rain_plus_pool',re,values=rainV)
rf,rcm,rd,ro,rq=field_commit('rain_plus_pool',re,rs,rm,values=rainV)
incident=np.array([.75,-.75+1])*[W,H]+P-.5
assert np.allclose(rd[2,:,:2],incident,atol=1e-5)
assert np.any(abs(rd[2,accepted,:2]-np.column_stack((re[0,accepted,0]*W+P-.5,(re[0,accepted,1]+1)*H+P-.5)))>1)
_,p2err,p3err=budget('rain_plus_pool_budget',re,rcm,rd,rf,previous,rainV)
reports.append(dict(case='independent incident/rain centre remains correct when head uses another pool position; both budgets close',
                    p2ResidualMM3=p2err,p3ResidualMM3=p3err))

# Generation handshake: an event cannot replay after its generation retires.
retired=nm.copy();retired[:,:,0:3]=0;retired[:,:,3]=np.floor(retired[:,:,3]/4)*4
_,stale=source_commit('generation_cannot_replay',ev,oldMeta=retired)
assert not np.any(stale[:,:,1])
reports.append(dict(case='pool birth uses the existing generation tag; stale events cannot replay'))

# Uniform sheet, connected ridge, shallow trail and unsupported geometry.
for label in ('sheet','ridge','thin','partial'):
    f=np.zeros_like(initial);cc=cells.copy()
    if label=='sheet':f[P:P+H,P:P+W,0]=.5
    elif label=='ridge':f[P:P+H,P+8,0]=4
    elif label=='thin':f[P+8,P+8,0]=.001
    else:f=initial.copy();cc[8,8,:2]=(.0625,.25);cc[24,40,:2]=(.0625,.25)
    assert np.max(abs(candidates(label,f,c=cc)))==0
reports.append(dict(case='uniform sheets/ridges/thin trail/partial boundary are not reclassified'))

# Capacity and partial final groups: actual production event, not a mirror of it.
allPeaks=np.zeros_like(initial)
for tile in range(tiles):allPeaks[P+(tile//4)*16+8,P+(tile%4)*16+8,0]=2
ac=candidates('all_regions',allPeaks)
for count in (1,7,8,9,1024,4096):
    for tick in (0,1,math.ceil(count/tiles)-1):
        vals={**v,'gBirthCount':count,'gPoolCount':count,'gPoolTick':tick}
        os=np.tile(state[:,:1],(1,count,1));om=np.tile(meta[:,:1],(1,count,1))
        result=events(f'capacity_{count}_{tick}',ac,os,om,vals)
        group=tick%math.ceil(count/tiles)
        rotation=(tick//math.ceil(count/tiles))%tiles
        owners={group*tiles+(t+tiles-rotation)%tiles for t in range(tiles)}
        expected={i for i in owners if i<count}
        assert set(np.where(result[4,:,2]>0)[0])==expected
        born=result[0,result[4,:,2]>0,:2]
        assert len(np.unique(born,axis=0))==len(born)
fairness=[]
for slot in (0,1024,2048,4095):
    visited={(slot%1024+tick//4)%1024 for tick in range(4096) if tick%4==slot//1024}
    aliased={(slot%1024+tick)%1024 for tick in range(4096) if tick%4==slot//1024}
    assert len(visited)==1024 and len(aliased)==256
    fairness.append(dict(slot=slot,regions=len(visited),oldAliasedRegions=len(aliased)))
reports.append(dict(case='actual source unique ownership at 1/7/8/9/1024/4096 slots; fixed group/region aliasing',
                    fairness=fairness))

# P4b OFF: actual event/state/field must match delivered s85 byte for byte.
offV={**v,'gPoolOn':0};off=events('P4b_off',c,values=offV)
oldEvent=metric+core+(OUT/'baseline/shaders/rainBirthEvent.hlsl').read_text()
oldEv=render('s85_event_reference',oldEvent,{**sourceTx,'txRainState':state,'txRainStateMeta':meta},offV,(N,4))
assert np.array_equal(off,oldEv)
os,om=source_commit('off_commit',off,values=offV)
of,oc,od,oo,oq=field_commit('off_field',off,os,om,values=offV)
oldFlow=metric+core+(OUT/'baseline/shaders/rainFilmFlow.hlsl').read_text()+code('rainFilmFlowPass')
oldQ=render('s85_flux_reference',oldFlow,{**geo,'txFilmPrevious':initial,'txFilmCells':cells},offV,(W,H))
assert np.array_equal(oq,oldQ)
# No descriptor source exists in this OFF fixture; use the same binned empty atlas.
bins=render('off_reference_bins',code('rainFilmBin'),{'txFilmDescriptors':od},offV,(12,4))
summary=render('off_reference_summary',e['inline'](e['source'],'rainDynamicSceneCopyState.gpuHeadsSummaryPass ='),
               {'txMask':bins},offV,(6,4))
oldResolve=(OUT/'baseline/shaders/rainFilmResolve.hlsl').read_text()+e['traversal']
oldField=render('s85_field_reference',oldResolve,{'txFilmPrevious':initial,'txFilmCells':cells,'txFilmDescriptors':od,
    'txFilmFlux':oldQ,'txMask':bins,'txSummary':summary},offV,size)
assert np.array_equal(of,oldField)
reports.append(dict(case='P4b OFF birth events, flux and field are bit-identical to a23527e'))

# Closed repeated actual commits, including source generation/evap/loss totals.
oldField=initial;oldState=state;oldMeta=meta;oldTotals=previous
errors=[]
for j in range(8):
    vv={**v,'gPoolTick':j,'gBirthTick':j,'gFilmEvapUMS':.1}
    c=candidates('closed_candidate_'+str(j),oldField,vv)
    ev=events('closed_event_'+str(j),c,oldState,oldMeta,vv)
    ns,nm=source_commit('closed_commit_'+str(j),ev,oldState,oldMeta,vv)
    nf,cm,desc,optics,q=field_commit('closed_field_'+str(j),ev,ns,nm,oldField,oldState,oldMeta,vv)
    nt,e2,e3=budget('closed_budget_'+str(j),ev,cm,desc,nf,oldTotals,vv)
    assert nf.min()>=0 and cm[:,:,1].min()>=0
    errors.append([e2,e3]);oldField,oldState,oldMeta,oldTotals=nf,ns,cm,nt
reports.append(dict(case='8 real source/head/film/evap/flux publications with internal-return counter and no external rain',
                    residualsMM3=errors))
(OUT/'pool_gpu_checks.json').write_text(json.dumps(dict(compiler='FXC ps_5_0 /Ges /WX, D3D11 WARP',checks=reports),indent=2))
print('s86 GPU:',len(reports),'production P4b gates passed')
