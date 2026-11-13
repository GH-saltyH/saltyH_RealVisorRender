-- H3 chase simulation (docs/RAINFX_V2_H3_ATLAS_SPEC.md 8i). Runs the REAL weather.lua (rain DSD, impact outcome W.impactKeep)
-- and the spray / haze laws of init.lua / spray.lua / haze.hlsl / visor.hlsl for one visor texel in the front of the visor,
-- through the user's 0 -> 250 km/h runs (acceleration from t = 12 s; speeds and wheel water at 14 / 16 / 18 / 20 s).
-- Usage: texlua rainfx2_h3_chase_sim.lua DEFAULTS_LUA RAINFX2_DIR [RH] [variant]
--   variant 'now' = the current build, 'fix' = the proposed H3-3c rules (printed side by side by the caller),
--   'i1' = section 8l impact lamella sweep (every spray impact gathers the fine caps under its beta_max d lamella -> G_c).
math.pow = math.pow or function(a, b) return a ^ b end
local DEF, ROOT, RH, VAR = arg[1], arg[2], tonumber(arg[3] or '0.95'), arg[4] or 'now'
local p = {}
for k, v in pairs(dofile(DEF)) do p[k] = v end
for k, v in pairs(dofile(ROOT .. '/physics.lua').DEFAULTS) do p[k] = v end
local okS, S = pcall(dofile, ROOT .. '/spray.lua')
for k, v in pairs(S.DEFAULTS) do p[k] = v end
local function capK(deg) local th = math.rad(math.min(math.max(deg, 5), 90)); local c, s = math.cos(th), math.sin(th)
  return math.pi * (2 - 3 * c + c * c * c) / (3 * s * s * s) end
p.shapeK = capK(p.contactDeg or 60)
p.sprayK = 1.35                                   -- the user's spray gain
p.microAMaxMM, p.microSplitMM = 0.3, 0.3
local W = dofile(ROOT .. '/weather.lua')

local SCEN = {
  { 'Light Thunderstorm', 0.10, 20, { {110, .79, 1.01, 1.09}, {160, .87, 1.09, 1.05}, {200, .92, 1.20, 1.21}, {240, 1.17, 1.17, 1.22} } },
  { 'Rain',               0.125, 20, { {110, .83, 1.26, 1.19}, {160, .90, 1.15, 1.13}, {200, .96, 1.26, 1.30}, {240, 1.30, 1.32, 1.37} } },
  { 'Thunderstorm',       0.20, 40, { {110, .93, .93, 1.31}, {160, 1.00, 1.37, 1.42}, {200, 1.10, 1.50, 1.53}, {240, 1.51, 1.55, 1.49} } },
  { 'Heavy Thunderstorm', 0.35, 70, { {110, 1.31, 1.56, 1.61}, {160, 1.26, 1.60, 1.52}, {200, 1.59, 1.82, 1.85}, {240, 1.79, 1.86, 1.85} } },
  { 'Heavy Rain',         0.60, 30, { {110, 1.65, 1.66, 1.90}, {160, 1.79, 1.94, 2.03}, {200, 2.04, 2.06, 2.07}, {240, 2.09, 2.09, 2.04} } },
}
local function sprayW(h) local x = math.max(h - p.sprayH0MM, 0) / (p.sprayHRefMM - p.sprayH0MM); return x ^ p.sprayHGamma end
local function sv(v) return v > p.sprayVMin and (v / p.sprayV0) ^ p.sprayExp * (1 - math.exp(-(v - p.sprayVMin) / 5)) or 0 end

-- one texel, frame steps, haze.hlsl laws
local a, phimax = p.hazeAMM or 0.015, p.hazePhiMax or 0.55
local sat = -math.log(1 - phimax) * p.shapeK * a / math.pi
local a50, rmax, q, cover, tau = 0.2125, 0.300, 0.4991, 0.761, p.hazeCoarsenTau or 0.5
local top = sat * a50 / a
local T, Dw = 20.0, 0.0
local rhoSat = 611.2 * math.exp(17.67 * T / (T + 243.5)) / (461.5 * (T + 273.15))
local evapD = 4 * 2.5e-5 * rhoSat * (1 - RH) / 1000 * 1e6
local kF = math.min(evapD / (p.shapeK * a * a), 5.0)
local E = 0.85                                      -- front of the visor: exposure x rainExposure
local pixMM, resPx = tonumber(arg[5] or "0.10"), tonumber(arg[6] or "2.0")                     -- DLSS internal 1620 x 912: ~0.1 mm of visor per pixel
local cellA = (602 / 512) * (146.3 / 128)

local function segAt(segs, t)                       -- piecewise-linear speed / wheel water from 12 s (0 km/h) on
  local pts = { {12, 0, segs[1][2], segs[1][3], segs[1][4]} }
  for i, s in ipairs(segs) do pts[#pts + 1] = { 12 + 2 * i, s[1], s[2], s[3], s[4] } end
  if t <= 12 then return 0, segs[1][2], segs[1][3], segs[1][4] end
  for i = 1, #pts - 1 do
    local A, B = pts[i], pts[i + 1]
    if t <= B[1] then local f = (t - A[1]) / (B[1] - A[1])
      return A[2] + f * (B[2] - A[2]), A[3] + f * (B[3] - A[3]), A[4] + f * (B[4] - A[4]), A[5] + f * (B[5] - A[5]) end
  end
  local L = pts[#pts]; return L[2], L[3], L[4], L[5]
end

local function supply(rI, windKmh, kmh, hL, hP, hA)
  local v = kmh / 3.6
  local rel = math.sqrt((v + 0.5 * windKmh / 3.6) ^ 2 + 81)                  -- car + half the wind (side / head mix) + fall
  local out = W.compute({ rainIntensity = rI, speedRel = rel, splashMMs = 0, airT = T, airRH = RH, p = p }, {})
  -- spray LWC at the helmet: lead at 16 m on the line, pack car 35 m / 1.5 m, any car 50 m / 2.5 m (path mode law)
  local lwc = 0
  for _, c in ipairs({ {16, 0, hL}, {35, 1.5, hP}, {50, 2.5, hA} }) do
    local wd = p.sprayWidthM + p.sprayWidenK * c[1]
    lwc = lwc + sv(v) * math.exp(-c[2] ^ 2 / wd ^ 2) * math.exp(-c[1] / p.sprayRangeM) * sprayW(c[3])
  end
  lwc = lwc * p.sprayLWC0 * p.sprayK
  local vOwn = math.max(v, 1)
  local DnS = math.min(math.max(0.39 * 12 * 0.072 / (1.2 * vOwn * vOwn) * 1000, 0.02), p.sprayDMaxMM or 0.8)
  local dS = DnS * 1e-3
  local stS = 1000 * dS * dS * vOwn / (18 * 1.8e-5 * 0.13)
  local mms = lwc * 1e-3 * vOwn * (stS / (stS + 0.25)) ^ 2
  -- SP1 / H3-3b shares (init.lua loop)
  local sl = math.log(p.sprayDsdSigma or 2.0)
  local vI = math.max(rel * 0.8 * 0.9, 0.3)
  local EV, Es, Ec, Er, EA = 0, 0, 0, 0, 0
  for i = 1, 24 do
    local z = -3.5 + (i - 0.5) * 7 / 24; local w = math.exp(-0.5 * z * z)
    local d = math.min(DnS * math.exp(sl * z), p.sprayDMaxMM or 0.8)
    local _, eK, hK, eS, eR = W.impactKeep(d, vI, p)
    EV = EV + w * math.pi / 6 * d ^ 3; Es = Es + w * hK; Ec = Ec + w * (eS or 0); Er = Er + w * (eR or 0)
    local dm = d * 1e-3; local Re, We = 1000 * vI * dm / 1e-3, 1000 * vI * vI * dm / 0.072   -- Roisman 2009 beta_max
    local bm = math.max(0.87 * Re ^ 0.2 - 0.40 * Re ^ 0.4 * We ^ -0.5, 1.0)
    EA = EA + w * math.pi / 4 * (bm * d) ^ 2
  end
  return { rainHaze = out.hazeMMs or 0, rainFlux = out.fluxMMs or 0, spray = mms, fine = mms * Es / EV, coarse = mms * Ec / EV,
           aIn = Ec > 0 and Er / Ec or a, DnS = DnS,
           AperV = EV > 0 and EA / EV or 0 }
end

local function visual(Gf, Gc, aIn)
  local aC = math.max(aIn, Gc * a / sat)
  local phiF = math.min(1 - math.exp(-math.pi * Gf / (p.shapeK * a)), phimax)
  local phiC = math.min(1 - math.exp(-math.pi * Gc / (p.shapeK * aC)), phimax)
  local relC = phiC / phimax
  local L = math.min(math.max(math.log(aC / a50) / math.log(2), -8), 0)
  local L0 = math.floor(L); local fL = L - L0
  local res = 0
  for k = 0, 1 do
    local sK = 2 ^ (L0 + k); local wk = k == 1 and fL or 1 - fL
    local aRes = 1 - math.min(resPx * pixMM / (rmax * sK), 1) ^ (1 / q)
    res = res + math.max(math.min(relC * wk, aRes), 0)
  end
  local phiU = phiC * math.max(1 - res / math.max(relC, 1e-4), 0)
  local veil = 1 - (1 - phiF) * (1 - phiU)
  return aC, phiF, phiC, res / math.max(relC, 1e-4), veil, res * cover
end

local hdr = string.format('%-19s %3s %6s %6s %6s %6s %6s | %5s %5s %6s %5s %5s %5s %5s', 'scene', 't', 'km/h', 'rainHz', 'sprFn', 'sprCo', 'aIn',
  'Gf', 'Gc', 'a(mm)', 'phiF', 'phiC', 'res%', 'veil')
print(string.format('RH %.2f  kF %.2f /s  G_sat %.4f mm  G_top %.4f mm  variant %s', RH, kF, sat, top, VAR))
print(hdr)
for _, sc in ipairs(SCEN) do
  local Gf, Gc, aInS = 0, 0, a
  local dt, t = 1 / 60, 0
  local nextT = 14
  while t < 20.001 do
    local kmh, hL, hP, hA = segAt(sc[4], t)
    local s = supply(sc[2], sc[3], kmh, hL, hP, hA)
    aInS = aInS + (s.aIn - aInS) * (1 - math.exp(-dt / 3))
    local aIn = math.max(aInS, a)
    if VAR == 'fix' then aIn = math.max(s.aIn, a) end
    local aC = math.max(aIn, Gc * a / sat)
    Gf = Gf * math.exp(-kF * dt); Gc = Gc * math.exp(-kF * dt * (a / aC) ^ 2)
    local relC = math.min(1 - math.exp(-math.pi * Gc / (p.shapeK * aC)), phimax) / phimax
    local onP = relC * cover
    local sup = (s.fine + s.rainHaze) * E * dt
    local supC = s.coarse * E * dt
    if VAR == 'fix' then supC = supC + sup; sup = 0 end      -- H3-3c: fine fragments land as part of the coat (no separate veil)
    Gc = Gc + sup * onP + supC; Gf = Gf + sup * (1 - onP)
    local relF = math.min(1 - math.exp(-math.pi * Gf / (p.shapeK * a)), phimax) / phimax
    local dC = Gf * (1 - math.exp(-dt / tau * relF * relF)); Gf = Gf - dC; Gc = Gc + dC
    if VAR == 'i1' then                                        -- 8l I1: lamella overrun rate nA = impacting spray x A / V
      local dI = Gf * (1 - math.exp(-s.spray * E * s.AperV * dt)); Gf = Gf - dI; Gc = Gc + dI
    end
    Gf = math.min(Gf, 2 * sat); Gc = math.min(Gc, top)
    t = t + dt
    if t >= nextT - 1e-6 and nextT <= 20 then
      local aC2, phiF, phiC, resF, veil, pc = visual(Gf, Gc, aIn)
      print(string.format('%-19s %3d %6.0f %6.4f %6.4f %6.4f %6.3f | %5.2f %5.2f %6.3f %5.2f %5.2f %5.0f %5.2f', sc[1], nextT, kmh,
        s.rainHaze, s.fine, s.coarse, aIn, Gf / sat, Gc / sat, aC2, phiF, phiC, 100 * resF, veil))
      nextT = nextT + 2
    end
  end
end
