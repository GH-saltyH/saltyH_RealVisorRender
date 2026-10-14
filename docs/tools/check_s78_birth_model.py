"""P2 diagnostic model: actual LuaJIT probability, flux and impact invariants."""
from pathlib import Path
import difflib,hashlib,json,math,tempfile,sys
sys.dont_write_bytecode=True
from check_s75_inputs import load_lua
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-14/s78'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
with tempfile.TemporaryDirectory(prefix='lua_',dir=OUT,ignore_cleanup_errors=True) as folder:
    lua=load_lua(folder)
    for name in ('realvisor.lua','rain_birth_model.lua'):
        lua.execute('assert(loadstring(...))',(ROOT/name).read_text(encoding='utf-8-sig'))
    factory=lua.execute((ROOT/'rain_birth_model.lua').read_text());model=factory()
    env=lua.table_from(dict(frame=1,liquidIntensity=.6,windX=0,windY=0,windZ=14.8/3.6,
        airX=0,airY=0,airZ=14.8/3.6,temperatureC=22,trackWetness=.6,trackWater=1,humidity=.8))
    model.update(model,env,20,1,0)
    reports=[]
    # Baseline P1 response time from independent kg/(kg/s) dimensions.
    taus={str(d):math.pi*d**3/6*1e-9*998.2/(80*.001002*d*2**(1/3)*.001)*1000
          for d in (.57,.65,.76,1.15,2.25)}
    reports.append(dict(case='P1 viscous relaxation milliseconds, 20 C theta90 shape80',values=taus))
    seeds=[]
    for seed in range(1,5):
        model.update(model,env,20,1,seed)
        ps=[model.probability(model,i) for i in range(1,129)]
        assert min(ps)>=-1e-12 and math.isclose(sum(ps),1,abs_tol=1e-12)
        ds=[model.sample(model,u) for u in (0,.1,.5,.9,.99,1)]
        diameters=[v[0] for v in ds]
        assert diameters==sorted(diameters)
        bounds=[(.1,.5),(.5,4.5),(.5,6.3),(.3,4)][seed-1]
        assert all(bounds[0]<=v<=bounds[1] for v in diameters)
        up=model.encounter(model,0,1,0,1)
        expected=model.rateMMH*1e9/3600000
        assert math.isclose(up.volumeMM3M2S,expected,rel_tol=1e-12),(up.volumeMM3M2S,expected)
        # Correct distinction between airborne and arrival-weighted number mean.
        assert up.meanDiameterMM>=model.meanDiameterMM
        down=model.encounter(model,0,-1,0,1)
        assert down.numberM2S==0 and down.volumeMM3M2S==0
        assert model.sample(model,.5,0,-1,0) is None
        shield=model.encounter(model,0,2,0,.25)
        assert math.isclose(shield.volumeMM3M2S,expected*.25,rel_tol=1e-12)
        # Volume distribution as well as count distribution, including tail dominance.
        volume=[ps[i-1]*model.bins[i].volume for i in range(1,129)]
        tail=sum(volume[i-1] for i in range(1,129) if model.bins[i].diameter>2)/sum(volume)
        seeds.append(dict(seed=seed,numberMeanMM=model.meanDiameterMM,volumeMeanMM3=model.meanVolumeMM3,
                          incidentUpMeanMM=up.meanDiameterMM,volumeShareAbove2MM=tail,quantileMM=diameters))
    reports.append(dict(case='four normalized 128-bin seeds and exactly normalized vertical flux',seeds=seeds))
    # Continuous mixtures; force/display/RH/track-state cannot feed the DSD/flux.
    maximum_step=0;previous=None
    for i in range(1001):
        env.frame=i+10;env.liquidIntensity=i/1000
        model.update(model,env,20,1,0)
        w=[model.weights[j] for j in range(1,5)]
        assert min(w)>=0 and math.isclose(sum(w),1,abs_tol=1e-12)
        assert math.isclose(model.rateMMH,20*i/1000,abs_tol=1e-10)
        if previous is not None:maximum_step=max(maximum_step,abs(model.meanDiameterMM-previous))
        previous=model.meanDiameterMM
    assert maximum_step<.03
    env.liquidIntensity=.6;env.frame=2000;model.update(model,env,20,1,0)
    fields=(model.meanDiameterMM,model.meanVolumeMM3,model.numberDensityM3)
    env.frame=2001;env.trackWetness=0;env.trackWater=0;env.humidity=0;env.carSpeedMS=80
    env.displayGain=.1;env.airZ=-80;model.update(model,env,20,1,0)
    assert fields==(model.meanDiameterMM,model.meanVolumeMM3,model.numberDensityM3)
    front=model.encounter(model,0,0,1,1);assert front.numberM2S>0
    expected=model.numberDensityM3*model.meanVolumeMM3*80
    assert math.isclose(front.volumeMM3M2S,expected,rel_tol=1e-12)
    env.frame=2002;env.liquidIntensity=0;model.update(model,env,20,1,0)
    assert model.rateMMH==model.numberDensityM3==0
    # Phase exclusion is supplied by P0 liquidIntensity, even with wet ground/RH.
    assert model.encounter(model,0,0,1,1).volumeMM3M2S==0
    env.frame=2003;env.liquidIntensity=.6;env.windZ=120/3.6;model.update(model,env,20,1,0)
    assert model.weights[4]==1 and model.weights[3]==0
    reports.append(dict(case='continuous mixtures, ambient wind vs car encounter, track/RH/display independence and dry phase',
                        maximumMeanStepMM=maximum_step))
    # Fixed fall-speed anchors: published piecewise formula, no negative small-drop Atlas.
    for d,expected in ((.1,.3),(.5,1.99995),(.86,3.49989),(1,9.65-10.3*math.exp(-.6))):
        assert math.isclose(model.terminalMS(d),expected,abs_tol=1e-10)
    assert model.terminalMS(0)==0
    # Impact changes with the actual normal, not vehicle speed as scalar.
    impact=model.impact(1.15,0,0,1,20,0,-10,998.2,.001002,.0728)
    assert impact.valid and impact.incident and impact.normalMS==10
    assert math.isclose(impact.weber,998.2*100*.00115/.0728,rel_tol=1e-12)
    assert math.isclose(impact.reynolds,998.2*10*.00115/.001002,rel_tol=1e-12)
    assert math.isclose(impact.ohnesorge,.001002/math.sqrt(998.2*.0728*.00115),rel_tol=1e-12)
    assert impact.tangentX==20 and impact.tangentZ==0
    ledger=model.partition(impact,.55,.2,.15,.1,.25)
    assert ledger.valid
    assert math.isclose(ledger.attachedMM3+ledger.filmMM3+ledger.microMM3+ledger.outflowMM3,impact.volumeMM3,rel_tol=1e-12)
    v=math.sqrt(ledger.velocityX**2+ledger.velocityY**2+ledger.velocityZ**2)
    vin=math.sqrt(impact.tangentX**2+impact.tangentY**2+impact.tangentZ**2)
    assert v<=vin and math.isclose(v,.25*vin,rel_tol=1e-12)
    assert not model.partition(impact,.55,.2,.15,.5,.25).valid
    assert not model.partition(impact,-.5,.5,.5,.5,.25).valid
    assert not model.partition(impact,.55,.2,.15,.1,1.01).valid
    backside=model.impact(1.15,0,0,-1,20,0,-10,998.2,.001002,.0728)
    assert backside.normalMS==0 and not backside.incident
    assert not model.partition(backside,1,0,0,0,.5).valid
    zero=model.impact(1.15,0,0,0,20,0,-10,998.2,.001002,.0728)
    assert not zero.valid
    invalid=model.impact(1.15,float('nan'),0,1,20,0,-10,998.2,.001002,.0728)
    assert not invalid.valid
    invalid=model.impact(1.15,0,0,1,float('nan'),0,-10,998.2,.001002,.0728)
    assert not invalid.valid
    reports.append(dict(case='normal We/Re/Oh, conservative supplied-fraction partition and impulse bound',
                        weber=impact.weber,reynolds=impact.reynolds,ohnesorge=impact.ohnesorge))
    # Actual hook/UI: diagnostics default off, opt-in lazy one-time load, no P1 bank mutation.
    source=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
    hook=source[source.index('rainDynamicSceneCopyState.physicsInputsUpdate=function()'):source.index('\nrainDynamicSceneCopyState.siShader=')]
    panel=source[source.index("rainDynamicSceneCopyState.rainUIPanels['physics_inputs']=function()"):
                 source.index('\nrainDynamicSceneCopyState.rainUISlider =')]
    lua.globals().birthFactory=factory
    lua.globals().environmentFactory=lua.execute((ROOT/'rain_environment.lua').read_text())
    lua.globals().unitsFactory=lua.execute((ROOT/'rain_physics_units.lua').read_text())
    lua.execute('''
        cfg={RUNTIME={RAIN_GPU_STATE_RAIN_OVERRIDE=-1,RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM=6/4096,
            RAIN_PHYSICS_BIRTH_DIAGNOSTICS=false,RAIN_RATE_AT_INTENSITY_1_MM_H=20,
            RAIN_RATE_INTENSITY_POWER=1,RAIN_PHYSICS_DSD_SEED_OVERRIDE=0}}
        inputFrame=1; birthLoads=0;lines=0;logged=0;click=false
        ac={WeatherType={},getCar=function() return {look={x=0,y=0,z=1}} end,
            getSim=function() return {frame=inputFrame,dt=1/60,rainIntensity=.6} end,
            log=function(s) assert(type(s)=='string');logged=logged+1 end}
        ui={text=function(s) lines=lines+1 end,textWrapped=function(s) lines=lines+1 end,
            checkbox=function() return false end,separator=function() end,sameLine=function() end,
            button=function(s) return click and s=='Log P2 reference-plane encounter' end}
        appNameDebug='[test]'
        rainDynamicSceneCopyState={rainUIPanels={},surface={ready=false},rainUISlider=function() end,
            loadRuntimeModule=function(name)
                if name=='rain_environment.lua' then return environmentFactory end
                if name=='rain_physics_units.lua' then return unitsFactory end
                if name=='rain_birth_model.lua' then birthLoads=birthLoads+1;return birthFactory end
                error(name)
            end}
    ''')
    lua.execute(hook);lua.execute(panel)
    lua.execute('''
        local st=rainDynamicSceneCopyState
        st.physicsInputsUpdate();st.rainUIPanels.physics_inputs();assert(birthLoads==0)
        cfg.RUNTIME.RAIN_PHYSICS_BIRTH_DIAGNOSTICS=true
        st.physicsInputsUpdate();st.rainUIPanels.physics_inputs();assert(birthLoads==1 and logged==0)
        click=true;st.rainUIPanels.physics_inputs();assert(logged==2);click=false
        for i=2,100 do inputFrame=i;st.physicsInputsUpdate() end
        assert(birthLoads==1 and st.physicsBirth.updates==100)
        cfg.RUNTIME.RAIN_PHYSICS_BIRTH_DIAGNOSTICS=false
        inputFrame=101;st.physicsInputsUpdate();assert(st.physicsBirth.updates==100)
        cfg.RUNTIME.RAIN_PHYSICS_BIRTH_DIAGNOSTICS=true;st.physicsBirth=nil
        st.loadRuntimeModule=function() return nil,'missing birth diagnostic module' end
        st.rainUIPanels.physics_inputs();assert(st.physicsBirthError and not st.physicsInputsError)
    ''')
    # No transient table construction in O(4) per-frame model update; warm JIT at same callsite.
    result=lua.execute('''
        local model=birthFactory();local e={frame=1,liquidIntensity=.6,windZ=4,airZ=-60}
        local function run(n) for i=1,n do e.frame=e.frame+1;model:update(e,20,1,0) end end
        run(5000);collectgarbage('collect');local before=collectgarbage('count')
        run(40000);collectgarbage('collect');return collectgarbage('count')-before
    ''')
    assert result<16,result
    reports.append(dict(case='actual lazy hook/UI, manual log, missing diagnostic module isolation, bounded frame allocation',
                        retainedLuaGrowthKiB=result))
baseline=json.loads((OUT/'baseline_manifest.json').read_text())
unchanged={name:sha(ROOT/name)==info['sha256'] for name,info in baseline.items()
           if not name.startswith('docs/') and name!='realvisor.lua'}
assert all(unchanged.values()),unchanged
diff=[]
for name in ('realvisor.lua','docs/README.md','docs/RAINFX_ROADMAP.md','docs/RAINFX_S77_SI_MOTION_PREVIEW.md'):
    old=(OUT/'baseline'/name).read_text(encoding='utf-8-sig').splitlines(True)
    new=(ROOT/name).read_text(encoding='utf-8-sig').splitlines(True)
    diff.extend(difflib.unified_diff(old,new,fromfile='s77/'+name,tofile='s78/'+name))
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
(OUT/'checks.json').write_text(json.dumps(dict(scope='P2 diagnostic preparation only; P1 physics/shaders unchanged',
    checks=reports,unchanged=unchanged),indent=2),encoding='utf-8')
print('s78:',len(reports),'checks passed; P1 shader/settings hashes unchanged')
