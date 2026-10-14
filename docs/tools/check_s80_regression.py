"""Run s79 numeric/wiring gates without overwriting historical results."""
from pathlib import Path
import sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/diagnostics/2026-10-15/s80'
for kind in ('gpu','binding'):
    path=ROOT/f'docs/tools/check_s79_{"birth_gpu" if kind=="gpu" else "binding"}.py'
    text=path.read_text()
    dest=OUT/f's79_{kind}_regression';dest.mkdir(parents=True,exist_ok=True)
    def change(old,new):
        global text
        assert text.count(old)==1,(kind,old)
        text=text.replace(old,new)
    change("OUT=ROOT/'docs/diagnostics/2026-10-14/s79'",f"OUT=ROOT/'docs/diagnostics/2026-10-15/s80/s79_{kind}_regression'")
    if kind=='gpu':
        change("baseline=OUT/'baseline'","baseline=ROOT/'docs/diagnostics/2026-10-14/s79/baseline'")
    else:
        change("(OUT/'baseline_manifest.json')","(ROOT/'docs/diagnostics/2026-10-14/s79/baseline_manifest.json')")
        change("(OUT/'baseline'/n)","(ROOT/'docs/diagnostics/2026-10-14/s79/baseline'/n)")
        change("ac={log=function() logCalls=logCalls+1 end}","logMessages={};ac={log=function(s) logCalls=logCalls+1;logMessages[logCalls]=s end}")
        change("assert(birth.read==originalRead and allocations==4)",
               "assert(birth.read==originalRead and allocations==4 and birth.publishedSeconds==.01 and birth.publishedSteps==1)")
        change("assert(not birth:publish({frame=4}))",
               "assert(math.abs(birth.publishedSeconds-.03)<1e-12 and birth.publishedSteps==3);assert(not birth:publish({frame=4}))")
        change("birth:dispose();assert(disposals==5 and not birth.ready and birth.tick==0)",
               "birth:dispose();assert(disposals==5 and not birth.ready and birth.tick==0 and birth.publishedSeconds==0 and birth.publishedSteps==0 and not birth.previousLog)")
        change("assert(dataDisposed==2 and birth.logValues[7]==3 and not birth.logPending and logCalls==1)",
               """assert(dataDisposed==2 and birth.logValues[7]==3 and not birth.logPending and logCalls==1)
        assert(string.find(logMessages[1],'publishedSeconds=0.010000 steps=1 intervalSeconds=0.010000',1,true))
        assert(string.find(logMessages[1],'inputRate=1000.000000',1,true))
        assert(birth.previousLog.seconds==.01 and birth.previousLog.input==10)
        -- Capture the second snapshot, then advance CPU publication clock while its callback waits.
        assert(birth:prepare(readState,readMeta,128,{frame=5,dt=.02},transform,rainDynamicSceneCopyState.physicsBirth))
        assert(birth:budget(readMeta,{frame=5}) and birth:publish({frame=5}))
        assert(birth:logBudget());local cb=pendingCallback
        assert(birth:prepare(readState,readMeta,128,{frame=6,dt=.5},transform,rainDynamicSceneCopyState.physicsBirth))
        assert(birth:budget(readMeta,{frame=6}) and birth:publish({frame=6}))
        local second={14,3,2,2,2,1,4,7}
        cb(nil,{floatValue=function(s,i,y) return second[i+1] end,dispose=function() end})
        assert(string.find(logMessages[2],'publishedSeconds=0.030000 steps=2 intervalSeconds=0.020000',1,true))
        assert(string.find(logMessages[2],'inputRate=200.000000',1,true))
        assert(birth.previousLog.seconds==.03 and birth.previousLog.input==14)
        """)
        change("birth.assetError='changed source';sim.frame=5","birth.assetError='changed source';sim.frame=7")
        change("assert(framePublish(sim)==false and birth.tick==1 and rainDynamicSceneCopyState.physicsBirthError=='changed source')",
               "assert(framePublish(sim)==false and birth.tick==3 and rainDynamicSceneCopyState.physicsBirthError=='changed source')")
        change("P2OffSkipsSourceBanks=True)","P2OffSkipsSourceBanks=True,publishedClockFailureAndReset=True,intervalRatesAndAsyncCapture=True)")
    exec(compile(text,str(path),'exec'),{'__file__':str(path)})
