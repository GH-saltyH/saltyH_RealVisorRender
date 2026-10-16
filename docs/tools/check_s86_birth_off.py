"""Nonempty-rain P4b-OFF event equivalence against user stamp a23527e."""
from pathlib import Path
import sys,json
import numpy as np
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s86'
e={'__file__':str(ROOT/'docs/tools/check_s86_pool_gpu.py')}
exec((ROOT/'docs/tools/check_s86_pool_gpu.py').read_text().split('\nreports=[]\n',1)[0],e)
render=e['render'];old=e['metric']+e['core']+(OUT/'baseline/shaders/rainBirthEvent.hlsl').read_text()
density=e['b']['values']['gBirthNumberDensity'];cases=[]
for label,factor,busy,extra in [('sparse',.03,False,{}),('rain',1,False,{}),('overflow',2.5,False,{}),
    ('occupied',1,True,{}),('occupied_overflow',2.5,True,{}),
    ('microscopic',1,False,{'gBirthMinPersistentMM':1}),
    ('wet_override',1,False,{'gBirthWetOverride':1}),
    ('reversed_normal',1,False,{'gBirthNormalSign':-1})]:
    meta=e['meta'].copy()
    if busy:meta[:,:,:]=(.001,1,1,29)
    values={**e['v'],'gPoolOn':0,'gBirthNumberDensity':density*factor,**extra}
    tx={**e['sourceTx'],'txRainState':e['state'],'txRainStateMeta':meta}
    a=render(label+'_current',e['eventCode'],tx,values,(128,4))
    b=render(label+'_stamp',old,tx,values,(128,4))
    assert np.array_equal(a,b),(label,float(np.max(abs(a-b))))
    cases.append(label)
(OUT/'birth_off_checks.json').write_text(json.dumps(dict(compiler='FXC /Ges /WX, D3D11 WARP',
    bitIdenticalTo='a23527e',cases=cases),indent=2))
print('s86 P4b OFF:',len(cases),'nonempty rain/capacity/overflow/material cases bit-identical')
