"""Bake numeric lens data INSIDE original white mask; never fill black holes.
RG = signed convex surface slope, B = dome height, A = original white region.
Run from repository root; source mask stays unchanged. Output RGBA16F DDS.
"""
from pathlib import Path
from collections import deque
import struct
import numpy as np
from PIL import Image
source=Path('texture/GLASS/GLASS_INT_OUTLINE_MASK.png');out=source.with_name('GLASS_INT_LENS_FIELD.dds');n=1024
mask=np.asarray(Image.open(source).convert('L').resize((n,n),Image.Resampling.BOX))>127
edge=mask & ~(np.roll(mask,1,0)&np.roll(mask,-1,0)&np.roll(mask,1,1)&np.roll(mask,-1,1))
distance=np.zeros((n,n),np.int32);distance[edge]=1;queue=deque(zip(*np.nonzero(edge)))
while queue:
 y,x=queue.popleft()
 for yy,xx in [(y-1,x),(y+1,x),(y,x-1),(y,x+1)]:
  if 0<=yy<n and 0<=xx<n and mask[yy,xx] and distance[yy,xx]==0:distance[yy,xx]=distance[y,x]+1;queue.append((yy,xx))
# Rounded cylinder cross-section across the white band: zero at edges,
# gently rounded maximum at its medial ridge. Mild smoothing avoids stairs.
height=np.sin(np.clip((distance.astype(np.float32)-.5)/max(distance.max(),1),0,1)*np.pi*.5)*mask
height=sum(np.roll(np.roll(height,y,0),x,1) for y in [-1,0,1] for x in [-1,0,1])/9
height*=mask
gy,gx=np.gradient(height);scale=max(np.percentile(np.hypot(gx,gy)[mask],95),1e-6)
grad=np.stack((gx/scale,gy/scale),axis=2);grad/=np.maximum(np.linalg.norm(grad,axis=2,keepdims=True),1);grad*=mask[:,:,None]
field=np.concatenate((grad,height[:,:,None],mask.astype(np.float32)[:,:,None]),axis=2).astype('<f2')
header=[124,0x100f,n,n,n*8,0,1]+[0]*11+[32,4,struct.unpack('<I',b'DX10')[0],0,0,0,0,0]+[0x1000,0,0,0,0]
out.write_bytes(b'DDS '+struct.pack('<31I',*header)+struct.pack('<5I',10,3,0,1,0)+field.tobytes())
assert np.max(field[:,:,3][~mask])==0 and not field[n//4,n//2,3]
assert np.max(height)>.5 and np.any(gx[mask]>0) and np.any(gx[mask]<0)
print('Lens field white-mask-only:',np.count_nonzero(mask),'pixels; black center preserved')
