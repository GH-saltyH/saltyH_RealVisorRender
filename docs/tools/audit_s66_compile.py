"""Time actual shader compilations, including CSP-style wrapped rain entry."""
from pathlib import Path
import re,subprocess,json,time,hashlib,difflib
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s66';OUT.mkdir(parents=True,exist_ok=True)
manifest=json.loads((OUT/'baseline/manifest.json').read_text())
previous=json.loads((ROOT/'docs/diagnostics/2026-10-12/s65/delivery.json').read_text())
old=(ROOT/'docs/diagnostics/2026-10-12/s65/baseline/realvisor.lua').read_text(encoding='utf-8')
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
for name in ('realvisor.lua','rain_surface.lua','native_glass_state.lua','native_glass_occlusion.lua'):
    p=ROOT/name
    print(name,'bytes',len(p.read_bytes()),flush=True)
model=ROOT/'visors/visor_lando_2025Champion_maxquality_diet_face.kn5'
with model.open('rb') as f: magic=f.read(6)
print('Model resolved:',model.resolve(),'magic',magic,flush=True)
report=[]
FXC='C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe'
names=['rainStateUpdateParams_full','rainStateMetaUpdateParams_full','gpuBounds','gpuHeadsPassB','rainVisorDynamicDrop','rainDepthCoverage','microPattern']
for name in names:
    code=(ROOT/'docs/diagnostics/2026-10-12/s65/shaders'/(name+'.hlsl')).read_text(encoding='utf-8')
    if name=='rainVisorDynamicDrop':
        normal=code
        wrapped=code.replace('float4 main(PS_IN pin):SV_TARGET','float4 rainProduction(PS_IN pin)')
        wrapped+='''
float4 main(PS_IN pin):SV_TARGET {
    pin.Tex+=float2(-4,-1);
    return rainProduction(pin);
}'''
        variants=[(name,normal),('rainWrapped',wrapped)]
    else:variants=[(name,code)]
    for label,code in variants:
        p=OUT/(label+'.hlsl');p.write_text(code,encoding='utf-8')
        start=time.perf_counter()
        run=subprocess.run([FXC,'/nologo','/T','ps_5_0','/E','main','/Ges','/WX','/Fo',str(OUT/(label+'.cso')),str(p)],capture_output=True,text=True)
        ms=(time.perf_counter()-start)*1000
        row={'shader':label,'compile_ms':ms,'returncode':run.returncode,'diagnostic':run.stdout+run.stderr}
        report.append(row);print(label,round(ms,1),'ms',run.returncode,(run.stdout+run.stderr)[-700:],flush=True)
(OUT/'cold_compile_audit.json').write_text(json.dumps(report,indent=2))
