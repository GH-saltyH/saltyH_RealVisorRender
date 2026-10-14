"""Analyze user s80 cumulative/interval budgets; no game or runtime writes."""
from pathlib import Path
import re,json,math,hashlib,difflib
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/diagnostics/2026-10-15/s80/game_recheck'
rows=[]
for line in (OUT/'p2_actual.log').read_text().splitlines():
    if not line.startswith('[RealVisor'):continue
    row={key:float(value) for key,value in re.findall(r'([A-Za-z][\w-]*)=([-+]?\d+(?:\.\d+)?)',line)}
    row['recomputedResidualMM3']=row['input']-sum(row[k] for k in ('film-reserve','micro-reserve','bounce','capacity','exit','drops'))
    # Six-decimal text serialization rounds each independent field.
    assert abs(row['recomputedResidualMM3']-row['residual'])<4e-6
    row['relativeCumulativeError']=abs(row['residual'])/row['input']
    row['inputFloat32ULP_MM3']=2**(math.frexp(row['input'])[1]-24)
    assert row['area']==.040289
    rows.append(row)
assert len(rows)==6
groups=[]
for label,samples in [('stationary',rows[:3]),('straight_100_150_kmh',rows[3:])]:
    intervals=[]
    for previous,current in zip(samples,samples[1:]):
        dt=current['publishedSeconds']-previous['publishedSeconds']
        assert abs(dt-current['intervalSeconds'])<1.1e-6
        assert current['steps']>previous['steps'] and current['frame']>previous['frame']
        delta={k:current[k]-previous[k] for k in ('input','film-reserve','micro-reserve','bounce','capacity','exit','drops','arrivals')}
        inputRate=delta['input']/dt;arrivalRate=delta['arrivals']/dt
        assert abs(inputRate-current['inputRate'])<1e-5
        assert abs(arrivalRate-current['arrivalRate'])<2e-6
        residualDelta=current['residual']-previous['residual']
        assert abs(residualDelta-current['residualDelta'])<1.1e-6
        relativeError=abs(current['residualDelta'])/delta['input']
        assert relativeError<1e-4
        intervals.append(dict(startFrame=previous['frame'],endFrame=current['frame'],seconds=dt,
                              deltas=delta,inputRateMM3S=inputRate,arrivalRateS=arrivalRate,
                              residualDeltaMM3=current['residualDelta'],relativeError=relativeError))
    elapsed=samples[-1]['publishedSeconds']-samples[0]['publishedSeconds']
    delta={k:samples[-1][k]-samples[0][k] for k in ('input','film-reserve','micro-reserve','bounce','capacity','exit','drops','arrivals')}
    groups.append(dict(condition=label,intervals=intervals,seconds=elapsed,deltas=delta,
                       inputRateMM3S=delta['input']/elapsed,arrivalRateS=delta['arrivals']/elapsed,
                       filmMicroSharePercent=100*(delta['film-reserve']+delta['micro-reserve'])/delta['input'],
                       categorySharesPercent={k:100*delta[k]/delta['input'] for k in ('bounce','capacity','exit','drops')}))
report=dict(date='2026-10-15',build='s80',scope='P2 actual-game water conservation in supplied 60% stationary/straight-driving conditions',
            result='passed',samples=rows,stableConditions=groups,
            maxAbsoluteResidualMM3=max(abs(r['residual']) for r in rows),
            maxRelativeCumulativeError=max(r['relativeCumulativeError'] for r in rows),
            maxRelativeIntervalError=max(i['relativeError'] for g in groups for i in g['intervals']),
            drivingToStationaryInputRateRatio=groups[1]['inputRateMM3S']/groups[0]['inputRateMM3S'],
            drivingToStationaryArrivalRateRatio=groups[1]['arrivalRateS']/groups[0]['arrivalRateS'],
            limits=['First 0-second log in each condition excluded from stable interval averages.',
                    'No simultaneous P0 input snapshot; flux/DSD/material calibration not certified.',
                    'No new FPS or memory measurement; P3 film/micro/trail rendering remains unimplemented.',
                    'Cumulative film/micro reserves are past allocation totals, not a current wet field.'])
baseline=json.loads((OUT/'baseline_hashes.json').read_text(encoding='utf-8-sig'))
preserved={}
for entry in baseline:
    p=Path(entry['Path'])
    if p.suffix=='.lua' or p.suffix=='.hlsl':
        same=hashlib.sha256(p.read_bytes()).hexdigest().upper()==entry['Hash']
        assert same,p
        preserved[p.relative_to(ROOT).as_posix()]=same
report['runtimeUnchanged']=preserved
(OUT/'checks.json').write_text(json.dumps(report,indent=2))
diff=[]
for old in sorted((OUT/'baseline/docs').glob('*.md')):
    new=ROOT/'docs'/old.name
    diff.extend(difflib.unified_diff(old.read_text(encoding='utf-8-sig').splitlines(True),
        new.read_text(encoding='utf-8-sig').splitlines(True),fromfile='s80-delivery/docs/'+old.name,tofile='s80-game-pass/docs/'+old.name))
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
print(json.dumps({k:report[k] for k in ('result','maxAbsoluteResidualMM3','maxRelativeCumulativeError',
      'maxRelativeIntervalError','drivingToStationaryInputRateRatio','drivingToStationaryArrivalRateRatio')},indent=2))
for group in groups:
    print(group['condition'],json.dumps({k:v for k,v in group.items() if k!='intervals'},indent=2))
