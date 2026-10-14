"""Actual 4096-slot bins: split current-head work from low-res swept trails."""
from pathlib import Path
import json,time
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s67'
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text(encoding='utf-8');env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')}
exec(base[:base.index('report=[]')],env);env['OUT']=OUT
render=env['render'];inline=env['inline'];env['types']['gNewTrailPixelUV']='float2'
lua=(ROOT/'realvisor.lua').read_text(encoding='utf-8');metric=(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text()
def dds(k):return np.frombuffer((ROOT/f'texture/RAIN_GEOMETRY/{k}.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
geo={'txRainDu':dds('du'),'txRainDv':dds('dv'),'txRainBoundaryMask':np.asarray(Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').convert('RGBA'),np.float32)/255}
count=4096;size=2048;ref=.0029296875
sites=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/spawn_sites.dds').read_bytes(),'<f4',offset=148).reshape(1,8192,4)
states=sites[:,:count,:].copy();states[:,:,1]-=1;states[:,:,2:]=(.6,-.4)
previous=states.copy();previous[:,:,:2]-=states[:,:,2:]/45
meta=np.zeros_like(states);meta[:,:,0]=np.linspace(.0004,.004,count);meta[:,:,2]=2;meta[:,:,3]=5
v={'gCount':count,'gSize':size,'gRainMetersPerUnit':.001/ref,'gRainReferencePerMM':ref,
 'gKs':1.24,'gMaxRadii':1.3,'gPuddleReach':1.07,'gUvPerMM':ref,'gBodyStretch':1,'gLookback':.03,
 'gShapeOn':1,'gShapeStrength':.8,'gPuddleOn':1,'gPuddleMinMM':1,'gPuddleShare':.3,
 'gLobesOn':1,'gStretchGain':.35,'gSweepWidthScale':.98,'gSweepMinRadius':.125,'gSweepWidthOffset':0,
 'gTile':(32,128),'gTilesX':64,'gTilesY':16,'gWords':43,'gMaskW':2752,'gSummaryW':64,'gSummaryWords':1,'gSparseWords':1}
frames=render('load4096_metric',metric+inline(lua,'rainDynamicSceneCopyState.gpuMetricShader ='),{**geo,'txRainState':states},v,(count,1))
tx={**geo,'txRainState':states,'txRainStateMeta':meta,'txRainPreviousState':previous,'txRainPreviousMeta':meta,
 'txRainDropMetric':frames,'txOverride':np.zeros_like(meta)}
common=inline(lua,'rainDynamicSceneCopyState.gpuHeadsCommon =')
report={}
outputs=[]
for label,sweep in [('prior_shared_sweep',1),('current_heads_only',0)]:
    values={**v,'gSweepEnabled':sweep}
    tx['txRainDropBounds']=render(label+'_bounds',common+inline(lua,'rainDynamicSceneCopyState.gpuBoundsShader ='),tx,values,(count,3))
    tx['txMask']=render(label+'_tiles',inline(lua,'rainDynamicSceneCopyState.gpuHeadsPassA ='),tx,values,(v['gMaskW'],16))
    tx['txSummary']=render(label+'_summary',inline(lua,'rainDynamicSceneCopyState.gpuHeadsSummaryPass ='),tx,values,(64,16))
    bits=tx['txMask'].astype(np.uint32)
    total=sum(int(x).bit_count() for x in bits.ravel());mean=total/(64*16)
    start=time.perf_counter()
    outputs.append(render(label+'_heads',metric+common+inline(lua,'rainDynamicSceneCopyState.gpuHeadsPassB ='),tx,values,(2048,512)))
    report[label]={'tile_candidate_sum':total,'mean_head_candidates_per_pixel':mean,
        'runner_wall_ms_including_setup_compile':(time.perf_counter()-start)*1000}
assert np.max(abs(outputs[0][:,:,:3]-outputs[1][:,:,:3]))<2e-6
assert report['current_heads_only']['tile_candidate_sum']<report['prior_shared_sweep']['tile_candidate_sum']
report['water_rgb_max_delta']=float(np.max(abs(outputs[0][:,:,:3]-outputs[1][:,:,:3])))
report['head_candidate_reduction']=1-report['current_heads_only']['tile_candidate_sum']/report['prior_shared_sweep']['tile_candidate_sum']
# Exercise all 4096 slots against the actual 4:1 du/dv/coating/hole bakes.
nv={**v,'gNewTrailBirthHold':.6,'gNewTrailLifecycle':1,'gNewTrailWet':.7,'gNewTrailSupply':.7,
 'gNewTrailShear':.55,'gNewTrailDensity':.7,'gNewTrailDensityMin':.15,'gNewTrailDensityFull':.6,
 'gNewTrailMinSpeed':ref*1.3653,'gNewTrailFullSpeed':ref*34.133,'gNewTrailMinDropMM':.2,
 'gNewTrailMinDiameterMM':.04,'gNewTrailWidthD':.7,'gNewTrailWipeD':.98,'gNewTrailWiden':2.34,
 'gNewTrailHeight':.75,'gNewTrailSeconds':.46,'gNewTrailWipeSeconds':.69,
 'gNewTrailSheetEnabled':1,'gNewTrailWaterEnabled':1,'gNewTrailWipeEnabled':1,
 'gNewTrailNoise':.75,'gNewTrailBeadCycles':1.25,'gNewTrailSheetRipple':.08,'gNewTrailPhase':.4,
 'gNewTrailDt':1/60,'gNewTrailHeadSize':2048,'gNewTrailDiffuse':0,'gNewTrailPixelUV':(1/1024,4/1024)}
ntx={**tx,'txTrailPrevious':np.zeros((256,1024,4),np.float32)}
ntx['txTrailDescriptors']=render('actual4096_trail_descriptors',
 (ROOT/'shaders/rainTrailDescriptor.hlsl').read_text(),ntx,nv,(count,4))
nv.update(gSize=1024,gTilesX=32,gTilesY=8,gMaskW=32*43,gSummaryW=32)
ntx['txMask']=render('actual4096_trail_tiles',(ROOT/'shaders/rainTrailBin.hlsl').read_text(),ntx,nv,(32*43,8))
ntx['txSummary']=render('actual4096_trail_summary',inline(lua,'rainDynamicSceneCopyState.gpuHeadsSummaryPass ='),ntx,nv,(32,8))
tail=inline(lua,'rainDynamicSceneCopyState.gpuHeadsPassB =');tail=tail[tail.index('void rgWalk('):]
tail=tail.replace('    return acc;','    return ntResolve(pin.Tex,acc);')
history=render('actual4096_trail_history',metric+(ROOT/'shaders/rainTrailResolve.hlsl').read_text()+tail,ntx,nv,(1024,256))
assert history[:,:,1].max()>0 and history[:,:,3].max()>0
def point_alpha(texture):
    iy=((np.arange(256)+.5)*texture.shape[0]/256).astype(int)
    ix=((np.arange(1024)+.5)*texture.shape[1]/1024).astype(int)
    return texture[iy[:,None],ix[None,:],3]
unsupported=(point_alpha(geo['txRainDu'])<.5)|(point_alpha(geo['txRainBoundaryMask'])<.5)
assert np.max(abs(history[unsupported]))==0,'Actual holes/boundaries must clip all history channels'
report['new_trail_actual_bakes']={'slot_count':count,'history_size':[1024,256],
 'valid_descriptors':int(np.sum(ntx['txTrailDescriptors'][1,:,1]>0)),
 'liquid_max':float(history[:,:,1].max()),'wipe_max':float(history[:,:,3].max()),
 'unsupported_max':float(np.max(abs(history[unsupported])))}
(OUT/'4096_candidate_checks.json').write_text(json.dumps(report,indent=2))
print('PASS: actual 4096-slot current-head bins remove swept-path work without changing water RGB',json.dumps(report),flush=True)
