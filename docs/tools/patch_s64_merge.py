"""One-time exact s64 merge hot-path patch, guarded against concurrent writes."""
from pathlib import Path
p=Path(__file__).resolve().parents[2]/'realvisor.lua';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
def rep(a,b):
    global s
    assert s.count(a)==1,(a[:80],s.count(a));s=s.replace(a,b)
a=s.index('    local px, py = state.mergePX or {}, state.mergePY or {}',s.index('rainDynamicSceneCopyState.updateMergeCommands'))
b=s.index('    local generation = state.generation or {}',a)
s=s[:a]+'''    local px, py = state.mergePX or {}, state.mergePY or {}
    state.mergePX, state.mergePY = px, py
    local maxR = 0.0
    for i=1,n do
        px[i]=nil
        if (rainDynamicStateAlive[i] or 0)>.5 then
            local u,v=state.surface:preview(rainDynamicStateU[i] or -1,rainDynamicStateV[i] or -2,
                rainDynamicStateVelocityU[i] or 0,rainDynamicStateVelocityV[i] or 0,age)
            if state.surface:valid(u,v) then
                px[i],py[i]=u,v;maxR=math.max(maxR,rainDynamicStateRadius[i] or 0)
            end
        end
    end
    local mergeReach,attractReach=r.RAIN_GPU_STATE_MERGE_REACH,r.RAIN_GPU_STATE_ATTRACT_REACH
    local cell=math.max(2*maxR*math.max(mergeReach,attractReach),1e-4)
    local X,Y,Z=state.mergeX or {},state.mergeY or {},state.mergeZ or {}
    local CX,CY,CZ=state.mergeCX or {},state.mergeCY or {},state.mergeCZ or {}
    state.mergeX,state.mergeY,state.mergeZ=X,Y,Z
    state.mergeCX,state.mergeCY,state.mergeCZ=CX,CY,CZ
    local minX,minY,minZ,maxX,maxY,maxZ=math.huge,math.huge,math.huge,-math.huge,-math.huge,-math.huge
    for i=1,n do if px[i] then
        X[i],Y[i],Z[i]=state.surface:point(px[i],py[i])
        local x,y,z=math.floor(X[i]/cell),math.floor(Y[i]/cell),math.floor(Z[i]/cell)
        CX[i],CY[i],CZ[i]=x,y,z
        minX,minY,minZ=math.min(minX,x),math.min(minY,y),math.min(minZ,z)
        maxX,maxY,maxZ=math.max(maxX,x),math.max(maxY,y),math.max(maxZ,z)
    end end
    -- Collision-free integer keys, including one neighbouring cell of padding.
    -- Avoid 27 string concatenations per live drop and per-frame point tables.
    local sy,sz=math.max(1,maxY-minY+3),math.max(1,maxZ-minZ+3)
    local sx=math.max(1,maxX-minX+3)
    assert(sx*sy*sz<4503599627370496,'Rain merge grid exceeds exact integer range')
    local function cellKey(x,y,z) return ((x-minX+1)*sy+y-minY+1)*sz+z-minZ+1 end
    local grid={};local maximumBucket=0
    for i=1,n do if px[i] then
        local key=cellKey(CX[i],CY[i],CZ[i]);local bucket=grid[key]
        if not bucket then bucket={};grid[key]=bucket end
        bucket[#bucket+1]=i;maximumBucket=math.max(maximumBucket,#bucket)
    end end
    local partner,kind={},{}
    local pairCount,attracts,checks=0,0,0
    local maxPairs=math.max(0,math.floor(r.RAIN_GPU_STATE_MERGE_MAX_PAIRS))
    local minSpeed,cone=r.RAIN_GPU_STATE_ATTRACT_MIN_SPEED,r.RAIN_GPU_STATE_ATTRACT_CONE
    local unit=state.surface:unit()
    for i=1,n do if px[i] and not partner[i] then
        local ri=rainDynamicStateRadius[i] or 0
        local vx,vy,vz=state.surface:velocity(px[i],py[i],rainDynamicStateVelocityU[i] or 0,rainDynamicStateVelocityV[i] or 0)
        vx,vy,vz=vx/unit,vy/unit,vz/unit
        local speed=math.sqrt(vx*vx+vy*vy+vz*vz)
        local bestJ,bestD,steerJ,steerD=nil,math.huge,nil,math.huge
        local merging=wantMerge and pairCount<maxPairs
        local steering=wantAttract and speed>=minSpeed
        if merging or steering then
            for gx=CX[i]-1,CX[i]+1 do for gy=CY[i]-1,CY[i]+1 do for gz=CZ[i]-1,CZ[i]+1 do
                local bucket=grid[cellKey(gx,gy,gz)]
                if bucket then for _,j in ipairs(bucket) do if j~=i then
                    checks=checks+1
                    local dx,dy,dz=X[j]-X[i],Y[j]-Y[i],Z[j]-Z[i]
                    local d2=dx*dx+dy*dy+dz*dz
                    local rs=ri+(rainDynamicStateRadius[j] or 0)
                    if merging and not partner[j] and d2<(rs*mergeReach)^2 and d2<bestD then
                        bestJ,bestD=j,d2
                    end
                    if steering and d2<(rs*attractReach)^2 and d2<steerD
                        and dx*vx+dy*vy+dz*vz>cone*math.sqrt(d2)*speed then
                        steerJ,steerD=j,d2
                    end
                end end end
            end end end
        end
        if bestJ then
            partner[i],kind[i],partner[bestJ],kind[bestJ]=bestJ,1,i,1;pairCount=pairCount+1
        elseif steerJ then partner[i],kind[i]=steerJ,2;attracts=attracts+1 end
    end end
    state.mergeCandidateChecks,state.mergeMaximumBucket=checks,maximumBucket
''' +s[b:]
# A signed projected airflow must be redirected, not merely supplemented by
# capped gravity: the old extra term could lose to the upward aerodynamic term.
rep('''            // Optional downward airflow is a physical gravity-tangent component.
            // UV V can face any direction; never force a signed V movement.
            if(gRainStateLifecycle>.5 && gRainAirflowDownwardMode>.5) {
                float3 down=float3(0,-1,0);down-=normalWorld*dot(down,normalWorld);
                float l=length(down);
                if(l>1e-6) forceWorld+=down/l*min(length(airWorld)*.30*gRainAirflowDownwardGain,
                    max(gRainStateGravity*gRainPhysicsAccelScale,.1)*(1+min(length(gRainAirVelocityWorld)/20,4)*gRainAirflowDownwardGain));
            }''','''            // Preserve lateral airflow, replace its signed downhill component.
            // Use WORLD gravity projected onto the actual surface; UV V is arbitrary.
            if(gRainStateLifecycle>.5 && gRainAirflowDownwardMode>.5) {
                float3 down=float3(0,-1,0);down-=normalWorld*dot(down,normalWorld);
                float l=length(down);
                if(l>1e-6) {
                    down/=l;
                    float along=dot(airWorld,down);
                    float desired=length(airWorld)*.30*max(gRainAirflowDownwardGain,0);
                    forceWorld+=down*(desired-along);
                }
            }''')
# Remove the mistakenly placed, unreachable overlay hook and insert in the
# exact live scene-stack function, before any optical captures/draws.
hook='''    if phase=='pre' or phase=='post' then
        st.nativeGlass=st.nativeGlass or dofile(appFolder..'/native_glass_occlusion.lua')({
            owner=function() return visor end,
            localFrame=function() return st.nativeGlassLocalFrame() end,
            editor=function(name) return st.visorLayerEditor(name) end})
        if not st.nativeGlass:update(sov.w,sov.h) then
            vl.err=st.nativeGlass.error;return -- no unoccluded fallback over native glass
        end
    end
'''
rep(hook,'')
rep('    sov.h = math.max(1, st.mainTargetHeight or 720)\n    local cachedSource',
    '    sov.h = math.max(1, st.mainTargetHeight or 720)\n'+hook+'    local cachedSource')
assert p.stat().st_mtime_ns==stamp,'Concurrent user edit'
p.write_text(s,encoding='utf-8');print('s64 merge, downward coupling and live native hook applied')
