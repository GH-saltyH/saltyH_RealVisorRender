"""Run actual bounded physical-site respawn functions on D3D11 WARP."""
from pathlib import Path
import json,struct,subprocess,tempfile
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/diagnostics/2026-10-12/kn5-migration'
FXC='C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe'
EXE=ROOT/'docs/diagnostics/2026-10-11/native-visor-material/native_readback.exe'
lua=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
start=lua.index('        float2 rainStateSpawnHash(')
end=lua.index('        /*\n            Stage 7C physical max-speed model.',start)
functions=lua[start:end]
start=lua.index('        float2 rainStateRespawnPosition(')
end=lua.index('        float4 rainStateUpdatePhysics(',start)
functions+=lua[start:end]
source='''Texture2D txRainDu,txRainDv,txRainBoundaryMask,txRainPhysicalSites,txRainSpawnAtlas,txRainState,txRainStateMeta;
SamplerState samPointRain;
float gRainMetersPerUnit,gRainReferencePerMM,gRainStateInit,gRainStateCount,gRainSpawnAtlasEnabled;
'''+(ROOT/'shaders/rainSurfaceMetric.hlsl').read_text()+functions+'''
float4 main(float4 pixel:SV_POSITION):SV_TARGET {
    float2 p=rainStateRespawnPosition(floor(pixel.x),3,float2(2,2));
    return float4(p,rainValid(p),1);
}
'''
def data(key):
    return np.frombuffer((ROOT/f'texture/RAIN_GEOMETRY/{key}.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
sites=np.frombuffer((ROOT/'texture/RAIN_GEOMETRY/spawn_sites.dds').read_bytes(),'<f4',offset=148).reshape(1,8192,4)
textures={'txRainDu':data('du'),'txRainDv':data('dv'),
 'txRainBoundaryMask':np.asarray(Image.open(ROOT/'texture/RAINFX_ObjNormal_BoundaryMask.dds').convert('RGBA'),np.float32)/255,
 'txRainPhysicalSites':sites,'txRainSpawnAtlas':sites[:,:4096],
 'txRainState':np.zeros((1,4096,4),np.float32),'txRainStateMeta':np.zeros((1,4096,4),np.float32)}
report=[]
with tempfile.TemporaryDirectory(prefix='spawn_gpu_',dir=OUT) as folder:
    folder=Path(folder);hlsl=folder/'spawn.hlsl';hlsl.write_text(source);cso=folder/'spawn.cso'
    compile=subprocess.run([FXC,'/nologo','/T','ps_5_0','/E','main','/Ges','/Fo',str(cso),str(hlsl)],capture_output=True,text=True)
    assert compile.returncode==0,compile.stderr
    # Record compiler diagnostics alongside actual shader execution results.
    (OUT/'spawn_compiler.txt').write_text(compile.stdout+compile.stderr)
    inputs=folder/'textures.bin'
    with inputs.open('wb') as f:
        f.write(struct.pack('<I',len(textures)))
        for name,a in textures.items():
            b=name.encode();h,w,_=a.shape
            f.write(struct.pack('<I',len(b))+b+struct.pack('<4I',w,h,1,1)+a.astype('<f4').tobytes())
    for init,atlas in [(1,0),(0,0),(0,1)]:
        params=folder/'params.txt';output=folder/'out.bin'
        params.write_text(f'gRainMetersPerUnit {(.001/.0029296875)}\ngRainReferencePerMM .0029296875\ngRainStateInit {init}\ngRainStateCount 4096\ngRainSpawnAtlasEnabled {atlas}')
        subprocess.run([str(EXE),str(cso),str(inputs),str(params),str(output),'4096','1'],check=True,stdout=subprocess.PIPE)
        a=np.frombuffer(output.read_bytes(),'<f4').reshape(4096,4)
        assert np.isfinite(a).all() and np.all(a[:,2]>.5),a[a[:,2]<.5][:10]
        unique=len(np.unique(a[:,:2],axis=0));assert unique>2000,unique
        report.append({'initialization':init,'prelaid_atlas':atlas,'valid_births':4096,'unique_positions':unique})
(OUT/'spawn_gpu_checks.json').write_text(json.dumps(report,indent=2))
print('PASS: 4096 valid finite births for initialization, fallback respawn and prelaid atlas on D3D11 WARP')
