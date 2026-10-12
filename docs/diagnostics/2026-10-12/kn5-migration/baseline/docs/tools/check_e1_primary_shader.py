"""Compile the actual E1 primary shader and check projected traversal math."""
from pathlib import Path
import math, subprocess, tempfile

root=Path(__file__).resolve().parents[2]
source=(root/'realvisor.lua').read_text(encoding='utf-8-sig')
start=source.index('rainDynamicSceneCopyState.e1PrimaryDraw = function(')
a=source.index('shader = [[',start)+len('shader = [[')
b=source.index('}]]}',a)+1
shader=source[a:b].replace('main(PS_IN pin)', 'main(PS_IN pin):SV_TARGET')
header='''
struct PS_IN { float4 PosH:SV_POSITION; float3 PosC:TEXCOORD0; float3 NormalW:TEXCOORD1; };
Texture2D txE1Depth,txE1Source,txE1DebugLight;
SamplerState samPointClamp,samLinearClamp;
float4x4 gE1Projection,gE1View;
float3 gE1EyeToSource;
float gE1TraceRange,gE1TraceSamples,gE1Parallax,gE1Mode,gE1Checker,gE1Mip,
    gE1MeanFloor,gE1Threshold,gE1Knee,gE1Gain,gE1Resolve;
'''
with tempfile.TemporaryDirectory(prefix='e1_primary_',dir=root/'docs/tools') as folder:
    path=Path(folder)/'primary.hlsl';path.write_text(header+shader,encoding='utf-8')
    fxc='C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe'
    subprocess.run([fxc,'/nologo','/T','ps_5_0','/E','main','/Fo',str(Path(folder)/'primary.cso'),str(path)],check=True)
    start=source.index('rainDynamicSceneCopyState.e1PrimaryResolveDraw = function()')
    a=source.index('shader=[[',start)+len('shader=[[')
    b=source.index('}]]}',a)+1
    resolve=source[a:b].replace('main(PS_IN pin)', 'main(PS_IN pin):SV_TARGET')
    resolve_header='''
    struct PS_IN { float4 PosH:SV_POSITION; float3 PosC:TEXCOORD0; };
    Texture2D txResolve; SamplerState samLinearClamp,samPointClamp;
    float3 gResolveEyeDelta;float4x4 gResolveView,gResolveProjection;
    float2 gResolveSize;float gResolveRadius,gResolveScale;
    '''
    path.write_text(resolve_header+resolve,encoding='utf-8')
    subprocess.run([fxc,'/nologo','/T','ps_5_0','/E','main','/Fo',str(Path(folder)/'resolve.cso'),str(path)],check=True)
print('PASS: actual E1 primary and reflection resolve shaders FXC ps_5_0')
# Strong perspective change: projected intervals remain uniform and ordered.
lo,hi,w0,w1=0.001,1.5,0.02,1.0
previous=-1
for j in range(129):
    s=j/128
    t=((1-s)*lo/w0+s*hi/w1)/((1-s)/w0+s/w1)
    w=w0+(w1-w0)*(t-lo)/(hi-lo)
    # Projected displacement along a line with x0=0 and x1=w1.
    projected=w1*(t-lo)/(hi-lo)/w
    assert t>previous and math.isclose(projected,s,abs_tol=1e-12)
    previous=t
assert math.isclose(previous,hi)
print('PASS: perspective-correct traversal ordering, endpoints and projected spacing')
