"""Deterministic valid birth sites uniform in real triangle area, not UV area."""
from pathlib import Path
import struct,hashlib
import numpy as np
from PIL import Image
from kn5_assets import KN5
ROOT=Path(__file__).resolve().parents[2]
m=KN5(ROOT/'visors/visor_lando_2025Champion_maxquality_diet_face.kn5');v,i=m.mesh('GLASS_RAINFX')
tri=v[i,:3].astype(np.float64);area=np.linalg.norm(np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]),axis=1)*.5
mask=np.asarray(Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').convert('RGBA'))[:,:,3]
uv=v[i,6:8];cdf=np.cumsum(area);rng=np.random.default_rng(713);sites=[]
assert mask.shape==(1024,4096),'RainFX boundary mask must be 4096 x 1024'
for batch in range(64):
    if sum(len(s) for s in sites)>=8192:break
    ids=np.searchsorted(cdf,rng.uniform(0,cdf[-1],8192));r=rng.random((8192,2));root=np.sqrt(r[:,0])
    weights=np.stack((1-root,root*(1-r[:,1]),root*r[:,1]),1)
    p=np.einsum('ij,ijk->ik',weights,uv[ids]);p[:,1]+=1
    x=np.clip((p[:,0]*4096).astype(int),0,4095);y=np.clip((p[:,1]*1024).astype(int),0,1023)
    good=(mask[y,x]>127)&(p[:,0]>=0)&(p[:,0]<=1)&(p[:,1]>=0)&(p[:,1]<=1)
    output=np.ones((good.sum(),4),np.float32);output[:,:2]=p[good];output[:,2]=rng.random(good.sum());sites.append(output)
assert sum(len(s) for s in sites)>=8192,'Insufficient valid physical surface: check UVs and alpha mask'
a=np.concatenate(sites)[:8192].reshape(1,8192,4)
h,w,_=a.shape;header=[124,0x100f,h,w,w*16,0,1]+[0]*11+[32,4,struct.unpack('<I',b'DX10')[0],0,0,0,0,0]+[0x1000,0,0,0,0]
(ROOT/'texture/RAIN_GEOMETRY/spawn_sites.dds').write_bytes(b'DDS '+struct.pack('<31I',*header)+struct.pack('<5I',2,3,0,1,0)+a.astype('<f4').tobytes())
(ROOT/'texture/RAIN_GEOMETRY/spawn.verify').write_text(hashlib.sha256(m.blob).hexdigest()+'\n'+hashlib.sha256((ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').read_bytes()).hexdigest()+'\n')
print('PASS: 8192 physical-area birth sites, all inside new alpha mask')
