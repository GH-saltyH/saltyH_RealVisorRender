"""Actual D3D11 shaders: bounded bins, smear, scene/native depth and coverage."""
from pathlib import Path
import re,json,struct,subprocess,tempfile,time
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s65'
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text(encoding='utf-8')
env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')}
exec(base[:base.index('report=[]')],env);env['OUT']=OUT
render=env['render'];inline=env['inline'];types=env['types']
lua=(ROOT/'realvisor.lua').read_text(encoding='utf-8');old=(OUT/'baseline/realvisor.lua').read_text(encoding='utf-8')
metric=(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text()
report=[]
def dds(k):return np.frombuffer((ROOT/f'texture/RAIN_GEOMETRY/{k}.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
geo={'txRainDu':dds('du'),'txRainDv':dds('dv'),'txRainBoundaryMask':np.asarray(Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').convert('RGBA'),np.float32)/255}
count=384;size=512
sites=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/spawn_sites.dds').read_bytes(),'<f4',offset=148).reshape(1,8192,4)
states=sites[:,:count,:].copy();states[:,:,1]-=1;states[:,:,2:]=(.1,-.06)
meta=np.zeros_like(states);meta[:,:,0]=np.linspace(.00065,.005,count);meta[:,:,3]=5
values={'gCount':count,'gSize':size,'gRainMetersPerUnit':.001/.0029296875,'gRainReferencePerMM':.0029296875,
 'gKs':1.45,'gMaxRadii':1.3,'gPuddleReach':1.07,'gUvPerMM':.0029296875,'gBodyStretch':1,'gLookback':.03,
 'gShapeOn':1,'gShapeStrength':.8,'gPuddleOn':1,'gPuddleMinMM':1,'gPuddleShare':.3,
 'gLobesOn':1,'gStretchGain':1,'gSummaryWords':1,'gWords':4}
frames=render('metric',metric+inline(lua,'rainDynamicSceneCopyState.gpuMetricShader ='),{**geo,'txRainState':states},values,(count,1))
tx={**geo,'txRainState':states,'txRainStateMeta':meta,'txRainDropMetric':frames,'txOverride':np.zeros_like(states)}
common=inline(lua,'rainDynamicSceneCopyState.gpuHeadsCommon =')
tx['txRainDropBounds']=render('bounds',common+inline(lua,'rainDynamicSceneCopyState.gpuBoundsShader ='),tx,values,(count,3))
def heads(source,tile,sparse):
    values.update(gTilesX=size//tile,gTilesY=size//(tile*4),gMaskW=size//tile*4,gTile=(tile,tile*4),gSparseWords=int(sparse),gSummaryW=size//tile)
    cm=inline(source,'rainDynamicSceneCopyState.gpuHeadsCommon =')
    tx['txMask']=render('tiles',metric+cm+inline(source,'rainDynamicSceneCopyState.gpuHeadsPassA ='),tx,values,(values['gMaskW'],values['gTilesY']))
    tx['txSummary']=render('summary',inline(lua,'rainDynamicSceneCopyState.gpuHeadsSummaryPass ='),tx,values,(values['gSummaryW'],values['gTilesY']))
    bits=tx['txMask'].astype(np.uint32)
    candidates=sum(int(x).bit_count() for x in bits.ravel())/(values['gTilesX']*values['gTilesY'])
    result=render('heads',metric+cm+inline(source,'rainDynamicSceneCopyState.gpuHeadsPassB ='),tx,values,(size,size//4))
    return result,candidates
a,old_candidates=heads(old,64,False)
b,new_candidates=heads(lua,32,True)
assert np.max(abs(a[:,:,:3]-b[:,:,:3]))<2e-6,(np.max(abs(a[:,:,:3]-b[:,:,:3])))
assert np.max(b[:,:,1])>.2
report.append({'case':'actual 64px dense to 32px sparse bounds bins: identical water RGB','max_delta':float(np.max(abs(a[:,:,:3]-b[:,:,:3]))),
 'mean_candidates_old':old_candidates,'mean_candidates_new':new_candidates,'slots':count})
# Same-generation physical motion supplies an independent swept A field.
previous=states.copy();previous[:,:,:2]-=states[:,:,2:]*.016
tx.update(txRainPreviousState=previous,txRainPreviousMeta=meta)
values.update(gSweepEnabled=1,gSweepWidthScale=.98,gSweepMinRadius=.125,gSweepWidthOffset=0)
tx['txRainDropBounds']=render('swept_bounds',common+inline(lua,'rainDynamicSceneCopyState.gpuBoundsShader ='),tx,values,(count,3))
c,swept_candidates=heads(lua,32,True)
assert np.max(abs(b[:,:,:3]-c[:,:,:3]))<2e-6
assert np.max(c[:,:,3])>.2
wipe=render('swept_wipe',inline(lua,'            gRidgeDecay = ridgeDecay,'),
    {'txWipePrevious':np.zeros_like(c),'txWipeSwept':c},{'gWipeSwept':1,'gWipeDecay':.3,'gRidgeDecay':.9},(512,128))
assert np.max(wipe[:,:,1])>.9 and np.max(wipe[:,:,0])==0
assert np.all(wipe[c[:,:,3]==0,1]==0)
report.append({'case':'swept GPU wipe survives zero CPU stamps/short recovery without changing water RGB',
 'swept_fraction':float(np.mean(c[:,:,3]>.001)),'mean_candidates':swept_candidates})
values['gSweepEnabled']=0
import sys
if '--heads-only' in sys.argv:
    (OUT/'head_checks.json').write_text(json.dumps(report,indent=2))
    for row in report:print(json.dumps(row),flush=True)
    sys.exit(0)

# Use the production compiled source/header to exercise all new bindings and
# all main shader branches, with packed mesh UV exactly as submitted by Lua.
full=(OUT/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8')
compiled={}
def full_render(name,source,textures,values,size=(256,64)):
    source=source.replace('float4 main(PS_IN pin):SV_TARGET','float4 production(PS_IN pin)')
    # FXC issues X4000 only after packing constant visor UV in this artificial
    # caller (production shader itself is separately compiled with /WX).
    source='#pragma warning(disable:4000)\n'+source
    source+='''
float2 testSize;
float4 main(float4 pixel:SV_POSITION):SV_TARGET {
    PS_IN pin;pin.PosH=pixel;pin.Tex=pixel.xy/testSize+float2(-4,-1);
    pin.PosC=float3(0,0,.2);pin.NormalW=float3(0,0,-1);return production(pin);
}'''
    with tempfile.TemporaryDirectory(prefix='full_',dir=OUT) as tmp:
        tmp=Path(tmp);p=tmp/'source.hlsl';cso=tmp/'shader.cso';p.write_text(source,encoding='utf-8')
        if source not in compiled:
            compile=subprocess.run([env['FXC'],'/nologo','/T','ps_5_0','/E','main','/Ges','/WX','/Fo',str(cso),str(p)],capture_output=True,text=True)
            assert compile.returncode==0,compile.stdout+compile.stderr
            compiled[source]=cso.read_bytes()
        else:cso.write_bytes(compiled[source])
        names=re.findall(r'^Texture2D (\w+);',source,re.M)
        inputs=tmp/'textures.bin'
        with inputs.open('wb') as f:
            f.write(struct.pack('<I',len(names)))
            for n in names:
                v=textures.get(n,np.zeros((1,1,4),np.float32));h,w,_=v.shape;key=n.encode()
                f.write(struct.pack('<I',len(key))+key+struct.pack('<4I',w,h,1,1)+v.astype('<f4').tobytes())
        values={**values,'testSize':size,'gDynamicDropInvRenderTargetSize':(1/size[0],1/size[1]),'gDynamicDropInvScreenSize':(1/size[0],1/size[1])}
        params=tmp/'params';params.write_text('\n'.join(k+' '+' '.join(map(str,np.atleast_1d(v))) for k,v in values.items()))
        out=tmp/'out';subprocess.run([str(env['EXE']),str(cso),str(inputs),str(params),str(out),*map(str,size)],check=True,stdout=subprocess.PIPE)
        a=np.frombuffer(out.read_bytes(),'<f4').reshape(size[1],size[0],4);assert np.isfinite(a).all(),name
        return a
y,x=np.mgrid[:64,:256]
scene=np.stack((x/256,y/64,(x%16)/16,np.ones_like(x)),axis=-1).astype(np.float32)
du=np.zeros_like(scene);du[:,:,0]=.3;du[:,:,3]=100
dv=np.zeros_like(scene);dv[:,:,1]=.2;dv[:,:,3]=1
mask=np.ones_like(scene);smear=mask.copy();smear[:,:,0]=.1
smear[:,:,1]=(np.floor(x/4)%2)*.25+.35
tx={'txRainDu':du,'txRainDv':dv,'txRainBoundaryMask':mask,'txDynamicSnapshot':scene,'txDynamicWeatherScreen':smear}
v={'gRainMetersPerUnit':.001/.0029296875,'gRainReferencePerMM':.0029296875,'gDynamicDropSmear':1,
 'gDynamicDropSmearTexture':1,'gDynamicDropSmearRTiling':1,'gDynamicDropSmearGTiling':1,
 'gDynamicDropSmearIntensity':1,'gDynamicDropSmearGContrast':1,'gDynamicDropSmearGGamma':1,
 'gDynamicDropSmearGPivot':.5,'gDynamicDropSmearEdgeSoft':.1,'gDynamicDropSmearClasses':4,
 'gDynamicDropSmearClassSoft':.35,'gDynamicDropSmearEraseSpan':1,'gDynamicDropSmearFacetAlpha':.5,
 'gDynamicDropSmearFacetPixels':8,'gDynamicDropSmearToneRange':.1,'gDynamicDropCameraForward':(0,0,1)}
a=full_render('smear',full,tx,v);assert np.max(a[:,:,3])>.1
types['gSmearTiling']='float2'
cache=render('smear_bake',inline(lua,'rainDynamicSceneCopyState.smearBake ='),
    {'txSmearSource':smear},{'gSmearTiling':(1,1)},(256,64))
b=full_render('smear_cached',full,{**tx,'txDynamicWeatherScreen':cache},{**v,'gDynamicDropSmearBaked':1})
assert np.max(abs(a-b))<2e-5,np.max(abs(a-b))
report.append({'case':'production filtered 4:1 bake matches live filtering and mixing','max_delta':float(np.max(abs(a-b)))})
depth=np.zeros_like(scene);depth[:,:,0]=10000
tx['txDynamicOcclusion']=depth
b=full_render('background_depth',full,tx,{**v,'gDynamicDropOcclusionOn':1});assert np.array_equal(a,b)
depth[:,:,0]=.1
b=full_render('foreground_depth',full,tx,{**v,'gDynamicDropOcclusionOn':1});assert np.max(abs(b))==0
depth[:,:,0]=10000;depth[:,:,1]=.1
b=full_render('native_front',full,tx,{**v,'gDynamicDropOcclusionOn':1});assert np.max(abs(b))==0
depth[:,:,1]=.3
b=full_render('native_behind',full,tx,{**v,'gDynamicDropOcclusionOn':1});assert np.array_equal(a,b)
report.append({'case':'full production rain clips closer opaque/native depths and preserves behind output','smear_alpha':float(np.max(a[:,:,3]))})

# Shader-program coverage equality: show surviving fragments as white. The
# colour contribution is deliberately discarded; only clip decisions count.
coverage=full.replace('    return c;\n}', '    return float4(1,1,1,1);\n}')
new=coverage.replace('    return float4(0,0,0,0);\n#endif','    return float4(1,1,1,1);\n#endif')
head=np.zeros_like(scene);head[:,:,1]=np.linspace(0,1,256);head[:,:,0]=head[:,:,1]*.08
tx['txDynamicBirthMask']=head
v.update(gDynamicDropWaterField=1,gDynamicDropWFThreshold=.35,gDynamicDropWFOpacity=.9,
 gDynamicDropWFInvMaskSize=1/256,gDynamicDropWFHeadStep=1/256,gDynamicDropDepthOnly=1,
 gDynamicDropDepthExact=1,gDynamicDropDepthAlphaMin=.7)
a=full_render('old_exact_depth',coverage,tx,v)
b=full_render('specialized_depth','#define RAIN_DEPTH_ONLY 1\n'+new,tx,v)
assert np.array_equal(a,b),np.max(abs(a-b))
assert np.any(a[:,:,0]>0) and np.any(a[:,:,0]==0)
report.append({'case':'specialized depth has identical actual full-shader coverage','surviving_fraction':float(np.mean(a[:,:,0]>0))})
v['gDynamicDropHazeDepthMin']=.3
a=full_render('old_haze_depth',coverage,tx,v)
b=full_render('new_haze_depth','#define RAIN_DEPTH_ONLY 1\n'+new,tx,v)
assert np.array_equal(a,b)
report.append({'case':'specialized depth also preserves enabled haze/flow coverage'})
(OUT/'gpu_checks.json').write_text(json.dumps(report,indent=2))
for row in report:print(json.dumps(row),flush=True)
print('PASS: production bins, full rain occlusion and exact specialized depth')
