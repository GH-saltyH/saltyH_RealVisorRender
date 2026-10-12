"""Guarded migration: rectangular sampling and CPU physical footprints."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'realvisor.lua';s=p.read_text(encoding='utf-8');mtime=p.stat().st_mtime_ns
def change(a,b,n=1):
    global s
    assert s.count(a)==n,(a[:90],s.count(a),n)
    s=s.replace(a,b)
change('return rainMetricProject(position,mul(forceWorld,transpose((float3x3)gRainObjectToWorld)));',
       'float scale=max(length(gRainObjectToWorld[0].xyz),1e-6);\n            return rainMetricProject(position,mul(forceWorld,transpose((float3x3)gRainObjectToWorld))/scale);')
change('rainStateUpdateParams.values.gRainObjectToWorld =\n        transform',
       'rainStateUpdateParams.values.gRainObjectToWorld =\n        transform\n    rainDynamicSceneCopyState.surface.scale=transform:transformVector(vec3(1,0,0)):length()\n    rainDynamicSceneCopyState.surface:bind(rainStateUpdateParams)\n    rainDynamicSceneCopyState.surface:bind(rainStateMetaUpdateParams)')
change('values.gRainMetersPerUnit = .001/math.max(r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM,1e-6)',
       'values.gRainMetersPerUnit = st.surface:unit()')
change("    if not ((cfg.RUNTIME.RAIN_VISOR_OVERLAY_PROBE\n", "    local rainEditor=rainDynamicSceneCopyState.e1SourceEditor('GLASS_RAINFX')\n    if (not rainEditor or rainEditor.visible~=false) and not ((cfg.RUNTIME.RAIN_VISOR_OVERLAY_PROBE\n")
change('shader = \n            rainShader.HLSL','shader = \n            rainDynamicSceneCopyState.surface.shader..rainShader.HLSL')
# Debug has its own dictionary, so bind explicitly rather than allocating a pass per frame.
change('            txRainSurfaceNormal =\n                textureRainSurfaceNormal,',
       "            txRainSurfaceNormal =\n                textureRainSurfaceNormal,\n            txRainDu=appFolder..'/texture/RAIN_GEOMETRY/du.dds',\n            txRainDv=appFolder..'/texture/RAIN_GEOMETRY/dv.dds',")
change('            gRainDebug = cfg.RUNTIME.RAIN_DEBUG,','            gRainDebug = cfg.RUNTIME.RAIN_DEBUG,\n            gRainMetersPerUnit=rainDynamicSceneCopyState.surface:unit(),')
change('    if not rainTargetMesh\n        or #rainTargetMesh == 0 then',
       "    local rainEditor=rainDynamicSceneCopyState.e1SourceEditor('GLASS_RAINFX')\n    if (rainEditor and rainEditor.visible==false) or not rainDynamicSceneCopyState.surface:validate() then return end\n    if not rainTargetMesh\n        or #rainTargetMesh == 0 then")
change('                ui.drawLine(first, last, wipeColor, wipeWidth)\n                ui.drawCircleFilled(last, wipeWidth * 0.5, wipeColor, 8)',
       '                state.surface:stroke(first.x,first.y,last.x,last.y,wipeWidth,wipeColor,size)')
change('                ui.drawLine(first, last, ridgeColor, ridgeWidth)\n                ui.drawCircleFilled(last, ridgeWidth * 0.5, ridgeColor, 8)',
       '                state.surface:stroke(first.x,first.y,last.x,last.y,ridgeWidth,ridgeColor,size)')
change('                        local speed = math.sqrt(\n                            velocityU * velocityU\n                            + velocityV * velocityV)',
       '                        local speed = state.surface:length(u,v,velocityU,velocityV)')
change('                    stamp.lobeX = stamp.x + dirX / length * reach\n                    stamp.lobeY = stamp.y + dirY / length * reach',
       '                    stamp.lobeX,stamp.lobeY=state.surface:shift(stamp.x,stamp.y,dirX/length*reach,dirY/length*reach,size)')
change('                local speed = math.sqrt(velocityU * velocityU\n                    + velocityV * velocityV)',
       '                velocityU,velocityV=state.surface:plane(stamp.x/size,stamp.y/size-1,velocityU,velocityV)\n                local speed = math.sqrt(velocityU * velocityU + velocityV * velocityV)')
change('                stamp.puddleX = stamp.x + dx * reach\n                stamp.puddleY = stamp.y + dy * reach',
       '                stamp.puddleX,stamp.puddleY=state.surface:shift(stamp.x,stamp.y,dx*reach,dy*reach,size)')
change('                stamp.puddle2X = stamp.x\n                    + (-dy * 0.7 - dx * 0.35) * reach\n                stamp.puddle2Y = stamp.y\n                    + (dx * 0.7 - dy * 0.35) * reach',
       '                stamp.puddle2X,stamp.puddle2Y=state.surface:shift(stamp.x,stamp.y,\n                    (-dy*.7-dx*.35)*reach,(dx*.7-dy*.35)*reach,size)')
change('                    bq(stamp.x + math.cos(a) * d,\n                        stamp.y + math.sin(a) * d, rr, rr, ux, uy,',
       '                    local lx,ly=state.surface:shift(stamp.x,stamp.y,math.cos(a)*d,math.sin(a)*d,size)\n                    bq(lx,ly, rr, rr, ux, uy,')
change('            local speed = math.sqrt(vu * vu + vv * vv)\n            local R = stamp.radius or 0.0',
       '            local pu,pv=state.surface:plane(stamp.x/headSize,stamp.y/headSize-1,vu,vv)\n            local speed = math.sqrt(pu*pu+pv*pv)\n            local R = stamp.radius or 0.0')
change('                    if dx * dx + dy * dy < math.max(',
       '                    if (state.surface:length(x/size,y/size-1,dx/size,dy/size)*size)^2 < math.max(')
change('                local len = math.sqrt(sx * sx + sy * sy)\n                local ux, uy = 1.0, 0.0\n                if len > 1e-4 then ux, uy = sx / len, sy / len end',
       '                local px,py=state.surface:plane(x/size,y/size-1,sx/size,sy/size)\n                local len = math.sqrt(px*px+py*py)*size\n                local ux,uy=1,0\n                if len>1e-4 then ux,uy=px*size/len,py*size/len end')
change('                    q1.x, q1.y = fx - vx * hw, fy - vy * hw\n                    q2.x, q2.y = x - vx * hw, y - vy * hw\n                    q3.x, q3.y = x + vx * hw, y + vy * hw\n                    q4.x, q4.y = fx + vx * hw, fy + vy * hw',
       '                    state.surface:ribbon(q1,q2,q3,q4,fx,fy,x,y,hw,ux,uy,size)')
change('                ui.drawImage(kernel, p1, p2, color)\n                lastX[index], lastY[index] = x, y',
       '                trailQuad(x,y,r/ks,r/ks,1,0,R*width/32,0)\n                lastX[index], lastY[index] = x, y')
change('                ui.drawImage(drawAtlas,\n                    vec2(o[2] - o[8], o[3] - o[8]),\n                    vec2(o[2] + o[8], o[3] + o[8]),\n                    rgbm(1.0, 1.0, 1.0, 1.0),\n                    vec2(col * tile / atlasW, row * tile / atlasH),\n                    vec2((col + 1) * tile / atlasW,\n                        (row + 1) * tile / atlasH))',
       '                local q1,q2,q3,q4=vec2(),vec2(),vec2(),vec2()\n                st.surface:quad(q1,q2,q3,q4,o[2],o[3],o[8],o[8],1,0,size)\n                local u0,v0=col*tile/atlasW,row*tile/atlasH\n                local u1,v1=(col+1)*tile/atlasW,(row+1)*tile/atlasH\n                ui.drawImageQuad(drawAtlas,q1,q2,q3,q4,rgbm(1,1,1,1),\n                    vec2(u0,v0),vec2(u1,v0),vec2(u1,v1),vec2(u0,v1))')
# No implicit sharing of UV velocity between triangles: transport the mean
# local 3D surface velocity, then project separately at every film texel.
change('        local su, sv, sw = 0.0, 0.0, 0.0','        local su,sv,sw,sx,sy,sz=0,0,0,0,0,0')
change('                local sp = math.sqrt(fu * fu + fv * fv)',
       '                local u,v=rainDynamicStateU[i],rainDynamicStateV[i]\n                local sp = state.surface:length(u,v,fu,fv)\n                local x,y,z=state.surface:velocity(u,v,fu,fv)')
change('                    su, sv, sw = su + fu * sp, sv + fv * sp, sw + sp',
       '                    su,sv,sw=su+fu*sp,sv+fv*sp,sw+sp\n                    sx,sy,sz=sx+x*sp,sy+y*sp,sz+z*sp')
change('        state.flowTV = sw > 0.0 and sv / sw or 0.0',
       '        state.flowTV = sw > 0.0 and sv / sw or 0.0\n        state.flowObjectTarget=vec3(sw>0 and sx/sw or 0,sw>0 and sy/sw or 0,sw>0 and sz/sw or 0)')
change('    local fk = 1.0 - math.exp(-dt / 0.5)',
       '    local fk = 1.0 - math.exp(-dt / 0.5)\n    state.flowObject=state.flowObject or vec3()\n    state.flowObject:lerp(state.flowObjectTarget or vec3(),fk)')
change('            txImpactBoundary = textureRainBoundaryMask,',
       "            txImpactBoundary = textureRainBoundaryMask,\n            txRainBoundaryMask=textureRainBoundaryMask,\n            txRainDu=state.surface.root..'du.dds',txRainDv=state.surface.root..'dv.dds',")
change('            gImpactStep = vec2(flowU * dt, flowV * dt),',
       '            gImpactStep = vec2(flowU * dt, flowV * dt),\n            gImpactObjectStep=(state.flowObject or vec3())*dt,\n            gRainMetersPerUnit=state.surface:unit(),')
change('                float2 uv = pin.Tex - gImpactStep;',
       '                float2 p=float2(pin.Tex.x,pin.Tex.y-1);\n                float2 stepUV=rainMetricProject(p,gImpactObjectStep/gRainMetersPerUnit);\n                float2 uv = pin.Tex - stepUV;')
change('        shader = [[\n            float4 main(PS_IN pin)\n            {\n                float2 p=float2(pin.Tex.x,pin.Tex.y-1);',
       '        shader = state.surface.shader..[[\n            float4 main(PS_IN pin)\n            {\n                float2 p=float2(pin.Tex.x,pin.Tex.y-1);')
change('                height *= smoothstep(0.45, 0.55, boundary);',
       '                height *= smoothstep(0.45,0.55,boundary)*rainValid(float2(uv.x,uv.y-1));')
assert p.stat().st_mtime_ns==mtime;p.write_text(s,encoding='utf-8')

p=ROOT/'shaders/rainVisorDynamicDrop.hlsl';s=p.read_text(encoding='utf-8');mtime=p.stat().st_mtime_ns
change('rainTrailRipple(uv + float2(0.0, s))','rainTrailRipple(uv + float2(0.0, 4.0*s))')
change('rainTrailRipple(uv - float2(0.0, s))) / (2.0 * s);','rainTrailRipple(uv - float2(0.0, 4.0*s))) / (2.0 * s * float2(1,4));')
change('float2 u = float2(st, 0.0), v = float2(0.0, st);','float2 u = float2(st, 0.0), v = float2(0.0, 4.0*st);')
change('/ (2.0 * st);','/ (2.0 * st * float2(1,4));',2)
change('/ (2.0 * max(wfStep, 1e-6));','/ (2.0 * max(wfStep, 1e-6)*float2(1,4));')
change('float2 v2 = float2(0.0, s2);','float2 v2 = float2(0.0, 4.0*s2);')
change('/ (2.0 * s2);','/ (2.0 * s2*float2(1,4));')
change('gNarrow /= 2.0 * max(wfStep, 1e-6);','gNarrow /= 2.0 * max(wfStep, 1e-6)*float2(1,4);')
assert p.stat().st_mtime_ns==mtime;p.write_text(s,encoding='utf-8')

p=ROOT/'shaders/rainVisorScreen.hlsl';s=p.read_text(encoding='utf-8');mtime=p.stat().st_mtime_ns
change('float distanceToDrop = length(pin.Tex - position);','float distanceToDrop = rainMetricLength(position,pin.Tex-position);')
change('        p,\n        0.0','        float2(p.x,p.y+1),\n        0.0')
change('            pin.Tex,\n            0.0','            float2(pin.Tex.x,pin.Tex.y+1),\n            0.0')
a=s.index('float2 rainDebugProjectWorldVector(');b=s.index('float3 rainDebugAirflow',a)
s=s[:a]+'''float2 rainDebugProjectWorldVector(float3 forceWorld,float2 position)
{
    float scale=max(length(gRainObjectToWorld[0].xyz),1e-6);
    return rainMetricProject(position,mul(forceWorld,transpose((float3x3)gRainObjectToWorld))/scale);
}

'''+s[b:]
change('                forceWorld,\n                normalWorld','                forceWorld,\n                state.rg')
change('float shaftLength = length(shaft);','float2 physicalShaft=rainMetricPlane(state.rg,shaft);\n        float shaftLength=length(physicalShaft);')
change('float2 toPoint = pin.Tex - state.rg;','float2 toPoint = rainMetricPlane(state.rg,pin.Tex-state.rg);')
change('dot(toPoint, shaft) / (shaftLength * shaftLength)','dot(toPoint, physicalShaft) / (shaftLength * shaftLength)')
change('length(pin.Tex - closest)','rainMetricLength(state.rg,pin.Tex-closest)')
change('length(state.ba)','rainMetricLength(state.rg,state.ba)',2)
a=s.index('    float mask = txRainBoundaryMask.',s.index('float4 rainBoundaryMaskDebug'));b=s.index('    return float4(mask',a)
s=s[:a]+'    float mask=rainValid(pin.Tex);\n\n'+s[b:]
assert p.stat().st_mtime_ns==mtime;p.write_text(s,encoding='utf-8')
print('Rectangular sampling, physical CPU kernels, frame-scale, debug, visibility and film transport migrated')
