"""Revise glass material separation and build a masked sticker film material.
Numerical texture processing, native HLSL/WARP validation, no runtime mutation.
"""
from pathlib import Path
import json
import shutil
import subprocess
import zipfile
import struct
import configparser
import numpy as np
from PIL import Image, ImageDraw
import test_visor_native_multimap as native

ROOT=native.ROOT
SOURCE=native.SOURCE
OUT=SOURCE/'native_smooth_glass_sticker_v2'
QA=ROOT/'docs/diagnostics/2026-10-11/glass-smooth-v2'
PROFILE=native.PROFILE | dict(ksAmbient=.20,ksDiffuse=.25,ksSpecular=.65,
    ksSpecularEXP=255,fresnelC=.04,fresnelEXP=5,fresnelMaxLevel=.55,ksEmissive=[0,0,0])
COAT_PROFILE=PROFILE | dict(ksSpecular=.45,fresnelC=.025,fresnelMaxLevel=.35)
STICKER_PROFILE=PROFILE | dict(ksAmbient=.25,ksDiffuse=.35,ksSpecular=.55,
    fresnelC=.035,fresnelMaxLevel=.55,emAlphaFromDiffuse=1)


def gamma(p):
    return p | dict(fresnelC=float(np.sqrt(p['fresnelC'])),
        fresnelMaxLevel=float(np.sqrt(p['fresnelMaxLevel'])),fresnelEXP=p['fresnelEXP']/2.2)


def rgba(rgb,alpha):
    if np.ndim(alpha)==0:alpha=np.full(rgb.shape[:2],alpha,np.float32)
    return np.uint8(np.rint(np.clip(np.concatenate((rgb,alpha[...,None]),-1),0,1)*255))


def smooth(a,passes=2):
    # Float binomial low-pass; clamp at the atlas border, never wrap UV islands.
    for _ in range(passes):
        for axis in [0,1]:
            pads=[(0,0)]*a.ndim;pads[axis]=(2,2);v=np.pad(a,pads,mode='edge')
            total=np.zeros_like(a)
            for i,k in enumerate([1,4,6,4,1]):
                slices=[slice(None)]*a.ndim;slices[axis]=slice(i,i+a.shape[axis])
                total+=v[tuple(slices)]*(k/16)
            a=total
    return a


def export(name,pixels,kind='data'):
    Image.fromarray(pixels).save(OUT/(name+'.png'))
    levels=native.mips(pixels,kind);h,w=pixels.shape[:2]
    hdr=[124,0x2100f,h,w,w*4,0,len(levels)]+[0]*11
    hdr += [32,0x41,0,32,255,65280,16711680,4278190080]+[0x401008,0,0,0,0]
    target=OUT/(name+'.dds')
    target.write_bytes(b'DDS '+struct.pack('<31I',*hdr)+b''.join(np.rint(a*255).astype('u1').tobytes() for a in levels))
    assert np.array_equal(np.asarray(Image.open(target).convert('RGBA')),pixels)
    assert len(levels)==max(w,h).bit_length() and levels[-1].shape==(1,1,4)
    return levels


def ini(name,material,profile,diffuse,normal,maps):
    lines=['; Template: merge parameters/resources into the actual named material.',
           '[MATERIAL_0]',f'NAME={material}','SHADER=ksPerPixelMultiMap_emissive',
           'ALPHABLEND=1','ALPHATEST=0','DEPTHMODE=1',f'VARCOUNT={len(profile)}']
    for i,(key,value) in enumerate(profile.items()):
        v=value if isinstance(value,list) else [value]
        lines += [f'VAR_{i}_NAME={key}',f'VAR_{i}_FLOAT1={v[0]}',
            f'VAR_{i}_FLOAT2='+','.join(str(x) for x in (v+[0,0])[:2]),
            f'VAR_{i}_FLOAT3='+','.join(str(x) for x in (v+[0,0,0])[:3]),
            f'VAR_{i}_FLOAT4='+','.join(str(x) for x in (v+[0,0,0,0])[:4])]
    textures=[('txDiffuse',diffuse),('txNormal',normal),('txMaps',maps),
              ('txDetail','neutral_white'),('txEmissive','neutral_black')]
    lines+=['RESCOUNT=5']
    for i,(key,value) in enumerate(textures):
        lines += [f'RES_{i}_NAME={key}',f'RES_{i}_SLOT={i}',f'RES_{i}_TEXTURE={value}.dds']
    (OUT/(name+'.ini')).write_text('\n'.join(lines)+'\n',encoding='utf-8')


def main():
    OUT.mkdir(exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
    native.OUT,native.QA=OUT,QA
    source_names=['GLASS_EXT_'+n+'.png' for n in ['GLOSS','txDetail','txDiff','txNormal']]
    source_names += ['GLASS_COAT_'+n+'.png' for n in ['NOISE1','NOISE2','NOISE3','SIGN','CUTPATTERN','txNormal']]
    source_names += ['GLASS_STICKER_txDetail.png']
    before={n:native.sha(SOURCE/n) for n in source_names}
    src={n:np.asarray(Image.open(SOURCE/n).convert('RGBA')) for n in source_names}
    def unpremul(a):
        return a[...,:3].astype(np.float32)/np.maximum(a[...,3:4].astype(np.float32)/255,1e-6)/255
    white=export('neutral_white',np.full((4,4,4),255,np.uint8))
    bp=np.full((4,4,4),255,np.uint8);bp[...,:3]=0
    black=export('neutral_black',bp)
    flat=export('flat_normal',np.tile(np.array([128,128,255,255],np.uint8),(4,4,1)),'normal')
    variants={};pixels_out={};analysis={}
    def save_kit(prefix,diffuse,normal,maps,profile,material):
        dl=export(prefix+'_diffuse',diffuse,'color');ml=export(prefix+'_maps',maps)
        variants[prefix]=dict(txDiffuse=[dl],txNormal=[normal],txMaps=[ml],txDetail=[white],txEmissive=[black])
        pixels_out[prefix]=(diffuse,maps)
        ini('material_'+prefix,material,profile,prefix+'_diffuse',
            'EXT_normal' if prefix=='EXT_smooth' else 'COAT_smooth_normal' if prefix=='COAT_smooth' else 'flat_normal',prefix+'_maps')
        ini('material_'+prefix+'_gamma',material,gamma(profile),prefix+'_diffuse',
            'EXT_normal' if prefix=='EXT_smooth' else 'COAT_smooth_normal' if prefix=='COAT_smooth' else 'flat_normal',prefix+'_maps')
    # EXT: retain opaque artwork, suppress all fine diffuse/opacity changes in glass.
    a=src['GLASS_EXT_txDiff.png'];coverage=a[...,3].astype(np.float32)/255;valid=coverage>.99
    strip=np.clip((.98-unpremul(src['GLASS_EXT_GLOSS.png'])[...,0]*255/253)/.96,0,1)*coverage
    detail=unpremul(src['GLASS_EXT_txDetail.png'])[...,0]*255
    opaque=np.maximum(strip,np.clip((detail-235)/18,0,1)*coverage)
    glass=valid & (opaque==0)
    lo,hi=np.percentile(detail[glass],[5,95]);grain=np.clip((detail-lo)/(hi-lo),0,1)
    rgb=unpremul(a)*opaque[...,None]+np.array([.085,.09,.095])*(1-opaque[...,None])
    alpha=.055*coverage*(1-opaque)+opaque
    diffuse=rgba(native.pad(rgb.astype(np.float32),valid,8),alpha)
    # Grain only changes specular intensity and reflection by a few percent.
    spec=(.80-.075*grain)*(1-opaque)+.28*opaque
    gloss=.975*(1-opaque)+.86*opaque
    reflection=(.97-.020*grain)*(1-opaque)+.18*opaque
    maps=rgba(native.pad(np.stack((spec,gloss,reflection),-1).astype(np.float32),valid,8),1)
    ext_n=np.asarray(Image.open(SOURCE/'native_multimap_test_v1/EXT_normal.png').convert('RGBA'))
    ext_levels=export('EXT_normal',ext_n,'normal')
    save_kit('EXT_smooth',diffuse,ext_levels,maps,PROFILE,'mtGLASS_EXT')
    analysis['EXT']=dict(glass_input_alpha_range=np.unique(diffuse[glass,3]).tolist(),
        glass_rgb_min=diffuse[glass,:3].min(0).tolist(),glass_rgb_max=diffuse[glass,:3].max(0).tolist(),
        glass_gloss_values=np.unique(maps[glass,1]).tolist(),
        old_diffuse_alpha_range=[int(x) for x in np.percentile(np.array(Image.open(SOURCE/'native_multimap_test_v1/EXT_balanced_diffuse.png'))[glass,3],[0,100])])
    assert np.unique(diffuse[glass,3]).size==1 and np.unique(maps[glass,1]).size==1
    assert np.max(diffuse[glass,:3].max(0)-diffuse[glass,:3].min(0))<=1
    # COAT: retain smooth macro edge haze and letters; remove all micro RGB/alpha noise.
    a=src['GLASS_COAT_SIGN.png'];coverage=a[...,3].astype(np.float32)/255;valid=coverage>.99
    def scalar(name):return np.clip(unpremul(src['GLASS_COAT_'+name+'.png'])[...,0]*255/253,0,1)
    fields=native.pad(np.stack([scalar(n) for n in ['NOISE3','NOISE1','NOISE2','SIGN','CUTPATTERN']],-1),valid,8)
    end=smooth(fields[...,0],passes=5)
    grain=np.clip((fields[...,1]-67/253)/((188-67)/253),0,1)
    letters=np.clip((1-fields[...,3])/(73/253),0,1)
    cut=fields[...,4]
    alpha=.04+.25*end+.035*cut;alpha += (1-alpha)*.32*letters
    color=np.tile(np.array([.24,.25,.26],np.float32),(*coverage.shape,1))
    color += end[...,None]*.08;color *= 1-.78*letters[...,None]
    diffuse=rgba(color,alpha*coverage)
    spec=.72-.070*grain-.10*end
    gloss=.975-.035*end
    reflection=.90-.018*grain-.06*end
    maps=rgba(np.stack((spec,gloss,reflection),-1),1)
    # Filter the encoded normal as vectors, preserving broad folds, not grain relief.
    coat_n=np.asarray(Image.open(SOURCE/'native_coating_film_test_v1/COAT_normal.png').convert('RGBA'))
    n=coat_n[...,:3].astype(np.float32)/255*2-1;n=smooth(n,passes=2)
    n[...,:2]*=.85;n/=np.maximum(np.linalg.norm(n,axis=-1,keepdims=True),1e-8)
    coat_levels=export('COAT_smooth_normal',rgba(n*.5+.5,coverage),'normal')
    save_kit('COAT_smooth',diffuse,coat_levels,maps,COAT_PROFILE,'mtGLASS_COATING')
    center=valid & (end<.01) & (letters<.01) & (cut<.01)
    analysis['COAT']=dict(center_rgb_min=diffuse[center,:3].min(0).tolist(),
        center_rgb_max=diffuse[center,:3].max(0).tolist(),center_alpha_values=np.unique(diffuse[center,3]).tolist(),
        center_gloss_values=np.unique(maps[center,1]).tolist(),normal_filter='float vector binomial low pass; XY strength 0.85')
    # STICKER: mask inversion ONLY inside original coverage. Black is a role mask, not color.
    a=src['GLASS_STICKER_txDetail.png'];coverage=a[...,3].astype(np.float32)/255
    visible=np.clip(1-unpremul(a)[...,0]*255/253,0,1)*coverage
    valid=coverage>.99;black_region=valid & (visible>.99);white_region=valid & (visible<.001)
    export('STICKER_visibility',rgba(np.repeat(visible[...,None],3,-1),1))
    uniform_maps=rgba(np.tile(np.array([.80,.97,.92],np.float32),(4,4,1)),1)
    for name,opacity in [('clear',.18),('balanced',.30),('defined',.42)]:
        color=np.tile(np.array([.43,.44,.45],np.float32),(*coverage.shape,1))
        diffuse=rgba(color,visible*opacity)
        save_kit('STICKER_'+name,diffuse,flat,uniform_maps,STICKER_PROFILE,'mtGLASS_STICKER')
        assert np.max(diffuse[white_region,3])==0
        assert np.max(diffuse[coverage==0,3])==0
        analysis['STICKER_'+name]=dict(black_input_alpha=np.unique(diffuse[black_region,3]).tolist(),
            white_input_alpha=np.unique(diffuse[white_region,3]).tolist(),outside_input_alpha=0)
    # An explicit flat-normal control helps separate mesh seams from texture folds.
    ini('material_COAT_smooth_flat_diagnostic','mtGLASS_COATING',COAT_PROFILE,
        'COAT_smooth_diffuse','flat_normal','COAT_smooth_maps')
    ini('material_EXT_smooth_flat_diagnostic','mtGLASS_EXT',PROFILE,
        'EXT_smooth_diffuse','flat_normal','EXT_smooth_maps')
    validate(variants,pixels_out,analysis,white,black,flat,black_region,white_region)
    assert before=={n:native.sha(SOURCE/n) for n in source_names}
    m=json.loads((QA/'validation.json').read_text())
    m.update(source_sha256=before,originals_unchanged_during_build=True,
             output_sha256={p.name:native.sha(p) for p in OUT.glob('*.dds')})
    (OUT/'asset_manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding='utf-8')
    shutil.copyfile(ROOT/'docs/SMOOTH_GLASS_AND_STICKER_V2.md',OUT/'README.md')
    for n in ['comparison.png','sticker_mask_preview.png','sticker_uv_inspection.png']:
        shutil.copyfile(QA/n,OUT/n)
    target=SOURCE/'GLASS_smooth_and_sticker_v2.zip'
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in sorted(OUT.iterdir()):
            if p.is_file():z.write(p,OUT.name+'/'+p.name)
    with zipfile.ZipFile(target) as z:assert z.testzip() is None
    print(json.dumps(dict(out=str(OUT),zip=str(target),analysis=analysis),ensure_ascii=False,indent=2))


def validate(variants,pixels_out,analysis,white,black,flat,black_region,white_region):
    shader=native.compile_shader(native.HEADER,'smooth_multimap_fixture')
    exe=ROOT/'docs/diagnostics/2026-10-11/native-visor-material/native_readback.exe'
    constants=dict(ksLightDirection=[0,0,-1,0],ksLightColor=[1,1,1,1],extSpecularColor=[1,1,1],
        ksAmbientColor_sky0=[.7,.7,.7,1],ksHorizonColor=[.5,.5,.5,1],ksZenithColor=[.7,.7,.7,1],
        perObjAmbientMultiplier=1,extLambertGamma_inner=1,extVAOExp=1,extFresnelGamma=1,
        extSunSpecularMult=1,extReflectionBrightness=1,extReflectionBrightnessMult=1,
        ksExposure=1,extEmissiveMults=[1,1,1,3],extIBLAmbientBaseThreshold=1,
        extMSAA=1,extClearCoat=0,extShaderFlags=0,ksNearPlane=.01,extFlags=0,extVaoMode=0,
        shadowR1=0,shadowR2=1,sceneShadowOpacity=0,fixtureAngle=0,fixtureProbe=0)
    env=native.cube();zero=[[np.zeros((1,1,4),np.float32)]]*6
    def run(label,textures,profile=PROFILE,changes=None,w=1024,h=256,environment=None):
        p=constants | profile | (changes or {}) | dict(fixtureSize=[w,h],extScreenSize=[w,h,1/w,1/h])
        params=QA/(label+'.params');params.write_text('\n'.join(k+' '+' '.join(str(v) for v in
            (a if isinstance(a,list) else [a])) for k,a in p.items()))
        inp=QA/(label+'.input');native.texture_input(inp,textures | {'txCube':env if environment is None else environment})
        dst=QA/(label+'.rgba32f')
        result=subprocess.run([str(exe),str(shader),str(inp),str(params),str(dst),str(w),str(h)],capture_output=True,text=True)
        if result.returncode:raise RuntimeError(result.stdout+result.stderr)
        a=np.fromfile(dst,'<f4').reshape(h,w,4);inp.unlink();assert np.isfinite(a).all()
        assert 0<=a[...,3].min() and a[...,3].max()<=1
        return a
    renders={}
    for name in ['EXT_smooth','COAT_smooth','STICKER_balanced']:
        p=COAT_PROFILE if name.startswith('COAT') else STICKER_PROFILE if name.startswith('STICKER') else PROFILE
        renders[name]=run(name,variants[name],p)
        renders[name+'_turned']=run(name+'_turned',variants[name],p,dict(fixtureAngle=.45))
    for family,folder in [('EXT','native_multimap_test_v1'),('COAT','native_coating_film_test_v1')]:
        old=variants[family+'_smooth'].copy()
        old['txDiffuse']=[native.mips(np.array(Image.open(SOURCE/folder/(family+'_balanced_diffuse.png'))),'color')]
        old['txMaps']=[native.mips(np.array(Image.open(SOURCE/folder/(family+'_balanced_maps.png'))))]
        renders[family+'_old_maps']=run(family+'_old_maps',old,COAT_PROFILE if family=='COAT' else PROFILE)
    # Flat fixture and no specular/environment: map details must cease affecting RGB/alpha.
    tests={}
    for family in ['EXT','COAT']:
        key=family+'_smooth';tex=variants[key] | {'txNormal':[flat]}
        p=PROFILE if family=='EXT' else COAT_PROFILE
        d,m=pixels_out[key];uniform=m.copy();uniform[...,0]=200;uniform[...,2]=240
        control=tex | {'txMaps':[native.mips(uniform)]}
        off=dict(ksSpecular=0,extSpecularColor=[0,0,0])
        actual=run(key+'_detail_off',tex,p,off,environment=zero)
        base=run(key+'_uniform_off',control,p,off,environment=zero)
        error=float(np.max(np.abs(actual-base)));assert error<1e-6
        on=run(key+'_detail_on',tex,p);on_base=run(key+'_uniform_on',control,p)
        change=float(np.max(np.abs(on-on_base)));assert change>1e-4
        tests[family]=dict(no_specular_no_environment_detail_delta=error,lit_detail_delta=change)
    def uv_at(mask):
        y,x=np.where(mask);i=len(x)//2
        return [(float(x[i])+.5)/4096,(float(y[i])+.5)/1024]
    black_uv=uv_at(black_region);white_uv=uv_at(white_region)
    probes={}
    for label,uv in [('black',black_uv),('white',white_uv),('outside',[.5,.01])]:
        for angle in [0,75]:
            key=label+'_'+str(angle)
            probes[key]=run('sticker_'+key,variants['STICKER_balanced'],STICKER_PROFILE,
                dict(fixtureProbe=1,fixtureUV=uv,fixtureAngle=float(np.deg2rad(angle))),w=1,h=1)[0,0].tolist()
    assert probes['white_0'][3]==0 and probes['white_75'][3]==0
    assert probes['outside_0'][3]==0 and probes['outside_75'][3]==0
    assert .29<probes['black_0'][3]<.31
    dark=dict(fixtureProbe=1,fixtureUV=black_uv,ksLightColor=[0,0,0,0],extSpecularColor=[0,0,0],
        ksAmbientColor_sky0=[0,0,0,0],ksHorizonColor=[0,0,0,0],ksZenithColor=[0,0,0,0])
    probes['dark']=run('sticker_dark',variants['STICKER_balanced'],STICKER_PROFILE,dark,w=1,h=1,environment=zero)[0,0].tolist()
    assert max(abs(v) for v in probes['dark'][:3])<1e-6
    shader=native.compile_shader('#define GAMMA_FIX 1\n'+native.HEADER,'smooth_multimap_fixture_gamma')
    for name,p,uv in [('EXT_smooth',PROFILE,[.5,.4]),('COAT_smooth',COAT_PROFILE,[.5,.4]),
                      ('STICKER_balanced',STICKER_PROFILE,black_uv)]:
        probes[name+'_gamma']=run(name+'_gamma_probe',variants[name],gamma(p),
            dict(fixtureProbe=1,fixtureUV=uv),w=1,h=1)[0,0].tolist()
    y,x=np.mgrid[:256,:1024];checker=((x//32+y//32)%2)[...,None]
    bg=np.array([.12,.15,.17])+checker*np.array([.28,.27,.24])
    order=['EXT_old_maps','EXT_smooth','EXT_smooth_turned','COAT_old_maps','COAT_smooth','COAT_smooth_turned']
    board=Image.new('RGB',(1024,len(order)*288),(22,24,28));draw=ImageDraw.Draw(board)
    for i,name in enumerate(order):
        a=renders[name];rgb=np.clip(a[...,:3]*a[...,3:4]+bg*(1-a[...,3:4]),0,1)
        im=Image.fromarray(np.uint8(np.rint(rgb*255)));im.save(QA/(name+'_preview.png'))
        board.paste(im,(0,i*288+28));draw.text((10,i*288+8),name+' / controlled native fixture',fill='white')
    board.save(QA/'comparison.png')
    a=renders['STICKER_balanced'];image=np.clip(a[...,:3]*a[...,3:4]+bg*(1-a[...,3:4]),0,1)
    Image.fromarray(np.uint8(np.rint(image*255))).save(QA/'sticker_mask_preview.png')
    manifest=dict(shader='ksPerPixelMultiMap_emissive',profiles=dict(EXT=PROFILE,COAT=COAT_PROFILE,STICKER=STICKER_PROFILE),
        map_channel_roles=dict(R='specular strength',G='exponent/reflection blur',B='reflection strength',A='unused'),
        analysis=analysis,detail_isolation=tests,sticker_gpu_probes=probes,
        scope='Local native HLSL on D3D11 WARP; synthetic UV cylinder/studio cube; no in-game sorting/mesh normal validation.')
    (QA/'validation.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')


if __name__=='__main__':main()
