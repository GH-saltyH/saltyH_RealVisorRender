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
  terminalSpeed = 6.0, diamScale = 1.0, impactScale = 1.0, sprayFlux = 2e-5,
  stickSlow = 0.8, microK = 7.0,   -- rev21: stickFast replaced by the splash rule (splashK0/resA/resB)
  -- rev47b: rain exposure 0.5 -> 1.0 (stored under a new key), rain arrives in a cone of rainSpreadDeg,
  -- crown runoff over the visor top edge at rest (catch length crownMM into a band of crownBandMM)
  exposure = 1.0, exposureFloor = 0.0, normalSign = 1.0, rainSpreadDeg = 18.0, crownMM = 20.0, crownBandMM = 3.0,
  -- drop physics: rainfx2/physics.lua (P.DEFAULTS, merged below)
  ladderMinMM = 0.3, ladderMaxMM = 2.2,   -- physics test drop ladder
  -- field
  -- rev21: moving drops wipe the haze clean and leave only a faint trace (user observation of real
  -- visors, research section 3.3): collect 0.9 -> 0.95, trace haze 0.15 -> 0.05 (below)
  microEvap = 0.05, microShear = 0.02, microCollect = 0.95,
  -- rev21 R-size (docs/RAINFX_V2_DROP_SIZE_RESEARCH.md section 3): impact fragmentation
  -- rev41 (rev40 review: at speed far too few visible small drops): resA 0.5 -> 0.3 (resolved share at
  -- 250 km/h 0.11 -> 0.25), resB 0.3 -> 0.4 (fragments 0.18 -> 0.12 mm)
  splashK0 = 58, resA = 0.3, resB = 0.4,
  -- rev21 growth of visible drops from unresolved water: haze condensation, film head drops
  nucM = 0.35, nucRate = 0.6, headMinMM = 0.08, headRate = 3.0, filmCollect = 0.3,
  -- rev21 CSP adoption: lateral kicks from surface noise (6 mm features), trail following
  meander = 0.0, meanderMM = 6.0, trailFollow = 1.5,   -- rev48-S6: the 6 mm meander is replaced by the defect field (F1)
  defMM = 1.2, defK = 5.0, defPin = 0.35,              -- rev48-S6 F1 surface defects: scale, gradient steering, stick-slip pinning
  -- sheetDrain rev14 0.5 -> 0.1: drainage dominated the film balance (eq ~ supply), now edge
  -- outflow does (eq ~ supply^(1/2..1/3)), compressing light..heavy into the cover window.
  traceDecay = 0.6, traceAmount = 0.6, sweepWidth = 0.9, sheetDrain = 0.1,
  -- drop lens (rev18): legacy Water Field rule, docs/RAINFX_V2_WF_LENS_PLAN.md
  kernelScale = 1.24, threshold = 0.35,     -- dome 1-(d/1.24R)^2, silhouette at U = 0.35 (= R)
  -- rev20 drop surface: contact angle of an impact-deposited drop (~ receding angle on polycarbonate
  -- / hard coat), per-drop spread, extra recession at the sliding rear, flattening on a wet surface.
  -- rev25: 75 -> 55. The TIR band starts at r/R = sin(48.6 deg)/sin(theta): 75 deg -> outer 22 % of the
  -- radius dark (thick rim on close drops), 55 deg -> 8 % (thin rim like the reference)
  contactDeg = 60, contactSpread = 8,   -- rev35: 60 (user: stronger curl looked better; normal 40-60)
  hysteresisDeg = 20, wetFlatten = 0.5,
  -- rev20 wobble of pinned drops in airflow (amplitude ~ drag/pinning), visible-rate tones
  wobbleAmp = 0.08, wobbleHz = 8.0,   -- rev21: 0.12 -> 0.08 (user: 0.07-0.09 best at speed)
  motionStretch = 0.35,                     -- WF MOTION_STRETCH
  minDrawMM = 0.06,                         -- smaller drops are drawn at this radius (rev21: 0.2 -> 0.12, rev41: 0.06)
  wfRefraction = 0.14,                      -- near lens (rev22 default = user choice 0.14; WF 0.69 -> chrome). Far rim: farRefraction
  wfSceneMip = 2.0, wfSlopeMip = 1.5,       -- WF SCENE_MIP 3 on a full-res shot = 2 on the half-res source
  largeStartPx = 8, largeFullPx = 30, largeBlurMip = 1.5, largeWarpPx = 4,   -- WF LARGE_WARP_PIXELS (rev19)
  -- defocus (rev18, D-C): thin-lens circle of confusion, docs/RAINFX_V2_DEFOCUS_PLAN.md
  apertureMM = 0.0,        -- entrance pupil A (rev23: 0 until the final whole-visor defocus step)
  focusM = 0.12,           -- focus distance zf (left visor ~ in focus, near-lens right blurred)
  defocusDA = true,        -- rev19: D-A stochastic colour gather (4 taps where CoC > 1 px); off = D-C
  housingM = 0.20,         -- frame pixels closer than this (linear m) are helmet housing (rev27: UI slider)
  sourceScale = 0.5,       -- refraction source resolution (fraction of the frame)
  -- rev22: symmetric rim loss 0.75 -> 0.35; the one-sided rim shading now comes from the far lens
  -- rev23 (look lab, offline match to the reference): one-sided rim from a directional environment
  -- rev31: WF values again (lens mode 0 = legacy Water Field rule is the default)
  -- rev33: symmetric rim loss 0 (user: a rim carries its own view direction, it cannot be a black ring)
  edgeLoss = 0.0, lossStart = 0.70, lossEnd = 1.30, glint = 0.45,
  -- rev32 two-zone WF lens: rim / small drops at the legacy strength, interior at the user's
  wfRimRefraction = 0.69, rimMip = 1.0, smallFullPx = 6, smallEndPx = 16,
  rimSharp = 1.0,     -- rev36: side views tilt only the outer 1/rimSharp of the radius; rev42 1 = off
                      -- (it flattened the interior: 'aluminium' drops, rev41 review, CORE section 54)
  -- rev43 single plano-convex lens (CORE section 55): one strength, 1 = physical (n 1.333). The rev32-42
  -- interior / rim refraction pair and the side-view band (rimSharp) are no longer used by the lens.
  lensPhys = 1.0,
  -- rev24 physical plano-convex lens (visor.hlsl r2DropLens): deflection gain (1 = physical, n 1.333),
  -- environment for rays leaving the screen (ground fraction of the sky colour), TIR interior,
  -- gravity sag of pinned drops (thick toward gravity, thin tail above)
  lensK = 0.35, envGround = 0.12, envInterior = 0.35, sagK = 0.25,
  rimMinPx = 1.5,     -- rev27: rim band at least this many px (small drops keep an outline)
  -- rev28 CSP windscreen drop shading (docs/RAINFX_V2_CSP_DROP_SHADING.md)
  rimBand = 0.25,     -- outer fraction of the radius shaded from the cubemap (CSP steep-normal zone)
  cspRefract = 0.30,  -- screen refraction of the flat interior (uv per unit normal tilt; CSP 0.25-0.5)
  rimEnvK = 0.7, rimCubeMip = 1.0, reflK = 1.0,
  -- rev29 full CSP windscreen port (docs/RAINFX_V2_CSP_DROP_SHADING.md section 5)
  cspMode = false,    -- rev31: not adopted (user rev30 review); kept for comparison
  lensMode = 0,       -- rev31: 0 legacy WF lens (default), 1 rev28 CSP cell shading
  depthTest = true,   -- rev32: back on (user: needed so the helmet housing hides the water; no effect on the pattern)
  wmU = 1024, wmV = 256,                -- water map texel ~0.59 x 0.57 mm (CSP windscreen 2048 map ~0.7 mm)
  wmMinMM = 0.15, wmSplit = 0.5, wmSkirt = 0.2, wmNoise = 1.0, wmStretch = 0.6,
  wmDecay = 2.0,      -- /s, traces fade (rev30: 0.5 read sticky/oily; CSP keeps them until a wiper)
  wmScale = 0.5,      -- rev30: drawn size of the water stamps vs the physical drop (visor scale tuning)
  wmStepMM = 0.7, wmBlurMip = 1.75,     -- CSP: 1 texel step at LOD 1.5 of a ~0.7 mm map
  wmNormalK = 2.2, wmCovK = 2.0,
  clearMaxMM = 0.3, clearK = 1.0,                     -- rev22 impact clearing of small pinned drops
  -- rev40 size mix (docs/RAINFX_V2_DROP_PIPELINE_PLAN.md step 2): fragment / nucleation diameter =
  -- base x X, pdf(X) ~ X^-(1+fragA) on [fragLo, fragHi] (0.88 = reference: counts x0.7 per 1.5x bin)
  fragA = 0.88, fragLo = 0.35, fragHi = 3.0, nucDiamMM = 0.2,   -- rev41 nuc 0.4 -> 0.2
  -- rev41: fragments of one impact spread over its lamella (cap per impact), clustered births
  fragMax = 12, clusterK = 0.6, clusterMM = 12.0,
  -- rev40 stagnation turbulence: tangential gusts = turbK x surface share of the relative air,
  -- spatial scale turbMM, correlation time turbTau (s)
  turbK = 0.0, turbMM = 8.0, turbTau = 0.2,   -- rev47 0: replaced by the stagnation buffeting (aero)
     -- rev41 1.0 / 0.06 -> rev42 0.6 / 0.2 (rev41 recording: jerky jumps)
  -- rev40 P3 gravity flattening of large drops (Bond number), radius ramp start -> full
  flatK = 0.0, flatStartMM = 1.0, flatFullMM = 2.2,   -- rev41 off (rev40 review: pot-lid look, lost volume)
  -- rev45 step 3 (docs/RAINFX_V2_DROP_PHYSICS_MODEL.md section 6 B): life cycle and trails
  growTime = 0.06, fadeTime = 0.10,          -- s: newborn drops grow in, swept drops fade out
  flyTime = 0.07, flySpeed = 0.25, flyStretch = 2.5,   -- blown-off drops fly off as a streak
  trailMM = 0.10, trailV0 = 0.02, trailWidthK = 0.5, trailRMin = 0.2,   -- rev47k trailRMin 0.12 -> 0.2 (small heads leave no visible rivulet)
  -- trail water (rule_trail; rev47j width 0.35 -> 0.5 r: reference ~1/4 of the head)
  trailThetaRDeg = 28.0, trailWetK = 0.35, trailLL = 5.0,   -- rev47l trail rule (Ca vs Ca*, docs/RAINFX_V2_TRAIL_RULES.md)
  -- rev48-S1 shape state (docs/RAINFX_V2_SHAPE_STATE_PLAN.md section 6): birth class shares, relaxation
  shpImpactK = 0.15, shpImpactMax = 1.8,   -- rev48-S2' (birth events: splats spread nearly evenly; was 0.35 / 3)
  baseSpread = 1.0,
  spreadVarK = 0.5, spreadR0 = 0.15, spreadR1 = 0.8, spreadWetK = 0.3,   -- rev48-S2c per-drop resting spread
    -- rev48-S2'b: resting drop profile = splat rule at this f (1 = rev48 dome; try 1.3-1.5)
  shpSpreadMin = 1.8, shpSpreadMax = 3.2, shpSpreadTau = 0.12, shpLamShift = 0.15,   -- rev48-S2' splat spread / recoil
  shpSkidK = 0.01, shpSkidMax = 0.05, shpRecoilT = 0.8,   -- rev48-S2b recoil 0.4 -> 0.8 s (60 s rest: settled drops stayed vertical ovals)
  -- (rev48-S2 oblique impact)
  shpMergeK = 1.0, shpWaist = 0.3,      -- rev48-S3 merged footprint (tensor gain, peanut waist of a balanced pair)
  asymK = 0.35, asymGravR = 1.0,       -- rev48-S2d off-centre apex (strength, radius where it points downhill)
  footPhys = true,                     -- rev48-S3b coalescence uses the drawn footprint (S4c: = the water radius x shape)
  footPinK = 1.0,                      -- rev48-S7 Furmidge: pinning by the contact width across the force (0 = 2r)
  shpBoK = 1.2, shpTearK = 0.12,
  shpSlugTau = 0.6, shpAirK = 0.08, shpAirMax = 1.6,   -- rev48-S5 E3 slug length memory, E6 air stretch of pinned drops
  shpTailTau = 0.25, shpTailStretch = 0.2, shpHookK = 2.0, shpFrontK = 1.2, shpSnapDeg = 40.0,   -- rev48-S6 F2 turns (S6b: head hook)
  shpSplitA = 2.6, shpSplitRate = 6.0, shpSplitRMin = 0.45, shpNeckK = 1.5, shpNeckT = 0.12, hiSplit = false,   -- rev48-S6c E8 tail split (aspect, events / s, min parent radius mm)
  shpOn = true, shpBendP = 0.07, shpLobeP = 0.02, shpSagP = 0.0, shpRelaxMove = 0.12, shpRelaxStill = 10.0,   -- rev48-S5 E7 replaces the random sag class (shpSagP 0)
  shpMotionK = 0.6, shpMotionV = 0.04, shpArrest = 0.5,   -- rev48-S4 motion morph (aspect 1 + k v/V), splat arrest share
  trailSlopeMax = 0.45,                      -- rev47k: rivulet edge slope 2 h0 / hw <= 0.45 (~24 deg; rev47j 0.8 drew glass rods)
  trailPinMM = 0.02, trailFlowK = 1.0,       -- rev47k: rivulets deeper than this run along themselves (film law x flowK)
  wetHaze = 1.5, hazeDepthMM = 0.004,        -- wetness from haze; water depth of full haze
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
  scatterK = 1.0, scatterM = 0.35, scatterM0 = 0.04, scatterFilm = 0.3, scatterSpray = 0.0,
  scatterMax = 0.35, scatterMip = 6.5, scatterSky = 0.3, scatterGain = 1.1,
  filmK = 1.0, sprayK = 1.0,
  hazeK = 0.8, traceHaze = 0.0,   -- rev47: R is trail water (drawn as water), no extra haze
  hazeMip = 4.0, veilMix = 0.25, veilBright = 1.0,
  depthCoverage = 0.35, debug = 0, debugBright = 1.0,
}

-- Persisted user controls (subset of DEFAULTS + enable switch).
local STORED = { enabled = true, rainExposure = DEFAULTS.exposure, wfRefraction = DEFAULTS.wfRefraction,
  wfSceneMip = DEFAULTS.wfSceneMip, focusM = DEFAULTS.focusM, defocusDA = DEFAULTS.defocusDA,
  contactDeg = DEFAULTS.contactDeg, wobbleAmp = DEFAULTS.wobbleAmp, lensK = DEFAULTS.lensK,
  apertureMM = DEFAULTS.apertureMM, hazeK = DEFAULTS.hazeK, substeps = DEFAULTS.substeps, freezeRain = false, windK = 1.0, metrics = false,
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
  v.gR2StickFrac = st.stickFrac or 0.6
  v.gR2StickSlow = p.stickSlow
  v.gR2SpeedRel = st.speedRel or p.terminalSpeed
  v.gR2SplashK0 = p.splashK0
  v.gR2ResA = p.resA
  v.gR2ResB = p.resB
  v.gR2NucM = p.nucM
  v.gR2NucRate = p.nucRate
  v.gR2HeadMinMM = p.headMinMM
  v.gR2HeadRate = p.headRate
  v.gR2FilmCollect = p.filmCollect
  v.gR2ClearMaxMM = p.clearMaxMM
  v.gR2ClearK = p.clearK
  v.gR2Meander = p.meander
  v.gR2DefInvMM, v.gR2DefK, v.gR2DefPin = 1.0 / math.max(p.defMM, 0.05), p.defK, p.defPin   -- rev48-S6 F1
  v.gR2TrailFollow = p.trailFollow
  if not self.meanderScale then self.meanderScale = vec2(602.0 / p.meanderMM, 146.3 / p.meanderMM) end
  v.gR2MeanderScale = self.meanderScale
  v.gR2MicroRate = self.store.freezeRain and 0 or (st.microRate or 0)
  v.gR2Exposure = p.exposure
  v.gR2ExposureFloor = p.exposureFloor
  v.gR2RainSpreadS = math.sin(math.rad(p.rainSpreadDeg))
  v.gR2CrownMM = p.crownMM
  v.gR2CrownBandMM = p.crownBandMM
  v.gR2RainMMs = self.store.freezeRain and 0 or (self.stats.rateMMh or 0) / 3600
  v.gR2RunbackK = p.runbackK
  v.gR2RunbackMax = p.runbackMax
  v.gR2LiftMM = p.liftMM
  v.gR2SlideTau = p.slideTau
  v.gR2ImpactLoss = p.impactLoss
  v.gR2NormalSign = p.normalSign
  v.gR2ShapeK = p.shapeK
  v.gR2PinCoat = p.pinCoat
  v.gR2PinGlass = p.pinGlass
  v.gR2PinNoiseMin = p.pinNoiseMin
  v.gR2PinNoiseMax = p.pinNoiseMax
  v.gR2Friction = p.friction
  v.gR2DragCd = p.dragCd
  v.gR2RhoAir = p.rhoAir
  v.gR2AirSurface = p.airSurface
  v.gR2VMax = p.vMax
  v.gR2VScale = p.vScale
  v.gR2TrailLoss = p.trailLoss
  v.gR2SurfaceTension = p.surfaceTension
  v.gR2PinKinetic = p.pinKinetic
  v.gR2VShed = p.vShed
  v.gR2GatherCells = p.gatherCells
  v.gR2LadderMinMM = p.ladderMinMM
  v.gR2LadderMaxMM = p.ladderMaxMM
  v.gR2Evap = p.evap
  v.gR2MinRadiusMM = p.minRadiusMM
  v.gR2MaxRadiusMM = p.maxRadiusMM
  v.gR2CoalesceK = p.coalesceK
  v.gR2MicroEvap = p.microEvap
  v.gR2MicroShear = p.microShear
  v.gR2MicroCollect = p.microCollect
  v.gR2TraceDecay = p.traceDecay
  v.gR2TraceAmount = p.traceAmount
  v.gR2SweepWidth = p.sweepWidth
  v.gR2SheetDrain = p.sheetDrain
  v.gR2FilmCf = p.filmCf
  v.gR2FilmFlowK = p.filmFlowK
  v.gR2FilmDiffuse = p.filmDiffuse
  v.gR2FilmMaxMM = p.filmMaxMM
  v.gR2FilmRate = self.store.freezeRain and 0 or (st.filmRate or 0)
  v.gR2FilmSplashMM = st.filmSplashMM or 0.1
  v.gR2FilmMinMM = p.filmMinMM
  -- rev40 size mix, stagnation turbulence, size histogram
  local fl = fragLaw(p, self.frag or {})
  self.frag = fl
  v.gR2FragLoP = fl.loP
  v.gR2FragHiP = fl.hiP
  v.gR2FragInvA = fl.invA
  v.gR2FragM3 = fl.m3
  v.gR2NucDiamMM = p.nucDiamMM
  v.gR2Time = self.wobbleT or 0
  v.gR2TurbK = p.turbK
  if not self.turbScale or self.turbMM ~= p.turbMM then
    self.turbMM = p.turbMM
    self.turbScale = vec2(602.0 / p.turbMM, 146.3 / p.turbMM)
  end
  v.gR2TurbScale = self.turbScale
  v.gR2TurbTau = p.turbTau
  v.gR2SizeBin0MM = p.sizeBin0MM
  v.gR2FilmFullMM = p.filmFullMM
  v.gR2WetHaze = p.wetHaze
  v.gR2HazeDepthMM = p.hazeDepthMM
  v.gR2TrailMM = p.trailMM
  v.gR2TrailMaxMM = p.trailMaxMM
  v.gR2TrailEvapMMs = p.trailEvapMMs
  v.gR2TrailV0 = p.trailV0
  v.gR2TrailWidthK = p.trailWidthK
  v.gR2TrailRMin = p.trailRMin
  v.gR2PearlMM = p.pearlMM
  v.gR2PearlRate = p.pearlRate
  v.gR2TrailSlopeMax = p.trailSlopeMax
  v.gR2ShpOn = p.shpOn and 1 or 0
  v.gR2ShpBendP, v.gR2ShpLobeP, v.gR2ShpSagP = p.shpBendP, p.shpLobeP, p.shpSagP
  v.gR2ShpRelaxMove, v.gR2ShpRelaxStill = p.shpRelaxMove, p.shpRelaxStill
  v.gR2ShpMergeK, v.gR2ShpWaist = p.shpMergeK, p.shpWaist
  v.gR2ShpMotionK, v.gR2ShpMotionV, v.gR2ShpArrest = p.shpMotionK, p.shpMotionV, p.shpArrest
  v.gR2ShpBoK, v.gR2ShpTearK = p.shpBoK, p.shpTearK
  v.gR2ShpSlugTau, v.gR2ShpAirK, v.gR2ShpAirMax = p.shpSlugTau, p.shpAirK, p.shpAirMax
  v.gR2ShpTailTau, v.gR2ShpTailStretch, v.gR2ShpHookK, v.gR2ShpSnapDeg = p.shpTailTau, p.shpTailStretch, p.shpHookK, p.shpSnapDeg   -- rev48-S6 F2
  v.gR2ShpSplitA, v.gR2ShpSplitRate, v.gR2ShpSplitRMin = p.shpSplitA, p.shpSplitRate, p.shpSplitRMin   -- rev48-S6c E8
  v.gR2FootPhys = p.footPhys and 1 or 0
  v.gR2FootPinK = p.footPinK
  v.gR2BaseSpread = p.baseSpread
  v.gR2SpreadVarK, v.gR2SpreadR0, v.gR2SpreadR1, v.gR2SpreadWetK = p.spreadVarK, p.spreadR0, p.spreadR1, p.spreadWetK
  v.gR2ShpImpactK, v.gR2ShpImpactMax = p.shpImpactK, p.shpImpactMax
  v.gR2ShpSkidK, v.gR2ShpSkidMax, v.gR2ShpRecoilT = p.shpSkidK, p.shpSkidMax, p.shpRecoilT
  v.gR2ShpSpreadMin, v.gR2ShpSpreadMax, v.gR2ShpLamShift = p.shpSpreadMin, p.shpSpreadMax, p.shpLamShift
  v.gR2TrailThetaRDeg = p.trailThetaRDeg
  v.gR2TrailWetK = p.trailWetK
  v.gR2TrailLL = p.trailLL
  v.gR2TrailPinMM = p.trailPinMM
  v.gR2TrailFlowK = p.trailFlowK
  v.gR2FilmBeadMM = p.filmBeadMM
  v.gR2DewetRate = p.dewetRate
  v.gR2FlyTime = p.flyTime
  v.gR2FlySpeed = p.flySpeed
  v.gR2FadeTime = p.fadeTime
  v.gR2FragMax = p.fragMax
  v.gR2AeroDirW = self.aeroDir or vec3(0, 0, -1)
  v.gR2AeroU = self.aeroU or 0
  v.gR2AeroDuDs = self.aeroDuDs or 0
  v.gR2BLDeltaMM = self.aeroDelta or 50
  v.gR2DropTau = p.dropTau
  v.gR2SimDt = self.frameDt or (1 / 60)
  v.gR2ShedK = p.shedK
  v.gR2AirDown = p.airDown
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
    textures = { txR2State = false, txR2Field = false, txR2Claim = false, txR2WMap = false, txR2Trail = false,
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
  self.F = { canvas(p.fieldU, p.fieldV, 1, u16, 'RainFX2 field A'), canvas(p.fieldU, p.fieldV, 1, u16, 'RainFX2 field B') }
  -- rev47j trail geometry (line point / direction / half-width per field texel)
  local h16 = render.TextureFormat.R16G16B16A16.Float
  self.TG = { canvas(p.fieldU, p.fieldV, 1, h16, 'RainFX2 trail A'), canvas(p.fieldU, p.fieldV, 1, h16, 'RainFX2 trail B') }
  self.ti = 1
  -- rev29 CSP windscreen water map (wmap.hlsl), RGBA16F with mips for the blurred-height normal
  local wmMips = math.floor(math.log(math.max(p.wmU, p.wmV)) / math.log(2)) + 1
  self.WM = { canvas(p.wmU, p.wmV, wmMips, render.TextureFormat.R16G16B16A16.Float, 'RainFX2 water map A'),
              canvas(p.wmU, p.wmV, wmMips, render.TextureFormat.R16G16B16A16.Float, 'RainFX2 water map B') }
  self.wmi = 1
  self.wmSize = vec2(p.wmU, p.wmV)
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
  self.passTrail = newPass(self, self.src.trail)
  self.passWMap = newPass(self, self.src.wmap)
  self.passClaim = newPass(self, self.src.claim)
  self.passMetrics = newPass(self, self.src.metrics)
  self.Mc = canvas(32, 8, 1, render.TextureFormat.R8G8B8A8.UNorm, 'RainFX2 metrics')
  self.passSizes = newPass(self, self.src.sizes)
  self.Hc = canvas(10, 16, 1, render.TextureFormat.R8G8B8A8.UNorm, 'RainFX2 size histogram')
  self.passMerge = newPass(self, self.src.merge)
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
  self.airW:set(air.x, air.y, air.z)
  self.rainDirW:set(rainVel.x / math.max(speedRel, 1e-6), rainVel.y / math.max(speedRel, 1e-6), rainVel.z / math.max(speedRel, 1e-6))
  local up = sim.cameraUp or vec3(0, 1, 0)
  local side = sim.cameraSide or vec3(1, 0, 0)
  local su = vec2(side.y, -up.y)
  local sl = math.sqrt(su.x * su.x + su.y * su.y)
  self.screenUp = sl > 1e-3 and vec2(su.x / sl, su.y / sl) or vec2(0, -1)
  local p = self.p
  self.weather.compute({ rainIntensity = sim.rainIntensity, speedRel = speedRel, sprayEstimate = 0, p = p }, self.stats)
  self.stats.speedRel = speedRel
  -- rev11 film supply: rain that does not stick as resolved drops + road spray.
  local spray, info = self.spray.estimate(sim, p, self.sprayInfo)
  self.sprayInfo = info
  spray = spray * p.sprayK
  local st = self.stats
  st.spray = spray
  local rainFilm = (st.fluxMMs or 0) * (1 - (st.stickFrac or 0.6)) * p.filmRainK
  local sprayFilm = spray * p.sprayFluxMMs
  -- rev47f: the two sources have separate gains (rev11-47e: filmK scaled both, so hiding spray with
  -- filmK 0 also removed the unresolved rain -- the trail / head-drop / wetness supply)
  st.rainFilm, st.sprayFilm = rainFilm * p.filmK, sprayFilm
  st.filmRate = rainFilm * p.filmK + sprayFilm
  p.filmRateMMs = st.filmRate
  local dRain = st.meanDiamMM or 0.5
  local dMix = (rainFilm * dRain + sprayFilm * p.sprayDiamMM) / math.max(rainFilm + sprayFilm, 1e-9)
  local texelMM2 = (602.0 / p.fieldU) * (146.3 / p.fieldV)
  st.filmSplashMM = math.pi * dMix * dMix * dMix / texelMM2   -- E[V] = pi D^3 (exponential DSD)
  st.microRate = (st.microRate or 0) + p.sprayHaze * spray
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
  p.exposure, p.apertureMM, p.hazeK, p.debug = s.rainExposure, s.apertureMM, s.hazeK, s.debug
  p.wfRefraction, p.wfSceneMip, p.focusM = s.wfRefraction, s.wfSceneMip, s.focusM
  p.contactDeg, p.wobbleAmp, p.lensK = s.contactDeg, s.wobbleAmp, s.lensK
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
      if self.WM then self.WM[1]:clear(rgbm(0, 0, 0, 0)); self.WM[2]:clear(rgbm(0, 0, 0, 0)) end
      ps.values.gR2LabOcc = p.labOcc
      ps.values.gR2LabRMinMM = p.labRMinMM
      ps.values.gR2LabRMaxMM = p.labRMaxMM
      if run(self.S[3 - self.si], ps) then self.si = 3 - self.si; self.labSeeded = true end
    end
    self.frameDt = self.frameDt or (1 / 60)
    self:updateWaterMap(0)                       -- static set: stamps only, no decay
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
  if vExp == math.huge then vExp = p.vMax end          -- rev42: blown-off drops leave, no steps needed
  if (self.inp.airSpeed or 0) > 10 then vExp = math.max(vExp, p.runbackMax) end   -- rev47b: runback
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
  if p.coalesceK > 0 then
    local pk, pm = self.passClaim, self.passMerge
    pk.textures.txR2State = self.S[self.si]
    pk.textures.txR2Field = self.F[self.fi]        -- rev48-S3b: wetness for the footprint radius
    sceneValues(self, pk.values)
    if run(self.C, pk) then
      pm.textures.txR2State = self.S[self.si]
      pm.textures.txR2Claim = self.C
      sceneValues(self, pm.values)
      if run(self.S[3 - self.si], pm) then self.si = 3 - self.si end
    end
  end
  -- rev8: only P1 runs per substep. Coalescence and the field run once per frame:
  -- touching drops merging a few ms later is invisible, landing drops still merge in
  -- the P1 gather, and the field draws the frame's accumulated displacement.
  -- (rev7: 4 passes x 4 substeps = frame preparation 0.57 ms.)
  for i = 1, p.substeps do
    self.sub = i
    local pc = self.passCells
    pc.textures.txR2State = self.S[self.si]
    pc.textures.txR2Field = self.F[self.fi]   -- rev21: haze/film births, trail following
    pc.textures.txR2Trail = self.TG[self.ti]  -- rev47j: pearling reads the rivulet lines
    sceneValues(self, pc.values)
    if not run(self.S[3 - self.si], pc) then self.status = 'compiling cells'; return end
    self.si = 3 - self.si
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
    local pf = self.passField
    pf.textures.txR2State = self.S[self.si]
    pf.textures.txR2Field = self.F[self.fi]
    pf.textures.txR2Trail = self.TG[self.ti]
    sceneValues(self, pf.values)
    pf.values.gR2Dt = self.frameDt                 -- field integrates the whole frame
    if run(self.F[3 - self.fi], pf) then
      self.fi = 3 - self.fi
      if trailOk then self.ti = 3 - self.ti end
    end
  end
  self:updateWaterMap(self.frameDt)
  self:metricsUpdate(sim)
  self.opticsReady = true
  self.status = 'running'
end

-- rev29: CSP water map update (stamps from the cell state + sharpen/decay of the previous map).
function R2:updateWaterMap(dt)
  local p = self.p
  if not p.cspMode then return end
  local pw = self.passWMap
  pw.textures.txR2State = self.S[self.si]
  pw.textures.txR2WMap = self.WM[self.wmi]
  sceneValues(self, pw.values)
  local v = pw.values
  v.gR2Dt = dt
  v.gR2WMSize = self.wmSize
  v.gR2WMMinMM, v.gR2WMSplit, v.gR2WMSkirt = p.wmMinMM, p.wmSplit, p.wmSkirt
  v.gR2WMNoise, v.gR2WMStretch, v.gR2WMDecay = p.wmNoise, p.wmStretch, p.wmDecay
  v.gR2WMScale = p.wmScale
  local dst = self.WM[3 - self.wmi]
  if run(dst, pw) then
    dst:mipsUpdate()
    self.wmi = 3 - self.wmi
  end
end

function R2:drawParams(depth)
  local key = depth and 'paramsDepth' or 'paramsColour'
  local t = self[key]
  if not t then
    t = { mesh = self.mesh, transform = 'original', async = true,
      textures = { txR2State = false, txR2Field = false, txR2Trail = false, txR2Scene = false, txR2WMap = false, txR2Mask = self.ctx.maskPath },
      values = {}, shader = depth and self.src.visorDepth or self.src.visor }
    self[key] = t
  end
  local p, v = self.p, t.values
  local size = render.getRenderTargetSize()
  v.gR2InvRT = vec2(1 / math.max(size.x, 1), 1 / math.max(size.y, 1))
  v.gR2Cells = self.cells
  v.gR2CellSizeMM = self.cellSizeMM
  v.gR2TexMM = self.texMM
  v.gR2ShapeK = p.shapeK
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
  v.gR2ShpSpreadTau = p.shpSpreadTau   -- rev48-S2'
  v.gR2BaseSpread = p.baseSpread       -- rev48-S2'b
  v.gR2AsymK, v.gR2AsymGravR = p.asymK, p.asymGravR   -- rev48-S2d
  v.gR2ShpFrontK = p.shpFrontK                         -- rev48-S6 F2 outer-front apex
  v.gR2ShpNeckK, v.gR2ShpNeckT, v.gR2HiSplit = p.shpNeckK, p.shpNeckT, p.hiSplit and 1 or 0   -- rev48-S6c E8 neck / review highlight
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
  v.gR2WobbleC = 0.25 * p.rhoAir * p.dragCd * math.pi / (2 * p.surfaceTension * p.pinCoat) * 1e-3
  v.gR2AirW = self.airW or vec3()
  v.gR2AirSurface = p.airSurface
  v.gR2Time = self.wobbleT or 0
  v.gR2MotionStretch = p.motionStretch
  v.gR2MinDrawMM = p.minDrawMM
  v.gR2WFRefraction = p.wfRefraction
  v.gR2WFSceneMip = p.wfSceneMip
  v.gR2WFSlopeMip = p.wfSlopeMip
  v.gR2LargeStartPx = p.largeStartPx
  v.gR2LargeFullPx = p.largeFullPx
  v.gR2LargeBlurMip = p.largeBlurMip
  v.gR2LargeWarpPx = p.largeWarpPx
  v.gR2DefocusMode = p.defocusDA and 1 or 0
  self.drawCount = ((self.drawCount or 0) + 1) % 4096
  v.gR2FrameNoise = self.drawCount                -- D-A tap rotation (TAA/DLSS resolves it)
  v.gR2EdgeLoss = p.edgeLoss
  v.gR2LossStart = p.lossStart
  v.gR2LossEnd = p.lossEnd
  v.gR2Glint = p.glint
  v.gR2WFRimRefraction = p.wfRimRefraction
  v.gR2RimMip = p.rimMip
  v.gR2RimSharp = p.rimSharp
  v.gR2SmallFullPx = p.smallFullPx
  v.gR2SmallEndPx = p.smallEndPx
  v.gR2LensK = p.lensK
  v.gR2EnvGround = p.envGround
  v.gR2EnvInterior = p.envInterior
  v.gR2SagK = p.sagK
  v.gR2LensPhys = p.lensPhys
  v.gR2FlatK = p.flatK
  v.gR2FlatStartMM = p.flatStartMM
  v.gR2FlatFullMM = p.flatFullMM
  v.gR2RimMinPx = p.rimMinPx
  v.gR2CspMode = p.cspMode and 1 or 0
  v.gR2LensMode = p.lensMode
  v.gR2WMStepMM, v.gR2WMBlurMip, v.gR2WMNormalK, v.gR2WMCovK = p.wmStepMM, p.wmBlurMip, p.wmNormalK, p.wmCovK
  v.gR2RimBand = p.rimBand
  v.gR2CspRefract = p.cspRefract
  v.gR2RimEnvK = p.rimEnvK
  v.gR2RimCubeMip = p.rimCubeMip
  v.gR2ReflK = p.reflK
  self.camLook = self.camLook or vec3(); self.camSide = self.camSide or vec3(); self.camUp = self.camUp or vec3()
  self.camLook:set(simNow.cameraLook or vec3(0, 0, 1))
  self.camSide:set(simNow.cameraSide or vec3(1, 0, 0))
  self.camUp:set(simNow.cameraUp or vec3(0, 1, 0))
  v.gR2CamLook, v.gR2CamSide, v.gR2CamUp = self.camLook, self.camSide, self.camUp
  v.gR2AccelW = self.accelW or vec3(0, -9.81, 0)
  v.gR2ScreenUp = self.screenUp or vec2(0, -1)
  v.gR2HazeK = p.hazeK
  v.gR2TraceHaze = p.traceHaze
  v.gR2HazeMip = p.hazeMip
  v.gR2VeilColor = self.veil or vec3(0.5, 0.5, 0.5)
  v.gR2VeilMix = p.veilMix
  v.gR2DepthCoverage = p.depthCoverage
  v.gR2FieldSize = self.fieldSize
  v.gR2FilmMaxMM = p.filmMaxMM
  v.gR2TrailMaxMM = p.trailMaxMM
  v.gR2FilmMinMM = p.filmMinMM
  v.gR2FilmFullMM = p.filmFullMM
  v.gR2TrailMinMM = p.trailMinMM
  v.gR2TrailFullMM = p.trailFullMM
  v.gR2FilmRefract = p.filmRefract
  v.gR2FilmAbsorb = p.filmAbsorb
  v.gR2FilmMip = p.filmMip
  v.gR2FilmVeil = p.filmVeil
  v.gR2ScatterM = p.scatterM * p.scatterK
  v.gR2ScatterM0 = p.scatterM0
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
  v.gR2FlyTime = p.flyTime
  v.gR2FlyStretch = p.flyStretch
  v.gR2VMax = p.vMax
  v.gR2VScale = p.vScale
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
  t.textures.txR2WMap = self.WM and self.WM[self.wmi] or false
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
    self.p.rimSharp = DEFAULTS.rimSharp
    self.p.lensPhys = DEFAULTS.lensPhys
    self.p.wfRimRefraction, self.p.rimEnvK, self.p.envInterior, self.p.edgeLoss = DEFAULTS.wfRimRefraction, DEFAULTS.rimEnvK, DEFAULTS.envInterior, DEFAULTS.edgeLoss
    self.p.lensMode, self.p.cspMode = DEFAULTS.lensMode, DEFAULTS.cspMode
    s.apertureMM, s.focusM, s.wfRefraction, s.wfSceneMip = DEFAULTS.apertureMM, DEFAULTS.focusM, DEFAULTS.wfRefraction, DEFAULTS.wfSceneMip
    s.contactDeg, s.wobbleAmp, s.lensK = DEFAULTS.contactDeg, DEFAULTS.wobbleAmp, DEFAULTS.lensK
    s.defocusDA = DEFAULTS.defocusDA
    s.filmRefract, s.filmVeil, s.scatterK = DEFAULTS.filmRefract, DEFAULTS.filmVeil, DEFAULTS.scatterK
  end
  -- rev34 UI: WF lens (main) first, then defocus, then the CSP comparison (kept, not adopted).
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
  self.p.flatK = ui.slider('##rfx2fk2', self.p.flatK, 0, 1, 'Flat top of large drops (r > 1 mm, default 0): %.2f')
  self.p.fragMax = ui.slider('##rfx2fm', self.p.fragMax, 1, 30, 'Small drops per raindrop impact (max): %.0f')
  self.p.clusterK = ui.slider('##rfx2ck', self.p.clusterK, 0, 1, 'Drop groups (clustered births): %.2f')
  self.p.shedK = ui.slider('##rfx2sh', self.p.shedK, 1.0, 5.0, 'Blow-off: air drag > %.1f x pinning')
  self.p.vMax = ui.slider('##rfx2vm', self.p.vMax, 0.005, 0.2, 'Creeping drops, top speed: %.3f m/s')
  ui.text('Helmet airflow (rev47: sphere flow, boundary layer, pressure gradient)')
  self.p.aeroKU = ui.slider('##rfx2ku', self.p.aeroKU, 0.1, 1.2, 'Air speed at the helmet (x car speed, cockpit shielding): %.2f')
  self.p.stagElevDeg = ui.slider('##rfx2se', self.p.stagElevDeg, -40, 40, 'Stagnation point above the visor centre: %.0f deg')
  self.p.buffetDeg = ui.slider('##rfx2bd', self.p.buffetDeg, 0, 25, 'Helmet buffeting (stagnation wander at 250 km/h): %.1f deg')
  self.p.buffetHz = ui.slider('##rfx2bh', self.p.buffetHz, 0.5, 8, 'Buffeting frequency: %.1f Hz')
  ui.text('Car / head jolts (rev47)')
  self.p.neckHz = ui.slider('##rfx2nh', self.p.neckHz, 0.5, 15, 'Neck low-pass of accelerations: %.1f Hz')
  self.p.headAccK = ui.slider('##rfx2hk', self.p.headAccK, 0, 1, 'Head motion (visor transform) acceleration share: %.2f')
  self.p.dropTau = ui.slider('##rfx2dt', self.p.dropTau, 0.0, 0.2, 'Drop inertia (speed follows the force over): %.3f s')
  self.p.slideTau = ui.slider('##rfx2st', self.p.slideTau, 0.0, 0.4, 'Runback inertia (sliding drops): %.3f s')
  self.p.runbackK = ui.slider('##rfx2rk', self.p.runbackK, 0.0005, 0.03, 'Runback speed (x air at the drop top): %.3f')
  self.p.runbackMax = ui.slider('##rfx2rm', self.p.runbackMax, 0.01, 0.5, 'Runback top speed: %.2f m/s')
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
  self.p.flyTime = ui.slider('##rfx2ft', self.p.flyTime, 0.0, 0.2, 'Blown-off drops: flight before they are gone %.2f s')
  self.p.fadeTime = ui.slider('##rfx2fd', self.p.fadeTime, 0.0, 0.3, 'Swept drops fade out over %.2f s')
  self.p.growTime = ui.slider('##rfx2gt', self.p.growTime, 0.0, 0.3, 'New drops grow in over %.2f s')
  ui.separator()
  ui.text('Drop shapes (rev48-S1 shape state; S1 = random birth classes, look lab: Reseed)')
  if ui.checkbox('Shape state (off = rev47 seeded ellipse)', self.p.shpOn) then self.p.shpOn = not self.p.shpOn end
  self.p.shpBendP = ui.slider('##rfx2sb', self.p.shpBendP, 0, 0.5, 'Bent (banana / S) share at birth: %.2f')
  self.p.shpLobeP = ui.slider('##rfx2sl', self.p.shpLobeP, 0, 0.5, 'Lobed (peanut / Y) share at birth: %.2f')
  self.p.shpSagP = ui.slider('##rfx2ss', self.p.shpSagP, 0, 0.5, 'Sagging (r > 0.6 mm, along gravity) share: %.2f')
  self.p.shpRelaxStill = ui.slider('##rfx2sr', self.p.shpRelaxStill, 0.1, 60, 'Pinned shape is held for: %.1f s (r >= 0.3 mm)')
  self.p.shpArrest = ui.slider('##rfx2sa', self.p.shpArrest, 0, 1, 'Splat arrested by pinning (kept spread share): %.2f')
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
  self.p.shpSpreadTau = ui.slider('##rfx2spt', self.p.shpSpreadTau, 0.02, 0.6, 'Splat recoil time constant: %.2f s')
  self.p.shpRecoilT = ui.slider('##rfx2rt', self.p.shpRecoilT, 0, 2, 'Impact splat recoil window: %.2f s (relaxes like a sliding drop)')
  self.p.shpSkidMax = ui.slider('##rfx2sk', self.p.shpSkidMax, 0, 0.15, 'Skid after impact, max: %.3f m/s')
  ui.separator()
  ui.text('Defocus (final step, off by default)')
  s.apertureMM = ui.slider('##rfx2ap', s.apertureMM, 0, 4, 'Aperture %.2f mm (0 = sharp)')
  s.focusM = ui.slider('##rfx2fz', s.focusM, 0.03, 1.0, 'Focus distance %.3f m')
  if ui.checkbox('D-A colour gather (4 taps near the lens; off = D-C analytic)', s.defocusDA) then s.defocusDA = not s.defocusDA end
  if self.cocInfo then ui.text(self.cocInfo) end
  self:offscreenTestUI()
  ui.separator()
  if ui.checkbox('Comparison: CSP methods (not adopted)', self.showCsp == true) then self.showCsp = not self.showCsp end
  if self.showCsp then
    if ui.checkbox('Use CSP cell shading instead of the WF lens', self.p.lensMode == 1) then self.p.lensMode = self.p.lensMode == 1 and 0 or 1 end
    s.lensK = ui.slider('##rfx2lk', s.lensK, 0, 1.5, 'CSP: interior lens strength: %.2f')
    self.p.rimBand = ui.slider('##rfx2rb', self.p.rimBand, 0.05, 0.5, 'CSP: rim width (cubemap zone): %.2f of radius')
    self.p.reflK = ui.slider('##rfx2rf', self.p.reflK, 0, 3, 'CSP: reflection (1.0): %.2f')
    self.p.rimEnvK = ui.slider('##rfx2re', self.p.rimEnvK, 0, 1.5, 'CSP: environment brightness at the rim: %.2f')
    if ui.checkbox('CSP windscreen water map', self.p.cspMode) then self.p.cspMode = not self.p.cspMode end
    if self.p.cspMode then
      self.p.wmBlurMip = ui.slider('##rfx2wbm', self.p.wmBlurMip, 0, 4, 'Water map normal blur: %.2f')
      self.p.wmNormalK = ui.slider('##rfx2wnk', self.p.wmNormalK, 0.5, 6, 'Water map normal gain (2.2): %.2f')
      self.p.wmDecay = ui.slider('##rfx2wdc', self.p.wmDecay, 0, 6, 'Water traces fade: %.2f /s')
      self.p.wmScale = ui.slider('##rfx2wsc', self.p.wmScale, 0.2, 1.5, 'Water drop size scale: %.2f')
    end
  end
  ui.separator()
  s.hazeK = ui.slider('##rfx2haze', s.hazeK, 0, 2, 'Haze strength: %.2f')
  s.substeps = ui.slider('##rfx2sub', s.substeps, 1, 4, 'Min substeps: %.0f (auto up to 4)', true)
  if ui.checkbox('Invert exposure side (auto: side facing away from the eye)', s.invertSide) then s.invertSide = not s.invertSide end
  s.debug = ui.slider('##rfx2dbg', s.debug, 0, 9, 'Debug: 1 water 2 exposure 3 refr.src 4 physics 5 film 6 defocus 7 lens (R rim, G env, B TIR/mip) 8 coverage 9 lens direction (R looks down, G up): %.0f', true)
  self:filmUI()
  self:physicsUI()
  local st = self.stats
  ui.text(string.format('Rain %.1f mm/h  mean D %.2f mm  rel. speed %.1f m/s',
    st.rateMMh or 0, st.meanDiamMM or 0, st.speedRel or 0))
  ui.text(string.format('Impacts %.0f /m2/s  splash K %.0f  resolved %.2f in %.2f mm fragments  micro %.3f /s',
    st.impactRate or 0, st.splashK or 0, st.stickFrac or 0, st.fragDiamMM or 0, st.microRate or 0))
  if self.sourceErr then ui.text('Refraction source: ' .. self.sourceErr) end
  ui.text('GPU/CPU cost: Render Stats -> "RainFX2 sim" / "RainFX2 draw".')
end

-- rev12 evaluation metrics: GPU block reduction (32x8) + async readback at 2 Hz, optional CSV.
local METRICS_HEADER = 'clock,weatherType,rainIntensity,rainWetness,rainWater,windKmh,carKmh,rainFluxMMs,spray,sprayCars,nearestM,filmRate,filmEqMM,filmCover,dropCover,haze,substeps,apertureMM,focusM,defocusDA,contactDeg,wfRefraction,wfSceneMip,filmRefract,filmVeil,scatterK,drops,sizeP50MM,p90p50,p99p50,binRatio,fragA,fragHi,turbK,flatK,dropDepthUM,residenceS\n'
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
    local c, total = {}, 0
    for x = 0, 9 do
      local n = 0
      for y = 0, 15 do
        data:colorTo(tmp, x, y)
        n = n + math.floor(tmp.rgb.r * 255 + 0.5) * 256 + math.floor(tmp.rgb.g * 255 + 0.5)
      end
      c[x + 1], total = n, total + n
    end
    data:dispose()
    local h = { counts = c, total = total }
    local function pct(q)
      if total <= 0 then return 0 end
      local target, cum = q * total, 0
      for k = 1, 10 do
        if cum + c[k] >= target and c[k] > 0 then
          return b0 * 1.5 ^ (k - 1 + (target - cum) / c[k])
        end
        cum = cum + c[k]
      end
      return b0 * 1.5 ^ 10
    end
    h.p50, h.p90, h.p99 = pct(0.5), pct(0.9), pct(0.99)
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
  local line = string.format('%.2f,%d,%.4f,%.4f,%.4f,%.1f,%.1f,%.4f,%.3f,%d,%.1f,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%.2f,%.2f,%d,%.0f,%.2f,%.1f,%.2f,%.2f,%.2f,%d,%.3f,%.2f,%.2f,%.3f,%.2f,%.2f,%.2f,%.2f,%.2f,%.3f\n',
    os.clock(), s.weatherType or -1, s.rainIntensity or 0, s.rainWetness or 0, s.rainWater or 0,
    s.windSpeedKmh or 0, (st.carSpeed or 0) * 3.6, st.fluxMMs or 0, st.spray or 0, si.cars or 0, si.nearestM or -1,
    st.filmRate or 0, d.filmEqMM or 0, m.film, m.drops, m.haze, self.p.substeps or 0,
    self.store.apertureMM, self.store.focusM, self.store.defocusDA and 1 or 0, self.store.contactDeg,
    self.store.wfRefraction, self.store.wfSceneMip,
    self.store.filmRefract, self.store.filmVeil, self.store.scatterK,
    h.total, h.p50, h.p90 / p50, h.p99 / p50, h.ratio, self.p.fragA, self.p.fragHi, self.p.turbK, self.p.flatK, h.depthUM or 0, h.residence or 0)
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
    ui.text(string.format('Film cover %.1f %%  drop cover %.1f %%  haze %.3f', m.film * 100, m.drops * 100, m.haze))
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
    ui.text(string.format('Spray %.2f (wet %.2f, %d cars, nearest %.0f m)  film supply %.3f mm/s',
      st.spray or 0, si.wet or 0, si.cars or 0, si.nearestM or -1, st.filmRate or 0))
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
  ui.text('Debug 4: blue pinned | green <0.1 | yellow <0.3 | orange <0.6 | red >=0.6 m/s | magenta step-limited | grey trace')
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
  ui.text(string.format('Speed (coat, forces aligned): r0.5 %.2f  r1 %.2f  r2 %.2f m/s  | cap %.1f, shed %.1f',
    d.v05, d.v10, d.v20, p.vMax, p.vShed))
  -- rev40 stagnation turbulence: peak tangential gust and the radius it can depin on its own
  -- (drag 0.25 rho Cd pi r^2 u^2 = pinning 2 gamma r dcos, mean heterogeneity, no gravity)
  local gust = p.turbK * p.airSurface * (i.airSpeed or 0)
  local rcG = gust > 0.1 and 2 * p.surfaceTension * p.pinCoat / (0.25 * p.rhoAir * p.dragCd * math.pi * gust * gust) * 1000 or math.huge
  ui.text(string.format('Centre gusts up to %.1f m/s tangential -> depin alone from r = %s (coat)', gust, rc(rcG)))
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
  for _, name in ipairs({ 'cells', 'field', 'trail', 'visor', 'source', 'claim', 'merge', 'seed', 'metrics', 'wmap', 'sizes' }) do
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
      wmap = common .. '\n' .. src.wmap,
      visor = src.visor,
      source = src.source,
      visorDepth = '#define R2_DEPTH_ONLY 1\n' .. src.visor,
    }
  end
  return self
end
