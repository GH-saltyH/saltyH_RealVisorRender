"""Narrow compiler warning isolation; no runtime mutation."""
from pathlib import Path
p=Path(__file__).with_name('check_s77_binding.py')
src=p.read_text();ns={'__file__':str(p)};exec(src[:src.index("a=render('SI_transport'")],ns)
for name,replace in [('no_grid',{'gRainStatePhysicalGridTest':'0.0'}),
                     ('no_init',{'gRainStateInit':'0.0'}),
                     ('no_lifecycle',{'gRainStateLifecycle':'0.0'}),
                     ('no_physics',{'gRainStatePhysics':'0.0'}),
                     ('all_off',{'gRainStatePhysics':'0.0','gRainStateInit':'0.0','gRainStateLifecycle':'0.0'}),
                     ('only_physics',{'gRainStateInit':'0.0','gRainStateLifecycle':'0.0'}),
                     ('only_birth',{'gRainStatePhysics':'0.0','gRainStateInit':'0.0'}),
                     ('legacy_baseline',{})]:
    code=ns['oldState'] if name=='legacy_baseline' else ns['stateCode']
    for k,v in replace.items():code=code.replace(k,v)
    try:
        a=ns['render']('isolate_'+name,code,ns['textures'],ns['values'],(1,1));print(name,'OK',a[0,0])
    except AssertionError as e:print(name,str(e).split('error X4000:')[-1].strip())
head=ns['stateCode'][:ns['stateCode'].index('float4 main(PS_IN pin)')]
for name,tail in [
    ('direct_birth','return float4(rainStateRespawnPosition(0,0,float2(.5,-.5)),0,0);'),
    ('direct_physics','return rainStateUpdatePhysics(float2(.5,-.5),float2(0,0),.001,.796328,0,.01);'),
    ('direct_advance','return rainAdvance(float2(.5,-.5),float2(.05,-.098),.01);')]:
    code=head+'float4 main(PS_IN pin){'+tail+'}'
    try:print(name,ns['render']('isolate_'+name,code,ns['textures'],ns['values'],(1,1)))
    except AssertionError as e:print(name,str(e).split('error X4000:')[-1].strip())
