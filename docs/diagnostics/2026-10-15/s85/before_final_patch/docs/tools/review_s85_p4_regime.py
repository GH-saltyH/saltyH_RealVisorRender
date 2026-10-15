"""Reproducible analysis of supplied SAME-frame s84 P4 snapshots. No game writes."""
from pathlib import Path
import json, math, re
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/diagnostics/2026-10-15/s85'
raw = (OUT / 'p4_paired.log').read_text()
rows = []
cells = np.frombuffer((ROOT / 'texture/RAIN_FILM/cells.dds').read_bytes(), '<f4', offset=148).reshape(256, 1024, 4)
for condition, pair in zip(('stationary', '137 km/h'), zip(raw.splitlines()[::2], raw.splitlines()[1::2])):
    budget, flow = ({k: float(v) for k, v in re.findall(r'(\w+)=([-+0-9.eE]+)', line)} for line in pair)
    assert budget['frame'] == flow['frame'] and budget['film'] == flow['totalFilmMM3']
    x, y = map(int, re.search(r'worstCell=\((\d+),(\d+)\)', pair[1]).groups())
    area, coverage, coating, supported = map(float, cells[y, x])
    # Scaled area is what the runtime reports. Do not assume model scale 1.
    h = flow['worstFilmUM'] * .001  # mm
    volume = h * flow['worstAreaMM2']
    equivalent_d = (6 * volume / math.pi) ** (1 / 3)
    # Current saved physical theta = 90 degrees, not the display gain.
    r90 = (3 * volume / (2 * math.pi)) ** (1 / 3)
    tau = 998.2 * (h * .001) ** 2 / (3 * .001002)
    residual = budget['input'] - sum(budget[k] for k in
        ('film', 'micro', 'drops', 'bounce', 'exit', 'headEvap', 'fieldEvap', 'runoff'))
    assert abs(residual - budget['residual']) < 1e-5
    assert abs(flow['limitedFilmMM3'] / budget['film'] - flow['limitedMassShare']) < 1e-6
    rows.append(dict(condition=condition, frame=int(budget['frame']), budget=budget, flow=flow,
        derived=dict(limitedMassPercent=100 * flow['limitedFilmMM3'] / budget['film'],
            modelVelocitySuppressedPercent=100 * (1 - flow['massWeightedVelocityRetained']),
            filmAbove1mmPercent=100 * flow['above1mmFilmMM3'] / budget['film'],
            limitedWetCellsPercent=100 * flow['limitedCells'] / flow['wetCells'],
            worstHeightOverCellStride=flow['worstFilmUM'] / flow['worstStrideUM'],
            worstCellVolumeMM3=volume, worstEquivalentSphereDMM=equivalent_d,
            theta90IllustrationCapHeightMM=r90, theta90IllustrationFootprintMM2=math.pi * r90 * r90,
            theta90IllustrationFootprintOverCell=math.pi * r90 * r90 / flow['worstAreaMM2'],
            quasiSteadyBodyForceSpeedMS=tau * flow['worstAccelMS2'],
            parabolicProfileRelaxationScaleSeconds=tau, relaxationOverDt=tau / flow['dt'],
            reconstructedBudgetResidualMM3=residual,
            relativeCumulativeBudgetResidual=abs(budget['residual']) / budget['input']),
        staticCell=dict(x=x, y=y, unscaledAreaMM2=area, coverage=coverage, coating=coating,
            supported=bool(supported), inferredScaleSquared=flow['worstAreaMM2'] / area)))

report = dict(step='s85', date='2026-10-15', evidence=rows,
    interpretation={
        'confirmed': 'Normal metrics/forces coexist with millimetre field columns; P4a h^2 quasi-steady mobility reaches outside its useful regime and its CFL limiter slows nearly half the film inventory.',
        'notEstablished': 'The spatial film distribution, local slopes, whether each peak is a drop or connected rivulet, and actual P4b game cost are not provided by these two reductions.',
        'unchanged': 'No diameter, display gain, source budget, water volume or runtime code was modified by this review.',
        'tauDefinition': 'rho*h^2/(3*mu) is the mean-parabolic-profile reduced-model response scale, not an exact Navier-Stokes eigenmode relaxation time.',
        'speedDefinition': 'Body-force-only term of the current code; not a reconstruction of total velocity including air shear/world projection.',
        'interval': 'The interval between snapshots contains the stationary-to-driving transition; do not call it a steady 137 km/h interval.'})
(OUT / 'regime_review.json').write_text(json.dumps(report, indent=2))
for row in rows:
    print(row['condition'], json.dumps(row['derived']))
    print('Static metric:', row['staticCell'])
