"""Production D3D11 WARP: native occlusion and equivalent Rain candidate culling."""
from pathlib import Path
import json,re,struct,subprocess,tempfile
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s63';OUT.mkdir(parents=True,exist_ok=True)
FXC='C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe'
EXE=ROOT/'docs/diagnostics/2026-10-11/native-visor-material/native_readback.exe'
def inline(source,anchor):
    a=source.index('[[',source.index(anchor))+2;return source[a:source.index(']]',a)]
lua=(ROOT/'realvisor.lua').read_text(encoding='utf-8');old=(OUT/'baseline/realvisor.lua').read_text(encoding='utf-8')
metric=(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text()
types={k:'float3' for k in ('gLayerColor','gLayerSun','gLayerBounce','gLayerAmbSky','gLayerAmbHorizon','gLayerLightDir','gLayerCameraSide','gLayerCameraUp','gLayerCameraLook')}
types.update({k:'float2' for k in ('gTile','gLayerInvShotSize','gLayerNativePixelScale','gOptNativePixelScale','gOptInvTarget','gOptEyeDeltaProjection','gOptProjectionScale')})
def render(name,code,textures,values,size,view=0):
    with tempfile.TemporaryDirectory(prefix='gpu_',dir=OUT) as folder:
        folder=Path(folder);tx=sorted(set(re.findall(r'\btx[A-Z]\w+',code)));val=sorted(set(re.findall(r'\bg[A-Z]\w+',code)))
        sampler=sorted(set(re.findall(r'\bsam[A-Z]\w+',code)))
        h='struct PS_IN {float4 PosH;float3 PosC;float3 NormalW;float2 Tex;};\n'
        h+='\n'.join('Texture2D '+t+';' for t in tx)+'\n'+'\n'.join('SamplerState '+t+';' for t in sampler)+'\n'
        h+='\n'.join(types.get(v,'float')+' '+v+';' for v in val)+'\n'
        code=code.replace('float4 main(PS_IN pin)','float4 production(PS_IN pin)')
        h+='float2 gTargetSize;float gView;\n'+code+'''
float4 main(float4 pixel:SV_POSITION):SV_TARGET {
    PS_IN pin;pin.PosH=pixel;pin.Tex=pixel.xy/gTargetSize;
    pin.PosC=float3((pin.Tex.x-.5)*.2+gView,(.5-pin.Tex.y)*.15,.2);
    pin.NormalW=float3(0,0,-1);return production(pin);
}
'''
        path=folder/'shader.hlsl';cso=folder/'shader.cso';path.write_text(h,encoding='utf-8')
        cp=subprocess.run([FXC,'/nologo','/T','ps_5_0','/E','main','/Ges','/WX','/Fo',str(cso),str(path)],capture_output=True,text=True)
        assert cp.returncode==0,cp.stdout+cp.stderr
        inputs=folder/'textures.bin'
        with inputs.open('wb') as f:
            f.write(struct.pack('<I',len(tx)))
            for name in tx:
                a=textures.get(name,np.zeros((1,1,4),np.float32));height,width,_=a.shape;b=name.encode()
                f.write(struct.pack('<I',len(b))+b+struct.pack('<4I',width,height,1,1)+a.astype('<f4').tobytes())
        params=folder/'params.txt';values={**values,'gTargetSize':size,'gView':view}
        params.write_text('\n'.join(k+' '+' '.join(map(str,np.atleast_1d(v))) for k,v in values.items()))
        output=folder/'out.bin';subprocess.run([str(EXE),str(cso),str(inputs),str(params),str(output),*map(str,size)],check=True,stdout=subprocess.PIPE)
        a=np.frombuffer(output.read_bytes(),'<f4').reshape(size[1],size[0],4)
        assert np.isfinite(a).all(),name
        return a
report=[]
native=(ROOT/'native_glass_occlusion.lua').read_text(encoding='utf-8')
face=inline(native,'self.params=self.params or')
a=render('native_front_face',face,{}, {},(128,64));assert np.min(a[:,:,0])>.19
report.append({'case':'actual native geometry capture shader compiles warning-free and writes metric distance'})
layer=(ROOT/'shaders/rainVisorLayer.hlsl').read_text(encoding='utf-8')
white=np.ones((64,128,4),np.float32);depth=white.copy();depth[:,:,:]=.1
v={'gLayerKind':1,'gLayerUseDiffuse':1,'gLayerBandOpacity':1,'gLayerBandAlphaMin':.06,
   'gLayerBandUnlitBrightness':1,'gLayerNativePixelScale':(1,1)}
tx={'txLayerDiffuse':white,'txLayerSource':white,'txLayerNativeDepth':depth}
a=render('native_off',layer,tx,v,(128,64));assert np.max(a[:,:,3])>.9
b=render('native_front',layer,tx,{**v,'gLayerNativeOn':1},(128,64));assert np.max(abs(b))==0
depth[:,:,:]=.5
c=render('native_behind',layer,tx,{**v,'gLayerNativeOn':1},(128,64));assert np.max(abs(c))==0
depth[:,:,:]=0
c=render('no_native_face',layer,tx,{**v,'gLayerNativeOn':1},(128,64));assert np.array_equal(a,c)
report.append({'case':'visible native exterior owns pixels despite FX depth differences; absent native retains output','front_max':float(np.max(abs(b)))})
# Cached HDR E4 gets the SAME non-compositing rejection before all effects/debug.
opt=(ROOT/'shaders/rainVisorOptics.hlsl').read_text()
gate=opt[opt.index('    if(gOptNativeOn>.5)'):opt.index('    float3 n=normalize(pin.NormalW)',opt.index('    if(gOptNativeOn>.5)'))]
code='float4 main(PS_IN pin) {\n'+gate+'return float4(20,10,5,0);}'
depth[:,:,:]=.1
a=render('cached_native_front',code,{'txOptNativeDepth':depth},{'gOptNativeOn':1,'gOptNativePixelScale':(1,1)},(128,64));assert np.max(abs(a))==0
report.append({'case':'cached E4 front native rejects all HDR contribution','front_max':float(np.max(abs(a)))})
# Actual production binning, then old/new kernels on identical states and masks.
def dds(k):return np.frombuffer((ROOT/f'texture/RAIN_GEOMETRY/{k}.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
geo={'txRainDu':dds('du'),'txRainDv':dds('dv'),'txRainBoundaryMask':np.asarray(Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').convert('RGBA'),np.float32)/255}
count=96;size=512;sites=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/spawn_sites.dds').read_bytes(),'<f4',offset=148).reshape(1,8192,4)
states=sites[:,:count,:].copy();states[:,:,1]-=1;states[:,:,2:]=(.04,-.02)
meta=np.zeros_like(states);meta[:,:,0]=.006;meta[:,:,3]=5
values={'gCount':count,'gSize':size,'gRainMetersPerUnit':.001/.0029296875,'gRainReferencePerMM':.0029296875}
frames=render('metric',metric+inline(lua,'rainDynamicSceneCopyState.gpuMetricShader ='),{**geo,'txRainState':states},values,(count,1))
tx={**geo,'txRainState':states,'txRainStateMeta':meta,'txRainDropMetric':frames,'txOverride':np.zeros_like(states)}
values.update(gMaskW=8,gTilesY=2,gTilesX=8,gWords=1,gTile=(64,256),gKs=1.45,gMaxRadii=1.3,gPuddleReach=1.07,
    gUvPerMM=.0029296875,gBodyStretch=1,gLookback=.03,gShapeOn=1,gShapeStrength=.8,gPuddleOn=1,gPuddleMinMM=1,gPuddleShare=.3,
    gLobesOn=1,gStretchGain=1,gSparseWords=0,gSummaryWords=1)
common=inline(lua,'rainDynamicSceneCopyState.gpuHeadsCommon =')
tx['txMask']=render('tile_mask',metric+common+inline(lua,'rainDynamicSceneCopyState.gpuHeadsPassA ='),tx,values,(8,2))
a=render('heads_before',metric+inline(old,'rainDynamicSceneCopyState.gpuHeadsCommon =')+inline(old,'rainDynamicSceneCopyState.gpuHeadsPassB ='),tx,values,(512,128))
b=render('heads_after',metric+common+inline(lua,'rainDynamicSceneCopyState.gpuHeadsPassB ='),tx,values,(512,128))
error=float(np.max(abs(a-b)));assert error<2e-6,error
assert np.max(b[:,:,1])>.2
report.append({'case':'early physical extent rejection preserves actual binned head output','max_delta':error,'slots':count})
(OUT/'gpu_checks.json').write_text(json.dumps(report,indent=2))
print('PASS: native front/behind/missing gates, cached E4 no blend, equivalent bounded Rain head culling')
