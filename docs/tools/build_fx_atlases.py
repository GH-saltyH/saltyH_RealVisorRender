"""Material textures on each independent FX UV. Offline normal-frame transport."""
from pathlib import Path
import io, struct, hashlib
import numpy as np
from PIL import Image, ImageFilter
from kn5_assets import KN5
from repair_visor_int_normal import component
from refine_visor_int_left_rim import read_rgba16
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'texture/GLASS/FX'
model=KN5(ROOT/'visors/visor_lando_2025Champion_maxquality_diet_face.kn5')
OUT.mkdir(parents=True,exist_ok=True)

def sample(image,uv):
    a=image if isinstance(image,np.ndarray) else np.asarray(image.convert('RGBA'),np.float32)/255
    h,w,_=a.shape;p=uv*[w,h]-.5;base=np.floor(p).astype(int);f=p-base
    x=base[:,:,0]%w;y=base[:,:,1]%h;X=(x+1)%w;Y=(y+1)%h
    return (a[y,x]*(1-f[:,:,0,None])+a[y,X]*f[:,:,0,None])*(1-f[:,:,1,None])+(a[Y,x]*(1-f[:,:,0,None])+a[Y,X]*f[:,:,0,None])*f[:,:,1,None]

def dds(path,a):
    h,w,_=a.shape
    header=[124,0x100f,h,w,w*16,0,1]+[0]*11+[32,4,struct.unpack('<I',b'DX10')[0],0,0,0,0,0]+[0x1000,0,0,0,0]
    path.write_bytes(b'DDS '+struct.pack('<31I',*header)+struct.pack('<5I',2,3,0,1,0)+a.astype('<f4').tobytes())

def normal16(path,a):
    h,w,_=a.shape
    header=[124,0x100f,h,w,w*8,0,1]+[0]*11+[32,4,struct.unpack('<I',b'DX10')[0],0,0,0,0,0]+[0x1000,0,0,0,0]
    path.write_bytes(b'DDS '+struct.pack('<31I',*header)+struct.pack('<5I',11,3,0,1,0)+np.rint(np.clip(a,0,1)*65535).astype('<u2').tobytes())

for role in ('EXT','INT','COAT'):
    transfer=np.load(ROOT/f'texture/RAIN_GEOMETRY/{role.lower()}_transfer.npz')
    uv=transfer['uv'];rotation=transfer['rotation'].reshape(*uv.shape[:2],3,3)
    slots=model.material('GLASS_'+role+'_MRR')['slots']
    for slot in ('txDiffuse','txNormal','txMaps','txDetail'):
        payload=model.textures[slots[slot]]
        image=Image.open(io.BytesIO(payload))
        if payload[:8]==b'\x89PNG\r\n\x1a\n' and payload[24:26]==bytes([16,6]):
            class BytesSource:
                def read_bytes(self):return payload
            image=read_rgba16(BytesSource()).astype(np.float32)/65535
        a=sample(image,uv[:,:,:2])
        if slot=='txNormal':
            n=a[:,:,:3]*2-1
            # AC normal textures use DirectX tangent Y; transport in geometric Y.
            n[:,:,1]*=-1;n=np.einsum('...i,...ij->...j',n,rotation)
            n/=np.maximum(np.linalg.norm(n,axis=2,keepdims=True),1e-10);n[:,:,1]*=-1
            a[:,:,:3]=n*.5+.5;a[:,:,3]=1
        Image.fromarray(np.clip(a*255+.5,0,255).astype(np.uint8)).save(OUT/(role.lower()+'_'+slot+'.png'))
        if role=='EXT' and slot=='txDiffuse':
            # Native diffuse alpha is glass opacity, not a custom band mask.
            band=a.copy();band[:,:,3]=np.clip((a[:,:,3]-.90)/.04,0,1)
            Image.fromarray(np.clip(band*255+.5,0,255).astype(np.uint8)).save(OUT/'ext_txBand.png')
        if role=='INT' and slot=='txNormal':
            normal16(OUT/'int_txNormal.dds',a)
            # Lens coverage follows the authored closed relief, not old atlas.
            length=np.linalg.norm(a[:,:,:2]*2-1,axis=2)
            mask=np.clip((length-.012)/.055,0,1)*(uv[:,:,3]>.5)
            # The two slopes bound one optical ring: retain its flat crown.
            # Closing joins the crown without filling the central window.
            closed=Image.fromarray((mask*255+.5).astype(np.uint8)).filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.MinFilter(11))
            mask=np.asarray(closed,np.float32)/255
            candidates=mask>.1
            largest=np.zeros_like(candidates)
            while candidates.any():
                region=component(candidates);candidates[region]=False
                if region.sum()>largest.sum():largest=region
            mask*=largest
            Image.fromarray((mask*255+.5).astype(np.uint8)).save(OUT/'int_outline.png')
            field=np.zeros_like(a);field[:,:,:2]=(a[:,:,:2]*2-1);field[:,:,3]=mask
            field[:,:,2]=mask;dds(OUT/'int_lens.dds',field)
    print(role,uv.shape,slots)
# Native capture materials without normals get an explicit neutral fallback.
Image.new('RGB',(4,4),(128,128,255)).save(ROOT/'texture/GLASS/E1_GEOMETRY/neutral_normal.png')
(OUT/'atlas.verify').write_text(hashlib.sha256(model.blob).hexdigest()+'\n')
