-- RainFX v2 physics (rev7): drop dynamics inputs, parameters and diagnostics, kept
-- separate from optics/appearance so the physics can be reviewed and tested on its own.
-- The GPU side is r2DropVelocity / r2Predict in shaders/common.hlsl; every formula
-- here mirrors it 1:1 (keep in sync). Units: SI unless the name says MM.
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
  friction = 0.06,          -- N s/m^2 = c * viscosity (c ~ 20..60 for sliding caps)
  dragCd = 1.0, rhoAir = 1.2,
  -- rev13: 0.35 streamed every drop >= 0.2 mm off the visor at 250 km/h (drop cover 1.5 %
  -- in all T3/T4 runs); reference B shows mostly static soft drops at speed (helmet behind
  -- screen/halo). 0.15: <= 0.3 mm stay, 0.5 mm creep, >= 1 mm stream/shed.
  airSurface = 0.15,        -- tangential air speed at the visor / free-stream relative air
  vMax = 1.5,               -- m/s, cap of the quasi-steady speed
  vShed = 3.0,              -- m/s, faster drops leave the surface (shed) instead of moving
  -- losses
  -- rev9: 0.02 removed ~2%/mm from a 0.5 mm drop (half its volume across the visor),
  -- drops shrank below the kinetic threshold and stopped mid-way. Hydrophobic coat: ~0.25.
  trailLoss = 0.005, evap = 1e-4, minRadiusMM = 0.08, maxRadiusMM = 2.2,
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
  filmRainK = 0.8,          -- rev15: 0.7 left Heavy Rain/Hurricane T3 at 43-48 % (target > 50 %)
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
  local accel = vec3(0, -9.81, 0)
  if car and car.acceleration and car.side then
    local a = car.acceleration
    accel = accel - (car.side * a.x + car.up * a.y + car.look * a.z) * 9.81
  end
  local wk = sim.windVelocityKmh or vec2()
  local wind = vec3(wk.x, 0, wk.y) / 3.6
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
  return math.min((F - Fpin) / (p.friction * rMM * 1e-3), p.vMax)
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
