-- P2 supply/impact preparation. Diagnostic only until GPU event commit is bound.
-- DSD is an estimated airborne NUMBER distribution, never a display profile.
return function()
    local pi,exp,log,sqrt=math.pi,math.exp,math.log,math.sqrt
    local st={bins={},weights={1,0,0,0},updates=0,confidence='estimated',
        rateMMH=0,numberDensityM3=0,meanDiameterMM=0,meanVolumeMM3=0,
        meanVolumeTerminalMM3MS=0,frame=nil}
    local function finite(x) return type(x)=='number' and x==x and x>-math.huge and x<math.huge end
    local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
    local function smooth(a,b,x) local t=clamp((x-a)/(b-a),0,1);return t*t*(3-2*t) end
    -- Symmetric triangular density in log D, with three seed-specific groups.
    -- The user's representative diameters are targets for later calibration,
    -- not assertions of the number means produced by these provisional seeds.
    local seeds={
        {edges={.1,.3,.5,.5},p={.90,.10,0}},
        {edges={.5,1.2,2.5,4.5},p={.65,.30,.05}},
        {edges={.5,1.4,3.0,6.3},p={.55,.35,.10}},
        {edges={.3,1.1,2.4,4.0},p={.75,.23,.02}}}
    local function triangularCDF(d,a,b)
        if b<=a then return d>=b and 1 or 0 end
        local t=clamp(log(d/a)/log(b/a),0,1)
        return t<=.5 and 2*t*t or 1-2*(1-t)*(1-t)
    end
    local function seedCDF(seed,d)
        local result=0
        for j=1,3 do if seed.p[j]>0 then
            result=result+seed.p[j]*triangularCDF(d,seed.edges[j],seed.edges[j+1])
        end end
        return result
    end
    function st.terminalMS(diameterMM)
        -- Frisch/Atlas piecewise approximation; avoids negative Atlas speeds
        -- at drizzle sizes. D is mm; speed is m/s at reference near-ground air.
        local d=math.max(diameterMM,0)
        if d<.11 then return 30*d*d end
        if d<=.86 then return 4.1665*d-.0833 end
        return math.max(0,9.65-10.3*exp(-.6*d))
    end
    local edges={}
    for i=0,128 do edges[i+1]=.1*exp(log(63)*i/128) end
    -- Snap grid boundaries to every seed support/group endpoint. A bin midpoint
    -- must not create diameters outside that seed's declared physical range.
    for _,d in ipairs({.1,.3,.5,1.1,1.2,1.4,2.4,2.5,3,4,4.5,6.3}) do
        edges[math.floor(log(d/.1)/log(63)*128+.5)+1]=d
    end
    for i=1,128 do
        local lo,hi=edges[i],edges[i+1]
        local d=sqrt(lo*hi);local v=pi*d^3/6
        local bin={low=lo,high=hi,diameter=d,volume=v,terminal=st.terminalMS(d),p={}}
        for j=1,4 do bin.p[j]=math.max(0,seedCDF(seeds[j],hi)-seedCDF(seeds[j],lo)) end
        st.bins[i]=bin
    end
    -- Cached seed moments: no 128-bin rebuild/loop in the frame update.
    local moments={}
    for j=1,4 do
        local m={d=0,v=0,vt=0,n=0}
        for i=1,128 do local b=st.bins[i];local p=b.p[j]
            m.n=m.n+p;m.d=m.d+p*b.diameter;m.v=m.v+p*b.volume;m.vt=m.vt+p*b.volume*b.terminal
        end
        assert(math.abs(m.n-1)<1e-9);moments[j]=m
    end
    function st:update(e,rateAtOne,power,overrideSeed)
        if self.frame==e.frame and self.lastRate==rateAtOne and self.lastPower==power
            and self.lastOverride==overrideSeed then return self end
        self.frame=e.frame;self.lastRate=rateAtOne;self.lastPower=power;self.lastOverride=overrideSeed
        self.updates=self.updates+1
        local i=clamp(e.liquidIntensity or 0,0,1)
        local ambient=sqrt((e.windX or 0)^2+(e.windY or 0)^2+(e.windZ or 0)^2)
        local q,c,b=smooth(.015,.15,i),smooth(.12,.60,i),smooth(12,30,ambient)
        self.weights[1]=1-q;self.weights[2]=q*(1-c);self.weights[3]=q*c*(1-b);self.weights[4]=q*c*b
        local seed=finite(overrideSeed) and math.floor(overrideSeed+.5) or 0
        if seed>=1 and seed<=4 then for j=1,4 do self.weights[j]=j==seed and 1 or 0 end end
        self.overrideSeed=seed>=1 and seed<=4 and seed or 0
        self.meanDiameterMM=0;self.meanVolumeMM3=0;self.meanVolumeTerminalMM3MS=0
        for j=1,4 do local w=self.weights[j];local m=moments[j]
            self.meanDiameterMM=self.meanDiameterMM+w*m.d
            self.meanVolumeMM3=self.meanVolumeMM3+w*m.v
            self.meanVolumeTerminalMM3MS=self.meanVolumeTerminalMM3MS+w*m.vt
        end
        local r=finite(rateAtOne) and math.max(rateAtOne,0) or 0
        local p=finite(power) and clamp(power,.1,4) or 1
        self.rateMMH=r*i^p
        self.verticalFluxMS=self.rateMMH/3600000
        self.numberDensityM3=self.verticalFluxMS/math.max(self.meanVolumeTerminalMM3MS*1e-9,1e-30)
        self.supercooled=(e.temperatureC or 20)<.01
        self.airX=e.airX or 0;self.airY=e.airY or 0;self.airZ=e.airZ or 0
        return self
    end
    function st:probability(index)
        local b=self.bins[index];local p=0
        for j=1,4 do p=p+self.weights[j]*b.p[j] end
        return p
    end
    local function normal(nx,ny,nz)
        if not finite(nx) or not finite(ny) or not finite(nz) then return nil end
        local length=sqrt(nx*nx+ny*ny+nz*nz)
        if length<1e-12 then return nil end
        return nx/length,ny/length,nz/length
    end
    function st:encounter(nx,ny,nz,exposure,out)
        -- Per-unit-area reference, not the visor area or an actual source event.
        -- A 128-bin loop only for explicit diagnostics / future slow LUT refresh.
        out=out or {};nx,ny,nz=normal(nx,ny,nz)
        out.valid=nx~=nil;out.numberM2S=0;out.volumeMM3M2S=0;out.meanDiameterMM=0
        if not nx then return out end
        local shield=clamp(exposure or 1,0,1)
        for i=1,128 do local b=self.bins[i]
            local vn=math.max(0,-(self.airX*nx+(self.airY-b.terminal)*ny+self.airZ*nz))
            local arrival=self.numberDensityM3*self:probability(i)*vn*shield
            out.numberM2S=out.numberM2S+arrival
            out.volumeMM3M2S=out.volumeMM3M2S+arrival*b.volume
            out.meanDiameterMM=out.meanDiameterMM+arrival*b.diameter
        end
        out.meanDiameterMM=out.meanDiameterMM/math.max(out.numberM2S,1e-30)
        return out
    end
    function st:sample(u,nx,ny,nz)
        -- Number CDF or encounter-weighted number CDF; distinct from volume CDF.
        u=clamp(u,0,1-1e-12)
        local total=0;local oriented=nx~=nil
        if oriented then nx,ny,nz=normal(nx,ny,nz);if not nx then return nil end end
        local function weight(i)
            local p=self:probability(i)
            if oriented then local b=self.bins[i]
                p=p*math.max(0,-(self.airX*nx+(self.airY-b.terminal)*ny+self.airZ*nz))
            end
            return p
        end
        for i=1,128 do total=total+weight(i) end
        if total<=1e-30 then return nil end
        local target=u*total;local sum=0
        for i=1,128 do local w=weight(i)
            if w>0 and target<sum+w then return self.bins[i].diameter,i end
            sum=sum+w
        end
        return nil
    end
    function st.impact(d,nx,ny,nz,airX,airY,airZ,rho,mu,gamma,out)
        out=out or {};nx,ny,nz=normal(nx,ny,nz)
        out.valid=nx~=nil and finite(d) and d>0 and finite(rho) and rho>0
            and finite(mu) and mu>0 and finite(gamma) and gamma>0
            and finite(airX) and finite(airY) and finite(airZ)
        if not out.valid then return out end
        local x,y,z=airX,airY-st.terminalMS(d),airZ
        local dot=x*nx+y*ny+z*nz;local vn=math.max(0,-dot);local dm=d*.001
        out.normalMS=vn;out.tangentX=x-dot*nx;out.tangentY=y-dot*ny;out.tangentZ=z-dot*nz
        out.volumeMM3=pi*d^3/6;out.massKG=rho*out.volumeMM3*1e-9
        out.weber=rho*vn*vn*dm/gamma;out.reynolds=rho*vn*dm/mu
        out.ohnesorge=mu/sqrt(rho*gamma*dm)
        out.incident=vn>0
        return out
    end
    function st.partition(impact,attached,film,micro,outflow,tangentFraction,out)
        -- Conservative initializer for explicitly supplied material LUT fractions.
        -- No global We threshold or invented empirical splash law is implied.
        out=out or {};out.valid=false
        if not impact.valid or not impact.incident then return out end
        if not finite(attached) or not finite(film) or not finite(micro) or not finite(outflow)
            or math.min(attached,film,micro,outflow)<0 or math.abs(attached+film+micro+outflow-1)>1e-9
            or not finite(tangentFraction) or tangentFraction<0 or tangentFraction>1 then return out end
        local v=impact.volumeMM3
        out.attachedMM3=v*attached;out.filmMM3=v*film;out.microMM3=v*micro;out.outflowMM3=v*outflow
        -- Fraction <=1 guarantees attached momentum never exceeds its incoming share.
        out.velocityX=impact.tangentX*tangentFraction;out.velocityY=impact.tangentY*tangentFraction
        out.velocityZ=impact.tangentZ*tangentFraction
        out.valid=true;return out
    end
    return st
end
