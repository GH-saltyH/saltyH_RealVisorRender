-- RainFX v2 (rev11): road spray reaching the visor, estimated from the cars ahead.
-- Reference A (heavy spray at speed) is dominated by water thrown up by the car in
-- front, not by rain. CSP exposes no spray field, so this is a cheap procedural
-- estimate (A4 auxiliary): per car ahead in a narrow cone, distance and lateral
-- falloff x its speed^2 x track water; plus a small self-spray term (own front tyres).
-- Pure Lua, one loop over sim.carsCount per frame, no allocations.
--
-- Returns spray >= 0 (1 = following closely at speed on a flooded track) and fills
-- `out` with a breakdown for the UI.

local S = {}

S.DEFAULTS = {
  sprayRangeM = 25,        -- e-folding distance behind a car
  sprayMaxM = 90,          -- ignore cars further ahead
  sprayWidthM = 2.5,       -- lateral gaussian width
  spraySpeedRef = 50,      -- m/s for speed factor 1
  -- rev12: 0.12 made own-car spray the whole film supply on every wet track (no cars ahead
  -- in all 12 profile runs, spray 0.27 at speed). Open-wheel front tyres throw water low and
  -- backwards; little reaches the helmet.
  spraySelf = 0.01,         -- own front tyres at spraySpeedRef on a flooded track
}

-- rev14: spray needs standing water. Linear in water made 29 % puddles (Light Rain) throw a
-- film-forming spray; now nothing below 30 % water, full at 80 % (rev15: Light Rain T4 with
-- 26 % puddles still made a 40 % film at 0.2).
local function wet(sim)
  return math.min(1, math.max(0, ((sim.rainWater or 0) - 0.3) / 0.5))
end

function S.estimate(sim, p, out)
  out = out or {}
  local w = wet(sim)
  local me = sim.focusedCar >= 0 and sim.focusedCar or 0
  local car = ac.getCar(me)
  out.wet, out.nearestM, out.cars = w, -1, 0
  if not car or w <= 0 then out.spray = 0; return 0, out end
  local pos, look = car.position, car.look
  local total = 0
  local n = sim.carsCount or 0
  for i = 0, n - 1 do
    if i ~= me then
      local c = ac.getCar(i)
      if c and c.isConnected ~= false then
        local dx, dy, dz = c.position.x - pos.x, c.position.y - pos.y, c.position.z - pos.z
        local ahead = dx * look.x + dy * look.y + dz * look.z
        if ahead > 0 and ahead < p.sprayMaxM then
          local lx, ly, lz = dx - look.x * ahead, dy - look.y * ahead, dz - look.z * ahead
          local lat2 = lx * lx + ly * ly + lz * lz
          local sp = math.min(c.velocity:length() / p.spraySpeedRef, 1.5)
          local k = math.exp(-ahead / p.sprayRangeM) * math.exp(-lat2 / (p.sprayWidthM * p.sprayWidthM)) * sp * sp
          if k > 1e-3 then
            total = total + k
            out.cars = out.cars + 1
            if out.nearestM < 0 or ahead < out.nearestM then out.nearestM = ahead end
          end
        end
      end
    end
  end
  local own = math.min(car.velocity:length() / p.spraySpeedRef, 1.5)
  total = (total + p.spraySelf * own * own) * w
  out.spray = total
  return total, out
end

return S
