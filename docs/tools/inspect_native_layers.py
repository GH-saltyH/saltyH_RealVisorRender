"""Native KN5 states and physical ray order, independent of transparency sorting."""
from pathlib import Path
import json
import numpy as np
from kn5_assets import KN5
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s64'
k=KN5(ROOT/'visors/visor_lando_2025Champion_maxquality_diet_face.kn5')
names=['GLASS_EXT_MRR','GLASS_INT_MRR','GLASS_COAT_MRR','GLASS_STICKER_MRR']
report={'states':{}}
for n in names:
    m=k.meshes[n];mat=k.material(n)
    report['states'][n]={'flags':m['flags'],'shader':mat['shader'],'blend':mat['blend'],'depth':mat['depth'],
        'isAdditive':mat['properties'].get('isAdditive',[0])[0],'emAlphaFromDiffuse':mat['properties'].get('emAlphaFromDiffuse',[0])[0]}
def triangles(name):
    m=k.meshes[name];return m['vertices'][m['indices'],:6].astype(np.float64)
def distance(t,eye,ray):
    normal=t[:,:,3:].mean(axis=1);t=t[:,:,:3]
    edge1=t[:,1]-t[:,0];edge2=t[:,2]-t[:,0]
    p=np.cross(ray,edge2);det=np.sum(edge1*p,1);valid=abs(det)>1e-10
    inv=np.divide(1,det,out=np.zeros_like(det),where=valid)
    s=eye-t[:,0];u=np.sum(s*p,1)*inv;q=np.cross(s,edge1)
    v=q@ray*inv;d=np.sum(edge2*q,1)*inv
    hit=valid&(u>=0)&(v>=0)&(u+v<=1)&(d>0)&(normal@(-ray)>0)
    return float(d[hit].min()) if hit.any() else None
ext,inner=triangles(names[0]),triangles(names[1])
points=inner[:,:,:3].mean(axis=1)[np.linspace(0,len(inner)-1,128).astype(int)]
report['ray_order']=[]
for eye in (np.array([0,-.5,0.]),np.array([.15,-.5,.15])):
    gaps=[]
    for point in points:
        ray=point-eye;ray/=np.linalg.norm(ray)
        a,b=distance(ext,eye,ray),distance(inner,eye,ray)
        if a is not None and b is not None:gaps.append(b-a)
    report['ray_order'].append({'eye_model_local':eye.tolist(),'common_rays':len(gaps),
        'EXT_in_front':int(np.sum(np.array(gaps)>1e-5)),'INT_in_front':int(np.sum(np.array(gaps)<-1e-5)),
        'coplanar':int(np.sum(abs(np.array(gaps))<=1e-5)),'min_INT_minus_EXT_m':min(gaps),'max_INT_minus_EXT_m':max(gaps)})
(OUT/'native_layers.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
