"""Second guarded migration: physical kernels and rectangular transport."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
def repl(s,a,b,n=1):
    assert s.count(a)==n,(a[:100],s.count(a));return s.replace(a,b)
def save(p,s,stamp):
    assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8',newline='\n')
p=ROOT/'realvisor.lua';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
# Physical sizes in the CPU mesh renderer too.
s=repl(s,'if math.abs(det) < 0.0000001 then return nil end','if math.abs(det) < 1e-12 then return nil end')
s=repl(s,'sample.tangentU * (radiusUV * sample.metersPerUVU)','sample.tangentU * (radiusUV * .001 / cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM)',2)
s=repl(s,'sample.tangentV * (radiusUV * sample.metersPerUVV)','sample.tangentV * (radiusUV * .001 / cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM)',2)
# Merge validation is metric-aware in both state/meta shaders.
s=s.replace('float dist = length(pState.rg - selfP);','float dist = rainMetricLength(selfP,pState.rg - selfP);')
s=repl(s,'float dist = length(toOther);','float dist = rainMetricLength(p,toOther);')
s=s.replace('length(v) * gRainSteerTurnRate','rainMetricLength(p,v) * gRainSteerTurnRate')
s=s.replace('float wsp0 = length(v);','float wsp0 = rainMetricLength(p,v);').replace('float wsp = length(v);','float wsp = rainMetricLength(p,v);')
# Wet-path gradient is a covector. Convert by the inverse metric, then turn
# in the orthonormal physical plane, preserving physical speed.
a=s.index('                float2 wdir = v / max(wsp, 1e-7);');b=s.index('\n            }\n#endif',a)
s=s[:a]+'''                float2 planeV=rainMetricPlane(p,v);
                float3 ju,jv;rainMetric(p,ju,jv);
                float aa=dot(ju,ju),bb=dot(ju,jv),cc=dot(jv,jv);
                float2 covector=wg/max(wt,1e-9);
                float2 gradUV=float2(cc*covector.x-bb*covector.y,aa*covector.y-bb*covector.x)
                    /max(aa*cc-bb*bb,1e-20)*gRainMetersPerUnit*gRainMetersPerUnit;
                float2 grad=rainMetricPlane(p,gradUV);
                float2 direction=planeV/max(wsp,1e-7);
                float2 lateral=grad-dot(grad,direction)*direction;
                float on=saturate(wsp/max(gRainWetPathMinSpeed,1e-6)-1);
                float2 change=lateral*(gRainWetPathGain*dt*on);
                change*=min(1,wsp*gRainSteerTurnRate*dt/max(length(change),1e-9));
                v+=rainMetricOffset(p,change);'''+s[b:]
# Attraction steering bounded in physical distance rather than UV-vector norm.
s=s.replace('length(attractDv)', 'rainMetricLength(p,attractDv)')
# Rectangle GPU backing, square virtual UI units; not all canvases are atlases.
s=s.replace('ui.ExtraCanvas(vec2(size, size), 1','ui.ExtraCanvas(vec2(size, math.max(1,math.floor(size/4))), 1')
# Atlas update wrappers: target variables scoped inside these functions only.
sections=[('updateTrailMask = function','updateTrailMaskTimed = function'),
 ('waterFieldDrawStamps = function','waterFieldUpdateImpactSheet = function'),
 ('waterFieldUpdateTrail = function','gpuHeadsCommon ='),
 ('gpuSplashRun = function','updateBirthMask = function'),
 ('updateBirthMask = function','rainOverlayEnsure = function')]
# Select canvas UI updates by actual function boundaries, avoid linear state
# metadata and the sprite atlas. CPU draws use virtual square coordinates.
for start,end in [('updateTrailMask = function','updateTrailMaskTimed = function'),
                  ('waterFieldUpdateTrail = function','gpuHeadsCommon ='),
                  ('updateBirthMask = function','rainOverlayEnsure = function')]:
    if start not in s or end not in s:continue
    a=s.index(start);b=s.index(end,a);part=s[a:b]
    part=part.replace('target:update(function()','state.surface:updateAtlas(target,size,function()')
    # state.surface is available through the shared table (state=that table).
    s=s[:a]+part+s[b:]
# Additional birth target updates named state.birthMaskA.
s=s.replace('state.birthMaskA:update(function()','state.surface:updateAtlas(state.birthMaskA,size,function()')
# Shader finite differences use both actual texel axes.
s=s.replace('gTrailTexel = 1.0 / size,','gTrailTexel = vec2(1.0,4.0) / size,')
s=s.replace('float2(gTrailTexel, 0.0)','float2(gTrailTexel.x, 0.0)').replace('float2(0.0, gTrailTexel)','float2(0.0, gTrailTexel.y)')
s=s.replace('txImpactBoundary.SampleLevel(samLinearClamp,\n                    pin.Tex, 0.0).r','txImpactBoundary.SampleLevel(samLinearClamp,\n                    pin.Tex, 0.0).a')
# Square-source smear pattern is intentionally reusable; locate relocated source.
s=repl(s,"'texture/smear_mask_v7_template_2048.png'","'texture/Pre 7.0 Textures/smear_mask_v7_template_2048.png'")
# Physical metric quads for CPU bodies/splashes/trails, before atlas scaling.
block='''        q1.x, q1.y = cx - ux * ax - vx * ay, cy - uy * ax - vy * ay
        q2.x, q2.y = cx + ux * ax - vx * ay, cy + uy * ax - vy * ay
        q3.x, q3.y = cx + ux * ax + vx * ay, cy + uy * ax + vy * ay
        q4.x, q4.y = cx - ux * ax + vx * ay, cy - uy * ax + vy * ay'''
assert s.count(block)>=2
s=s.replace(block,'        state.surface:quad(q1,q2,q3,q4,cx,cy,ax,ay,ux,uy,size)')
# CPU per-drop velocity is mapped into a physical orthonormal plane when used
# as a visual speed/orientation (transport still uses raw velocity U,V).
for start,end in [('waterFieldDrawStamps = function','waterFieldUpdateImpactSheet = function')]:
    a=s.index(start);b=s.index(end,a);part=s[a:b]
    part=part.replace('local speed = math.sqrt(vu * vu + vv * vv)',
        'vu,vv=state.surface:plane(stamp.x/size,stamp.y/size-1,vu,vv)\n            local speed = math.sqrt(vu * vu + vv * vv)')
    s=s[:a]+part+s[b:]
# GPU head kernels operate in the same physical plane; virtual pixels keep
# existing R/32 codes and CPU splash metadata unchanged.
s=repl(s,'rainDynamicSceneCopyState.gpuHeadsCommon = [[','rainDynamicSceneCopyState.gpuHeadsCommon = rainDynamicSceneCopyState.surface.shader..[[')
s=repl(s,'    vel = st.ba;','    vel = rainMetricPlane(st.rg,st.ba);')
s=repl(s,'    float2 d = px - c;','    float2 d = rainMetricPlane(float2(c.x/gSize,c.y/gSize-1),(px-c)/gSize)*gSize;',2)
s=repl(s,'    local tilesY = tilesX','    local tilesY = math.ceil(size/(tile*4))')
s=repl(s,'    values.gTile = tile','    values.gTile = vec2(tile,tile*4)')
s=s.replace('floor(px.x / gTile)','floor(px.x / gTile.x)').replace('floor(px.y / gTile)','floor(px.y / gTile.y)')
s=repl(s,'            float2 q = clamp(pos, tmin, tmax);\n            if (dot(q - pos, q - pos) <= reach * reach)',
 '''            float2 ext=rainMetricExtent(float2(pos.x/gSize,pos.y/gSize-1),reach/gSize)*gSize;
            if(all(pos+ext>=tmin)&&all(pos-ext<=tmax))''')
# Bind metric textures/uniforms to ALL head pass variants (CSP auto declarations).
s=repl(s,'    values.gSize = size','    values.gSize = size\n    values.gRainMetersPerUnit = .001/math.max(r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM,1e-6)')
s=repl(s,'textures = { txRainState = state, txRainStateMeta = meta },',
 "textures = {txRainState=state,txRainStateMeta=meta,txRainDu=st.surface.root..'du.dds',txRainDv=st.surface.root..'dv.dds',txRainBoundaryMask=textureRainBoundaryMask},")
s=repl(s,'textures = { txRainState = state, txRainStateMeta = meta,\n                txMask',
 "textures = {txRainState=state,txRainStateMeta=meta,txRainDu=st.surface.root..'du.dds',txRainDv=st.surface.root..'dv.dds',txRainBoundaryMask=textureRainBoundaryMask,\n                txMask")
s=repl(s,'rainDynamicSceneCopyState.gpuSplashAtlasShader = [[','rainDynamicSceneCopyState.gpuSplashAtlasShader = rainDynamicSceneCopyState.surface.shader..[[')
# Sprite atlas is square per sprite (not visor UV); its body kernel is physical.
# The atlas shader evaluates local sprite coordinates, so do not metric-map
# sprite texels; they are projected by the CPU destination quad instead.
a=s.index('rainDynamicSceneCopyState.gpuSplashAtlasShader =');b=s.index('rainDynamicSceneCopyState.gpuSplashRun',a) if 'rainDynamicSceneCopyState.gpuSplashRun' in s[a:] else s.index('rainDynamicSceneCopyState.gpuSplash',a+60)
part=s[a:b];part=part.replace('rainDynamicSceneCopyState.surface.shader..[[','[[').replace('rainMetricPlane(float2(c.x/gSize,c.y/gSize-1),(px-c)/gSize)*gSize','px-c');s=s[:a]+part+s[b:]
# Inline splash shader may still have the metric prelude removed above.
# Main rain surface: clip holes, use metric projected size, rectangular steps.
s=repl(s,'    rainDynamicSceneCopyState.lastDropMeshParams = dropMeshParams',
 '''    rainDynamicSceneCopyState.surface:bind(dropMeshParams)
    dropMeshParams.shader=rainDynamicSceneCopyState.surface.shader..dropMeshParams.shader
    rainDynamicSceneCopyState.lastDropMeshParams = dropMeshParams''')
save(p,s,stamp)
p=ROOT/'shaders/rainVisorDynamicDrop.hlsl';stamp=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
s=repl(s,'float2 stepV = float2(0.0, wfStep);','float2 stepV = float2(0.0, wfStep*4.0);')
s=repl(s,'float radiusPx = radiusUV / sqrt(max(abs(wfDet), 1e-14));',
 '''float2 physicalDx=rainMetricPlane(float2(patternUV.x,patternUV.y-1),wfDx);
            float2 physicalDy=rainMetricPlane(float2(patternUV.x,patternUV.y-1),wfDy);
            float physicalDet=physicalDx.x*physicalDy.y-physicalDx.y*physicalDy.x;
            float radiusPx = radiusUV / sqrt(max(abs(physicalDet), 1e-14));''')
s=repl(s,'float2 patternUV = float2(pin.Tex.x + 4.0, pin.Tex.y + 1.0);',
 '''float2 patternUV = float2(pin.Tex.x + 4.0, pin.Tex.y + 1.0);
        clip(rainValid(float2(patternUV.x,patternUV.y-1))-.5);''') if 'float2 patternUV = float2(pin.Tex.x + 4.0, pin.Tex.y + 1.0);' in s else s
save(p,s,stamp)



