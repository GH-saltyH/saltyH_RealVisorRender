"""Actual P2 Lua submission/publication, async hash checks and readback retirement."""
from pathlib import Path
import sys,json,re,tempfile,hashlib,difflib
sys.dont_write_bytecode=True
from check_s75_inputs import load_lua
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-14/s79'
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig');gpu=(ROOT/'rain_birth_gpu.lua').read_text()
runtime={}
for key,value in re.findall(r'^\s*(RAIN_\w+)\s*=\s*(true|false|[-+\d.eE]+)\s*,',source,re.M):
    runtime[key]=value=='true' if value in ('true','false') else float(value)
with tempfile.TemporaryDirectory(prefix='lua_',dir=OUT,ignore_cleanup_errors=True) as folder:
    lua=load_lua(folder)
    for text in (source,gpu):lua.execute('assert(loadstring(...))',text)
    lua.globals().factory=lua.execute(gpu);lua.globals().project=ROOT.as_posix();lua.globals().runtime=lua.table_from(runtime)
    lua.execute('''
        allocations=0;disposals=0;hashChecks={};canvasCalls={};logCalls=0;dataDisposed=0;failPass=nil
        function vec2(x,y) return {x=x,y=y} end
        function vec3(x,y,z) return {x=x or 0,y=y or 0,z=z or 0,set=function(s,a,b,c) s.x=a;s.y=b;s.z=c end} end
        function vec4(x,y,z,w) return {x=x,y=y,z=z,w=w,set=function(s,a,b,c,d) s.x=a;s.y=b;s.z=c;s.w=d end} end
        function rgbm(...) return {...} end
        mat4x4={identity=function() return {} end}
        render={BlendMode={Opaque=1},AntialiasingMode={None=0},TextureFormat={R32G32B32A32={Float=1},R32={Float=2}}}
        io.checksumSHA256=function(path,callback) hashChecks[path]=callback end
        ui={ExtraCanvas=function(size,...)
            allocations=allocations+1
            local c={size=size,setName=function(s,n) s.name=n end,clear=function() end,
                dispose=function(s) disposals=disposals+1;s.disposed=true end,
                updateWithShader=function(s,p) table.insert(canvasCalls,s.name);return s.name~=failCanvas end,
                accessData=function(s,cb) pendingCallback=cb end}
            return c
        end}
        surface={shader='',root=project..'/texture/RAIN_GEOMETRY/',scale=1,
            bind=function(s,p) p.textures.txRainDu=s.root..'du.dds';p.textures.txRainDv=s.root..'dv.dds'
                p.textures.txRainBoundaryMask=project..'/texture/RAINFX_ObjNormal_BoundaryMask.dds'
                p.values.gRainMetersPerUnit=.001/(6/4096);p.values.gRainReferencePerMM=6/4096 end}
        function measure(name,fn,...)
            if name==failPass then return false end
            return fn(...)
        end
        ac={log=function() logCalls=logCalls+1 end};appNameDebug='[test]';appFolder=project
        cfg={RUNTIME=runtime};runtime.RAIN_PHYSICS_SI_PREVIEW=true;runtime.RAIN_PHYSICS_P2_BIRTH_PREVIEW=true
        runtime.RAIN_GPU_STATE_LIFECYCLE=true;runtime.RAIN_GPU_STATE_MODE=6
        rainDynamicSceneCopyState={surface=surface,siShader='',measure=measure,
            physicsBirth={numberDensityM3=10,weights={0,1,0,0},airX=1,airY=0,airZ=-20},
            loadRuntimeModule=function(name) assert(name=='rain_birth_gpu.lua');return factory end}
        rainStateUpdateParams={values={gRainBirthOn=1},textures={}}
        rainStateMetaUpdateParams={values={},textures={}}
        readState={};readMeta={};count=128;transform={};rainStateReadIsA=true
        writeState={updateWithShader=function() return failPass~='State transport' end}
        writeMeta={updateWithShader=function() return failPass~='State lifecycle' end}
    ''')
    start=source.index('rainDynamicSceneCopyState.preparePhysicsBirth=function(')
    end=source.index('\nrainDynamicSceneCopyState.stateEntryShader=',start)
    lua.execute(source[start:end])
    start=source.index('    if rainStateUpdateParams.values.gRainBirthOn>.5 then',source.index('local function updateRainGPUState'))
    end=source.index('    rainStateReadIsA = not rainStateReadIsA',start)+len('    rainStateReadIsA = not rainStateReadIsA')
    lua.execute('function framePublish(sim) '+source[start:end]+' return true end')
    # Real constructor pending checks gate preparation, without any canvas allocation.
    lua.execute('''
        sim={frame=1,dt=.01}
        assert(framePublish(sim)==false and rainStateReadIsA and allocations==0)
        birth=rainDynamicSceneCopyState.physicalBirthGPU
        assert(birth.assetPending==4)
    ''')
    manifest=json.loads((ROOT/'texture/RAIN_BIRTH/assets.json').read_text())
    for name,expected in manifest['sha256'].items():
        path=ROOT.as_posix()+'/'+name
        cb=lua.globals().hashChecks[path]
        if cb:cb(None,expected)
    lua.execute('''
        assert(birth.assetPending==0 and not birth.assetError)
        assert(framePublish(sim)==true and not rainStateReadIsA and birth.tick==1 and allocations==4)
        assert(rainStateUpdateParams.textures.txRainBirthEvent==birth.events)
        assert(rainStateMetaUpdateParams.textures.txRainBirthEvent==birth.events)
        originalRead=birth.read
        sim.frame=2
        for _,name in ipairs({'P2 birth events','State transport','State lifecycle','P2 budget blocks','P2 budget totals'}) do
            failPass=name
            assert(framePublish(sim)==false and not rainStateReadIsA and birth.tick==1)
            assert(birth.read==originalRead and allocations==4)
        end
        failPass=nil
        assert(framePublish(sim)==true and rainStateReadIsA and birth.tick==2 and birth.frame==2)
        sim.frame=3
        assert(framePublish(sim)==true and allocations==4 and birth.tick==3)
        assert(not birth:publish({frame=4}))
        assert(not birth:publish(sim))
        assert(not birth:prepare(readState,readMeta,4097,{frame=4,dt=.01},transform,rainDynamicSceneCopyState.physicsBirth))
        assert(birth.error and allocations==4)
        assert(birth:prepare(readState,readMeta,128,{frame=4,dt=.01},transform,rainDynamicSceneCopyState.physicsBirth))
        assert(birth:logBudget() and birth.logPending and allocations==5)
        assert(not birth:logBudget())
        local firstCallback=pendingCallback
        birth:dispose();assert(disposals==5 and not birth.ready and birth.tick==0)
        firstCallback(nil,{dispose=function() dataDisposed=dataDisposed+1 end})
        assert(dataDisposed==1 and not birth.logValues and logCalls==0)
        sim.frame=4;assert(framePublish(sim)==true and allocations==9 and birth.tick==1)
        assert(birth:logBudget() and allocations==10)
        local fixture={10,2,1,1,2,1,3,5}
        pendingCallback(nil,{floatValue=function(s,i,y) return fixture[i+1] end,
            dispose=function() dataDisposed=dataDisposed+1 end})
        assert(dataDisposed==2 and birth.logValues[7]==3 and not birth.logPending and logCalls==1)
        birth.assetError='changed source';sim.frame=5
        assert(framePublish(sim)==false and birth.tick==1 and rainDynamicSceneCopyState.physicsBirthError=='changed source')
    ''')
    # Actual scalar binding: effective P2 requires SI + lifecycle production mode.
    start=source.index('rainDynamicSceneCopyState.bindSIParams=function(')
    end=source.index('\nrainDynamicSceneCopyState.bindSIParams(rainStateUpdateParams)',start)
    lua.execute(source[start:end]);lua.execute('''
        rainDynamicSceneCopyState.physicsInputs={airDensity=1.2,inertiaVerified=false,
            windX=0,windZ=0,velocityX=0,velocityY=0,velocityZ=0}
        p={values={},textures={}};rainDynamicSceneCopyState.bindSIParams(p);assert(p.values.gRainBirthOn==1)
        runtime.RAIN_GPU_STATE_MODE=4;rainDynamicSceneCopyState.bindSIParams(p);assert(p.values.gRainBirthOn==0)
        runtime.RAIN_GPU_STATE_MODE=6;runtime.RAIN_PHYSICS_SI_PREVIEW=false
        rainDynamicSceneCopyState.bindSIParams(p);assert(p.values.gRainBirthOn==0)
    ''')
    # Default code has no source-bank calls when P2 is off.
    lua.execute('''
        rainStateUpdateParams.values.gRainBirthOn=0
        failPass=nil;sim.frame=6
        local before=birth.tick;assert(framePublish(sim)==true and birth.tick==before)
    ''')
    start=source.index('    local siChanged=',source.index('local function updateRainGPUState'))
    end=source.index('    if cfg.RUNTIME.RAIN_GPU_STATE_MODE <= 0 then',start)
    lua.execute('''
        runtime.RAIN_PHYSICS_SI_PREVIEW=true
        rainDynamicSceneCopyState.siConfigured=true;rainDynamicSceneCopyState.birthConfigured=true
        rainDynamicSceneCopyState.siEpoch=0
        rainStateSingleDropDirty=true;rainStateConfiguredMode=6
        rainDynamicStateReadbackReady=true;rainDynamicStateHasSnapshot=true
        resetDisposed=0
        local function bank() return {dispose=function() resetDisposed=resetDisposed+1 end} end
        rainStateA=bank();rainStateB=bank();rainStateMetaA=bank();rainStateMetaB=bank()
        rainStateUpdateParams.textures.txRainBirthEvent=birth.events
        rainStateMetaUpdateParams.textures.txRainBirthEvent=birth.events
    ''')
    lua.execute('function actualBankReset() '+source[start:end]+' end')
    lua.execute('''
        actualBankReset();assert(resetDisposed==4 and rainDynamicSceneCopyState.siEpoch==1)
        assert(not rainDynamicStateHasSnapshot and not rainDynamicStateReadbackReady)
        assert(rainStateUpdateParams.textures.txRainBirthEvent==false and rainStateMetaUpdateParams.textures.txRainBirthEvent==false)
        assert(birth.count==nil and birth.eventParams.textures.txRainState==false)
    ''')
    tests=dict(wholeLuaSyntax=True,asyncFourSmallAssetChecks=True,effectivePreviewGate=True,
        sameEventForBothBanks=True,allFiveFailurePointsKeepReadBanksAndTick=True,
        publicationAndBudgetAtomic=True,reuseCanvasAfterWarmup=True,
        ordinaryBankResetRetiresEpochAndClearsDisposedTextures=True,
        disposalAndOldEpochReadbackRetirement=True,manualEightFloatStats=True,
        P2OffSkipsSourceBanks=True)
manifest=json.loads((OUT/'baseline_manifest.json').read_text())
allowed={'realvisor.lua','shaders/rainStateEntry.hlsl','shaders/rainMetaEntry.hlsl',
         'docs/README.md','docs/RAINFX_ROADMAP.md','docs/RAINFX_S78_BIRTH_DISTRIBUTION_AND_BUDGET.md',
         'docs/tools/install_s75_inputs.ps1','docs/tools/build_kn5_migration.py'}
same={n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest()==p['sha256'] for n,p in manifest.items() if n not in allowed}
assert all(same.values()),same
diff=[]
for n in sorted(allowed):
    old=(OUT/'baseline'/n).read_text(encoding='utf-8-sig').splitlines(True)
    new=(ROOT/n).read_text(encoding='utf-8-sig').splitlines(True)
    diff.extend(difflib.unified_diff(old,new,fromfile='s78/'+n,tofile='s79/'+n))
(OUT/'source.diff').write_text(''.join(diff),encoding='utf-8')
(OUT/'binding_checks.json').write_text(json.dumps(dict(checks=tests,unchanged=same,
    scope='production Lua wiring with pending/error/readback fixture; actual shader numerics are WARP'),indent=2))
print('s79 Lua:',len(tests),'checks passed; tuning/core/legacy shaders unchanged')
