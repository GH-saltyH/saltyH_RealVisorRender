-- RainFX v2 road spray reaching the visor (rev48-P2, docs/RAINFX_V2_DEPOSITION_MODEL.md sections 1.5 / 3).
-- CSP exposes no spray field: the liquid water content of the spray cloud at the helmet is estimated from the cars
-- ahead with the measured spray laws (Gaylard, Kirwan & Lockerby 2017 review; FHWA 2014 splash & spray report):
--   * spray needs road water: ~linear in the water film (Koppa) -> w = max(rainWater, rainWetness)
--   * almost none below ~50 km/h, then density ~ V^2.8 (Maycock 1966; ~V^3 Chatfield 1979)
--   * the cloud thins behind the car (e-folding sprayRangeM, Borg & Vevang 25 -> 50 m) and widens (plume)
--   * two parts: fine SPRAY (number mean 70-90 um, airborne, far) and ballistic SPLASH (1-4 mm tread drops, only
--     close behind: e-folding splashRangeM)
-- LWC0 (g/m^3 right behind a car at V0 on a flooded road) is calibrated to the visibility of a following driver
-- (tens of m: ~1-3 g/m^3 for 40 um effective radius) and to reference B / D (sheet within ~1 s when following).
-- Returns LWC (g/m^3) of fine spray at the helmet; out.splash = the near-field factor for the ballistic drops.
-- Pure Lua, one loop over the cars per frame, no allocations.

local S = {}

S.DEFAULTS = {
  sprayLWC0 = 3.0,          -- g/m^3 right behind a car at sprayV0 on a flooded road
  sprayV0 = 70.0,           -- m/s reference speed of the car ahead
  sprayExp = 2.8,           -- density ~ V^2.8 (Maycock)
  sprayVMin = 13.9,         -- m/s (50 km/h): below it a tyre throws (almost) no spray
  sprayRangeM = 25,         -- e-folding distance behind a car (fine spray)
  splashRangeM = 6,         -- e-folding distance of the ballistic tread drops
  sprayMaxM = 120,          -- ignore cars further ahead
  sprayWidthM = 1.5,        -- lateral gaussian half-width right behind the car (~tyre track) ...
  sprayWidenK = 0.08,       -- ... growing by this x the distance (plume)
  spraySelf = 0.002,        -- own front tyres (open wheel: low and backwards, little reaches the helmet)
  -- PUD-2 (docs/RAINFX_V2_PUDDLE_API.md): source = water at each car's own tyre contact (ac.StateWheel.waterThickness),
  -- not the track-global max(rainWater, rainWetness) (user test: wetness 0 / water 100 % -> a drying road, wheel water
  -- -> 0, while the global value kept the pack's spray at full). Water met by a tyre Q = h b V -> spray ~ h (Koppa:
  -- linear in the water film); hRef = the film on a fully wet road (user probe: wetness 100 % -> 1.75-1.87 mm).
  sprayWheelWater = true,   -- false: legacy global road water
  sprayHRefMM = 1.8,        -- wheel water that counts as 'flooded road' (the LWC0 calibration point)
  -- S2a (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 9): spray factor w(h) = (max(h - h0, 0) / (hRef - h0))^gamma. A thin film is
  -- taken up by the tread grooves and thrown little; spray grows faster once the water exceeds that. Calibrated with the
  -- deposition Monte Carlo (docs/tools/rainfx2_spray_mc.py) to the reference (wetness 10-15 %, wheel water ~0.75 mm, 0 -> 228
  -- km/h in ~5 s: dense 0.2-0.5 mm drops at the onset of flow) = x0.07-0.1 of the linear law there, flooded point unchanged.
  sprayH0MM = 0.7,          -- 2026-11-06 user: wheel spray less sensitive (0.6 -> 0.7: the 10 % wetness film 0.73-0.89 mm throws ~x0.4 less)
  sprayHGamma = 1.5,
  sprayHTau = 0.3,          -- s, a car's spray cloud follows its wheel water with this lag (cloud lifetime ~ range / V)
  splashSelfK = 3.0,        -- own front-wheel puddle splash (excess over the road film); PUD-3: x10 (user: ~3 drops vs tens in the puddle reference)
  -- PUD-3 SPRAY ON THE PATH (user: a lead car hit a puddle off my line; I turned into its line a moment later and met
  -- nothing -- in reality its spray still hangs over the path it drove). Each car leaves a path history (a point every
  -- sprayPathStepM with its speed term and the wheel water met since the previous point); the helmet samples the spray
  -- left on that PATH: lateral distance to the nearest path segment, s = path length the car drove since that point.
  -- Straight following gives exactly the previous line-of-sight model (s = distance ahead, same width / range laws).
  sprayPath = true,
  sprayPathStepM = 2.0,     -- path point spacing (m); 64 points cover sprayMaxM
  splashRadiusM = 3.0,      -- PUD-3b: radial reach of the ballistic splash around a path point (side spray of a tyre in water)
  splashSelfTau = 2.0,      -- s, slow baseline of the own front wheel water (the film); the excess above it is a puddle
}

local function roadWater(sim, p)
  -- M-REF3: measurement override of the road state (p.roadFixWater / p.roadFixWet, nil = CSP live values)
  local water = p.roadFixWater or sim.rainWater or 0
  local wet = p.roadFixWet or sim.rainWetness or 0
  return math.min(1, math.max(0, math.max(water, wet)))
end

-- PUD-1 probe (docs/RAINFX_V2_PUDDLE_API.md): CSP rain physics water at a wheel's contact point,
-- ac.StateWheel.waterThickness (m). Max over the given wheel indices, in mm (-1 = not available).
local function sprayW(h, p)   -- S2a road-water factor of a tyre (h in mm)
  local h0, hR = p.sprayH0MM or 0.6, math.max(p.sprayHRefMM or 1.8, 1e-3)
  local x = math.max(h - h0, 0) / math.max(hR - h0, 1e-3)
  return x ^ (p.sprayHGamma or 1.5)
end

local function wheelWaterMM(c, a, b)
  local wh = c and c.wheels
  if not wh then return -1 end
  local m = -1
  for k = a, b do
    local w = wh[k]
    local t = w and w.waterThickness
    if t and t * 1000 > m then m = t * 1000 end
  end
  return m
end

local HS = {}            -- PUD-2: per car smoothed wheel water (mm), allocated once per car index
local PATH_N = 64
local PATHS = {}         -- PUD-3: per car ring buffer (arrays allocated once per car index)
local function pathOf(i)
  local P = PATHS[i]
  if not P then
    P = { n = 0, head = 0, x = {}, y = {}, z = {}, s = {}, sv = {}, hm = {}, hx = {},
          S = 0, lx = nil, ly = 0, lz = 0, acc = 0, hSum = 0, hMax = 0, sLast = 0 }
    PATHS[i] = P
  end
  return P
end
-- advance car i's path (position, speed term sv, wheel water h in mm, all cars every frame)
local function pathStep(P, pos, sv, h, step)
  local px, py, pz = pos.x, pos.y, pos.z
  if P.lx then
    local dx, dy, dz = px - P.lx, py - P.ly, pz - P.lz
    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
    if d > 50 then P.n, P.head, P.S, P.acc, P.hSum, P.hMax, P.sLast = 0, 0, 0, 0, 0, 0, 0   -- teleport / replay jump
    else
      P.S = P.S + d
      P.acc, P.hSum, P.hMax = P.acc + d, P.hSum + h * d, math.max(P.hMax, h)
    end
  end
  P.lx, P.ly, P.lz = px, py, pz
  P.cur_sv, P.cur_h = sv, h
  if P.n == 0 or P.S - P.sLast >= step then
    local k = P.head % PATH_N + 1
    P.head = k
    P.n = math.min(P.n + 1, PATH_N)
    P.x[k], P.y[k], P.z[k], P.s[k] = px, py, pz, P.S
    P.sv[k] = sv
    P.hm[k] = P.acc > 1e-6 and P.hSum / P.acc or h   -- mean water met over the interval (fine spray ~ water met)
    P.hx[k] = math.max(P.hMax, h)                     -- peak (a puddle shorter than the step still bursts)
    P.acc, P.hSum, P.hMax, P.sLast = 0, 0, 0, P.S
  end
end
-- spray left on car i's path at point (mx, my, mz): returns lat^2, s, sv, h mean, h peak of the nearest segment
local function pathNearest(P, mx, my, mz)
  if P.n == 0 then return nil end
  local best, bs, bsv, bhm, bhx = 1e30, 0, 0, 0, 0
  local k = P.head
  -- segment from the newest point to the car's current position
  local ax, ay, az, as = P.x[k], P.y[k], P.z[k], P.s[k]
  local bx, by, bz, bS = P.lx, P.ly, P.lz, P.S
  local svB, hmB, hxB = P.cur_sv, (P.acc > 1e-6 and P.hSum / P.acc or P.cur_h), math.max(P.hMax, P.cur_h)
  for _ = 1, P.n do
    local ex, ey, ez = bx - ax, by - ay, bz - az
    local L2 = ex * ex + ey * ey + ez * ez
    local t = 0
    if L2 > 1e-9 then t = math.min(math.max(((mx - ax) * ex + (my - ay) * ey + (mz - az) * ez) / L2, 0), 1) end
    local qx, qy, qz = ax + ex * t - mx, ay + ey * t - my, az + ez * t - mz
    local d2 = qx * qx + qy * qy + qz * qz
    if d2 < best then best, bs, bsv, bhm, bhx = d2, P.S - (as + (bS - as) * t), svB, hmB, hxB end
    -- step back: the segment ending at point k carries the values stored at k
    svB, hmB, hxB = P.sv[k], P.hm[k], P.hx[k]
    bx, by, bz, bS = ax, ay, az, as
    k = (k - 2) % PATH_N + 1
    if _ == P.n then break end
    ax, ay, az, as = P.x[k], P.y[k], P.z[k], P.s[k]
  end
  return best, bs, bsv, bhm, bhx
end
local selfBase = nil

function S.estimate(sim, p, out)
  out = out or {}
  local wheelMode = p.sprayWheelWater ~= false and not p.roadFixWater   -- the M-REF3 override forces the legacy source
  local dtS = math.max(sim.dt or 0, 0)
  local aH = 1 - math.exp(-dtS / math.max(p.sprayHTau or 0.3, 1e-3))
  local w = roadWater(sim, p)
  local me = sim.focusedCar >= 0 and sim.focusedCar or 0
  local car = ac.getCar(me)
  out.wet, out.nearestM, out.cars, out.splash = w, -1, 0, 0
  out.nearestKmh, out.nearestLatM = -1, -1   -- M-REF: the nearest contributing car (speed, lateral offset)
  out.selfFrontMM, out.selfRearMM = wheelWaterMM(car, 0, 1), wheelWaterMM(car, 2, 3)   -- PUD-1 probe (own front / rear)
  out.leadWaterMM, out.packWaterMM, out.aheadWaterMM = -1, -1, -1   -- nearest contributing car / max over contributing / any car ahead
  if car and p.wheelProbe then   -- diagnostics only (metrics / CSV on)
    local pos0, look0 = car.position, car.look
    for i = 0, (sim.carsCount or 0) - 1 do   -- probe only: is the value filled for AI / replay cars? (any car < 60 m ahead)
      if i ~= me then
        local c = ac.getCar(i)
        if c then
          local cp = c.position
          local ah = (cp.x - pos0.x) * look0.x + (cp.y - pos0.y) * look0.y + (cp.z - pos0.z) * look0.z   -- no vec allocation
          if ah > 0 and ah < 60 then out.aheadWaterMM = math.max(out.aheadWaterMM, wheelWaterMM(c, 0, 3)) end
        end
      end
    end
  end
  -- PUD-2 own front wheels: road film baseline (slow) and the puddle excess above it
  local hF = out.selfFrontMM
  out.selfPuddle = 0
  if wheelMode and hF and hF >= 0 then
    if not selfBase then selfBase = hF end
    selfBase = selfBase + (hF - selfBase) * (1 - math.exp(-dtS / math.max(p.splashSelfTau or 2, 1e-3)))
    out.selfPuddle = math.max(hF - selfBase, 0) / math.max(p.sprayHRefMM or 1.8, 1e-3)
  end
  if not car or (not wheelMode and w <= 0) then out.spray = 0; return 0, out end
  local hRef = math.max(p.sprayHRefMM or 1.8, 1e-3)
  local pathMode = wheelMode and p.sprayPath ~= false
  local pos, look = car.position, car.look
  local lwc, splash = 0, 0
  local n = sim.carsCount or 0
  for i = 0, n - 1 do
    if i ~= me then
      local c = ac.getCar(i)
      if c and c.isConnected ~= false then
        local wf, wi = w, w   -- road water factor: smoothed (cloud) / instant (ballistic splash)
        if wheelMode then
          local hs = wheelWaterMM(c, 0, 3)
          hs = math.max(hs, 0)
          local prev = HS[i] or hs
          prev = prev + (hs - prev) * aH
          HS[i] = prev
          wf, wi = sprayW(prev, p), sprayW(hs, p)
        end
        local dx, dy, dz = c.position.x - pos.x, c.position.y - pos.y, c.position.z - pos.z
        local ahead = dx * look.x + dy * look.y + dz * look.z
        if pathMode then
          -- PUD-3: record this car's path, then sample the spray it left where my helmet is
          local v = c.velocity:length()
          local sv = v > p.sprayVMin and (v / p.sprayV0) ^ p.sprayExp * (1 - math.exp(-(v - p.sprayVMin) / 5)) or 0
          local P = pathOf(i)
          pathStep(P, c.position, sv, math.max(wheelWaterMM(c, 0, 3), 0), p.sprayPathStepM or 2)
          local cl = c.look
          -- only behind the car along its own heading (a tyre does not throw forward)
          if dx * dx + dy * dy + dz * dz < p.sprayMaxM * p.sprayMaxM and dx * cl.x + dy * cl.y + dz * cl.z > 0 then
            local lat2, sP, svP, hmP, hxP = pathNearest(P, pos.x, pos.y, pos.z)
            if lat2 and sP < p.sprayMaxM and svP > 0 then
              local wd = p.sprayWidthM + p.sprayWidenK * sP
              local cross = math.exp(-lat2 / (wd * wd))
              local k = svP * cross * math.exp(-sP / p.sprayRangeM) * sprayW(hmP, p)
              -- PUD-3b (user: real splash is also radial): the ballistic tread drops of a puddle hit fly out sideways too ->
              -- the splash kernel is at least splashRadiusM wide around the path, whatever the fine-spray plume width
              local wdS = math.max(wd, p.splashRadiusM or 3.0)
              local kS = svP * math.exp(-lat2 / (wdS * wdS)) * math.exp(-sP / p.splashRangeM) * sprayW(hxP, p)
              if k > 1e-4 or kS > 1e-4 then
                lwc = lwc + k
                splash = splash + kS
                out.cars = out.cars + 1
                if out.nearestM < 0 or sP < out.nearestM then
                  out.nearestM, out.nearestKmh, out.nearestLatM = sP, v * 3.6, math.sqrt(lat2)
                  out.leadWaterMM = hxP
                end
                out.packWaterMM = math.max(out.packWaterMM, hxP)
              end
            end
          end
        elseif ahead > 0 and ahead < p.sprayMaxM then
          local v = c.velocity:length()
          if v > p.sprayVMin then
            local lx, ly, lz = dx - look.x * ahead, dy - look.y * ahead, dz - look.z * ahead
            local lat2 = lx * lx + ly * ly + lz * lz
            local wd = p.sprayWidthM + p.sprayWidenK * ahead
            local sv = (v / p.sprayV0) ^ p.sprayExp * (1 - math.exp(-(v - p.sprayVMin) / 5))   -- smooth onset
            local cross = math.exp(-lat2 / (wd * wd))
            local k = sv * cross * math.exp(-ahead / p.sprayRangeM) * wf
            if k > 1e-4 then
              lwc = lwc + k
              splash = splash + sv * cross * math.exp(-ahead / p.splashRangeM) * wi
              out.cars = out.cars + 1
              if out.nearestM < 0 or ahead < out.nearestM then
                out.nearestM, out.nearestKmh, out.nearestLatM = ahead, v * 3.6, math.sqrt(lat2)
                out.leadWaterMM = wheelWaterMM(c, 0, 3)
              end
              out.packWaterMM = math.max(out.packWaterMM, wheelWaterMM(c, 0, 3))
            end
          end
        end
      end
    end
  end
  local own = car.velocity:length()
  local selfW = wheelMode and sprayW(math.max(hF or 0, 0), p) or w
  local selfK = own > p.sprayVMin and p.spraySelf * (own / p.sprayV0) ^ p.sprayExp * selfW or 0
  if wheelMode then
    lwc = (lwc + selfK) * p.sprayLWC0              -- road water already per car (wf)
    out.splash = splash + (p.splashSelfK or 0) * out.selfPuddle * math.min(own / 20, 1)   -- PUD-2 own puddle splash
  else
    lwc = (lwc + selfK) * p.sprayLWC0 * w
    out.splash = splash * w
  end
  out.spray = lwc
  return lwc, out
end

return S
