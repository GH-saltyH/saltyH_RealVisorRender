"""Actual Lua pending micro bake, draw-call bounds and obsolete upload gate."""
from pathlib import Path
import runpy
ROOT=Path(__file__).resolve().parents[2]
env=runpy.run_path(str(ROOT/'docs/tools/check_baked_housing.py'));lua=env['lua']
source=(ROOT/'realvisor.lua').read_text(encoding='utf-8')
lua.globals().folder=ROOT.as_posix()
lua.execute('''
    ffi=require('ffi')
    local v={};v.__index=v
    function vec2(x,y) return setmetatable({x=x or 0,y=y or 0},v) end
    function v:set(x,y) self.x=x;self.y=y;return self end
    function rgbm(r,g,b,a) return {r=r,g=g,b=b,a=a} end
    render.AntialiasingMode={None=0};render.TextureFormat={R8G8B8A8={UNorm=1}}
    render.BlendMode={Opaque=0}
    cfg={RUNTIME={RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM=.0029296875,
        RAIN_DYNAMIC_MICRO_PATTERN_DIAMETER_MM=.46,RAIN_DYNAMIC_MICRO_PATTERN_TEXELS_PER_CELL=12,
        RAIN_DYNAMIC_MICRO_PATTERN_STRATA=1,RAIN_DYNAMIC_MICRO_PATTERN_PRESENCE=.77,
        RAIN_DYNAMIC_MICRO_PATTERN_FIRST_PRESENCE=.55,RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MIN=.32,
        RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MAX=.55,RAIN_DYNAMIC_MICRO_PATTERN_RIM_TEXELS=1.43}}
    allocations=0;updates=0;ui={}
    function canvas()
        local c={}
        function c:setName() return self end
        function c:dispose() self.disposed=true end
        function c:clear() self.cleared=true end
        function c:update(fn) fn() end
        function c:updateWithShader(p)
            updates=updates+1;params=p;assert(p.async==true)
            return not pending
        end
        return c
    end
    function ui.ExtraCanvas() allocations=allocations+1;return canvas() end
    function ui.pushClipRect() end;function ui.popClipRect() end
    function ui.beginScale() end;function ui.endPivotScale() end
    calls=0
    function ui.drawCircleFilled() end
    function ui.drawQuadFilled() calls=calls+1 end
    function ui.drawImageQuad(image) assert(image);calls=calls+1 end
    function ui.drawTriangleFilled() error('Individual CPU cap triangles are forbidden') end
''')
factory=lua.execute((ROOT/'rain_surface.lua').read_text(encoding='utf-8'))
lua.globals().surface=factory(ROOT.as_posix(),lua.globals().cfg['RUNTIME'])
lua.execute('''
    rainDynamicSceneCopyState={surface=surface,microBakeKeyNow=function() return 'test' end}
    textureRainBoundaryMask=folder..'/texture/RAINFX_ObjNormal_BoundaryMask.dds'
''')
a=source.index('rainDynamicSceneCopyState.bakeMicroPattern = function()')
b=source.index('\n        local patternSize, patternGrid =',a)
lua.execute(source[a:b])
lua.execute('''
    local s=rainDynamicSceneCopyState
    pending=true;s.bakeMicroPattern()
    assert(not s.microPatternReady and not s.microBakeKey and allocations==1)
    local old=s.microPatternCanvas
    pending=false;s.bakeMicroPattern()
    assert(s.microPatternCanvas==old and allocations==1 and updates==2)
    assert(s.microPatternReady and s.microBakeKey=='test')
    surface:updateAtlas(canvas(),2048,function()
        for i=1,1000 do surface:stroke(900,900,910,912,4,rgbm(1,1,1,1),2048) end
    end)
    assert(calls==3000,'One physical ribbon and two cached image caps per stroke')
''')
a=source.index('local function applyRainDynamicStateToSurfaceMesh()')
b=source.index('\n--------------------------------------------------------\n-- 3.6.0 TESTING:',a)
lua.execute(source[a:b].replace('local function applyRainDynamicStateToSurfaceMesh()','function obsoleteUpload()'))
lua.execute('cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_STATE_ENABLED=true;obsoleteUpload()')
lua.execute('''
    count=4;width=4;i=0;dst=1;velocityRange=.125
    rainDynamicStateVelocityU={};rainDynamicStateVelocityV={}
    data={floatValue=function(_,x,y)
        local v=y==2 and -.4 or 1.7
        return .5+.5*v/(math.abs(v)+velocityRange)
    end}
''')
a=source.index('            local encodedU=data:floatValue(')
b=source.index('            rainDynamicStateRadius[dst]',a)
lua.execute(source[a:b])
lua.execute('assert(math.abs(rainDynamicStateVelocityU[1]+.4)<1e-9 and math.abs(rainDynamicStateVelocityV[1]-1.7)<1e-9)')
print('PASS: pending micro retries retain allocation, success gates readiness; 3000 calls for 1000 strokes; production skips obsolete per-drop mesh upload')
print('PASS: actual Lua signed velocity decoder matches bounded GPU encoding without clipping')
