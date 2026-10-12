-- Native exterior glass owns its covered pixels. This independent metric
-- capture does not write scene depth or sample/composite native glass colour.
return function(d)
    local st={ready=false,updates=0,names={'GLASS_EXT_MRR','GLASS_COAT_MRR','GLASS_INT_MRR','GLASS_STICKER_MRR'}}
    function st:dispose()
        if self.shot then self.shot:dispose();self.shot=nil end
        self.ready=false;self.key=nil;self.owner=nil
    end
    function st:draw()
        render.setCullMode(render.CullMode.None)
        render.setBlendMode(render.BlendMode.Opaque)
        render.setDepthMode(render.DepthMode.Normal)
        for _,e in ipairs(self.items) do
            self.params=self.params or {transform='original',async=false,shader=[[
                float4 main(PS_IN pin) {
                    // Native INT reverses the FX normal: retain exterior faces
                    // only. An inside camera must still see the custom optics.
                    clip(dot(pin.NormalW,-pin.PosC)-1e-7);
                    return float4(length(pin.PosC),0,0,1);
                }
            ]]}
            self.params.mesh=e.targetMesh
            if render.mesh(self.params)==false then error('Native glass depth pending') end
        end
    end
    function st:update(w,h)
        local owner=d.owner()
        if not owner then self:dispose();return true end
        self.items={};local visibility={}
        for _,name in ipairs(self.names) do
            local e=d.editor(name)
            local visible=e and e.visible~=false and e.targetMesh and #e.targetMesh>0 and e.targetMesh:isVisible(1)
            visibility[#visibility+1]=visible and name or '-'
            if visible then self.items[#self.items+1]=e end
        end
        if #self.items==0 then self.ready=false;self.key=nil;return true end
        local sim=ac.getSim()
        local eye,look,up
        if d.localFrame then eye,look,up=d.localFrame() end
        if not eye then
            local inverse=owner:getWorldTransformationRaw():inverse()
            eye=inverse:transformPoint(sim.cameraPosition)
            look=inverse:transformVector(sim.cameraLook)
            up=inverse:transformVector(sim.cameraUp)
        end
        local parts={w,h,sim.cameraFOV,table.concat(visibility,':')}
        for _,v in ipairs({eye,look,up}) do
            parts[#parts+1]=string.format('%.8f,%.8f,%.8f',v.x,v.y,v.z)
        end
        local key=table.concat(parts,':')
        if owner==self.owner and key==self.key and self.ready then return true end
        self.ready=false
        if not self.shot or self.w~=w or self.h~=h or self.owner~=owner then
            self:dispose();self.owner=owner;self.w,self.h=w,h
            self.shot=ac.GeometryShot({opaque=function() self:draw() end},vec2(w,h),1,true,
                render.AntialiasingMode.None,render.TextureFormat.R32.Float)
            self.shot:setName('Native exterior glass metric occlusion')
            self.shot:setSky(false);self.shot:setParticles(false)
            self.shot:setClearColor(rgbm(0,0,0,0));self.shot:setClippingPlanes(.001,10)
        end
        local ok,err=pcall(function()
            if self.shot:update(sim.cameraPosition,sim.cameraLook,sim.cameraUp,sim.cameraFOV)==false then
                error('Native glass capture pending')
            end
        end)
        render.setCullMode(render.CullMode.None)
        render.setBlendMode(render.BlendMode.BlendPremultiplied)
        render.setDepthMode(render.DepthMode.ReadOnly)
        self.error=not ok and tostring(err) or nil
        if not ok then return false end
        self.ready=true;self.key=key;self.updates=self.updates+1
        return true
    end
    function st:bind(p,prefix,enabled)
        p.textures['tx'..prefix..'NativeDepth']=enabled and self.ready and self.shot or false
        p.values['g'..prefix..'NativeOn']=enabled and self.ready and 1 or 0
        local target=render.getRenderTargetSize()
        p.values['g'..prefix..'NativePixelScale']=vec2((self.w or 1)/math.max(target.x,1),
            (self.h or 1)/math.max(target.y,1))
    end
    return st
end
