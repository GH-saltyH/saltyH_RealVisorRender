"""Exact-anchor, mtime-guarded s63 runtime fixes; not a migration tool."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=ROOT/'realvisor.lua';mtime=p.stat().st_mtime_ns;s=p.read_text(encoding='utf-8')
def rep(a,b,count=1):
    global s
    assert s.count(a)==count,(a[:100],s.count(a),count)
    s=s.replace(a,b)
# Every CPU-predicted centre must remain on the supported surface.
for indent,default in [('            ','0.0'),('            ','-1.0'),('                ','-1.0')]:
    a=(f'{indent}local u = (rainDynamicStateU[index] or {default})\n'
       f'{indent}    + (rainDynamicStateVelocityU[index] or 0.0)\n'
       f'{indent}        * predictedAge\n'
       f'{indent}local v = (rainDynamicStateV[index] or '+('-1.0' if default=='0.0' else '-2.0')+')\n'
       f'{indent}    + (rainDynamicStateVelocityV[index] or 0.0)\n'
       f'{indent}        * predictedAge')
    b=(f'{indent}local u,v=state.surface:preview(rainDynamicStateU[index] or -1,\n'
       f'{indent}    rainDynamicStateV[index] or -2,rainDynamicStateVelocityU[index] or 0,\n'
       f'{indent}    rainDynamicStateVelocityV[index] or 0,predictedAge)')
    rep(a,b)
rep('if u >= 0.0 and u <= 1.0 and v >= -1.0 and v <= 0.0 then','if state.surface:valid(u,v) then',3)
rep('local distance2 = du * du + dv * dv','local distance = state.surface:length(u,v,du,dv)\n                local distance2 = distance * distance')
rep('if old and old.generation ~= generation then old = nil end',
    'if old and (old.generation ~= generation\n                    or not state.surface:segment(old.u,old.v,u,v)) then old = nil end')
rep('    t, minKernel, ampScale)\n    local r = cfg.RUNTIME',
    '    t, minKernel, ampScale, surface, headSize)\n    local r = cfg.RUNTIME')
rep('    local x, y = origin.x, origin.y\n',
    '    local x, y = origin.x, origin.y\n    if not surface:valid(x/headSize,y/headSize-1) then return 0 end\n    local function piece(dx,dy,rx,ry,ux,uy,code,energy,amp)\n        local cx,cy=surface:shift(x,y,dx,dy,headSize)\n        quad(cx*scale,cy*scale,rx*scale,ry*scale,ux,uy,code,energy,amp)\n    end\n')
rep('            quad((x + ca * d) * scale, (y + sn * d) * scale, along * scale,\n                rr * scale, -sn, ca, rr / 32.0, 1.0, ringOn * amp0)',
    '            piece(ca*d,sn*d,along,rr,-sn,ca,rr/32.0,1.0,ringOn*amp0)')
rep('            quad((x + satellites[j + 2] * d) * scale,\n                (y + satellites[j + 3] * d) * scale,\n                rr * scale, rr * scale, 1.0, 0.0, rr / 32.0, 1.0, amp0)',
    '            piece(satellites[j+2]*d,satellites[j+3]*d,rr,rr,1,0,rr/32.0,1.0,amp0)')
rep('origin, 1.0, st, tearMinKernel, 1.0)',
    'origin, 1.0, st, tearMinKernel, 1.0, state.surface, size)')
rep('tearMinKernel / math.max(scale, 0.05), 0.85)',
    'tearMinKernel / math.max(scale, 0.05), 0.85, state.surface, headSize)')
# Reject quads on blank Jacobian cells BEFORE issuing UI commands.
rep('        state.surface:quad(q1,q2,q3,q4,cx,cy,ax,ay,ux,uy,size)',
    '        if not state.surface:quad(q1,q2,q3,q4,cx,cy,ax,ay,ux,uy,size) then return end',2)
rep('                st.surface:quad(q1,q2,q3,q4,o[2],o[3],o[8],o[8],1,0,size)',
    '                local supported=st.surface:quad(q1,q2,q3,q4,o[2],o[3],o[8],o[8],1,0,size)')
rep('                ui.drawImageQuad(drawAtlas,q1,q2,q3,q4,rgbm(1,1,1,1),\n                    vec2(u0,v0),vec2(u1,v0),vec2(u1,v1),vec2(u0,v1))',
    '                if supported then ui.drawImageQuad(drawAtlas,q1,q2,q3,q4,rgbm(1,1,1,1),\n                    vec2(u0,v0),vec2(u1,v0),vec2(u1,v1),vec2(u0,v1)) end')
rep('                    state.surface:ribbon(q1,q2,q3,q4,fx,fy,x,y,hw,ux,uy,size)',
    '                    local supported=state.surface:ribbon(q1,q2,q3,q4,fx,fy,x,y,hw,ux,uy,size)')
rep('                    if len > 1e-3 then\n                        ui.drawImageQuad(ribbon',
    '                    if supported and len > 1e-3 then\n                        ui.drawImageQuad(ribbon')
rep('if lastGen[index] == generation and lastX[index] then',
    'if lastGen[index] == generation and lastX[index]\n                    and state.surface:segment(lastX[index]/size,lastY[index]/size-1,x/size,y/size-1) then')
# Per-pixel tile candidates retain the same conservative reach as Pass A.
# Reject pixels outside each candidate BEFORE seeds, trig, shape and kernels.
rep('    float speed = length(vel);\n    float seedA = rgFrac',
    '    float reach = R * (gKs * 1.4 + max(gMaxRadii, max(gPuddleReach * 1.1, 0.6)) + 0.1) + 2.0;\n'
    '    if(any(abs(px-pos)>rgExtent(reach))) return;\n    float speed = length(vel);\n    float seedA = rgFrac')
# Empty physical-mask pixels never walk tile lists.
rep('    float2 tex = pin.Tex;\n    if (gFlipY > 0.5)',
    '    if(rainValid(float2(pin.Tex.x,pin.Tex.y-1))<.5) return 0;\n    float2 tex = pin.Tex;\n    if (gFlipY > 0.5)')
assert p.stat().st_mtime_ns==mtime,'User changed realvisor.lua during patch'
p.write_text(s,encoding='utf-8')
print('s63 exact runtime anchors applied; settings and user profiling retained')
