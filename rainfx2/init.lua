-- RainFX v2 core: GPU-resident cell-gather visor rain.
-- Design: docs/RAINFX_CSP728_RE2_OPTIMAL_PLAN.md, integration: docs/RAINFX_V2_CORE.md.
--
-- Per frame (once, never inside offscreen captures):
--   P1 cells  (S ping-pong, RGBA32F)  x substeps
--   P1b claim (C, RGBA16F) + P1c merge (S ping-pong): coalescence of touching drops (rev6)
--   P2 field  (F ping-pong, RGBA16 UNorm) x substeps
-- Draw: P3 housing-free refraction source (half res, once per view), then P4 visor
-- composite on a copy of GLASS_RAINFX between glass stack pre/post, then a depth-only pass. Drops are evaluated analytically per screen pixel from S
-- (rev3: the coarse optics atlas was blocky at near-eye magnification and is gone).
-- No readback, no per-drop Lua, no vertex upload.
--
-- ctx = {
--   folder      = app folder,
--   targetMesh  = function() -> ac.SceneReference (GLASS_RAINFX) or nil,
--   surface     = rain_surface.lua object (hash-verified geometry: :validate(), .root),
--   maskPath    = RAINFX_ObjNormal_BoundaryMask.dds path,
--   surfaceOffset = metres to lift the drawn copy along its normal,
--   depthReversed = optional function() -> true if dynamic::depth is reversed-Z,
-- }

local MESH_NAME = 'RealVisor_RainFX2_Surface'

local R2 = {}
R2.__index = R2

local function readFile(path)
  local f = io.open(path, 'rb')
  if not f then return nil end
  local s = f:read('*a')
  f:close()
  return s
end

-- Tunables. Physical meaning in docs/RAINFX_V2_CORE.md; values are first estimates.
local DEFAULTS = {
  -- grids (mesh: U span ~0.60 m, V span ~0.146 m -> 512x128 cells ~1.2 mm)
  cellsU = 512, cellsV = 128, fieldU = 1024, fieldV = 256,
  substeps = 2,
  -- supply (weather.lua)
  terminalSpeed = 6.0,   -- rev48-P1/P2: diamScale / impactScale / sprayFlux removed (dsdD0K, spray.lua LWC)
  dsdD0K = 1.0,   -- rev48-P1: median volume diameter x this (drizzle classes < 1, P3 weather mapping)
  fineRMM = 0.25,   -- splash satellites below this radius leave as mist with the helmet air (F9: the F1-F8 fine layer is removed)
  -- rev47b: rain exposure 0.5 -> 1.0 (stored under a new key), rain arrives in a cone of rainSpreadDeg,
  -- crown runoff over the visor top edge at rest (catch length crownMM into a band of crownBandMM)
  exposure = 1.0, exposureFloor = 0.0, normalSign = 1.0, rainSpreadDeg = 18.0, crownMM = 20.0, crownBandMM = 3.0,
  -- drop physics: rainfx2/physics.lua (P.DEFAULTS, merged below)
  ladderMinMM = 0.3, ladderMaxMM = 2.2,   -- physics test drop ladder
  -- field
  -- rev21: moving drops wipe the haze clean and leave only a faint trace (user observation of real
  -- visors, research section 3.3): collect 0.9 -> 0.95, trace haze 0.15 -> 0.05 (below)
  -- rev21 R-size (docs/RAINFX_V2_DROP_SIZE_RESEARCH.md section 3): impact fragmentation
  -- rev41 (rev40 review: at speed far too few visible small drops): resA 0.5 -> 0.3 (resolved share at
  -- 250 km/h 0.11 -> 0.25), resB 0.3 -> 0.4 (fragments 0.18 -> 0.12 mm)
  splashK0 = 58, resA = 0.5, resB = 0.4, stickMin = 0.25,   -- S1 (2026-11-17, docs/RAINFX_V2_S_REVIEW.md): kept-share floor (splashed <= 0.75)   -- F3: resA 0.3 -> 0.5 (splashed mass ~0.75-0.8 at K/K0 ~ 18: Mundo 1995, SLD Trontin & Villedieu 2016)
  -- rev21 growth of visible drops from unresolved water: haze condensation, film head drops
  filmCollect = 0.3,   -- F1: nucM / nucRate (haze nucleation) replaced by the fine coalescence
  -- rev21 CSP adoption: lateral kicks from surface noise (6 mm features), trail following
  trailFollow = 1.5,   -- C-clean: rev21 meander removed (replaced by the defect field F1, rev48-S6)
  strongK = 2.0, strongThr = 0.74, strongMM = 0.4, escape = true,   -- J1 (2026-11-07, SPRAY_RAIN_REF s19-21): sparse strong defects + escape (F2 review: 4 froze the centre)
  blGrowth = true, dynRet = true, pgradK = 1.0,   -- F2 (s21): boundary-layer growth from the stagnation point, dynamic retention
  defMM = 1.2, defK = 5.0, defPin = 0.35,              -- rev48-S6 F1 surface defects: scale, gradient steering, stick-slip pinning
  -- sheetDrain rev14 0.5 -> 0.1: drainage dominated the film balance (eq ~ supply), now edge
  -- outflow does (eq ~ supply^(1/2..1/3)), compressing light..heavy into the cover window.
  sweepWidth = 0.9, filmDrain = 0.1,   -- film drainage /s with the film model OFF (legacy path)
  -- drop lens (rev18): legacy Water Field rule, docs/RAINFX_V2_WF_LENS_PLAN.md
  kernelScale = 1.24, threshold = 0.35,     -- dome 1-(d/1.24R)^2, silhouette at U = 0.35 (= R)
  -- rev20 drop surface: contact angle of an impact-deposited drop (~ receding angle on polycarbonate
  -- / hard coat), per-drop spread, extra recession at the sliding rear, flattening on a wet surface.
  -- rev25: 75 -> 55. The TIR band starts at r/R = sin(48.6 deg)/sin(theta): 75 deg -> outer 22 % of the
  -- radius dark (thick rim on close drops), 55 deg -> 8 % (thin rim like the reference)
  capVolume = true,
  shedU10 = 25.0,   -- rev48-F4b: outer air speed (m/s) that depins a 10 uL drop on the coat (R6b 20; F4b fit to the dryFlow reference frames)
  shedBeta = 0.11,  -- 2026-11-07 (SPRAY_RAIN_REF s23, user fix with stagnation 24 deg + F2 / F3); rev48-F4b 0.08: U_c(V) = shedU10 (V / 10 uL)^-shedBeta (reference: r 0.6 / 0.25 / 0.15 mm move from ~150 / 177 / 205 km/h)
  bigOn = true, bigRMM = 0.8,   -- rev48-R7a: drops >= bigRMM drawn / touching in a +-4 cell window (largest per 4 x 4 tile)   -- rev48-R3: drop volume = spherical cap of contactDeg (false: rev7 hemisphere 2.094)
  contactDeg = 58,   -- R-steep2 (TRAIL_REVIEW3 section 45-46): 58 = steep rim without the 'button' outer layer of 70 (user test)
  -- S-fix history (TRAIL_REVIEW3 sections 36-38): 45 = between the coat theta_r 40 / theta_a 54 (rev35 was 60: a full TIR ring)
  hysteresisDeg = 20,
  -- rev20 wobble of pinned drops in airflow (amplitude ~ drag/pinning), visible-rate tones
  wobbleAmp = 0.08, wobbleHz = 8.0,   -- rev21: 0.12 -> 0.08 (user: 0.07-0.09 best at speed)
  motionStretch = 0.35,                     -- WF MOTION_STRETCH
  minDrawMM = 0.06,                         -- smaller drops are drawn at this radius (rev21: 0.2 -> 0.12, rev41: 0.06)
  wfRefraction = 0.14,                      -- near lens (rev22 default = user choice 0.14; WF 0.69 -> chrome). Far rim: farRefraction
  wfSceneMip = 2.0,       -- WF SCENE_MIP 3 on a full-res shot = 2 on the half-res source
  -- defocus (rev18, D-C): thin-lens circle of confusion, docs/RAINFX_V2_DEFOCUS_PLAN.md
  apertureMM = 0.0,        -- entrance pupil A (rev23: 0 until the final whole-visor defocus step)
  focusM = 0.12,           -- focus distance zf (left visor ~ in focus, near-lens right blurred)
  defocusDA = true,        -- rev19: D-A stochastic colour gather (4 taps where CoC > 1 px); off = D-C
  housingMask = true,      -- H-mask (TRAIL_REVIEW3 section 59): remove the housing by its own coverage shot (any depth)
  housingM = 0.05,         -- frame pixels closer than this (linear m) are helmet housing (rev27: UI slider; S-fix2 tried 0.15: removed car parts touching the visor -> back to 0.05, section 41)
  sourceScale = 0.5,       -- refraction source resolution (fraction of the frame)
  -- rev22: symmetric rim loss 0.75 -> 0.35; the one-sided rim shading now comes from the far lens
  glint = 0.45,
  -- rev43 single plano-convex lens (CORE section 55): one strength, 1 = physical (n 1.333). The rev32-42
  -- interior / rim refraction pair and the side-view band were removed (rev48-U1 cleanup).
  lensPhys = 1.0,
  -- rev24 physical plano-convex lens (visor.hlsl r2DropLens): deflection gain (1 = physical, n 1.333),
  -- environment for rays leaving the screen (ground fraction of the sky colour), TIR interior,
  -- gravity sag of pinned drops (thick toward gravity, thin tail above)
  sagK = 0.25,
  -- rev28 CSP windscreen drop shading (docs/RAINFX_V2_CSP_DROP_SHADING.md)
  -- rev29 full CSP windscreen port (docs/RAINFX_V2_CSP_DROP_SHADING.md section 5)
  depthTest = true,   -- rev32: back on (user: needed so the helmet housing hides the water; no effect on the pattern)
  clearMaxMM = 0.3, clearK = 1.0,                     -- rev22 impact clearing of small pinned drops
  -- rev40 size mix (docs/RAINFX_V2_DROP_PIPELINE_PLAN.md step 2): fragment / nucleation diameter =
  -- base x X, pdf(X) ~ X^-(1+fragA) on [fragLo, fragHi] (0.88 = reference: counts x0.7 per 1.5x bin)
  fragA = 0.88, fragLo = 0.35, fragHi = 3.0,
  -- rev41: fragments of one impact spread over its lamella (cap per impact), clustered births
  fragMax = 12, clusterK = 0.6, clusterMM = 12.0,
  -- rev45 step 3 (docs/RAINFX_V2_DROP_PHYSICS_MODEL.md section 6 B): life cycle and trails
  growTime = 0.06, fadeTime = 0.10,          -- s: newborn drops grow in, swept drops fade out
  trailWidthK = 0.5,
  coatOn = true, coatWear = 0.3, coatWearRate = 0.0, testDirt = 0.0, dirtMM = 3.0, coatKD = 0.5, coatKC = 0.5, coatKM = 0.4, coatTauA = 1.0, coatTauR = 20.0,   -- B1d coat state
  tailOn = true, tailNeckRho = 0.75, tailK = 4.0, tailMax = 20.0, tailWidthK = 0.6, tailTau = 0.1, tailFlat = 0.85, headRound = 1.0, surfH = true, surfK = 0.04, rimPhys = true, steep = true, cubeK = 0.7, cubeMip = 2.0, imgPupilMM = 0.0, lensStable = true, sceneCompress = true, compressK = 0.01, bondFlatK = 0.5,   -- B1 drop tails (docs/RAINFX_V2_TRAIL_REVIEW3.md section 11)
  -- trail water (rule_trail; rev47j width 0.35 -> 0.5 r: reference ~1/4 of the head)
  surfThetaRDeg = 40.0,   -- FILM-UNIFY A (docs/RAINFX_V2_FILM_UNIFY_PLAN.md): ONE receding angle of the coat (user 2026-11-13); trailThetaRDeg,
                          -- filmRecedeDeg and hysteresisDeg are derived from it every frame (R2:syncSurface)
  trailThetaRDeg = 28.0, trailWetK = 0.35, trailLL = 5.0,   -- rev47l trail rule (Ca vs Ca*, docs/RAINFX_V2_TRAIL_RULES.md)
  -- rev48-S1 shape state (docs/RAINFX_V2_SHAPE_STATE_PLAN.md section 6): birth class shares, relaxation
  shpImpactK = 0.15, shpImpactMax = 1.8,   -- rev48-S2' (birth events: splats spread nearly evenly; was 0.35 / 3)
  baseSpread = 1.0,
    -- rev48-S2'b: resting drop profile = splat rule at this f (1 = rev48 dome; try 1.3-1.5)
  shpSpreadMin = 1.8, shpSpreadMax = 3.2, shpRecoilC = 3.0, shpLamShift = 0.15,
  shpRimK = 0.6, shpFingerK = 0.25,   -- rev48-U2 splat lamella: rim share of the profile, downstream finger amplitude   -- rev48-S2' splat spread / recoil
  shpSkidK = 0.01, shpSkidMax = 0.05,   -- rev48-S2b recoil 0.4 -> 0.8 s (60 s rest: settled drops stayed vertical ovals)
  -- (rev48-S2 oblique impact)
  shpMergeK = 1.0, shpWaist = 0.0,      -- rev48-S3 merged footprint (tensor gain); M2: waist 0 (bridge fills in ~20 ms)
  shpMergeTau = 0.015,   -- R-steep: Cox-Voinov recession U ~ (gamma / 9 mu ln)(theta_eq^3 - theta^3) ~ 0.1 m/s -> ~10-20 ms per mm (was 0.6)
  -- rev48-M1 note:                    -- rev48-M1: s per mm of radius for a flat (merged / arrested) footprint to recede to theta_r
  asymK = 0.35, asymGravR = 1.0,       -- rev48-S2d off-centre apex (strength, radius where it points downhill)
  footPhys = true,                     -- rev48-S3b coalescence uses the drawn footprint (S4c: = the water radius x shape)
  footPinK = 1.0,                      -- rev48-S7 Furmidge: pinning by the contact width across the force (0 = 2r)
  shpBoK = 1.2, shpTearK = 0.12,
  shpSlugTau = 0.6, shpAirK = 0.08, shpAirMax = 1.6,   -- rev48-S5 E3 slug length memory, E6 air stretch of pinned drops
  shpTailTau = 0.25, shpTailStretch = 0.2, shpHookK = 2.0, shpFrontK = 1.2, shpSnapDeg = 40.0,   -- rev48-S6 F2 turns (S6b: head hook)
  -- FILM S2 (docs/RAINFX_V2_FILM_S2_DESIGN.md; cleanup 2026-11-16: the rev48-W1 sheet parameters are gone, sheet* -> film*)
  filmOn = true,                 -- FILM-UNIFY (2026-11-13, user): the water film model is on by default
  filmStoreMaxMM = 4.0,          -- field B scale with the film on (B = h / 4 mm; R1 puddles reach ~2 mm, the puddle height)
  filmSpill = true,              -- R1: water beyond the largest stable drop spreads as film (false = discarded, rev1-48)
  filmDrawMinMM = 0.10,          -- the drawn film starts here (the rev11 overlay until S2-3); F1 joins from filmJoinMM
  filmRecedeDeg = 50,            -- coat receding angle used by the film rules (R2:syncSurface sets it from surfThetaRDeg)
  filmFollowK = 0.5,             -- drops follow the water paths (cells)
  impactWaveK = 1.0,   -- P4 sheet waves / impact crater + ring
  shpSplitA = 2.6, shpSplitRate = 6.0, shpSplitRMin = 0.45, shpNeckK = 1.5, shpNeckT = 0.12, hiSplit = false, hiImpact = false,   -- rev48-S6c E8 tail split (aspect, events / s, min parent radius mm)
  shpOn = true, shpDefShape = 1.0, shpRelaxMove = 0.12, shpRelaxStill = 10.0,   -- rev48-S5 E7 replaces the random sag class (shpSagP 0)
  shpMotionK = 0.6, shpMotionV = 0.04,   -- rev48-S4 motion morph (aspect 1 + k v/V); R1: arrest from theta_r (shpArrest removed)
  trailSlopeMax = 0.45,                      -- rev47k: rivulet edge slope 2 h0 / hw <= 0.45 (~24 deg; rev47j 0.8 drew glass rods)
  trailPinMM = 0.02, trailFlowK = 1.0,       -- rev47k: rivulets deeper than this run along themselves (film law x flowK)
  wetHaze = 0.0,        -- H1 (2026-11-07): 0 -- the haze G is separate micro caps (dropwise), not a wetting film (was 1.5 while G was ~0)
  hazeK = 1.0, hazeAMM = 0.015, hazePhiMax = 0.55, hazeExpo = 0.9, hazeRMaxMM = 0.08, hazeRes = 2, hazeNuc = true, hazeNucTau = 0.3, hazeNucSite = true, hazeMask = 1, haloK = 0.5, haloInMM = 0.1, haloOutMM = 0.4, microOn = true, microBias = 0, microRefract = 1.0, microResPx = 2.0, microHaloK = 0.5, microHaloPx = 1.5, microAMaxMM = 0.3, hazeCoarsenTau = 0.5, hazeNucPMax = 0.02, hazeOverrunK = 1.0, hazeWetMM = 0.02, microBlurK = 0.7,   -- 8l I1 lamella sweep, 8m S1 water layer, V2 unresolved-lens blur share
    -- H1 haze: scatter gain, micro cap radius mm, breath-figure coverage, impact exposure, finest fragments held as haze; N1 defect sites, N3 reach mask (0 off | 1 on | 2 verify), N2 wipe halo (section 27)
  sprayVRelK = 0.8, sprayAeroDn = true, sprayAeroC = 0.39,            -- SP1 spray impact speed / SpeedRel; SP0 torn-spray median
  pearlMM = 0.006, pearlRate = 0.0,   -- PL1 (2026-11-07): delayed trail pearling off (green / blue streams born seconds later from invisible trail water); was 0.6;          -- rev47k: every rivulet section beads up, 0.6 /s per cell (rev47j 0.03 / 0.1: thin trails never broke)
  filmBeadMM = 0.04, dewetRate = 4.0,        -- rev47j: film >= 0.04 mm in a cell gathers into a bead, 4 /s per cell
  -- rev47 T-layer: trail water lives in field R (depth / trailMaxMM), pinned (no diffusion / advection),
  -- evaporates at trailEvapMMs (thin trails vanish first), collected by later drops
  trailMaxMM = 0.5, trailEvapMMs = 0.003,   -- rev47j: 0.025 -> 0.003 (reference trails stay for seconds)
  sizeBin0MM = 0.04,  -- size histogram: first bin edge (= minRadiusMM), 10 bins x1.5 (rev41)
  -- rev23 look lab: occupancy per cell, radius range (pdf ~ r^-1.88 = reference size histogram)
  labOcc = 0.3, labRMinMM = 0.12, labRMaxMM = 2.0,
  -- water film optics (rev11)
  -- rev46: film / trail water visible from 0.03 mm (trails), sharp (base mip 0.75; rev11-45 4.5 = milky)
  filmMinMM = 0.08, filmFullMM = 0.20,   -- rev47j: only a real sheet shows (thin film dewets into beads); trails are lens kernels
  trailMinMM = 0.012, trailFullMM = 0.05, filmRefract = 12.0, filmAbsorb = 0.8, filmMip = 0.75, filmVeil = 0.25,
  -- forward scattering veil of the VISOR SURFACE only (rev17, docs/RAINFX_V2_EVAL.md section 11):
  -- airborne spray/mist is CSP's own particle domain and is not reproduced here (scatterSpray 0).
  scatterK = 1.0, scatterFilm = 0.3, scatterSpray = 0.0,   -- F3: scatterM / M0 removed (fine droplets are drawn as drops)
  scatterMax = 0.35, scatterMip = 6.5, scatterSky = 0.3, scatterGain = 1.1,
  filmK = 1.0, sprayK = 1.0,
  veilBright = 1.0,   -- F2: hazeK / hazeMip / veilMix removed (one veil = the surface scatter)
  depthCoverage = 0.35, debug = 0, debugBright = 1.0,
}

-- Persisted user controls (subset of DEFAULTS + enable switch).
local STORED = { enabled = true, rainExposure = DEFAULTS.exposure, wfRefraction = DEFAULTS.wfRefraction,
  wfSceneMip = DEFAULTS.wfSceneMip, focusM = DEFAULTS.focusM, defocusDA = DEFAULTS.defocusDA,
  contactDeg = DEFAULTS.contactDeg, wobbleAmp = DEFAULTS.wobbleAmp,
  apertureMM = DEFAULTS.apertureMM, substeps = DEFAULTS.substeps, freezeRain = false, windK = 1.0, metrics = false,
  filmK = DEFAULTS.filmK, sprayK = DEFAULTS.sprayK, filmRefract = DEFAULTS.filmRefract, filmVeil = DEFAULTS.filmVeil,
  scatterK = DEFAULTS.scatterK,
  debug = DEFAULTS.debug, invertSide = false,
  windDirOffsetDeg = 180, windDirCalibrated = false,
  airTFix = false, airTFixC = 22.1,
  intensityFix = false, intensityFixV = 0.10,
  roadFix = false, roadFixWater = 0.35, roadFixWet = 0.12 }   -- M-REF3: reference road water / wetness for the spray estimate   -- M-REF2: RainFX rain supply at a fixed intensity (CSP road water / spray unchanged)   -- M-REF: replay air temperature (CSP replays do not record it)   -- rev48: compass -> game-space wind convention (calibrated live)


-- rev40: truncated power law of the fragment size factor X, pdf ~ X^-(1+a) on [lo, hi].
-- Shader inverse CDF X = (lo^-a + u (hi^-a - lo^-a))^(-1/a); E[X^3] keeps the mass in expectation.
local function fragLaw(p, out)
  local a, lo, hi = math.max(p.fragA, 0.05), p.fragLo, math.max(p.fragHi, p.fragLo + 1e-3)
  if out.a == a and out.lo == lo and out.hi == hi then return out end
  out.a, out.lo, out.hi = a, lo, hi
  out.loP, out.hiP, out.invA = lo ^ -a, hi ^ -a, -1 / a
  local C = a / (lo ^ -a - hi ^ -a)
  out.m3 = C * (hi ^ (3 - a) - lo ^ (3 - a)) / (3 - a)
  out.m1 = math.abs(1 - a) < 1e-6 and C * math.log(hi / lo) or C * (hi ^ (1 - a) - lo ^ (1 - a)) / (1 - a)
  return out
end

-- rev48-R3 (docs/RAINFX_V2_PHYSICS_AUDIT.md C): spherical-cap volume factor V = K(theta) r^3 of the drawn contact
-- angle. capVolume = false restores the rev7 90 deg hemisphere (2.0944) for A/B comparison.
local function capK(deg)
  local th = math.rad(math.min(math.max(deg, 5), 90))
  local c, s = math.cos(th), math.sin(th)
  return math.pi * (2 - 3 * c + c * c * c) / (3 * s * s * s)
end
local function updateShapeK(p)
  p.shapeK = (p.capVolume ~= false) and capK(p.contactDeg or 60) or 2.0944
  -- rev48-F4: the drop air load is the size law U_c(V) (common r2DropVelocity / physics P.airLoad); R6b's Cd is gone
end

local DQ_NAMES = {}   -- PERF-11: 'gR2DQ' .. i built once (was 16 new strings per pass call)
for i = 0, 15 do DQ_NAMES[i] = 'gR2DQ' .. i end
-- PERF-11 CPU probe (profiler on only): Lua time in sceneValues and in pass submission (updateWithShader) per frame
local SIM_CPU = { sv = 0, run = 0, n = 0 }
-- N1 (section 27): <w> of the nucleation site weight w = ((v - thr) / (1 - thr))^2 over the strong-defect value noise
-- (smoothstep-bilinear of 4 iid uniforms; the hash does not matter for the mean). Monte Carlo once per threshold
-- (thr 0.74 -> 0.0257, 15.3 % of the area > 0; checked against 2 M numpy samples).
local SITE_MEAN = {}
local function siteMean(thr)
  local key = math.floor(thr * 1000 + 0.5)
  local m = SITE_MEAN[key]
  if m then return m end
  local x, n, sum = 12345, 40000, 0
  local function rnd() x = (1103515245 * x + 12345) % 2147483648; return x / 2147483648 end
  for _ = 1, n do
    local a, b, c, d, fx, fy = rnd(), rnd(), rnd(), rnd(), rnd(), rnd()
    local sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    local v = (a * (1 - sx) + b * sx) * (1 - sy) + (c * (1 - sx) + d * sx) * sy
    local e = math.max(0, (v - thr) / math.max(1 - thr, 1e-3))
    sum = sum + e * e
  end
  m = sum / n
  SITE_MEAN[key] = m
  return m
end

-- B1d COATING STATE (docs/RAINFX_V2_TRAIL_REVIEW3.md section 18): values read by tgshared r2CoatFactor (sim passes + visor
-- debug 10). Wear level W: UI value + optional growth per minute of rain; a tear-off resets W, draws a new defect field and
-- clears the wetting memory (field G) for one frame.
local function coatValues(self, v)
  local p = self.p
  v.gR2CoatOn = p.coatOn == false and 0 or 1
  v.gR2CoatSeed = self.coatSeed or 0
  v.gR2CoatWear = math.min(math.max(self.coatWear or p.coatWear or 0, 0), 1)
  v.gR2TestDirt = p.testDirt or 0
  v.gR2DirtMM = p.dirtMM or 3.0
  v.gR2CoatKD, v.gR2CoatKC, v.gR2CoatKM = p.coatKD or 0.5, p.coatKC or 0.5, p.coatKM or 0.4
  v.gR2CoatTauA, v.gR2CoatTauR = p.coatTauA or 1.0, p.coatTauR or 20.0
  v.gR2CoatReset = (self.coatResetFrames or 0) > 0 and 1 or 0
  v.gR2TrailMinMM = p.trailMinMM   -- field: the memory counts trail water from the drawn depth
  v.gR2StrongThr = p.strongThr or 0.74
  v.gR2StrongInvMM = 1.0 / math.max(p.strongMM or 0.4, 0.05)
end

local function sceneValuesImpl(self, v)
  coatValues(self, v)
  -- Shared constant set for P1-P3 (one cbuffer layout; unused entries are harmless).
  local p, st = self.p, self.stats
  v.gR2Cells = self.cells
  v.gR2FieldSize = self.fieldSize
  v.gR2CellMM = self.cellMM
  v.gR2CellSizeMM = self.cellSizeMM
  v.gR2Dt = self.h or 0
  v.gR2Frame = self.frameSeed or 0
  v.gR2Sub = self.sub or 0
  v.gR2SubN = p.substeps or 1                       -- S1: the last substep takes the fine deposit (cells), field clears it
  v.gR2SprayFineOn = p.sprayFine ~= false and 1 or 0
  v.gR2FineMaxMM = 0.01                              -- G scale (mm of water at G = 1); the reservoir stays ~1e-3 of it
  do   -- H1c / H1b haze layer: size, breath-figure saturation depth (phi = hazePhiMax), coalescence nucleus
    local a, phi = p.hazeAMM or 0.015, math.min(p.hazePhiMax or 0.55, 0.95)
    local sat = -math.log(1 - phi) * (p.shapeK or 1) * a / math.pi
    v.gR2HazeSize = self.hazeSize or self.fieldSize
    v.gR2HazeSatMM = sat
    v.gR2HazeAMM, v.gR2HazePhiMax = a, phi            -- H3-3: the haze pass needs the coverage law too (phi(G_f), phi(G_c))
    v.gR2HazeCapMM = 2 * sat
    v.gR2HazeNucOn = p.hazeNuc == false and 0 or 1
    -- H3-3 (docs/RAINFX_V2_H3_ATLAS_SPEC.md 4, 8f): coarse water G_c grows the atlas pieces up to the top octave (area
    -- median a50 at scale 1 <-> G_top = sat x a50 / a_min); a cell drop is born only from the excess above it and only
    -- at a_max or larger (smaller drops are atlas pieces)
    local mic = self.microAtlas and self:microAtlas() or nil
    v.gR2HazeTopMM = sat * ((mic and mic.a50 or 0.212) / a)
    v.gR2MicroCover = mic and mic.cover or 0.76
    v.gR2HazeCoarsenTau = p.hazeCoarsenTau or 0.5
    v.gR2HazeNucVolMM3 = (p.shapeK or 1) * (p.microAMaxMM or 0.3) ^ 3
    v.gR2HazeNucPMax = p.hazeNucPMax or 0.02
    v.gR2HazeNucTau = p.hazeNucTau or 0.3
    v.gR2HazeWetMM = p.hazeWetMM or 0.02              -- S1: water layer (film / sheet / rivulet) that takes the haze in
    v.gR2HazeMinMM = 1e-3 * sat                       -- N3: texels below are skipped by the haze sweep AND the cells take-up
    v.gR2HazeMaskMode = p.hazeMask or 1               -- N3: 0 = 25-record loop | 1 = reach mask | 2 = verify (visor red)
    v.gR2HazeNucSite = p.hazeNucSite == false and 0 or 1   -- N1: nucleate on the J1 strong-defect sites
    v.gR2HazeNucWInv = 1 / math.max(siteMean(p.strongThr or 0.74), 1e-4)
    v.gR2HaloK = p.haloK or 0.5                       -- N2 wipe halo: weight 1 to r + haloIn, 0 at r (1 + haloK) + haloOut
    v.gR2HaloInMM = p.haloInMM or 0.1
    v.gR2HaloOutMM = p.haloOutMM or 0.4
  end
  do   -- micro droplet evaporation: dV/dt = evapDiff r (diffusion-limited), V = shapeK r^3 -> k = evapDiff / (shapeK r^2)
    local rf = p.hazeAMM or 0.015                    -- H1: the micro caps of the haze
    v.gR2FineEvapK = math.min((self.evapDiff or 0) / math.max((p.shapeK or 1) * rf * rf, 1e-6), 5.0)
    self.lastFineEvapK = v.gR2FineEvapK
  end
  v.gR2ObjToWorld = self.objToWorld
  v.gR2AccelW = self.accelW
  v.gR2AirW = self.airW
  v.gR2RainDirW = self.rainDirW
  v.gR2ImpactRate = self.store.freezeRain and 0 or (st.impactRate or 0)
  for i = 0, 15 do v[DQ_NAMES[i]] = (st.dq and st.dq[i + 1]) or 0.3 end   -- rev48-P1 impact diameter inverse CDF
  v.gR2TerminalSpeed = p.terminalSpeed   -- rev48-R4: reference fall speed inside SpeedRel (per-drop V_t(d) replaces it)
  v.gR2SpeedRel = st.speedRel or p.terminalSpeed
  v.gR2SplashK0 = p.splashK0
  v.gR2ResA = p.resA
  v.gR2StickMin = p.stickMin or 0.25
  v.gR2ResB = p.resB
  v.gR2FineRMM = p.fineRMM   -- F9: satellite mist radius
  do   -- S1b spray droplet size distribution: lognormal number DSD (median st.sprayDnMM (SP0), sigma_g sprayDsdSigma)
    local Dn, sg = st.sprayDnMM or p.sprayDiamMM or 0.09, math.max(p.sprayDsdSigma or 2.0, 1.05)
    local sl = math.log(sg)
    local Dmin = (6 * (p.shapeK or 1) / math.pi) ^ (1 / 3) * (p.minRadiusMM or 0.04)   -- sphere whose cap radius = minRadiusMM
    local zmin = math.log(Dmin / Dn) / sl
    local function Phi(z) return 1 / (1 + math.exp(-1.702 * z)) end                    -- same approximation as cells.hlsl
    local mms = self.store.freezeRain and 0 or (st.sprayMMs or 0)
    local EV = math.pi / 6 * Dn ^ 3 * math.exp(4.5 * sl * sl)                          -- mean droplet volume (mm^3)
    local fVis = 1 - Phi(zmin)                                                            -- visible-size count share
    v.gR2SprayVisRate = mms / EV * fVis                                                   -- visible-size droplets / mm^2 / s (events)
    v.gR2SprayVisVolMM3 = st.sprayPieceMM3 or 0                                           -- SP1: mean drawn piece of an event
    self.lastVals = self.lastVals or {}
    self.lastVals.visMMs = v.gR2SprayVisRate * v.gR2SprayVisVolMM3                       -- E2 readout: visible spray water mm/s
    self.lastVals.supFine, self.lastVals.supCoarse = v.gR2SprayFineMMs, v.gR2SprayCoarseMMs   -- E3 haze cap runoff estimate
    v.gR2SprayFineMMs = mms * (st.sprayHazeShare or 0)                                    -- SP1: sub-visible stuck water -> G
    v.gR2HazeOverrun = mms * (st.sprayAperV or 0) * (p.hazeOverrunK or 1.0)              -- I1: lamella overruns / s (x exposure)
    v.gR2SprayCoarseMMs = mms * (st.sprayCoarseShare or 0)                                -- H3-3: pieces < a_max -> G_c (atlas)
    v.gR2MicroSplitMM = p.microSplitMM or 0                                               -- H3-3: cells births only >= this radius
    v.gR2CoarseInRMM = math.max(st.coarseInRMM or 0, p.hazeAMM or 0.015)                  -- H3-3b: arrival size of G_c pieces
    v.gR2SprayLnDn, v.gR2SprayS, v.gR2SprayZmin = math.log(Dn), sl, zmin
    v.gR2SprayDMaxMM = p.sprayDMaxMM or 0.8
  end
  v.gR2SprayVRelK = p.sprayVRelK or 0.8                    -- SP1 spray impact speed / SpeedRel (wake slows the droplets)
  v.gR2RainHazeMMs = self.store.freezeRain and 0 or (st.hazeMMs or 0)   -- H1 rain sub-visible stuck water -> G
  v.gR2FilmCollect = p.filmCollect
  v.gR2ClearMaxMM = p.clearMaxMM
  v.gR2ClearK = p.clearK
  v.gR2DefInvMM, v.gR2DefK, v.gR2DefPin = 1.0 / math.max(p.defMM, 0.05), p.defK, p.defPin   -- rev48-S6 F1
  v.gR2StrongK = p.strongK or 2.0            -- J1 strong defects: pinning x (1 + strongK S)
  v.gR2BLGrowth = p.blGrowth == false and 0 or 1   -- F2a boundary-layer growth from the stagnation point
  v.gR2DynRet = p.dynRet == false and 0 or 1       -- F2b dynamic retention (Cox-Voinov)
  v.gR2PGradK = p.pgradK or 1.0                   -- F3 stagnation pressure-gradient push (x V rho u_e du_e/ds)
  v.gR2StrongThr = p.strongThr or 0.74       -- J1: noise level of a strong defect (0.74 = 15 % of the area)
  v.gR2StrongInvMM = 1.0 / math.max(p.strongMM or 0.4, 0.05)
  v.gR2Escape = p.escape == false and 0 or 1 -- J1: a held drop advances where its contact line is free
  v.gR2TrailFollow = p.trailFollow
  v.gR2Exposure = p.exposure
  v.gR2ExposureFloor = p.exposureFloor
  v.gR2RainSpreadS = math.sin(math.rad(p.rainSpreadDeg))
  v.gR2CrownMM = p.crownMM
  v.gR2CrownBandMM = p.crownBandMM
  v.gR2RainMMs = self.store.freezeRain and 0 or (self.stats.rateMMh or 0) / 3600
  v.gR2RunbackMax = p.runbackMax
  v.gR2ImpactLoss = p.impactLoss
  v.gR2NormalSign = p.normalSign
  updateShapeK(p)
  v.gR2ShapeK = p.shapeK
  v.gR2CapVolume = p.capVolume ~= false and 1 or 0
  v.gR2BigOn, v.gR2BigRMM = p.bigOn and self.BG and 1 or 0, p.bigRMM or 0.8   -- rev48-R7a
  v.gR2ContactDeg = p.contactDeg   -- R3: footprint of the drop cap (R5b: no per-drop spread in the sim)
  v.gR2PinCoat = p.pinCoat
  v.gR2PinGlass = p.pinGlass
  v.gR2PinNoiseMin = p.pinNoiseMin
  v.gR2PinNoiseMax = p.pinNoiseMax
  v.gR2Friction = p.friction
  v.gR2ShedU10, v.gR2ShedBeta = p.shedU10 or 20, p.shedBeta or 0.1   -- rev48-F4
  v.gR2RhoAir = p.rhoAir
  v.gR2AeroWeC = p.aeroWeC or 12          -- M1: aerodynamic breakup Weber number of a drop top (0 = off)
  v.gR2AeroBreakTau = p.aeroBreakTau or 0.05
  v.gR2TurbI = p.turbI or 0.15            -- T1 cockpit turbulence intensity u' / (kU U)
  v.gR2TurbHz = p.turbHz or 4.0           -- T1 frozen-turbulence drift rate
  v.gR2TurbMM = p.turbMM or 15.0          -- T1 eddy size on the visor
  v.gR2AirSurface = p.airSurface
  v.gR2VMax = p.vMax
  v.gR2MotionStretch = p.motionStretch   -- B3c: tailtex measures the tail from the drawn head (r2DrawnRadiiMM rear stretch)
  v.gR2SurfaceTension = p.surfaceTension
  v.gR2PinKinetic = p.pinKinetic
  v.gR2GatherCells = p.gatherCells
  v.gR2LadderMinMM = p.ladderMinMM
  v.gR2LadderMaxMM = p.ladderMaxMM
  v.gR2EvapDiff, v.gR2EvapConv = self.evapDiff or 0, self.evapConv or 0   -- rev48-F5 drop evaporation (fineBudget)
  v.gR2MinRadiusMM = p.minRadiusMM
  v.gR2MaxRadiusMM = p.maxRadiusMM
  v.gR2Spill = p.filmSpill == false and 0 or 1   -- R1 overflow -> film
  v.gR2CoalesceK = p.coalesceK
  v.gR2SweepWidth = p.sweepWidth
  v.gR2FilmDrain = p.filmDrain
  v.gR2FilmCf = p.filmCf
  do   -- FILM S2 (docs/RAINFX_V2_FILM_S2_DESIGN.md): water layer depth, edge-retreat reference width, air shear, substeps
    v.gR2FilmWetMM = p.hazeWetMM or 0.02           -- film = water >= this (the haze pass's water-layer depth, S1)
    v.gR2FilmRefWMM = p.filmRefWMM or 5.0          -- body width in the dewetting / fed law (log term; lamella-patch scale)
    v.gR2FilmJoinMM = p.filmJoinMM or 0.10         -- F1: a drop joins only a real (visible) film ...
    v.gR2FilmThickMM = p.filmThickMM or 0.30       -- F1/F3: ... that stays thin; a cell film this thick becomes a drop
    local ue = self.aeroU or 0
    local tauPa = 0.5 * 1.2 * (p.filmCf or 0.005) * ue * ue      -- air shear (Pa) for the substep count only
    -- substeps: Courant <= 1 at the speed of a 0.3 mm film (shear + gravity), even, 2..4
    local vmax = 0.5 * tauPa * 0.3 + 3.27 * 0.09
    local cour = vmax * 1000 * (self.frameDt or 1 / 60) / (602.0 / p.fieldU)
    self.filmSub = math.min(4, math.max(2, 2 * math.ceil(math.min(cour, 4) / 2)))
  end
  v.gR2FilmFlowK = p.filmFlowK
  v.gR2FilmMaxMM = p.filmOn and p.filmStoreMaxMM or p.filmMaxMM   -- rev48-W1: B holds the sheet (up to 2 mm)
  v.gR2FilmOn = p.filmOn and 1 or 0
  v.gR2FilmRecedeDeg = p.filmRecedeDeg or 50
  v.gR2GrowTime = p.growTime   -- rev48-W1t: cells uses it for patch beads (was a visor-only value)
  v.gR2FilmFollowK = p.filmFollowK or 0.5
  v.gR2FilmDt = (self.frameDt or 1 / 60) / math.max(self.filmSub or 2, 1)   -- the film call sets frameDt / substeps
  v.gR2FilmRate = self.store.freezeRain and 0 or (st.filmRate or 0)
  v.gR2FilmMinMM = p.filmOn and p.filmDrawMinMM or p.filmMinMM   -- rev48-W1e: with the sheet on only a sheet shows
  do   -- E1 / F6' (docs/RAINFX_V2_FILM_S2_DESIGN.md section 10): film supply vs the fed limit (r2FedRate, the edge-retreat law)
    local function fedMMs(h)   -- supply (mm/s) that holds a layer of depth h (body width filmRefWMM) against its edges' retreat
      local wet = math.min(h / math.max(p.filmFullMM or 0.2, 1e-4), 1)
      local th = math.rad(p.trailThetaRDeg or 40) * (1 - (p.trailWetK or 0.35) * wet)
      local W = v.gR2FilmRefWMM or 5
      return h * 2 * (72000 * th ^ 3 / (9 * math.log(math.max(W * 1e6, 10)))) / W
    end
    local q = ((v.gR2FilmRate or 0) + (v.gR2SprayFineMMs or 0) + (v.gR2RainHazeMMs or 0) + (v.gR2SprayCoarseMMs or 0)) * (p.exposure or 1)
    local qf = fedMMs(v.gR2FilmWetMM or 0.02)
    self.e1 = { q = q, qFed = qf, qVis = fedMMs(v.gR2FilmJoinMM or 0.1) }
    v.gR2FilmTile = 0                                                             -- F4c: set by the film call (block summary)
  end
  v.gR2BeadMoveRMM = (p.beadDrops ~= false and self.beadMoveR) or 1e3   -- B2: bead radius that moves (P.criticalRadius)
  -- rev40 size mix, stagnation turbulence, size histogram
  local fl = fragLaw(p, self.frag or {})
  self.frag = fl
  v.gR2FragLoP = fl.loP
  v.gR2FragHiP = fl.hiP
  v.gR2FragInvA = fl.invA
  v.gR2FragM3 = fl.m3
  v.gR2HazeNucM3Inv = 1 / math.max(fl.m3, 1e-3)      -- N1: nucleus radius fineNucRMM x X -> mean volume V_nuc <X^3>
  v.gR2Time = self.wobbleT or 0
  v.gR2SizeBin0MM = p.sizeBin0MM
  v.gR2FilmFullMM = p.filmFullMM
  v.gR2WetHaze = p.wetHaze
  v.gR2TrailMaxMM = p.trailMaxMM
  v.gR2TrailEvapMMs = p.trailEvapMMs
  v.gR2TrailWidthK = p.trailWidthK
  v.gR2PearlMM = p.pearlMM
  v.gR2PearlRate = p.pearlRate
  v.gR2TrailSlopeMax = p.trailSlopeMax
  v.gR2ShpOn = p.shpOn and 1 or 0
  v.gR2ShpDefShape = p.shpDefShape or 1.0   -- rev48-R5: birth contour from the defect field (bend / lobe / sag classes removed)
  v.gR2ShpRelaxMove, v.gR2ShpRelaxStill = p.shpRelaxMove, p.shpRelaxStill
  v.gR2ShpMergeK, v.gR2ShpWaist = p.shpMergeK, p.shpWaist
  v.gR2ShpMergeTau = p.shpMergeTau or 0.015
  v.gR2Steep = p.steep ~= false and 1 or 0   -- R-steep: arrested / merged drops recede to the cap
  v.gR2ShpMotionK, v.gR2ShpMotionV = p.shpMotionK, p.shpMotionV
  v.gR2ShpBoK, v.gR2ShpTearK = p.shpBoK, p.shpTearK
  v.gR2ShpSlugTau, v.gR2ShpAirK, v.gR2ShpAirMax = p.shpSlugTau, p.shpAirK, p.shpAirMax
  v.gR2ShpTailTau, v.gR2ShpTailStretch, v.gR2ShpHookK, v.gR2ShpSnapDeg = p.shpTailTau, p.shpTailStretch, p.shpHookK, p.shpSnapDeg   -- rev48-S6 F2
  v.gR2ShpSplitA, v.gR2ShpSplitRate, v.gR2ShpSplitRMin = p.shpSplitA, p.shpSplitRate, p.shpSplitRMin   -- rev48-S6c E8
  v.gR2FootPhys = p.footPhys and 1 or 0
  v.gR2FootPinK = p.footPinK
  v.gR2BaseSpread = p.baseSpread
  v.gR2ShpImpactK, v.gR2ShpImpactMax = p.shpImpactK, p.shpImpactMax
  v.gR2ShpSkidK, v.gR2ShpSkidMax = p.shpSkidK, p.shpSkidMax
  v.gR2ShpSpreadMin, v.gR2ShpSpreadMax, v.gR2ShpLamShift = p.shpSpreadMin, p.shpSpreadMax, p.shpLamShift
  v.gR2ShpRecoilC = p.shpRecoilC   -- rev48-R1: recoil tau = C sqrt(rho r^3 / gamma) (r2Predict ramp / walk)
  v.gR2TrailThetaRDeg = p.trailThetaRDeg
  v.gR2TrailWetK = p.trailWetK
  v.gR2TailOn = p.tailOn == false and 0 or 1                     -- B1 drop tails (S quarter 3)
  v.gR2TailNeckRho = p.tailNeckRho or 0.75                        -- L2b: the tail rises out of the head cap at rho_n x its radius
  v.gR2TailNeckDeg = (p.contactDeg or 58) - 0.5 * (p.hysteresisDeg or 20)   -- L2b: the head's rear rim angle
  v.gR2TailWidthK = p.tailWidthK or 0.6                           -- B3c: rivulet half-width 0.5 K W sqrt(1 - 1/s), W = drawn head half-width
  v.gR2TailK, v.gR2TailMax, v.gR2TailTau = p.tailK or 4, p.tailMax or 20, p.tailTau or 0.1
  v.gR2TrailLL = p.trailLL
  v.gR2TrailPinMM = p.trailPinMM
  v.gR2TrailFlowK = p.trailFlowK
  v.gR2FilmBeadMM = p.filmBeadMM
  v.gR2DewetRate = p.dewetRate
  v.gR2FrameDt = self.frameDt or 1 / 60
  v.gR2FadeTime = p.fadeTime
  v.gR2FragMax = p.fragMax
  v.gR2AeroDirW = self.aeroDir or vec3(0, 0, -1)
  v.gR2AeroU = self.aeroU or 0
  v.gR2AeroDuDs = self.aeroDuDs or 0
  v.gR2BLDeltaMM = self.aeroDelta or 50
  v.gR2DropTau = p.dropTau
  v.gR2SimDt = self.frameDt or (1 / 60)
  v.gR2ClusterK = p.clusterK
  if not self.clusterScale or self.clusterMM ~= p.clusterMM then
    self.clusterMM = p.clusterMM
    self.clusterScale = vec2(602.0 / p.clusterMM, 146.3 / p.clusterMM)
  end
  v.gR2ClusterScale = self.clusterScale
  if not self.pinScale or self.pinMM ~= p.pinMM then
    self.pinMM = p.pinMM
    self.pinScale = vec2(602.0 / p.pinMM, 146.3 / p.pinMM)
  end
  v.gR2PinScale = self.pinScale
  return v
end

local function sceneValues(self, v)
  if not (RV_PROF and RV_PROF.on) then return sceneValuesImpl(self, v) end
  local t0 = os.preciseClock()
  local r = sceneValuesImpl(self, v)
  SIM_CPU.sv = SIM_CPU.sv + (os.preciseClock() - t0) * 1000
  return r
end

local PASS_NAMES = setmetatable({}, { __mode = 'k' })   -- PERF-2: pass table -> Render Stats name (kept out of the params)
-- PERF-5 TEXTURE BUDGET: CSP's ui.fx template (scene include) reserves t14 for its shadow array -> a simulation pass may
-- bind at most 14 textures (t0..t13), and this shared table has exactly 14. Adding one more rebinds the shadow array
-- for the draws that follow (PERF-4: E7 glitch). docs/tools/check_rainfx2_shaders.py reads this table and fails then.
local function newPass(self, shader, name, haze)   -- haze: true = cells / hzv, 'hzm' = hzm, 'mask' = the haze pass
  local root = self.ctx.surface.root
  local pass = {
    async = true,
    blendMode = render.BlendMode.Opaque,
    textures = { txR2State = false, txR2Field = false, txR2Claim = false, txR2Trail = false,
      txR2FieldOld = false, txR2FilmK = false, txR2Lam = false,   -- F_prev of last frame (merge: S2 film join), film coefficients (S2), impact registry (U1)
      txR2Big = false,   -- rev48-R7a big-drop tiles
      txR2Pred = false,  -- PERF-3 per-drop prediction (predict.hlsl -> cells)
      txR2Du = root .. 'du.dds', txR2Dv = root .. 'dv.dds', txR2Mask = self.ctx.maskPath },
    values = sceneValues(self, {}),
    shader = shader,
  }
  if haze then   -- H1c: cells / haze bind the haze layer in the claims slot (claims are merge-only) -> still 14 textures
    pass.textures.txR2Claim = nil
    pass.textures.txR2Haze = false
  end
  if haze == 'mask' then   -- N3: the haze pass binds its cell data in the prediction slot (predict -> cells only) -> 14
    pass.textures.txR2Pred = nil
    pass.textures.txR2HzMask = false
    pass.textures.txR2Big = nil      -- T1: the substep wipe mask in the big-drop slot (visor only) -> still 14
    pass.textures.txR2Wm = false
  elseif haze == 'hzm' then   -- H3-P2: hzm binds the static validity class in the prediction slot -> 14
    pass.textures.txR2Pred = nil
    pass.textures.txR2HzValid = false
  end
  if haze == 'film' then   -- F4c: the film transport reads the F4b block summary in the claims slot -> 14
    pass.textures.txR2Claim = nil
    pass.textures.txR2FilmAny = false
  end
  if haze == 'wm' then   -- T1: the substep wipe mask reads its previous substep in the prediction slot -> 14
    pass.textures.txR2Pred = nil
    pass.textures.txR2Wm = false
  end
  if name then PASS_NAMES[pass] = 'RainFX2 sim/' .. name end
  return pass
end

-- FILM-UNIFY A (docs/RAINFX_V2_FILM_UNIFY_PLAN.md section 1): one surface. The coat's receding angle theta_r drives the trail
-- threshold / drop dynamic retention (trailThetaRDeg), the sheet meniscus / thin-film rate (filmRecedeDeg) and, with the
-- fitted Furmidge contact-angle hysteresis dcos = pinCoat (drop depinning, F4b), the advancing angle
-- theta_a = acos(cos theta_r - pinCoat) -> hysteresisDeg = theta_a - theta_r (sheet fronts).
function R2:syncSurface()
  local p = self.p
  local th = p.surfThetaRDeg or 40
  p.trailThetaRDeg, p.filmRecedeDeg = th, th
  local ca = math.cos(math.rad(th)) - (p.pinCoat or 0.18)
  p.hysteresisDeg = math.deg(math.acos(math.max(math.min(ca, 1), -1))) - th
end

function R2:enabled()
  return self.store.enabled and not self.err
end

function R2:ensureResources()
  if self.ready then return true end
  local p = self.p
  local none = render.AntialiasingMode.None
  local function canvas(w, h, mips, fmt, name)
    local c = ui.ExtraCanvas(vec2(w, h), mips, none, fmt)
    c:setName(name)
    c:clear(rgbm(0, 0, 0, 0))
    return c
  end
  local f32 = render.TextureFormat.R32G32B32A32.Float
  local u16 = render.TextureFormat.R16G16B16A16.UNorm
  -- rev45: twice the cell width, right half = per-drop life cycle (age, flight, fade, direction)
  -- rev48-S1: three cell widths [drop | life | shape state]
  -- B1 (docs/RAINFX_V2_TRAIL_REVIEW3.md section 11): + tail quarter [drop | life | shape | tail]
  self.S = { canvas(4 * p.cellsU, p.cellsV, 1, f32, 'RainFX2 cells A'), canvas(4 * p.cellsU, p.cellsV, 1, f32, 'RainFX2 cells B') }
  self.C = canvas(p.cellsU, p.cellsV, 1, render.TextureFormat.R16G16B16A16.Float, 'RainFX2 claims')
  -- rev48-F8 (F7 review: a background of motionless droplets built up whenever intensity > 0, faster at speed): the field was
  -- R16G16B16A16 UNORM -- one step 1/65535 of fineMaxMM. A multiplicative loss per frame (fine evaporation 0.14 %/frame at
  -- tau 12 s) rounds back to the same value below ~360 steps (G < 0.0055: 8 % of the 0.6 mm micro-grid drawn as droplets),
  -- so the fine water never left; the semi-Lagrangian fine transport rounded fractional inflow UP on empty texels (mass
  -- created along the flow, more at speed). 32-bit float field: decays / transports to zero (12 MB for the 3 targets).
  self.F = { canvas(p.fieldU, p.fieldV, 1, f32, 'RainFX2 field A'), canvas(p.fieldU, p.fieldV, 1, f32, 'RainFX2 field B') }
  -- rev48-W1: sheet substeps ping-pong between the new field and this scratch (the previous field stays intact
  -- for the merge pass of the next frame = txR2FieldOld); sheet velocity coefficients once per frame
  self.SK = canvas(p.fieldU, p.fieldV, 1, f32, 'RainFX2 film coef')
  self.FS = canvas(p.fieldU, p.fieldV, 1, f32, 'RainFX2 film scratch')   -- FILM S2-1 transport ping-pong
  -- rev48-W1d: nucleation mask per cell (made on S_next; read by this frame's field and next frame's merge)
  -- rev48-W1q: lamella registry per cell (birth frame), ping-pong
  self.LM = { canvas(p.cellsU, p.cellsV, 1, f32, 'RainFX2 lamella A'), canvas(p.cellsU, p.cellsV, 1, f32, 'RainFX2 lamella B') }
  self.li = 1
  -- rev48-R7a big-drop tiles (4 x 4 cells -> the largest drop, drawn / touching in a +-4 cell window)
  self.BG = canvas(math.ceil(p.cellsU / 4), math.ceil(p.cellsV / 4), 1, f32, 'RainFX2 big drops')
  self.TT = canvas(math.floor(p.fieldU / 2), math.floor(p.fieldV / 2) + math.ceil(p.cellsV / 4), 1, f32, 'RainFX2 tail raster')   -- B3g: + one TP row per big-drop tile row (tail constants)   -- B3a: half the field   -- B2 (tailtex.hlsl): the visor draws the drop tails from it
  -- rev47j trail geometry (line point / direction / half-width per field texel)
  local h16 = render.TextureFormat.R16G16B16A16.Float
  self.TG = { canvas(p.fieldU, p.fieldV, 1, f32, 'RainFX2 trail A'), canvas(p.fieldU, p.fieldV, 1, f32, 'RainFX2 trail B') }   -- TR0: packed tag / depth (RGBA32F)
  self.ti = 1
  -- H1c haze layer (2x the field: 0.29 mm texels), G in units of fineMaxMM, ping-pong
  local hr = math.max(1, math.floor(p.hazeRes or 2))
  self.hazeSize = vec2(p.fieldU * hr, p.fieldV * hr)
  self.HZ = { canvas(p.fieldU * hr, p.fieldV * hr, 1, render.TextureFormat.R16G16.Float, 'RainFX2 haze A'),   -- H3-3: R fine, G coarse
              canvas(p.fieldU * hr, p.fieldV * hr, 1, render.TextureFormat.R16G16.Float, 'RainFX2 haze B') }
  self.hi = 1
  self.HZM = canvas(p.cellsU, p.cellsV, 1, f32, 'RainFX2 haze reach mask')   -- N3 (hzm.hlsl)
  self.HZV = canvas(p.cellsU, p.cellsV, 1, render.TextureFormat.R16.Float, 'RainFX2 haze validity')   -- H3-P2 (hzv.hlsl, once)
  self.WM = { canvas(p.cellsU, p.cellsV, 1, f32, 'RainFX2 haze wipe mask A'), canvas(p.cellsU, p.cellsV, 1, f32, 'RainFX2 haze wipe mask B') }   -- T1 (wm.hlsl)
  self.wmi, self.wmValid = 1, false
  self.hzvValid = false
  self.si, self.fi = 1, 1
  self.cells = vec2(p.cellsU, p.cellsV)
  self.fieldSize = vec2(p.fieldU, p.fieldV)
  self.accelW, self.airW, self.rainDirW = vec3(0, -9.81, 0), vec3(), vec3(0, -1, 0)
  self.objToWorld = mat4x4.identity()
  -- Mesh metric (measured from du/dv, docs/RAINFX_V2_KICKOFF.md 2.2): median 0.602 m/U, 0.146 m/V.
  self.cellSizeMM = vec2(602.0 / p.cellsU, 146.3 / p.cellsV)
  self.cellMM = (self.cellSizeMM.x + self.cellSizeMM.y) * 0.5
  self.texMM = vec2(602.0, 146.3)
  self.passCells = newPass(self, self.src.cells, 'cells', true)
  self.passHzm = newPass(self, self.src.hzm, 'hzm', 'hzm')     -- N3 reach mask + N1 nucleus ratio
  self.passHzv = newPass(self, self.src.hzv, 'hzv', true)      -- H3-P2 static validity class
  self.passHaze = newPass(self, self.src.haze, 'haze', 'mask')   -- H1c
  self.passWm = newPass(self, self.src.wm, 'wm', 'wm')           -- T1 substep wipe mask
  self.passPredict = newPass(self, self.src.predict, 'predict')   -- PERF-3
  self.PR = canvas(3 * p.cellsU, p.cellsV, 1, f32, 'RainFX2 drop prediction')
  self.REC = canvas(6 * p.cellsU, p.cellsV, 1, f32, 'RainFX2 drop records')   -- PERF-9 visor candidates (rec.hlsl)
  self.MSK = canvas(p.cellsU, p.cellsV, 1, render.TextureFormat.R32G32.Float, 'RainFX2 candidate mask')   -- PERF-10 (msk.hlsl)
  self.passField = newPass(self, self.src.field, 'field')
  self.passFilmK = newPass(self, self.src.filmcoef, 'filmcoef')
  self.passFilm = newPass(self, self.src.film, 'film', 'film')    -- FILM S2-1 (F4c: block summary bound)
  self.passLam = newPass(self, self.src.lam, 'lam')               -- rev48-W1q
  self.passTrail = newPass(self, self.src.trail, 'trail')
  self.passClaim = newPass(self, self.src.claim, 'claim')
  self.passMetrics = newPass(self, self.src.metrics, 'metrics')
  self.passFilmAny = newPass(self, self.src.filmany, 'filmany')   -- F4b
  self.FAc = canvas(32, 8, 1, render.TextureFormat.R8G8B8A8.UNorm, 'RainFX2 film gate')
  self.Mc = canvas(32, 8, 1, render.TextureFormat.R8G8B8A8.UNorm, 'RainFX2 metrics')
  self.passAudit = newPass(self, self.src.audit, 'audit', true)   -- E3 mass audit (haze in the claims slot)
  self.AUc = canvas(160, 8, 1, f32, 'RainFX2 mass audit')   -- E3 (x < 96) + E4 tails (96..159)
  self.passSizes = newPass(self, self.src.sizes, 'sizes')
  self.Hc = canvas(10, 16, 1, render.TextureFormat.R8G8B8A8.UNorm, 'RainFX2 size histogram')
  self.passMerge = newPass(self, self.src.merge, 'merge')
  self.passBig = newPass(self, self.src.big, 'big')              -- rev48-R7a
  self.passTailTex = newPass(self, self.src.tailtex, 'tailtex')  -- B2 tail raster (TT)
  self.ready = true
  return true
end

function R2:ensureMesh()
  if self.mesh then return true end
  local target = self.ctx.targetMesh()
  if not target or #target == 0 then self.status = 'GLASS_RAINFX mesh not found'; return false end
  local vertices, indices = target:getVertices(), target:getIndices()
  local parent = target:getParent()
  if not vertices or not indices or #vertices == 0 or #indices < 3 or not parent or #parent == 0 then
    self.status = 'GLASS_RAINFX geometry unavailable'; return false
  end
  local stale = parent:findNodes(MESH_NAME)
  if stale and #stale > 0 then stale:dispose() end
  local offset = self.ctx.surfaceOffset or 0
  local vb = ac.VertexBuffer(#vertices)
  for i = 1, #vertices do
    local s = vertices:get(i)
    vb:set(i, ac.MeshVertex.new(s.pos + s.normal * offset, s.normal, s.uv))
  end
  local ib = ac.IndicesBuffer(#indices)
  for i = 1, #indices do ib:set(i, indices:get(i)) end
  self.mesh = parent:createMesh(MESH_NAME, nil, vb, ib, false, false)
  if not self.mesh then self.status = 'createMesh failed'; return false end
  self.mesh:setVisible(false, false)
  self.mesh:setShadows(false)
  self.target = target
  return true
end

-- World-space inputs. Local->world happens in the shaders with the mesh matrix,
-- exactly like the verified legacy solver (mul(v, (float3x3)M), CSP transposes for HLSL).
-- rev47 JOLT (docs/RAINFX_V2_REV46_REVIEW.md sections 4, 7.1): the helmet feels the car acceleration
-- (car.acceleration, G, car axes -> world) plus the head motion relative to the car (second difference
-- of the visor world position minus the car part, clamped), low-pass filtered like the neck does
-- (2nd order, neckHz / neckZeta, per world axis). Gravity is added after the filter.
function R2:filterAccel(sim, inp)
  local p = self.p
  local dt = math.min(sim.dt or 0, 1 / 20) * (self.timeScale or 1)
  local raw = inp.carAccW or vec3()
  local pos = self.objToWorld:transformPoint(vec3(0, 0, 0))
  local head = vec3()
  local h = self.headHist
  if dt > 0 and h and h.dt1 and h.dt1 > 0 and (pos - h.p1):length() < 1.0 then
    local v1 = (pos - h.p1) / dt
    local v0 = (h.p1 - h.p0) / h.dt1
    head = (v1 - v0) / (0.5 * (dt + h.dt1)) - raw
    local hl = head:length()
    local maxA = p.headAccMaxG * 9.81
    if hl > maxA then head = head * (maxA / hl) end
  end
  if dt > 0 then
    self.headHist = { p0 = h and h.p1 or pos, p1 = pos, dt1 = dt }
  end
  local u = raw + head * p.headAccK
  local f = self.accFilt
  if not f then f = { x = vec3(u.x, u.y, u.z), v = vec3() }; self.accFilt = f end
  if dt > 0 then
    local w = 2 * math.pi * math.max(p.neckHz, 0.1)
    local n = math.max(1, math.ceil(w * dt / 0.3))
    local h2 = dt / n
    for _ = 1, n do
      local acc = (u - f.x) * (w * w) - f.v * (2 * p.neckZeta * w)
      f.v = f.v + acc * h2
      f.x = f.x + f.v * h2
    end
  end
  inp.accRawG = (u:length()) / 9.81
  inp.accFiltG = f.x:length() / 9.81
  inp.accelW = vec3(0, -9.81, 0) - f.x
  inp.accelG = inp.accelW:length() / 9.81
end

-- rev47 AERO: stagnation direction (relative air, tilted by the stagnation elevation about the helmet
-- side axis (rev47g: visor transform, not the camera), plus a smooth buffeting wander), outer-flow scale and boundary-layer thickness.
function R2:aeroInputs(sim, air)
  local p, P = self.p, self.physics
  local U = air:length()
  local ah = U > 1e-3 and air / U or vec3(0, 0, -1)
  -- rev47g: helmet axes from the VISOR world transform only (user: camera presets move independently of
  -- the visor; the camera must not enter the force model). up = visor local +Y in world, side = up x air.
  -- rev47i (rev47g review: drops fanned out from the bottom, no downward flow): the visor local +Y is
  -- not the helmet up for this KN5 (axis-correction profile). The helmet-up axis is picked once from the
  -- visor transform: the local axis (+-X, +-Y, +-Z) whose world image best matches world up while the
  -- driver is upright (re-picked after a reset / profile change). It then rotates with the visor.
  if not self.helmetUpLocal then
    local best, bd = vec3(0, 1, 0), -2
    for _, ax in ipairs({ vec3(1,0,0), vec3(-1,0,0), vec3(0,1,0), vec3(0,-1,0), vec3(0,0,1), vec3(0,0,-1) }) do
      local w = self.objToWorld:transformVector(ax)
      local l = w:length()
      local dd = l > 1e-9 and w.y / l or -2
      if dd > bd then best, bd = ax, dd end
    end
    self.helmetUpLocal = best
  end
  local up = self.objToWorld:transformVector(self.helmetUpLocal)
  local ul = up:length()
  up = ul > 1e-6 and up / ul or vec3(0, 1, 0)
  local side = vec3(up.y * ah.z - up.z * ah.y, up.z * ah.x - up.x * ah.z, up.x * ah.y - up.y * ah.x)
  local sl = side:length()
  side = sl > 1e-6 and side / sl or vec3(1, 0, 0)
  local t = self.wobbleT or 0
  local amp = math.rad(p.buffetDeg) * math.min(U / 69.4, 1.5)
  local w = 2 * math.pi * p.buffetHz
  local yaw = amp * (0.6 * math.sin(w * t) + 0.4 * math.sin(2.31 * w * t + 1.3))
  local pitch = amp * (0.6 * math.sin(1.37 * w * t + 0.7) + 0.4 * math.sin(2.9 * w * t + 2.1))
  local e = math.rad(p.stagElevDeg) + pitch
  -- stagnation normal tilted up by e  <->  oncoming air tilted down
  local a1 = ah * math.cos(e) - up * math.sin(e)
  a1 = a1 * math.cos(yaw) + side * math.sin(yaw)
  local al = a1:length()
  a1 = al > 1e-6 and a1 / al or ah
  self.helmetUpY = up.y                         -- UI check: ~1 when the visor local +Y is the helmet up
  if not self.aeroDir then self.aeroDir = vec3() end
  self.aeroDir:set(a1.x, a1.y, a1.z)
  local ue, a, delta = P.aeroScales(p, U)
  self.aeroU, self.aeroDuDs, self.aeroDelta = ue, a, delta
end

-- rev48-F3/F5 DROP EVAPORATION (F9: the fine layer is gone; this is the entity drops' law, cells r2Predict): a sessile cap of
-- radius r loses dV/dt = 4 r D drho / rho_w (diffusion-limited, Picknett & Bexon 1977) plus the forced convection of the
-- helmet stagnation layer h_m = 0.57 Sc^0.4 D sqrt(a / nu) on its wetted area; drho = rho_sat(T) (1 - RH),
-- RH / T = CSP ac.getAirHumidity / ambientTemperature (also the F6 sub-cloud evaporation).
function R2:fineBudget(sim)
  local p = self.p
  local T = sim.ambientTemperature or 20
  if self.store.airTFix then T = self.store.airTFixC end   -- M-REF: replays do not record the air temperature
  self.cspT = sim.ambientTemperature
  local okH, hum = pcall(ac.getAirHumidity, sim.cameraPosition or vec3())
  local RH = math.min(math.max(okH and hum or 0.6, 0), 0.995)   -- F4 (user): CSP humidity as given (weather profile)
  local rhoSat = 611.2 * math.exp(17.67 * T / (T + 243.5)) / (461.5 * (T + 273.15))   -- kg/m^3
  local drho = rhoSat * (1 - RH)
  local D, nu = 2.5e-5, 1.5e-5
  local a = math.max(self.aeroDuDs or 0, 0)
  local hm = 0.57 * 0.6 ^ 0.4 * D * math.sqrt(a / nu) + 0.005                          -- + natural convection floor
  self.evapDiff = 4 * D * drho / 1000 * 1e6          -- mm^2/s: dV/dt = evapDiff r (mm^3/s, r in mm)
  self.evapConv = (hm - 0.005) * drho / 1000 * 1000   -- mm/s on the wetted area (forced part; still-air part = evapDiff)
  self.fineRH, self.fineT = RH, T
end

function R2:updateInputs(sim)
  self.objToWorld = self.target:getWorldTransformationRaw():clone()
  if self.p.windDirOffsetDeg == nil then self.p.windDirOffsetDeg = self.store.windDirOffsetDeg end
  local inp = self.physics.inputs(sim, self.p, self.inp)
  if inp.windCalibrated then
    self.windCalT = (self.windCalT or 0) + (sim.dt or 0)
    if self.windCalT > 2 then                        -- persist after 2 s of live wind
      self.store.windDirOffsetDeg, self.store.windDirCalibrated = inp.windCalibrated, true
      self.windCalT = 0
    end
  end
  self.inp = inp
  local accel, air, rainVel, speedRel = inp.accelW, inp.airW, inp.rainVel, inp.speedRel
  self:filterAccel(sim, inp)
  accel = inp.accelW
  self.accelW:set(accel.x, accel.y, accel.z)
  self:aeroInputs(sim, air)
  self:fineBudget(sim)
  self.airW:set(air.x, air.y, air.z)
  self.rainDirW:set(rainVel.x / math.max(speedRel, 1e-6), rainVel.y / math.max(speedRel, 1e-6), rainVel.z / math.max(speedRel, 1e-6))
  local up = sim.cameraUp or vec3(0, 1, 0)
  local side = sim.cameraSide or vec3(1, 0, 0)
  local su = vec2(side.y, -up.y)
  local sl = math.sqrt(su.x * su.x + su.y * su.y)
  self.screenUp = sl > 1e-3 and vec2(su.x / sl, su.y / sl) or vec2(0, -1)
  local p = self.p
  -- rev48-P2 ROAD SPRAY (spray.lua): LWC of the fine spray cloud at the helmet (g/m^3) -> water flux on the visor
  -- = LWC x the helmet's speed through the cloud x impingement (90 um drops: Stokes ~10 at speed, eta ~0.9); the
  -- ballistic tread drops (1-4 mm, only close behind) join the raindrop supply as rare big impacts (weather.lua)
  p.wheelProbe = (self.store.metrics or self.recording) and true or false   -- PUD-1: car scan for the probe only when measuring
  p.roadFixWater = self.store.roadFix and self.store.roadFixWater or nil   -- M-REF3: reference road state for spray
  p.roadFixWet = self.store.roadFix and self.store.roadFixWet or nil
  local spray, info = self.spray.estimate(sim, p, self.sprayInfo)
  self.sprayInfo = info
  spray = spray * p.sprayK
  local vOwn = math.max(inp.carSpeed or 0, 1)
  -- SP0 (docs/RAINFX_V2_SPRAY_RAIN_REF.md section 17): tyre spray is torn as it is made -- water thrown off the tread at road
  -- speed into air moving at ~the car speed breaks until the aerodynamic Weber number rho_a v^2 d / gamma <= 12 (Pilch &
  -- Erdman 1987: a free drop in a gas stream, here it applies). Number median = sprayAeroC x that largest stable size
  -- (0.39: 0.09 mm at 200 km/h = the measured 70-90 um road spray), at most the source size sprayDMaxMM at low speed.
  local DnS = p.sprayDiamMM or 0.09
  if p.sprayAeroDn ~= false then
    DnS = math.min(math.max((p.sprayAeroC or 0.39) * 12 * 0.072 / (1.2 * vOwn * vOwn) * 1000, 0.02), p.sprayDMaxMM or 0.8)
  end
  local dS = DnS * 1e-3
  local stS = 1000 * dS * dS * vOwn / (18 * 1.8e-5 * 0.13)
  local etaS = (stS / (stS + 0.25)) ^ 2
  local sprayMMs = spray * 1e-3 * vOwn * etaS                -- g/m^3 -> m^3/m^3 (1e-6) x m/s -> mm/s (1e3)
  local splashMMs = (info.splash or 0) * p.sprayLWC0 * p.sprayK * 1e-3 * vOwn * p.splashShare
  local intensity = self.store.intensityFix and self.store.intensityFixV or sim.rainIntensity   -- M-REF2: measurement override
  self.weather.compute({ rainIntensity = intensity, weatherType = sim.weatherType, speedRel = speedRel,
                         splashMMs = splashMMs, airT = self.fineT, airRH = self.fineRH, p = p }, self.stats)
  self.stats.speedRel = speedRel
  local st = self.stats
  st.spray, st.sprayMMs, st.splashMMs = spray, sprayMMs, splashMMs
  -- SP1 / H1: the spray droplets' impact outcome in expectation (same law as cells.hlsl, W.impactKeep): over the lognormal
  -- (median DnS, sigma_g sprayDsdSigma, <= sprayDMaxMM) -> the mean drawn piece of a visible-size event (cells) and the
  -- stuck water in sub-visible fragments (-> haze G); the splashed rest leaves with the air.
  do
    local sl = math.log(math.max(p.sprayDsdSigma or 2.0, 1.05))
    local dMax = p.sprayDMaxMM or 0.8
    local Dmin = (6 * (p.shapeK or 1) / math.pi) ^ (1 / 3) * (p.minRadiusMM or 0.04)
    local vI = math.max(speedRel * (p.sprayVRelK or 0.8) * (p.hazeExpo or 0.9), 0.3)
    local EV, Es, Ec, Er, nV, epV, wS, EA = 0, 0, 0, 0, 0, 0, 0, 0
    -- H3-3: with the micro-drop atlas, drawn pieces below a_max are atlas water (haze G_c), only larger ones cell drops
    p.microSplitMM = (self.p.microOn ~= false and self.microAtlas and self:microAtlas()) and (p.microAMaxMM or 0.3) or 0
    for i = 1, 24 do
      local z = -3.5 + (i - 0.5) * 7 / 24
      local w = math.exp(-0.5 * z * z)
      local d = math.min(DnS * math.exp(sl * z), dMax)
      local _, eK, hK, eS, eR = self.weather.impactKeep(d, vI, p)
      EV = EV + w * math.pi / 6 * d * d * d
      Es, Ec, Er, wS = Es + w * hK, Ec + w * (eS or 0), Er + w * (eR or 0), wS + w
      -- I1 (H3 spec 8l): impact lamella area, beta_max = 0.87 Re^0.2 - 0.40 Re^0.4 We^-0.5 (Roisman 2009), d in mm
      local Re, We = 1000 * vI * d, 1000 * vI * vI * d * 1e-3 / 0.072
      local bm = math.max(0.87 * Re ^ 0.2 - 0.40 * Re ^ 0.4 * We ^ -0.5, 1.0)
      EA = EA + w * math.pi / 4 * (bm * d) ^ 2
      if d >= Dmin then nV, epV = nV + w, epV + w * (eK - (eS or 0)) end
    end
    st.sprayDnMM = DnS
    st.sprayHazeShare = EV > 0 and Es / EV or 0
    st.sprayAperV = EV > 0 and EA / EV or 0                      -- I1: lamella area per mm^3 of impacting spray (/mm)
    st.sprayCoarseShare = EV > 0 and Ec / EV or 0                -- H3-3: small drawn pieces -> atlas water G_c
    -- H3-3b: their volume-weighted radius = the size at which coarse water ARRIVES (smoothed, ~3 s: the coat keeps its
    -- pieces when the spray changes); coverage / size of G_c follow the cap law at max(arrival, saturation) size
    local aIn = Ec > 0 and Er / Ec or (p.hazeAMM or 0.015)
    local kS = 1 - math.exp(-(self.frameDt or 1 / 60) / 3.0)
    st.coarseInRMM = (st.coarseInRMM or aIn) + (aIn - (st.coarseInRMM or aIn)) * kS
    st.sprayPieceMM3 = nV > 0 and epV / nV or 0                   -- mean cell-drop piece (>= a_max) of a visible event
  end
  -- rev11 film supply: rain that does not stick as resolved drops + the fine road spray (all of it: 70-90 um drops are
  -- far below a cell -- they join the film / haze, the W1 sheet regime makes the 'following in spray' water sheet)
  local rainFilm = math.max((st.fluxMMs or 0) - (st.splashFluxMMs or 0), 0) * (1 - (st.stickFrac or 0.6)) * p.filmRainK
  local sprayFilm = 0   -- rev48-F1: the fine road spray joins the FINE layer (gR2SprayFineMMs), not the film
  -- rev47f: the two sources have separate gains (rev11-47e: filmK scaled both, so hiding spray with
  -- filmK 0 also removed the unresolved rain -- the trail / head-drop / wetness supply)
  st.rainFilm, st.sprayFilm = rainFilm * p.filmK, sprayFilm
  st.filmRate = rainFilm * p.filmK + sprayFilm
  p.filmRateMMs = st.filmRate
  local dRain = st.meanDiamMM or 0.5
  local dMix = (rainFilm * dRain + sprayFilm * p.sprayDiamMM) / math.max(rainFilm + sprayFilm, 1e-9)
  local texelMM2 = (602.0 / p.fieldU) * (146.3 / p.fieldV)
  -- rev48-P1: E[V] of a rain impact = pi / 6 E[D^3] (supply DSD); spray keeps its exponential pi D^3
  local vRain = math.pi / 6 * (st.dsdM3 or 6 * dRain ^ 3)
  local vMix = (rainFilm * vRain + sprayFilm * math.pi / 6 * p.sprayDiamMM ^ 3) / math.max(rainFilm + sprayFilm, 1e-9)
  st.filmSplashMM = vMix / texelMM2
  self.stats.carSpeed = inp.carSpeed
  -- Veil = fog colour with reduced chroma (same idea as the legacy fog tone).
  local f = sim.fogColor or rgb(0.5, 0.5, 0.5)
  local l = f.r * 0.2126 + f.g * 0.7152 + f.b * 0.0722
  self.veil = vec3(l + (f.r - l) * 0.3, l + (f.g - l) * 0.3, l + (f.b - l) * 0.3) * p.veilBright
end

local function run(canvas, pass)
  -- PERF-2: with the app profiler on (realvisor RV_PROF, global) every simulation pass is its own Render Stats entry
  if not (RV_PROF and RV_PROF.on) then return canvas:updateWithShader(pass) ~= false end
  local name = PASS_NAMES[pass]
  local t0 = os.preciseClock()   -- PERF-11: submission CPU (includes render.measure's own cost when it is used)
  local res
  if name and render.measure then
    render.measure(name, function() res = canvas:updateWithShader(pass) end)
  else
    res = canvas:updateWithShader(pass)
  end
  SIM_CPU.run, SIM_CPU.n = SIM_CPU.run + (os.preciseClock() - t0) * 1000, SIM_CPU.n + 1
  return res ~= false
end

-- Once per simulation frame, from render.onSceneReady.
function R2:simulate(sim)
  if not self:enabled() then return end
  if self.simFrame == sim.frame then return end
  self.simFrame = sim.frame
  if RV_PROF and RV_PROF.on and RV_PROF.add and SIM_CPU.n > 0 then   -- PERF-11: last frame's sim CPU split
    RV_PROF.add('RainFX2 sim Lua: sceneValues', SIM_CPU.sv)
    RV_PROF.add('RainFX2 sim Lua: pass submit (' .. SIM_CPU.n .. ' calls)', SIM_CPU.run)
  end
  SIM_CPU.sv, SIM_CPU.run, SIM_CPU.n = 0, 0, 0
  self.recValid = false   -- PERF-9: records follow this frame's state (recUpdate on the drawn exits)
  local s = self.store
  local p = self.p
  p.exposure, p.apertureMM, p.debug = s.rainExposure, s.apertureMM, s.debug
  p.wfRefraction, p.wfSceneMip, p.focusM = s.wfRefraction, s.wfSceneMip, s.focusM
  p.contactDeg, p.wobbleAmp = s.contactDeg, s.wobbleAmp
  p.defocusDA = s.defocusDA
  local userSub = math.max(1, math.min(4, math.floor(s.substeps + 0.5)))
  p.filmK, p.sprayK, p.filmRefract, p.filmVeil = s.filmK, s.sprayK, s.filmRefract, s.filmVeil
  p.scatterK = s.scatterK
  p.windK = s.windK
  p.normalSign = s.invertSide and -1 or 1
  if not self.ctx.surface:validate() then self.status = self.ctx.surface.status or 'geometry not verified'; return end
  if not self:ensureResources() or not self:ensureMesh() then return end
  if self.clearRequest then   -- M-REF: empty visor for repeatable replay segments (clear, no resource churn)
    self.clearRequest = false
    local z = rgbm(0, 0, 0, 0)
    for _, k in ipairs({ 'S', 'F', 'TG', 'LM', 'HZ' }) do
      for _, c in ipairs(self[k] or {}) do c:clear(z) end
    end
    for _, k in ipairs({ 'C', 'PR', 'REC', 'MSK', 'HZM', 'SK', 'BG', 'TT' }) do
      if self[k] then self[k]:clear(z) end
    end
    self.recValid, self.mskValid, self.hzmValid = false, false, false
  end
  -- rev23 look lab (docs/RAINFX_V2_DROP_PIPELINE_PLAN.md step 1): static reference-distributed
  -- drop set, physics / births / film / haze / scatter / wobble / defocus off. Works while paused.
  if self.lookLab then
    if self.labRequest or not self.labSeeded then
      self.labRequest = false
      local ps = self.passSeed
      if not ps then ps = newPass(self, self.src.seed, 'seed'); self.passSeed = ps end
      sceneValues(self, ps.values)
      self.labSeedN = ((self.labSeedN or 0) + 1) % 100000
      ps.values.gR2Frame = self.labSeedN
      ps.values.gR2SeedMode = 1
      ps.values.gR2LabOcc = p.labOcc
      ps.values.gR2LabRMinMM = p.labRMinMM
      ps.values.gR2LabRMaxMM = p.labRMaxMM
      if run(self.S[3 - self.si], ps) then self.si = 3 - self.si; self.labSeeded = true end
    end
    self.frameDt = self.frameDt or (1 / 60)
    self.opticsReady = true
    self.status = 'look lab (static drops, other effects off)'
    self:recUpdate()
    return
  end
  self.labSeeded = false
  local dt = sim.dt or 0
  if dt <= 0 then self.status = 'paused'; self:recUpdate(); return end
  dt = math.min(dt, 1 / 20) * (self.timeScale or 1)   -- rev9: slow motion for physics review
  self.wobbleT = ((self.wobbleT or 0) + dt) % 600
  self:updateInputs(sim)
  -- Substeps: enough that the fastest expected drop (2 mm, forces aligned) stays in the
  -- gather window; faster than that it is speed-limited (r2Predict), not deleted.
  local P = self.physics
  self:syncSurface()
  local vExp = P.speedLegacySubsteps(p, 2.0, self.inp.accelG * 9.81, self.inp.airSpeed, p.pinCoat)   -- PHYS-UI: substeps unchanged
  -- B2: smallest drop that moves this frame (full tangential g + the air speed at the visor; once per frame, bisection)
  self.beadMoveR = math.min(P.criticalRadius(p, self.inp.accelG * 9.81, self.inp.airSpeed, p.pinCoat), 1e3)
  p.substeps = P.substeps(p, dt, self.cellMM, userSub, vExp)
  self.frameSeed = sim.frame % 1048576
  self.h = dt / p.substeps
  self.frameDt = dt
  do   -- B1d: coat wear grows with rain time (optional), the tear-off reset lasts one frame
    self.coatWear = self.coatWear or p.coatWear or 0
    local raining = self.stats and (self.stats.fluxMMs or 0) > 0
    if (p.coatWearRate or 0) > 0 and raining then self.coatWear = math.min(self.coatWear + dt * p.coatWearRate / 60, 1) end
    if (self.coatResetFrames or 0) > 0 then self.coatResetFrames = self.coatResetFrames - 1 end
  end
  self.diag = P.diagnose(p, self.inp, self.h, self.cellMM, self.diag)
  if self.ladderRequest then
    self.ladderRequest = false
    local ps = self.passSeed
    if not ps then ps = newPass(self, self.src.seed, 'seed'); self.passSeed = ps end
    sceneValues(self, ps.values)
    ps.values.gR2SeedMode = 0
    if run(self.S[3 - self.si], ps) then self.si = 3 - self.si end
  end
  -- rev13: coalescence runs FIRST (on last frame's state). The merge may leave a drop
  -- centre off its cell (centroid); the P1 substeps that follow relocate it, so the visor
  -- never sees off-cell drops (rev12: drops cut by the 5x5 draw window along cell edges).
  if p.coalesceK > 0 or p.filmOn then   -- rev48-W1: the merge pass also removes the sheet-absorbed share
    local pk, pm = self.passClaim, self.passMerge
    pk.textures.txR2State = self.S[self.si]
    pk.textures.txR2Field = self.F[self.fi]        -- rev48-S3b: wetness for the footprint radius
    pk.textures.txR2Big = self.BG                  -- rev48-R7a
    sceneValues(self, pk.values)
    if run(self.C, pk) then
      pm.textures.txR2State = self.S[self.si]
      pm.textures.txR2Claim = self.C
      pm.textures.txR2FieldOld = self.F[3 - self.fi]   -- FILM S2-1: F_prev of last frame's field pass (film join)
      pm.textures.txR2Big = self.BG                     -- rev48-R7a (built on this same S last frame)
      sceneValues(self, pm.values)
      if run(self.S[3 - self.si], pm) then self.si = 3 - self.si end
    end
  end
  -- rev8: only P1 runs per substep. Coalescence and the field run once per frame:
  -- touching drops merging a few ms later is invisible, landing drops still merge in
  -- the P1 gather, and the field draws the frame's accumulated displacement.
  -- (rev7: 4 passes x 4 substeps = frame preparation 0.57 ms.)
  -- rev48-W1q/W1u: lamella registry of this frame (F_prev for the fed flag) BEFORE the cells pass -- cells bears the
  -- residual drops of the lamellae the field pass collapses this same frame (same registry)
  do   -- rev48-U1: the impact registry is the only source of raindrop impacts (cells / field / visor), always on
    local pl = self.passLam
    pl.textures.txR2Lam = self.LM[self.li]
    pl.textures.txR2Field = self.F[self.fi]
    sceneValues(self, pl.values)
    if run(self.LM[3 - self.li], pl) then self.li = 3 - self.li end
  end
  -- FILM S2-0: the rev48-W1t patch-bead pass is removed
  for i = 1, p.substeps do
    self.sub = i
    do   -- PERF-3: each drop's step once (cells gathers the stored results); same textures as the cells pass
      local pp = self.passPredict
      pp.textures.txR2State = self.S[self.si]
      pp.textures.txR2Field = self.F[self.fi]
      pp.textures.txR2Trail = self.TG[self.ti]
      pp.textures.txR2Lam = self.LM[self.li]
      sceneValues(self, pp.values)
      if not run(self.PR, pp) then self.status = 'compiling predict'; return end
    end
    local pc = self.passCells
    pc.textures.txR2Pred = self.PR
    pc.textures.txR2State = self.S[self.si]
    pc.textures.txR2Field = self.F[self.fi]   -- rev21: haze/film births, trail following
    pc.textures.txR2Trail = self.TG[self.ti]  -- rev47j: pearling reads the rivulet lines
    pc.textures.txR2Lam = self.LM[self.li]      -- rev48-W1u residual drops
    pc.textures.txR2Haze = self.HZ[self.hi]     -- H1c haze layer (HZ_prev)
    sceneValues(self, pc.values)
    if not run(self.S[3 - self.si], pc) then self.status = 'compiling cells'; return end
    self.si = 3 - self.si
    do   -- T1 (H3 spec 8m): this substep's sweep of the haze texels, united with the earlier substeps of the frame
      local pw = self.passWm
      pw.textures.txR2State = self.S[self.si]
      pw.textures.txR2Wm = self.WM[self.wmi]
      pw.textures.txR2Haze = self.HZ[self.hi]          -- H3-P5: HZ_prev (skip cells with no haze to wipe)
      pw.textures.txR2Big = self.HZV                   -- H3-P5: static validity class in the (unused) big-drop slot
      sceneValues(self, pw.values)
      if self.hzvValid and run(self.WM[3 - self.wmi], pw) then
        self.wmi = 3 - self.wmi
        self.wmValid = (i == 1) or self.wmValid
      elseif i == 1 then
        self.wmValid = false
      end
    end
    do   -- TR0 (docs/RAINFX_V2_TRAIL_REVIEW2.md section 6): trail geometry + this frame's depth after EVERY substep (each
      -- substep end lies within +-2 cells of every point of its path: no unrecorded stretches); the swept segment is the
      -- move of the frame so far, its duration i x h (the speed of the trail rule)
      local pt = self.passTrail
      pt.textures.txR2State = self.S[self.si]
      pt.textures.txR2Field = self.F[self.fi]
      pt.textures.txR2Trail = self.TG[self.ti]
      sceneValues(self, pt.values)
      pt.values.gR2Dt = self.h * i
      if run(self.TG[3 - self.ti], pt) then self.ti = 3 - self.ti end
    end
  end
  do   -- rev48-R7a: big-drop tiles of the final state (visor now, claim / merge next frame)
    local pg = self.passBig
    pg.textures.txR2State = self.S[self.si]
    sceneValues(self, pg.values)
    if not p.bigOn or not run(self.BG, pg) then self.BG:clear(rgbm(0, 0, 0, 0)) end
  end
  do   -- B2: tail raster of the final state (after the big tiles; the visor draws it in the txR2Trail slot)
    local pq = self.passTailTex
    pq.textures.txR2State = self.S[self.si]
    pq.textures.txR2Big = self.BG
    pq.textures.txR2Field = self.F[self.fi]          -- B3a: coat state / wetness at the head (rivulet width of the trail rule)
    sceneValues(self, pq.values)
    self.ttValid = p.bigOn and p.tailOn ~= false and run(self.TT, pq) or false
    if not self.ttValid then self.TT:clear(rgbm(0, 0, 0, 0)) end
  end
  do   -- H1c / H1b: haze layer on S_next (sweep, coalescence, supply); cells read HZ_prev this frame
    -- N3: reach mask + N1 nucleus ratio first (S_next, HZ_prev: the same inputs as the haze pass / the cells event)
    if not self.hzvValid then   -- H3-P2: static (geometry only), once per resource set
      local pv = self.passHzv
      sceneValues(self, pv.values)
      self.hzvValid = run(self.HZV, pv) and true or false
    end
    local pm = self.passHzm
    pm.textures.txR2HzValid = self.HZV
    pm.textures.txR2State = self.S[self.si]
    pm.textures.txR2Haze = self.HZ[self.hi]
    pm.textures.txR2Field = self.F[self.fi]   -- H3-P4: S1 water-layer class per cell (F_prev)
    sceneValues(self, pm.values)
    self.hzmValid = self.hzvValid and run(self.HZM, pm)
    if self.hzmValid then
      local ph = self.passHaze
      ph.textures.txR2State = self.S[self.si]
      ph.textures.txR2Haze = self.HZ[self.hi]
      ph.textures.txR2HzMask = self.HZM
      ph.textures.txR2Wm = self.WM[self.wmi]          -- T1
      ph.textures.txR2Field = self.F[self.fi]         -- S1: F_prev water layers
      sceneValues(self, ph.values)
      ph.values.gR2Dt = self.frameDt
      if not self.wmValid then ph.values.gR2HazeMaskMode = 0 end   -- T1 mask not built: legacy gather
      if run(self.HZ[3 - self.hi], ph) then self.hi = 3 - self.hi end
    end
  end
  do
    -- TR0: the trail geometry was written after every cells substep (TG[ti] = this frame's lines, tagged); the field
    -- lays the depth of the lines tagged this frame (no second gather)
    local pf = self.passField
    pf.textures.txR2State = self.S[self.si]
    pf.textures.txR2Field = self.F[self.fi]
    pf.textures.txR2Trail = self.TG[self.ti]
    pf.textures.txR2Lam = self.LM[self.li]
    sceneValues(self, pf.values)
    pf.values.gR2Dt = self.frameDt                 -- field integrates the whole frame
    -- F5: sheet coefficients BEFORE the field (front rule + body mobility read them); geometry and scene only
    local skOK = false
    if p.filmOn then
      local pkc = self.passFilmK
      sceneValues(self, pkc.values)
      skOK = run(self.SK, pkc)
    end
    pf.textures.txR2FilmK = self.SK
    if run(self.F[3 - self.fi], pf) then
      -- FILM S2-1 transport (film.hlsl): an even number of substeps (scratch ping-pong)
      if p.filmOn then
        if skOK and self:filmGate() then   -- F4b: no film on the visor (readback, 1-3 frames old) -> no transport
          local nsub = self.filmSub or 2
          local a, b = self.F[3 - self.fi], self.FS
          local pfm = self.passFilm
          sceneValues(self, pfm.values)
          pfm.values.gR2FilmDt = self.frameDt / nsub
          pfm.textures.txR2FilmK = self.SK
          pfm.textures.txR2FilmAny = self.FAc
          -- F4c: skip dry blocks once a summary exists (FAc on the GPU = the last gate pass, <= 3 frames old)
          pfm.values.gR2FilmTile = (p.filmTile ~= false and (self.filmGateSent or 0) > 0) and 1 or 0
          for _ = 1, nsub do
            pfm.textures.txR2Field = a
            if not run(b, pfm) then break end
            a, b = b, a
          end
        end
      end
      self.fi = 3 - self.fi
      if p.filmOn then self:filmGateUpdate() end
    end
  end
  self:metricsUpdate(sim)
  self:auditUpdate()
  self:recUpdate()
  self.opticsReady = true
  self.status = 'running'
end


-- PERF-9 (2026-11-06): the values cand.hlsl reads (r2CandCore / r2SupportCore), ONE source for the visor draw
-- (drawParams) and the drop-record pass (simulate -> recUpdate): the records equal what the visor computed itself.
-- docs/tools/check_rainfx2_shaders.py fails if cand.hlsl / rec.hlsl use a gR2 value not assigned here.
local function candValues(self, v)
  local p = self.p
  coatValues(self, v)   -- B1d: tgshared r2CoatFactor (visor debug 10)
  updateShapeK(p)
  v.gR2MaxRadiusMM = p.maxRadiusMM   -- R1: drawn radius stops at the largest cap (spill water is the field's)
  v.gR2Cells = self.cells
  v.gR2CellSizeMM = self.cellSizeMM
  v.gR2ShapeK = p.shapeK
  v.gR2CapVolume = p.capVolume ~= false and 1 or 0
  v.gR2BigOn, v.gR2BigRMM = p.bigOn and self.BG and 1 or 0, p.bigRMM or 0.8   -- rev48-R7a
  v.gR2KernelScale = p.kernelScale
  v.gR2TailFlat = p.tailFlat or 0.85     -- B3e: rivulet section flatness (beta along the neck; 0 = dome like the head)
  v.gR2HeadRound = p.headRound or 1.0   -- B3f: sliding head round at its front (0 = symmetric ellipse)
  v.gR2Steep = p.steep ~= false and 1 or 0       -- R-steep: lens reflected ray exits the opposite side of the cap
  v.gR2CubeK, v.gR2CubeMip = p.cubeK or 0.7, p.cubeMip or 2.0   -- R-img: CSP steep rim = cube x 0.7
  v.gR2ImgPupilMM = p.imgPupilMM or 0.0   -- R-img: camera entrance pupil seen through a drop (in-drop image defocus)
  v.gR2SceneCompress = p.sceneCompress ~= false and 1 or 0   -- R-img5 (visor inverse; cleanup: on, k 0.01)
  v.gR2CompressK = p.compressK or 0.01
  v.gR2LensStable = p.lensStable ~= false and 1 or 0   -- R-img3: per-drop lens mip (no ddx), fixed D-A taps
  v.gR2RimPhys = p.rimPhys ~= false and 1 or 0   -- S-fix: own rim angle (f), front / rear hysteresis, Bond top flattening, Fresnel / TIR
  v.gR2BondFlatK = p.bondFlatK or 0.5   -- S-fix2: top flattening = k (r / 2.7 mm)^2 (1.5 flattened big drops into puddles)
  v.gR2SurfH = p.surfH ~= false and 1 or 0   -- B3h: one water height field (refraction from grad H); off = per-primitive lens union
  v.gR2SurfK = p.surfK or 0.04          -- B3h: smooth-max width of the union (mm)
  v.gR2ShpOn = p.shpOn and 1 or 0   -- rev48-S1
  v.gR2ShpRecoilC = p.shpRecoilC   -- rev48-R1
  v.gR2ShpLamShift = p.shpLamShift   -- rev48-U2: lamella centre vs the recoiling residual
  v.gR2ShpRimK, v.gR2ShpFingerK = p.shpRimK or 0.6, p.shpFingerK or 0.25
  v.gR2ShpImpactK, v.gR2ShpImpactMax = p.shpImpactK, p.shpImpactMax   -- U2a: lamella ellipse along Vt (visor)
  v.gR2BaseSpread = p.baseSpread       -- rev48-S2'b
  v.gR2ShpNeckK, v.gR2ShpNeckT, v.gR2HiSplit = p.shpNeckK, p.shpNeckT, p.hiSplit and 1 or 0   -- rev48-S6c E8 neck / review highlight
  v.gR2HiImpact = p.hiImpact and 1 or 0   -- rev48-U1 review highlight
  v.gR2ContactDeg = p.contactDeg
  v.gR2WobbleAmp = p.wobbleAmp
  v.gR2MotionStretch = p.motionStretch
  v.gR2Frame = self.frameSeed or 0
  v.gR2MinDrawMM = p.minDrawMM
  v.gR2SagK = p.sagK
  v.gR2FilmRecedeDeg = p.filmRecedeDeg or 50
  v.gR2SimDt = self.frameDt or (1 / 60)   -- packed move = displacement of the whole frame
  v.gR2GrowTime = p.growTime
  v.gR2FadeTime = p.fadeTime
  v.gR2VMax = p.vMax
  v.gR2LookLab = self.lookLab and 1 or 0
  return v
end

-- PERF-9: drop records of the CURRENT state (end of every simulate path that leaves S drawn). Its own small texture
-- table (3 of 14; the shared simulation table stays 14 / 14); values = candValues, the visor's own source.
function R2:recUpdate()
  self.recValid = false
  if not self.REC or self.p.useRec == false then return end
  local rp = self.passRec
  if not rp then
    rp = { async = true, blendMode = render.BlendMode.Opaque,
      textures = { txR2State = false, txR2Lam = false, txR2Big = false }, values = {}, shader = self.src.rec }
    PASS_NAMES[rp] = 'RainFX2 sim/rec'
    self.passRec = rp
  end
  rp.textures.txR2State = self.S[self.si]
  rp.textures.txR2Lam = self.LM and self.LM[self.li] or false
  rp.textures.txR2Big = self.BG or false
  candValues(self, rp.values)
  if run(self.REC, rp) then
    self.recValid, self.recS, self.recLM = true, self.S[self.si], self.LM and self.LM[self.li]
  end
  -- PERF-10: per-cell candidate mask from these records (+ the big tiles); same values source
  self.mskValid = false
  if self.recValid and self.MSK and self.p.useMask ~= false then
    local mp = self.passMsk
    if not mp then
      mp = { async = true, blendMode = render.BlendMode.Opaque,
        textures = { txR2Rec = false, txR2Big = false }, values = {}, shader = self.src.msk }
      PASS_NAMES[mp] = 'RainFX2 sim/msk'
      self.passMsk = mp
    end
    mp.textures.txR2Rec = self.REC
    mp.textures.txR2Big = self.BG or false
    candValues(self, mp.values)
    self.mskValid = run(self.MSK, mp)
  end
end

-- H3-1: the baked atlas texture/RAINFX_MicroDrops.dds (+ .json from docs/tools/rainfx2_bake_microdrops.py: piece p50 at
-- octave 0, tile size). Looked up once; missing -> the micro layer is off (H1 veil only).
function R2:microAtlas()
  if self.micro == nil then
    local base = (self.ctx.folder or '.') .. '/texture/RAINFX_MicroDrops'
    local js = readFile(base .. '.json')
    if js and io.fileExists and not (io.fileExists(base .. '.dds') and io.fileExists(base .. '_Halo.dds')) then js = nil end
    if js then
      local function num(key, def) return tonumber(js:match('"' .. key .. '"%s*:%s*([%d%.eE%-]+)')) or def end
      self.micro = { path = base .. '.dds', halo = base .. '_Halo.dds', tile = num('tileMM', 25.6),
        a50 = num('pieceR_a50', 0.212),      -- area-weighted median piece radius at octave 0 (the octave reference)
        rmax = num('pieceR_max', 0.30), q = num('rankQ', 0.5),   -- radius(rank) ~ rmax (1 - rank)^q
        sdf = num('sdfRangeMM', 0.1), cover = num('coverage', 0.76),
        centre = num('centreVec', 0) }   -- U-micro: R, G = position in the piece's drop disc (analytic cap)
    else
      self.micro = false
    end
  end
  return self.micro or nil
end

function R2:drawParams(depth)
  local key = depth and 'paramsDepth' or 'paramsColour'
  local t = self[key]
  if not t then
    t = { mesh = self.mesh, transform = 'original', async = true,
      textures = { txR2State = false, txR2Field = false, txR2Trail = false, txR2Scene = false, txR2Lam = false, txR2Big = false, txR2Rec = false, txR2Msk = false, txR2Mask = self.ctx.maskPath, txR2Haze = false, txR2Micro = false, txR2MicroHalo = false },   -- PERF-5: mesh.fx allows 13 user textures (t13+ reserved); PERF-9/10 10 / 13; H1c 11 / 13; H3 12 / 13 (atlas; the N3 mask moved out: verify = G -1 in the haze pass); H3-2d 13 / 13 (halo atlas)
      values = {}, shader = depth and self.src.visorDepth or self.src.visor }
    self[key] = t
  end
  t.mesh = self.mesh   -- LIFE-1: the drop mesh is rebuilt after a suspend (a cached disposed mesh failed every draw)
  local p, v = self.p, t.values
  local size = render.getRenderTargetSize()
  v.gR2InvRT = vec2(1 / math.max(size.x, 1), 1 / math.max(size.y, 1))
  v.gR2TexMM = self.texMM
  candValues(self, v)   -- PERF-9: every value the candidate code (cand.hlsl) reads -- shared with the record pass
  v.gR2FineRMM = p.fineRMM
  v.gR2ApertureMM = p.apertureMM
  v.gR2FovK = 0.5 / math.tan(math.rad(math.max(ac.getSim().cameraFOV or 60, 1)) * 0.5)
  v.gR2FocusM = p.focusM
  -- Camera and visor transform at DRAW time (camera scripts may move both after onSceneReady).
  local simNow = ac.getSim()
  self.camPos = self.camPos or vec3()
  self.camPos:set(simNow.cameraPosition)
  v.gR2CamPos = self.camPos
  if self.mesh then self.drawToWorld = self.mesh:getWorldTransformationRaw():clone() end   -- PosL is in this mesh's space
  v.gR2ObjToWorld = self.drawToWorld or self.objToWorld
  local function coc(z) return p.apertureMM * math.abs(p.focusM - z) / math.max(p.focusM, 1e-3) end
  self.cocInfo = string.format('CoC on the visor: %.2f mm @3 cm, %.2f mm @6 cm, %.2f mm @12 cm (Debug 6 = distance / CoC px)',
    coc(0.03), coc(0.06), coc(0.12))
  v.gR2AsymK, v.gR2AsymGravR = p.asymK, p.asymGravR   -- rev48-S2d
  v.gR2ShpFrontK = p.shpFrontK                         -- rev48-S6 F2 outer-front apex
  v.gR2WetHaze = p.wetHaze
  v.gR2Threshold = p.threshold
  v.gR2Hysteresis = p.hysteresisDeg
  v.gR2WobbleHz = p.wobbleHz
  -- Fa/Fpin = (0.25 rho Cd pi / (2 gamma dcos_coat)) * r * u^2, r in mm -> * 1e-3
  v.gR2WobbleC = 0.25 * p.rhoAir * 1.0 * math.pi / (2 * p.surfaceTension * p.pinCoat) * 1e-3   -- R6b: tuned look (Cd 1)
  v.gR2AirW = self.airW or vec3()
  v.gR2AirSurface = p.airSurface
  v.gR2Time = self.wobbleT or 0
  -- rev48-P4 sheet surface
  v.gR2FrameDt = self.frameDt or 1 / 60
  for i = 0, 15 do v[DQ_NAMES[i]] = (self.stats and self.stats.dq and self.stats.dq[i + 1]) or 0.3 end   -- rev48-P1 (PERF-11 names)
  v.gR2SpeedRel = (self.stats and self.stats.speedRel) or p.terminalSpeed
  v.gR2RainDirW = self.rainDirW or vec3(0, -1, 0)   -- rev48-P4b impact direction
  v.gR2ImpactWaveK = p.impactWaveK or 1
  v.gR2WFSceneMip = p.wfSceneMip
  v.gR2DefocusMode = p.defocusDA and 1 or 0
  self.drawCount = ((self.drawCount or 0) + 1) % 4096
  v.gR2FrameNoise = self.drawCount                -- D-A tap rotation (TAA/DLSS resolves it)
  v.gR2Glint = p.glint
  v.gR2LensPhys = p.lensPhys
  self.camLook = self.camLook or vec3(); self.camSide = self.camSide or vec3(); self.camUp = self.camUp or vec3()
  self.camLook:set(simNow.cameraLook or vec3(0, 0, 1))
  self.camSide:set(simNow.cameraSide or vec3(1, 0, 0))
  self.camUp:set(simNow.cameraUp or vec3(0, 1, 0))
  v.gR2CamLook, v.gR2CamSide, v.gR2CamUp = self.camLook, self.camSide, self.camUp
  v.gR2AccelW = self.accelW or vec3(0, -9.81, 0)
  v.gR2VeilColor = self.veil or vec3(0.5, 0.5, 0.5)
  v.gR2DepthCoverage = p.depthCoverage
  v.gR2FieldSize = self.fieldSize
  v.gR2FilmMaxMM = p.filmOn and p.filmStoreMaxMM or p.filmMaxMM   -- rev48-W1: B holds the sheet (up to 2 mm)
  v.gR2TrailMaxMM = p.trailMaxMM
  v.gR2FilmMinMM = p.filmOn and p.filmDrawMinMM or p.filmMinMM   -- rev48-W1e: with the sheet on only a sheet shows
  v.gR2FilmWetMM = p.hazeWetMM or 0.02   -- debug 5: film layer depth (= field / film passes)
  v.gR2FilmOn = p.filmOn and 1 or 0   -- rev48-P2 sheet lens
  v.gR2FilmFollowK = p.filmFollowK or 0.5
  v.gR2FilmRate = self.store.freezeRain and 0 or ((self.stats and self.stats.filmRate) or 0)
  v.gR2FilmFullMM = p.filmFullMM
  v.gR2TrailMinMM = p.trailMinMM
  v.gR2TrailFullMM = p.trailFullMM
  v.gR2FilmRefract = p.filmRefract
  v.gR2FilmAbsorb = p.filmAbsorb
  v.gR2FilmMip = p.filmMip
  v.gR2FilmVeil = p.filmVeil
  v.gR2ScatterFilm = p.scatterFilm * p.scatterK
  v.gR2ScatterSpray = p.scatterSpray * p.scatterK
  v.gR2ScatterMax = p.scatterMax
  v.gR2HazeK, v.gR2HazeAMM, v.gR2HazePhiMax = p.hazeK or 1.0, p.hazeAMM or 0.015, p.hazePhiMax or 0.55   -- H1 haze
  do   -- H3: saturation depth of the finest caps (same as sceneValues) -> coarsening a_eff = hazeAMM x G / G_sat
    local a, phi = p.hazeAMM or 0.015, math.min(p.hazePhiMax or 0.55, 0.95)
    v.gR2HazeSatMM = -math.log(1 - phi) * (p.shapeK or 1) * a / math.pi
  end
  v.gR2FineMaxMM = 0.01                              -- H1: G scale (same as the simulation)
  v.gR2ScatterMip = p.scatterMip
  v.gR2SceneBicubic = p.sceneBicubic == false and 0 or 1   -- V3: B-spline reads of the coarse scene mips (veil, blur, film)
  v.gR2ScatterSky = p.scatterSky
  v.gR2ScatterGain = p.scatterGain
  v.gR2Spray = self.store.freezeRain and 0 or (self.stats.spray or 0)
  v.gR2VLimit = self.diag and self.diag.vGather or 0.5   -- physical m/s (h already scaled)
  v.gR2Debug = p.debug
  v.gR2DebugBright = p.debugBright
  return t
end

-- P3: housing-free, premultiplied refraction source from the pre-glass frame copy.
-- Returns the canvas, or nil (draw then falls back to the raw copy).
function R2:prepareSource(src)
  local p = self.p
  local size = render.getRenderTargetSize()
  local w = math.max(16, math.floor(size.x * p.sourceScale))
  local h = math.max(16, math.floor(size.y * p.sourceScale))
  -- V4 (2026-11-15): power-of-two source so every mip is an exact 2 x 2 box of the one below. An odd size (810 x 456 ->
  -- 405, 202.5 ...) makes the hardware mip chain skip texel rows / columns: a small bright light (the green board) vanished
  -- from the coarse veil mips and came back while panning. Next power of two up (1620 x 912 frame: 1024 x 512).
  if p.sourcePot ~= false then
    w = math.floor(2 ^ math.ceil(math.log(w) / math.log(2) - 1e-6) + 0.5)
    h = math.floor(2 ^ math.ceil(math.log(h) / math.log(2) - 1e-6) + 0.5)
  end
  if not self.source or self.sourceW ~= w or self.sourceH ~= h then
    if self.source then self.source:dispose() end
    self.source = ui.ExtraCanvas(vec2(w, h), math.floor(math.log(math.max(w, h)) / math.log(2)) + 1,
      render.AntialiasingMode.None, render.TextureFormat.R16G16B16A16.Float)
    self.source:setName('RainFX2 refraction source (housing-free)')
    self.sourceW, self.sourceH = w, h
  end
  local sim = ac.getSim()
  local near = math.max(sim.cameraClipNear or 0.05, 0.001)
  local pass = self.passSource
  if not pass then
    pass = { async = true, blendMode = render.BlendMode.Opaque,
      textures = { txR2Src = false, txR2Depth = 'dynamic::depth', txR2HousingMask = false }, values = {}, shader = self.src.source }
    self.passSource = pass
  end
  pass.textures.txR2Src = src
  local v = pass.values
  v.gR2SceneCompress = self.p.sceneCompress ~= false and 1 or 0   -- R-img5: tone-compressed refraction source (HDR lights do not flood the mips)
  v.gR2CompressK = self.p.compressK or 0.01
  v.gR2Near = near
  v.gR2Far = math.max(sim.cameraClipFar or 5000, near + 1)
  v.gR2HousingM = p.housingM
  -- H-mask (docs/RAINFX_V2_TRAIL_REVIEW3.md section 59): housing-only coverage shot from realvisor.lua (nil -> depth rule only)
  local hm, hmStatus, hmSize = nil, nil, nil
  if p.housingMask ~= false and self.ctx.housingMask then hm, hmStatus, hmSize = self.ctx.housingMask() end
  self.housingMaskStatus = hm and (hmStatus or 'H-mask on') or (p.housingMask == false and 'H-mask off' or ('H-mask unavailable' .. (hmStatus and (': ' .. hmStatus) or '')))
  pass.textures.txR2HousingMask = hm or false
  v.gR2HousingMaskOn = hm and 1 or 0
  v.gR2HousingMaskTexel = hmSize and vec2(1 / math.max(hmSize.x, 1), 1 / math.max(hmSize.y, 1)) or vec2(0, 0)
  v.gR2DepthReversed = (self.ctx.depthReversed and self.ctx.depthReversed()) and 1 or 0
  if self.source:updateSceneWithShader(pass) == false then return nil end
  if self.source:mipsUpdate() == false then return nil end
  return self.source
end

-- src: HDR frame copy with mips taken before the glass stack (fallbackSource). Returns true if drawn.
function R2:draw(src, viewKey, depth)
  if not self:enabled() or not self.opticsReady or not self.mesh or not src then return false end
  -- rev20 crash guard (rev19 review: camera passing through an AI car, then its interior in view
  -- -> 4/4 game crashes). Extra views with another render-target size (car mirrors / windscreen
  -- passes) reached this draw before the frame's main view was tracked, and prepareSource then
  -- disposed and re-created the full-res HDR canvas with mips several times per frame while the
  -- previous one could still be bound. Draw only into the established main size; adopt a new size
  -- only after it has been the only one seen for 30 consecutive draws (window resize).
  local rt = render.getRenderTargetSize()
  local rw, rh = math.floor(rt.x), math.floor(rt.y)
  if rw ~= self.drawW or rh ~= self.drawH then
    local key = rw * 65536 + rh
    if self.sizeKey == key then self.sizeVotes = self.sizeVotes + 1 else self.sizeKey, self.sizeVotes = key, 1 end
    if self.drawW and self.sizeVotes < 30 then self.skipReason = string.format('skipped %dx%d view', rw, rh); return false end
    self.drawW, self.drawH = rw, rh
  else
    self.sizeKey, self.sizeVotes = nil, 0
  end
  local memo = depth and 'depthViewKey' or 'colourViewKey'
  if viewKey and self[memo] == viewKey then return false end
  local t = self:drawParams(depth)
  if not depth then
    local ok, res
    if RV_PROF and RV_PROF.on and render.measure then   -- PERF-2: refraction source (0.5 x frame + mips) on its own
      ok, res = pcall(function() local r; render.measure('RainFX2 draw/source', function() r = self:prepareSource(src) end); return r end)
    else
      ok, res = pcall(self.prepareSource, self, src)
    end
    if not ok then self.sourceErr = tostring(res); res = nil end
    -- Raw copy as fallback: alpha 1 everywhere, so r2Scene reduces to a plain fetch.
    self.sceneTex = res or src
  end
  t.textures.txR2Scene = self.sceneTex or src
  if not depth and self.offscreenTest == 'pending' then self:offscreenTestRun() end
  t.textures.txR2State = self.S[self.si]
  t.textures.txR2Field = self.F[self.fi]
  t.textures.txR2Trail = self.TT or false   -- B3: tail raster (C8: the rev47j vector trail lines are no longer drawn)
  t.textures.txR2Lam = self.LM and self.LM[self.li] or false   -- rev48-P4 impacts on the sheet
  t.textures.txR2Big = self.BG or false                         -- rev48-R7a
  t.textures.txR2Haze = self.HZ and self.HZ[self.hi] or false   -- H1c haze layer
  t.values.gR2HazeMaskMode = self.hzmValid and (self.p.hazeMask or 1) or 0   -- N3 verify: the haze pass writes G = -1 (red)
  local mic = self:microAtlas()                                  -- H3 micro-drop atlas (docs/RAINFX_V2_H3_ATLAS_SPEC.md)
  t.textures.txR2Micro = mic and mic.path or false
  t.textures.txR2MicroHalo = mic and mic.halo or false            -- H3-2d: nearest existing piece (halo)
  t.values.gR2MicroOn = (mic and self.p.microOn ~= false) and 1 or 0
  t.values.gR2MicroA50MM = mic and mic.a50 or 0.212
  t.values.gR2MicroCentre = mic and mic.centre or 0   -- U-micro atlas format
  t.values.gR2CoarseInRMM = math.max((self.stats and self.stats.coarseInRMM) or 0, self.p.hazeAMM or 0.015)   -- H3-3b
  t.values.gR2MicroRMaxMM = mic and mic.rmax or 0.30
  t.values.gR2MicroRankQ = mic and mic.q or 0.5
  t.values.gR2MicroSdfMM = mic and mic.sdf or 0.1
  t.values.gR2MicroTileMM = mic and mic.tile or 25.6
  t.values.gR2MicroBias = self.p.microBias or 0                  -- octaves (debug only: H3-3 sizes come from G_c)
  t.values.gR2MicroRefract = self.p.microRefract or 1.0
  t.values.gR2MicroResPx = self.p.microResPx or 2.0              -- smallest piece radius drawn as a drop (px)
  t.values.gR2MicroHaloK = self.p.microHaloK or 0.5              -- veil-free band outside a piece (x a_eff)
  t.values.gR2MicroHaloPx = self.p.microHaloPx or 1.5            -- ... at least this many pixels (H3-2d)
  t.values.gR2MicroBlurK = self.p.microBlurK or 0.7              -- V2: unresolved lenses drawn as blurred scene (area share)
  t.values.gR2PerfProbe = self.p.perfProbe or 0                -- PERF-6 cost probe (0 off)
  t.values.gR2TightReach = self.p.tightReach or 1              -- PERF-7 tight drop support (0 legacy | 1 on | 2 verify)
  -- PERF-9: records only if they were built from exactly the textures this draw binds (else the per-pixel path)
  local recOk = self.recValid and self.p.useRec ~= false and self.recS == t.textures.txR2State
    and self.recLM == (self.LM and self.LM[self.li]) or false
  t.textures.txR2Rec = recOk and self.REC or false
  t.values.gR2UseRec = recOk and 1 or 0
  local mskOk = recOk and self.mskValid and self.p.useMask ~= false   -- PERF-10: built from these records
  t.textures.txR2Msk = mskOk and self.MSK or false
  t.values.gR2UseMask = mskOk and 1 or 0
  render.setCullMode(render.CullMode.None)
  render.setBlendMode(render.BlendMode.AlphaBlend)
  -- rev31: the drop mesh is a copy of the visor surface offset by only 0.05 mm; a depth-tested colour
  -- pass can z-fight with anything written at that surface (oblique / close views -> dot/hatch pattern).
  render.setDepthMode(depth and render.DepthMode.Normal or (self.p.depthTest and render.DepthMode.ReadOnly or render.DepthMode.Off))
  self.mesh:setVisible(true, false)
  local ok, res = pcall(render.mesh, t)
  self.mesh:setVisible(false, false)
  render.setDepthMode(render.DepthMode.ReadOnly)
  if not ok then self.err = 'Draw: ' .. tostring(res); ac.warn('RainFX v2 ' .. self.err); return false end
  if res ~= false then self[memo] = viewKey end
  return res ~= false
end

-- rev18 experiment for defocus D-B (docs/RAINFX_V2_DEFOCUS_PLAN.md section 6): can the visor
-- copy be drawn with render.mesh into an ExtraCanvas from inside the render event? The test
-- draws the mesh UVs into a 512x288 canvas and reads it back; the result decides D-B vs D-A.
function R2:offscreenTestRun()
  self.offscreenTest = 'running'
  local ok, err = pcall(function()
    if not self.testCanvas then
      self.testCanvas = ui.ExtraCanvas(vec2(512, 288), 1, render.AntialiasingMode.None, render.TextureFormat.R8G8B8A8.UNorm)
      self.testCanvas:setName('RainFX2 offscreen mesh test')
    end
    self.testCanvas:clear(rgbm(0, 0, 0, 0))
    local drawn = nil
    self.mesh:setVisible(true, false)
    self.testCanvas:update(function()
      drawn = render.mesh({ mesh = self.mesh, transform = 'original', textures = {}, values = {},
        shader = 'float4 main(PS_IN pin) { return float4(frac(pin.Tex.x * 8), frac(pin.Tex.y * 8), 1, 1); }' })
    end)
    self.mesh:setVisible(false, false)
    self.testCanvas:accessData(function(e2, data)
      if e2 or not data then self.offscreenTest = 'readback failed: ' .. tostring(e2); return end
      local n, c = 0, rgbm()
      for y = 0, 287, 4 do for x = 0, 511, 4 do
        data:colorTo(c, x, y)
        if c.mult > 0.5 then n = n + 1 end
      end end
      data:dispose()
      self.offscreenTest = string.format('render.mesh returned %s, covered samples %d / %d -> %s',
        tostring(drawn), n, 128 * 72, n > 0 and 'D-B possible' or 'D-B NOT possible (use D-A)')
    end)
  end)
  if not ok then self.offscreenTest = 'error: ' .. tostring(err) end
end

function R2:offscreenTestUI()
  if ui.button('Test: draw visor mesh into an offscreen canvas (defocus D-B)') then self.offscreenTest = 'pending' end
  if self.offscreenTest then
    ui.text('Offscreen test: ' .. self.offscreenTest)
    if self.testCanvas and self.offscreenTest:find('covered') then ui.image(self.testCanvas, vec2(256, 144)) end
  end
end

-- UI-1: one collapsible section with a fixed gap before it (layout policy, R2:ui)
local UI_GAP = 8
-- UI-1b: information lines carry a marker so they read apart from checkboxes / sliders
local function uiInfo(t) ui.text('> ' .. t) end
local function uiSection(title, open, fn)
  ui.offsetCursorY(UI_GAP)
  ui.treeNode(title .. '###rfx2sec_' .. title:sub(1, 12), open and ui.TreeNodeFlags.DefaultOpen or 0, fn)
end

function R2:ui()
  local s = self.store
  ui.text('RainFX v2 (cell-gather): ' .. (self.err and 'ERROR' or self.status))
  if self.err then
    -- rev36: any v2 error turns v2 off (enabled() = false) and the legacy RainFX comes back while
    -- the checkbox stays on. Show the error in full and allow a retry.
    ui.textColored('v2 stopped, legacy RainFX shown. Error: ' .. tostring(self.err), rgbm(1, 0.3, 0.2, 1))
    if ui.button('Clear the v2 error and retry') then self.err = nil; self.warned = nil end
  end
  if ui.checkbox('Enable RainFX v2 (turns legacy RainFX off)', s.enabled) then s.enabled = not s.enabled end
  if not s.enabled then return end
  -- UI-1 (2026-11-07) LAYOUT POLICY: one collapsible section per subject (ui.treeNode, sections ordered input -> forces ->
  -- motion -> births -> trails / sheet -> look -> tests / metrics / diagnostics); the same gap before every section;
  -- slider ids are unique (##rfx2 + short key) -- duplicated ids made two sliders share one ImGui state.
  uiSection('Rain input', false, function()
    s.rainExposure = ui.slider('##rfx2exp', s.rainExposure, 0, 1.5, 'Rain exposure (1 = physical): %.2f')
    self.p.rainSpreadDeg = ui.slider('##rfx2rsd', self.p.rainSpreadDeg, 0, 40, 'Rain direction spread (gusts): %.0f deg')
    self.p.crownMM = ui.slider('##rfx2cr', self.p.crownMM, 0, 60, 'Helmet crown runoff over the visor top (at rest): %.0f mm catch')
    self.p.rainWindK = ui.slider('##rfx2rwk', self.p.rainWindK or 0.6, 0, 1, 'Rain drift by the wind (helmet height / shelter): %.2f')
  end)
  uiSection('Spray and haze (SP0 / SP1 / H1)', true, function()
    s.sprayK = ui.slider('##rfx2sk', s.sprayK, 0, 5, 'Spray gain (cars ahead / road spray; 0 hides spray): %.2f')
    local si, st, d = self.sprayInfo or {}, self.stats, self.diag
    uiInfo(string.format('Wheel water (mm): own front %.2f  rear %.2f | lead %.2f  pack max %.2f  any car <60 m %.2f',
      si.selfFrontMM or -1, si.selfRearMM or -1, si.leadWaterMM or -1, si.packWaterMM or -1, si.aheadWaterMM or -1))
    if ui.checkbox('Spray source = each car\'s wheel water (PUD-2; off = global road water / wetness)', self.p.sprayWheelWater ~= false) then
      self.p.sprayWheelWater = self.p.sprayWheelWater == false
    end
    uiInfo(string.format('Own puddle excess %.2f (x hRef %.1f mm)%s', si.selfPuddle or 0, self.p.sprayHRefMM or 1.8,
      self.store.roadFix and '  -- road override on: legacy global source' or ''))
    if ui.checkbox('Spray torn by the air as it is made (SP0: median from We 12 at the car speed)', self.p.sprayAeroDn ~= false) then
      self.p.sprayAeroDn = self.p.sprayAeroDn == false
    end
    self.p.sprayAeroC = ui.slider('##rfx2sac', self.p.sprayAeroC or 0.39, 0.1, 1.0, 'Spray median / largest stable size (SP0): %.2f')
    self.p.sprayVRelK = ui.slider('##rfx2svr', self.p.sprayVRelK or 0.8, 0.3, 1.2, 'Spray impact speed / air speed (SP1): %.2f')
    local stt = self.stats or {}
    uiInfo(string.format('Spray median %.3f mm | haze share %.2f, drawn piece %.4f mm3 | rain haze %.4f mm/s',
      stt.sprayDnMM or 0, stt.sprayHazeShare or 0, stt.sprayPieceMM3 or 0, stt.hazeMMs or 0))
    uiInfo(string.format('H3: spray pieces < a_max -> micro layer %.3f of the spray water, arriving r %.3f mm (cell drops >= %.2f mm)',
      stt.sprayCoarseShare or 0, stt.coarseInRMM or 0, self.p.microSplitMM or 0))
    self.p.hazeK = ui.slider('##rfx2hzk', self.p.hazeK or 1.0, 0, 1.5, 'Haze of sub-visible micro drops (H1): %.2f')
    self.p.hazeAMM = ui.slider('##rfx2hza', self.p.hazeAMM or 0.015, 0.005, 0.04, 'Haze micro cap radius (H1): %.3f mm')
    if ui.checkbox('Saturated haze coalesces into drops (H1b)', self.p.hazeNuc ~= false) then self.p.hazeNuc = self.p.hazeNuc == false end
    self.p.hazeNucTau = ui.slider('##rfx2hnt', self.p.hazeNucTau or 0.3, 0.05, 3, 'Haze coalescence time (H1b): %.2f s')
    if ui.checkbox('Coalescence on surface defect sites (N1; off = every saturated cell alike -> lattice)', self.p.hazeNucSite ~= false) then
      self.p.hazeNucSite = self.p.hazeNucSite == false
    end
    self.p.haloK = ui.slider('##rfx2hlk', self.p.haloK or 0.5, 0, 1.5, 'Wipe halo: outer edge at r x (1 + %.2f) + outer offset (N2)')
    self.p.haloInMM = ui.slider('##rfx2hli', self.p.haloInMM or 0.1, 0, 0.5, 'Wipe halo: fully clean to r + %.2f mm (N2)')
    self.p.haloOutMM = ui.slider('##rfx2hlo', self.p.haloOutMM or 0.4, 0, 1.0, 'Wipe halo: outer offset %.2f mm (N2)')
    local mic = self:microAtlas()
    if ui.checkbox('Micro-drop layer (H3 atlas; off = flat H1 veil)', self.p.microOn ~= false) then self.p.microOn = self.p.microOn == false end
    if not mic then uiInfo('H3 atlas missing: texture/RAINFX_MicroDrops.dds + .json (docs/tools/rainfx2_bake_microdrops.py)') end
    self.p.microBias = ui.slider('##rfx2mib', self.p.microBias or 0, -3, 4, 'Micro size bias (DEBUG, 0 = physical): %.1f octaves')
    self.p.microRefract = ui.slider('##rfx2mir', self.p.microRefract or 1.0, 0, 2, 'Micro lens slope gain: %.2f')
    self.p.microResPx = ui.slider('##rfx2mip', self.p.microResPx or 2.0, 0.1, 4, 'Smallest micro drop drawn (radius): %.2f px (smaller ones = haze veil)')
    self.p.microHaloK = ui.slider('##rfx2mih', self.p.microHaloK or 0.5, 0, 2, 'Micro drop wipe halo: %.2f x size')
    self.p.microHaloPx = ui.slider('##rfx2mhp', self.p.microHaloPx or 1.5, 0, 6, 'Micro drop wipe halo, at least: %.1f px')
    self.p.hazeCoarsenTau = ui.slider('##rfx2hct', self.p.hazeCoarsenTau or 0.5, 0.1, 5, 'Fine -> micro drops time at full coverage (E2): %.2f s')
    self.p.hazeNucPMax = ui.slider('##rfx2hnp', self.p.hazeNucPMax or 0.02, 0.002, 0.2, 'Cell-drop births from haze, max per cell and frame: %.3f')
    local hm = math.floor(self.p.hazeMask or 1)
    local hmNames = { [0] = 'off (frame-end 25-record gather, A/B)', 'on (T1 substep wipe mask)' }
    if ui.button('Haze wipe (T1): ' .. (hmNames[math.min(hm, 1)] or '?') .. '##rfx2hzm') then self.p.hazeMask = hm >= 1 and 0 or 1 end
    self.p.hazeOverrunK = ui.slider('##rfx2hov', self.p.hazeOverrunK or 1.0, 0, 2, 'Spray lamellae gather fine caps (I1): x %.2f')
    self.p.hazeWetMM = ui.slider('##rfx2hwm', self.p.hazeWetMM or 0.02, 0.005, 0.1, 'Water layer that absorbs haze (S1): %.3f mm')
    self.p.microBlurK = ui.slider('##rfx2mbk', self.p.microBlurK or 0.7, 0, 1, 'Unresolved micro drops as blurred scene (V2): %.2f')
    if si and d then
      uiInfo(string.format('Spray LWC %.2f g/m3 -> %.3f mm/s on the visor, splash drops %.4f mm/s (road water %.2f, %d cars, nearest %.0f m)  film supply %.3f mm/s',
        st.spray or 0, st.sprayMMs or 0, st.splashMMs or 0, si.wet or 0, si.cars or 0, si.nearestM or -1, st.filmRate or 0))
      uiInfo(string.format('Film equilibrium %.3f mm (full exposure), flow %.3f m/s', d.filmEqMM or 0, d.filmVel or 0))
    end
  end)
  uiSection('Helmet air (outer flow, boundary layer, turbulence, depinning law)', true, function()
    self.p.aeroKU = ui.slider('##rfx2ku', self.p.aeroKU, 0.1, 1.2, 'Air speed at the helmet (x car speed, cockpit shielding): %.2f')
    self.p.stagElevDeg = ui.slider('##rfx2se', self.p.stagElevDeg, -45, 45, 'Stagnation point above the visor centre: %.0f deg')
    if ui.checkbox('Boundary layer thickens away from the stagnation point (F2a)', self.p.blGrowth ~= false) then self.p.blGrowth = self.p.blGrowth == false end
    self.p.pgradK = ui.slider('##rfx2pgk', self.p.pgradK or 1.0, 0, 2, '(%.2f) Stagnation pressure gradient pushes the drop volume (F3, 1 = physical)')
    self.p.buffetDeg = ui.slider('##rfx2bd', self.p.buffetDeg, 0, 25, 'Helmet buffeting (stagnation wander at 250 km/h): %.1f deg')
    self.p.buffetHz = ui.slider('##rfx2bh', self.p.buffetHz, 0.5, 8, 'Buffeting frequency: %.1f Hz')
    self.p.turbI = ui.slider('##rfx2ti', self.p.turbI or 0.15, 0, 0.6, 'Cockpit turbulence intensity (T1, u\' / kU U): %.2f')
    self.p.turbHz = ui.slider('##rfx2th', self.p.turbHz or 4.0, 0.5, 20, 'Turbulence drift rate (T1): %.1f Hz')
    self.p.turbMM = ui.slider('##rfx2tm', self.p.turbMM or 15.0, 3, 60, 'Turbulence eddy size (T1): %.0f mm')
    self.p.shedU10 = ui.slider('##rfx2su', self.p.shedU10 or 20, 5, 40, 'Air speed that depins a 10 uL drop (wind tunnel ~10-20): %.0f m/s')
    self.p.shedBeta = ui.slider('##rfx2sb', self.p.shedBeta or 0.1, 0.0, 0.35, 'Size law U_c ~ V^-beta (small drops need more air): %.2f')
    do
      local P = self.physics
      local function kmh(r) return P.depinKmh(self.p, r, math.rad(45)) end   -- PHYS-UI: full shader law (BL, T1 RMS, F3)
      uiInfo(string.format('Depins at (theta 45 deg, pin 1): r0.1 %.0f  r0.2 %.0f  r0.3 %.0f  r0.5 %.0f  r1 %.0f  r2 %.0f km/h',
        kmh(0.1), kmh(0.2), kmh(0.3), kmh(0.5), kmh(1), kmh(2)))
    end
  end)
  uiSection('Drop motion on the surface (pinning, stick-slip, speed law)', true, function()
    if ui.checkbox('Dynamic retention: a moving contact line is held more (Cox-Voinov, F2b)', self.p.dynRet ~= false) then self.p.dynRet = self.p.dynRet == false end
    self.p.defMM = ui.slider('##rfx2dmm', self.p.defMM, 0.3, 5, 'Surface defect size: %.2f mm')
    self.p.defK = ui.slider('##rfx2dk', self.p.defK, 0, 15, 'Defects steer the head (zig-zag, x pinning asymmetry): %.1f')
    self.p.defPin = ui.slider('##rfx2dp', self.p.defPin, 0, 0.8, 'Defects hold the head (stick-slip): %.2f')
    self.p.strongK = ui.slider('##rfx2stk', self.p.strongK or 2.0, 0, 10, 'Strong defects hold x(1 + k S) (J1 stick-slip): %.1f')
    self.p.strongThr = ui.slider('##rfx2st', self.p.strongThr or 0.74, 0.6, 0.95, 'Strong defect level (0.74 = 15 %% of the area): %.2f')
    if ui.checkbox('Held drop escapes where its contact line is free (J1)', self.p.escape ~= false) then self.p.escape = self.p.escape == false end
    self.p.footPinK = ui.slider('##rfx2fpk', self.p.footPinK, 0, 1, 'Pinning by contact width across the force (Furmidge): %.2f')
    self.p.dropTau = ui.slider('##rfx2dt', self.p.dropTau, 0.0, 0.2, 'Drop inertia (speed follows the force over): %.3f s')
    self.p.neckHz = ui.slider('##rfx2nh', self.p.neckHz, 0.5, 15, 'Neck low-pass of accelerations: %.1f Hz')
    self.p.headAccK = ui.slider('##rfx2hk', self.p.headAccK, 0, 1, 'Head motion (visor transform) acceleration share: %.2f')
  end)
  uiSection('Drop births and sizes (impacts, splats, size law)', false, function()
    self.p.fragA = ui.slider('##rfx2fa', self.p.fragA, 0.3, 2.0, 'Size law exponent (0.88 = reference, x0.7 per 1.5x size): %.2f')
    self.p.fragHi = ui.slider('##rfx2fh', self.p.fragHi, 1.0, 6.0, 'Largest new drop (x typical fragment): %.1f')
    self.p.fragMax = ui.slider('##rfx2fm', self.p.fragMax, 1, 30, 'Small drops per raindrop impact (max): %.0f')
    self.p.clusterK = ui.slider('##rfx2ck', self.p.clusterK, 0, 1, 'Drop groups (clustered births): %.2f')
    self.p.maxRadiusMM = ui.slider('##rfx2mxr', self.p.maxRadiusMM, 0.2, 3.0, 'Largest drop on the visor (safety bound, 3.0): %.2f mm')
    self.p.fineRMM = ui.slider('##rfx2frm', self.p.fineRMM, 0.1, 0.5, 'Splash satellites below radius %.2f mm leave as mist')
    self.p.impactLoss = ui.slider('##rfx2il', self.p.impactLoss, 0, 1, 'Impact on a small drop: share splashed off %.2f')
    if ui.checkbox('Cap volume (R3: drop volume = spherical cap of the contact angle; off = rev7 hemisphere)', self.p.capVolume ~= false) then self.p.capVolume = (self.p.capVolume == false) end
    self.p.shpImpactK = ui.slider('##rfx2ik', self.p.shpImpactK, 0, 1, 'Impact stretch k: %.2f')
    self.p.shpImpactMax = ui.slider('##rfx2im', self.p.shpImpactMax, 1, 4, 'Impact stretch max: %.1f')
    self.p.shpSpreadMin = ui.slider('##rfx2sp0', self.p.shpSpreadMin, 1, 4, 'Impact splat spread min (x final radius): %.2f')
    self.p.shpSpreadMax = ui.slider('##rfx2sp1', self.p.shpSpreadMax, 1, 5, 'Impact splat spread max: %.2f')
    self.p.shpRecoilC = ui.slider('##rfx2spt', self.p.shpRecoilC or 3.0, 1, 30, 'Splat recoil: tau = %.1f x sqrt(rho r^3 / gamma) (3 = physical, ~11 ms at 1 mm)')
    self.p.shpSkidMax = ui.slider('##rfx2skm', self.p.shpSkidMax, 0, 0.15, 'Skid after impact, max: %.3f m/s')
    self.p.shpSkidK = ui.slider('##rfx2skid', self.p.shpSkidK, 0, 0.05, 'Impact push of a hit drop (newborns stick, U2): %.3f')
    self.p.shpLamShift = ui.slider('##rfx2lsh', self.p.shpLamShift, 0, 0.5, 'Splat residual walks downstream during recoil (x r (f0-1) aspect): %.2f')
    self.p.shpRimK = ui.slider('##rfx2rim', self.p.shpRimK or 0.6, 0, 0.85, 'Splat lamella rim share (thick rim, thin interior): %.2f')
    self.p.shpFingerK = ui.slider('##rfx2fng', self.p.shpFingerK or 0.25, 0, 0.6, 'Splat downstream fingers: %.2f')
    self.p.shpTearK = ui.slider('##rfx2tk', self.p.shpTearK, 0, 0.3, 'Torn rims of splashing impacts: %.2f')
  end)
  uiSection('Tail split, turns and sliding shape', false, function()
    self.p.shpSplitA = ui.slider('##rfx2spa', self.p.shpSplitA, 1.5, 4.5, 'Sliding drop sheds its tail above aspect: %.2f')
    self.p.shpSplitRate = ui.slider('##rfx2spr', self.p.shpSplitRate, 0, 20, 'Tail split events (while stretched / snapping): %.1f /s')
    self.p.shpSplitRMin = ui.slider('##rfx2spm', self.p.shpSplitRMin, 0.2, 1.5, 'Only drops above this radius split: %.2f mm')
    self.p.shpNeckK = ui.slider('##rfx2nk', self.p.shpNeckK, 0, 3, 'Split piece necks toward its parent: %.2f')
    self.p.shpNeckT = ui.slider('##rfx2nt', self.p.shpNeckT, 0.02, 0.5, 'Neck retracts over: %.2f s')
    self.p.shpTailTau = ui.slider('##rfx2tt', self.p.shpTailTau, 0.03, 1, 'Pinned tail follows a turn over: %.2f s')
    self.p.shpTailStretch = ui.slider('##rfx2tst', self.p.shpTailStretch, 0, 0.4, 'Head-tail stretch in a turn: %.2f')
    self.p.shpHookK = ui.slider('##rfx2hok', self.p.shpHookK, 0, 4, 'Head bends onto the new heading (hook, x tan): %.2f')
    self.p.shpFrontK = ui.slider('##rfx2frk', self.p.shpFrontK, 0, 3, 'Thick front moves to the outer side: %.2f')
    self.p.shpSnapDeg = ui.slider('##rfx2sd', self.p.shpSnapDeg, 10, 90, 'Tail lets go above: %.0f deg')
    self.p.shpMotionK = ui.slider('##rfx2smk', self.p.shpMotionK, 0, 1.5, 'Sliding head elongation: %.2f')
    self.p.shpRelaxMove = ui.slider('##rfx2sm', self.p.shpRelaxMove, 0.02, 2, 'Sliding drop morphs to its head shape over: %.2f s')
  end)
  uiSection('Coating state (B1d: wear, test dirt, wetting memory, tear-off)', false, function()
    if ui.checkbox('Receding angle varies with the coat state (B1d; debug 10 = theta_r map, green = wetting memory)', self.p.coatOn ~= false) then self.p.coatOn = self.p.coatOn == false end
    if ui.button('Tear off (new film: no wear, no memory, new defect field)') then
      self.coatSeed = (self.coatSeed or 0) + 37.7
      self.coatWear, self.p.coatWear = 0, 0
      self.coatResetFrames = 2
    end
    local w = ui.slider('##rfx2cw', self.coatWear or self.p.coatWear or 0, 0, 1, 'Coat wear level W (worn / scratched spots): %.2f')
    if w ~= (self.coatWear or self.p.coatWear or 0) then self.coatWear, self.p.coatWear = w, w end
    self.p.coatWearRate = ui.slider('##rfx2cwr', self.p.coatWearRate or 0, 0, 0.5, 'Wear growth while it rains: %.2f / min (0 = fixed)')
    self.p.coatKD = ui.slider('##rfx2ckd', self.p.coatKD or 0.5, 0, 0.8, 'Worn coat lowers theta_r by up to: %.2f')
    self.p.testDirt = ui.slider('##rfx2tdt', self.p.testDirt or 0, 0, 1, 'TEST road dirt level (until the dirt model): %.2f')
    self.p.coatKC = ui.slider('##rfx2ckc', self.p.coatKC or 0.5, 0, 0.8, 'Dirt lowers theta_r by up to: %.2f')
    self.p.dirtMM = ui.slider('##rfx2dmm', self.p.dirtMM or 3, 0.5, 20, 'Dirt patch size: %.1f mm')
    self.p.coatKM = ui.slider('##rfx2ckm', self.p.coatKM or 0.4, 0, 0.8, 'Wetting memory lowers theta_r by up to: %.2f')
    self.p.coatTauA = ui.slider('##rfx2cta', self.p.coatTauA or 1, 0.1, 10, 'Memory builds under water over: %.1f s')
    self.p.coatTauR = ui.slider('##rfx2ctr', self.p.coatTauR or 20, 1, 300, 'Memory recovers when dry over: %.0f s')
  end)
  uiSection('Trails and thin film', false, function()
    self.p.surfThetaRDeg = ui.slider('##rfx2ttr', self.p.surfThetaRDeg or 40, 5, 90, 'Coat receding contact angle (trails, sheet, drops; FILM-UNIFY): %.1f deg')
    self.p.trailWetK = ui.slider('##rfx2twk', self.p.trailWetK, 0, 0.8, 'Wet surface lowers the receding angle by: %.2f')
    self.p.trailLL = ui.slider('##rfx2tll', self.p.trailLL, 0, 20, 'Trail depth (x r Ca^2/3): %.1f')
    self.p.trailWidthK = ui.slider('##rfx2tw', self.p.trailWidthK, 0.1, 1.0, 'Trail width at high speed (x head radius): %.2f')
    if ui.checkbox('Drop tails (B1: head + attached tail on its path; debug 1 = yellow -> green centre line)', self.p.tailOn ~= false) then self.p.tailOn = self.p.tailOn == false end
    self.p.tailWidthK = ui.slider('##rfx2tlw', self.p.tailWidthK or 0.6, 0.2, 2, 'Tail rivulet width (x DRAWN head half-width x sqrt(1 - 1/s) / 2, >= 0.2): %.2f')
    self.p.tailNeckRho = ui.slider('##rfx2tnr', self.p.tailNeckRho or 0.75, 0.3, 1.0, 'Tail neck rises out of the head at %.2f x its radius (L2b; 1 = tail stays under the head)')
    self.p.tailFlat = ui.slider('##rfx2tlf', self.p.tailFlat or 0.85, 0, 0.95, 'Tail rivulet flat top (B3e: 0 = dome lens, 0.85 = transparent interior, refracting edges): %.2f')
    if ui.checkbox('Steep drops (R-steep: arrested / merged drops recede to the cap)', self.p.steep ~= false) then self.p.steep = self.p.steep == false end
    self.p.imgPupilMM = ui.slider('##rfx2ipp', self.p.imgPupilMM or 0.0, 0, 3, 'In-drop image defocus: camera pupil %.2f mm (R-img; 0 = sharp, defocus is a separate pass)')
    if ui.checkbox('Tone-compressed drop image (R-img5: lights do not flood small / blurred drops; off = linear HDR mips)', self.p.sceneCompress ~= false) then self.p.sceneCompress = self.p.sceneCompress == false end
    self.p.compressK = ui.slider('##rfx2cpk', self.p.compressK or 0.01, 0, 1, '  compression strength %.2f (0 = linear light spread, 1 = full)')
    if ui.checkbox('Stable lens (R-img3: one image mip per drop, no ddx / per-pixel tap noise; off = old)', self.p.lensStable ~= false) then self.p.lensStable = self.p.lensStable == false end
    self.p.cubeK = ui.slider('##rfx2cbk', self.p.cubeK or 0.7, 0, 3, 'Off-frame lens exits: reflection cubemap brightness %.2f (R-steep2)')
    self.p.cubeMip = ui.slider('##rfx2cbm', self.p.cubeMip or 2.0, 0, 6, 'Off-frame lens exits: cubemap blur (mip) %.1f')
    if ui.checkbox('Physical rim angle (S-fix: own angle, hysteresis front / rear, Bond flattening; off = old)', self.p.rimPhys ~= false) then self.p.rimPhys = self.p.rimPhys == false end
    self.p.bondFlatK = ui.slider('##rfx2bfk', self.p.bondFlatK or 0.5, 0, 4, 'Gravity top flattening k (r / 2.7 mm)^2: %.2f')
    if ui.checkbox('One water height field (B3h: head + tail + drops refract at one surface; off = B3g lens union)', self.p.surfH ~= false) then self.p.surfH = self.p.surfH == false end
    self.p.surfK = ui.slider('##rfx2sfk', self.p.surfK or 0.04, 0.005, 0.2, 'Height field smooth union width: %.3f mm')
    self.p.headRound = ui.slider('##rfx2hrd', self.p.headRound or 1.0, 0, 1, 'Sliding head round front (B3f corner drop: 0 = symmetric ellipse): %.2f')
    self.p.tailK = ui.slider('##rfx2tlk', self.p.tailK or 4, 0, 12, 'Tail length L = k r (s - 1), k: %.1f')
    self.p.tailMax = ui.slider('##rfx2tlm', self.p.tailMax or 20, 1, 30, 'Tail length max (x head radius; packed points reach 24 mm): %.1f')
    self.p.tailTau = ui.slider('##rfx2tlt', self.p.tailTau or 0.1, 0.02, 1, 'Tail length follows over: %.2f s')
    self.p.pearlRate = ui.slider('##rfx2pr', self.p.pearlRate, 0, 2, 'Trail beading into small drops (per cell): %.2f /s')
    self.p.trailSlopeMax = ui.slider('##rfx2ts2', self.p.trailSlopeMax, 0.1, 1.5, 'Trail edge slope max (rivulet height / width): %.2f')
    self.p.trailPinMM = ui.slider('##rfx2tp', self.p.trailPinMM, 0.0, 0.1, 'Trail runs along itself above: %.3f mm (below: pinned residue)')
    self.p.trailFlowK = ui.slider('##rfx2tf', self.p.trailFlowK, 0.0, 5.0, 'Trail flow speed (x film law): %.2f')
    self.p.runbackMax = ui.slider('##rfx2rm', self.p.runbackMax, 0.01, 0.5, 'Rivulet flow top speed (trail water): %.2f m/s')
    self.p.trailEvapMMs = ui.slider('##rfx2te', self.p.trailEvapMMs, 0.0, 0.05, 'Trail water evaporation: %.4f mm/s')
    self.p.filmBeadMM = ui.slider('##rfx2fb', self.p.filmBeadMM, 0.01, 0.2, 'Film gathers into a bead from: %.3f mm')
    self.p.dewetRate = ui.slider('##rfx2dw', self.p.dewetRate, 0, 20, 'Dewetting rate (per cell): %.1f /s')
  end)
  uiSection('Water film S2 (docs/RAINFX_V2_FILM_S2_DESIGN.md)', false, function()
    if ui.checkbox('Film S2 water model (film rules, transport, caps)', self.p.filmOn) then self.p.filmOn = not self.p.filmOn end
    self.p.filmFollowK = ui.slider('##rfx2wsf', self.p.filmFollowK, 0, 2, 'Drops follow the water paths: %.2f')
    s.filmK = ui.slider('##rfx2fk', s.filmK, 0, 5, 'Rain film supply gain (unresolved rain; keep 1): %.2f')
    self.p.filmJoinMM = ui.slider('##rfx2fjm', self.p.filmJoinMM or 0.10, 0.02, 0.3, 'Drops join a film from (F1): %.2f mm')
    self.p.filmThickMM = ui.slider('##rfx2ftm', self.p.filmThickMM or 0.30, 0.15, 1.0, 'Drops join a film only while it stays below (F1): %.2f mm')
    if ui.checkbox('Water beyond the largest drop spreads as film (R1 overflow)', self.p.filmSpill ~= false) then self.p.filmSpill = self.p.filmSpill == false end
    self.p.stickMin = ui.slider('##rfx2skm', self.p.stickMin or 0.25, 0, 0.5, 'Kept share floor of fast impacts (S1; 0 = old law): %.2f')
    if ui.checkbox('Mass audit (E3: reservoirs and losses, ~0.5 s readback)', self.p.audit == true) then self.p.audit = self.p.audit ~= true end
    local au = self.audit
    if self.p.audit and au then
      ui.text(string.format('E3 water on the visor (mm3): drops %.1f (%d, %d at the largest cap) | haze fine %.1f coarse %.1f | film %.1f | trail %.1f | total %.1f',
        au.drops, au.nDrops, au.nCap, au.hf, au.hc, au.film, au.trail, au.total))
      ui.text(string.format('E3 per second (mm3/s): in ~%.1f | change %s | haze cap runoff ~%.1f (fine at cap %.0f mm2, coarse %.0f mm2) | evaporation ~%.1f | rest %s',
        au.inflow, au.dTot and string.format('%.1f', au.dTot) or '-', au.capRun, au.capF, au.capC, au.evap, au.rest and string.format('%.1f', au.rest) or '-'))
      local e4 = au.e4
      if e4 then
        ui.text(string.format('E4 tails: big drops %d (moving >= 0.1 m/s %d, fastest %.2f m/s, coat theta_r there %.1f deg) | drops with s > 1: %d (largest s %.2f) | tails %d (longest %.1f mm)',
          e4.nBig, e4.nMove, e4.vMax, e4.nMove > 0 and e4.phiSum / e4.nMove or 0, e4.nS1, e4.sMax, e4.nTail, e4.lMax))
      end
    end
    if ui.checkbox('Trail beads that can move become drops (B2)', self.p.beadDrops ~= false) then self.p.beadDrops = self.p.beadDrops == false end
    if ui.checkbox('Smooth (B-spline) coarse scene mips: veil / blur light (V3)', self.p.sceneBicubic ~= false) then self.p.sceneBicubic = self.p.sceneBicubic == false end
    if ui.checkbox('Power-of-two refraction source (exact mips: lights do not drop out of the veil, V4)', self.p.sourcePot ~= false) then self.p.sourcePot = self.p.sourcePot == false end
    local stt = self.stats or {}
    ui.text(string.format('E2 arriving: rain %.3f mm/s (normal incidence, sticks %.0f %%) | spray %.3f mm/s (fine %.3f, coarse %.3f, visible %.3f)',
      stt.fluxMMs or 0, 100 * (stt.stickFrac or 0), stt.sprayMMs or 0, (stt.sprayMMs or 0) * (stt.sprayHazeShare or 0),
      (stt.sprayMMs or 0) * (stt.sprayCoarseShare or 0), (self.lastVals and self.lastVals.visMMs) or 0))
    local e = self.e1
    if e then
      ui.text(string.format('E1 supply %.4f mm/s | holds a 0.02 mm layer from %.3f, a 0.10 mm film from %.3f mm/s (x%.2f)',
        e.q, e.qFed, e.qVis, e.q / math.max(e.qFed, 1e-9)))
    end
    ui.text(string.format('B2 beads move from r = %s | film transport %s', (self.beadMoveR or 1e3) < 50 and string.format('%.2f mm', self.beadMoveR) or 'never (static)',
      self.filmGateOpen == false and 'idle (no film)' or 'running'))
    ui.text(string.format('F4b gate: %s | film blocks %d / 256 | reads %d / sent %d%s', self.filmGateOpen == nil and 'unknown' or (self.filmGateOpen and 'open' or 'closed'),
      self.filmGateBlocks or -1, self.filmGateReads or 0, self.filmGateSent or 0, self.filmGateErr and (' | ' .. self.filmGateErr) or ''))
    if self.filmGateMap then
      ui.text('F4b map (F film >= 0.02 mm, M mobile only, B both, T thick >= filmThickMM; 32 x 8 blocks):')
      for _, r in ipairs(self.filmGateMap) do ui.text(r) end
    end
  end)
  uiSection('Drop look (lens, shape, spread, film / scatter veil)', false, function()
    self.p.lensPhys = ui.slider('##rfx2lp', self.p.lensPhys, 0, 1.5, 'Lens strength (1 = physical water cap, one image): %.2f')
    s.contactDeg = ui.slider('##rfx2ca', s.contactDeg, 20, 90, 'Contact angle: %.0f deg (rim curl; normal 40-60)')
    s.wfSceneMip = ui.slider('##rfx2mip', s.wfSceneMip, 0, 6, 'Image blur in the drop (scene mip): %.1f')
    s.wobbleAmp = ui.slider('##rfx2wb', s.wobbleAmp, 0, 0.3, 'Wobble in airflow: %.2f')
    self.p.housingM = ui.slider('##rfx2hm', self.p.housingM, 0.00, 0.6, 'Refraction source: remove housing closer than %.2f m')
    if ui.checkbox('Refraction source: remove the housing by its own coverage shot (H-mask; depth rule below stays as a floor)', self.p.housingMask ~= false) then self.p.housingMask = self.p.housingMask == false end
    ui.text('  ' .. tostring(self.housingMaskStatus or '-'))
    if ui.checkbox('Hide water behind the helmet housing (depth test)', self.p.depthTest) then self.p.depthTest = not self.p.depthTest end
    if ui.checkbox('Shape state (off = rev47 seeded ellipse)', self.p.shpOn) then self.p.shpOn = not self.p.shpOn end
    self.p.shpDefShape = ui.slider('##rfx2ds', self.p.shpDefShape or 1.0, 0, 3, 'Birth contour from surface defects (x defect pinning): %.2f')
    self.p.shpRelaxStill = ui.slider('##rfx2sr', self.p.shpRelaxStill, 0.1, 60, 'Pinned shape is held for: %.1f s (r >= 0.3 mm)')
    self.p.shpBoK = ui.slider('##rfx2bo', self.p.shpBoK, 0, 3, 'Gravity sag of pinned drops (aspect 1 + k Bo): %.2f')
    self.p.shpSlugTau = ui.slider('##rfx2sg', self.p.shpSlugTau, 0.05, 3, 'Elongated drop keeps its length when it starts to slide: %.2f s')
    self.p.shpAirK = ui.slider('##rfx2sak', self.p.shpAirK, 0, 0.3, 'Air stretches pinned drops (x We_air): %.2f')
    self.p.baseSpread = ui.slider('##rfx2bs', self.p.baseSpread, 1, 2, 'Resting drop profile (splat rule at f): %.2f  [1 = dome; 1.3-1.5 = mid-recoil look]')
    if self.p.baseSpread > 1.001 then
      local f = self.p.baseSpread
      uiInfo(string.format('  -> footprint x%.2f, contact angle %.0f deg, flat top %.2f (visual only; physics radius unchanged)',
        f, (self.store.contactDeg or 60) / (f * math.sqrt(f)), 0.85 * math.min(f - 1, 1)))
    end
    self.p.asymK = ui.slider('##rfx2ak', self.p.asymK, 0, 0.6, 'Off-centre apex (thicker downhill / per-drop): %.2f')
    if ui.checkbox('Merge at the drawn footprint (resting spread x shape)', self.p.footPhys) then self.p.footPhys = not self.p.footPhys end
    self.p.shpMergeK = ui.slider('##rfx2mk', self.p.shpMergeK, 0, 1.5, 'Merged footprint elongation: %.2f')
    self.p.shpWaist = ui.slider('##rfx2mw', self.p.shpWaist, 0, 0.45, 'Merged pair peanut waist: %.2f')
    self.p.shpMergeTau = ui.slider('##rfx2mt', self.p.shpMergeTau or 0.015, 0.005, 5, 'Merged footprint recedes to theta_r over %.3f s / mm radius (Cox-Voinov ~0.01)')
    self.p.vMax = ui.slider('##rfx2vm', self.p.vMax, 0.005, 0.2, 'Motion stretch reference speed (visor only, R6): %.3f m/s')
    self.p.fadeTime = ui.slider('##rfx2fd', self.p.fadeTime, 0.0, 0.3, 'Swept drops fade out over %.2f s')
    self.p.growTime = ui.slider('##rfx2gt', self.p.growTime, 0.0, 0.3, 'New drops grow in over %.2f s')
    if ui.checkbox('Big-drop window (R7a: large / merged drops drawn and touching up to 4 cells away)', self.p.bigOn) then self.p.bigOn = not self.p.bigOn end
    s.filmRefract = ui.slider('##rfx2fr', s.filmRefract, 0, 40, 'Film refraction (wave gain): %.1f')
    s.filmVeil = ui.slider('##rfx2fv', s.filmVeil, 0, 1, 'Film veil: %.2f')
    s.scatterK = ui.slider('##rfx2sc', s.scatterK, 0, 3, 'Scatter veil (haze/film/spray): %.2f')
    if ui.button('Reset look to defaults (lens, defocus, film, scatter)') then
      self.p.lensPhys = DEFAULTS.lensPhys
      s.apertureMM, s.focusM, s.wfRefraction, s.wfSceneMip = DEFAULTS.apertureMM, DEFAULTS.focusM, DEFAULTS.wfRefraction, DEFAULTS.wfSceneMip
      s.contactDeg, s.wobbleAmp = DEFAULTS.contactDeg, DEFAULTS.wobbleAmp
      s.defocusDA = DEFAULTS.defocusDA
      s.filmRefract, s.filmVeil, s.scatterK = DEFAULTS.filmRefract, DEFAULTS.filmVeil, DEFAULTS.scatterK
    end
  end)
  uiSection('Defocus (final step, off by default)', false, function()
    s.apertureMM = ui.slider('##rfx2ap', s.apertureMM, 0, 4, 'Aperture %.2f mm (0 = sharp)')
    s.focusM = ui.slider('##rfx2fz', s.focusM, 0.03, 1.0, 'Focus distance %.3f m')
    if ui.checkbox('D-A colour gather (4 taps near the lens; off = D-C analytic)', s.defocusDA) then s.defocusDA = not s.defocusDA end
    if self.cocInfo then uiInfo(self.cocInfo) end
  end)
  uiSection('Physics test and readouts', false, function()
    self:physicsUI()
    local st = self.stats
    uiInfo(string.format('Rain %.1f mm/h  mean D %.2f mm  rel. speed %.1f m/s',
      st.rateMMh or 0, st.meanDiamMM or 0, st.speedRel or 0))
    uiInfo(string.format('Impacts %.0f /m2/s  splash K %.0f  resolved %.2f in %.2f mm fragments  fine spray %.2f um/s',
      st.impactRate or 0, st.splashK or 0, st.stickFrac or 0, st.fragDiamMM or 0, (st.sprayMMs or 0) * 1000))
    if st.dq then   -- rev48-P1 supply DSD (constrained gamma) and the impacting-diameter quantiles
      local sm = ac.getSim()
      uiInfo(string.format('Supply DSD: D0 %.2f mm (family x%.1f)  mu %.1f  Lambda %.1f /mm | impacting D p50 %.2f p90 %.2f p99 %.2f mm',
        st.dsdD0 or 0, st.familyK or 1, st.dsdMu or 0, st.dsdLambda or 0, st.dq[8] or 0, st.dq[12] or 0, st.dq[15] or 0))
      uiInfo(string.format('CSP weather (P3 log): type %s  intensity %.3f  wetness %.3f  water %.3f',
        tostring(sm.weatherType), sm.rainIntensity or 0, sm.rainWetness or 0, sm.rainWater or 0))
      uiInfo(string.format('Sub-cloud evaporation (F6): cloud base %.0f m, %.1f %% of the rain mass reaches the ground (%.3f of %.3f mm/h)',
        st.cloudBaseM or 0, (st.groundShare or 1) * 100, st.groundMMh or 0, st.rateMMh or 0))
      uiInfo(string.format('Air (CSP): RH %.0f %%  T %.0f C (drop evaporation, sub-cloud evaporation)', (self.fineRH or 0) * 100, self.fineT or 0))
    end
    if self.sourceErr then uiInfo('Refraction source: ' .. self.sourceErr) end
  end)
  uiSection('Measurement and metrics (M-REF, CSV, replay)', false, function()
    self:metricsUI()
  end)
  uiSection('Diagnostics and performance', false, function()
    s.debug = ui.slider('##rfx2dbg', s.debug, 0, 11, '(%.0f) Debug: 11 drop rim angle (blue 20 .. red 60 deg) 10 sheet state (R supply/q_c, G connected, B lamella, white >= 0.3 mm) 1 water 2 exposure 3 refr.src 4 physics 5 film 6 defocus 7 lens (R rho, G squeeze, B TIR/mip) 8 coverage 9 lens direction (R looks down, G up)', true)
    if ui.checkbox('Highlight impacts (magenta = born by an impact < 0.3 s, yellow = drop hit this frame)', self.p.hiImpact) then self.p.hiImpact = not self.p.hiImpact end
    if ui.checkbox('Highlight split pieces (cyan, 1.5 s)', self.p.hiSplit) then self.p.hiSplit = not self.p.hiSplit end
    self.p.perfProbe = ui.slider('##rfx2pp', self.p.perfProbe or 0, 0, 2, 'Visor cost probe: %.0f (0 off | 1 setup only | 2 + drop union, no lens) -- diagnostics', true)
    if ui.checkbox('Drop records (PERF-9: candidates computed once per drop)', self.p.useRec ~= false) then self.p.useRec = self.p.useRec == false end
    if ui.checkbox('Candidate mask (PERF-10: only drops that reach the cell)', self.p.useMask ~= false) then self.p.useMask = self.p.useMask == false end
    self.p.tightReach = ui.slider('##rfx2tr', self.p.tightReach or 1, 0, 2, 'Tight drop support: %.0f (0 legacy | 1 on | 2 verify: red = skipped drop contributed)', true)
    if ui.checkbox('Look lab: static reference-sized drops, all other effects off', self.lookLab == true) then
      self.lookLab = not self.lookLab
      self.labSeeded = false
    end
    if self.lookLab then
      ui.sameLine()
      if ui.button('New drop set') then self.labRequest = true end
      local p = self.p
      local v1, c1 = ui.slider('##rfx2lo', p.labOcc, 0.05, 0.8, 'Lab occupancy per cell: %.2f')
      local v2, c2 = ui.slider('##rfx2lr', p.labRMaxMM, 0.5, 3.0, 'Lab largest radius: %.2f mm')
      p.labOcc, p.labRMaxMM = v1, v2
      if c1 or c2 then self.labRequest = true end
    end
    s.substeps = ui.slider('##rfx2sub', s.substeps, 1, 4, 'Min substeps: %.0f (auto up to 4)', true)
    if ui.checkbox('Invert exposure side (auto: side facing away from the eye)', s.invertSide) then s.invertSide = not s.invertSide end
    self:offscreenTestUI()
    uiInfo('GPU/CPU cost: Render Stats -> "RainFX2 sim" / "RainFX2 draw".')
  end)
end

-- rev12 evaluation metrics: GPU block reduction (32x8) + async readback at 2 Hz, optional CSV.
local METRICS_HEADER = 'clock,weatherType,rainIntensity,rainWetness,rainWater,windKmh,carKmh,rainFluxMMs,spray,sprayCars,nearestM,filmRate,filmEqMM,filmCover,dropCover,haze,substeps,apertureMM,focusM,defocusDA,contactDeg,wfRefraction,wfSceneMip,filmRefract,filmVeil,scatterK,drops,sizeP50MM,p90p50,p99p50,binRatio,fragA,fragHi,dropDepthUM,residenceS,stagElevDeg,nBand0,p99Band0MM,nBand1,p99Band1MM,nBand2,p99Band2MM,simTimeS,replay,replayFrame,replayRate,sceneTag,fps,airT,airRH,cspAirT,windDirDeg,cloudBaseM,groundShare,rateMMh,groundMMh,impactRate,meanDiamMM,stickFrac,speedRel,sprayMMs,splashMMs,roadWet,leadKmh,leadLatM,dropsPerCm2,filmRateRain,selfFrontWaterMM,selfRearWaterMM,leadWaterMM,packWaterMM,aheadWaterMM,selfPuddle,wheelMode\n'
-- F4b FILM GATE (docs/RAINFX_V2_FILM_S2_DESIGN.md section 10): the film substeps run only while the field holds film or a
-- mobile body somewhere (filmany.hlsl 32x8 summary, async readback). Unknown (first frames, failed read) = open. A gate that
-- saw film stays open 30 frames (no flapping); new film starts moving 1-3 frames after it appears (no pop: it only waits).
function R2:filmGate()
  if self.p.filmGate == false then return true end
  return self.filmGateOpen ~= false
end
function R2:filmGateUpdate()
  if self.p.filmGate == false or self.filmGateBusy then return end
  local pg = self.passFilmAny
  pg.textures.txR2Field = self.F[self.fi]
  sceneValues(self, pg.values)
  if not run(self.FAc, pg) then self.filmGateOpen = nil; self.filmGateErr = 'pass not run'; return end
  self.filmGateBusy = true
  self.filmGateSent = (self.filmGateSent or 0) + 1
  local tmp = rgbm()
  self.FAc:accessData(function(err, data)
    self.filmGateBusy = false
    if err or not data then self.filmGateOpen = nil; self.filmGateErr = tostring(err or 'no data'); return end
    local hit, n, rows = false, 0, {}
    for y = 0, 7 do
      local row = {}
      for x = 0, 31 do
        data:colorTo(tmp, x, y)
        local f, m, th = tmp.rgb.r > 0.5, tmp.rgb.g > 0.5, tmp.rgb.b > 0.5
        -- F4d (2026-11-15): the transport moves only MOBILE bodies (F5); pinned film is the field's (retreat, caps, sources).
        -- Gating on film kept the transport running for one pinned spot (game test: 1 / 256 blocks, film 0.265 ms)
        if m then hit = true end
        if f or m then n = n + 1 end
        row[#row + 1] = th and 'T' or ((f and m) and 'B' or (f and 'F' or (m and 'M' or '.')))
      end
      rows[#rows + 1] = table.concat(row)
    end
    self.filmGateMap = rows   -- diagnostic: F film >= wet, M mobile flag only, B both (field u -> right, v -> down)
    data:dispose()
    self.filmGateBlocks, self.filmGateReads, self.filmGateErr = n, (self.filmGateReads or 0) + 1, nil
    if hit then self.filmGateHold = 30 else self.filmGateHold = (self.filmGateHold or 0) - 1 end
    self.filmGateOpen = hit or self.filmGateHold > 0
  end)
end

-- E3 MASS AUDIT (docs/RAINFX_V2_S_REVIEW.md section 7): reservoir totals (audit.hlsl) every ~0.5 s while p.audit is on, and the
-- per-second balance: inflow (arriving x kept x exposed area) = change of the reservoirs + haze cap runoff + evaporation + rest
-- (rest = drops leaving the visor, splash of drops hitting drops, losses not modelled here).
function R2:auditUpdate()
  if not self.p.audit or self.auditBusy or not self.passAudit then return end
  local now = os.clock()
  if self.auditT and now - self.auditT < 0.5 then return end
  local pa = self.passAudit
  pa.textures.txR2State = self.S[self.si]
  pa.textures.txR2Field = self.F[self.fi]
  pa.textures.txR2Haze = self.HZ and self.HZ[self.hi] or false
  sceneValues(self, pa.values)
  if not run(self.AUc, pa) then return end
  self.auditBusy = true
  local tmp = rgbm()
  local tNow = now
  self.AUc:accessData(function(err, data)
    self.auditBusy = false
    if err or not data then self.auditErr = tostring(err); return end
    local s = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
    local e4 = { vMax = 0, sMax = 0, phiSum = 0, lMax = 0 }
    for y = 0, 7 do
      for x = 0, 159 do
        data:colorTo(tmp, x, y)
        if x < 128 then
          local k = math.floor(x / 32) * 4
          s[k + 1], s[k + 2], s[k + 3], s[k + 4] = s[k + 1] + tmp.rgb.r, s[k + 2] + tmp.rgb.g, s[k + 3] + tmp.rgb.b, s[k + 4] + tmp.mult
        else   -- E4 maxima
          e4.vMax, e4.sMax = math.max(e4.vMax, tmp.rgb.r), math.max(e4.sMax, tmp.rgb.g)
          e4.phiSum, e4.lMax = (e4.phiSum or 0) + tmp.rgb.b, math.max(e4.lMax, tmp.mult)
        end
      end
    end
    e4.nBig, e4.nMove, e4.nS1, e4.nTail = s[13], s[14], s[15], s[16]
    data:dispose()
    local a = { drops = s[1], film = s[2], trail = s[3], expA = s[4], hf = s[5], hc = s[6], capF = s[7], capC = s[8],
      trailA = s[9], nDrops = s[10], nCap = s[11], visA = s[12] }
    a.total = a.drops + a.film + a.trail + a.hf + a.hc
    local prev = self.audit
    if prev and tNow > prev.t then a.dTot = (a.total - prev.total) / (tNow - prev.t) end
    local st, lv, p = self.stats or {}, self.lastVals or {}, self.p
    local expAvg = a.visA > 0 and a.expA / a.visA or 0
    a.inflow = ((st.fluxMMs or 0) + (st.sprayMMs or 0)) * (st.stickFrac or 0) * a.expA
    a.capRun = (a.capF * ((lv.supFine or 0) + (st.hazeMMs or 0)) + a.capC * (lv.supCoarse or 0)) * expAvg * (p.exposure or 1)
    a.evap = (self.lastFineEvapK or 0) * a.hf + (p.trailEvapMMs or 0) * a.trailA
    if a.dTot then a.rest = a.inflow - a.dTot - a.capRun - a.evap end
    a.t = tNow
    a.e4 = e4
    self.audit = a
  end)
end

function R2:metricsUpdate(sim)
  if not (self.store.metrics or self.recording) or self.metricsBusy then return end
  local now = os.clock()
  if self.metricsT and now - self.metricsT < 0.5 then return end
  self.metricsT = now
  local pm = self.passMetrics
  pm.textures.txR2State = self.S[self.si]
  pm.textures.txR2Field = self.F[self.fi]
  sceneValues(self, pm.values)
  if not run(self.Mc, pm) then return end
  self.metricsBusy = true
  local tmp = rgbm()
  self.Mc:accessData(function(err, data)
    self.metricsBusy = false
    if err or not data then self.metricsErr = tostring(err); return end
    local w, f, d, h = 0, 0, 0, 0
    for y = 0, 7 do
      for x = 0, 31 do
        data:colorTo(tmp, x, y)
        local a = tmp.mult
        w, f, d, h = w + a, f + tmp.rgb.r * a, d + tmp.rgb.g * a, h + tmp.rgb.b * a
      end
    end
    data:dispose()
    w = math.max(w, 1e-6)
    local m = self.metrics or {}
    m.film, m.drops, m.haze = f / w, d / w, h / w
    m.validFrac = w / 256                      -- rev47d: share of the 32x8 blocks on the visor
    self.metrics = m
    if self.recording then self:metricsWrite(sim) end
  end)
  self:sizesUpdate()
end

-- rev40 drop size histogram (sizes.hlsl): counts per 1.5x radius bin, percentiles, bin ratio.
-- Reference (docs/RAINFX_V2_DROP_PIPELINE_PLAN.md section 2): counts fall x0.7 per bin,
-- p90/p50 ~ 3-3.5, p99/p50 >= 10 (measured on diameters in px; radius ratios are the same).
function R2:sizesUpdate()
  if self.sizesBusy then return end
  local ph = self.passSizes
  ph.textures.txR2State = self.S[self.si]
  sceneValues(self, ph.values)
  if not run(self.Hc, ph) then return end
  self.sizesBusy = true
  local tmp = rgbm()
  local b0 = self.p.sizeBin0MM
  self.Hc:accessData(function(err, data)
    self.sizesBusy = false
    if err or not data then self.metricsErr = tostring(err); return end
    -- rev48-M3: also per third of the cell rows (stripes 0-4 / 5-10 / 11-15 along the visor V axis), so the
    -- large-drop tail can be located (air-facing band vs lower / lee band)
    local c, total = {}, 0
    local cb, tb = { {}, {}, {} }, { 0, 0, 0 }
    for x = 0, 9 do
      local n = 0
      local nb = { 0, 0, 0 }
      for y = 0, 15 do
        data:colorTo(tmp, x, y)
        local v = math.floor(tmp.rgb.r * 255 + 0.5) * 256 + math.floor(tmp.rgb.g * 255 + 0.5)
        n = n + v
        local band = y <= 4 and 1 or (y <= 10 and 2 or 3)
        nb[band] = nb[band] + v
      end
      c[x + 1], total = n, total + n
      for k = 1, 3 do cb[k][x + 1], tb[k] = nb[k], tb[k] + nb[k] end
    end
    data:dispose()
    local h = { counts = c, total = total }
    local function pctOf(cc, tot, q)
      if tot <= 0 then return 0 end
      local target, cum = q * tot, 0
      for k = 1, 10 do
        if cum + cc[k] >= target and cc[k] > 0 then
          return b0 * 1.5 ^ (k - 1 + (target - cum) / cc[k])
        end
        cum = cum + cc[k]
      end
      return b0 * 1.5 ^ 10
    end
    local function pct(q) return pctOf(c, total, q) end
    h.p50, h.p90, h.p99 = pct(0.5), pct(0.9), pct(0.99)
    h.band = {}
    for k = 1, 3 do h.band[k] = { n = tb[k], p50 = pctOf(cb[k], tb[k], 0.5), p99 = pctOf(cb[k], tb[k], 0.99) } end
    -- rev47d water budget: standing drop water (bin-centre radii, cap volume shapeK r^3) as a mean depth
    -- over the visor, against the incoming rain flux -> residence time of the water as drops.
    local vol = 0
    for k = 1, 10 do
      local rc = b0 * 1.5 ^ (k - 0.5)
      vol = vol + c[k] * self.p.shapeK * rc * rc * rc
    end
    local area = 602.0 * 146.3 * math.max((self.metrics and self.metrics.validFrac) or 1, 0.05)
    h.depthUM = vol / area * 1000
    local flux = (self.stats.fluxMMs or 0) * self.p.exposure
    h.residence = flux > 1e-6 and (vol / area) / flux or 0
    local ls, nr = 0, 0
    for k = 2, 8 do
      if c[k] > 0 and c[k + 1] > 0 then ls, nr = ls + math.log(c[k + 1] / c[k]), nr + 1 end
    end
    h.ratio = nr > 0 and math.exp(ls / nr) or 0
    self.sizeHist = h
  end)
end

function R2:metricsWrite(sim)
  local s, st, si, m, d = ac.getSim(), self.stats, self.sprayInfo or {}, self.metrics, self.diag or {}
  local h = self.sizeHist or { total = 0, p50 = 0, p90 = 0, p99 = 0, ratio = 0 }
  local p50 = math.max(h.p50, 1e-6)
  local bd = h.band or { { n = 0, p99 = 0 }, { n = 0, p99 = 0 }, { n = 0, p99 = 0 } }
  local line = string.format('%.2f,%d,%.4f,%.4f,%.4f,%.1f,%.1f,%.4f,%.3f,%d,%.1f,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%.2f,%.2f,%d,%.0f,%.2f,%.1f,%.2f,%.2f,%.2f,%d,%.3f,%.2f,%.2f,%.3f,%.2f,%.2f,%.2f,%.3f,%.1f,%d,%.3f,%d,%.3f,%d,%.3f\n',
    os.clock(), s.weatherType or -1, s.rainIntensity or 0, s.rainWetness or 0, s.rainWater or 0,
    s.windSpeedKmh or 0, (st.carSpeed or 0) * 3.6, st.fluxMMs or 0, st.spray or 0, si.cars or 0, si.nearestM or -1,
    st.filmRate or 0, d.filmEqMM or 0, m.film, m.drops, m.haze, self.p.substeps or 0,
    self.store.apertureMM, self.store.focusM, self.store.defocusDA and 1 or 0, self.store.contactDeg,
    self.store.wfRefraction, self.store.wfSceneMip,
    self.store.filmRefract, self.store.filmVeil, self.store.scatterK,
    h.total, h.p50, h.p90 / p50, h.p99 / p50, h.ratio, self.p.fragA, self.p.fragHi, h.depthUM or 0, h.residence or 0,
    self.p.stagElevDeg or 0, bd[1].n, bd[1].p99, bd[2].n, bd[2].p99, bd[3].n, bd[3].p99)
  -- M-REF (2026-11-06, docs/RAINFX_V2_SPRAY_RAIN_REF.md): replay sync + supply chain + spray source, appended columns
  local area = 602.0 * 146.3 * math.max((m and m.validFrac) or 1, 0.05)   -- mm^2 of visor in the metric blocks
  line = line:sub(1, -2) .. string.format(',%.3f,%d,%d,%.2f,%d,%.0f,%.1f,%.3f,%.1f,%.0f,%.0f,%.3f,%.3f,%.3f,%.1f,%.3f,%.3f,%.2f,%.5f,%.5f,%.3f,%.1f,%.2f,%.3f,%.5f\n',
    (s.time or 0) / 1000, s.isReplayActive and 1 or 0, s.replayCurrentFrame or -1, s.replayPlaybackRate or 0,
    self.sceneTag or 0, s.fps or 0, self.fineT or 0, self.fineRH or 0, self.cspT or -99, s.windDirectionDeg or 0,
    st.cloudBaseM or 0, st.groundShare or 0, st.rateMMh or 0, st.groundMMh or 0, st.impactRate or 0, st.meanDiamMM or 0,
    st.stickFrac or 0, st.speedRel or 0, st.sprayMMs or 0, st.splashMMs or 0, si.wet or 0, si.nearestKmh or -1,
    si.nearestLatM or -1, (h.total or 0) / (area * 0.01), st.rainFilm or 0)
  line = line:sub(1, -2) .. string.format(',%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d\n',   -- PUD-1 probe: wheel water (mm, -1 n/a)
    si.selfFrontMM or -1, si.selfRearMM or -1, si.leadWaterMM or -1, si.packWaterMM or -1, si.aheadWaterMM or -1,
    si.selfPuddle or 0, (self.p.sprayWheelWater ~= false and not self.store.roadFix) and 1 or 0)
  local ok = pcall(function()
    local f = io.open(self.recordPath, 'a')
    if f then f:write(line); f:close() end
  end)
  if not ok then self.metricsErr = 'CSV write failed: ' .. tostring(self.recordPath) end
end

function R2:metricsUI()
  local s = self.store
  if ui.checkbox('Metrics (GPU block reduction, readback 2 Hz)', s.metrics) then s.metrics = not s.metrics end
  if ui.checkbox('Record metrics CSV', self.recording or false) then
    self.recording = not self.recording
    if self.recording then
      self.recordPath = self.ctx.folder .. '/rainfx2_metrics_' .. os.date('%Y%m%d_%H%M%S') .. '.csv'
      pcall(function() local f = io.open(self.recordPath, 'w'); if f then f:write(METRICS_HEADER); f:close() end end)
    end
  end
  local m = self.metrics
  if m then
    uiInfo(string.format('Film cover %.1f %%  drop cover %.2f %%', m.film * 100, m.drops * 100))
  end
  local h = self.sizeHist
  if h and h.total > 0 then
    local b0, parts = self.p.sizeBin0MM, {}
    for k = 1, 10 do parts[k] = string.format('%.2f:%d', b0 * 1.5 ^ (k - 1), h.counts[k]) end
    uiInfo('Drops by radius (mm, 1.5x bins): ' .. table.concat(parts, '  '))
    uiInfo(string.format('Radius p50 %.2f mm  p90/p50 %.1f  p99/p50 %.1f  bin ratio %.2f  (reference: 3-3.5, >= 10, 0.70)',
      h.p50, h.p90 / math.max(h.p50, 1e-6), h.p99 / math.max(h.p50, 1e-6), h.ratio))
    uiInfo(string.format('Water budget: rain in %.3f mm/s (x exposure)  standing as drops %.1f um  -> residence %.2f s  | film supply %.3f mm/s%s',
      (self.stats.fluxMMs or 0) * self.p.exposure, h.depthUM or 0, h.residence or 0, self.stats.filmRate or 0,
      (self.store.filmK or 1) <= 0 and '  (Rain film supply gain 0: unresolved rain is dropped)' or ''))
  end
  -- M-REF: scene tag (CSV column sceneTag) and the replay air temperature
  if ui.button('Clear visor water (start a measured segment empty)') then self.clearRequest = true end
  self.sceneTag = math.floor(ui.slider('##rfx2tag', self.sceneTag or 0, 0, 9, 'Scene tag (CSV): %.0f  (e.g. 1 stop, 2 solo fast, 3 pack fast, 4 pack slow)') + 0.5)
  if ui.checkbox('Fix air temperature (replays do not record it)', self.store.airTFix) then self.store.airTFix = not self.store.airTFix end
  if ui.checkbox('Fix rain intensity for RainFX supply (measurement; CSP road water / spray unchanged)', self.store.intensityFix) then self.store.intensityFix = not self.store.intensityFix end
  if self.store.intensityFix then self.store.intensityFixV = ui.slider('##rfx2ifx', self.store.intensityFixV * 100, 0, 40, 'Rain intensity: %.1f %%') / 100 end
  if ui.checkbox('Fix road water / wetness for the spray estimate (reference: water 30-40 %, wetness 10-15 %)', self.store.roadFix) then self.store.roadFix = not self.store.roadFix end
  if self.store.roadFix then
    self.store.roadFixWater = ui.slider('##rfx2rfw', self.store.roadFixWater * 100, 0, 100, 'Road water: %.0f %%') / 100
    self.store.roadFixWet = ui.slider('##rfx2rfe', self.store.roadFixWet * 100, 0, 100, 'Road wetness: %.0f %%') / 100
  end
  if self.store.airTFix then self.store.airTFixC = ui.slider('##rfx2atc', self.store.airTFixC, -10, 45, 'Air temperature: %.1f C') end
  local s0 = ac.getSim()
  uiInfo(string.format('Replay %s  frame %d  rate %.2f  | air %.1f C (CSP %.1f)  RH %.0f %%',
    s0.isReplayActive and 'on' or 'off', s0.replayCurrentFrame or -1, s0.replayPlaybackRate or 0,
    self.fineT or 0, self.cspT or -99, (self.fineRH or 0) * 100))
  if self.recording then uiInfo('Recording: ' .. tostring(self.recordPath)) end
  if self.metricsErr then uiInfo('Metrics: ' .. self.metricsErr) end
end

-- Water film / spray panel (rev11).
-- UI-1: filmUI split into the Spray / Water sheet / Look sections of R2:ui

-- Physics review panel (rev7): inputs breakdown, analytic thresholds, test tools.
function R2:physicsUI()
  local s, p, i, d = self.store, self.p, self.inp, self.diag
  local P = self.physics
  ui.separator()
  uiInfo('Physics (rainfx2/physics.lua, docs/RAINFX_V2_CORE.md section 14)')
  if ui.checkbox('Freeze rain (no new drops / haze)', s.freezeRain) then s.freezeRain = not s.freezeRain end
  self.timeScale = ui.slider('##rfx2ts', self.timeScale or 1, 0.05, 1, 'Physics time scale: %.2f (slow motion, not saved)')
  s.windK = ui.slider('##rfx2wk', s.windK, 0, 1, 'Ambient wind reaching the visor: %.2f')
  if ui.button('Physics test: drop ladder 0.3..2.2 mm (left -> right)') then
    self.ladderRequest = true
    s.freezeRain = true
  end
  uiInfo('Debug 4: pinned = blue residue/merged, cyan split piece, white satellite | green <0.1 | yellow <0.3 | orange <0.6 | red >=0.6 m/s | magenta step-limited')
  if not i or not d then return end
  uiInfo(string.format('Car %.1f m/s  wind %.1f m/s (sim windSpeedKmh %.1f m/s, from %s)  air rel. %.1f m/s  accel %.2f g',
    i.carSpeed, i.windSpeed, i.windSpeedSim, i.windSource or '?', i.airSpeed, i.accelG))
  local rd = self.rainDirW
  if rd then
    uiInfo(string.format('Rain direction (world, relative to the visor): x %.2f y %.2f z %.2f -> %.0f deg from vertical (Debug 2 follows this)',
      rd.x, rd.y, rd.z, math.deg(math.acos(math.max(-1, math.min(1, -rd.y))))))
  end
  uiInfo(string.format('Wind direction convention: offset %.0f deg (%s). Calibrates itself while a live session has wind.',
    p.windDirOffsetDeg or s.windDirOffsetDeg or 180, s.windDirCalibrated and 'calibrated' or 'default: meteorological from'))
  if ui.button('Flip wind convention (180 deg)') then
    p.windDirOffsetDeg = ((p.windDirOffsetDeg or 180) + 180) % 360
    s.windDirOffsetDeg = p.windDirOffsetDeg
  end
  local function rc(v) return v == math.huge and 'never' or string.format('%.2f mm', v) end
  uiInfo(string.format('Slides by gravity from r = %s (coat), %s (glass), keeps sliding from %s; with air (coat) %s',
    rc(d.rcGravCoat), rc(d.rcGravGlass), rc(d.rcGravCoatKin), rc(d.rcAllCoat)))
  uiInfo(string.format('Speed (coat, forces aligned, R6 uncapped): r0.5 %.2f  r1 %.2f  r2 %.2f m/s',
    d.v05, d.v10, d.v20))
  local U = i.airSpeed or 0
  uiInfo(string.format('Helmet air: outer flow %.1f m/s, boundary layer %.2f mm | swept alone from r = %s (2 deg) %s (20 deg) %s (50 deg)',
    self.aeroU or 0, self.aeroDelta or 0, rc(P.aeroCritical(p, U, math.rad(2), p.pinCoat)),
    rc(P.aeroCritical(p, U, math.rad(20), p.pinCoat)), rc(P.aeroCritical(p, U, math.rad(50), p.pinCoat))))
  uiInfo(string.format('Acceleration (car + head): raw %.2f g -> neck-filtered %.2f g', i.accRawG or 0, i.accFiltG or 0))
  local hl = self.helmetUpLocal
  uiInfo(string.format('Helmet axes from the visor transform (not the camera): local up (%d,%d,%d), up . world up = %.2f',
    hl and hl.x or 0, hl and hl.y or 0, hl and hl.z or 0, self.helmetUpY or 0))
  ui.sameLine()
  if ui.button('Re-pick helmet up') then self.helmetUpLocal = nil end
  uiInfo(string.format('Substeps %d -> step limit %.2f m/s (faster drops are speed-limited)',
    p.substeps or 0, d.vGather))
end

function R2:dispose()
  -- PERF-1 / LIFE-1: release EVERY GPU resource; each release is guarded and every field is cleared even if one
  -- fails, so a later ensureResources / ensureMesh always rebuilds from a clean state.
  local function free(c) if c then pcall(c.dispose, c) end end
  for _, list in ipairs({ self.S or {}, self.F or {}, self.TG or {}, self.LM or {}, self.HZ or {} }) do
    for _, c in ipairs(list) do free(c) end
  end
  for _, k in ipairs({ 'C', 'PR', 'REC', 'MSK', 'HZM', 'HZV', 'SK', 'BG', 'TT', 'Mc', 'Hc', 'source', 'testCanvas', 'mesh' }) do
    free(self[k]); self[k] = nil
  end
  self.sceneTex = nil
  self.S, self.F, self.TG, self.LM, self.HZ, self.ready, self.opticsReady = nil, nil, nil, nil, nil, false, false
  self.paramsColour, self.paramsDepth, self.passSource, self.passSeed = nil, nil, nil, nil
  self.simFrame, self.colourViewKey, self.depthViewKey = nil, nil, nil
  self.recValid, self.recS, self.recLM, self.passRec = false, nil, nil, nil   -- PERF-9
  self.mskValid, self.passMsk = false, nil   -- PERF-10
  self.hzmValid, self.passHzm = false, nil   -- N3
  self.hzvValid, self.passHzv = false, nil   -- H3-P2
  if self.WM then free(self.WM[1]); free(self.WM[2]) end
  self.WM, self.wmValid, self.passWm = nil, false, nil   -- T1
  self.drawW, self.drawH, self.sizeKey, self.sizeVotes = nil, nil, nil, 0
  self.metricsBusy, self.sizesBusy = false, false   -- a readback in flight on a disposed canvas never returns
  self.labSeeded = false
end

-- LIFE-1 (realvisor rainfx2Lifecycle, from script.update): GLASS_RAINFX hidden -> suspend, shown -> resume
function R2:suspend()
  self:dispose()
  self.status = 'off: GLASS_RAINFX hidden (no simulation, no draw, GPU resources released)'
end
function R2:resume()
  self:dispose()          -- idempotent: whatever survived is rebuilt
  self.err = nil          -- an error of the previous run does not block the restart
  self.status = 'restarting'
end

return function(ctx)
  local self = setmetatable({}, R2)
  self.ctx = ctx
  self.status = 'idle'
  self.p = {}
  for k, v in pairs(DEFAULTS) do self.p[k] = v end
  self.physics = dofile(ctx.folder .. '/rainfx2/physics.lua')
  for k, v in pairs(self.physics.DEFAULTS) do self.p[k] = v end
  self.spray = dofile(ctx.folder .. '/rainfx2/spray.lua')
  for k, v in pairs(self.spray.DEFAULTS) do self.p[k] = v end
  self.store = ac.storage(STORED, 'rfx2_')
  self.weather = dofile(ctx.folder .. '/rainfx2/weather.lua')
  self.stats = {}
  local dir = ctx.folder .. '/rainfx2/shaders/'
  local tgs = readFile(dir .. 'tgshared.hlsl')   -- TR0 / TR2b: trail packing + bead rows, shared by sim and visor
  local common = tgs and readFile(dir .. 'common.hlsl') and (tgs .. '\n' .. readFile(dir .. 'common.hlsl')) or nil
  local cand = tgs and readFile(dir .. 'cand.hlsl') and (tgs .. '\n' .. readFile(dir .. 'cand.hlsl')) or nil   -- PERF-9: candidate code shared by visor and rec
  local src = {}
  for _, name in ipairs({ 'hazenuc', 'wmalias', 'haze', 'cells', 'predict', 'field', 'trail', 'visor', 'source', 'claim', 'merge', 'seed', 'metrics', 'sizes', 'filmcoef', 'film', 'filmany', 'audit', 'lam', 'big', 'tailtex', 'rec', 'msk', 'hzm', 'hzv', 'wm' }) do
    src[name] = readFile(dir .. name .. '.hlsl')
    if not src[name] or not common or not cand then
      self.err = 'Missing shader: rainfx2/shaders/' .. name .. '.hlsl'
    end
  end
  if not self.err then
    self.src = {
      cells = common .. '\n' .. src.hazenuc .. '\n' .. src.cells,
      haze = src.wmalias .. '\n' .. common .. '\n' .. src.hazenuc .. '\n' .. src.haze,   -- T1: txR2Big slot holds the wipe mask
      hzm = common .. '\n' .. src.hazenuc .. '\n' .. src.hzm,   -- N3
      hzv = common .. '\n' .. src.hazenuc .. '\n' .. src.hzv,   -- H3-P2
      wm = common .. '\n' .. src.hazenuc .. '\n' .. src.wm,     -- T1
      predict = common .. '\n' .. src.predict,
      field = common .. '\n' .. src.field,
      trail = common .. '\n' .. src.trail,
      claim = common .. '\n' .. src.claim,
      merge = common .. '\n' .. src.merge,
      seed = common .. '\n' .. src.seed,
      metrics = common .. '\n' .. src.metrics,
      sizes = common .. '\n' .. src.sizes,
      filmcoef = common .. '\n' .. src.filmcoef,
      film = common .. '\n' .. src.film,   -- FILM S2-1
      filmany = common .. '\n' .. src.filmany,   -- F4b film gate
      audit = common .. '\n' .. src.hazenuc .. '\n' .. src.audit,       -- E3 mass audit (+ E4: r2HazePhiAround)
      lam = common .. '\n' .. src.lam,
      big = common .. '\n' .. src.big,
      tailtex = common .. '\n' .. src.tailtex,   -- B2 tail raster
      visor = cand .. '\n' .. src.visor,
      rec = cand .. '\n' .. src.rec,
      msk = src.msk,
      source = src.source,
      visorDepth = '#define R2_DEPTH_ONLY 1\n' .. cand .. '\n' .. src.visor,
    }
  end
  return self
end
