"""User s79 measurements and explicitly ideal-plane, estimated source comparison."""
from pathlib import Path
import json, sys, tempfile, hashlib
sys.dont_write_bytecode=True
from check_s75_inputs import load_lua
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s80'
samples=[dict(label='stationary',frame=710668,input=4476.677734,film=514.779907,micro=349.602966,
              bounce=1368.951050,capacity=85.293922,exit=1575.328369,drops=587.053528,
              residualReported=-4.332008,arrivals=432,areaM2=.040289),
         dict(label='driving_100_150_kmh',frame=723626,input=13793.625,film=1832.923340,micro=1487.909912,
              bounce=5287.489258,capacity=166.471283,exit=4998.470703,drops=22.264177,
              residualReported=-1.903673,arrivals=1769,areaM2=.040289)]
for sample in samples:
    sample['fractionsPercent']={k:sample[k]/sample['input']*100 for k in ('film','micro','bounce','capacity','exit','drops')}
    sample['residualCalculatedMM3']=sample['input']-sum(sample[k] for k in ('film','micro','bounce','capacity','exit','drops'))
    sample['residualPercent']=sample['residualCalculatedMM3']/sample['input']*100
    sample['elapsedSeconds']=None;sample['fps']=None
source=(ROOT/'rain_birth_model.lua').read_text()
with tempfile.TemporaryDirectory(prefix='lua_',dir=OUT,ignore_cleanup_errors=True) as folder:
    lua=load_lua(folder);model=lua.execute(source)()
    e=lua.table_from(dict(frame=1,liquidIntensity=.608979,windX=-.1266,windY=0,windZ=4.6233,
                         airX=-.1266*.3,airY=0,airZ=4.6233*.3,temperatureC=22))
    model.update(model,e,20,1,0)
    reference=dict(rateMMH=model.rateMMH,weights=[model.weights[i] for i in range(1,5)],
                   numberMeanDiameterMM=model.meanDiameterMM,numberMeanVolumeMM3=model.meanVolumeMM3,
                   volumeWeightedTerminalMS=model.meanVolumeTerminalMM3MS/model.meanVolumeMM3,
                   numberDensityM3=model.numberDensityM3,sourceHash=hashlib.sha256(source.encode()).hexdigest(),planes=[])
    area=.040288600952370551
    for label,n in [('upward',(0,1,0)),('vertical_facing_ambient_wind',(0,0,-1)),('vertical_leeward',(0,0,1))]:
        out=model.encounter(model,*n,1,lua.table())
        reference['planes'].append(dict(label=label,numberPerSecond=out.numberM2S*area,
                                       volumeMM3PerSecond=out.volumeMM3M2S*area,arrivalMeanDiameterMM=out.meanDiameterMM))
report=dict(date='2026-10-15',build='s79',samples=samples,idealPlanes=reference,
            performanceStationary=dict(appOffFPS=[91,94],P1FPS=[72,73],P1P2FPS=[72,73],
                                       wholeAppAddedMS=[1000/73-1000/91,1000/72-1000/94],
                                       P2IncrementMS=None,note='No resolvable P2 FPS difference; no isolated GPU timing.'),
            limits=['Cumulative snapshots have no elapsed-time field; do not derive observed rates.',
                    'P0 snapshots and budget frames differ; not simultaneous.',
                    'Ideal plane area equals full curved-mesh area only for normalization, not measured visor flux.',
                    'Stationary FPS provided in follow-up; driving cost is unmeasured.'])
(OUT/'user_results.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
