"""Run production New Trail pending/publication/environment and pending optics."""
from pathlib import Path
import runpy,re,json,hashlib,time,sys
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/(sys.argv[1] if len(sys.argv)>1 else 'docs/diagnostics/2026-10-12/s67')
env=runpy.run_path(str(ROOT/'docs/tools/check_baked_housing.py'));lua=env['lua']
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8');module=(ROOT/'rain_trails.lua').read_text()
lua.execute('assert(loadstring(...))',module);lua.execute('assert(loadstring(...))',(ROOT/'visor_optics.lua').read_text())
runtime={}
for key,v in re.findall(r'\b(RAIN_\w+)\s*=\s*(true|false|-?\d+(?:\.\d+)?)\s*,',source):
    if key not in runtime:runtime[key]= v=='true' if v in ('true','false') else float(v)
lua.globals().runtime=lua.table_from(runtime);lua.globals().folder=ROOT.as_posix()
lua.execute('''
    cfg={RUNTIME=runtime};render.AntialiasingMode={None=0};render.BlendMode={Opaque=0}
    render.TextureFormat={R32G32B32A32={Float=1},R16G16B16A16={Float=2}}
    function vec2(x,y) return {x=x,y=y} end;function rgbm() return {} end
    allocations,updates,disposed=0,0,0;pendingStage=nil;ui={}
    function ui.ExtraCanvas(size)
        allocations=allocations+1
        return {size=size,setName=function(self,n) self.name=n end,clear=function() end,
            dispose=function(self) self.disposed=true;disposed=disposed+1 end,
            updateWithShader=function(self,p)
                assert(p.async==true and p.blendMode==0)
                local n=0;for _ in pairs(p.textures) do n=n+1 end;assert(n<=11)
                self.params=p;updates=updates+1
                return self.name~=pendingStage
            end}
    end
    surface={root=folder..'/texture/RAIN_GEOMETRY/',shader='metric shader'}
    state={smearDensity=.6,smearFacing=1,smearAirKmh=100,smearCarKmh=100}
    sim={frame=1,dt=1/60,rainIntensity=.6,rainWetness=1,rainWater=1}
    input={state={},meta={},previousState={},previousMeta={},metric={},override={},lifecycle=true}
    headValues={gCount=4096,gSize=2048,gRainReferencePerMM=.0029296875,gRainMetersPerUnit=.001/.0029296875}
    function measure(key,fn,...) if key==pendingStage then return false end;return fn(...) end
''')
factory=lua.execute(module)
dependency=lua.table_from({'folder':ROOT.as_posix(),'runtime':lua.globals().runtime,'surface':lua.globals().surface,
    'boundary':'mask','summary':'summary shader','traversal':'void rgWalk() {}\nfloat4 main(PS_IN pin){\n    return acc;\n}',
    'measure':lua.globals().measure})
lua.globals().trail=factory(dependency)
lua.execute('''
    pendingStage='New Trail descriptors'
    assert(trail:prepare(input,headValues,sim,state)==false and allocations==6 and not trail.ready)
    assert(not trail:publish(sim,state) and not state.waterTrailReady)
    local a=trail.a
    for i=1,50 do trail:prepare(input,headValues,sim,state) end
    assert(allocations==6 and trail.a==a)
    pendingStage='New Trail resolve';assert(trail:prepare(input,headValues,sim,state)==false)
    assert(trail.read==a and not trail:publish(sim,state))
    pendingStage=nil;assert(trail:prepare(input,headValues,sim,state))
    assert(not trail.ready and trail.read==a)
    assert(trail:publish(sim,state) and state.waterTrailRead==state.trailMaskRead)
    assert(trail.frame==sim.frame and trail.ready and state.waterTrailReady)
    local phaseRead=trail.descriptorRead
    pendingStage='New Trail resolve'
    assert(not trail:prepare(input,headValues,sim,state) and not trail:publish(sim,state))
    assert(trail.descriptorRead==phaseRead,'Pending retries must not publish the phase bank')
    pendingStage=nil
    assert(trail.read.params.values.gCount==4096 and trail.read.size.x==1024 and trail.read.size.y==256)
    local w=trail.wet;trail:environment(sim,state);assert(trail.wet==w)
    for i=1,180 do sim.frame=sim.frame+1;trail:environment(sim,state) end
    assert(trail.wet>.3 and trail.wet<.6)
    sim.rainIntensity=0;state.smearDensity=0;state.smearAirKmh=0;state.smearFacing=0
    for i=1,3600 do sim.frame=sim.frame+1;trail:environment(sim,state) end
    assert(trail.supply==0 and trail.wet<.04,'Track wetness/puddles must not force a wet visor')
    headValues.gCount=2048;pendingStage='New Trail descriptors'
    assert(trail:prepare(input,headValues,sim,state)==false and a.disposed)
    assert(not state.waterTrailRead and not state.waterTrailReady,'Disposed history cannot feed physics next frame')
    assert(allocations==12 and disposed==6)
''')
report=['Actual 4096-slot pipeline: six bounded allocations including descriptor phase banks, async retry reuse, atomic liquid/wipe publication, same-frame heads/paths, resize cleanup',
    'One wetness update per frame; 3-second rise/20-second dry response; wet tracks alone do not create water']
# Execute the actual narrowed CPU splash-centre branch for 4096 live drops.
a=source.index('    if state.newTrailActive and state.gpuHeadsActive then',source.index('rainDynamicSceneCopyState.updateBirthMask ='))
b=source.index('    else\n    -- Give new births',a)
branch=source[a:b]+'    end'
lua.execute('''
    state={newTrailActive=true,gpuHeadsActive=true,birthSeenAt={},generation={},surface={}}
    count=4096;rainDynamicStateRenderClock=20;predictedAge=0;growTime=.05;size=2048;stamps={};previews=0
    rainDynamicStateRadius={};rainDynamicStateAlive={};rainDynamicStateU={};rainDynamicStateV={}
    rainDynamicStateVelocityU={};rainDynamicStateVelocityV={}
    for i=1,count do state.birthSeenAt[i]=0;rainDynamicStateRadius[i]=.004;rainDynamicStateAlive[i]=1 end
    for i=1,20 do state.birthSeenAt[i]=19.8 end
    state.surface.preview=function() previews=previews+1;return .5,-.5 end
    state.surface.valid=function() return true end
    ac={getCar=function() return {speedKmh=150} end}
    rainDynamicSurfaceFrac=function(x) return x-math.floor(x) end
''')
lua.execute(branch);lua.execute('assert(previews==20 and #stamps==20)')
report.append('4096 old/live CPU drops only preview the 20 eligible active splash centres; no CPU trail stamping')
# Pending state/meta pair must never publish an empty/reordered bank.
a=source.index("    local transportReady=rainDynamicSceneCopyState.measure('State transport'")
b=source.index('\nend',a)
lua.execute('''
    writeState={updateWithShader=function() return transportOK end}
    writeMeta={updateWithShader=function() return lifecycleOK end}
    rainStateUpdateParams={};rainStateMetaUpdateParams={}
    rainDynamicSceneCopyState={measure=measure}
''')
lua.execute('function publishPhysics() '+source[a:b]+' end')
lua.execute('''
    rainStateReadIsA=true;transportOK=false;lifecycleOK=true;publishPhysics();assert(rainStateReadIsA)
    transportOK=true;lifecycleOK=false;publishPhysics();assert(rainStateReadIsA)
    transportOK=true;lifecycleOK=true;publishPhysics();assert(not rainStateReadIsA)
''')
report.append('Async state and lifecycle writes publish as a pair; false results retain the old bank')
# The UI migration must keep physical sizes fixed when the atlas resolution changes.
a=source.index('rainDynamicSceneCopyState.newTrailMode=function(sim)')
b=source.index('-- Splash v2 overrides',a)
lua.execute('''
    rainDynamicSceneCopyState={newTrailActive=true,newTrail={environment=function() end}}
    cfg.RUNTIME.RAIN_NEW_TRAIL_ENABLED=true;cfg.RUNTIME.RAIN_GPU_HEADS=true
''')
lua.execute(source[a:b])
lua.execute('''
    local r=cfg.RUNTIME
    local oldSamples=r.RAIN_DYNAMIC_BIRTH_MASK_SIZE*r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM
    local oldRef,oldMin=r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SIZE_REF,r.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS
    rainDynamicSceneCopyState.newTrailMode(sim)
    assert(math.abs(r.RAIN_NEW_TRAIL_SPLASH_REF_MM*oldSamples*.5-oldRef)<1e-8)
    assert(math.abs(r.RAIN_NEW_TRAIL_SPLASH_MIN_MM*oldSamples*.5-oldMin)<1e-8)
    local refMM,minMM,rim=r.RAIN_NEW_TRAIL_SPLASH_REF_MM,r.RAIN_NEW_TRAIL_SPLASH_MIN_MM,r.RAIN_NEW_TRAIL_MICRO_RIM_D
    r.RAIN_DYNAMIC_BIRTH_MASK_SIZE=r.RAIN_DYNAMIC_BIRTH_MASK_SIZE*2
    rainDynamicSceneCopyState.newTrailMode(sim)
    assert(r.RAIN_NEW_TRAIL_SPLASH_REF_MM==refMM and r.RAIN_NEW_TRAIL_SPLASH_MIN_MM==minMM and r.RAIN_NEW_TRAIL_MICRO_RIM_D==rim)
''')
report.append('One-time splash/mm and micro/D migration preserves current tuning and is stable across resolution changes')
# Owned captures can return true while their render.mesh callback is pending.
a=source.index('    local callsBefore = st.calls',source.index('rainDynamicSceneCopyState.e1SourceUpdate ='))
b=source.index('    st.view =',a)
lua.execute('''
    st={calls=0,ov={}};nativeCapture=false;r=cfg.RUNTIME
    rainDynamicSceneCopyState.captureUpdate=function() st.calls=st.calls+1;st.ov.pending=capturePending;return captureResult end
''')
lua.execute('function checkSourcePending() '+source[a:b]+' return true end')
lua.execute('''
    captureResult=true;capturePending=true;assert(checkSourcePending()==false)
    capturePending=false;captureResult=false;assert(checkSourcePending()==false)
    captureResult=true;assert(checkSourcePending()==true)
''')
a=source.index('    local depthCallsBefore = st.depthCalls or 0',source.index('rainDynamicSceneCopyState.e1SourceUpdate ='))
b=source.index('    if st.shot:mipsUpdate()',a)
lua.execute('''
    rainDynamicSceneCopyState.captureUpdate=function() st.depthCalls=(st.depthCalls or 0)+1;st.depthPending=capturePending;return captureResult end
''')
lua.execute('function checkDepthPending() '+source[a:b]+' return true end')
lua.execute('''
    capturePending=true;assert(checkDepthPending()==false)
    capturePending=false;assert(checkDepthPending()==true)
''')
report.append('True GeometryShot update with pending source/depth callback cannot publish incomplete capture')
a=source.index('    -- No CPU splash writer runs with WF disabled:')
b=source.index('    local values = st.gpuValues',a)
lua.execute('''
    clears=0;st={gpuOverride={clear=function() clears=clears+1 end},gpuOverrides={1},gpuOverrideCount=1}
    rgbm={colors={transparent=0}};r={RAIN_DYNAMIC_WATER_FIELD_ENABLED=false}
''')
lua.execute(source[a:b]);lua.execute('assert(clears==1 and #st.gpuOverrides==0 and st.gpuOverrideCount==0)')
report.append('Wipe-only mode clears stale splash body suppression without CPU splash work')
for name in ('settings.ini','settings_mats.ini','rain_surface.lua','shaders/rainSurfaceMetric.hlsl'):
    assert (ROOT/name).read_bytes()==(OUT/'baseline'/name).read_bytes(),name
assert 'Optics shader/capture pending' not in (ROOT/'visor_optics.lua').read_text()
assert 'error(\'Native glass depth pending\')' not in (ROOT/'native_glass_occlusion.lua').read_text()
report.append('Workspace settings and physical transport retained; normal pending never throws from optics/native capture callbacks')
(OUT/'runtime_checks.json').write_text(json.dumps(report,indent=2))
for row in report:print('PASS:',row)
