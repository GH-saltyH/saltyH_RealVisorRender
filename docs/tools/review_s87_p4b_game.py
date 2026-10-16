"""Review supplied P4b paired snapshots, with explicit unmatched-run limitations."""
from pathlib import Path
import json,re,math
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-16/s87'
lines=(OUT/'p4b_actual.log').read_text().splitlines()
old=json.loads((ROOT/'docs/diagnostics/2026-10-15/s85/regime_review.json').read_text())['evidence']
cells=np.frombuffer((ROOT/'texture/RAIN_FILM/cells.dds').read_bytes(),'<f4',offset=148).reshape(256,1024,4)
rows=[]
for i,condition in enumerate(('stationary','137km/h')):
    budget,flow=({k:float(v) for k,v in re.findall(r'(\w+)=([-+\d.eE]+)',line)} for line in lines[2*i:2*i+2])
    assert budget['frame']==flow['frame'] and budget['film']==flow['totalFilmMM3']
    balance=budget['input']-sum(budget[k] for k in ('film','micro','drops','bounce','exit','headEvap','fieldEvap','runoff'))
    assert abs(balance-budget['residual'])<1e-5
    assert abs(flow['limitedFilmMM3']/budget['film']-flow['limitedMassShare'])<1e-6
    assert flow['above1mmFilmMM3']==0 and budget['poolReturned']>0
    x,y=map(int,re.search(r'worstCell=\((\d+),(\d+)\)',lines[2*i+1]).groups())
    rows.append(dict(condition=condition,budget=budget,flow=flow,
        derived=dict(relativeCumulativeResidual=abs(budget['residual'])/budget['input'],
            recalculatedResidualMM3=balance,limitedWetCellsPercent=100*flow['limitedCells']/flow['wetCells'],
            velocitySuppressedPercent=100*(1-flow['massWeightedVelocityRetained']),
            areaMeanFilmUM=budget['film']/float(cells[:,:,0].sum(dtype=np.float64))*1000,
            worstCellModelVelocityRetained=.8/flow['maxCourant'],
            nominalUniformSubsteps=math.ceil(flow['maxCourant']/.8)),
        staticCell=dict(x=x,y=y,areaMM2=float(cells[y,x,0]),coverage=float(cells[y,x,1]),coating=float(cells[y,x,2])),
        priorP4a=dict(frame=old[i]['budget']['frame'],publishedSeconds=old[i]['budget']['publishedSeconds'],
            inputMM3=old[i]['budget']['input'],limitedMassShare=old[i]['flow']['limitedMassShare'],
            velocityRetained=old[i]['flow']['massWeightedVelocityRetained'],maxFilmUM=old[i]['flow']['maxFilmUM']),
        comparisonIsMatched=False))
a,b=(r['budget'] for r in rows)
elapsed=b['publishedSeconds']-a['publishedSeconds'];dr=b['residual']-a['residual'];di=b['input']-a['input']
assert abs(dr)/di<1e-4
assert abs(elapsed-b['intervalSeconds'])<2e-6 and abs(dr-b['residualDelta'])<2e-6
report=dict(date='2026-10-16',step='s87',scope='Supplied 60% same-condition replay; two paired P4b snapshots plus two approximately 40s captures',
    observations=rows,transitionInterval=dict(seconds=elapsed,inputDeltaMM3=di,residualDeltaMM3=dr,
        relativeResidual=abs(dr)/di,poolReturnDeltaMM3=b['poolReturned']-a['poolReturned'],
        condition='Includes stationary -> driving transition, not a steady 137km/h rate'),
    performance=dict(offFPS=67,onFPS=67,offMemoryMB=82.52,onMemoryMB=85.99,memorySnapshotDeltaMB=3.47,
        capture='Replay initial run, P1..P4 plus optional P4b, user captures around40s; not exact timestamp matching',
        verdict='No visible FPS regression at supplied precision; memory samples do not establish retained growth or a leak'),
    gates=dict(conservation='passes supplied cumulative/transition criterion; not a long-run certificate',
        poolReturn='active in both snapshots',extremeColumns='no >1mm film stock in either snapshot',
        transportTimeAccuracy='still open: raw C17.28/60.21 and limited mass11.75/17.25%',
        headFieldVisualContinuity='unresolved; head WF slope debug and head-only display gain2 do not isolate physical coupling',
        fullLoadAndLongMemory='not measured by these data'))
(OUT/'game_checks.json').write_text(json.dumps(report,indent=2))
print('Same-frame water conservation:',[r['derived']['relativeCumulativeResidual'] for r in rows])
print('Transition conservation:',report['transitionInterval'])
print('Current limiting:',[(r['flow']['limitedMassShare'],r['flow']['massWeightedVelocityRetained']) for r in rows])
print('Worst cell metrics:',[r['staticCell'] for r in rows])
