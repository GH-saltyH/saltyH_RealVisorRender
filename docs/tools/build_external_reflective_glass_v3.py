"""External visor: reflective outer film, independently recolorable dark EXT.

Uses the actual local MultiMap HLSL and D3D11 WARP, not an in-game capture.
Numerical texture processing; original assets and FBX material settings are inputs.
"""
from pathlib import Path
import argparse
import json
import shutil
import subprocess
import zipfile
import numpy as np
from PIL import Image, ImageDraw
import test_visor_native_multimap as native
import build_smooth_glass_and_sticker as smooth

ROOT, SOURCE = native.ROOT, native.SOURCE
PREVIOUS = SOURCE/'native_smooth_glass_sticker_v2'
OUT = SOURCE/'native_external_reflective_glass_v3'
QA = ROOT/'docs/diagnostics/2026-10-11/external-reflective-glass-v3'
ZIP = SOURCE/'GLASS_external_reflective_v3.zip'
EXT_OPACITY = .72
EXT_PROFILE = smooth.PROFILE | dict(ksAmbient=.15, ksDiffuse=.20,
    ksSpecular=.25, fresnelC=.02, fresnelEXP=5, fresnelMaxLevel=.16)
COAT_PROFILE = smooth.COAT_PROFILE | dict(ksAmbient=.08, ksDiffuse=.12,
    ksSpecular=.90, fresnelC=.32, fresnelEXP=4, fresnelMaxLevel=.85)


def read(path):
    return np.asarray(Image.open(path).convert('RGBA'))


def unpremul(a):
    return a[...,:3].astype(np.float32)/np.maximum(a[...,3:4]/255,1e-6)/255


def rgb_argument(value):
    result=[int(x) for x in value.split(',')]
    if len(result)!=3 or any(x<0 or x>255 for x in result):
        raise argparse.ArgumentTypeError('RGB must be three byte values, e.g. 4,4,4')
    return result


def prepare():
    OUT.mkdir(exist_ok=True); QA.mkdir(parents=True,exist_ok=True)
    smooth.OUT = native.OUT = OUT
    native.QA = QA


def ext_pixels(tint):
    # Established pattern segmentation: dark upper strip and white isolated badge.
    # The file names do not determine shader channel semantics.
    source=read(SOURCE/'GLASS_EXT_txDiff.png')
    coverage=source[...,3].astype(np.float32)/255; valid=coverage>.99
    strip=np.clip((.98-unpremul(read(SOURCE/'GLASS_EXT_GLOSS.png'))[...,0]*255/253)/.96,0,1)*coverage
    detail=unpremul(read(SOURCE/'GLASS_EXT_txDetail.png'))[...,0]*255
    opaque=np.maximum(strip,np.clip((detail-235)/18,0,1)*coverage)
    rgb=unpremul(source)*opaque[...,None]+np.asarray(tint,np.float32)/255*(1-opaque[...,None])
    alpha=EXT_OPACITY*coverage*(1-opaque)+opaque
    diffuse=smooth.rgba(native.pad(rgb.astype(np.float32),valid,8),alpha)
    # Opaque artwork retains the previous map; glass has no micro variation.
    old=read(PREVIOUS/'EXT_smooth_maps.png')[...,:3].astype(np.float32)/255
    values=old*opaque[...,None]+np.array([.40,1,.25],np.float32)*(1-opaque[...,None])
    maps=smooth.rgba(native.pad(values.astype(np.float32),valid,8),1)
    glass=valid&(opaque==0)
    return diffuse,maps,opaque,glass,coverage


def package():
    shutil.copyfile(ROOT/'docs/EXTERNAL_REFLECTIVE_GLASS_V3.md',OUT/'README.md')
    with zipfile.ZipFile(ZIP,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in sorted(OUT.iterdir()):
            if p.is_file(): z.write(p,OUT.name+'/'+p.name)
    with zipfile.ZipFile(ZIP) as z: assert z.testzip() is None


def tint_only(tint):
    manifest=json.loads((OUT/'asset_manifest.json').read_text(encoding='utf-8'))
    old=read(OUT/'EXT_dark_diffuse.png')
    protected={p.name:native.sha(p) for p in OUT.glob('*.dds') if p.name!='EXT_dark_diffuse.dds'}
    diffuse,_,opaque,glass,_=ext_pixels(tint)
    assert np.array_equal(old[...,3],diffuse[...,3])
    assert np.array_equal(old[opaque>=.999,:3],diffuse[opaque>=.999,:3])
    smooth.export('EXT_dark_diffuse',diffuse,'color')
    assert protected=={name:native.sha(OUT/name) for name in protected}
    manifest['tint_rgb_u8']=tint
    manifest['analysis'].update(tint_rgb_u8=tint,
        EXT_glass_rgb_min=diffuse[glass,:3].min(0).tolist(),
        EXT_glass_rgb_max=diffuse[glass,:3].max(0).tolist())
    manifest['output_sha256']={p.name:native.sha(p) for p in OUT.glob('*.dds')}
    manifest['recolor_verification']=dict(alpha_byte_identical=True,opaque_artwork_byte_identical=True,
        all_other_dds_byte_identical=True,glass_rgb_min=diffuse[glass,:3].min(0).tolist(),
        glass_rgb_max=diffuse[glass,:3].max(0).tolist())
    manifest['preview_note']='comparison.png and native probes are the original black-tint baseline.'
    (OUT/'asset_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tint-rgb',type=rgb_argument)
    parser.add_argument('--tint-only',action='store_true',help='Rebuild only EXT diffuse RGB; preserve opacity and every other DDS.')
    args=parser.parse_args(); prepare()
    settings=OUT/'tint_settings.json'
    tint=args.tint_rgb or (json.loads(settings.read_text(encoding='utf-8'))['tint_rgb_u8'] if settings.exists() else [4,4,4])
    if len(tint)!=3 or any(type(x)!=int or not 0<=x<=255 for x in tint): raise ValueError('Invalid tint_rgb_u8')
    if args.tint_only:
        tint_only(tint)
        settings.write_text(json.dumps(dict(tint_rgb_u8=tint),indent=2)+'\n',encoding='utf-8')
        package()
        print(json.dumps(dict(out=str(OUT),tint_rgb_u8=tint,mode='tint-only',zip=str(ZIP)),ensure_ascii=False))
        return
    inputs=[SOURCE/n for n in ['GLASS_EXT_txDiff.png','GLASS_EXT_GLOSS.png','GLASS_EXT_txDetail.png']]
    inputs += [PREVIOUS/n for n in ['EXT_normal.png','COAT_smooth_normal.png','COAT_smooth_diffuse.png',
        'EXT_smooth_maps.png','EXT_smooth_diffuse.png','COAT_smooth_maps.png','neutral_white.png','neutral_black.png','flat_normal.png']]
    before={str(p.relative_to(SOURCE)):native.sha(p) for p in inputs}
    white=smooth.export('neutral_white',read(PREVIOUS/'neutral_white.png'))
    black=smooth.export('neutral_black',read(PREVIOUS/'neutral_black.png'))
    flat=smooth.export('flat_normal',read(PREVIOUS/'flat_normal.png'),'normal')
    ext_n=smooth.export('EXT_normal',read(PREVIOUS/'EXT_normal.png'),'normal')
    coat_n=smooth.export('COAT_smooth_normal',read(PREVIOUS/'COAT_smooth_normal.png'),'normal')
    diffuse,maps,opaque,glass,coverage=ext_pixels(tint)
    ext_d=smooth.export('EXT_dark_diffuse',diffuse,'color'); ext_m=smooth.export('EXT_dark_maps',maps)
    mask=smooth.rgba(np.repeat((1-opaque)[...,None],3,-1),coverage)
    Image.fromarray(mask).save(OUT/'EXT_tint_region_mask.png')
    coat_d=smooth.export('COAT_reflective_diffuse',read(PREVIOUS/'COAT_smooth_diffuse.png'),'color')
    # Constant 4x4 map: sharp and strong throughout the whole film, including ends.
    coat_map=np.tile(np.array([230,255,255,255],np.uint8),(4,4,1))
    coat_m=smooth.export('COAT_reflective_maps',coat_map)
    for family,material,profile,d,n,m in [
        ('EXT_dark','mtGLASS_EXT',EXT_PROFILE,'EXT_dark_diffuse','EXT_normal','EXT_dark_maps'),
        ('COAT_reflective','mtGLASS_COATING',COAT_PROFILE,'COAT_reflective_diffuse','COAT_smooth_normal','COAT_reflective_maps')]:
        smooth.ini('material_'+family,material,profile,d,n,m)
        smooth.ini('material_'+family+'_gamma',material,smooth.gamma(profile),d,n,m)
    common=dict(txDetail=[white],txEmissive=[black])
    kits=dict(EXT_dark=common|dict(txDiffuse=[ext_d],txNormal=[ext_n],txMaps=[ext_m]),
        COAT_reflective=common|dict(txDiffuse=[coat_d],txNormal=[coat_n],txMaps=[coat_m]))
    analysis=dict(tint_rgb_u8=tint,EXT_input_alpha=np.unique(diffuse[glass,3]).tolist(),
        EXT_glass_rgb_min=diffuse[glass,:3].min(0).tolist(),EXT_glass_rgb_max=diffuse[glass,:3].max(0).tolist(),
        EXT_glass_map_values=[np.unique(maps[glass,i]).tolist() for i in range(3)],
        COAT_maps_rgba=coat_map[0,0].tolist(),COAT_map_resolution=[4,4],
        coat_diffuse_identical_to_v2=np.array_equal(read(OUT/'COAT_reflective_diffuse.png'),read(PREVIOUS/'COAT_smooth_diffuse.png')),
        normals_identical_to_v2=True)
    assert np.array_equal(read(OUT/'EXT_normal.png'),read(PREVIOUS/'EXT_normal.png'))
    assert np.array_equal(read(OUT/'COAT_smooth_normal.png'),read(PREVIOUS/'COAT_smooth_normal.png'))
    assert np.unique(diffuse[glass,3]).size==1
    report=validate(kits,flat,analysis)
    assert before=={str(p.relative_to(SOURCE)):native.sha(p) for p in inputs}
    report.update(source_sha256=before,originals_unchanged_during_build=True,
        output_sha256={p.name:native.sha(p) for p in OUT.glob('*.dds')},tint_rgb_u8=tint)
    (OUT/'asset_manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    settings.write_text(json.dumps(dict(tint_rgb_u8=tint),indent=2)+'\n',encoding='utf-8')
    shutil.copyfile(QA/'comparison.png',OUT/'comparison.png')
    package()
    print(json.dumps(dict(out=str(OUT),zip=str(ZIP),analysis=analysis,tests=report['probes']),ensure_ascii=False,indent=2))


def validate(kits,flat,analysis):
    shader=native.compile_shader(native.HEADER,'external_reflective_fixture')
    exe=ROOT/'docs/diagnostics/2026-10-11/native-visor-material/native_readback.exe'
    constants=dict(ksLightDirection=[.35,-.3,-.88741197,0],ksLightColor=[1,1,1,1],extSpecularColor=[1,1,1],
        ksAmbientColor_sky0=[.7,.7,.7,1],ksHorizonColor=[.5,.5,.5,1],ksZenithColor=[.7,.7,.7,1],
        perObjAmbientMultiplier=1,extLambertGamma_inner=1,extVAOExp=1,extFresnelGamma=1,
        extSunSpecularMult=1,extReflectionBrightness=1,extReflectionBrightnessMult=1,
        ksExposure=1,extEmissiveMults=[1,1,1,3],extIBLAmbientBaseThreshold=1,
        extMSAA=1,extClearCoat=0,extShaderFlags=0,ksNearPlane=.01,extFlags=0,extVaoMode=0,
        shadowR1=0,shadowR2=1,sceneShadowOpacity=0,fixtureAngle=0,fixtureProbe=0)
    zero=[[np.zeros((1,1,4),np.float32)]]*6
    whitecube=[[np.ones((1,1,4),np.float32)]]*6
    env=native.cube()
    # Colored surroundings and distinct straight boundaries augment the studio cube.
    for face in env:
        a=face[0];h,w=a.shape[:2];y,x=np.mgrid[:h,:w]
        band=((x//24+y//32)%2)[...,None]
        a[...,:3]+=np.array([.12,.18,.23])+band*np.array([.10,.03,.02])
        face[0]=a
        for i in range(1,len(face)):
            prev=face[i-1]
            face[i]=native.resize_float(prev,(max(1,prev.shape[1]//2),max(1,prev.shape[0]//2)))

    def run(label,tex,p,changes=None,w=1024,h=256,environment=None):
        params=constants|p|(changes or {})|dict(fixtureSize=[w,h],extScreenSize=[w,h,1/w,1/h])
        pp=QA/(label+'.params');pp.write_text('\n'.join(k+' '+' '.join(str(v) for v in
            (a if isinstance(a,list) else [a])) for k,a in params.items()))
        inp=QA/(label+'.input');native.texture_input(inp,tex|dict(txCube=env if environment is None else environment))
        dst=QA/(label+'.rgba32f')
        r=subprocess.run([str(exe),str(shader),str(inp),str(pp),str(dst),str(w),str(h)],capture_output=True,text=True)
        if r.returncode: raise RuntimeError(r.stdout+r.stderr)
        result=np.fromfile(dst,'<f4').reshape(h,w,4);inp.unlink()
        assert np.isfinite(result).all() and result[...,3].min()>=0 and result[...,3].max()<=1
        return result

    old={}
    for family,n in [('EXT','EXT_normal'),('COAT','COAT_smooth_normal')]:
        old[family]=kits['EXT_dark' if family=='EXT' else 'COAT_reflective']|dict(
            txDiffuse=[native.mips(read(PREVIOUS/(family+'_smooth_diffuse.png')),'color')],
            txNormal=[native.mips(read(PREVIOUS/(n+'.png')),'normal')],
            txMaps=[native.mips(read(PREVIOUS/(family+'_smooth_maps.png')))])
    profiles=dict(EXT_dark=EXT_PROFILE,COAT_reflective=COAT_PROFILE)
    renders={}
    for label,ext,coat,ep,cp in [('v2',old['EXT'],old['COAT'],smooth.PROFILE,smooth.COAT_PROFILE),
        ('v3',kits['EXT_dark'],kits['COAT_reflective'],EXT_PROFILE,COAT_PROFILE)]:
        for suffix,angle in [('',0),('_turned',.45)]:
            renders[label+suffix]=(run(label+'_EXT'+suffix,ext,ep,dict(fixtureAngle=angle)),
                run(label+'_COAT'+suffix,coat,cp,dict(fixtureAngle=angle)))
    # Isolate reflection, with flat normal and identical UV: actual native output.
    probes={}
    off=dict(ksLightColor=[0,0,0,0],extSpecularColor=[0,0,0],
        ksAmbientColor_sky0=[0,0,0,0],ksHorizonColor=[0,0,0,0],ksZenithColor=[0,0,0,0],
        fixtureProbe=1,fixtureUV=[.5,.4])
    for angle in [0,60,75]:
        records={}
        for label,ext,coat,ep,cp in [('v2',old['EXT'],old['COAT'],smooth.PROFILE,smooth.COAT_PROFILE),
            ('v3',kits['EXT_dark'],kits['COAT_reflective'],EXT_PROFILE,COAT_PROFILE)]:
            options=off|dict(fixtureAngle=float(np.deg2rad(angle)))
            e=run(label+'_EXT_probe_'+str(angle),ext|dict(txNormal=[flat]),ep,options,1,1,zero)[0,0]
            c=run(label+'_COAT_probe_'+str(angle),coat|dict(txNormal=[flat]),cp,options,1,1,whitecube)[0,0]
            records[label]=dict(EXT_alpha=float(e[3]),COAT_alpha=float(c[3]),
                background_transmission=float((1-e[3])*(1-c[3])),
                COAT_composited_white_environment_response=float(c[0]*c[3]))
        probes[str(angle)]=records
    assert probes['0']['v3']['background_transmission']<.20
    assert probes['0']['v3']['COAT_composited_white_environment_response']>20*probes['0']['v2']['COAT_composited_white_environment_response']
    assert probes['75']['v3']['background_transmission']<probes['0']['v3']['background_transmission']
    # Colored diffuse substitution leaves both opacity and white environment reflection unchanged.
    for name in ['EXT_dark','COAT_reflective']:
        tex=kits[name]|dict(txNormal=[flat]);p=profiles[name]
        d=np.tile(np.array([255,0,0,184],np.uint8),(4,4,1))
        original=run(name+'_neutral_reflection',tex,p,off,1,1,whitecube)[0,0]
        colored=run(name+'_red_reflection',tex|dict(txDiffuse=[native.mips(d,'color')]),p,off,1,1,whitecube)[0,0]
        error=float(np.max(np.abs(original[:3]-colored[:3])))
        assert error<1e-6
        probes[name+'_tint_independent_reflection_delta']=error
    shader=native.compile_shader('#define GAMMA_FIX 1\n'+native.HEADER,'external_reflective_fixture_gamma')
    for name,p in profiles.items():
        a=run(name+'_gamma_probe',kits[name]|dict(txNormal=[flat]),smooth.gamma(p),off,1,1,whitecube)[0,0]
        probes[name+'_gamma_rgba']=a.tolist()
    # Numerical compositing in physically separate order: interior -> EXT -> COAT.
    y,x=np.mgrid[:256,:1024]
    checker=((x//32+y//32)%2)[...,None]
    bg=np.array([.12,.15,.17])+checker*np.array([.28,.27,.24])
    def over(a,b): return a[...,:3]*a[...,3:4]+b*(1-a[...,3:4])
    order=['v2','v3','v3_turned']
    board=Image.new('RGB',(1024,len(order)*290),(22,24,28));draw=ImageDraw.Draw(board)
    for i,label in enumerate(order):
        e,c=renders[label];rgb=over(c,over(e,bg))
        im=Image.fromarray(np.uint8(np.rint(np.clip(rgb,0,1)*255)))
        im.save(QA/(label+'_stack.png'));board.paste(im,(0,i*290+30))
        draw.text((10,i*290+9),label+' | interior -> EXT -> COAT | native HLSL synthetic fixture',fill='white')
    board.save(QA/'comparison.png')
    report=dict(shader='ksPerPixelMultiMap_emissive',profiles=profiles,analysis=analysis,probes=probes,
        texture_channels=dict(R='specular strength',G='specular exponent / added reflection blur',B='reflection strength',A='unused'),
        scope='Local native HLSL on D3D11 WARP; synthetic UV cylinder/studio cube; not a helmet or in-game capture.')
    (QA/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    return report


if __name__=='__main__': main()
