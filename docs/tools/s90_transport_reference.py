"""Offline GPU factories: frozen characteristic tracing + component-clipped s89 remap."""
from pathlib import Path
import sys,math
sys.dont_write_bytecode=True
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-16/s90'
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text()
env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')};exec(base[:base.index('report=[]')],env)
env['OUT']=OUT;env['types'].update(gTraceGrid='float2',gTestGrid='float2',gFilmGrid='float2',
    gFilmObjectToWorld='float4x4',gFilmAccelerationWorld='float3',gFilmAirWorld='float3')
render=env['render']
def code(step,name):return (ROOT/f'docs/prototypes/{step}/{name}.hlsl').read_text()
common=code('s90','traceCommon')

def runs_from_mask(mask):
    H,W=mask.shape;runs=np.full((H,W,4),-1,np.float32)
    for axis in (0,1):
        a=mask if axis==0 else mask.T
        for row,values in enumerate(a):
            edges=np.diff(np.r_[False,values,False].astype(int));lo=np.flatnonzero(edges==1);hi=np.flatnonzero(edges==-1)
            for l,h in zip(lo,hi):
                if axis==0:runs[row,l:h,:2]=[l,h]
                else:runs[l:h,row,2:]=[l,h]
    return runs

def prepare(velocity,runs,axis=0,tol=0):
    H,W=velocity.shape[:2];N=W if axis==0 else H;rows=H if axis==0 else W
    v=dict(gTraceGrid=(W,H),gTraceLanes=N,gTraceRows=rows,gTraceBlockCount=math.ceil(N/16),
        gTraceAxis=axis,gTraceAffineTolerance=tol,gTraceMaxVisits=128,gTraceDt=0)
    tx={'txTraceVelocity':velocity,'txTraceRuns':runs}
    blocks=render('trace_affine_blocks',common+code('s90','traceBlocks'),tx,v,(math.ceil(N/16),rows))
    tx['txTraceBlocks']=blocks
    return tx,v

def trace(packets,prepared,dt,max_visits=128,allow_reject=False):
    tx,v=prepared;v={**v,'gTraceDt':dt,'gTraceMaxVisits':max_visits}
    W,H=map(int,v['gTraceGrid'])
    a=render('trace_map',common+code('s90','traceMap'),{**tx,'txTracePackets':packets},v,(W,H))
    if not allow_reject:assert np.max(a[:,:,2])==0,('Trace rejected',np.unique(a[:,:,2],return_counts=True))
    assert np.all(a[:,:,1]>a[:,:,0])
    return a

def remap(packets,intervals,runs,axis=0,stats=False,linear=True,allow_reject=False):
    H,W=packets.shape[:2];N=W if axis==0 else H;rows=H if axis==0 else W
    leaves=math.ceil(N/16);groups=math.ceil(leaves/16)
    v=dict(gTestGrid=(W,H),gTestLanes=N,gTestRows=rows,gTestLeaves=leaves,gTestGroups=groups,gTestAxis=axis,gTestDebug=0,gTraceLinear=1 if linear else 0)
    common89=code('s89','overlapCommon')+code('s90','traceReconstruction')
    # Exact adaptations: own segment, limited reconstruction, ordered-map gate.
    leafCode=code('s89','overlapLeaves')
    a='float low=1e30,high=-1e30,count=0;'
    b='float low=1e30,high=-1e30,count=0,last=-1e30,status=0;'
    assert leafCode.count(a)==1;leafCode=leafCode.replace(a,b)
    a='''        low=min(low,interval.x);high=max(high,interval.y);count+=1;
        float fraction=saturate(ovInside(interval,0,gTestLanes));
        ovAdd(packet*(1-fraction),lost,correction);'''
    b='''        status=max(status,txTestIntervals.Load(int3(p,0)).b);
        float4 own=txTraceRuns.Load(int3(p,0));float2 run=gTestAxis<.5 ? own.rg : own.ba;
        float fraction=trFraction(p,interval,max(run.x,0),min(run.y,gTestLanes));
        ovAdd(packet*(1-fraction),lost,correction);
        if(fraction>0) {
            float l=max(interval.x,run.x),h=min(interval.y,run.y);
            if(l<last)status=max(status,4);
            last=max(last,h);low=min(low,l);high=max(high,h);count+=1;
        }'''
    assert leafCode.count(a)==1;leafCode=leafCode.replace(a,b)
    a='float4(low,high,count,0)';assert leafCode.count(a)==1;leafCode=leafCode.replace(a,'float4(low,high,count,status)')
    gatherCode=code('s89','overlapGather')
    a='ovAdd(packet*ovInside(interval,lo,hi),sum,correction);'
    b='float4 own=txTraceRuns.Load(int3(source,0));float2 run=gTestAxis<.5 ? own.rg : own.ba;\n                ovAdd(packet*trFraction(source,interval,max(lo,run.x),min(hi,run.y)),sum,correction);'
    assert gatherCode.count(a)==1;gatherCode=gatherCode.replace(a,b)
    a='float4 sum=0,correction=0;';assert gatherCode.count(a)==1
    gatherCode=gatherCode.replace(a,'float4 sum=txTestPackets.Load(int3(p,0)),correction=0;')
    a='    [loop]for(int group=0;group<(int)gTestGroups;++group) {';assert gatherCode.count(a)==1
    gatherCode=gatherCode.replace(a,'    if(txTraceAcceptance.Load(int3(0,0,0)).r>.5) {\n    sum=0;\n'+a)
    a='    // Manual-only operation count;';assert gatherCode.count(a)==1
    gatherCode=gatherCode.replace(a,'    }\n'+a)
    tx={'txTestPackets':packets,'txTestIntervals':intervals,'txTraceRuns':runs}
    leaf=render('remap_supported_leaves',common89+leafCode,tx,v,(leaves,rows*2))
    groupCode=code('s89','overlapGroups')
    a='float low=1e30,high=-1e30,count=0;';assert groupCode.count(a)==1
    groupCode=groupCode.replace(a,'float low=1e30,high=-1e30,count=0,status=0;')
    a='        if(bounds.z<=0)continue;';assert groupCode.count(a)==1
    groupCode=groupCode.replace(a,'        status=max(status,bounds.w);\n'+a+'\n        if(bounds.x<high)status=max(status,4);')
    a='float4(low,high,count,0)';assert groupCode.count(a)==1;groupCode=groupCode.replace(a,'float4(low,high,count,status)')
    group=render('remap_supported_groups',common89+groupCode,{'txTestLeaves':leaf},v,(groups,rows))
    acceptance=render('remap_GPU_admission',code('s90','traceAccept'),{'txTestGroups':group},v,(1,1))
    tx.update(txTestLeaves=leaf,txTestGroups=group,txTraceAcceptance=acceptance)
    if not allow_reject:assert acceptance[0,0,0]==1,('GPU rejected candidate',acceptance)
    result=render('remap_supported_gather',common89+gatherCode,tx,v,(W,H))
    loss=render('remap_gated_loss_probe',code('s90','traceAcceptedLoss'),tx,v,(leaves,rows))
    lost=loss.sum(axis=(0,1),dtype=np.float64)
    residual=result.sum(axis=(0,1),dtype=np.float64)+lost-packets.sum(axis=(0,1),dtype=np.float64)
    assert np.min(result[:,:,0])>=0
    work=None
    if stats:work=render('remap_supported_work',common89+gatherCode,tx,{**v,'gTestDebug':1},(W,H))
    return result,lost,residual,work

def velocity_from_cells(u,v=None):
    H,W=u.shape;a=np.zeros((H,W,4),np.float32)
    a[:,:,2]=u/W
    if v is not None:a[:,:,3]=v/H
    return a

def exact_cell_gaussian(W,centre,sigma,total=1):
    x=np.arange(W+1,dtype=float)
    erf=np.array([math.erf((q-centre)/(2**.5*sigma)) for q in x])
    return np.diff(erf)*.5*total
