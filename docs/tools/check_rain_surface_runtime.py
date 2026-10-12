"""Execute actual Lua surface hash gates, geometry metric and parameter binding."""
from pathlib import Path
import json,runpy
ROOT=Path(__file__).resolve().parents[2]
env=runpy.run_path(str(ROOT/'docs/tools/check_baked_housing.py'));lua=env['lua']
meta=json.loads((ROOT/'texture/RAIN_GEOMETRY/manifest.json').read_text())
lua.globals().surfaceFolder=ROOT.as_posix()
lua.globals().modelHash=meta['sha256'];lua.globals().maskHash=meta['mask_sha256']
lua.execute('''
    ffi=require('ffi')
    function vec2(x,y) return {x=x,y=y} end
    local open=io.open
    function io.open(path,...)
        if missingBake and path:find('spawn_sites.dds',1,true) then return nil end
        return open(path,...)
    end
    function io.checksumSHA256(path,callback)
        checks=(checks or 0)+1
        callback(nil,badHash and 'wrong' or (path:find('.kn5',1,true) and modelHash or maskHash))
    end
    surfaceRuntime={MODEL_PATH='visors/visor_lando_2025Champion_maxquality_diet_face.kn5',
        RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM=.0029296875}
''')
factory=lua.execute((ROOT/'rain_surface.lua').read_text(encoding='utf-8'))
lua.globals().surface=factory(ROOT.as_posix(),lua.globals().surfaceRuntime)
lua.execute('''
    assert(surface:validate() and checks==2,surface.status..' checks='..tostring(checks))
    assert(surface:validate() and checks==2) -- steady state has no file hashing
    local params={textures={},values={}};surface:bind(params)
    assert(params.textures.txRainDu and params.textures.txRainDv and params.textures.txRainBoundaryMask)
    assert(params.values.gRainReferencePerMM==.0029296875)
    local k=surface:unit();surface.scale=2;assert(surface:unit()==k/2)
    surface.scale=1
    local du,dv=surface:offset(.5,-.5,.0029296875,0)
    assert(math.abs(surface:length(.5,-.5,du,dv)-.0029296875)<1e-10)
    local box=surface:microSearch(.55);assert(box.x==2 and box.y==2)
    surface.scale=.75;box=surface:microSearch(.55);assert(box.x>=3 and box.y>=3)
    surface.scale=1
    surface.model=nil;badHash=true;assert(not surface:validate() and not surface.ready)
    assert(surface.status:find('changed'))
    surface.model=nil;badHash=false;missingBake=true
    assert(not surface:validate() and surface.status:find('Missing RainFX bake'))
    surface.model=nil;missingBake=false;assert(surface:validate())
''')
print('PASS: actual surface Lua hash/cache/missing-data gates, UV metric, profile scale, all shader bindings and adaptive micro stencil')
