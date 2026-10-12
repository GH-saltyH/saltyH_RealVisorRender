"""Build visor material candidates and execute the actual local CSP shader on WARP.

The controlled UV/cylinder fixture is not an in-game screenshot or a KN5 test.
All original textures, models and runtime settings remain untouched.
"""
from pathlib import Path
import hashlib
import json
import struct
import subprocess
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'ModelWorks/_2_blender_f1-helmet-lando_2025championWinner/texture/리뉴얼'
OUT = SOURCE / 'native_multimap_test_v1'
QA = ROOT / 'docs/diagnostics/2026-10-11/native-visor-material'
FXC = 'C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe'
VC = Path('C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Auxiliary/Build/vcvars64.bat')
PROFILE = dict(ksAmbient=.5, ksDiffuse=.5, ksSpecular=1, ksSpecularEXP=255,
               ksEmissive=0, ksAlphaRef=0, fresnelC=.08, fresnelEXP=5,
               fresnelMaxLevel=.5, isAdditive=0, useDetail=0,
               detailUVMultiplier=1, nmObjectSpace=0, emAlphaFromDiffuse=-1,
               emSkipDiffuseMap=0, emChannelsMode=0, extColoredReflection=0,
               extColoredReflectionNorm=0, shadowBiasMult=0)
PROFILE_GAMMA = PROFILE | {'ksAmbient':.25,'ksDiffuse':.25,
                          'fresnelC':float(np.sqrt(.08)), 'fresnelMaxLevel':float(np.sqrt(.5)),
                          'fresnelEXP':5/2.2}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def resize_float(a, size):
    return np.stack([np.asarray(Image.fromarray(a[..., c]).resize(size, Image.Resampling.BOX))
                     for c in range(a.shape[-1])], axis=-1)


def mips(rgba, kind='data'):
    a = rgba.astype(np.float32)/255
    levels = [a]
    while max(a.shape[:2]) > 1:
        size = (max(1, a.shape[1]//2), max(1, a.shape[0]//2))
        if kind == 'color':
            # Work in sRGB as the legacy fixture does, but avoid black alpha fringes.
            premul = np.concatenate((a[..., :3]*a[..., 3:4], a[..., 3:4]), -1)
            small = resize_float(premul, size)
            a = np.concatenate((small[..., :3]/np.maximum(small[..., 3:4], 1e-8), small[..., 3:4]), -1)
        elif kind == 'normal':
            n = a[..., :3]*2-1
            small = resize_float(np.concatenate((n, a[..., 3:4]), -1), size)
            n = small[..., :3]/np.maximum(np.linalg.norm(small[..., :3], axis=-1, keepdims=True), 1e-8)
            a = np.concatenate((n*.5+.5, small[..., 3:4]), -1)
        else:
            a = resize_float(a, size)
        # GPU validation samples the identical quantized mip payload exported to DDS.
        a = np.rint(np.clip(a, 0, 1)*255).astype(np.float32)/255
        levels.append(a)
    return levels


def export(name, rgba, kind='data'):
    if '--gpu-only' in sys.argv and (OUT/(name+'.png')).exists():
        return mips(np.asarray(Image.open(OUT/(name+'.png')).convert('RGBA')),kind)
    Image.fromarray(rgba).save(OUT / (name+'.png'))
    levels = mips(rgba, kind)
    h, w = rgba.shape[:2]
    header = [124, 0x2100F, h, w, w*4, 0, len(levels)]+[0]*11
    header += [32, 0x41, 0, 32, 0xff, 0xff00, 0xff0000, 0xff000000]
    header += [0x401008, 0, 0, 0, 0]
    path = OUT / (name+'.dds')
    path.write_bytes(b'DDS '+struct.pack('<31I', *header)+b''.join(
        np.rint(v*255).astype(np.uint8).tobytes() for v in levels))
    assert np.array_equal(np.asarray(Image.open(path)), rgba)
    assert len(levels) == 13 and levels[-1].shape == (1, 1, 4)
    return levels


def pad(a, valid, iterations=16):
    if '--gpu-only' in sys.argv:
        return a
    a = a.copy(); known = valid.copy()
    for _ in range(iterations):
        total = np.zeros_like(a); count = np.zeros(valid.shape, np.float32)
        for dy, dx in [(0,1),(0,-1),(1,0),(-1,0)]:
            k = np.roll(known, (dy,dx), (0,1)); v = np.roll(a, (dy,dx), (0,1))
            if dy == 1: k[0] = False
            if dy == -1: k[-1] = False
            if dx == 1: k[:,0] = False
            if dx == -1: k[:,-1] = False
            total += v*k[...,None]; count += k
        new = ~known & (count>0)
        a[new] = total[new]/count[new,None]; known |= new
    return a


def native_ini(name, profile=PROFILE, suffix=''):
    lines = ['; MATERIAL_0 is a placeholder: use the actual EXT material index.',
             '; Do not apply this to the currently hidden native mesh while a custom overlay is active.',
             '[MATERIAL_0]', 'NAME=mtGLASS_EXT_NATIVE_TEST',
             'SHADER=ksPerPixelMultiMap_emissive', 'ALPHABLEND=1', 'ALPHATEST=0',
             'DEPTHMODE=1', f'VARCOUNT={len(profile)}']
    for i, (key,value) in enumerate(profile.items()):
        lines += [f'VAR_{i}_NAME={key}',f'VAR_{i}_FLOAT1={value}',f'VAR_{i}_FLOAT2=0,0',
                  f'VAR_{i}_FLOAT3=0,0,0',f'VAR_{i}_FLOAT4=0,0,0,0']
    textures = [('txDiffuse',f'EXT_{name}_diffuse.dds'),('txNormal','EXT_normal.dds'),
                ('txMaps',f'EXT_{name}_maps.dds'),('txDetail','neutral_white.dds'),
                ('txEmissive','neutral_black.dds')]
    lines += ['RESCOUNT=5']
    for i,(key,value) in enumerate(textures):
        lines += [f'RES_{i}_NAME={key}',f'RES_{i}_SLOT={i}',f'RES_{i}_TEXTURE={value}']
    (OUT / f'material_{name}{suffix}.ini').write_text('\n'.join(lines)+'\n',encoding='utf-8')


def compile_shader(text, name):
    path=QA/(name+'.hlsl'); path.write_text(text, encoding='utf-8')
    target=path.with_suffix('.cso')
    args=[FXC,'/nologo','/T','ps_5_0','/E','main','/Fo',str(target)]
    for folder in ['recreated','custom','custom_objects/common']:
        args += ['/I',str(ROOT/'acc-shaders-master'/folder)]
    result=subprocess.run(args+[str(path)],capture_output=True,text=True)
    (QA/(name+'_compile.log')).write_text(result.stdout+result.stderr,encoding='utf-8')
    if result.returncode: raise RuntimeError(result.stdout+result.stderr)
    return target


HEADER = '''#define TARGET_PS 1
#define MODE_MAIN_NOFX 1
#define OBJECT_SHADER 1
#define NO_FOG 1
#define main nativeMaterialMain
#include "ksPerPixelMultiMap_emissive_ps.fx"
#undef main
cbuffer Fixture : register(b12) {float2 fixtureSize; float fixtureAngle; float fixtureProbe; float2 fixtureUV;};
float4 main(float4 position:SV_POSITION):SV_TARGET {
 PS_IN_NmExtra4 pin=(PS_IN_NmExtra4)0;
 pin.PosH=position;
 float2 uv=fixtureProbe>0 ? fixtureUV : position.xy/fixtureSize;
 pin.Tex=uv; pin.Extra=float4(1,0,0,0); pin.Ao=1;
 pin.ShadowTex0=float4(0,0,0,1);
 float angle=fixtureProbe>0 ? fixtureAngle : (uv.x-.5)*1.9+fixtureAngle;
 pin.NormalW=float3(sin(angle),0,cos(angle));
 pin.TangentW=float3(cos(angle),0,-sin(angle)); pin.BitangentW=float3(0,1,0);
 pin.PosC=float3(0,0,-1);
 PS_OUT result=nativeMaterialMain(pin); return result.result;
}
'''


def cube():
    # Artificial studio environment. Each face follows D3D cube orientation.
    s=256; y,x=np.mgrid[:s,:s].astype(np.float32); u=2*(x+.5)/s-1; v=2*(y+.5)/s-1
    directions=[(np.ones_like(u),-v,-u),(-np.ones_like(u),-v,u),
                (u,np.ones_like(u),v),(u,-np.ones_like(u),-v),
                (u,-v,np.ones_like(u)),(-u,-v,-np.ones_like(u))]
    result=[]
    for components in directions:
        n=np.stack(components,-1); n/=np.linalg.norm(n,axis=-1,keepdims=True)
        softbox=np.exp(-((n[...,0]-.23-.30*n[...,1])/.032)**8)*np.exp(-(n[...,1]/.7)**8)*(n[...,2]>.1)
        rgb=(.025+.1*np.maximum(n[...,1],0))[...,None]*np.array([.85,.94,1.05])+softbox[...,None]*10
        a=np.concatenate((rgb,np.ones((*rgb.shape[:2],1))),-1).astype(np.float32)
        levels=[a]
        while max(a.shape[:2])>1:
            a=resize_float(a,(max(1,a.shape[1]//2),max(1,a.shape[0]//2))); levels.append(a)
        result.append(levels)
    return result


def texture_input(path, textures):
    with path.open('wb') as f:
        f.write(struct.pack('<I',len(textures)))
        for name,faces in textures.items():
            name=name.encode(); f.write(struct.pack('<I',len(name))+name)
            h,w=faces[0][0].shape[:2]
            f.write(struct.pack('<4I',w,h,len(faces[0]),len(faces)))
            for levels in faces:
                for a in levels:f.write(a.astype('<f4').tobytes())


def main():
    OUT.mkdir(exist_ok=True); QA.mkdir(parents=True,exist_ok=True)
    names=['GLOSS','ROUGH','txDetail','txDiff','txNormal']
    source={name:np.asarray(Image.open(SOURCE/f'GLASS_EXT_{name}.png').convert('RGBA')) for name in names}
    before={name:sha(SOURCE/f'GLASS_EXT_{name}.png') for name in names}
    manifest_path=OUT/'asset_manifest.json'
    if '--gpu-only' in sys.argv and manifest_path.exists():
        assert json.loads(manifest_path.read_text(encoding='utf-8'))['sources']==before, 'Source changed: rebuild assets first'
    assert all(a.shape==(1024,4096,4) for a in source.values())
    coverage=source['txDiff'][...,3].astype(np.float32)/255
    valid=coverage>.99
    alpha_differences={name:int(np.count_nonzero(a[...,3]!=source['txDiff'][...,3])) for name,a in source.items()}
    assert all(alpha_differences[name]==0 for name in names if name!='txNormal')
    channels={name:{'sha256':before[name],'rgba_ranges':[[int(a[...,c].min()),int(a[...,c].max())] for c in range(4)],
                    'alpha_at_fully_covered_pixels':np.unique(a[valid,3]).tolist()} for name,a in source.items()}
    # Observed masks: zero RGB inside the silhouette coincides with sponsor strip;
    # full-brightness patches in the mottled scalar field coincide with stickers.
    strip=np.clip(1-source['GLOSS'][...,0].astype(np.float32)/253,0,1)*coverage
    detail=source['txDetail'][...,0].astype(np.float32)/np.maximum(coverage,1e-6)
    sticker=np.clip((detail-235)/18,0,1)*coverage
    opaque=np.maximum(strip,sticker)
    glass=valid & (opaque<.05)
    low,high=np.percentile(detail[glass],[5,95])
    scuff=np.clip((detail-low)/(high-low),0,1)
    rough=source['ROUGH'][...,0].astype(np.float32)/np.maximum(coverage,1e-6)/255
    correlation=float(np.corrcoef(detail[glass],source['txDiff'][glass,0])[0,1])
    rgb=source['txDiff'][...,:3].astype(np.float32)/np.maximum(coverage[...,None],1e-6)
    normal_coverage=source['txNormal'][...,3].astype(np.float32)/255
    normal=source['txNormal'][...,:3].astype(np.float32)/np.maximum(normal_coverage[...,None],1e-6)
    normal=pad(normal,valid); normal[~(np.linalg.norm(normal,axis=-1)>0)]=[128,128,255]
    n=normal/255*2-1;n/=np.maximum(np.linalg.norm(n,axis=-1,keepdims=True),1e-8)
    normal=np.uint8(np.clip(np.rint(np.concatenate(((n*.5+.5)*255,coverage[...,None]*255),-1)),0,255))
    normal_levels=export('EXT_normal',normal,'normal')
    white=np.full((4,4,4),255,np.uint8); black=white.copy();black[...,:3]=0
    Image.fromarray(white).save(OUT/'neutral_white.png');Image.fromarray(black).save(OUT/'neutral_black.png')
    # Small neutral maps still have legal complete DDS mip chains.
    for filename,pixels in [('neutral_white',white),('neutral_black',black)]:
        levels=mips(pixels);h,w=pixels.shape[:2]
        hdr=[124,0x2100f,h,w,w*4,0,len(levels)]+[0]*11+[32,0x41,0,32,255,65280,16711680,4278190080]+[0x401008,0,0,0,0]
        (OUT/(filename+'.dds')).write_bytes(b'DDS '+struct.pack('<31I',*hdr)+b''.join(np.rint(a*255).astype('u1').tobytes() for a in levels))
    variants={}; statistics={}
    for name,base,cloud,rough_base,rough_cloud in [('clear',.035,.05,.08,.14),('balanced',.09,.12,.12,.24),('worn',.15,.20,.18,.34)]:
        alpha=coverage*(base+cloud*scuff)*(1-opaque)+opaque
        tint=np.array([18,20,21],np.float32)+scuff[...,None]*22
        color=rgb*opaque[...,None]+tint*(1-opaque[...,None])
        color=pad(color,valid)
        diffuse=np.uint8(np.clip(np.rint(np.concatenate((color,alpha[...,None]*255),-1)),0,255))
        r=rough_base+rough_cloud*scuff
        r=r*(1-opaque)+np.clip(.32+.46*rough,0,1)*opaque
        # Artist-controlled legacy exponent, not a PBR roughness conversion.
        gloss=(1-r)**2
        spec=(.75-.25*scuff)*(1-opaque)+.12*opaque
        reflection=(.96-.12*scuff)*(1-opaque)+.13*opaque
        maps_rgb=pad(np.stack((spec,gloss,reflection),-1)*255,valid)
        maps=np.uint8(np.clip(np.rint(np.concatenate((maps_rgb,np.full((*coverage.shape,1),255)),-1)),0,255))
        variants[name]={'txDiffuse':[export(f'EXT_{name}_diffuse',diffuse,'color')],
                        'txNormal':[normal_levels],'txMaps':[export(f'EXT_{name}_maps',maps)],
                        'txDetail':[[white.astype(np.float32)/255]],'txEmissive':[[black.astype(np.float32)/255]]}
        native_ini(name)
        native_ini(name,PROFILE_GAMMA,'_gamma')
        statistics[name]={'glass_alpha_range':[float(alpha[glass].min()),float(alpha[glass].max())],
                          'opaque_sticker_alpha':float(alpha[opaque>.99].min()),
                          'glass_maps_median':np.median(maps[glass,:3],axis=0).tolist()}
    Image.fromarray(np.uint8(np.stack((opaque,scuff,rough),-1)*255)).save(QA/'pattern_roles.png')
    manifest_path.write_text(json.dumps({'sources':before,'files':{p.name:sha(p) for p in OUT.glob('*.dds')}},indent=2),encoding='utf-8')
    shader=compile_shader(HEADER,'native_fixture')
    exe=QA/'native_readback.exe'
    build=f'"{VC}" && cl /nologo /EHsc /std:c++17 "{ROOT / "docs/tools/native_visor_material_readback.cpp"}" /Fo"{QA / "native_readback.obj"}" /Fe"{exe}" /link d3d11.lib d3dcompiler.lib dxguid.lib'
    result=subprocess.run(build,shell=True,cwd=QA,capture_output=True,text=True,errors='replace')
    (QA/'cpp_compile.log').write_text(result.stdout+result.stderr,encoding='utf-8')
    if result.returncode:raise RuntimeError(result.stdout+result.stderr)
    constants=dict(PROFILE,fixtureSize=[1024,256],fixtureAngle=0,fixtureProbe=0,
                   ksLightDirection=[0,0,-1,0],ksLightColor=[1,1,1,1],extSpecularColor=[1,1,1],
                   ksAmbientColor_sky0=[.7,.7,.7,1],ksHorizonColor=[.5,.5,.5,1],ksZenithColor=[.7,.7,.7,1],
                   perObjAmbientMultiplier=1,extLambertGamma_inner=1,extVAOExp=1,extFresnelGamma=1,
                   extSunSpecularMult=1,extReflectionBrightness=1,extReflectionBrightnessMult=1,
                   ksExposure=1,extEmissiveMults=[1,1,1,3],extIBLAmbientBaseThreshold=1,
                   extScreenSize=[1024,256,1/1024,1/256],extMSAA=1,extClearCoat=0,
                   extShaderFlags=0,ksNearPlane=.01,extFlags=0,extVaoMode=0)
    env=cube()
    def run(label,textures,changes=None,w=1024,h=256):
        params=constants | (changes or {}) | {'fixtureSize':[w,h]}
        parameter_file=QA/(label+'.params')
        parameter_file.write_text('\n'.join(k+' '+' '.join(str(v) for v in (a if isinstance(a,list) else [a])) for k,a in params.items()))
        inp=QA/(label+'.input');texture_input(inp,textures | {'txCube':env})
        dst=QA/(label+'.rgba32f')
        result=subprocess.run([str(exe),str(shader),str(inp),str(parameter_file),str(dst),str(w),str(h)],capture_output=True,text=True)
        if result.returncode:raise RuntimeError(result.stdout+result.stderr)
        a=np.fromfile(dst,'<f4').reshape(h,w,4)
        assert np.isfinite(a).all(),label
        inp.unlink()  # Large duplicate fixture buffers are reproducible from DDS.
        return a
    renders={name:run(name,tex) for name,tex in variants.items()}
    raw={key:[[source[name].astype(np.float32)/255]] for key,name in [('txDiffuse','txDiff'),('txNormal','txNormal'),('txDetail','txDetail')]}
    raw['txMaps']=variants['balanced']['txMaps'];raw['txEmissive']=[[black.astype(np.float32)/255]]
    renders['raw_alpha']=run('raw_alpha',raw,{'useDetail':1,'emAlphaFromDiffuse':1})
    renders['detail_connected']=run('detail_connected',variants['balanced'] | {'txDetail':raw['txDetail']},{'useDetail':1})
    renders['alpha_fixed']=run('alpha_fixed',variants['balanced'],{'emAlphaFromDiffuse':1})
    # Probe control constants against actual GPU outputs at a flat glass texel.
    probes={}
    for label,changes in [('glass',{}),('no_reflection',{'fresnelC':0,'fresnelMaxLevel':0}),
                          ('grazing',{'fixtureAngle':1.2}),('night_no_light',{'ksLightColor':[0,0,0,0],'extSpecularColor':[0,0,0],'ksAmbientColor_sky0':[0,0,0,0]}),
                          ('alpha_fixed',{'emAlphaFromDiffuse':1}),('default_alpha',{'emAlphaFromDiffuse':0}),
                          ('strip',{'fixtureUV':[.5,.15]})]:
        probes[label]=run('probe_'+label,variants['balanced'],{'fixtureProbe':1,'fixtureUV':[.5,.55]} | changes,w=1,h=1)[0,0].tolist()
    assert probes['glass'][3] < .5 and probes['strip'][3] > .99
    assert probes['grazing'][3] > probes['glass'][3]
    assert probes['default_alpha'][3] > .99
    # Dark field and black emissive must not glow: explicitly remove environment too.
    dark=dict(variants['balanced']); zero_env=[[np.zeros((1,1,4),np.float32)]]*6
    saved_env=env;env=zero_env
    probes['black_scene']=run('probe_black_scene',dark,{'fixtureProbe':1,'fixtureUV':[.5,.55],
                             'ksLightColor':[0,0,0,0],'extSpecularColor':[0,0,0],
                             'ksAmbientColor_sky0':[0,0,0,0]},w=1,h=1)[0,0].tolist()
    env=saved_env
    assert max(abs(v) for v in probes['black_scene'][:3]) < 1e-6
    channel_probes={}
    for label,value,angle in [('R0',[0,.5,0,1],0),('R1',[1,.5,0,1],0),
                              ('G_low',[1,.05,0,1],.25),('G_high',[1,1,0,1],.25),
                              ('B0',[0,.8,0,1],0),('B1',[0,.8,1,1],0)]:
        tex=variants['balanced'] | {'txMaps':[[np.array(value,np.float32).reshape(1,1,4)]]}
        changes={'fixtureProbe':1,'fixtureUV':[.5,.55],'fixtureAngle':angle,
                 'ksAmbient':0,'ksDiffuse':0}
        if label[0]!='B':changes |= {'fresnelC':0,'fresnelMaxLevel':0}
        channel_probes[label]=run('probe_'+label,tex,changes,w=1,h=1)[0,0].tolist()
    assert channel_probes['R1'][0] > channel_probes['R0'][0]+.1
    assert channel_probes['G_low'][0] > channel_probes['G_high'][0]+.01
    assert channel_probes['B1'][0] > channel_probes['B0'][0]+.001
    legacy_shader=shader
    shader=compile_shader('#define GAMMA_FIX 1\n'+HEADER,'native_fixture_gamma')
    renders['balanced_gamma']=run('balanced_gamma',variants['balanced'],PROFILE_GAMMA)
    gamma_glass=run('probe_gamma_glass',variants['balanced'],PROFILE_GAMMA | {'fixtureProbe':1,'fixtureUV':[.5,.55]},w=1,h=1)[0,0].tolist()
    gamma_grazing=run('probe_gamma_grazing',variants['balanced'],PROFILE_GAMMA | {'fixtureProbe':1,'fixtureUV':[.5,.55],'fixtureAngle':1.2},w=1,h=1)[0,0].tolist()
    assert 0 < gamma_glass[3] < .5
    assert abs(gamma_grazing[3]-probes['grazing'][3]) < 1e-5
    shader=legacy_shader
    # Background checker stands for geometry behind glass, not copied reference pixels.
    h,w=256,1024;y,x=np.mgrid[:h,:w]; checker=((x//40+y//32)%2)[...,None]
    background=np.array([.09,.13,.16])+checker*np.array([.13,.14,.12])
    board=Image.new('RGB',(1024,len(renders)*292),(20,22,26));draw=ImageDraw.Draw(board)
    silhouette=np.asarray(Image.fromarray(source['txDiff'][...,3]).resize((w,h),Image.Resampling.BOX),np.float32)/255
    for i,(name,a) in enumerate(renders.items()):
        opacity=a[...,3:4]*silhouette[...,None]
        bg=background**2.2 if name.endswith('_gamma') else background
        composite=a[...,:3]*opacity+bg*(1-opacity)
        # Native legacy output uses its original color space. Gamma-fix is linear.
        display=np.clip(composite,0,1)**(1/2.2 if name.endswith('_gamma') else 1)
        im=Image.fromarray(np.uint8(np.rint(display*255)))
        im.save(QA/(name+'_preview.png'));board.paste(im,(0,i*292+32));draw.text((10,i*292+9),name,fill='white')
    board.save(QA/'comparison.png')
    assert before == {name:sha(SOURCE/f'GLASS_EXT_{name}.png') for name in names}
    report={'scope':'Actual local CSP main shader, artificial cylinder/UV inputs and studio cube; no game/KN5/DLSS validation',
            'source_channels':channels,'alpha_differences_vs_diffuse':alpha_differences,'originals_unchanged':True,
            'detail_diffuse_glass_correlation':correlation,'scalar_glass_p5_p95':[float(low),float(high)],
            'profile':PROFILE,'gamma_fix_profile':PROFILE_GAMMA,'variants':statistics,'gpu_probes':probes,
            'txMaps_isolation_gpu_probes':channel_probes,'gamma_fix_glass_gpu':gamma_glass,
            'gamma_fix_grazing_gpu':gamma_grazing,
            'shader_sha256':sha(ROOT/'acc-shaders-master/recreated/ksPerPixelMultiMap_emissive_ps.fx'),
            'renderer':'D3D11 WARP / ps_5_0 / MODE_MAIN_NOFX / NO_FOG / no game resources',
            'dds':'RGBA8 UNORM, full 13 mips for 4096x1024, normal mip renormalization, color alpha-weighted mip filtering'}
    (QA/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'output':str(OUT),'comparison':str(QA/'comparison.png'),'gpu_probes':probes},indent=2))


if __name__=='__main__':main()
