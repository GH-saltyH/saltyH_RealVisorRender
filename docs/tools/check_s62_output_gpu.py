"""Execute production glass/micro/cache/readback paths on D3D11 WARP."""
from pathlib import Path
import re,json,struct,subprocess,tempfile
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s62'
FXC='C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe'
EXE=ROOT/'docs/diagnostics/2026-10-11/native-visor-material/native_readback.exe'
lua=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
metric=(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text()
def inline(anchor):
    a=lua.index('[[',lua.index(anchor))+2;return lua[a:lua.index(']]',a)]
def dds(key):return np.frombuffer((ROOT/f'texture/RAIN_GEOMETRY/{key}.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
geometry={'txRainDu':dds('du'),'txRainDv':dds('dv'),'txRainBoundaryMask':np.asarray(Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').convert('RGBA'),np.float32)/255}
types={k:'float3' for k in ('gLayerColor','gLayerSun','gLayerBounce','gLayerAmbSky','gLayerAmbHorizon','gLayerLightDir','gLayerCameraSide','gLayerCameraUp','gLayerCameraLook')}
types.update({k:'float2' for k in ('gLayerInvShotSize','gLayerNativePixelScale','gSize','gMicroGridUV','gMicroSearch')})
def wrapped(code):
    textures=sorted(set(re.findall(r'\btx[A-Z]\w+',code)))
    values=sorted(set(re.findall(r'\bg[A-Z]\w+',code)))
    samplers=sorted(set(re.findall(r'\bsam[A-Z]\w+',code)))
    header='struct PS_IN {float4 PosH;float3 PosC;float3 NormalW;float2 Tex;};\n'
    header+='\n'.join('Texture2D '+t+';' for t in textures)+'\n'
    declared=set(re.findall(r'SamplerState\s+(\w+)',code))
    header+='\n'.join('SamplerState '+s+';' for s in samplers if s not in declared)+'\n'
    header+='\n'.join(types.get(v,'float')+' '+v+';' for v in values)+'\n'
    code=code.replace('float4 main(PS_IN pin)','float4 production(PS_IN pin)')
    return header+'float2 gTargetSize;float gViewX;\n'+code+'''
float4 main(float4 pixel:SV_POSITION):SV_TARGET {
    PS_IN pin;pin.PosH=pixel;pin.Tex=pixel.xy/gTargetSize;
    pin.PosC=float3((pin.Tex.x-.5)*.2+gViewX,(.5-pin.Tex.y)*.15,.2);
    pin.NormalW=float3(0,0,-1);return production(pin);
}
'''
report=[]
with tempfile.TemporaryDirectory(prefix='s62_gpu_',dir=OUT) as folder:
    folder=Path(folder);inputs=folder/'textures.bin';params=folder/'params.txt';output=folder/'out.bin'
    def render(name,code,textures,values,size=(128,64)):
        source=wrapped(code);hlsl=folder/(name+'.hlsl');cso=folder/(name+'.cso');hlsl.write_text(source,encoding='utf-8')
        compile=subprocess.run([FXC,'/nologo','/T','ps_5_0','/E','main','/Ges','/WX','/Fo',str(cso),str(hlsl)],capture_output=True,text=True)
        assert compile.returncode==0,compile.stdout+compile.stderr
        with inputs.open('wb') as f:
            f.write(struct.pack('<I',len(textures)))
            for key,a in textures.items():
                b=key.encode();h,w,_=a.shape;f.write(struct.pack('<I',len(b))+b+struct.pack('<4I',w,h,1,1)+a.astype('<f4').tobytes())
        values={**values,'gTargetSize':size}
        params.write_text('\n'.join(k+' '+' '.join(map(str,np.atleast_1d(v))) for k,v in values.items()))
        subprocess.run([str(EXE),str(cso),str(inputs),str(params),str(output),str(size[0]),str(size[1])],check=True,stdout=subprocess.PIPE)
        a=np.frombuffer(output.read_bytes(),'<f4').reshape(size[1],size[0],4)
        assert np.isfinite(a).all(),name
        return a
    # All optical paths use the user's saved extreme settings. A flat normal
    # and zero lens slope must add no fixed dark rectangle at any camera angle.
    code=(ROOT/'shaders/rainVisorLayer.hlsl').read_text(encoding='utf-8')
    empty=np.zeros((4,4,4),np.float32);white=np.ones_like(empty)
    normal=white.copy();normal[:,:,:2]=.5
    textures={name:empty.copy() for name in re.findall(r'\btxLayer\w+',code)}
    y,x=np.mgrid[:64,:128];scene=np.stack((x/128,y/64,(x%16)/16,np.ones_like(x)),axis=-1).astype(np.float32)
    textures.update(txLayerSource=scene,txLayerNormal=normal,txLayerOutline=white)
    values={'gLayerKind':3,'gLayerOptics':1,'gLayerNormalFlipG':1,'gLayerInvShotSize':(1/128,1/64),
     'gLayerCameraSide':(1,0,0),'gLayerCameraUp':(0,1,0),'gLayerCameraLook':(0,0,1),
     'gLayerLightDir':(0,0,-1),'gLayerSun':(1,1,1),'gLayerOpticsBrightness':.75,
     'gLayerOpticsTransmissionLoss':.66,'gLayerOpticsLensGain':6.77,'gLayerOpticsNormal':1.702,
     'gLayerOpticsRimPeak':1,'gLayerOpticsRimSharpness':1.97,'gLayerOpticsRefractionPx':48,
     'gLayerOpticsReflection':1,'gLayerOpticsReflectionPx':84.1,'gLayerBandAlphaMin':.06}
    for view in (0,.13):
        a=render('flat',code,textures,{**values,'gViewX':view})
        assert np.max(abs(a))<2e-5,np.max(abs(a))
        report.append({'case':'flat INT remains neutral with saved brightness/loss','view_x':view,'max_delta':float(np.max(abs(a)))})
    normal[:,:,0]=.65;textures['txLayerNormal']=normal
    images=[render('bevel',code,textures,{**values,'gViewX':view}) for view in (0,.13)]
    difference=float(np.mean(abs(images[0]-images[1])))
    assert difference>1e-4,difference
    report.append({'case':'bevel response changes with viewing angle','mean_change':difference})
    band=np.asarray(Image.open(ROOT/'texture/GLASS/FX/ext_txBand.png'),np.float32)/255
    textures['txLayerDiffuse']=band
    a=render('band',code,textures,{**values,'gLayerKind':1,'gLayerUseDiffuse':1,'gLayerBandOpacity':1,'gLayerGlassAlpha':0},(2048,512))
    opaque=float(np.mean(a[:,:,3]>.5));assert .02<opaque<.25,opaque
    assert np.max(a[band[:,:,3]<.001,3])<1e-6
    report.append({'case':'EXT opaque coverage only inside band, alpha threshold .06','opaque_fraction':opaque})
    micro=metric+inline('                            gMicroGridUV=vec2')
    a=render('micro',micro,geometry,{'gMicroPatternGrid':832,'gMicroGridUV':(832,208),'gMicroSearch':(2,2),
     'gRainMetersPerUnit':.001/.0029296875,'gRainReferencePerMM':.0029296875,'gMicroStrata':1,
     'gMicroPresence':.77,'gMicroFirstPresence':.55,'gMicroRadiusMin':.32,'gMicroRadiusMax':.55,'gMicroRimCells':1.43/12},(640,160))
    interior=a[:,:,3]>.75;gate=(np.floor(a[:,:,2]*255+.5)//16+.5)/16
    active=interior&(gate<=.6);fraction=float(np.mean(active));assert fraction>.005,fraction
    report.append({'case':'production micro bake has active interiors at 60% rain','active_fraction':fraction})
    states=np.zeros((1,4096,4),np.float32)
    sites=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/spawn_sites.dds').read_bytes(),'<f4',offset=148).reshape(1,8192,4)
    states[:,:,:2]=sites[:,:4096,:2];states[:,:,1]-=1;states[:,:,2]=-.4;states[:,:,3]=1.7
    frames=render('metric',metric+inline('rainDynamicSceneCopyState.gpuMetricShader ='),{**geometry,'txRainState':states},
                  {'gCount':4096,'gRainMetersPerUnit':.001/.0029296875,'gRainReferencePerMM':.0029296875},(4096,1))
    assert np.all(frames[:,:,3]>.5) and np.all(frames[:,:,0]>0) and np.all(frames[:,:,2]>0)
    report.append({'case':'4096 GPU per-drop physical frames valid','records':4096})
    readback=inline('local RAIN_DYNAMIC_STATE_READBACK_HLSL =')
    a=render('readback',readback,{'txRainState':states,'txRainStateMeta':np.zeros_like(states)},
             {'gRainStateCount':4096,'gRainReadbackWidth':4096,'gRainReadbackHeight':6,'gRainStateVelocityEncodeRange':.125},(4096,6))
    assert np.all((a[2:4,:,0]>0)&(a[2:4,:,0]<1))
    q=a[2:4,:,0]*2-1;decoded=.125*q/np.maximum(1-abs(q),1e-7)
    assert np.allclose(decoded[0],-.4,atol=1e-5) and np.allclose(decoded[1],1.7,atol=1e-5),(decoded[:,0],a[2:4,0,0])
    report.append({'case':'signed actual UV velocities survive .125 legacy range inside SDK 0..1 encoding','u':float(decoded[0,0]),'v':float(decoded[1,0])})
    drop=(ROOT/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8')
    point=drop[drop.index('float4 rainMicroPoint('):drop.index('// (Declared before its first use')]
    point+='\nfloat4 main(PS_IN pin){return rainMicroPoint(pin.Tex);}\n'
    a=render('pending',point,{'txDynamicMicroPattern':white},{'gDynamicDropMicroPatternEnabled':0})
    assert np.max(abs(a))==0
    report.append({'case':'pending/unbound micro texture cannot make a visor-wide lens','maximum':float(np.max(abs(a)))})
(OUT/'output_gpu_checks.json').write_text(json.dumps(report,indent=2))
print('PASS: D3D11 WARP flat INT neutrality, view-dependent bevel, transparent EXT, active micro at 60%, GPU metric and unclipped signed readback')
