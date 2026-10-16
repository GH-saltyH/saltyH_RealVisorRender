"""Trace one scripted head segment through ACTUAL GPU deposition and head rendering.

This isolates coordinate/time/display contracts; not reproduction of the video
or proof that the P1 and P4 constitutive laws are physically complete.
"""
from pathlib import Path
import sys,json,math
import numpy as np
from PIL import Image,ImageDraw
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-16/s87'
path=ROOT/'docs/tools/check_s86_pool_gpu.py';text=path.read_text()
prefix=text.split("\nc=candidates('actual_candidate',initial);",1)[0]
assert prefix!=text
env={'__file__':str(path)};exec(prefix,env)
env['e']['env']['OUT']=OUT
render=env['render'];code=env['code'];metric=env['metric'];geo=env['geo'];core=env['core']
v={**env['v'],'gPoolOn':0,'gCount':1,'gBirthCount':1,'gFilmCount':1,'gBirthBlocks':1,
   'gWords':1,'gMaskW':6,'gFilmDt':1/60,'gFilmMotionDt':1/60,'gFilmFlowOn':0}
ref=6/4096;volume=math.pi*2**3/6;radius=(3*volume/(2*math.pi))**(1/3)
ns=np.array([[[.5,-.5,.9375,0]]],np.float32) # 30mm/s along 32mm-wide flat fixture
os=ns.copy();os[:,:,0]-=.5/32 # exactly 0.5mm displacement in 1/60s
meta=np.array([[[radius*ref,volume,1,1]]],np.float32)
events=np.zeros((4,1,4),np.float32);empty=np.zeros_like(env['initial'])
field,cm,desc,optics,q=env['field_commit']('same_head',events,ns,meta,empty,os,meta,v)
transfer=float(desc[1,0,0]);remaining=float(cm[0,0,1])
assert transfer>0 and abs(remaining+field.sum(dtype=np.float64)-float(meta[0,0,1]))<1e-6
expected=np.r_[os[0,0,:2]+[0,1],ns[0,0,:2]+[0,1]]*[64,32,64,32]+16-.5
assert np.allclose(desc[0,0],expected,atol=1e-6)
yy,xx=np.indices((32,64));mass=field[16:48,16:80,0]
centroid=np.array([((xx+.5)*mass).sum()/mass.sum()/64,((yy+.5)*mass).sum()/mass.sum()/32])
expectedCentre=(os[0,0,:2]+ns[0,0,:2])*.5+[0,1]
assert np.max(abs(centroid-expectedCentre))<1e-6
# Fresh deposited trail is not advected until the following step, because
# actual P4 donor flux reads only the previous published field.
withFlow=env['field_commit']('fresh_trail_same_frame',events,ns,meta,empty,os,meta,{**v,'gFilmFlowOn':1})[0]
assert np.array_equal(field,withFlow)

source=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig');inline=env['e']['inline']
common=inline(source,'rainDynamicSceneCopyState.gpuHeadsCommon =')
hp={**v,'gCount':1,'gSize':1024,'gTile':(64,256),'gTilesX':16,'gTilesY':4,
    'gWords':1,'gMaskW':16,'gSummaryWords':1,'gSummaryW':16,'gSparseWords':1,'gFlipY':0,
    'gKs':1,'gMaxRadii':1.3,'gPuddleReach':1.07,'gBodyStretch':0,'gLookback':.03,
    'gShapeOn':0,'gShapeStrength':0,'gPuddleOn':0,'gPuddleMinMM':1,'gPuddleShare':.3,
    'gUvPerMM':ref,'gLobesOn':0,'gStretchGain':0,'gSweepEnabled':0,'gSweepMinRadius':0,
    'gSweepWidthScale':0,'gSweepWidthOffset':0}
baseTx={**geo,'txRainState':ns,'txRainStateMeta':meta,'txOverride':np.zeros_like(meta)}
frames=render('same_head_metric',metric+inline(source,'rainDynamicSceneCopyState.gpuMetricShader ='),baseTx,hp,(1,1))
baseTx['txRainDropMetric']=frames
measurements=[];sheet=Image.new('RGB',(1200,350),'#181818');draw=ImageDraw.Draw(sheet)
for j,gain in enumerate((.4,1,2)):
    values={**hp,'gHeadDisplayGain':gain}
    bounds=render('head_bounds_'+str(gain),common+inline(source,'rainDynamicSceneCopyState.gpuBoundsShader ='),baseTx,values,(1,3))
    tx={**baseTx,'txRainDropBounds':bounds}
    mask=render('head_bins_'+str(gain),common+inline(source,'rainDynamicSceneCopyState.gpuHeadsPassA ='),tx,values,(16,4))
    summary=render('head_summary_'+str(gain),inline(source,'rainDynamicSceneCopyState.gpuHeadsSummaryPass ='),{'txMask':mask},values,(16,4))
    heads=render('head_raster_'+str(gain),metric+common+inline(source,'rainDynamicSceneCopyState.gpuHeadsPassB ='),
        {**tx,'txMask':mask,'txSummary':summary},values,(1024,256))
    y,x=np.indices((256,1024));h=heads[:,:,1];total=h.sum(dtype=np.float64)
    centre=np.array([((x+.5)*h).sum(dtype=np.float64)/total/1024,((y+.5)*h).sum(dtype=np.float64)/total/256])
    assert np.max(abs(centre-[.5,.5]))<1e-6
    occupied=np.where(h>.01);width=(occupied[1].max()-occupied[1].min()+1)/1024*32
    # Re-evaluate the real descriptor while the appearance value changes.
    d=render('display_invariant_deposit_'+str(gain),env['descriptorCode'],
       {**geo,'txFilmOldState':os,'txFilmNewState':ns,'txFilmOldMeta':meta,'txFilmNewMeta':meta,'txFilmBirthEvent':events},
       {**v,'gHeadDisplayGain':gain},(1,5))
    assert np.array_equal(d,desc)
    measurements.append(dict(displayGain=gain,headCentreUV=centre.tolist(),displaySupportWidthMM=width,
                             trailCentreUV=centroid.tolist(),trailTransferredMM3=transfer))
    resized=Image.fromarray(optics[:,:,0]).resize((1024,256),Image.Resampling.BILINEAR)
    f=np.asarray(resized);f=f/max(float(f.max()),1e-30)
    rgb=np.stack((h*.8,f*.8+h*.35,f*.9),axis=-1)
    panel=Image.fromarray((np.clip(rgb,0,1)*255).astype(np.uint8)).crop((352,80,672,176)).resize((400,240))
    sheet.paste(panel,(j*400,55));draw.text((j*400+8,12),f'Head display gain {gain:g}',fill='white')
    draw.text((j*400+8,315),f'physical deposit {transfer:.7f} mm3',fill='white')
sheet.save(OUT/'head_field_same_segment.png')
report=dict(compiler='FXC ps_5_0 /Ges /WX, D3D11 WARP',
    fixture='Scripted 0.5mm head movement at30mm/s on flat metric; no incident source, shape lobes off. Not the game video.',
    physicalEquivalentDiameterMM=2,segmentCells=desc[0,0].tolist(),transferredMM3=transfer,
    sameStepSourceFieldMassErrorMM3=float(remaining+field.sum(dtype=np.float64)-float(meta[0,0,1])),
    noSameStepFreshTrailAdvection=True,measurements=measurements,
    conclusion='Current production contracts share positions/segments/time; head appearance gain changes footprint only, not the physical trail. This does not certify game visual continuity or film/head constitutive equivalence.')
(OUT/'head_field_link_checks.json').write_text(json.dumps(report,indent=2))
print('Same-segment GPU link passed:',json.dumps(measurements))
