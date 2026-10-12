"""Deterministic linear data atlas: R dust, G scratches, B tangent, A smudge.

Fixed visor UV layout, seed 17. Numeric authoring explicitly authorized by user.
DDS alpha is data, not opacity. Does not alter mesh, diffuse or normal textures.
"""
from pathlib import Path
import struct, json, hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'texture/GLASS'
SIZE=2048
HEIGHT=SIZE//4

def build():
    rng=np.random.default_rng(17)
    dust=Image.new('L',(SIZE,HEIGHT));draw=ImageDraw.Draw(dust)
    # Sparse grains with varied radii. No uniform additive dust floor.
    for _ in range(10500):
        x,y=rng.uniform([0,0],[SIZE,HEIGHT]);radius=rng.uniform(.4,1.8)
        if rng.random()>.35+.65*abs(y/HEIGHT-.45):continue
        draw.ellipse((x-radius,y-radius,x+radius,y+radius),fill=int(rng.uniform(75,255)))
    dust=np.asarray(dust.filter(ImageFilter.GaussianBlur(.35)),np.uint8)
    scratches=np.zeros((HEIGHT,SIZE),np.uint8)
    yy,xx=np.mgrid[:HEIGHT,:SIZE]
    tangent=np.rint(((np.arctan2(yy-1.20*HEIGHT,xx-.48*SIZE)+np.pi/2)%(2*np.pi))/(2*np.pi)*255).astype(np.uint8)
    # Convert the pixel-space tangent into this rectangular atlas's UV axes.
    angle=tangent.astype(np.float32)/255*2*np.pi
    tangent=np.rint((np.arctan2(np.sin(angle)/HEIGHT,np.cos(angle)/SIZE)%(2*np.pi))/(2*np.pi)*255).astype(np.uint8)
    # Separate irregular segments of wipe arcs, not a repeating sine ripple.
    for _ in range(440):
        center=np.array([.48*SIZE,1.20*HEIGHT])
        radius=rng.uniform(.32*HEIGHT,1.22*SIZE)
        a=rng.uniform(-2.75,-.35);length=rng.uniform(.005,.065)
        t=np.linspace(a,a+length,max(4,int(radius*length*3)))
        x=np.rint(center[0]+radius*np.cos(t)).astype(int)
        y=np.rint(center[1]+radius*np.sin(t)).astype(int)
        valid=(x>=0)&(x<SIZE)&(y>=0)&(y<HEIGHT)
        x,y,t=x[valid],y[valid],t[valid]
        value=int(rng.uniform(100,245));take=scratches[y,x]<value
        scratches[y[take],x[take]]=value
    smudge=Image.new('L',(SIZE,HEIGHT));draw=ImageDraw.Draw(smudge)
    for _ in range(4):
        x,y=rng.uniform([0,0],[SIZE,HEIGHT]);rx,ry=rng.uniform(20,100),rng.uniform(70,200)
        draw.ellipse((x-rx,y-ry,x+rx,y+ry),fill=int(rng.uniform(6,24)))
    smudge=np.asarray(smudge.filter(ImageFilter.GaussianBlur(24)),np.uint8)
    rgba=np.stack((dust,scratches,tangent,smudge),axis=-1)
    OUT.mkdir(parents=True,exist_ok=True)
    Image.fromarray(rgba).save(OUT/'visor_contamination_rgba.png')
    header=[124,0x100F,HEIGHT,SIZE,SIZE*4,0,1]+[0]*11
    header += [32,0x41,0,32,0xff,0xff00,0xff0000,0xff000000]+[0x1000,0,0,0,0]
    path=OUT/'visor_contamination_rgba.dds'
    path.write_bytes(b'DDS '+struct.pack('<31I',*header)+rgba.tobytes())
    # Inspect packed values via opaque, labelled single-channel previews.
    preview=Image.new('RGB',(1536,544),(24,24,24));draw=ImageDraw.Draw(preview)
    for i,(label,channel) in enumerate([('R - dust',dust),('G - scratches',scratches),('A - smudge',smudge)]):
        tile=Image.fromarray(channel).resize((512,512),Image.Resampling.LANCZOS)
        preview.paste(tile.convert('RGB'),(i*512,32));draw.text((i*512+12,10),label,fill='white')
    preview.save(OUT/'visor_contamination_preview.png')
    meta={'size':[SIZE,HEIGHT],'seed':17,'format':'RGBA8 UNORM linear, alpha is smudge data',
          'channels':['dust','scratch coverage','scratch tangent / 2pi','smudge'],
          'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
          'mean_rgba':(rgba.mean(axis=(0,1))/255).tolist()}
    (OUT/'visor_contamination.json').write_text(json.dumps(meta,indent=2)+'\n')
    assert np.array_equal(np.frombuffer(path.read_bytes(),np.uint8,offset=128).reshape(rgba.shape),rgba)
    assert np.all(rgba[...,0]>=0) and np.count_nonzero(scratches)>250
    assert np.count_nonzero(scratches)<SIZE*HEIGHT*.03
    print(json.dumps(meta,indent=2))

if __name__=='__main__':build()
