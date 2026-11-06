"""Blob-density curve of a reference / game recording over a dark visor background (RAINFX_V2_SPRAY_RAIN_REF.md).
Frames: ffmpeg -i VIDEO -vf "select=not(mod(n\,10)),crop=1080:300:0:0" -vsync 0 -frame_pts 1 DIR/t_%04d.png
Usage: python docs/tools/rainfx2_ref_blobcurve.py DIR   (columns: frame, dark area px, bright LoG blobs / 100 kpx of dark
background, median / p90 radius px, area cover, fine / mid detail). Compare RATIOS between scenes of one source."""
import numpy as np, glob, sys, os
from PIL import Image
from scipy.ndimage import gaussian_filter, gaussian_laplace, maximum_filter, binary_erosion
d=sys.argv[1]; out=[]
sig=(2.0,3.0,4.5,6.5,9.0,13.0)
for f in sorted(glob.glob(d+'/t_*.png')):
    n=int(os.path.basename(f)[2:6])
    a=np.asarray(Image.open(f).convert('RGB'),np.float32)/255
    Y=a@np.array([0.2126,0.7152,0.0722],np.float32)
    bg=gaussian_filter(Y,20)
    dark=binary_erosion(bg<0.30,iterations=12); dark[:, :250]=False   # exclude F1 logo area
    area=dark.sum()
    if area<20000: out.append((n,area,0,0,0,0)); continue
    R=np.stack([-s*s*gaussian_laplace(Y,s) for s in sig])
    cnt=0; rad=[]; contrast=[]
    for sign in (1,):
        Q=sign*R; mx=maximum_filter(Q,size=(3,9,9)); pk=(Q==mx)&(Q>0.03)&dark[None]
        k,yy,xx=np.nonzero(pk); cnt+=len(k); rad+=[1.414*sig[i] for i in k]; contrast+=list(Q[pk])
    rad=np.array(rad) if rad else np.zeros(1)
    fine=float(np.abs(Y-gaussian_filter(Y,1.5))[dark].mean()); mid=float(np.abs(Y-gaussian_filter(Y,6))[dark].mean())
    out.append((n,area,cnt/area*1e5,float(np.median(rad)),float(np.percentile(rad,90)),float(np.sum(np.pi*rad**2)/area),fine,mid))
print('frame darkArea blobs/100kpx r_med r_p90 cover fine mid')
for o in out: print(' '.join(f'{v:.3f}' if isinstance(v,float) else str(v) for v in o))
