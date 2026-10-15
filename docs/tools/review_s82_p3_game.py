"""Read user P3 budgets and timestamped media; leave runtime and originals intact."""
from pathlib import Path
import json, re, subprocess, hashlib, math
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/diagnostics/2026-10-15/s82';OUT.mkdir(exist_ok=True)
BIN=Path('C:/Users/songak/AppData/Local/Overwolf/Extensions/ncfplpkmiejjaklknfnkgcpapnhkggmlcppckhcb/270.0.10/obs/bin/64bit')
rows=[]
for line in (OUT/'p3_actual.log').read_text().splitlines():
    if not line.startswith('[RealVisor'):continue
    r={k:float(v) for k,v in re.findall(r'([A-Za-z][\w-]*)=([-+]?\d+(?:\.\d+)?)',line)}
    r['recomputedResidual']=r['input']-sum(r[k] for k in ('film','micro','drops','bounce','exit','headEvap','fieldEvap','runoff'))
    assert abs(r['recomputedResidual']-r['residual'])<5e-6
    r['relativeCumulativeError']=abs(r['residual'])/r['input']
    r['inputFloat32ULP']=2**(math.frexp(r['input'])[1]-24)
    r['filmMeanUM']=r['film']/40288.6009595*1000
    rows.append(r)
assert len(rows)==6
groups=[]
for label,samples in [('stationary',rows[:3]),('straight_137_kmh',rows[3:])]:
    intervals=[]
    for a,b in zip(samples,samples[1:]):
        dt=b['publishedSeconds']-a['publishedSeconds']
        assert abs(dt-b['intervalSeconds'])<1.1e-6
        delta={k:b[k]-a[k] for k in ('input','film','micro','drops','bounce','exit','headEvap','fieldEvap','runoff','trailTransferred','arrivals')}
        relativeError=abs(b['residualDelta'])/delta['input']
        assert relativeError<1e-4
        assert abs(delta['input']/dt-b['inputRate'])<1e-5
        intervals.append(dict(seconds=dt,deltas=delta,relativeError=relativeError,residualDelta=b['residualDelta']))
    dt=samples[-1]['publishedSeconds']-samples[0]['publishedSeconds']
    groups.append(dict(condition=label,intervals=intervals,seconds=dt,
        inputRate=(samples[-1]['input']-samples[0]['input'])/dt,
        filmGrowthRate=(samples[-1]['film']-samples[0]['film'])/dt,
        trailTransferRate=(samples[-1]['trailTransferred']-samples[0]['trailTransferred'])/dt))
baseline=json.loads((OUT/'baseline_hashes.json').read_text(encoding='utf-8-sig'))
unchanged={e['path']:hashlib.sha256((ROOT/e['path']).read_bytes()).hexdigest().upper()==e['hash']
           for e in baseline if (ROOT/e['path']).suffix in ('.lua','.hlsl')}
assert all(unchanged.values())
report=dict(scope='s81 game P3 water balance, supplied 60% conditions only',samples=rows,groups=groups,
    maxRelativeIntervalError=max(i['relativeError'] for g in groups for i in g['intervals']),
    maxRelativeCumulativeError=max(r['relativeCumulativeError'] for r in rows),
    maxAbsoluteResidual=max(abs(r['residual']) for r in rows),
    nominalIncrementalFrameMS=1000/65-1000/66,
    fpsMeasurement='P2 66, P3 65; user uncertainty around one FPS; not isolated GPU timing',
    memoryMeasurement='Initial report: 142 then 165 MB before GC. Subsequent minimum/maximum ranges are analyzed separately in memory_followup/checks.json when present.',
    runtimeUnchanged=unchanged)
(OUT/'game_checks.json').write_text(json.dumps(report,indent=2))
memoryPath=OUT/'memory_followup/measurements.json'
if memoryPath.exists():
    memory=json.loads(memoryPath.read_text())
    measurements={r['id']:r for r in memory['measurements']}
    comparisons=[]
    for a,b in [('p2_start','p2_3min'),('p3_start','p3_3min'),
                ('p3_reference','p3_5toggles'),('p3_reference','p3_40toggles'),
                ('p3_5toggles','p3_40toggles')]:
        comparisons.append(dict(start=a,end=b,
            minDeltaMB=round(measurements[b]['minMB']-measurements[a]['minMB'],6),
            maxDeltaMB=round(measurements[b]['maxMB']-measurements[a]['maxMB'],6)))
    memoryReport=dict(measurements=memory,comparisons=comparisons,
        result='No sustained Memory accumulation observed in supplied 3-minute and up-to-40-toggle runs.',
        gate='Observed-range memory accumulation check passed, not a universal leak-free certification.',
        limits=['30 FPS sampling can miss shorter peaks or exact post-GC troughs.',
                'P3 minimum declines after replay start; unmatched elapsed times confound small differences.',
                'Single ranges, no raw timeline/repeats; do not fit a per-toggle leak rate.',
                'App Memory is not an isolated measurement of driver/GPU residency.',
                '10-minute and 100%/4096-active-slot memory/p99 gate remains open.'],
        runtimeUnchanged=unchanged)
    (OUT/'memory_followup/checks.json').write_text(json.dumps(memoryReport,indent=2))
    print('Memory follow-up:',json.dumps(comparisons,indent=2))
print(json.dumps({k:v for k,v in report.items() if k not in ('samples','runtimeUnchanged','groups')},indent=2))
print(json.dumps(groups,indent=2))
if '--media' in __import__('sys').argv:
    frames=OUT/'frames';frames.mkdir(exist_ok=True);metadata=[]
    for idx,path in enumerate(sorted((ROOT/'docs/videos').glob('_P3Test_*.mp4'))):
        m=json.loads(subprocess.check_output([str(BIN/'ffprobe.exe'),'-v','quiet','-print_format','json','-show_format','-show_streams',str(path)]))
        duration=float(m['format']['duration']);stream=next(s for s in m['streams'] if s['codec_type']=='video')
        times=sorted(set([duration*j/9 for j in range(1,9)]+[t for t in (83.8,84,84.2) if t<duration]))
        sheet=Image.new('RGB',(1280,390*math.ceil(len(times)/2)),'#222');draw=ImageDraw.Draw(sheet)
        for j,t in enumerate(times):
            dest=frames/f'video{idx}_{j}.png'
            subprocess.run([str(BIN/'ffmpeg.exe'),'-v','error','-y','-ss',str(t),'-i',str(path),'-frames:v','1',str(dest)],check=True)
            frame=Image.open(dest).convert('RGB');frame.thumbnail((640,360))
            x=j%2*640;y=j//2*390;sheet.paste(frame,(x,y+30));draw.text((x+8,y+8),f'{path.stem} / {t:.3f}s',fill='white')
        sheet.save(frames/f'video{idx}_sheet.jpg',quality=92)
        metadata.append(dict(path=path.relative_to(ROOT).as_posix(),duration=duration,width=stream['width'],height=stream['height'],times=times))
    (OUT/'media.json').write_text(json.dumps(metadata,indent=2))
    print(json.dumps(metadata,indent=2))
