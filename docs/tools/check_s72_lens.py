"""Verify actual deposited model films reach the current production lens."""
from pathlib import Path
import json,re,struct,subprocess,tempfile
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-13/s72'
fixture=(ROOT/'docs/tools/check_s72_trail.py').read_text(encoding='utf-8')
scope={'__file__':str(ROOT/'docs/tools/check_s72_trail.py')};exec(fixture[:fixture.index('cases=[]')],scope)
env=scope['scope']['env'];compiled={}
helpers=(ROOT/'docs/tools/check_s66_gpu.py').read_text(encoding='utf-8')
exec(helpers[helpers.index('def full_render('):helpers.index('\ny,x=np.mgrid')],globals())
full=(ROOT/'docs/diagnostics/2026-10-13/s71/shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8')
metric=(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text()
full=full[:full.index(metric)]+metric+(ROOT/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8').replace('float4 main(PS_IN pin)','float4 main(PS_IN pin):SV_TARGET')
pipeline=scope['pipeline'];tx=scope['tx'];v=scope['v'];ref=scope['ref']
sw,sh=2048,512;y,x=np.mgrid[:sh,:sw]
scene=np.stack(((x//4)%2,(y//4)%2,x/sw,np.ones_like(x)),axis=-1).astype(np.float32)
values={'gRainMetersPerUnit':.001/ref,'gRainReferencePerMM':ref,'gDynamicDropNewTrail':1,
    'gDynamicDropNewTrailGradientD':.37,'gDynamicDropNewTrailRefractD':.73,'gDynamicDropNewHeadGradientD':.321,
    'gDynamicDropWaterField':1,'gDynamicDropWFTrail':1,'gDynamicDropWFThreshold':.35,
    'gDynamicDropWFOpacity':1,'gDynamicDropWFSheetAlpha':1,'gDynamicDropWFInvMaskSize':1/2048,
    'gDynamicDropWFHeadStep':1/2048,'gDynamicDropWFTrailStep':1/1024,
    'gDynamicDropTrailSlopeMax':2.15,'gDynamicDropTrailRefractPx':24.5,'gDynamicDropWaterToneFloor':1,
    'gDynamicDropCameraForward':(0,0,1),'gDynamicDropCameraSide':(1,0,0),'gDynamicDropCameraUp':(0,1,0)}
report={}
for scale in [1,3]:
    history,_=pipeline('lens_history_'+str(scale),{'gNewTrailModelDiameterScale':scale,'gNewTrailOutputDiameterScale':1/scale})
    textures={'txRainDu':tx['txRainDu'],'txRainDv':tx['txRainDv'],'txRainBoundaryMask':tx['txRainBoundaryMask'],
        'txDynamicSnapshot':scene,'txDynamicWaterTrail':history,'txDynamicTrailMask':history}
    normal=full_render('film_lens_'+str(scale),full,textures,values,(sw,sh))
    zero=full_render('film_zero_lens_'+str(scale),full,textures,{**values,'gDynamicDropNewTrailRefractD':0},(sw,sh))
    delta=float(np.max(abs(normal[:,:,:3]-zero[:,:,:3])))
    report[str(scale)]={'deposited_G_peak':float(history[:,:,1].max()),'alpha_max':float(normal[:,:,3].max()),
                       'refraction_rgb_delta':delta}
    if scale==3:
        assert normal[:,:,3].max()>.8,'Developed ordinary-drop film must have substantial lens presence'
        assert delta>.01,'Deposited film must bend the scene, not only show a transparent mask'
        assert np.max(abs(normal[:80]))==0 and np.max(abs(normal[-80:]))==0,'Bare visor must not acquire a full-screen ghost'
        report['bare_max']=float(max(np.max(abs(normal[:80])),np.max(abs(normal[-80:]))))
(OUT/'lens_checks.json').write_text(json.dumps(report,indent=2));print(json.dumps(report),flush=True)
print('PASS: model film reaches production refraction with substantial coverage and no bare-visor ghost')
