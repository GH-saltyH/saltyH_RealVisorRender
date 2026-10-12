"""Actual physical airflow and unchanged adaptive transport on D3D11 WARP."""
from pathlib import Path
import json,re
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
# Reuse the established shader reflection/fixture runner, without its scenarios.
ns={};text=(ROOT/'docs/tools/check_s63_gpu.py').read_text(encoding='utf-8')
prefix=text[:text.index('report=[]')].replace("Path(__file__).resolve().parents[2]","Path(r'"+ROOT.as_posix()+"')")
prefix=prefix.replace('        assert cp.returncode==0,cp.stdout+cp.stderr',
    "        if cp.returncode: (OUT/'failed_gpu_fixture.hlsl').write_text(h,encoding='utf-8')\n        assert cp.returncode==0,cp.stdout+cp.stderr")
exec(prefix,ns)
ns['OUT']=ROOT/'docs/diagnostics/2026-10-12/s64';render=ns['render']
ns['types'].update(gRainObjectToWorld='float4x4',gRainAirVelocityWorld='float3',gRainAcceleration='float3')
lua=(ROOT/'realvisor.lua').read_text(encoding='utf-8');old=(ns['OUT']/'baseline/realvisor.lua').read_text(encoding='utf-8')
metric=(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text();oldMetric=(ns['OUT']/'baseline/shaders/rainSurfaceMetric.hlsl').read_text()
def dds(k):return np.frombuffer((ROOT/f'texture/RAIN_GEOMETRY/{k}.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
boundary=np.asarray(ns['Image'].open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').convert('RGBA'),np.float32)/255
tx={'txRainDu':dds('du'),'txRainDv':dds('dv'),'txRainBoundaryMask':boundary,'txRainSurfaceNormal':boundary}
M=np.array([[1,0,0,0],[0,0,-1,0],[0,1,0,0],[0,0,0,1]],float)
values={'gRainObjectToWorld':M.T.ravel(),'gRainMetersPerUnit':.001/.0029296875,'gRainReferencePerMM':.0029296875,
    'gRainForceMask':4,'gRainAirflowGain':1,'gRainPhysicsAccelScale':.03567788,'gRainAirDensity':1.2,'gRainAirDragCoeff':.47,
    'gRainStatePhysicalDiameterUVPerMM':.0029296875,'gRainStateLifecycle':1,'gRainAirflowDownwardGain':2.58,'gRainStateGravity':9.81}
report=[]
for air in [(0,0,-50),(15,0,-45)]:
    images=[]
    for name,source in [('old',old),('new',lua)]:
        a=source.index('        float3 rainStateNormalWorld(');b=source.index('        float rainStateAdhesion(',a)
        code=metric+source[a:b]+'''
float4 main(PS_IN pin) {
    float2 p=float2(pin.Tex.x,pin.Tex.y-1);
    if(rainValid(p)<.5)return 0;
    float mag;float2 force=rainStateSurfaceForce(p,.00085,mag);
    float3 u,v;rainMetric(p,u,v);
    float3 world=mul((u*force.x+v*force.y)/gRainMetersPerUnit,(float3x3)gRainObjectToWorld);
    float3 n=normalize(mul(cross(u,v),(float3x3)gRainObjectToWorld)),down=float3(0,-1,0);down-=n*dot(down,n);
    down/=max(length(down),1e-9);
    return float4(dot(world,down),dot(world,cross(n,down)),mag,1);
}
'''
        images.append(render('force_'+name,code,tx,{**values,'gRainAirVelocityWorld':air,'gRainAirflowDownwardMode':1},(128,32)))
    before,after=images;active=(after[:,:,3]>.5)&(after[:,:,2]>.01)
    backwards=int(np.count_nonzero(active&(before[:,:,0]<-.001)))
    negative=int(np.count_nonzero(active&(after[:,:,0]<-.001)))
    assert backwards>0 and negative==0,(backwards,negative)
    original=render('force_option_off',code,tx,{**values,'gRainAirVelocityWorld':air,'gRainAirflowDownwardMode':0},(128,32))
    lateral=float(np.max(abs(original[active,1]-after[active,1])))
    assert lateral<.001,lateral
    report.append({'case':'physical airflow downward at 180 km/h equivalent','relative_air_ms':air,
        'active_samples':int(active.sum()),'upward_before':backwards,'upward_after':negative,'max_lateral_projection_change':lateral})
code='''
float4 main(PS_IN pin) {
    float2 p=float2(pin.Tex.x,pin.Tex.y-1);if(rainValid(p)<.5)return 0;
    float2 v=rainMetricOffset(p,float2(.57,.29));
    return rainAdvance(p,v,gDeltaTime);
}
'''
for dt in [.016,.05]:
    a=render('transport_old',oldMetric+code,tx,{**values,'gDeltaTime':dt},(128,32))
    b=render('transport_new',metric+code,tx,{**values,'gDeltaTime':dt},(128,32))
    assert np.array_equal(a[:,:,0]>1,b[:,:,0]>1),'Absorbing boundary classifications changed'
    delta=float(np.max(abs(a-b)));assert delta<3e-5,delta
    report.append({'case':'cached Jacobian transport preserves old trajectory and exits','dt':dt,'max_delta':delta})
# Execute seeded active state paths with command and wet-path/hold bypasses.
for name,kind in re.findall(r'\b(g\w+)\s*=\s*(vec2|vec3|vec4|rgbm|rgb|mat4x4)',lua):
    ns['types'][name]={'vec2':'float2','vec3':'float3','vec4':'float4','rgbm':'float4','rgb':'float3','mat4x4':'float4x4'}[kind]
ns['types'].update(gRainAcceleration='float3',gRainAirVelocityWorld='float3',gRainObjectToWorld='float4x4')
count=96;sites=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/spawn_sites.dds').read_bytes(),'<f4',offset=148).reshape(1,8192,4)
states=sites[:,:count].copy();states[:,:,1]-=1;states[:,:,2:]=(.05,-.02)
states[0,1,:2]=states[0,0,:2]+(.0001,0)
meta=np.zeros_like(states);meta[:,:,0]=.00085;meta[:,:,1]=1;meta[:,:,2]=3;meta[:,:,3]=5
base={**values,'gRainAirflowDownwardMode':0,'gRainForceMask':1,'gRainGravityGain':1,'gRainStateCount':count,
    'gRainStatePhysics':1,'gRainStateDeltaTime':.016,'gRainStateFlowAcceleration':.1296,'gRainStateFlowSpeedScale':1,
    'gRainStateFlowDrag':4.84,'gRainStateMobileDrag':.62,'gRainStateMobileSpeedMultiplier':3.9,'gRainStateMovingForceGain':1,
    'gRainStateKineticAdhesionFraction':.2,'gRainStatePhysicalMaxSpeed1MM':.4624,'gRainStatePhysicalMaxSpeedExponent':.67,
    'gRainStateAdhesionMin':.285,'gRainStateAdhesionMax':.305,'gRainStateMobileThresholdUV':.01,'gRainStateTravelMix':1,
    'gRainCoatAdhesion':.55,'gRainGlassExtraDrag':1.5,'gRainBirthHold':.6,'gRainBirthRamp':1.2,'gRainMergeEnabled':1,
    'gRainMergeReach':1.15,'gRainAttractReach':1.6,'gRainAttractGain':.03,'gRainMergeMaxDiameterMM':2.5,
    'gRainSteerTurnRate':1.5,'gRainWetPathGain':.6,'gRainWetPathMinSpeed':.01,'gRainWetPathTexel':(1/1024,4/1024),
    'gRainWetPathAhead':1.5,'gRainStateRainIntensity':.6,'gRainStateTargetOccupancy':1,'gRainStateExposure':1,
    'gRainStateAgeMin':8,'gRainStateAgeMax':18}
for case in ['empty','attract','merge','birth_hold']:
    cmd=np.zeros_like(states)
    if case in ['attract','merge']:
        cmd[0,0]=[0,1/255,(129 if case=='attract' else 65)/255,1]
        cmd[0,1]=[0,0,(129 if case=='attract' else 65)/255,1]
    caseMeta=meta.copy()
    if case=='birth_hold':caseMeta[:,:,2]=.1
    fixture={**tx,'txRainState':states,'txRainStateMeta':caseMeta,'txRainMergeCmd':cmd,'txRainWetPath':np.zeros((8,32,4),np.float32)}
    for passName in ['rainStateUpdateParams']:
        out=[]
        for label,src,shared in [('old',old,oldMetric),('new',lua,metric)]:
            code=ns['inline'](src,'local '+passName+' = {')
            code=re.sub(r'SamplerState\s+\w+\s*\{[^}]*\};','',code)
            # These fixtures supply alive, initialized records. The artificial
            # function wrapper triggers an FXC false-positive in unreachable
            # spawn returns; full unmodified entries compile separately /WX.
            code=code.replace('gRainStateInit','0.0')
            code=re.sub(r'if\s*\(status\s*>\s*1\.5\)', 'if(false)', code)
            code='#define RAIN_MERGE_CODE 1\n#define RAIN_WETPATH_CODE 1\n'+shared+code
            out.append(render(passName+'_'+case+'_'+label,code,fixture,base,(count,1)))
        delta=float(np.max(abs(out[0]-out[1])));assert delta<3e-5,(case,passName,delta)
        report.append({'case':'full '+passName+' preserves '+case,'max_delta':delta})
(ns['OUT']/'physics_gpu_checks.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2));print('PASS: actual downward force with no upward samples; adaptive transport retains trajectories/exits')
