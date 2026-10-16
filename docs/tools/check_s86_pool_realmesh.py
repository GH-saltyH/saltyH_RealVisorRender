"""Production P4b on actual geometry, using supplied peak masses in a SYNTHETIC field."""
from pathlib import Path
import sys,json
import numpy as np
from PIL import Image
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s86'
env={'__file__':str(ROOT/'docs/tools/check_s86_pool_gpu.py')}
exec((ROOT/'docs/tools/check_s86_pool_gpu.py').read_text().split('\nreports=[]\n',1)[0],env)
render=env['render'];code=env['code'];metric=env['metric'];core=env['core']
def asset(name):return np.frombuffer((ROOT/f'texture/RAIN_GEOMETRY/{name}.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
cells=np.frombuffer((ROOT/'texture/RAIN_FILM/cells.dds').read_bytes(),'<f4',offset=148).reshape(256,1024,4)
mask=np.asarray(Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').convert('RGBA'),np.float32)/255
geo={'txRainDu':asset('du'),'txRainDv':asset('dv'),'txRainBoundaryMask':mask}
field=np.zeros((288,1056,4),np.float32);field[16:272,16:1040,0]=cells[:,:,0]*.001
review=json.loads((ROOT/'docs/diagnostics/2026-10-15/s85/regime_review.json').read_text())
points=[]
for row in review['evidence']:
    x,y=row['staticCell']['x'],row['staticCell']['y'];points.append((x,y))
    field[16+y,16+x,0]=row['derived']['worstCellVolumeMM3']
values={**env['v'],'gFilmGrid':(1024,256),'gFilmPaddedSize':(1056,288),
        'gPoolCount':4096,'gBirthCount':4096,'gFilmCount':4096,'gPoolTick':0}
c=render('real_mesh_pool_candidates',env['candidateCode'],{'txFilmPrevious':field,'txFilmCells':cells},values,(1024,1))
chosen=c[0,c[0,:,3]>0]
assert len(chosen)==2 and set(map(tuple,chosen[:,:2].astype(int)))==set(points),chosen
meta=np.zeros((1,4096,4),np.float32);meta[:,:,3]=28
state=np.tile(np.array([.5,-.5,0,0],np.float32),(1,4096,1))
tx={**env['sourceTx'],**geo,'txRainState':state,'txRainStateMeta':meta,'txPoolCandidates':c}
ev=render('real_mesh_pool_events',env['eventCode'],tx,values,(4096,5))
assert np.count_nonzero(ev[4,:,2])==2
spawn=ev[0,ev[4,:,2]>0];positions=np.floor((spawn[:,:2]+[0,1])*[1024,256]).astype(int)
assert set(map(tuple,positions))==set(points)
# Same real geometry/field with display-only coefficients present does not
# alter event output; these values do not occur in the pool/source shader.
display=render('display_coefficients_independent',env['eventCode'],tx,
    {**values,'gDynamicDropP2DisplayScale':.05,'gRainDisplayDiameterGain':2},(4096,5))
assert np.array_equal(ev,display)
(OUT/'realmesh_checks.json').write_text(json.dumps(dict(
    compiler='FXC ps_5_0 /Ges /WX, D3D11 WARP',actualGeometryAndMask=True,
    field='Synthetic: 1um background and two provided cell masses; not reconstructed game spatial field.',
    cells=points,acceptedHeads=2,returnedMM3=float(ev[4,:,2].sum(dtype=np.float64)),
    displayCoefficientsIndependent=True),indent=2))
print('s86 actual mesh: both supplied peak-cell synthetic pools return to heads; display coefficients independent')
