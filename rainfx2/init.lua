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
  splashK0 = 58, resA = 0.5, resB = 0.4,   -- F3: resA 0.3 -> 0.5 (splashed mass ~0.75-0.8 at K/K0 ~ 18: Mundo 1995, SLD Trontin & Villedieu 2016)
  -- rev21 growth of visible drops from unresolved water: haze condensation, film head drops
  filmCollect = 0.3,   -- F1: nucM / nucRate (haze nucleation) replaced by the fine coalescence
  -- rev21 CSP adoption: lateral kicks from surface noise (6 mm features), trail following
  trailFollow = 1.5,   -- C-clean: rev21 meander removed (replaced by the defect field F1, rev48-S6)
  defMM = 1.2, defK = 5.0, defPin = 0.35,              -- rev48-S6 F1 surface defects: scale, gradient steering, stick-slip pinning
  -- sheetDrain rev14 0.5 -> 0.1: drainage dominated the film balance (eq ~ supply), now edge
  -- outflow does (eq ~ supply^(1/2..1/3)), compressing light..heavy into the cover window.
  sweepWidth = 0.9, sheetDrain = 0.1,
  -- drop lens (rev18): legacy Water Field rule, docs/RAINFX_V2_WF_LENS_PLAN.md
  kernelScale = 1.24, threshold = 0.35,     -- dome 1-(d/1.24R)^2, silhouette at U = 0.35 (= R)
  -- rev20 drop surface: contact angle of an impact-deposited drop (~ receding angle on polycarbonate
  -- / hard coat), per-drop spread, extra recession at the sliding rear, flattening on a wet surface.
  -- rev25: 75 -> 55. The TIR band starts at r/R = sin(48.6 deg)/sin(theta): 75 deg -> outer 22 % of the
  -- radius dark (thick rim on close drops), 55 deg -> 8 % (thin rim like the reference)
  capVolume = true,
  shedU10 = 25.0,   -- rev48-F4b: outer air speed (m/s) that depins a 10 uL drop on the coat (R6b 20; F4b fit to the dryFlow reference frames)
  shedBeta = 0.08,  -- rev48-F4b: U_c(V) = shedU10 (V / 10 uL)^-shedBeta (reference: r 0.6 / 0.25 / 0.15 mm move from ~150 / 177 / 205 km/h)
  bigOn = true, bigRMM = 0.8,   -- rev48-R7a: drops >= bigRMM drawn / touching in a +-4 cell window (largest per 4 x 4 tile)   -- rev48-R3: drop volume = spherical cap of contactDeg (false: rev7 hemisphere 2.094)
  contactDeg = 60, contactSpread = 8,   -- rev35: 60 (user: stronger curl looked better; normal 40-60); R5b: spread only on the sheet edge (drops: flatness)
  hysteresisDeg = 20, wetFlatten = 0.5,
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
  housingM = 0.20,         -- frame pixels closer than this (linear m) are helmet housing (rev27: UI slider)
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
  reflK = 1.0,   -- sheet lens reflection
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
  -- trail water (rule_trail; rev47j width 0.35 -> 0.5 r: reference ~1/4 of the head)
  trailThetaRDeg = 28.0, trailWetK = 0.35, trailLL = 5.0,   -- rev47l trail rule (Ca vs Ca*, docs/RAINFX_V2_TRAIL_RULES.md)
  -- rev48-S1 shape state (docs/RAINFX_V2_SHAPE_STATE_PLAN.md section 6): birth class shares, relaxation
  shpImpactK = 0.15, shpImpactMax = 1.8,   -- rev48-S2' (birth events: splats spread nearly evenly; was 0.35 / 3)
  baseSpread = 1.0,
  spreadVarK = 0.5, spreadR0 = 0.15, spreadR1 = 0.8, spreadWetK = 0.3,   -- rev48-S2c per-drop resting spread
    -- rev48-S2'b: resting drop profile = splat rule at this f (1 = rev48 dome; try 1.3-1.5)
  shpSpreadMin = 1.8, shpSpreadMax = 3.2, shpRecoilC = 3.0, shpLamShift = 0.15,
  shpRimK = 0.6, shpFingerK = 0.25,   -- rev48-U2 splat lamella: rim share of the profile, downstream finger amplitude   -- rev48-S2' splat spread / recoil
  shpSkidK = 0.01, shpSkidMax = 0.05,   -- rev48-S2b recoil 0.4 -> 0.8 s (60 s rest: settled drops stayed vertical ovals)
  -- (rev48-S2 oblique impact)
  shpMergeK = 1.0, shpWaist = 0.0,      -- rev48-S3 merged footprint (tensor gain); M2: waist 0 (bridge fills in ~20 ms)
  shpMergeTau = 0.6,                    -- rev48-M1: s per mm of radius for a flat (merged / arrested) footprint to recede to theta_r
  asymK = 0.35, asymGravR = 1.0,       -- rev48-S2d off-centre apex (strength, radius where it points downhill)
  footPhys = true,                     -- rev48-S3b coalescence uses the drawn footprint (S4c: = the water radius x shape)
  footPinK = 1.0,                      -- rev48-S7 Furmidge: pinning by the contact width across the force (0 = 2r)
  shpBoK = 1.2, shpTearK = 0.12,
  shpSlugTau = 0.6, shpAirK = 0.08, shpAirMax = 1.6,   -- rev48-S5 E3 slug length memory, E6 air stretch of pinned drops
  shpTailTau = 0.25, shpTailStretch = 0.2, shpHookK = 2.0, shpFrontK = 1.2, shpSnapDeg = 40.0,   -- rev48-S6 F2 turns (S6b: head hook)
  -- rev48-W1 water sheet (docs/RAINFX_V2_WATER_SHEET_PLAN.md): off until verified (P1: physics + metrics only)
  sheetOn = false, sheetSub = 8, sheetHJoin = 0.10, sheetFront = 0.22, sheetSmooth = 0.12, sheetAbsorbK = 0.5,
  sheetRMax = 1.5, sheetUMax = 0.25, sheetFilmMaxMM = 2.0, sheetRecedeDeg = 50,   -- W1h: visor receding contact angle; unconnected water dewets at 2.3 (theta_r / 60)^3 /s (Cox-Voinov theta^3)
  sheetSceneMip = 0.0, sheetSlopeK = 1.0, sheetEdgeK = 0.6, sheetRidgeK = 0.8, sheetTailK = 0.35,   -- P2d edge profile
    -- rev48-P2b sheet lens: sharp scene (CSP bias -2), interior slope gain (2 mm blurred h)
  sheetHFed = 0.03, sheetFedTau = 0.4, sheetLumpK = 1.3, sheetKeepMM = 0.04, sheetWaveK = 1.0, sheetWetFrac = 0.5, sheetWetMM = 0.02, sheetGatherK = 0.15, sheetPinMM = 0.3, patchBeadRate = 6.0, sheetFollowK = 0.5,   -- W1t patch -> drop, drops follow water paths
    -- W1r wetted surface / drainage gathering
  impactWaveK = 1.0,   -- P4 sheet waves / impact crater + ring
    -- W1j: fed regime from the local lamella supply averaged over 0.4 s
    -- rev48-W1i: impact-fed sheared film counts as sheet from 0.03 mm
  sheetNucPhi = 0.5, sheetConnK = 1.3, sheetRetract = 8.0,   -- W1f: connected sheet > 1.3 x largest drop footprint in 5x5 cells; rear retraction /s
                          -- rev48-W1d: sheet nucleates from dense drop clusters (coverage) hit by an impact
  shpSplitA = 2.6, shpSplitRate = 6.0, shpSplitRMin = 0.45, shpNeckK = 1.5, shpNeckT = 0.12, hiSplit = false, hiImpact = false,   -- rev48-S6c E8 tail split (aspect, events / s, min parent radius mm)
  shpOn = true, shpDefShape = 1.0, shpRelaxMove = 0.12, shpRelaxStill = 10.0,   -- rev48-S5 E7 replaces the random sag class (shpSagP 0)
  shpMotionK = 0.6, shpMotionV = 0.04,   -- rev48-S4 motion morph (aspect 1 + k v/V); R1: arrest from theta_r (shpArrest removed)
  trailSlopeMax = 0.45,                      -- rev47k: rivulet edge slope 2 h0 / hw <= 0.45 (~24 deg; rev47j 0.8 drew glass rods)
  trailPinMM = 0.02, trailFlowK = 1.0,       -- rev47k: rivulets deeper than this run along themselves (film law x flowK)
  wetHaze = 1.5,        -- wetness from field G (F9: G is always 0)
  pearlMM = 0.006, pearlRate = 0.6,          -- rev47k: every rivulet section beads up, 0.6 /s per cell (rev47j 0.03 / 0.1: thin trails never broke)
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
  windDirOffsetDeg = 180, windDirCalibrated = false }   -- rev48: compass -> game-space wind convention (calibrated live)


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

-- rev48-W1h: unconnected water on the visor dewets (gathers into beads, swept by drops) at a rate ~ the dewetting
-- speed, which scales as theta_r^3 (Cox-Voinov / de Gennes); calibrated 2.3 /s at theta_r 60 deg (W1g).
local function sheetThinRate(p)
  local k = (p.sheetRecedeDeg or 50) / 60
  return 2.3 * k * k * k
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

local function sceneValues(self, v)
  -- Shared constant set for P1-P3 (one cbuffer layout; unused entries are harmless).
  local p, st = self.p, self.stats
  v.gR2Cells = self.cells
  v.gR2FieldSize = self.fieldSize
  v.gR2CellMM = self.cellMM
  v.gR2CellSizeMM = self.cellSizeMM
  v.gR2Dt = self.h or 0
  v.gR2Frame = self.frameSeed or 0
  v.gR2Sub = self.sub or 0
  v.gR2ObjToWorld = self.objToWorld
  v.gR2AccelW = self.accelW
  v.gR2AirW = self.airW
  v.gR2RainDirW = self.rainDirW
  v.gR2ImpactRate = self.store.freezeRain and 0 or (st.impactRate or 0)
  v.gR2MeanDiamMM = st.meanDiamMM or 0.3
  for i = 0, 15 do v['gR2DQ' .. i] = (st.dq and st.dq[i + 1]) or 0.3 end   -- rev48-P1 impact diameter inverse CDF
  v.gR2DsdM3 = st.dsdM3 or 0.162
  v.gR2TerminalSpeed = p.terminalSpeed   -- rev48-R4: reference fall speed inside SpeedRel (per-drop V_t(d) replaces it)
  v.gR2SpeedRel = st.speedRel or p.terminalSpeed
  v.gR2SplashK0 = p.splashK0
  v.gR2ResA = p.resA
  v.gR2ResB = p.resB
  v.gR2FineRMM = p.fineRMM   -- F9: satellite mist radius
  v.gR2SprayFineMMs = self.store.freezeRain and 0 or (st.sprayMMs or 0)
  v.gR2FilmCollect = p.filmCollect
  v.gR2ClearMaxMM = p.clearMaxMM
  v.gR2ClearK = p.clearK
  v.gR2DefInvMM, v.gR2DefK, v.gR2DefPin = 1.0 / math.max(p.defMM, 0.05), p.defK, p.defPin   -- rev48-S6 F1
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
  v.gR2AirSurface = p.airSurface
  v.gR2VMax = p.vMax
  v.gR2SurfaceTension = p.surfaceTension
  v.gR2PinKinetic = p.pinKinetic
  v.gR2GatherCells = p.gatherCells
  v.gR2LadderMinMM = p.ladderMinMM
  v.gR2LadderMaxMM = p.ladderMaxMM
  v.gR2EvapDiff, v.gR2EvapConv = self.evapDiff or 0, self.evapConv or 0   -- rev48-F5 drop evaporation (fineBudget)
  v.gR2MinRadiusMM = p.minRadiusMM
  v.gR2MaxRadiusMM = p.maxRadiusMM
  v.gR2CoalesceK = p.coalesceK
  v.gR2MicroCollect = p.microCollect
  v.gR2SweepWidth = p.sweepWidth
  v.gR2SheetDrain = p.sheetDrain
  v.gR2FilmCf = p.filmCf
  v.gR2FilmFlowK = p.filmFlowK
  v.gR2FilmDiffuse = p.filmDiffuse
  v.gR2FilmMaxMM = p.sheetOn and p.sheetFilmMaxMM or p.filmMaxMM   -- rev48-W1: B holds the sheet (up to 2 mm)
  v.gR2SheetOn = p.sheetOn and 1 or 0
  v.gR2SheetHJoin, v.gR2SheetFront, v.gR2SheetSmooth = p.sheetHJoin, p.sheetFront, p.sheetSmooth
  v.gR2SheetAbsorbK, v.gR2SheetRMax, v.gR2SheetUMax = p.sheetAbsorbK, p.sheetRMax, p.sheetUMax
  v.gR2SheetThinRate = sheetThinRate(p)   -- rev48-W1h: from the visor wettability
  v.gR2SheetNucPhi = p.sheetNucPhi
  v.gR2SheetRecedeDeg = p.sheetRecedeDeg or 50
  v.gR2SheetHFed = p.sheetHFed or 0.03
  v.gR2SheetQMax = 1.0
  v.gR2SheetWetFrac = p.sheetWetFrac or 0.5
  v.gR2SheetWetMM = p.sheetWetMM or 0.02
  v.gR2SheetGatherK = p.sheetGatherK or 0.15
  v.gR2SheetPinMM = p.sheetPinMM or 0.3
  v.gR2PatchBeadRate = p.patchBeadRate or 6
  v.gR2GrowTime = p.growTime   -- rev48-W1t: cells uses it for patch beads (was a visor-only value)
  v.gR2SheetFollowK = p.sheetFollowK or 0.5
  v.gR2SheetFedTau = p.sheetFedTau or 0.4
  v.gR2SheetConnA = (p.sheetConnK or 1.3) * math.pi * math.min(p.maxRadiusMM, 1.9) ^ 2 / (25 * (self.cellSizeMM and self.cellSizeMM.x * self.cellSizeMM.y or 1.344))
  v.gR2SheetRetract = p.sheetRetract
  v.gR2SheetDt = (self.frameDt or 1 / 60) / math.max(p.sheetSub or 8, 1)
  v.gR2SheetResMMs = ((self.stats and self.stats.fluxMMs) or 0) * ((self.stats and self.stats.stickFrac) or 0)
  v.gR2FilmRate = self.store.freezeRain and 0 or (st.filmRate or 0)
  v.gR2FilmSplashMM = st.filmSplashMM or 0.1
  v.gR2FilmMinMM = p.sheetOn and p.sheetHJoin or p.filmMinMM   -- rev48-W1e: with the sheet on only a sheet shows
  -- rev40 size mix, stagnation turbulence, size histogram
  local fl = fragLaw(p, self.frag or {})
  self.frag = fl
  v.gR2FragLoP = fl.loP
  v.gR2FragHiP = fl.hiP
  v.gR2FragInvA = fl.invA
  v.gR2FragM3 = fl.m3
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
  v.gR2ShpMergeTau = p.shpMergeTau or 0.6
  v.gR2ShpMotionK, v.gR2ShpMotionV = p.shpMotionK, p.shpMotionV
  v.gR2ShpBoK, v.gR2ShpTearK = p.shpBoK, p.shpTearK
  v.gR2ShpSlugTau, v.gR2ShpAirK, v.gR2ShpAirMax = p.shpSlugTau, p.shpAirK, p.shpAirMax
  v.gR2ShpTailTau, v.gR2ShpTailStretch, v.gR2ShpHookK, v.gR2ShpSnapDeg = p.shpTailTau, p.shpTailStretch, p.shpHookK, p.shpSnapDeg   -- rev48-S6 F2
  v.gR2ShpSplitA, v.gR2ShpSplitRate, v.gR2ShpSplitRMin = p.shpSplitA, p.shpSplitRate, p.shpSplitRMin   -- rev48-S6c E8
  v.gR2FootPhys = p.footPhys and 1 or 0
  v.gR2FootPinK = p.footPinK
  v.gR2BaseSpread = p.baseSpread
  v.gR2SpreadVarK, v.gR2SpreadR0, v.gR2SpreadR1, v.gR2SpreadWetK = p.spreadVarK, p.spreadR0, p.spreadR1, p.spreadWetK
  v.gR2ShpImpactK, v.gR2ShpImpactMax = p.shpImpactK, p.shpImpactMax
  v.gR2ShpSkidK, v.gR2ShpSkidMax = p.shpSkidK, p.shpSkidMax
  v.gR2ShpSpreadMin, v.gR2ShpSpreadMax, v.gR2ShpLamShift = p.shpSpreadMin, p.shpSpreadMax, p.shpLamShift
  v.gR2ShpRecoilC = p.shpRecoilC   -- rev48-R1: recoil tau = C sqrt(rho r^3 / gamma) (r2Predict ramp / walk)
  v.gR2TrailThetaRDeg = p.trailThetaRDeg
  v.gR2TrailWetK = p.trailWetK
  v.gR2TrailLL = p.trailLL
  v.gR2TrailPinMM = p.trailPinMM
  v.gR2TrailFlowK = p.trailFlowK
  v.gR2FilmBeadMM = p.filmBeadMM
  v.gR2DewetRate = p.dewetRate
  v.gR2SheetLumpK = p.sheetLumpK or 1.3
  v.gR2SheetKeepMM = p.sheetKeepMM or 0.04
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

local function newPass(self, shader)
  local root = self.ctx.surface.root
  return {
    async = true,
    blendMode = render.BlendMode.Opaque,
    textures = { txR2State = false, txR2Field = false, txR2Claim = false, txR2Trail = false,
      txR2FieldOld = false, txR2SheetK = false, txR2SheetNuc = false, txR2Lam = false, txR2Bead = false,   -- rev48-W1 water sheet (W1d nucleation mask, W1q lamella registry)
      txR2Big = false,   -- rev48-R7a big-drop tiles
      txR2Du = root .. 'du.dds', txR2Dv = root .. 'dv.dds', txR2Mask = self.ctx.maskPath },
    values = sceneValues(self, {}),
    shader = shader,
  }
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
  self.S = { canvas(3 * p.cellsU, p.cellsV, 1, f32, 'RainFX2 cells A'), canvas(3 * p.cellsU, p.cellsV, 1, f32, 'RainFX2 cells B') }
  self.C = canvas(p.cellsU, p.cellsV, 1, render.TextureFormat.R16G16B16A16.Float, 'RainFX2 claims')
  -- rev48-F8 (F7 review: a background of motionless droplets built up whenever intensity > 0, faster at speed): the field was
  -- R16G16B16A16 UNORM -- one step 1/65535 of fineMaxMM. A multiplicative loss per frame (fine evaporation 0.14 %/frame at
  -- tau 12 s) rounds back to the same value below ~360 steps (G < 0.0055: 8 % of the 0.6 mm micro-grid drawn as droplets),
  -- so the fine water never left; the semi-Lagrangian fine transport rounded fractional inflow UP on empty texels (mass
  -- created along the flow, more at speed). 32-bit float field: decays / transports to zero (12 MB for the 3 targets).
  self.F = { canvas(p.fieldU, p.fieldV, 1, f32, 'RainFX2 field A'), canvas(p.fieldU, p.fieldV, 1, f32, 'RainFX2 field B') }
  -- rev48-W1: sheet substeps ping-pong between the new field and this scratch (the previous field stays intact
  -- for the merge pass of the next frame = txR2FieldOld); sheet velocity coefficients once per frame
  self.FS = canvas(p.fieldU, p.fieldV, 1, f32, 'RainFX2 field sheet scratch')   -- F8: same format as the field
  self.SK = canvas(p.fieldU, p.fieldV, 1, f32, 'RainFX2 sheet coef')
  -- rev48-W1d: nucleation mask per cell (made on S_next; read by this frame's field and next frame's merge)
  self.NM = canvas(p.cellsU, p.cellsV, 1, render.TextureFormat.R16G16B16A16.Float, 'RainFX2 sheet nucleation')
  -- rev48-W1q: lamella registry per cell (birth frame), ping-pong
  self.LM = { canvas(p.cellsU, p.cellsV, 1, f32, 'RainFX2 lamella A'), canvas(p.cellsU, p.cellsV, 1, f32, 'RainFX2 lamella B') }
  self.li = 1
  self.BM = canvas(p.cellsU, p.cellsV, 1, f32, 'RainFX2 patch beads')   -- rev48-W1t
  -- rev48-R7a big-drop tiles (4 x 4 cells -> the largest drop, drawn / touching in a +-4 cell window)
  self.BG = canvas(math.ceil(p.cellsU / 4), math.ceil(p.cellsV / 4), 1, f32, 'RainFX2 big drops')
  -- rev47j trail geometry (line point / direction / half-width per field texel)
  local h16 = render.TextureFormat.R16G16B16A16.Float
  self.TG = { canvas(p.fieldU, p.fieldV, 1, h16, 'RainFX2 trail A'), canvas(p.fieldU, p.fieldV, 1, h16, 'RainFX2 trail B') }
  self.ti = 1
  self.si, self.fi = 1, 1
  self.cells = vec2(p.cellsU, p.cellsV)
  self.fieldSize = vec2(p.fieldU, p.fieldV)
  self.accelW, self.airW, self.rainDirW = vec3(0, -9.81, 0), vec3(), vec3(0, -1, 0)
  self.objToWorld = mat4x4.identity()
  -- Mesh metric (measured from du/dv, docs/RAINFX_V2_KICKOFF.md 2.2): median 0.602 m/U, 0.146 m/V.
  self.cellSizeMM = vec2(602.0 / p.cellsU, 146.3 / p.cellsV)
  self.cellMM = (self.cellSizeMM.x + self.cellSizeMM.y) * 0.5
  self.texMM = vec2(602.0, 146.3)
  self.passCells = newPass(self, self.src.cells)
  self.passField = newPass(self, self.src.field)
  self.passSheet = newPass(self, self.src.sheet)            -- rev48-W1
  self.passSheetK = newPass(self, self.src.sheetcoef)
  self.passNuc = newPass(self, self.src.nuc)               -- rev48-W1d
  self.passLam = newPass(self, self.src.lam)               -- rev48-W1q
  self.passBead = newPass(self, self.src.bead)             -- rev48-W1t
  self.passTrail = newPass(self, self.src.trail)
  self.passClaim = newPass(self, self.src.claim)
  self.passMetrics = newPass(self, self.src.metrics)
  self.Mc = canvas(32, 8, 1, render.TextureFormat.R8G8B8A8.UNorm, 'RainFX2 metrics')
  self.passSizes = newPass(self, self.src.sizes)
  self.Hc = canvas(10, 16, 1, render.TextureFormat.R8G8B8A8.UNorm, 'RainFX2 size histogram')
  self.passMerge = newPass(self, self.src.merge)
  self.passBig = newPass(self, self.src.big)              -- rev48-R7a
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
  local spray, info = self.spray.estimate(sim, p, self.sprayInfo)
  self.sprayInfo = info
  spray = spray * p.sprayK
  local vOwn = math.max(inp.carSpeed or 0, 1)
  local dS = p.sprayDiamMM * 1e-3
  local stS = 1000 * dS * dS * vOwn / (18 * 1.8e-5 * 0.13)
  local etaS = (stS / (stS + 0.25)) ^ 2
  local sprayMMs = spray * 1e-3 * vOwn * etaS                -- g/m^3 -> m^3/m^3 (1e-6) x m/s -> mm/s (1e3)
  local splashMMs = (info.splash or 0) * p.sprayLWC0 * p.sprayK * 1e-3 * vOwn * p.splashShare
  self.weather.compute({ rainIntensity = sim.rainIntensity, weatherType = sim.weatherType, speedRel = speedRel,
                         splashMMs = splashMMs, airT = self.fineT, airRH = self.fineRH, p = p }, self.stats)
  self.stats.speedRel = speedRel
  local st = self.stats
  st.spray, st.sprayMMs, st.splashMMs = spray, sprayMMs, splashMMs
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
  return canvas:updateWithShader(pass) ~= false
end

-- Once per simulation frame, from render.onSceneReady.
function R2:simulate(sim)
  if not self:enabled() then return end
  if self.simFrame == sim.frame then return end
  self.simFrame = sim.frame
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
  -- rev23 look lab (docs/RAINFX_V2_DROP_PIPELINE_PLAN.md step 1): static reference-distributed
  -- drop set, physics / births / film / haze / scatter / wobble / defocus off. Works while paused.
  if self.lookLab then
    if self.labRequest or not self.labSeeded then
      self.labRequest = false
      local ps = self.passSeed
      if not ps then ps = newPass(self, self.src.seed); self.passSeed = ps end
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
    return
  end
  self.labSeeded = false
  local dt = sim.dt or 0
  if dt <= 0 then self.status = 'paused'; return end
  dt = math.min(dt, 1 / 20) * (self.timeScale or 1)   -- rev9: slow motion for physics review
  self.wobbleT = ((self.wobbleT or 0) + dt) % 600
  self:updateInputs(sim)
  -- Substeps: enough that the fastest expected drop (2 mm, forces aligned) stays in the
  -- gather window; faster than that it is speed-limited (r2Predict), not deleted.
  local P = self.physics
  local vExp = P.speed(p, 2.0, self.inp.accelG * 9.81, self.inp.airSpeed, p.pinCoat)
  p.substeps = P.substeps(p, dt, self.cellMM, userSub, vExp)
  self.frameSeed = sim.frame % 1048576
  self.h = dt / p.substeps
  self.frameDt = dt
  self.diag = P.diagnose(p, self.inp, self.h, self.cellMM, self.diag)
  if self.ladderRequest then
    self.ladderRequest = false
    local ps = self.passSeed
    if not ps then ps = newPass(self, self.src.seed); self.passSeed = ps end
    sceneValues(self, ps.values)
    ps.values.gR2SeedMode = 0
    if run(self.S[3 - self.si], ps) then self.si = 3 - self.si end
  end
  -- rev13: coalescence runs FIRST (on last frame's state). The merge may leave a drop
  -- centre off its cell (centroid); the P1 substeps that follow relocate it, so the visor
  -- never sees off-cell drops (rev12: drops cut by the 5x5 draw window along cell edges).
  if p.coalesceK > 0 or p.sheetOn then   -- rev48-W1: the merge pass also removes the sheet-absorbed share
    local pk, pm = self.passClaim, self.passMerge
    pk.textures.txR2State = self.S[self.si]
    pk.textures.txR2Field = self.F[self.fi]        -- rev48-S3b: wetness for the footprint radius
    pk.textures.txR2Big = self.BG                  -- rev48-R7a
    sceneValues(self, pk.values)
    if run(self.C, pk) then
      pm.textures.txR2State = self.S[self.si]
      pm.textures.txR2Claim = self.C
      pm.textures.txR2FieldOld = self.F[3 - self.fi]   -- rev48-W1: F_prev of last frame's field pass
      pm.textures.txR2SheetNuc = self.NM                -- rev48-W1d: last frame's nucleation (same S)
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
  -- rev48-W1t: isolated patches that bead this frame (F_prev); read by the cells substep 1 and the field pass
  if p.sheetOn then
    local pb = self.passBead
    pb.textures.txR2Field = self.F[self.fi]
    pb.textures.txR2Lam = self.LM[self.li]
    pb.textures.txR2SheetNuc = self.NM
    sceneValues(self, pb.values)
    if not run(self.BM, pb) then self.BM:clear(rgbm(0, 0, 0, 0)) end
    self.bmDirty = true
  elseif self.bmDirty then
    self.BM:clear(rgbm(0, 0, 0, 0)); self.bmDirty = false
  end
  for i = 1, p.substeps do
    self.sub = i
    local pc = self.passCells
    pc.textures.txR2State = self.S[self.si]
    pc.textures.txR2Field = self.F[self.fi]   -- rev21: haze/film births, trail following
    pc.textures.txR2Trail = self.TG[self.ti]  -- rev47j: pearling reads the rivulet lines
    pc.textures.txR2SheetNuc = self.NM          -- rev48-W1k: drops collect isolated remnants only
    pc.textures.txR2Bead = self.BM              -- rev48-W1t
    pc.textures.txR2Lam = self.LM[self.li]      -- rev48-W1u residual drops
    sceneValues(self, pc.values)
    if not run(self.S[3 - self.si], pc) then self.status = 'compiling cells'; return end
    self.si = 3 - self.si
  end
  do   -- rev48-R7a: big-drop tiles of the final state (visor now, claim / merge next frame)
    local pg = self.passBig
    pg.textures.txR2State = self.S[self.si]
    sceneValues(self, pg.values)
    if not p.bigOn or not run(self.BG, pg) then self.BG:clear(rgbm(0, 0, 0, 0)) end
  end
  do
    -- rev47j: trail geometry first (reads F_prev, TG_prev); the field then still sees TG_prev, the same
    -- lines the cells pass beaded (pearling removes that water), and both swap together.
    local pt = self.passTrail
    pt.textures.txR2State = self.S[self.si]
    pt.textures.txR2Field = self.F[self.fi]
    pt.textures.txR2Trail = self.TG[self.ti]
    sceneValues(self, pt.values)
    pt.values.gR2Dt = self.frameDt                 -- the packed move is the whole frame's
    local trailOk = run(self.TG[3 - self.ti], pt)
    -- rev48-W1d: sheet nucleation mask on S_next (this field pass adds, next frame's merge removes)
    if p.sheetOn then
      local pn = self.passNuc
      pn.textures.txR2State = self.S[self.si]
      pn.textures.txR2Field = self.F[self.fi]        -- W1f: sheet area share from F_prev
      sceneValues(self, pn.values)
      pn.values.gR2Dt = self.frameDt
      if not run(self.NM, pn) then self.NM:clear(rgbm(0, 0, 0, 0)) end
      self.nmDirty = true
    elseif self.nmDirty then
      self.NM:clear(rgbm(0, 0, 0, 0)); self.nmDirty = false
    end
    local pf = self.passField
    pf.textures.txR2State = self.S[self.si]
    pf.textures.txR2Field = self.F[self.fi]
    pf.textures.txR2Trail = self.TG[self.ti]
    pf.textures.txR2SheetNuc = self.NM
    pf.textures.txR2Lam = self.LM[self.li]
    pf.textures.txR2Bead = self.BM
    sceneValues(self, pf.values)
    pf.values.gR2Dt = self.frameDt                 -- field integrates the whole frame
    if run(self.F[3 - self.fi], pf) then
      -- rev48-W1 WATER SHEET: conservative flux substeps on the new field (B), scratch ping-pong (even count)
      if p.sheetOn then
        local pkc, psh = self.passSheetK, self.passSheet
        sceneValues(self, pkc.values)
        if run(self.SK, pkc) then
          local nsub = math.max(2, 2 * math.floor((p.sheetSub or 8) / 2 + 0.5))
          local a, b = self.F[3 - self.fi], self.FS
          sceneValues(self, psh.values)
          psh.values.gR2SheetDt = self.frameDt / nsub
          psh.textures.txR2SheetK = self.SK
          psh.textures.txR2SheetNuc = self.NM        -- W1f: retraction into connected sheet only
          for _ = 1, nsub do
            psh.textures.txR2Field = a
            if not run(b, psh) then break end
            a, b = b, a
          end
        end
      end
      self.fi = 3 - self.fi
      if trailOk then self.ti = 3 - self.ti end
    end
  end
  self:metricsUpdate(sim)
  self.opticsReady = true
  self.status = 'running'
end


function R2:drawParams(depth)
  local key = depth and 'paramsDepth' or 'paramsColour'
  local t = self[key]
  if not t then
    t = { mesh = self.mesh, transform = 'original', async = true,
      textures = { txR2State = false, txR2Field = false, txR2Trail = false, txR2Scene = false, txR2Lam = false, txR2SheetNuc = false, txR2Big = false, txR2Mask = self.ctx.maskPath },
      values = {}, shader = depth and self.src.visorDepth or self.src.visor }
    self[key] = t
  end
  local p, v = self.p, t.values
  local size = render.getRenderTargetSize()
  v.gR2InvRT = vec2(1 / math.max(size.x, 1), 1 / math.max(size.y, 1))
  v.gR2Cells = self.cells
  v.gR2CellSizeMM = self.cellSizeMM
  v.gR2TexMM = self.texMM
  updateShapeK(p)
  v.gR2ShapeK = p.shapeK
  v.gR2CapVolume = p.capVolume ~= false and 1 or 0
  v.gR2BigOn, v.gR2BigRMM = p.bigOn and self.BG and 1 or 0, p.bigRMM or 0.8   -- rev48-R7a
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
  v.gR2KernelScale = p.kernelScale
  v.gR2ShpOn = p.shpOn and 1 or 0   -- rev48-S1
  v.gR2ShpRecoilC = p.shpRecoilC   -- rev48-R1
  v.gR2ShpLamShift = p.shpLamShift   -- rev48-U2: lamella centre vs the recoiling residual
  v.gR2ShpRimK, v.gR2ShpFingerK = p.shpRimK or 0.6, p.shpFingerK or 0.25
  v.gR2ShpImpactK, v.gR2ShpImpactMax = p.shpImpactK, p.shpImpactMax   -- U2a: lamella ellipse along Vt (visor)
  v.gR2BaseSpread = p.baseSpread       -- rev48-S2'b
  v.gR2AsymK, v.gR2AsymGravR = p.asymK, p.asymGravR   -- rev48-S2d
  v.gR2ShpFrontK = p.shpFrontK                         -- rev48-S6 F2 outer-front apex
  v.gR2ShpNeckK, v.gR2ShpNeckT, v.gR2HiSplit = p.shpNeckK, p.shpNeckT, p.hiSplit and 1 or 0   -- rev48-S6c E8 neck / review highlight
  v.gR2HiImpact = p.hiImpact and 1 or 0   -- rev48-U1 review highlight
  v.gR2SpreadVarK, v.gR2SpreadR0, v.gR2SpreadR1, v.gR2SpreadWetK = p.spreadVarK, p.spreadR0, p.spreadR1, p.spreadWetK
  v.gR2WetHaze = p.wetHaze
  v.gR2Threshold = p.threshold
  v.gR2ContactDeg = p.contactDeg
  v.gR2ContactSpread = p.contactSpread
  v.gR2Hysteresis = p.hysteresisDeg
  v.gR2WetFlatten = p.wetFlatten
  v.gR2WobbleAmp = p.wobbleAmp
  v.gR2WobbleHz = p.wobbleHz
  -- Fa/Fpin = (0.25 rho Cd pi / (2 gamma dcos_coat)) * r * u^2, r in mm -> * 1e-3
  v.gR2WobbleC = 0.25 * p.rhoAir * 1.0 * math.pi / (2 * p.surfaceTension * p.pinCoat) * 1e-3   -- R6b: tuned look (Cd 1)
  v.gR2AirW = self.airW or vec3()
  v.gR2AirSurface = p.airSurface
  v.gR2Time = self.wobbleT or 0
  v.gR2MotionStretch = p.motionStretch
  -- rev48-P4 sheet surface
  v.gR2Frame = self.frameSeed or 0
  v.gR2FrameDt = self.frameDt or 1 / 60
  v.gR2MeanDiamMM = (self.stats and self.stats.meanDiamMM) or 0.3
  for i = 0, 15 do v['gR2DQ' .. i] = (self.stats and self.stats.dq and self.stats.dq[i + 1]) or 0.3 end   -- rev48-P1
  v.gR2SpeedRel = (self.stats and self.stats.speedRel) or p.terminalSpeed
  v.gR2SheetWaveK = p.sheetWaveK or 1
  v.gR2RainDirW = self.rainDirW or vec3(0, -1, 0)   -- rev48-P4b impact direction
  v.gR2ImpactWaveK = p.impactWaveK or 1
  v.gR2MinDrawMM = p.minDrawMM
  v.gR2WFSceneMip = p.wfSceneMip
  v.gR2DefocusMode = p.defocusDA and 1 or 0
  self.drawCount = ((self.drawCount or 0) + 1) % 4096
  v.gR2FrameNoise = self.drawCount                -- D-A tap rotation (TAA/DLSS resolves it)
  v.gR2Glint = p.glint
  v.gR2SagK = p.sagK
  v.gR2LensPhys = p.lensPhys
  v.gR2ReflK = p.reflK
  self.camLook = self.camLook or vec3(); self.camSide = self.camSide or vec3(); self.camUp = self.camUp or vec3()
  self.camLook:set(simNow.cameraLook or vec3(0, 0, 1))
  self.camSide:set(simNow.cameraSide or vec3(1, 0, 0))
  self.camUp:set(simNow.cameraUp or vec3(0, 1, 0))
  v.gR2CamLook, v.gR2CamSide, v.gR2CamUp = self.camLook, self.camSide, self.camUp
  v.gR2AccelW = self.accelW or vec3(0, -9.81, 0)
  v.gR2VeilColor = self.veil or vec3(0.5, 0.5, 0.5)
  v.gR2DepthCoverage = p.depthCoverage
  v.gR2FieldSize = self.fieldSize
  v.gR2FilmMaxMM = p.sheetOn and p.sheetFilmMaxMM or p.filmMaxMM   -- rev48-W1: B holds the sheet (up to 2 mm)
  v.gR2TrailMaxMM = p.trailMaxMM
  v.gR2FilmMinMM = p.sheetOn and p.sheetHJoin or p.filmMinMM   -- rev48-W1e: with the sheet on only a sheet shows
  v.gR2SheetOn = p.sheetOn and 1 or 0   -- rev48-P2 sheet lens
  v.gR2SheetRecedeDeg = p.sheetRecedeDeg or 50
  v.gR2SheetSceneMip = p.sheetSceneMip or 0
  v.gR2SheetSlopeK = p.sheetSlopeK or 1
  v.gR2SheetEdgeK = p.sheetEdgeK or 0.6
  v.gR2SheetHFed = p.sheetHFed or 0.03   -- rev48-W1i fed-sheet contour (visor)
  v.gR2SheetQMax = 1.0
  v.gR2SheetWetFrac = p.sheetWetFrac or 0.5
  v.gR2SheetWetMM = p.sheetWetMM or 0.02
  v.gR2SheetGatherK = p.sheetGatherK or 0.15
  v.gR2SheetPinMM = p.sheetPinMM or 0.3
  v.gR2PatchBeadRate = p.patchBeadRate or 6
  v.gR2SheetFollowK = p.sheetFollowK or 0.5
  v.gR2SheetKeepMM = p.sheetKeepMM or 0.04   -- W1o visor contour of remnants
  v.gR2SheetHJoin = p.sheetHJoin
  v.gR2SheetThinRate = sheetThinRate(p)
  v.gR2SheetResMMs = ((self.stats and self.stats.fluxMMs) or 0) * ((self.stats and self.stats.stickFrac) or 0)
  v.gR2FilmRate = self.store.freezeRain and 0 or ((self.stats and self.stats.filmRate) or 0)
  v.gR2SheetRidgeK = p.sheetRidgeK or 0.8
  v.gR2SheetTailK = p.sheetTailK or 0.35
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
  v.gR2ScatterMip = p.scatterMip
  v.gR2ScatterSky = p.scatterSky
  v.gR2ScatterGain = p.scatterGain
  v.gR2Spray = self.store.freezeRain and 0 or (self.stats.spray or 0)
  v.gR2SimDt = self.frameDt or (1 / 60)   -- packed move = displacement of the whole frame
  v.gR2GrowTime = p.growTime
  v.gR2FadeTime = p.fadeTime
  v.gR2VMax = p.vMax
  v.gR2VLimit = self.diag and self.diag.vGather or 0.5   -- physical m/s (h already scaled)
  v.gR2LookLab = self.lookLab and 1 or 0
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
      textures = { txR2Src = false, txR2Depth = 'dynamic::depth' }, values = {}, shader = self.src.source }
    self.passSource = pass
  end
  pass.textures.txR2Src = src
  local v = pass.values
  v.gR2Near = near
  v.gR2Far = math.max(sim.cameraClipFar or 5000, near + 1)
  v.gR2HousingM = p.housingM
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
    local ok, res = pcall(self.prepareSource, self, src)
    if not ok then self.sourceErr = tostring(res); res = nil end
    -- Raw copy as fallback: alpha 1 everywhere, so r2Scene reduces to a plain fetch.
    self.sceneTex = res or src
  end
  t.textures.txR2Scene = self.sceneTex or src
  if not depth and self.offscreenTest == 'pending' then self:offscreenTestRun() end
  t.textures.txR2State = self.S[self.si]
  t.textures.txR2Field = self.F[self.fi]
  t.textures.txR2Trail = self.TG and self.TG[self.ti] or false
  t.textures.txR2Lam = self.LM and self.LM[self.li] or false   -- rev48-P4 impacts on the sheet
  t.textures.txR2SheetNuc = self.NM or false                    -- rev48-W1v Debug 10
  t.textures.txR2Big = self.BG or false                         -- rev48-R7a
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
  s.rainExposure = ui.slider('##rfx2exp', s.rainExposure, 0, 1.5, 'Rain exposure (1 = physical): %.2f')
  self.p.rainSpreadDeg = ui.slider('##rfx2rsd', self.p.rainSpreadDeg, 0, 40, 'Rain direction spread (gusts): %.0f deg')
  self.p.crownMM = ui.slider('##rfx2cr', self.p.crownMM, 0, 60, 'Helmet crown runoff over the visor top (at rest): %.0f mm catch')
  -- rev23 look lab: judge the drop look alone (reference: 물방울형태및흐름 video)
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
  if ui.button('Reset look to defaults (lens, defocus, film, scatter)') then
    self.p.lensPhys = DEFAULTS.lensPhys
    s.apertureMM, s.focusM, s.wfRefraction, s.wfSceneMip = DEFAULTS.apertureMM, DEFAULTS.focusM, DEFAULTS.wfRefraction, DEFAULTS.wfSceneMip
    s.contactDeg, s.wobbleAmp = DEFAULTS.contactDeg, DEFAULTS.wobbleAmp
    s.defocusDA = DEFAULTS.defocusDA
    s.filmRefract, s.filmVeil, s.scatterK = DEFAULTS.filmRefract, DEFAULTS.filmVeil, DEFAULTS.scatterK
  end
  -- rev34 UI: WF lens (main) first, then defocus (C-clean: the CSP comparison is removed).
  ui.separator()
  ui.text('Drops: WF lens, surface-based (main)')
  self.p.lensPhys = ui.slider('##rfx2lp', self.p.lensPhys, 0, 1.5, 'Lens strength (1 = physical water cap, one image): %.2f')
  s.contactDeg = ui.slider('##rfx2ca', s.contactDeg, 20, 90, 'Contact angle: %.0f deg (rim curl; normal 40-60)')
  s.wfSceneMip = ui.slider('##rfx2mip', s.wfSceneMip, 0, 6, 'Image blur in the drop (scene mip): %.1f')
  s.wobbleAmp = ui.slider('##rfx2wb', s.wobbleAmp, 0, 0.3, 'Wobble in airflow: %.2f')
  self.p.housingM = ui.slider('##rfx2hm', self.p.housingM, 0.05, 0.6, 'Refraction source: remove housing closer than %.2f m')
  if ui.checkbox('Hide water behind the helmet housing (depth test)', self.p.depthTest) then self.p.depthTest = not self.p.depthTest end
  ui.separator()
  ui.text('Drop sizes and stagnation (step 2; check: Metrics -> drops by radius)')
  self.p.fragA = ui.slider('##rfx2fa', self.p.fragA, 0.3, 2.0, 'Size law exponent (0.88 = reference, x0.7 per 1.5x size): %.2f')
  self.p.fragHi = ui.slider('##rfx2fh', self.p.fragHi, 1.0, 6.0, 'Largest new drop (x typical fragment): %.1f')
  self.p.fragMax = ui.slider('##rfx2fm', self.p.fragMax, 1, 30, 'Small drops per raindrop impact (max): %.0f')
  self.p.clusterK = ui.slider('##rfx2ck', self.p.clusterK, 0, 1, 'Drop groups (clustered births): %.2f')
  self.p.vMax = ui.slider('##rfx2vm', self.p.vMax, 0.005, 0.2, 'Motion stretch reference speed (visor only, R6): %.3f m/s')
  ui.text('Helmet airflow (rev47: sphere flow, boundary layer, pressure gradient)')
  self.p.aeroKU = ui.slider('##rfx2ku', self.p.aeroKU, 0.1, 1.2, 'Air speed at the helmet (x car speed, cockpit shielding): %.2f')
  self.p.stagElevDeg = ui.slider('##rfx2se', self.p.stagElevDeg, -40, 40, 'Stagnation point above the visor centre: %.0f deg')
  self.p.buffetDeg = ui.slider('##rfx2bd', self.p.buffetDeg, 0, 25, 'Helmet buffeting (stagnation wander at 250 km/h): %.1f deg')
  self.p.buffetHz = ui.slider('##rfx2bh', self.p.buffetHz, 0.5, 8, 'Buffeting frequency: %.1f Hz')
  ui.text('Car / head jolts (rev47)')
  self.p.neckHz = ui.slider('##rfx2nh', self.p.neckHz, 0.5, 15, 'Neck low-pass of accelerations: %.1f Hz')
  self.p.headAccK = ui.slider('##rfx2hk', self.p.headAccK, 0, 1, 'Head motion (visor transform) acceleration share: %.2f')
  self.p.dropTau = ui.slider('##rfx2dt', self.p.dropTau, 0.0, 0.2, 'Drop inertia (speed follows the force over): %.3f s')
  self.p.runbackMax = ui.slider('##rfx2rm', self.p.runbackMax, 0.01, 0.5, 'Rivulet flow top speed (trail water): %.2f m/s')
  self.p.impactLoss = ui.slider('##rfx2il', self.p.impactLoss, 0, 1, 'Impact on a small drop: share splashed off %.2f')
  self.p.trailEvapMMs = ui.slider('##rfx2te', self.p.trailEvapMMs, 0.0, 0.05, 'Trail water evaporation: %.4f mm/s')
  ui.separator()
  ui.text('Trails and drop life cycle (step 3)')
  self.p.trailThetaRDeg = ui.slider('##rfx2tr', self.p.trailThetaRDeg, 5, 60, 'Receding contact angle (dry coat; trails from Ca > Ca*): %.1f deg')
  self.p.trailWetK = ui.slider('##rfx2twk', self.p.trailWetK, 0, 0.8, 'Wet surface lowers the receding angle by: %.2f')
  self.p.trailLL = ui.slider('##rfx2tll', self.p.trailLL, 0, 20, 'Trail depth (x r Ca^2/3): %.1f')
  self.p.trailWidthK = ui.slider('##rfx2tw', self.p.trailWidthK, 0.1, 1.0, 'Trail width at high speed (x head radius): %.2f')
  self.p.pearlRate = ui.slider('##rfx2pr', self.p.pearlRate, 0, 2, 'Trail beading into small drops (per cell): %.2f /s')
  self.p.trailSlopeMax = ui.slider('##rfx2ts2', self.p.trailSlopeMax, 0.1, 1.5, 'Trail edge slope max (rivulet height / width): %.2f')
  self.p.trailPinMM = ui.slider('##rfx2tp', self.p.trailPinMM, 0.0, 0.1, 'Trail runs along itself above: %.3f mm (below: pinned residue)')
  self.p.trailFlowK = ui.slider('##rfx2tf', self.p.trailFlowK, 0.0, 5.0, 'Trail flow speed (x film law): %.2f')
  ui.text('Thin film dewetting (rev47j, mass-conserving: the unresolved rain gathers into beads)')
  self.p.filmBeadMM = ui.slider('##rfx2fb', self.p.filmBeadMM, 0.01, 0.2, 'Film gathers into a bead from: %.3f mm')
  self.p.dewetRate = ui.slider('##rfx2dw', self.p.dewetRate, 0, 20, 'Dewetting rate (per cell): %.1f /s')
  self.p.fadeTime = ui.slider('##rfx2fd', self.p.fadeTime, 0.0, 0.3, 'Swept drops fade out over %.2f s')
  self.p.growTime = ui.slider('##rfx2gt', self.p.growTime, 0.0, 0.3, 'New drops grow in over %.2f s')
  ui.separator()
  ui.text('Drop shapes (rev48-S1 shape state; S1 = random birth classes, look lab: Reseed)')
  if ui.checkbox('Shape state (off = rev47 seeded ellipse)', self.p.shpOn) then self.p.shpOn = not self.p.shpOn end
  self.p.shpDefShape = ui.slider('##rfx2ds', self.p.shpDefShape or 1.0, 0, 3, 'Birth contour from surface defects (x defect pinning): %.2f')
  self.p.shpRelaxStill = ui.slider('##rfx2sr', self.p.shpRelaxStill, 0.1, 60, 'Pinned shape is held for: %.1f s (r >= 0.3 mm)')
  self.p.shpBoK = ui.slider('##rfx2bo', self.p.shpBoK, 0, 3, 'Gravity sag of pinned drops (aspect 1 + k Bo): %.2f')
  self.p.shpTearK = ui.slider('##rfx2tk', self.p.shpTearK, 0, 0.3, 'Torn rims of splashing impacts: %.2f')
  self.p.shpSlugTau = ui.slider('##rfx2sg', self.p.shpSlugTau, 0.05, 3, 'Elongated drop keeps its length when it starts to slide: %.2f s')
  self.p.shpAirK = ui.slider('##rfx2sak', self.p.shpAirK, 0, 0.3, 'Air stretches pinned drops (x We_air): %.2f')
  ui.text('Flow on a rough surface (rev48-S6): defects steer the head, turns bend the drop')
  self.p.defMM = ui.slider('##rfx2dmm', self.p.defMM, 0.3, 5, 'Surface defect size: %.2f mm')
  self.p.defK = ui.slider('##rfx2dk', self.p.defK, 0, 15, 'Defects steer the head (zig-zag, x pinning asymmetry): %.1f')
  self.p.defPin = ui.slider('##rfx2dp', self.p.defPin, 0, 0.8, 'Defects hold the head (stick-slip): %.2f')
  self.p.shpTailTau = ui.slider('##rfx2tt', self.p.shpTailTau, 0.03, 1, 'Pinned tail follows a turn over: %.2f s')
  self.p.shpTailStretch = ui.slider('##rfx2ts', self.p.shpTailStretch, 0, 0.4, 'Head-tail stretch in a turn: %.2f')
  self.p.shpHookK = ui.slider('##rfx2ck', self.p.shpHookK, 0, 4, 'Head bends onto the new heading (hook, x tan): %.2f')
  self.p.shpFrontK = ui.slider('##rfx2fk', self.p.shpFrontK, 0, 3, 'Thick front moves to the outer side: %.2f')
  self.p.shpSnapDeg = ui.slider('##rfx2sd', self.p.shpSnapDeg, 10, 90, 'Tail lets go above: %.0f deg')
  self.p.shpSplitA = ui.slider('##rfx2spa', self.p.shpSplitA, 1.5, 4.5, 'Sliding drop sheds its tail above aspect: %.2f')
  self.p.shpSplitRate = ui.slider('##rfx2spr', self.p.shpSplitRate, 0, 20, 'Tail split events (while stretched / snapping): %.1f /s')
  self.p.shpSplitRMin = ui.slider('##rfx2spm', self.p.shpSplitRMin, 0.2, 1.5, 'Only drops above this radius split: %.2f mm')
  self.p.shpNeckK = ui.slider('##rfx2nk', self.p.shpNeckK, 0, 3, 'Split piece necks toward its parent: %.2f')
  self.p.shpNeckT = ui.slider('##rfx2nt', self.p.shpNeckT, 0.02, 0.5, 'Neck retracts over: %.2f s')
  if ui.checkbox('Highlight split pieces (cyan, 1.5 s)', self.p.hiSplit) then self.p.hiSplit = not self.p.hiSplit end
  self.p.shedU10 = ui.slider('##rfx2su', self.p.shedU10 or 20, 5, 40, 'Air speed that depins a 10 uL drop (wind tunnel ~10-20): %.0f m/s')
  self.p.shedBeta = ui.slider('##rfx2sb', self.p.shedBeta or 0.1, 0.0, 0.35, 'Size law U_c ~ V^-beta (small drops need more air): %.2f')
  do
    local P = self.physics
    local function kmh(r) return P.criticalU(self.p, r) / (1.5 * self.p.aeroKU * 0.707) * 3.6 end
    ui.text(string.format('Depins at (theta 45 deg, pin 1): r0.1 %.0f  r0.2 %.0f  r0.3 %.0f  r0.5 %.0f  r1 %.0f  r2 %.0f km/h',
      kmh(0.1), kmh(0.2), kmh(0.3), kmh(0.5), kmh(1), kmh(2)))
  end
  self.p.fineRMM = ui.slider('##rfx2frm', self.p.fineRMM, 0.1, 0.5, 'Splash satellites below radius %.2f mm leave as mist')
  if ui.checkbox('Big-drop window (R7a: large / merged drops drawn and touching up to 4 cells away)', self.p.bigOn) then self.p.bigOn = not self.p.bigOn end
  if ui.checkbox('Cap volume (R3: drop volume = spherical cap of the contact angle; off = rev7 hemisphere)', self.p.capVolume ~= false) then self.p.capVolume = (self.p.capVolume == false) end
  if ui.checkbox('Highlight impacts (magenta = born by an impact < 0.3 s, yellow = drop hit this frame)', self.p.hiImpact) then self.p.hiImpact = not self.p.hiImpact end
  self.p.shpSkidK = ui.slider('##rfx2skid', self.p.shpSkidK, 0, 0.05, 'Impact push of a hit drop (newborns stick, U2): %.3f')
  self.p.shpLamShift = ui.slider('##rfx2lsh', self.p.shpLamShift, 0, 0.5, 'Splat residual walks downstream during recoil (x r (f0-1) aspect): %.2f')
  self.p.shpRimK = ui.slider('##rfx2rim', self.p.shpRimK or 0.6, 0, 0.85, 'Splat lamella rim share (thick rim, thin interior): %.2f')
  self.p.shpFingerK = ui.slider('##rfx2fng', self.p.shpFingerK or 0.25, 0, 0.6, 'Splat downstream fingers: %.2f')
  ui.text('Water sheet (rev48-W1 P1: physics + metrics; Debug 5 shows it; not drawn as a lens yet)')
  if ui.checkbox('Water sheet: one water for film / sheet, conservative flow', self.p.sheetOn) then self.p.sheetOn = not self.p.sheetOn end
  self.p.sheetSub = ui.slider('##rfx2wss', self.p.sheetSub, 2, 16, 'Sheet flow substeps per frame: %.0f', true)
  self.p.sheetUMax = ui.slider('##rfx2wum', self.p.sheetUMax, 0.02, 0.5, 'Sheet speed cap: %.2f m/s')
  self.p.sheetHJoin = ui.slider('##rfx2wj', self.p.sheetHJoin, 0.04, 0.4, 'Sheet from (drops join it): %.2f mm')
  self.p.sheetFront = ui.slider('##rfx2wf', self.p.sheetFront, 0.1, 0.6, 'Sheet front advances above: %.2f mm')
  self.p.sheetAbsorbK = ui.slider('##rfx2wa', self.p.sheetAbsorbK, 0.1, 1, 'Drop joins the sheet per frame: %.2f')
  self.p.sheetRMax = ui.slider('##rfx2wr', self.p.sheetRMax, 0.8, 1.5, 'Capped puddles above this radius become sheet: %.2f mm')
  self.p.sheetSmooth = ui.slider('##rfx2wsm', self.p.sheetSmooth, 0, 0.24, 'Sheet surface tension smoothing: %.2f')
  self.p.sheetSceneMip = ui.slider('##rfx2wsmip', self.p.sheetSceneMip, 0, 4, 'Sheet image blur (scene mip): %.1f')
  self.p.sheetSlopeK = ui.slider('##rfx2wslk', self.p.sheetSlopeK, 0, 3, 'Sheet interior refraction (slope gain): %.2f')
  self.p.sheetEdgeK = ui.slider('##rfx2wedk', self.p.sheetEdgeK, 0, 2, 'Sheet edge (meniscus) strength: %.2f')
  self.p.sheetRidgeK = ui.slider('##rfx2wrk', self.p.sheetRidgeK, 0, 2, 'Sheet front gathers (capillary ridge): %.2f')
  self.p.sheetTailK = ui.slider('##rfx2wtk', self.p.sheetTailK, 0.1, 1, 'Sheet trailing edge angle x %.2f (lower = longer taper)')
  self.p.sheetRecedeDeg = ui.slider('##rfx2wtr', self.p.sheetRecedeDeg, 15, 100, 'Visor receding contact angle: %.0f deg (30 dirty, 50 used, 65 new coat, 90 repellent)')
  ui.text(string.format('  unconnected water dewets %.2f /s -> impact film (all rain x exposure) above %.3f mm/s (now %.3f mm/s x exposure)', sheetThinRate(self.p), sheetThinRate(self.p) * self.p.sheetHJoin, ((self.stats.fluxMMs or 0) * (self.stats.stickFrac or 0)) + (self.stats.filmRate or 0)))
  self.p.rainWindK = ui.slider('##rfx2rwk', self.p.rainWindK or 0.6, 0, 1, 'Rain drift by the wind (helmet height / shelter): %.2f')
  self.p.sheetHFed = ui.slider('##rfx2whf', self.p.sheetHFed, 0.01, 0.1, 'Impact-fed sheet from: %.3f mm')
  self.p.sheetFedTau = ui.slider('##rfx2wft', self.p.sheetFedTau, 0.1, 1.5, 'Impact supply memory (fed regime): %.2f s')
  self.p.sheetKeepMM = ui.slider('##rfx2wkm', self.p.sheetKeepMM, 0.01, 0.1, 'Residual patch kept (lump) from: %.3f mm')
  self.p.sheetWaveK = ui.slider('##rfx2wwv', self.p.sheetWaveK, 0, 3, 'Sheet wind waves: %.2f')
  self.p.impactWaveK = ui.slider('##rfx2wiw', self.p.impactWaveK, 0, 3, 'Impacts on the sheet (crater / ring): %.2f')
  self.p.sheetWetFrac = ui.slider('##rfx2wwf', self.p.sheetWetFrac, 0.1, 1.5, 'Surface stays wet from supply x %.2f of the sheet threshold')
  self.p.sheetWetMM = ui.slider('##rfx2wwm', self.p.sheetWetMM, 0, 0.06, 'Wet layer left behind: %.3f mm')
  self.p.sheetGatherK = ui.slider('##rfx2wgk', self.p.sheetGatherK, 0, 1, 'Drainage gathers into leading flows: %.2f')
  self.p.sheetPinMM = ui.slider('##rfx2wpin', self.p.sheetPinMM, 0, 1, 'Isolated patch pinned up to: %.2f mm')
  self.p.patchBeadRate = ui.slider('##rfx2wpb', self.p.patchBeadRate, 0, 10, 'Settled patch beads into a drop: %.1f /s')
  self.p.sheetFollowK = ui.slider('##rfx2wsf', self.p.sheetFollowK, 0, 2, 'Drops follow the water paths: %.2f')
  self.p.sheetNucPhi = ui.slider('##rfx2wnp', self.p.sheetNucPhi, 0.2, 0.9, 'Sheet nucleates at drop coverage: %.2f')
  self.p.sheetConnK = ui.slider('##rfx2wck', self.p.sheetConnK, 0.5, 3, 'Sheet = connected area > largest drop x %.2f')
  self.p.sheetRetract = ui.slider('##rfx2wrt', self.p.sheetRetract, 0, 60, 'Sheet rear retracts thin water: %.0f /s')
  self.p.shpMotionK = ui.slider('##rfx2smk', self.p.shpMotionK, 0, 1.5, 'Sliding head elongation: %.2f')
  self.p.shpRelaxMove = ui.slider('##rfx2sm', self.p.shpRelaxMove, 0.02, 2, 'Sliding drop morphs to its head shape over: %.2f s')
  ui.text('Oblique impact (rev48-S2): aspect = 1 + k Vt/Vn, lamella and fragments stretched downstream')
  self.p.shpImpactK = ui.slider('##rfx2ik', self.p.shpImpactK, 0, 1, 'Impact stretch k: %.2f')
  self.p.shpImpactMax = ui.slider('##rfx2im', self.p.shpImpactMax, 1, 4, 'Impact stretch max: %.1f')
  self.p.baseSpread = ui.slider('##rfx2bs', self.p.baseSpread, 1, 2, 'Resting drop profile (splat rule at f): %.2f  [1 = dome; 1.3-1.5 = mid-recoil look]')
  self.p.asymK = ui.slider('##rfx2ak', self.p.asymK, 0, 0.6, 'Off-centre apex (thicker downhill / per-drop): %.2f')
  if ui.checkbox('Merge at the drawn footprint (resting spread x shape)', self.p.footPhys) then self.p.footPhys = not self.p.footPhys end
  self.p.footPinK = ui.slider('##rfx2fpk', self.p.footPinK, 0, 1, 'Pinning by contact width across the force (Furmidge): %.2f')
  self.p.shpMergeK = ui.slider('##rfx2mk', self.p.shpMergeK, 0, 1.5, 'Merged footprint elongation: %.2f')
  self.p.shpWaist = ui.slider('##rfx2mw', self.p.shpWaist, 0, 0.45, 'Merged pair peanut waist: %.2f')
  self.p.shpMergeTau = ui.slider('##rfx2mt', self.p.shpMergeTau or 0.6, 0.05, 5, 'Merged footprint recedes to theta_r over %.2f s / mm radius')
  self.p.spreadVarK = ui.slider('##rfx2svk', self.p.spreadVarK, 0, 1.5, 'Per-drop flattening (large drops, seeded): +%.2f')
  self.p.spreadR1 = ui.slider('##rfx2sr1', self.p.spreadR1, 0.2, 2.0, 'Full flattening from radius: %.2f mm (starts at 0.15 mm)')
  self.p.spreadWetK = ui.slider('##rfx2swk', self.p.spreadWetK, 0, 1, 'Wet surface flattens more: x(1 + %.2f wet)')
  if self.p.baseSpread > 1.001 then
    local f = self.p.baseSpread
    ui.text(string.format('  -> footprint x%.2f, contact angle %.0f deg, flat top %.2f (visual only; physics radius unchanged)',
      f, (self.store.contactDeg or 60) / (f * math.sqrt(f)), 0.85 * math.min(f - 1, 1)))
  end
  self.p.shpSpreadMin = ui.slider('##rfx2sp0', self.p.shpSpreadMin, 1, 4, 'Impact splat spread min (x final radius): %.2f')
  self.p.shpSpreadMax = ui.slider('##rfx2sp1', self.p.shpSpreadMax, 1, 5, 'Impact splat spread max: %.2f')
  self.p.shpRecoilC = ui.slider('##rfx2spt', self.p.shpRecoilC or 3.0, 1, 30, 'Splat recoil: tau = %.1f x sqrt(rho r^3 / gamma) (3 = physical, ~11 ms at 1 mm)')
  self.p.shpSkidMax = ui.slider('##rfx2sk', self.p.shpSkidMax, 0, 0.15, 'Skid after impact, max: %.3f m/s')
  ui.separator()
  ui.text('Defocus (final step, off by default)')
  s.apertureMM = ui.slider('##rfx2ap', s.apertureMM, 0, 4, 'Aperture %.2f mm (0 = sharp)')
  s.focusM = ui.slider('##rfx2fz', s.focusM, 0.03, 1.0, 'Focus distance %.3f m')
  if ui.checkbox('D-A colour gather (4 taps near the lens; off = D-C analytic)', s.defocusDA) then s.defocusDA = not s.defocusDA end
  if self.cocInfo then ui.text(self.cocInfo) end
  self:offscreenTestUI()
  ui.separator()
  ui.separator()
  s.substeps = ui.slider('##rfx2sub', s.substeps, 1, 4, 'Min substeps: %.0f (auto up to 4)', true)
  if ui.checkbox('Invert exposure side (auto: side facing away from the eye)', s.invertSide) then s.invertSide = not s.invertSide end
  s.debug = ui.slider('##rfx2dbg', s.debug, 0, 10, 'Debug: 10 sheet state (R supply/q_c, G connected, B lamella, white >= 0.3 mm) 1 water 2 exposure 3 refr.src 4 physics 5 film 6 defocus 7 lens (R rho, G squeeze, B TIR/mip) 8 coverage 9 lens direction (R looks down, G up): %.0f', true)
  self:filmUI()
  self:physicsUI()
  local st = self.stats
  ui.text(string.format('Rain %.1f mm/h  mean D %.2f mm  rel. speed %.1f m/s',
    st.rateMMh or 0, st.meanDiamMM or 0, st.speedRel or 0))
  ui.text(string.format('Impacts %.0f /m2/s  splash K %.0f  resolved %.2f in %.2f mm fragments  fine spray %.2f um/s',
    st.impactRate or 0, st.splashK or 0, st.stickFrac or 0, st.fragDiamMM or 0, (st.sprayMMs or 0) * 1000))
  if st.dq then   -- rev48-P1 supply DSD (constrained gamma) and the impacting-diameter quantiles
    local sm = ac.getSim()
    ui.text(string.format('Supply DSD: D0 %.2f mm (family x%.1f)  mu %.1f  Lambda %.1f /mm | impacting D p50 %.2f p90 %.2f p99 %.2f mm',
      st.dsdD0 or 0, st.familyK or 1, st.dsdMu or 0, st.dsdLambda or 0, st.dq[8] or 0, st.dq[12] or 0, st.dq[15] or 0))
    ui.text(string.format('CSP weather (P3 log): type %s  intensity %.3f  wetness %.3f  water %.3f',
      tostring(sm.weatherType), sm.rainIntensity or 0, sm.rainWetness or 0, sm.rainWater or 0))
    ui.text(string.format('Sub-cloud evaporation (F6): cloud base %.0f m, %.1f %% of the rain mass reaches the ground (%.3f of %.3f mm/h)',
      st.cloudBaseM or 0, (st.groundShare or 1) * 100, st.groundMMh or 0, st.rateMMh or 0))
    ui.text(string.format('Air (CSP): RH %.0f %%  T %.0f C (drop evaporation, sub-cloud evaporation)', (self.fineRH or 0) * 100, self.fineT or 0))
  end
  if self.sourceErr then ui.text('Refraction source: ' .. self.sourceErr) end
  ui.text('GPU/CPU cost: Render Stats -> "RainFX2 sim" / "RainFX2 draw".')
end

-- rev12 evaluation metrics: GPU block reduction (32x8) + async readback at 2 Hz, optional CSV.
local METRICS_HEADER = 'clock,weatherType,rainIntensity,rainWetness,rainWater,windKmh,carKmh,rainFluxMMs,spray,sprayCars,nearestM,filmRate,filmEqMM,filmCover,dropCover,haze,substeps,apertureMM,focusM,defocusDA,contactDeg,wfRefraction,wfSceneMip,filmRefract,filmVeil,scatterK,drops,sizeP50MM,p90p50,p99p50,binRatio,fragA,fragHi,dropDepthUM,residenceS,stagElevDeg,nBand0,p99Band0MM,nBand1,p99Band1MM,nBand2,p99Band2MM\n'
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
    ui.text(string.format('Film cover %.1f %%  drop cover %.2f %%', m.film * 100, m.drops * 100))
  end
  local h = self.sizeHist
  if h and h.total > 0 then
    local b0, parts = self.p.sizeBin0MM, {}
    for k = 1, 10 do parts[k] = string.format('%.2f:%d', b0 * 1.5 ^ (k - 1), h.counts[k]) end
    ui.text('Drops by radius (mm, 1.5x bins): ' .. table.concat(parts, '  '))
    ui.text(string.format('Radius p50 %.2f mm  p90/p50 %.1f  p99/p50 %.1f  bin ratio %.2f  (reference: 3-3.5, >= 10, 0.70)',
      h.p50, h.p90 / math.max(h.p50, 1e-6), h.p99 / math.max(h.p50, 1e-6), h.ratio))
    ui.text(string.format('Water budget: rain in %.3f mm/s (x exposure)  standing as drops %.1f um  -> residence %.2f s  | film supply %.3f mm/s%s',
      (self.stats.fluxMMs or 0) * self.p.exposure, h.depthUM or 0, h.residence or 0, self.stats.filmRate or 0,
      (self.store.filmK or 1) <= 0 and '  (Rain film supply gain 0: unresolved rain is dropped)' or ''))
  end
  if self.recording then ui.text('Recording: ' .. tostring(self.recordPath)) end
  if self.metricsErr then ui.text('Metrics: ' .. self.metricsErr) end
end

-- Water film / spray panel (rev11).
function R2:filmUI()
  local s, st, d, si = self.store, self.stats, self.diag, self.sprayInfo
  ui.separator()
  ui.text('Water film (A regime) / spray')
  s.filmK = ui.slider('##rfx2fk', s.filmK, 0, 5, 'Rain film supply gain (unresolved rain; keep 1): %.2f')
  s.sprayK = ui.slider('##rfx2sk', s.sprayK, 0, 5, 'Spray gain (cars ahead / road spray; 0 hides spray): %.2f')
  s.filmRefract = ui.slider('##rfx2fr', s.filmRefract, 0, 40, 'Film refraction (wave gain): %.1f')
  s.filmVeil = ui.slider('##rfx2fv', s.filmVeil, 0, 1, 'Film veil: %.2f')
  s.scatterK = ui.slider('##rfx2sc', s.scatterK, 0, 3, 'Scatter veil (haze/film/spray): %.2f')
  if si and d then
    ui.text(string.format('Spray LWC %.2f g/m3 -> %.3f mm/s on the visor, splash drops %.4f mm/s (road water %.2f, %d cars, nearest %.0f m)  film supply %.3f mm/s',
      st.spray or 0, st.sprayMMs or 0, st.splashMMs or 0, si.wet or 0, si.cars or 0, si.nearestM or -1, st.filmRate or 0))
    ui.text(string.format('Film equilibrium %.3f mm (full exposure), flow %.3f m/s', d.filmEqMM or 0, d.filmVel or 0))
  end
  self:metricsUI()
end

-- Physics review panel (rev7): inputs breakdown, analytic thresholds, test tools.
function R2:physicsUI()
  local s, p, i, d = self.store, self.p, self.inp, self.diag
  local P = self.physics
  ui.separator()
  ui.text('Physics (rainfx2/physics.lua, docs/RAINFX_V2_CORE.md section 14)')
  if ui.checkbox('Freeze rain (no new drops / haze)', s.freezeRain) then s.freezeRain = not s.freezeRain end
  self.timeScale = ui.slider('##rfx2ts', self.timeScale or 1, 0.05, 1, 'Physics time scale: %.2f (slow motion, not saved)')
  s.windK = ui.slider('##rfx2wk', s.windK, 0, 1, 'Ambient wind reaching the visor: %.2f')
  if ui.button('Physics test: drop ladder 0.3..2.2 mm (left -> right)') then
    self.ladderRequest = true
    s.freezeRain = true
  end
  ui.text('Debug 4: pinned = blue residue/merged, cyan split piece, white satellite | green <0.1 | yellow <0.3 | orange <0.6 | red >=0.6 m/s | magenta step-limited')
  if not i or not d then return end
  ui.text(string.format('Car %.1f m/s  wind %.1f m/s (sim windSpeedKmh %.1f m/s, from %s)  air rel. %.1f m/s  accel %.2f g',
    i.carSpeed, i.windSpeed, i.windSpeedSim, i.windSource or '?', i.airSpeed, i.accelG))
  local rd = self.rainDirW
  if rd then
    ui.text(string.format('Rain direction (world, relative to the visor): x %.2f y %.2f z %.2f -> %.0f deg from vertical (Debug 2 follows this)',
      rd.x, rd.y, rd.z, math.deg(math.acos(math.max(-1, math.min(1, -rd.y))))))
  end
  ui.text(string.format('Wind direction convention: offset %.0f deg (%s). Calibrates itself while a live session has wind.',
    p.windDirOffsetDeg or s.windDirOffsetDeg or 180, s.windDirCalibrated and 'calibrated' or 'default: meteorological from'))
  if ui.button('Flip wind convention (180 deg)') then
    p.windDirOffsetDeg = ((p.windDirOffsetDeg or 180) + 180) % 360
    s.windDirOffsetDeg = p.windDirOffsetDeg
  end
  local function rc(v) return v == math.huge and 'never' or string.format('%.2f mm', v) end
  ui.text(string.format('Slides by gravity from r = %s (coat), %s (glass), keeps sliding from %s; with air (coat) %s',
    rc(d.rcGravCoat), rc(d.rcGravGlass), rc(d.rcGravCoatKin), rc(d.rcAllCoat)))
  ui.text(string.format('Speed (coat, forces aligned, R6 uncapped): r0.5 %.2f  r1 %.2f  r2 %.2f m/s',
    d.v05, d.v10, d.v20))
  local U = i.airSpeed or 0
  ui.text(string.format('Helmet air: outer flow %.1f m/s, boundary layer %.2f mm | swept alone from r = %s (2 deg) %s (20 deg) %s (50 deg)',
    self.aeroU or 0, self.aeroDelta or 0, rc(P.aeroCritical(p, U, math.rad(2), p.pinCoat)),
    rc(P.aeroCritical(p, U, math.rad(20), p.pinCoat)), rc(P.aeroCritical(p, U, math.rad(50), p.pinCoat))))
  ui.text(string.format('Acceleration (car + head): raw %.2f g -> neck-filtered %.2f g', i.accRawG or 0, i.accFiltG or 0))
  local hl = self.helmetUpLocal
  ui.text(string.format('Helmet axes from the visor transform (not the camera): local up (%d,%d,%d), up . world up = %.2f',
    hl and hl.x or 0, hl and hl.y or 0, hl and hl.z or 0, self.helmetUpY or 0))
  ui.sameLine()
  if ui.button('Re-pick helmet up') then self.helmetUpLocal = nil end
  ui.text(string.format('Substeps %d -> step limit %.2f m/s (faster drops are speed-limited)',
    p.substeps or 0, d.vGather))
end

function R2:dispose()
  for _, list in ipairs({ self.S or {}, self.F or {}, self.TG or {} }) do
    for _, c in ipairs(list) do c:dispose() end
  end
  if self.mesh then self.mesh:dispose() end
  if self.source then self.source:dispose() end
  if self.C then self.C:dispose() end
  if self.testCanvas then self.testCanvas:dispose(); self.testCanvas = nil end
  if self.Mc then self.Mc:dispose(); self.Mc = nil end
  if self.Hc then self.Hc:dispose(); self.Hc = nil end
  self.source, self.sceneTex, self.C = nil, nil, nil
  self.S, self.F, self.TG, self.mesh, self.ready, self.opticsReady = nil, nil, nil, nil, false, false
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
  local common = readFile(dir .. 'common.hlsl')
  local src = {}
  for _, name in ipairs({ 'cells', 'field', 'trail', 'visor', 'source', 'claim', 'merge', 'seed', 'metrics', 'sizes', 'sheet', 'sheetcoef', 'nuc', 'lam', 'bead', 'big' }) do
    src[name] = readFile(dir .. name .. '.hlsl')
    if not src[name] or not common then
      self.err = 'Missing shader: rainfx2/shaders/' .. name .. '.hlsl'
    end
  end
  if not self.err then
    self.src = {
      cells = common .. '\n' .. src.cells,
      field = common .. '\n' .. src.field,
      trail = common .. '\n' .. src.trail,
      claim = common .. '\n' .. src.claim,
      merge = common .. '\n' .. src.merge,
      seed = common .. '\n' .. src.seed,
      metrics = common .. '\n' .. src.metrics,
      sizes = common .. '\n' .. src.sizes,
      sheet = common .. '\n' .. src.sheet,
      sheetcoef = common .. '\n' .. src.sheetcoef,
      nuc = common .. '\n' .. src.nuc,
      lam = common .. '\n' .. src.lam,
      bead = common .. '\n' .. src.bead,
      big = common .. '\n' .. src.big,
      visor = src.visor,
      source = src.source,
      visorDepth = '#define R2_DEPTH_ONLY 1\n' .. src.visor,
    }
  end
  return self
end
