"""Blender background: bake the KN5 UV Jacobian and offline INT→EXT lookup.

No UV-axis assumptions, wrapping, or runtime mesh-to-mesh UV conversion.
Run after build_visor_optics_assets.py with Blender --background --python.
"""
from pathlib import Path
import sys, json, hashlib, struct
import numpy as np
from mathutils.bvhtree import BVHTree
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'docs/tools'))
from kn5_assets import KN5
MODEL = ROOT / 'visors/visor_lando_2025Champion_maxquality_diet_face.kn5'
OUT = ROOT / 'texture/RAIN_GEOMETRY'
W, H = 2048, 512

def dds(path, image):
    h,w,_=image.shape
    header=[124,0x100f,h,w,w*16,0,1]+[0]*11+[32,4,struct.unpack('<I',b'DX10')[0],0,0,0,0,0]+[0x1000,0,0,0,0]
    path.write_bytes(b'DDS '+struct.pack('<31I',*header)+struct.pack('<5I',2,3,0,1,0)+image.astype('<f4').tobytes())

def raster(vertices, indices, callback):
    uv=vertices[:,6:8].copy();uv[:,1]+=1
    for ids in indices:
        t=uv[ids]; a,b=t[1]-t[0],t[2]-t[0]
        det=a[0]*b[1]-a[1]*b[0]
        if abs(det)<1e-12: continue
        lo=np.maximum(np.floor(t.min(0)*[W,H]-.5).astype(int),0)
        hi=np.minimum(np.ceil(t.max(0)*[W,H]-.5).astype(int),[W-1,H-1])
        if np.any(hi<lo):continue
        yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
        q=np.stack(((xx+.5)/W,(yy+.5)/H),axis=-1)-t[0]
        u=(q[...,0]*b[1]-q[...,1]*b[0])/det
        v=(a[0]*q[...,1]-a[1]*q[...,0])/det
        valid=(u>=-1e-6)&(v>=-1e-6)&(u+v<=1.000001)
        if np.any(valid):callback(ids,xx[valid],yy[valid],np.stack((1-u[valid]-v[valid],u[valid],v[valid]),-1),a,b,det)

def pad(images, valid, iterations=6):
    # Copy nearest valid neighbour, never average across islands or wrap edges.
    valid=valid.copy()
    for _ in range(iterations):
        old=valid.copy()
        for dy,dx in ((0,1),(0,-1),(1,0),(-1,0)):
            sy=slice(max(0,-dy),min(H,H-dy));sx=slice(max(0,-dx),min(W,W-dx))
            ty=slice(max(0,dy),min(H,H+dy));tx=slice(max(0,dx),min(W,W+dx))
            fill=(~valid[ty,tx])&old[sy,sx]
            for image in images:image[ty,tx][fill]=image[sy,sx][fill]
            valid[ty,tx][fill]=True
    return valid

def tree(model,name):
    v,i=model.mesh(name)
    return BVHTree.FromPolygons(v[:,:3].tolist(),i.tolist(),all_triangles=True),v,i

def bary(point, tri):
    a,b=tri[1]-tri[0],tri[2]-tri[0]; q=np.asarray(point)-tri[0]
    aa,ab,bb=np.dot(a,a),np.dot(a,b),np.dot(b,b);den=aa*bb-ab*ab
    if abs(den)<1e-20:return np.array([1.,0,0])
    u=(np.dot(q,a)*bb-np.dot(q,b)*ab)/den
    v=(np.dot(q,b)*aa-np.dot(q,a)*ab)/den
    return np.array([1-u-v,u,v])

def main():
    model=KN5(MODEL);OUT.mkdir(parents=True,exist_ok=True)
    vertices,indices=model.mesh('GLASS_RAINFX')
    du=np.zeros((H,W,4),np.float32);dv=du.copy();pos=du.copy();normal=du.copy()
    def paint(ids,x,y,weights,a,b,det):
        tri=vertices[ids,:3];e,f=tri[1]-tri[0],tri[2]-tri[0]
        du[y,x,:3]=(e*b[1]-f*a[1])/det
        dv[y,x,:3]=(f*a[0]-e*b[0])/det
        du[y,x,3]=1;pos[y,x,:3]=weights@tri;pos[y,x,3]=1
        normal[y,x,:3]=weights@vertices[ids,3:6]
    raster(vertices,indices,paint)
    valid=du[:,:,3]>.5
    coating,_,_=tree(model,'GLASS_COAT_FX')
    yy,xx=np.nonzero(valid)
    for y,x in zip(yy,xx):
        nearest=coating.find_nearest(Vector(pos[y,x,:3]))
        dv[y,x,3]=1. if nearest[0] is not None and nearest[3]<.0015 else 0.
    normals=normal[:,:,:3];normals/=np.maximum(np.linalg.norm(normals,axis=-1,keepdims=True),1e-10)
    normal[:,:,:3]=normals*.5+.5;normal[:,:,3]=valid
    coat_fraction=float(dv[:,:,3][valid].mean())
    padded=pad([du,dv,pos,normal],valid)
    for key,image in [('du',du),('dv',dv),('position',pos),('normal',normal)]:dds(OUT/(key+'.dds'),image)
    # Correspondence is object-space nearest surface, not shared UV coordinates.
    ext,ev,ei=tree(model,'GLASS_EXT_FX');iv,ii=model.mesh('GLASS_INT_FX')
    field=np.zeros((H,W,4),np.float32)
    mapped=np.zeros((len(iv),2),np.float32);errors=[]
    for idx,p in enumerate(iv[:,:3]):
        nearest=ext.find_nearest(Vector(p));assert nearest[0] is not None
        weights=bary(nearest[0],ev[ei[nearest[2]],:3])
        mapped[idx]=weights@ev[ei[nearest[2]],6:8]+[0,1];errors.append(nearest[3])
    def correspondence(ids,x,y,weights,*_):field[y,x,:2]=weights@mapped[ids];field[y,x,3]=1
    raster(iv,ii,correspondence);pad([field],field[:,:,3]>.5)
    glass=ROOT/'texture/GLASS';glass.mkdir(parents=True,exist_ok=True)
    dds(glass/'GLASS_INT_EXT_UV_FIELD.dds',field)
    for role in ('EXT','INT','COAT'):
        target='GLASS_'+role+'_FX';source='GLASS_'+role+'_MRR'
        sv,si=model.mesh(source);tv,ti=model.mesh(target);source_tree,_,_=tree(model,source)
        mapped=np.zeros((len(tv),2),np.float32);source_frames=np.zeros((len(tv),3,3),np.float32)
        def frame(n,tri,uv):
            n=n/max(np.linalg.norm(n),1e-10);a,b=uv[1]-uv[0],uv[2]-uv[0]
            det=a[0]*b[1]-a[1]*b[0]
            assert abs(det)>1e-12,(role,'Degenerate source UV')
            t=((tri[1]-tri[0])*b[1]-(tri[2]-tri[0])*a[1])/det
            v=((tri[2]-tri[0])*a[0]-(tri[1]-tri[0])*b[0])/det
            t-=n*np.dot(n,t);t/=max(np.linalg.norm(t),1e-10)
            b=np.cross(n,t);b*=1 if np.dot(b,v)>=0 else -1
            return np.stack((t,b,n))
        for idx,p in enumerate(tv[:,:3]):
            nearest=source_tree.find_nearest(Vector(p));ids=si[nearest[2]]
            weights=bary(nearest[0],sv[ids,:3]);mapped[idx]=weights@sv[ids,6:8]
            mapped[idx]-=np.floor(mapped[idx])
            source_frames[idx]=frame(weights@sv[ids,3:6],sv[ids,:3],sv[ids,6:8])
        field=np.zeros((H,W,4),np.float32);rotation=np.zeros((H,W,9),np.float32)
        def transfer(ids,x,y,weights,*_):
            field[y,x,:2]=weights@mapped[ids];field[y,x,3]=1
            # Orthogonal frames at target pixel, transport tangent-space normals.
            n=weights@tv[ids,3:6];n/=np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-10)
            a,b=tv[ids[1],6:8]-tv[ids[0],6:8],tv[ids[2],6:8]-tv[ids[0],6:8]
            det=a[0]*b[1]-a[1]*b[0];e,f=tv[ids[1],:3]-tv[ids[0],:3],tv[ids[2],:3]-tv[ids[0],:3]
            t=(e*b[1]-f*a[1])/det;v=(f*a[0]-e*b[0])/det
            t=t[None,:]-n*np.sum(n*t,axis=1,keepdims=True);t/=np.maximum(np.linalg.norm(t,axis=1,keepdims=True),1e-10)
            bit=np.cross(n,t);bit*=np.where(np.sum(bit*v,axis=1)>=0,1,-1)[:,None]
            target_frame=np.stack((t,bit,n),axis=1)
            old_frame=np.einsum('pi,ijk->pjk',weights,source_frames[ids])
            rotation[y,x]=np.einsum('pij,pkj->pik',old_frame,target_frame).reshape(-1,9)
        raster(tv,ti,transfer);pad([field,rotation],field[:,:,3]>.5)
        np.savez_compressed(OUT/(role.lower()+'_transfer.npz'),uv=field,rotation=rotation)
        print('Baked independent material correspondence:',role,flush=True)
    mask=ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds'
    meta={'model':str(MODEL.relative_to(ROOT)),'sha256':hashlib.sha256(model.blob).hexdigest(),
        'mask_sha256':hashlib.sha256(mask.read_bytes()).hexdigest(),'mesh':'GLASS_RAINFX',
        'width':W,'height':H,'valid_pixels':int(valid.sum()),'padded_pixels':int(padded.sum()),
        'coated_fraction':coat_fraction,'coat_distance_m':.0015,
        'int_ext_max_distance_m':float(max(errors)),'units':'metres per raw KN5 UV unit',
        'uv_domain':[0,1,-1,0],'wrap':False}
    (OUT/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n')
    (OUT/'surface.verify').write_text(meta['sha256']+'\n'+meta['mask_sha256']+'\n')
    print(json.dumps(meta,indent=2))

if __name__=='__main__':main()
