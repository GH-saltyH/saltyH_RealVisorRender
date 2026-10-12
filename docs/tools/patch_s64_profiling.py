from pathlib import Path
p=Path(__file__).resolve().parents[2]/'realvisor.lua';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
def rep(a,b):
    global s
    assert s.count(a)==1,(a[:100],s.count(a));s=s.replace(a,b)
rep('    state.mergeSnapshot = rainDynamicStateSnapshotTime\n','    state.mergeSnapshot = rainDynamicStateSnapshotTime\n    local profileStart=r.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0\n')
rep('    state.mergePairsTotal = (state.mergePairsTotal or 0) + pairCount\n',
    '    state.mergePairsTotal = (state.mergePairsTotal or 0) + pairCount\n    state.profMergeMs=r.RAIN_PERFORMANCE_PROFILING and (os.preciseClock()-profileStart)*1000 or 0\n')
rep('local function updateRainGPUState(sim)', '''-- SDK render.measure records CPU AND GPU in Render Stats; submission clocks
-- alone cannot identify an expensive GPU pass. Diagnostic overhead is opt-in.
rainDynamicSceneCopyState.measure = function(key,fn,...)
    if cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and render.measure then
        local a,b,c
        render.measure('RealVisor/'..key,function(...) a,b,c=fn(...) end,...)
        return a,b,c
    end
    return fn(...)
end
local function updateRainGPUState(sim)''')
rep('        rainDynamicSceneCopyState.updateMergeCommands, count, lifecycleOn)',
    "        rainDynamicSceneCopyState.measure,'Merge CPU',rainDynamicSceneCopyState.updateMergeCommands,count,lifecycleOn)")
for obj,param,key in [('writeState','rainStateUpdateParams','State transport'),('writeMeta','rainStateMetaUpdateParams','State lifecycle')]:
    rep(f'    {obj}:updateWithShader({param})',f"    rainDynamicSceneCopyState.measure('{key}',{obj}.updateWithShader,{obj},{param})")
rep('    updateRainGPUState(sim)',"    rainDynamicSceneCopyState.measure('Physics total',updateRainGPUState,sim)")
rep('            rainDynamicSceneCopyState.updateTrailMaskTimed, sim)',
    "            rainDynamicSceneCopyState.measure,'Wipe mask',rainDynamicSceneCopyState.updateTrailMaskTimed,sim)")
rep('                rainDynamicSceneCopyState.updateBirthMask, sim)',
    "                rainDynamicSceneCopyState.measure,'Water canvases total',rainDynamicSceneCopyState.updateBirthMask,sim)")
rep('        local updated = rainDynamicSceneCopyState.geometryShot:update(',
    "        local updated = rainDynamicSceneCopyState.measure('World refraction capture',\n            rainDynamicSceneCopyState.geometryShot.update,rainDynamicSceneCopyState.geometryShot,")
rep('    rainDynamicSceneCopyState.shotToneUpdate(sim)',
    "    rainDynamicSceneCopyState.measure('Refraction tone + copies',rainDynamicSceneCopyState.shotToneUpdate,sim)")
rep('        dynamicDrawn = render.mesh(dropMeshParams)',"        dynamicDrawn = rainDynamicSceneCopyState.measure('Rain colour',render.mesh,dropMeshParams)")
rep('        render.mesh(dropMeshParams)',"        rainDynamicSceneCopyState.measure('Rain depth',render.mesh,dropMeshParams)")
rep("    local sceneStackOk = pcall(rainDynamicSceneCopyState.visorSceneStack, 'pre')",
    "    local sceneStackOk = pcall(rainDynamicSceneCopyState.measure,'Glass pre',rainDynamicSceneCopyState.visorSceneStack,'pre')")
rep("        local okPost, errPost = pcall(rainDynamicSceneCopyState.visorSceneStack, 'post')",
    "        local okPost, errPost = pcall(rainDynamicSceneCopyState.measure,'Glass post',rainDynamicSceneCopyState.visorSceneStack,'post')")
rep('    p.profOverrideWriteAvg = (p.profOverrideWriteAvg or 0) * 0.95\n        + (p.profOverrideWriteMs or 0) * 0.05',
    '    p.profOverrideWriteAvg = (p.profOverrideWriteAvg or 0) * 0.95\n        + (p.profOverrideWriteMs or 0) * 0.05\n    p.profMergeAvg=(p.profMergeAvg or 0)*.95+(p.profMergeMs or 0)*.05')
rep("            ui.text(string.format('Rain birth + WF CPU (avg): total %.2f ms | wipe mask %.2f ms | slots %d',\n                (p.profBirthAvg or 0.0), (p.profTrailAvg or 0.0), rainDynamicStateReadbackCount or 0))", 
    """            ui.text(string.format('Rain birth + WF CPU (avg): total %.2f ms | wipe mask %.2f ms | slots %d',
                (p.profBirthAvg or 0.0), (p.profTrailAvg or 0.0), rainDynamicStateReadbackCount or 0))
            ui.text(string.format('Merge CPU %.2f ms | candidate checks %d | largest bucket %d',
                p.profMergeAvg or 0,p.mergeCandidateChecks or 0,p.mergeMaximumBucket or 0))
            ui.textWrapped('Render Stats -> RealVisor/* shows separate CPU/GPU timings. Nested totals overlap; compare leaf passes.')""")
assert p.stat().st_mtime_ns==stamp,'Concurrent user edit'
p.write_text(s,encoding='utf-8');print('s64 CPU + GPU measurement hooks applied')
