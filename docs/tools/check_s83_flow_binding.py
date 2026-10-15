"""Actual Lua P4 prepare/reset/publish plus pending and manual callback ownership."""
from pathlib import Path
import sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
text=(ROOT/'docs/tools/check_s81_film_binding.py').read_text()
text=text.replace("OUT=ROOT/'docs/diagnostics/2026-10-15/s81'","OUT=ROOT/'docs/diagnostics/2026-10-15/s83'")
text=text.replace('allocations=0;disposals=0;','liveBanks=0;allocations=0;disposals=0;',1)
text=text.replace('function bank(name)\n','function bank(name)\n            liveBanks=liveBanks+1\n',1)
text=text.replace('s.disposed=true;disposals=disposals+1','s.disposed=true;disposals=disposals+1;liveBanks=liveBanks-1',1)
anchor='report=dict(wholeLuaSyntax=True';assert text.count(anchor)==1
extra='''    lua.execute("""
        assert(liveBanks==0)
        runtime.RAIN_PHYSICS_P4_TRANSPORT_PREVIEW=true;actualReset()
        rainStateA=bank('state A');rainStateB=bank('state B');rainStateMetaA=bank('meta A');rainStateMetaB=bank('meta B')
        runtime.RAIN_PHYSICS_P3_FILM_PREVIEW=true
        rainStateUpdateParams.values.gRainObjectToWorld={}
        rainStateUpdateParams.values.gRainForceMask=5
        rainStateUpdateParams.values.gRainSiInertiaWorld=vec3(10,20,30)
        rainStateUpdateParams.values.gRainSiAirWorld=vec3(2,3,4)
        rainStateUpdateParams.values.gRainSiAirFraction=.25
        rainStateUpdateParams.values.gRainAirflowDownwardMode=1
        rainStateUpdateParams.values.gRainAirflowDownwardGain=1.5
        sim.frame=10;assert(framePublish(sim));assert(liveBanks==17 and f.flux)
        assert(f.flowParams.values.gFilmObjectToWorld==rainStateUpdateParams.values.gRainObjectToWorld)
        assert(f.values.gFilmAccelerationWorld.x==0 and f.values.gFilmAccelerationWorld.y==-9.80665)
        assert(f.values.gFilmAirWorld.x==.5 and f.values.gFilmAirWorld.y==.75 and f.values.gFilmAirWorld.z==1)
        assert(f.values.gFilmAirDownward==1 and f.values.gFilmAirDownwardGain==1.5)
        local oldField=f.read;local oldOptics=f.optics;local oldBudget=b.read;local oldClock=f.publishedSeconds
        sim.frame=11;failPass='P4 face flux'
        assert(not framePublish(sim) and f.read==oldField and f.optics==oldOptics and b.read==oldBudget)
        assert(f.publishedSeconds==oldClock and f.frame==10)
        failPass=nil;assert(framePublish(sim));assert(liveBanks==17)
        for _,name in ipairs({'P4 manual Courant blocks','P4 manual Courant coarse'}) do
            failPass=name;assert(not f:logFlow() and not f.flowLogPending and liveBanks==20)
        end
        failPass=nil;assert(f:logFlow());local cb=pendingCallback
        local v={3.5,4,10,.125,100,1,.6,0,3.5,2,3,80,3.5,.25,500,9.8}
        cb(nil,{floatValue=function(s,i,y) return v[i+1] end,dispose=function() dataDisposed=dataDisposed+1 end})
        assert(not f.flowLogPending and string.find(logMessages[#logMessages],'maxCourant=3.500000',1,true))
        assert(f:logFlow());local stale=pendingCallback
        rainDynamicSceneCopyState.siConfigured=true;rainDynamicSceneCopyState.birthConfigured=true
        rainDynamicSceneCopyState.filmConfigured=true;rainDynamicSceneCopyState.flowConfigured=true
        runtime.RAIN_PHYSICS_P4_TRANSPORT_PREVIEW=false;actualReset();assert(liveBanks==0)
        local n=dataDisposed;stale(nil,{dispose=function() dataDisposed=dataDisposed+1 end})
        assert(dataDisposed==n+1 and not f.flowLogPending)
        for cycle=1,40 do
            runtime.RAIN_PHYSICS_P4_TRANSPORT_PREVIEW=cycle%2==1;actualReset();assert(liveBanks==0)
            rainStateA=bank('state A');rainStateB=bank('state B');rainStateMetaA=bank('meta A');rainStateMetaB=bank('meta B')
            sim.frame=cycle+100;assert(framePublish(sim))
            assert(liveBanks==(runtime.RAIN_PHYSICS_P4_TRANSPORT_PREVIEW and 17 or 16))
        end
        rainStateSingleDropDirty=true;actualReset();assert(liveBanks==0)
    """)
    (OUT/'flow_binding_checks.json').write_text(json.dumps(dict(actualLuaFactoriesAndMainReset=True,
        sharedP1TransformAndForceFlags=True,sharedDownwardAirOverride=True,fluxPendingKeepsAllReadBanks=True,
        manualOnlyCourantReduction=True,staleEpochDisposesData=True,toggleCycles=40,
        liveBanksP3=16,liveBanksP4=17,resetLiveBanks=0),indent=2))
'''
text=text.replace(anchor,extra+anchor)
sys.path.insert(0,str(ROOT/'docs/tools'))
exec(compile(text,str(ROOT/'docs/tools/check_s81_film_binding.py'),'exec'),{'__file__':str(ROOT/'docs/tools/check_s81_film_binding.py')})
print('P4 Lua: force/transform, pending, 40 toggles and stale callbacks passed')
