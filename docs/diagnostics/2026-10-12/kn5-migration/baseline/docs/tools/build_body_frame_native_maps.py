"""Fixed diffuse/normal helmet shell material candidates, actual local native shaders.
The preview uses an artificial UV cylinder and studio cube, not the helmet mesh.
"""
from pathlib import Path
import json
import shutil
import struct
import subprocess
import zipfile
import numpy as np
from PIL import Image, ImageDraw
import test_visor_native_multimap as native

ROOT=native.ROOT
SOURCE=ROOT/'ModelWorks/_2_blender_f1-helmet-lando_2025championWinner/texture'
COLLECTION=Path('E:/_db_OS_Core/다운로드/LANDO NORRIS 2025 HELMET F1 WORLD CHAMPION/collection')
OUT=SOURCE/'native_body_frame_test_v1'
QA=ROOT/'docs/diagnostics/2026-10-11/native-body-frame'
PROFILE=dict(ksAmbient=.4,ksDiffuse=.6,ksSpecular=.65,ksSpecularEXP=255,
             ksEmissive=[0,0,0],ksAlphaRef=0,fresnelC=.08,fresnelEXP=5,
             fresnelMaxLevel=.85,isAdditive=0,useDetail=0,detailUVMultiplier=1,
             nmObjectSpace=0,extColoredReflection=2,extColoredReflectionNorm=0,
             shadowBiasMult=0)
GAMMA=PROFILE | dict(ksAmbient=.25,ksDiffuse=.6,fresnelC=float(np.sqrt(.08)),
                      fresnelEXP=5/2.2,fresnelMaxLevel=float(np.sqrt(.85)))
PBR=PROFILE | dict(ksDiffuse=1,ksAmbient=1,extColoredReflection=0,
                  pbOcclusion=[0,1],pbSmoothness=[0,1],pbMetalness=[0,1],
                  pbReflectance=[.04,.04],pbColorSource=0,pbOcclusionSource=2,
                  pbOcclusionMult=1,pbReflectionBlurEnv=0,extStickersMode_uint=0,
                  pbClearCoatSmoothness=[.82,.96],pbClearCoatIntensity=0,
                  pbClearCoatF0=.04,pbClearCoatNormalShare=0)
CLEARCOAT=PBR | dict(pbClearCoatSmoothness=[.82,.96],pbClearCoatIntensity=.25,
                     pbClearCoatF0=.04,pbClearCoatNormalShare=0)


def export(name, pixels):
    Image.fromarray(pixels).save(OUT/(name+'.png'))
    levels=native.mips(pixels)
    h,w=pixels.shape[:2]
    hdr=[124,0x2100f,h,w,w*4,0,len(levels)]+[0]*11+[32,0x41,0,32,255,65280,16711680,4278190080]+[0x401008,0,0,0,0]
    target=OUT/(name+'.dds')
    target.write_bytes(b'DDS '+struct.pack('<31I',*hdr)+b''.join(np.rint(a*255).astype('u1').tobytes() for a in levels))
    assert np.array_equal(np.asarray(Image.open(target)),pixels)
    assert len(levels)==12 and levels[-1].shape==(1,1,4)
    return levels


def dds_levels(path):
    # Decode every existing DXT5 mip, rather than replacing the fixed file's mips.
    blob=path.read_bytes();header=bytearray(blob[:128])
    assert blob[84:88]==b'DXT5'
    h,w=struct.unpack_from('<II',blob,12);count=struct.unpack_from('<I',blob,28)[0]
    offset=128;levels=[]
    from io import BytesIO
    for _ in range(count):
        size=max(1,(w+3)//4)*max(1,(h+3)//4)*16
        struct.pack_into('<III',header,12,h,w,size);struct.pack_into('<I',header,28,1)
        levels.append(np.asarray(Image.open(BytesIO(header+blob[offset:offset+size])).convert('RGBA'),np.float32)/255)
        offset+=size;h=max(1,h//2);w=max(1,w//2)
    assert offset==len(blob)
    return levels


def ini(name,shader,profile,map_name):
    lines=['; MATERIAL_0 and NAME: replace with the actual BODY_FRAME material.',
           '[MATERIAL_0]','NAME=mtBODY_FRAME_NATIVE_TEST',f'SHADER={shader}',
           'ALPHABLEND=0','ALPHATEST=0','DEPTHMODE=0',f'VARCOUNT={len(profile)}']
    for i,(key,value) in enumerate(profile.items()):
        v=value if isinstance(value,list) else [value]
        lines += [f'VAR_{i}_NAME={key}',f'VAR_{i}_FLOAT1={v[0]}',
                  f'VAR_{i}_FLOAT2='+','.join(str(a) for a in (v+[0,0])[:2]),
                  f'VAR_{i}_FLOAT3='+','.join(str(a) for a in (v+[0,0,0])[:3]),
                  f'VAR_{i}_FLOAT4='+','.join(str(a) for a in (v+[0,0,0,0])[:4])]
    textures=[('txDiffuse','BODY_FRAME_2K_txDiff.dds'),('txNormal','BODY_FRAME_1K_txNormal.dds'),
              ('txMaps',map_name+'.dds'),('txDetail','neutral_white.dds')]
    if shader.startswith('nePBR'):textures+=[('txEmissive','neutral_black.dds')]
    lines += [f'RESCOUNT={len(textures)}']
    for i,(key,value) in enumerate(textures):
        lines += [f'RES_{i}_NAME={key}',f'RES_{i}_SLOT={i}',f'RES_{i}_TEXTURE={value}']
    (OUT/f'material_{name}.ini').write_text('\n'.join(lines)+'\n',encoding='utf-8')


def fixture(shader,extras=''):
    # Shaders are included without altering their material calculations.
    path=(ROOT/'acc-shaders-master'/shader).as_posix()
    return '''#define TARGET_PS 1
#define MODE_MAIN_NOFX 1
#define OBJECT_SHADER 1
#define NO_FOG 1
'''+extras+'''\n#define main nativeMaterialMain
#include "'''+path+'''"
#undef main
cbuffer Fixture : register(b12) {float2 fixtureSize; float fixtureAngle; float fixtureProbe; float2 fixtureUV;};
float4 main(float4 position:SV_POSITION):SV_TARGET {
 PS_IN_Nm pin=(PS_IN_Nm)0;
 pin.PosH=position;
 float2 uv=fixtureProbe>0 ? fixtureUV : position.xy/fixtureSize;
 pin.Tex=uv;pin.Ao=1;pin.ShadowTex0=float4(0,0,0,1);
 float angle=fixtureProbe>0 ? fixtureAngle : (uv.x-.5)*1.9+fixtureAngle;
 pin.NormalW=float3(sin(angle),0,cos(angle));
 pin.TangentW=float3(cos(angle),0,-sin(angle));pin.BitangentW=float3(0,1,0);
 pin.PosC=float3(0,0,-1);
 PS_OUT result=nativeMaterialMain(pin);return result.result;
}
'''


def brdf_lut():
    # Synthetic test resource: split-sum GGX integration. It is not CSP's bundled LUT.
    s=64;y,x=np.mgrid[:s,:s].astype(np.float32)
    nv=np.maximum((x+.5)/s,.001);rough=1-(y+.5)/s;alpha=rough**2
    vx=np.sqrt(1-nv**2);A=np.zeros_like(nv);B=A.copy();samples=512
    for i in range(samples):
        bits=i;radical=0.;scale=.5
        while bits:radical+=(bits&1)*scale;bits>>=1;scale*=.5
        phi=2*np.pi*i/samples
        cos=np.sqrt((1-radical)/(1+(alpha**2-1)*radical));sin=np.sqrt(1-cos**2)
        hx=sin*np.cos(phi);hy=sin*np.sin(phi);hz=cos
        vh=np.maximum(vx*hx+nv*hz,0);nl=2*vh*hz-nv
        nl=np.maximum(nl,0)
        g1v=2*nv/(nv+np.sqrt(alpha**2+(1-alpha**2)*nv**2))
        g1l=2*nl/np.maximum(nl+np.sqrt(alpha**2+(1-alpha**2)*nl**2),1e-8)
        gv=g1v*g1l*vh/np.maximum(hz*nv,1e-8)
        fc=(1-vh)**5;A+=(1-fc)*gv;B+=fc*gv
    A/=samples;B/=samples
    return [[np.stack((B,np.maximum(A+B,.001),np.zeros_like(A),np.ones_like(A)),-1)]]


def main():
    OUT.mkdir(exist_ok=True);QA.mkdir(parents=True,exist_ok=True);native.QA=QA
    paths=[SOURCE/'BODY_FRAME_1K_txNormal.dds',SOURCE/'BODY_FRAME_2K_txDiff.dds',
           COLLECTION/'BODY_FRAME_4K_METALLIC.png',COLLECTION/'BODY_FRAME_4K_NOTUSED.png']
    before={str(p):native.sha(p) for p in paths}
    normal_levels=dds_levels(paths[0]);diffuse_levels=dds_levels(paths[1])
    d=diffuse_levels[0]
    masks=[np.asarray(Image.open(p).convert('RGBA').resize((2048,1024),Image.Resampling.BOX)) for p in paths[2:]]
    assert all(np.array_equal(a[...,0],a[...,1]) and np.array_equal(a[...,1],a[...,2]) for a in masks)
    metal=np.clip(masks[0][...,0].astype(np.float32)/246,0,1)
    cavity=1-masks[1][...,0].astype(np.float32)/255
    # Pale isolated patches coincide with silver decals; darkness in the broad map
    # follows vent/grid and small recesses. The broad white field is smooth paint.
    maps={}
    for name,gloss in [('balanced',.88),('crisp',.96)]:
        r=(.48+.43*metal)*(1-.82*cavity)
        g=(gloss+(1-gloss)*.7*metal)*(1-.7*cavity)
        b=(.72+.28*metal)*(1-.90*cavity)
        pixels=np.uint8(np.rint(np.clip(np.stack((r,g,b,metal),-1),0,1)*255))
        maps[name]=[export('BODY_FRAME_'+name+'_txMaps',pixels)]
        ini(name,'ksPerPixelMultiMap',PROFILE,'BODY_FRAME_'+name+'_txMaps')
        ini(name+'_gamma','ksPerPixelMultiMap',GAMMA,'BODY_FRAME_'+name+'_txMaps')
    smooth=(.88+.06*metal)*(1-.62*cavity)
    pbr_pixels=np.uint8(np.rint(np.clip(np.stack((smooth,metal,np.ones_like(metal),1-.35*cavity),-1),0,1)*255))
    maps['pbr']=[export('BODY_FRAME_pbr_txMaps',pbr_pixels)]
    # The local plain nePBR_MultiMap WITHOUT_NMDETAIL/Hill12 branch samples but
    # does not apply the normal. ClearCoat calls getNormalW; intensity=0 is our
    # uncoated PBR control while retaining the fixed normal's effect.
    ini('pbr','nePBR_MultiMap_ClearCoat',PBR,'BODY_FRAME_pbr_txMaps')
    ini('pbr_clearcoat','nePBR_MultiMap_ClearCoat',CLEARCOAT,'BODY_FRAME_pbr_txMaps')
    for p in paths[:2]:
        shutil.copyfile(p,OUT/p.name);assert native.sha(OUT/p.name)==before[str(p)]
    for name in ['neutral_white','neutral_black']:
        for ext in ['png','dds']:
            shutil.copyfile(SOURCE/'리뉴얼/native_multimap_test_v1'/f'{name}.{ext}',OUT/f'{name}.{ext}')
    Image.fromarray(np.uint8(np.rint(np.stack((metal,cavity,np.zeros_like(metal)),-1)*255))).save(QA/'observed_roles.png')
    shaders={
        'legacy':native.compile_shader(fixture('recreated/ksPerPixelMultiMap_ps.fx'),'body_multimap'),
        'gamma':native.compile_shader(fixture('recreated/ksPerPixelMultiMap_ps.fx','#define GAMMA_FIX 1\n'),'body_multimap_gamma'),
        'pbr':native.compile_shader(fixture('custom_objects/nePBR_MultiMap_ClearCoat_ps.fx',
                        '#define ALLOW_PBR_EXTRAS_BASE 1\n#define ALLOW_CLEARCOAT 1\n'),'body_pbr'),
        'clearcoat':native.compile_shader(fixture('custom_objects/nePBR_MultiMap_ClearCoat_ps.fx',
                        '#define ALLOW_PBR_EXTRAS_BASE 1\n#define ALLOW_CLEARCOAT 1\n'),'body_pbr_clearcoat')}
    constants=dict(PROFILE,fixtureSize=[1024,512],fixtureAngle=0,fixtureProbe=0,
                   ksLightDirection=[.35,-.3,-.88741197,0],ksLightColor=[1,1,1,1],extSpecularColor=[1,1,1],
                   ksAmbientColor_sky0=[.7,.7,.7,1],ksHorizonColor=[.5,.5,.5,1],ksZenithColor=[.7,.7,.7,1],
                   perObjAmbientMultiplier=1,extLambertGamma_inner=1,extVAOExp=1,extFresnelGamma=1,
                   extSunSpecularMult=1,extReflectionBrightness=1,extReflectionBrightnessMult=1,
                   ksExposure=1,extEmissiveMults=[1,1,1,3],extIBLAmbientBaseThreshold=1,
                   extScreenSize=[1024,512,1/1024,1/512],extMSAA=1,extClearCoat=0,
                   extShaderFlags=0,ksNearPlane=.01,extFlags=0,extVaoMode=0,
                   shadowR1=0,shadowR2=1,sceneShadowOpacity=0)
    white=np.ones((1,1,4),np.float32);black=white.copy();black[...,:3]=0
    common={'txDiffuse':[diffuse_levels],'txNormal':[normal_levels],'txDetail':[[white]],'txEmissive':[[black]]}
    env=native.cube();lut=brdf_lut()
    exe=ROOT/'docs/diagnostics/2026-10-11/native-visor-material/native_readback.exe'
    def run(label,shader_name,map_name,profile=None,extra=None,uv=None,environment=None,custom_maps=None,custom_normal=None):
        w,h=(1,1) if uv else (1024,512)
        params=constants | (profile or {}) | (extra or {}) | {'fixtureSize':[w,h]}
        if uv:params.update(fixtureProbe=1,fixtureUV=uv)
        txt=QA/(label+'.params');txt.write_text('\n'.join(k+' '+' '.join(str(v) for v in (a if isinstance(a,list) else [a])) for k,a in params.items()))
        inp=QA/(label+'.input');native.texture_input(inp,common | {'txNormal':custom_normal or common['txNormal'],
                   'txMaps':custom_maps or maps[map_name],
                   'txCube':env if environment is None else environment,'txBDRFMap':lut})
        dst=QA/(label+'.rgba32f')
        result=subprocess.run([str(exe),str(shaders[shader_name]),str(inp),str(txt),str(dst),str(w),str(h)],capture_output=True,text=True)
        if result.returncode:raise RuntimeError(result.stdout+result.stderr)
        a=np.fromfile(dst,'<f4').reshape(h,w,4);assert np.isfinite(a).all(),label
        assert np.all(a[...,3]>.999),label
        inp.unlink();return a
    renders={'ksMultiMap_balanced':run('ksMultiMap_balanced','legacy','balanced'),
             'ksMultiMap_crisp':run('ksMultiMap_crisp','legacy','crisp'),
             'ksMultiMap_gamma':run('ksMultiMap_gamma','gamma','balanced',GAMMA),
             'PBR':run('PBR','pbr','pbr',PBR),
             'PBR_clearcoat':run('PBR_clearcoat','clearcoat','pbr',CLEARCOAT)}
    renders['ksMultiMap_turned']=run('ksMultiMap_turned','legacy','balanced',extra={'fixtureAngle':.4})
    flat=run('pbr_flat_normal_control','clearcoat','pbr',CLEARCOAT,
             custom_normal=[[np.array([.5,.5,1,1],np.float32).reshape(1,1,4)]])
    normal_difference=float(np.max(abs(flat[...,:3]-renders['PBR_clearcoat'][...,:3])))
    assert normal_difference>.01
    # Find an interior silver texel and a painted texel from observed channels.
    yy,xx=np.mgrid[:1024,:2048]
    metal_region=(metal>.75)&(xx>900)&(xx<1100)&(yy>550)
    ym,xm=np.where(metal_region);idx=len(xm)//2
    silver=[(int(xm[idx])+.5)/2048,(int(ym[idx])+.5)/1024]
    yl,xl=np.where((d[...,1]>.8)&(d[...,0]>.5)&(yy<500)&(cavity<.1));idx=len(xl)//2
    paint=[(int(xl[idx])+.5)/2048,(int(yl[idx])+.5)/1024]
    probes={}
    dark=[[np.zeros((1,1,4),np.float32)]]*6
    no_light={'ksLightColor':[0,0,0,0],'extSpecularColor':[0,0,0],
              'ksAmbientColor_sky0':[0,0,0,0],'ksHorizonColor':[0,0,0,0],'ksZenithColor':[0,0,0,0]}
    for mode,shader_name,map_name,profile in [('legacy','legacy','balanced',PROFILE),('pbr','pbr','pbr',PBR)]:
        for label,uv in [('paint',paint),('silver',silver)]:
            probes[mode+'_'+label]=run('probe_'+mode+'_'+label,shader_name,map_name,profile,uv=uv)[0,0].tolist()
            probes[mode+'_'+label+'_env_only']=run('probe_'+mode+'_'+label+'_env_only',shader_name,map_name,profile,
                                                 no_light,uv,env)[0,0].tolist()
        probes[mode+'_dark']=run('probe_'+mode+'_dark',shader_name,map_name,profile,no_light,paint,dark)[0,0].tolist()
        assert max(abs(v) for v in probes[mode+'_dark'][:3])<1e-6
    # At the identical silver texel, removing metalness should reduce env response.
    nonmetal=maps['pbr'][0][0].copy();nonmetal[...,1]=0
    probes['pbr_silver_no_metal_env_only']=run('probe_pbr_silver_no_metal','pbr','pbr',PBR,no_light,
                                             silver,env,[[nonmetal]])[0,0].tolist()
    assert sum(probes['pbr_silver_env_only'][:3])>sum(probes['pbr_silver_no_metal_env_only'][:3])*2
    board=Image.new('RGB',(1024,548*len(renders)),(22,24,28));draw=ImageDraw.Draw(board)
    for i,(name,a) in enumerate(renders.items()):
        display=np.clip(a[...,:3],0,1)**(1/2.2 if name.endswith('_gamma') else 1)
        im=Image.fromarray(np.uint8(np.rint(display*255)));im.save(QA/(name+'_preview.png'))
        board.paste(im,(0,i*548+32));draw.text((10,i*548+10),name,fill='white')
    board.save(QA/'comparison.png')
    assert before=={str(p):native.sha(p) for p in paths}
    manifest={'sources':before,'fixed_diffuse_normal_copies_byte_identical':True,'originals_unchanged':True,
              'outputs':{p.name:native.sha(p) for p in OUT.glob('*.dds')},
              'profiles':{'legacy':PROFILE,'gamma':GAMMA,'pbr':PBR,'clearcoat':CLEARCOAT},
              'scope':'D3D11 WARP native shader source; artificial UV cylinder, synthetic studio cube; not game/mesh/DLSS',
              'pbr_fixture_resources':'512-sample synthetic split-sum GGX LUT, not the installed CSP LUT',
              'pbr_compile_features':['ALLOW_PBR_EXTRAS_BASE','ALLOW_CLEARCOAT'],
              'pbr_shader':'nePBR_MultiMap_ClearCoat; coat intensity0 / .25 comparison',
              'fixed_normal_vs_flat_max_rgb_difference':normal_difference,
              'probe_uv':{'paint':paint,'silver':silver},'probes':probes,
              'maps_resolution':[2048,1024],'maps_mips':12,
              'fixed_source_mips':{'normal':len(normal_levels),'diffuse':len(diffuse_levels)},
              'bright_patch_fraction':float(np.mean(metal>.4)),
              'maps_channels':{'ksPerPixelMultiMap':['specular strength','specular exponent control','reflection strength','CSP reflection tint mask'],
                               'nePBR_MultiMap_ClearCoat':['smoothness','metalness','reflectance selector (constant .04 profile)','occlusion']}}
    (OUT/'asset_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (QA/'validation.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'out':str(OUT),'probes':probes},indent=2))


def package():
    shutil.copyfile(ROOT/'docs/NATIVE_BODY_FRAME_TEXTURE_TEST.md',OUT/'README.md')
    for name in ['ksMultiMap_balanced_preview.png','PBR_preview.png','PBR_clearcoat_preview.png','comparison.png','observed_roles.png']:
        shutil.copyfile(QA/name,OUT/name)
    target=SOURCE/'BODY_FRAME_native_material_test_v1.zip'
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in sorted(OUT.iterdir()):
            if p.is_file():z.write(p,OUT.name+'/'+p.name)
    with zipfile.ZipFile(target) as z:assert z.testzip() is None
    print(str(target))


if __name__=='__main__':
    main()
    package()
