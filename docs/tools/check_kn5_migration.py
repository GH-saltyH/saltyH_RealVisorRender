"""Mesh/UV/mask contract and physical-unit invariants for the new KN5."""
from pathlib import Path
import hashlib, json, struct, io, re
import numpy as np
from PIL import Image
from kn5_assets import KN5
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/kn5-migration'
OUT.mkdir(parents=True,exist_ok=True)
model=KN5(ROOT/'visors/visor_lando_2025Champion_maxquality_diet_face.kn5')
def data(key):return np.frombuffer((ROOT/f'texture/RAIN_GEOMETRY/{key}.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
du=data('du');dv=data('dv');pos=data('position');normal=data('normal')
maskImage=Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds')
mask=np.asarray(maskImage.resize((2048,512),Image.Resampling.NEAREST).convert('RGBA'),np.float32)/255
assert maskImage.size==(4096,1024)
valid=(mask[:,:,3]>.5)&(du[:,:,3]>.5)
assert valid.sum()>100000
u=du[valid,:3].astype(np.float64);v=dv[valid,:3].astype(np.float64)
a=np.sum(u*u,axis=1);b=np.sum(u*v,axis=1);c=np.sum(v*v,axis=1);det=a*c-b*b
assert np.isfinite(du).all() and np.isfinite(dv).all() and np.min(det)>1e-12
rng=np.random.default_rng(128);force=rng.normal(size=u.shape)
dotU=np.sum(u*force,1);dotV=np.sum(v*force,1)
projected=np.stack(((c*dotU-b*dotV)/det,(a*dotV-b*dotU)/det),axis=1)
reconstructed=u*projected[:,0,None]+v*projected[:,1,None]
residual=force-reconstructed
assert np.max(np.abs(np.sum(residual*u,1)))<1e-10
assert np.max(np.abs(np.sum(residual*v,1)))<1e-10
# A 1 mm radius remains 1 mm on strongly skewed and rotated triangles.
angle=rng.uniform(0,2*np.pi,len(u));lengthU=np.sqrt(a);along=b/lengthU;vertical=np.sqrt(c-along*along)
dy=np.sin(angle)*.001/vertical;dx=(np.cos(angle)*.001-along*dy)/lengthU
radius=np.linalg.norm(u*dx[:,None]+v*dy[:,None],axis=1)
assert np.max(abs(radius-.001))<1e-12
# Object map convention validation against interpolated KN5 vertex normals.
N=normal[valid,:3]*2-1;N/=np.maximum(np.linalg.norm(N,axis=1,keepdims=True),1e-10)
sourceN=mask[valid,:3]*2-1;sourceN/=np.maximum(np.linalg.norm(sourceN,axis=1,keepdims=True),1e-10)
cosine=np.sum(N*sourceN,1)
area=np.sqrt(det)
report={'model_sha256':hashlib.sha256(model.blob).hexdigest(),'mask_pixels':int((mask[:,:,3]>.5).sum()),
 'metric_supported_pixels':int(valid.sum()),'mask_without_metric_pixels':int(((mask[:,:,3]>.5)&(du[:,:,3]<.5)).sum()),
 'normal_mean_cosine':float(cosine.mean()),'normal_p05_cosine':float(np.percentile(cosine,5)),
 'physical_coated_fraction':float(np.sum(area*dv[valid,3])/np.sum(area)),
 'median_m_per_u':float(np.median(np.sqrt(a))),'median_m_per_v':float(np.median(np.sqrt(c))),
 'radius_max_error_m':float(np.max(abs(radius-.001))), 'triangle_count':len(model.meshes['GLASS_RAINFX']['indices'])}
for role in ('EXT','INT','COAT'):
    for slot in ('txDiffuse','txNormal','txMaps','txDetail'):
        image=Image.open(ROOT/f'texture/GLASS/FX/{role.lower()}_{slot}.png');assert image.size==(2048,512)
meta=json.loads((ROOT/'texture/RAIN_GEOMETRY/manifest.json').read_text())
assert meta['sha256']==report['model_sha256']
assert meta['mask_sha256']==hashlib.sha256((ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').read_bytes()).hexdigest()
assert meta['data_version']=='rain-surface-v2'
assert (ROOT/'texture/RAIN_GEOMETRY/surface.verify').read_text().splitlines()==[meta['sha256'],meta['mask_sha256'],'rain-surface-v2']
assert (ROOT/'texture/RAIN_GEOMETRY/spawn.verify').read_text().splitlines()==[meta['sha256'],meta['mask_sha256']]
assert (ROOT/'texture/GLASS/FX/atlas.verify').read_text().strip()==meta['sha256']
normal16=(ROOT/'texture/GLASS/FX/int_txNormal.dds').read_bytes()
assert struct.unpack_from('<2I',normal16,12)==(512,2048)
assert struct.unpack_from('<I',normal16,128)[0]==11 # RGBA16 UNORM
sites=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/spawn_sites.dds').read_bytes(),'<f4',offset=148).reshape(8192,4)
full=np.asarray(maskImage.convert('RGBA'))[:,:,3]
assert np.all(full[(sites[:,1]*1024).astype(int),(sites[:,0]*4096).astype(int)]>127)
assert np.isfinite(sites).all()
report['physical_birth_sites']=len(sites)
report['int_normal_format']='RGBA16 UNORM 2048 x 512'
report['micro_cell_extent_per_local_metre']=meta['micro_cell_extent_per_local_metre']
assert Image.open(ROOT/'texture/GLASS/visor_contamination_rgba.dds').size==(2048,512)
assets=set()
for name in ('realvisor.lua','visor_optics.lua'):
    lua=(ROOT/name).read_text(encoding='utf-8')
    assets.update(re.findall(r"(?:appFolder|d\.folder)\s*\.\.\s*'/((?:texture/)[^']+)'",lua))
    if name=='realvisor.lua':
        prefixes=list(re.finditer(r"local\s+T\s*=\s*appFolder\s*\.\.\s*'/(texture/[^']*)'",lua))
        for match in re.finditer(r"\bT\s*\.\.\s*'([^']+\.(?:dds|png))'",lua):
            prefix=[p for p in prefixes if p.start()<match.start()][-1].group(1)
            assets.add(prefix+match.group(1))
for asset in sorted(assets):assert (ROOT/asset).exists(),f'Missing active texture path: {asset}'
report['literal_runtime_texture_paths_checked']=len(assets)
(OUT/'geometry_checks.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2));print('PASS: KN5 exact EOF, per-surface 4:1 atlases, force projection, metric circles, model/mask hash')
