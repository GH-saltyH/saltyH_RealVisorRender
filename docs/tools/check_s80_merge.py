"""Reproduce curved-metric one-sided SI merges in actual state/meta shaders."""
from pathlib import Path
import sys,json
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/diagnostics/2026-10-15/s80'
prefix=(ROOT/'docs/tools/check_s79_birth_gpu.py').read_text().split("events=render(",1)[0]
env={'__file__':str(ROOT/'docs/tools/check_s79_birth_gpu.py')}
exec(prefix,env)
env['env']['OUT']=OUT
np=env['np'];render=env['render'];helpers=env['helpers'];metric=env['metric'];core=env['core'];code=env['code']
ref=env['ref'];vols=[env['math'].pi*.65**3/6,env['math'].pi*2.25**3/6]
report=[]
for version in ('baseline','current'):
    path=OUT/'baseline' if version=='baseline' else ROOT
    source=(path/'realvisor.lua').read_text(encoding='utf-8-sig')
    sc='#define RAIN_MERGE_CODE\n'+metric+core+helpers(source,'local rainStateUpdateParams =')+(path/'shaders/rainStateEntry.hlsl').read_text()
    mc='#define RAIN_MERGE_CODE\n'+metric+core+helpers(source,'local rainStateMetaUpdateParams =')+(path/'shaders/rainMetaEntry.hlsl').read_text()
    du=env['du'].copy();du[:,:16,0]=.5;du[:,16:,0]=2
    state=np.array([[[.499,-.5,0,0],[.501,-.5,0,0]]],np.float32)
    command=np.array([[[0,1/255,64/255,1],[0,0,64/255,1]]],np.float32)
    for direction in ('small_left','large_left'):
        diameters=[.65,2.25] if direction=='small_left' else [2.25,.65]
        vv=vols if direction=='small_left' else list(reversed(vols))
        meta=np.array([[[d*2**(1/3)*ref/2,v,2,1] for d,v in zip(diameters,vv)]],np.float32)
        tx={**env['textures'],'txRainDu':du,'txRainState':state,'txRainStateMeta':meta,'txRainMergeCmd':command}
        val={**env['motion'],'gRainStateCount':2,'gRainStateDeltaTime':0,'gRainMergeEnabled':1,'gRainMergeReach':1.15}
        newMeta=render(f'{version}_{direction}_meta',mc,tx,val,(2,1))
        newState=render(f'{version}_{direction}_state',sc,tx,val,(2,1))
        residual=float(meta[:,:,1].sum(dtype=np.float64)-newMeta[:,:,1].sum(dtype=np.float64))
        report.append(dict(version=version,case=direction,oldVolume=meta[:,:,1].tolist(),newVolume=newMeta[:,:,1].tolist(),residualMM3=residual,newState=newState.tolist()))
        if version=='baseline':assert abs(residual)>vols[0]*.99
        else:assert abs(residual)<1e-6 and np.array_equal(newMeta[:,:,1],meta[:,:,1])
    # Close neighbours still merge; stale commands cannot transfer departed water.
    for case in ('close_pair','departed_partner'):
        ss=state.copy();ss[0,0,0]=.5;ss[0,1,0]=.5001
        boundary=env['mask'].copy()
        if case=='departed_partner':
            ss[0,0,0]=.499
            ss[0,1,0]=.50001
            boundary[:,:16,3]=0
        mm=np.array([[[d*2**(1/3)*ref/2,v,2,1] for d,v in zip([.65,2.25],vols)]],np.float32)
        tx={**env['textures'],'txRainDu':du,'txRainBoundaryMask':boundary,
            'txRainState':ss,'txRainStateMeta':mm,'txRainMergeCmd':command}
        newMeta=render(f'{version}_{case}',mc,tx,val,(2,1))
        event=render(f'{version}_{case}_event',env['eventCode'],tx,
                     {**env['values'],'gBirthCount':2,'gBirthNumberDensity':0},(2,4))
        exited=float(event[3,:,1].sum(dtype=np.float64))
        residual=float(mm[:,:,1].sum(dtype=np.float64)-newMeta[:,:,1].sum(dtype=np.float64)-exited)
        report.append(dict(version=version,case=case,residualMM3=residual,exitMM3=exited,newVolume=newMeta[:,:,1].tolist()))
        if case=='close_pair':assert newMeta[0,0,1]==0 and abs(residual)<1e-6
        elif version=='baseline':assert residual<-vols[0]*.99,(newMeta,exited,residual,event[3])
        else:assert newMeta[0,0,1]==0 and newMeta[0,1,1]==mm[0,1,1] and abs(residual)<1e-6
(OUT/'merge_checks.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
