"""Read the real E2/E3 shader output, including premultiplied negative deltas."""
from pathlib import Path
import json,re
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s68'
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text(encoding='utf-8');env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')}
exec(base[:base.index('report=[]')],env);env['OUT']=OUT;render=env['render']
code=(ROOT/'shaders/rainVisorLayer.hlsl').read_text(encoding='utf-8')
old=(OUT/'baseline/shaders/rainVisorLayer.hlsl').read_text(encoding='utf-8')
w,h=128,64;empty=np.zeros((h,w,4),np.float32);white=np.ones_like(empty)
normal=white.copy();normal[:,:,:2]=.5
scene=white.copy();scene[:,:,:3]=2
outline=white.copy();lens=empty.copy();lens[:,40:88,3]=1
tx={name:empty for name in set(re.findall(r'\btxLayer\w+',code))}
tx.update(txLayerSource=scene,txLayerNormal=normal,txLayerOutline=outline,txLayerLens=lens)
v={'gLayerKind':3,'gLayerOptics':1,'gLayerInvShotSize':(1/w,1/h),
 'gLayerCameraSide':(1,0,0),'gLayerCameraUp':(0,1,0),'gLayerCameraLook':(0,0,1),
 'gLayerOpticsRimPeak':1,'gLayerOpticsRimSharpness':2,'gLayerOpticsBrightness':0,
 'gLayerBandAlphaMin':.06,'gLayerOpticsConvexTint':0}
neutral=render('convex_tint_zero',code,tx,v,(w,h))
prior=render('prior_neutral',old,tx,v,(w,h))
assert np.max(abs(neutral-prior))==0,'Default tint must retain the accepted output exactly'
tinted=render('convex_tint_half',code,tx,{**v,'gLayerOpticsConvexTint':.5},(w,h))
assert np.max(abs(tinted[:,45:83,:3]+1))<1e-6,'Half tint subtracts half of HDR scene (2) in its convex area'
assert np.max(abs(tinted[:,:32]))==0 and np.max(abs(tinted[:,96:]))==0
assert np.max(abs(tinted[:,:,3]))==0,'Clear-glass tint must remain a scene delta, not a second opaque layer'
outline[:,56:72,0]=0
hole=render('convex_tint_hole',code,tx,{**v,'gLayerOpticsConvexTint':1},(w,h))
assert np.max(abs(hole[:,58:70]))==0,'The central unmasked window remains untouched'
assert np.max(abs(hole[:,45:53,:3]+2))<1e-6
result={'zero_tint_baseline_delta':float(np.max(abs(neutral-prior))),
 'half_tint_hdr_delta':float(tinted[32,48,0]),'clear_outside_max':float(np.max(abs(tinted[:,:32]))),
 'central_hole_max':float(np.max(abs(hole[:,58:70]))),'alpha_max':float(np.max(abs(tinted[:,:,3]))),
 'old_effect_gain':v['gLayerOpticsBrightness'],'texture_bindings':len(tx)}
(OUT/'tint_gpu_checks.json').write_text(json.dumps(result,indent=2))
print('PASS: actual E2/E3 convex tint, flat crown, central-hole exclusion, zero-default equality and independent effect gain',result)
