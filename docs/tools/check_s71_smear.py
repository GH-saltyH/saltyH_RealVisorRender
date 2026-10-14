"""Production D3D11 replay of red (low G) and green smear behavior."""
from pathlib import Path
import re,json,struct,subprocess,tempfile,sys,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/diagnostics/2026-10-13/s71';OUT.mkdir(parents=True,exist_ok=True)
helper=(ROOT/'docs/tools/check_s63_gpu.py').read_text(encoding='utf-8')
env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')}
exec(helper[:helper.index('report=[]')],env);env['OUT']=OUT
fixture=(ROOT/'docs/tools/check_s66_gpu.py').read_text(encoding='utf-8');compiled={}
exec(fixture[fixture.index('def full_render('):fixture.index('\ny,x=np.mgrid')],globals())
metric=(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text()
header=(ROOT/'docs/diagnostics/2026-10-12/s67/shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8')
header=header[:header.index(metric)]
def program(body):return header+metric+body.replace('float4 main(PS_IN pin)','float4 main(PS_IN pin):SV_TARGET')
before=(OUT/'baseline/shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8')
after=(ROOT/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8')
size=(512,128);y,x=np.mgrid[:size[1],:size[0]]
scene=np.stack(((x//4)%2,(y//4)%2,x/size[0],np.ones_like(x)),axis=-1).astype(np.float32)
du=np.zeros_like(scene);du[:,:,0]=.30;du[:,:,3]=100
dv=np.zeros_like(scene);dv[:,:,1]=.20;mask=np.ones_like(scene)
smear=np.ones_like(scene);smear[:,:,0]=0
head=np.zeros_like(scene);head[:,:,1]=.7;head[:,:,0]=.7*.002*2048/32
trail=head.copy();trail[:,:,3]=.95
v={'gRainMetersPerUnit':.001/.0029296875,'gRainReferencePerMM':.0029296875,
   'gDynamicDropNewTrail':1,'gDynamicDropNewTrailGradientD':.37,'gDynamicDropNewTrailRefractD':.73,
   'gDynamicDropNewHeadGradientD':.08,'gDynamicDropWaterField':1,'gDynamicDropWFTrail':1,
   'gDynamicDropWFThreshold':.35,'gDynamicDropWFOpacity':1,'gDynamicDropWFSheetAlpha':1,
   'gDynamicDropWFInvMaskSize':1/2048,'gDynamicDropWFHeadStep':1/2048,'gDynamicDropWFTrailStep':1/1024,
   'gDynamicDropTrailSlopeMax':2.15,'gDynamicDropTrailRefractPx':24.5,'gDynamicDropWaterToneFloor':1,
   'gDynamicDropSmear':1,'gDynamicDropSmearTexture':1,'gDynamicDropSmearBaked':1,
   'gDynamicDropSmearIntensity':1,'gDynamicDropSmearGContrast':1,'gDynamicDropSmearGGamma':1,
   'gDynamicDropSmearGPivot':.5,'gDynamicDropSmearEdgeSoft':.04,'gDynamicDropSmearClasses':5,
   'gDynamicDropSmearClassSoft':.35,'gDynamicDropSmearClassSeed':0,'gDynamicDropSmearEraseSpan':.60,
   'gDynamicDropSmearClassWipe':.80,'gDynamicDropSmearHeadHide':1,'gDynamicDropSmearTrailHide':1,
   'gDynamicDropSmearPathWeaken':.85,'gDynamicDropSmearTrailMix':.55,
   'gDynamicDropSmearHeadMix':.35,'gDynamicDropSmearTrailClear':.8,
   'gDynamicDropTrailMaskWipeEnabled':1,'gDynamicDropTrailMaskWipeStrength':1.5,
   'gDynamicDropCameraForward':(0,0,1),'gDynamicDropCameraSide':(1,0,0),'gDynamicDropCameraUp':(0,1,0)}
tx={'txRainDu':du,'txRainDv':dv,'txRainBoundaryMask':mask,'txDynamicSnapshot':scene,
    'txDynamicWeatherScreen':smear,'txDynamicBirthMask':head,'txDynamicTrailMask':trail}
report=[]
outputs={}
versions=[('before',before)] if '--baseline' in sys.argv else [('before',before),('after',after)]
for version,body in versions:
    source=program(body)
    # Smear evaluation precedes all water returns, so a probe can inspect
    # region survival without masked-head clipping obscuring the diagnosis.
    probe=source.replace('smearDebugColor = float4(gSmearMask * 0.85, gSmearK, 0.15, 0.85);',
        'smearDebugColor = float4(gSmearMask,gSmearVisibilityG,smearPresence,smearWipe);')
    for name,g,wipe,heads in [('red_head_fresh_wipe',0,.95,True),('red_trail',0,0,False),
                              ('green_head_fresh_wipe',1,.95,True),('green_trail',1,0,False)]:
        smear[:,:,1]=g;trail[:,:,3]=wipe
        textures={**tx,'txDynamicBirthMask':head if heads else np.zeros_like(head),
                  'txDynamicWaterTrail':np.zeros_like(head) if heads else head}
        out=full_render(version+'_'+name,source,textures,v,size)
        evaluation=full_render(version+'_mask_'+name,probe,textures,{**v,'gDynamicDropSmearDebug':1},size)
        outputs[version,name]=out
        row={'version':version,'case':name,'region_mean':float(evaluation[:,:,0].mean()),
             'effective_class_wipe_mean':float(evaluation[:,:,3].mean()),'alpha_max':float(out[:,:,3].max())}
        report.append(row);print(json.dumps(row),flush=True)
    # Smear disabled must retain exactly the previous water output.
    outputs[version,'disabled']=full_render(version+'_disabled',source,tx,{**v,'gDynamicDropSmear':0},size)
if '--baseline' not in sys.argv:
    assert outputs['before','red_head_fresh_wipe'][:,:,3].min()>.99,'Expected reproduction: fresh wipe disables the red region and reveals opaque heads'
    assert outputs['before','red_trail'][:,:,3].min()>.99,'Expected reproduction: neutral trail bypasses low G'
    assert np.max(abs(outputs['after','red_head_fresh_wipe']))==0,'Low-G heads must stay hidden despite clearance'
    assert np.max(abs(outputs['after','red_trail']))==0,'Low-G neutral trails must follow the visibility control'
    for name in ['green_head_fresh_wipe','green_trail','disabled']:
        delta=float(np.max(abs(outputs['before',name]-outputs['after',name])))
        assert delta<2e-6,(name,delta)
        report.append({'case':name+' preserves output','max_delta':delta})
    # At every internal boundary, class colour and erasure choose the same
    # neighbours and the same symmetric interpolation. No runtime callbacks.
    g=np.linspace(0,1,4097)
    smear_n=5;c=g*smear_n;edge=np.clip(np.floor(c+.5),1,smear_n-1)
    lower=np.clip(edge-1,0,smear_n-1);upper=np.minimum(lower+1,smear_n-1)
    t=np.clip((c-(edge-.35*.5))/.35,0,1);blend=t*t*(3-2*t)
    order=lambda k:np.mod((k+.5)*.6180339887,1)
    step=lambda a,b,x: (lambda t:t*t*(3-2*t))(np.clip((x-a)/(b-a),0,1))
    erase=.4
    expected=step(erase-.15,erase+.15,order(lower))*(1-blend)+step(erase-.15,erase+.15,order(upper))*blend
    # Actual shared helper on a texture holding the complete G ramp.
    code=body[body.index('float4 rainSmearClassPair('):body.index('float3 rainSmearClassColor(')]
    code=code[:code.index('float4 rainSmearClassHash(')] if 'float4 rainSmearClassHash(' in code else code
    code+='''\nfloat4 main(PS_IN pin) {float4 p=rainSmearClassPair(pin.Tex.x);return p;}'''
    pair=env['render']('class_pair',code,{}, {'gDynamicDropSmearClasses':5,'gDynamicDropSmearClassSoft':.35},(4096,1))[0]
    actual_g=(np.arange(4096)+.5)/4096;actual_c=actual_g*5
    edge=np.clip(np.floor(actual_c+.5),1,4);tt=np.clip((actual_c-edge+.175)/.35,0,1)
    assert np.max(abs(pair[:,2]-tt*tt*(3-2*tt)))<3e-6
    assert np.array_equal(pair[:,0],edge-1) and np.array_equal(pair[:,1],edge)
    report.append({'case':'shared symmetric class pair','sample_count':4096,'max_presence_step':float(np.max(abs(np.diff(expected))))})
(OUT/('smear_baseline.json' if '--baseline' in sys.argv else 'smear_checks.json')).write_text(json.dumps(report,indent=2))
print('PASS: production red/green smear replay'+(' (baseline reproduction)' if '--baseline' in sys.argv else ', visibility/wipe/class contract'),flush=True)
