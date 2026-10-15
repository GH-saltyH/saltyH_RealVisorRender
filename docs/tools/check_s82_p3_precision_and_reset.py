"""Targeted long float32 arithmetic and repeated production reset checks.
The arithmetic fixture reuses pfResolve's body, replacing only its previous
texture Load with a loop argument. It is NOT a full long game simulation.
"""
from pathlib import Path
import sys,json,re
import numpy as np
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s82'
base=(ROOT/'docs/tools/check_s63_gpu.py').read_text();env={'__file__':str(ROOT/'docs/tools/check_s63_gpu.py')}
exec(base[:base.index('report=[]')],env);env['OUT']=OUT
resolve=(ROOT/'shaders/rainFilmResolve.hlsl').read_text()
start=resolve.index('float4 pfTransportFlux(') if 'float4 pfTransportFlux(' in resolve else resolve.index('float4 pfResolve(')
body=resolve[start:]
assert body.count('float4 old=txFilmPrevious.Load(int3(p,0));')==1
body=body.replace('float4 pfResolve(float2 cell,float4 fresh)','float4 pfResolve(float2 cell,float4 fresh,float4 old)')
body=body.replace('float4 old=txFilmPrevious.Load(int3(p,0));','')
wrapper='''
float4 main(PS_IN pin) {
    int i=(int)(pin.Tex.x*4);
    float4 setup=txSetup.Load(int3(i,0,0));
    float4 state=txInitial.Load(int3(i,0,0));
    [loop] for(int j=0;j<(int)setup.w;++j)state=pfResolve(float2(0,0),float4(setup.xy,0,0),state);
    return state;
}'''
env['types'].update(gFilmGrid='float2')
initial=np.array([[[.025,.003,0,0],[.025,.003,0,0],[.025,.003,0,0],[.025,.003,0,0]]],np.float32)
setup=np.array([[[.0000006,.0000002,0,42007],[.0000006,.0000002,0,66000],
                 [.00002,.000002,0,42007],[.00002,.000002,0,66000]]],np.float32)
cells=np.array([[[.25,1,0,1]]],np.float32)
result=env['render']('long_pfResolve_arithmetic',body+wrapper,{'txSetup':setup,'txInitial':initial,'txFilmCells':cells},
    dict(gFilmPad=0,gFilmGrid=(1,1),gFilmScale2=1,gFilmMicroJoinUM=20,gFilmEvapUMS=.02417,gFilmDt=.016),(4,1))
cases=[]
for i in range(4):
    source=float(setup[0,i,:2].sum(dtype=np.float64))*int(setup[0,i,3])
    expected=float(initial[0,i].sum(dtype=np.float64))+source
    residual=expected-float(result[0,i].sum(dtype=np.float64))
    cases.append(dict(steps=int(setup[0,i,3]),expectedMM3=expected,residualMM3=residual,
                      relativeInputError=abs(residual)/source,stockAndLosses=result[0,i].tolist()))
(OUT/'precision_checks.json').write_text(json.dumps(dict(compiler='FXC /Ges /WX, D3D11 WARP',
    scope='production pfResolve arithmetic in a single shader loop, no spatial/bin/source integration',cases=cases),indent=2))
print('Arithmetic:',json.dumps(cases,indent=2))
# Run the original production Lua fixture with an isolated output directory,
# instrumenting bank liveness and appending 100 real mode resets/publications.
text=(ROOT/'docs/tools/check_s81_film_binding.py').read_text()
anchor="OUT=ROOT/'docs/diagnostics/2026-10-15/s81'";assert text.count(anchor)==1
text=text.replace(anchor,"OUT=ROOT/'docs/diagnostics/2026-10-15/s82'")
text=text.replace('allocations=0;disposals=0;','liveBanks=0;allocations=0;disposals=0;',1)
text=text.replace('function bank(name)\n', 'function bank(name)\n            liveBanks=liveBanks+1\n',1)
text=text.replace('s.disposed=true;disposals=disposals+1','s.disposed=true;disposals=disposals+1;liveBanks=liveBanks-1',1)
anchor="report=dict(wholeLuaSyntax=True";assert text.count(anchor)==1
extra='''    lua.execute("""
        assert(liveBanks==0,'initial reset left live banks: '..liveBanks)
        local steadyOn=nil;local steadyOff=nil
        for cycle=1,100 do
            runtime.RAIN_PHYSICS_P3_FILM_PREVIEW=cycle%2==1
            actualReset();assert(liveBanks==0,'reset leaked banks at cycle '..cycle)
            rainStateA=bank('state A');rainStateB=bank('state B')
            rainStateMetaA=bank('meta A');rainStateMetaB=bank('meta B')
            sim.frame=100+cycle;assert(framePublish(sim))
            for j=1,3 do sim.frame=sim.frame+1000;assert(framePublish(sim)) end
            if runtime.RAIN_PHYSICS_P3_FILM_PREVIEW then
                if not steadyOn then steadyOn=liveBanks end
                assert(liveBanks==steadyOn and liveBanks==16,'P3 live bank growth')
                assert(f:logBudget());local cb=pendingCallback
                runtime.RAIN_PHYSICS_P3_FILM_PREVIEW=false;actualReset()
                cb(nil,{dispose=function() dataDisposed=dataDisposed+1 end})
                assert(liveBanks==0 and not f.ready and not f.logPending)
                -- Update the stored mode before the next cycle's reset.
                runtime.RAIN_PHYSICS_P3_FILM_PREVIEW=true
                actualReset()
            else
                if not steadyOff then steadyOff=liveBanks end
                assert(liveBanks==steadyOff and liveBanks==8,'P2 live bank growth')
            end
        end
        rainStateSingleDropDirty=true;actualReset();assert(liveBanks==0)
    """)
    (OUT/'reset_checks.json').write_text(json.dumps(dict(cycles=100,
        productionModuleAndMainReset=True,steadyP3LiveBanks=16,steadyP2LiveBanks=8,
        resetLiveBanks=0,staleReadbacksDisposed=True,
        limitation='mocked CSP canvas handles; does not measure SDK/driver caches or Lua post-GC heap'),indent=2))
'''
text=text.replace(anchor,extra+anchor)
sys.path.insert(0,str(ROOT/'docs/tools'))
exec(compile(text,str(ROOT/'docs/tools/check_s81_film_binding.py'),'exec'),{'__file__':str(ROOT/'docs/tools/check_s81_film_binding.py')})
print('100 production mode-reset cycles: constant live-bank counts, zero after reset')
