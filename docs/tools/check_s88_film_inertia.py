"""Offline candidate: finite-inertia film, actual P4 donor/gather, explicit rejection gates.

No runtime files or installed modules are modified. GPU = D3D11 WARP, not game timing.
"""
from pathlib import Path
import json, math, sys
sys.dont_write_bytecode=True
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/diagnostics/2026-10-16/s88'
OUT.mkdir(exist_ok=True,parents=True)
path=ROOT/'docs/tools/check_s83_flow_gpu.py'
prefix=path.read_text().split('\nreports=[]',1)[0]
prefix=prefix.replace("OUT=ROOT/'docs/diagnostics/2026-10-15/s83'", "OUT=ROOT/'docs/diagnostics/2026-10-16/s88'")
e={'__file__':str(path)};exec(prefix,e)
render=e['render'];code=e['code'];P,W,H=e['P'],e['W'],e['H'];size=e['size']
v=e['values'];cells=e['cells'];geo=e['geo'];blank=e['field']
common=e['env']['metric']+e['env']['core']+code('rainFilmPoolAddress')+code('rainFilmPoolAvailable')
prototype=lambda name:(ROOT/f'docs/prototypes/s88/{name}.hlsl').read_text()
predictCode=common+prototype('rainFilmInertia')+prototype('rainFilmInertiaPass')
momentumCode=common+prototype('rainFilmMomentum')
flow=code('rainFilmFlow')
anchor='float2 travel=rainSiProjectUV(uw,vw,velocity)*gFilmGrid*gFilmDt;'
assert flow.count(anchor)==1
# Replace only the constitutive velocity input; quantized debits stay production.
candidateFlow=e['env']['metric']+e['env']['core']+flow.replace(anchor,'float2 travel=txFilmPredicted.Load(int3(inner,0)).ba*gFilmGrid*gFilmDt;')+code('rainFilmFlowPass')
checks=[]
zero=np.zeros((H,W,4),np.float32)
def stock(um):
    a=blank.copy();a[P:P+H,P:P+W,0]=cells[:,:,0]*um*.001
    return a
def predict(label,old,velocity=zero,values=v,geometry=geo):
    return render(label,predictCode,{**geometry,'txFilmPrevious':old,'txFilmCells':cells,'txFilmVelocity':velocity},values,(W,H))
def donor(label,old,pred,values=v):
    return render(label,candidateFlow,{**geo,'txFilmPrevious':old,'txFilmCells':cells,'txFilmPredicted':pred},values,(W,H))
def gather(label,old,q,values=v):
    return e['gather'](label,old,np.pad(q,((P,P),(P,P),(0,0))),values)
def commit(label,old,current,pred,q,values=v,geometry=geo):
    return render(label,momentumCode,{**geometry,'txFilmPrevious':old,'txFilmCurrent':current,
        'txFilmCells':cells,'txFilmFlux':q,'txFilmPredicted':pred},values,(W,H))

# Frozen-height exact solution is a reference for this reduced closure, not CFD.
rho,mu,g=998.2,.001002,9.80665
uniform_program=common+prototype('rainFilmInertia')+'''
float4 main(PS_IN pin) {
    float3 velocity=0,displacement=0;
    int count=(int)gTestSteps;
    [loop]for(int i=0;i<count;++i) {
        float3 next,mean;
        fiRelax(velocity,float3(0,-9.80665,0),gTestH,gTestDt,next,mean);
        velocity=next;displacement+=mean*gTestDt;
    }
    return float4(velocity.xy,displacement.xy);
}
'''
uniform=[]
for h in (1e-6,20e-6,500e-6,1e-3,12e-3):
    tau=rho*h*h/(3*mu);terminal=-g*tau
    expected=np.array([0,terminal*(-math.expm1(-1/tau)),0,
        terminal*(1-tau*(-math.expm1(-1/tau)))])
    rows=[]
    for hz in (30,60,144):
        a=render('exact_uniform',uniform_program,{},dict(gFilmMu=mu,gTestH=h,gTestDt=1/hz,gTestSteps=hz),(1,1))[0,0]
        assert np.allclose(a,expected,rtol=2e-5,atol=1e-10),(h,hz,a,expected)
        rows.append(a.tolist())
    uniform.append(dict(heightUM=h*1e6,relaxationSeconds=tau,endVelocityMS=float(expected[1]),
        displacementM=float(expected[3]),results30_60_144=rows))
checks.append('30/60/144 Hz exact frozen-height velocity and integrated travel across 1..12000 um')

old=stock(500)
p=predict('finite_acceleration_from_rest',old)
physicalMean=p[H//2,W//2,2:]*np.array([.032,.008])
assert 0 < -physicalMean[1] <= g*v['gFilmDt']/2+1e-6
assert np.max(abs(p[:,:,0]))==0 and np.max(p[:,:,1])<0
normal=predict('normal_force_only',old,values={**v,'gFilmAccelerationWorld':(0,0,-g),'gFilmAirWorld':(0,0,50)})
assert np.max(abs(normal))==0
empty=predict('empty_field',blank,velocity=np.ones_like(zero))
assert np.max(abs(empty))==0
stopped=predict('zero_dt',old,velocity=np.ones_like(zero),values={**v,'gFilmDt':0})
assert np.allclose(stopped,1,rtol=1e-6) # Preserve velocity; travel = mean * dt = 0.
checks.append('finite acceleration, tangent projection, no dry velocity and no dt=0 transport')

# Force reversal retains velocity: no instantaneous reversal of a deep column.
moving=zero.copy();moving[:,:,1]=-.4/.008
braking=predict('force_reversal',stock(1000),moving,{**v,'gFilmAccelerationWorld':(0,g,0)})
assert braking[5,20,1]<0 and braking[5,20,1]>moving[5,20,1]
checks.append('deep film decelerates before reversing; finite velocity history')

# Physical result independent of UV scale/skew, physical radius/display settings.
skewU=geo['txRainDu'].copy();skewU[:,:,:3]=(.064,0,0)
skewV=geo['txRainDv'].copy();skewV[:,:,:3]=(.004,.004,0)
skewGeo={**geo,'txRainDu':skewU,'txRainDv':skewV}
skewP=predict('skewed_uv',old,geometry=skewGeo)
actual=skewP[5,20,:2]@np.array([[.064,0,0],[.004,.004,0]])
reference=p[5,20,:2]@np.array([[.032,0,0],[0,.008,0]])
assert np.allclose(actual,reference,rtol=2e-6,atol=1e-8)
rotation=np.array([[0,1,0],[-1,0,0],[0,0,1]],np.float32)
matrix=np.eye(4,dtype=np.float32);matrix[:3,:3]=rotation
rot=predict('rotated_object',old,values={**v,'gFilmObjectToWorld':matrix.T.ravel(),
    'gFilmAccelerationWorld':tuple(np.array([0,-g,0])@rotation)})
assert np.allclose(rot,p,rtol=2e-6,atol=1e-7)
checks.append('skewed/scaled UV basis and object rotation preserve world velocity')

# Actual gather, with the same donor quantization, preserves water at strong CFL.
patch=blank.copy();patch[P+4:P+12,P+20:P+40,0]=.125
patch[P+4:P+12,P+20:P+40,1]=.001
pred=predict('momentum_patch',patch)
q=donor('momentum_patch_flux',patch,pred)
current=gather('momentum_patch',patch,q)
velocity=commit('momentum_patch_commit',patch,current,pred,q)
assert np.min(current)>=0
residual=float(current.sum(dtype=np.float64)-patch.sum(dtype=np.float64))
assert abs(residual)<1e-6
assert np.array_equal(current[:,:,1],patch[:,:,1])
wet=current[P:P+H,P:P+W,0]>0
assert np.allclose(velocity[wet,:2],pred[5,25,:2],rtol=3e-6,atol=2e-6)
assert np.max(abs(velocity[~wet]))==0
checks.append('production donor/gather conserves film and pinned micro; momentum follows water into recipients')

# Discrete linear momentum at zero external force must use donor flux weights,
# including different directions and sign changes, not interpolated velocities.
prng=np.random.default_rng(88)
initial=blank.copy();initial[P+3:P+H-3,P+8:P+W-8,0]=prng.uniform(.0002,.001,(H-6,W-16))
pred=np.zeros_like(zero);pred[3:H-3,8:W-8,:2]=prng.uniform(-.03,.03,(H-6,W-16,2))
pred[:,:,2:]=pred[:,:,:2]
q=donor('opposing_momentum_flux',initial,pred)
result=gather('opposing_momentum',initial,q)
vel=commit('opposing_momentum_commit',initial,result,pred,q)
before=(initial[P:P+H,P:P+W,0,None]*pred[:,:,:2]).sum(axis=(0,1),dtype=np.float64)
after=(result[P:P+H,P:P+W,0,None]*vel[:,:,:2]).sum(axis=(0,1),dtype=np.float64)
assert np.allclose(before,after,rtol=1e-5,atol=1e-9),(before,after)
checks.append('paired opposing-velocity momentum transport conserves discrete linear momentum on flat closed support')

# Newly deposited/condensed water is at rest in this candidate. Adding stock
# therefore dilutes mean velocity; proportional evaporation preserves velocity.
base=stock(500);pred=np.zeros_like(zero);pred[:,:,0]=.1/.032
q=donor('dilution_flux',base,pred)
resolved=gather('dilution_base',base,q)
added=resolved.copy();added[P:P+H,P:P+W,0]*=2
diluted=commit('new_water_dilutes_momentum',base,added,pred,q)
original=commit('undiluted_velocity',base,resolved,pred,q)
assert np.allclose(diluted[:,:,:2],original[:,:,:2]*.5,rtol=2e-6,atol=1e-8)
evaporated=resolved.copy();evaporated[:,:,2]+=(resolved[:,:,0]+resolved[:,:,1])*.25;evaporated[:,:,:2]*=.75
remaining=commit('evaporation_same_velocity',base,evaporated,pred,q)
assert np.allclose(remaining,original,rtol=2e-6,atol=1e-8)
checks.append('zero-momentum new water dilutes mean velocity; proportional evaporation preserves velocity')

# CF does not turn wind-only forcing into gravity, and the user downward
# override retains the same tangent convention as P1/P4 production.
windValues={**v,'gFilmAccelerationWorld':(0,0,0),'gFilmAirWorld':(5,0,0)}
wind=predict('wind_only',old,values=windValues)
assert wind[5,20,0]>0 and wind[5,20,1]==0
down=predict('downward_override',old,values={**windValues,'gFilmAirWorld':(0,5,0),'gFilmAirDownward':1})
assert down[5,20,1]<0
checks.append('wind shear and explicit downward option preserve production direction convention')

# Evaluate user peak heights with their measured normal acceleration and
# minimum stride in a scalar aligned synthetic metric. Not a replay recovery.
observations=[('stationary',455.523193,590.267151,8.911367,.015741),
              ('137kmh',556.913635,207.219452,6.848907,.017169)]
limits=[]
for label,um,strideUM,acc,dt in observations:
    h=um*1e-6;tau=rho*h*h/(3*mu);vEq=acc*tau;stride=strideUM*1e-6
    warm=vEq*dt/stride
    initial=vEq*(1-tau/dt*(-math.expm1(-dt/tau)))*dt/stride
    limits.append(dict(case=label,heightUM=um,strideUM=strideUM,dt=dt,relaxationSeconds=tau,
        terminalVelocityMS=vEq,firstStepCourantFromRest=initial,warmCourant=warm,
        warmVelocityRetained=min(1,.8/warm),nominalStepsAtWarmC=math.ceil(warm/.8)))
    assert warm>.8
checks.append('rejection gate: finite inertia alone leaves warm steady-flow Courant > 0.8 for supplied peak scales')

# Full-width allocation-size compile/run, not a game GPU timestamp.
fullV={**v,'gFilmGrid':(1024,256),'gFilmPaddedSize':(1056,288)}
fullCells=np.tile(np.array([.25,1,0,1],np.float32),(256,1024,1))
fullField=np.zeros((288,1056,4),np.float32)
fullField[16:272,16:1040,0]=.125
full=render('full_grid_predictor',predictCode,{**geo,'txFilmPrevious':fullField,'txFilmCells':fullCells,
    'txFilmVelocity':np.zeros_like(fullCells)},fullV,(1024,256))
assert np.isfinite(full).all() and np.max(abs(full))>0
checks.append('1024x256 predictor executes warning-free at production field dimensions')

report=dict(step='s88',compiler='FXC ps_5_0 /Ges /WX + D3D11 WARP',checks=checks,
    frozenHeightReference=uniform,pairedVolumeResidualMM3=residual,flatMomentumBefore=before.tolist(),
    flatMomentumAfter=after.tolist(),suppliedPeakScaleEstimates=limits,
    addedRawBytesAt1024x256=1024*256*(16+2*8),extraSteadyPasses=2,
    runtimeIntegrated=False,gameTimingMeasured=False,transportTimeGatePassed=False,
    decision='Do not install inertia-only transport as a CFL solution. Evaluate conservative long-travel remap and bounded cost before integration.',
    limits=['No capillary pressure/contact-line solver','Fresh rain/trail and joined micro enter with zero tangent momentum',
            'Curved donor momentum is tangent-projected at recipient; global 3D momentum is not conserved against a curved substrate',
            'Object-rotation fixture checks one transform, not rotating-frame Coriolis/centrifugal dynamics',
            'Uniform exact ODE is not a varying-height PDE convergence certificate'])
(OUT/'inertia_checks.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:report[k] for k in ('checks','suppliedPeakScaleEstimates','addedRawBytesAt1024x256','extraSteadyPasses','decision')},indent=2))
