"""Material persistence regression tests using the bundled LuaJIT runtime."""
from pathlib import Path
import runpy

root=Path(__file__).resolve().parents[2]
env=runpy.run_path(str(root/'docs/tools/check_baked_housing.py'))
lua=env['lua']
lua.execute('''
    function vec2(x,y) return {x=x,y=y} end
    function vec3(x,y,z) return {x=x,y=y,z=z} end
    files={};writes=0
    io.load=function(path) return files[path] end
    io.save=function(path,data) files[path]=data;writes=writes+1;return true end
    ac={INIConfig={parse=function(data)
        local ini={sections={}}
        local section
        for line in ((data or '')..'\\n'):gmatch('(.-)\\n') do
            local heading=line:match('^%[(.-)%]$')
            if heading then section=heading;ini.sections[section]={}
            elseif section then
                local key,val=line:match('^(.-)=(.*)$')
                if key then
                    local items={}
                    for v in (val..','):gmatch('(.-),') do items[#items+1]=v:match('^%s*(.-)%s*$') end
                    ini.sections[section][key]=items
                end
            end
        end
        function ini:get(s,k) return self.sections[s] and self.sections[s][k] end
        function ini:set(s,k,v)
            self.sections[s]=self.sections[s] or {}
            self.sections[s][k]=type(v)=='table' and v or v~=nil and {tostring(v)} or nil
        end
        function ini:serialize()
            local lines={}
            for s,values in pairs(self.sections) do
                lines[#lines+1]='['..s..']'
                for k,v in pairs(values) do lines[#lines+1]=k..'='..table.concat(v,',') end
            end
            return table.concat(lines,'\\n')
        end
        return ini
    end}}
    params={{name='f',type='float'},{name='b',type='bool'},
        {name='v2',type='vec2'},{name='v3',type='vec3'},{name='unread',type='float'}}
    applied={};separated=0
    function editor(name)
        return {meshName=name,loaded=true,parameters=params,inputBuffers={},
            targetMesh={{},ensureUniqueMaterials=function() separated=separated+1 end},values={
                f={value=0.12345678912345678,readOk=true},b={value=false,readOk=true},
                v2={value=vec2(2,3),readOk=true},v3={value=vec3(4,5,6),readOk=true},
                unread={value=0,readOk=false}}}
    end
    e=editor('BODY_FRAME');custom=editor('GLASS_INT_OVERLAY')
    runtime={RAIN_VISOR_LAYER_TEST=true,RAIN_VISOR_LAYER_GAIN=1.23456789123456,UNRELATED=99}
    deps={path='settings_mats.ini',editors={e,custom},runtime=runtime,
        customItem=function(name) if name=='GLASS_INT_OVERLAY' then return {} end end,
        read=function() error('Unexpected reread') end,
        apply=function(ed) applied[ed.meshName]=ed.values;return true end}
''')
factory=lua.execute((root/'material_settings.lua').read_text(encoding='utf-8'))
lua.globals().factory=factory
lua.execute('''
    st=factory(deps)
    assert(st:load() and files[deps.path] and writes==1)
    assert(not files[deps.path]:find('unread=') and not files[deps.path]:find('UNRELATED'))
    assert(not files[deps.path]:find('MESH:GLASS_INT_OVERLAY'))
    assert(st:save(true) and separated==1 and not applied.GLASS_INT_OVERLAY)
    e.values.f.value=0;e.values.b.value=true;e.values.v2.value=vec2(0,0);e.values.v3.value=vec3(0,0,0)
    runtime.RAIN_VISOR_LAYER_GAIN=0;runtime.RAIN_VISOR_LAYER_TEST=false
    assert(st:load())
    assert(e.values.f.value==0.12345678912345678 and e.values.b.value==false)
    assert(e.values.v2.value.y==3 and e.values.v3.value.z==6)
    assert(runtime.RAIN_VISOR_LAYER_GAIN==1.23456789123456 and runtime.RAIN_VISOR_LAYER_TEST)
    files[deps.path]=files[deps.path]..'\\n[MESH:ABSENT]\\nf=7\\n[MESH:BODY_FRAME]\\nf=nan\\nb=invalid\\n'
    local previous=e.values.f.value
    assert(st:load() and e.values.f.value==previous and e.values.b.value==false)
    assert(files[deps.path]:find('MESH:ABSENT') and files[deps.path]:find('f=7'))
    e.values.unread.edited=true;e.values.unread.value=2
    assert(st:save(false) and files[deps.path]:find('unread=2'))
    st:markDirty();st.changedAt=os.clock()-1;local before=writes;st:flush()
    assert(writes==before+1 and not st.dirty)
    io.save=function() return false end
    assert(not st:save(false) and st.status:find('error'))
''')
print('PASS: INI round-trip float/bool/vectors, custom runtime, missing mesh preservation, invalid/unread values, shared material isolation, debounce and write failure')
