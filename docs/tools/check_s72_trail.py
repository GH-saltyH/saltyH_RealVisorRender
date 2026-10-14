"""Production trail diameter, phase, subpixel conservation and cost audit."""
from pathlib import Path
import re,json,hashlib,math
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-13/s72'
fixture=(ROOT/'docs/tools/check_s67_gpu.py').read_text(encoding='utf-8')
fixture=fixture[:fixture.index("a,desc=pipeline('continuous')")].replace("2026-10-12/s67","2026-10-13/s72")
scope={'__file__':str(ROOT/'docs/tools/check_s67_gpu.py')};exec(fixture,scope)
pipeline=scope['pipeline'];tx=scope['tx'];v=scope['v'];states=scope['states'];previous=scope['previous']
meta=scope['meta'];ref=scope['ref'];size=scope['size'];count=scope['count'];frames=scope['frames'];dv=scope['dv']
report={};tx['txTrailPreviousDescriptors']=np.zeros((5,count,4),np.float32)
v.update(gNewTrailModelDiameterScale=1,gNewTrailOutputDiameterScale=1,gNewTrailPixelIntegration=1,gNewTrailBandlimit=1,
    gNewTrailWiden=1,gNewTrailWidthD=.21,gNewTrailMinDiameterMM=.147,gNewTrailShear=.6,gNewTrailWet=.8,
    gNewTrailDensity=1,gNewTrailSupply=.8,gNewTrailNoise=.75,gNewTrailBeadCycles=5,gNewTrailSheetRipple=0,
    gNewTrailDiffuse=0)
meta[0,0,0]=.65*ref/2;dv[:,:,3]=1
cases=[]
for scale in [1,3,4]:
    a,desc=pipeline('model_'+str(scale),{'gNewTrailModelDiameterScale':scale,'gNewTrailOutputDiameterScale':1/scale})
    if scale==1:base_desc=desc.copy();base_wipe=a[:,:,3].copy()
    assert np.max(abs(a[:,:,3]-base_wipe))<3e-6,'Model size must not enlarge the accepted wiping footprint'
    _,thin=pipeline('thin_model_'+str(scale),{'gNewTrailModelDiameterScale':scale,
        'gNewTrailOutputDiameterScale':1/scale,'gNewTrailSheetEnabled':0})
    if scale==1:thin_base=thin.copy()
    assert abs(float(thin[1,0,0])-float(thin_base[1,0,0]))<1e-8,'Reciprocal output scale must retain thin-trace width'
    cases.append({'model_scale':scale,'output_scale':1/scale,'model_diameter_mm':.65*scale,
        'descriptor_height':float(desc[1,0,1]),'deposited_height_max':float(a[:,:,1].max()),
        'liquid_sum':float(a[:,:,1].sum()),'display_width_mm':float(desc[1,0,0]*2/ref)})
assert cases[1]['descriptor_height']>cases[0]['descriptor_height']*2
report['diameter_candidates']=cases
# Same model/path translated from between rows onto a row; sum of thickness
# (not peak height) is the physically meaningful pixel-integral comparison.
v.update(gNewTrailModelDiameterScale=3,gNewTrailOutputDiameterScale=1/3,gNewTrailNoise=0,gNewTrailSheetRipple=0)
between,desc=pipeline('between_rows')
states[0,0,1]=previous[0,0,1]=-.5+2/size
centred,desc2=pipeline('centred_row')
mass_delta=abs(float(between[:,:,1].sum()/centred[:,:,1].sum())-1)
assert between[:,:,1].max()>0 and mass_delta<.003,mass_delta
report['pixel_integral']={'between_rows_peak':float(between[:,:,1].max()),'centred_peak':float(centred[:,:,1].max()),
    'translation_liquid_sum_relative_delta':mass_delta}
# Publish the descriptor phase, then advance one slot. Its generation must
# carry phase on movement and reset when reborn, without CPU readback.
tx['txTrailPreviousDescriptors']=desc2.copy();previous[0,0,:]=states[0,0,:];states[0,0,0]+=.02
_,next_desc=pipeline('phase_next')
assert abs(float(next_desc[4,0,0])-float(desc2[4,0,1]))<1e-5
old_seam=math.sin(float(desc2[4,0,1])*2*math.pi)
new_seam=math.sin(float(next_desc[4,0,0])*2*math.pi)
report['phase']={'end':float(desc2[4,0,1]),'next_begin':float(next_desc[4,0,0]),
    'legacy_ripple_seam_jump':abs(old_seam),'new_ripple_seam_jump':abs(old_seam-new_seam)}
tx['txTrailPreviousDescriptors']=next_desc
held_position=previous.copy();previous[0,0,:]=states[0,0,:]
held,held_desc=pipeline('phase_pinned')
assert held_desc[4,0,1]==next_desc[4,0,1] and held[:,:,1].max()==0
previous[:]=held_position;meta[0,0,3]=9
_,reborn=pipeline('phase_generation');assert reborn[4,0,0]==0,'New generation must not inherit the old phase'
report['phase']['reborn_begin']=float(reborn[4,0,0])

source=(ROOT/'realvisor.lua').read_text(encoding='utf-8');baseline=(OUT/'baseline/realvisor.lua').read_text(encoding='utf-8')
def profiles(s):
    return {k:float(v) for k,v in re.findall(r'^\s*(RAIN_GPU_SIZE_[A-Z_]+|RAIN_DYNAMIC_MICRO_PATTERN_DIAMETER_MM)\s*=\s*([\d.]+)',s,re.M)}
assert profiles(source)==profiles(baseline),'Accepted birth/micro profiles must stay unchanged'
main=(ROOT/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8')
old_main=(OUT/'baseline/shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8')
floor='''                        // Sub-texel derivatives of a bilinear film alternate
                        // between cell slopes. Keep a half-history-texel floor
                        // in physical units; reuse the same four height taps.
                        float historySpan=wfStep*max(localFrame.x,
                            4*length(float2(localFrame.y,localFrame.z)));
                        r=max(r,historySpan*.5);
'''
assert main.replace(floor,'')==old_main,'Only New Trail derivative filtering may change; head/micro optics must remain unchanged'
assert (ROOT/'shaders/rainMirrorWater.hlsl').read_bytes()==(OUT/'baseline/shaders/rainMirrorWater.hlsl').read_bytes()
# The core physics shader programs, not just their settings, remain unchanged.
for anchor in ['local rainStateUpdateParams = {','local rainStateMetaUpdateParams = {']:
    assert scope['inline'](source,anchor)==scope['inline'](baseline,anchor)
profile=profiles(source);rows=[]
for rain in [.03,.50,.60,1]:
    if rain<=.03:k0,k1,t='DRY','LIGHT',rain/.03
    elif rain<=.5:k0,k1,t='LIGHT','RAIN',(rain-.03)/.47
    else:k0,k1,t='RAIN','HEAVY',(rain-.5)/.5
    lo=profile['RAIN_GPU_SIZE_MIN_'+k0]*(1-t)+profile['RAIN_GPU_SIZE_MIN_'+k1]*t
    hi=profile['RAIN_GPU_SIZE_MAX_'+k0]*(1-t)+profile['RAIN_GPU_SIZE_MAX_'+k1]*t
    mean=lo+(hi-lo)/(profile['RAIN_GPU_SIZE_BIAS']+1)
    smooth=lambda d: (lambda t:t*t*(3-2*t))(max(0,min(1,(d-.4)/2.1)))
    rows.append({'rain':rain,'display_mm':[lo,hi],'model_mm':[3*lo,3*hi],
        'mean_size_response_before':smooth(mean),'mean_size_response_after':smooth(mean*3),
        'puddle_1p4mm_without_merge_before':hi>=1.4,'impact_fast_1p4mm_before':hi>=1.4})
report['size_gate_audit']=rows
report['micro']={'display_mm':profile['RAIN_DYNAMIC_MICRO_PATTERN_DIAMETER_MM'],
                 'corresponding_model_mm':3*profile['RAIN_DYNAMIC_MICRO_PATTERN_DIAMETER_MM'],
                 'static_micro_has_no_mobile_trail_state':True}
report['cost']={'history_size':[1024,256],'full_atlas_passes_added':0,'metadata_rows_before':4,'metadata_rows_after':5,
    'descriptor_memory_before_bytes':4096*4*16,'descriptor_memory_after_bytes':2*4096*5*16,
    'additional_metadata_bytes':2*4096*5*16-4096*4*16,'additional_descriptor_pixels_per_frame':4096,
    'resolved_phase_fetches_per_candidate_at_most':1,'curve_subdivision_2_to_3_segments_candidate_work_multiplier':[2,3],
    'doubling_atlas_width_pixel_and_history_memory_multiplier':4,'actual_hardware_gpu_ms_measured':False}
(OUT/'trail_checks.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
for k,row in report.items():print(k,json.dumps(row),flush=True)
print('PASS: model/output compensation, pixel integral, persistent/reset phase, accepted micro/head sizes and physics preserved')
