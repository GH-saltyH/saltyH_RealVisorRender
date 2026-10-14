"""D3D11 readbacks of the actual unified descriptor/bin/history/lens programs."""
from pathlib import Path
import re,json,time
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s67';OUT.mkdir(parents=True,exist_ok=True)
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text();env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')}
exec(base[:base.index('report=[]')],env);env['OUT']=OUT
render=env['render'];inline=env['inline'];types=env['types'];types['gNewTrailPixelUV']='float2'
lua=(ROOT/'realvisor.lua').read_text(encoding='utf-8');metric=(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text()
descriptor=(ROOT/'shaders/rainTrailDescriptor.hlsl').read_text();bins=(ROOT/'shaders/rainTrailBin.hlsl').read_text()
tail=inline(lua,'rainDynamicSceneCopyState.gpuHeadsPassB =');tail=tail[tail.index('void rgWalk('):]
tail=tail.replace('    return acc;','    return ntResolve(pin.Tex,acc);')
resolve=metric+(ROOT/'shaders/rainTrailResolve.hlsl').read_text()+tail
report=[];unit=.001/.0029296875;ref=.0029296875;size=1024;count=96
du=np.zeros((256,1024,4),np.float32);du[:,:,0]=.30;du[:,:,3]=100
dv=np.zeros_like(du);dv[:,:,1]=.20;mask=np.ones_like(du)
states=np.zeros((1,count,4),np.float32);states[:,:,:2]=(2,2);states[0,0]=(.65,-.5,1.0,0)
previous=states.copy();previous[0,0,0]=.35
meta=np.zeros_like(states);meta[0,0]=(1.2*ref,1,2,5)
frames=np.zeros_like(states);frames[:,:,0]=.3/unit;frames[:,:,2]=.2/unit;frames[:,:,3]=1
zero=np.zeros_like(du)
v={'gCount':count,'gRainReferencePerMM':ref,'gRainMetersPerUnit':unit,'gSize':size,
   'gNewTrailBirthHold':.6,'gNewTrailLifecycle':1,'gNewTrailWet':.7,'gNewTrailSupply':.7,'gNewTrailShear':.55,
   'gNewTrailDensity':.7,'gNewTrailDensityMin':.15,'gNewTrailDensityFull':.6,
   'gNewTrailMinSpeed':ref*1.3653,'gNewTrailFullSpeed':ref*34.133,
   'gNewTrailMinDropMM':.2,'gNewTrailMinDiameterMM':.04,'gNewTrailWidthD':.7,'gNewTrailWipeD':.98,
   'gNewTrailWiden':2.34,'gNewTrailHeight':.75,'gNewTrailSeconds':.46,'gNewTrailWipeSeconds':.69,
   'gNewTrailSheetEnabled':1,'gNewTrailWaterEnabled':1,'gNewTrailWipeEnabled':1,
   'gNewTrailNoise':.75,'gNewTrailBeadCycles':1.25,'gNewTrailSheetRipple':.08,'gNewTrailPhase':.4,
   'gNewTrailDt':1/60,'gNewTrailHeadSize':2048,'gNewTrailDiffuse':0,'gNewTrailPixelUV':(1/size,4/size),
   'gTile':(32,128),'gTilesX':32,'gTilesY':8,'gWords':1,'gMaskW':32,'gSummaryW':32,'gSummaryWords':1,
   'gSparseWords':1,'gDebug':0,'gFlipY':0}
tx={'txRainState':states,'txRainStateMeta':meta,'txRainPreviousState':previous,'txRainPreviousMeta':meta.copy(),
    'txRainDropMetric':frames,'txOverride':np.zeros_like(meta),'txRainDu':du,'txRainDv':dv,
    'txRainBoundaryMask':mask,'txTrailPrevious':zero}
def pipeline(name,values=None):
    values={**v,**(values or {})}
    desc=render(name+'_descriptor',descriptor,tx,values,(count,4))
    tiles=render(name+'_tiles',bins,{'txTrailDescriptors':desc},values,(values['gMaskW'],8))
    summary=render(name+'_summary',inline(lua,'rainDynamicSceneCopyState.gpuHeadsSummaryPass ='),{'txMask':tiles},values,(values['gSummaryW'],8))
    output=render(name+'_resolve',resolve,{**tx,'txTrailDescriptors':desc,'txMask':tiles,'txSummary':summary},values,(size,size//4))
    return output,desc
a,desc=pipeline('continuous')
assert np.all(a[127,360:665,1]>.05),(float(a[:,:,1].max()),desc[:,0])
assert a[127,662,1]>.05 and a[127,358,1]>.05,'Trail must reach both GPU endpoints'
assert a[:,:,3].max()>.8 and a[:,:,1].max()>.3
report.append({'case':'current GPU segment connects every intermediate pixel and both endpoints without CPU stamps','height_max':float(a[:,:,1].max())})
tx['txTrailPrevious']=a
b,_=pipeline('max_history',{'gNewTrailDt':0})
assert np.max(abs(a-b))<2e-6,'Repainting must use max, never additive height'
report.append({'case':'repeated deposition does not accumulate thickness','max_delta':float(np.max(abs(a-b)))})
tx['txTrailPrevious']=zero
for name,modify,restore in [
    ('hold',lambda:meta.__setitem__((0,0,2),0),lambda:meta.__setitem__((0,0,2),2)),
    ('generation',lambda:meta.__setitem__((0,0,3),9),lambda:meta.__setitem__((0,0,3),5)),
    ('absorbed',lambda:meta.__setitem__((0,0,3),4),lambda:meta.__setitem__((0,0,3),5)),
    ('stationary',lambda:previous.__setitem__((0,0,0),.65),lambda:previous.__setitem__((0,0,0),.35))]:
    modify();c,_=pipeline(name);restore();assert np.max(abs(c))==0,name
    report.append({'case':name+' produces neither a teleport path nor a liquid/wipe stamp'})
meta[0,0,0]=.05*ref
c,_=pipeline('micro');assert c[:,:,1].max()==0 and c[:,:,3].max()>0
meta[0,0,0]=1.2*ref
report.append({'case':'micro drop clears a footprint without leaving liquid','wipe_max':float(c[:,:,3].max())})
tx['txTrailPrevious']=a;states[0,0,0]=2
c,_=pipeline('decay60',{'gNewTrailDt':1/60});tx['txTrailPrevious']=c
d,_=pipeline('decay60_2',{'gNewTrailDt':1/60});tx['txTrailPrevious']=a
e,_=pipeline('decay30',{'gNewTrailDt':1/30})
assert np.max(abs(d-e))<3e-6
assert e[:,:,1].max()<a[:,:,1].max()
report.append({'case':'pure decay is timestep invariant at 30/60 Hz; deposition remains every frame','max_delta':float(np.max(abs(d-e)))})
states[0,0,0]=.65;tx['txTrailPrevious']=zero
dv[:,:,3]=1
coated,_=pipeline('coated');assert coated[:,:,1].max()<a[:,:,1].max()
assert np.max(abs(coated[:,:,3]-a[:,:,3]))<2e-6
report.append({'case':'coating lowers film height while preserving the same micro wipe footprint'})
dv[:,:,3]=0
low,_=pipeline('low_shear',{'gNewTrailShear':.3});high,_=pipeline('high_shear',{'gNewTrailShear':1})
assert high[:,:,1].max()<low[:,:,1].max()
report.append({'case':'high shear thins water after the intermediate-speed maximum'})
# A skewed local UV metric must still connect the same current/previous path.
frames[:,:,1]=.11/unit
du[:,:,1]=0;dv[:,:,0]=.11
previous[0,0,:2]=(.4,-.65);states[0,0,:2]=(.6,-.4)
skew,_=pipeline('skewed_uv')
for t in np.linspace(0,1,31):
    uv=np.array((.4,.35))*(1-t)+np.array((.6,.6))*t
    ix,iy=(uv*np.array((1024,256))).astype(int)
    assert skew[max(0,iy-1):iy+2,max(0,ix-1):ix+2,1].max()>.01,t
report.append({'case':'skewed UV metric connects every sampled point of the current GPU path'})
mask[115:129,501:524,3]=0
blocked,blocked_desc=pipeline('unsupported_hole')
assert blocked[:,:,1].max()==0 and blocked[:,:,3].max()==0
report.append({'case':'a segment crossing an unsupported hole cannot create liquid or whole-visor clearance'})
(OUT/'trail_gpu_checks.json').write_text(json.dumps(report,indent=2))
for row in report:print(json.dumps(row),flush=True)
print('PASS: actual unified GPU liquid/wipe history, eligibility, coating, shear and frame continuity')
