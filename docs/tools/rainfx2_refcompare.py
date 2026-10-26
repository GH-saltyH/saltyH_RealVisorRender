#!/usr/bin/env python3
"""Reference vs RainFX v2 image statistics (docs/RAINFX_V2_EVAL.md section 10).

Usage:
  python docs/tools/rainfx2_refcompare.py REF_DIR LABEL=IMG [LABEL=IMG ...]
REF_DIR holds frames extracted from the reference videos in subfolders C/, B/, A/
(e.g. ffmpeg -i ref.mp4 -vf fps=20/<duration> -q:v 2 REF_DIR/B/%02d.jpg).
Images are converted to luma, resized to 1280 px width (reference resolution), cropped to
a region of interest (broadcast graphics / game UI excluded) and summarised. Compare
regimes as RATIOS to the C (light) set of the same source: cameras, codecs and scenes
differ, so absolute values are not comparable.
"""
# Reference vs RainFX v2 image statistics (docs/RAINFX_V2_EVAL.md section 10).
import numpy as np, glob, sys, json, os
from PIL import Image
from scipy.ndimage import gaussian_filter, gaussian_laplace, maximum_filter
def load(path, roi):
    im=Image.open(path).convert('RGB'); w,h=im.size
    x0,y0,x1,y1=[int(v) for v in (roi[0]*w,roi[1]*h,roi[2]*w,roi[3]*h)]
    im=im.crop((x0,y0,x1,y1)); s=1280/w
    im=im.resize((max(1,int(im.size[0]*s)),max(1,int(im.size[1]*s))),Image.LANCZOS)
    a=np.asarray(im,np.float32)/255
    return a@np.array([0.2126,0.7152,0.0722],np.float32), a
def stats(Y, A):
    o={}
    o['p05'],o['p50'],o['p95']=[float(np.percentile(Y,q)) for q in (5,50,95)]
    o['range']=o['p95']-o['p05']
    o['sat']=float((A.max(-1)-A.min(-1)).mean())
    o['detail_mid']=float(np.abs(Y-gaussian_filter(Y,8)).mean())
    o['detail_fine']=float(np.abs(Y-gaussian_filter(Y,1.5)).mean())
    o['fine_over_mid']=o['detail_fine']/max(o['detail_mid'],1e-6)
    # blobs: scale-normalised LoG maxima (bright and dark), |resp| > T
    T=0.035; cnt=0; area=0; radii=[]
    resp=[]
    sig=(2.0,3.0,4.5,6.5,9.0)
    for s in sig: resp.append(-s*s*gaussian_laplace(Y,s))
    R=np.stack(resp)          # positive = bright blob
    for sign in (1,-1):
        Q=sign*R
        mx=maximum_filter(Q,size=(3,7,7))
        pk=(Q==mx)&(Q>T)
        k,yy,xx=np.nonzero(pk)
        for kk in k: radii.append(1.414*sig[kk])
        cnt+=len(k)
    radii=np.array(radii) if radii else np.zeros(1)
    A_=Y.size
    o['blobs_per_100kpx']=cnt/A_*1e5
    o['blob_r_med_pctW']=float(np.median(radii))/1280*100
    o['blob_cover']=float(np.sum(np.pi*radii**2)/A_)
    return o
def run(paths, roi):
    S=[stats(*load(p,roi)) for p in paths]
    return {k:float(np.median([s[k] for s in S])) for k in S[0]}, len(S)
REF_ROI=(0.03,0.09,0.97,0.88); OUR_ROI=(0.02,0.16,0.66,0.86)
if __name__ == '__main__':
    ref=sys.argv[1]
    sets={}
    for r in 'CBA':
        fs=sorted(glob.glob(os.path.join(ref,r,'*.jpg'))+glob.glob(os.path.join(ref,r,'*.png')))
        if fs: sets['ref '+r]=(fs,REF_ROI)
    for a in sys.argv[2:]:
        k,v=a.split('=',1); sets[k]=([v],OUR_ROI)
    keys=['p05','p50','p95','range','sat','detail_mid','detail_fine','fine_over_mid','blobs_per_100kpx','blob_r_med_pctW','blob_cover']
    print('| set | n | '+' | '.join(keys)+' |'); print('|'+'---|'*(len(keys)+2))
    for name,(ps,roi) in sets.items():
        m,n=run(ps,roi)
        print(f'| {name} | {n} | '+' | '.join(f'{m[k]:.3f}' for k in keys)+' |')
