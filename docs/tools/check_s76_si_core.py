"""D3D11 WARP checks for P1 SI primitives; no live-state activation yet."""
from pathlib import Path
import json
import math
import hashlib
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/diagnostics/2026-10-14/s76';OUT.mkdir(parents=True,exist_ok=True)
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text(encoding='utf-8')
env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')}
exec(base[:base.index('report=[]')],env)
env['OUT']=OUT
render=env['render'];types=env['types']
for k in ('gGravity','gInertia','gVelocity','gAir','gNormal','gDu','gDv'):types[k]='float3'
core=(ROOT/'shaders/rainPhysicsSI.hlsl').read_text(encoding='utf-8')
reports=[]
def case(name,code,values=None):return render(name,core+code,{},values or {},(1,1))[0,0]
def close(a,b,atol=1e-5):assert np.allclose(a,b,atol=atol,rtol=2e-5),(a,b)

geometry='''float4 main(PS_IN pin) {
 float v=rainSiVolumeMM3(gDiameter);float r=rainSiContactRadiusMM(v,gTheta);
 return float4(v,rainSiMassKG(v,998.2)*1e6,2*r,rainSiCapHeightMM(r,gTheta));}'''
for d in (.1,.25,.65,1.15,2.25,4.5,6.3):
    a=case('geometry_'+str(d).replace('.','p'),geometry,{'gDiameter':d,'gTheta':90})
    volume=math.pi*d**3/6
    close(a,[volume,volume*.9982,d*2**(1/3),d*2**(1/3)*.5],1e-4)
reports.append({'case':'stored mm3 -> actual kg and spherical-cap footprint, .1 to 6.3 mm','passed':True})
measure='''float4 main(PS_IN pin) {
 float v=rainSiVolumeMM3(gDiameter);float r=rainSiContactRadiusMM(v,90);
 return float4(rainSiPinningN(2*r,70,110,.0728,1),rainSiWeber(gDiameter,2,998.2,.0728),
 rainSiEquivalentDiameterMM(v),rainSiPinningN(2*r,80,80,.0728,1));}'''
a=case('pinning_weber',measure,{'gDiameter':.65})
radius=.65*2**(1/3)*.5
close(a,[.0728*2*radius*.001*(math.cos(math.radians(70))-math.cos(math.radians(110))),
    998.2*4*.65*.001/.0728,.65,0],1e-6)
reports.append({'case':'Furmidge N and normal Weber units; zero hysteresis has zero pinning','passed':True})
solver='''float4 main(PS_IN pin) {
 float v=rainSiVolumeMM3(gDiameter);
 float3 speed=rainSiSlideWorld(gVelocity,gGravity,gInertia,gAir,gNormal,v,90,
 gThetaR,gThetaA,gDynamicR,gDynamicA,998.2,.001002,.0728,1.18654,gCd,1,gViscous,gDt);
 return float4(speed,v);}'''
defaults={'gDiameter':1.15,'gVelocity':(0,0,0),'gGravity':(0,-9.80665,0),'gInertia':(0,0,0),
    'gAir':(0,0,0),'gNormal':(0,0,1),'gThetaR':80,'gThetaA':100,'gDynamicR':87,'gDynamicA':93,
    'gCd':0,'gViscous':80,'gDt':1/60}
a=case('pinned_small',solver,defaults);close(a[:3],[0,0,0])
reports.append({'case':'small water drop can remain pinned under gravity','passed':True})
free={**defaults,'gThetaR':90,'gThetaA':90,'gDynamicR':90,'gDynamicA':90,'gViscous':0,'gDt':.01}
a=case('free_gravity_inertia',solver,{**free,'gInertia':(5,0,0)})
close(a[:3],[.05,-.0980665,0],1e-6)
reports.append({'case':'separate true gravity and signed inertial acceleration; no global force gain','velocity_ms':a[:3].tolist()})
# User observed G has no stationary gravity. Accelerating car -> opposite attached-water inertia.
user_inertia=(5.70589,1.97306,-3.68181)
a=case('observed_acceleration',solver,{**free,'gGravity':(0,0,0),'gInertia':user_inertia})
close(a[:3],np.array([user_inertia[0],user_inertia[1],0])*.01,1e-6)
b=case('observed_braking',solver,{**free,'gGravity':(0,0,0),'gInertia':(.45861,.68473,38.02966)})
close(b[:3],[.0045861,.0068473,0],1e-6)
reports.append({'case':'provided raw world G is reversed once; surface-normal acceleration is cancelled','passed':True})
# Exact linear-drag test without contact friction: analytic solution is independent of diameter/UV.
damped={**free,'gViscous':80,'gGravity':(0,0,0),'gInertia':(10,0,0),'gDt':.1}
a=case('analytic_viscous',solver,damped)
V=math.pi*1.15**3/6;m=998.2*V*1e-9;r=1.15*2**(1/3)*.5
c=80*.001002*2*r*.001
expected=10*m/c*(1-math.exp(-c*.1/m))
close(a[:3],[expected,0,0],1e-6)
reports.append({'case':'stable viscous solution matches analytic velocity for stiff small-drop drag','velocity_ms':float(a[0])})
stop=case('friction_stops_without_reversing',solver,{**defaults,'gGravity':(0,0,0),'gVelocity':(.01,0,0),'gDt':1})
close(stop[:3],[0,0,0])
zero=case('zero_volume',solver,{**defaults,'gDiameter':0});close(zero,[0,0,0,0])
reports.append({'case':'contact friction stops through zero without reversal; empty drop remains finite','passed':True})
air='''float4 main(PS_IN pin){float3 f=rainSiAirForceN(gAir,gVelocity,gNormal,.5,.5,1.2,1);
 return float4(f,length(rainSiTangent(f,gNormal)));}'''
a=case('grazing_air',air,{'gAir':(10,0,0),'gVelocity':(0,0,0),'gNormal':(0,0,1)})
assert a[0]>0 and a[3]>0,a
b=case('normal_air',air,{'gAir':(0,0,-10),'gVelocity':(0,0,0),'gNormal':(0,0,1)})
assert b[2]<0 and b[3]==0,b
reports.append({'case':'grazing wind drag is retained; normal pressure does not create fictitious tangent acceleration','passed':True})
merge='''float4 main(PS_IN pin){float va=rainSiVolumeMM3(.65),vb=rainSiVolumeMM3(2.25);
 return float4(rainSiMergedVelocity(float3(1,2,0),float3(-2,1,0),va,vb),va+vb);}'''
a=case('volume_momentum_merge',merge);va=math.pi*.65**3/6;vb=math.pi*2.25**3/6
close(a,[(va-2*vb)/(va+vb),(2*va+vb)/(va+vb),0,va+vb],1e-5)
reports.append({'case':'same-liquid merge conserves volume and physical momentum; no footprint-cubed cap','passed':True})
metric='''float4 main(PS_IN pin) {
 float3 speed=rainSiIntegrateSlip(float3(0,0,0),float3(.0001,-.0002,0),float3(0,0,1),.000001,0,0,0,.01);
 float2 uv=rainSiProjectUV(gDu,gDv,speed);
 return float4(rainSiWorldVelocity(gDu,gDv,uv),gDisplayGain*1.15);}'''
for gain in (.25,.5,1,2):
    a=case('appearance_independent_'+str(gain).replace('.','p'),metric,
        {'gDu':(.3,0,0),'gDv':(.07,.2,0),'gDisplayGain':gain})
    close(a[:3],[1,-2,0],1e-6)
    b=case('uv_remap_'+str(gain).replace('.','p'),metric,
        {'gDu':(.6,0,0),'gDv':(.14,.1,0),'gDisplayGain':gain})
    close(b[:3],a[:3],1e-6)
reports.append({'case':'physical motion invariant under UV remapping/skew and display diameter gain .25 to 2','passed':True})
report={'stage':'P1 shared core primitives; persistent state/renderer binding is next',
    'compiler':'FXC ps_5_0 /Ges /WX','execution':'D3D11 WARP float readback',
    'source_sha256':hashlib.sha256(core.encode()).hexdigest(),'checks':reports,
    'actual_game_physics_activation':False}
(OUT/'si_core_checks.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
