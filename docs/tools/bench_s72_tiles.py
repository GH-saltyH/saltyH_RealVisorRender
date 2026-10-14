"""4096 current-profile drops on actual bakes: model-width candidate cost."""
from pathlib import Path
import numpy as np,json
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-13/s72'
fixture=(ROOT/'docs/tools/bench_s67_candidates.py').read_text(encoding='utf-8')
fixture=fixture[:fixture.index('report={}')] .replace('2026-10-12/s67','2026-10-13/s72')
scope={'__file__':str(ROOT/'docs/tools/bench_s67_candidates.py')};exec(fixture,scope)
render=scope['render'];inline=scope['inline'];lua=scope['lua'];tx=scope['tx'];v=scope['v'];count=scope['count'];ref=scope['ref']
scope['meta'][:,:,0]=np.linspace(.57,.76,count)*ref/2
values={**v,'gSize':1024,'gNewTrailBirthHold':.6,'gNewTrailLifecycle':1,'gNewTrailWet':.8,'gNewTrailSupply':.8,
    'gNewTrailShear':.6,'gNewTrailDensity':1,'gNewTrailDensityMin':.15,'gNewTrailDensityFull':.6,
    'gNewTrailMinSpeed':1.3653*ref,'gNewTrailFullSpeed':34.133*ref,'gNewTrailMinDropMM':.2,
    'gNewTrailMinDiameterMM':.147,'gNewTrailWidthD':.21,'gNewTrailWipeD':.98,'gNewTrailWiden':1,
    'gNewTrailHeight':.74,'gNewTrailSeconds':.46,'gNewTrailWipeSeconds':.69,
    'gNewTrailSheetEnabled':1,'gNewTrailWaterEnabled':1,'gNewTrailWipeEnabled':1,
    'gNewTrailPixelUV':(1/1024,4/1024),'gTilesX':32,'gTilesY':8,'gMaskW':32*43,'gWords':43}
tx['txTrailPrevious']=np.zeros((256,1024,4),np.float32)
report={}
for scale in [1,3]:
    values.update(gNewTrailModelDiameterScale=scale,gNewTrailOutputDiameterScale=1/scale)
    desc=render('profile_descriptor_'+str(scale),(ROOT/'shaders/rainTrailDescriptor.hlsl').read_text(),tx,values,(count,5))
    bits=render('profile_tiles_'+str(scale),(ROOT/'shaders/rainTrailBin.hlsl').read_text(),{'txTrailDescriptors':desc},values,(values['gMaskW'],8)).astype(np.uint32)
    candidates=sum(int(x).bit_count() for x in bits.ravel())
    report[str(scale)]={'total_tile_candidates':candidates,'mean_candidates_per_atlas_pixel':candidates/(32*8),
                       'valid_descriptors':int((desc[1,:,1]>0).sum())}
report['candidate_relative_increase']=report['3']['total_tile_candidates']/report['1']['total_tile_candidates']-1
report['limits']='Actual metrics and current 100% birth diameter range, controlled velocities/ages; candidate work is not a GPU millisecond measurement.'
(OUT/'candidate_cost.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
