"""Pack conservative distance-to-boundary into du.A, preserving du.RGB.

Exact 8-neighbour distance transform, in original mask texels. This lets
physical integration take larger steps in the interior and refine at holes.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'texture/RAIN_GEOMETRY'
valid=np.asarray(Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').convert('RGBA'))[:,:,3]>127
valid[[0,-1],:]=False;valid[:,[0,-1]]=False
h,w=valid.shape;x=np.arange(w,dtype=np.int32)
distance=np.where(valid,h+w,0).astype(np.int32)
for y in range(1,h):
    prev=distance[y-1]
    row=np.minimum(distance[y],prev+1)
    row[1:]=np.minimum(row[1:],prev[:-1]+1)
    row[:-1]=np.minimum(row[:-1],prev[1:]+1)
    distance[y]=x+np.minimum.accumulate(row-x)
for y in range(h-2,-1,-1):
    prev=distance[y+1]
    row=np.minimum(distance[y],prev+1)
    row[1:]=np.minimum(row[1:],prev[:-1]+1)
    row[:-1]=np.minimum(row[:-1],prev[1:]+1)
    distance[y]=(np.minimum.accumulate((row+x)[::-1])[::-1]-x)
path=OUT/'du.dds';blob=path.read_bytes();data=np.frombuffer(blob,'<f4',offset=148).reshape(512,2048,4).copy()
sourceX=np.minimum(((np.arange(2048)+.5)*w/2048).astype(int),w-1)
sourceY=np.minimum(((np.arange(512)+.5)*h/512).astype(int),h-1)
# Subtract 3 original texels: 2K lookup displacement plus mask-cell extent.
data[:,:,3]=np.where(data[:,:,3]>.5,np.maximum(1,distance[np.ix_(sourceY,sourceX)]-3),0)
path.write_bytes(blob[:148]+data.tobytes())
dv=np.frombuffer((OUT/'dv.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
u=data[data[:,:,3]>.5,:3].astype(np.float64);v=dv[data[:,:,3]>.5,:3].astype(np.float64)
a=np.sum(u*u,1);b=np.sum(u*v,1);c=np.sum(v*v,1)
extent=np.sqrt(np.stack((c,a),1)/(a*c-b*b)[:,None])*[1,.25]
bounds=np.max(extent,axis=0)
(OUT/'surface_bounds.lua').write_text(f'return {{{bounds[0]:.12g},{bounds[1]:.12g}}}\n')
meta=json.loads((OUT/'manifest.json').read_text())
meta['du_alpha']='valid >= 1; conservative safe step in source mask texels'
meta['step_limit_max_mask_texels']=int(data[:,:,3].max())
meta['data_version']='rain-surface-v2'
meta['micro_cell_extent_per_local_metre']=bounds.tolist()
(OUT/'manifest.json').write_text(json.dumps(meta,indent=2)+'\n')
lines=(OUT/'surface.verify').read_text().splitlines()
(OUT/'surface.verify').write_text('\n'.join(lines[:2]+['rain-surface-v2'])+'\n')
print('Packed boundary distance:',int(distance.max()),'mask texels; du.A max:',int(data[:,:,3].max()))
