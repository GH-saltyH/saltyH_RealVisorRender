"""Snapshot and validate P1 live preview wiring (legacy path remains default)."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-14/s77'
if len(sys.argv)>1 and sys.argv[1]=='snapshot':
    assert not (OUT/'baseline_manifest.json').exists()
    files=['realvisor.lua','rain_environment.lua','rain_physics_units.lua','rain_trails.lua','rain_surface.lua',
           'settings.ini','settings_mats.ini','docs/README.md','docs/RAINFX_ROADMAP.md']
    files += [p.relative_to(ROOT).as_posix() for p in (ROOT/'shaders').glob('*.hlsl')]
    m={}
    for name in files:
        p=ROOT/name
        if not p.exists():continue
        dst=OUT/'baseline'/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst)
        m[name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'mtime_ns':p.stat().st_mtime_ns}
    (OUT/'baseline_manifest.json').write_text(json.dumps(m,indent=2),encoding='utf-8')
    print('P1 binding baseline staged');sys.exit(0)
import re,math,difflib,tempfile
import numpy as np
from check_s75_inputs import load_lua
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
old=(OUT/'baseline/realvisor.lua').read_text(encoding='utf-8-sig')
with tempfile.TemporaryDirectory(prefix='lua_',dir=OUT,ignore_cleanup_errors=True) as folder:
    lua=load_lua(folder);lua.execute('assert(loadstring(...))',source)
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text(encoding='utf-8')
env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')};exec(base[:base.index('report=[]')],env)
env['OUT']=OUT;render=env['render'];inline=env['inline'];types=env['types']
types.update({'gRainObjectToWorld':'float4x4','gRainAcceleration':'float3','gRainAirVelocityWorld':'float3',
    'gRainSiInertiaWorld':'float3','gRainSiAirWorld':'float3','gRainWetPathTexel':'float2',
    'gRainStateSingleDropPosition':'float2'})
referenceEnv={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')}
# The archived entry reproduces X4000 before P1. Only that reference comparison
# is compiled without /WX; all current production programs still require /WX.
exec(base[:base.index('report=[]')].replace("'/WX',",''),referenceEnv)
referenceEnv['OUT']=OUT;referenceEnv['types'].update(types);referenceRender=referenceEnv['render']
core=(ROOT/'shaders/rainPhysicsSI.hlsl').read_text();metric=(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text()
def body(src,key):
    # CSP ignores effect SamplerState blocks; the native wrapper declares samplers.
    return re.sub(r'SamplerState\s+\w+\s*\{.*?\};','',inline(src,key),flags=re.S)
stateHelpers=body(source,'local rainStateUpdateParams =').split('        float4 main(PS_IN pin) {')[0]
stateCode=metric+core+stateHelpers+(ROOT/'shaders/rainStateEntry.hlsl').read_text()
metaHelpers=body(source,'local rainStateMetaUpdateParams =').split('        float4 main(PS_IN pin) {')[0]
metaCode=metric+core+metaHelpers+(ROOT/'shaders/rainMetaEntry.hlsl').read_text()
oldState=metric+body(old,'local rainStateUpdateParams =')
oldMeta=metric+body(old,'local rainStateMetaUpdateParams =')
du=np.zeros((8,32,4),np.float32);dv=np.zeros_like(du);du[:,:,0]=1;du[:,:,3]=100;dv[:,:,1]=1
mask=np.ones_like(du);normal=np.ones_like(du)*.5;normal[:,:,2]=1
state=np.array([[[.5,-.5,0,0]]],np.float32)
ref=6/4096
values={'gRainStateCount':1,'gRainStateDeltaTime':.01,'gRainStateInit':0,'gRainStateLifecycle':0,'gRainStatePhysics':1,
    'gRainReferencePerMM':ref,'gRainMetersPerUnit':.001/ref,'gRainStatePhysicalDiameterUVPerMM':ref,
    'gRainStatePhysicalRadiusUVPerMM':ref/2,'gRainObjectToWorld':np.eye(4).ravel(),
    'gRainStateGravity':9.81,'gRainForceMask':3,'gRainPhysicsAccelScale':.03567788,
    'gRainGravityGain':1,'gRainInertiaGain':1,'gRainAirflowGain':1,'gRainAirDensity':1.2,
    'gRainAcceleration':(5,0,0),'gRainAirVelocityWorld':(0,0,0),
    'gRainStateFlowAcceleration':.1296,'gRainStateFlowSpeedScale':1,'gRainStateFlowDrag':4.84,
    'gRainStateAdhesionMin':.285,'gRainStateAdhesionMax':.305,'gRainStateMobileDrag':.62,
    'gRainStatePhysicalMaxSpeed1MM':.4624,'gRainStatePhysicalMaxSpeedExponent':.67,
    'gRainStateMobileSpeedMultiplier':3.9,'gRainStateMovingForceGain':2.99,
    'gRainStateMobileThresholdUV':.0011,'gRainStateKineticAdhesionFraction':.297,'gRainCoatAdhesion':.55,
    'gRainSiOn':1,'gRainSiTheta':90,'gRainSiRhoWater':998.2,'gRainSiMu':.001002,'gRainSiGamma':.0728,
    'gRainSiRhoAir':1.186541,'gRainSiAttachedCd':0,'gRainSiViscousShape':0,'gRainSiAirFraction':.15,
    'gRainSiInertiaWorld':(5,0,0),'gRainSiAirWorld':(0,0,0),
    'gRainSiStaticBare':0,'gRainSiStaticCoat':0,'gRainSiDynamicBare':0,'gRainSiDynamicCoat':0}
diameter=1.15;volume=math.pi*diameter**3/6
meta=np.array([[[diameter*2**(1/3)*ref/2,volume,2,1]]],np.float32)
textures={'txRainDu':du,'txRainDv':dv,'txRainBoundaryMask':mask,'txRainSurfaceNormal':normal,
    'txRainState':state,'txRainStateMeta':meta}
reports=[]
a=render('SI_transport',stateCode,textures,values,(1,1))
assert np.allclose(a[0,0],[.5005,-.500980665,.05,-.0980665],rtol=1e-5,atol=1e-6),a
reports.append({'case':'actual persistent state shader uses SI acceleration and raw UV metric','output':a[0,0].tolist()})
for remap in (ref,ref/2,ref*2):
    result=render('reference_codec_'+str(remap).replace('.','p'),stateCode,textures,
        {**values,'gRainReferencePerMM':remap,'gRainStatePhysicalDiameterUVPerMM':remap,
         'gRainStatePhysicalRadiusUVPerMM':remap/2,'gRainMetersPerUnit':.001/remap},(1,1))
    assert np.allclose(a,result,atol=2e-6),result
reports.append({'case':'physical transport invariant to legacy reference codec, x0.5/x2','passed':True})
# Same input snapshot: default OFF preserves old state and metadata GPU output.
legacyMeta=np.array([[[.65*ref/2,1.0055,2,1]]],np.float32)
for label,newCode,legacyCode in [('state',stateCode,oldState),('meta',metaCode,oldMeta)]:
    x=referenceRender('legacy_'+label,legacyCode,{**textures,'txRainStateMeta':legacyMeta},values,(1,1))
    y=render('preview_off_'+label,newCode,{**textures,'txRainStateMeta':legacyMeta},{**values,'gRainSiOn':0},(1,1))
    assert np.array_equal(x,y),(label,x,y)
reports.append({'case':'preview OFF state/meta are bit-identical to P0 baseline','passed':True})
lifeValues={**values,'gRainSiOn':0,'gRainStateLifecycle':1,'gRainStateRainIntensity':.6,
    'gRainStateRainWetness':.6,'gRainStateRainWater':1,'gRainStateTargetOccupancy':1,
    'gRainStateExposure':1,'gRainStateAgeMin':8,'gRainStateAgeMax':18,
    'gRainStateRespawnGapMin':.2,'gRainStateRespawnGapMax':.5,
    'gRainSizeMinDrizzle':.65,'gRainSizeMaxDrizzle':.65,'gRainSizeMinLight':.65,'gRainSizeMaxLight':.65,
    'gRainSizeMinRain':.65,'gRainSizeMaxRain':.65,'gRainSizeMinHeavy':.65,'gRainSizeMaxHeavy':.65,
    'gRainSizeMinRare':.65,'gRainSizeMaxRare':.65,'gRainSizeBias':2}
for phase,options,packed,age in [('init',{'gRainStateInit':1},1,2),
    ('waiting',{},0,.1),('waiting_eligible',{},0,4),('respawn',{},2,.5),('active',{},1,2),
    ('expired',{},1,99),('dry_expired',{'gRainStateRainIntensity':0},1,3)]:
    sample=legacyMeta.copy();sample[0,0,2]=age;sample[0,0,3]=packed
    tx={**textures,'txRainStateMeta':sample}
    val={**lifeValues,**options}
    for label,newCode,legacyCode in [('state',stateCode,oldState),('meta',metaCode,oldMeta)]:
        x=referenceRender('legacy_'+phase+'_'+label,legacyCode,tx,val,(1,1))
        y=render('off_'+phase+'_'+label,newCode,tx,val,(1,1))
        assert np.array_equal(x,y),(phase,label,x,y)
reports.append({'case':'single-exit legacy init/waiting/eligible/respawn/active/expiry/dry-expiry are bit-identical','passed':True})
rot=np.array([[0,1,0,0],[-1,0,0,0],[0,0,1,0],[0,0,0,1]],np.float32)
# Default HLSL column-major constant storage; supply the transposed matrix bytes.
rotated=render('SI_rotated_world',stateCode,textures,{**values,'gRainObjectToWorld':rot.T.ravel()},(1,1))
assert np.allclose(rotated[0,0,2:],[-.0980665,-.05],atol=2e-6),rotated
reports.append({'case':'rotated Jacobian preserves world gravity/inertia and changes only UV components','passed':True})
# Initial diagnostic distribution and active metadata contain volume, not 1..9 mass.
init=render('SI_meta_init',metaCode,textures,{**values,'gRainStateInit':1},(1,1))
d=float(init[0,0,1]);assert d>0 and d!=1
decodedDiameter=(6*d/math.pi)**(1/3)
assert math.isclose(float(init[0,0,0]),decodedDiameter*2**(1/3)*ref/2,rel_tol=5e-5),(init,decodedDiameter)
assert init[0,0,3]==1,init
active=render('SI_meta_active',metaCode,textures,values,(1,1))
assert math.isclose(float(active[0,0,1]),volume,rel_tol=1e-6),active
assert math.isclose(float(active[0,0,0]),diameter*2**(1/3)*ref/2,rel_tol=1e-6),active
reports.append({'case':'meta.G is volume mm3; contact radius re-derived without changing volume','passed':True})
# Display scale affects only head raster radius, not state or volume.
headCode=inline(source,'rainDynamicSceneCopyState.gpuHeadsCommon =')+'''
float4 main(PS_IN pin) {float2 p,v;float r,i,g,u;
 if(!rgDrop(0,p,r,v,i,g,u))return 0;return float4(r,u,txRainStateMeta.Load(int3(0,0,0)).g,1);}
'''
frame=np.array([[[1/(.001/ref),0,1/(.001/ref),1]]],np.float32)
headTx={**textures,'txRainDropMetric':frame}
first=None
for gain in (.25,.5,1,2):
    result=render('head_gain_'+str(gain).replace('.','p'),headCode,headTx,
        {'gCount':1,'gSize':2048,'gHeadDisplayGain':gain},(1,1))[0,0]
    assert math.isclose(float(result[0]),float(meta[0,0,0])*2048*gain,rel_tol=1e-6),result
    if first is not None:assert np.array_equal(first[1:],result[1:]),(first,result)
    first=result
reports.append({'case':'display gain alters raster radius only; physical contact/volume remain identical','passed':True})
# Compile and execute production merge validation in both passes, including volume conservation.
def command(partner):return [partner//256/255,(partner%256)/255,64/255,1]
states=np.array([[[.5,-.5,.03,0],[.5001,-.5,-.02,0]]],np.float32)
vols=[math.pi*.65**3/6,math.pi*2.25**3/6]
metas=np.array([[[.65*2**(1/3)*ref/2,vols[0],2,1],[2.25*2**(1/3)*ref/2,vols[1],2,1]]],np.float32)
commands=np.array([[command(1),command(0)]],np.float32)
vals={**values,'gRainStateCount':2,'gRainStateLifecycle':1,'gRainStateDeltaTime':0,
    'gRainMergeEnabled':1,'gRainMergeReach':1.15,'gRainMergeMaxDiameterMM':.1}
tx={**textures,'txRainState':states,'txRainStateMeta':metas,'txRainMergeCmd':commands}
transport=render('SI_merge_transport','#define RAIN_MERGE_CODE\n'+stateCode,tx,vals,(2,1))
commit=render('SI_merge_meta','#define RAIN_MERGE_CODE\n'+metaCode,tx,vals,(2,1))
assert commit[0,0,3]==0 and commit[0,0,1]==0,commit
assert commit[0,1,3]==1 and math.isclose(float(commit[0,1,1]),sum(vols),rel_tol=1e-6),commit
expected=(.03*vols[0]-.02*vols[1])/sum(vols)
assert math.isclose(float(transport[0,1,2]),expected,rel_tol=1e-5,abs_tol=1e-6),transport
assert float(commit[0,1,0])>vals['gRainMergeMaxDiameterMM']*ref/2
reports.append({'case':'paired merge conserves V and momentum; old display diameter cap is bypassed','passed':True})
allDefines='#define RAIN_MERGE_CODE\n#define RAIN_WETPATH_CODE\n'
test=render('all_transport_macros',allDefines+stateCode,tx,
    {**vals,'gRainWetPathTexel':(.01,.04),'gRainWetPathGain':.3,'gRainWetPathMinSpeed':.001},(2,1))
assert np.allclose(test,transport,atol=1e-6),test
reports.append({'case':'production merge+wetpath macro variant is /WX-clean; SI rejects legacy wetpath steering','passed':True})
runtime={}
for key,value in re.findall(r'^\s*(RAIN_\w+)\s*=\s*(true|false|[-+\d.eE]+)\s*,',source,re.M):
    runtime[key]=value=='true' if value in ('true','false') else float(value)
lua.globals().runtime=lua.table_from(runtime)
lua.execute('''
    allocations=0;cfg={RUNTIME=runtime}
    function vec3() allocations=allocations+1;return {set=function(self,x,y,z) self.x=x;self.y=y;self.z=z end} end
    rainDynamicSceneCopyState={physicsInputs={airDensity=1.186541,inertiaVerified=true,
        inertiaX=5,inertiaY=1,inertiaZ=-3,windX=1,windZ=3,velocityX=4,velocityY=2,velocityZ=6}}
    pa={values={}};pb={values={}}
''')
start=source.index('rainDynamicSceneCopyState.bindSIParams=function(p)')
end=source.index('\nrainDynamicSceneCopyState.bindSIParams(rainStateUpdateParams)',start)
lua.execute(source[start:end])
lua.execute('''
    local s=rainDynamicSceneCopyState
    for i=1,200 do s.bindSIParams(pa);s.bindSIParams(pb) end
    assert(allocations==4 and pa.values.gRainSiOn==0)
    for k,v in pairs(pa.values) do assert(pb.values[k]~=nil) end
    runtime.RAIN_PHYSICS_SI_PREVIEW=true;s.bindSIParams(pa)
    assert(allocations==4 and pa.values.gRainSiOn==1)
    assert(pa.values.gRainSiInertiaWorld.x==5 and pa.values.gRainSiInertiaWorld.z==-3)
    assert(pa.values.gRainSiAirWorld.x==-3 and pa.values.gRainSiAirWorld.y==-2 and pa.values.gRainSiAirWorld.z==-3)
    runtime.RAIN_FORCE_AIRFLOW_INCLUDE_WIND=false;s.bindSIParams(pa)
    assert(pa.values.gRainSiAirWorld.x==-4 and pa.values.gRainSiAirWorld.z==-6)
''')
start=source.index('    local siChanged=',source.index('local function updateRainGPUState'))
end=source.index('    if cfg.RUNTIME.RAIN_GPU_STATE_MODE <= 0 then',start)
lua.execute('''
    disposed=0;historyDisposed=0
    function canvas() return {dispose=function() disposed=disposed+1 end} end
    rainStateA=canvas();rainStateB=canvas();rainStateMetaA=canvas();rainStateMetaB=canvas()
    rainStateSingleDropDirty=false;rainStateConfiguredMode=runtime.RAIN_GPU_STATE_MODE
    rainStateInitialized=true;rainDynamicStateHasSnapshot=true;rainDynamicStateReadbackReady=true
    rainDynamicSceneCopyState.siConfigured=false;rainDynamicSceneCopyState.siEpoch=0
    rainDynamicSceneCopyState.newTrail={dispose=function() historyDisposed=historyDisposed+1 end}
''')
lua.execute('function resetVersion() '+source[start:end]+' end')
lua.execute('''
    resetVersion();assert(disposed==4 and historyDisposed==1)
    assert(rainDynamicSceneCopyState.siEpoch==1 and not rainStateInitialized and not rainDynamicStateHasSnapshot)
    assert(not rainDynamicStateReadbackReady and rainStateA==nil and rainStateMetaA==nil)
    resetVersion();assert(disposed==4 and historyDisposed==1 and rainDynamicSceneCopyState.siEpoch==1)
''')
start=source.index('        if slot.modelEpoch~=')
end=source.index('        local profileStart=',start)
lua.execute('function retireOldCopy() '+source[start:end]+' accepted=true end')
lua.execute('''
    retired=0;accepted=false;slot={modelEpoch=0};data={dispose=function() retired=retired+1 end}
    retireOldCopy();assert(retired==1 and not accepted)
    slot.modelEpoch=1;retireOldCopy();assert(retired==1 and accepted)
''')
start=source.index('    if cfg.RUNTIME.RAIN_PHYSICS_SI_PREVIEW then\n        state.birthMaskReady=')
end=source.index('    local cpuBuildStart =',start)
lua.execute('function finishPreview() '+source[start:end]+' error("CPU fallback") end')
lua.execute('''
    state={gpuHeadsActive=true,birthMaskRead={}};sim={frame=40}
    assert(finishPreview() and state.birthMaskFrame==40 and state.birthMaskReady)
    state.gpuHeadsActive=false;assert(not finishPreview() and state.birthMaskRead==nil and state.birthMaskFrame==nil)
''')
reports.append({'case':'actual Lua bindings reuse four vectors; version reset disposes four banks and stale readbacks; GPU heads publish without CPU stamping','passed':True})
baseline=json.loads((OUT/'baseline_manifest.json').read_text())
unchanged={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==entry['sha256']
    for name,entry in baseline.items() if name not in ('realvisor.lua','docs/README.md','docs/RAINFX_ROADMAP.md')}
assert all(unchanged.values()),unchanged
game=Path('D:/Games/Assetto Corsa/apps/lua/realvisor')
installed={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==hashlib.sha256((game/name).read_bytes()).hexdigest()
    for name in ('realvisor.lua','shaders/rainPhysicsSI.hlsl','shaders/rainStateEntry.hlsl','shaders/rainMetaEntry.hlsl')}
assert all(installed.values()),installed
(OUT/'source.diff').write_text(''.join(difflib.unified_diff(old.splitlines(True),source.splitlines(True),
    fromfile='s76/realvisor.lua',tofile='s77/realvisor.lua')),encoding='utf-8')
(OUT/'checks.json').write_text(json.dumps({'checks':reports,'whole_luajit_syntax':True,
    'compiler':'FXC ps_5_0 /Ges /WX (archived warning-bearing reference without /WX)',
    'baseline_dependencies_and_tuning_unchanged':unchanged,'installed_sources_match':installed,
    'actual_game_preview_pending':True},indent=2),encoding='utf-8')
print(json.dumps(reports,indent=2))
