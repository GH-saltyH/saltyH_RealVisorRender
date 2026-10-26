-- RainFX v2: CSP weather/vehicle state -> visor water supply parameters.
-- Pure function of its inputs (no GPU, no globals) so it can be checked offline.
-- Mapping: docs/RAINFX_CSP728_RE2_OPTIMAL_PLAN.md section 4 (continuous, no presets).
--
-- in  = { rainIntensity, speedRel (m/s, |rain velocity relative to the visor|),
--         sprayEstimate (0..), p = tuning table }
-- out = { rateMMh, meanDiamMM, impactRate (impacts/m^2/s at normal incidence),
--         stickFrac, microRate (1/s), fluxMMs }

local W = {}

-- CSP 0.3.0-preview728 debug UI: mm/h = rainIntensity * 100 (dwrite.dll 0x1807CA830).
function W.rateMMh(rainIntensity)
  return math.max(0, rainIntensity or 0) * 100
end

-- Marshall-Palmer: N(D) ~ exp(-Lambda D), Lambda = 4.1 R^-0.21 mm^-1; mean D = 1/Lambda.
function W.meanDiamMM(rateMMh)
  if rateMMh <= 0 then return 0.3 end
  return math.max(0.15, math.pow(rateMMh, 0.21) / 4.1)
end

function W.compute(input, out)
  out = out or {}
  local p = input.p
  local R = W.rateMMh(input.rainIntensity)
  local vt = p.terminalSpeed
  local speedRel = math.max(input.speedRel or vt, 0)
  local D = W.meanDiamMM(R) * p.diamScale
  -- Water volume flux through a surface facing the relative rain stream (m/s):
  -- liquid water content (R / 3.6e6 / vt) times the relative speed.
  local flux = R / 3.6e6 / vt * speedRel
  -- Spray: bounded extra supply (m/s of water), only when an estimate is given.
  flux = flux + math.min(input.sprayEstimate or 0, 1) * p.sprayFlux
  -- Exponential DSD: E[d^3] = 6 D^3 -> E[V] = pi D^3 (mm^3).
  local meanVolM3 = math.pi * D * D * D * 1e-9
  out.rateMMh = R
  out.meanDiamMM = D
  out.fluxMMs = flux * 1000
  out.impactRate = meanVolM3 > 0 and flux / meanVolM3 * p.impactScale or 0
  -- Faster impacts splash more: less of each drop stays as a resolved drop.
  local k = math.min(math.max((speedRel - 10) / 60, 0), 1)
  out.stickFrac = p.stickSlow + (p.stickFast - p.stickSlow) * k
  -- Unresolved micro droplets (haze) grow with flux and impact speed (splash).
  out.microRate = p.microK * out.fluxMMs * math.min(math.max(speedRel / 30, 0.2), 3)
  return out
end

return W
