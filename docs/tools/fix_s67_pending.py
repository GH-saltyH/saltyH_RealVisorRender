from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];p=ROOT/'visor_optics.lua';stamp=p.stat().st_mtime_ns
s=p.read_text(encoding='utf-8')
def one(a,b):
    global s
    assert s.count(a)==1,(a,s.count(a));s=s.replace(a,b)
one("    local function requireUpdate(value) if value==false then error('Optics shader/capture pending') end end",'''    local function ready(value)
        if value==false then st.pending=true;st.status='Optics shader/capture preparing';return false end
        return true
    end''')
one('                for _,p in ipairs(draws) do requireUpdate(safeDraw(p)) end','''                for _,p in ipairs(draws) do
                    if safeDraw(p)==false then
                        self.capturePending=self.capturePending or {};self.capturePending[name]=true
                        return -- normal async compile; never throw across a CSP callback
                    end
                end''')
one('            requireUpdate((d.captureUpdate or function(shot,...) return shot:update(...) end)(self[name],eyeWorld,look,up,self.bakeFov))','''            self.capturePending=self.capturePending or {};self.capturePending[name]=false
            local updated=(d.captureUpdate or function(shot,...) return shot:update(...) end)(self[name],eyeWorld,look,up,self.bakeFov)
            if not ready(updated) or not ready(not self.capturePending[name]) then return false end''')
one('self.probeExpected=ac.GeometryShot({opaque=function() requireUpdate(safeDraw(self.probeExpectedParams)) end}',
    'self.probeExpected=ac.GeometryShot({opaque=function() self.probeExpectedPending=safeDraw(self.probeExpectedParams)==false end}')
one('        requireUpdate(d.probeUpdate(self.probeExpected,probe.captureRefs,origin,-light,up,75))','''        self.probeExpectedPending=false
        local updated=d.probeUpdate(self.probeExpected,probe.captureRefs,origin,-light,up,75)
        if not ready(updated) or not ready(not self.probeExpectedPending) then return false end''')
while 'requireUpdate(' in s:
    a=s.index('requireUpdate(');start=a+len('requireUpdate(');b=start;depth=1
    while depth:
        if s[b]=='(':depth+=1
        elif s[b]==')':depth-=1
        b+=1
    s=s[:a]+'if not ready('+s[start:b-1]+') then return false end'+s[b:]
one('        self:updateMask();local sim=ac.getSim();local pose=d.pose();if not pose then return end',
    '        if self:updateMask()==false then return false end;local sim=ac.getSim();local pose=d.pose();if not pose then return end')
one('        self:updateBright(scene,maxMip)','        if self:updateBright(scene,maxMip)==false then return false end')
one('        local light,side=self:updateSun(sim);local inverse=pose:inverse()',
    '        local light,side=self:updateSun(sim);if light==false then return false end;local inverse=pose:inverse()')
assert p.stat().st_mtime_ns==stamp;p.write_text(s,encoding='utf-8')
print('Optics pending now returns readiness and callback markers; no pending exceptions')
