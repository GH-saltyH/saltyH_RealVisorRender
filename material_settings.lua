-- Persist native editor values by mesh, custom shader controls by runtime key.
-- Inject dependencies so INI round-trip and initialization can be tested locally.
return function(d)
    local st={path=d.path, dirty=false}
    local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
    local function custom(e) return d.customItem(e.meshName)~=nil end
    local function decode(ini,section,key,kind)
        local raw=ini:get(section,key)
        if not raw then return nil end
        if kind=='bool' then
            local v=tostring(raw[1]):lower()
            if v=='1' or v=='true' then return true end
            if v=='0' or v=='false' then return false end
            return nil
        end
        local n=kind=='vec3' and 3 or kind=='vec2' and 2 or 1
        local v={}
        for i=1,n do v[i]=tonumber(raw[i]);if not finite(v[i]) then return nil end end
        if n==3 then return vec3(v[1],v[2],v[3]) end
        if n==2 then return vec2(v[1],v[2]) end
        return v[1]
    end
    local function encode(value,kind)
        if kind=='bool' then return value and '1' or '0' end
        if kind=='vec2' or kind=='vec3' then
            local v={value.x,value.y}
            if kind=='vec3' then v[3]=value.z end
            for i,x in ipairs(v) do if not finite(x) then return nil end;v[i]=string.format('%.17g',x) end
            return v
        end
        if finite(value) then return string.format('%.17g',value) end
    end
    function st:markDirty() self.dirty=true;self.changedAt=os.clock() end
    function st:applyEditor(e,values)
        if custom(e) or not e.targetMesh or #e.targetMesh==0 then return true end
        local saved=e.values
        local selected={}
        for key,entry in pairs(values or saved or {}) do
            if (entry.readOk or entry.edited) and encode(entry.value,entry.type or 'float') then
                selected[key]=entry
            end
        end
        if next(selected)==nil then return true end
        e.values=selected
        local ok,result=pcall(function()
            e.targetMesh:ensureUniqueMaterials() -- mesh-specific edits must not alter shared materials
            return d.apply(e)
        end)
        e.values=saved
        if not ok then e.lastError=tostring(result);return false end
        return result~=false
    end
    function st:save(applyAll)
        local ok,err=pcall(function()
            self.ini=self.ini or ac.INIConfig.parse(io.load(self.path) or '')
            self.ini:set('META','VERSION',1)
            for _,e in ipairs(d.editors) do
                if not custom(e) and e.loaded then
                    if applyAll and not self:applyEditor(e) then error(e.lastError or ('Cannot apply '..e.meshName)) end
                    for _,p in ipairs(e.parameters) do
                        local entry=e.values[p.name]
                        if entry and (entry.readOk or entry.edited) then
                            local value=encode(entry.value,p.type)
                            if value then self.ini:set('MESH:'..e.meshName,p.name,value) end
                        end
                    end
                end
            end
            for key,value in pairs(d.runtime) do
                if key:match('^RAIN_VISOR_LAYER_') and (type(value)=='boolean' or type(value)=='number') then
                    self.ini:set('CUSTOM_SHADER',key,encode(value,type(value)=='boolean' and 'bool' or 'float'))
                end
            end
            if io.save(self.path,self.ini:serialize(),true)==false then error('INI write failed') end
        end)
        self.status=ok and 'Saved settings_mats.ini' or ('Material settings error: '..tostring(err))
        if ok then self.dirty=false end
        return ok
    end
    function st:load()
        local ok,err=pcall(function()
            local data=io.load(self.path)
            self.ini=ac.INIConfig.parse(data or '')
            for key,current in pairs(d.runtime) do
                if key:match('^RAIN_VISOR_LAYER_') and (type(current)=='boolean' or type(current)=='number') then
                    local value=decode(self.ini,'CUSTOM_SHADER',key,type(current)=='boolean' and 'bool' or 'float')
                    if value~=nil then d.runtime[key]=value end
                end
            end
            for _,e in ipairs(d.editors) do
                if not custom(e) and e.targetMesh and #e.targetMesh>0 then
                    if not e.loaded then d.read(e) end
                    local restored={}
                    for _,p in ipairs(e.parameters) do
                        local value=decode(self.ini,'MESH:'..e.meshName,p.name,p.type)
                        if value~=nil then
                            local entry={type=p.type,value=value,readOk=true}
                            e.values[p.name]=entry;restored[p.name]=entry
                        end
                    end
                    e.inputBuffers={}
                    if not self:applyEditor(e,restored) then error(e.lastError or ('Cannot restore '..e.meshName)) end
                end
            end
            self.status=data and 'Loaded settings_mats.ini' or 'Created settings_mats.ini from current materials'
            -- Fill newly discovered parameters without dropping absent mesh sections.
            if not self:save(false) then error(self.status) end
        end)
        if not ok then self.status='Material settings error: '..tostring(err) end
        return ok
    end
    function st:flush()
        if self.dirty and os.clock()-(self.changedAt or 0)>0.5 then self:save(false) end
    end
    return st
end
