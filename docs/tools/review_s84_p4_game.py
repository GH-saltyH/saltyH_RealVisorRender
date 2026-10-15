"""Analyze supplied, non-consecutive P4 snapshots and timestamped original media."""
from pathlib import Path
import json,re,sys,subprocess,math
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s84'
water=[];flow=[]
for line in (OUT/'p4_actual.log').read_text().splitlines():
    if not line.startswith('[RealVisor'):continue
    row={k:float(v) for k,v in re.findall(r'([A-Za-z][\w-]*)=([-+]?\d+(?:\.\d+)?)',line)}
    if 'current-field' in line:
        row['limitedCellPercent']=100*row['limitedCells']/row['wetCells']
        row['worstVelocityRetainedFraction']=.8/row['maxCourant']
        row['nominalSubstepsToAvoidLimit']=math.ceil(row['maxCourant']/.8)
        flow.append(row)
    else:
        recomputed=row['input']-sum(row[k] for k in ('film','micro','drops','bounce','exit','headEvap','fieldEvap','runoff'))
        assert abs(recomputed-row['residual'])<5e-6,(recomputed,row)
        row['relativeCumulativeError']=abs(row['residual'])/row['input'];water.append(row)
assert len(water)==len(flow)==6
groups=[]
for label,ss in [('stationary',water[:3]),('straight_137kmh',water[3:])]:
    intervals=[]
    for a,b in zip(ss,ss[1:]):
        seconds=b['publishedSeconds']-a['publishedSeconds']
        delta={k:b[k]-a[k] for k in ('input','film','micro','drops','bounce','exit','headEvap','fieldEvap','runoff','trailTransferred')}
        dr=b['residual']-a['residual'];relative=abs(dr)/delta['input']
        assert relative<1e-4
        intervals.append(dict(seconds=seconds,deltas=delta,residualDeltaMM3=dr,relativeError=relative,
            sourceRateMM3S=delta['input']/seconds,
            printedIntervalMatchesProvidedPair=abs(seconds-b['intervalSeconds'])<2e-6,
            printedResidualDeltaMatchesProvidedPair=abs(dr-b['residualDelta'])<2e-6))
    groups.append(dict(condition=label,intervals=intervals))
report=dict(scope='supplied 60% P4 stationary/137kmh observations after session warm-up',water=water,flow=flow,
    stableIntervals=groups,maxRelativeIntervalError=max(i['relativeError'] for g in groups for i in g['intervals']),
    maxAbsoluteResidualMM3=max(r['residual'] for r in water),
    maxRelativeCumulativeError=max(r['relativeCumulativeError'] for r in water),
    waterConservation='passes supplied interval criterion, not a long-run certification',
    transportTimeAccuracy='fails: large raw Courant; only positivity is certified by limiter',
    performance={'p3FPS':[65,66,66,65,70,65], 'p4FPS':'user judges equal by segment; no separate numeric P4 vector supplied',
                 'p3MemoryMB':[79.70,145.92],'p4MemoryMB':None,
                 'warmup':'same continuous replay session, over 30 minutes since load before test; not 30 minutes of P4 runtime'},
    limitations=['Provided water logs are not all consecutive button presses: recompute deltas from publishedSeconds and cumulative counters.',
        'Flow and water frames differ by 48..81 frames; limitedFilm/currentFilm ratios cannot be treated as exact same-frame fractions.',
        'Image list is under user P3Only heading; filename P4 is not proof P4 was enabled.',
        'P4 current Memory range is not supplied separately.'])
(OUT/'game_checks.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k not in ('water','flow','stableIntervals')},indent=2))
for g in groups:print(g['condition'],[(round(i['seconds'],6),i['relativeError']) for i in g['intervals']])
print('Flow limited cells %:',[r['limitedCellPercent'] for r in flow])
if '--media' in sys.argv:
    BIN=Path('C:/Users/songak/AppData/Local/Overwolf/Extensions/ncfplpkmiejjaklknfnkgcpapnhkggmlcppckhcb/270.0.10/obs/bin/64bit')
    frames=OUT/'frames';frames.mkdir(exist_ok=True);metadata=[]
    for idx,path in enumerate(sorted((ROOT/'docs/videos/s83_P4_GAME_REVIEW').glob('*.mp4'))):
        m=json.loads(subprocess.check_output([str(BIN/'ffprobe.exe'),'-v','quiet','-print_format','json','-show_format','-show_streams',str(path)]))
        duration=float(m['format']['duration']);stream=next(s for s in m['streams'] if s['codec_type']=='video')
        times=[duration*j/9 for j in range(1,9)]
        sheet=Image.new('RGB',(1280,1560),'#222');draw=ImageDraw.Draw(sheet)
        for j,t in enumerate(times):
            dest=frames/f'video{idx}_{j}.png'
            subprocess.run([str(BIN/'ffmpeg.exe'),'-v','error','-y','-ss',str(t),'-i',str(path),'-frames:v','1',str(dest)],check=True)
            frame=Image.open(dest).convert('RGB');frame.thumbnail((640,360))
            x=j%2*640;y=j//2*390;sheet.paste(frame,(x,y+30));draw.text((x+8,y+8),f'{idx}: {t:.3f}s',fill='white')
        sheet.save(frames/f'video{idx}_sheet.jpg',quality=92)
        metadata.append(dict(index=idx,path=path.relative_to(ROOT).as_posix(),duration=duration,width=stream['width'],height=stream['height'],times=times))
    (OUT/'media.json').write_text(json.dumps(metadata,indent=2));print(json.dumps(metadata,indent=2))
