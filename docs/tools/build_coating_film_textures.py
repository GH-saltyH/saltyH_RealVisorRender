"""Prepare film texture candidates and validate with the local native shader/WARP.
No game mesh, runtime configuration or input texture is modified.
"""
from pathlib import Path
import json
import shutil
import subprocess
import zipfile
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import test_visor_native_multimap as native

ROOT, SOURCE = native.ROOT, native.SOURCE
OUT = SOURCE / 'native_coating_film_test_v1'
QA = ROOT / 'docs/diagnostics/2026-10-11/native-coating-film'
PROFILE = native.PROFILE | dict(ksSpecular=.45, fresnelC=.025, fresnelMaxLevel=.30)
GAMMA = PROFILE | dict(ksAmbient=.25, ksDiffuse=.25, fresnelC=float(np.sqrt(.025)),
                      fresnelMaxLevel=float(np.sqrt(.30)), fresnelEXP=5/2.2)


def package():
    shutil.copyfile(ROOT/'docs/NATIVE_COATING_FILM_TEXTURE_TEST.md',OUT/'README.md')
    for name in ['balanced_gamma_preview.png','comparison.png','end_letter_closeup.png']:
        shutil.copyfile(QA/name,OUT/name)
    target=SOURCE/'GLASS_COAT_native_film_test_v1.zip'
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for path in sorted(OUT.iterdir()):
            if path.is_file():archive.write(path,OUT.name+'/'+path.name)
    with zipfile.ZipFile(target) as archive:assert archive.testzip() is None
    print(str(target))


def ini(name, profile, suffix=''):
    lines = ['; MATERIAL_0 and NAME are placeholders for the actual coating material.',
             '; Native material test: connect to the native draw path before judging it.',
             '[MATERIAL_0]', 'NAME=mtGLASS_COATING_NATIVE_TEST',
             'SHADER=ksPerPixelMultiMap_emissive', 'ALPHABLEND=1', 'ALPHATEST=0',
             'DEPTHMODE=1', f'VARCOUNT={len(profile)}']
    for i, (key, value) in enumerate(profile.items()):
        lines += [f'VAR_{i}_NAME={key}', f'VAR_{i}_FLOAT1={value}', f'VAR_{i}_FLOAT2=0,0',
                  f'VAR_{i}_FLOAT3=0,0,0', f'VAR_{i}_FLOAT4=0,0,0,0']
    textures = [('txDiffuse',f'COAT_{name}_diffuse.dds'), ('txNormal','COAT_normal.dds'),
                ('txMaps',f'COAT_{name}_maps.dds'), ('txDetail','neutral_white.dds'),
                ('txEmissive','neutral_black.dds')]
    lines += ['RESCOUNT=5']
    for i,(key,value) in enumerate(textures):
        lines += [f'RES_{i}_NAME={key}', f'RES_{i}_SLOT={i}', f'RES_{i}_TEXTURE={value}']
    (OUT/f'material_{name}{suffix}.ini').write_text('\n'.join(lines)+'\n', encoding='utf-8')


def main():
    OUT.mkdir(exist_ok=True); QA.mkdir(parents=True,exist_ok=True)
    native.OUT, native.QA = OUT, QA
    names=['CUTPATTERN','NOISE1','NOISE2','NOISE3','SIGN','txNormal']
    source={n:np.asarray(Image.open(SOURCE/f'GLASS_COAT_{n}.png').convert('RGBA')) for n in names}
    before={n:native.sha(SOURCE/f'GLASS_COAT_{n}.png') for n in names}
    coverage=source['SIGN'][...,3].astype(np.float32)/255
    valid=coverage>.99
    assert all(np.array_equal(a[...,3],source['SIGN'][...,3]) for a in source.values())
    def scalar(name):
        return np.clip(source[name][...,0].astype(np.float32)/np.maximum(coverage,1e-6)/253,0,1)
    end=scalar('NOISE3')
    grain=np.clip((scalar('NOISE1')-67/253)/((188-67)/253),0,1)
    macro=1-scalar('NOISE2')
    cut=scalar('CUTPATTERN')
    lettering=np.clip((1-scalar('SIGN'))/(73/253),0,1)
    # Padding extends data past island boundaries; source alpha still defines coverage.
    normal=source['txNormal'][...,:3].astype(np.float32)/np.maximum(coverage[...,None],1e-6)/255*2-1
    normal[~valid]=[0,0,1]
    fields=native.pad(np.concatenate((np.stack((end,grain,macro,cut,lettering),-1),normal),-1),valid,16)
    end,grain,macro,cut,lettering=[fields[...,i] for i in range(5)]
    normal=fields[...,5:8];normal/=np.maximum(np.linalg.norm(normal,axis=-1,keepdims=True),1e-8)
    def normal_pixels(n):
        return np.uint8(np.rint(np.clip(np.concatenate((n*.5+.5,coverage[...,None]),-1),0,1)*255))
    normal_levels=native.export('COAT_normal',normal_pixels(normal),'normal')
    # Optional very shallow recess: perturb tangent slopes, not encoded normal RGB.
    glyph=np.asarray(Image.fromarray(np.uint8(np.rint(np.clip(lettering,0,1)*255))).filter(
        ImageFilter.GaussianBlur(.6)),np.float32)/255
    gy,gx=np.gradient(-glyph*.035)
    slopes=normal[...,:2]/np.maximum(normal[...,2:3],.2)-np.stack((gx,gy),-1)
    engraved=np.concatenate((slopes,np.ones((*coverage.shape,1),np.float32)),-1)
    engraved/=np.linalg.norm(engraved,axis=-1,keepdims=True)
    native.export('COAT_normal_shallow_engraving',normal_pixels(engraved),'normal')
    for name in ['neutral_white','neutral_black']:
        for ext in ['png','dds']:
            shutil.copyfile(SOURCE/'native_multimap_test_v1'/f'{name}.{ext}',OUT/f'{name}.{ext}')
    white=np.full((1,1,4),1,np.float32);black=white.copy();black[...,:3]=0
    variants={};stats={}
    for name,base,fine,end_alpha in [('clear',.025,.012,.18),('balanced',.04,.025,.30),('cloudy',.065,.04,.44)]:
        alpha=np.clip(base+fine*grain+.008*macro+end_alpha*end*(.85+.15*grain)+.04*cut,0,.72)
        alpha=alpha+(1-alpha)*.32*lettering
        # Low contrast neutral veil; cloudy ends scatter more diffuse light.
        color=np.stack((.20+.30*end+.04*grain,.21+.30*end+.04*grain,.22+.30*end+.04*grain),-1)
        color*=1-.78*lettering[...,None]
        diffuse=np.uint8(np.rint(np.clip(np.concatenate((color,(alpha*coverage)[...,None]),-1),0,1)*255))
        rough=.045+.23*end+.07*grain+.045*macro+.08*cut+.06*lettering
        maps_rgb=np.stack((.65-.23*end-.08*grain, (1-np.clip(rough,0,.8))**2,
                           .85-.16*end-.06*grain),-1)
        maps=np.uint8(np.rint(np.clip(np.concatenate((maps_rgb,np.ones((*coverage.shape,1))),-1),0,1)*255))
        variants[name]={'txDiffuse':[native.export(f'COAT_{name}_diffuse',diffuse,'color')],
                        'txNormal':[normal_levels], 'txMaps':[native.export(f'COAT_{name}_maps',maps)],
                        'txDetail':[[white]], 'txEmissive':[[black]]}
        ini(name,PROFILE);ini(name,GAMMA,'_gamma')
        center=valid & (end<.04) & (lettering<.01)
        ends=valid & (end>.98) & (lettering<.01)
        stats[name]={'center_input_alpha_p5_p95':np.percentile(alpha[center],[5,95]).tolist(),
                     'ends_input_alpha_p5_p95':np.percentile(alpha[ends],[5,95]).tolist(),
                     'dds_mips':13}
    role=np.stack((end,grain,lettering),-1)*coverage[...,None]
    Image.fromarray(np.uint8(np.rint(np.clip(role,0,1)*255))).save(QA/'pattern_roles.png')
    shader=native.compile_shader(native.HEADER,'film_native_fixture')
    exe=ROOT/'docs/diagnostics/2026-10-11/native-visor-material/native_readback.exe'
    constants=dict(PROFILE,fixtureSize=[1024,256],fixtureAngle=0,fixtureProbe=0,
                   ksLightDirection=[0,0,-1,0],ksLightColor=[1,1,1,1],extSpecularColor=[1,1,1],
                   ksAmbientColor_sky0=[.7,.7,.7,1],ksHorizonColor=[.5,.5,.5,1],ksZenithColor=[.7,.7,.7,1],
                   perObjAmbientMultiplier=1,extLambertGamma_inner=1,extVAOExp=1,extFresnelGamma=1,
                   extSunSpecularMult=1,extReflectionBrightness=1,extReflectionBrightnessMult=1,
                   ksExposure=1,extEmissiveMults=[1,1,1,3],extIBLAmbientBaseThreshold=1,
                   extScreenSize=[1024,256,1/1024,1/256],extMSAA=1,extClearCoat=0,
                   extShaderFlags=0,ksNearPlane=.01,extFlags=0,extVaoMode=0)
    env=native.cube()
    def run(label,textures,changes=None,w=1024,h=256,environment=None):
        params=constants | (changes or {}) | {'fixtureSize':[w,h]}
        parameter_file=QA/(label+'.params')
        parameter_file.write_text('\n'.join(k+' '+' '.join(str(v) for v in (a if isinstance(a,list) else [a])) for k,a in params.items()))
        inp=QA/(label+'.input');native.texture_input(inp,textures | {'txCube':env if environment is None else environment})
        dst=QA/(label+'.rgba32f')
        result=subprocess.run([str(exe),str(shader),str(inp),str(parameter_file),str(dst),str(w),str(h)],capture_output=True,text=True)
        if result.returncode:raise RuntimeError(result.stdout+result.stderr)
        a=np.fromfile(dst,'<f4').reshape(h,w,4);assert np.isfinite(a).all(),label
        inp.unlink();return a
    renders={name:run(name,tex) for name,tex in variants.items()}
    flat=np.array([.5,.5,1,1],np.float32).reshape(1,1,4)
    renders['balanced_flat_normal']=run('balanced_flat_normal',variants['balanced'] | {'txNormal':[[flat]]})
    renders['balanced_turned']=run('balanced_turned',variants['balanced'],{'fixtureAngle':.45})
    probes={}
    for label,uv in [('center',[.5,.4]),('left_end',[.10,.4]),('right_end',[.8,.4]),('letter',[3349/4096,459/1024])]:
        probes[label]=run('probe_'+label,variants['balanced'],{'fixtureProbe':1,'fixtureUV':uv},1,1)[0,0].tolist()
    assert probes['left_end'][3]>probes['center'][3]+.15
    probes['dark']=run('probe_dark',variants['balanced'],{'fixtureProbe':1,'fixtureUV':[.5,.4],
                         'ksLightColor':[0,0,0,0],'extSpecularColor':[0,0,0],
                         'ksAmbientColor_sky0':[0,0,0,0]},1,1,[[np.zeros((1,1,4),np.float32)]]*6)[0,0].tolist()
    assert max(abs(v) for v in probes['dark'][:3])<1e-6
    shader=native.compile_shader('#define GAMMA_FIX 1\n'+native.HEADER,'film_native_fixture_gamma')
    renders['balanced_gamma']=run('balanced_gamma',variants['balanced'],GAMMA)
    gamma=run('probe_gamma_center',variants['balanced'],GAMMA | {'fixtureProbe':1,'fixtureUV':[.5,.4]},1,1)[0,0].tolist()
    assert abs(gamma[3]-probes['center'][3])<1e-5
    y,x=np.mgrid[:256,:1024];checker=((x//32+y//32)%2)[...,None]
    background=np.array([.11,.14,.16])+checker*np.array([.26,.25,.23])
    silhouette=np.asarray(Image.fromarray(source['SIGN'][...,3]).resize((1024,256),Image.Resampling.BOX),np.float32)/255
    board=Image.new('RGB',(1024,len(renders)*288),(22,24,28));draw=ImageDraw.Draw(board)
    for i,(name,a) in enumerate(renders.items()):
        opacity=np.clip(a[...,3:4],0,1)*silhouette[...,None]
        bg=background**2.2 if name.endswith('_gamma') else background
        color=a[...,:3]*opacity+bg*(1-opacity)
        display=np.clip(color,0,1)**(1/2.2 if name.endswith('_gamma') else 1)
        image=Image.fromarray(np.uint8(np.rint(display*255)))
        image.save(QA/(name+'_preview.png'));board.paste(image,(0,i*288+28));draw.text((10,i*288+8),name,fill='white')
    board.save(QA/'comparison.png')
    Image.open(QA/'balanced_preview.png').crop((740,30,1024,230)).resize((852,600)).save(QA/'end_letter_closeup.png')
    assert before=={n:native.sha(SOURCE/f'GLASS_COAT_{n}.png') for n in names}
    manifest={'sources':before,'files':{p.name:native.sha(p) for p in OUT.glob('*.dds')},
              'variants':stats,'profile':PROFILE,'profile_gamma':GAMMA,
              'scope':'Native local CSP shader, D3D11 WARP synthetic UV/cylinder and studio environment; no game test',
              'gpu_probes':probes,'gamma_center':gamma,'originals_unchanged':True,
              'normal_max_length_error_before_encoding':float(np.max(abs(np.linalg.norm(normal[valid],axis=-1)-1))),
              'normal_letter_depth':'Optional artistic shallow recess, not measured geometry',
              'source_alpha_equal':True,'dds':'RGBA8 UNORM; 4096x1024 complete13mips; normalized normal mips'}
    (OUT/'asset_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (QA/'validation.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    package()
    print(json.dumps({'out':str(OUT),'variants':stats,'gpu_probes':probes},ensure_ascii=False,indent=2))


if __name__=='__main__':main()
