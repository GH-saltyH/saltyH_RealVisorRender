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
  stickSlow = 0.8, stickFast = 0.4, microK = 7.0,
  exposure = 0.5, exposureFloor = 0.0, normalSign = 1.0,
  -- drop physics: rainfx2/physics.lua (P.DEFAULTS, merged below)
  ladderMinMM = 0.3, ladderMaxMM = 2.2,   -- physics test drop ladder
  -- field
  microEvap = 0.05, microShear = 0.02, microCollect = 0.9,
  -- sheetDrain rev14 0.5 -> 0.1: drainage dominated the film balance (eq ~ supply), now edge
  -- outflow does (eq ~ supply^(1/2..1/3)), compressing light..heavy into the cover window.
  traceDecay = 0.6, traceAmount = 0.6, sweepWidth = 0.9, sheetDrain = 0.1,
  -- drop shape (CSP rain-map model, rev4): contour noise, fixed-width rim bevel, weak dome
  contourAmp = 0.25, bevelMM = 1.5, aspect = 0.5, maxHeightMM = 1.2, domeK = 0.25, slopeMax = 1.5,
  -- optics (rev5): pupil defocus + physical deflection (n-1)*slope, housing-free source
  apertureMM = 1.2,        -- entrance pupil of the reference camera = blur disc on the visor
  refraction = 1.0,        -- gain on the physical deflection
  dropVeil = 0.2,          -- rev16: drop colour toward the veil (reference B/C soft bright discs)
  housingM = 0.20,         -- frame pixels closer than this (linear m) are helmet housing
  sourceScale = 0.5,       -- refraction source resolution (fraction of the frame)
  dropMip = 0.5, edgeLoss = 0.20, lossStart = 1.00, lossEnd = 1.60,   -- rev16 edgeLoss 0.5 -> 0.2
  glint = 0.45, toneMin = 0.85, toneMax = 1.45, toneFloor = 0.25,     -- rev16 toneMin 0.55 -> 0.85
  -- water film optics (rev11)
  filmMinMM = 0.05, filmFullMM = 0.15, filmRefract = 12.0, filmAbsorb = 0.8, filmMip = 4.5, filmVeil = 0.25,
  -- forward scattering veil of the VISOR SURFACE only (rev17, docs/RAINFX_V2_EVAL.md section 11):
  -- airborne spray/mist is CSP's own particle domain and is not reproduced here (scatterSpray 0).
  scatterK = 1.0, scatterM = 0.35, scatterM0 = 0.04, scatterFilm = 0.3, scatterSpray = 0.0,
  scatterMax = 0.35, scatterMip = 6.5, scatterSky = 0.3, scatterGain = 1.1,
  filmK = 1.0, sprayK = 1.0,
  hazeK = 0.8, traceHaze = 0.15, hazeMip = 4.0, veilMix = 0.25, veilBright = 1.0,
  depthCoverage = 0.35, debug = 0, debugBright = 1.0,
}

-- Persisted user controls (subset of DEFAULTS + enable switch).
local STORED = { enabled = true, exposure = DEFAULTS.exposure, refractK = DEFAULTS.refraction,
  apertureMM = DEFAULTS.apertureMM, hazeK = DEFAULTS.hazeK, substeps = DEFAULTS.substeps, freezeRain = false, windK = 1.0, metrics = false,
  filmK = DEFAULTS.filmK, sprayK = DEFAULTS.sprayK, filmRefract = DEFAULTS.filmRefract, filmVeil = DEFAULTS.filmVeil,
  scatterK = DEFAULTS.scatterK,
  contourAmp = DEFAULTS.contourAmp, bevelMM = DEFAULTS.bevelMM,
  debug = DEFAULTS.debug, invertSide = false }


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
  v.gR2MicroRate = self.store.freezeRain and 0 or (st.microRate or 0)
  v.gR2Exposure = p.exposure
  v.gR2ExposureFloor = p.exposureFloor
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
  return v
end

local function newPass(self, shader)
  local root = self.ctx.surface.root
  return {
    async = true,
    blendMode = render.BlendMode.Opaque,
    textures = { txR2State = false, txR2Field = false, txR2Claim = false,
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
  self.S = { canvas(p.cellsU, p.cellsV, 1, f32, 'RainFX2 cells A'), canvas(p.cellsU, p.cellsV, 1, f32, 'RainFX2 cells B') }
  self.C = canvas(p.cellsU, p.cellsV, 1, render.TextureFormat.R16G16B16A16.Float, 'RainFX2 claims')
  self.F = { canvas(p.fieldU, p.fieldV, 1, u16, 'RainFX2 field A'), canvas(p.fieldU, p.fieldV, 1, u16, 'RainFX2 field B') }
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
  self.passClaim = newPass(self, self.src.claim)
  self.passMetrics = newPass(self, self.src.metrics)
  self.Mc = canvas(32, 8, 1, render.TextureFormat.R8G8B8A8.UNorm, 'RainFX2 metrics')
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
function R2:updateInputs(sim)
  self.objToWorld = self.target:getWorldTransformationRaw():clone()
  local inp = self.physics.inputs(sim, self.p, self.inp)
  self.inp = inp
  local accel, air, rainVel, speedRel = inp.accelW, inp.airW, inp.rainVel, inp.speedRel
  self.accelW:set(accel.x, accel.y, accel.z)
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
  st.filmRate = (rainFilm + sprayFilm) * p.filmK
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
  p.exposure, p.refraction, p.apertureMM, p.hazeK, p.debug = s.exposure, s.refractK, s.apertureMM, s.hazeK, s.debug
  p.contourAmp, p.bevelMM = s.contourAmp, s.bevelMM
  local userSub = math.max(1, math.min(4, math.floor(s.substeps + 0.5)))
  p.filmK, p.sprayK, p.filmRefract, p.filmVeil = s.filmK, s.sprayK, s.filmRefract, s.filmVeil
  p.scatterK = s.scatterK
  p.windK = s.windK
  p.normalSign = s.invertSide and -1 or 1
  if not self.ctx.surface:validate() then self.status = self.ctx.surface.status or 'geometry not verified'; return end
  if not self:ensureResources() or not self:ensureMesh() then return end
  local dt = sim.dt or 0
  if dt <= 0 then self.status = 'paused'; return end
  dt = math.min(dt, 1 / 20) * (self.timeScale or 1)   -- rev9: slow motion for physics review
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
    if run(self.S[3 - self.si], ps) then self.si = 3 - self.si end
  end
  -- rev13: coalescence runs FIRST (on last frame's state). The merge may leave a drop
  -- centre off its cell (centroid); the P1 substeps that follow relocate it, so the visor
  -- never sees off-cell drops (rev12: drops cut by the 5x5 draw window along cell edges).
  if p.coalesceK > 0 then
    local pk, pm = self.passClaim, self.passMerge
    pk.textures.txR2State = self.S[self.si]
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
    sceneValues(self, pc.values)
    if not run(self.S[3 - self.si], pc) then self.status = 'compiling cells'; return end
    self.si = 3 - self.si
  end
  do
    local pf = self.passField
    pf.textures.txR2State = self.S[self.si]
    pf.textures.txR2Field = self.F[self.fi]
    sceneValues(self, pf.values)
    pf.values.gR2Dt = self.frameDt                 -- field integrates the whole frame
    if run(self.F[3 - self.fi], pf) then self.fi = 3 - self.fi end
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
      textures = { txR2State = false, txR2Field = false, txR2Scene = false, txR2Mask = self.ctx.maskPath },
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
  v.gR2ContourAmp = p.contourAmp
  v.gR2BevelMM = p.bevelMM
  v.gR2Aspect = p.aspect
  v.gR2MaxHeightMM = p.maxHeightMM
  v.gR2DomeK = p.domeK
  v.gR2SlopeMax = p.slopeMax
  v.gR2Refraction = p.refraction
  v.gR2DropMip = p.dropMip
  v.gR2EdgeLoss = p.edgeLoss
  v.gR2DropVeil = p.dropVeil
  v.gR2LossStart = p.lossStart
  v.gR2LossEnd = p.lossEnd
  v.gR2Glint = p.glint
  v.gR2ToneMin = p.toneMin
  v.gR2ToneMax = p.toneMax
  v.gR2ToneFloor = p.toneFloor
  v.gR2ScreenUp = self.screenUp or vec2(0, -1)
  v.gR2HazeK = p.hazeK
  v.gR2TraceHaze = p.traceHaze
  v.gR2HazeMip = p.hazeMip
  v.gR2VeilColor = self.veil or vec3(0.5, 0.5, 0.5)
  v.gR2VeilMix = p.veilMix
  v.gR2DepthCoverage = p.depthCoverage
  v.gR2FieldSize = self.fieldSize
  v.gR2FilmMaxMM = p.filmMaxMM
  v.gR2FilmMinMM = p.filmMinMM
  v.gR2FilmFullMM = p.filmFullMM
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
  v.gR2VMax = p.vMax
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
  t.textures.txR2State = self.S[self.si]
  t.textures.txR2Field = self.F[self.fi]
  render.setCullMode(render.CullMode.None)
  render.setBlendMode(render.BlendMode.AlphaBlend)
  render.setDepthMode(depth and render.DepthMode.Normal or render.DepthMode.ReadOnly)
  self.mesh:setVisible(true, false)
  local ok, res = pcall(render.mesh, t)
  self.mesh:setVisible(false, false)
  render.setDepthMode(render.DepthMode.ReadOnly)
  if not ok then self.err = 'Draw: ' .. tostring(res); return false end
  if res ~= false then self[memo] = viewKey end
  return res ~= false
end

function R2:ui()
  local s = self.store
  ui.text('RainFX v2 (cell-gather): ' .. (self.err or self.status))
  if ui.checkbox('Enable RainFX v2 (turns legacy RainFX off)', s.enabled) then s.enabled = not s.enabled end
  if not s.enabled then return end
  s.exposure = ui.slider('##rfx2exp', s.exposure, 0, 1, 'Rain exposure: %.2f')
  if ui.button('Reset look to defaults (aperture, refraction, contour, bevel, film, scatter)') then
    s.apertureMM, s.refractK, s.contourAmp, s.bevelMM = DEFAULTS.apertureMM, DEFAULTS.refraction, DEFAULTS.contourAmp, DEFAULTS.bevelMM
    s.filmRefract, s.filmVeil, s.scatterK = DEFAULTS.filmRefract, DEFAULTS.filmVeil, DEFAULTS.scatterK
  end
  s.apertureMM = ui.slider('##rfx2ap', s.apertureMM, 0, 4, 'Defocus: camera aperture %.2f mm (0 = sharp)')
  s.refractK = ui.slider('##rfx2ref', s.refractK, 0, 2, 'Refraction: %.2f x physical (n-1)')
  s.contourAmp = ui.slider('##rfx2cont', s.contourAmp, 0, 0.4, 'Contour irregularity: %.2f')
  s.bevelMM = ui.slider('##rfx2bev', s.bevelMM, 0.05, 1.5, 'Rim bevel width: %.2f mm')
  s.hazeK = ui.slider('##rfx2haze', s.hazeK, 0, 2, 'Haze strength: %.2f')
  s.substeps = ui.slider('##rfx2sub', s.substeps, 1, 4, 'Min substeps: %.0f (auto up to 4)', true)
  if ui.checkbox('Invert exposure side (auto: side facing away from the eye)', s.invertSide) then s.invertSide = not s.invertSide end
  s.debug = ui.slider('##rfx2dbg', s.debug, 0, 5, 'Debug: 1 water, 2 exposure, 3 refr. source, 4 physics, 5 film: %.0f', true)
  self:filmUI()
  self:physicsUI()
  local st = self.stats
  ui.text(string.format('Rain %.1f mm/h  mean D %.2f mm  rel. speed %.1f m/s',
    st.rateMMh or 0, st.meanDiamMM or 0, st.speedRel or 0))
  ui.text(string.format('Impacts %.0f /m2/s  stick %.2f  micro %.3f /s',
    st.impactRate or 0, st.stickFrac or 0, st.microRate or 0))
  if self.sourceErr then ui.text('Refraction source: ' .. self.sourceErr) end
  ui.text('GPU/CPU cost: Render Stats -> "RainFX2 sim" / "RainFX2 draw".')
end

-- rev12 evaluation metrics: GPU block reduction (32x8) + async readback at 2 Hz, optional CSV.
local METRICS_HEADER = 'clock,weatherType,rainIntensity,rainWetness,rainWater,windKmh,carKmh,rainFluxMMs,spray,sprayCars,nearestM,filmRate,filmEqMM,filmCover,dropCover,haze,substeps,apertureMM,refractK,contourAmp,bevelMM,filmRefract,filmVeil,scatterK\n'
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
    self.metrics = m
    if self.recording then self:metricsWrite(sim) end
  end)
end

function R2:metricsWrite(sim)
  local s, st, si, m, d = ac.getSim(), self.stats, self.sprayInfo or {}, self.metrics, self.diag or {}
  local line = string.format('%.2f,%d,%.4f,%.4f,%.4f,%.1f,%.1f,%.4f,%.3f,%d,%.1f,%.4f,%.4f,%.4f,%.4f,%.4f,%d,%.2f,%.2f,%.2f,%.2f,%.1f,%.2f,%.2f\n',
    os.clock(), s.weatherType or -1, s.rainIntensity or 0, s.rainWetness or 0, s.rainWater or 0,
    s.windSpeedKmh or 0, (st.carSpeed or 0) * 3.6, st.fluxMMs or 0, st.spray or 0, si.cars or 0, si.nearestM or -1,
    st.filmRate or 0, d.filmEqMM or 0, m.film, m.drops, m.haze, self.p.substeps or 0,
    self.store.apertureMM, self.store.refractK, self.store.contourAmp, self.store.bevelMM,
    self.store.filmRefract, self.store.filmVeil, self.store.scatterK)
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
  if self.recording then ui.text('Recording: ' .. tostring(self.recordPath)) end
  if self.metricsErr then ui.text('Metrics: ' .. self.metricsErr) end
end

-- Water film / spray panel (rev11).
function R2:filmUI()
  local s, st, d, si = self.store, self.stats, self.diag, self.sprayInfo
  ui.separator()
  ui.text('Water film (A regime) / spray')
  s.filmK = ui.slider('##rfx2fk', s.filmK, 0, 5, 'Film supply gain: %.2f')
  s.sprayK = ui.slider('##rfx2sk', s.sprayK, 0, 5, 'Spray gain: %.2f')
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
  ui.text(string.format('Car %.1f m/s  wind %.1f m/s (sim windSpeedKmh %.1f m/s)  air rel. %.1f m/s  accel %.2f g',
    i.carSpeed, i.windSpeed, i.windSpeedSim, i.airSpeed, i.accelG))
  local function rc(v) return v == math.huge and 'never' or string.format('%.2f mm', v) end
  ui.text(string.format('Slides by gravity from r = %s (coat), %s (glass), keeps sliding from %s; with air (coat) %s',
    rc(d.rcGravCoat), rc(d.rcGravGlass), rc(d.rcGravCoatKin), rc(d.rcAllCoat)))
  ui.text(string.format('Speed (coat, forces aligned): r0.5 %.2f  r1 %.2f  r2 %.2f m/s  | cap %.1f, shed %.1f',
    d.v05, d.v10, d.v20, p.vMax, p.vShed))
  ui.text(string.format('Substeps %d -> step limit %.2f m/s (faster drops are speed-limited)',
    p.substeps or 0, d.vGather))
end

function R2:dispose()
  for _, list in ipairs({ self.S or {}, self.F or {} }) do
    for _, c in ipairs(list) do c:dispose() end
  end
  if self.mesh then self.mesh:dispose() end
  if self.source then self.source:dispose() end
  if self.C then self.C:dispose() end
  if self.Mc then self.Mc:dispose(); self.Mc = nil end
  self.source, self.sceneTex, self.C = nil, nil, nil
  self.S, self.F, self.mesh, self.ready, self.opticsReady = nil, nil, nil, false, false
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
  for _, name in ipairs({ 'cells', 'field', 'visor', 'source', 'claim', 'merge', 'seed', 'metrics' }) do
    src[name] = readFile(dir .. name .. '.hlsl')
    if not src[name] or not common then
      self.err = 'Missing shader: rainfx2/shaders/' .. name .. '.hlsl'
    end
  end
  if not self.err then
    self.src = {
      cells = common .. '\n' .. src.cells,
      field = common .. '\n' .. src.field,
      claim = common .. '\n' .. src.claim,
      merge = common .. '\n' .. src.merge,
      seed = common .. '\n' .. src.seed,
      metrics = common .. '\n' .. src.metrics,
      visor = src.visor,
      source = src.source,
      visorDepth = '#define R2_DEPTH_ONLY 1\n' .. src.visor,
    }
  end
  return self
end
