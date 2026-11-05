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
}

local function roadWater(sim)
  return math.min(1, math.max(0, math.max(sim.rainWater or 0, sim.rainWetness or 0)))
end

function S.estimate(sim, p, out)
  out = out or {}
  local w = roadWater(sim)
  local me = sim.focusedCar >= 0 and sim.focusedCar or 0
  local car = ac.getCar(me)
  out.wet, out.nearestM, out.cars, out.splash = w, -1, 0, 0
  if not car or w <= 0 then out.spray = 0; return 0, out end
  local pos, look = car.position, car.look
  local lwc, splash = 0, 0
  local n = sim.carsCount or 0
  for i = 0, n - 1 do
    if i ~= me then
      local c = ac.getCar(i)
      if c and c.isConnected ~= false then
        local dx, dy, dz = c.position.x - pos.x, c.position.y - pos.y, c.position.z - pos.z
        local ahead = dx * look.x + dy * look.y + dz * look.z
        if ahead > 0 and ahead < p.sprayMaxM then
          local v = c.velocity:length()
          if v > p.sprayVMin then
            local lx, ly, lz = dx - look.x * ahead, dy - look.y * ahead, dz - look.z * ahead
            local lat2 = lx * lx + ly * ly + lz * lz
            local wd = p.sprayWidthM + p.sprayWidenK * ahead
            local sv = (v / p.sprayV0) ^ p.sprayExp * (1 - math.exp(-(v - p.sprayVMin) / 5))   -- smooth onset
            local cross = math.exp(-lat2 / (wd * wd))
            local k = sv * cross * math.exp(-ahead / p.sprayRangeM)
            if k > 1e-4 then
              lwc = lwc + k
              splash = splash + sv * cross * math.exp(-ahead / p.splashRangeM)
              out.cars = out.cars + 1
              if out.nearestM < 0 or ahead < out.nearestM then out.nearestM = ahead end
            end
          end
        end
      end
    end
  end
  local own = car.velocity:length()
  local selfK = own > p.sprayVMin and p.spraySelf * (own / p.sprayV0) ^ p.sprayExp or 0
  lwc = (lwc + selfK) * p.sprayLWC0 * w
  out.splash = splash * w
  out.spray = lwc
  return lwc, out
end

return S
