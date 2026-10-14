from pathlib import Path
import re,struct,subprocess,tempfile,json
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s67'
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text(encoding='utf-8');env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')}
exec(base[:base.index('report=[]')],env);env['OUT']=OUT
fixture=(ROOT/'docs/tools/check_s66_gpu.py').read_text(encoding='utf-8')
compiled={};exec(fixture[fixture.index('def full_render('):fixture.index('\ny,x=np.mgrid')],globals())
full=(OUT/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8')
h,w=128,512;y,x=np.mgrid[:h,:w]
scene=np.stack(((x//4)%2,y/h,x/w,np.ones_like(x)),axis=-1).astype(np.float32)
du=np.zeros_like(scene);du[:,:,0]=.30;du[:,:,3]=100
dv=np.zeros_like(scene);dv[:,:,1]=.20
mask=np.ones_like(scene);trail=np.zeros_like(scene)
across=(y-63.5)/9;profile=np.maximum(0,1-across*across)*.7
trail[:,:,1]=profile;trail[:,:,0]=profile*(.004*2048/32);trail[:,:,2]=profile
trail[:,:,3]=.8*(profile>0)
v={'gRainMetersPerUnit':.001/.0029296875,'gRainReferencePerMM':.0029296875,
 'gDynamicDropNewTrail':1,'gDynamicDropNewTrailGradientD':.35,'gDynamicDropNewTrailRefractD':.65,
 'gDynamicDropNewHeadGradientD':.08,
 'gDynamicDropWaterField':1,'gDynamicDropWFTrail':1,'gDynamicDropWFThreshold':.35,
 'gDynamicDropWFOpacity':1,'gDynamicDropWFSheetAlpha':1,'gDynamicDropWFInvMaskSize':1/2048,
 'gDynamicDropWFHeadStep':1/2048,'gDynamicDropWFTrailStep':1/1024,
 'gDynamicDropTrailSlopeMax':1.5,'gDynamicDropTrailRefractPx':22,'gDynamicDropTrailProfileRange':.35,
 'gDynamicDropWaterToneFloor':1,'gDynamicDropTrailMaskWipeEnabled':1,'gDynamicDropTrailMaskWipeStrength':1.5,
 'gDynamicDropCameraForward':(0,0,1),'gDynamicDropCameraSide':(1,0,0),'gDynamicDropCameraUp':(0,1,0)}
tx={'txRainDu':du,'txRainDv':dv,'txRainBoundaryMask':mask,'txDynamicSnapshot':scene,
    'txDynamicWaterTrail':trail,'txDynamicTrailMask':trail}
a=full_render('new_sheet_refracting',full,tx,v,(w,h))
b=full_render('new_sheet_zero_lens',full,tx,{**v,'gDynamicDropNewTrailRefractD':0},(w,h))
assert a[:,:,3].max()>.9
assert np.max(abs(a[:,:,:3]-b[:,:,:3]))>.001,'A continuous sheet must shift the scene image'
assert np.max(abs(a[profile==0]))==0,'Bare visor must not gain a ghost image'
only_wipe=trail.copy();only_wipe[:,:,:3]=0
c=full_render('clearance_only',full,{**tx,'txDynamicWaterTrail':only_wipe,'txDynamicTrailMask':only_wipe},v,(w,h))
assert np.max(abs(c))==0,'Clearance alone is not liquid and must not refract the whole visor'
# Instrument the production helper directly to verify A/G channel selection.
code='''float4 main(PS_IN pin) {
    float4 t=txDynamicTrailMask.SampleLevel(samLinearClamp,pin.Tex,0);
    return float4(0,gDynamicDropNewTrail>.5 ? t.a : t.g,0,0);
}'''
g=env['render']('wipe_channel',code,{'txDynamicTrailMask':trail},{'gDynamicDropNewTrail':1},(w,h))
assert np.max(abs(g[:,:,1]-trail[:,:,3]))<1e-6
report={'sheet_image_delta':float(np.max(abs(a[:,:,:3]-b[:,:,:3]))),'bare_max':float(np.max(abs(a[profile==0]))),
 'wipe_only_colour_max':float(np.max(abs(c))),'wipe_channel_delta':float(np.max(abs(g[:,:,1]-trail[:,:,3])))}
# Compare the shared-frame refactor against the mathematically identical
# independent helper calls in production, including head and trail lenses.
old=full.replace('float2 physicalDx=float2(localFrame.x*wfDx.x+localFrame.y*wfDx.y,localFrame.z*wfDx.y);',
 'float2 physicalDx=rainMetricPlane(float2(patternUV.x,patternUV.y-1),wfDx);')
old=old.replace('float2 physicalDy=float2(localFrame.x*wfDy.x+localFrame.y*wfDy.y,localFrame.z*wfDy.y);',
 'float2 physicalDy=rainMetricPlane(float2(patternUV.x,patternUV.y-1),wfDy);')
old=old.replace('stepU=float2(headPhysicalStep/localFrame.x,0);',
 'stepU=rainMetricOffset(float2(patternUV.x,patternUV.y-1),float2(headPhysicalStep,0));')
old=old.replace('stepV=float2(-localFrame.y*dv/localFrame.x,dv);',
 'stepV=rainMetricOffset(float2(patternUV.x,patternUV.y-1),float2(0,headPhysicalStep));')
old=old.replace('float2 du=float2(r/localFrame.x,0);',
 'float2 du=rainMetricOffset(float2(patternUV.x,patternUV.y-1),float2(r,0));')
old=old.replace('float2 dv=float2(-localFrame.y*dvStep/localFrame.x,dvStep);',
 'float2 dv=rainMetricOffset(float2(patternUV.x,patternUV.y-1),float2(0,r));')
reference=full_render('shared_frame_reference',old,tx,v,(w,h))
delta=float(np.max(abs(a-reference)));assert delta<2e-5,delta
head_tx={**tx,'txDynamicWaterTrail':np.zeros_like(trail),'txDynamicTrailMask':np.zeros_like(trail),'txDynamicBirthMask':trail}
head_v={**v,'gDynamicDropRefractPx':10,'gDynamicDropRefract':1}
head_a=full_render('shared_frame_heads',full,head_tx,head_v,(w,h))
head_b=full_render('independent_frame_heads',old,head_tx,head_v,(w,h))
assert head_a[:,:,3].max()>.5,'Head branch must execute'
head_delta=float(np.max(abs(head_a-head_b)));assert head_delta<2e-5,head_delta
report.update(shared_frame_trail_delta=delta,shared_frame_head_delta=head_delta)
(OUT/'lens_checks.json').write_text(json.dumps(report,indent=2));print('PASS: actual New Trail sheet refraction, bare visor, wipe-only output and channel contract',report)
