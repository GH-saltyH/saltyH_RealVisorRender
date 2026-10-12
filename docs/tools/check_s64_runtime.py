"""Real stack hook, native shadow policy, measurements and merge cache semantics."""
from pathlib import Path
import runpy,json
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s64'
env=runpy.run_path(str(ROOT/'docs/tools/check_visor_optics.py'));lua=env['lua']
lua.execute('''
    local s=rainDynamicSceneCopyState
    -- Exercise the real scene stack with a native mask which MUST be queried.
    local native=s.nativeGlass;local layer=s.visorLayer;local draws=s.cachedOptics.draws
    local ready=false;local calls=0
    s.nativeGlass={update=function(_,w,h) assert(w==1280 and h==720);calls=calls+1;return ready end,
        bind=function(_,p,prefix)
            p.textures['tx'..prefix..'NativeDepth']=false;p.values['g'..prefix..'NativeOn']=0
            p.values['g'..prefix..'NativePixelScale']=vec2(1,1)
        end,error='pending test'}
    local oldSource=layer.opticsSource
    s.visorSceneStack('post');assert(calls==1 and layer.err=='pending test')
    assert(layer.opticsSource==oldSource and s.cachedOptics.draws==draws,'Pending mask must stop post optics')
    ready=true;s.visorSceneStack('post');assert(calls==2)
    s.nativeGlass=native
    -- Profiling must preserve false/multiple returns and propagate errors.
    optRuntime.RAIN_PERFORMANCE_PROFILING=true;local measurements=0
    render.measure=function(key,fn,...) assert(key:find('RealVisor/',1,true)==1);measurements=measurements+1;fn(...) end
    local a,b,c=s.measure('test',function(x) return false,x,7 end,42)
    assert(a==false and b==42 and c==7 and measurements==1)
    assert(not pcall(s.measure,'error',function() error('test failure') end))
    optRuntime.RAIN_PERFORMANCE_PROFILING=false
    s.measure('bypass',function() return true end);assert(measurements==2)
''')
factory=lua.execute((ROOT/'native_glass_state.lua').read_text(encoding='utf-8'))
lua.globals().stateFactory=factory
lua.execute('''
    shadowMeshes={};local function mesh(name,shadow)
        local ref={1,shadow=shadow,name=name}
        function ref:at() return self end
        function ref:isCastingShadows() return self.shadow end
        function ref:setShadows(v) self.shadow=v end
        return ref
    end
    for _,n in ipairs({'GLASS_EXT_MRR','GLASS_COAT_MRR','GLASS_INT_MRR','GLASS_STICKER_MRR'}) do
        shadowMeshes[n]={visible=true,targetMesh=mesh(n,true)}
    end
    shadowMeshes.FRAME_MAIN={visible=true,targetMesh=mesh('FRAME_MAIN',true)}
    shadowRuntime={RAIN_VISOR_LAYER_NATIVE_GLASS_SHADOWS=false}
    policy=stateFactory({editor=function(n) return shadowMeshes[n] end,runtime=shadowRuntime,dirty=function() end})
    policy:update()
    for n,e in pairs(shadowMeshes) do
        assert(e.visible and e.targetMesh.shadow==(n=='FRAME_MAIN'))
    end
    shadowRuntime.RAIN_VISOR_LAYER_NATIVE_GLASS_SHADOWS=true;policy:update()
    for _,e in pairs(shadowMeshes) do assert(e.targetMesh.shadow) end
    shadowRuntime.RAIN_VISOR_LAYER_NATIVE_GLASS_SHADOWS=false;policy:update();policy:restore()
    for _,e in pairs(shadowMeshes) do assert(e.targetMesh.shadow) end
''')
# Current real merge path with no live records must keep the GPU branch off
# across repeated access to the same snapshot, instead of re-enabling it.
bench=runpy.run_path(str(ROOT/'docs/tools/bench_s64_cpu.py'));mergeLua=bench['lua']
mergeLua.execute('''
    for i=1,2000 do rainDynamicStateAlive[i]=0 end
    rainDynamicStateSnapshotTime=99;rainDynamicStateRenderClock=99.01
    assert(not rainDynamicSceneCopyState.updateMergeCommands(2000,true))
    assert(not rainDynamicSceneCopyState.updateMergeCommands(2000,true))
    assert(not rainDynamicSceneCopyState.mergeActive and rainDynamicSceneCopyState.mergePairs==0)
''')
# Ensure all readback exits release their owned CPU copy, and legacy inactive
# HUD code no longer contains phase-dependent native scene hooks.
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
a=source.index('    slot.canvas:accessData(function(err, data)');b=source.index('\nend\n',a)
assert source[a:b].count('data:dispose()')==3
a=source.index('rainDynamicSceneCopyState.rainOverlayHud = function(');b=source.index('\nrender.on(',a)
assert 'nativeGlass:update' not in source[a:b] and "if phase=='pre'" not in source[a:b]
(OUT/'runtime_checks.json').write_text(json.dumps({'live_stack_native_hook':True,'pending_mask_blocks_optics':True,
    'measurement_preserves_false_returns_and_errors':True,'native_glass_sun_shadows_disabled_restorable':True,
    'frame_visibility_and_shadows_retained':True,'empty_merge_snapshot_remains_disabled':True,
    'readback_error_stale_success_dispose':True},indent=2))
print('PASS: actual scene hook/pending gate, measurement semantics, native shadows/restore, empty merge cache and readback disposal')
