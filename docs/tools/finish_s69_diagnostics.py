from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];p=ROOT/'realvisor.lua';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
def one(a,b):
    global s
    assert s.count(a)==1,(a[:100],s.count(a));s=s.replace(a,b)
one('''                            item=state.cpuSplashItems[index] or {};state.cpuSplashItems[index]=item''','''                            item=state.cpuSplashItems[index]
                            if not item then
                                item={};state.cpuSplashItems[index]=item
                                state.cpuSplashItemCount=(state.cpuSplashItemCount or 0)+1
                            end''')
one('''    local list=state.gpuSplashList or {}
    local drawn=0''','''    local list=state.gpuSplashList or {}
    state.cpuSplashFrameEvents=#list
    local drawn=0''')
one("            ui.textWrapped('Render Stats -> RealVisor/* shows separate CPU/GPU timings. Nested totals overlap; compare leaf passes.')", "            ui.text(string.format('Splash frame %d | retained events %d | retired trail queue %d | slot pool %d | Lua heap %.1f MB',\n                p.cpuSplashFrameEvents or 0,#(p.gpuSplashList or {}),#(p.pendingSplash or {}),\n                p.cpuSplashItemCount or 0,collectgarbage('count')/1024))\n            ui.textWrapped('Render Stats -> RealVisor/* shows separate CPU/GPU timings. Nested totals overlap; compare leaf passes.')")
one("' / updates '..n.updates..' / '..tostring(n.error or vl.status)","' / updates '..n.updates..' / prepared frame '..tostring(st.nativeGlassPreparedFrame)..' / '..tostring(n.error or vl.status)")
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8',newline='\r\n')
print('Added bounded splash/heap and scene-ready mask diagnostics; no forced GC')
