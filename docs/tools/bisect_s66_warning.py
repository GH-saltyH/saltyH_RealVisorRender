from pathlib import Path
import subprocess,json,concurrent.futures,time
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s66/warning';OUT.mkdir(parents=True,exist_ok=True)
base=(ROOT/'docs/diagnostics/2026-10-12/s66/shaders/rainWrapped.hlsl').read_text(encoding='utf-8')
def without_block(code,anchor):
    a=code.index(anchor);start=code.index('{',a);depth=1;end=start+1
    while depth:
        if code[end]=='{':depth+=1
        if code[end]=='}':depth-=1
        end+=1
    return code[:a]+code[end:]
a=base.index('float4 rainProduction(PS_IN pin)');b=base.index('\nfloat4 main(PS_IN pin)',a)
cases={'raw_entry':base[:a]+'float4 rainProduction(PS_IN pin){return float4(1,1,1,1);}\n'+base[b:],
 'drop_entry':base[:a]+'float4 rainProduction(PS_IN pin){return rainDropMain(pin);}\n'+base[b:]}
cases['no_coarse']=without_block(base,'    if (gDynamicDropDepthOnly > 0.5 && gDynamicDropDepthExact < 0.5)')
pos=cases['no_coarse'].index('    else\n    {',a)
cases['no_coarse']=cases['no_coarse'][:pos]+cases['no_coarse'][pos:].replace('    else\n    {','    {',1)
cases['no_flow_fill']=without_block(base,'    if (gFlowCoverage > 0.0 && gDynamicDropWFDebug < 0.5 && gDynamicDropSmearDebug < 0.5)')
cases['no_occlusion']=without_block(base,'    if(gDynamicDropOcclusionOn>.5)')
cases['no_debug']=without_block(base,'    if(gDynamicDropSurfaceDebug>6.5)')
cases['no_ldr_fog']=without_block(base,'    if (gDynamicDropLDR > 0.5)')
cases['no_exact_depth']=without_block(base,'    if (gDynamicDropDepthOnly > 0.5 && gDynamicDropDepthExact > 0.5)')
cases={'debug_init':base.replace('float3 u,v;rainMetric(p,u,v);','float3 u=float3(0,0,0),v=float3(0,0,0);rainMetric(p,u,v);'),
 'debug_return':base.replace('clip(pin.Tex.x<-2.5 ? 1 : -1);','if(pin.Tex.x>=-2.5)return float4(0,0,0,0);').replace('float2 p=float2(pin.Tex.x+4,pin.Tex.y);clip(rainValid(p)-.5);','float2 p=float2(pin.Tex.x+4,pin.Tex.y);if(rainValid(p)<.5)return float4(0,0,0,0);'),
 'debug_flat':base.replace('return float4(color,1);','return float4(1,0,1,1);'),
 'debug_unconditional':base.replace('clip(pin.Tex.x<-2.5 ? 1 : -1);','').replace('clip(rainValid(p)-.5);','')}
def run(item):
    name,code=item;p=OUT/(name+'.hlsl');p.write_text(code,encoding='utf-8');start=time.perf_counter()
    r=subprocess.run(['C:/Program Files (x86)/Windows Kits/10/bin/10.0.19041.0/x64/fxc.exe','/nologo','/T','ps_5_0','/E','main','/Ges','/WX','/Fo',str(OUT/(name+'.cso')),str(p)],capture_output=True,text=True)
    row={'case':name,'returncode':r.returncode,'ms':(time.perf_counter()-start)*1000,'output':r.stdout+r.stderr}
    print(name,r.returncode,row['output'][-650:],flush=True);return row
a=base.index('    gFlowSceneOffset =',base.index('float4 rainProduction('));b=base.index('    // Keep the coarse',a)
initialization=base[a:b]
code=base[:a]+base[b:]
entry=code.index('{',code.index('float4 rainProduction('))+1
cases={'debug_branch':base.replace('    if(gDynamicDropSurfaceDebug>6.5)', '    [branch] if(gDynamicDropSurfaceDebug>6.5)')}
begin=base.index('    if(gDynamicDropSurfaceDebug>6.5)');end=base.index('    float4 c =',begin)
diagnostic=base[begin:end]
cases['debug_program']=base[:begin]+'#ifdef RAIN_SURFACE_DEBUG\n'+diagnostic.replace('    if(gDynamicDropSurfaceDebug>6.5) {','    {')+'#else\n'+base[end:base.index('\nfloat4 main(PS_IN pin)',end)].rstrip()[:-1]+'#endif\n}\n'+base[base.index('\nfloat4 main(PS_IN pin)',end):]
cases['debug_program_on']='#define RAIN_SURFACE_DEBUG 1\n'+cases['debug_program']
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:rows=list(pool.map(run,cases.items()))
(OUT/'report.json').write_text(json.dumps(rows,indent=2))
