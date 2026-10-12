from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'realvisor.lua';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
def rep(a,b,n=1):
    global s
    assert s.count(a)==n,(a[:80],s.count(a));s=s.replace(a,b)
rep('        state.surface:updateAtlas(target,size,function()\n            for j = 1, #drawList do',
    '        st.surface:updateAtlas(target,size,function()\n            for j = 1, #drawList do')
# Source RGB might use a different object-axis convention. Recover surface
# normal from the geometric Jacobian, orient towards authored vertex normal.
# This is also independent of UV handedness.
rep('''            float3 n = txRainSurfaceNormal.SampleLevel(
                samLinearRain, float2(p.x,p.y+1.0), 0.0
            ).rgb * 2.0 - 1.0;''','''            float3 n = txRainSurfaceNormal.SampleLevel(
                samLinearRain, float2(p.x,p.y+1.0), 0.0
            ).rgb * 2.0 - 1.0;''')
# Coating controls are explicit settings, preserving all pre-existing values.
rep("        RAIN_DYNAMIC_SMEAR_TEXTURE =",'''        RAIN_SURFACE_COAT_ADHESION = 0.55, -- contact-angle hysteresis approximation
        RAIN_SURFACE_GLASS_EXTRA_DRAG = 1.5,
        RAIN_SURFACE_COAT_RETENTION = 0.65,
        RAIN_DYNAMIC_SMEAR_TEXTURE =''')
rep('    rainDynamicSceneCopyState.surface:bind(rainStateMetaUpdateParams)',
    '''    rainDynamicSceneCopyState.surface:bind(rainStateMetaUpdateParams)
    rainStateUpdateParams.values.gRainCoatAdhesion=cfg.RUNTIME.RAIN_SURFACE_COAT_ADHESION
    rainStateUpdateParams.values.gRainGlassExtraDrag=cfg.RUNTIME.RAIN_SURFACE_GLASS_EXTRA_DRAG''')
# Physical merge broad phase, no UV-island bucket assumptions.
a=s.index('    local grid = {}',s.index('updateMergeCommands = function'));b=s.index('    local partner = {}',a)
s=s[:a]+'''    local grid = {}
    local points={}
    local function cellKey(x,y,z) return x..':'..y..':'..z end
    for i=1,n do
        if px[i] then
            local x,y,z=state.surface:point(px[i],py[i]);points[i]={x,y,z}
            local key=cellKey(math.floor(x/cell),math.floor(y/cell),math.floor(z/cell))
            local bucket=grid[key] or {};grid[key]=bucket;bucket[#bucket+1]=i
        end
    end
'''+s[b:]
rep('''            local cx = math.floor(xi / cell)
            local cy = math.floor((yi + 1.0) / cell)''','''            local point=points[i]
            local cx=math.floor(point[1]/cell);local cy=math.floor(point[2]/cell);local cz=math.floor(point[3]/cell)''')
rep('''            local speed = math.sqrt(vu * vu + vv * vv)
            local steerJ, steerD''','''            local pu,pv=state.surface:plane(xi,yi,vu,vv)
            local speed=math.sqrt(pu*pu+pv*pv)
            local steerJ, steerD''')
rep('''                for gy = cy - 1, cy + 1 do
                    local bucket = grid[gx * 65536 + gy]''','''                for gy = cy - 1, cy + 1 do
                  for gz=cz-1,cz+1 do
                    local bucket = grid[cellKey(gx,gy,gz)]''')
rep('''                                local d = math.sqrt(dx * dx + dy * dy)''','''                                local other=points[j]
                                local d=math.sqrt((other[1]-point[1])^2+(other[2]-point[2])^2+(other[3]-point[3])^2)
                                local du,dv=state.surface:plane(xi,yi,dx,dy)''')
rep('''                                    and (dx * vu + dy * vv)
                                        > cone * d * speed''','''                                    and (du * pu + dv * pv)
                                        > cone * d * speed''')
rep('''            if bestJ and pairCount < maxPairs then''','''            end -- physical Z cell
            if bestJ and pairCount < maxPairs then''')
# Physical head/lobe/puddle offsets on the GPU. Synthetic kernels are defined
# in orthonormal plane units and then mapped to true UV, never V=down.
rep('''float rgFrac(float x) { return x - floor(x); }''','''float2 rgShift(float2 pos,float2 physicalPixels) {
    float2 p=float2(pos.x/gSize,pos.y/gSize-1);
    return pos+rainMetricOffset(p,physicalPixels/gSize)*gSize;
}
float rgFrac(float x) { return x - floor(x); }''')
rep('tail = pos - vel / speed * (mr * R);','tail = rgShift(pos,-vel / speed * (mr * R));')
rep('lobe = pos + dir * (R * (0.45 + 0.15 * seedB) * gShapeStrength);','lobe = rgShift(pos,dir * (R * (0.45 + 0.15 * seedB) * gShapeStrength));')
rep('p1 = pos + dd * reach;','p1 = rgShift(pos,dd * reach);')
rep('p2 = pos + float2(-dd.y * 0.7 - dd.x * 0.35, dd.x * 0.7 - dd.y * 0.35) * reach;',
    'p2 = rgShift(pos,float2(-dd.y * 0.7 - dd.x * 0.35, dd.x * 0.7 - dd.y * 0.35) * reach);')
rep('rgKern(px, pos + float2(cos(a), sin(a)) * d, rr, rr, u, R / 32.0, amp, acc);',
    'rgKern(px, rgShift(pos,float2(cos(a), sin(a)) * d), rr, rr, u, R / 32.0, amp, acc);')
# Do not produce off-surface head texels, even if their kernel extends over a
# hole. State exits die via the same mask; renderer clips it too.
rep('    if (gDebug > 0.5 && gDebug < 1.5)',
    '    acc *= rainValid(float2(pin.Tex.x,pin.Tex.y-1));\n    if (gDebug > 0.5 && gDebug < 1.5)')
# Boundary clip + lower film retention on hydrophobic coating, no island wrap.
rep('textures = { txTrailPrevious = previous },',
    "textures = {txTrailPrevious=previous,txTrailBoundary=textureRainBoundaryMask,txTrailCoat=state.surface.root..'dv.dds'},") if 'textures = { txTrailPrevious = previous },' in s else None
rep('gTrailTexel = vec2(1.0,4.0) / size,',
    'gTrailTexel = vec2(1.0,4.0) / size,\n            gTrailCoatRetention=cfg.RUNTIME.RAIN_SURFACE_COAT_RETENTION,')
rep('''                float4 next = previous * k;''','''                float coat=txTrailCoat.SampleLevel(samLinearClamp,pin.Tex,0).a;
                k=pow(k,1/max(lerp(1,gTrailCoatRetention,coat),.05));
                float4 next = previous * k * step(.5,txTrailBoundary.SampleLevel(samLinearClamp,pin.Tex,0).a);''')
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8',newline='\n')
p=ROOT/'shaders/rainVisorDynamicDrop.hlsl';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
rep('''            pin.Tex.x + 4.0, pin.Tex.y + 1.0));''','''            pin.Tex.x + 4.0, pin.Tex.y + 1.0));
        clip(rainValid(float2(patternUV.x,patternUV.y-1))-.5);''')
rep('''float2 patternUV = saturate(float2(pin.Tex.x + 4.0, pin.Tex.y + 1.0));''',
    '''float2 patternUV = saturate(float2(pin.Tex.x + 4.0, pin.Tex.y + 1.0));
        clip(rainValid(float2(patternUV.x,patternUV.y-1))-.5);''')
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8',newline='\n')
