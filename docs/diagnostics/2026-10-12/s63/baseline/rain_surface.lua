-- Static KN5 geometry contract. CPU samples only drop positions; no per-frame
-- atlas transfer. DDS bytes remain alive while FFI reads their float payload.
return function(folder,runtime)
    local st={root=folder..'/texture/RAIN_GEOMETRY/',ready=false,scale=1}
    local f=assert(io.open(folder..'/shaders/rainSurfaceMetric.hlsl','rb'))
    st.shader=f:read('*a');f:close()
    local function line(file) return (file:read('*l') or ''):gsub('\r$','') end
    function st:validate()
        if self.model==runtime.MODEL_PATH then return self.ready end
        self.model=runtime.MODEL_PATH;self.ready=false;self.status='Checking RainFX KN5/mask hashes'
        local f=io.open(self.root..'surface.verify','rb')
        if not f then self.status='Missing RainFX geometry bake';return false end
        local modelHash=line(f);local maskHash=line(f);local version=line(f);f:close()
        if version~='rain-surface-v2' then self.status='RainFX step limits missing: rebuild geometry';return false end
        for _,name in ipairs({'du.dds','dv.dds','position.dds','surface_bounds.lua','spawn_sites.dds'}) do
            local asset=io.open(self.root..name,'rb')
            if not asset then self.status='Missing RainFX bake: '..name;return false end
            asset:close()
        end
        local function stamps(path,expected,mask)
            local asset=io.open(path,'rb');if not asset then return false end
            local model,alpha=line(asset),line(asset);asset:close()
            return model==expected and (not mask or alpha==mask)
        end
        if not stamps(folder..'/texture/GLASS/FX/atlas.verify',modelHash)
            or not stamps(self.root..'spawn.verify',modelHash,maskHash) then
            self.status='FX atlas or physical birth sites stale: finish KN5 rebuild';return false
        end
        local current=self.model;local modelOK,maskOK=false,false
        local function done()
            if self.model==current then
                self.ready=modelOK and maskOK
                if self.ready then self.status='RainFX KN5 and alpha boundary verified' end
            end
        end
        io.checksumSHA256(folder..'/'..current,function(err,hash)
            if self.model~=current then return end
            modelOK=not err and hash==modelHash;done()
            if not self.ready then self.status=modelOK and 'Waiting for RainFX mask verification' or 'RainFX KN5 changed: rebuild geometry' end
        end)
        io.checksumSHA256(folder..'/texture/RAINFX_ObjNormal_BoundaryMask.dds',function(err,hash)
            if self.model~=current then return end
            maskOK=not err and hash==maskHash;done()
            if not maskOK then self.status='RainFX boundary mask changed: rebuild geometry' end
            if self.ready then self.status='RainFX KN5 and alpha boundary verified' end
        end)
        return self.ready
    end
    function st:unit()
        return .001/math.max(runtime.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM,1e-6)/math.max(self.scale,1e-6)
    end
    function st:microSearch(radius)
        -- Static geometry extrema, evaluated once. The stencil grows only
        -- when profile scale or the user radius needs more neighbouring cells.
        if not self.bounds then self.bounds=assert(loadfile(self.root..'surface_bounds.lua'))() end
        local k=radius*self:unit()
        return vec2(math.max(1,math.ceil(self.bounds[1]*k-.05)),
            math.max(1,math.ceil(self.bounds[2]*k-.05)))
    end
    function st:bind(p)
        p.textures.txRainDu=self.root..'du.dds';p.textures.txRainDv=self.root..'dv.dds'
        p.textures.txRainBoundaryMask=folder..'/texture/RAINFX_ObjNormal_BoundaryMask.dds'
        p.values.gRainMetersPerUnit=self:unit()
        p.values.gRainReferencePerMM=runtime.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM
    end
    local arrays={}
    local function tap(key,u,v)
        local data=arrays[key]
        if not data then
            local f=assert(io.open(st.root..key..'.dds','rb'));local bytes=f:read('*a');f:close()
            data={bytes=bytes,p=ffi.cast('const float*',ffi.cast('const char*',bytes)+148)};arrays[key]=data
        end
        local x=math.max(0,math.min(2047,math.floor(u*2048)))
        local y=math.max(0,math.min(511,math.floor((v+1)*512)));local i=(y*2048+x)*4
        return tonumber(data.p[i]),tonumber(data.p[i+1]),tonumber(data.p[i+2])
    end
    function st:metric(u,v)
        local x,y,z=tap('du',u,v);local X,Y,Z=tap('dv',u,v)
        local a=math.max(math.sqrt(x*x+y*y+z*z),1e-9)
        local b=(x*X+y*Y+z*Z)/a;local c=math.sqrt(math.max(X*X+Y*Y+Z*Z-b*b,1e-18))
        return a,b,c,self:unit()
    end
    function st:plane(u,v,dx,dy)
        local a,b,c,k=self:metric(u,v);return (a*dx+b*dy)/k,c*dy/k
    end
    function st:offset(u,v,x,y)
        local a,b,c,k=self:metric(u,v);local dy=y*k/c;return (x*k-b*dy)/a,dy
    end
    function st:length(u,v,dx,dy) local x,y=self:plane(u,v,dx,dy);return math.sqrt(x*x+y*y) end
    function st:velocity(u,v,du,dv)
        local x,y,z=tap('du',u,v);local X,Y,Z=tap('dv',u,v)
        return x*du+X*dv,y*du+Y*dv,z*du+Z*dv
    end
    function st:point(u,v)
        -- Bilinear positions retain sub-texel separation for CPU merges.
        -- Jacobians remain discrete; unrelated island bases never blend.
        tap('position',u,v)
        local data=arrays.position.p
        local fx,fy=u*2048-.5,(v+1)*512-.5
        local x,y=math.floor(fx),math.floor(fy);fx,fy=fx-x,fy-y
        local X,Y,Z=0,0,0
        for dy=0,1 do for dx=0,1 do
            local i=(math.max(0,math.min(511,y+dy))*2048+math.max(0,math.min(2047,x+dx)))*4
            local w=(dx==0 and 1-fx or fx)*(dy==0 and 1-fy or fy)
            X=X+tonumber(data[i])*w;Y=Y+tonumber(data[i+1])*w;Z=Z+tonumber(data[i+2])*w
        end end
        local k=self:unit();return X/k,Y/k,Z/k
    end
    function st:shift(cx,cy,x,y,size)
        local dx,dy=self:offset(cx/size,cy/size-1,x/size,y/size)
        return cx+dx*size,cy+dy*size
    end
    function st:ribbon(q1,q2,q3,q4,x0,y0,x1,y1,halfWidth,ux,uy,size)
        local dx,dy=self:offset(x0/size,y0/size-1,-uy*halfWidth/size,ux*halfWidth/size)
        local X,Y=self:offset(x1/size,y1/size-1,-uy*halfWidth/size,ux*halfWidth/size)
        q1:set(x0-dx*size,y0-dy*size);q2:set(x1-X*size,y1-Y*size)
        q3:set(x1+X*size,y1+Y*size);q4:set(x0+dx*size,y0+dy*size)
    end
    function st:stroke(x0,y0,x1,y1,width,color,size)
        local px,py=self:plane(x1/size,y1/size-1,(x1-x0)/size,(y1-y0)/size)
        local len=math.sqrt(px*px+py*py);local ux,uy=1,0
        if len>1e-9 then ux,uy=px/len,py/len end
        self.strokeQuad=self.strokeQuad or {vec2(),vec2(),vec2(),vec2()}
        local q1,q2,q3,q4=unpack(self.strokeQuad)
        self:ribbon(q1,q2,q3,q4,x0,y0,x1,y1,width*.5,ux,uy,size)
        ui.drawQuadFilled(q1,q2,q3,q4,color)
        self:quad(q1,q2,q3,q4,x0,y0,width*.5,width*.5,1,0,size)
        ui.drawImageQuad(self.strokeCircle,q1,q2,q3,q4,color)
        self:quad(q1,q2,q3,q4,x1,y1,width*.5,width*.5,1,0,size)
        ui.drawImageQuad(self.strokeCircle,q1,q2,q3,q4,color)
    end
    -- A physical kernel quad in the virtual square UI coordinate system. The
    -- atlas backing this UI can be rectangular via a final resample.
    function st:quad(q1,q2,q3,q4,cx,cy,ax,ay,ux,uy,size)
        local u,v=cx/size,cy/size-1
        local x,y=self:offset(u,v,ux*ax/size,uy*ax/size)
        local X,Y=self:offset(u,v,-uy*ay/size,ux*ay/size)
        x,y,X,Y=x*size,y*size,X*size,Y*size
        q1:set(cx-x-X,cy-y-Y);q2:set(cx+x-X,cy+y-Y)
        q3:set(cx+x+X,cy+y+Y);q4:set(cx-x+X,cy-y+Y)
    end
    function st:updateAtlas(canvas,size,draw)
        if not self.strokeCircle then
            self.strokeCircle=ui.ExtraCanvas(vec2(64,64),1,render.AntialiasingMode.None,render.TextureFormat.R8G8B8A8.UNorm)
            self.strokeCircle:clear(rgbm(0,0,0,0))
            self.strokeCircle:update(function() ui.drawCircleFilled(vec2(32,32),32,rgbm(1,1,1,1),32) end)
        end
        canvas:update(function()
            -- Virtual coordinates retain existing width-based radius codes.
            -- Transform once at draw submission; GPU backing is W × W/4.
            ui.pushClipRect(vec2(),vec2(size,size),false)
            ui.beginScale();draw();ui.endPivotScale(vec2(1,.25),vec2());ui.popClipRect()
        end)
    end
    return st
end
