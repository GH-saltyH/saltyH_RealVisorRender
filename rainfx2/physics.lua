-- RainFX v2 physics (rev7): drop dynamics inputs, parameters and diagnostics, kept
-- separate from optics/appearance so the physics can be reviewed and tested on its own.
-- The GPU side is r2DropVelocity / r2Predict in shaders/common.hlsl; every formula
-- here mirrors it 1:1 (keep in sync). Units: SI unless the name says MM.
-- rev40: the GPU adds random stagnation gusts (common.hlsl r2TurbAir) to the air; not mirrored here
-- (random by design), init.lua physicsUI shows their peak speed and the radius they depin alone.
-- Review and sources: docs/RAINFX_V2_CORE.md section 14.

local P = {}

-- Defaults (merged into the core parameter table by init.lua).
P.DEFAULTS = {
  shapeK = 2.0944,          -- V / r^3 (mm^3/mm^3): hemispherical cap, contact angle ~90 deg
  -- contact-angle hysteresis: Fpin = gamma * 2r * dcos * noise (Furmidge)
  surfaceTension = 0.072,   -- N/m, water
  pinCoat = 0.18,           -- dcos on the hydrophobic coat (visor exterior)
  pinGlass = 0.35,          -- dcos on bare polycarbonate
  pinNoiseMin = 0.6, pinNoiseMax = 1.4,   -- per-cell heterogeneity (stick-slip)
  pinKinetic = 0.6,         -- hysteresis of a moving drop / static (rev8, no permanent traps)
  -- motion: quasi-steady sliding, v = (F - Fpin) / (friction * r)
  -- rev19 (rev18 Debug 4: the right third ran into the solver limit at 1x): 0.06 slid a 2.2 mm
  -- drop at 1.4 m/s under gravity alone, i.e. capillary number Ca = mu v / gamma = 0.019, above
  -- the pearling/rivulet transition of sliding drops (Ca ~ 0.005-0.01, Podgorski, Flesselles &
  -- Limat 2001; Le Grand, Daerr & Limat 2005). Contact-line dissipation for a ~90 deg cap is
  -- F ~ (3 mu ln(L/a) / theta) * 4r * v ~ 0.1..0.15 * r * v (ln ~ 10..15).
  friction = 0.15,          -- N s/m^2 (gravity only: 1.2 mm 0.09, 1.6 mm 0.25, 2.2 mm 0.5 m/s)
  dragCd = 1.0, rhoAir = 1.2,
  -- rev13: 0.35 streamed every drop >= 0.2 mm off the visor at 250 km/h (drop cover 1.5 %
  -- in all T3/T4 runs); reference B shows mostly static soft drops at speed (helmet behind
  -- screen/halo). 0.15: <= 0.3 mm stay, 0.5 mm creep, >= 1 mm stream/shed.
  airSurface = 0.15,        -- tangential air speed at the visor / free-stream relative air
  -- rev41 (rev40 review: drops crossed the visor in 'lightning' paths at 100-300 km/h;
  -- docs/tools/rainfx2_airflow_sim.py): 0.5 / 1.2 let 0.4-1.5 mm drops slide 0.2-0.7 m over 2 s.
  -- With 0.30 / 0.45 they creep or are blown off within 0.01-0.3 s after 1-30 mm (short trails).
  -- rev42 (rev41 recording): 1 mm on the visor is ~30 px, 0.3 m/s ~150 px per frame -> jumps. Moving
  -- drops now creep (speed saturates smoothly at vMax); drops whose AIR drag exceeds shedK x pinning are
  -- blown off at once (no visible run across the visor).
  vMax = 0.08,              -- m/s, rev19 0.5, rev41 0.30, rev42 0.03 tanh, rev43 0.08 graded:
  vScale = 0.25,            -- v = vMax (1 - exp(-vq / vScale)), vq = quasi-steady speed
  shedK = 2.0,              -- blown off when air drag > shedK x pinning force
  airDown = 0.0,            -- rev42-46 observed-flow fix (0.8); rev47 0: replaced by the stagnation elevation
  -- rev47 helmet aerodynamics (P.aeroForces): effective free stream at the helmet (cockpit / screen
  -- shielding), helmet radius, stagnation point elevation above the visor centre (deg, + = above ->
  -- flow over the visor runs down and out), buffeting wander of the stagnation point (deg at 250 km/h)
  aeroKU = 0.35, helmetR = 0.13,   -- rev47c 0.6 -> 0.35 (observed persistence, REV47B_REVIEW)
  stagElevDeg = 35.0, buffetDeg = 4.0, buffetHz = 1.5,   -- rev47b 8/3 -> 4/1.5; rev48-M1 stagnation 12 -> 35 deg (MOTION_REVIEW s7)
  -- rev47b runback: drops blown loose slide with the air (speed runbackK x air at the drop top, between
  -- vMax and runbackMax), lift off only above liftMM; sliding inertia slideTau; impact splash share
  -- rev47c (REV47B_REVIEW: 0.5 m/s = ~250 px per frame at the visor scale; references show visible flow of a
  -- few cm/s): runbackK 0.03 -> 0.003, runbackMax 0.5 -> 0.06, slideTau 0.1 -> 0.15, impactLoss 0.3 -> 0.15
  runbackK = 0.003, runbackMax = 0.06, liftMM = 1.5, slideTau = 0.15, impactLoss = 0.15,
  -- rev47 drop inertia (s): a drop's speed relaxes to the force-driven target over dropTau (contact-line
  -- relaxation); acceleration low-pass of the helmet (neck), cut-off Hz and damping
  dropTau = 0.04, neckHz = 3.0, neckZeta = 0.7, headAccK = 1.0, headAccMaxG = 2.0,
  -- shed test uses the UNCAPPED quasi-steady speed: 3.0 at friction 0.06 = 1.2 at 0.15 (same force,
  -- airflow shedding at speed unchanged)
  vShed = 1.0,              -- m/s, rev42: only the shed sentinel (speed 1e3) is above it
  -- losses
  -- rev9: 0.02 removed ~2%/mm from a 0.5 mm drop (half its volume across the visor),
  -- drops shrank below the kinetic threshold and stopped mid-way. Hydrophobic coat: ~0.25.
  trailLoss = 0.005, evap = 1e-4,
  minRadiusMM = 0.04, maxRadiusMM = 1.5,   -- rev41: 0.08 / 2.2 (rev40 review: many more small drops, max much smaller)
  pinMM = 4.0,              -- rev41: pinning heterogeneity feature size (smooth field, was white noise per cell)
  coalesceK = 1.0,
  windK = 1.0,              -- ambient wind reaching the visor (CSP wind ignores pits/cockpit shelter)
  -- water film W (rev11): lubrication-theory film, see P.filmVelocity
  filmCf = 0.005,           -- skin-friction coefficient of the air over the film
  filmFlowK = 1.0,          -- gain on the film velocity
  filmDiffuse = 0.6,        -- surface-tension smoothing per frame (5-tap blend)
  filmMaxMM = 0.5,          -- W = 1 thickness
  sprayFluxMMs = 0.5,       -- film supply (mm/s) at spray estimate 1 (following closely, flooded)
  sprayDiamMM = 0.25,       -- spray droplet diameter (many small splashes)
  -- rev14 (rev13 review): 0.35 left Heavy Rain at 250 km/h with no film (eq 0.068 mm < 0.05-0.15 window)
  -- rev21: 0.8 x 0.59 / 0.88 -- the R-size rule leaves more rain unresolved at speed (Heavy Rain
  -- T3: 0.88 vs 0.59 of the volume), so the share is rescaled to keep the rev15 film calibration.
  filmRainK = 0.54,         -- rev15: 0.8 (0.7 left Heavy Rain/Hurricane T3 at 43-48 %, target > 50 %)
                            -- share of non-sticking rain that joins the film (rest: micro haze)
  sprayHaze = 0.4,          -- micro haze rate (1/s) at spray estimate 1
  -- solver
  maxSubsteps = 4,          -- automatic substeps never exceed this
  gatherCells = 1.95,       -- max displacement per substep (5x5 gather window)
}

-- World-space inputs from the sim. car.acceleration is car-local G (x side, y up,
-- z look); a drop on the car feels gravity minus the car acceleration.
function P.inputs(sim, p, out)
  out = out or {}
  local car = ac.getCar(sim.focusedCar >= 0 and sim.focusedCar or 0) or ac.getCar(0)
  local carVel = car and car.velocity or vec3()
  -- rev47: the car part of the acceleration (m/s^2, world) is returned separately; init.lua adds the
  -- head (visor) motion, low-pass filters it like the neck does and forms accelW = gravity - filtered.
  local carAcc = vec3()
  if car and car.acceleration and car.side then
    local a = car.acceleration
    carAcc = (car.side * a.x + car.up * a.y + car.look * a.z) * 9.81
  end
  local accel = vec3(0, -9.81, 0) - carAcc
  out.carAccW = carAcc
  -- rev48 wind source (rev47l / S1 reviews: in a REPLAY whose weather a controller overrides, the visor
  -- exposure ignored the wind direction). sim.windVelocityKmh (game-space vector) is the live source; in
  -- replays it keeps the recorded wind, while the controller override reaches the conditions set
  -- (ac.overrideReplayConditions -> sim.weatherConditions.wind: real-world compass direction, km/h).
  -- Compass -> game space: ac.getCompassAngle gives the track orientation; the convention offset (from /
  -- to, handedness of the track) is CALIBRATED live from windDirectionDeg vs the game-space vector and kept
  -- in p.windDirOffsetDeg (init.lua stores it), default 180 (meteorological 'from').
  local wk = sim.windVelocityKmh or vec2()
  local wind = vec3(wk.x, 0, wk.y) / 3.6
  local wkLen = math.sqrt(wk.x * wk.x + wk.y * wk.y)
  local wsKmh = sim.windSpeedKmh or 0
  out.windSource = 'windVelocityKmh'
  out.windCalibrated = nil
  local compass = ac and ac.getCompassAngle
  local function fromCompass(deg)
    local cz = compass(vec3(0, 0, 1)) or 0
    local cx = compass(vec3(1, 0, 0)) or 90
    local hand = ((cx - cz) % 360) < 180 and 1 or -1
    local d = math.rad(deg - cz)
    return vec3(hand * math.sin(d), 0, math.cos(d))
  end
  local live = not sim.isReplayActive
  if compass and live and wkLen > 2 and sim.windDirectionDeg then
    -- calibrate: compass angle of the actual game-space wind minus the reported direction
    local off = ((compass(vec3(wk.x, 0, wk.y)) or 0) - sim.windDirectionDeg) % 360
    local prev = p.windDirOffsetDeg or off
    local dd = ((off - prev + 540) % 360) - 180
    p.windDirOffsetDeg = (prev + 0.1 * dd) % 360
    out.windCalibrated = p.windDirOffsetDeg
  end
  local cond = sim.weatherConditions
  local cw = cond and cond.wind
  if compass and not live and cw then
    local kmh = 0.5 * ((cw.speedFrom or 0) + (cw.speedTo or cw.speedFrom or 0))
    wind = fromCompass((cw.direction or 0) + (p.windDirOffsetDeg or 180)) * (kmh / 3.6)
    out.windSource = string.format('replay conditions %.0f deg %.0f km/h', cw.direction or 0, kmh)
  elseif compass and wsKmh > 1 and wkLen < 0.2 * wsKmh then
    wind = fromCompass((sim.windDirectionDeg or 0) + (p.windDirOffsetDeg or 180)) * (wsKmh / 3.6)
    out.windSource = string.format('windDirectionDeg %.0f (fallback)', sim.windDirectionDeg or 0)
  end
  local air = wind * (p.windK or 1) - carVel
  local rainVel = vec3(0, -p.terminalSpeed, 0) + air
  out.accelW, out.airW = accel, air
  out.rainVel = rainVel
  out.speedRel = rainVel:length()
  -- breakdown for the review UI
  out.carSpeed = carVel:length()
  out.windSpeed = wind:length()
  out.windSpeedSim = (sim.windSpeedKmh or 0) / 3.6
  out.airSpeed = air:length()
  out.accelG = accel:length() / 9.81
  return out
end

-- rev47 helmet aerodynamics (docs/RAINFX_V2_REV46_REVIEW.md section 3, docs/tools/rainfx2_helmet_aero.py):
-- helmet ~ sphere R_h; outer flow u_e = 1.5 kU U sin(theta) away from the stagnation point; laminar
-- stagnation boundary layer delta = 2.4 sqrt(nu / a), a = 1.5 kU U / R_h; the drop top (0.6 r) sees
-- u_e f(0.6 r / delta), f = x (2 - x) below 1; pressure gradient V rho u_e du_e/ds pushes outward.
-- Mirrored by common.hlsl r2DropVelocity.
P.NU_AIR = 1.5e-5
function P.aeroScales(p, U)
  local ue = 1.5 * p.aeroKU * U
  local a = ue / math.max(p.helmetR, 0.02)
  local delta = a > 1e-3 and 2.4 * math.sqrt(P.NU_AIR / a) * 1000 or 50
  return ue, a, math.min(delta, 50)
end
function P.aeroForces(p, rMM, U, thetaRad, pinCos)
  local r = rMM * 1e-3
  local ue0, a, delta = P.aeroScales(p, U)
  local ue = ue0 * math.sin(thetaRad)
  local x = 0.6 * rMM / delta
  local uh = ue * (x < 1 and x * (2 - x) or 1)
  local Fd = 0.25 * p.rhoAir * p.dragCd * math.pi * r * r * uh * uh
  local Fp = p.shapeK * rMM * rMM * rMM * 1e-9 * p.rhoAir * ue * a * math.cos(thetaRad)
  return Fd + Fp, p.surfaceTension * 2 * r * pinCos
end
-- Smallest radius (mm) swept by the air alone at angle theta from the stagnation point.
function P.aeroCritical(p, U, thetaRad, pinCos)
  local lo, hi = 0.01, 5.0
  local function moves(rr) local F, Fp = P.aeroForces(p, rr, U, thetaRad, pinCos); return F > (p.shedK or 2) * Fp end
  if not moves(hi) then return math.huge end
  if moves(lo) then return lo end
  for _ = 1, 40 do
    local m = 0.5 * (lo + hi)
    if moves(m) then hi = m else lo = m end
  end
  return hi
end

-- Forces for one drop radius (mm) on a surface whose tangential gravity and air
-- are the full magnitudes (worst case, = vertical surface facing the air stream).
function P.forces(p, rMM, gTan, airTan, pinCos, noise)
  local r = rMM * 1e-3
  local mass = 1e-6 * p.shapeK * rMM * rMM * rMM
  local Fg = mass * gTan
  local u = airTan * p.airSurface
  local Fa = 0.25 * p.rhoAir * p.dragCd * math.pi * r * r * u * u
  local Fpin = p.surfaceTension * 2 * r * pinCos * (noise or 1)
  return Fg, Fa, Fpin
end

-- Quasi-steady speed (m/s) with the forces aligned (upper bound).
function P.speed(p, rMM, gTan, airTan, pinCos)
  local Fg, Fa, Fpin = P.forces(p, rMM, gTan, airTan, pinCos)
  local F = Fg + Fa
  if F <= Fpin then return 0 end
  if Fa > (p.shedK or 1e9) * Fpin then return rMM > (p.liftMM or 1e9) and math.huge or (p.runbackMax or p.vMax) end   -- rev47b runback
  local vq = (F - Fpin) / (p.friction * rMM * 1e-3)
  return p.vMax * (1 - math.exp(-vq / p.vScale))
end

-- Smallest radius (mm) that moves, by bisection on F(r) - Fpin(r) (monotone in r).
function P.criticalRadius(p, gTan, airTan, pinCos)
  local lo, hi = 0.02, 6.0
  local function moves(r) local Fg, Fa, Fpin = P.forces(p, r, gTan, airTan, pinCos); return Fg + Fa > Fpin end
  if not moves(hi) then return math.huge end
  if moves(lo) then return lo end
  for _ = 1, 40 do
    local m = 0.5 * (lo + hi)
    if moves(m) then hi = m else lo = m end
  end
  return hi
end

-- Film mean velocity (m/s) for thickness hMM on a surface with full tangential g / air.
function P.filmVelocity(p, hMM, gTan, airTan)
  local h = hMM * 1e-3
  local u = airTan * p.airSurface
  local tau = 0.5 * p.rhoAir * p.filmCf * u * u
  return math.min((tau * h / 2e-3 + 1000 * gTan * h * h / 3e-3) * p.filmFlowK, 1.0)
end

-- Substeps so the fastest expected drop stays inside the gather window.
function P.substeps(p, dt, cellMM, userMin, vExpected)
  local need = math.ceil(math.min(vExpected, p.vShed) * dt * 1000 / (p.gatherCells * cellMM))
  return math.max(userMin, math.min(p.maxSubsteps, math.max(1, need)))
end

-- Diagnostics for the UI and the doc (no GPU readback; analytic for the current inputs).
function P.diagnose(p, inp, h, cellMM, out)
  out = out or {}
  local g = inp.accelG * 9.81
  local a = inp.airSpeed
  out.rcGravCoat = P.criticalRadius(p, g, 0, p.pinCoat)
  out.rcGravGlass = P.criticalRadius(p, g, 0, p.pinGlass)
  out.rcAllCoat = P.criticalRadius(p, g, a, p.pinCoat)
  out.rcGravCoatKin = P.criticalRadius(p, g, 0, p.pinCoat * p.pinKinetic)
  out.v05 = P.speed(p, 0.5, g, a, p.pinCoat)
  out.v10 = P.speed(p, 1.0, g, a, p.pinCoat)
  out.v20 = P.speed(p, 2.0, g, a, p.pinCoat)
  out.vGather = (h and h > 0) and p.gatherCells * cellMM * 1e-3 / h or 0
  -- film equilibrium at full exposure over a visor run of L = 0.1 m:
  -- supply * L = h * v(h) + drain * h * L   (outflow at the edge + drainage), bisection in h.
  local q = (p.filmRateMMs or 0) * 1e-3 * 0.1
  local lo, hi = 0, p.filmMaxMM
  for _ = 1, 30 do
    local m = 0.5 * (lo + hi)
    local out_ = m * 1e-3 * P.filmVelocity(p, m, g, a) + (p.sheetDrain or 0.5) * m * 1e-3 * 0.1
    if out_ > q then hi = m else lo = m end
  end
  out.filmEqMM = hi
  out.filmVel = P.filmVelocity(p, hi, g, a)
  return out
end

return P
