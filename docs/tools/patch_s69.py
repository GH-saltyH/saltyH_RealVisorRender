from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];p=ROOT/'realvisor.lua';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
def one(a,b):
    global s
    assert s.count(a)==1,(a[:120],s.count(a));s=s.replace(a,b)
one('    local grid={};local maximumBucket=0\n    for i=1,n do if px[i] then\n        local key=cellKey(CX[i],CY[i],CZ[i]);local bucket=grid[key]\n        if not bucket then bucket={};grid[key]=bucket end\n        bucket[#bucket+1]=i;maximumBucket=math.max(maximumBucket,#bucket)\n    end end\n    local partner,kind={},{}', '''    -- Reuse a sparse linked grid. Ascending insertion preserves the previous
    -- candidate/tie order without allocating one Lua table per occupied cell.
    local scratch=state.mergeScratch
    if not scratch then
        scratch={grid={},tail={},counts={},keys={},next={},partner={},kind={},used=0}
        state.mergeScratch=scratch
    end
    local grid,tail,counts,keys,nextSlot=scratch.grid,scratch.tail,scratch.counts,scratch.keys,scratch.next
    for i=1,scratch.used do
        local key=keys[i];grid[key]=nil;tail[key]=nil;counts[key]=nil;keys[i]=nil
    end
    local used,maximumBucket=0,0
    for i=1,n do if px[i] then
        local key=cellKey(CX[i],CY[i],CZ[i]);local last=tail[key]
        nextSlot[i]=nil
        if not last then
            used=used+1;keys[used]=key;grid[key]=i;counts[key]=1
        else nextSlot[last]=i;counts[key]=counts[key]+1 end
        tail[key]=i;maximumBucket=math.max(maximumBucket,counts[key])
    end end
    scratch.used=used
    local partner,kind=scratch.partner,scratch.kind
    for i=1,n do partner[i]=nil;kind[i]=nil end''')
one('''                local bucket=grid[cellKey(gx,gy,gz)]
                if bucket then for _,j in ipairs(bucket) do if j~=i then''','''                local j=grid[cellKey(gx,gy,gz)]
                while j do if j~=i then''')
one('''                end end end
            end end end
        end
        if bestJ then''','''                end;j=nextSlot[j] end
            end end end
        end
        if bestJ then''')
one('''    state.gpuSplashList = splashes
    local tearing = 0''','''    state.gpuSplashList = splashes
    -- This list is frame-local in BOTH renderers. The CPU path previously
    -- retained every old event and redrew an ever-growing history.
    for i=#splashes,1,-1 do splashes[i]=nil end
    if state.newTrailActive then state.pendingSplash=nil end
    state.cpuSplashItems=state.cpuSplashItems or {}
    local tearing = 0''')
one('''                        splashes[#splashes + 1] = { index, origin.x,
                            origin.y, origin.radius, origin.energy,
                            st, generation }''','''                        local item
                        if not r.RAIN_GPU_SPLASH then
                            item=state.cpuSplashItems[index] or {};state.cpuSplashItems[index]=item
                            item[1],item[2],item[3],item[4]=index,origin.x,origin.y,origin.radius
                            item[5],item[6],item[7]=origin.energy,st,generation
                        else item={index,origin.x,origin.y,origin.radius,origin.energy,st,generation} end
                        splashes[#splashes+1]=item''')
one('''                        if r.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED then
                            state.pendingSplash = state.pendingSplash or {}''','''                        if r.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED and not state.newTrailActive then
                            state.pendingSplash = state.pendingSplash or {}''')
one('''            for _,item in ipairs(list) do
                drawn=drawn+state.waterFieldSplashV2(quad,state.tearOrigin[item[1]],1,item[6],
                    minimum,1,state.surface,size)
            end''','''            for _,item in ipairs(list) do
                local origin=state.tearOrigin and state.tearOrigin[item[1]]
                if origin and origin.generation==item[7] then
                    drawn=drawn+state.waterFieldSplashV2(quad,origin,1,item[6],minimum,1,state.surface,size)
                end
            end''')
one('''    state.waterFieldKernels=drawn
end
rainDynamicSceneCopyState.waterFieldDrawStamps''','''    state.waterFieldKernels=drawn
    for i=#list,1,-1 do list[i]=nil end -- release consumed events even without new births
end
rainDynamicSceneCopyState.waterFieldDrawStamps''')
one('''    if state.newTrailActive then return end
    if not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED then''','''    if state.newTrailActive then state.pendingSplash=nil;return end
    if not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED then''')
one('''    if want then
        local samplesPerMM=''','''    if want then
        st.pendingSplash=nil -- retired CPU trail queue has no consumer in New Trail
        local samplesPerMM=''')
one('''                        stamps[#stamps+1]={x=u*size,y=(v+1)*size,radius=R,index=index}''','''                        state.splashStampPool=state.splashStampPool or {}
                        local stamp=state.splashStampPool[index] or {};state.splashStampPool[index]=stamp
                        stamp.x,stamp.y,stamp.radius,stamp.index=u*size,(v+1)*size,R,index
                        stamps[#stamps+1]=stamp''')
one('''render.onSceneReady(function()
    local optics=rainDynamicSceneCopyState.cachedOptics''','''-- A GeometryShot changes capture camera/viewport state. Refresh the moving
-- native mask before main rendering, never between main glass submissions.
rainDynamicSceneCopyState.nativeGlassPrepare=function()
    local st=rainDynamicSceneCopyState;local r=cfg.RUNTIME;local sim=ac.getSim()
    if (st.offscreenCaptureActive or 0)>0 then return false end
    st.nativeGlassPreparedFrame=nil
    if not initialized or not visor or activeEnableMode~=1 or not sim
        or not r.RAIN_VISOR_LAYER or not r.RAIN_VISOR_SCENE_STACK or r.RAIN_VISOR_OVERLAY then return false end
    if not st.nativeGlass then
        local factory,err=st.loadRuntimeModule('native_glass_occlusion.lua')
        if not factory then st.visorLayer.err=err;return false end
        st.nativeGlass=factory({owner=function() return visor end,
            localFrame=function() return st.nativeGlassLocalFrame() end,
            editor=function(name) return st.visorLayerEditor(name) end,captureUpdate=st.captureUpdate})
    end
    local w=math.max(1,st.mainTargetWidth or sim.windowWidth or 1280)
    local h=math.max(1,st.mainTargetHeight or sim.windowHeight or 720)
    local ok,result=pcall(st.measure,'Native glass mask',st.nativeGlass.update,st.nativeGlass,w,h)
    if not ok or result==false then
        st.visorLayer.err=not ok and tostring(result) or st.nativeGlass.error;return false
    end
    st.nativeGlassPreparedFrame=sim.frame;return true
end
render.onSceneReady(rainDynamicSceneCopyState.nativeGlassPrepare)
render.onSceneReady(function()
    local optics=rainDynamicSceneCopyState.cachedOptics''')
a=s.index("    if phase=='pre' or phase=='post' then",s.index('rainDynamicSceneCopyState.visorSceneStack = function'))
b=s.index('    local cachedSource',a)
one(s[a:b],'''    if (phase=='pre' or phase=='post') and (not st.nativeGlass
        or st.nativeGlassPreparedFrame~=ac.getSim().frame) then
        vl.status='Waiting for scene-ready native mask';return false
    end
''')
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8',newline='\r\n')
print('s69: scene-ready native mask, bounded splash histories and pooled ascending merge grid')
