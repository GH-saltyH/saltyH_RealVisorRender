"""Execute actual Lua on baked data: blank cells, stroke gaps, surface splash, capture lifecycle."""
from pathlib import Path
import runpy,json,re
import numpy as np
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/diagnostics/2026-10-12/s63'
env=runpy.run_path(str(ROOT/'docs/tools/check_s62_runtime.py'));lua=env['lua']
lua.execute('''
    calls=0;q1=vec2();q2=vec2();q3=vec2();q4=vec2()
    assert(not surface:quad(q1,q2,q3,q4,0,0,2,2,1,0,2048))
    assert(not surface:ribbon(q1,q2,q3,q4,0,0,900,900,2,1,0,2048))
    surface:stroke(0,0,0,0,4,rgbm(1,1,1,1),2048);assert(calls==0)
    assert(surface:metric(0,-1)==nil)
    local x,y=surface:offset(0,-1,.1,.1);assert(x==0 and y==0)
    local u,v=surface:preview(.5,-.5,100,-100,.1);assert(u==.5 and v==-.5)
    checked=0;invalid=0;maxExtent=0
    for y=0,511 do for x=0,2047 do
        local u,v=(x+.5)/2048,(y+.5)/512-1
        if not surface:valid(u,v) then
            assert(not surface:quad(q1,q2,q3,q4,u*2048,(v+1)*2048,2,2,1,0,2048))
            invalid=invalid+1
        elseif x%32==0 and y%8==0 then
            assert(surface:quad(q1,q2,q3,q4,u*2048,(v+1)*2048,4,4,1,0,2048))
            maxExtent=math.max(maxExtent,math.abs(q1.x-q3.x),math.abs(q1.y-q3.y));checked=checked+1
        end
    end end
''')
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
a=source.index('rainDynamicSceneCopyState.waterFieldSplashV2 = function(')
b=source.index('\n-- R1.4 only needs',a)
lua.execute('''
    rainDynamicSurfaceFrac=function(x) return x-math.floor(x) end
    cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SPREAD=5
    cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_HOLLOW_AT=.45
    cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_BREAK_AT=.55
    cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SCATTER=2.31
''')
lua.execute(source[a:b])
lua.execute('''
    splashQuads=0
    local function draw(cx,cy,rx,ry,ux,uy)
        if surface:quad(q1,q2,q3,q4,cx,cy,rx*1.45,ry*1.45,ux,uy,2048) then
            splashQuads=splashQuads+1
            assert(math.abs(q1.x-q3.x)<300 and math.abs(q1.y-q3.y)<500)
        end
    end
    for frame=0,60 do
        local origin={x=1024,y=1024,radius=4,seedA=.33,seedB=.72,energy=1}
        rainDynamicSceneCopyState.waterFieldSplashV2(draw,origin,1,frame/60,.5,1,surface,2048)
    end
    local ox,oy=1024,1024
    for i=0,63 do local angle=i/64*math.pi*2
        local x,y=surface:shift(ox,oy,math.cos(angle)*8,math.sin(angle)*8,2048)
        local dx,dy=surface:plane(.5,-.5,(x-ox)/2048,(y-oy)/2048)
        assert(math.abs(math.sqrt(dx*dx+dy*dy)*2048-8)<1e-8)
    end
    assert(splashQuads>500)
''')
defaults={}
for key,value in re.findall(r'\b(RAIN_\w+)\s*=\s*([-+\d.]+|true|false)\s*[,\n]',source):
    if key not in defaults:
        defaults[key]=True if value=='true' else False if value=='false' else float(value)
for key,value in defaults.items():lua.globals().cfg['RUNTIME'][key]=value
lua.execute('ac={getCar=function() return {speedKmh=100} end}')
old=(OUT/'baseline/realvisor.lua').read_text(encoding='utf-8')
a=old.index('rainDynamicSceneCopyState.waterFieldDrawStamps = function(');b=old.index('\n-- Continuous water influx',a)
lua.execute(old[a:b].replace('rainDynamicSceneCopyState.waterFieldDrawStamps =','rainDynamicSceneCopyState.oldDrawStamps =',1))
a=source.index('rainDynamicSceneCopyState.waterFieldCollectGpuSplash = function(');b=source.index('\n-- Draws every head stamp',a)
lua.execute(source[a:b])
a=source.index('rainDynamicSceneCopyState.waterFieldDrawCpuSplash = function(');b=source.index('\nrainDynamicSceneCopyState.waterFieldDrawStamps =',a)
lua.execute(source[a:b])
lua.execute('''
    rainDynamicStateRenderClock=10;rainDynamicStateRadius={};rainDynamicStateVelocityU={};rainDynamicStateVelocityV={}
    local params={surface=surface,gpuHeadsActive=true,birthSeenAt={},generation={},waterKernel=function() return canvas() end}
    stamps={};for i=1,96 do
        rainDynamicStateRadius[i]=4/2048;rainDynamicStateVelocityU[i]=.01;rainDynamicStateVelocityV[i]=-.02
        params.birthSeenAt[i]=0;params.generation[i]=1;stamps[i]={x=1024,y=1024,radius=4,index=i}
    end
    local plane=surface.plane;metricCalls=0
    function surface:plane(...) metricCalls=metricCalls+1;return plane(self,...) end
    cfg.RUNTIME.RAIN_GPU_SPLASH=false
    rainDynamicSceneCopyState.oldDrawStamps(params,stamps,2048,{})
    oldMetricCalls=metricCalls;assert(oldMetricCalls==96)
    metricCalls=0;params.tearOrigin=nil;params.pendingSplash=nil;params.gpuOverrides={}
    rainDynamicSceneCopyState.waterFieldCollectGpuSplash(params,stamps,2048)
    rainDynamicSceneCopyState.waterFieldDrawCpuSplash(params,canvas(),2048)
    assert(metricCalls==0 and params.waterFieldKernels==0 and #(params.gpuSplashList or {})==0)
    surface.plane=plane
''')
native=(ROOT/'native_glass_occlusion.lua').read_text(encoding='utf-8')
lua.execute('''
    function vec3(x,y,z) return {x=x,y=y,z=z} end
    ac={}
    local basis={}
    function basis:inverse() return self end
    function basis:transformPoint(v) return v end
    function basis:transformVector(v) return v end
    nativeOwner={getWorldTransformationRaw=function() return basis end}
    nativeEditors={};local names={'GLASS_EXT_MRR','GLASS_COAT_MRR','GLASS_INT_MRR','GLASS_STICKER_MRR'}
    for _,name in ipairs(names) do
        nativeEditors[name]={visible=true,targetMesh=setmetatable({1},{__index={isVisible=function() return true end}})}
    end
    nativeSim={cameraPosition=vec3(0,0,0),cameraLook=vec3(0,0,1),cameraUp=vec3(0,1,0),cameraFOV=90}
    ac.getSim=function() return nativeSim end
    render.TextureFormat.R32={Float=1};render.CullMode={None=0};render.DepthMode={Normal=0,ReadOnly=1}
    render.BlendMode.BlendPremultiplied=1
    function render.setCullMode() end;function render.setBlendMode() end;function render.setDepthMode() end
    render.getRenderTargetSize=function() return vec2(128,64) end
    function render.mesh(p) nativeDraws=(nativeDraws or 0)+1;return not nativeDrawPending end
    ac.GeometryShot=function(callback)
        local c={}
        for _,name in ipairs({'setName','setSky','setParticles','setClearColor','setClippingPlanes'}) do c[name]=function() end end
        function c:update() callback.opaque();return not capturePending end
        function c:dispose() nativeDisposed=(nativeDisposed or 0)+1 end
        return c
    end
''')
factory=lua.execute(native)
lua.globals().nativeFactory=factory
lua.execute('''
    native=nativeFactory({owner=function() return nativeOwner end,editor=function(n) return nativeEditors[n] end})
    assert(native:update(128,64) and native.updates==1 and nativeDraws==4)
    for i=1,1000 do assert(native:update(128,64)) end
    assert(native.updates==1 and nativeDraws==4,'Stable camera must reuse metric capture')
    nativeEditors.GLASS_EXT_MRR.visible=false
    assert(native:update(128,64) and native.updates==2 and nativeDraws==7)
    local p={textures={},values={}};native:bind(p,'Layer',true)
    assert(p.values.gLayerNativeOn==1 and p.textures.txLayerNativeDepth)
    nativeSim.cameraFOV=91;capturePending=true
    assert(not native:update(128,64) and not native.ready)
    capturePending=false;assert(native:update(128,64) and native.ready)
    nativeSim.cameraFOV=92;nativeDrawPending=true
    assert(not native:update(128,64) and not native.ready)
    nativeDrawPending=false;assert(native:update(128,64))
    for _,e in pairs(nativeEditors) do e.visible=false end
    assert(native:update(128,64) and not native.ready)
    native:bind(p,'Opt',true);assert(p.values.gOptNativeOn==0 and p.textures.txOptNativeDepth==false)
    native:dispose();assert(native.shot==nil)
''')
# Exact current width equation in millimetres (user controls unchanged).
report={'invalid_cells_rejected':int(lua.globals().invalid),'valid_kernel_samples':int(lua.globals().checked),
    'maximum_sampled_4px_quad_extent':float(lua.globals().maxExtent),'splash_kernels':int(lua.globals().splashQuads),
    'native_stable_frames':1000,'native_stable_capture_updates':1,
    'settled_head_cpu_metric_calls_before':int(lua.globals().oldMetricCalls),
    'settled_head_cpu_metric_calls_after':int(lua.globals().metricCalls),
    'wipe_width_mm':'max(0.25/(2048*0.0029296875), diameter_mm*0.980 + 0.0)',
    'wipe_minimum_width_mm':.25/(2048*.0029296875)}
assert report['invalid_cells_rejected']==535983
(OUT/'runtime_checks.json').write_text(json.dumps(report,indent=2))
print('PASS: every blank metric cell rejected; bounded real-surface splash; physical circular offsets; native cache/visibility/pending/failure/disposal')
print(json.dumps(report,indent=2))
