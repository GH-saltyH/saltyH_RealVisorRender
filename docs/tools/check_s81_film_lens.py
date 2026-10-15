"""Full production rain shader: physical-film optics, empty/native/depth gates."""
from pathlib import Path
import re,json,struct,subprocess,tempfile,sys
sys.dont_write_bytecode=True
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s81'
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text();env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')}
exec(base[:base.index('report=[]')],env);env['OUT']=OUT
helpers=(ROOT/'docs/tools/check_s66_gpu.py').read_text();compiled={}
exec(helpers[helpers.index('def full_render('):helpers.index('\ny,x=np.mgrid')],globals())
compiledHeader=(ROOT/'docs/diagnostics/2026-10-12/s67/shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8')
metric=(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text()
header=compiledHeader[:compiledHeader.index('// KN5 local metres / raw signed UV.')]
newUniforms='float2 gDynamicDropP3Grid;\n'+'\n'.join('float '+key+';' for key in
    ('gDynamicDropP3On','gDynamicDropP3OpticalGain','gDynamicDropP3MaxPx','gDynamicDropP3MicroMip','gDynamicDropP3Debug'))+'\n'
full=header+newUniforms+metric+(ROOT/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8').replace('float4 main(PS_IN pin)','float4 main(PS_IN pin):SV_TARGET')
old=header+metric+(OUT/'baseline/shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8').replace('float4 main(PS_IN pin)','float4 main(PS_IN pin):SV_TARGET')
W,H=256,64;y,x=np.mgrid[:H,:W]
scene=np.stack(((x//3)%2,(y//3)%2,x/W,np.ones_like(x)),axis=-1).astype(np.float32)
du=np.zeros_like(scene);du[:,:,0]=.3;du[:,:,3]=100
dv=np.zeros_like(scene);dv[:,:,1]=.2;dv[:,:,3]=1
mask=np.ones_like(scene)
height=np.zeros_like(scene);height[20:45,60:200,0]=300*np.sin(np.pi*np.arange(140)/140)[None,:]**2
tx={'txRainDu':du,'txRainDv':dv,'txRainBoundaryMask':mask,'txDynamicWaterTrail':height,'txDynamicSnapshot':scene}
values={'gRainMetersPerUnit':.001/(6/4096),'gRainReferencePerMM':6/4096,'gDynamicDropP3Grid':(W,H),
        'gDynamicDropP3On':1,'gDynamicDropP3OpticalGain':1,'gDynamicDropP3MaxPx':24,'gDynamicDropP3MicroMip':2,
        'gDynamicDropCameraForward':(0,0,1),'gDynamicDropCameraSide':(1,0,0),'gDynamicDropCameraUp':(0,1,0)}
a=full_render('physical_film_lens',full,tx,values,(W,H))
b=full_render('physical_film_no_optical_gain',full,tx,{**values,'gDynamicDropP3OpticalGain':0},(W,H))
delta=float(np.max(abs(a[:,:,:3]-b[:,:,:3])))
assert delta>.02 and a[:,:,3].max()>.9
assert np.max(abs(a[:15]))==0 and np.max(abs(a[50:]))==0
empty=full_render('empty_field_no_ghost',full,{**tx,'txDynamicWaterTrail':np.zeros_like(height)},values,(W,H))
assert np.max(abs(empty))==0
debug=full_render('film_height_debug',full,tx,{**values,'gDynamicDropP3Debug':1},(W,H))
assert debug[:,:,0].max()>.6
head=np.zeros_like(scene);head[24:40,112:144,1]=.9;head[:,:,0]=head[:,:,1]*.08
headTx={**tx,'txDynamicBirthMask':head}
headValues={**values,'gDynamicDropP3On':0,'gDynamicDropWaterField':1,'gDynamicDropWFThreshold':.35,
            'gDynamicDropWFOpacity':.8,'gDynamicDropWFInvMaskSize':1/W,'gDynamicDropWFHeadStep':1/W,
            'gDynamicDropWFKernelScale':1.2,'gDynamicDropWFRefraction':.004,'gDynamicDropWaterToneFloor':1}
off=full_render('P3_off_visible_heads',full,headTx,headValues,(W,H))
reference=full_render('P2_stamp_visible_heads',old,headTx,{k:v for k,v in headValues.items() if 'P3' not in k},(W,H))
assert np.array_equal(off,reference)
assert off[:,:,3].max()>.5
depth=np.zeros_like(scene);depth[:,:,0]=.1
hidden=full_render('native_front_excludes_physical_film',full,{**tx,'txDynamicOcclusion':depth},
                   {**values,'gDynamicDropOcclusionOn':1},(W,H))
assert np.max(abs(hidden))==0
coverage=full.replace('    return c;\n#endif','    return float4(1,1,1,1);\n#endif')
transparentDepth=full_render('transparent_film_no_depth','#define RAIN_DEPTH_ONLY 1\n'+coverage,tx,
                            {**values,'gDynamicDropDepthOnly':1,'gDynamicDropDepthExact':1,'gDynamicDropDepthAlphaMin':.5},(W,H))
assert np.max(abs(transparentDepth))==0
Image.fromarray((np.clip(a[:,:,:3],0,1)*255).astype(np.uint8)).save(OUT/'physical_film_lens.png')
report=dict(compiler='full production shader, FXC /Ges /WX, D3D11 WARP',refractionRGBDelta=delta,
            substantialAlpha=float(a[:,:,3].max()),emptyFieldNoGhost=True,uncoveredPixelsClear=True,
            P3OffBitIdenticalToP2Stamp=True,nativeFrontExcluded=True,transparentFilmWritesNoOpaqueDepth=True)
(OUT/'lens_checks.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
