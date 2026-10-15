"""Only manual diagnostics change. Check reduction/argmax/units and snapshot pairing."""
from pathlib import Path
import sys,json,hashlib
import numpy as np
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s84'
text=(ROOT/'docs/tools/check_s83_flow_gpu.py').read_text().split("q=flux('gravity_faces'",1)[0]
text=text.replace("OUT=ROOT/'docs/diagnostics/2026-10-15/s83'","OUT=ROOT/'docs/diagnostics/2026-10-15/s84'")
env={'__file__':str(ROOT/'docs/tools/check_s83_flow_gpu.py')};exec(text,env)
render,code=env['render'],env['code'];v=env['values'];initial=env['initial'];geo=env['geo'];cells=env['cells']
flow=env['flowCode'];huge={**v,'gFilmDt':10,'gFilmAccelerationWorld':(1000,-1000,0)}
blocks=render('extended_diag_fine',flow+code('rainFilmFlowBlocks'),{**geo,'txFilmPrevious':initial,'txFilmCells':cells},huge,(6,12))
coarse=render('extended_diag_coarse',flow+code('rainFilmFlowBlocks'),{'txFilmFlowBlocks':blocks},
    {**huge,'gFilmPaddedSize':(6,3),'gFilmReductionSize':(5,2),'gFilmFlowReduce':1},(5,8))
stats=render('extended_diag_stats',code('rainFilmFlowStats'),{'txFilmFlowBlocks':coarse},{},(16,1))[0,:,0]
assert stats[1]==40 and stats[2]==40
assert abs(stats[3]-1)<1e-6 and abs(stats[5]-1)<1e-6
assert abs(stats[4]-100)<1e-4 and stats[7]==0
assert 0<stats[6]<stats[5] and stats[0]==stats[8]==stats[12]
assert abs(stats[11]-100)<1e-4 and stats[13]==.25 and abs(stats[14]-500)<1e-3
assert abs(stats[15]-np.sqrt(2)*1000)<1e-3
assert 20<=stats[9]<28 and 5<=stats[10]<10
# New stages only read field state: transport code and coefficients are unchanged.
unchanged={}
for name in ['shaders/rainFilmFlow.hlsl','shaders/rainFilmFlowPass.hlsl','shaders/rainFilmResolve.hlsl',
             'shaders/rainFilmDescriptor.hlsl','shaders/rainFilmOptics.hlsl']:
    unchanged[name]=(ROOT/name).read_bytes()==(OUT/'baseline'/name).read_bytes();assert unchanged[name]
# Current real mesh, uniform thickness, identity world transform, gravity only.
# This is an SI/metric probe, NOT reconstruction of a user's spatial field.
def asset(name):return np.frombuffer((ROOT/f'texture/RAIN_GEOMETRY/{name}.dds').read_bytes(),'<f4',offset=148).reshape(512,2048,4)
realCells=np.frombuffer((ROOT/'texture/RAIN_FILM/cells.dds').read_bytes(),'<f4',offset=148).reshape(256,1024,4)
realGeo={'txRainDu':asset('du'),'txRainDv':asset('dv')}
probe='''float4 main(PS_IN pin) {
    int2 p=min((int2)(pin.Tex*gFilmGrid),(int2)gFilmGrid-1)+(int)gFilmPad;
    FilmFlow f=ffEvaluate(p);float4 info=ffCellInfo(p);return float4(f.courant,info.x,info.y,0);
}'''
# Reuse diagnostic cell-info helper, omit its entrypoint.
infoCode=code('rainFilmFlowBlocks').split('float4 main(',1)[0]
probes=[]
for um in (100,1000):
    field=np.zeros((288,1056,4),np.float32);field[16:272,16:1040,0]=realCells[:,:,0]*(um*.001)
    vv={**v,'gFilmGrid':(1024,256),'gFilmPaddedSize':(1056,288),'gFilmDt':1/60}
    result=render('real_metric_'+str(um),flow+infoCode+probe,
        {**realGeo,'txFilmPrevious':field,'txFilmCells':realCells},vv,(1024,256))
    supported=realCells[:,:,0]>0;c=result[:,:,0][supported]
    probes.append(dict(heightUM=um,maxCourant=float(c.max()),medianCourant=float(np.median(c)),
                       limitedCellPercent=float(100*np.mean(c>.8))))
assert probes[1]['maxCourant']>probes[0]['maxCourant']*99
(OUT/'diagnostic_gpu_checks.json').write_text(json.dumps(dict(compiler='FXC /Ges /WX, D3D11 WARP',
    sixteenFloatValues=stats.tolist(),argmaxRowsMatch=True,unitProbe=probes,steadyShadersUnchanged=unchanged),indent=2))
print('Extended GPU diagnostics passed:',json.dumps(probes))
# Reuse previous actual-Lua fixtures, isolate their output, extend mock readback to16.
binding=(ROOT/'docs/tools/check_s83_flow_binding.py').read_text()
bindingPrefix=binding.split('exec(compile(text,',1)[0]
scope={'__file__':str(ROOT/'docs/tools/check_s83_flow_binding.py')};exec(bindingPrefix,scope)
binding=scope['text'].replace("OUT=ROOT/'docs/diagnostics/2026-10-15/s83'","OUT=ROOT/'docs/diagnostics/2026-10-15/s84'")
binding=binding.replace('local v={3.5,4,10,.125}','local v={3.5,4,10,.125,100,1,.6,0,3.5,2,3,80,3.5,.25,500,9.8}')
anchor='        for cycle=1,40 do';assert binding.count(anchor)==1
extra='''
        runtime.RAIN_PHYSICS_P4_TRANSPORT_PREVIEW=true;actualReset()
        local requests={};local originalBank=bank
        bank=function(name)
            local c=originalBank(name)
            c.accessData=function(s,cb) requests[#requests+1]=cb;pendingCallback=cb end
            return c
        end
        rainStateA=bank('state A');rainStateB=bank('state B');rainStateMetaA=bank('meta A');rainStateMetaB=bank('meta B')
        sim.frame=99;assert(framePublish(sim))
        f.flowLogPending=true;assert(not f:logSnapshot() and #requests==0 and not f.logPending)
        f.flowLogPending=false
        assert(f:logSnapshot() and #requests==2 and f.logPending and f.flowLogPending)
        assert(f.flowStats.size.x==16 and f.flowBlocks.size.y==72 and f.flowCoarse.size.y==8)
        local budget={2,1,.5,.25,0,0,0,0,10,3,1,2,.25,.7,.8,5}
        requests[1](nil,{floatValue=function(s,i,y) return budget[i+1] end,dispose=function() end})
        local diag={3.5,4,10,.125,100,1,.6,0,3.5,2,3,80,3.5,.25,500,9.8}
        requests[2](nil,{floatValue=function(s,i,y) return diag[i+1] end,dispose=function() end})
        assert(not f.logPending and not f.flowLogPending)
        assert(string.find(logMessages[#logMessages-1],'frame=99',1,true))
        assert(string.find(logMessages[#logMessages],'frame=99',1,true))
        assert(string.find(logMessages[#logMessages],'limitedMassShare=0.125000',1,true))
        assert(string.find(logMessages[#logMessages],'massWeightedVelocityRetained=0.600000',1,true))
        rainStateSingleDropDirty=true;actualReset();assert(liveBanks==0)
'''
binding=binding.replace(anchor,extra+anchor)
sys.path.insert(0,str(ROOT/'docs/tools'))
exec(compile(binding,str(ROOT/'docs/tools/check_s81_film_binding.py'),'exec'),{'__file__':str(ROOT/'docs/tools/check_s81_film_binding.py')})
(OUT/'paired_snapshot_checks.json').write_text(json.dumps(dict(sameFrameTwoReadbacks=True,
    diagnosticShape=[16,1],fieldShape=[66,72],coarseShape=[5,8],resetAndStaleEpoch=True),indent=2))
print('Extended Lua readback/pairing/reset fixtures passed')
