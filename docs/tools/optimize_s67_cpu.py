from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];p=ROOT/'realvisor.lua';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
def one(a,b):
    global s
    assert s.count(a)==1,(a[:80],s.count(a));s=s.replace(a,b)
a=s.index('    -- Give new births a few growing stamps',s.index('rainDynamicSceneCopyState.updateBirthMask ='))
b=s.index('    if waterField then\n        state.profCpuBuildMs',a)
old=s[a:b]
new='''    local shaped,puddles=0,0
    if state.newTrailActive and state.gpuHeadsActive then
        -- Heads/shapes/paths are GPU-owned. CPU centres are only needed for
        -- active impact splashes, never for every old living drop.
        local r=cfg.RUNTIME
        if r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_V2 then
            local car=ac.getCar(0);local kmh=car and car.speedKmh or 0
            local threshold=math.min(r.RAIN_GPU_SIZE_MIN_HEAVY,r.RAIN_GPU_SIZE_MAX_HEAVY)
                +math.abs(r.RAIN_GPU_SIZE_MAX_HEAVY-r.RAIN_GPU_SIZE_MIN_HEAVY)
                *math.max(0,math.min(r.RAIN_DYNAMIC_WATER_FIELD_TEAR_HEAVY_SIZE_PERCENT,100))*.01
            for index=1,count do
                local age=state.birthSeenAt and state.birthSeenAt[index]
                age=age and rainDynamicStateRenderClock-age
                local gen=state.generation and state.generation[index] or 0
                local origin=state.tearOrigin and state.tearOrigin[index]
                local radius=rainDynamicStateRadius[index] or 0
                local duration=origin and origin.generation==gen and origin.duration
                    or r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SECONDS*1.4
                local selected=origin and origin.generation==gen
                    or radius*2/r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM>=threshold
                    or kmh>r.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KMH
                        and rainDynamicSurfaceFrac(index*.438579+gen*.913247)<r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SPEED_SHARE
                if selected and age and age>=0 and age<duration*3 and (rainDynamicStateAlive[index] or 0)>.5 then
                    local u,v=state.surface:preview(rainDynamicStateU[index] or -1,rainDynamicStateV[index] or -2,
                        rainDynamicStateVelocityU[index] or 0,rainDynamicStateVelocityV[index] or 0,predictedAge,index)
                    if state.surface:valid(u,v) then
                        local growth=age<growTime and (.28+.72*math.min(age/growTime,1)) or 1
                        local R=radius*size*growth
                        if r.RAIN_DYNAMIC_BIRTH_MASK_SHAPE_VARIATION and R>=1.2
                            and rainDynamicSurfaceFrac(index*.7548776662+gen*.5698402911)>.34 then
                            R=R*(1-.1*math.max(0,math.min(r.RAIN_DYNAMIC_BIRTH_MASK_SHAPE_STRENGTH,1.5)))
                        end
                        stamps[#stamps+1]={x=u*size,y=(v+1)*size,radius=R,index=index}
                    end
                end
            end
        end
    else
'''+old.replace('    local shaped = 0','    shaped = 0').replace('    local puddles = 0','    puddles = 0')+'    end\n'
s=s[:a]+new+s[b:]
one('        state.waterKernel(state)\n        if cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_RIBBON then',
    '        if not state.newTrailActive then state.waterKernel(state) end\n        if not state.newTrailActive and cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_RIBBON then')
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8')
print('New Trail removes full CPU head geometry/preview/shape construction; only recent eligible splash centres remain')
