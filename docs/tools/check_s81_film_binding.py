"""Actual P3 modules + main publication/reset with pending/readback fixtures."""
from pathlib import Path
import sys,json,re,tempfile,hashlib
sys.dont_write_bytecode=True
from check_s75_inputs import load_lua
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-15/s81'
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8-sig')
birth=(ROOT/'rain_birth_gpu.lua').read_text();film=(ROOT/'rain_film.lua').read_text()
runtime={k:(v=='true' if v in ('true','false') else float(v)) for k,v in
    re.findall(r'^\s*(RAIN_\w+)\s*=\s*(true|false|[-+\d.eE]+)\s*,',source,re.M)}
def inline(text,key):
    start=text.index('[[',text.index(key))+2;return text[start:text.index(']]',start)]
with tempfile.TemporaryDirectory(prefix='lua_',dir=OUT,ignore_cleanup_errors=True) as folder:
    lua=load_lua(folder)
    for text in (source,birth,film):lua.execute('assert(loadstring(...))',text)
    lua.globals().birthFactory=lua.execute(birth);lua.globals().filmFactory=lua.execute(film)
    lua.globals().project=ROOT.as_posix();lua.globals().runtime=lua.table_from(runtime)
    lua.globals().traversal=inline(source,'rainDynamicSceneCopyState.gpuHeadsPassB =')
    lua.globals().summary=inline(source,'rainDynamicSceneCopyState.gpuHeadsSummaryPass =')
    lua.execute('''
        allocations=0;disposals=0;hashChecks={};logMessages={};hashCalls=0;passCalls={};dataDisposed=0
        function vec2(x,y) return {x=x,y=y} end
        function vec3(x,y,z) return {x=x or 0,y=y or 0,z=z or 0,set=function(s,a,b,c) s.x=a;s.y=b;s.z=c end} end
        function vec4(x,y,z,w) return {x=x,y=y,z=z,w=w,set=function(s,a,b,c,d) s.x=a;s.y=b;s.z=c;s.w=d end} end
        function rgbm(...) return {...} end
        mat4x4={identity=function() return {} end}
        render={BlendMode={Opaque=1},AntialiasingMode={None=0},TextureFormat={R32G32B32A32={Float=1},R32={Float=2},R16G16B16A16={Float=3}}}
        io.checksumSHA256=function(path,callback) hashChecks[path]=callback;hashCalls=hashCalls+1 end
        function bank(name)
            return {name=name,setName=function(s,n) s.name=n end,clear=function() end,
                dispose=function(s) assert(not s.disposed,'double dispose: '..s.name);s.disposed=true;disposals=disposals+1 end,
                updateWithShader=function(s,p)
                    assert(not s.disposed,'write disposed bank: '..s.name)
                    for key,value in pairs(p.textures or {}) do if type(value)=='table' then
                        assert(not value.disposed,'read disposed texture: '..key)
                        assert(value~=s,'read/write feedback: '..key)
                    end end
                    return true
                end,
                accessData=function(s,cb) pendingCallback=cb end}
        end
        ui={ExtraCanvas=function(size,scale,aa,format)
            allocations=allocations+1;local c=bank('canvas '..allocations);c.size=size;c.format=format;return c
        end}
        surface={shader='',root=project..'/texture/RAIN_GEOMETRY/',scale=1,
            bind=function(s,p) p.textures.txRainDu=s.root..'du.dds';p.textures.txRainDv=s.root..'dv.dds'
                p.textures.txRainBoundaryMask=project..'/texture/RAINFX_ObjNormal_BoundaryMask.dds'
                p.values.gRainMetersPerUnit=.001/(6/4096);p.values.gRainReferencePerMM=6/4096 end}
        function measure(name,fn,...)
            passCalls[name]=(passCalls[name] or 0)+1
            if name==failPass then return false end
            if name==throwPass then error('injected '..name) end
            return fn(...)
        end
        ac={log=function(s) logMessages[#logMessages+1]=s end};appNameDebug='[test]';appFolder=project
        cfg={RUNTIME=runtime};runtime.RAIN_PHYSICS_SI_PREVIEW=true;runtime.RAIN_PHYSICS_P2_BIRTH_PREVIEW=true
        runtime.RAIN_PHYSICS_P3_FILM_PREVIEW=true;runtime.RAIN_GPU_STATE_LIFECYCLE=true;runtime.RAIN_GPU_STATE_MODE=6
        rainDynamicSceneCopyState={surface=surface,siShader='',measure=measure,
            physicsBirth={numberDensityM3=10,weights={0,1,0,0},airX=1,airY=0,airZ=-20},
            physicsInputs={airX=1,airY=0,airZ=-20,humidity=.8,temperatureC=22},
            gpuHeadsPassB=traversal,gpuHeadsSummaryPass=summary,
            loadRuntimeModule=function(name)
                if name=='rain_birth_gpu.lua' then return birthFactory end
                assert(name=='rain_film.lua');return filmFactory
            end}
        rainStateUpdateParams={values={gRainBirthOn=1,gRainStateDeltaTime=.01},textures={}}
        rainStateMetaUpdateParams={values={},textures={}}
        rainStateA=bank('state A');rainStateB=bank('state B');rainStateMetaA=bank('meta A');rainStateMetaB=bank('meta B')
        rainStateReadIsA=true;count=128;transform={}
    ''')
    start=source.index('rainDynamicSceneCopyState.preparePhysicsBirth=function(')
    end=source.index('\nrainDynamicSceneCopyState.stateEntryShader=',start)
    lua.execute(source[start:end])
    start=source.index('    if rainStateUpdateParams.values.gRainBirthOn>.5 then',source.index('local function updateRainGPUState'))
    end=source.index('    rainStateReadIsA = not rainStateReadIsA',start)+len('    rainStateReadIsA = not rainStateReadIsA')
    lua.execute('''function framePublish(sim)
        readState=rainStateReadIsA and rainStateA or rainStateB
        readMeta=rainStateReadIsA and rainStateMetaA or rainStateMetaB
        writeState=rainStateReadIsA and rainStateB or rainStateA
        writeMeta=rainStateReadIsA and rainStateMetaB or rainStateMetaA
        rainStateUpdateParams.textures.txRainState=readState;rainStateUpdateParams.textures.txRainStateMeta=readMeta
        rainStateMetaUpdateParams.textures.txRainState=readState;rainStateMetaUpdateParams.textures.txRainStateMeta=readMeta
    '''+source[start:end]+''' return true end''')
    lua.execute('sim={frame=1,dt=.01};assert(framePublish(sim)==false and allocations==0)')
    manifest=json.loads((ROOT/'texture/RAIN_BIRTH/assets.json').read_text())
    for name,expected in manifest['sha256'].items():
        cb=lua.globals().hashChecks[ROOT.as_posix()+'/'+name]
        if cb:cb(None,expected)
    lua.execute('assert(framePublish(sim)==false and allocations==4 and rainStateReadIsA)')
    fieldAsset=ROOT/'texture/RAIN_FILM/cells.dds'
    lua.globals().hashChecks[fieldAsset.as_posix()](None,hashlib.sha256(fieldAsset.read_bytes()).hexdigest())
    lua.execute('''
        firstPublished=framePublish(sim)
        assert(firstPublished==true and not rainStateReadIsA and allocations==12 and hashCalls==5,
            tostring(firstPublished)..' allocations='..allocations..' hashes='..hashCalls..' error='..tostring(rainDynamicSceneCopyState.physicsFilmError))
        b=rainDynamicSceneCopyState.physicalBirthGPU;f=rainDynamicSceneCopyState.physicalFilmGPU
        assert(f.ready and b.tick==1 and f.frame==1)
        assert(f.publishedSeconds==b.publishedSeconds and f.publishedSteps==b.publishedSteps)
        assert(b.blocks.size.y==3 and b.totalsA.size.y==6)
        assert(b.blockParams.textures.txBirthTransfers==f.descriptors)
        assert(b.blockParams.textures.txRainNewMeta==rainStateMetaB)
        assert(f.metaScratch~=rainStateMetaA and f.metaScratch~=rainStateMetaB)
        initialMetaA=rainStateMetaA;initialMetaB=rainStateMetaB;initialField=f.read;initialOptics=f.optics;initialBTotal=b.read
        sim.frame=2
        for _,name in ipairs({'P2 birth events','State transport','State lifecycle','P3 descriptors','P3 paired meta',
            'P3 sparse tiles','P3 sparse summary','P3 field deposition','P3 physical height',
            'P2 budget blocks','P2 budget totals'}) do
            failPass=name
            assert(framePublish(sim)==false and not rainStateReadIsA and b.tick==1 and b.publishedSeconds==.01)
            assert(rainStateMetaA==initialMetaA and rainStateMetaB==initialMetaB and f.read==initialField)
            assert(f.optics==initialOptics and b.read==initialBTotal)
            assert(f.publishedSeconds==b.publishedSeconds and f.publishedSteps==b.publishedSteps)
            assert(allocations==12 and f.metaScratch~=rainStateMetaA and f.metaScratch~=rainStateMetaB)
        end
        failPass=nil;throwPass='P3 descriptors'
        assert(framePublish(sim)==false and rainDynamicSceneCopyState.physicsFilmError)
        assert(b.tick==1 and b.read==initialBTotal and f.read==initialField)
        throwPass=nil;assert(framePublish(sim)==true and rainStateReadIsA and b.tick==2)
        assert(b.eventParams.values.gBirthWetOn==1 and b.eventParams.textures.txBirthWetHeight==initialOptics)
        sim.frame=3;assert(framePublish(sim)==true and allocations==12 and hashCalls==5)
        assert(f.metaScratch~=rainStateMetaA and f.metaScratch~=rainStateMetaB)
        assert(not f:prepare(readState,readMeta,writeState,writeMeta,b.events,128,sim,rainDynamicSceneCopyState.physicsInputs,.01))
        for _,name in ipairs({'P3 manual field blocks','P3 manual coarse blocks','P3 manual field totals'}) do
            failPass=name;assert(not f:logBudget() and not f.logPending and allocations==16)
            assert(f.frame==3 and b.tick==3 and b.read==f.birthRead)
        end
        failPass=nil;assert(f:logBudget() and allocations==16 and f.logPending)
        local stale=pendingCallback
        f:dispose();assert(not f.ready and not f.count)
        stale(nil,{dispose=function() dataDisposed=dataDisposed+1 end})
        assert(dataDisposed==1 and not f.logValues and #logMessages==0)
        sim.frame=4;assert(framePublish(sim)==true and allocations==24)
        assert(f:logBudget() and allocations==28)
        local v={2,1,.5,.25,0,0,0,0,10,3,1,2,.25,.7,.8,5}
        pendingCallback(nil,{floatValue=function(s,i,y) return v[i+1] end,dispose=function() dataDisposed=dataDisposed+1 end})
        assert(dataDisposed==2 and not f.logPending and #logMessages==1 and string.find(logMessages[1],'residual=0.000000',1,true))
        assert(f.logValues[14]==.7)
        assert(string.find(logMessages[1],'publishedSeconds=0.010000 steps=1',1,true))
        assert(not f:prepare(readState,readMeta,writeState,writeMeta,b.events,128.5,{frame=5,dt=.01},rainDynamicSceneCopyState.physicsInputs,.01))
    ''')
    # Production mode reset owns three DISTINCT metadata canvases. Disposed
    # handles are cleared from both module parameter sets and main bindings.
    start=source.index('    local siChanged=',source.index('local function updateRainGPUState'))
    end=source.index('    if cfg.RUNTIME.RAIN_GPU_STATE_MODE <= 0 then',start)
    lua.execute('''
        rainDynamicSceneCopyState.siConfigured=true;rainDynamicSceneCopyState.birthConfigured=true
        rainDynamicSceneCopyState.filmConfigured=true;rainDynamicSceneCopyState.siEpoch=0
        rainStateSingleDropDirty=false;rainStateConfiguredMode=6;runtime.RAIN_PHYSICS_P3_FILM_PREVIEW=false
        rainDynamicStateReadbackReady=true;rainDynamicStateHasSnapshot=true
        beforeDispose=disposals
    ''')
    lua.execute('function actualReset() '+source[start:end]+' end')
    lua.execute('''
        actualReset();assert(rainStateA==nil and rainStateB==nil and rainStateMetaA==nil and rainStateMetaB==nil)
        assert(not f.ready and not b.ready and not f.count and not b.count)
        assert(rainDynamicSceneCopyState.siEpoch==1 and not rainDynamicStateHasSnapshot)
        assert(disposals-beforeDispose==20) -- 12 P3 (manual stats), 4 P2, 4 main banks
        assert(f.metaParams.textures.txFilmNewMeta==false and b.blockParams.textures.txBirthTransfers==false)
        assert(rainStateUpdateParams.textures.txRainBirthEvent==false)
    ''')
report=dict(wholeLuaSyntax=True,sharedProductionTraversal=True,asyncFiveChecks=True,noFieldAllocationBeforeHashReady=True,
    all11PendingPointsPreserveMainFieldOpticsBudgetsAndClock=True,prepareExceptionKeepsOldBanks=True,
    correctedMetaOwnershipHasNoFeedback=True,previousFieldWetHeightFeedsImpact=True,canvasReuseAndNoPerFrameHashChecks=True,
    budgetReductionsOnlyRunOnManualRequest=True,manual16FloatBudgetAndOldEpochRetirement=True,resetDisposesDistinctOwnersAndClearsPointers=True)
(OUT/'binding_checks.json').write_text(json.dumps(report,indent=2));print('s81 Lua:',len(report),'actual module/publication checks passed')
