"""Production Lua factories/main: P4b pending, bank ownership, counters and resets."""
from pathlib import Path
import sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
binding=(ROOT/'docs/tools/check_s83_flow_binding.py').read_text()
scope={'__file__':str(ROOT/'docs/tools/check_s83_flow_binding.py')}
exec(binding.split('exec(compile(text,',1)[0],scope)
text=scope['text'].replace("OUT=ROOT/'docs/diagnostics/2026-10-15/s83'","OUT=ROOT/'docs/diagnostics/2026-10-15/s86'")
anchor='report=dict(wholeLuaSyntax=True';assert text.count(anchor)==1
extra='''    lua.execute("""
        runtime.RAIN_PHYSICS_P4_TRANSPORT_PREVIEW=true
        runtime.RAIN_PHYSICS_P4_POOL_PREVIEW=true;actualReset();assert(liveBanks==0)
        rainStateA=bank('state A');rainStateB=bank('state B');rainStateMetaA=bank('meta A');rainStateMetaB=bank('meta B')
        sim.frame=1000;assert(framePublish(sim));assert(liveBanks==18)
        assert(b.poolMode and f.poolMode and b.events.size.y==5 and b.poolCandidates.size.x==1024)
        assert(b.eventParams.values.gPoolOn==1 and f.values.gPoolOn==1)
        assert(b.eventParams.values.gPoolHasField==0 and b.poolParams.textures.txFilmPrevious==false)
        local firstField=f.read;local allocated=allocations
        sim.frame=1001;assert(framePublish(sim));assert(liveBanks==18 and allocations==allocated)
        assert(b.eventParams.values.gPoolHasField==1 and b.poolParams.textures.txFilmPrevious==firstField)
        assert(f.values.gPoolTick==b.tick-1 and b.eventParams.values.gPoolTick==b.tick-1)
        assert(f.flowParams.textures.txFilmBirthEvent==b.events and f.resolveParams.textures.txFilmBirthEvent==b.events)
        assert(f.opticsParams.textures.txFilmBirthEvent==b.events)
        local field=f.read;local optics=f.optics;local budget=b.read;local tick=b.tick;local clock=f.publishedSeconds
        local metaA=rainStateMetaA;local metaB=rainStateMetaB;local readFlag=rainStateReadIsA
        sim.frame=1002
        for _,name in ipairs({'P4b pool candidates','P2 birth events','State transport','State lifecycle',
            'P3 descriptors','P3 paired meta','P3 sparse tiles','P3 sparse summary','P4 face flux',
            'P3 field deposition','P3 physical height','P2 budget blocks','P2 budget totals'}) do
            failPass=name;assert(not framePublish(sim))
            assert(f.read==field and f.optics==optics and b.read==budget and b.tick==tick)
            assert(f.publishedSeconds==clock and b.publishedSeconds==clock and f.frame==1001)
            assert(rainStateMetaA==metaA and rainStateMetaB==metaB and rainStateReadIsA==readFlag)
            assert(liveBanks==18 and allocations==allocated)
            assert(b.poolParams.textures.txFilmPrevious==field)
        end
        failPass=nil;throwPass='P4b pool candidates';assert(not framePublish(sim))
        assert(rainDynamicSceneCopyState.physicsBirthError and b.tick==tick and f.read==field)
        throwPass=nil
        -- A manual current-field estimate must ignore speculative source events
        -- as well as returns already included in the published field.
        assert(f:logFlow());assert(f.values.gPoolOn==1 and f.flowBlocksParams.values.gPoolOn==0)
        local staleFlow=pendingCallback
        assert(f.flowBlocksParams.textures.txFilmBirthEvent==false)
        assert(framePublish(sim));assert(b.tick==tick+1 and liveBanks==21)
        assert(f:logBudget());local fcb=pendingCallback
        fcb(nil,{floatValue=function(s,i,y)
            local v={2,1,.5,.25,2,0,0,0,10,3,1,2,.25,.7,.8,5};return v[i+1]
        end,dispose=function() dataDisposed=dataDisposed+1 end})
        assert(string.find(logMessages[#logMessages],'transport=P4b poolReturned=2.000000',1,true))
        assert(string.find(logMessages[#logMessages],'residual=0.000000',1,true))
        assert(b:logBudget());local bcb=pendingCallback
        local messageStart=#logMessages
        bcb(nil,{floatValue=function(s,i,y)
            local v={10,4,1,1,1,1,3,5,1,.7,0,2};return v[i+1]
        end,dispose=function() dataDisposed=dataDisposed+1 end})
        assert(string.find(logMessages[messageStart+1],'residual=0.000000',1,true))
        assert(string.find(logMessages[messageStart+2],'poolReturned=2.000000',1,true))
        -- Resizing cannot consume the old field in a newly reset source epoch.
        count=256;sim.frame=1003;assert(framePublish(sim))
        assert(b.eventParams.values.gPoolHasField==0 and b.poolParams.textures.txFilmPrevious==false)
        assert(b.events.size.x==256 and b.events.size.y==5 and f.count==256)
        rainStateSingleDropDirty=true;actualReset();assert(liveBanks==0)
        local n=dataDisposed;staleFlow(nil,{dispose=function() dataDisposed=dataDisposed+1 end})
        assert(dataDisposed==n+1)
        assert(b.poolParams.textures.txFilmPrevious==false and b.eventParams.textures.txPoolCandidates==false)
        assert(f.resolveParams.textures.txFilmBirthEvent==false and f.flowParams.textures.txFilmBirthEvent==false)
        count=128
        for cycle=1,40 do
            runtime.RAIN_PHYSICS_P4_POOL_PREVIEW=cycle%2==1;actualReset();assert(liveBanks==0)
            rainStateA=bank('state A');rainStateB=bank('state B');rainStateMetaA=bank('meta A');rainStateMetaB=bank('meta B')
            sim.frame=1100+cycle;assert(framePublish(sim))
            assert(liveBanks==(runtime.RAIN_PHYSICS_P4_POOL_PREVIEW and 18 or 17))
            assert(b.events.size.y==(runtime.RAIN_PHYSICS_P4_POOL_PREVIEW and 5 or 4))
            assert(not runtime.RAIN_PHYSICS_P4_POOL_PREVIEW or b.eventParams.values.gPoolHasField==0)
        end
        rainStateSingleDropDirty=true;actualReset();assert(liveBanks==0)
    """)
    (OUT/'pool_binding_checks.json').write_text(json.dumps(dict(actualProductionFactoriesAndMain=True,
        pendingAndExceptionAtomicPublication=True,pendingPasses=13,previousFieldOnly=True,
        poolEventBankTickMatchesField=True,diagnosticNeverDebitsSpeculativeOrPublishedEvent=True,
        sourceAndFieldLogsInternalReturn=True,countChangeStartsWithoutOldField=True,
        staleCallbackRetirement=True,clearsAllPoolTextureReferences=True,toggleCycles=40,
        liveBanksP4=17,liveBanksP4b=18,resetLiveBanks=0),indent=2))
'''
text=text.replace(anchor,extra+anchor)
sys.path.insert(0,str(ROOT/'docs/tools'))
exec(compile(text,str(ROOT/'docs/tools/check_s81_film_binding.py'),'exec'),{'__file__':str(ROOT/'docs/tools/check_s81_film_binding.py')})
print('s86 Lua: P4b 13 pending points, atomic banks, return logs, resize, stale callbacks and 40 toggles passed')
