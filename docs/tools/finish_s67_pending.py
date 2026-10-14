from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'realvisor.lua';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
def one(a,b):
    global s
    assert s.count(a)==1,(a,s.count(a));s=s.replace(a,b)
one('    local values = st.gpuValues or {}', '''    -- No CPU splash writer runs with WF disabled: discard its previous body
    -- suppression rather than hiding heads/trails indefinitely in wipe-only mode.
    if not r.RAIN_DYNAMIC_WATER_FIELD_ENABLED then
        st.gpuOverride:clear(rgbm.colors.transparent)
        st.gpuOverrides={};st.gpuOverrideCount=0
    end
    local values = st.gpuValues or {}''')
one("    if ov.internalSource and (not ok or err == false) then error(item.mesh .. ': source draw ' .. tostring(err)) end", '''    if ov.internalSource then
        if not ok then error(item.mesh .. ': source draw ' .. tostring(err)) end
        if err==false then ov.pending=true;return false end
    end''')
one('    local callsBefore = st.calls\n    local updated', '    local callsBefore = st.calls\n    st.ov.pending=false\n    local updated')
one("    if updated == false then\n        error('Source shot update pending')\n    end", "    if updated == false or st.ov.pending then\n        st.status='Source capture preparing';return false\n    end")
one("    local depthCallsBefore = st.depthCalls or 0\n    if rainDynamicSceneCopyState.captureUpdate(st.positionShot,origin,look,up,r.RAIN_VISOR_LAYER_E1_SOURCE_FOV)==false then\n        error('Metric depth capture pending')\n    end", "    local depthCallsBefore = st.depthCalls or 0\n    st.depthPending=false\n    local depthUpdated=rainDynamicSceneCopyState.captureUpdate(st.positionShot,origin,look,up,r.RAIN_VISOR_LAYER_E1_SOURCE_FOV)\n    if depthUpdated==false or st.depthPending then\n        st.status='Metric depth capture preparing';return false\n    end")
one('    if capture and (not ok or result==false) then error(st.status) end', '''    if capture then
        if not ok then error(st.status) end
        st.capturePending=result==false
        if st.capturePending then return false end
    end''')
one('    rainDynamicSceneCopyState.e1Primary.resolving=true\n    local ok,res=pcall(function()', '    rainDynamicSceneCopyState.e1Primary.resolving=true\n    rainDynamicSceneCopyState.e1Primary.capturePending=false\n    local ok,res=pcall(function()')
one("    if res==false then error('Primary reflection resolve pending') end", "    if res==false or rainDynamicSceneCopyState.e1Primary.capturePending then return false end")
one("            if not ok or res==false then error('Geometry trace: '..tostring(res)) end", "            if not ok then error('Geometry trace: '..tostring(res)) end\n            st.capturePending=res==false")
one("    local ok,err=pcall(function()\n        st.shot:setClippingPlanes(math.max(sim.cameraClipNear or 0.008,0.001),sim.cameraClipFar or 1000)\n        if rainDynamicSceneCopyState.captureUpdate(st.shot,sim.cameraPosition,sim.cameraLook,sim.cameraUp,sim.cameraFOV)==false then\n            error('Geometry capture pending')\n        end\n    end)\n    st.ready=ok\n    primary.status=ok and 'Geometry capture ready; waiting for INT composite' or ('Geometry capture error: '..tostring(err))", "    st.capturePending=false\n    local ok,result=pcall(function()\n        st.shot:setClippingPlanes(math.max(sim.cameraClipNear or 0.008,0.001),sim.cameraClipFar or 1000)\n        return rainDynamicSceneCopyState.captureUpdate(st.shot,sim.cameraPosition,sim.cameraLook,sim.cameraUp,sim.cameraFOV)\n    end)\n    st.ready=ok and result~=false and not st.capturePending\n    primary.status=st.ready and 'Geometry capture ready; waiting for INT composite'\n        or (ok and 'Geometry capture preparing' or ('Geometry capture error: '..tostring(result)))")
assert p.stat().st_mtime_ns==stamp
p.write_text(s,encoding='utf-8',newline='\r\n')
print('Cleared disabled-WF overrides and propagated pending from remaining owned capture callbacks')
