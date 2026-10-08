"""Bake EXT material UV on the INT mesh from nearest surface triangles.
Numeric RGBA16F DDS: RG=EXT UV, A=valid INT surface. Source KN5 unchanged.
"""
from pathlib import Path
import struct,re,numpy as np
root=Path(__file__).resolve().parents[2];b=(root/'visors/visor_lando_2025Champion_maxquality_diet.kn5').read_bytes()
def mesh(key):
 for m in re.finditer(key.encode(),b):
  if struct.unpack_from('<I',b,m.start()-8)[0]==2:
   p=m.end();n=struct.unpack_from('<I',b,p+8)[0];v=np.frombuffer(b,dtype='<f4',count=n*11,offset=p+12).reshape(n,11).astype(float);i=p+12+n*44;count=struct.unpack_from('<I',b,i)[0];indices=np.frombuffer(b,dtype='<u2',count=count,offset=i+4).reshape(-1,3);return v,indices
iv,it=mesh('GLASS_INT_OVERLAY');ev,et=mesh('GLASS_EXT_OVERLAY');tri=ev[et,:3];uvtri=ev[et,6:8];mapped=[]
for p in iv[:,:3]:
 a=tri[:,0];ab=tri[:,1]-a;ac=tri[:,2]-a;ap=p-a
 aa=(ab*ab).sum(1);bb=(ab*ac).sum(1);cc=(ac*ac).sum(1);d=(ap*ab).sum(1);e=(ap*ac).sum(1);den=aa*cc-bb*bb;safe=np.where(abs(den)>1e-16,den,1)
 v=(cc*d-bb*e)/safe;w=(aa*e-bb*d)/safe;bary=np.c_[1-v-w,v,w];proj=a+ab*v[:,None]+ac*w[:,None];dist=((proj-p)**2).sum(1);dist[(bary<0).any(1)|(abs(den)<1e-16)]=np.inf
 best=int(dist.argmin());bd=dist[best];bu=bary[best]@uvtri[best]
 for j,k in [(0,1),(1,2),(2,0)]:
  q=tri[:,j];edge=tri[:,k]-q;t=np.clip(((p-q)*edge).sum(1)/np.maximum((edge*edge).sum(1),1e-16),0,1);pt=q+edge*t[:,None];ds=((pt-p)**2).sum(1);idx=int(ds.argmin())
  if ds[idx]<bd:bd=ds[idx];bu=uvtri[idx,j]*(1-t[idx])+uvtri[idx,k]*t[idx]
 mapped.append(bu)
mapped=np.array(mapped);n=1024;field=np.zeros((n,n,4),np.float32);uv=iv[:,6:8]%1
for ids in it:
 t=uv[ids]*n-.5;lo=np.maximum(np.floor(t.min(0)).astype(int),0);hi=np.minimum(np.ceil(t.max(0)).astype(int),n-1)
 if (hi<lo).any():continue
 xs,ys=np.meshgrid(np.arange(lo[0],hi[0]+1),np.arange(lo[1],hi[1]+1));p=np.stack((xs,ys),axis=-1);ab=t[1]-t[0];ac=t[2]-t[0];det=ab[0]*ac[1]-ab[1]*ac[0]
 if abs(det)<1e-10:continue
 q=p-t[0];v=(q[:,:,0]*ac[1]-q[:,:,1]*ac[0])/det;w=(ab[0]*q[:,:,1]-ab[1]*q[:,:,0])/det;weights=np.stack((1-v-w,v,w),axis=-1);inside=(weights>=-1e-6).all(2);values=weights@mapped[ids];field[ys[inside],xs[inside],:2]=values[inside];field[ys[inside],xs[inside],3]=1
# Extend values a few texels into raster boundaries for bilinear filtering.
valid=field[:,:,3]>0
for _ in range(4):
 for axis,shift in [(0,1),(0,-1),(1,1),(1,-1)]:
  neighbour=np.roll(field,shift,axis);take=~valid&(neighbour[:,:,3]>0);field[take]=neighbour[take];valid[take]=True
header=[124,0x100f,n,n,n*8,0,1]+[0]*11+[32,4,struct.unpack('<I',b'DX10')[0],0,0,0,0,0]+[0x1000,0,0,0,0]
out=root/'texture/GLASS/GLASS_INT_EXT_UV_FIELD.dds';out.write_bytes(b'DDS '+struct.pack('<31I',*header)+struct.pack('<5I',10,3,0,1,0)+field.astype('<f2').tobytes())
assert np.isfinite(mapped).all() and valid.any();print('EXT UV field generated; vertices',len(mapped),'mapped V bounds',mapped[:,1].min(),mapped[:,1].max())
