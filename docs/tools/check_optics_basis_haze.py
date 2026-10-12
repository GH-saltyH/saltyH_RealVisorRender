"""Read production normal-basis and condensation functions back through D3D11.

Neighbouring raster derivatives are deliberately absent: mapped normals must
remain valid at UV seams and when screen-space hits switch mesh/triangle.
"""
from pathlib import Path
import re, subprocess, tempfile, struct
import numpy as np

root=Path(__file__).resolve().parents[2]
fxc='C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe'
vc='C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Auxiliary/Build/vcvars64.bat'
trace=(root/'shaders/visorOpticsTrace.hlsl').read_text()
basis=trace[trace.index('float3 optWorldVector'):trace.index('bool optMesh')]
basis+=trace[trace.index('float3 optMapNormal'):trace.index('float4 optRepeatMip')]
drop=(root/'shaders/rainVisorDynamicDrop.hlsl').read_text(encoding='utf-8-sig')
haze=drop[drop.index('float4 rainHazeEvalBase'):drop.index('// The smear itself')]
header='struct PS_IN {float4 PosH:SV_POSITION;float3 PosC:TEXCOORD0;float3 NormalW:TEXCOORD1;float2 Tex:TEXCOORD2;};\n'

def vector(v):return 'float3('+','.join(map(str,v))+')'
def matrix(m):return 'float4x4('+','.join(map(str,m.flatten()))+')'
fixtures=[]
for name,m,t,b,n in [
    ('UV basis',np.eye(4),[1,0,0],[0,1,0],[0,0,1]),
    ('mirrored UV basis',np.eye(4),[-1,0,0],[0,1,0],[0,0,1]),
    ('scaled rotated UV basis',np.array([[0,2,0,0],[-3,0,0,0],[0,0,.5,0],[10000,20,13000,1.]]),[1,0,0],[0,1,0],[0,0,1]),
    ('degenerate UV basis falls back to smooth normal',np.eye(4),[0,0,0],[0,0,0],[0,0,1]),
]:
    inv=np.linalg.inv(m);tw=np.array(t)@m[:3,:3];bw=np.array(b)@m[:3,:3]
    nw=np.array(n)@inv[:3,:3].T;nw/=np.linalg.norm(nw)
    tt=tw-nw*np.dot(nw,tw)
    expected=nw
    if np.linalg.norm(tt)>1e-10:
        tt/=np.linalg.norm(tt);bb=np.cross(nw,tt);bb*=1 if np.dot(bb,bw)>=0 else -1
        expected=tt*.1+bb*.2+nw*np.sqrt(.95)
    shader=basis+'\nfloat4 main(PS_IN pin):SV_TARGET {return float4(optMapNormal('+vector(nw)+',optWorldVector('+vector(t)+','+matrix(inv)+'),optWorldVector('+vector(b)+','+matrix(inv)+'),float2(.1,.2)),1);}'
    fixtures.append((name,shader,(*expected,1)))

for rain,threshold in [(0,.05),(0,.5),(0,.95),(.0001,.05),(.5,.05),(1,.05),(1,.95)]:
    values={name:'0' for name in re.findall(r'\bgDynamicDrop\w+|\bgSmearMask|\bgFogTone',haze)}
    values.update(gDynamicDropHazeEnabled='1',gDynamicDropHazeRain=str(rain),gDynamicDropHazeRevealSoft='.4',
                  gDynamicDropHazeStrength='.57',gDynamicDropHazeMottle='.5',gDynamicDropHazeDebug='1')
    stubs='SamplerState samLinearClamp;Texture2D txDynamicTrailMask,txDynamicWaterTrail;\n'
    for name,value in sorted(values.items()):
        typ='float2' if name in ['gDynamicDropInvRenderTargetSize','gDynamicDropInvScreenSize'] else 'float3' if name=='gFogTone' else 'float'
        stubs+=f'static const {typ} {name}={value};\n'
    stubs+=f'float4 rainHazeField(float2 uv){{return float4(.8,.5,{threshold},.5);}}\n'
    stubs+='float rainSmearWipe(float x){return x;}float rainSmearVis(float x){return 1;}\n'
    stubs+='float4 rainSnap(SamplerState s,float2 uv,float mip){return float4(1,1,1,1);}\n'
    stubs+='float3 rainDynamicWeatherSkyTone(float3 c,float2 uv){return c;}\n'
    step=np.clip((rain-(threshold-.4))/.8,0,1);reveal=step*step*(3-2*step)
    amount=rain*reveal*.9*.57
    expected=(.15,.55,1,min(amount*1.5,1)) if amount>=.003 else (0,0,0,0)
    fixtures.append((f'haze rain={rain} threshold={threshold}',stubs+haze+'\nfloat4 main(PS_IN pin):SV_TARGET {return rainHazeEvalBase(float2(0,0),pin.Tex);}',expected))

with tempfile.TemporaryDirectory(prefix='optics_basis_',dir=root/'docs/tools') as temporary:
    temporary=Path(temporary);exe=temporary/'readback.exe'
    command=f'"{vc}" && cl /nologo /EHsc /std:c++17 "{root / "docs/tools/optics_shader_readback.cpp"}" /Fo"{temporary / "readback.obj"}" /Fe"{exe}" /link d3d11.lib d3dcompiler.lib'
    subprocess.run(command,shell=True,cwd=temporary,check=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    for name,source,expected in fixtures:
        hlsl=temporary/'fixture.hlsl';cso=temporary/'fixture.cso';data=temporary/'textures.bin'
        hlsl.write_text(header+source);data.write_bytes(struct.pack('<I',0))
        subprocess.run([fxc,'/nologo','/T','ps_5_0','/E','main','/Ges','/WX','/Fo',str(cso),str(hlsl)],check=True,stdout=subprocess.PIPE)
        actual=np.array([float(x) for x in subprocess.check_output([str(exe),str(cso),str(data)],text=True).split()])
        assert np.allclose(actual,expected,rtol=1e-5,atol=1e-5),(name,actual,expected)
        print('PASS: D3D11',name,actual.tolist())
