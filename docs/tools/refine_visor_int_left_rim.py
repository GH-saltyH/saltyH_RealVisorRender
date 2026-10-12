"""Remove the local left-rim kink without changing other 16-bit normal data."""
from pathlib import Path
import hashlib
import json
import struct
import zlib
import numpy as np
from PIL import Image, ImageDraw
import repair_visor_int_normal as rim

SOURCE=rim.MASTER
DEST=rim.TEX/'GLASS_INT_txNormal_convex_continuous_v2_left_uniform_16bit.png'
PREVIEW=rim.TEX/'GLASS_INT_txNormal_convex_continuous_v2_left_uniform.png'
QA=rim.ROOT/'docs/diagnostics/2026-10-11/normal-left-rim-v2'
OLD_QA=rim.QA
RECORDS={}


def read_rgba16(path):
    data=path.read_bytes()
    assert data[:8]==b'\x89PNG\r\n\x1a\n'
    w,h,depth,color,compression,filtering,interlace=struct.unpack('>IIBBBBB',data[16:29])
    assert (depth,color,compression,filtering,interlace)==(16,6,0,0,0)
    payload=bytearray();offset=8
    while offset<len(data):
        size=struct.unpack('>I',data[offset:offset+4])[0]
        tag=data[offset+4:offset+8];chunk=data[offset+8:offset+8+size]
        assert zlib.crc32(tag+chunk)==struct.unpack('>I',data[offset+8+size:offset+12+size])[0]
        if tag==b'IDAT':payload.extend(chunk)
        offset+=size+12
    rows=np.frombuffer(zlib.decompress(payload),dtype='uint8').reshape(h,w*8+1)
    # This input is the previous numerical writer's exact filter-0 master.
    assert np.all(rows[:,0]==0)
    return rows[:,1:].copy().view('>u2').reshape(h,w,4).astype('uint16')


def refine(curve,role):
    # Coordinates in the original builder's crop: global origin (880,260).
    # Replace only the mid-left segment, leaving both rounded corners intact.
    result=curve.copy();branch=curve[curve[:,0]<200]
    branch=branch[np.argsort(branch[:,1])]
    ya,yb=300.,475.  # Full-resolution image Y: 560 to 735.
    xa,xb=np.interp([ya,yb],branch[:,1],branch[:,0])
    slopes=[]
    for y in [ya,yb]:
        local=branch[np.abs(branch[:,1]-y)<12]
        slopes.append(float(np.polyfit(local[:,1]-y,local[:,0],1)[0]))
    changed=(curve[:,0]<200)&(curve[:,1]>=ya)&(curve[:,1]<=yb)
    t=(curve[changed,1]-ya)/(yb-ya)
    replacement=(2*t**3-3*t**2+1)*xa+(t**3-2*t**2+t)*(yb-ya)*slopes[0]
    replacement+=(-2*t**3+3*t**2)*xb+(t**3-t**2)*(yb-ya)*slopes[1]
    result[changed,0]=replacement
    RECORDS[role]=dict(global_y_interval=[int(ya+260),int(yb+260)],
        start_end_x=[float(xa+880),float(xb+880)],endpoint_slopes=slopes,
        max_horizontal_correction_px=float(np.max(np.abs(result[:,0]-curve[:,0]))))
    return result


def main():
    QA.mkdir(parents=True,exist_ok=True)
    before=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    original=read_rgba16(SOURCE)
    previous=json.loads((OLD_QA/'validation.json').read_text(encoding='utf-8'))
    assert hashlib.sha256(rim.SOURCE.read_bytes()).hexdigest()==previous['source_sha256']
    rim.MASTER=QA/'regenerated_16bit.png';rim.DEST=QA/'regenerated_8bit.png';rim.QA=QA
    rim.main(contour_transform=refine)
    candidate=read_rgba16(rim.MASTER)
    delta=np.any(original!=candidate,axis=2)
    yy,xx=np.where(delta)
    assert len(xx)>0
    bounds=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]
    assert xx.min()>=900 and xx.max()<1100 and yy.min()>480 and yy.max()<805,bounds
    # Start from the supplied master; unrelated pixels are preserved exactly.
    output=original.copy();output[delta]=candidate[delta]
    assert np.array_equal(original[...,3],output[...,3])
    assert np.array_equal(original[~delta],output[~delta])
    rim.save_rgba16(DEST,output)
    rgb8=np.rint(output.astype('float64')/257).clip(0,255).astype('uint8')
    Image.fromarray(rgb8).save(PREVIEW)
    # Zoom the corrected segment; numerical diagnostic lighting checks continuity.
    region=(910,510,1090,780)
    board=Image.new('RGB',(720,570),'#242424');draw=ImageDraw.Draw(board)
    for i,(label,pixels) in enumerate([('BEFORE',original),('AFTER / UNIFORM LEFT RIM',output)]):
        rgba=np.rint(pixels.astype('float64')/257).clip(0,255).astype('uint8')
        im=Image.fromarray(rgba).convert('RGB').crop(region).resize((360,540),Image.Resampling.NEAREST)
        board.paste(im,(i*360,30));draw.text((i*360+8,10),label,fill='white')
    board.save(QA/'left_rim_before_after.png')
    n=output[...,:3].astype('float64')/32767.5-1
    unit_error=float(np.max(np.abs(np.linalg.norm(n[delta],axis=1)-1)))
    assert unit_error<.00003
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()==before
    report=dict(source=str(SOURCE),output=str(DEST),preview=str(PREVIEW),
        source_sha256=before,output_sha256=hashlib.sha256(DEST.read_bytes()).hexdigest(),
        resolution=[4096,1024],bit_depth=16,changed_pixels=int(delta.sum()),changed_bounds_xyxy=bounds,
        alpha_identical=True,all_pixels_outside_local_correction_identical=True,
        edited_normal_unit_length_max_error=unit_error,curve_correction=RECORDS,
        continuity_method='Cubic Hermite path with endpoint positions and tangents; scalar raised-height field -> normalized gradient normals.')
    (QA/'left_rim_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2))


if __name__=='__main__':main()
