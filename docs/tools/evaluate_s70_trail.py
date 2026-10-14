"""Evaluate current saved New Trail tuning, without changing runtime settings.

Uses the production descriptor, sparse resolve and optical shader on D3D11
WARP. Controlled straight paths isolate thickness from gameplay motion; the
actual baked surface is sampled separately. Results are not in-game timings.
"""
from pathlib import Path
import re, json, hashlib, math, struct, subprocess, tempfile
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/diagnostics/2026-10-12/s70'
OUT.mkdir(parents=True, exist_ok=True)
lua = (ROOT/'realvisor.lua').read_text(encoding='utf-8')
settings_path = Path('D:/Games/Assetto Corsa/apps/lua/realvisor/settings_mats.ini')
saved = settings_path.read_bytes()
defaults = {}
for k, value in re.findall(r'^\s*(RAIN_[A-Z0-9_]+)\s*=\s*([^,\r\n]+)', lua, re.M):
    try: defaults.setdefault(k, float(value))
    except ValueError:
        if value.strip() in ('true', 'false'): defaults.setdefault(k, value.strip() == 'true')
overrides = {k:float(v) for k,v in re.findall(r'^(RAIN_[A-Z0-9_]+)=([\d.eE+-]+)\s*$', saved.decode('utf-8-sig'), re.M)}
cfg = {**defaults, **overrides}
def c(key): return cfg[key]

helper = (ROOT/'docs/tools/check_s63_gpu.py').read_text(encoding='utf-8')
env = {'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')}
exec(helper[:helper.index('report=[]')], env)
env['OUT'] = OUT
env['types']['gNewTrailPixelUV'] = 'float2'
render, inline = env['render'], env['inline']
metric = (ROOT/'shaders/rainSurfaceMetric.hlsl').read_text()
descriptor = (ROOT/'shaders/rainTrailDescriptor.hlsl').read_text()
bins = (ROOT/'shaders/rainTrailBin.hlsl').read_text()
tail = inline(lua, 'rainDynamicSceneCopyState.gpuHeadsPassB =')
tail = tail[tail.index('void rgWalk('):].replace('    return acc;', '    return ntResolve(pin.Tex,acc);')
resolve = metric + (ROOT/'shaders/rainTrailResolve.hlsl').read_text() + tail
fixture = (ROOT/'docs/tools/check_s66_gpu.py').read_text(encoding='utf-8')
compiled = {}
exec(fixture[fixture.index('def full_render('):fixture.index('\ny,x=np.mgrid')], globals())
header = (ROOT/'docs/diagnostics/2026-10-12/s67/shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8')
full = header[:header.index(metric)] + metric + (ROOT/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8').replace('float4 main(PS_IN pin)', 'float4 main(PS_IN pin):SV_TARGET')
# Return the actual branch's image shift, height and compositing alpha.
assert full.count('gSolidA = solidAlpha;') == 1
probe = full.replace('gSolidA = solidAlpha;', 'return float4(trailOffsetPx,h0,solidAlpha);')

ref = c('RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM'); unit = .001/ref
size = int(c('RAIN_DYNAMIC_WATER_FIELD_TRAIL_SIZE')); count = 96
du = np.zeros((size//4,size,4),np.float32); du[:,:,0]=.30; du[:,:,3]=100
dv = np.zeros_like(du); dv[:,:,1]=.20; dv[:,:,3]=1
boundary = np.ones_like(du); zero = np.zeros_like(du)
frames = np.zeros((1,count,4),np.float32); frames[:,:,0]=.30/unit;frames[:,:,2]=.20/unit;frames[:,:,3]=1
states = np.zeros_like(frames);states[:,:,:2]=2;states[0,0,:2]=(.65,-.5)
previous=states.copy();previous[0,0,0]=.35
meta = np.zeros_like(frames);meta[0,0]=(ref*.65/2,1,2,5)
tx = {'txRainState':states,'txRainPreviousState':previous,'txRainStateMeta':meta,'txRainPreviousMeta':meta,
      'txRainDropMetric':frames,'txOverride':np.zeros_like(meta),'txRainDu':du,'txRainDv':dv,
      'txRainBoundaryMask':boundary,'txTrailPrevious':zero}
v = {'gCount':count,'gSize':size,'gRainReferencePerMM':ref,'gRainMetersPerUnit':unit,
     'gNewTrailBirthHold':c('RAIN_GPU_STATE_BIRTH_HOLD_SECONDS'),'gNewTrailLifecycle':1,
     'gNewTrailDensityMin':c('RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_MIN'),
     'gNewTrailDensityFull':c('RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_FULL'),
     'gNewTrailMinSpeed':c('RAIN_NEW_TRAIL_MIN_SPEED_MM_S')*ref,
     'gNewTrailFullSpeed':c('RAIN_NEW_TRAIL_FULL_SPEED_MM_S')*ref,
     'gNewTrailMinDropMM':c('RAIN_NEW_TRAIL_MIN_DROP_MM'),
     'gNewTrailMinDiameterMM':c('RAIN_NEW_TRAIL_MIN_FOOTPRINT_MM'),
     'gNewTrailWidthD':c('RAIN_DYNAMIC_WATER_FIELD_TRAIL_WIDTH'),
     'gNewTrailWipeD':c('RAIN_DYNAMIC_TRAIL_MASK_WIPE_WIDTH_SCALE'),
     'gNewTrailWiden':c('RAIN_DYNAMIC_WATER_FIELD_SHEET_WIDEN'),
     'gNewTrailHeight':c('RAIN_NEW_TRAIL_HEIGHT'),
     'gNewTrailSeconds':c('RAIN_DYNAMIC_WATER_FIELD_TRAIL_SECONDS'),
     'gNewTrailWipeSeconds':c('RAIN_DYNAMIC_TRAIL_MASK_SECONDS'),
     'gNewTrailSheetEnabled':int(c('RAIN_DYNAMIC_WATER_FIELD_SHEET_ENABLED')),
     'gNewTrailWaterEnabled':1,'gNewTrailWipeEnabled':1,
     'gNewTrailNoise':c('RAIN_DYNAMIC_WATER_FIELD_TRAIL_NOISE'),
     'gNewTrailBeadCycles':c('RAIN_NEW_TRAIL_BEAD_CYCLES_D'),
     'gNewTrailSheetRipple':c('RAIN_NEW_TRAIL_SHEET_RIPPLE'),'gNewTrailPhase':.4,
     'gNewTrailDt':1/60,'gNewTrailHeadSize':2048,
     'gNewTrailDiffuse':1-math.exp(-c('RAIN_DYNAMIC_WATER_FIELD_TRAIL_DIFFUSE')*4),
     'gNewTrailPixelUV':(1/size,4/size),'gTile':(32,128),'gTilesX':size//32,'gTilesY':size//128,
     'gWords':1,'gMaskW':size//32,'gSummaryW':size//32,'gSummaryWords':1,'gSparseWords':1,'gDebug':0,'gFlipY':0}
def pipeline(name, values):
    desc=render(name+'_descriptor',descriptor,tx,values,(count,4))
    tiles=render(name+'_tiles',bins,{'txTrailDescriptors':desc},values,(values['gMaskW'],values['gTilesY']))
    summary=render(name+'_summary',inline(lua,'rainDynamicSceneCopyState.gpuHeadsSummaryPass ='),{'txMask':tiles},values,(values['gSummaryW'],values['gTilesY']))
    result=render(name+'_resolve',resolve,{**tx,'txTrailDescriptors':desc,'txMask':tiles,'txSummary':summary},values,(size,size//4))
    return result,desc

# A complete 4:1 visor atlas occupies this controlled screen. No smear and no
# other layer hides the result; this is an optimistic direct optical view.
sw,sh=2048,512;y,x=np.mgrid[:sh,:sw]
scene=np.stack(((x//4)%2,(y//4)%2,x/sw,np.ones_like(x)),axis=-1).astype(np.float32)
opt = {'gRainMetersPerUnit':unit,'gRainReferencePerMM':ref,'gDynamicDropNewTrail':1,
       'gDynamicDropNewTrailGradientD':c('RAIN_NEW_TRAIL_GRADIENT_D'),
       'gDynamicDropNewTrailRefractD':c('RAIN_NEW_TRAIL_REFRACT_D'),
       'gDynamicDropNewHeadGradientD':c('RAIN_NEW_TRAIL_HEAD_GRADIENT_D'),
       'gDynamicDropWaterField':1,'gDynamicDropWFTrail':1,'gDynamicDropWFThreshold':.35,
       'gDynamicDropWFOpacity':1,'gDynamicDropWFSheetAlpha':1,'gDynamicDropWFInvMaskSize':1/2048,
       'gDynamicDropWFHeadStep':1/2048,'gDynamicDropWFTrailStep':1/size,
       'gDynamicDropTrailSlopeMax':c('RAIN_DYNAMIC_TRAIL_SLOPE_MAX'),
       'gDynamicDropTrailRefractPx':c('RAIN_DYNAMIC_TRAIL_REFRACT_PX'),
       'gDynamicDropWaterToneFloor':1,'gDynamicDropCameraForward':(0,0,1),
       'gDynamicDropCameraSide':(1,0,0),'gDynamicDropCameraUp':(0,1,0)}
rows=[]
for rain,air,speed,d,aligned in [(.6,0,5,.65,False),(.6,100,15,.65,False),(.6,120,35,.65,False),
                                (1,200,35,.76,False),(.6,120,35,1.5,False),(.6,120,35,2.5,False),
                                (.6,120,35,.65,True),(1,200,35,.76,True)]:
    density=rain*air/c('RAIN_DYNAMIC_SMEAR_REF_KMH');supply=min(.65*rain+.35*min(density,1),1)
    values={**v,'gNewTrailWet':supply,'gNewTrailSupply':supply,'gNewTrailShear':min(air/200,1),'gNewTrailDensity':density}
    states[0,0,1]=previous[0,0,1]=-.5+(2/size if aligned else 0)
    states[0,0,2]=speed*ref/frames[0,0,0];meta[0,0,0]=d*ref/2
    history,desc=pipeline('case'+str(len(rows)),values)
    bindings={'txRainDu':du,'txRainDv':dv,'txRainBoundaryMask':boundary,'txDynamicSnapshot':scene,
              'txDynamicWaterTrail':history,'txDynamicTrailMask':history}
    measured=full_render('opt'+str(len(rows)),probe,bindings,opt,(sw,sh))
    visible=measured[:,:,3]>.01
    displacement=np.linalg.norm(measured[:,:,:2],axis=-1)
    row={'rain':rain,'air_kmh':air,'drop_mm_s':speed,'drop_diameter_mm':d,'wet':supply,'aligned_atlas_row':aligned,
         'descriptor_G':float(desc[1,0,1]),'width_mm':float(desc[1,0,0]*2/ref),
         'life_seconds':float(desc[1,0,3]),'atlas_G_max':float(history[:,:,1].max()),
         'alpha_max':float(measured[:,:,3].max()),'offset_px_max':float(displacement.max()),
         'visible_offset_px_max':float(displacement[visible].max()) if visible.any() else 0,
         'alpha_weighted_offset_max':float((displacement*measured[:,:,3]).max())}
    rows.append(row);print(json.dumps(row),flush=True)
    if d==.65 and air==120:
        # Half a second after the path is vacated, production history only.
        blank=np.zeros((4,count,4),np.float32);blank[3,:,:2]=2e9;blank[3,:,2:]=-2e9
        decay_tx={**tx,'txTrailDescriptors':blank}
        for frame in range(30):
            history=render('decay',resolve,{**decay_tx,'txTrailPrevious':history},values,(size,size//4))
        row['atlas_G_after_0p5_seconds']=float(history[:,:,1].max())

# Actual surface metrics/support/coating, same ordinary 0.65 mm birth size.
def dds(name):return np.frombuffer((ROOT/f'texture/RAIN_GEOMETRY/{name}.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
geo={'txRainDu':dds('du'),'txRainDv':dds('dv'),
     'txRainBoundaryMask':np.asarray(Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').convert('RGBA'),np.float32)/255}
sites=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/spawn_sites.dds').read_bytes(),'<f4',offset=148).reshape(1,8192,4)
states=sites[:,:count,:].copy();states[:,:,1]-=1
frames=render('real_metric',metric+inline(lua,'rainDynamicSceneCopyState.gpuMetricShader ='),{**geo,'txRainState':states},v,(count,1))
states[:,:,2]=35*ref/np.maximum(frames[:,:,0],1e-6);states[:,:,3]=0
previous=states.copy();previous[:,:,0]-=states[:,:,2]/60
meta[:,:,:]=(ref*.65/2,1,2,5)
tx.update(geo);tx.update(txRainState=states,txRainPreviousState=previous,txRainDropMetric=frames,txRainStateMeta=meta,txRainPreviousMeta=meta)
actual,desc=pipeline('actual_bakes',{**v,'gNewTrailWet':.65,'gNewTrailSupply':.65,'gNewTrailShear':.6,'gNewTrailDensity':.72})
actual_probe=full_render('actual_bakes_optical',probe,{**geo,'txDynamicSnapshot':scene,
    'txDynamicWaterTrail':actual,'txDynamicTrailMask':actual},opt,(sw,sh))
coating=geo['txRainDv'][::2,::2,3]>.99
coated_alpha=actual_probe[geo['txRainDv'][:,:,3]>.99,3]
coated_shift=np.linalg.norm(actual_probe[:,:,:2],axis=-1)[geo['txRainDv'][:,:,3]>.99]
report={'settings_sha256':hashlib.sha256(saved).hexdigest(),
        'relevant_tuning':{k:value for k,value in cfg.items() if k.startswith(('RAIN_NEW_TRAIL','RAIN_GPU_SIZE_','RAIN_DYNAMIC_WATER_FIELD_TRAIL','RAIN_DYNAMIC_WATER_FIELD_SHEET'))},
        'source_sha256':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['realvisor.lua','rain_trails.lua','shaders/rainTrailDescriptor.hlsl','shaders/rainTrailResolve.hlsl','shaders/rainVisorDynamicDrop.hlsl']},
        'controlled_cases':rows,'actual_bakes':{'slots':count,'valid_liquid_descriptors':int((desc[1,:,1]>0).sum()),
         'descriptor_G_max':float(desc[1,:,1].max()),'atlas_G_max':float(actual[:,:,1].max()),
         'coated_atlas_G_max':float(actual[coating,1].max()),
         'coated_alpha_max':float(coated_alpha.max()),'coated_offset_px_max':float(coated_shift.max()),
         'coated_alpha_weighted_offset_max':float((coated_alpha*coated_shift).max())},
        'limits':'Controlled paths, no smear/FX/native occlusion, W at equilibrium; no measured game trajectories or hardware frame times. G is dimensionless, not micrometres.'}
(OUT/'trail_visibility.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS: current production thickness/history/optical branch evaluation; no runtime tuning changed',flush=True)
