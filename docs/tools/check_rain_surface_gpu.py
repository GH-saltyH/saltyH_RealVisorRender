"""Execute production metric/transport HLSL on D3D11 WARP, with real bakes.

Checks measured radii, preserved speed across basis changes, and a hole that
an endpoint/midpoint check skips. Does not require the running game.
"""
from pathlib import Path
import io,json,struct,subprocess,tempfile
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
QA=ROOT/'docs/diagnostics/2026-10-12/kn5-migration';QA.mkdir(parents=True,exist_ok=True)
EXE=ROOT/'docs/diagnostics/2026-10-11/native-visor-material/native_readback.exe'
FXC='C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe'
metric=(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text()
header='Texture2D txRainDu,txRainDv,txRainBoundaryMask; float gRainMetersPerUnit,gRainReferencePerMM,gMode;float2 gTargetSize;float4 gStart;float gDeltaTime;\n'
source=header+metric+'''
float4 main(float4 pixel:SV_POSITION):SV_TARGET {
    float2 uv=pixel.xy/gTargetSize,p=float2(uv.x,uv.y-1);
    if(gMode>1.5)return rainAdvance(gStart.xy,gStart.zw,gDeltaTime);
    if(rainValid(p)<.5)return float4(0,0,0,0);
    float3 u,v;rainMetric(p,u,v);
    if(gMode<.5) {
        float3 force=float3(.6,-.7,.2);
        float2 velocity=rainMetricProject(p,force);
        float3 residual=force-(u*velocity.x+v*velocity.y)/gRainMetersPerUnit;
        float2 radius=rainMetricOffset(p,float2(.0029296875,0));
        return float4(abs(dot(residual,normalize(u))),abs(dot(residual,normalize(v))),
            abs(rainMetricLength(p,radius)-.0029296875),1);
    }
    float2 velocity=rainMetricOffset(p,float2(.57,.29));
    float4 moved=rainAdvance(p,velocity,gDeltaTime);
    if(rainValid(moved.rg)<.5)return float4(0,0,1,1);
    return float4(abs(rainMetricLength(moved.rg,moved.ba)-length(float2(.57,.29))),
        length(moved.rg-p),0,1);
}
'''
def write_textures(path,textures):
    with path.open('wb') as f:
        f.write(struct.pack('<I',len(textures)))
        for name,a in textures.items():
            b=name.encode();h,w,_=a.shape
            f.write(struct.pack('<I',len(b))+b+struct.pack('<4I',w,h,1,1))
            f.write(a.astype('<f4').tobytes())

report=[]
with tempfile.TemporaryDirectory(prefix='rain_gpu_',dir=QA) as tmp:
    tmp=Path(tmp);hlsl=tmp/'metric.hlsl';cso=tmp/'metric.cso';hlsl.write_text(source)
    subprocess.run([FXC,'/nologo','/T','ps_5_0','/E','main','/Ges','/WX','/Fo',str(cso),str(hlsl)],check=True,stdout=subprocess.PIPE)
    inputs=tmp/'textures.bin';params=tmp/'params.txt';out=tmp/'out.bin'
    def render(mode,scale=1,dt=.03,size=(128,32),start=(.1,-.5,1,0)):
        w,h=size
        params.write_text(f'gMode {mode}\ngRainMetersPerUnit {(.001/.0029296875)/scale}\ngRainReferencePerMM .0029296875\ngTargetSize {w} {h}\ngDeltaTime {dt}\ngStart '+' '.join(map(str,start)))
        subprocess.run([str(EXE),str(cso),str(inputs),str(params),str(out),str(w),str(h)],check=True,stdout=subprocess.PIPE)
        return np.frombuffer(out.read_bytes(),'<f4').reshape(h,w,4)
    textures={name:np.frombuffer((ROOT/f'texture/RAIN_GEOMETRY/{key}.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
              for name,key in [('txRainDu','du'),('txRainDv','dv')]}
    textures['txRainBoundaryMask']=np.asarray(Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').convert('RGBA'),np.float32)/255
    write_textures(inputs,textures)
    for scale in [1,2,.75]:
        result=render(0,scale);valid=result[:,:,3]>.5
        assert valid.sum()>1000
        error=np.max(result[valid,:3],axis=0)
        assert error[0]<2e-5 and error[1]<2e-5 and error[2]<1e-8,error
        report.append({'case':'force orthogonality and 1 mm reference radius','profile_scale':scale,'valid_samples':int(valid.sum()),'errors':error.tolist()})
    for dt in [.016,.05]:
        result=render(1,dt=dt);live=(result[:,:,3]>.5)&(result[:,:,2]<.5)
        print('transport dt',dt,'live',int(live.sum()),'exits',int((result[:,:,2]>.5).sum()))
        assert live.sum()>1000
        error=float(np.max(result[live,0]));assert error<3e-5,error
        report.append({'case':'inertial speed across new UV bases','dt':dt,'live_samples':int(live.sum()),'maximum_speed_error':error,'boundary_exits':int((result[:,:,2]>.5).sum())})
    # A one-texel hole at U=0.25: both endpoint (0.9) and midpoint (0.5)
    # are valid. Adaptive production transport must stop at the hole.
    du=np.zeros((2,8,4),np.float32);du[:]=[1,0,0,1]
    dv=np.zeros_like(du);dv[:]=[0,1,0,1]
    boundary=np.ones_like(du);boundary[:,2,3]=0
    write_textures(inputs,{'txRainDu':du,'txRainDv':dv,'txRainBoundaryMask':boundary})
    result=render(2,dt=.8,size=(1,1))[0,0]
    assert np.array_equal(result,[2,2,0,0]),result
    report.append({'case':'crossed one-texel hole exits, with no wrapping','result':result.tolist()})
    result=render(2,dt=.4,size=(1,1),start=(.9,-.5,1,0))[0,0]
    assert np.array_equal(result,[2,2,0,0]),result
    report.append({'case':'outer boundary exits','result':result.tolist()})
(QA/'rain_gpu_checks.json').write_text(json.dumps(report,indent=2))
print('PASS: D3D11 WARP real geometry force/radius, scaled profiles, transported inertia, holes and no wrap')
