"""Compile the actual Lua inline physics/transport and file rain shaders."""
from pathlib import Path
import re,subprocess,json,sys,time
ROOT=Path(__file__).resolve().parents[2];lua=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
OUT=ROOT/(sys.argv[2] if len(sys.argv)>2 else 'docs/diagnostics/2026-10-12/s67/shaders');OUT.mkdir(parents=True,exist_ok=True)
metric=(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text()
fxc='C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe'
types={}
for name,kind in re.findall(r'\b(g\w+)\s*=\s*(vec2|vec3|vec4|rgbm|rgb|mat4x4)',lua):
    types[name]={'vec2':'float2','vec3':'float3','vec4':'float4','rgbm':'float4','rgb':'float3','mat4x4':'float4x4'}[kind]
types.update(gRainObjectToWorld='float4x4',gRainAcceleration='float3',gRainAirVelocityWorld='float3',
 gDynamicDropWeatherFogColor='float3',gMirrorLightDirection='float3',gMirrorLightColor='float3',
 gDynamicDropCameraSide='float3',gDynamicDropCameraUp='float3',gDynamicDropCameraForward='float3',
 gImpactObjectStep='float3',gMicroSearch='float2')
types.update({k:'float3' for k in ('gLayerColor','gLayerSun','gLayerBounce','gLayerAmbSky','gLayerAmbHorizon',
 'gLayerLightDir','gLayerCameraSide','gLayerCameraUp','gLayerCameraLook')})
types['gNewTrailPixelUV']='float2';types['gTile']='float2'
def inline(anchor):
    start=lua.index(anchor);a=lua.index('[[',start)+2;b=lua.index(']]',a);return lua[a:b]
passes={}
for name in ['rainStateUpdateParams','rainStateMetaUpdateParams']:
    code=inline('local '+name+' = {')
    for define in ['', '#define RAIN_MERGE_CODE 1\n#define RAIN_WETPATH_CODE 1\n']:
        passes[name+('_full' if define else '_base')]=define+metric+code
common=inline('rainDynamicSceneCopyState.gpuHeadsCommon =')
passes['gpuBounds']=common+inline('rainDynamicSceneCopyState.gpuBoundsShader =')
passes['gpuSummary']=inline('rainDynamicSceneCopyState.gpuHeadsSummaryPass =')
passes['gpuMetric']=metric+inline('rainDynamicSceneCopyState.gpuMetricShader =')
passes['stateReadback']=inline('local RAIN_DYNAMIC_STATE_READBACK_HLSL =')
passes['gpuHeadsPassA']=inline('rainDynamicSceneCopyState.gpuHeadsPassA =')
passes['gpuHeadsPassB']=metric+common+inline('rainDynamicSceneCopyState.gpuHeadsPassB =')
passes['rainVisorDynamicDrop']=metric+(ROOT/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8')
passes['rainDepthCoverage']='#define RAIN_DEPTH_ONLY 1\n'+passes['rainVisorDynamicDrop']
passes['rainWrapped']=passes['rainVisorDynamicDrop'].replace('float4 main(PS_IN pin)','float4 rainProduction(PS_IN pin)')+'''
float4 main(PS_IN pin) {
    pin.Tex+=float2(-4,-1);
    return rainProduction(pin);
}'''
passes['rainSurfaceDiagnostic']='#define RAIN_SURFACE_DEBUG 1\n'+passes['rainWrapped']
passes['rainDepthWrapped']='#define RAIN_DEPTH_ONLY 1\n'+passes['rainWrapped']
passes['rainOcclusion']=inline('rainDynamicSceneCopyState.rainOcclusionUpdate =')
passes['smearBake']=inline('rainDynamicSceneCopyState.smearBake =')
passes['wipeMask']=inline('            gRidgeDecay = ridgeDecay,')
passes['rainMirrorWater']=(ROOT/'shaders/rainMirrorWater.hlsl').read_text()
passes['impactFilm']=metric+inline('            gImpactObjectStep=')
passes['waterTrail']=inline('            gTrailCoatRetention=')
passes['rainDebug']=metric+(ROOT/'shaders/rainVisorScreen.hlsl').read_text(encoding='utf-8')
passes['gpuSplashAtlas']=inline('rainDynamicSceneCopyState.gpuSplashAtlasShader =')
passes['microPattern']=metric+inline('                            gMicroGridUV=vec2')
passes['glassLayer']=(ROOT/'shaders/rainVisorLayer.hlsl').read_text(encoding='utf-8')
passes['newTrailDescriptor']=(ROOT/'shaders/rainTrailDescriptor.hlsl').read_text()
passes['newTrailBin']=(ROOT/'shaders/rainTrailBin.hlsl').read_text()
tail=inline('rainDynamicSceneCopyState.gpuHeadsPassB =')
tail=tail[tail.index('void rgWalk('):].replace('    return acc;','    return ntResolve(pin.Tex,acc);')
passes['newTrailResolve']=metric+(ROOT/'shaders/rainTrailResolve.hlsl').read_text()+tail
report=[]
for name,code in passes.items():
    if len(sys.argv)>1 and name not in sys.argv[1].split(','):continue
    textures=sorted(set(re.findall(r'\btx[A-Z]\w+',code)))
    values=sorted(set(re.findall(r'\bg[A-Z]\w+',code)))
    samplers=sorted(set(re.findall(r'\bsam[A-Z]\w+',code)))
    assert len(textures)<=11,(name,textures)
    header='struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;float3 ApplyFog(float3 c){return c;}};\n'
    header+='\n'.join('Texture2D '+t+';' for t in textures)+'\n'
    declared=set(re.findall(r'SamplerState\s+(\w+)',code))
    header+='\n'.join('SamplerState '+t+';' for t in samplers if t not in declared)+'\n'
    declared_values=set(re.findall(r'\b(?:float[234]?(?:x[234])?|bool|int)\s+(g\w+)',code))
    header+='\n'.join(types.get(v,'float')+' '+v+';' for v in values if v not in declared_values)+'\n'
    code=re.sub(r'float4 main\(PS_IN pin\)',r'float4 main(PS_IN pin):SV_TARGET',code)
    path=OUT/(name+'.hlsl');path.write_text(header+code,encoding='utf-8')
    started=time.perf_counter()
    p=subprocess.run([fxc,'/nologo','/T','ps_5_0','/E','main','/Ges','/WX','/Fo',str(OUT/(name+'.cso')),str(path)],capture_output=True,text=True)
    ms=(time.perf_counter()-started)*1000
    print(name,p.returncode,round(ms,1),'ms',p.stdout[-300:]+p.stderr[-1400:],flush=True)
    assert p.returncode==0,name
    report.append({'pass':name,'textures':textures,'uniforms':values,'compile_ms':ms})
(OUT/('bindings.json' if len(sys.argv)==1 else 'bindings_'+sys.argv[1].replace(',','_')+'.json')).write_text(json.dumps(report,indent=2))
print('PASS:',len(report),'actual Rain/glass shader variants, no warnings (/WX); CSP texture limit <= 11')
