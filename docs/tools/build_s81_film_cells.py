"""Offline physical cell area/coverage/coating for the conservative P3 field."""
from pathlib import Path
import numpy as np,json,struct,hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];ASSET=ROOT/'texture/RAIN_FILM';ASSET.mkdir(exist_ok=True)
GEO=ROOT/'texture/RAIN_GEOMETRY'
def field(name):return np.frombuffer((GEO/(name+'.dds')).read_bytes(),'<f4',offset=148).reshape(512,2048,4)
u=field('du');v=field('dv')
mask=np.asarray(Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').resize((2048,512),Image.Resampling.NEAREST).convert('RGBA'))[:,:,3]>127
valid=mask&(u[:,:,3]>=1)
area=np.linalg.norm(np.cross(u[:,:,:3].astype(np.float64),v[:,:,:3].astype(np.float64)),axis=2)*valid*1e6/(2048*512)
def sum2(a):return a.reshape(256,2,1024,2).sum(axis=(1,3))
cells=np.zeros((256,1024,4),np.float32)
cells[:,:,0]=sum2(area);cells[:,:,1]=sum2(valid.astype(float))*.25
cells[:,:,2]=sum2(area*np.clip(v[:,:,3],0,1))/np.maximum(cells[:,:,0],1e-30)
cells[:,:,3]=cells[:,:,0]>1e-10
hdr=struct.pack('<31I',124,0x2100f,256,1024,1024*16,0,1,*([0]*11),32,4,0x30315844,*([0]*5),0x1000,0,0,0,0)
path=ASSET/'cells.dds';path.write_bytes(b'DDS '+hdr+struct.pack('<5I',2,3,0,1,0)+cells.astype('<f4').tobytes())
verify=(GEO/'surface.verify').read_text().splitlines()
sourceNames=['texture/RAIN_GEOMETRY/du.dds','texture/RAIN_GEOMETRY/dv.dds','texture/RAIN_GEOMETRY/position.dds','texture/RAINFX_ObjNormal_BoundaryMask.dds']
sha={n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in sourceNames}
sha['texture/RAIN_FILM/cells.dds']=hashlib.sha256(path.read_bytes()).hexdigest()
assert abs(float(cells[:,:,0].sum(dtype=np.float64))-float(area.sum()))<float(area.sum())*1e-7
# P4's 4-neighbour stencil requires a physically continuous supported UV domain.
# Reject a new seam topology for P4, while allowing P3 deposition to keep working.
points=field('position')[1::2,1::2,:3].astype(np.float64)
U=u[1::2,1::2,:3].astype(np.float64);V=v[1::2,1::2,:3].astype(np.float64)
supported=cells[:,:,0]>0;badEdges=0
for axis,derivative in ((1,U/1024),(0,V/256)):
    neighbours=supported[:,:-1]&supported[:,1:] if axis==1 else supported[:-1]&supported[1:]
    expected=np.linalg.norm(derivative[:,:-1] if axis==1 else derivative[:-1],axis=2)
    chord=np.linalg.norm(np.diff(points,axis=axis),axis=2)
    badEdges+=int(np.sum(neighbours&(chord>np.maximum(4*expected,.002))))
degenerate=int(np.sum(supported&(np.linalg.norm(np.cross(U,V),axis=2)<1e-12)))
flowConnected=badEdges==0 and degenerate==0
(ASSET/'geometry.lua').write_text('return {version="rain-film-v1",width=1024,height=256,pad=16,flowConnectedUV='+str(flowConnected).lower()+',modelHash="'+verify[0]+'",maskHash="'+verify[1]+'",cellsHash="'+sha['texture/RAIN_FILM/cells.dds']+'"}\n')
(ASSET/'assets.json').write_text(json.dumps(dict(width=1024,height=256,areaM2=float(cells[:,:,0].sum(dtype=np.float64))/1e6,
    flowConnectedUV=flowConnected,flowDiscontinuousEdges=badEdges,flowDegenerateCells=degenerate,sha256=sha),indent=2))
print('P3 cells: 1024x256, supported area',float(cells[:,:,0].sum(dtype=np.float64))/1e6,'m2')
print('P4 connected UV:',flowConnected,'discontinuous edges:',badEdges,'degenerate cells:',degenerate)
