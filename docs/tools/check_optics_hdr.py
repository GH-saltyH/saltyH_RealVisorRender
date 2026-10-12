"""Run production optics pixel shaders on D3D11 WARP, read float HDR outputs.

Requires Visual Studio 2022 C++ tools and the Windows SDK. These fixtures test
energy/routing; CSP exposure, real KN5 visibility and game appearance remain
integration checks.
"""
from pathlib import Path
import re, subprocess, tempfile, struct
import numpy as np

root=Path(__file__).resolve().parents[2]
code=(root/'shaders/rainVisorOptics.hlsl').read_text().replace('main(PS_IN pin)','main(PS_IN pin):SV_TARGET')
bright_code=(root/'shaders/visorOpticsBright.hlsl').read_text().replace('main(PS_IN pin)','main(PS_IN pin):SV_TARGET')
values=sorted(set(re.findall(r'\bgOpt\w+',code+bright_code)))
types={}
for name in ['Pose','PoseInverse','BakePose','BakeView','BakeProjection','BakePoseInverse','BakeViewInverse','BakeProjectionInverse','SourceView','SourceProjection']:types['gOpt'+name]='float4x4'
for name in ['Sun','Tint','Sky','Horizon','LocalLight','Eye','EyeLocal','BakeEye','LightWorld','CameraSide','CameraUp','SourceOriginLocal','OpeningLocal','WorldUpLocal']:types['gOpt'+name]='float3'
for name in ['InvTarget','EyeDeltaProjection','ProjectionScale','BrightInvSource','NativePixelScale']:types['gOpt'+name]='float2'
identity='float4x4(1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1)'
defaults={'gOptSun':'float3(100,100,100)','gOptTint':'float3(1,1,1)',
          'gOptSky':'float3(1,1,1)','gOptHorizon':'float3(1,1,1)',
          'gOptLocalLight':'float3(0,0,1)','gOptLightWorld':'float3(0,0,1)',
          'gOptCameraSide':'float3(1,0,0)','gOptCameraUp':'float3(0,1,0)',
          'gOptInvTarget':'float2(1,1)','gOptBakeScale':'1','gOptBounce':'.2',
          'gOptBounceBase':'.25','gOptReflectionGain':'1','gOptAmbientAO':'1',
          'gOptEffectGain':'1','gOptDebugGain':'1',
          'gOptOpeningLocal':'float3(0,0,1)','gOptWorldUpLocal':'float3(0,1,0)',
          'gOptOpeningCosLo':'-.05','gOptOpeningCosHi':'.35'}
textures={'txOptHit':(0,0,0,1),'txOptMaterial':(.5,.25,.1,.2),'txOptSurface':(0,0,1,0),
          'txOptSunVisibility':(1,1,1,1),'txOptScene':(100,100,100,1),
          'txOptRadiance':(20,10,5,1),'txOptGlass':(0,0,1,1),'txOptBright':(100,100,100,0),
          'txOptSH':(.8862269,0,0,-.51166335)}
fixtures=[('indirect shaded with open hemisphere',1,{}, {},(.625,.3125,.125,1)),
          ('external shade',1,{}, {'txOptSunVisibility':(0,0,0,1)},(0,0,0,1)),
          ('open aperture',1,{}, {'txOptSH':(3.5449077,0,0,0)},(60,30,12,1)),
          ('HDR diagnostic white',0,{'gOptDebug':'8'}, {},(100,100,100,1)),
          ('HDR radiance',0,{'gOptDebug':'10','gOptInteriorReady':'1','gOptTier':'1'}, {},(20,10,5,1)),
          ('HDR reflection',0,{'gOptDebug':'12','gOptInteriorReady':'1','gOptTier':'1'}, {},(.8,.4,.2,1)),
          ('additive final',0,{'gOptInteriorReady':'1','gOptTier':'1'}, {},(.8,.4,.2,0))]
# Zero diffuse isolates the authored highlight from ambient/direct/bounce.
spec_samples={'txOptSurface':(0,0,1,.5),'txOptMaterial':(0,0,0,.2),'txOptSH':(3.5449077,0,0,0)}
fixtures += [
    ('material specular light colour',1,{'gOptSun':'float3(100,50,10)'},spec_samples,(50,25,5,1)),
    ('material specular external shadow',1,{},dict(spec_samples,txOptSunVisibility=(0,0,0,1)),(0,0,0,1)),
    ('material specular aperture shadow',1,{},dict(spec_samples,txOptSH=(0,0,0,0)),(0,0,0,1)),
    ('rough material highlight',1,{'gOptLocalLight':'float3(.8660254038,0,.5)'},
     dict(spec_samples,txOptMaterial=(0,0,0,np.sqrt(.2))), (25*.75**4,)*3+(1,)),
    ('glossy material highlight',1,{'gOptLocalLight':'float3(.8660254038,0,.5)'},
     spec_samples,(25*.75**24,)*3+(1,)),
    ('hit-to-visor view direction',1,{},dict(spec_samples,txOptHit=(-1,0,0,1),txOptMaterial=(0,0,0,np.sqrt(.2))),
     (50*((1+1/np.sqrt(2))/2)**4,)*3+(1,)),
    ('canonical eye and rotation',1,{'gOptEyeLocal':'float3(1,0,1)',
      'gOptBakePoseInverse':'float4x4(0,0,1,0,0,1,0,0,-1,0,0,0,2000,100,1500,1)'},
     spec_samples,(50,50,50,1)),
    ('opposing light finite',1,{'gOptLocalLight':'float3(0,0,-1)'},spec_samples,(0,0,0,1)),
    ('specular additive reflection',0,{'gOptInteriorReady':'1','gOptTier':'1'},
     {'txOptRadiance':(50,25,5,1)},(2,1,.2,0)),
]
lamp=np.array([200.,100.,50.]);lamp_lum=lamp@np.array([.2126,.7152,.0722])
fixtures += [
    ('uniform bright sky rejected before blur',2,{'gOptBrightRelative':'4','gOptBrightThreshold':'1'},
     {'txOptAverage':(100,100,100,1)},(0,0,0,0)),
    ('local lamp excess energy and hue preserved',2,{'gOptBrightRelative':'4','gOptBrightThreshold':'1'},
     {'txOptScene':(*lamp,1),'txOptAverage':(10,10,10,1)},(*tuple(lamp*(1-40/lamp_lum)),0)),
    ('black source finite',2,{'gOptBrightRelative':'4'},
     {'txOptScene':(0,0,0,1),'txOptAverage':(0,0,0,1)},(0,0,0,0)),
]
# Lighting alpha is native-source coverage, independent of HDR energy.
fixtures=[(name,lighting,overrides,samples,(*expected[:3],0) if lighting else expected)
          for name,lighting,overrides,samples,expected in fixtures]
native={'txOptNative':(.2,3,1,1),'txOptNativeDepth':(0,1,0,1),'txOptSunVisibility':(0,0,0,1),
        'txOptScene':(0,0,0,1)}
fixtures += [
    ('night local light independent of sun and frame mean',1,{'gOptNativeReady':'1','gOptSun':'float3(0,0,0)'},native,(.2,3,1,1)),
    ('black native source cannot erase analytic image',1,{'gOptNativeReady':'1'},
     {'txOptNative':(0,0,0,1),'txOptNativeDepth':(0,1,0,1)},(.625,.3125,.125,1)),
    ('native supplements weaker analytic light per channel',1,{'gOptNativeReady':'1'},
     {'txOptNative':(1,3,1,1),'txOptNativeDepth':(0,1,0,1)},(1,3,1,1)),
    ('track translation cannot change native depth acceptance',1,{'gOptNativeReady':'1','gOptSun':'float3(0,0,0)',
      'gOptPose':'float4x4(1,0,0,0,0,1,0,0,0,0,1,0,12000,100,15000,1)'},native,(.2,3,1,1)),
    ('native depth boundary fades light confidence',1,{'gOptNativeReady':'1','gOptSun':'float3(0,0,0)'},
     dict(native,txOptNativeDepth=(.00075,1,0,1)),(.1,1.5,.5,.5)),
    ('native camera frustum edge leaves analytic image intact',1,{'gOptNativeReady':'1','gOptSourceOriginLocal':'float3(1,0,0)'},
     {'txOptNative':(100,100,100,1),'txOptNativeDepth':(0,1,0,1)},(.625,.3125,.125,0)),
    ('native depth mismatch rejects foreground colour',1,{'gOptNativeReady':'1','gOptSun':'float3(0,0,0)'},
     dict(native,txOptNativeDepth=(.03,1,0,1)),(0,0,0,0)),
    ('native wrong material ID rejects colour',1,{'gOptNativeReady':'1','gOptSun':'float3(0,0,0)'},
     dict(native,txOptNativeDepth=(0,4,0,1)),(0,0,0,0)),
    ('mixed native silhouette rejects wrong-ID bilinear colour taps',1,{'gOptNativeReady':'1','gOptSun':'float3(0,0,0)'},
     dict(native,txOptNativeDepth=[[(0,1,0,1),(0,4,0,1)],[(0,1,0,1),(0,4,0,1)]],
          txOptNative=[[ (.2,3,1,1),(100,100,100,1)],[ (.2,3,1,1),(100,100,100,1)]]),(.1,1.5,.5,.5)),
    ('mixed native silhouette rejects nearer foreground depth taps',1,{'gOptNativeReady':'1','gOptSun':'float3(0,0,0)'},
     dict(native,txOptNativeDepth=[[(0,1,0,1),(.03,1,0,1)],[(0,1,0,1),(.03,1,0,1)]],
          txOptNative=[[ (.2,3,1,1),(100,100,100,1)],[ (.2,3,1,1),(100,100,100,1)]]),(.1,1.5,.5,.5)),
    ('ambient fill isolated',1,{'gOptDebug':'15','gOptAmbient':'1'},
     {'txOptAO':(0,0,0,1),'txOptSH':(3.5449077,0,0,0)},(33.75,16.875,6.75,0)),
    ('native coverage diagnostic',0,{'gOptDebug':'14'},{'txOptRadiance':(20,10,5,.5)},(50,50,50,1)),
    ('ambient zero sky chroma still carries night energy',1,{'gOptDebug':'15','gOptAmbient':'1',
      'gOptSky':'float3(0,0,0)','gOptHorizon':'float3(0,0,0)'},
     {'txOptAO':(0,0,0,1),'txOptSH':(3.5449077,0,0,0)},(33.75,16.875,6.75,0)),
    ('ambient unresolved bounce retains AO contrast',1,{'gOptDebug':'15','gOptAmbient':'1','gOptAmbientAO':'.85'},
     {'txOptAO':(0,0,0,0),'txOptSH':(3.5449077,0,0,0)},(5.0625,2.53125,1.0125,0)),
    ('dust isolated same energy as Final',0,{'gOptDebug':'16','gOptDustGain':'.015'},{'txOptMask':(.5,0,0,0)},(.75,.75,.75,1)),
    ('ghosts require tier two',0,{'gOptDebug':'17','gOptTier':'1','gOptGhostGain':'1','gOptGhostThreshold':'1'}, {},(0,0,0,1)),
    ('ghosts isolated same energy as Final',0,{'gOptDebug':'17','gOptTier':'2','gOptGhostGain':'1'}, {},(.16,.16,.16,1)),
    ('scratches isolated same energy as Final',0,{'gOptDebug':'18','gOptTier':'2','gOptScratchGain':'.012'},
     {'txOptMask':(0,.5,0,0)},(.6,.6,.6,1)),
    ('dust over scene preview uses Final additive alpha',0,{'gOptDebug':'16','gOptDebugOverlay':'1','gOptDustGain':'.015'},
     {'txOptMask':(.5,0,0,0)},(.75,.75,.75,0)),
    ('effect gain boosts production and debug together',0,{'gOptTier':'2','gOptGhostGain':'1','gOptEffectGain':'4'}, {},(.64,.64,.64,0)),
    ('dark extracted source gives no false scene ghosts',0,{'gOptTier':'2','gOptGhostGain':'5','gOptDustGain':'.2','gOptScratchGain':'.2'},
     {'txOptBright':(0,0,0,0),'txOptMask':(.5,.5,0,0)},(0,0,0,0)),
    ('defocused fine scratch area energy retained',0,{'gOptTier':'2','gOptScratchGain':'.2','gOptEffectGain':'4'},
     {'txOptMask':(0,.002,0,0)},(.16,.16,.16,0)),
]
fixtures += [
    ('closed visibility has no unconditional ambient or bounce floor',1,{'gOptAmbient':'2','gOptAmbientAO':'0'},
     {'txOptSH':(0,0,0,0)},(0,0,0,0)),
    ('opening away from sun suppresses leaking L1 lobe',1,{'gOptOpeningLocal':'float3(0,0,-1)'},
     {'txOptSH':(3.5449077,0,0,0)},(0,0,0,0)),
    ('opening toward ground cannot borrow bright frame for sky fill',1,
     {'gOptOpeningLocal':'float3(0,-1,0)','gOptLocalLight':'float3(0,1,0)','gOptAmbient':'2','gOptAmbientAO':'0'},
     {'txOptSH':(3.5449077,0,0,0)},(0,0,0,0)),
    ('glare at tier zero responds to zero effect gain',0,
     {'gOptEffectGain':'0','gOptDustGain':'.2','gOptSmudgeGain':'.2','gOptSunDustGain':'.2'},
     {'txOptMask':(.5,.5,0,.5)},(0,0,0,0)),
    ('all gains zero leaves bright base scene untouched at tier two',0,
     {'gOptTier':'2','gOptInteriorReady':'1','gOptReflectionGain':'0','gOptDoubleGain':'0',
      'gOptEffectGain':'0','gOptGhostGain':'5','gOptDustGain':'.2','gOptScratchGain':'.2'},
     {'txOptMask':(.5,.5,0,.5)},(0,0,0,0)),
]
base=Path('C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Auxiliary/Build/vcvars64.bat')
fxc='C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe'
with tempfile.TemporaryDirectory(prefix='optics_hdr_',dir=root/'docs/tools') as tmp:
    tmp=Path(tmp);exe=tmp/'readback.exe'
    build=f'"{base}" && cl /nologo /EHsc /std:c++17 "{root / "docs/tools/optics_shader_readback.cpp"}" /Fo"{tmp / "readback.obj"}" /Fe"{exe}" /link d3d11.lib d3dcompiler.lib'
    subprocess.run(build,shell=True,cwd=tmp,check=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    for name,lighting,overrides,samples,expected in fixtures:
        bindings=['txOptHit','txOptSurface','txOptMaterial','txOptAO','txOptSH','txOptSunVisibility','txOptScene','txOptGlass','txOptNative','txOptNativeDepth'] if lighting else [
            'txOptScene','txOptMask','txOptSunVisibility','txOptBright','txOptHit','txOptSurface','txOptGlass','txOptSH','txOptAO','txOptRadiance','txOptNativeDepth']
        if lighting==2:bindings=['txOptScene','txOptAverage']
        header='#define OPT_LIGHTING '+str(lighting)+'\n'
        header+='struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;};\n'
        header+='SamplerState samPointClamp:register(s0),samLinearClamp:register(s1);\n'
        for key in values:
            typ=types.get(key,'float');value=overrides.get(key,defaults.get(key,identity if typ=='float4x4' else '0'))
            header+=f'static const {typ} {key}={value};\n'
        header+='\n'.join(f'Texture2D {key}:register(t{i});' for i,key in enumerate(bindings))+'\n'
        hlsl=tmp/'fixture.hlsl';cso=tmp/'fixture.cso';data=tmp/'textures.bin'
        hlsl.write_text(header+(bright_code if lighting==2 else code))
        subprocess.run([fxc,'/nologo','/T','ps_5_0','/E','main','/Ges','/WX','/Fo',str(cso),str(hlsl)],check=True,stdout=subprocess.PIPE)
        payload=struct.pack('<I',len(bindings)|0x80000000)
        for key in bindings:
            pixels=np.array(samples.get(key,textures.get(key,(0,0,0,0))),dtype='<f4').reshape(-1,4)
            width=2 if len(pixels)==4 else 1;height=len(pixels)//width
            payload+=struct.pack('<II',width,height)+pixels.tobytes()
        data.write_bytes(payload)
        actual=np.array([float(x) for x in subprocess.check_output([str(exe),str(cso),str(data)],text=True).split()])
        # Empty final contributions discard and preserve the prior target.
        if lighting==0 and tuple(expected)==(0,0,0,0):expected=(1000,1000,1000,1)
        assert np.allclose(actual,expected,atol=1e-4,rtol=1e-5),(name,actual,expected)
        print(f'PASS: D3D11 WARP {name}: {actual.tolist()}')
