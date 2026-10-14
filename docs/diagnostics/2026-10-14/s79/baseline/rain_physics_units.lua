-- Physical units/geometry primitives. No display size/reference/Smear inputs.
-- These pure helpers do not replace the live legacy simulation in P0.
return function()
    local pi=math.pi
    local u={rhoWater=998.2,viscosity=.001002,surfaceTension=.0728,gravity=9.80665}
    local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
    local function positive(v) return finite(v) and v>0 end
    function u.volumeMM3(diameterMM)
        if not finite(diameterMM) or diameterMM<0 then return nil end
        return pi*diameterMM*diameterMM*diameterMM/6
    end
    function u.equivalentDiameterMM(volumeMM3)
        if not finite(volumeMM3) or volumeMM3<0 then return nil end
        return (6*volumeMM3/pi)^(1/3)
    end
    function u.massKG(volumeMM3,rho)
        if not finite(volumeMM3) or volumeMM3<0 or not positive(rho or u.rhoWater) then return nil end
        return volumeMM3*1e-9*(rho or u.rhoWater)
    end
    function u.contactRadiusMM(volumeMM3,thetaDeg)
        if not finite(volumeMM3) or volumeMM3<0 or not positive(thetaDeg) or thetaDeg>=180 then return nil end
        local t=math.tan(thetaDeg*pi/360)
        return (6*volumeMM3/(pi*t*(3+t*t)))^(1/3)
    end
    function u.capVolumeMM3(radiusMM,thetaDeg)
        if not finite(radiusMM) or radiusMM<0 or not positive(thetaDeg) or thetaDeg>=180 then return nil end
        local t=math.tan(thetaDeg*pi/360)
        return pi*radiusMM^3*t*(3+t*t)/6
    end
    function u.pinningN(widthMM,recedingDeg,advancingDeg,k,gamma)
        if not finite(widthMM) or widthMM<0 or not finite(recedingDeg) or not finite(advancingDeg)
            or recedingDeg<0 or advancingDeg>180 or recedingDeg>advancingDeg
            or not positive(k or 1) or not positive(gamma or u.surfaceTension) then return nil end
        return (k or 1)*(gamma or u.surfaceTension)*widthMM*.001
            *(math.cos(recedingDeg*pi/180)-math.cos(advancingDeg*pi/180))
    end
    function u.weber(diameterMM,normalSpeedMS,rho,gamma)
        if not finite(diameterMM) or diameterMM<0 or not finite(normalSpeedMS) or normalSpeedMS<0
            or not positive(rho or u.rhoWater) or not positive(gamma or u.surfaceTension) then return nil end
        return (rho or u.rhoWater)*normalSpeedMS^2*diameterMM*.001/(gamma or u.surfaceTension)
    end
    -- Local orthonormal plane from the baked Jacobian. a=|du|, b=dot(du/a,dv),
    -- c=|dv-b du/a|; metres per raw UV, multiplied only by physical model scale.
    local function metricOK(a,b,c,scale)
        return positive(a) and finite(b) and positive(c) and positive(scale)
    end
    function u.metricPlane(du,dv,a,b,c,scale)
        if not finite(du) or not finite(dv) or not metricOK(a,b,c,scale) then return nil end
        return (a*du+b*dv)*scale,c*dv*scale
    end
    function u.metricOffset(xM,yM,a,b,c,scale)
        if not finite(xM) or not finite(yM) or not metricOK(a,b,c,scale) then return nil end
        local dv=yM/(c*scale)
        return (xM/scale-b*dv)/a,dv
    end
    function u.metricCalibration(a,b,c,scale,width,height)
        if not metricOK(a,b,c,scale) or not positive(width) or not positive(height) then return nil end
        return width*.001/(a*scale),height*.001/(math.sqrt(b*b+c*c)*scale),
            a*c*scale*scale/(width*height)*1e6 -- physical cell area in mm2
    end
    return u
end
