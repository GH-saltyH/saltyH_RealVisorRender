-- Transparent native glass does not cast an opaque four-layer sun shadow.
-- Material colours, alpha, shader, cull/depth modes and Visible are preserved.
return function(d)
    local st={items={},names={'GLASS_EXT_MRR','GLASS_COAT_MRR','GLASS_INT_MRR','GLASS_STICKER_MRR'}}
    function st:restore()
        for _,entry in pairs(self.items) do
            for _,part in ipairs(entry.parts) do pcall(function() part.ref:setShadows(part.shadows) end) end
        end
        self.items={}
    end
    function st:update()
        for _,name in ipairs(self.names) do
            local e=d.editor(name);local ref=e and e.targetMesh
            if ref and #ref>0 then
                local entry=self.items[name]
                if not entry or entry.ref~=ref then
                    entry={ref=ref,parts={}};self.items[name]=entry
                    for i=1,#ref do
                        entry.parts[#entry.parts+1]={ref=ref:at(i),shadows=ref:isCastingShadows(i)}
                    end
                end
                for _,part in ipairs(entry.parts) do
                    part.ref:setShadows(d.runtime.RAIN_VISOR_LAYER_NATIVE_GLASS_SHADOWS and part.shadows or false)
                end
            end
        end
    end
    function st:ui()
        if ui.checkbox('Native glass casts hard sun shadows (comparison)',d.runtime.RAIN_VISOR_LAYER_NATIVE_GLASS_SHADOWS) then
            d.runtime.RAIN_VISOR_LAYER_NATIVE_GLASS_SHADOWS=not d.runtime.RAIN_VISOR_LAYER_NATIVE_GLASS_SHADOWS
            d.dirty()
        end
        ui.textWrapped('Clear native glass keeps reflections and opacity; hard shadows are off so the opening receives sunlight. Frame/rubber shadows remain.')
        ui.treeNode('Native glass render states',function()
            for _,name in ipairs(self.names) do
                local entry=self.items[name]
                if entry then
                    local ref=entry.ref
                    ui.text(string.format('%s: transparent %s | blend %s | depth %s | cull %s | shadow %s',name,
                        tostring(ref:isTransparent(1)),tostring(ref:blendMode(1)),tostring(ref:depthMode(1)),
                        tostring(ref:cullMode(1)),tostring(ref:isCastingShadows(1))))
                end
            end
        end)
    end
    return st
end
