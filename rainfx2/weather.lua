-- RainFX v2: CSP weather/vehicle state -> visor water supply parameters.
-- Pure function of its inputs (no GPU, no globals) so it can be checked offline.
-- Mapping: docs/RAINFX_CSP728_RE2_OPTIMAL_PLAN.md section 4 (continuous, no presets).
--
-- in  = { rainIntensity, speedRel (m/s, |rain velocity relative to the visor|),
--         sprayEstimate (0..), p = tuning table }
-- out = { rateMMh, meanDiamMM, impactRate (impacts/m^2/s at normal incidence),
--         stickFrac, fluxMMs, DSD quantiles dq / dsdM3 (P1), splash (P2) }

local W = {}

-- CSP 0.3.0-preview728 debug UI: mm/h = rainIntensity * 100 (dwrite.dll 0x1807CA830).
function W.rateMMh(rainIntensity)
  return math.max(0, rainIntensity or 0) * 100
end

-- Marshall-Palmer median volume diameter (mm): D0 = 3.67 / Lambda_MP, Lambda_MP = 4.1 R^-0.21 (kept for the UI)
function W.meanDiamMM(rateMMh)
  if rateMMh <= 0 then return 0.3 end
  return math.max(0.15, math.pow(rateMMh, 0.21) / 4.1)
end

-- rev48-P1 SUPPLY (docs/RAINFX_V2_DEPOSITION_MODEL.md): constrained-gamma DSD N(D) = N0 D^mu e^(-Lambda D)
-- (Zhang, Vivekanandan & Brandes 2001: mu = -0.016 L^2 + 1.213 L - 1.957, L D0 = 3.67 + mu; mu clamped to [-1, 6],
-- the fit's range), D0 = 0.895 R^0.21 x dsdD0K (MP; drizzle classes scale it, P3), N0 from the rate integral with the
-- Atlas 1973 fall speed. The visor's impact rate per size = N(D) |v_rel(D)| eta(D): v_rel combines the vehicle / wind
-- part of the relative speed with the drop's own fall speed (R4), eta = Langmuir-type helmet impingement
-- (St / (St + 0.25))^2 (fine drops follow the air around the helmet). Outputs a 16-knot inverse CDF of the impacting
-- diameter (knots at s = k / 15, u = 1 - (1 - s)^3: tail-weighted) and E[D^3] of an impact.
local NG = 160
local Dg, Ng, Wg = {}, {}, {}
local function vt(D) return math.max(9.65 - 10.3 * math.exp(-0.6 * D), 0.1) end
-- rev48-F6 SUB-CLOUD EVAPORATION (F5 review: at Light Drizzle -- intensity ~0.0x %, wetness / water 0, humidity 60 %,
-- sun -- the visor filled within seconds; the reference 'dryFlow' shows a dry visor with rare real drops). Rain is made
-- at the cloud base and falls through sub-saturated air: a drop of diameter D loses
--   D dD/dt = 4 f_v (S - 1) / (F_k + F_d)        (Rogers & Yau 1989 eq. 7.18, f_v = 0.78 + 0.308 Sc^1/3 Re^1/2)
-- over the fall from the lifting condensation level H = 125 m (T - T_dew) (Espy; CSP air temperature / humidity),
-- with RH rising linearly to 100 % at H. At 19 C / RH 60 % (H ~ 1 km) drops below ~0.7 mm never reach the ground --
-- drizzle (D0 ~0.3 mm) vanishes but for a rare large tail drop (a sun shower), light rain keeps most of its water;
-- at RH ~100 % (real drizzle / fog) nothing changes. CSP's wetness 0 (the road stays dry) is the same fact.
-- The drop COUNT flux is conserved for survivors; the concentration at the ground = flux / v_t(D_ground).
-- Map Dg(D) depends on T and RH only (cached).
local fallKey, Dground = nil, {}
local function dewPoint(T, RH)
  local a, b = 17.27, 237.7
  local g = math.log(math.max(RH, 1e-3)) + a * T / (b + T)
  return b * g / (a - g)
end
function W.fallMap(T, RH, dD, NG)
  local key = string.format('%.1f_%.3f', T, RH)
  if key == fallKey then return Dground end
  fallKey = key
  local H = math.max(125 * (T - dewPoint(T, RH)), 0)
  local TK = T + 273.15
  local L, Rv, K, Dv = 2.5e6, 461.5, 0.025, 2.5e-5
  local es = 611.2 * math.exp(17.67 * T / (T + 243.5))
  local FkFd = (L / (Rv * TK) - 1) * L * 1000 / (K * TK) + 1000 * Rv * TK / (Dv * es)
  local NZ = 120
  for k = 1, NG do
    local D = (k - 0.5) * dD * 1e-3                -- m
    if H > 1 and RH < 0.999 then
      local dz = H / NZ
      for iz = NZ, 1, -1 do
        local z = (iz - 0.5) * dz
        local v = math.max(9.65 - 10.3 * math.exp(-600 * D), 0.05)
        local Re = D * v / 1.5e-5
        local f = 0.78 + 0.308 * 0.84 * math.sqrt(Re)
        local S = RH + (1 - RH) * z / H
        local d2 = D * D + 8 * (S - 1) / FkFd * f * dz / v
        if d2 <= 0 then D = 0; break end
        D = math.sqrt(d2)
      end
    end
    Dground[k] = D * 1000
  end
  W.cloudBaseM = H
  return Dground
end

function W.supply(R, speedRel, p, out)
  local vt0 = p.terminalSpeed
  local D0 = 0.895 * math.max(R, 0.01) ^ 0.21 * (p.dsdD0K or 1) * (out.familyK or 1)
  local lam = 3.67 / D0
  local mu = 0
  for _ = 1, 40 do
    mu = math.min(math.max(-0.016 * lam * lam + 1.213 * lam - 1.957, -1), 6)
    lam = (3.67 + mu) / D0
  end
  local dD = 6.0 / NG
  local h2 = math.max(speedRel * speedRel - vt0 * vt0, 0)
  local Rh, muA = 0.13, 1.8e-5
  local rUnit, wSum, m3 = 0, 0, 0
  for k = 1, NG do
    local D = (k - 0.5) * dD
    local n = D ^ mu * math.exp(-lam * D)
    local v = vt(D)
    rUnit = rUnit + n * D * D * D * v
    Dg[k], Ng[k] = D, n
  end
  local n0 = R / math.max(6 * math.pi * 1e-4 * rUnit * dD, 1e-30)
  local flux = 0
  local gmap = W.fallMap(out.airT or 20, out.airRH or 1, dD, NG)   -- F6: diameter at the ground (0 = evaporated)
  local cbMass, gMass = 0, 0
  for k = 1, NG do Wg[k] = 0 end
  for k = 1, NG do
    local D0k = Dg[k]
    local D = gmap[k]
    local Fc = n0 * Ng[k] * vt(D0k) * dD                     -- count flux at the cloud base (/m^2/s)
    cbMass = cbMass + Fc * D0k * D0k * D0k
    local w = 0
    if D > 0.05 then
      gMass = gMass + Fc * D * D * D
      local vr = math.sqrt(h2 + vt(D) ^ 2)
      local St = 1000 * (D * 1e-3) ^ 2 * vr / (18 * muA * Rh)
      local eta = vr > 1 and (St / (St + 0.25)) ^ 2 or 1
      w = Fc / vt(D) * vr * eta                               -- impacts / m^2 / s of this class (normal incidence)
    end
    local j = math.min(math.max(math.floor(D / dD) + 1, 1), NG)   -- binned at its GROUND size (quantiles below)
    Wg[j] = Wg[j] + w
    wSum = wSum + w
    m3 = m3 + w * D * D * D
    flux = flux + w * math.pi / 6 * D * D * D * 1e-9         -- m / s of water
  end
  out.groundShare = cbMass > 0 and gMass / cbMass or 1       -- F6: mass share reaching the ground
  out.groundMMh = R * out.groundShare
  out.cloudBaseM = W.cloudBaseM or 0
  -- rev48-P2 ballistic tread drops thrown by the car ahead (lognormal, median 1.6 mm, sigma_g 1.4; Weir 1978 1-4 mm):
  -- volume flux splashMMs (mm/s) as extra impacts of their own sizes (rare big drops close behind a car)
  local sMMs = out.splashMMs or 0
  out.splashFluxMMs = 0
  if sMMs > 1e-7 then
    local sg = math.log(1.4)
    local pv, nsum = 0, 0
    for k = 1, NG do
      local D = Dg[k]
      local pdf = math.exp(-(math.log(D / 1.6)) ^ 2 / (2 * sg * sg)) / (D * sg * math.sqrt(2 * math.pi))
      pv = pv + pdf * math.pi / 6 * D * D * D * 1e-9 * dD
      nsum = nsum + pdf * dD
    end
    local nRate = (sMMs * 1e-3) / math.max(pv / math.max(nsum, 1e-12), 1e-30) / math.max(nsum, 1e-12)
    for k = 1, NG do
      local D = Dg[k]
      local pdf = math.exp(-(math.log(D / 1.6)) ^ 2 / (2 * sg * sg)) / (D * sg * math.sqrt(2 * math.pi))
      local w = nRate * pdf * dD
      Wg[k] = Wg[k] + w
      wSum = wSum + w
      m3 = m3 + w * D * D * D
      flux = flux + w * math.pi / 6 * D * D * D * 1e-9
      out.splashFluxMMs = out.splashFluxMMs + w * math.pi / 6 * D * D * D * 1e-6
    end
  end
  out.dsdMu, out.dsdLambda, out.dsdD0 = mu, lam, D0
  out.impactRate = wSum
  out.fluxMMs = flux * 1000
  out.dsdM3 = wSum > 0 and m3 / wSum or 6 * D0 ^ 3
  out.dq = out.dq or {}
  local acc, k = 0, 1
  local mean = 0
  for i = 0, 15 do
    local u = math.min(math.max(1 - (1 - i / 15) ^ 3, 1e-4), 1 - 1e-5)
    while k < NG and (acc + Wg[k]) < u * wSum do acc = acc + Wg[k]; k = k + 1 end
    local f = Wg[k] > 0 and (u * wSum - acc) / Wg[k] or 0
    out.dq[i + 1] = (k - 1 + math.min(math.max(f, 0), 1)) * dD
  end
  for kk = 1, NG do mean = mean + Wg[kk] * Dg[kk] end
  out.meanDiamMM = wSum > 0 and mean / wSum or D0
  return out
end

-- rev48-P3 DSD family by CSP weatherType (docs/metrics/20261104_P3_Metrics, RAINFX_V2_DEPOSITION_MODEL.md section 5):
-- the measured intensities x 100 give realistic rates (LightDrizzle 0.1, Drizzle 1.1, HeavyDrizzle 4.6, LightRain 0.6
-- (16 % zero), Rain 6.7, HeavyRain 35, Thunderstorm 8, HeavyThunderstorm 7-29, Hurricane 44 mm/h), so R stays
-- intensity x 100; the TYPE picks the drop-size family: drizzle = many fine drops (D0 x 0.5 -> 0.3-0.6 mm), stratiform
-- rain = MP (x 1), continental convective storms / squalls / tornado = larger drops at the same rate (x 1.2,
-- Bringi et al. 2003), hurricane = maritime convective (x 1).
local D0K = { [0] = 1.2, [1] = 1.2, [2] = 1.2, [3] = 0.5, [4] = 0.5, [5] = 0.5, [6] = 1.0, [7] = 1.0, [8] = 1.0,
              [26] = 1.2, [27] = 1.2, [28] = 1.0 }
function W.familyK(weatherType)
  return D0K[weatherType or -1] or 1.0
end

function W.compute(input, out)
  out = out or {}
  local p = input.p
  local R = W.rateMMh(input.rainIntensity)
  local speedRel = math.max(input.speedRel or p.terminalSpeed, 0)
  out.rateMMh = R
  out.familyK = W.familyK(input.weatherType)
  out.splashMMs = input.splashMMs or 0
  out.airT, out.airRH = input.airT or 20, input.airRH or 1   -- F6 sub-cloud evaporation (CSP air temperature / humidity)
  if R > 0 or out.splashMMs > 1e-7 then
    W.supply(R, speedRel, p, out)
  else
    out.impactRate, out.fluxMMs, out.meanDiamMM, out.dsdM3 = 0, 0, 0.3, 0.162
    out.dq = out.dq or {}
    for i = 1, 16 do out.dq[i] = 0.3 end
  end
  -- rev21 R-size: splash parameter K = We^1/2 Re^1/4 of the mean impacting drop; resolved fraction (K0/K)^resA
  -- (R2: deposition keeps all). Used for the film share of the non-resolved rain (and the UI).
  local D = out.meanDiamMM
  local v = math.max(speedRel, 0.5)
  out.splashK = math.sqrt(13.8889 * v * v * D) * (1000 * v * D) ^ 0.25
  local kr = math.min(1, (p.splashK0 or 58) / math.max(out.splashK, 1e-3))
  out.stickFrac = kr ^ (p.resA or 0.5)
  out.fragDiamMM = D * kr ^ (p.resB or 0.3)
  return out
end

return W
