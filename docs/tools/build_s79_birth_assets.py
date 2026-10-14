"""Offline physical area and static DSD/material LUTs; never run at game startup."""
from pathlib import Path
import sys,struct,hashlib,json,tempfile
sys.dont_write_bytecode=True
import numpy as np
from PIL import Image
from check_s75_inputs import load_lua
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-14/s79'
ASSET=ROOT/'texture/RAIN_BIRTH';ASSET.mkdir(exist_ok=True)
def dds(name,a):
    h,w,_=a.shape
    header=[124,0x100f,h,w,w*16,0,1]+[0]*11+[32,4,struct.unpack('<I',b'DX10')[0],0,0,0,0,0]+[0x1000,0,0,0,0]
    (ASSET/name).write_bytes(b'DDS '+struct.pack('<31I',*header)+struct.pack('<5I',2,3,0,1,0)+a.astype('<f4').tobytes())
with tempfile.TemporaryDirectory(prefix='lua_',dir=OUT,ignore_cleanup_errors=True) as folder:
    lua=load_lua(folder);model=lua.execute((ROOT/'rain_birth_model.lua').read_text())()
    lut=np.zeros((2,128,4),np.float32)
    for i in range(128):
        b=model.bins[i+1];lut[0,i]=[b.p[j] for j in range(1,5)]
        lut[1,i]=[b.diameter,b.volume,b.terminal,0]
    lut[0]=np.cumsum(lut[0],axis=0);lut[0,-1]=1
    dds('dsd.dds',lut)
# These are explicitly ESTIMATED material priors, not measured splash thresholds.
# LogWe transitions are broad; all rows conserve volume. P3 will supply actual wet state.
response=np.zeros((4,32,4),np.float32)
for coat in range(2):
    for wet in range(2):
        for k in range(32):
            x=k/31*5;t=np.clip((x-1.5)/2.5,0,1);t=t*t*(3-2*t)
            attached=(.95*(1-t)+.45*t) if not coat else (.60*(1-t)+.12*t)
            film=(.03*(1-t)+.30*t)*(1+.25*wet)*(1-.6*coat)
            micro=.01*(1-t)+.15*t
            rebound=max(0,1-attached-film-micro)
            response[coat*2+wet,k]=[attached,film,micro,rebound]
assert np.allclose(response.sum(axis=2),1) and np.min(response)>=0
dds('impact_estimated.dds',response)
geo=ROOT/'texture/RAIN_GEOMETRY'
def field(name):return np.frombuffer((geo/(name+'.dds')).read_bytes(),'<f4',offset=148).reshape(512,2048,4)
u=field('du');v=field('dv')
mask=np.asarray(Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').resize((2048,512),Image.Resampling.NEAREST).convert('RGBA'))[:,:,3]>127
valid=mask&(u[:,:,3]>=1)
area=float(np.linalg.norm(np.cross(u[:,:,:3].astype(np.float64),v[:,:,:3].astype(np.float64)),axis=2)[valid].sum()/(2048*512))
assert 0.005<area<.3,area
sites=np.frombuffer((geo/'spawn_sites.dds').read_bytes(),'<f4',offset=148).reshape(8192,4).copy()
xx=np.clip((sites[:,0]*2048).astype(int),0,2047);yy=np.clip((sites[:,1]*512).astype(int),0,511)
good=valid[yy,xx];assert good.mean()>.99,'Birth sites and supported metric disagree'
sites=sites[good];xx=xx[good];yy=yy[good]
cross=np.cross(u[yy,xx,:3],v[yy,xx,:3]);authored=field('normal')[yy,xx,:3]*2-1
cos=np.einsum('ij,ij->i',cross,authored)/np.maximum(np.linalg.norm(cross,axis=1)*np.linalg.norm(authored,axis=1),1e-20)
assert np.min(abs(cos))>1e-3,'Numerically ambiguous authored outward normal'
sites[:,2]=np.where(cos>=0,1,-1) # canonical outward sign, no 16 MiB normal texture at runtime
sites=np.resize(sites,(8192,4))
dds('sites.dds',sites.reshape(1,8192,4))
names=['texture/RAIN_GEOMETRY/du.dds','texture/RAIN_GEOMETRY/dv.dds','texture/RAIN_GEOMETRY/normal.dds',
       'texture/RAIN_GEOMETRY/spawn_sites.dds','texture/RAIN_GEOMETRY/surface.verify',
       'texture/RAINFX_ObjNormal_BoundaryMask.dds','rain_birth_model.lua']
manifest={n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in names}
manifest.update({f'texture/RAIN_BIRTH/{n}':hashlib.sha256((ASSET/n).read_bytes()).hexdigest()
                 for n in ('dsd.dds','impact_estimated.dds','sites.dds')})
verify=(geo/'surface.verify').read_text().splitlines()
runtimeHashes={k:v for k,v in manifest.items() if k=='rain_birth_model.lua' or k.startswith('texture/RAIN_BIRTH/')}
entries=','.join('["'+k+'"]="'+v+'"' for k,v in runtimeHashes.items())
code='return {areaM2='+format(area,'.17g')+',modelHash="'+verify[0]+'",maskHash="'+verify[1]+'",version="rain-birth-v1",hashes={'+entries+'}}\n'
(ASSET/'geometry.lua').write_text(code)
(ASSET/'assets.json').write_text(json.dumps(dict(areaM2=area,sha256=manifest,
    authoredAlignmentMin=float(np.min(abs(cos))),weakAlignmentSites=int((abs(cos)<.1).sum()),
    sourceSites=int(good.sum()),confidence='estimated material/DSD; baked physical metric area'),indent=2))
print('Built static DSD/impact LUTs; supported physical area',area,'m2')
