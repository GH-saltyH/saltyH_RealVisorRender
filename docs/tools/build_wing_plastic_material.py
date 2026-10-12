"""Clear wing material assets; execute local native shader sources on D3D11 WARP.

No original textures, blend files, FBX settings or runtime settings are changed.
"""
from pathlib import Path
import json
import struct
import shutil
import subprocess
import zipfile
import numpy as np
from PIL import Image, ImageDraw
import test_visor_native_multimap as native

ROOT = native.ROOT
SOURCE = ROOT / 'ModelWorks/_2_blender_f1-helmet-lando_2025championWinner/texture'
OUT = SOURCE / 'native_wing_plastic_test_v1'
QA = ROOT / 'docs/diagnostics/2026-10-11/native-wing'
NM = dict(ksAmbient=.15, ksDiffuse=.10, ksSpecular=.85, ksSpecularEXP=235,
          ksEmissive=[0, 0, 0], ksAlphaRef=0, diffuseMult=0, normalMult=0,
          fresnelC=.04, fresnelEXP=5/.96, fresnelMaxLevel=.8,
          extColoredReflection=0, extColoredReflectionNorm=0)
NM_GAMMA = NM | dict(ksAmbient=.10, fresnelC=.2, fresnelEXP=5/(.96*2.2),
                      fresnelMaxLevel=float(np.sqrt(.8)))
MM = native.PROFILE | dict(ksAmbient=.15, ksDiffuse=.10, ksSpecular=.85,
                           fresnelC=.04, fresnelMaxLevel=.8, ksEmissive=[0,0,0])
MM_GAMMA = MM | dict(ksAmbient=.10, fresnelC=.2, fresnelEXP=5/2.2,
                      fresnelMaxLevel=float(np.sqrt(.8)))


def export(name, pixels, kind='data'):
    Image.fromarray(pixels).save(OUT / (name+'.png'))
    levels = native.mips(pixels, kind)
    h,w = pixels.shape[:2]
    hdr = [124,0x2100f,h,w,w*4,0,len(levels)]+[0]*11
    hdr += [32,0x41,0,32,255,65280,16711680,4278190080]+[0x401008,0,0,0,0]
    path = OUT / (name+'.dds')
    path.write_bytes(b'DDS '+struct.pack('<31I',*hdr)+b''.join(
        np.rint(a*255).astype('u1').tobytes() for a in levels))
    assert np.array_equal(np.asarray(Image.open(path).convert('RGBA')), pixels)
    assert len(levels) == max(w,h).bit_length()
    assert levels[-1].shape == (1,1,4)
    return levels


def ini(name, shader, profile, diffuse, normal='WING_flat_normal', multimap=False):
    lines = ['; MATERIAL_0 is a template index; merge into the actual wing material.',
             '; Current blend: WING_04 / WING_TOPMOST / WING_TOPSIDE.',
             '[MATERIAL_0]', 'NAME=mtBODY_WING_MIRROR', f'SHADER={shader}',
             'ALPHABLEND=1', 'ALPHATEST=0', 'DEPTHMODE=1', f'VARCOUNT={len(profile)}']
    for i,(key,value) in enumerate(profile.items()):
        v = value if isinstance(value,list) else [value]
        lines += [f'VAR_{i}_NAME={key}',f'VAR_{i}_FLOAT1={v[0]}',
                  f'VAR_{i}_FLOAT2='+','.join(str(x) for x in (v+[0,0])[:2]),
                  f'VAR_{i}_FLOAT3='+','.join(str(x) for x in (v+[0,0,0])[:3]),
                  f'VAR_{i}_FLOAT4='+','.join(str(x) for x in (v+[0,0,0,0])[:4])]
    textures = [('txDiffuse',diffuse),('txNormal',normal)]
    if multimap:
        textures += [('txMaps','WING_uniform_maps'),('txDetail','neutral_white'),
                     ('txEmissive','neutral_black')]
    lines += [f'RESCOUNT={len(textures)}']
    for i,(key,value) in enumerate(textures):
        lines += [f'RES_{i}_NAME={key}',f'RES_{i}_SLOT={i}',f'RES_{i}_TEXTURE={value}.dds']
    (OUT/(name+'.ini')).write_text('\n'.join(lines)+'\n',encoding='utf-8')


def main():
    OUT.mkdir(exist_ok=True); QA.mkdir(parents=True,exist_ok=True)
    native.OUT, native.QA = OUT,QA
    originals = [SOURCE/'MRR_BODY_WING_2K_txNormal.png', SOURCE/'MRR_WING_DIFF.dds',
        SOURCE.parent/'visor_lando_2025Champion_maxquality.blend',
        SOURCE.parent/'Final/visor_lando_2025Champion_maxquality_Full.fbx.ini']
    before = {str(p):native.sha(p) for p in originals}
    neutral_flat = np.tile(np.array([128,128,255,255],np.uint8),(4,4,1))
    flat = export('WING_flat_normal',neutral_flat,'normal')
    white = export('neutral_white',np.full((4,4,4),255,np.uint8))
    black_pixels = np.full((4,4,4),255,np.uint8); black_pixels[...,:3]=0
    black = export('neutral_black',black_pixels)
    maps = np.tile(np.array([235,242,255,255],np.uint8),(4,4,1))
    maps_levels = export('WING_uniform_maps',maps)
    raw = np.asarray(Image.open(originals[0]).convert('RGBA'))
    n = raw[...,:3].astype(np.float32)/255*2-1
    n /= np.maximum(np.linalg.norm(n,axis=-1,keepdims=True),1e-8)
    normal_pixels = np.empty_like(raw); normal_pixels[...,:3] = np.rint((n*.5+.5)*255)
    normal_pixels[...,3] = 255
    detail_normal = export('WING_legacyUV_normal',normal_pixels,'normal')
    variants = {}
    for name,alpha_byte in [('clear',3),('balanced',8),('defined',16)]:
        pixels = np.tile(np.array([77,77,77,alpha_byte],np.uint8),(4,4,1))
        diffuse = export('WING_'+name+'_diffuse',pixels,'color')
        variants[name] = dict(txDiffuse=[diffuse],txNormal=[flat])
        for suffix,profile in [('',NM),('_gamma',NM_GAMMA)]:
            ini('material_nm_'+name+suffix,'ksPerPixelNM_UVMult',profile,'WING_'+name+'_diffuse')
    ini('material_nm_balanced_legacyUV','ksPerPixelNM_UVMult',NM,
        'WING_balanced_diffuse','WING_legacyUV_normal')
    for suffix,profile in [('',MM),('_gamma',MM_GAMMA)]:
        ini('material_multimap_balanced'+suffix,'ksPerPixelMultiMap_emissive',profile,
            'WING_balanced_diffuse',multimap=True)
    header = native.HEADER.replace('ksPerPixelMultiMap_emissive_ps.fx','ksPerPixelNM_UVMult_ps.fx')
    header = header.replace('PS_IN_NmExtra4','PS_IN_Nm').replace('pin.Extra=float4(1,0,0,0);','')
    shader = native.compile_shader(header,'wing_nm_fixture')
    runner = ROOT/'docs/diagnostics/2026-10-11/native-visor-material/native_readback.exe'
    constants = dict(ksLightDirection=[.35,-.3,-.88741197,0],ksLightColor=[1,1,1,1],
        extSpecularColor=[1,1,1],ksAmbientColor_sky0=[.7,.7,.7,1],
        ksHorizonColor=[.5,.5,.5,1],ksZenithColor=[.7,.7,.7,1],
        perObjAmbientMultiplier=1,extLambertGamma_inner=1,extVAOExp=1,extFresnelGamma=1,
        extSunSpecularMult=1,extReflectionBrightness=1,extReflectionBrightnessMult=1,
        ksExposure=1,extEmissiveMults=[1,1,1,3],extIBLAmbientBaseThreshold=1,
        extMSAA=1,extClearCoat=0,extShaderFlags=0,ksNearPlane=.01,extFlags=0,extVaoMode=0,
        shadowR1=0,shadowR2=1,sceneShadowOpacity=0,fixtureAngle=0,fixtureProbe=0)
    env = native.cube()

    def run(label,textures,profile=NM,changes=None,w=512,h=512,environment=None):
        params = constants | profile | (changes or {}) | dict(fixtureSize=[w,h],
                    extScreenSize=[w,h,1/w,1/h])
        parameter_file = QA/(label+'.params')
        parameter_file.write_text('\n'.join(k+' '+' '.join(str(v) for v in
            (a if isinstance(a,list) else [a])) for k,a in params.items()))
        inp = QA/(label+'.input')
        native.texture_input(inp,textures | {'txCube':env if environment is None else environment})
        dst = QA/(label+'.rgba32f')
        result = subprocess.run([str(runner),str(shader),str(inp),str(parameter_file),str(dst),str(w),str(h)],
                                 capture_output=True,text=True)
        if result.returncode:raise RuntimeError(result.stdout+result.stderr)
        a = np.fromfile(dst,'<f4').reshape(h,w,4); inp.unlink()
        assert np.isfinite(a).all(),label
        assert a[...,3].min()>=0 and a[...,3].max()<=1,label
        return a

    renders = {name:run(name,tex) for name,tex in variants.items()}
    renders['balanced_turned'] = run('balanced_turned',variants['balanced'],changes={'fixtureAngle':.6})
    renders['legacyUV_detail'] = run('legacyUV_detail',variants['balanced'] | {'txNormal':[detail_normal]})
    probes = {}
    for angle in [0,45,75,85]:
        probes[str(angle)] = run('angle_'+str(angle),variants['balanced'],changes={
            'fixtureProbe':1,'fixtureUV':[.5,.5],'fixtureAngle':float(np.deg2rad(angle))},w=1,h=1)[0,0].tolist()
    assert .05 < probes['0'][3] < .10
    assert probes['85'][3] > probes['0'][3]+.3
    darkness = dict(fixtureProbe=1,fixtureUV=[.5,.5],ksLightColor=[0,0,0,0],
        extSpecularColor=[0,0,0],ksAmbientColor_sky0=[0,0,0,0],
        ksHorizonColor=[0,0,0,0],ksZenithColor=[0,0,0,0])
    dark = run('dark',variants['balanced'],changes=darkness,w=1,h=1,
               environment=[[np.zeros((1,1,4),np.float32)]]*6)[0,0]
    assert max(abs(dark[:3])) < 1e-6
    assert np.max(np.abs(renders['legacyUV_detail']-renders['balanced']))>.01
    shader = native.compile_shader('#define GAMMA_FIX 1\n'+header,'wing_nm_fixture_gamma')
    gamma = run('gamma_front',variants['balanced'],NM_GAMMA,
                dict(fixtureProbe=1,fixtureUV=[.5,.5]),w=1,h=1)[0,0].tolist()
    assert abs(gamma[3]-probes['0'][3])<1e-5
    renders['balanced_gamma'] = run('balanced_gamma',variants['balanced'],NM_GAMMA)
    shader = native.compile_shader(native.HEADER,'wing_multimap_fixture')
    multi = variants['balanced'] | dict(txMaps=[maps_levels],txDetail=[white],txEmissive=[black])
    renders['multimap_balanced'] = run('multimap_balanced',multi,MM)
    multi_front = run('multimap_front',multi,MM,dict(fixtureProbe=1,fixtureUV=[.5,.5]),w=1,h=1)[0,0].tolist()
    assert abs(multi_front[3]-probes['0'][3])<.001
    shader = native.compile_shader('#define GAMMA_FIX 1\n'+native.HEADER,'wing_multimap_fixture_gamma')
    multi_gamma = run('multimap_gamma_front',multi,MM_GAMMA,
                      dict(fixtureProbe=1,fixtureUV=[.5,.5]),w=1,h=1)[0,0].tolist()
    assert abs(multi_gamma[3]-multi_front[3])<1e-5
    # Controlled checker backdrop demonstrates alpha; this is not helmet geometry.
    y,x = np.mgrid[:512,:512]
    checker=((x//40+y//40)%2)[...,None]
    background=np.array([.10,.16,.08])+checker*np.array([.42,.46,.08])
    board=Image.new('RGB',(1536,1112),(22,24,28));draw=ImageDraw.Draw(board)
    labels = ['clear','balanced','defined','balanced_turned','legacyUV_detail','multimap_balanced']
    for i,name in enumerate(labels):
        a=renders[name];opacity=a[...,3:4]
        display=np.clip(a[...,:3]*opacity+background*(1-opacity),0,1)
        im=Image.fromarray(np.uint8(np.rint(display*255)))
        im.save(QA/(name+'_preview.png'))
        xx=(i%3)*512; yy=(i//3)*548
        board.paste(im,(xx,yy+32));draw.text((xx+10,yy+10),name,fill='white')
    draw.text((10,1098),'Native D3D11 WARP / synthetic cylinder + studio cube / NOT an in-game helmet render',fill='white')
    board.save(QA/'comparison.png')
    assert before == {str(p):native.sha(p) for p in originals}
    inventory=json.loads((QA/'blend_wing_inventory.json').read_text())
    uv_summary={r['name']:dict(uv_min=np.min(r['uv'],axis=0).tolist(),
        uv_max=np.max(r['uv'],axis=0).tolist(),materials=r['materials'])
        for r in inventory if r['name'] in ['WING_04','WING_TOPMOST','WING_TOPSIDE']}
    manifest=dict(shader='ksPerPixelNM_UVMult',profile=NM,profile_gamma=NM_GAMMA,
        alternate_shader='ksPerPixelMultiMap_emissive',alternate_profile=MM,
        source_sha256=before,originals_unchanged=True,uv_inventory=uv_summary,
        gpu_probes=probes,dark=dark.tolist(),gamma_front=gamma,multimap_front=multi_front,
        multimap_gamma_front=multi_gamma,
        diffuse_alpha={name:int(tex['txDiffuse'][0][0][0,0,3]*255)/255 for name,tex in variants.items()},
        normal_difference_max=float(np.max(np.abs(renders['legacyUV_detail']-renders['balanced']))),
        default_normal='Flat tangent normal: existing mesh geometry supplies curvature/bevels.',
        optional_normal='Existing 2K normal normalized, same UV layout; legacy UV only.',
        fixture_scope='Local native shaders on D3D11 WARP; synthetic UV cylinder/studio cube; no game/KN5/sorting test.',
        dds='RGBA8 UNORM full mip chain: constants 4x4/3 levels, optional normal 2048x2048/12 levels.',
        output_sha256={p.name:native.sha(p) for p in OUT.glob('*.dds')})
    (OUT/'asset_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (QA/'validation.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    shutil.copyfile(ROOT/'docs/NATIVE_WING_PLASTIC_MATERIAL.md',OUT/'README.md')
    for name in ['comparison.png','uv_binding_inspection.png']:
        shutil.copyfile(QA/name,OUT/name)
    target=SOURCE/'WING_native_plastic_test_v1.zip'
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for p in sorted(OUT.iterdir()):
            if p.is_file():archive.write(p,OUT.name+'/'+p.name)
    with zipfile.ZipFile(target) as archive:assert archive.testzip() is None
    print(json.dumps(dict(out=str(OUT),zip=str(target),gpu_probes=probes,
                         gamma_front=gamma,dark=dark.tolist()),indent=2))


if __name__=='__main__':main()
