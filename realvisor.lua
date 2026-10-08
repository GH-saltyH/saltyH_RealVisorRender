------------------------------------------------------------
-- Real Visor Overlay
local strDisplayName = 'Real Visor Overlay'
local strAppNameInternal = 'RealVisor'
-- Version: 0.6.0
local strVersion= '0.6.0'
local appNameDebug = '[RealVisor_v' .. strVersion .. ']'
--
-- Author: saltyH
-- CSP Target: 0.3.0-preview477+
--
-- Tested on AC 1.16 / CSP 0.3.0-preview542
--
-- Focus:
-- v0.6.0 Custom Shader 
--  RainFX, RenderPass Improvements (Newer upscaler compatible)
------------------------------------------------------------

------------------------------------------------------------
-- Persistent settings
------------------------------------------------------------

local scriptSettings = ac.INIConfig.scriptSettings()


--------------------------------------------------------
-- Path
--------------------------------------------------------
local appFolder = 
    ac.dirname()
    -- ac.getFolder(ac.FolderID.ACApps) .. '/lua/realvisor/'


    --------------------------------------------------------
    -- Path: Textures
    --------------------------------------------------------
    
    local textureRainSurfaceNormal = appFolder .. '/texture/GLASS_EXT_RAINFX_surfaceNormal_objectSpace_2K.dds'
    local textureRainBoundaryMask = appFolder .. '/texture/GLASS_EXT_RAINFX_boundaryMask_2K.dds'
    local testtextureRainSurfaceNormal = appFolder .. '/texture/test_objectSpace.dds'

    
    --------------------------------------------------------
    -- Dynamic mesh renderer experiment
    --------------------------------------------------------
    
    local rainDynamicMeshTest = nil
    local rainDynamicMeshTestNode = nil
    local rainDynamicMeshTestVertices = nil
    local rainDynamicMeshTestIndices = nil
    local rainDynamicMeshTestInitialized = false

    -- Stage 2: actual visor surface extraction / UV lookup test.
    local RAIN_DYNAMIC_SURFACE_MESH_NAME = 'RealVisor_DynamicSurfaceTest'
    local rainDynamicSurfaceVertices = nil
    local rainDynamicSurfaceIndices = nil
    local rainDynamicSurfaceLookup = nil
    local rainDynamicSurfaceMesh = nil
    local rainDynamicSurfaceParent = nil
    local rainDynamicSurfaceInitialized = false
    local rainDynamicSurfaceMeshVertices = nil
    local rainDynamicSurfaceMeshCount = 0
    -- Script-global table avoids the LuaJIT limit on chunk-level locals.
    rainDynamicSceneCopyState = {}
    -- Stage 3: persistent GPU state -> async CPU readback -> dynamic vertices.
    local rainDynamicStateReadbackSlots = {}
    local rainDynamicStateReadbackCount = 0
    local rainDynamicStateReadbackNextSlot = 1
    local rainDynamicStateReadbackReady = false
    local rainDynamicStateReadbackErrorLogged = false
    local rainDynamicStateFirstApplyLogged = false
    local rainDynamicRootCallbackLogged = false
    local rainDynamicManualPreDrawLogged = false
    local rainDynamicManualDrawLogged = false
    local rainDynamicStateLatestAcceptedRequestFrame = -1

    -- Stage 3 cadence diagnostics. Frame counters only; no per-frame logging.
    local rainDynamicStateRequestFrame = -1
    local rainDynamicStateLastCallbackFrame = -1
    local rainDynamicStateLastApplyFrame = -1
    local rainDynamicStateCallbackCount = 0
    local rainDynamicStateCallbackLatencySum = 0
    local rainDynamicStateCallbackLatencyMin = math.huge
    local rainDynamicStateCallbackLatencyMax = 0
    local rainDynamicStateCallbackIntervalSum = 0
    local rainDynamicStateCallbackIntervalMin = math.huge
    local rainDynamicStateCallbackIntervalMax = 0
    local rainDynamicStateApplyCount = 0
    local rainDynamicStateApplyIntervalSum = 0
    local rainDynamicStateApplyIntervalMin = math.huge
    local rainDynamicStateApplyIntervalMax = 0

    local rainDynamicStateU = {}
    local rainDynamicStateV = {}
    local rainDynamicStateVelocityU = {}
    local rainDynamicStateVelocityV = {}
    local rainDynamicStateRadius = {}
    local rainDynamicStateAlive = {}
    local rainDynamicStateHasSnapshot = false
    local rainDynamicStateSnapshotTime = 0.0
    local rainDynamicStateRenderClock = 0.0
    local rainDynamicStateRenderClockFrame = -1

    
    --------------------------------------------------------
    -- Path: Settings
    --------------------------------------------------------
    
    local settingsFile = 
    appFolder .. '/settings.ini'

    local MESH_VISIBILITY_SECTION = 'MESH_VISIBILITY'

    -- Forward declaration: profile persistence and KN5 setup share the same
    -- mesh descriptors defined in the material-editor section below.
    local MATERIAL_EDITORS
    
    
    --------------------------------------------------------
    -- Path: Shaders
    --------------------------------------------------------
    
    local shaders = {

        {
            ID = 'RAINFXVISOR',
            PATH = appFolder .. '/shaders/rainVisorScreen.hlsl',
            LOADED = false,
            HLSL = nil,
        },

        {
            ID = 'RAINFXDYNAMICDROP',
            PATH = appFolder .. '/shaders/rainVisorDynamicDrop.hlsl',
            LOADED = false,
            HLSL = nil,
        },


        {
            ID = 'RAINFXVISORLAYER',
            PATH = appFolder .. '/shaders/rainVisorLayer.hlsl',
            LOADED = false,
            HLSL = nil,
        },
    }
        

local RAIN_FORCE_GRAVITY = 1
local RAIN_FORCE_INERTIA = 2
local RAIN_FORCE_AIRFLOW = 4

local cfg = scriptSettings:mapConfig({

    --------------------------------------------------------
    -- Active profile
    --------------------------------------------------------

    GENERAL = {
        ACTIVE = 1,
        ENABLE = 1,
    },


    --------------------------------------------------------
    -- Profile 1
    --  Real World Aspect        -- F1 TV Visor Cam
    --  46 Inch 16:9             -- 46 Inch 16:9    
    --  FOV (vertical) 51.03°,   -- FOV 39°
    --  Eye distance 60cm        -- 60cm
    --------------------------------------------------------

    PROFILE_1 = {
        PITCH = 0.0000,
        YAW   = 0.0000,
        ROLL  = 0.0000,

        OFFSET_X = 0.0000,
        OFFSET_Y = 0.0000,
        OFFSET_Z = -0.1033,
        
        SCALE = 1.0000,

        NEARCLIP = 0.0181,
        
        ENABLE_MOTION   = 1,
        
        MOTION_GAIN_X   = 0.00009,
        MOTION_GAIN_Y   = 0.00006,
        MOTION_GAIN_Z   = 0.00007,
        
        MOTION_SMOOTHING = 30.0,
        MOTION_SHARPNESS = 1.11,
        
        MOTION_LIMIT_X  = 0.025,
        MOTION_LIMIT_Y  = 0.020,
        MOTION_LIMIT_Z  = 0.020,        

        HIDE_DRIVER_HELMET = 1,
    },


    --------------------------------------------------------
    -- Profile 2
    --  F1 TV Visor Cam
    --  46 Inch 16:9    
    --  FOV 39°
    --  60cm    
    --------------------------------------------------------

    PROFILE_2 = {
        PITCH = -0.2200,
        YAW   = -19.2700,
        ROLL  = -6.3800,

        OFFSET_X = 0.1089,
        OFFSET_Y = -0.0040,
        OFFSET_Z = -0.0594,

        SCALE = 1.0000,

        NEARCLIP = 0.0081,

        ENABLE_MOTION   = 1,
        
        MOTION_GAIN_X   = 0.00009,
        MOTION_GAIN_Y   = 0.00006,
        MOTION_GAIN_Z   = 0.00007,
        
        MOTION_SMOOTHING = 30.0,
        MOTION_SHARPNESS = 1.11,
        
        MOTION_LIMIT_X  = 0.025,
        MOTION_LIMIT_Y  = 0.020,
        MOTION_LIMIT_Z  = 0.020,

        HIDE_DRIVER_HELMET = 1,
    },
    
    
    --------------------------------------------------------
    -- Runtime / development settings
    --
    -- These are intentionally NOT profile-dependent.
    --------------------------------------------------------
    
    RUNTIME = {
        ENABLED = true,
        
        MODEL_PATH =
        --'visors/visor_lando_2025Champion_maxquality.kn5',
        -- 'visors/visor_lando_2025Champion_maxquality_full.kn5',      -- it contains every version (big size)
        'visors/visor_lando_2025Champion_maxquality_diet.kn5',      -- compact version for overlayProbe
        

        --------------------------------------------------------
        -- Visor Model Debug Controls
        --------------------------------------------------------
        
        DEBUG_DELTAPOS  = false,
        DEBUG_ROTATION  = false,
        DEBUG_HEAD      = false,
        DEBUG_TIMER     = 0.10,
        
        
        --------------------------------------------------------
        -- G-Force Motion
        --------------------------------------------------------

        DEBUG_MOTION    = false,
        
        
        --------------------------------------------------------
        -- Material Parameter Prototype
        --------------------------------------------------------
        
        -- Experimental: some 'bool' jstyle shader parameters may actually need
        -- to be sent as 0/1 floats rather than Lua true/false to take effect.
        -- Toggle this in the material editor window while testing
        
        MATERIAL_BOOL_AS_NUMBER = true,
        

        --------------------------------------------------------
        -- Neck / Head Debug Controls
        --------------------------------------------------------

        HIDE_DRIVER_HELMET_SCALE = mat4x4.scaling(
                                        vec3.new(0.00001)
                                    ),
        SHOW_DRIVER_HELMET_SCALE = mat4x4.scaling(
                                        vec3.new(1.00000)
                                    ),
        NECK_FOLLOW_ENABLED = true,
       

        ------------------------------------------------------------
        -- v0.6.0 Rain / Visor Water
        ------------------------------------------------------------

        RAIN_ENABLED = true,

        ------------------------------------------------------------
        -- Unified external-force source controls (Phase A)
        ------------------------------------------------------------
        RAIN_FORCE_GRAVITY_ENABLED = true,
        RAIN_FORCE_INERTIA_ENABLED = true,
        RAIN_FORCE_AIRFLOW_ENABLED = true,
        -- Add track wind (sim.windVelocityKmh, axes per SMEAR_WIND_MODE) to
        -- the airflow the drops feel.
        RAIN_FORCE_AIRFLOW_INCLUDE_WIND = true,
        -- false: original signed tangent airflow, true: downward visor
        -- runoff with the original left/right tangent component.
        RAIN_AIRFLOW_DOWNWARD_MODE = true,
        RAIN_AIRFLOW_DOWNWARD_GAIN = 2.58,

        -- All external accelerations enter the GPU in SI m/s^2 and
        -- share this compact surface-force conversion.
        -- This preserves the previously validated gravity calibration.
        RAIN_PHYSICS_ACCEL_SCALE = 0.03567788,
        RAIN_FORCE_GRAVITY_GAIN = 1.0,
        RAIN_FORCE_INERTIA_GAIN = 1.0,
        RAIN_FORCE_AIRFLOW_GAIN = 1.0,

        -- Air model constants (SI).
        RAIN_AIR_DENSITY = 1.20,
        RAIN_AIR_DRAG_COEFF = 0.47,

        -- Drop dynamics
        -- Acceleration after surface adhesion is exceeded.
        RAIN_FLOW_ACCELERATION = 0.1296,    -- Flow acceleration

        -- Post-adhesion flow intensity multiplier. Default 1.0 preserves
        -- the current physical calibration; later tuning must still respect
        -- the absolute physical max-speed clamp.
        RAIN_FLOW_SPEED_SCALE = 1.0,    -- Flow speed scale

        -- Linear air/viscous drag coefficient.
        RAIN_FLOW_DRAG = 4.84,           -- Flow drag when pinned Default 7.00     *Fine Tuned

        -- Adhesion threshold range. A drop remains attached while the
        -- effective tangential force is below its own threshold.
        RAIN_ADHESION_MIN = 0.285,       -- Default 0.65   *Fine Tuned
        RAIN_ADHESION_MAX = 0.305,       -- Default 2.20   *Fine Tuned

        ------------------------------------------------------------
        -- v0.6.0 RainFX persistent GPU state
        ------------------------------------------------------------

        -- Number of persistent droplet state texels.
        -- One texel represents one persistent droplet.
        RAIN_GPU_STATE_COUNT = 4096,

        -- Persistent state:
        -- 0 = disabled
        -- 1 = initialize only
        -- 3 = canonical persistent RainFX physics + weather-driven lifecycle
        -- 4 = canonical persistent physics + 3x3 physical-size diagnostic
        -- 6 = canonical persistent physics + boundary lifecycle
        -- 7 = single persistent droplet position probe
        -- 10 = canonical physical 9-drop validation
        RAIN_GPU_STATE_MODE = 3,

        -- Signed visor-UV position used by the single-drop probe.
        RAIN_GPU_STATE_SINGLE_DROP_X = 0.500,
        RAIN_GPU_STATE_SINGLE_DROP_Y = -0.500,

        -- Persistent lifecycle: explicit surface exit/death/respawn. No edge wrapping.
        RAIN_GPU_STATE_LIFECYCLE = true,
        RAIN_GPU_STATE_LIFECYCLE_LOG = true,
        -- -1: live CSP rain intensity. 0..1: deterministic test weather.
        RAIN_GPU_STATE_RAIN_OVERRIDE = -1.0,
        -- At r=0.03 / 0.08 / 0.50, approximate eligible fractions are
        -- 0.21 / 0.30 / 0.69 before the optional density multiplier.
        RAIN_GPU_STATE_DENSITY_SCALE = 0.5,
        RAIN_GPU_STATE_FREEZE_DEBUG = false, -- performance diagnosis: keep existing state, skip physics passes
        RAIN_GPU_PRELAID_SITES = false, -- R1.2: bake valid birth sites once on the GPU
        RAIN_GPU_PRELAID_DEBUG = false,
        RAIN_GPU_STATE_CAPACITY_RAMP_POWER = 1.0,
        -- Live birth-size keyframes in mm; a slot samples these at birth.
        RAIN_GPU_SIZE_MIN_DRY = 0.34,                   -- Default 0.35mm
        RAIN_GPU_SIZE_MAX_DRY = 0.41,                   -- Default 1.40mm
        RAIN_GPU_SIZE_MIN_LIGHT = 0.35,                 -- Default 0.35mm
        RAIN_GPU_SIZE_MAX_LIGHT = 0.45,                 -- Default 2.53mm
        RAIN_GPU_SIZE_MIN_RAIN = 0.44,                  -- Default 0.91mm
        RAIN_GPU_SIZE_MAX_RAIN = 0.59,                  -- Default 4.10mm
        RAIN_GPU_SIZE_MIN_HEAVY = 0.57,                 -- Default 1.15mm
        RAIN_GPU_SIZE_MAX_HEAVY = 0.76,                 -- Default 4.10mm
        RAIN_GPU_SIZE_MIN_RARE = 0.65,                  -- Default 5mm
        RAIN_GPU_SIZE_MAX_RARE = 0.93,                  -- Default 6mm            
        RAIN_GPU_SIZE_BIAS = 2.0,
        RAIN_GPU_SIZE_RARECHANCE_DRY = 0.003,           -- Rare-size drop chance at dry
        RAIN_GPU_SIZE_RARECHANCE_HEAVY = 0.028,         -- Rare-size drop chance at heavy
        -- Add encounters from vehicle speed without changing surface flow.
        RAIN_GPU_STATE_SPEED_EXPOSURE_GAIN = 1.0,           -- Driving rain exposure gain, default: 1.00
        RAIN_GPU_STATE_AGE_MIN_SECONDS = 2.1,               -- Moving drop minimum age (seconds), default: 8.0
        RAIN_GPU_STATE_AGE_MAX_SECONDS = 10.0,              -- Moving drop maximum age (seconds), default: 18.0
        RAIN_GPU_STATE_MOBILE_SPEED_MULTIPLIER = 3.9,       -- Moving drop speed / calibrated cap, 
        RAIN_GPU_STATE_MOBILE_DRAG = 0.62,                  -- Moving drop drag,  Default : 1.59
        RAIN_GPU_STATE_KINETIC_ADHESION_FRACTION = 0.297,   -- Kinetic adhesion / static  default : 0.08
        RAIN_GPU_STATE_MOVING_FORCE_GAIN = 2.99,            -- Flow force gain in motion
        RAIN_GPU_STATE_MOBILE_THRESHOLD_UV = 0.0011,        -- Movement threshold (UV/s)
        RAIN_GPU_STATE_BOUNDARY_MARGIN = 0.005,
        RAIN_GPU_STATE_RESPAWN_GAP_MIN = 0.15,
        RAIN_GPU_STATE_RESPAWN_GAP_MAX = 0.75,

        -- Stage 7C: physical-reference size-dependent surface max speed.
        -- 1 mm diameter occupies exactly 0.0029296875 visor UV in the
        -- calibrated Debug 50 mesh measurement.
        RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM = 0.0029296875,

        -- Coalescence + absorption steering (docs/RAINFX_COALESCENCE.md).
        -- Pairs come from the async readback on the CPU (uniform grid);
        -- both GPU state passes validate them identically on current data.
        -- Compile-time: false removes all merge code from both state shaders
        -- (exactly the pre-merge shaders). Needs a Lua reload.
        RAIN_GPU_STATE_MERGE_SHADER = true,
        RAIN_GPU_STATE_MERGE_ENABLED = true,
        RAIN_GPU_STATE_MERGE_REACH = 1.15,     -- merge when d < reach*(r1+r2)
        RAIN_GPU_STATE_MERGE_MAX_DIAMETER_MM = 2.5,
        RAIN_GPU_STATE_MERGE_MAX_PAIRS = 256,  -- per readback snapshot
        RAIN_GPU_STATE_ATTRACT_ENABLED = true,
        RAIN_GPU_STATE_ATTRACT_REACH = 1.6,    -- steer when d < reach*(r1+r2)
        RAIN_GPU_STATE_ATTRACT_GAIN = 0.03,    -- visor UV / s^2 at contact
        RAIN_GPU_STATE_ATTRACT_MIN_SPEED = 0.002, -- only moving drops steer
        RAIN_GPU_STATE_ATTRACT_CONE = 0.0,     -- cos: 0 = forward half-plane
        -- Wet-path steering (docs/RAINFX_TRAIL_FLOW.md): moving drops are
        -- pulled sideways into existing wet tracks (water-field trail
        -- canvas), so later drops follow earlier paths and form rivulets.
        -- Compile-time define like MERGE_SHADER (needs a Lua reload).
        RAIN_GPU_STATE_WETPATH_SHADER = true,
        RAIN_GPU_STATE_WETPATH_ENABLED = true,
        RAIN_GPU_STATE_WETPATH_GAIN = 0.6,      -- visor UV / s^2 per unit slope
        RAIN_GPU_STATE_WETPATH_MIN_SPEED = 0.010, -- visor UV / s
        -- Worm fix (docs/RAINFX_IMPACT_SPLASH.md): the wet-path gradient is
        -- read AHEAD of the drop (its own trail is behind it), and wet-path
        -- and attraction steering may turn a drop at most TURN_RATE rad/s,
        -- so slow drops can no longer circle and wriggle.
        RAIN_GPU_STATE_WETPATH_AHEAD = 1.5,     -- drop radii ahead
        RAIN_GPU_STATE_STEER_TURN_RATE = 1.5,   -- rad / s
        -- Birth hold: a fresh drop rests HOLD s (jittered 0.6-1.4x), then its
        -- time step ramps in over RAMP s, so it starts slowly.
        RAIN_GPU_STATE_BIRTH_HOLD_SECONDS = 0.6,
        RAIN_GPU_STATE_BIRTH_RAMP_SECONDS = 1.2,
        RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_1MM = 0.4624,      -- Default 0.016
        -- Atlas/Ulbrich-style size exponent used as the first-order
        -- size-dependent max-speed curve.
        RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_EXPONENT = 0.67,

        -- 0 = canonical persistent physical droplets
        -- 40 = boundary mask
        -- 41 = lifecycle state
        -- 51 = physical persistent-state viewer
        RAIN_DYNAMIC_MESH_TEST_ENABLED = false,
        RAIN_DYNAMIC_MESH_TEST_GRID = 16,
        RAIN_DYNAMIC_MESH_TEST_QUAD_SIZE = 0.030,
        RAIN_DYNAMIC_MESH_TEST_SPACING = 0.050,
        RAIN_DYNAMIC_MESH_TEST_Z = -0.020,
        RAIN_DYNAMIC_MESH_TEST_CURVATURE_X = 0.90,
        RAIN_DYNAMIC_MESH_TEST_CURVATURE_Y = 0.35,

        -- Stage 2: use the real GLASS_EXT_DUMMY KN5 mesh as the
        -- authoritative UV -> local 3D surface mapping source.
        -- This test still uses deterministic CPU positions; it does not
        -- read the persistent GPU state yet.
        RAIN_DYNAMIC_SURFACE_TEST_ENABLED = false,

        -- Stage 3: render the actual persistent GPU droplet positions through
        -- the validated KN5 UV -> 3D mapping using asynchronous readback.
        RAIN_DYNAMIC_SURFACE_STATE_ENABLED = true,

        -- Refraction-source (geometry shot) settings. The former Stage 4B
        -- per-drop-quad diagnostics were removed with the quad shader
        -- (docs/RAINFX_WATER_FIELD.md §10); these names stay for settings
        -- compatibility, but they are functional, not debug:
        --   SKY_DEPTH / SKY_FOG_COLOR / SKY_CLOUD_DETAIL: the shot carries
        --   depth (sky tone needs it) and a mip chain (blur needs it).
        --   SHOT_YEBIS*: tonemapped shot (off: HDR shot).
        RAIN_DYNAMIC_DROP_SKY_DEPTH_DEBUG = false,
        RAIN_DYNAMIC_DROP_SKY_FOG_COLOR_DEBUG = true,
        RAIN_DYNAMIC_DROP_SKY_CLOUD_DETAIL_DEBUG = true,
        RAIN_DYNAMIC_DROP_SHOT_YEBIS_DEBUG = false,
        RAIN_DYNAMIC_DROP_SHOT_YEBIS_SCALE = 1.0,
        -- Lua-only capture path (main.track.opaque screen copy); keep off.
        RAIN_DYNAMIC_DROP_SCREEN_SOURCE_COMPARE_DEBUG = false,
        -- Still referenced by the Lua draw-state / impact code:
        RAIN_DYNAMIC_DROP_UV_DEBUG = false,
        RAIN_DYNAMIC_DROP_IMPACT_SHAPE_ENABLED = false,
        RAIN_DYNAMIC_DROP_IMPACT_SHAPE_SECONDS = 0.14,
        RAIN_DYNAMIC_DROP_IMPACT_LARGE_DIAMETER_MM = 3.0,
        RAIN_DYNAMIC_DROP_IMPACT_FAST_MIN_DIAMETER_MM = 1.4,
        RAIN_DYNAMIC_DROP_IMPACT_FAST_TRAVEL_MIX = 0.75,
        -- Static micro droplets share the main mesh and scene shot.
        RAIN_DYNAMIC_MICRO_LAYER_ENABLED = true,
        RAIN_DYNAMIC_MICRO_PATTERN_ENABLED = true,
        RAIN_DYNAMIC_MICRO_PATTERN_DIAMETER_MM = 0.46,           -- Fine Tuned for New micro pattern: 0.46
        RAIN_DYNAMIC_MICRO_PATTERN_TEXTURE_SIZE = 12288,
        RAIN_DYNAMIC_MICRO_LAYER_DEBUG = false,
        RAIN_DYNAMIC_MICRO_PATTERN_RAIN_POWER = 0.92,
        -- Micro pop-in (docs/RAINFX_MICRO_PATTERN.md): a picked share of the
        -- baked disks cycles absent -> lands -> lives -> fades, each with its
        -- own period and phase (no synchronised blinking).
        RAIN_DYNAMIC_MICRO_POP_ENABLED = true,
        -- Exact point reads of the micro pattern (Load). false = the former
        -- bilinear read (what the ignored point sampler really did).
        RAIN_DYNAMIC_MICRO_POINT_LOAD = false,
        RAIN_DYNAMIC_MICRO_POP_PICK = 0.35,     -- share of disks that cycle
        RAIN_DYNAMIC_MICRO_POP_PERIOD = 5.0,    -- s, x 0.5..1.5 per disk
        RAIN_DYNAMIC_MICRO_POP_OFF = 0.30,      -- share of the cycle absent
        RAIN_DYNAMIC_MICRO_POP_FADE = 0.08,     -- share of the life fading out
        RAIN_DYNAMIC_MICRO_POP_FLASH = 0.11,    -- landing highlight (x fog)
        RAIN_DYNAMIC_MICRO_POP_ID_SCALE = 1.0,  -- id cells per pattern cell
        -- Micro pattern v2 (docs/RAINFX_MICRO_PATTERN.md). Bake-time values;
        -- changes need a Lua reload.
        RAIN_DYNAMIC_MICRO_PATTERN_STRATA = 1,          -- Micro strata
        RAIN_DYNAMIC_MICRO_PATTERN_FIRST_PRESENCE = 0.55,   -- Micro fist stratum presence
        RAIN_DYNAMIC_MICRO_PATTERN_PRESENCE = 0.77,     -- Micro stratum presence
        RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MIN = 0.32, -- cells, FINE TUNED
        RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MAX = 0.55, -- cells, FINE TUNED
        RAIN_DYNAMIC_MICRO_PATTERN_RIM_CELLS = 0.07, -- superseded by RIM_TEXELS
        -- Invisible cut line: the winner's outer ring (in pattern texels)
        -- shows the unrefracted scene/haze, separating fragments.
        RAIN_DYNAMIC_MICRO_PATTERN_RIM_TEXELS = 1.43,       -- Micro cut line, FINE TUNED
        -- Pattern texels per grid cell (legacy look 2048 / 546 = 3.75).
        RAIN_DYNAMIC_MICRO_PATTERN_TEXELS_PER_CELL = 12.00,     --FINE TUNED
        -- 0 = invisible cut line (gap). > 0 = draw the ring refracted but
        -- darkened by this amount instead.
        RAIN_DYNAMIC_MICRO_PATTERN_OUTLINE_DARK = 0.001,     -- Micro outline, FINE TUNED
        -- Micro disks use the water-field head lens rule only (the legacy
        -- "scene optics" mode was removed 2026-10-02, RAINFX_MICRO_PATTERN.md).
        RAIN_DYNAMIC_MICRO_WATER_LENS_REFRACTION = 1.0, -- x WF refraction
        RAIN_DYNAMIC_MICRO_WATER_LENS_SLOPE = 0.8,      -- FINE TUNED
        RAIN_DYNAMIC_MICRO_LAYER_OPACITY = 0.8,
        -- Persistent UV wipe mask composited with the static micro layer.
        RAIN_DYNAMIC_TRAIL_MASK_ENABLED = true,
        RAIN_DYNAMIC_TRAIL_MASK_DEBUG = false,
        RAIN_DYNAMIC_TRAIL_MASK_WIPE_ENABLED = true,
        RAIN_DYNAMIC_TRAIL_MASK_WIPE_STRENGTH = 1.5,
        RAIN_DYNAMIC_TRAIL_MASK_FILM_ENABLED = true,
        RAIN_DYNAMIC_TRAIL_MASK_SKY_CORRECTION = true,
        RAIN_DYNAMIC_TRAIL_MASK_FILM_OPACITY = 0.11,    -- Thin film opacity, FINE TUNED
        RAIN_DYNAMIC_TRAIL_MASK_FILM_PIXELS = 2.6,
        -- s34: own lifetime of the thin film (was tied to the wipe recovery
        -- time RAIN_DYNAMIC_TRAIL_MASK_SECONDS, ~3 s visible + fp16 tail).
        RAIN_DYNAMIC_TRAIL_MASK_FILM_SECONDS = 1.0,      -- Thin film refraction, FIND TUNED
        RAIN_DYNAMIC_TRAIL_MASK_RIDGE_ENABLED = true,
        RAIN_DYNAMIC_TRAIL_MASK_RIDGE_SECONDS = 1.30,
        RAIN_DYNAMIC_TRAIL_MASK_RIDGE_OPACITY = 0.22,
        RAIN_DYNAMIC_TRAIL_MASK_RIDGE_PIXELS = 11.2,
        RAIN_DYNAMIC_TRAIL_MASK_SIZE = 2048,            -- FINE TUNED (no fps dropping)
        -- Wipe / liquid-ridge path width from the drop's own diameter:
        -- width = diameter * scale + offset (mm), floored to MIN texels.
        -- Legacy was a fixed 1.5 R / 0.75 R with a 1.4-texel radius floor,
        -- which at 512 made most drops the same width.
        RAIN_DYNAMIC_TRAIL_MASK_WIPE_WIDTH_SCALE = 0.980,     -- Wipe width, FINE TUNED
        RAIN_DYNAMIC_TRAIL_MASK_WIPE_WIDTH_OFFSET_MM = 0.0, -- Wipe width offset, FINE TUNED
        RAIN_DYNAMIC_TRAIL_MASK_RIDGE_WIDTH_SCALE = 0.60,   -- Liquid ridge width, FINE TUNED
        RAIN_DYNAMIC_TRAIL_MASK_RIDGE_WIDTH_OFFSET_MM = 0.0,    -- Liquid ridge offset, FINE TUNED
        RAIN_DYNAMIC_TRAIL_MASK_MIN_WIDTH_TEXELS = 0.25,        -- Path min width, FINE TUNED
        RAIN_DYNAMIC_TRAIL_MASK_SECONDS = 0.69,
        -- Head stamp source for the water field (legacy birth-mask optics,
        -- its RGBA8 encoding and its decay path were removed 2026-10-02;
        -- docs/RAINFX_WATER_FIELD.md §7).
        RAIN_DYNAMIC_BIRTH_MASK_ENABLED = true,
        RAIN_DYNAMIC_BIRTH_MASK_ONLY = true,
        RAIN_DYNAMIC_BIRTH_MASK_SIZE = 2048,
        -- R1.1 (docs/RAINFX_GPU_PRELAID.md): water-field heads (body, tail,
        -- shape lobe, puddles, irregular lobes) evaluated on the GPU from the
        -- live state textures by tile binning; the CPU keeps only the splash
        -- v2 / tear pieces and the trail. A/B with the CPU path.
        RAIN_GPU_HEADS = true,
        RAIN_GPU_SPLASH = false,      -- R1.4: bounded GPU splash atlas, opt-in
        RAIN_GPU_HEADS_SPARSE_WORDS = false, -- R1.3: skip empty tile-mask words
        RAIN_GPU_HEADS_TILE = 64,        -- px of the head canvas per tile
        RAIN_GPU_HEADS_FLIP_Y = false,   -- debug: canvas row orientation
        RAIN_GPU_HEADS_DEBUG = 0,        -- 0 off, 1 tile occupancy, 2 GPU-only, 3 no head shading
        RAIN_DYNAMIC_BIRTH_MASK_BODY_STRETCH = true,
        RAIN_DYNAMIC_BIRTH_MASK_SHAPE_VARIATION = true,
        RAIN_DYNAMIC_BIRTH_MASK_SHAPE_STRENGTH = 0.85,
        RAIN_DYNAMIC_BIRTH_PUDDLE_ENABLED = true,
        RAIN_DYNAMIC_BIRTH_PUDDLE_SHARE = 0.25,
        RAIN_DYNAMIC_BIRTH_PUDDLE_MIN_MM = 1.40,
        RAIN_DYNAMIC_BIRTH_PUDDLE_REACH = 0.70,
        RAIN_DYNAMIC_BIRTH_MASK_SKY_CORRECTION = true,
        RAIN_DYNAMIC_BIRTH_MASK_BODY_LOOKBACK_SECONDS = 0.04,
        RAIN_DYNAMIC_BIRTH_MASK_BODY_MAX_RADII = 1.5,
        RAIN_DYNAMIC_BIRTH_MASK_GROW_SECONDS = 0.12,

        -- Water field (docs/RAINFX_WATER_FIELD.md). Heads are drawn as soft
        -- height kernels into the birth-mask canvas (fp16): G = union height,
        -- R/G = radius code (radius texels / 32), B/G = impact energy.
        -- A threshold on G gives the silhouette, so overlapping kernels merge
        -- like metaballs; the slope of G drives one screen-space refraction
        -- rule for every shape (round, lobed, torn, trail). false = legacy.
        RAIN_DYNAMIC_WATER_FIELD_ENABLED = true,
        RAIN_DYNAMIC_WATER_FIELD_DEBUG = 0, -- 1 height/silhouette, 2 slope, 3 large-drop weight
        RAIN_DYNAMIC_WATER_FIELD_THRESHOLD = 0.35,
        RAIN_DYNAMIC_WATER_FIELD_KERNEL_SCALE = 1.24,
        RAIN_DYNAMIC_WATER_FIELD_REFRACTION = 0.35, -- shot heights at slope 1
        RAIN_DYNAMIC_WATER_FIELD_SCENE_MIP = 3.0,
        RAIN_DYNAMIC_WATER_FIELD_SLOPE_MIP = 1.5,
        RAIN_DYNAMIC_WATER_FIELD_EDGE_LOSS = 0.75,
        RAIN_DYNAMIC_WATER_FIELD_LOSS_START = 0.70,
        RAIN_DYNAMIC_WATER_FIELD_LOSS_END = 1.30,
        RAIN_DYNAMIC_WATER_FIELD_GLINT = 0.45,
        RAIN_DYNAMIC_WATER_FIELD_OPACITY = 0.97,
        RAIN_DYNAMIC_WATER_FIELD_NORMAL_STEP_TEXELS = 1.0,
        RAIN_DYNAMIC_WATER_FIELD_LOBES = true,
        RAIN_DYNAMIC_WATER_FIELD_MOTION_STRETCH = 0.35,
        RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KMH = 111.0,
        RAIN_DYNAMIC_WATER_FIELD_TEAR_FULL_KMH = 205.0,
        RAIN_DYNAMIC_WATER_FIELD_TEAR_HEAVY_SIZE_PERCENT = 50.0, -- minimum position within the heavy birth-size range
        -- Kernels below ~1.5 texels never cross the silhouette threshold
        -- on the texel grid; tear pieces are clamped to this size.
        RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS = 0.70,     -- WF tear min piece (texels), FINE TUNED
        -- Impact splash v2 (docs/RAINFX_IMPACT_SPLASH.md): animated in the
        -- head canvas at the frozen impact point. Centre pressed flat then
        -- emptied, mass pushed into a rim ring that grows, breaks up and
        -- scatters. Energy = speed term x size term. false = old pancake.
        RAIN_DYNAMIC_WATER_FIELD_SPLASH_V2 = true,
        RAIN_DYNAMIC_WATER_FIELD_SPLASH_SPEED_SHARE = 0.69, -- stable share of speed-only births; size-qualified births always pass
        RAIN_DYNAMIC_WATER_FIELD_SPLASH_SECONDS = 0.27, -- x (0.6 + 0.8 size)
        RAIN_DYNAMIC_WATER_FIELD_SPLASH_SIZE_REF = 8.0, -- head texels = size 1
        RAIN_DYNAMIC_WATER_FIELD_SPLASH_SPREAD = 5.0,   -- rim radius growth
        RAIN_DYNAMIC_WATER_FIELD_SPLASH_HOLLOW_AT = 0.45, -- centre empty by t
        RAIN_DYNAMIC_WATER_FIELD_SPLASH_BREAK_AT = 0.55, -- rim breaks from t
        RAIN_DYNAMIC_WATER_FIELD_SPLASH_SCATTER = 2.31,  -- break-up throw (radii)
        RAIN_DYNAMIC_WATER_FIELD_SPLASH_RESIDUAL = 0.65, -- remaining drop size
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED = true,
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_SIZE = 1024,
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_SECONDS = 0.46,      -- WF trail lifetime, FINE TUNED
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_WIDTH = 0.78,        -- WF trail width, FINE TUNED
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_NOISE = 0.75,        -- WF trail bead noise, FINE TUNED
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_NOISE_CELLS = 203.0, -- WF trail noise cells FINE TUNED
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_MIN_SPEED = 0.004, -- visor UV / s
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_MIN_RADIUS = 0.677, -- head-mask texels; shared trail/sheet gate
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_HEAD_BACK = 0.9, -- radii behind the head
        RAIN_DYNAMIC_WATER_FIELD_SHEET_LINK_RADII = 8.0, -- maximum segment length before restart
        RAIN_DYNAMIC_WATER_FIELD_SHEET_LINK_MIN_TEXELS = 32.0, -- trail-canvas texel floor for tiny drops
        -- Fast-flow sheet (docs/RAINFX_WATER_FIELD.md): fast heads lay a
        -- wider, flatter, continuous track that decays smoothly (no beads)
        -- and renders blurrier/milkier, like a thick spray film. Trail B/G
        -- stores the sheet factor 0..1.
        RAIN_DYNAMIC_WATER_FIELD_SHEET_ENABLED = true,
        -- Local impact film prototype. Kept opt-in until in-game tuning.
        RAIN_DYNAMIC_IMPACT_SHEET_ENABLED = true,
        RAIN_DYNAMIC_IMPACT_SHEET_FLUX_START = 0.60, -- provisional influx threshold
        RAIN_DYNAMIC_IMPACT_SHEET_FEED = 0.87, -- height / s per excess influx
        RAIN_DYNAMIC_IMPACT_SHEET_SECONDS = 0.65,
        RAIN_DYNAMIC_IMPACT_SHEET_SMEAR_MIX = 0.55,
        RAIN_DYNAMIC_IMPACT_SHEET_WAVE_PX = 60.0, -- film-only lens displacement
        RAIN_DYNAMIC_IMPACT_SHEET_OPACITY = 1.0,
        RAIN_DYNAMIC_WATER_FIELD_SHEET_START_SPEED = 0.03, -- UV / s
        RAIN_DYNAMIC_WATER_FIELD_SHEET_FULL_SPEED = 0.10,  -- UV / s
        RAIN_DYNAMIC_WATER_FIELD_SHEET_FORM = 1.0, -- shared shape strength for either trigger
        RAIN_DYNAMIC_WATER_FIELD_SHEET_HEIGHT_MIN = 0.75, -- sheet height floor before decay
        RAIN_DYNAMIC_WATER_FIELD_SHEET_WIDEN = 2.34,   -- + x trail width FINE TUNED
        RAIN_DYNAMIC_WATER_FIELD_SHEET_THIN = 0.80,   -- amplitude loss, FINE TUNED
        RAIN_DYNAMIC_WATER_FIELD_SHEET_PERSIST = 0.25, -- slower decay, FINE TUNED
        RAIN_DYNAMIC_WATER_FIELD_SHEET_BLUR = 2.25,    -- extra mip, FINE TUNED
        RAIN_DYNAMIC_WATER_FIELD_SHEET_VEIL = 0.00,   -- milky lift, FINE TUNED
        RAIN_DYNAMIC_WATER_FIELD_SPLASH_SHEET = 0.35, -- splash in trail
        RAIN_DYNAMIC_WATER_FIELD_SHEET_ALPHA = 1.00,  -- film opacity, FINE TUNED
        -- Density OR speed can trigger sheets; shared shape is independent
        -- of which ramp passed (rain x relative airspeed, smear model).
        RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_GATE = true,
        RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_MIN = 0.15,
        RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_FULL = 0.60,
        RAIN_DYNAMIC_WATER_FIELD_SHEET_EDGE_SOFT = 0.24, -- soft film edge, FINE TUNED
        -- Trail flow (docs/RAINFX_TRAIL_FLOW.md).
        -- Surface-tension levelling: per-frame 4-neighbour diffusion of the
        -- trail canvas, so beads/segments merge into one smooth film.
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_DIFFUSE = 0.05,
        -- Fast-flow sheets: a ribbon (constant along the path) instead of a
        -- stretched dome per frame, which left a chain of bumps.
        RAIN_DYNAMIC_WATER_FIELD_SHEET_RIBBON = true,
        -- Slope taps at least one trail texel apart: a sub-texel step on the
        -- bilinear 1024 trail gives a per-texel constant slope (grid look).
        RAIN_DYNAMIC_WATER_FIELD_GRADIENT_TRAIL_TEXELS = 1.0,
        -- Trail refraction v2 (docs/RAINFX_TRAIL_REFRACTION.md, T1 + T2):
        -- trails are cylindrical lenses: sharp image shifted across the flow
        -- by the thickness gradient instead of a blurred copy ("paint").
        RAIN_DYNAMIC_TRAIL_REFRACT_V2 = true,
        RAIN_DYNAMIC_TRAIL_REFRACT_PX = 14.0,      -- image shift at slope 1 (render px)
        RAIN_DYNAMIC_TRAIL_GRAD_WIDE_TEXELS = 3.5, -- ~ half a trail width (trail canvas)
        RAIN_DYNAMIC_TRAIL_GRAD_MIX = 0.65,        -- 0 narrow (edges) .. 1 wide (interior)
        RAIN_DYNAMIC_TRAIL_PROFILE_RANGE = 0.35,   -- G above threshold = full thickness
        RAIN_DYNAMIC_TRAIL_SLOPE_MAX = 1.5,
        RAIN_DYNAMIC_TRAIL_MIP_BASE = 0.75,        -- sharp
        RAIN_DYNAMIC_TRAIL_MIP_SLOPE = 1.0,        -- defocus with curvature
        RAIN_DYNAMIC_TRAIL_SHEET_BLUR = 0.5,       -- fast-flow sheets (was 2.25 via WF)
        -- T3: flowing thickness ripple (stretched along the mean drop flow)
        RAIN_DYNAMIC_TRAIL_RIPPLE_AMP = 0.30,      -- thickness units
        RAIN_DYNAMIC_TRAIL_RIPPLE_ALONG = 45.0,    -- cells per UV along the flow
        RAIN_DYNAMIC_TRAIL_RIPPLE_ACROSS = 160.0,  -- cells per UV across
        RAIN_DYNAMIC_TRAIL_RIPPLE_SPEED = 1.0,     -- x mean drop speed
        -- T4: dramatic refraction at steep contact edges
        RAIN_DYNAMIC_TRAIL_EDGE_BOOST = 0.8,
        RAIN_DYNAMIC_TRAIL_EDGE_START = 0.6,       -- slope
        RAIN_DYNAMIC_TRAIL_EDGE_END = 1.3,
        -- T6: wiped film / ridge follow the same rule
        RAIN_DYNAMIC_TRAIL_FILM_BOOST = 2.5,       -- x film / ridge edge pixels
        -- Anti-chrome tone limiter (heads, trails, micro water lens): the
        -- refracted image is compressed toward the blurred view behind the
        -- drop, and its luminance is held inside a ratio window of it.
        RAIN_DYNAMIC_WATER_TONE_ENABLED = false,
        RAIN_DYNAMIC_WATER_TONE_CONTRAST = 0.50, -- 1 = off, 0 = flat
        RAIN_DYNAMIC_WATER_TONE_RATIO_MIN = 0.55,
        RAIN_DYNAMIC_WATER_TONE_RATIO_MAX = 1.45,
        RAIN_DYNAMIC_WATER_TONE_BG_MIP = 4.5,
        -- Floor of the ratio window's reference, x fog luminance. Without it
        -- the window collapsed to ~0 over black backgrounds (windscreen,
        -- cockpit) and every drop there disappeared.
        RAIN_DYNAMIC_WATER_TONE_FLOOR = 0.25,
        -- Heads/trails use the v1 limiter (size-weighted v2 reverted, see
        -- docs/RAINFX_TRAIL_FLOW.md §v3). Micro water lens: own switch.
        RAIN_DYNAMIC_WATER_TONE_MICRO = false,
        -- Large drops: low-res, imperfect inner image with a soft boundary.
        RAIN_DYNAMIC_WATER_LARGE_START_PX = 8.0,
        RAIN_DYNAMIC_WATER_LARGE_FULL_PX = 30.0,
        RAIN_DYNAMIC_WATER_LARGE_BLUR_MIP = 1.5,  -- extra mip at full size
        RAIN_DYNAMIC_WATER_LARGE_WARP_PIXELS = 4.0,
        RAIN_DYNAMIC_WATER_LARGE_WARP_CELLS = 0.6, -- warp cell / drop radius
        RAIN_DYNAMIC_WATER_LARGE_EDGE_SOFT = 0.10, -- height band (soft edge)
        

        -- Smear mask v3 (docs/RAINFX_SMEAR_MASK.md §v3, user design).
        -- density = rain x (|car velocity - wind| / REF_KMH)
        -- trigger = TRIGGER_OVERRIDE or density >= TRIGGER
        -- reveal  = REVEAL_OVERRIDE (>= 0) or
        --           min(1, density / FULL) x max(0, dot(cameraLook, airDir))
        -- Texture R: region shows where R <= reveal (low R first).
        -- Texture G: blend degree inside the region (micro visible+turbid
        -- by G, drops turbid by G, trails/paths weakened by G).
        RAIN_DYNAMIC_SMEAR_ENABLED = true,
        RAIN_DYNAMIC_SMEAR_DEBUG = 0,          -- 1 region/G, 2 raw R, 3 raw G, 4 classes
        RAIN_DYNAMIC_SMEAR_TEXTURE = 'texture/smear_mask_v7_template_2048.png', -- app-relative
        RAIN_DYNAMIC_SMEAR_USE_TEXTURE = true, -- false = procedural test mask
        RAIN_DYNAMIC_SMEAR_NOSE_EXCLUDE = true,
        RAIN_DYNAMIC_SMEAR_NOSE_U = 0.490,
        RAIN_DYNAMIC_SMEAR_NOSE_TIP_V = 0.335,
        RAIN_DYNAMIC_SMEAR_NOSE_HALF_WIDTH = 0.267,
        RAIN_DYNAMIC_SMEAR_NOSE_HEIGHT = 0.417,
        RAIN_DYNAMIC_SMEAR_NOSE_SOFT = 0.083,
        RAIN_DYNAMIC_SMEAR_REF_KMH = 200.0,    -- airspeed giving amplification 1
        RAIN_DYNAMIC_SMEAR_TRIGGER = 0.30,     -- density that starts the effect
        RAIN_DYNAMIC_SMEAR_FULL = 0.90,        -- density giving full reveal
        RAIN_DYNAMIC_SMEAR_TRIGGER_OVERRIDE = false,
        RAIN_DYNAMIC_SMEAR_REVEAL_OVERRIDE_ON = false,
        RAIN_DYNAMIC_SMEAR_REVEAL_OVERRIDE = 0.0, -- manual reveal 0..1
        RAIN_DYNAMIC_SMEAR_FACING_POWER = 1.0,
        RAIN_DYNAMIC_SMEAR_ATTACK_SECONDS = 0.74,
        RAIN_DYNAMIC_SMEAR_RELEASE_SECONDS = 3.31,
        RAIN_DYNAMIC_SMEAR_EDGE_SOFT = 0.04,   -- R band around the reveal front
        RAIN_DYNAMIC_SMEAR_MICRO_HIDE = 1.0,   -- micro visibility -> G in region
        RAIN_DYNAMIC_SMEAR_MICRO_TURBID = 0.51, -- micro turbid x G
        RAIN_DYNAMIC_SMEAR_DROP_TURBID = 0.780, -- GPU drops turbid x G
        -- v4 fixed region rules (no G): inside the region WF trails and
        -- heads are laid OVER the micro pattern with these strengths.
        -- v5: water keeps its own silhouette, rim and glint (flow stays
        -- visible) and its colour MIXES with the micro/haze beneath.
        RAIN_DYNAMIC_SMEAR_TRAIL_MIX = 0.55,   -- trail colour -> layer beneath
        -- v9 (user): in the region WF trails are weak and clear, only the
        -- moving drops stay turbid (foam carried by the drops).
        RAIN_DYNAMIC_SMEAR_TRAIL_TURBID = 1.0,  -- trail -> turbid colour (was 0.45)
        RAIN_DYNAMIC_SMEAR_TRAIL_BLUR = 0.0,   -- extra trail mip in region (was 1.5)
        RAIN_DYNAMIC_SMEAR_TRAIL_CLEAR = 0.80, -- trail opacity removed in region
        RAIN_DYNAMIC_SMEAR_HEAD_MIX = 0.35,    -- head colour -> layer beneath
        -- v8: inside the region every feature follows G' (low = invisible).
        RAIN_DYNAMIC_SMEAR_HEAD_HIDE = 1.0,    -- moving drops: visibility -> G'
        RAIN_DYNAMIC_SMEAR_TRAIL_HIDE = 1.0,   -- WF trails (+ their haze clear)
        -- v8 pattern density: tiles of the mask over the visor UV.
        RAIN_DYNAMIC_SMEAR_R_TILING = 1.0,     -- region blobs
        RAIN_DYNAMIC_SMEAR_G_TILING = 2.5,     -- class patches (denser)
        RAIN_DYNAMIC_SMEAR_PATH_WEAKEN = 0.85, -- v8: wipe paths/film/ridge follow G' by this
        RAIN_DYNAMIC_SMEAR_WIND_MODE = 1,      -- 0 ignore, 1 (x,z), 2 (x,-z), 3 (-x,-z)
        RAIN_DYNAMIC_SMEAR_MIP = 5.0,          -- turbid colour blur
        -- v6 G processing: G' = sat((G - PIVOT) * CONTRAST + PIVOT)^GAMMA
        RAIN_DYNAMIC_SMEAR_G_CONTRAST = 1.8,
        RAIN_DYNAMIC_SMEAR_G_PIVOT = 0.55,
        RAIN_DYNAMIC_SMEAR_G_GAMMA = 1.0,
        -- v7 class facets (docs/RAINFX_SMEAR_MASK.md v7, replaces the v6
        -- region water sheet): G' -> N classes, each its own refraction
        -- image / tone / blur; erased one by one as the state weakens.
        RAIN_DYNAMIC_SMEAR_CLASSES = 5,
        RAIN_DYNAMIC_SMEAR_CLASS_SOFT = 0.35,      -- boundary blend (class share)
        RAIN_DYNAMIC_SMEAR_CLASS_SEED = 0.0,
        RAIN_DYNAMIC_SMEAR_FACET_PIXELS = 10.0,    -- per-class image offset (px)
        RAIN_DYNAMIC_SMEAR_TONE_RANGE = 0.18,      -- per-class tone +-
        RAIN_DYNAMIC_SMEAR_CLASS_MIP_RANGE = 1.5,  -- per-class blur +- (mip)
        RAIN_DYNAMIC_SMEAR_ERASE_SPAN = 0.60,      -- reveal below this erases classes
        RAIN_DYNAMIC_SMEAR_CLASS_WIPE = 0.80,      -- wiping erases classes
        RAIN_DYNAMIC_SMEAR_LINE_STRENGTH = 0.12,   -- soft boundary line darkening
        RAIN_DYNAMIC_SMEAR_LINE_WIDTH = 0.06,      -- in class units
        RAIN_DYNAMIC_SMEAR_FACET_ALPHA = 0.18,     -- facet film on bare glass
        RAIN_DYNAMIC_SMEAR_VEIL = 0.45,        -- turbid colour -> fog
        -- Procedural test mask (used without texture).
        RAIN_DYNAMIC_SMEAR_MASK_CELLS = 5.0,
        RAIN_DYNAMIC_SMEAR_MASK_WARP = 0.6,
        RAIN_DYNAMIC_SMEAR_FILL_CELLS = 420.0,
        RAIN_DYNAMIC_SMEAR_FILL_PATCH_CELLS = 40.0,
        
        
        -- Haze / condensation film (docs/RAINFX_HAZE.md). Procedural in
        -- visor UV (no texture); revealed by rain in a stable order, cleared
        -- by wipes and water-field tracks; composited under micro disks.
        RAIN_DYNAMIC_HAZE_ENABLED = true,
        RAIN_DYNAMIC_HAZE_DEBUG = false,
        RAIN_DYNAMIC_HAZE_TEXTURE_SIZE = 1024,
        RAIN_DYNAMIC_HAZE_MIST_CELLS = 31.7,
        RAIN_DYNAMIC_HAZE_ORDER_CELLS = 30.0,
        RAIN_DYNAMIC_HAZE_SPECKLE_CELLS = 1500.0,
        RAIN_DYNAMIC_HAZE_STRENGTH = 0.57,      -- Haze strength, FINE TUNED
        RAIN_DYNAMIC_HAZE_MOTTLE = 0.65,
        RAIN_DYNAMIC_HAZE_RAIN_POWER = 0.80,
        RAIN_DYNAMIC_HAZE_REVEAL_SOFT = 0.40,
        RAIN_DYNAMIC_HAZE_MIP = 4.5,
        RAIN_DYNAMIC_HAZE_VEIL = 0.12,
        RAIN_DYNAMIC_HAZE_SPECKLE_PIXELS = 0.4,
        RAIN_DYNAMIC_HAZE_TRAIL_CLEAR = 0.90,
        RAIN_DYNAMIC_HAZE_SKY_CORRECTION = true,
        RAIN_DYNAMIC_TRAIL_MASK_MAX_STAMPS = 384, -- per frame (was 64: each drop
                                                  -- re-stamped only every ~0.5 s)
        -- Test whether track-stage HDR works without the extra scene copy.
        RAIN_DYNAMIC_DROP_SCREEN_UV_PREPASS = false,
        -- Compare dynamic::hdr at the track transparent draw stage.
        -- 2026-10-03: false = draw at main.root.transparent (stage probe:
        -- the frame there already has the cockpit, driver and wipers, so
        -- they no longer draw over the haze, and the frame copy of tone
        -- mode 3 contains them). Needs a Lua reload. If rain streaks show
        -- inside the drops at this stage, set it back to true.
        RAIN_DYNAMIC_DROP_DRAW_AT_TRACK = false,
        -- Verified: this stage excludes sharp rain streaks from dynamic
        -- drops. Other KN5 transparent visor regions still show the artifact
        -- and require a separate visor-wide rendering/order investigation.
        -- 2026-10-02 (user test): with the geometry shot as the refraction
        -- source, the track stage no longer mixes rain streaks in, so the
        -- smoke-stage workaround is not needed any more.
        RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG = true,
        -- Depth test off for drops. Rejected in game (2026-10-02): drops of
        -- overlapping visor parts showed through each other. Kept as a
        -- diagnostic toggle only (docs/RAINFX_IMPACT_SPLASH.md §6).
        RAIN_DYNAMIC_DROP_DEPTH_OFF = false,
        -- Refraction source (geometry shot) completeness: the transparent
        -- pass adds car glass / interior transparent parts, so the image a
        -- drop refracts matches what is really behind the visor. The near
        -- clip keeps the helmet visor itself out of its own source.
        RAIN_DYNAMIC_DROP_SHOT_TRANSPARENT = true,
        -- Refraction-source tone pass (docs/RAINFX_SHOT_TONE.md). The shot is
        -- rendered without the frame's weather fog, so far geometry kept its
        -- raw (brown) colour while sky texels were swapped to the fog tone
        -- per sample, AFTER blurring: hard "paint" edges in every blurred
        -- drop / trail. The pass tones every shot texel once (continuous
        -- aerial fog by depth, sky = fog with bounded cloud contrast) and the
        -- mips are built from the toned image, so blur stays consistent.
        RAIN_DYNAMIC_SHOT_TONE_ENABLED = true,
        -- Stage probe (docs/RAINFX_STAGE_PROBE.md): copies the chosen scene
        -- texture at every hookable render stage into small thumbnails, to
        -- see what each stage already contains (car, clouds, transparents)
        -- and in which order the stages run. Diagnostic only.
        RAIN_DYNAMIC_STAGE_PROBE = false,
        RAIN_DYNAMIC_STAGE_PROBE_SOURCE = 1,   -- 1 dynamic::hdr, 2 dynamic::screen, 3 dynamic::depth
        RAIN_DYNAMIC_STAGE_PROBE_EXPOSURE = 1.0,
        RAIN_DYNAMIC_STAGE_PROBE_WIDTH = 320,
        -- Overlay probe (docs/RAINFX_POST_OVERLAY.md P0): renders the drop
        -- mesh offscreen through ac.GeometryShot custom callbacks and can
        -- draw it full-screen in ui.onExclusiveHUD (after post / DLSS).
        -- Diagnostic only, default off. Changes nothing when off.
        RAIN_VISOR_OVERLAY_PROBE = false,
        RAIN_VISOR_OVERLAY_PROBE_FULLSCREEN = false, -- draw the overlay on screen
        RAIN_VISOR_OVERLAY_PROBE_HIDE_SCENE = false, -- skip the in-scene drop draw
        -- P1 (docs/RAINFX_POST_OVERLAY.md): the visor layer is drawn ONLY as
        -- a post overlay: in-scene draw off, the final frame (dynamic::screen
        -- in the HUD callback, before our draw) is the refraction source,
        -- shader in LDR mode, composite with ui.renderShader (alpha blend).
        RAIN_VISOR_OVERLAY = false, -- s53: archived (scene stack is the path)
        RAIN_VISOR_OVERLAY_SOURCE_MIPS = 9,
        RAIN_VISOR_OVERLAY_FOG_MIP = 6.0,   -- LDR veil tone: frame mean mip
        RAIN_VISOR_OVERLAY_DEBUG_ALPHA = false, -- show overlay alpha as grey
        -- HUD lift (docs/RAINFX_POST_OVERLAY.md "HUD order"): original AC /
        -- Python app windows are drawn BEFORE ui.onExclusiveHUD, so the
        -- overlay covers them. Lift = move those windows to a redirect layer
        -- and draw that layer above the overlay. Lifted windows get no mouse
        -- input (CSP redirect limitation): turn lift off to move/click them.
        RAIN_VISOR_OVERLAY_HUD_LIFT = true,
        RAIN_VISOR_OVERLAY_HUD_LAYER = 7,
        RAIN_VISOR_OVERLAY_HUD_PREMULTIPLIED = true, -- user test: sharp text
        -- s41: overlay resolution. 0 = main render target (DLSS input,
        -- softer after upscale), 1 = output / window size (sharp, ~2.25x
        -- pixels at DLSS quality). Pixel-unit params and blur mips are
        -- rescaled so the look stays the same in screen terms.
        RAIN_VISOR_OVERLAY_RES_SCALE = 1.0,
        -- Visor layer V1 (docs/RAINFX_VISOR_LAYER.md): the visor KN5 parts
        -- are hidden in the scene and drawn in the overlay with our shaders.
        -- Housing opaque with depth, then glass back to front (coating,
        -- rain, GLASS_EXT, GLASS_INT), premultiplied. Needs RAIN_VISOR_OVERLAY.
        RAIN_VISOR_LAYER = true,
        -- s53 (docs/RAINFX_VISOR_LAYER.md §17): the visor stack is drawn IN
        -- THE SCENE (drop callback), not in the overlay. Housing opaque with
        -- depth, then glass back to front around the rain mesh. HDR output.
        RAIN_VISOR_SCENE_STACK = true,
        RAIN_VISOR_LAYER_SUN_HDR = 1.0,       -- x sim.lightColor (HDR) in the scene stack
        RAIN_VISOR_LAYER_AMBIENT = 0.85,      -- x frame-mean luminance (s45)
        RAIN_VISOR_LAYER_AMBIENT_SAT = 0.35,  -- sky/horizon chroma kept
        RAIN_VISOR_LAYER_AMBIENT_FLOOR = 0.35, -- downward faces x this
        RAIN_VISOR_LAYER_LIGHT_FLIP = true,   -- toward light = -sim.lightDirection
        -- s46 helmet shadow for interior parts (fabric, glass line): the
        -- shell blocks the sun unless it shines in through the visor
        -- opening, i.e. comes from in front of the head (camera look).
        RAIN_VISOR_LAYER_HELMET_SHADOW = true, -- s50: off, the scene-shadow probe is the shadow source
        RAIN_VISOR_LAYER_SHADOW_COS_LO = -0.05, -- dot(toLight, forward): dark
        RAIN_VISOR_LAYER_SHADOW_COS_HI = 0.35,  -- fully lit through the opening
        RAIN_VISOR_LAYER_INTERIOR_AMBIENT = 0.44, -- ambient x this inside (s47: was 0.6)
        -- s47 scattered light inside the helmet (hard-coded estimate):
        -- sun bounce = sun x SUN_BOUNCE x (BOUNCE_BASE + (1-BASE) x sunVis)
        -- opening   = frame-mean luminance x OPENING (scene through the visor)
        RAIN_VISOR_LAYER_SUN_BOUNCE = 0.19,
        RAIN_VISOR_LAYER_BOUNCE_BASE = 0.29,
        RAIN_VISOR_LAYER_OPENING = 1.00,
        -- s48: interior hemisphere / opening light keep this much sky chroma
        -- (0 = neutral grey; s47 tinted the interior with the sky tone).
        RAIN_VISOR_LAYER_INTERIOR_SKY_CHROMA = 1.0,
        -- s49 scene-shadow probe (docs/RAINFX_VISOR_LAYER.md §13): a second
        -- KN5 instance, housing only, dark probe material, drawn in the
        -- scene so CSP shadow maps (trees, poles, buildings) reach it.
        RAIN_VISOR_LAYER_SHADOW_PROBE = true,
        RAIN_VISOR_LAYER_PROBE_ALBEDO = 0.05,  -- ksDiffuse of the probe
        RAIN_VISOR_LAYER_PROBE_GAIN = 1.0,     -- calibration of sun HDR
        RAIN_VISOR_LAYER_PROBE_STRENGTH = 1.0,
        RAIN_VISOR_LAYER_PROBE_MIN_NL = 0.12,
        RAIN_VISOR_LAYER_PROBE_MAX_DEPTH = 0.35, -- m: farther = not the probe
        RAIN_VISOR_LAYER_PROBE_DEBUG = false,
        RAIN_VISOR_LAYER_AMBIENT_MIP = 10.0,
        RAIN_VISOR_LAYER_SUN = 0.50,          -- x light colour (normalised)
        RAIN_VISOR_LAYER_GLASS_ALPHA = 0.00,  -- faint film of the glass layers
        RAIN_VISOR_LAYER_OPTICS = true, -- E2/E3 prototype, inner glass only








        RAIN_VISOR_LAYER_EXT_RELIEF = 1.0,


















        RAIN_VISOR_LAYER_OPTICS_NORMAL = 0.952,
        RAIN_VISOR_LAYER_OPTICS_REFRACTION_PX = 48.00,
        RAIN_VISOR_LAYER_OPTICS_BLUR_PX = 1.52, -- directional hairline split, not area blur
        RAIN_VISOR_LAYER_OPTICS_RIM_SHARPNESS = 3.96,
        RAIN_VISOR_LAYER_OPTICS_RIM_PEAK = 0.889,
        RAIN_VISOR_LAYER_OPTICS_LENS_GAIN = 0.85,
        RAIN_VISOR_LAYER_OPTICS_TRANSMISSION_LOSS = 0.53,
        RAIN_VISOR_LAYER_OPTICS_REFLECTION = 0.87,
        RAIN_VISOR_LAYER_OPTICS_REFLECTION_PX = 98.0,
        RAIN_VISOR_LAYER_OPTICS_INTERIOR = true,
        RAIN_VISOR_LAYER_OPTICS_INTERIOR_PX = 25.85,
        RAIN_VISOR_LAYER_OPTICS_INTERIOR_NORMAL = 1.78,
        RAIN_VISOR_LAYER_OPTICS_INTERIOR_BEND_PX = 16.0,
        RAIN_VISOR_LAYER_OPTICS_INTERIOR_SPLIT_PX = 1.34,
        RAIN_VISOR_LAYER_OPTICS_INTERIOR_BLUR_PX = 3.87,
        RAIN_VISOR_LAYER_OPTICS_INTERIOR_BLUR_AMOUNT = 1.00,
        RAIN_VISOR_LAYER_OPTICS_INTERIOR_SOFT_PX = 4.267,
        RAIN_VISOR_LAYER_OPTICS_INTERIOR_SOFT_AMOUNT = 0.5,
        RAIN_VISOR_LAYER_OPTICS_MASK_PREVIEW = false,
        RAIN_VISOR_LAYER_OPTICS_BRIGHTNESS = 0.73,
        RAIN_VISOR_LAYER_OPTICS_RELIEF_SPEC = 1.69,
        RAIN_VISOR_LAYER_OPTICS_RELIEF_GLOSS = 0.18,
        RAIN_VISOR_LAYER_OPTICS_RELIEF_SHADE = 0.75,
        RAIN_VISOR_LAYER_BAND_OPACITY = 1.00, -- top band blocks the scene (s55: was 0.92)
        RAIN_VISOR_LAYER_BAND_EXTERNAL_LIGHT = false,
        RAIN_VISOR_LAYER_BAND_UNLIT_BRIGHTNESS = 0.149,
        RAIN_VISOR_LAYER_BAND_ALPHA_MIN = 0.064, -- txDIFF alpha where the band starts (BC alpha < 1)
        RAIN_VISOR_LAYER_BORDER_GREY = 0.00,  -- BODY_INT_BORDER_GLASSLINE
        RAIN_VISOR_LAYER_CULL_FLIP = false,   -- single-sided parts: cull front
        -- V2 housing materials (docs/RAINFX_VISOR_LAYER.md §8)
        RAIN_VISOR_LAYER_NORMAL_FLIP_G = false,
        RAIN_VISOR_LAYER_FRAME_NORMAL = 1.76,
        RAIN_VISOR_LAYER_FRAME_SPEC = 1.03,
        RAIN_VISOR_LAYER_FRAME_GLOSS = 0.72,
        RAIN_VISOR_LAYER_RUBBER_NORMAL = 1.00,
        RAIN_VISOR_LAYER_RUBBER_SPEC = 0.50,
        RAIN_VISOR_LAYER_RUBBER_GLOSS = 0.50,
        RAIN_VISOR_LAYER_FABRIC_NORMAL = 1.00,
        RAIN_VISOR_LAYER_FABRIC_SHEEN = 0.74,
        RAIN_VISOR_LAYER_FABRIC_SHEEN_POWER = 1.0,
        RAIN_VISOR_LAYER_FABRIC_SPEC = 0.0,
        RAIN_VISOR_LAYER_FABRIC_GLOSS = 0.60,
        RAIN_VISOR_LAYER_FABRIC_LIT_LIFT = 1.75, -- s51: x spec x mask x N.L, direct light only
        -- s51: interior mirror. Overlay-drawn visor meshes are shown in the
        -- MIRROR pass (stock materials, coloured) and the grey shadow probe
        -- is hidden there; in the main pass it is the other way round.
        -- Meshes NOT drawn by the overlay always follow their Visible box.
        RAIN_VISOR_LAYER_MIRROR_STOCK = true,
        RAIN_DYNAMIC_SHOT_TONE_AERIAL_DENSITY = 0.004, -- 1/m: 1-exp(-d*k)
        RAIN_DYNAMIC_SHOT_TONE_AERIAL_MAX = 0.85,  -- cap for geometry
        RAIN_DYNAMIC_SHOT_TONE_SATURATION = 0.75,  -- geometry chroma kept
        RAIN_DYNAMIC_SHOT_TONE_CLOUD_CONTRAST = 0.25, -- sky detail (old rule)
        RAIN_DYNAMIC_SHOT_TONE_PREVIEW = false,    -- UI preview of the result
        -- v2 (docs/RAINFX_SHOT_TONE.md §v2): match the shot to THIS frame.
        -- 1 = aerial fog toward the fog colour (v1), 2 = frame match: the
        -- shot is multiplied by the low-frequency ratio frame / shot, read
        -- from dynamic::hdr inside the drop callback (before car glass and
        -- before our drops). Hue, fog and exposure come from the real frame,
        -- detail from the shot. v1 read too blue: fog colour is not the sky.
        RAIN_DYNAMIC_SHOT_TONE_MODE = 3,
        -- v3 (docs/RAINFX_STAGE_PROBE.md §result): 3 = frame-first composite.
        -- Per texel, the HDR frame of THIS frame (copied in the drop callback,
        -- before our drops and before car glass) is used wherever its depth
        -- agrees with the shot (same surface, or both sky); the shot fills
        -- what the frame lacks at that stage (root objects such as wipers)
        -- and what the frame has but must not refract (KN5 visor < 0.1 m).
        -- HDR stays in scene space, so post-processing tones it like the
        -- rest of the frame (no LDR double tone mapping).
        RAIN_DYNAMIC_SHOT_TONE_AGREE_LO = 0.04,   -- rel. depth diff: full frame
        RAIN_DYNAMIC_SHOT_TONE_AGREE_HI = 0.12,   -- rel. depth diff: full shot
        RAIN_DYNAMIC_SHOT_TONE_FRAME_DEPTH_REVERSED = false,
        -- Frame texel rejected when it is this much darker than the shot
        -- (depth present but colour not drawn yet at this stage: the black
        -- glove / wheel / glass rim seen in the interior view).
        RAIN_DYNAMIC_SHOT_TONE_FRAME_MIN_RATIO = 0.25,
        -- v4 (docs/RAINFX_NEAR_OBJECTS.md): the frame is NEARER than the shot
        -- and beyond this distance = a real object the shot does not draw
        -- (steering wheel, cockpit, hands: AC culls the interior in extra
        -- shots). Trust the frame there instead of falling back to the
        -- shot sky. Below it = helmet / KN5 visor parts (not refracted).
        -- Active only at the root.transparent draw stage (frame complete).
        RAIN_DYNAMIC_SHOT_TONE_NEAR_TRUST = true,
        RAIN_DYNAMIC_SHOT_TONE_NEAR_TRUST_MIN = 0.15, -- m
        -- s34: frame priority. At the root.transparent stage the frame holds
        -- every opaque object, so it is used wherever it has colour and lies
        -- beyond NEAR_TRUST_MIN; the shot only fills helmet / KN5 range.
        -- Fixes the wheel over the dashboard (shot cockpit differs from the
        -- main one). Trade-off: no car-glass tint from the shot.
        RAIN_DYNAMIC_SHOT_TONE_FRAME_PRIORITY = true,
        RAIN_DYNAMIC_SHOT_TONE_COMPOSE_DEBUG = false, -- green frame / red shot
        RAIN_DYNAMIC_SHOT_TONE_MATCH_MIP = 5,      -- shot mip of the ratio
        RAIN_DYNAMIC_SHOT_TONE_MATCH_STRENGTH = 1.0,
        RAIN_DYNAMIC_SHOT_TONE_MATCH_CHROMA = 1.0, -- 0 = luminance ratio only
        RAIN_DYNAMIC_SHOT_TONE_RATIO_MIN = 0.25,
        RAIN_DYNAMIC_SHOT_TONE_RATIO_MAX = 4.0,
        -- Veil / glint / flash colour (was the raw fog colour, too blue):
        -- fog colour with this much of its chroma kept (luminance kept).
        RAIN_DYNAMIC_FOG_TONE_SATURATION = 0.37,
        -- Car glass is drawn after every stage we can hook (track / root /
        -- smoke tested) and blends over the drops. A second, cheap pass
        -- writes visor depth where water or micro drops are, so that later
        -- glass behind the visor fails its depth test there. Its tint is
        -- still in the drops, since they refract the shot (with glass).
        -- It also gives TAA/DLSS a near (head-locked) depth there.
        RAIN_DYNAMIC_DROP_DEPTH_OCCLUDE = true,
        -- 2 = exact (the depth pass shades like the colour pass and writes
        -- depth where alpha >= ALPHA_MIN; follows wipes, recovery, films,
        -- region sheets; costs a second full shading of the visor layer),
        -- 1 = cheap gate (water height / micro class only).
        RAIN_DYNAMIC_DROP_DEPTH_OCCLUDE_MODE = 2,
        RAIN_DYNAMIC_DROP_DEPTH_ALPHA_MIN = 0.35,
        -- v4: 0 = off. > 0: pixels whose final alpha (haze, film, smear
        -- included) reaches this value also write depth, so car glass drawn
        -- later (wiper zone) cannot cover them. Loses the glass tint there.
        RAIN_DYNAMIC_DROP_HAZE_DEPTH_MIN = 0.0,
        -- Visor KN5 motion stencil (CSP: 1 = reduced TAA, 0.5 = extra TAA,
        -- < 0 = untouched). Anti-ghosting test for fast camera motion.
        RAIN_VISOR_MOTION_STENCIL = -1.0,
        -- DLSS shimmer diagnosis (docs/RAINFX_VISOR_GLASS.md §6). Every KN5
        -- mesh of the visor shimmers, even a plain diffuse one, while the
        -- render.mesh drops do not: the suspect is the per-node motion
        -- (previous world transform) of the camera-locked hierarchy.
        -- T1: clear the stored motion of the whole chain every frame.
        RAIN_VISOR_MOTION_TEST_CLEAR = false,
        -- T2: re-apply the camera transform at render time
        -- ('main.track.opaque'), after every camera script has run.
        RAIN_VISOR_MOTION_TEST_LATE = false,
        -- T3: draw this one KN5 mesh ourselves with render.mesh (flat lit
        -- test shader) and hide it in the normal pass. '' = off.
        -- Example: 'GLASS_COATING_REFL'. Compare it with its neighbours under DLSS.
        RAIN_VISOR_REDRAW_TEST_MESH = '',     -- diagnostic only: keep '' in normal use
        RAIN_DYNAMIC_DROP_SHOT_NEAR = 0.10, -- metres (>= camera near clip)
        -- Leave three empty frames before each diagnostic draw to check
        -- whether HDR/LDR contains droplets from earlier frames.
        RAIN_DYNAMIC_DROP_SPARSE_FRAME_DEBUG = false,
        -- Compare live HDR with an opaque-pass copy if needed.
        RAIN_DYNAMIC_DROP_HDR_SNAPSHOT_DEBUG = false,
        -- Render the scene again without the hidden transport mesh to test
        -- a source that cannot contain previous droplet draws.
        RAIN_DYNAMIC_DROP_GEOMETRY_SHOT_DEBUG = true,
        -- Keep the best empirical scale as a reference against projection.
        
        RAIN_DYNAMIC_STATE_VELOCITY_ENCODE_RANGE = 0.125,
        RAIN_DYNAMIC_STATE_PREDICTION_MAX_SECONDS = 0.05,
        
        -- accessData() currently returns with a measured fixed ~10-frame
        -- latency on the target CSP build. Keep more slots than that latency
        -- so one asynchronous readback can be issued every render frame.
        RAIN_DYNAMIC_STATE_READBACK_RING_SIZE = 16,
        
        -- Cadence instrumentation is validated (10-frame async latency with
        -- one completed snapshot and one mesh update every frame). Keep the
        -- counters available but silence periodic logging for normal testing.
        RAIN_DYNAMIC_STATE_CADENCE_DEBUG = false,
        
        RAIN_DYNAMIC_SURFACE_TEST_DROPLET_DIAMETER_MM = 1.50,
        RAIN_DYNAMIC_SURFACE_TEST_OFFSET_M = 0.00005,
        RAIN_DYNAMIC_SURFACE_TEST_UV_BUCKETS = 32,
        
        RAIN_DEBUG = 0,
        RAIN_PERFORMANCE_PROFILING = false, -- optional CPU clocks and diagnostic counters
        

        AVG_TIME_X_MIN = 0.0,
        AVG_TIME_X_MAX = 0.0,
        AVG_TIME_Y_MIN = 0.0,
        AVG_TIME_Y_MAX = 0.0,
        AVG_TIME_N_MIN = 0.0,
        AVG_TIME_N_MAX = 0.0,
    },
})


------------------------------------------------------------
-- Hardcoded profile defaults
--
-- This table is the single source of truth for Reset.
------------------------------------------------------------

local DEFAULT_PROFILE1 = {
    
    PITCH = 0.0000,
    YAW   = 0.0000,
    ROLL  = 0.0000,

    OFFSET_X = 0.0000,
    OFFSET_Y = 0.0000,
    OFFSET_Z = -0.1033,

    SCALE = 1.0000,

    NEARCLIP = 0.0181,

    ENABLE_MOTION   = 1,
    
    MOTION_GAIN_X   = 0.00009,
    MOTION_GAIN_Y   = 0.00006,
    MOTION_GAIN_Z   = 0.00007,
    
    MOTION_SMOOTHING = 30.0,
    MOTION_SHARPNESS = 1.11,
    
    MOTION_LIMIT_X  = 0.025,
    MOTION_LIMIT_Y  = 0.020,
    MOTION_LIMIT_Z  = 0.020,

    HIDE_DRIVER_HELMET = 1,
}


local DEFAULT_PROFILE2 = {
    
    PITCH = -0.2200,
    YAW   = -19.2700,
    ROLL  = -6.3800,

    OFFSET_X = 0.1089,
    OFFSET_Y = -0.0040,
    OFFSET_Z = -0.0594,

    SCALE = 1.0000,

    NEARCLIP = 0.0081,

    ENABLE_MOTION   = 1,
    
    MOTION_GAIN_X   = 0.00009,
    MOTION_GAIN_Y   = 0.00006,
    MOTION_GAIN_Z   = 0.00007,
    
    MOTION_SMOOTHING = 30.0,
    MOTION_SHARPNESS = 1.11,
    
    MOTION_LIMIT_X  = 0.025,
    MOTION_LIMIT_Y  = 0.020,
    MOTION_LIMIT_Z  = 0.020,

    HIDE_DRIVER_HELMET = 1,
}


------------------------------------------------------------
-- Scene references
------------------------------------------------------------

local carsRoot = nil

local cameraAnchor = nil    -- Temporal Crash Patches v2.0.0 Restore

local cameraRoot = nil
local offsetNode = nil
local motionNode = nil
local scaleNode = nil
local axisPitchNode = nil
local axisYawNode = nil
local axisRollNode = nil

local visor = nil


------------------------------------------------------------
-- Runtime state
------------------------------------------------------------


local initialized = false

local shaderInitialized = false

local materialInputApplyRequested = false   -- It helps to trigger when you presses 'Enter' on inputtext


    --------------------------------------------------------
    -- v0.5.0 Real Neck CameraFX
    --------------------------------------------------------
    
    local driverNeck = nil      --  Store 1st neck

    local driverNecks = {}      --  Debug: Store all neck found 
    local driverHeads = {}      --  Visiblilty control : we need to get all driver heads to hide them completely

    local headFoundLogged = false
    local nekFoundLogged = false
    
    
    --------------------------------------------------------
    -- v0.6.0 Rain Drop 
    --------------------------------------------------------
    local rainTargetMesh = nil


    ------------------------------------------------------------
    -- Head Observation State
    ------------------------------------------------------------

    local function createRealCamDebugState()
        return {
            referencePosition = nil,
            previousPosition = nil,
        
            referenceLook = nil,
            previousLook = nil,
        
            referenceUp = nil,
            previousUp = nil,
        
            debugTimer = 0,
        }
    end

    local realCamDebugStates = {}


------------------------------------------------------------
-- Material editor state (VISOR_GLASS_EXT_DIRT prototype)
------------------------------------------------------------

local materialEditWindowOpen = false    -- Visibility flag for the floating material editor window


------------------------------------------------------------
-- Motion state
------------------------------------------------------------

local previousVelocity = nil
    
local motionCurrent = vec3(
    0,
    0,
    0
)


--------------------------------------------------------
-- Rain flow state
--------------------------------------------------------

local rainAccelerationCurrent = vec3(0, 0, 0)
local rainLastDebugMode = nil
local rainRenderDiagnosticLogged = false


------------------------------------------------------------
-- RainFX persistent GPU state
--
-- Stage 1:
--   ExtraCanvas A -> physics shader -> B
--   ExtraCanvas B -> physics shader -> A
--
-- Each texel currently stores:
--   RG = position
--   BA = velocity
--
-- The state texture is intentionally independent from the
-- procedural droplet renderer until persistence is verified.
------------------------------------------------------------

local rainStateA = nil
local rainStateB = nil
local rainStateMetaA = nil
local rainStateMetaB = nil
local rainStateReadIsA = true
local rainStateInitialized = false
local rainStateLastFrame = -1
local rainStateConfiguredMode = nil
local rainStateSingleDropDirty = false

------------------------------------------------------------
-- RainFX debug UI option labels
--
-- The UI uses combo indices, while cfg.RUNTIME keeps the original
-- numeric debug/state values so shader branches and diagnostics do
-- not need to change when the UI wording changes.
------------------------------------------------------------
local RAIN_DEBUG_OPTIONS = {
    '[0] RainFX — canonical full effect',
    '[1] Local surface normal (object-space RGB)',
    '[2] World surface normal (world-space RGB)',
    '[3] Boundary mask',
    '[4] Predicted positions',
    '[5] Force direction',
    '[6] Physical state viewer'
}



local RAIN_GPU_STATE_MODE_OPTIONS = {
    '[0] Disabled',
    '[1] Initialize only',
    '[3] Canonical physics + rain lifecycle',
    '[4] Canonical persistent physics + 3x3 physical-size diagnostic',
    '[6] Boundary lifecycle comparison (rain lifecycle active)',
    '[7] Single persistent droplet position probe',
    '[10] Canonical physical 9-drop validation'
}


local rainStateUpdateParams = {
    defines = { RAIN_GPU_STATE_PASS = true,
        RAIN_MERGE_CODE = cfg.RUNTIME.RAIN_GPU_STATE_MERGE_SHADER,
        RAIN_WETPATH_CODE = cfg.RUNTIME.RAIN_GPU_STATE_WETPATH_SHADER },

    textures = {
        txRainState = false,
        txRainStateMeta = false,
        txRainSurfaceNormal = false,
        txRainBoundaryMask = false,
        txRainSpawnAtlas = false,
        txRainMergeCmd = false,
        txRainWetPath = false,
    },

    values = {
        gRainWetPathGain = 0.0,
        gRainWetPathMinSpeed = 0.004,
        gRainWetPathTexel = 1.0 / 1024.0,
        gRainWetPathAhead = 1.5,
        gRainSteerTurnRate = 1.5,
        gRainBirthHold = 0.6,
        gRainBirthRamp = 1.2,
        gRainStateDeltaTime = 0.0,
        gRainStateCount = 256.0,
        gRainAcceleration = vec3(0.0, 0.0, 0.0),
        gRainForceMask = 0.0,
        gRainPhysicsAccelScale = cfg.RUNTIME.RAIN_PHYSICS_ACCEL_SCALE,
        gRainGravityGain = cfg.RUNTIME.RAIN_FORCE_GRAVITY_GAIN,
        gRainInertiaGain = cfg.RUNTIME.RAIN_FORCE_INERTIA_GAIN,
        gRainAirflowGain = cfg.RUNTIME.RAIN_FORCE_AIRFLOW_GAIN,
        gRainAirflowDownwardMode =
            cfg.RUNTIME.RAIN_AIRFLOW_DOWNWARD_MODE and 1.0 or 0.0,
        gRainAirflowDownwardGain =
            cfg.RUNTIME.RAIN_AIRFLOW_DOWNWARD_GAIN,
        gRainAirVelocityWorld = vec3(0.0, 0.0, 0.0),
        gRainAirDensity = cfg.RUNTIME.RAIN_AIR_DENSITY,
        gRainAirDragCoeff = cfg.RUNTIME.RAIN_AIR_DRAG_COEFF,
        gRainStatePhysicalDiameterUVPerMM =
            cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM,
        gRainStatePhysicalMaxSpeed1MM =
            cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_1MM,
        gRainStatePhysicalMaxSpeedExponent =
            cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_EXPONENT,
        gRainStateFlowAcceleration = cfg.RUNTIME.RAIN_FLOW_ACCELERATION,
        gRainStateFlowSpeedScale = cfg.RUNTIME.RAIN_FLOW_SPEED_SCALE,
        gRainStateFlowDrag = cfg.RUNTIME.RAIN_FLOW_DRAG,
        gRainStateGravity = 9.81,
        gRainStateAdhesionMin = cfg.RUNTIME.RAIN_ADHESION_MIN,
        gRainStateAdhesionMax = cfg.RUNTIME.RAIN_ADHESION_MAX,
        gRainObjectToWorld = mat4x4.identity(),
        gRainStateInit = 0.0,
        gRainSpawnAtlasEnabled = 0.0,
        gRainStatePhysics = 0.0,
        gRainStatePhysicalTest = 0.0,
        gRainStatePhysicalGridTest = 0.0,
        gRainStateLifecycle = 0.0,
        gRainStateBoundaryMargin = 0.005,
        gRainStateMobileSpeedMultiplier =
            cfg.RUNTIME.RAIN_GPU_STATE_MOBILE_SPEED_MULTIPLIER,
        gRainStateMobileDrag = cfg.RUNTIME.RAIN_GPU_STATE_MOBILE_DRAG,
        gRainStateKineticAdhesionFraction =
            cfg.RUNTIME.RAIN_GPU_STATE_KINETIC_ADHESION_FRACTION,
        gRainStateMovingForceGain =
            cfg.RUNTIME.RAIN_GPU_STATE_MOVING_FORCE_GAIN,
        gRainStateMobileThresholdUV =
            cfg.RUNTIME.RAIN_GPU_STATE_MOBILE_THRESHOLD_UV,
        gRainStateTravelMix = 0.0,
        gRainStateAgeMin = 8.0,
        gRainStateAgeMax = 18.0,
        gRainStateSingleDropTest = 0.0,
        gRainStateSingleDropPosition = vec2(
            cfg.RUNTIME.RAIN_GPU_STATE_SINGLE_DROP_X,
            cfg.RUNTIME.RAIN_GPU_STATE_SINGLE_DROP_Y
        ),
        gRainMergeEnabled = 0.0,
        gRainMergeReach = 0.85,
        gRainAttractReach = 1.6,
        gRainAttractGain = 0.03,
        gRainMergeMaxDiameterMM = 5.0,
    },

    shader = [[
        SamplerState samPointRain {
            Filter = MIN_MAG_MIP_POINT;
            AddressU = CLAMP;
            AddressV = CLAMP;
            AddressW = CLAMP;
        };

        SamplerState samLinearRain {
            Filter = MIN_MAG_MIP_LINEAR;
            AddressU = CLAMP;
            AddressV = CLAMP;
            AddressW = CLAMP;
        };

        float rainStateHash(float n) {
            return frac(sin(n * 127.1 + 311.7) * 43758.5453);
        }

        float2 rainStateSpawnHash(float seed)
        {
            float n = fmod(seed, 4096.0);
            float3 p = frac(float3(n, n + 19.19, n + 71.71)
                * float3(0.1031, 0.11369, 0.13787));
            p += dot(p, p.yzx + 33.33);
            return frac((p.xx + p.yz) * p.zy);
        }

        /*
            The supplied boundary mask uses the same mesh UV space as the
            visor surface-normal texture:
                R >= 0.5 : valid droplet surface
                R <  0.5 : outside / invalid

            Persistent state position is already raw visor UV. The boundary mask is sampled directly in that coordinate system.
        */
        float rainStateBoundaryMask(float2 position)
        {
            // Boundary validity is defined directly by the mask in raw UV.
            // Reject positions outside the signed visor UV domain before
            // CLAMP sampling so an out-of-domain state cannot appear valid.
            if (
                position.x < 0.0
                || position.x > 1.0
                || position.y < -1.0
                || position.y > 0.0
            ) {
                return 0.0;
            }

            return txRainBoundaryMask.SampleLevel(
                samLinearRain,
                position,
                0.0
            ).r;
        }

        /*
            Spread initial positions across the visor. On later births,
            compare valid candidates against a bounded sample of living
            drops, so short lifetimes do not repeatedly fill a few spots.
            Only births pay for the additional texture reads.
        */
        float2 rainStateFindValidPosition(
            float stateIndex,
            float cycleSeed,
            float2 previousPosition
        )
        {
            float2 best = float2(0.5, -0.5);
            float bestClearance = -1.0;
            int validCount = 0;
            // Only about a fifth of the boundary texture is usable visor.
            // Stop after eight valid choices; a hard cap also handles an
            // absent or malformed mask without an unbounded shader loop.
            [loop] for (int attempt = 0; attempt < 128; ++attempt)
            {
                float2 anchor = frac(float2(
                    (stateIndex + 0.5) * 0.61803398875
                        + cycleSeed * 0.38196601125,
                    (stateIndex + 0.5) * 0.75487766625
                        + cycleSeed * 0.56984029099));
                float2 jitter = rainStateSpawnHash(
                    stateIndex * 11.0 + cycleSeed * 173.0
                        + (float)attempt * 271.0);
                float reach = min(0.18 + floor(attempt / 16) * 0.18,
                    1.0);
                float2 sampleUV = frac(anchor + (jitter - 0.5) * reach);
                float2 candidate = float2(sampleUV.x, -sampleUV.y);

                if (rainStateBoundaryMask(candidate) < 0.5)
                {
                    continue;
                }

                if (gRainStateInit > 0.5)
                {
                    return candidate;
                }
                validCount += 1;

                float clearance = 1.0;
                float count = max(gRainStateCount, 1.0);
                [loop] for (int probe = 0; probe < 16; ++probe)
                {
                    float otherIndex = fmod(
                        stateIndex + 1.0 + (float)probe * 37.0
                            + (float)attempt * 53.0,
                        count);
                    float2 uv = float2((otherIndex + 0.5) / count, 0.5);
                    float4 otherMeta = txRainStateMeta.SampleLevel(
                        samPointRain, uv, 0.0);
                    float otherGeneration = floor(otherMeta.a * 0.25);
                    float otherStatus = otherMeta.a - otherGeneration * 4.0;
                    if (otherStatus < 0.5 || otherStatus > 1.5)
                    {
                        continue;
                    }
                    float2 otherPosition = txRainState.SampleLevel(
                        samPointRain, uv, 0.0).rg;
                    float2 delta = candidate - otherPosition;
                    clearance = min(clearance,
                        dot(delta, delta) - otherMeta.r * otherMeta.r);
                }
                if (clearance > bestClearance)
                {
                    best = candidate;
                    bestClearance = clearance;
                }
                if (validCount >= 8)
                {
                    break;
                }
            }

            if (validCount > 0)
            {
                return best;
            }
            // A transient failed search should never turn a previously
            // valid drop into a new birth at the fixed visor center.
            return rainStateBoundaryMask(previousPosition) >= 0.5
                ? previousPosition : best;
        }

        /*
            Stage 7C physical max-speed model.

            Research reference:
                V_terminal(D) ~= 3.778 * D^0.67

            D is diameter in millimeters and V is free-fall speed in m/s.
            That relationship is NOT copied as an absolute visor speed.
            Only the observed size dependence is retained. The 1 mm surface
            speed is calibrated independently in Lua as UV/s.

            Current physical-reference radius is already expressed in raw
            visor UV, so diameter can be recovered exactly from the measured
            1 mm diameter = 0.0029296875 UV relationship.
        */
        float rainStatePhysicalMaxSpeed(
            float radius
        )
        {
            if (radius <= 0.000001)
            {
                return 0.0;
            }

            float diameterUV =
                radius * 2.0;

            float diameterMM =
                diameterUV
                / max(
                    gRainStatePhysicalDiameterUVPerMM,
                    0.000001
                );

            diameterMM =
                clamp(
                    diameterMM,
                    0.5,
                    6.0
                );

            float sizeFactor =
                pow(
                    diameterMM,
                    gRainStatePhysicalMaxSpeedExponent
                );

            return
                max(
                    gRainStatePhysicalMaxSpeed1MM,
                    0.0
                )
                * sizeFactor;
        }

        float rainStateMaxSpeedValue(
            float radius
        )
        {
            return rainStatePhysicalMaxSpeed(radius);
        }

        float3 rainStateNormalWorld(float2 p) {
            float3 n = txRainSurfaceNormal.SampleLevel(
                samLinearRain, p, 0.0
            ).rgb * 2.0 - 1.0;

            n = normalize(n);
            return normalize(mul(n, (float3x3)gRainObjectToWorld));
        }

        float2 rainStateProjectForce(float3 forceWorld, float3 normalWorld) {
            float3 normalObject = normalize(
                mul(normalWorld, transpose((float3x3)gRainObjectToWorld))
            );

            float3 u = float3(1.0, 0.0, 0.0);
            u -= normalObject * dot(u, normalObject);

            if (length(u) < 0.0001) {
                u = float3(0.0, 0.0, 1.0);
                u -= normalObject * dot(u, normalObject);
            }

            u = normalize(u);

            /*
                Signed visor-V contract:
                    object-space -Y is the canonical increasing mesh-V direction.

                The persistent state pass cannot use ddx/ddy to recover the
                actual dP/dV tangent, so the normal-derived basis needs an
                explicit orientation check.  cross(normal, U) produces a
                right-handed tangent frame, but its V axis can be opposite to
                the mesh UV V direction.  Align V with object-space -Y while
                keeping the already-validated U orientation unchanged.
            */
            float3 v = normalize(cross(normalObject, u));
            float3 canonicalV = float3(0.0, -1.0, 0.0);
            if (dot(v, canonicalV) < 0.0)
            {
                v = -v;
            }

            float3 uWorld = normalize(mul(u, (float3x3)gRainObjectToWorld));
            float3 vWorld = normalize(mul(v, (float3x3)gRainObjectToWorld));

            return float2(dot(forceWorld, uWorld), dot(forceWorld, vWorld));
        }

        /*
            Consolidated baseline external force entry point.

            Gravity and vehicle acceleration are part of the persistent
            physics baseline. Air drag is intentionally kept outside this
            function because the verified Debug 31 airflow value is an
            incoming relative-air velocity, not a complete drag force.
            Production drag must oppose the droplet's surface velocity.
        */
        /*
            Persistent physics is kept as an explicit pipeline.

            The current tangent basis is intentionally unchanged from the
            validated Debug 36 implementation: object-space X is projected
            onto the local surface normal and V is derived by cross product.
            This is the part that will be replaced when a true mesh-UV tangent
            source is introduced; it must not be silently changed here.
        */
        /*
            Unified external-force pipeline.

            Source domains:
              Gravity  : world m/s^2, directed by the simulation gravity.
              Inertia  : world m/s^2, already sign-inverted in Lua from the
                         vehicle's car-local G acceleration.
              Airflow  : world-relative air velocity, converted here to an
                         aerodynamic acceleration using SI water-drop mass.

            Bitmask:
              1 = gravity
              2 = vehicle inertia
              4 = airflow

            All enabled sources are summed in WORLD space first. Only then is
            the single surface-normal/tangent projection performed.
        */
        float3 rainStateAirflowAccelerationWorld(
            float3 normalWorld,
            float radius
        )
        {
            float speed = length(gRainAirVelocityWorld);
            if (speed < 0.0001)
                return float3(0.0, 0.0, 0.0);

            float diameterMM =
                max(
                    (radius * 2.0)
                    / max(gRainStatePhysicalDiameterUVPerMM, 0.000001),
                    0.0
                );

            float diameterM = diameterMM * 0.001;
            float radiusM = diameterM * 0.5;
            float area = 3.14159265 * radiusM * radiusM;
            float volume = (4.0 / 3.0) * 3.14159265 * radiusM * radiusM * radiusM;
            float massKg = max(volume * 1000.0, 0.000000000001);

            float3 airDir = gRainAirVelocityWorld / speed;

            /*
                One-sided surface incidence:
                the air must travel into the surface normal side.
                The normal component is ultimately cancelled by the rigid
                visor; the incidence factor controls aerodynamic pressure.
            */
            float incidence =
                saturate(
                    -dot(
                        airDir,
                        normalWorld
                    )
                );

            if (incidence <= 0.000001)
                return float3(0.0, 0.0, 0.0);

            float dragForce =
                0.5
                * max(gRainAirDensity, 0.0)
                * speed
                * speed
                * max(gRainAirDragCoeff, 0.0)
                * area
                * incidence;

            return
                (gRainAirVelocityWorld / speed)
                * (dragForce / massKg);
        }

        float3 rainStateExternalForceWorld(
            float3 normalWorld,
            float radius,
            out float3 airWorld
        )
        {
            float3 forceWorld = float3(0.0, 0.0, 0.0);
            airWorld = float3(0.0, 0.0, 0.0);

            if (fmod(floor(gRainForceMask), 2.0) >= 0.5)
                forceWorld +=
                    float3(0.0, -gRainStateGravity, 0.0)
                    * gRainPhysicsAccelScale * gRainGravityGain;

            if (fmod(floor(gRainForceMask / 2.0), 2.0) >= 0.5)
                forceWorld +=
                    gRainAcceleration
                    * gRainPhysicsAccelScale * gRainInertiaGain;

            if (fmod(floor(gRainForceMask / 4.0), 2.0) >= 0.5)
            {
                airWorld =
                    rainStateAirflowAccelerationWorld(
                        normalWorld,
                        radius
                    )
                    * gRainPhysicsAccelScale * gRainAirflowGain;
                forceWorld += airWorld;
            }

            return forceWorld;
        }

        float2 rainStateSurfaceForce(
            float2 position,
            float radius,
            out float forceMagnitude
        )
        {
            float3 normalWorld =
                rainStateNormalWorld(position);

            float3 airWorld;
            float3 forceWorld =
                rainStateExternalForceWorld(
                    normalWorld,
                    radius,
                    airWorld
                );

            float2 tangentForce =
                rainStateProjectForce(
                    forceWorld,
                    normalWorld
                );

            if (gRainStateLifecycle > 0.5
                && fmod(floor(gRainForceMask), 2.0) >= 0.5)
            {
                // Existing projection may face -V on this visor. Correct
                // only the falling contribution, leaving car inertia and
                // airflow free to respond to their actual directions.
                float2 gravity = rainStateProjectForce(
                    float3(0.0, -gRainStateGravity, 0.0)
                        * gRainPhysicsAccelScale * gRainGravityGain,
                    normalWorld);
                tangentForce.y += abs(gravity.y) - gravity.y;
            }

            if (gRainStateLifecycle > 0.5
                && gRainAirflowDownwardMode > 0.5
                && fmod(floor(gRainForceMask / 4.0), 2.0) >= 0.5)
            {
                float2 airTangent = rainStateProjectForce(
                    airWorld, normalWorld);
                float speed = length(gRainAirVelocityWorld);
                float referenceGravity = max(gRainStateGravity
                    * gRainPhysicsAccelScale, 0.1);
                float cap = referenceGravity * (1.0
                    + min(speed / 20.0, 4.0)
                        * max(gRainAirflowDownwardGain, 0.0));
                float downward = min(length(airWorld) * 0.30
                    * max(gRainAirflowDownwardGain, 0.0), cap);
                downward = max(downward, abs(airTangent.x)
                    * max(gRainAirflowDownwardGain, 0.0) * 0.65);
                // Leave projected X untouched; replace only airflow V.
                // Increasing signed V moves toward the visor bottom.
                tangentForce.y += downward - airTangent.y;
            }

            forceMagnitude =
                length(tangentForce);

            return tangentForce;
        }

        float rainStateAdhesion(
            float stateIndex,
            float mass
        )
        {
            float adhesionBase =
                lerp(
                    gRainStateAdhesionMin,
                    gRainStateAdhesionMax,
                    rainStateHash(stateIndex + 211.0)
                );

            return
                adhesionBase
                / sqrt(max(mass, 0.000001));
        }

        float2 rainStateFlowAcceleration(
            float2 tangentForce,
            float forceMagnitude,
            float adhesion,
            float dt
        )
        {
            float excess =
                max(
                    forceMagnitude - adhesion,
                    0.0
                );

            if (
                excess <= 0.000001
                || forceMagnitude <= 0.000001
            )
            {
                return float2(0.0, 0.0);
            }

            float2 direction =
                tangentForce
                / forceMagnitude;

            /*
                Flow acceleration is already expressed in normalized
                persistent-state coordinates. Do not divide it by the
                procedural UV cell scale: that scale describes the rain
                pattern density, not the physical state coordinate unit.

                Keeping these domains separate is important because an
                increase in procedural cell density must not make a real
                droplet physically slower.
            */
            float acceleration =
                excess
                * gRainStateFlowAcceleration
                * max(gRainStateFlowSpeedScale, 0.0);

            return
                direction
                * acceleration
                * dt;
        }

        float2 rainStateApplyDrag(
            float2 velocity,
            float forceMagnitude,
            float adhesion,
            float dt,
            float mobile
        )
        {
            // Ordinary flow drag and kinetic adhesion apply from birth.
            float drag = lerp(gRainStateFlowDrag,
                max(gRainStateMobileDrag, 0.0), mobile);

            if (forceMagnitude <= adhesion && mobile < 0.5)
            {
                velocity *=
                    exp(
                        -drag
                        * 2.0
                        * dt
                    );
            }

            velocity *=
                exp(
                    -max(drag, 0.0)
                    * dt
                );

            return velocity;
        }

        float2 rainStateClampSpeed(
            float2 velocity,
            float radius,
            float mobile
        )
        {
            float speed =
                length(velocity);

            float maxSpeed =
                rainStateMaxSpeedValue(radius)
                * lerp(1.0,
                    max(gRainStateMobileSpeedMultiplier, 1.0),
                    mobile * gRainStateTravelMix);

            if (
                speed
                > maxSpeed
            )
            {
                velocity =
                    velocity
                    / max(
                        speed,
                        0.000001
                    )
                    * maxSpeed;
            }

            return velocity;
        }

        float2 rainStateIntegratePosition(
            float2 position,
            float2 velocity,
            float dt
        )
        {
            /*
                Persistent state coordinates are raw visor UV coordinates.
                Boundary lifecycle owns exit/death/respawn explicitly, so
                this integration function never wraps or clamps the result.
            */
            return position + velocity * dt;
        }

        float2 rainStateRespawnPosition(
            float stateIndex,
            float respawnCycle,
            float2 previousPosition
        )
        {
            if (gRainSpawnAtlasEnabled > 0.5)
            {
                int count = (int)max(gRainStateCount, 1.0);
                int site = ((int)stateIndex + (int)respawnCycle * 37) % count;
                float4 prelaid = txRainSpawnAtlas.Load(int3(site, 0, 0));
                float2 pos = float2(prelaid.r, prelaid.g - 1.0);
                if (prelaid.a > 0.5 && rainStateBoundaryMask(pos) >= 0.5)
                    return pos;
            }
            return rainStateFindValidPosition(
                stateIndex,
                respawnCycle,
                previousPosition
            );
        }

        float4 rainStateUpdatePhysics(
            float2 position,
            float2 velocity,
            float radius,
            float mass,
            float stateIndex,
            float dt
        )
        {
            float forceMagnitude = 0.0;

            float2 tangentForce =
                rainStateSurfaceForce(
                    position,
                    radius,
                    forceMagnitude
                );

            float adhesion =
                rainStateAdhesion(
                    stateIndex,
                    mass
                );

            // Motion overcomes static pinning: rolling water sees a much
            // smaller resistance until it actually slows to a stop.
            float mobile = gRainStateLifecycle > 0.5
                ? smoothstep(0.001,
                    max(gRainStateMobileThresholdUV, 0.0011),
                    length(velocity)) : 0.0;
            float movingAdhesion = lerp(adhesion,
                adhesion * saturate(gRainStateKineticAdhesionFraction),
                mobile);
            float movingForce = forceMagnitude;

            velocity +=
                rainStateFlowAcceleration(
                    tangentForce,
                    movingForce,
                    movingAdhesion,
                    dt
                ) * lerp(1.0,
                    max(gRainStateMovingForceGain, 0.0), mobile);

            velocity =
                rainStateApplyDrag(
                    velocity,
                    forceMagnitude,
                    movingAdhesion,
                    dt,
                    mobile
                );

            velocity =
                rainStateClampSpeed(
                    velocity,
                    radius,
                    mobile
                );

            position =
                rainStateIntegratePosition(
                    position,
                    velocity,
                    dt
                );

            return float4(
                position,
                velocity
            );
        }


        // Mass coalescence + absorption steering (docs/RAINFX_COALESCENCE.md).
        // Compiled only with RAIN_MERGE_CODE (cfg RAIN_GPU_STATE_MERGE_SHADER).
        // Per-slot command texel written by Lua from the async readback:
        // R,G = partner index (hi, lo byte), B = type * 64 + generation % 64
        // of the PARTNER (type 1 = mutual merge, 2 = attract to partner).
        // Straight-line (no early returns): FXC overflowed its stack on the
        // first, branch-heavy version inside the already large state shader.
#ifdef RAIN_MERGE_CODE
        float rainMergePartner(float4 cmd)
        {
            return floor(cmd.r * 255.0 + 0.5) * 256.0
                + floor(cmd.g * 255.0 + 0.5);
        }

        // Returns x = type (0 none), y = partner, z = valid, w = survivor.
        float4 rainMergeDecode(float index, float count, float selfGen,
            float2 selfP, float selfR, out float4 pState, out float4 pMeta)
        {
            float4 cmd = txRainMergeCmd.SampleLevel(samPointRain,
                float2((index + 0.5) / count, 0.5), 0.0);
            float code = floor(cmd.b * 255.0 + 0.5);
            float type = floor(code / 64.0);
            float genLow = code - type * 64.0;
            float partner = clamp(rainMergePartner(cmd), 0.0, count - 1.0);
            float2 puv = float2((partner + 0.5) / count, 0.5);
            pMeta = txRainStateMeta.SampleLevel(samPointRain, puv, 0.0);
            pState = txRainState.SampleLevel(samPointRain, puv, 0.0);
            float4 pCmd = txRainMergeCmd.SampleLevel(samPointRain, puv, 0.0);
            float pGen = floor(pMeta.a * 0.25);
            float pStatus = pMeta.a - pGen * 4.0;
            float pCode = floor(pCmd.b * 255.0 + 0.5);
            float pType = floor(pCode / 64.0);
            float pGenLow = pCode - pType * 64.0;
            float dist = length(pState.rg - selfP);
            float sumR = selfR + pMeta.r;
            float ok = (type > 0.5 ? 1.0 : 0.0)
                * (abs(partner - index) > 0.5 ? 1.0 : 0.0)
                * (abs(pStatus - 1.0) < 0.5 ? 1.0 : 0.0)
                * (abs(fmod(pGen, 64.0) - genLow) < 0.5 ? 1.0 : 0.0)
                * (gRainMergeEnabled > 0.5 ? 1.0 : 0.0);
            float mutual = (abs(pType - 1.0) < 0.5 ? 1.0 : 0.0)
                * (abs(rainMergePartner(pCmd) - index) < 0.5 ? 1.0 : 0.0)
                * (abs(fmod(selfGen, 64.0) - pGenLow) < 0.5 ? 1.0 : 0.0);
            float mergeValid = ok * mutual
                * (type < 1.5 ? 1.0 : 0.0)
                * (dist <= sumR * gRainMergeReach ? 1.0 : 0.0);
            float attractValid = ok
                * (type > 1.5 ? 1.0 : 0.0)
                * (dist > 1e-7 ? 1.0 : 0.0)
                * (dist < sumR * gRainAttractReach ? 1.0 : 0.0);
            float survivor = (selfR > pMeta.r
                || (selfR == pMeta.r && index < partner)) ? 1.0 : 0.0;
            return float4(type, partner, max(mergeValid, attractValid),
                survivor);
        }

        float rainMergeRadius(float selfR, float partnerR)
        {
            // Same contact angle: footprint radius scales with volume^(1/3).
            float merged = pow(max(selfR * selfR * selfR
                + partnerR * partnerR * partnerR, 1e-15), 1.0 / 3.0);
            return min(merged, gRainMergeMaxDiameterMM * 0.00146484375);
        }

        float rainMergeMassProfile(float diameterMM)
        {
            float volumeMin = 0.5 * 0.5 * 0.5;
            float volumeMax = 6.0 * 6.0 * 6.0;
            float volume = diameterMM * diameterMM * diameterMM;
            return lerp(1.0, 9.0, saturate((volume - volumeMin)
                / (volumeMax - volumeMin)));
        }
#endif

        float4 main(PS_IN pin) {
            float count = max(gRainStateCount, 1.0);
            float index = min(floor(pin.Tex.x * count), count - 1.0);
            float2 suv = float2((index + 0.5) / count, 0.5);

            if (gRainStateInit > 0.5) {

                if (gRainStateSingleDropTest > 0.5) {
                    return float4(gRainStateSingleDropPosition.x, gRainStateSingleDropPosition.y , 0.0, 0.0);
                }

                if (gRainStatePhysicalTest > 0.5 && index < 9.0)
                {
                    float u = lerp(0.250, 0.750, index / 8.0);

                    return float4(
                        u,
                        -0.500,
                        0.0,
                        0.0
                    );
                }

                if (gRainStatePhysicalGridTest > 0.5 && index < 9.0) {
                    const float measuredX[3] = {
                        0.250, 0.500, 0.750
                    };

                    const float measuredY[3] = {
                        -0.600, -0.500, -0.450
                    };

                    int i = (int)index;
                    int ix = i % 3;
                    int iy = i / 3;

                    // Debug 36 test points are raw visor UV values.
                    // Legacy calibration values only constrain this fixed
                    // measurement set; they do not remap state coordinates.
                    return float4(measuredX[ix], measuredY[iy], 0.0, 0.0);
                }

                float2 p =
                    rainStateRespawnPosition(
                        index,
                        0.0,
                        float2(0.5, -0.5)
                    );

                return float4(p, 0.0, 0.0);
            }

            float4 state =
                txRainState.SampleLevel(
                    samPointRain,
                    suv,
                    0.0
                );

            float4 meta =
                txRainStateMeta.SampleLevel(
                    samPointRain,
                    suv,
                    0.0
                );

            float2 p = state.rg;
            float2 v = state.ba;
            float radius = meta.r;
            float mass = max(meta.g, 1.0);
            float dt = max(gRainStateDeltaTime, 0.0);

            /*
                Lifecycle flags in Meta.A modulo 4; the integer quotient
                identifies the current birth generation:
                    0 = dead / waiting for respawn gap
                    1 = alive
                    2 = respawn pending; consume on this state pass

                Meta.B remains the accumulated age/waiting timer.
                The respawn cycle comes from the packed generation.
            */
            if (gRainStateLifecycle > 0.5)
            {
                float generation = floor(meta.a * 0.25);
                float status = meta.a - generation * 4.0;
                if (status > 1.5)
                {
                    if (gRainStatePhysicalTest > 0.5 && index < 9.0)
                    {
                        float u = lerp(
                            0.250,
                            0.750,
                            index / 8.0
                        );

                        return float4(
                            u,
                            -0.500,
                            0.0,
                            0.0
                        );
                    }

                    float2 respawn =
                        rainStateRespawnPosition(
                            index,
                            generation + 1.0,
                            p
                        );

                    // A new lifetime begins at rest. The normal surface
                    // forces take over on the next physics update; its
                    // visual birth streak belongs to the shared UV mask.
                    return float4(respawn, 0.0, 0.0);
                }

                if (status < 0.5)
                {
                    return float4(
                        p,
                        0.0,
                        0.0
                    );
                }
            }

            // Birth hold (docs/RAINFX_IMPACT_SPLASH.md): a fresh drop rests
            // for a jittered HOLD, then its time step ramps in over RAMP, so
            // it accelerates gradually. Meta.B is the age while alive.
            {
                float holdJitter = frac(sin(index * 12.9898 + 78.233)
                    * 43758.5453);
                float holdT = gRainBirthHold * (0.6 + 0.8 * holdJitter);
                float holdK = gRainStateLifecycle > 0.5
                    ? saturate((meta.b - holdT) / max(gRainBirthRamp, 1e-3))
                    : 1.0;
                holdK = holdK * holdK * (3.0 - 2.0 * holdK);
                dt *= holdK;
                v *= holdK > 0.0 ? 1.0 : 0.0;
            }

#ifdef RAIN_MERGE_CODE
            if (gRainMergeEnabled > 0.5 && gRainStateLifecycle > 0.5)
            {
                float4 pState, pMeta;
                float4 merge = rainMergeDecode(index, count,
                    floor(meta.a * 0.25), p, radius, pState, pMeta);
                float isMerge = merge.z * (merge.x < 1.5 ? 1.0 : 0.0);
                float isAttract = merge.z * (merge.x > 1.5 ? 1.0 : 0.0);
                if (isMerge > 0.5 && merge.w < 0.5)
                    return float4(p, 0.0, 0.0); // absorbed
                // Survivor: volume-weighted centre and momentum (weights are
                // zero when not merging), so it is pulled toward the drop it
                // swallowed and changes course.
                float selfV = radius * radius * radius;
                float otherV = pMeta.r * pMeta.r * pMeta.r * isMerge;
                float total = max(selfV + otherV, 1e-15);
                p = (p * selfV + pState.rg * otherV) / total;
                v = (v * selfV + pState.ba * otherV) / total;
                radius = lerp(radius, rainMergeRadius(radius, pMeta.r),
                    isMerge);
                mass = lerp(mass, max(rainMergeMassProfile(
                    radius / 0.00146484375), 1.0), isMerge);
                // Absorption steering toward a drop ahead.
                float2 toOther = pState.rg - p;
                float dist = length(toOther);
                float reach = max((radius + pMeta.r) * gRainAttractReach,
                    1e-7);
                float2 attractDv = toOther / max(dist, 1e-7)
                    * gRainAttractGain * saturate(1.0 - dist / reach) * dt
                    * isAttract;
                // Worm fix: at most TURN_RATE rad/s of course change.
                float attractMax = length(v) * gRainSteerTurnRate * dt;
                v += attractDv * min(1.0, attractMax
                    / max(length(attractDv), 1e-9));
            }
#endif

#ifdef RAIN_WETPATH_CODE
            // Wet-path steering (docs/RAINFX_TRAIL_FLOW.md): a pre-wetted
            // track has lower contact-angle hysteresis, so a moving drop
            // slides into it. Only the component across the motion is
            // applied (no braking, and a drop's own trail behind it is
            // symmetric). Straight-line code: no branches, no loops.
            {
                float wsp0 = length(v);
                float2 wdir0 = v / max(wsp0, 1e-7);
                // Read AHEAD of the drop: its own fresh trail lies behind.
                float wt = gRainWetPathTexel;
                float2 wuv = float2(p.x, p.y + 1.0) + wdir0
                    * (radius * gRainWetPathAhead + 2.0 * wt);
                float2 wg = float2(
                    txRainWetPath.SampleLevel(samLinearRain,
                        wuv + float2(wt, 0.0), 0.0).g
                    - txRainWetPath.SampleLevel(samLinearRain,
                        wuv - float2(wt, 0.0), 0.0).g,
                    txRainWetPath.SampleLevel(samLinearRain,
                        wuv + float2(0.0, wt), 0.0).g
                    - txRainWetPath.SampleLevel(samLinearRain,
                        wuv - float2(0.0, wt), 0.0).g) * 0.5;
                float wsp = length(v);
                float2 wdir = v / max(wsp, 1e-7);
                float2 wlat = wg - dot(wg, wdir) * wdir;
                float wOn = saturate(wsp / max(gRainWetPathMinSpeed, 1e-6)
                    - 1.0);
                float2 wetDv = wlat * (gRainWetPathGain * dt * wOn);
                // Worm fix: at most TURN_RATE rad/s of course change.
                float wetMax = wsp * gRainSteerTurnRate * dt;
                v += wetDv * min(1.0, wetMax / max(length(wetDv), 1e-9));
            }
#endif

            if (gRainStatePhysics > 0.5) {
                return rainStateUpdatePhysics(
                    p,
                    v,
                    radius,
                    mass,
                    index,
                    dt
                );
            }

            return float4(p, v);
        }
    ]],
}

local rainStateMetaUpdateParams = {
    defines = { RAIN_MERGE_CODE = cfg.RUNTIME.RAIN_GPU_STATE_MERGE_SHADER },
    textures = {
        txRainStateMeta = false,
        txRainState = false,
        txRainBoundaryMask = false,
        txRainSpawnAtlas = false,
        txRainMergeCmd = false,
    },
    values = {
        gRainStateDeltaTime = 0.0,
        gRainStateCount = 256.0,
        gRainStateInit = 0.0,
        gRainSpawnAtlasEnabled = 0.0,
        gRainStatePhysicalTest = 0.0,
        gRainStatePhysicalGridTest = 0.0,
        gRainStateLifecycle = 0.0,
        gRainStateBoundaryMargin = 0.005,
        gRainStateTargetOccupancy = 0.0,
        gRainSizeMinDry = cfg.RUNTIME.RAIN_GPU_SIZE_MIN_DRY,
        gRainSizeMinLight = cfg.RUNTIME.RAIN_GPU_SIZE_MIN_LIGHT,
        gRainSizeMinRain = cfg.RUNTIME.RAIN_GPU_SIZE_MIN_RAIN,
        gRainSizeMinHeavy = cfg.RUNTIME.RAIN_GPU_SIZE_MIN_HEAVY,
        gRainSizeMinRare = cfg.RUNTIME.RAIN_GPU_SIZE_MIN_RARE,
        gRainSizeMaxDry = cfg.RUNTIME.RAIN_GPU_SIZE_MAX_DRY,
        gRainSizeMaxLight = cfg.RUNTIME.RAIN_GPU_SIZE_MAX_LIGHT,
        gRainSizeMaxRain = cfg.RUNTIME.RAIN_GPU_SIZE_MAX_RAIN,
        gRainSizeMaxHeavy = cfg.RUNTIME.RAIN_GPU_SIZE_MAX_HEAVY,
        gRainSizeMaxRare = cfg.RUNTIME.RAIN_GPU_SIZE_MAX_RARE,
        gRainSizeBias = cfg.RUNTIME.RAIN_GPU_SIZE_BIAS,
        gRainSizeRareChanceDry = cfg.RUNTIME.RAIN_GPU_SIZE_RARECHANCE_DRY,
        gRainSizeRareChanceHeavy = cfg.RUNTIME.RAIN_GPU_SIZE_RARECHANCE_HEAVY,
        gRainStateRespawnGapMin = 0.15,
        gRainStateRespawnGapMax = 0.75,
        gRainStateRainIntensity = 0.0,
        gRainStateExposure = 1.0,
        gRainStateAgeMin = 8.0,
        gRainStateAgeMax = 18.0,
        gRainStateSingleDropTest = 0.0,
        gRainMergeEnabled = 0.0,
        gRainMergeReach = 0.85,
        gRainAttractReach = 1.6,
        gRainAttractGain = 0.03,
        gRainMergeMaxDiameterMM = 5.0,
    },

    shader = [[
        SamplerState samPointRainMeta {
            Filter = MIN_MAG_MIP_POINT;
            AddressU = CLAMP;
            AddressV = CLAMP;
            AddressW = CLAMP;
        };

        SamplerState samLinearRain {
            Filter = MIN_MAG_MIP_LINEAR;
            AddressU = CLAMP;
            AddressV = CLAMP;
            AddressW = CLAMP;
        };

        float rainStateHash(float n) {
            return frac(sin(n * 127.1 + 311.7) * 43758.5453);
        }

        /*
            Final physical droplet model.
            This pass retains the deterministic 0.5–6.0 mm distribution
            for diagnostic modes; weather-driven mobile births use the
            smaller-biased distribution below.
        */
        float rainStatePhysicalDiameterMM(float index)
        {
            return lerp(
                0.5,
                6.0,
                rainStateHash(index + 101.0)
            );
        }

        float rainStateBirthDiameterMM(float index, float rain)
        {
            float minimum, maximum;
            if (rain <= 0.03)
            {
                float t = saturate(rain / 0.03);
                minimum = lerp(gRainSizeMinDry, gRainSizeMinLight, t);
                maximum = lerp(gRainSizeMaxDry, gRainSizeMaxLight, t);
            }
            else if (rain <= 0.50)
            {
                float t = saturate((rain - 0.03) / 0.47);
                minimum = lerp(gRainSizeMinLight, gRainSizeMinRain, t);
                maximum = lerp(gRainSizeMaxLight, gRainSizeMaxRain, t);
            }
            else
            {
                float t = saturate((rain - 0.50) / 0.50);
                minimum = lerp(gRainSizeMinRain, gRainSizeMinHeavy, t);
                maximum = lerp(gRainSizeMaxRain, gRainSizeMaxHeavy, t);
            }
            float rareChance = lerp(gRainSizeRareChanceDry,
                gRainSizeRareChanceHeavy, saturate(rain));
            if (rainStateHash(index + 307.0) > 1.0 - rareChance)
                return lerp(gRainSizeMinRare, gRainSizeMaxRare, rainStateHash(index + 619.0));
            float randomSize = rainStateHash(index + 101.0);
            return lerp(minimum, max(minimum, maximum),
                pow(randomSize, max(gRainSizeBias, 0.1)));
        }

        float rainStatePhysicalMassProfile(float diameterMM)
        {
            float volumeMin = 0.5 * 0.5 * 0.5;
            float volumeMax = 6.0 * 6.0 * 6.0;
            float volume = diameterMM * diameterMM * diameterMM;

            return lerp(
                1.0,
                9.0,
                saturate(
                    (volume - volumeMin)
                    / (volumeMax - volumeMin)
                )
            );
        }

        /*
            The supplied boundary mask uses the same mesh UV space as the
            visor surface-normal texture:
                R >= 0.5 : valid droplet surface
                R <  0.5 : outside / invalid

            Persistent state position is already raw visor UV. The boundary mask is sampled directly in that coordinate system.
        */
        float rainStateBoundaryMask(float2 position)
        {
            // Boundary validity is defined directly by the mask in raw UV.
            // Reject texture-domain positions before CLAMP sampling so an
            // out-of-domain state cannot appear valid at the texture edge.
            if (
                position.x < 0.0
                || position.x > 1.0
                || position.y < -1.0
                || position.y > 0.0
            ) {
                return 0.0;
            }

            return txRainBoundaryMask.SampleLevel(
                samLinearRain,
                position,
                0.0
            ).r;
        }
        

        // Mass coalescence + absorption steering (docs/RAINFX_COALESCENCE.md).
        // Compiled only with RAIN_MERGE_CODE (cfg RAIN_GPU_STATE_MERGE_SHADER).
        // Per-slot command texel written by Lua from the async readback:
        // R,G = partner index (hi, lo byte), B = type * 64 + generation % 64
        // of the PARTNER (type 1 = mutual merge, 2 = attract to partner).
        // Straight-line (no early returns): FXC overflowed its stack on the
        // first, branch-heavy version inside the already large state shader.
#ifdef RAIN_MERGE_CODE
        float rainMergePartner(float4 cmd)
        {
            return floor(cmd.r * 255.0 + 0.5) * 256.0
                + floor(cmd.g * 255.0 + 0.5);
        }

        // Returns x = type (0 none), y = partner, z = valid, w = survivor.
        float4 rainMergeDecode(float index, float count, float selfGen,
            float2 selfP, float selfR, out float4 pState, out float4 pMeta)
        {
            float4 cmd = txRainMergeCmd.SampleLevel(samPointRainMeta,
                float2((index + 0.5) / count, 0.5), 0.0);
            float code = floor(cmd.b * 255.0 + 0.5);
            float type = floor(code / 64.0);
            float genLow = code - type * 64.0;
            float partner = clamp(rainMergePartner(cmd), 0.0, count - 1.0);
            float2 puv = float2((partner + 0.5) / count, 0.5);
            pMeta = txRainStateMeta.SampleLevel(samPointRainMeta, puv, 0.0);
            pState = txRainState.SampleLevel(samPointRainMeta, puv, 0.0);
            float4 pCmd = txRainMergeCmd.SampleLevel(samPointRainMeta, puv, 0.0);
            float pGen = floor(pMeta.a * 0.25);
            float pStatus = pMeta.a - pGen * 4.0;
            float pCode = floor(pCmd.b * 255.0 + 0.5);
            float pType = floor(pCode / 64.0);
            float pGenLow = pCode - pType * 64.0;
            float dist = length(pState.rg - selfP);
            float sumR = selfR + pMeta.r;
            float ok = (type > 0.5 ? 1.0 : 0.0)
                * (abs(partner - index) > 0.5 ? 1.0 : 0.0)
                * (abs(pStatus - 1.0) < 0.5 ? 1.0 : 0.0)
                * (abs(fmod(pGen, 64.0) - genLow) < 0.5 ? 1.0 : 0.0)
                * (gRainMergeEnabled > 0.5 ? 1.0 : 0.0);
            float mutual = (abs(pType - 1.0) < 0.5 ? 1.0 : 0.0)
                * (abs(rainMergePartner(pCmd) - index) < 0.5 ? 1.0 : 0.0)
                * (abs(fmod(selfGen, 64.0) - pGenLow) < 0.5 ? 1.0 : 0.0);
            float mergeValid = ok * mutual
                * (type < 1.5 ? 1.0 : 0.0)
                * (dist <= sumR * gRainMergeReach ? 1.0 : 0.0);
            float attractValid = ok
                * (type > 1.5 ? 1.0 : 0.0)
                * (dist > 1e-7 ? 1.0 : 0.0)
                * (dist < sumR * gRainAttractReach ? 1.0 : 0.0);
            float survivor = (selfR > pMeta.r
                || (selfR == pMeta.r && index < partner)) ? 1.0 : 0.0;
            return float4(type, partner, max(mergeValid, attractValid),
                survivor);
        }

        float rainMergeRadius(float selfR, float partnerR)
        {
            // Same contact angle: footprint radius scales with volume^(1/3).
            float merged = pow(max(selfR * selfR * selfR
                + partnerR * partnerR * partnerR, 1e-15), 1.0 / 3.0);
            return min(merged, gRainMergeMaxDiameterMM * 0.00146484375);
        }
#endif

        float4 main(PS_IN pin) {
            float count = max(gRainStateCount, 1.0);
            float index = min(floor(pin.Tex.x * count), count - 1.0);
            float2 suv = float2((index + 0.5) / count, 0.5);
            
            float4 singdroptest = float4(0.0735, 3.0, 0.0, 1.0);

            if (gRainStateInit > 0.5) {
                

                if (gRainStateSingleDropTest > 0.5) {
                    // cause crashing if returning anything here
                }


                float diameterMM = gRainStateLifecycle > 0.5
                    ? rainStateBirthDiameterMM(index,
                        gRainStateRainIntensity)
                    : rainStatePhysicalDiameterMM(index);
                float radius = diameterMM * 0.00146484375;
                float mass = rainStatePhysicalMassProfile(diameterMM);

                // Rain-dependent initial population prevents a dry startup
                // from filling every slot with permanent visible drops.
                float occupancy = gRainStateTargetOccupancy;
                float allowed = rainStateHash(index + 419.0);
                float initialStatus = gRainStateLifecycle > 0.5
                    && allowed >= occupancy ? 0.0 : 1.0;
                return float4(radius, mass, 0.0, initialStatus);
            }

            float4 meta = txRainStateMeta.SampleLevel(
                samPointRainMeta, suv, 0.0
            );

            float dt = max(gRainStateDeltaTime, 0.0);

            if (gRainStateLifecycle > 0.5)
            {
                // Meta.A packs generation * 4 + status, preserving the
                // existing single-channel state and readback footprint.
                float generation = floor(meta.a * 0.25);
                float status = meta.a - generation * 4.0;
                float rain = saturate(gRainStateRainIntensity);
                if (status > 1.5)
                {
                    float nextGeneration = fmod(generation + 1.0, 4096.0);
                    meta.a = nextGeneration * 4.0 + 1.0;
                    meta.b = 0.0;

                    float diameterMM = rainStateBirthDiameterMM(
                        index + nextGeneration * 17.123, rain);

                    meta.r = diameterMM * 0.00146484375;
                    meta.g = rainStatePhysicalMassProfile(diameterMM);

                    return meta;
                }

                if (status < 0.5)
                {
                    meta.b += dt;

                    float gap01 = rainStateHash(index
                        + generation * 23.71 + 701.0);
                    float respawnGap = lerp(
                        gRainStateRespawnGapMin,
                        gRainStateRespawnGapMax, gap01);
                    // Use a stable eligibility per slot. With a new random
                    // admission for each generation, rejected slots could
                    // never retry and the alive count converged to zero.
                    float admission = gRainSpawnAtlasEnabled > 0.5
                        ? txRainSpawnAtlas.Load(int3((int)index, 0, 0)).b
                        : rainStateHash(index + 419.0);
                    float gapScale = lerp(3.0, 0.5, sqrt(rain))
                        / max(gRainStateExposure, 1.0);
                    if (rain > 0.001
                        && admission < gRainStateTargetOccupancy
                        && meta.b >= respawnGap * gapScale)
                    {
                        meta.a = generation * 4.0 + 2.0;
                    }

                    return meta;
                }

                float4 state = txRainState.SampleLevel(
                    samPointRainMeta,
                    suv,
                    0.0
                );

                float2 p = state.rg;
                float2 v = state.ba;
#ifdef RAIN_MERGE_CODE
                if (gRainMergeEnabled > 0.5)
                {
                    float4 pState, pMeta;
                    float4 merge = rainMergeDecode(index, count, generation,
                        p, meta.r, pState, pMeta);
                    float isMerge = merge.z * (merge.x < 1.5 ? 1.0 : 0.0);
                    if (isMerge > 0.5 && merge.w < 0.5)
                    {
                        // Absorbed: dead now, normal respawn gap later.
                        meta.a = generation * 4.0;
                        meta.b = 0.0;
                        return meta;
                    }
                    meta.r = lerp(meta.r, rainMergeRadius(meta.r, pMeta.r),
                        isMerge);
                    meta.g = lerp(meta.g, rainStatePhysicalMassProfile(
                        meta.r / 0.00146484375), isMerge);
                }
#endif
                float2 predicted = p + v * dt;
                float2 midpoint = lerp(
                    p,
                    predicted,
                    0.5
                );

                /*
                    The supplied visor mask is now the authoritative
                    lifecycle boundary. A droplet is considered to have
                    exited when either the midpoint or predicted state lies
                    outside the valid mask.
                */
                bool exits =
                    rainStateBoundaryMask(midpoint) < 0.5
                    || rainStateBoundaryMask(predicted) < 0.5;

                if (exits)
                {
                    meta.a = generation * 4.0;
                    meta.b = 0.0;
                    return meta;
                }

                float ageRange = lerp(gRainStateAgeMin,
                    gRainStateAgeMax,
                    rainStateHash(index + generation * 5.197 + 211.0));
                if (rain <= 0.001)
                    ageRange = min(ageRange, 2.0);
                if (meta.b + dt >= ageRange)
                {
                    meta.a = generation * 4.0;
                    meta.b = 0.0;
                    return meta;
                }
            }

            meta.b += dt;
            return meta;
        }
    ]],
}

local motionTarget= vec3(
    0,
    0,
    0
)

local textDebugMotion = nil


------------------------------------------------------------
-- Camera vectors
------------------------------------------------------------

local worldUp = vec3(0, 1, 0)


------------------------------------------------------------
-- Active profile helpers
------------------------------------------------------------

local activeProfile = 1
local activeEnableMode = 1


local function getProfile(profileIndex)

    if profileIndex == 2 then
        return cfg.PROFILE_2
    end

    return cfg.PROFILE_1
end


local function getActiveProfile()

    return getProfile(activeProfile)

end


------------------------------------------------------------
-- Runtime transform state
------------------------------------------------------------

local activeOffset = vec3()
local activeScale = 1.0

local activePitch = 0.0
local activeYaw = 0.0
local activeRoll = 0.0

local activeNearclip = 0.0181

local activeEnableMotion = 1
local activeMotionGainX = 0.0
local activeMotionGainY = 0.0
local activeMotionGainZ = 0.0
local activeMotionSmoothing = 0.0
local activeMotionSharpness = 0.0
local activeMotionLimitX = 0.0
local activeMotionLimitY = 0.0
local activeMotionLimitZ = 0.0

local lastScale = -1

local lastPitch = 99999
local lastYaw = 99999
local lastRoll = 99999


------------------------------------------------------------
-- Profile save/load
------------------------------------------------------------

local function loadProfiles()

    local config = ac.INIConfig.load(settingsFile)

    local p1 = config:mapSection('PROFILE_1', DEFAULT_PROFILE1)
    local p2 = config:mapSection('PROFILE_2', DEFAULT_PROFILE2)


    for key, value in pairs(p1) do
        cfg.PROFILE_1[key] = value
    end
    
    
    for key, value in pairs(p2) do
        cfg.PROFILE_2[key] = value
    end


    local generalProfile = config:mapSection('GENERAL', cfg.GENERAL)

    local activePrfRaw = generalProfile.ACTIVE or 1

    local enableModRaw = generalProfile.ENABLE


    ac.log(
        appNameDebug
        .. ' generalProfile.ENABLE = '
        .. tostring( generalProfile.ENABLE)
    )


    activeProfile = math.clamp(
        math.floor(activePrfRaw or 1),
        1,
        2
    )
    
    local enableModClamped = math.clamp(
        math.floor(enableModRaw or 1),
        1,
        2
    )
    
    cfg.GENERAL.ACTIVE = activeProfile

    cfg.GENERAL.ENABLE = enableModClamped


    activeEnableMode = enableModClamped
    -- (tonumber(enableMod.ENABLE) or 1) ~= 0


    --------------------------------------------------------
    -- Per-mesh visibility
    --------------------------------------------------------

    for _, editor in ipairs(MATERIAL_EDITORS or {}) do
        local visibleValue = config:get(
            MESH_VISIBILITY_SECTION,
            editor.meshName,
            editor.visible and 1 or 0
        )

        editor.visible = visibleValue ~= 0

        if editor.targetMesh
            and #editor.targetMesh > 0 then
            editor.targetMesh:setVisible(editor.visible, false)
        end
    end


    ac.log(
        appNameDebug
        .. ' cfg.GENERAL.ENABLE = '
        .. tostring(cfg.GENERAL.ENABLE)
    )

end


local function saveProfiles()
    local p1 = cfg.PROFILE_1
    local p2 = cfg.PROFILE_2

    local meshVisibilityLines = {}

    for _, editor in ipairs(MATERIAL_EDITORS or {}) do
        meshVisibilityLines[#meshVisibilityLines + 1] =
            string.format(
                '%s=%d',
                editor.meshName,
                editor.visible and 1 or 0
            )
    end

    local meshVisibilityContent =
        table.concat(meshVisibilityLines, '\n')

    local content = string.format([[
[GENERAL]
ACTIVE=%d
ENABLE=%d

[PROFILE_1]
PITCH=%.6f
YAW=%.6f
ROLL=%.6f
OFFSET_X=%.6f
OFFSET_Y=%.6f
OFFSET_Z=%.6f
SCALE=%.6f
NEARCLIP=%.6f
ENABLE_MOTION=%d
MOTION_GAIN_X=%.8f
MOTION_GAIN_Y=%.8f
MOTION_GAIN_Z=%.8f
MOTION_SMOOTHING=%.6f
MOTION_SHARPNESS=%.6f
MOTION_LIMIT_X=%.6f
MOTION_LIMIT_Y=%.6f
MOTION_LIMIT_Z=%.6f
HIDE_DRIVER_HELMET=%d

[PROFILE_2]
PITCH=%.6f
YAW=%.6f
ROLL=%.6f
OFFSET_X=%.6f
OFFSET_Y=%.6f
OFFSET_Z=%.6f
SCALE=%.6f
NEARCLIP=%.6f
ENABLE_MOTION=%d
MOTION_GAIN_X=%.8f
MOTION_GAIN_Y=%.8f
MOTION_GAIN_Z=%.8f
MOTION_SMOOTHING=%.6f
MOTION_SHARPNESS=%.6f
MOTION_LIMIT_X=%.6f
MOTION_LIMIT_Y=%.6f
MOTION_LIMIT_Z=%.6f
HIDE_DRIVER_HELMET=%d

[MESH_VISIBILITY]
%s
]],
        cfg.GENERAL.ACTIVE,
        cfg.GENERAL.ENABLE,

        p1.PITCH,
        p1.YAW,
        p1.ROLL,
        p1.OFFSET_X,
        p1.OFFSET_Y,
        p1.OFFSET_Z,
        p1.SCALE,
        p1.NEARCLIP,
        p1.ENABLE_MOTION,
        p1.MOTION_GAIN_X,
        p1.MOTION_GAIN_Y,
        p1.MOTION_GAIN_Z,
        p1.MOTION_SMOOTHING,
        p1.MOTION_SHARPNESS,
        p1.MOTION_LIMIT_X,
        p1.MOTION_LIMIT_Y,
        p1.MOTION_LIMIT_Z,
        p1.HIDE_DRIVER_HELMET,

        p2.PITCH,
        p2.YAW,
        p2.ROLL,
        p2.OFFSET_X,
        p2.OFFSET_Y,
        p2.OFFSET_Z,
        p2.SCALE,
        p2.NEARCLIP,
        p2.ENABLE_MOTION,
        p2.MOTION_GAIN_X,
        p2.MOTION_GAIN_Y,
        p2.MOTION_GAIN_Z,
        p2.MOTION_SMOOTHING,
        p2.MOTION_SHARPNESS,
        p2.MOTION_LIMIT_X,
        p2.MOTION_LIMIT_Y,
        p2.MOTION_LIMIT_Z,
        p2.HIDE_DRIVER_HELMET,

        meshVisibilityContent
    )

    io.save(settingsFile, content)

end


local function applyActiveProfileToRuntime()

    local p = getActiveProfile()


    activeEnableMode = cfg.GENERAL.ENABLE


    activeOffset:set(
        p.OFFSET_X,
        p.OFFSET_Y,
        p.OFFSET_Z
    )

    activeScale = p.SCALE

    activePitch = p.PITCH
    activeYaw = p.YAW
    activeRoll = p.ROLL

    activeNearclip = p.NEARCLIP


    -- Profile-specific G-force motion settings
    -- Runtime motion code should read these active values.

    activeEnableMotion = p.ENABLE_MOTION

    activeMotionGainX = p.MOTION_GAIN_X
    activeMotionGainY = p.MOTION_GAIN_Y
    activeMotionGainZ = p.MOTION_GAIN_Z

    activeMotionSmoothing = p.MOTION_SMOOTHING
    activeMotionSharpness = p.MOTION_SHARPNESS

    activeMotionLimitX = p.MOTION_LIMIT_X
    activeMotionLimitY = p.MOTION_LIMIT_Y
    activeMotionLimitZ = p.MOTION_LIMIT_Z


    ac.overrideCameraClipPlanes(activeNearclip, ac.getSim().cameraClipFar)

end


------------------------------------------------------------
-- Profile switching
------------------------------------------------------------

local function setActiveProfile(index)

    index = math.clamp(
        math.floor(index),
        1,
        2
    )

    if activeProfile == index then
        return false
    end

    activeProfile = index

    cfg.GENERAL.ACTIVE =
        activeProfile


    applyActiveProfileToRuntime()

    
    saveProfiles()


    --------------------------------------------------------
    -- Force transform refresh
    --------------------------------------------------------

    lastScale = -1
    lastPitch = 99999
    lastYaw = 99999
    lastRoll = 99999

    return true

end


------------------------------------------------------------
-- Profile value setters
------------------------------------------------------------

local function setProfileValue(
    key,
    value
)

    local p =
        getActiveProfile()


    if p[key] == value then
        return
    end


    if key == 'ENABLE_MODE' then        
        cfg.GENERAL.ENABLE = value

    else        
        p[key] = value        

    end

    
    applyActiveProfileToRuntime()

    
    saveProfiles()

    
    --------------------------------------------------------
    -- Force transform update
    --------------------------------------------------------

    if key == 'SCALE' then
        lastScale = -1
    elseif key == 'PITCH' then
        lastPitch = 99999
    elseif key == 'YAW' then
        lastYaw = 99999
    elseif key == 'ROLL' then
        lastRoll = 99999
    end

end


------------------------------------------------------------
-- Reset one profile value to hardcoded default
------------------------------------------------------------

local function resetProfileValue(key)

    local defaultValue = nil

    if activeProfile == 1 then
    
        defaultValue = DEFAULT_PROFILE1[key]
        
         --ac.log('RealVisor: default_profile1_key=' .. tostring(key) .. ' value=' .. defaultValue)

    elseif activeProfile == 2 then
    
        defaultValue = DEFAULT_PROFILE2[key]

        --ac.log('RealVisor: default_profile2_key=' .. tostring(key) .. ' value=' .. defaultValue)

    end


    if defaultValue == nil then
        return
    end

    setProfileValue(
        key,
        defaultValue
    )

end


------------------------------------------------------------
-- Reset entire active profile
------------------------------------------------------------

local function resetActiveProfile()

    local p =
        getActiveProfile()

    for key, value in pairs(DEFAULT_PROFILE) do
        p[key] = value
    end

    applyActiveProfileToRuntime()

    saveProfiles()

    lastScale = -1
    lastPitch = 99999
    lastYaw = 99999
    lastRoll = 99999

end


------------------------------------------------------------
-- Helper: profile Context Menu
------------------------------------------------------------

local function profileContextMenu(label, key)

    if ui.beginPopupContextItem('##'.. key .. '_context') then        
        
        --ac.log('RealVisor: popup opened key=' .. tostring(key))
        
        if ui.menuItem('Reset to Default') then

            --ac.log('RealVisor: Reset clicked key=' .. tostring(key))
            
            resetProfileValue(key)


        end


        ui.separator()

        local defaultValue = 
                activeProfile == 1 
                and DEFAULT_PROFILE1[key] 
                or DEFAULT_PROFILE2[key]


        -- ac.log(
        --     appNameDebug
        --     ..' default key='
        --     .. tostring(key)
        --     .. ' value='
        --     .. tostring(defaultValue)
        -- )
        

        ui.text('Default: ' .. tostring(defaultValue))


        ui.endPopup()


    end

end

------------------------------------------------------------
-- Global Names
------------------------------------------------------------
local strMaterialEditorPopup = 'RealVisorMaterialEditor'


------------------------------------------------------------
-- Material Parameter Helpers
------------------------------------------------------------
local activeMaterialEditor = nil


------------------------------------------------------------
-- Custom Parameter Registry
------------------------------------------------------------
local PARAMS_KS_PERPIXEL = {

    -- Scalar
    { 
        name = 'ksAmbient',    
        type = 'float',   
        label = 'Ambient',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksDiffuse',
        type = 'float',   
        label = 'Diffuse',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecular',    
        type = 'float',   
        label = 'Specular',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecularEXP',    
        type = 'float',   
        label = 'Specular EXP',  
        group = 'Base', 
        format = '%.1f'  
    },

    {
        name = 'ksAlphaRef',    
        type = 'float',   
        label = 'Alpha Ref',  
        group = 'Base', 
        format = '%.3f'  
    },

    {    
        name = 'ksEmissive',    
        type = 'vec3',   
        label = 'Emissive',
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    }

}


local PARAMS_ST_PERPIXELNM_UVFLOW = {

    -- Scalar
    { 
        name = 'ksAmbient',    
        type = 'float',   
        label = 'Ambient',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksDiffuse',
        type = 'float',   
        label = 'Diffuse',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecular',    
        type = 'float',   
        label = 'Specular',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecularEXP',    
        type = 'float',   
        label = 'Specular EXP',  
        group = 'Base', 
        format = '%.1f'  
    },

    {
        name = 'ksAlphaRef',    
        type = 'float',   
        label = 'Alpha Ref',  
        group = 'Base', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelC',
        type = 'float',   
        label = 'C',  
        group = 'Fresnel', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelEXP',    
        type = 'float',   
        label = 'EXP',  
        group = 'Fresnel', 
        format = '%.2f'  
    },
    {
        name = 'fresnelMaxLevel',    
        type = 'float',   
        label = 'Max Level',  
        group = 'Fresnel', 
        format = '%.3f'  
    },

    {    
        name = 'extColoredReflection',    
        type = 'float',   
        label = 'ColoredReflection',  
        group = 'Colored Reflection', 
        format = '%.3f'  
    },

    {   
        name = 'extColoredReflectionN',    
        type = 'float',   
        label = 'ColoredReflectionN',  
        group = 'Colored Reflection', 
        format = '%.3f'  
    },
    
    {
        name = 'nmObjectSpace',    
        type = 'float',   
        label = 'Object Space',  
        group = 'Normal', 
        format = '%.3f'  
    },

    {
        name = 'NMmult',    
        type = 'float',   
        label = 'NM Mult',  
        group = 'Normal', 
        format = '%.3f'  
    },
    {
        name = 'detailNMmult',    
        type = 'float',   
        label = 'Detail NM mult',  
        group = 'Normal', 
        format = '%.3f'  
    },

    {
        name = 'uvMultX',
        type = 'float',   
        label = 'Mult X',  
        group = 'UV', 
        format = '%.3f'  
    },

    {
        name = 'uvMultY',    
        type = 'float',   
        label = 'Mult Y',  
        group = 'UV', 
        format = '%.3f'  
    },

    {
        name = 'uvOffsetX',    
        type = 'float',   
        label = 'Offset X',  
        group = 'UV', 
        format = '%.3f'  
    },
    
    {
        name = 'uvOffsetY',    
        type = 'float',   
        label = 'Offset Y',  
        group = 'UV', 
        format = '%.3f'  
    },


    -- Vector3
    {    
        name = 'ksEmissive',    
        type = 'vec3',   
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    },


    -- Vector2
    {    
        name = 'offsetDSpeed',    
        type = 'vec2',   
        labelX = 'D Speed X',  
        labelY = 'D Speed Y',  
        group = 'UV Animation', 
        format = '%.3f, %.3f',
        rangeMin = -500.000,
        rangeMax = 500.000      
    },

    {    
        name = 'offsetNMSpeed',    
        type = 'vec2',   
        labelX = 'NM Speed X',  
        labelY = 'NM Speed Y',  
        group = 'UV Animation', 
        format = '%.3f, %.3f',
        rangeMin = -500.000,
        rangeMax = 500.000      
    },

    { 
        name = 'offsetNMdetailSpeed',
        type = 'vec2',   
        labelX = 'Detail NM Speed X',  
        labelY = 'Detail NM Speed Y',  
        group = 'UV Animation', 
        format = '%.3f, %.3f',
        rangeMin = -500.000,
        rangeMax = 500.000        
    },

    {   
        name = 'pauseTiming',    
        type = 'vec2',   
        labelX = 'Pause Timing X',  
        labelY = 'Pause Timing Y',  
        group = 'UV Animation', 
        format = '%.3f, %.3f',
        rangeMin = -50000.000,
        rangeMax = 50000.000        
    },


    -- Boolean / 0 or 1
    {
        name = 'isAdditive',    
        type = 'bool',   
        label = 'Additive',  
        group = 'Flags' 
    },
    
    {   
        name = 'emAlphaFromDiffuse',    
        type = 'bool',   
        label = 'Emissive Alpha From Diffuse',  
        group = 'Flags'   
    },

    {   
        name = 'emClipOutside',    
        type = 'bool',   
        label = 'Emissive Clip Outside',  
        group = 'Flags'   
    }
}


local PARAMS_KS_PERPIXELNM_UV_MULT = {
    ------------------------------------------------------------
    -- ksPerPixelReflection
    ------------------------------------------------------------
    
    -- Scalar
    { 
        name = 'ksAmbient',    
        type = 'float',   
        label = 'Ambient',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksDiffuse',
        type = 'float',   
        label = 'Diffuse',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecular',    
        type = 'float',   
        label = 'Specular',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecularEXP',    
        type = 'float',   
        label = 'Specular EXP',  
        group = 'Base', 
        format = '%.1f'  
    },

    {
        name = 'ksAlphaRef',    
        type = 'float',   
        label = 'Alpha Ref',  
        group = 'Base', 
        format = '%.3f'  
    },

    
    {
        name = 'diffuseMult',    
        type = 'float',   
        label = 'Diffuse multiplier',  
        group = 'UV', 
        format = '%.3f'  
    },
    
    {
        name = 'normalMult',    
        type = 'float',   
        label = 'Diffuse multiplier',  
        group = 'UV', 
        format = '%.3f'  
    },

    {    
        name = 'bo',    
        type = 'vec2',   
        label = 'b.o',
        group = 'ETC', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000    
    },

    {    
        name = 'boh',    
        type = 'float',   
        label = 'b.o ',
        group = 'ETC', 
        format = '%.3f',
    },

    {    
        name = 'fresnelC',
        type = 'float',   
        label = 'C',  
        group = 'Fresnel', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelEXP',    
        type = 'float',   
        label = 'EXP',  
        group = 'Fresnel', 
        format = '%.2f'  
    },

    {
        name = 'fresnelMaxLevel',    
        type = 'float',   
        label = 'Max Level',  
        group = 'Fresnel', 
        format = '%.3f'  
    },

    -- Vector3
    {    
        name = 'ksEmissive',    
        type = 'vec3',   
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000    
    }
}    


local PARAMS_KS_PERPIXEL_MULTIMAP_EMISSIVE = {

    -- Scalar
    { 
        name = 'ksAmbient',    
        type = 'float',   
        label = 'Ambient',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksDiffuse',
        type = 'float',   
        label = 'Diffuse',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecular',    
        type = 'float',   
        label = 'Specular',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecularEXP',    
        type = 'float',   
        label = 'Specular EXP',  
        group = 'Base', 
        format = '%.1f'  
    },

    {
        name = 'ksAlphaRef',    
        type = 'float',   
        label = 'Alpha Ref',  
        group = 'Base', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelC',
        type = 'float',   
        label = 'C',  
        group = 'Fresnel', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelEXP',    
        type = 'float',   
        label = 'EXP',  
        group = 'Fresnel', 
        format = '%.2f'  
    },
    {
        name = 'fresnelMaxLevel',    
        type = 'float',   
        label = 'Max Level',  
        group = 'Fresnel', 
        format = '%.3f'  
    },

    {    
        name = 'extColoredReflection',    
        type = 'float',   
        label = 'ColoredReflection',  
        group = 'Colored Reflection', 
        format = '%.3f'  
    },

    {   
        name = 'extColoredReflectionN',    
        type = 'float',   
        label = 'ColoredReflectionN',  
        group = 'Colored Reflection', 
        format = '%.3f'  
    },

    {   
        name = 'extColoredBaseReflect',    
        type = 'float',   
        label = 'Colored Base Reflect',  
        group = 'Colored Reflection', 
        format = '%.3f'  
    },    
    
    {
        name = 'detailUVMultiplier',    
        type = 'float',   
        label = 'Detail UV mult',  
        group = 'Detail', 
        format = '%.3f'  
    },
    
    {
        name = 'shadowBiasMult',    
        type = 'float',   
        label = 'Bias multiplier',  
        group = 'Shadow Adjustment', 
        format = '%.3f'  
    },
    
    {
        name = 'nmObjectSpace',    
        type = 'float',   
        label = 'Object Space (0= tangent 1= ObjectSpace)',  
        group = 'Normal', 
        format = '%.3f'  
    },

    {
        name = 'sunSpecular',    
        type = 'float',   
        label = 'Specular',  
        group = 'Sun', 
        format = '%.3f'  
    },

    {
        name = 'sunSpecularEXP',    
        type = 'float',   
        label = 'EXP',  
        group = 'Sun', 
        format = '%.3f'  
    },
    
    {
        name = 'emMirrorOffset',    
        type = 'float',   
        label = 'Mirror Offset',  
        group = 'Emissive', 
        format = '%.3f'  
    },

    -- Vector3
    {    
        name = 'emMirrorDir',    
        type = 'vec3',   
        label = 'Mirror Direction',
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = -300.000,
        rangeMax = 300.000
    },

    {    
        name = 'ksEmissive',    
        type = 'vec3',   
        label = 'Emissive 0',
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    },

    {    
        name = 'ksEmissive1',    
        type = 'vec3',   
        label = 'Emissive 1',
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    },

    {    
        name = 'ksEmissive2',    
        type = 'vec3',   
        label = 'Emissive 2',
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    },

    {    
        name = 'ksEmissive3',    
        type = 'vec3',   
        label = 'Emissive 3',
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    },

    {    
        name = 'ksEmissive4',    
        type = 'vec3',   
        label = 'Emissive 4',
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    },

    {    
        name = 'ksEmissive5',    
        type = 'vec3',   
        label = 'Emissive 5',
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    },

    {    
        name = 'ksEmissive6',    
        type = 'vec3',   
        label = 'Emissive 6',
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    },
        
    {
        name = 'emChannelsMode',    
        type = 'float',   
        label = 'Channels Mode (need verify)',  
        group = 'Emissive', 
        format = '%.3f'  
    },

    {
        name = 'emMirrorChannel3As4',    
        type = 'float',   
        label = 'Mirror Channel 3 as 4 (need verify)',  
        group = 'Emissive', 
        format = '%.3f'  
    },

    {
        name = 'emMirrorChannel2As5',    
        type = 'float',   
        label = 'Mirror Channel 2 as 5 (need verify)',  
        group = 'Emissive', 
        format = '%.3f'  
    },

    {
        name = 'emMirrorChannel1As6',    
        type = 'float',   
        label = 'Mirror Channel 1 as 6 (need verify)',  
        group = 'Emissive', 
        format = '%.3f'  
    },

    {
        name = 'extBounceBack',    
        type = 'float',   
        label = 'Bounce Back (need verify)',  
        group = 'Bounce', 
        format = '%.3f'  
    },

    -- Boolean / 0 or 1
    {
        name = 'isAdditive',    
        type = 'bool',   
        label = 'Additive',  
        group = 'Flags' 
    },
 
    {
        name = 'useDetail',    
        type = 'bool',   
        label = 'use Detail texture',  
        group = 'Flags' 
    },

    {   
        name = 'emAlphaFromDiffuse',    
        type = 'bool',   
        label = 'Emissive Alpha From Diffuse',  
        group = 'Flags'   
    },

    {   
        name = 'emSkipDiffuseMap',    
        type = 'bool',   
        label = 'emissive Skip Diffuse Map',  
        group = 'Flags'   
    },


}


local PARAMS_KS_PERPIXEL_NM = {

    -- Scalar
    { 
        name = 'ksAmbient',    
        type = 'float',   
        label = 'Ambient',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksDiffuse',
        type = 'float',   
        label = 'Diffuse',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecular',    
        type = 'float',   
        label = 'Specular',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecularEXP',    
        type = 'float',   
        label = 'Specular EXP',  
        group = 'Base', 
        format = '%.1f'  
    },
    
    {
        name = 'ksAlphaRef',    
        type = 'float',   
        label = 'Alpha Ref',  
        group = 'Base', 
        format = '%.3f'  
    },

    -- Vector3
    {    
        name = 'ksEmissive',    
        type = 'vec3',   
        label = 'Emissive',
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    },
    
    {    
        name = 'fresnelC',
        type = 'float',   
        label = 'C',  
        group = 'Fresnel', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelEXP',    
        type = 'float',   
        label = 'EXP',  
        group = 'Fresnel', 
        format = '%.2f'  
    },

    {
        name = 'fresnelMaxLevel',    
        type = 'float',   
        label = 'Max Level',  
        group = 'Fresnel', 
        format = '%.3f'  
    },
        
    {
        name = 'nmObjectSpace',    
        type = 'float',   
        label = 'Object Space',  
        group = 'Normal', 
        format = '%.3f'  
    },

    -- Vector3
    {    
        name = 'boh',    
        type = 'vec3',   
        label = 'boh',
        group = 'boh', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    },

    -- Boolean / 0 or 1
    {
        name = 'isAdditive',    
        type = 'bool',   
        label = 'Additive',  
        group = 'Flags' 
    },

}


local PARAMS_KS_PERPIXEL_MULTIMAP = {

    -- Scalar
    { 
        name = 'ksAmbient',    
        type = 'float',   
        label = 'Ambient',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksDiffuse',
        type = 'float',   
        label = 'Diffuse',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecular',    
        type = 'float',   
        label = 'Specular',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecularEXP',    
        type = 'float',   
        label = 'Specular EXP',  
        group = 'Base', 
        format = '%.1f'  
    },

    {
        name = 'ksAlphaRef',    
        type = 'float',   
        label = 'Alpha Ref',  
        group = 'Base', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelC',
        type = 'float',   
        label = 'C',  
        group = 'Fresnel', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelEXP',    
        type = 'float',   
        label = 'EXP',  
        group = 'Fresnel', 
        format = '%.2f'  
    },

    {
        name = 'fresnelMaxLevel',    
        type = 'float',   
        label = 'Max Level',  
        group = 'Fresnel', 
        format = '%.3f'  
    },
        
    {
        name = 'nmObjectSpace',    
        type = 'float',   
        label = 'Object Space',  
        group = 'Normal', 
        format = '%.3f'  
    },
    
    {
        name = 'detailUVMultiplier',    
        type = 'float',   
        label = 'UV Multiplier',  
        group = 'UV', 
        format = '%.3f'  
    },

    {
        name = 'shadowBiasMult',
        type = 'float',   
        label = 'shadow Bias Multiplier',  
        group = 'UV', 
        format = '%.3f'  
    },

    {
        name = 'sunSpecular',
        type = 'float',   
        label = 'Specular',  
        group = 'Sun', 
        format = '%.3f'  
    },

    {
        name = 'sunSpecularEXP',
        type = 'float',   
        label = 'EXP',  
        group = 'Sun', 
        format = '%.3f'  
    },

    -- Vector3
    {    
        name = 'ksEmissive',    
        type = 'vec3',   
        label = 'Emissive',
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    },

    -- Vector4
    -- There's 4Vec types called damageZones not bindings yet

    -- Boolean / 0 or 1
    {
        name = 'isAdditive',    
        type = 'bool',   
        label = 'Additive',  
        group = 'Flags' 
    },
    
    {   
        name = 'useDetail',    
        type = 'bool',   
        label = 'use Detail texture',  
        group = 'Flags'   
    }

}


local PARAMS_KS_PERPIXEL_MULTIMAP_NMDETAIL = {

    -- Scalar
    { 
        name = 'ksAmbient',    
        type = 'float',   
        label = 'Ambient',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksDiffuse',
        type = 'float',   
        label = 'Diffuse',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecular',    
        type = 'float',   
        label = 'Specular',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecularEXP',    
        type = 'float',   
        label = 'Specular EXP',  
        group = 'Base', 
        format = '%.1f'  
    },

    {
        name = 'ksAlphaRef',    
        type = 'float',   
        label = 'Alpha Ref',  
        group = 'Base', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelC',
        type = 'float',   
        label = 'C',  
        group = 'Fresnel', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelEXP',    
        type = 'float',   
        label = 'EXP',  
        group = 'Fresnel', 
        format = '%.2f'  
    },

    {
        name = 'fresnelMaxLevel',    
        type = 'float',   
        label = 'Max Level',  
        group = 'Fresnel', 
        format = '%.3f'  
    },

    {
        name = 'detailUVMultiplier',    
        type = 'float',   
        label = 'UV Multiplier',  
        group = 'UV', 
        format = '%.3f'  
    },

    {
        name = 'shadowBiasMult',
        type = 'float',   
        label = 'shadow Bias Multiplier',  
        group = 'UV', 
        format = '%.3f'  
    },

    {
        name = 'detailNormalBlend',
        type = 'float',   
        label = 'detail Normal Blend (float or 0/1 ? pls check it out)',  
        group = 'Extras', 
        format = '%.3f'  
    },

    -- Vector3
    {    
        name = 'ksEmissive',    
        type = 'vec3',   
        label = 'Emissive',
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    },


    -- Boolean / 0 or 1
    {
        name = 'isAdditive',    
        type = 'bool',   
        label = 'Additive',  
        group = 'Flags' 
    },
    
    {   
        name = 'useDetail',    
        type = 'bool',   
        label = 'use Detail texture',  
        group = 'Flags'   
    }
}


local PARAMS_KS_PERPIXEL_MULTIMAP_SIMPLE_REFL = {

    -- Scalar
    { 
        name = 'ksAmbient',    
        type = 'float',   
        label = 'Ambient',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksDiffuse',
        type = 'float',   
        label = 'Diffuse',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecular',    
        type = 'float',   
        label = 'Specular',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecularEXP',    
        type = 'float',   
        label = 'Specular EXP',  
        group = 'Base', 
        format = '%.1f'  
    },

    {
        name = 'ksAlphaRef',    
        type = 'float',   
        label = 'Alpha Ref',  
        group = 'Base', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelC',
        type = 'float',   
        label = 'C',  
        group = 'Fresnel', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelEXP',    
        type = 'float',   
        label = 'EXP',  
        group = 'Fresnel', 
        format = '%.2f'  
    },

    {
        name = 'fresnelMaxLevel',    
        type = 'float',   
        label = 'Max Level',  
        group = 'Fresnel', 
        format = '%.3f'  
    },
        
    {
        name = 'nmObjectSpace',    
        type = 'float',   
        label = 'Object Space',  
        group = 'Normal', 
        format = '%.3f'  
    },
    
    {
        name = 'detailUVMultiplier',    
        type = 'float',   
        label = 'UV Multiplier',  
        group = 'UV', 
        format = '%.3f'  
    },

    {
        name = 'shadowBiasMult',
        type = 'float',   
        label = 'shadow Bias Multiplier',  
        group = 'UV', 
        format = '%.3f'  
    },

    -- Vector3
    {    
        name = 'ksEmissive',    
        type = 'vec3',   
        label = 'Emissive',
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000
    },


    -- Boolean / 0 or 1
    {
        name = 'isAdditive',    
        type = 'bool',   
        label = 'Additive',  
        group = 'Flags' 
    },
    
    {   
        name = 'useDetail',    
        type = 'bool',   
        label = 'use Detail texture',  
        group = 'Flags'   
    }

}


local PARAMS_KS_WINDSCREEN = {
    ------------------------------------------------------------
    -- ksWindScreen
    ------------------------------------------------------------
    
    -- Scalar
    { 
        name = 'ksAmbient',    
        type = 'float',   
        label = 'Ambient',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksDiffuse',
        type = 'float',   
        label = 'Diffuse',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecular',    
        type = 'float',   
        label = 'Specular',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecularEXP',    
        type = 'float',   
        label = 'Specular EXP',  
        group = 'Base', 
        format = '%.1f'  
    },

    {
        name = 'ksAlphaRef',    
        type = 'float',   
        label = 'Alpha Ref',  
        group = 'Base', 
        format = '%.3f'  
    },

    -- Vector3
    {    
        name = 'ksEmissive',    
        type = 'vec3',   
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000    
    },
}    


local PARAMS_KS_PERPIXEL_REFLECTION = {
    ------------------------------------------------------------
    -- ksPerPixelReflection
    ------------------------------------------------------------
    
    -- Scalar
    { 
        name = 'ksAmbient',    
        type = 'float',   
        label = 'Ambient',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksDiffuse',
        type = 'float',   
        label = 'Diffuse',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecular',    
        type = 'float',   
        label = 'Specular',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecularEXP',    
        type = 'float',   
        label = 'Specular EXP',  
        group = 'Base', 
        format = '%.1f'  
    },

    {
        name = 'ksAlphaRef',    
        type = 'float',   
        label = 'Alpha Ref',  
        group = 'Base', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelC',
        type = 'float',   
        label = 'C',  
        group = 'Fresnel', 
        format = '%.3f'  
    },

    {    
        name = 'fresnelEXP',    
        type = 'float',   
        label = 'EXP',  
        group = 'Fresnel', 
        format = '%.2f'  
    },

    {
        name = 'fresnelMaxLevel',    
        type = 'float',   
        label = 'Max Level',  
        group = 'Fresnel', 
        format = '%.3f'  
    },

    -- Vector3
    {    
        name = 'ksEmissive',    
        type = 'vec3',   
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000    
    },

    -- Boolean / 0 or 1
    {
        name = 'isAdditive',    
        type = 'bool',   
        label = 'Additive',  
        group = 'Flags' 
    },
}    


local PARAMS_KS_PERPIXEL_ALPHA = {
    ------------------------------------------------------------
    -- ksWindScreen
    ------------------------------------------------------------
    
    -- Scalar
    { 
        name = 'ksAmbient',    
        type = 'float',   
        label = 'Ambient',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksDiffuse',
        type = 'float',   
        label = 'Diffuse',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecular',    
        type = 'float',   
        label = 'Specular',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'ksSpecularEXP',    
        type = 'float',   
        label = 'Specular EXP',  
        group = 'Base', 
        format = '%.1f'  
    },

    {
        name = 'ksAlphaRef',    
        type = 'float',   
        label = 'Alpha Ref',  
        group = 'Base', 
        format = '%.3f'  
    },

    {
        name = 'alpha',    
        type = 'float',   
        label = 'Final Alpha',  
        group = 'Base', 
        format = '%.3f'  
    },

    -- Vector3
    {    
        name = 'ksEmissive',    
        type = 'vec3',   
        labelX = 'Emissive R',  
        labelY = 'Emissive G',  
        labelZ = 'Emissive B',  
        group = 'Emissive', 
        format = '%.3f',
        rangeMin = 0.000,
        rangeMax = 1.000    
    },
}    


    ------------------------------------------------------------
    -- Material Definition
    ------------------------------------------------------------
    MATERIAL_EDITORS = {


        ------------------------------------------------------------
        -- materials profile: visor_lando_2025Champion_maxquality.kn5 
        ------------------------------------------------------------

        {
            id = 'OVRBODYFABRIC',

            meshName = 
                'BODY_FABRIC_OVERLAY',

            materialName = 
                'DUMMY',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_ALPHA,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },
				
        {
            id = 'OVRBODYFRAME',

            meshName = 
                'BODY_FRAME_OVERLAY',

            materialName = 
                'DUMMY',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_ALPHA,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },
        
        {
            id = 'OVRRUBBERBAND',

            meshName = 
                'BODY_GLASSLINE_OVERLAY',

            materialName = 
                'DUMMY',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_ALPHA,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },


        {
            id = 'OVRGLASSCOAT',

            meshName = 
                'GLASS_COATING_OVERLAY',

            materialName = 
                'DUMMY',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_ALPHA,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },        

        {
            id = 'OVRGLASSEXT',

            meshName = 
                'GLASS_EXT_OVERLAY',

            materialName = 
                'DUMMY',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_ALPHA,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },

        {
            id = 'OVRGLASSINT',

            meshName = 
                'GLASS_INT_OVERLAY',

            materialName = 
                'DUMMY',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_ALPHA,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },
				
				
        {
            id = 'OVRGLASSRAINFX',

            meshName = 
                'GLASS_RAINFX_OVERLAY',

            materialName = 
                'DUMMY',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_ALPHA,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },
        
        {
            id = 'BODYCAM',

            meshName = 
                'BODY_CAM',

            materialName = 
                'mtBODY_CAM',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },

        {
            id = 'BODYCAMHOUSE',

            meshName = 
                'BODY_CAM_HOUSE',

            materialName = 
                'mtBODY_CAM_HOUSE',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_MULTIMAP,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },

        {
            id = 'BODYCAMLENS',

            meshName = 
                'BODY_CAM_LENS',

            materialName = 
                'mtBODY_CAM_LENS',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_ALPHA,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },

        {
            id = 'BODYFRAME',

            meshName = 
                'BODY_FRAME',

            materialName = 
                'mtBODY_FRAME',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_MULTIMAP,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },


        {
            id = 'RUBBERBAND',

            meshName = 
                'BODY_GLASSLINE',

            materialName = 
                'mtBODY_GLASSLINE',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_NM,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },
        
        
        {
            id = 'GLASSINT',

            meshName = 
                'GLASS_INT',

            materialName = 
                'mtGLASS_INT',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_MULTIMAP_EMISSIVE,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },

        {
            id = 'GLASSEXTBAND',

            meshName = 
                'GLASS_EXT_BAND',

            materialName = 
                'mtGLASS_EXT_BAND',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_MULTIMAP_EMISSIVE,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },


        {
            id = 'GLASSCOATINGREFL',

            meshName = 
                'GLASS_COATING_REFL',

            materialName = 
                'mtGLASS_COATING_REFL',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_MULTIMAP_EMISSIVE,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },

        {
            id = 'GLASSEXTDUMMY',

            meshName = 
                'GLASS_EXT_DUMMY',

            materialName = 
                'mtGLASS_EXT_DUMMY',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_MULTIMAP,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },


        {
            id = 'MRRBODYBRACKET',

            meshName = 
                'BODY_BRACKET_MIRROR',

            materialName = 
                'mtBODY_BRACKET_MIRROR',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_NM,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },


        {
            id = 'MRRBODYFRAME',

            meshName = 
                'BODY_FRAME_MIRROR',

            materialName = 
                'mtBODY_FRAME',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_MULTIMAP,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },


        {
            id = 'MRRSCREWBLACK',

            meshName = 
                'BODY_SCREW_BLACK_MIRROR',

            materialName = 
                'mtBODY_SCREW_BLACK_MIRROR',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_MULTIMAP,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },

        {
            id = 'MRRSCREWFRAMEBLACK',

            meshName = 
                'BODY_SCREW_FRAME_BLACK_MIRROR',

            materialName = 
                'mtBODY_SCREW_FRAME_BLACK_MIRROR',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_NM,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },
        
        {
            id = 'MRRSCREWMETAL',

            meshName = 
                'BODY_SCREW_METAL_MIRROR',

            materialName = 
                'mtBODY_SCREW_METAL_MIRROR',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_MULTIMAP,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },
        
        {
            id = 'MRRSILICON',

            meshName = 
                'BODY_SILICON_MIRROR',

            materialName = 
                'mtBODY_SILICON_MIRROR',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },
        
        {
            id = 'MRRBODYWING',

            meshName = 
                'BODY_WING_MIRROR',

            materialName = 
                'mtBODY_WING_MIRROR',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXELNM_UV_MULT,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },

        {
            id = 'MRRGLASSCOAT',

            meshName = 
                'GLASS_COATING_MIRROR',

            materialName = 
                'mtGLASS_COATING_MIRROR',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_MULTIMAP_EMISSIVE,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },        
        

        {
            id = 'MRRGLASS',

            meshName = 
                'GLASS_MIRROR',

            materialName = 
                'mtGLASS_MIRROR',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_MULTIMAP,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        },


        {
            id = 'MRRGLASSSTICKER',

            meshName = 
                'GLASS_STICKER_MIRROR',

            materialName = 
                'mtGLASS_STICKER_MIRROR',

            targetMesh = nil,
            materialQueryRef = nil,

            parameters = 
                PARAMS_KS_PERPIXEL_REFLECTION,

            values = {},

            inputBuffers = {},
            
            loaded = false,
            lastError = nil,

            visible = true,
        }
    }    




--------------------------------------------------------
-- Helper function: Clamp
--------------------------------------------------------

local function clampValue(value, minimum, maximum)  

    if value < minimum then
        return minimum
    end

    if value > maximum then 
        return maximum
    end

    return value
end

--------------------------------------------------------
-- Helper function: String to number safely 
--------------------------------------------------------
local function safe_tonumber(str, default)
    -- 1. Default value fallback (ensures we return a number even if 'default' isn't passed)
    local fallback = default or 0
    
    -- 2. Nil check
    if str == nil then 
        return fallback 
    end
    
    -- 3. Clean up the string (remove leading/trailing spaces if it's a string)
    if type(str) == "string" then
        str = str:match("^%s*(.-)%s*$")
    end
    
    -- 4. Attempt conversion
    local num = tonumber(str)
    
    -- 5. Return the successfully parsed number or the fallback
    return num or fallback
end

------------------------------------------------------------
-- Material Parameter Prototype: helpers
--
-- Read and Apply are kept strictly separate:
--   - loadMaterialParams() reads current values from the material
--     into extDirtValues (UI state). Only called on init / manual reload.
--   - applyMaterialParams() pushes edited UI state back onto the
--     material. Only called when the user presses "Refresh".
-- The per-frame UI code only ever touches extDirtValues, never the
-- material directly, so scrubbing a slider can never fight with a
-- material read happening on the same frame.
------------------------------------------------------------


--------------------------------------------------------
-- Default value per declared parameter type
--------------------------------------------------------

local function defaultMaterialValue(paramType)

    if paramType == 'float' then
        return 0.0

    elseif paramType == 'vec2' then
        return vec2(0, 0)

    elseif paramType == 'vec3' then
        return vec3(0, 0, 0)

    elseif paramType == 'bool' then
        return false
    end

    return 0.0
end


--------------------------------------------------------
-- Safely read one property off a SceneReference
--
-- NOTE: exact CSP getter name/behavior for reading back a live
-- material property value was not fully verifiable at the time of
-- writing (see chat notes). This is wrapped in pcall and falls back
-- to a type-appropriate default so the tool never hard-crashes the
-- script if the getter is missing/renamed on a given CSP build --
-- worth double-checking against your local CSP Lua docs.
--------------------------------------------------------

local function readMaterialProperty(meshRef, paramDef)

    if not meshRef then
        return defaultMaterialValue(paramDef.type), false
    end

    local ok, result = pcall(
        function()
            return meshRef:getMaterialPropertyValue(paramDef.name)
        end
    )

    if not ok or result == nil then
        return defaultMaterialValue(paramDef.type), false
    end

    return result, true
end


--------------------------------------------------------
-- Read all EXTDIRT_PARAMETERS from the material into
-- extDirtValues (UI state only, does not touch the material).
--------------------------------------------------------

local function loadMaterialParams(editor)

    editor.values = {}

    if not editor.targetMesh 
        or #editor.targetMesh == 0 then

        ac.warn(
            appNameDebug 
            .. ' MATERIAL: ' 
            .. editor.meshName
            .. ' mesh not available'
        )

        editor.loaded = false

        return false 
    end

    for _, paramDef in ipairs(editor.parameters) do

        local rawValue, readOk =
            readMaterialProperty(
                editor.targetMesh, 
                paramDef)

        local entry = {
            type = paramDef.type,
            readOk = readOk
        }

        if paramDef.type == 'float' then

            entry.value = 
                tonumber(rawValue) 
                or 0.0

        elseif paramDef.type == 'bool' then            

            if type(rawValue) == 'boolean' then

                entry.value = rawValue

            elseif type(rawValue) == 'number' then

                entry.value = 
                    rawValue > 0.5

            else

                entry.value = false
            end

        elseif paramDef.type == 'vec2' then

            local okX, xValue = 
                pcall(function() 
                    return rawValue.x 
                end)

            local okY, yValue = 
                pcall(function() 
                    return rawValue.y                         
                end)

            if okX and okY 
                and xValue ~= nil 
                and yValue ~= nil then

                entry.value = vec2(xValue, yValue)

            else

                entry.value = vec2(0, 0)
            end

        elseif paramDef.type == 'vec3' then

            local okX, xValue = 
                pcall(function() 
                    return rawValue.x 
                end)

            local okY, yValue = 
                pcall(function() 
                    return rawValue.y                     
                end)
                
            local okZ, zValue = 
                pcall(function() 
                    return rawValue.z                        
                end)

            if okX and okY and okZ 
                and xValue ~= nil 
                and yValue ~= nil 
                and zValue ~= nil then

                entry.value = 
                    vec3(xValue, yValue, zValue)

            else

                entry.value = 
                    vec3(0, 0, 0)
            end
        end

        editor.values[paramDef.name] = entry

    end

    editor.loaded = true
    editor.lastError = nil

    ac.log(
        appNameDebug 
        .. ' MATERIAL: ' 
        .. editor.materialName 
        .. ' parameters loaded'
    )

    return true
end


--------------------------------------------------------
-- Push edited extDirtValues back onto the material.
-- Only called explicitly (Refresh button) -- never per-frame.
--------------------------------------------------------

local function applyMaterialParams(editor)

    if not editor.targetMesh
        or #editor.targetMesh == 0 then

        editor.lastError = 
             editor.meshName 
             .. ' mesh not available'

        return false
    end

    local allOk = true

    for _, paramDef in ipairs(editor.parameters) do

        local entry = 
            editor.values[paramDef.name]

        if entry then

            local sendValue = entry.value

            if paramDef.type == 'bool' then

                if cfg.RUNTIME.MATERIAL_BOOL_AS_NUMBER then
                    sendValue = entry.value and 1.0 or 0.0
                else
                    sendValue = entry.value and true or false
                end
            end

            local ok, err = pcall(
                function()
                    editor.targetMesh:setMaterialProperty(
                        paramDef.name,
                        sendValue
                    )
                end
            )

            if not ok then

                allOk = false

                editor.lastError = 
                    paramDef.name 
                    .. ': ' 
                    .. tostring(err)

                ac.warn(
                    appNameDebug .. ' MATERIAL: failed to set "' .. paramDef.name .. '" -> ' .. tostring(err)
                )
            end
        end
    end

    if allOk then

        editor.lastError = nil

        ac.log(
            appNameDebug 
            .. ' MATERIAL: ' 
            .. editor.materialName 
            .. ' parameters applied'
        )
    end

    return allOk
end


------------------------------------------------------------
-- Apply scale
------------------------------------------------------------

local function applyScale()

    if not scaleNode then
        return
    end


    if math.abs(
        activeScale - lastScale
    ) < 0.000001 then
        return
    end


    local transform =
        scaleNode:getTransformationRaw()


    if transform then

        transform:set(

            mat4x4.scaling(
                vec3.new(activeScale)
            )
        )
    end


    lastScale = activeScale
end


------------------------------------------------------------
-- Apply model axis correction
------------------------------------------------------------

local function applyAxisCorrection()

    ------------------------------------------------------------
    -- Pitch
    ------------------------------------------------------------

    if axisPitchNode
        and math.abs(
            activePitch - lastPitch
        ) >= 0.0001 then

        axisPitchNode:setRotation(

            vec3(1, 0, 0),

            math.rad(
                activePitch
            )
        )

        lastPitch =
            activePitch
    end


    ------------------------------------------------------------
    -- Yaw
    ------------------------------------------------------------

    if axisYawNode
        and math.abs(
            activeYaw - lastYaw
        ) >= 0.0001 then

        axisYawNode:setRotation(

            vec3(0, 1, 0),

            math.rad(
                activeYaw
            )
        )

        lastYaw=
            activeYaw
    end


    ------------------------------------------------------------
    -- Roll
    ------------------------------------------------------------

    if axisRollNode
        and math.abs(
            activeRoll - lastRoll
        ) >= 0.0001 then

        axisRollNode:setRotation(

            vec3(0, 0, 1),

            math.rad(
                activeRoll
            )
        )

        lastRoll=
            activeRoll
    end
end


local function updateHelmetVisibility()

    local p = getActiveProfile()

    if not driverHeads

        or #driverHeads == 0 then

        return

    end


    for _, helmet in ipairs(driverHeads) do

        local transform =

            helmet:getTransformationRaw()
        

        if transform then

            if p.HIDE_DRIVER_HELMET == 1 then                
                    
                transform:set(

                    cfg.RUNTIME.HIDE_DRIVER_HELMET_SCALE

                )

            else
                
                transform:set(
                
                    cfg.RUNTIME.SHOW_DRIVER_HELMET_SCALE

                )


            end

        end
        
    end
    

end


------------------------------------------------------------
-- Find Driver Head
--
-- Observation only.
-- This does NOT modify the driver head or camera.
------------------------------------------------------------

local function findDriverHeadAndNeck()

    local foundNek = 
        ac.findNodes('DRIVER:RIG_Nek')


    if not foundNek
        or #foundNek == 0 then

        driverNeck = nil

        if not nekFoundLogged then

            ac.warn(
                appNameDebug
                .. ' NEK: DRIVER:RIG_Nek not found'
            )

            nekFoundLogged = true
        end

        return false
    end


    --------------------------------------------------------
    -- Try to find the physical driver head node
    --------------------------------------------------------
    
    local foundHead =
        ac.findNodes('DRIVER:RIG_Head')


    if not foundHead
        or #foundHead == 0 then

        driverHeads = nil

        if not headFoundLogged then

            ac.warn(
                appNameDebug
                .. ' HEAD: DRIVER:RIG_Head not found'
            )

            headFoundLogged = true
        end

        return false
    end

    
    --------------------------------------------------------
    -- Keep the reference
    --------------------------------------------------------

    driverNecks = foundNek
    driverHeads = foundHead


    if not headFoundLogged 
        and not nekFoundLogged then

        ac.log(
            appNameDebug
            .. ' HEAD: DRIVER:RIG_Head found'
            .. ' | count='
            .. tostring(#foundHead)
        )

        headFoundLogged = true


        for neckIndex, node in ipairs(driverNecks) do
            realCamDebugStates[neckIndex] = createRealCamDebugState()
                        

            if neckIndex == 1 then
                
                driverNeck = node

            end


            --------------------------------------------------------
            -- Debug Nek Hierarchy
            --------------------------------------------------------


            ac.log(
                appNameDebug
                .. ' NECK[' .. neckIndex .. '] Hierarchy:'
            )

            
            for depth = 1, 10 do

                ----------------------------------------------------
                -- SceneReference can be empty even when it is not nil
                ----------------------------------------------------

                if node == nil or #node == 0 then
                    ac.log(
                        appNameDebug
                        .. ' NECK[' .. neckIndex .. '] '
                        .. 'Hierarchy end at depth='
                        .. tostring(depth)
                    )

                    break
                end


                ----------------------------------------------------
                -- Node name
                ----------------------------------------------------

                local strTab =
                    string.rep('  ', depth - 1)

                ac.log(
                    appNameDebug
                    .. strTab
                    .. '└── '
                    .. '[' .. node:name() .. ']'
                )


                ----------------------------------------------------
                -- Move to parent
                ----------------------------------------------------

                node = node:getParent()
                
            end

        end
        

        -- show/hide models when loaded (one time load)

        updateHelmetVisibility()

    end

    return true
end



------------------------------------------------------------
-- Observe Driver Head (actually it Observes Neck instead)
--
-- Observation only.
-- No camera modification.
------------------------------------------------------------

local function observeDriverHead(dt)

    if not cfg.RUNTIME.DEBUG_HEAD then
        return
    end


    --------------------------------------------------------
    -- Find neck if needed
    --------------------------------------------------------

    if not driverNeck
        or #driverNeck == 0 
        or not driverHeads
        or #driverHeads == 0 then

        if not findDriverHeadAndNeck() then
            return 
        end
    end


    for _, node in ipairs(driverHeads) do 

        -- node:setVisible(not cfg.RUNTIME.HIDE_DRIVER_HELMET)


    end


    for i, selectNeck in ipairs(driverNecks) do
        

        --------------------------------------------------------
        -- Read transform components
        --------------------------------------------------------

        local position =
            selectNeck:getPosition()

        local look =
            selectNeck:getLook()

        local up =
            selectNeck:getUp()


        if position
            and look
            and up then


            --------------------------------------------------------
            -- First frame
            --------------------------------------------------------

            if realCamDebugStates[i].referencePosition == nil then

                realCamDebugStates[i].referencePosition =
                    vec3(
                        position.x,
                        position.y,
                        position.z
                    )

                realCamDebugStates[i].previousPosition =
                    vec3(
                        position.x,
                        position.y,
                        position.z
                    )

                realCamDebugStates[i].headReferenceLook =
                    vec3(
                        look.x,
                        look.y,
                        look.z
                    )

                realCamDebugStates[i].previousLook =
                    vec3(
                        look.x,
                        look.y,
                        look.z
                    )

                realCamDebugStates[i].headReferenceUp =
                    vec3(
                        up.x,
                        up.y,
                        up.z
                    )

                realCamDebugStates[i].previousUp =
                    vec3(
                        up.x,
                        up.y,
                        up.z
                    )

                ac.log(
                    appNameDebug
                    .. ' HEAD[' .. i .. ']: reference captured'
                )

            else


                --------------------------------------------------------
                -- Reference delta
                --------------------------------------------------------

                local deltaPosition =
                    position - realCamDebugStates[i].referencePosition

                local deltaLook =
                    look - realCamDebugStates[i].headReferenceLook

                local deltaUp =
                    up - realCamDebugStates[i].headReferenceUp


                --------------------------------------------------------
                -- Frame delta
                --------------------------------------------------------

                local frameDeltaPosition =
                    position - realCamDebugStates[i].previousPosition

                local frameDeltaLook =
                    look - realCamDebugStates[i].previousLook

                local frameDeltaUp =
                    up - realCamDebugStates[i].previousUp


                --------------------------------------------------------
                -- Save current state
                --------------------------------------------------------

                realCamDebugStates[i].previousPosition:set(position)
                realCamDebugStates[i].previousLook:set(look)
                realCamDebugStates[i].previousUp:set(up)


                --------------------------------------------------------
                -- Debug Logger by Timer
                --------------------------------------------------------

                realCamDebugStates[i].debugTimer =
                    realCamDebugStates[i].debugTimer + (dt or 0)

                if realCamDebugStates[i].debugTimer <= cfg.RUNTIME.DEBUG_TIMER then
    
                    --------------------------------------------------------
                    -- LOG: Position
                    --------------------------------------------------------
    
                    ac.log(
                        appNameDebug
                        .. ' HEAD[' .. i .. '] POS '
                        .. 'P('
                        .. string.format('%.4f', position.x)
                        .. ', '
                        .. string.format('%.4f', position.y)
                        .. ', '
                        .. string.format('%.4f', position.z)
                        .. ')'
                        .. ' REFΔ('
                        .. string.format('%.4f', deltaPosition.x)
                        .. ', '
                        .. string.format('%.4f', deltaPosition.y)
                        .. ', '
                        .. string.format('%.4f', deltaPosition.z)
                        .. ')'
                        .. ' FRAMEΔ('
                        .. string.format('%.5f', frameDeltaPosition.x)
                        .. ', '
                        .. string.format('%.5f', frameDeltaPosition.y)
                        .. ', '
                        .. string.format('%.5f', frameDeltaPosition.z)
                        .. ')'
                    )
    
    
                    --------------------------------------------------------
                    -- LOG: Look
                    --------------------------------------------------------
    
                    ac.log(
                        appNameDebug
                        .. ' HEAD[' .. i .. '] LOOK '
                        .. 'L('
                        .. string.format('%.4f', look.x)
                        .. ', '
                        .. string.format('%.4f', look.y)
                        .. ', '
                        .. string.format('%.4f', look.z)
                        .. ')'
                        .. ' Δ('
                        .. string.format('%.5f', deltaLook.x)
                        .. ', '
                        .. string.format('%.5f', deltaLook.y)
                        .. ', '
                        .. string.format('%.5f', deltaLook.z)
                        .. ')'
                    )
    
    
                    --------------------------------------------------------
                    -- LOG: Up
                    --------------------------------------------------------
    
                    ac.log(
                        appNameDebug
                        .. ' HEAD[' .. i .. '] UP '
                        .. 'U('
                        .. string.format('%.4f', up.x)
                        .. ', '
                        .. string.format('%.4f', up.y)
                        .. ', '
                        .. string.format('%.4f', up.z)
                        .. ')'
                        .. ' Δ('
                        .. string.format('%.5f', deltaUp.x)
                        .. ', '
                        .. string.format('%.5f', deltaUp.y)
                        .. ', '
                        .. string.format('%.5f', deltaUp.z)
                        .. ')'
                    )


                else

                    realCamDebugStates[i].debugTimer = 0

                end
            end
        end
    end
end


--------------------------------------------------------
-- RainFX persistent GPU state
--------------------------------------------------------

local function rainStateCountForMode()
    return math.max(
        1,
        math.floor(
            cfg.RUNTIME.RAIN_GPU_STATE_MODE == 4
            and 9
            or cfg.RUNTIME.RAIN_GPU_STATE_MODE == 10
            and 9
            or cfg.RUNTIME.RAIN_GPU_STATE_MODE == 7
            and 1
            or rainDynamicSceneCopyState.allocatedStateCount
            or cfg.RUNTIME.RAIN_GPU_STATE_COUNT
        )
    )
end

-- A low-rain anchor keeps the user's accepted 0.03 population while
-- filling the existing 512 slots more rapidly at higher rain rates.
-- Store helpers on the existing state table to avoid Lua's chunk-local cap.
rainDynamicSceneCopyState.lifecycleTargetForRain = function(rain)
    if rain <= 0.001 then return 0.0 end
    if rain <= 0.03 then
        return 0.05 + 0.90 * math.sqrt(rain)
    elseif rain <= 0.08 then
        return 0.206 + (0.60 - 0.206) * (rain - 0.03) / 0.05
    elseif rain <= 0.31 then
        return 0.60 + (0.85 - 0.60) * (rain - 0.08) / 0.23
    elseif rain <= 0.50 then
        return 0.85 + (0.95 - 0.85) * (rain - 0.31) / 0.19
    end
    return math.min(1.0, 0.95 + 0.05 * (rain - 0.50) / 0.20)
end

rainDynamicSceneCopyState.lifecycleCapacityFactor = function(rain)
    local count = math.max(rainStateCountForMode(), 512)
    local base = math.min(1.0, 512.0 / count)
    local t = math.max(0.0, math.min(1.0,
        (rain - 0.03) / 0.97))
    return base + (1.0 - base)
        * (t ^ cfg.RUNTIME.RAIN_GPU_STATE_CAPACITY_RAMP_POWER)
end

rainDynamicSceneCopyState.lifecycleExposureForVelocity = function(velocity)
    if not velocity then return 1.0 end
    local speed = math.sqrt(velocity.x * velocity.x
        + velocity.y * velocity.y + velocity.z * velocity.z)
    return 1.0 + math.min(speed / 40.0, 2.0)
        * cfg.RUNTIME.RAIN_GPU_STATE_SPEED_EXPOSURE_GAIN
end

rainDynamicSceneCopyState.lifecycleTravelMix = function(velocity)
    if not velocity then return 0.0 end
    local speed = math.sqrt(velocity.x * velocity.x
        + velocity.y * velocity.y + velocity.z * velocity.z)
    local x = math.max(0.0, math.min(1.0, (speed - 2.0) / 16.0))
    return x * x * (3.0 - 2.0 * x)
end

rainDynamicSceneCopyState.prepareSpawnAtlas = function(count)
    local st = rainDynamicSceneCopyState
    if not cfg.RUNTIME.RAIN_GPU_PRELAID_SITES or not textureRainBoundaryMask then
        return false
    end
    if st.spawnAtlas and st.spawnAtlasCount == count then return true end
    if st.spawnAtlas then st.spawnAtlas:dispose(); st.spawnAtlas = nil end
    local ok, result = pcall(function()
        local atlas = ui.ExtraCanvas(vec2(count, 1), 1,
            render.AntialiasingMode.None,
            render.TextureFormat.R32G32B32A32.Float)
            :setName('RainFX pre-laid birth sites')
        local updated = atlas:updateWithShader({
            textures = { txRainBoundaryMask = textureRainBoundaryMask },
            values = { gCount = count },
            shader = [[
                float siteHash(float n)
                {
                    return frac(sin(n * 127.1 + 311.7) * 43758.5453);
                }
                float4 main(PS_IN pin)
                {
                    int site = (int)min(floor(pin.Tex.x * gCount), gCount - 1.0);
                    float order = siteHash(site + 419.0);
                    [loop] for (int k = 0; k < 64; ++k)
                    {
                        float u = siteHash(site * 17.13 + k * 71.71);
                        float v = siteHash(site * 29.37 + k * 53.53);
                        float2 p = float2(u, -v);
                        if (txRainBoundaryMask.SampleLevel(samLinearClamp, p, 0).r >= 0.5)
                            return float4(u, 1.0 - v, order, 1.0);
                    }
                    return float4(0.5, 0.5, order, 0.0);
                }
            ]],
        })
        if updated == false then error('atlas shader pending') end
        st.spawnAtlas = atlas
        st.spawnAtlasCount = count
    end)
    st.spawnAtlasError = ok and nil or tostring(result)
    return ok
end

local function initializeRainGPUState()
    if rainStateInitialized and rainStateA and rainStateB
        and rainStateMetaA and rainStateMetaB then
        return true
    end

    local count = rainStateCountForMode()

    if not rainStateA then
        rainStateA = ui.ExtraCanvas(
            vec2(count, 1),
            1,
            render.TextureFormat.R32G32B32A32.Float
        ):setName('RainFX State A')
    end

    if not rainStateB then
        rainStateB = ui.ExtraCanvas(
            vec2(count, 1),
            1,
            render.TextureFormat.R32G32B32A32.Float
        ):setName('RainFX State B')
    end

    if not rainStateMetaA then
        rainStateMetaA = ui.ExtraCanvas(
            vec2(count, 1),
            1,
            render.TextureFormat.R32G32B32A32.Float
        ):setName('RainFX State Meta A')
    end

    if not rainStateMetaB then
        rainStateMetaB = ui.ExtraCanvas(
            vec2(count, 1),
            1,
            render.TextureFormat.R32G32B32A32.Float
        ):setName('RainFX State Meta B')
    end

    if not rainStateA or not rainStateB or not rainStateMetaA or not rainStateMetaB then
        ac.warn(appNameDebug .. ' Rain GPU state: ExtraCanvas allocation failed')
        rainStateA = nil
        rainStateB = nil
        rainStateMetaA = nil
        rainStateMetaB = nil
        return false
    end

    rainDynamicSceneCopyState.allocatedStateCount = count

    local physicalTest =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE == 10 and 1.0 or 0.0

    local physicalGridTest =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE == 4 and 1.0 or 0.0

    local lifecycle =
        (
            (cfg.RUNTIME.RAIN_GPU_STATE_MODE == 3
                or cfg.RUNTIME.RAIN_GPU_STATE_MODE == 6)
            and cfg.RUNTIME.RAIN_GPU_STATE_LIFECYCLE
        )
        and 1.0
        or 0.0

    local singleDrop =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE == 7 and 1.0 or 0.0

    rainStateUpdateParams.values.gRainStateCount = count
    rainStateUpdateParams.values.gRainStateInit = 1.0
    rainStateUpdateParams.values.gRainStatePhysicalTest = physicalTest
    rainStateUpdateParams.values.gRainStatePhysicalGridTest = physicalGridTest
    rainStateUpdateParams.values.gRainStateLifecycle = lifecycle
    rainStateUpdateParams.values.gRainStateSingleDropTest = singleDrop
    rainStateUpdateParams.values.gRainStateSingleDropPosition:set(
        cfg.RUNTIME.RAIN_GPU_STATE_SINGLE_DROP_X,
        cfg.RUNTIME.RAIN_GPU_STATE_SINGLE_DROP_Y
    )

    rainStateMetaUpdateParams.values.gRainStateCount = count
    rainStateMetaUpdateParams.values.gRainStateInit = 1.0
    rainStateMetaUpdateParams.values.gRainStateLifecycle = lifecycle
    rainStateMetaUpdateParams.values.gRainStateSingleDropTest = singleDrop
    rainStateMetaUpdateParams.values.gRainStateBoundaryMargin =
        cfg.RUNTIME.RAIN_GPU_STATE_BOUNDARY_MARGIN
    rainStateMetaUpdateParams.values.gRainStateRespawnGapMin =
        cfg.RUNTIME.RAIN_GPU_STATE_RESPAWN_GAP_MIN
    rainStateMetaUpdateParams.values.gRainStateRespawnGapMax =
        cfg.RUNTIME.RAIN_GPU_STATE_RESPAWN_GAP_MAX

    local initialSim = ac.getSim()
    local initialRain = initialSim and initialSim.rainIntensity or 0.0
    if cfg.RUNTIME.RAIN_GPU_STATE_RAIN_OVERRIDE >= 0.0 then
        initialRain = cfg.RUNTIME.RAIN_GPU_STATE_RAIN_OVERRIDE
    end
    initialRain = math.max(0.0, math.min(1.0, initialRain or 0.0))
    rainDynamicSceneCopyState.lifecycleRainSmoothed = initialRain
    local initialCar = ac.getCar(0)
    rainStateUpdateParams.values.gRainStateTravelMix =
        rainDynamicSceneCopyState.lifecycleTravelMix(
            initialCar and initialCar.velocity)
    local initialExposure =
        rainDynamicSceneCopyState.lifecycleExposureForVelocity(
            initialCar and initialCar.velocity)
    rainStateUpdateParams.values.gRainStateRainIntensity = initialRain
    rainStateMetaUpdateParams.values.gRainStateRainIntensity = initialRain
    rainStateMetaUpdateParams.values.gRainStateExposure = initialExposure
    rainStateMetaUpdateParams.values.gRainStateTargetOccupancy =
        math.min(1.0,
            rainDynamicSceneCopyState.lifecycleTargetForRain(initialRain)
                * rainDynamicSceneCopyState.lifecycleCapacityFactor(initialRain)
                * cfg.RUNTIME.RAIN_GPU_STATE_DENSITY_SCALE
                * initialExposure)
    rainStateMetaUpdateParams.values.gRainStateAgeMin =
        cfg.RUNTIME.RAIN_GPU_STATE_AGE_MIN_SECONDS
    rainStateMetaUpdateParams.values.gRainStateAgeMax =
        cfg.RUNTIME.RAIN_GPU_STATE_AGE_MAX_SECONDS

    rainStateUpdateParams.textures.txRainState = false
    rainStateUpdateParams.textures.txRainStateMeta = false
    rainStateUpdateParams.textures.txRainSurfaceNormal = false
    rainStateUpdateParams.textures.txRainBoundaryMask = textureRainBoundaryMask
    local atlasReady = rainDynamicSceneCopyState.prepareSpawnAtlas(count)
    rainStateUpdateParams.textures.txRainSpawnAtlas =
        atlasReady and rainDynamicSceneCopyState.spawnAtlas or false
    rainStateUpdateParams.values.gRainSpawnAtlasEnabled = atlasReady and 1.0 or 0.0

    rainStateMetaUpdateParams.textures.txRainStateMeta = false
    rainStateMetaUpdateParams.textures.txRainState = false
    rainStateMetaUpdateParams.textures.txRainBoundaryMask = textureRainBoundaryMask
    rainStateMetaUpdateParams.textures.txRainSpawnAtlas =
        atlasReady and rainDynamicSceneCopyState.spawnAtlas or false
    rainStateMetaUpdateParams.values.gRainSpawnAtlasEnabled = atlasReady and 1.0 or 0.0
    rainStateUpdateParams.values.gRainMergeEnabled = 0.0
    rainStateMetaUpdateParams.values.gRainMergeEnabled = 0.0

    local initPasses = {
        { rainStateA, rainStateUpdateParams, 'state A' },
        { rainStateB, rainStateUpdateParams, 'state B' },
        { rainStateMetaA, rainStateMetaUpdateParams, 'meta A' },
        { rainStateMetaB, rainStateMetaUpdateParams, 'meta B' },
    }
    for _, pass in ipairs(initPasses) do
        local ok, result = pcall(function()
            return pass[1]:updateWithShader(pass[2])
        end)
        if not ok or result == false then
            if not rainDynamicSceneCopyState.stateInitWarning then
                ac.warn(appNameDebug .. ' Rain GPU state init pending at '
                    .. pass[3] .. ': ' .. tostring(result))
                rainDynamicSceneCopyState.stateInitWarning = true
            end
            return false
        end
    end
    rainDynamicSceneCopyState.stateInitWarning = false

    rainStateUpdateParams.values.gRainStateInit = 0.0
    rainStateMetaUpdateParams.values.gRainStateInit = 0.0

    rainStateReadIsA = true
    rainStateInitialized = true
    rainStateConfiguredMode = cfg.RUNTIME.RAIN_GPU_STATE_MODE
    rainStateLastFrame = -1

    ac.log(
        appNameDebug
        .. ' Rain GPU state initialized: '
        .. tostring(count)
        .. ' physical droplets'
    )

    return true
end

-- Coalescence / steering commands (docs/RAINFX_COALESCENCE.md). Built once
-- per readback snapshot with a uniform grid, drawn into a count x 1 RGBA8
-- canvas: R,G = partner index bytes, B = type * 64 + partner generation % 64.
rainDynamicSceneCopyState.updateMergeCommands = function(count, lifecycleOn)
    local state = rainDynamicSceneCopyState
    local r = cfg.RUNTIME
    if not state.mergeCmd or state.mergeCmdCount ~= count then
        if state.mergeCmd then state.mergeCmd:dispose() end
        state.mergeCmd = ui.ExtraCanvas(vec2(count, 1), 1,
            render.TextureFormat.R8G8B8A8.UNorm)
            :setName('RainFX merge commands')
        state.mergeCmd:clear(rgbm.colors.transparent)
        state.mergeCmdCount = count
        state.mergeSnapshot = nil
    end
    local wantMerge = r.RAIN_GPU_STATE_MERGE_ENABLED
    local wantAttract = r.RAIN_GPU_STATE_ATTRACT_ENABLED
    if not lifecycleOn or not rainDynamicStateHasSnapshot
        or not (wantMerge or wantAttract) then
        if state.mergeActive then
            state.mergeCmd:clear(rgbm.colors.transparent)
            state.mergeActive = false
        end
        state.mergePairs, state.mergeAttracts = 0, 0
        return false
    end
    if state.mergeSnapshot == rainDynamicStateSnapshotTime then return true end
    state.mergeSnapshot = rainDynamicStateSnapshotTime

    local n = math.min(count, rainDynamicStateReadbackCount)
    local age = math.min(math.max(
        rainDynamicStateRenderClock - rainDynamicStateSnapshotTime, 0.0),
        r.RAIN_DYNAMIC_STATE_PREDICTION_MAX_SECONDS)
    local px, py = state.mergePX or {}, state.mergePY or {}
    state.mergePX, state.mergePY = px, py
    local maxR = 0.0
    for i = 1, n do
        if (rainDynamicStateAlive[i] or 0.0) > 0.5 then
            px[i] = (rainDynamicStateU[i] or 0.0)
                + (rainDynamicStateVelocityU[i] or 0.0) * age
            py[i] = (rainDynamicStateV[i] or -1.0)
                + (rainDynamicStateVelocityV[i] or 0.0) * age
            maxR = math.max(maxR, rainDynamicStateRadius[i] or 0.0)
        else
            px[i] = nil
        end
    end
    local mergeReach = r.RAIN_GPU_STATE_MERGE_REACH
    local attractReach = r.RAIN_GPU_STATE_ATTRACT_REACH
    local cell = math.max(2.0 * maxR * math.max(mergeReach, attractReach),
        1e-4)
    local grid = {}
    for i = 1, n do
        if px[i] then
            local key = math.floor(px[i] / cell) * 65536
                + math.floor((py[i] + 1.0) / cell)
            local bucket = grid[key]
            if not bucket then bucket = {}; grid[key] = bucket end
            bucket[#bucket + 1] = i
        end
    end
    local partner = {}
    local kind = {}
    local pairCount = 0
    local attracts = 0
    local maxPairs = math.max(0, math.floor(r.RAIN_GPU_STATE_MERGE_MAX_PAIRS))
    local minSpeed = r.RAIN_GPU_STATE_ATTRACT_MIN_SPEED
    local cone = r.RAIN_GPU_STATE_ATTRACT_CONE
    for i = 1, n do
        local xi = px[i]
        if xi and not partner[i] then
            local yi = py[i]
            local ri = rainDynamicStateRadius[i] or 0.0
            local cx = math.floor(xi / cell)
            local cy = math.floor((yi + 1.0) / cell)
            local bestJ, bestD = nil, math.huge
            local vu = rainDynamicStateVelocityU[i] or 0.0
            local vv = rainDynamicStateVelocityV[i] or 0.0
            local speed = math.sqrt(vu * vu + vv * vv)
            local steerJ, steerD = nil, math.huge
            for gx = cx - 1, cx + 1 do
                for gy = cy - 1, cy + 1 do
                    local bucket = grid[gx * 65536 + gy]
                    if bucket then
                        for _, j in ipairs(bucket) do
                            if j ~= i then
                                local dx, dy = px[j] - xi, py[j] - yi
                                local d = math.sqrt(dx * dx + dy * dy)
                                local rs = ri + (rainDynamicStateRadius[j]
                                    or 0.0)
                                if wantMerge and not partner[j]
                                    and d < rs * mergeReach and d < bestD
                                then
                                    bestJ, bestD = j, d
                                end
                                if wantAttract and speed >= minSpeed
                                    and d < rs * attractReach and d < steerD
                                    and (dx * vu + dy * vv)
                                        > cone * d * speed
                                then
                                    steerJ, steerD = j, d
                                end
                            end
                        end
                    end
                end
            end
            if bestJ and pairCount < maxPairs then
                partner[i], kind[i] = bestJ, 1
                partner[bestJ], kind[bestJ] = i, 1
                pairCount = pairCount + 1
            elseif steerJ then
                partner[i], kind[i] = steerJ, 2
                attracts = attracts + 1
            end
        end
    end
    local generation = state.generation or {}
    state.mergeCmd:clear(rgbm.colors.transparent)
    if pairCount + attracts > 0 then
        local color = rgbm(0.0, 0.0, 0.0, 1.0)
        local p1, p2 = vec2(), vec2()
        state.mergeCmd:update(function()
            for i = 1, n do
                local j = partner[i]
                if j then
                    local slot = j - 1 -- shader index is 0-based
                    local genLow = (generation[j] or 0) % 64
                    color.r = math.floor(slot / 256) / 255.0
                    color.g = (slot % 256) / 255.0
                    color.b = (kind[i] * 64 + genLow) / 255.0
                    color.mult = 1.0
                    p1.x, p1.y = i - 1, 0
                    p2.x, p2.y = i, 1
                    ui.drawRectFilled(p1, p2, color)
                end
            end
        end)
    end
    state.mergeActive = true
    state.mergePairs = pairCount
    state.mergeAttracts = attracts
    state.mergePairsTotal = (state.mergePairsTotal or 0) + pairCount
    return true
end

local function updateRainGPUState(sim)
    if rainStateSingleDropDirty
        or (
            rainStateConfiguredMode ~= nil
            and rainStateConfiguredMode ~= cfg.RUNTIME.RAIN_GPU_STATE_MODE
        )
    then
        rainStateA = nil
        rainStateB = nil
        rainStateMetaA = nil
        rainStateMetaB = nil
        rainStateInitialized = false
        rainStateReadIsA = true
        rainStateLastFrame = -1
        rainStateConfiguredMode = nil
        rainStateSingleDropDirty = false
    end

    if cfg.RUNTIME.RAIN_GPU_STATE_MODE <= 0 then
        return
    end

    if not initializeRainGPUState() or not rainStateInitialized then
        return
    end

    local frame = sim and sim.frame
    if frame == nil or rainStateLastFrame == frame then
        return
    end

    rainStateLastFrame = frame

    if cfg.RUNTIME.RAIN_GPU_STATE_FREEZE_DEBUG then
        local deadline = rainDynamicSceneCopyState.stateFreezeUntil
        if deadline and os.preciseClock() < deadline then return end
        -- A probe must not silently persist across a reload or a drive.
        cfg.RUNTIME.RAIN_GPU_STATE_FREEZE_DEBUG = false
        rainDynamicSceneCopyState.stateFreezeUntil = nil
    end

    if cfg.RUNTIME.RAIN_GPU_STATE_MODE == 1 then
        return
    end

    local dt = sim.dt
    if not dt or dt <= 0.000001 then
        return
    end

    local transform =
        rainTargetMesh
        and rainTargetMesh:getWorldTransformationRaw():clone()
        or mat4x4.identity()

    local count = rainStateCountForMode()

    rainStateUpdateParams.values.gRainStateDeltaTime =
        math.min(dt, 0.05)
    rainStateUpdateParams.values.gRainStateCount = count
    rainStateUpdateParams.values.gRainStatePhysics =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE >= 3 and 1.0 or 0.0
    rainStateUpdateParams.values.gRainStatePhysicalTest =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE == 10 and 1.0 or 0.0
    rainStateUpdateParams.values.gRainStatePhysicalGridTest =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE == 4 and 1.0 or 0.0
    rainStateUpdateParams.values.gRainStateLifecycle =
        (
            (cfg.RUNTIME.RAIN_GPU_STATE_MODE == 3
                or cfg.RUNTIME.RAIN_GPU_STATE_MODE == 6)
            and cfg.RUNTIME.RAIN_GPU_STATE_LIFECYCLE
        )
        and 1.0
        or 0.0
    rainStateUpdateParams.values.gRainStateSingleDropTest =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE == 7 and 1.0 or 0.0
    rainStateUpdateParams.values.gRainStateSingleDropPosition:set(
        cfg.RUNTIME.RAIN_GPU_STATE_SINGLE_DROP_X,
        cfg.RUNTIME.RAIN_GPU_STATE_SINGLE_DROP_Y
    )

    rainStateUpdateParams.values.gRainAcceleration =
        rainAccelerationCurrent

    local forceMask = 0
    if cfg.RUNTIME.RAIN_FORCE_GRAVITY_ENABLED then
        forceMask = forceMask + RAIN_FORCE_GRAVITY
    end
    if cfg.RUNTIME.RAIN_FORCE_INERTIA_ENABLED then
        forceMask = forceMask + RAIN_FORCE_INERTIA
    end
    if cfg.RUNTIME.RAIN_FORCE_AIRFLOW_ENABLED then
        forceMask = forceMask + RAIN_FORCE_AIRFLOW
    end

    rainStateUpdateParams.values.gRainForceMask = forceMask
    rainStateUpdateParams.values.gRainPhysicsAccelScale =
        cfg.RUNTIME.RAIN_PHYSICS_ACCEL_SCALE
    rainStateUpdateParams.values.gRainGravityGain =
        cfg.RUNTIME.RAIN_FORCE_GRAVITY_GAIN
    rainStateUpdateParams.values.gRainInertiaGain =
        cfg.RUNTIME.RAIN_FORCE_INERTIA_GAIN
    rainStateUpdateParams.values.gRainAirflowGain =
        cfg.RUNTIME.RAIN_FORCE_AIRFLOW_GAIN
    rainStateUpdateParams.values.gRainAirflowDownwardMode =
        cfg.RUNTIME.RAIN_AIRFLOW_DOWNWARD_MODE and 1.0 or 0.0
    rainStateUpdateParams.values.gRainAirflowDownwardGain =
        cfg.RUNTIME.RAIN_AIRFLOW_DOWNWARD_GAIN
    -- Air relative to the car: track wind minus car velocity (wind is
    -- optional, RAIN_FORCE_AIRFLOW_INCLUDE_WIND).
    do
        local awx, awz = 0.0, 0.0
        if cfg.RUNTIME.RAIN_FORCE_AIRFLOW_INCLUDE_WIND then
            awx, awz = rainDynamicSceneCopyState.windWorldMS(
                rainDynamicSceneCopyState, ac.getSim())
        end
        rainDynamicSceneCopyState.airflowWindX = awx
        rainDynamicSceneCopyState.airflowWindZ = awz
        rainStateUpdateParams.values.gRainAirVelocityWorld:set(
            awx - ac.getCar(0).velocity.x,
            -ac.getCar(0).velocity.y,
            awz - ac.getCar(0).velocity.z
        )
    end
    rainStateUpdateParams.values.gRainAirDensity =
        cfg.RUNTIME.RAIN_AIR_DENSITY
    rainStateUpdateParams.values.gRainAirDragCoeff =
        cfg.RUNTIME.RAIN_AIR_DRAG_COEFF
    rainStateUpdateParams.values.gRainStateFlowAcceleration =
        cfg.RUNTIME.RAIN_FLOW_ACCELERATION
    rainStateUpdateParams.values.gRainStateFlowSpeedScale =
        cfg.RUNTIME.RAIN_FLOW_SPEED_SCALE
    rainStateUpdateParams.values.gRainStateFlowDrag =
        cfg.RUNTIME.RAIN_FLOW_DRAG
    rainStateUpdateParams.values.gRainStateMobileSpeedMultiplier =
        cfg.RUNTIME.RAIN_GPU_STATE_MOBILE_SPEED_MULTIPLIER
    rainStateUpdateParams.values.gRainStateMobileDrag =
        cfg.RUNTIME.RAIN_GPU_STATE_MOBILE_DRAG
    rainStateUpdateParams.values.gRainStateKineticAdhesionFraction =
        cfg.RUNTIME.RAIN_GPU_STATE_KINETIC_ADHESION_FRACTION
    rainStateUpdateParams.values.gRainStateMovingForceGain =
        cfg.RUNTIME.RAIN_GPU_STATE_MOVING_FORCE_GAIN
    rainStateUpdateParams.values.gRainStateMobileThresholdUV =
        cfg.RUNTIME.RAIN_GPU_STATE_MOBILE_THRESHOLD_UV
    rainStateUpdateParams.values.gRainStatePhysicalMaxSpeed1MM =
        cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_1MM
    rainStateUpdateParams.values.gRainStateGravity =
        math.abs(
            ac.getSim()
            and ac.getSim().gravity
            or -9.81
        )
    rainStateUpdateParams.values.gRainStateAdhesionMin =
        cfg.RUNTIME.RAIN_ADHESION_MIN
    rainStateUpdateParams.values.gRainStateAdhesionMax =
        cfg.RUNTIME.RAIN_ADHESION_MAX
    rainStateUpdateParams.values.gRainObjectToWorld =
        transform

    rainStateUpdateParams.values.gRainStateBoundaryMargin =
        cfg.RUNTIME.RAIN_GPU_STATE_BOUNDARY_MARGIN
    rainStateUpdateParams.values.gRainStateRespawnGapMin =
        cfg.RUNTIME.RAIN_GPU_STATE_RESPAWN_GAP_MIN
    rainStateUpdateParams.values.gRainStateRespawnGapMax =
        cfg.RUNTIME.RAIN_GPU_STATE_RESPAWN_GAP_MAX

    rainStateMetaUpdateParams.values.gRainStateCount = count
    rainStateMetaUpdateParams.values.gRainStateDeltaTime =
        math.min(dt, 0.05)
    rainStateMetaUpdateParams.values.gRainStateLifecycle =
        (
            (cfg.RUNTIME.RAIN_GPU_STATE_MODE == 3
                or cfg.RUNTIME.RAIN_GPU_STATE_MODE == 6)
            and cfg.RUNTIME.RAIN_GPU_STATE_LIFECYCLE
        )
        and 1.0
        or 0.0
    rainStateMetaUpdateParams.values.gRainStateBoundaryMargin =
        cfg.RUNTIME.RAIN_GPU_STATE_BOUNDARY_MARGIN
    rainStateMetaUpdateParams.values.gRainStateRespawnGapMin =
        cfg.RUNTIME.RAIN_GPU_STATE_RESPAWN_GAP_MIN
    rainStateMetaUpdateParams.values.gRainStateRespawnGapMax =
        cfg.RUNTIME.RAIN_GPU_STATE_RESPAWN_GAP_MAX
    rainStateMetaUpdateParams.values.gRainStateSingleDropTest =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE == 7 and 1.0 or 0.0

    local liveRain = sim.rainIntensity or 0.0
    if cfg.RUNTIME.RAIN_GPU_STATE_RAIN_OVERRIDE >= 0.0 then
        liveRain = cfg.RUNTIME.RAIN_GPU_STATE_RAIN_OVERRIDE
        rainDynamicSceneCopyState.lifecycleRainSmoothed = liveRain
    else
        local previousRain =
            rainDynamicSceneCopyState.lifecycleRainSmoothed or liveRain
        local response = liveRain > previousRain and 3.0 or 0.20
        liveRain = previousRain + (liveRain - previousRain)
            * (1.0 - math.exp(-math.min(dt, 0.05) * response))
        rainDynamicSceneCopyState.lifecycleRainSmoothed = liveRain
    end
    liveRain = math.max(0.0, math.min(1.0, liveRain))
    local activeCar = ac.getCar(0)
    local activeVelocity = activeCar and activeCar.velocity
    local travelMix = rainDynamicSceneCopyState.lifecycleTravelMix(
        activeVelocity)
    rainDynamicSceneCopyState.currentTravelMix = travelMix
    rainStateUpdateParams.values.gRainStateTravelMix = travelMix
    local exposure = rainDynamicSceneCopyState.lifecycleExposureForVelocity(
        activeVelocity)
    rainStateUpdateParams.values.gRainStateRainIntensity = liveRain
    -- Birth-size controls affect the next generation without rebuilding state.
    for _, pair in ipairs({
        {'gRainSizeMinDry', 'RAIN_GPU_SIZE_MIN_DRY'},
        {'gRainSizeMinLight', 'RAIN_GPU_SIZE_MIN_LIGHT'},
        {'gRainSizeMinRain', 'RAIN_GPU_SIZE_MIN_RAIN'},
        {'gRainSizeMinHeavy', 'RAIN_GPU_SIZE_MIN_HEAVY'},
        {'gRainSizeMinRare', 'RAIN_GPU_SIZE_MIN_RARE'},
        {'gRainSizeMaxDry', 'RAIN_GPU_SIZE_MAX_DRY'},
        {'gRainSizeMaxLight', 'RAIN_GPU_SIZE_MAX_LIGHT'},
        {'gRainSizeMaxRain', 'RAIN_GPU_SIZE_MAX_RAIN'},
        {'gRainSizeMaxHeavy', 'RAIN_GPU_SIZE_MAX_HEAVY'},
        {'gRainSizeMaxRare', 'RAIN_GPU_SIZE_MAX_RARE'},
        {'gRainSizeBias', 'RAIN_GPU_SIZE_BIAS'},
        {'gRainSizeRareChanceDry', 'RAIN_GPU_SIZE_RARECHANCE_DRY'},
        {'gRainSizeRareChanceHeavy', 'RAIN_GPU_SIZE_RARECHANCE_HEAVY'},
    }) do
        --rainStateUpdateParams.values[pair[1]] = cfg.RUNTIME[pair[2]]
        rainStateMetaUpdateParams.values[pair[1]] = cfg.RUNTIME[pair[2]]
    end

    rainStateMetaUpdateParams.values.gRainStateRainIntensity = liveRain
    rainStateMetaUpdateParams.values.gRainStateExposure = exposure
    rainStateMetaUpdateParams.values.gRainStateTargetOccupancy =
        math.min(1.0,
            rainDynamicSceneCopyState.lifecycleTargetForRain(liveRain)
                * rainDynamicSceneCopyState.lifecycleCapacityFactor(liveRain)
                * cfg.RUNTIME.RAIN_GPU_STATE_DENSITY_SCALE * exposure)
    rainStateMetaUpdateParams.values.gRainStateAgeMin =
        cfg.RUNTIME.RAIN_GPU_STATE_AGE_MIN_SECONDS
    rainStateMetaUpdateParams.values.gRainStateAgeMax =
        cfg.RUNTIME.RAIN_GPU_STATE_AGE_MAX_SECONDS

    local readState =
        rainStateReadIsA and rainStateA or rainStateB
    local writeState =
        rainStateReadIsA and rainStateB or rainStateA
    local readMeta =
        rainStateReadIsA and rainStateMetaA or rainStateMetaB
    local writeMeta =
        rainStateReadIsA and rainStateMetaB or rainStateMetaA

    rainStateUpdateParams.textures.txRainState = readState
    rainStateUpdateParams.textures.txRainStateMeta = readMeta
    rainStateUpdateParams.textures.txRainSurfaceNormal = textureRainSurfaceNormal
    rainStateUpdateParams.textures.txRainBoundaryMask = textureRainBoundaryMask

    rainStateMetaUpdateParams.textures.txRainStateMeta = readMeta
    rainStateMetaUpdateParams.textures.txRainState = readState
    rainStateMetaUpdateParams.textures.txRainBoundaryMask = textureRainBoundaryMask

    local atlasReady = rainDynamicSceneCopyState.prepareSpawnAtlas(count)
    local atlas = atlasReady and rainDynamicSceneCopyState.spawnAtlas or false
    rainStateUpdateParams.textures.txRainSpawnAtlas = atlas
    rainStateMetaUpdateParams.textures.txRainSpawnAtlas = atlas
    rainStateUpdateParams.values.gRainSpawnAtlasEnabled = atlasReady and 1.0 or 0.0
    rainStateMetaUpdateParams.values.gRainSpawnAtlasEnabled = atlasReady and 1.0 or 0.0

    local lifecycleOn =
        rainStateMetaUpdateParams.values.gRainStateLifecycle > 0.5
    local mergeOk, mergeReady = pcall(
        rainDynamicSceneCopyState.updateMergeCommands, count, lifecycleOn)
    if not mergeOk and not rainDynamicSceneCopyState.mergeWarned then
        ac.warn(appNameDebug .. ' Merge commands failed: '
            .. tostring(mergeReady))
        rainDynamicSceneCopyState.mergeWarned = true
    end
    local mergeOn = mergeOk and mergeReady and 1.0 or 0.0
    local mergeCmd = mergeOn > 0.5 and rainDynamicSceneCopyState.mergeCmd
        or false
    for _, params in ipairs({ rainStateUpdateParams,
        rainStateMetaUpdateParams }) do
        params.textures.txRainMergeCmd = mergeCmd
        params.values.gRainMergeEnabled = mergeOn
        params.values.gRainMergeReach = cfg.RUNTIME.RAIN_GPU_STATE_MERGE_REACH
        params.values.gRainAttractReach =
            cfg.RUNTIME.RAIN_GPU_STATE_ATTRACT_REACH
        params.values.gRainAttractGain =
            cfg.RUNTIME.RAIN_GPU_STATE_ATTRACT_ENABLED
            and cfg.RUNTIME.RAIN_GPU_STATE_ATTRACT_GAIN or 0.0
        params.values.gRainMergeMaxDiameterMM =
            cfg.RUNTIME.RAIN_GPU_STATE_MERGE_MAX_DIAMETER_MM
    end
    -- Wet-path steering reads last frame's water-field trail canvas.
    local wetPath = cfg.RUNTIME.RAIN_GPU_STATE_WETPATH_ENABLED
        and rainDynamicSceneCopyState.waterTrailReady
        and rainDynamicSceneCopyState.waterTrailRead or false
    rainStateUpdateParams.textures.txRainWetPath = wetPath
    rainStateUpdateParams.values.gRainWetPathGain =
        wetPath and cfg.RUNTIME.RAIN_GPU_STATE_WETPATH_GAIN or 0.0
    rainStateUpdateParams.values.gRainWetPathMinSpeed =
        cfg.RUNTIME.RAIN_GPU_STATE_WETPATH_MIN_SPEED
    rainStateUpdateParams.values.gRainWetPathTexel =
        1.0 / math.max(rainDynamicSceneCopyState.waterTrailSize or 1024, 1)
    rainStateUpdateParams.values.gRainWetPathAhead =
        cfg.RUNTIME.RAIN_GPU_STATE_WETPATH_AHEAD
    rainStateUpdateParams.values.gRainSteerTurnRate =
        cfg.RUNTIME.RAIN_GPU_STATE_STEER_TURN_RATE
    rainStateUpdateParams.values.gRainBirthHold =
        cfg.RUNTIME.RAIN_GPU_STATE_BIRTH_HOLD_SECONDS
    rainStateUpdateParams.values.gRainBirthRamp =
        cfg.RUNTIME.RAIN_GPU_STATE_BIRTH_RAMP_SECONDS

    writeState:updateWithShader(rainStateUpdateParams)
    writeMeta:updateWithShader(rainStateMetaUpdateParams)

    rainStateReadIsA = not rainStateReadIsA
end


--------------------------------------------------------
-- Dynamic mesh renderer experiment: Stage 1
--
-- Creates one persistent mesh containing 256 small curved-surface quads.
-- The mesh is parented below axisRollNode so it follows the visor hierarchy.
-- No GPU state readback and no alterVertices() are used yet.
-- The only purpose of this stage is to validate the public
-- createMesh() -> render.mesh() path and establish a renderer
-- performance baseline against the fullscreen 256-drop search.
--------------------------------------------------------

local RAIN_DYNAMIC_MESH_TEST_HLSL = [[
float4 main(PS_IN pin)
{
    float2 uv = pin.Tex;
    float edge = smoothstep(
        0.0,
        0.08,
        min(
            min(uv.x, 1.0 - uv.x),
            min(uv.y, 1.0 - uv.y)
        )
    );

    float alpha = 0.30 + edge * 0.20;

    return float4(0.35, 0.85, 1.0, alpha);
}
]]

local function initializeRainDynamicMeshTest()
    if rainDynamicMeshTestInitialized then
        return rainDynamicMeshTest ~= nil
    end

    rainDynamicMeshTestInitialized = true

    local grid = math.max(
        math.floor(cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_GRID),
        1
    )

    local vertexCount = grid * grid * 4
    local indexCount = grid * grid * 6

    rainDynamicMeshTestVertices = ac.VertexBuffer(vertexCount)
    rainDynamicMeshTestIndices = ac.IndicesBuffer(indexCount)

    local vertexIndex = 1
    local indexIndex = 1

    local halfSpan =
        ((grid - 1) * cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_SPACING
        + cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_QUAD_SIZE) * 0.5

    for gy = 0, grid - 1 do
        for gx = 0, grid - 1 do

            local x0 =
                gx * cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_SPACING
                - halfSpan

            local y0 =
                gy * cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_SPACING
                - halfSpan

            local x1 =
                x0 + cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_QUAD_SIZE

            local y1 =
                y0 + cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_QUAD_SIZE

            local curvatureX = cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_CURVATURE_X
            local curvatureY = cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_CURVATURE_Y

            local z0 = cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_Z + curvatureX * x0 * x0 + curvatureY * y0 * y0
            local z1 = cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_Z + curvatureX * x1 * x1 + curvatureY * y0 * y0
            local z2 = cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_Z + curvatureX * x1 * x1 + curvatureY * y1 * y1
            local z3 = cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_Z + curvatureX * x0 * x0 + curvatureY * y1 * y1

            rainDynamicMeshTestVertices:set(
                vertexIndex,
                ac.MeshVertex.new(
                    vec3(x0, y0, z0),
                    vec3(0, 0, 1),
                    vec2(0, 0)
                )
            )
            vertexIndex = vertexIndex + 1

            rainDynamicMeshTestVertices:set(
                vertexIndex,
                ac.MeshVertex.new(
                    vec3(x1, y0, z1),
                    vec3(0, 0, 1),
                    vec2(1, 0)
                )
            )
            vertexIndex = vertexIndex + 1

            rainDynamicMeshTestVertices:set(
                vertexIndex,
                ac.MeshVertex.new(
                    vec3(x1, y1, z2),
                    vec3(0, 0, 1),
                    vec2(1, 1)
                )
            )
            vertexIndex = vertexIndex + 1

            rainDynamicMeshTestVertices:set(
                vertexIndex,
                ac.MeshVertex.new(
                    vec3(x0, y1, z3),
                    vec3(0, 0, 1),
                    vec2(0, 1)
                )
            )
            vertexIndex = vertexIndex + 1

            local base = vertexIndex - 5

            rainDynamicMeshTestIndices:set(indexIndex, base)
            rainDynamicMeshTestIndices:set(indexIndex + 1, base + 1)
            rainDynamicMeshTestIndices:set(indexIndex + 2, base + 2)
            rainDynamicMeshTestIndices:set(indexIndex + 3, base)
            rainDynamicMeshTestIndices:set(indexIndex + 4, base + 2)
            rainDynamicMeshTestIndices:set(indexIndex + 5, base + 3)

            indexIndex = indexIndex + 6
        end
    end

    if not axisRollNode or #axisRollNode == 0 then
        ac.warn(
            appNameDebug
            .. ' Dynamic mesh test: axisRollNode is not available'
        )
        return false
    end

    rainDynamicMeshTestNode =
        axisRollNode:createNode(
            'REALVISOR_DYNAMIC_MESH_TEST'
        )

    if not rainDynamicMeshTestNode then
        ac.warn(
            appNameDebug
            .. ' Dynamic mesh test: failed to create child node'
        )
        return false
    end

    rainDynamicMeshTest =
        rainDynamicMeshTestNode:createMesh(
            'RealVisor_DynamicMeshTest',
            nil,
            rainDynamicMeshTestVertices,
            rainDynamicMeshTestIndices,
            true,
            false
        )

    if not rainDynamicMeshTest then
        ac.warn(
            appNameDebug
            .. ' Dynamic mesh test: createMesh() failed'
        )
        return false
    end

    ac.log(
        appNameDebug
        .. ' Dynamic mesh test initialized: '
        .. tostring(grid * grid)
        .. ' quads / '
        .. tostring(vertexCount)
        .. ' vertices / '
        .. tostring(indexCount)
        .. ' indices'
    )

    return true
end

--------------------------------------------------------
-- Dynamic mesh renderer experiment: Stage 2
--
-- Shared Stage 2/3 diagnostic pixel shader. Stage 2 validates static
-- UV->surface geometry; Stage 3 uses the same primitive shader while its
-- vertices come from live persistent GPU state. This is intentionally NOT
-- the final optical RainFX shader (shaders/rainVisorScreen.hlsl remains the
-- canonical fullscreen path until the dynamic optical shader is designed).
--
-- Replace the synthetic curved surface from Stage 1.1 with the actual
-- GLASS_EXT_DUMMY KN5 mesh. getVertices()/getIndices() are called once,
-- then a UV-space bucket index is built for CPU barycentric lookup.
--
-- This stage intentionally does NOT consume rainStateA/metaA yet. It uses
-- deterministic UV samples to validate the geometry mapping in isolation.
--------------------------------------------------------

local RAIN_DYNAMIC_SURFACE_DIAGNOSTIC_HLSL = [[
float4 main(PS_IN pin)
{
    // Stage 2/3 geometry diagnostic:
    // keep the quad as the transport primitive, but clip its visible
    // footprint to a circle so Meta.R physical-radius differences can be
    // judged directly. Geometry dimensions are still authored from radiusUV.
    float2 centered = pin.Tex * 2.0 - 1.0;
    float radius = length(centered);

    clip(1.0 - radius);

    float softEdge =
        1.0 - smoothstep(0.82, 1.0, radius);

    float centerHighlight =
        1.0 - smoothstep(0.0, 0.65, radius);

    float3 baseColor =
        float3(
            0.18 + pin.Tex.x * 0.40,
            0.35 + pin.Tex.y * 0.35,
            1.0
        );

    float3 color =
        lerp(
            baseColor,
            float3(0.80, 0.92, 1.0),
            centerHighlight * 0.35
        );

    return float4(
        color,
        0.55 + softEdge * 0.40
    );
}
]]

local function rainDynamicSurfaceFrac(x)
    return x - math.floor(x)
end

local function rainDynamicSurfaceBuildLookup(vertices, indices)
    local bucketCount = math.max(
        math.floor(cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_TEST_UV_BUCKETS),
        4
    )

    -- Do not assume the mesh uses the same normalized UV convention as
    -- the fullscreen RainFX state. The visor's established V range is
    -- -1..0, so bucket coordinates must be derived from the actual KN5 UVs.
    local minU = math.huge
    local maxU = -math.huge
    local minV = math.huge
    local maxV = -math.huge

    for i = 1, #vertices do
        local vertex = vertices:get(i)
        minU = math.min(minU, vertex.uv.x)
        maxU = math.max(maxU, vertex.uv.x)
        minV = math.min(minV, vertex.uv.y)
        maxV = math.max(maxV, vertex.uv.y)
    end

    local rangeU = math.max(maxU - minU, 0.0000001)
    local rangeV = math.max(maxV - minV, 0.0000001)

    local buckets = {}
    for i = 1, bucketCount * bucketCount do
        buckets[i] = {}
    end

    local triangles = {}
    local triangleCount = math.floor(#indices / 3)
    local validTriangleCount = 0
    local totalUVArea = 0.0

    local function bucketIndex(x, y)
        x = math.max(0, math.min(bucketCount - 1, x))
        y = math.max(0, math.min(bucketCount - 1, y))
        return y * bucketCount + x + 1
    end

    local function uvToBucketX(u)
        return math.floor(
            math.max(
                0,
                math.min(bucketCount - 1, ((u - minU) / rangeU) * bucketCount)
            )
        )
    end

    local function uvToBucketY(v)
        return math.floor(
            math.max(
                0,
                math.min(bucketCount - 1, ((v - minV) / rangeV) * bucketCount)
            )
        )
    end

    for tri = 0, triangleCount - 1 do
        local i0 = indices:get(tri * 3 + 1)
        local i1 = indices:get(tri * 3 + 2)
        local i2 = indices:get(tri * 3 + 3)

        local v0 = vertices:get(i0 + 1)
        local v1 = vertices:get(i1 + 1)
        local v2 = vertices:get(i2 + 1)

        local u0 = v0.uv
        local u1 = v1.uv
        local u2 = v2.uv

        local du1 = u1.x - u0.x
        local dv1 = u1.y - u0.y
        local du2 = u2.x - u0.x
        local dv2 = u2.y - u0.y
        local determinant = du1 * dv2 - du2 * dv1

        if math.abs(determinant) > 0.0000001 then
            local triMinU = math.min(u0.x, u1.x, u2.x)
            local triMaxU = math.max(u0.x, u1.x, u2.x)
            local triMinV = math.min(u0.y, u1.y, u2.y)
            local triMaxV = math.max(u0.y, u1.y, u2.y)

            local minX = uvToBucketX(triMinU)
            local maxX = uvToBucketX(triMaxU)
            local minY = uvToBucketY(triMinV)
            local maxY = uvToBucketY(triMaxV)

            local uvArea = math.abs(determinant) * 0.5
            totalUVArea = totalUVArea + uvArea

            local triangle = {
                i0 = i0, i1 = i1, i2 = i2,
                u0 = u0, u1 = u1, u2 = u2,
                determinant = determinant,
                uvArea = uvArea,
                cumulativeUVArea = totalUVArea,
            }

            validTriangleCount = validTriangleCount + 1
            triangles[validTriangleCount] = triangle

            for by = minY, maxY do
                for bx = minX, maxX do
                    local bucket = buckets[bucketIndex(bx, by)]
                    bucket[#bucket + 1] = validTriangleCount
                end
            end
        end
    end

    return {
        bucketCount = bucketCount,
        buckets = buckets,
        triangles = triangles,
        validTriangleCount = validTriangleCount,
        vertexCount = #vertices,
        indexCount = #indices,
        minU = minU,
        maxU = maxU,
        minV = minV,
        maxV = maxV,
        rangeU = rangeU,
        rangeV = rangeV,
        bboxUVArea = rangeU * rangeV,
        totalUVArea = totalUVArea,
    }
end

local function rainDynamicSurfaceFindTriangle(lookup, uv)
    local bucketCount = lookup.bucketCount

    -- BuildLookup stores triangles in buckets normalized against the actual
    -- extracted KN5 UV bounds. Query coordinates must use the exact same
    -- mapping (the visor V domain is negative, so uv.y * bucketCount would
    -- otherwise clamp almost every query to bucket row 0).
    local normalizedU = (uv.x - lookup.minU) / lookup.rangeU
    local normalizedV = (uv.y - lookup.minV) / lookup.rangeV
    local bx = math.max(0, math.min(
        bucketCount - 1,
        math.floor(normalizedU * bucketCount)
    ))
    local by = math.max(0, math.min(
        bucketCount - 1,
        math.floor(normalizedV * bucketCount)
    ))
    local bucket = lookup.buckets[by * bucketCount + bx + 1]

    local best = nil
    local bestMargin = -math.huge

    for i = 1, #bucket do
        local triangle = lookup.triangles[bucket[i]]
        local u0, u1, u2 = triangle.u0, triangle.u1, triangle.u2
        local den = triangle.determinant

        local w1 = ((u2.y - u0.y) * (uv.x - u0.x) - (u2.x - u0.x) * (uv.y - u0.y)) / den
        local w2 = ((u1.x - u0.x) * (uv.y - u0.y) - (u1.y - u0.y) * (uv.x - u0.x)) / den
        local w0 = 1.0 - w1 - w2
        local margin = math.min(w0, w1, w2)

        if margin >= -0.00001 and margin > bestMargin then
            best = triangle
            bestMargin = margin
            best.w0, best.w1, best.w2 = w0, w1, w2
        end
    end

    return best
end


local function rainDynamicSurfaceValidateLookup(lookup)
    -- Stage 2 accuracy gate:
    -- generate several guaranteed-inside UV points from every valid triangle
    -- and feed them back through the same bucket + barycentric lookup path.
    -- This isolates lookup correctness from random samples that can legitimately
    -- fall outside the visor UV island.
    local probeWeights = {
        { 1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0 },
        { 0.60, 0.20, 0.20 },
        { 0.20, 0.60, 0.20 },
    }

    local total = 0
    local hitCount = 0
    local missCount = 0
    local bucketMembershipMiss = 0
    local containmentMiss = 0
    local bucketCount = lookup.bucketCount

    local function queryBucketIndex(uv)
        local normalizedU = (uv.x - lookup.minU) / lookup.rangeU
        local normalizedV = (uv.y - lookup.minV) / lookup.rangeV
        local bx = math.max(0, math.min(
            bucketCount - 1,
            math.floor(normalizedU * bucketCount)
        ))
        local by = math.max(0, math.min(
            bucketCount - 1,
            math.floor(normalizedV * bucketCount)
        ))
        return by * bucketCount + bx + 1
    end

    for triangleIndex = 1, lookup.validTriangleCount do
        local triangle = lookup.triangles[triangleIndex]

        for probeIndex = 1, #probeWeights do
            local weights = probeWeights[probeIndex]
            local uv =
                triangle.u0 * weights[1]
                + triangle.u1 * weights[2]
                + triangle.u2 * weights[3]

            total = total + 1

            local bucket = lookup.buckets[queryBucketIndex(uv)]
            local expectedTrianglePresent = false
            for candidateIndex = 1, #bucket do
                if bucket[candidateIndex] == triangleIndex then
                    expectedTrianglePresent = true
                    break
                end
            end

            local found = rainDynamicSurfaceFindTriangle(lookup, uv)
            if found then
                hitCount = hitCount + 1
            else
                missCount = missCount + 1
                if expectedTrianglePresent then
                    containmentMiss = containmentMiss + 1
                else
                    bucketMembershipMiss = bucketMembershipMiss + 1
                end
            end
        end
    end

    return {
        total = total,
        hitCount = hitCount,
        missCount = missCount,
        bucketMembershipMiss = bucketMembershipMiss,
        containmentMiss = containmentMiss,
    }
end


local function rainDynamicSurfaceAreaWeightedUV(lookup, sampleIndex, sampleCount)
    if lookup.totalUVArea <= 0.0 or lookup.validTriangleCount <= 0 then
        return nil
    end

    -- Stratify the cumulative UV-area domain so each requested point maps to
    -- actual visor geometry. The two irrational-style hashes decorrelate the
    -- within-triangle barycentric position without introducing a visible grid.
    local areaFraction =
        (sampleIndex + 0.5) / math.max(sampleCount, 1)
    local targetArea = areaFraction * lookup.totalUVArea

    local lo, hi = 1, lookup.validTriangleCount
    while lo < hi do
        local mid = math.floor((lo + hi) * 0.5)
        if lookup.triangles[mid].cumulativeUVArea >= targetArea then
            hi = mid
        else
            lo = mid + 1
        end
    end

    local triangle = lookup.triangles[lo]

    -- Uniform point over triangle area:
    -- sqrt(r1) avoids clustering toward u0.
    local r1 = rainDynamicSurfaceFrac((sampleIndex + 0.5) * 0.7548776662)
    local r2 = rainDynamicSurfaceFrac((sampleIndex + 0.5) * 0.5698402911)
    local sr1 = math.sqrt(r1)

    local w0 = 1.0 - sr1
    local w1 = sr1 * (1.0 - r2)
    local w2 = sr1 * r2

    return
        triangle.u0 * w0
        + triangle.u1 * w1
        + triangle.u2 * w2
end

local function rainDynamicSurfaceSample(lookup, vertices, uv)
    local triangle = rainDynamicSurfaceFindTriangle(lookup, uv)
    if not triangle then
        return nil
    end

    local v0 = vertices:get(triangle.i0 + 1)
    local v1 = vertices:get(triangle.i1 + 1)
    local v2 = vertices:get(triangle.i2 + 1)
    local w0, w1, w2 = triangle.w0, triangle.w1, triangle.w2

    local position = v0.pos * w0 + v1.pos * w1 + v2.pos * w2
    local normal = v0.normal * w0 + v1.normal * w1 + v2.normal * w2

    if normal:lengthSquared() < 0.0000001 then return nil end
    normal:normalize()

    local edge1 = v1.pos - v0.pos
    local edge2 = v2.pos - v0.pos
    local du1, dv1 = v1.uv.x - v0.uv.x, v1.uv.y - v0.uv.y
    local du2, dv2 = v2.uv.x - v0.uv.x, v2.uv.y - v0.uv.y
    local det = du1 * dv2 - du2 * dv1
    if math.abs(det) < 0.0000001 then return nil end

    local tangentU = (edge1 * dv2 - edge2 * dv1) / det
    local tangentV = (edge2 * du1 - edge1 * du2) / det
    local tangentULength = tangentU:length()
    local tangentVLength = tangentV:length()
    if tangentULength < 0.0000001 or tangentVLength < 0.0000001 then return nil end

    tangentU = tangentU - normal * tangentU:dot(normal)
    if tangentU:lengthSquared() < 0.0000001 then return nil end
    tangentU:normalize()

    local canonicalV = normal:cross(tangentU)
    if canonicalV:lengthSquared() < 0.0000001 then return nil end
    canonicalV:normalize()
    if canonicalV:dot(tangentV) < 0.0 then canonicalV = -canonicalV end

    return {
        position = position,
        normal = normal,
        tangentU = tangentU,
        tangentV = canonicalV,
        metersPerUVU = tangentULength,
        metersPerUVV = tangentVLength,
    }
end

local function initializeRainDynamicSurfaceTest()
    if rainDynamicSurfaceInitialized then
        return rainDynamicSurfaceMesh ~= nil
    end

    if not rainTargetMesh or #rainTargetMesh == 0 then
        ac.warn(appNameDebug .. ' Dynamic surface test: rainTargetMesh unavailable')
        return false
    end

    local vertices = rainTargetMesh:getVertices()
    local indices = rainTargetMesh:getIndices()

    if not vertices or not indices or #vertices == 0 or #indices < 3 then
        ac.warn(appNameDebug .. ' Dynamic surface test: failed to extract vertices/indices')
        return false
    end

    rainDynamicSurfaceVertices = vertices
    rainDynamicSurfaceIndices = indices
    rainDynamicSurfaceLookup = rainDynamicSurfaceBuildLookup(vertices, indices)

    ac.log(
        appNameDebug
        .. ' Dynamic surface extraction: '
        .. tostring(#vertices) .. ' vertices / '
        .. tostring(#indices) .. ' indices / '
        .. tostring(rainDynamicSurfaceLookup.validTriangleCount) .. ' valid UV triangles'
    )

    ac.log(
        appNameDebug
        .. ' Dynamic surface UV bounds: U='
        .. string.format('%.6f..%.6f', rainDynamicSurfaceLookup.minU, rainDynamicSurfaceLookup.maxU)
        .. ' V='
        .. string.format('%.6f..%.6f', rainDynamicSurfaceLookup.minV, rainDynamicSurfaceLookup.maxV)
    )

    local uvAreaRatio =
        rainDynamicSurfaceLookup.bboxUVArea > 0.0
        and rainDynamicSurfaceLookup.totalUVArea / rainDynamicSurfaceLookup.bboxUVArea
        or 0.0

    ac.log(
        appNameDebug
        .. ' Dynamic surface UV area: triangles='
        .. string.format('%.6f', rainDynamicSurfaceLookup.totalUVArea)
        .. ' bbox='
        .. string.format('%.6f', rainDynamicSurfaceLookup.bboxUVArea)
        .. ' summed-ratio='
        .. string.format('%.3f', uvAreaRatio * 100.0)
        .. '%'
    )

    local lookupValidation = rainDynamicSurfaceValidateLookup(rainDynamicSurfaceLookup)
    local lookupAccuracy =
        lookupValidation.total > 0
        and (lookupValidation.hitCount / lookupValidation.total) * 100.0
        or 0.0

    ac.log(
        appNameDebug
        .. ' Dynamic surface lookup self-test: '
        .. tostring(lookupValidation.hitCount) .. '/'
        .. tostring(lookupValidation.total)
        .. ' guaranteed-inside probes mapped ('
        .. string.format('%.3f', lookupAccuracy) .. '%), '
        .. tostring(lookupValidation.missCount) .. ' missed'
    )

    if lookupValidation.missCount > 0 then
        ac.log(
            appNameDebug
            .. ' Dynamic surface lookup self-test misses: '
            .. tostring(lookupValidation.bucketMembershipMiss)
            .. ' bucket-membership / '
            .. tostring(lookupValidation.containmentMiss)
            .. ' containment'
        )
    end

    local parent = rainTargetMesh:getParent()
    if not parent or #parent == 0 then
        ac.warn(appNameDebug .. ' Dynamic surface test: rainTargetMesh parent unavailable')
        return false
    end

    -- Dynamic test meshes used to be created with keepAlive=true. That can
    -- leave old copies attached to the scene after a Lua reload, where they
    -- are rendered by the normal scene pass using their fallback material.
    -- Remove all stale copies before creating the renderer-owned mesh.
    local staleDynamicMeshes =
        parent:findNodes(RAIN_DYNAMIC_SURFACE_MESH_NAME)

    if staleDynamicMeshes and #staleDynamicMeshes > 0 then
        local staleCount = #staleDynamicMeshes
        staleDynamicMeshes:dispose()
        ac.log(
            appNameDebug
            .. ' Dynamic surface cleanup: removed '
            .. tostring(staleCount)
            .. ' stale scene mesh reference(s)'
        )
    end

    rainDynamicSurfaceParent = parent

    local count = cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED
        and cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ONLY
        and 0 or rainStateCountForMode()
    local useMicroPattern = cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_ENABLED
        and cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_ENABLED
    -- Legacy per-disk micro quads removed (the shader draws only the
    -- surface layer, docs/RAINFX_WATER_FIELD.md §10).
    local microCount = 0
    local patternVertexCount = useMicroPattern and #vertices or 0
    local patternIndexCount = useMicroPattern and #indices or 0
    local meshVertices = ac.VertexBuffer(
        count * 4 + microCount * 4 + patternVertexCount)
    local meshIndices = ac.IndicesBuffer(
        count * 6 + microCount * 6 + patternIndexCount)
    rainDynamicSurfaceMeshVertices = meshVertices
    rainDynamicSurfaceMeshCount = count

    local diameterUV =
        cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_TEST_DROPLET_DIAMETER_MM
        * cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM
    local radiusUV = diameterUV * 0.5
    local surfaceOffset = cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_TEST_OFFSET_M

    local vertexIndex, indexIndex = 1,
        microCount * 6 + patternIndexCount + 1
    local hitCount, missCount = 0, 0

    for i = 0, count - 1 do
        -- Encode a stable per-drop shape seed in whole, even Tex.x bands.
        -- HLSL removes the band before reconstructing 0..1 quad UV.
        local shapeBand = ((i * 73) % 1021) * 2
        -- Stage 2 visual validation should measure surface mapping, not the
        -- occupancy of a rectangular UV bounding box. Select each diagnostic
        -- UV directly from valid triangles, weighted by triangle UV area.
        local uv = rainDynamicSurfaceAreaWeightedUV(
            rainDynamicSurfaceLookup,
            i,
            count
        )

        local sample =
            uv
            and rainDynamicSurfaceSample(
                rainDynamicSurfaceLookup,
                vertices,
                uv
            )
            or nil

        if sample then
            hitCount = hitCount + 1
            local center = sample.position + sample.normal * surfaceOffset
            local uOffset = sample.tangentU * (radiusUV * sample.metersPerUVU)
            local vOffset = sample.tangentV * (radiusUV * sample.metersPerUVV)

            meshVertices:set(vertexIndex,     ac.MeshVertex.new(center - uOffset - vOffset, sample.normal, vec2(shapeBand, 0)))
            meshVertices:set(vertexIndex + 1, ac.MeshVertex.new(center + uOffset - vOffset, sample.normal, vec2(shapeBand + 1, 0)))
            meshVertices:set(vertexIndex + 2, ac.MeshVertex.new(center + uOffset + vOffset, sample.normal, vec2(shapeBand + 1, 1)))
            meshVertices:set(vertexIndex + 3, ac.MeshVertex.new(center - uOffset + vOffset, sample.normal, vec2(shapeBand, 1)))
        else
            missCount = missCount + 1
            local dead = vec3(0, 0, 0)
            local fallbackNormal = vec3(0, 0, 1)
            for j = 0, 3 do
                meshVertices:set(vertexIndex + j, ac.MeshVertex.new(dead, fallbackNormal, vec2(shapeBand + ((j == 1 or j == 2) and 1 or 0), j >= 2 and 1 or 0)))
            end
        end

        local base = vertexIndex - 1
        meshIndices:set(indexIndex, base)
        meshIndices:set(indexIndex + 1, base + 1)
        meshIndices:set(indexIndex + 2, base + 2)
        meshIndices:set(indexIndex + 3, base)
        meshIndices:set(indexIndex + 4, base + 2)
        meshIndices:set(indexIndex + 5, base + 3)
        vertexIndex = vertexIndex + 4
        indexIndex = indexIndex + 6
    end

    -- A fixed, area-stratified micro-droplet field uses the same visor lookup.
    -- Its indices are first so moving drops composite over this base layer.

    if useMicroPattern then
        local baseVertex = count * 4 + microCount * 4
        for i = 1, patternVertexCount do
            local source = vertices:get(i)
            meshVertices:set(baseVertex + i, ac.MeshVertex.new(
                source.pos
                    + source.normal * cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_TEST_OFFSET_M,
                source.normal,
                vec2(source.uv.x - 4.0, source.uv.y)))
        end
        for i = 1, patternIndexCount do
            meshIndices:set(microCount * 6 + i,
                baseVertex + indices:get(i))
        end

        -- Re-runnable bake (UI: diameter, pixelation, rim, strata ...).
        rainDynamicSceneCopyState.bakeMicroPattern = function()
            local patternGrid = math.max(4, math.floor(
                1.12 / math.max(0.01,
                    cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_DIAMETER_MM)
                    / cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM
                    + 0.5))
            -- Texture size follows the disk grid: few texels per cell is the
            -- intended low-resolution look (legacy 2048 / 546 = 3.75).
            local patternSize = math.max(256, math.min(16384, math.floor(
                patternGrid * math.max(1.0,
                    cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_TEXELS_PER_CELL)
                + 0.5)))
            rainDynamicSceneCopyState.microPatternGrid = patternGrid
            if rainDynamicSceneCopyState.microPatternCanvas then
                rainDynamicSceneCopyState.microPatternCanvas:dispose()
                rainDynamicSceneCopyState.microPatternCanvas = nil
            end
            rainDynamicSceneCopyState.microPatternReady = false
            -- A threefold linear increase uses nine times the texture memory.
            -- Fall back if a large allocation is unavailable on the active GPU.
            for _, size in ipairs({ patternSize, math.min(patternSize, 8192),
                math.min(patternSize, 4096) }) do
                local canvasOk, canvas = pcall(function()
                    return ui.ExtraCanvas(vec2(size, size), 1,
                        render.TextureFormat.R8G8B8A8.UNorm)
                end)
                if canvasOk and canvas then
                    patternSize = size
                    rainDynamicSceneCopyState.microPatternCanvas = canvas
                        :setName('RainFX static micro pattern')
                    break
                end
            end
            if rainDynamicSceneCopyState.microPatternCanvas then
                local maskOk, maskResult = pcall(function()
                    return rainDynamicSceneCopyState.microPatternCanvas:updateWithShader({
                        -- Opaque: the rim class (A = 0.5) must not be
                        -- premultiplied into the stored lens coordinates.
                        blendMode = render.BlendMode.Opaque,
                        values = {
                            gMicroPatternGrid = patternGrid,
                            gMicroStrata = math.max(1, math.min(6, math.floor(
                                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_STRATA + 0.5))),
                            gMicroPresence =
                                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_PRESENCE,
                            gMicroFirstPresence =
                                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_FIRST_PRESENCE,
                            gMicroRadiusMin =
                                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MIN,
                            gMicroRadiusMax =
                                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MAX,
                            -- Invisible cut line: a ring of fixed TEXEL width.
                            gMicroRimCells =
                                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RIM_TEXELS
                                * patternGrid / math.max(patternSize, 1),
                        },
                        shader = [[
                            float3 hashMicroCell(float2 cell)
                            {
                                float3 p = frac(float3(cell.x, cell.y, cell.x)
                                    * 0.1031);
                                p += dot(p, p.yzx + 33.33);
                                return frac((p.xxy + p.yzz) * p.zyx);
                            }
                            // Micro pattern v2 (docs/RAINFX_MICRO_PATTERN.md).
                            // Several strata of jittered disks with varying
                            // radius. Priority = 1 - gate: the earliest disk to
                            // appear with rain stays on top, later disks only
                            // show as crescents, half-moons and dots around it,
                            // so rising rain never cuts holes into visible disks.
                            // RG = lens-local coords of the winner (unit disk),
                            // B = gate (4 bit) * 16 + radius (4 bit), A = class:
                            // 1 interior, 0.5 outline rim, 0 empty.
                            float4 main(PS_IN pin)
                            {
                                float2 p = pin.Tex * gMicroPatternGrid;
                                float2 baseCell = floor(p);
                                float best = -1.0;
                                float2 chosen = float2(0.0, 0.0);
                                float chosenRadius = gMicroRadiusMin;
                                float chosenGate = 0.99;
                                int strata = (int)gMicroStrata;
                                [loop] for (int layer = 0; layer < 6; ++layer)
                                {
                                    if (layer >= strata) break;
                                    float fl = (float)layer;
                                    float presenceLimit = layer == 0
                                        ? gMicroFirstPresence : gMicroPresence;
                                    [unroll] for (int y = -1; y <= 1; ++y)
                                    {
                                        [unroll] for (int x = -1; x <= 1; ++x)
                                        {
                                            float2 cell = baseCell
                                                + float2((float)x, (float)y);
                                            float3 h = hashMicroCell(cell
                                                + float2(137.31, 417.73) * fl);
                                            float3 g = hashMicroCell(cell
                                                + float2(59.17 * fl + 11.0,
                                                    23.9 * fl + 7.0));
                                            float2 center = cell + 0.5
                                                + (h.xy - 0.5) * 0.90;
                                            float radius = lerp(gMicroRadiusMin,
                                                gMicroRadiusMax, g.x);
                                            float2 local = (p - center) / radius;
                                            float presence = frac(h.x * 13.71
                                                + h.y * 7.17);
                                            float gate = clamp((fl + g.y)
                                                / (float)strata, 0.01, 0.99);
                                            float priority = 1.0 - gate;
                                            if (presence < presenceLimit
                                                && dot(local, local) < 1.0
                                                && priority > best)
                                            {
                                                best = priority;
                                                chosen = local;
                                                chosenRadius = radius;
                                                chosenGate = gate;
                                            }
                                        }
                                    }
                                }
                                float dist = saturate(length(chosen));
                                // The winner keeps a thin outline ring of fixed
                                // width in cells: fragments stay separated.
                                float rimStart = 1.0 - gMicroRimCells
                                    / max(chosenRadius, 0.05);
                                float cls = best < 0.0 ? 0.0
                                    : (dist < rimStart ? 1.0 : 0.5);
                                float gateQ = floor(chosenGate * 15.999);
                                float radiusQ = floor(saturate((chosenRadius
                                    - gMicroRadiusMin) / max(gMicroRadiusMax
                                    - gMicroRadiusMin, 1e-4)) * 15.999);
                                return float4(chosen * 0.5 + 0.5,
                                    (gateQ * 16.0 + radiusQ + 0.5) / 255.0, cls);
                            }
                        ]]
                    })
                end)
                rainDynamicSceneCopyState.microPatternReady =
                    maskOk and maskResult ~= false
                if not maskOk then
                    ac.warn(appNameDebug .. ' Micro pattern shader: '
                        .. tostring(maskResult))
                end
            else
                rainDynamicSceneCopyState.microPatternReady = false
            end
            rainDynamicSceneCopyState.microPatternSize = patternSize
            rainDynamicSceneCopyState.microBakeKey =
                rainDynamicSceneCopyState.microBakeKeyNow()
            return patternSize, patternGrid
        end
        local patternSize, patternGrid =
            rainDynamicSceneCopyState.bakeMicroPattern()
        ac.log(appNameDebug .. ' Micro pattern: '
            .. tostring(patternSize) .. 'x' .. tostring(patternSize)
            .. ' grid=' .. tostring(patternGrid)
            .. ' boundsU=' .. tostring(rainDynamicSurfaceLookup.minU)
            .. '..' .. tostring(rainDynamicSurfaceLookup.maxU)
            .. ' boundsV=' .. tostring(rainDynamicSurfaceLookup.minV)
            .. '..' .. tostring(rainDynamicSurfaceLookup.maxV)
            .. ' surfaceVertices=' .. tostring(patternVertexCount)
            .. ' triangles=' .. tostring(math.floor(patternIndexCount / 3))
            .. ' ready='
            .. tostring(rainDynamicSceneCopyState.microPatternReady))
    end

    rainDynamicSurfaceMesh = rainDynamicSurfaceParent:createMesh(
        RAIN_DYNAMIC_SURFACE_MESH_NAME,
        nil,
        meshVertices,
        meshIndices,
        false,
        false
    )

    if not rainDynamicSurfaceMesh then
        ac.warn(appNameDebug .. ' Dynamic surface test: createMesh() failed')
        return false
    end

    -- Keep the attached transport mesh hidden from ordinary scene traversal.
    -- The explicit draw callback temporarily enables it only for the duration
    -- of render.mesh(), because that API also respects SceneReference
    -- visibility on the target CSP build.
    rainDynamicSurfaceMesh:setVisible(false, false)

    rainDynamicSurfaceInitialized = true

    ac.log(
        appNameDebug
        .. ' Dynamic surface test initialized: '
        .. tostring(hitCount) .. '/' .. tostring(count)
        .. ' area-weighted surface samples mapped, '
        .. tostring(missCount) .. ' lookup misses'
    )

    return true
end


--------------------------------------------------------
-- Dynamic mesh renderer experiment: Stage 3
--
-- Keep persistent physics on GPU. A tiny R32FLOAT staging canvas flattens
-- only the renderer ABI required by the CPU:
--   [0..N)     U
--   [N..2N)    V encoded as V + 1 (signed visor V is -1..0)
--   [2N..3N)   velocity U encoded around 0.5
--   [3N..4N)   velocity V encoded around 0.5
--   [4N..5N)   physical radius in UV
--   [5N..6N)   packed generation*4 + lifecycle status
--
-- accessData() is asynchronous. The callback only copies scalar values into
-- Lua arrays; alterVertices() is applied from the render callback afterwards.
--------------------------------------------------------

local RAIN_DYNAMIC_STATE_READBACK_HLSL = [[
SamplerState samPointRain {
    Filter = MIN_MAG_MIP_POINT;
    AddressU = CLAMP;
    AddressV = CLAMP;
    AddressW = CLAMP;
};

float4 main(PS_IN pin)
{
    float count = max(gRainStateCount, 1.0);
    float total = count * 6.0;
    float slot = min(floor(pin.Tex.y * gRainReadbackHeight)
        * gRainReadbackWidth
        + floor(pin.Tex.x * gRainReadbackWidth), total - 1.0);
    float channel = floor(slot / count);
    float index = slot - channel * count;
    float2 suv = float2((index + 0.5) / count, 0.5);

    float4 state = txRainState.SampleLevel(samPointRain, suv, 0.0);
    float4 meta = txRainStateMeta.SampleLevel(samPointRain, suv, 0.0);

    float velocityRange = max(gRainStateVelocityEncodeRange, 0.000001);
    float value = 0.0;

    if (channel < 0.5) {
        value = saturate(state.r);
    } else if (channel < 1.5) {
        // Encode signed visor V (-1..0) into documented 0..1 CPU scalar range.
        value = saturate(state.g + 1.0);
    } else if (channel < 2.5) {
        value = saturate(0.5 + state.b / (2.0 * velocityRange));
    } else if (channel < 3.5) {
        value = saturate(0.5 + state.a / (2.0 * velocityRange));
    } else if (channel < 4.5) {
        value = max(meta.r, 0.0);
    } else {
        value = meta.a;
    }

    return float4(value, value, value, value);
}
]]

local function initializeRainDynamicStateReadback()
    local count = rainStateCountForMode()
    local ringSize = math.max(
        math.floor(cfg.RUNTIME.RAIN_DYNAMIC_STATE_READBACK_RING_SIZE),
        2
    )

    if #rainDynamicStateReadbackSlots == ringSize
        and rainDynamicStateReadbackCount == count
    then
        return true
    end

    rainDynamicStateReadbackSlots = {}
    rainDynamicStateReadbackCount = count
    -- 6144 is the proven 1024-slot width; larger capacities use rows.
    local readbackWidth = math.min(count * 6, 6144)
    local readbackHeight = math.ceil(count * 6 / readbackWidth)
    rainDynamicStateReadbackNextSlot = 1
    rainDynamicStateReadbackReady = false
    rainDynamicStateLatestAcceptedRequestFrame = -1
    rainDynamicStateHasSnapshot = false
    rainDynamicStateSnapshotTime = 0.0
    rainDynamicSceneCopyState.generation = {}
    rainDynamicSceneCopyState.birthSeenAt = {}
    rainDynamicSceneCopyState.birthImpactEligible = {}
    rainDynamicSceneCopyState.birthsSinceLog = 0

    for slotIndex = 1, ringSize do
        local canvas = ui.ExtraCanvas(
            vec2(readbackWidth, readbackHeight),
            1,
            render.TextureFormat.R32.Float
        ):setName(
            'RainFX Dynamic Mesh Readback '
            .. tostring(slotIndex)
        )

        if not canvas then
            ac.warn(
                appNameDebug
                .. ' Dynamic state readback: staging canvas allocation failed at slot '
                .. tostring(slotIndex)
            )
            rainDynamicStateReadbackSlots = {}
            return false
        end

        rainDynamicStateReadbackSlots[slotIndex] = {
            canvas = canvas,
            width = readbackWidth,
            height = readbackHeight,
            pending = false,
            requestFrame = -1,
            requestTime = 0.0,
            params = {
                textures = {
                    txRainState = false,
                    txRainStateMeta = false,
                },
                values = {
                    gRainStateCount = count,
                    gRainReadbackWidth = readbackWidth,
                    gRainReadbackHeight = readbackHeight,
                    gRainStateVelocityEncodeRange =
                        cfg.RUNTIME.RAIN_DYNAMIC_STATE_VELOCITY_ENCODE_RANGE,
                },
                shader = RAIN_DYNAMIC_STATE_READBACK_HLSL,
            },
        }
    end

    -- Restart diagnostics when the pipeline is rebuilt so old serial-readback
    -- samples do not contaminate the ring-buffer cadence measurements.
    rainDynamicStateRequestFrame = -1
    rainDynamicStateLastCallbackFrame = -1
    rainDynamicStateLastApplyFrame = -1
    rainDynamicStateCallbackCount = 0
    rainDynamicStateCallbackLatencySum = 0
    rainDynamicStateCallbackLatencyMin = math.huge
    rainDynamicStateCallbackLatencyMax = 0
    rainDynamicStateCallbackIntervalSum = 0
    rainDynamicStateCallbackIntervalMin = math.huge
    rainDynamicStateCallbackIntervalMax = 0
    rainDynamicStateApplyCount = 0
    rainDynamicStateApplyIntervalSum = 0
    rainDynamicStateApplyIntervalMin = math.huge
    rainDynamicStateApplyIntervalMax = 0

    ac.log(
        appNameDebug
        .. ' Dynamic state readback initialized: '
        .. tostring(count)
        .. ' drops / '
        .. tostring(count * 6)
        .. ' R32FLOAT scalars in '
        .. tostring(readbackWidth) .. 'x' .. tostring(readbackHeight)
        .. ' / ring='
        .. tostring(ringSize)
    )

    return true
end

local function updateRainDynamicStateRenderClock(sim)
    if not sim or sim.frame == rainDynamicStateRenderClockFrame then
        return
    end

    rainDynamicStateRenderClockFrame = sim.frame
    rainDynamicStateRenderClock =
        rainDynamicStateRenderClock
        + math.max(sim.dt or 0.0, 0.0)
end

local function requestRainDynamicStateReadback()
    if not initializeRainDynamicStateReadback() then
        return
    end

    local state =
        rainStateReadIsA and rainStateA or rainStateB
    local meta =
        rainStateReadIsA and rainStateMetaA or rainStateMetaB

    if not state or not meta then
        return
    end

    local ringSize = #rainDynamicStateReadbackSlots
    if ringSize == 0 then
        return
    end

    -- Find the next free staging slot. With a ring larger than the measured
    -- callback latency, normal operation should find one immediately.
    local slot = nil
    local slotIndex = rainDynamicStateReadbackNextSlot

    for attempt = 1, ringSize do
        local candidate = rainDynamicStateReadbackSlots[slotIndex]
        if candidate and not candidate.pending then
            slot = candidate
            break
        end

        slotIndex = slotIndex % ringSize + 1
    end

    if not slot then
        -- All readbacks are still in flight. Skip this frame rather than
        -- overwriting a staging canvas whose asynchronous transfer is pending.
        return
    end

    rainDynamicStateReadbackNextSlot =
        slotIndex % ringSize + 1

    local count = rainDynamicStateReadbackCount
    local requestSim = ac.getSim()
    local requestFrame =
        requestSim and requestSim.frame or -1

    slot.params.textures.txRainState = state
    slot.params.textures.txRainStateMeta = meta
    slot.params.values.gRainStateCount = count
    slot.params.values.gRainReadbackWidth = slot.width
    slot.params.values.gRainReadbackHeight = slot.height
    slot.params.values.gRainStateVelocityEncodeRange =
        cfg.RUNTIME.RAIN_DYNAMIC_STATE_VELOCITY_ENCODE_RANGE
    slot.requestFrame = requestFrame
    slot.requestTime = rainDynamicStateRenderClock

    slot.canvas:updateWithShader(slot.params)

    slot.pending = true
    rainDynamicStateRequestFrame = requestFrame

    slot.canvas:accessData(function(err, data)
        slot.pending = false

        if err or not data then
            if not rainDynamicStateReadbackErrorLogged then
                ac.warn(
                    appNameDebug
                    .. ' Dynamic state readback failed: '
                    .. tostring(err or 'missing data')
                )
                rainDynamicStateReadbackErrorLogged = true
            end
            return
        end

        local callbackSim = ac.getSim()
        local callbackFrame =
            callbackSim and callbackSim.frame or -1
        local sourceRequestFrame = slot.requestFrame

        if callbackFrame >= 0 and sourceRequestFrame >= 0 then
            local latencyFrames =
                math.max(callbackFrame - sourceRequestFrame, 0)

            rainDynamicStateCallbackCount =
                rainDynamicStateCallbackCount + 1
            rainDynamicStateCallbackLatencySum =
                rainDynamicStateCallbackLatencySum + latencyFrames
            rainDynamicStateCallbackLatencyMin =
                math.min(rainDynamicStateCallbackLatencyMin, latencyFrames)
            rainDynamicStateCallbackLatencyMax =
                math.max(rainDynamicStateCallbackLatencyMax, latencyFrames)

            if rainDynamicStateLastCallbackFrame >= 0 then
                local intervalFrames =
                    math.max(
                        callbackFrame - rainDynamicStateLastCallbackFrame,
                        0
                    )
                rainDynamicStateCallbackIntervalSum =
                    rainDynamicStateCallbackIntervalSum + intervalFrames
                rainDynamicStateCallbackIntervalMin =
                    math.min(
                        rainDynamicStateCallbackIntervalMin,
                        intervalFrames
                    )
                rainDynamicStateCallbackIntervalMax =
                    math.max(
                        rainDynamicStateCallbackIntervalMax,
                        intervalFrames
                    )
            end

            rainDynamicStateLastCallbackFrame = callbackFrame

            if cfg.RUNTIME.RAIN_DYNAMIC_STATE_CADENCE_DEBUG
                and rainDynamicStateCallbackCount % 120 == 0
            then
                local callbackIntervals =
                    math.max(rainDynamicStateCallbackCount - 1, 1)

                ac.log(
                    appNameDebug
                    .. ' Dynamic state cadence callback: avgLatency='
                    .. string.format(
                        '%.2f',
                        rainDynamicStateCallbackLatencySum
                        / rainDynamicStateCallbackCount
                    )
                    .. 'f min='
                    .. tostring(rainDynamicStateCallbackLatencyMin)
                    .. ' max='
                    .. tostring(rainDynamicStateCallbackLatencyMax)
                    .. ' | avgInterval='
                    .. string.format(
                        '%.2f',
                        rainDynamicStateCallbackIntervalSum
                        / callbackIntervals
                    )
                    .. 'f min='
                    .. tostring(
                        rainDynamicStateCallbackIntervalMin == math.huge
                        and 0
                        or rainDynamicStateCallbackIntervalMin
                    )
                    .. ' max='
                    .. tostring(rainDynamicStateCallbackIntervalMax)
                )
            end
        end

        -- Multiple readbacks are now in flight. Do not let an unusually late
        -- older callback overwrite state from a newer completed request.
        if sourceRequestFrame < rainDynamicStateLatestAcceptedRequestFrame then
            return
        end

        rainDynamicStateLatestAcceptedRequestFrame = sourceRequestFrame

        local velocityRange =
            cfg.RUNTIME.RAIN_DYNAMIC_STATE_VELOCITY_ENCODE_RANGE

        rainDynamicSceneCopyState.generation =
            rainDynamicSceneCopyState.generation or {}
        local aliveCount, waitingCount, pendingCount, births = 0, 0, 0, 0
        for i = 0, count - 1 do
            local dst = i + 1
            local width = slot.width
            rainDynamicStateU[dst] =
                data:floatValue(i % width, math.floor(i / width))
            rainDynamicStateV[dst] =
                data:floatValue((count + i) % width,
                    math.floor((count + i) / width)) - 1.0
            rainDynamicStateVelocityU[dst] =
                (data:floatValue((count * 2 + i) % width,
                    math.floor((count * 2 + i) / width)) - 0.5)
                * 2.0 * velocityRange
            rainDynamicStateVelocityV[dst] =
                (data:floatValue((count * 3 + i) % width,
                    math.floor((count * 3 + i) / width)) - 0.5)
                * 2.0 * velocityRange
            rainDynamicStateRadius[dst] =
                data:floatValue((count * 4 + i) % width,
                    math.floor((count * 4 + i) / width))
            local packedStatus = data:floatValue(
                (count * 5 + i) % width,
                math.floor((count * 5 + i) / width))
            local generation = math.floor(packedStatus / 4)
            if rainDynamicSceneCopyState.generation[dst] ~= nil
                and rainDynamicSceneCopyState.generation[dst]
                    ~= generation then
                births = births + 1
                rainDynamicSceneCopyState.birthSeenAt[dst] =
                    rainDynamicStateRenderClock
                local diameterMM = rainDynamicStateRadius[dst] * 2.0
                    / math.max(cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM, 0.000001)
                local travelMix = rainDynamicSceneCopyState.currentTravelMix or 0.0
                rainDynamicSceneCopyState.birthImpactEligible[dst] =
                    diameterMM >= cfg.RUNTIME.RAIN_DYNAMIC_DROP_IMPACT_LARGE_DIAMETER_MM
                    or (diameterMM >= cfg.RUNTIME.RAIN_DYNAMIC_DROP_IMPACT_FAST_MIN_DIAMETER_MM
                        and travelMix >= cfg.RUNTIME.RAIN_DYNAMIC_DROP_IMPACT_FAST_TRAVEL_MIX)
            end
            rainDynamicSceneCopyState.generation[dst] = generation
            local status = packedStatus % 4
            rainDynamicStateAlive[dst] =
                status == 1 and 1.0 or 0.0
            if status == 1 then
                aliveCount = aliveCount + 1
            elseif status == 2 then
                pendingCount = pendingCount + 1
            else
                waitingCount = waitingCount + 1
            end
        end

        rainDynamicSceneCopyState.birthsSinceLog =
            (rainDynamicSceneCopyState.birthsSinceLog or 0) + births
        if cfg.RUNTIME.RAIN_GPU_STATE_LIFECYCLE_LOG
            and rainDynamicStateCallbackCount % 180 == 0 then
            local cells, uniqueCells, largestCell, centerFallback = {}, 0, 0, 0
            for i = 1, count do
                if (rainDynamicStateAlive[i] or 0) > 0.5 then
                    local u = rainDynamicStateU[i] or 0
                    local v = rainDynamicStateV[i] or -1
                    local x = math.max(0, math.min(63, math.floor(u * 64)))
                    local y = math.max(0, math.min(31,
                        math.floor((v + 1) * 32)))
                    local cell = x + y * 64
                    if not cells[cell] then uniqueCells = uniqueCells + 1 end
                    cells[cell] = (cells[cell] or 0) + 1
                    largestCell = math.max(largestCell, cells[cell])
                    if math.abs(u - 0.5) < 0.00001
                        and math.abs(v + 0.5) < 0.00001 then
                        centerFallback = centerFallback + 1
                    end
                end
            end
            ac.log(appNameDebug .. ' Rain lifecycle: rain='
                .. string.format('%.2f',
                    rainStateMetaUpdateParams.values.gRainStateRainIntensity)
                .. ' target='
                .. string.format('%.2f',
                    rainStateMetaUpdateParams.values.gRainStateTargetOccupancy)
                .. ' exposure='
                .. string.format('%.2f',
                    rainStateMetaUpdateParams.values.gRainStateExposure)
                .. ' alive=' .. tostring(aliveCount)
                .. ' waiting=' .. tostring(waitingCount)
                .. ' pending=' .. tostring(pendingCount)
                .. ' uvCells64x32=' .. tostring(uniqueCells)
                .. ' maxCell=' .. tostring(largestCell)
                .. ' centerFallback=' .. tostring(centerFallback)
                .. ' travelMix=' .. string.format('%.2f',
                    rainStateUpdateParams.values.gRainStateTravelMix)
                .. ' flowCap=' .. string.format('%.1f',
                    cfg.RUNTIME.RAIN_GPU_STATE_MOBILE_SPEED_MULTIPLIER)
                .. ' flowDrag=' .. string.format('%.2f',
                    cfg.RUNTIME.RAIN_GPU_STATE_MOBILE_DRAG)
                .. ' airDown=' .. tostring(
                    cfg.RUNTIME.RAIN_AIRFLOW_DOWNWARD_MODE)
                .. ' airDownGain=' .. string.format('%.2f',
                    cfg.RUNTIME.RAIN_AIRFLOW_DOWNWARD_GAIN)
                .. ' birthsSinceLog='
                .. tostring(rainDynamicSceneCopyState.birthsSinceLog))
            rainDynamicSceneCopyState.birthsSinceLog = 0
        end

        rainDynamicStateSnapshotTime = slot.requestTime
        rainDynamicStateHasSnapshot = true
        rainDynamicStateReadbackReady = true
    end)
end

local function applyRainDynamicStateToSurfaceMesh()
    if rainDynamicSurfaceMeshCount == 0 then return end
    if not rainDynamicStateHasSnapshot
        or not rainDynamicSurfaceMesh
        or not rainDynamicSurfaceMeshVertices
        or not rainDynamicSurfaceLookup
        or not rainDynamicSurfaceVertices
    then
        return
    end

    local hadFreshSnapshot = rainDynamicStateReadbackReady
    rainDynamicStateReadbackReady = false

    local applySim = ac.getSim()
    local applyFrame = applySim and applySim.frame or -1

    if applyFrame >= 0 then
        rainDynamicStateApplyCount =
            rainDynamicStateApplyCount + 1

        if rainDynamicStateLastApplyFrame >= 0 then
            local intervalFrames =
                math.max(applyFrame - rainDynamicStateLastApplyFrame, 0)

            rainDynamicStateApplyIntervalSum =
                rainDynamicStateApplyIntervalSum + intervalFrames
            rainDynamicStateApplyIntervalMin =
                math.min(
                    rainDynamicStateApplyIntervalMin,
                    intervalFrames
                )
            rainDynamicStateApplyIntervalMax =
                math.max(
                    rainDynamicStateApplyIntervalMax,
                    intervalFrames
                )
        end

        rainDynamicStateLastApplyFrame = applyFrame

        if cfg.RUNTIME.RAIN_DYNAMIC_STATE_CADENCE_DEBUG
            and rainDynamicStateApplyCount % 30 == 0
        then
            local applyIntervals =
                math.max(rainDynamicStateApplyCount - 1, 1)

            ac.log(
                appNameDebug
                .. ' Dynamic state cadence mesh: avgInterval='
                .. string.format(
                    '%.2f',
                    rainDynamicStateApplyIntervalSum / applyIntervals
                )
                .. 'f min='
                .. tostring(
                    rainDynamicStateApplyIntervalMin == math.huge
                    and 0
                    or rainDynamicStateApplyIntervalMin
                )
                .. ' max='
                .. tostring(rainDynamicStateApplyIntervalMax)
            )
        end
    end

    local stateCount = rainDynamicStateReadbackCount
    local meshCount = rainDynamicSurfaceMeshCount
    local surfaceOffset = cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_TEST_OFFSET_M
    local mappedAlive = 0
    local lookupMisses = 0
    local predictionAge = math.max(
        rainDynamicStateRenderClock - rainDynamicStateSnapshotTime,
        0.0
    )
    predictionAge = math.min(
        predictionAge,
        cfg.RUNTIME.RAIN_DYNAMIC_STATE_PREDICTION_MAX_SECONDS
    )

    for i = 0, meshCount - 1 do
        local vertexIndex = i * 4 + 1
        -- Keep the silhouette stable during a life, but change it on rebirth.
        -- A prime-sized band avoids the former 61-slot repeating pattern.
        local shapeBand = ((i * 73
            + (rainDynamicSceneCopyState.generation[i + 1] or 0) * 131)
            % 1021) * 2
        local active =
            i < stateCount
            and (rainDynamicStateAlive[i + 1] or 0.0) > 0.5

        local sample = nil
        local uv = nil
        local radiusUV = 0.0

        if active then
            uv = vec2(
                (rainDynamicStateU[i + 1] or 0.0)
                    + (rainDynamicStateVelocityU[i + 1] or 0.0)
                    * predictionAge,
                (rainDynamicStateV[i + 1] or -1.0)
                    + (rainDynamicStateVelocityV[i + 1] or 0.0)
                    * predictionAge
            )
            radiusUV = rainDynamicStateRadius[i + 1] or 0.0
            sample = rainDynamicSurfaceSample(
                rainDynamicSurfaceLookup,
                rainDynamicSurfaceVertices,
                uv
            )
        end

        if sample and radiusUV > 0.0 then
            mappedAlive = mappedAlive + 1
            local impactBand = 0
            local birthAt = rainDynamicSceneCopyState.birthSeenAt[i + 1]
            local impactSeconds = cfg.RUNTIME.RAIN_DYNAMIC_DROP_IMPACT_SHAPE_SECONDS
            if cfg.RUNTIME.RAIN_DYNAMIC_DROP_IMPACT_SHAPE_ENABLED
                and rainDynamicSceneCopyState.birthImpactEligible[i + 1]
                and birthAt and impactSeconds > 0.0
            then
                local impactAge = rainDynamicStateRenderClock - birthAt
                if impactAge >= 0.0 and impactAge < impactSeconds then
                    impactBand = math.min(3, math.ceil(
                        (1.0 - impactAge / impactSeconds) * 3.0))
                end
            end
            local impactUV = impactBand * 4.0

            local center =
                sample.position + sample.normal * surfaceOffset
            local uOffset =
                sample.tangentU * (radiusUV * sample.metersPerUVU)
            local vOffset =
                sample.tangentV * (radiusUV * sample.metersPerUVV)

            rainDynamicSurfaceMeshVertices:set(
                vertexIndex,
                ac.MeshVertex.new(
                    center - uOffset - vOffset,
                    sample.normal,
                    vec2(shapeBand, impactUV)
                )
            )
            rainDynamicSurfaceMeshVertices:set(
                vertexIndex + 1,
                ac.MeshVertex.new(
                    center + uOffset - vOffset,
                    sample.normal,
                    vec2(shapeBand + 1, impactUV)
                )
            )
            rainDynamicSurfaceMeshVertices:set(
                vertexIndex + 2,
                ac.MeshVertex.new(
                    center + uOffset + vOffset,
                    sample.normal,
                    vec2(shapeBand + 1, impactUV + 1)
                )
            )
            rainDynamicSurfaceMeshVertices:set(
                vertexIndex + 3,
                ac.MeshVertex.new(
                    center - uOffset + vOffset,
                    sample.normal,
                    vec2(shapeBand, impactUV + 1)
                )
            )
        else
            if active then
                lookupMisses = lookupMisses + 1
            end

            local dead = vec3(0, 0, 0)
            local fallbackNormal = vec3(0, 0, 1)
            rainDynamicSurfaceMeshVertices:set(vertexIndex,     ac.MeshVertex.new(dead, fallbackNormal, vec2(shapeBand, 0)))
            rainDynamicSurfaceMeshVertices:set(vertexIndex + 1, ac.MeshVertex.new(dead, fallbackNormal, vec2(shapeBand + 1, 0)))
            rainDynamicSurfaceMeshVertices:set(vertexIndex + 2, ac.MeshVertex.new(dead, fallbackNormal, vec2(shapeBand + 1, 1)))
            rainDynamicSurfaceMeshVertices:set(vertexIndex + 3, ac.MeshVertex.new(dead, fallbackNormal, vec2(shapeBand, 1)))
        end

    end

    rainDynamicSurfaceMesh:alterVertices(
        rainDynamicSurfaceMeshVertices
    )

    if not rainDynamicStateFirstApplyLogged then
        ac.log(
            appNameDebug
            .. ' Dynamic state first mesh update: '
            .. tostring(mappedAlive)
            .. ' live drops mapped, '
            .. tostring(lookupMisses)
            .. ' surface lookup misses / predictionAge='
            .. string.format('%.4f', predictionAge)
            .. 's'
        )
        rainDynamicStateFirstApplyLogged = true
    end
end

--------------------------------------------------------
-- 3.6.0 TESTING: Custom Shader Render - RainDrops
--------------------------------------------------------
--------------------------------------------------------
-- Capture the available screen scene before the track transparent droplet
-- draw. The weather diagnostic uses a low-resolution mip chain to keep
-- broad fog/cloud structure while suppressing small bright rain streaks.
render.on('main.track.opaque', function()
    if not cfg.RUNTIME.RAIN_DYNAMIC_DROP_SCREEN_SOURCE_COMPARE_DEBUG
        and rainDynamicSceneCopyState.weatherScreenCanvas
    then
        rainDynamicSceneCopyState.weatherScreenCanvas:dispose()
        rainDynamicSceneCopyState.weatherScreenCanvas = nil
        rainDynamicSceneCopyState.weatherWidth = nil
        rainDynamicSceneCopyState.weatherHeight = nil
        rainDynamicSceneCopyState.weatherFrame = nil
    end
    if not cfg.RUNTIME.RAIN_DYNAMIC_DROP_HDR_SNAPSHOT_DEBUG
        and not cfg.RUNTIME.RAIN_DYNAMIC_DROP_SCREEN_SOURCE_COMPARE_DEBUG
        or not cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_STATE_ENABLED
        or not cfg.RUNTIME.RAIN_ENABLED
    then
        return
    end

    local sim = ac.getSim()
    if not sim then return end

    if cfg.RUNTIME.RAIN_DYNAMIC_DROP_SCREEN_SOURCE_COMPARE_DEBUG then
        local screenSize = ui.imageSize('dynamic::screen')
        if screenSize.x < 1 or screenSize.y < 1 then
            screenSize = vec2(sim.windowWidth or 1, sim.windowHeight or 1)
        end
        local weatherWidth = math.max(64,
            math.floor(screenSize.x * 0.5))
        local weatherHeight = math.max(64,
            math.floor(screenSize.y * 0.5))
        if not rainDynamicSceneCopyState.weatherScreenCanvas
            or rainDynamicSceneCopyState.weatherWidth ~= weatherWidth
            or rainDynamicSceneCopyState.weatherHeight ~= weatherHeight
        then
            if rainDynamicSceneCopyState.weatherScreenCanvas then
                rainDynamicSceneCopyState.weatherScreenCanvas:dispose()
            end
            rainDynamicSceneCopyState.weatherScreenCanvas = ui.ExtraCanvas(
                vec2(weatherWidth, weatherHeight), 9,
                render.AntialiasingMode.None,
                render.TextureFormat.R8G8B8A8.UNorm
            )
            rainDynamicSceneCopyState.weatherWidth = weatherWidth
            rainDynamicSceneCopyState.weatherHeight = weatherHeight
            ac.log(appNameDebug .. ' Dynamic drop weather-screen source: '
                .. tostring(weatherWidth) .. 'x' .. tostring(weatherHeight)
                .. ' mips=9')
        end
        rainDynamicSceneCopyState.weatherScreenCanvas:copyFrom(
            'dynamic::screen')
        rainDynamicSceneCopyState.weatherScreenCanvas:mipsUpdate()
        rainDynamicSceneCopyState.weatherFrame = sim.frame
    end
    if not cfg.RUNTIME.RAIN_DYNAMIC_DROP_HDR_SNAPSHOT_DEBUG then return end

    local captureSize = ui.imageSize('dynamic::screen')
    if captureSize.x < 1 or captureSize.y < 1 then
        captureSize = render.getRenderTargetSize()
    end
    local captureWidth = math.max(1, math.floor(captureSize.x))
    local captureHeight = math.max(1, math.floor(captureSize.y))
    if not rainDynamicSceneCopyState.canvas
        or rainDynamicSceneCopyState.width ~= captureWidth
        or rainDynamicSceneCopyState.height ~= captureHeight
    then
        if rainDynamicSceneCopyState.canvas then
            rainDynamicSceneCopyState.canvas:dispose()
        end
        rainDynamicSceneCopyState.canvas = ui.ExtraCanvas(
            vec2(captureWidth, captureHeight),
            1,
            render.AntialiasingMode.None,
            render.TextureFormat.R16G16B16A16.Float
        )
        rainDynamicSceneCopyState.width = captureWidth
        rainDynamicSceneCopyState.height = captureHeight
    end
    rainDynamicSceneCopyState.canvas:copyFrom('dynamic::screen')
    rainDynamicSceneCopyState.captureFrame = sim.frame
end)

-- Refraction-source tone pass (docs/RAINFX_SHOT_TONE.md). Runs inside the
-- drop draw callback (main.track.transparent): dynamic::hdr then holds this
-- frame without car glass and without our drops. updateSceneWithShader is
-- the API meant for passes in the middle of the scene render.
rainDynamicSceneCopyState.shotToneUpdate = function(sim)
    local st = rainDynamicSceneCopyState
    local r = cfg.RUNTIME
    st.toneReady = false
    if not r.RAIN_DYNAMIC_SHOT_TONE_ENABLED or not st.geometryShot
        or st.shotFrame ~= sim.frame then
        return
    end
    local width, height = st.shotWidth or 1, st.shotHeight or 1
    local mips, withDepth = st.shotMips or 1, st.shotWithDepth
    local mode = math.floor((r.RAIN_DYNAMIC_SHOT_TONE_MODE or 2) + 0.5)
    if not st.toneCanvas or st.toneWidth ~= width
        or st.toneHeight ~= height or st.toneMips ~= mips then
        if st.toneCanvas then st.toneCanvas:dispose() end
        if st.toneFrame then st.toneFrame:dispose() end
        st.toneCanvas = ui.ExtraCanvas(vec2(width, height), mips,
            render.AntialiasingMode.None,
            render.TextureFormat.R16G16B16A16.Float)
        st.toneCanvas:setName('RainFX toned refraction source')
        -- Frame copy at 1/4 size: its mip (MATCH_MIP - 2) has the same
        -- footprint as shot mip MATCH_MIP.
        st.toneFrame = ui.ExtraCanvas(
            vec2(math.max(8, math.floor(width / 4)),
                math.max(8, math.floor(height / 4))), 8,
            render.AntialiasingMode.None,
            render.TextureFormat.R16G16B16A16.Float)
        st.toneFrame:setName('RainFX frame tone reference')
        if st.frameFull then st.frameFull:dispose() end
        -- v3: full-size frame copy, RGB = HDR, A = linear depth (m).
        st.frameFull = ui.ExtraCanvas(vec2(width, height), 1,
            render.AntialiasingMode.None,
            render.TextureFormat.R16G16B16A16.Float)
        st.frameFull:setName('RainFX frame copy (HDR + depth)')
        st.toneWidth, st.toneHeight, st.toneMips = width, height, mips
    end
    local near = math.max(sim.cameraClipNear or 0.05,
        r.RAIN_DYNAMIC_DROP_SHOT_NEAR)
    local matchMip = math.max(2, math.min(mips - 1,
        math.floor(r.RAIN_DYNAMIC_SHOT_TONE_MATCH_MIP + 0.5)))
    local ok, res = pcall(function()
        if mode == 2 then
            local copied = st.toneFrame:updateSceneWithShader({
                async = true,
                textures = { txInput = 'dynamic::hdr' },
                shader = [[
                    float4 main(PS_IN pin)
                    {
                        return float4(txInput.SampleLevel(samLinearClamp,
                            pin.Tex, 0.0).rgb, 1.0);
                    }
                ]]
            })
            if copied == false then return false end
            st.toneFrame:mipsUpdate()
        elseif mode == 3 then
            local mainNear = math.max(sim.cameraClipNear or 0.05, 0.001)
            local mainFar = math.max(sim.cameraClipFar or 5000.0, mainNear + 1.0)
            local copied = st.frameFull:updateSceneWithShader({
                async = true,
                textures = { txInput = 'dynamic::hdr', txDepthIn = 'dynamic::depth' },
                values = {
                    gN = mainNear, gF = mainFar,
                    gReversed = r.RAIN_DYNAMIC_SHOT_TONE_FRAME_DEPTH_REVERSED and 1.0 or 0.0,
                },
                shader = [[
                    float4 main(PS_IN pin)
                    {
                        float3 c = txInput.SampleLevel(samLinearClamp,
                            pin.Tex, 0.0).rgb;
                        float d = txDepthIn.SampleLevel(samLinearClamp,
                            pin.Tex, 0.0).r;
                        if (gReversed > 0.5) d = 1.0 - d;
                        float lin = d > 0.99999 ? 10000.0
                            : gN * gF / max(gF - d * (gF - gN), 1e-4);
                        return float4(c, min(lin, 10000.0));
                    }
                ]]
            })
            if copied == false then return false end
        end
        local updated = st.toneCanvas:updateSceneWithShader({
            async = true,
            textures = {
                txShot = st.geometryShot,
                txShotDepth = withDepth and st.geometryShot:depth() or false,
                txFrame = st.toneFrame,
                txFrameFull = st.frameFull,
            },
            values = {
                gFrameMinRatio = r.RAIN_DYNAMIC_SHOT_TONE_FRAME_MIN_RATIO,
                -- s35: also at main.smoke (later than root.transparent).
                gNearTrust = (r.RAIN_DYNAMIC_SHOT_TONE_NEAR_TRUST
                    and (r.RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG
                        or not r.RAIN_DYNAMIC_DROP_DRAW_AT_TRACK)) and 1.0 or 0.0,
                gNearTrustMin = math.max(r.RAIN_DYNAMIC_SHOT_TONE_NEAR_TRUST_MIN, near),
                gFramePriority = (r.RAIN_DYNAMIC_SHOT_TONE_FRAME_PRIORITY
                    and (r.RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG
                        or not r.RAIN_DYNAMIC_DROP_DRAW_AT_TRACK)) and 1.0 or 0.0,
                gAgreeLo = r.RAIN_DYNAMIC_SHOT_TONE_AGREE_LO,
                gAgreeHi = r.RAIN_DYNAMIC_SHOT_TONE_AGREE_HI,
                gComposeDebug = r.RAIN_DYNAMIC_SHOT_TONE_COMPOSE_DEBUG and 1.0 or 0.0,
                gMode = mode,
                gHasDepth = withDepth and 1.0 or 0.0,
                gNear = near,
                gFar = math.max(sim.cameraClipFar or 5000.0, near + 1.0),
                gDensity = r.RAIN_DYNAMIC_SHOT_TONE_AERIAL_DENSITY,
                gAerialMax = r.RAIN_DYNAMIC_SHOT_TONE_AERIAL_MAX,
                gSaturation = r.RAIN_DYNAMIC_SHOT_TONE_SATURATION,
                gCloudContrast = r.RAIN_DYNAMIC_SHOT_TONE_CLOUD_CONTRAST,
                gFog = st.fogTone or sim.fogColor,
                gBroadMip = math.max(0, mips - 1),
                gMatchMip = matchMip,
                gFrameMip = matchMip - 2,
                gMatch = r.RAIN_DYNAMIC_SHOT_TONE_MATCH_STRENGTH,
                gChroma = r.RAIN_DYNAMIC_SHOT_TONE_MATCH_CHROMA,
                gRatioMin = r.RAIN_DYNAMIC_SHOT_TONE_RATIO_MIN,
                gRatioMax = r.RAIN_DYNAMIC_SHOT_TONE_RATIO_MAX,
            },
            shader = [[
                float4 main(PS_IN pin)
                {
                    float2 uv = pin.Tex;
                    float3 w = float3(0.2126, 0.7152, 0.0722);
                    float3 c = txShot.SampleLevel(samLinearClamp, uv, 0.0).rgb;
                    if (gMode > 2.5)
                    {
                        // v3 frame-first composite (per texel, no ratio).
                        float4 f = txFrameFull.SampleLevel(samLinearClamp, uv, 0.0);
                        bool frameSky = f.a > 9000.0;
                        float agree = 1.0;
                        // v4: frame nearer than the shot, beyond the helmet
                        // range = object the shot lacks (wheel, cockpit).
                        float nearFrame = 0.0;
                        if (gHasDepth > 0.5)
                        {
                            float d = txShotDepth.SampleLevel(samLinearClamp,
                                uv, 0.0).r;
                            bool shotSky = d > 0.99999;
                            float linS = gNear * gFar
                                / max(gFar - d * (gFar - gNear), 1e-4);
                            if (shotSky || frameSky)
                                agree = (shotSky && frameSky) ? 1.0 : 0.0;
                            else
                                agree = 1.0 - smoothstep(gAgreeLo,
                                    max(gAgreeHi, gAgreeLo + 1e-3),
                                    abs(f.a - linS) / max(linS, 0.05));
                            bool frameNearer = !frameSky && (shotSky
                                || f.a < linS * (1.0 - gAgreeHi));
                            nearFrame = (gNearTrust > 0.5 && frameNearer
                                && f.a > gNearTrustMin) ? 1.0 : 0.0;
                        }
                        else
                        {
                            // No shot depth: only reject what is nearer than
                            // the shot can see (KN5 visor parts).
                            agree = f.a < gNear * 1.5 ? 0.0 : 1.0;
                        }
                        // Colour sanity: depth can exist where the colour of
                        // a root object is not drawn yet at this stage.
                        float lf = dot(f.rgb, w);
                        float ls = dot(c, w);
                        // (not for nearFrame: a dark wheel against a bright
                        // shot sky is real, not missing colour)
                        agree *= (lf > 1e-6 ? 1.0 : 0.0)
                            * (nearFrame > 0.5 ? 1.0
                                : smoothstep(gFrameMinRatio * 0.5,
                                    gFrameMinRatio, lf / max(ls, 1e-5)))
                            * saturate(gMatch);
                        if (nearFrame > 0.5 && lf > 1e-6)
                            agree = saturate(gMatch);
                        if (gFramePriority > 0.5 && lf > 1e-6
                            && f.a > gNearTrustMin)
                            agree = saturate(gMatch);
                        if (gComposeDebug > 0.5)
                            return nearFrame > 0.5 && lf > 1e-6
                                ? float4(0.0, 0.3, 1.0, 1.0)
                                : float4(1.0 - agree, agree, 0.0, 1.0);
                        return float4(lerp(c, f.rgb, agree), 1.0);
                    }
                    if (gMode > 1.5)
                    {
                        // v2 frame match: low-frequency ratio frame / shot.
                        float3 sLow = txShot.SampleLevel(samLinearClamp, uv,
                            gMatchMip).rgb;
                        float3 fLow = txFrame.SampleLevel(samLinearClamp, uv,
                            gFrameMip).rgb;
                        float valid = dot(fLow, w) > 1e-5 ? 1.0 : 0.0;
                        float3 ratio = clamp(fLow / max(sLow, 1e-4),
                            gRatioMin, gRatioMax);
                        float lr = clamp(dot(fLow, w) / max(dot(sLow, w), 1e-4),
                            gRatioMin, gRatioMax);
                        float3 m = lerp(float3(lr, lr, lr), ratio,
                            saturate(gChroma));
                        c *= lerp(float3(1.0, 1.0, 1.0), m,
                            saturate(gMatch) * valid);
                        return float4(c, 1.0);
                    }
                    // v1 aerial fog toward the (desaturated) fog tone.
                    float d = gHasDepth > 0.5
                        ? txShotDepth.SampleLevel(samLinearClamp, uv, 0.0).r
                        : 0.0;
                    bool sky = gHasDepth > 0.5 && d > 0.99999;
                    float lin = gNear * gFar
                        / max(gFar - d * (gFar - gNear), 1e-4);
                    float aerial = sky ? 1.0
                        : (1.0 - exp(-lin * max(gDensity, 0.0)))
                            * saturate(gAerialMax);
                    float l = dot(c, w);
                    float far01 = sky ? 1.0 : saturate(1.0
                        - exp(-lin * max(gDensity, 0.0)));
                    c = lerp(float3(l, l, l), c,
                        lerp(1.0, saturate(gSaturation), far01));
                    float3 broad = txShot.SampleLevel(samLinearClamp, uv,
                        gBroadMip).rgb;
                    float contrast = clamp(1.0 + (l / max(dot(broad, w), 0.02)
                        - 1.0) * gCloudContrast, 0.95, 1.12);
                    c = lerp(c, gFog * contrast, saturate(aerial));
                    return float4(c, 1.0);
                }
            ]]
        })
        if updated == false then return false end
        if mips > 1 then st.toneCanvas:mipsUpdate() end
        return true
    end)
    st.toneReady = ok and res and true or false
    if not ok and not st.toneWarned then
        ac.warn(appNameDebug .. ' Shot tone pass: ' .. tostring(res))
        st.toneWarned = true
    end
end

-- Complete GPU and transport preparation before transparent callbacks.
-- These callbacks only consume resources prepared for this exact frame.
render.onSceneReady(function()
    if not initialized or not shaderInitialized
        or not cfg.RUNTIME.RAIN_ENABLED then return end
    local sim = ac.getSim()
    if not sim then return end
    updateRainGPUState(sim)
    if cfg.RUNTIME.RAIN_GPU_STATE_MODE > 0
        and not rainStateInitialized then return end
    rainDynamicSceneCopyState.stateReadyFrame = sim.frame
    if cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_STATE_ENABLED then
        local maskOk, maskError = pcall(
            rainDynamicSceneCopyState.updateTrailMaskTimed, sim)
        if not maskOk and not rainDynamicSceneCopyState.maskWarned then
            ac.warn(appNameDebug .. ' Dynamic UV mask update failed: '
                .. tostring(maskError))
            rainDynamicSceneCopyState.maskWarned = true
        end
        rainDynamicSceneCopyState.microRebakeIfNeeded(
            rainDynamicSceneCopyState)
        if cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED then
            local tB0 = cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0
            local birthOk, birthError = pcall(
                rainDynamicSceneCopyState.updateBirthMask, sim)
            -- R1.0 profiling (docs/RAINFX_GPU_PRELAID.md): CPU cost of the
            -- per-drop stamping (birth mask + water-field heads + trails).
            rainDynamicSceneCopyState.profBirthMs = ((cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0) - tB0) * 1000.0
            if not birthOk and not rainDynamicSceneCopyState.birthMaskWarned then
                ac.warn(appNameDebug .. ' Dynamic birth mask update failed: '
                    .. tostring(birthError))
                rainDynamicSceneCopyState.birthMaskWarned = true
            end
        else
            rainDynamicSceneCopyState.birthMaskSuspended = true
        end
        if not initializeRainDynamicSurfaceTest() then return end
        rainDynamicSceneCopyState.preparedFrame = sim.frame
        if not rainDynamicSceneCopyState.prepareReadyLogged then
            ac.log(appNameDebug .. ' Dynamic drop scene-ready preparation '
                .. 'complete: state=' .. tostring(rainStateInitialized)
                .. ' surface=' .. tostring(rainDynamicSurfaceInitialized)
                .. ' frame=' .. tostring(sim.frame))
            rainDynamicSceneCopyState.prepareReadyLogged = true
        end
    end
end)

-- Stage 1: low-resolution persistent visor-UV motion mask. Existing
-- readback supplies head centers; no per-drop surface lookup or trail mesh.
rainDynamicSceneCopyState.updateTrailMask = function(sim)
    if not cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_ENABLED
        or not rainDynamicStateHasSnapshot then return end
    local size = math.max(128, math.floor(
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SIZE))
    local state = rainDynamicSceneCopyState
    if not state.trailMaskA or state.trailMaskSize ~= size then
        if state.trailMaskA then state.trailMaskA:dispose() end
        if state.trailMaskB then state.trailMaskB:dispose() end
        -- 2026-10-03 fix (docs/RAINFX_TRAIL_FLOW.md "wipe mask"): 8-bit
        -- UNorm could not decay: v * decay rounds back to v once
        -- v < 0.5 / (1 - decay) (e.g. ~12 % at 60 fps / 3.1 s, ~40 % with
        -- longer seconds), so wiped paths never recovered and kept
        -- accumulating. fp16 RG (only R/G are read) + an explicit cutoff.
        state.trailMaskA = ui.ExtraCanvas(vec2(size, size), 1,
            render.TextureFormat.R16G16.Float)
            :setName('RainFX Wipe Mask A')
        state.trailMaskB = ui.ExtraCanvas(vec2(size, size), 1,
            render.TextureFormat.R16G16.Float)
            :setName('RainFX Wipe Mask B')
        state.trailMaskA:clear(rgbm.colors.transparent)
        state.trailMaskB:clear(rgbm.colors.transparent)
        state.trailMaskRead = state.trailMaskA
        state.trailMaskSize = size
        state.trailMaskLast = {}
        state.trailMaskCursor = 1
        state.trailMaskFrame = nil
    end
    if state.trailMaskFrame == sim.frame then return end
    local source = state.trailMaskRead
    local target = source == state.trailMaskA
        and state.trailMaskB or state.trailMaskA
    local frameDt = math.min(math.max(sim.dt or 0.0, 0.0), 0.05)
    local wipeDecay = math.exp(-frameDt * 3.0
        / math.max(cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SECONDS, 0.05))
    local ridgeDecay = math.exp(-frameDt * 3.0
        / math.max(cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_SECONDS, 0.05))
    local copied = target:updateWithShader({
        async = true,
        textures = { txWipePrevious = source },
        values = {
            gWipeDecay = wipeDecay,
            gRidgeDecay = ridgeDecay,
        },
        shader = [[
            float4 main(PS_IN pin)
            {
                float4 previous = txWipePrevious.SampleLevel(
                    samLinearClamp, pin.Tex, 0.0);
                float r = previous.r * gRidgeDecay;
                float g = previous.g * gWipeDecay;
                return float4(r < 0.004 ? 0.0 : r, g < 0.004 ? 0.0 : g,
                    0.0, 1.0);
            }
        ]]
    })
    if copied == false then return end

    local count = rainDynamicStateReadbackCount
    local limit = math.max(1, math.floor(
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_MAX_STAMPS))
    local cursor = state.trailMaskCursor
    local stamps = {}
    local inspected = 0
    local predictedAge = math.min(math.max(
        rainDynamicStateRenderClock - rainDynamicStateSnapshotTime, 0.0),
        cfg.RUNTIME.RAIN_DYNAMIC_STATE_PREDICTION_MAX_SECONDS)
    while inspected < count and #stamps < limit do
        local index = (cursor - 1 + inspected) % count + 1
        local generation = state.generation
            and state.generation[index] or 0
        local old = state.trailMaskLast[index]
        if (rainDynamicStateAlive[index] or 0) > 0.5 then
            local u = (rainDynamicStateU[index] or 0.0)
                + (rainDynamicStateVelocityU[index] or 0.0)
                    * predictedAge
            local v = (rainDynamicStateV[index] or -1.0)
                + (rainDynamicStateVelocityV[index] or 0.0)
                    * predictedAge
            local radius = rainDynamicStateRadius[index] or 0.0
            if u >= 0.0 and u <= 1.0 and v >= -1.0 and v <= 0.0 then
                if old and old.generation ~= generation then old = nil end
                local du = old and u - old.u or 0.0
                local dv = old and v - old.v or 0.0
                local minimum = math.max(radius * 0.4, 1.0 / size)
                local distance2 = du * du + dv * dv
                if not old or distance2 >= minimum * minimum then
                    -- New births stamp only at their current position.
                    -- Subsequent movement leaves the ordinary trail.
                    local fromU = old and old.u or u
                    local fromV = old and old.v or v
                    -- radius is the physical visor-UV radius of this drop.
                    stamps[#stamps + 1] = {
                        x0 = fromU * size, y0 = (fromV + 1.0) * size,
                        x1 = u * size, y1 = (v + 1.0) * size,
                        diameter = 2.0 * radius * size,
                    }
                    state.trailMaskLast[index] = {
                        u = u, v = v, generation = generation }
                end
            end
        else
            state.trailMaskLast[index] = nil
        end
        inspected = inspected + 1
    end
    state.trailMaskCursor = (cursor - 1 + inspected) % count + 1
    if #stamps > 0 then
        local texelsPerMM = cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM
            * size
        local minWidth = math.max(0.25,
            cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_MIN_WIDTH_TEXELS)
        local wipeScale = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_WIPE_WIDTH_SCALE
        local wipeOffset = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_WIPE_WIDTH_OFFSET_MM
            * texelsPerMM
        local ridgeScale =
            cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_WIDTH_SCALE
        local ridgeOffset =
            cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_WIDTH_OFFSET_MM
            * texelsPerMM
        local widthSum, widthCount = 0.0, 0
        target:update(function()
            local wipeColor = rgbm(0.0, 0.95, 0.0, 1.0)
            local ridgeColor = rgbm(0.95, 0.95, 0.0, 1.0)
            for _, stamp in ipairs(stamps) do
                local first = vec2(stamp.x0, stamp.y0)
                local last = vec2(stamp.x1, stamp.y1)
                local wipeWidth = math.max(minWidth,
                    stamp.diameter * wipeScale + wipeOffset)
                local ridgeWidth = math.max(minWidth,
                    stamp.diameter * ridgeScale + ridgeOffset)
                ui.drawLine(first, last, wipeColor, wipeWidth)
                ui.drawCircleFilled(last, wipeWidth * 0.5, wipeColor, 8)
                -- Narrow liquid core inside a wider wiped footprint.
                ui.drawLine(first, last, ridgeColor, ridgeWidth)
                ui.drawCircleFilled(last, ridgeWidth * 0.5, ridgeColor, 8)
                widthSum = widthSum + wipeWidth
                widthCount = widthCount + 1
            end
        end)
        if widthCount > 0 then
            state.trailMaskMeanWidth = widthSum / widthCount
        end
    end
    state.trailMaskRead = target
    state.trailMaskFrame = sim.frame
    state.trailMaskStamps = (state.trailMaskStamps or 0) + #stamps
    if sim.frame % 180 == 0 then
        ac.log(appNameDebug .. ' Dynamic UV mask: '
            .. tostring(size) .. 'x' .. tostring(size)
            .. ' stamps=' .. tostring(state.trailMaskStamps)
            .. ' budget=' .. tostring(limit)
            .. ' recoverySeconds='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SECONDS))
        state.trailMaskStamps = 0
    end
end


-- Micro pattern bake key: any change triggers a debounced re-bake.
rainDynamicSceneCopyState.microBakeKeyNow = function()
    local r = cfg.RUNTIME
    return string.format('%.3f|%.2f|%.2f|%d|%.2f|%.2f|%.2f|%.2f',
        r.RAIN_DYNAMIC_MICRO_PATTERN_DIAMETER_MM,
        r.RAIN_DYNAMIC_MICRO_PATTERN_TEXELS_PER_CELL,
        r.RAIN_DYNAMIC_MICRO_PATTERN_RIM_TEXELS,
        math.floor(r.RAIN_DYNAMIC_MICRO_PATTERN_STRATA + 0.5),
        r.RAIN_DYNAMIC_MICRO_PATTERN_FIRST_PRESENCE,
        r.RAIN_DYNAMIC_MICRO_PATTERN_PRESENCE,
        r.RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MIN,
        r.RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MAX)
end

-- Called from onSceneReady (never from UI): re-bake 0.4 s after the last
-- change of any bake setting, so dragging a slider does not re-bake per frame.
rainDynamicSceneCopyState.microRebakeIfNeeded = function(state)
    if not state.bakeMicroPattern then return end
    local key = state.microBakeKeyNow()
    if key == state.microBakeKey then
        state.microPendingKey = nil
        return
    end
    local now = rainDynamicStateRenderClock
    if state.microPendingKey ~= key then
        state.microPendingKey = key
        state.microPendingSince = now
        return
    end
    if now - (state.microPendingSince or now) < 0.4 then return end
    local ok, err = pcall(state.bakeMicroPattern)
    if not ok then
        ac.warn(appNameDebug .. ' Micro pattern re-bake failed: '
            .. tostring(err))
        state.microBakeKey = key
    else
        ac.log(appNameDebug .. ' Micro pattern re-baked: ' .. key
            .. ' size=' .. tostring(state.microPatternSize))
    end
    state.microPendingKey = nil
end

-- Smear mask trigger (docs/RAINFX_SMEAR_MASK.md §v3): rain x relative
-- airspeed, facing term from the camera look vs incoming air; smoothed and
-- advanced once per frame. Also resolves the mask texture once.
-- UI tooltips (hover) for the trail-flow / smear section.
rainDynamicSceneCopyState.uiHelp = {
    RAIN_DYNAMIC_SMEAR_ENABLED = 'Master switch of the smear region (fingerprint-like turbid patches revealed by water density).',
    RAIN_DYNAMIC_SMEAR_USE_TEXTURE = 'Use the mask texture (R reveal order, G blend). Off: procedural stand-in with the same meaning.',
    RAIN_DYNAMIC_SMEAR_TRIGGER_OVERRIDE = 'Force the trigger ON regardless of density.',
    RAIN_DYNAMIC_SMEAR_REVEAL_OVERRIDE_ON = 'Use the manual reveal value instead of the density x facing result.',
    RAIN_DYNAMIC_SMEAR_REVEAL_OVERRIDE = 'Manual reveal 0..1: region = pixels with R <= this value.',
    RAIN_DYNAMIC_SMEAR_REF_KMH = 'Airspeed (car minus wind) that counts as amplification 1. density = rain x airspeed / this.',
    RAIN_DYNAMIC_SMEAR_TRIGGER = 'Density at which the effect starts.',
    RAIN_DYNAMIC_SMEAR_FULL = 'Density giving full reveal (reveal = min(1, density / this) x facing).',
    RAIN_DYNAMIC_SMEAR_FACING_POWER = 'Sharpens the facing term (camera look vs incoming air). Higher = only head-on air reveals.',
    RAIN_DYNAMIC_SMEAR_ATTACK_SECONDS = 'Time constant while the reveal rises.',
    RAIN_DYNAMIC_SMEAR_RELEASE_SECONDS = 'Time constant while the reveal falls (region dries away).',
    RAIN_DYNAMIC_SMEAR_EDGE_SOFT = 'Width of the R band around the reveal front (soft region edge).',
    RAIN_DYNAMIC_SMEAR_MICRO_HIDE = 'Inside the region micro drops show only by G (1 = fully, low G hides them).',
    RAIN_DYNAMIC_SMEAR_MICRO_TURBID = 'Micro drops turn turbid by region x G x this.',
    RAIN_DYNAMIC_SMEAR_DROP_TURBID = 'GPU drop heads turn turbid by region x G x this.',
    RAIN_DYNAMIC_SMEAR_TRAIL_MIX = 'WF trails keep their shape; their colour mixes with the layer beneath by this (region only).',
    RAIN_DYNAMIC_SMEAR_TRAIL_TURBID = 'Legacy WF colour at smear transition edges. Full smear interiors use neutral refraction and preserve the smear material.',
    RAIN_DYNAMIC_SMEAR_TRAIL_BLUR = 'Legacy WF blur at smear transition edges. Full smear interiors retain their original blur.',
    RAIN_DYNAMIC_SMEAR_TRAIL_CLEAR = 'Legacy WF overlay clearing at smear transition edges. Full smear interiors use the independent neutral trail-refraction path.',
    RAIN_DYNAMIC_SMEAR_HEAD_MIX = 'GPU heads keep their shape; colour mixes with the layer beneath by this.',
    RAIN_DYNAMIC_SMEAR_PATH_WEAKEN = 'Wipe paths, thin film and ridge inside the region follow G by this: low G = weak wipe, high G = full (v8).',
    RAIN_DYNAMIC_SMEAR_MIP = 'Blur of the turbid colour (mip of the refraction source).',
    RAIN_DYNAMIC_SMEAR_VEIL = 'Turbid colour drifts toward the fog colour by this.',
    RAIN_DYNAMIC_SMEAR_HEAD_HIDE = 'Moving drops inside the region: visibility goes to G (1 = low G hides them fully).',
    RAIN_DYNAMIC_SMEAR_TRAIL_HIDE = 'G-dependent legacy WF overlay visibility at smear transition edges; it does not hide neutral refraction in full smear interiors.',
    RAIN_DYNAMIC_SMEAR_R_TILING = 'How many times the mask R (region blobs) repeats over the visor. The texture must tile.',
    RAIN_DYNAMIC_SMEAR_G_TILING = 'How many times the mask G (class patches) repeats over the visor. Higher = denser pattern.',
    RAIN_DYNAMIC_SMEAR_CLASSES = 'Number of facet classes G is cut into. Each class bends and tones the scene its own way.',
    RAIN_DYNAMIC_SMEAR_CLASS_SOFT = 'How blurred the class boundaries are (share of a class blending into the next).',
    RAIN_DYNAMIC_SMEAR_CLASS_SEED = 'Reshuffles the class offsets, tones and erase order.',
    RAIN_DYNAMIC_SMEAR_FACET_PIXELS = 'How far each class shifts its refraction image (render pixels).',
    RAIN_DYNAMIC_SMEAR_TONE_RANGE = 'Brightness spread between classes (+-).',
    RAIN_DYNAMIC_SMEAR_CLASS_MIP_RANGE = 'Blur spread between classes (+- mip around the turbid blur).',
    RAIN_DYNAMIC_SMEAR_ERASE_SPAN = 'Below this reveal level the classes are erased one by one (random fixed order).',
    RAIN_DYNAMIC_SMEAR_CLASS_WIPE = 'How strongly wiping/flowing water erases classes on its path.',
    RAIN_DYNAMIC_SMEAR_LINE_STRENGTH = 'Faint darkening on the boundaries between classes.',
    RAIN_DYNAMIC_SMEAR_LINE_WIDTH = 'Width of the boundary lines, in class units.',
    RAIN_DYNAMIC_SMEAR_FACET_ALPHA = 'Opacity of the class facet film on bare glass (no depth write, like haze).',
    RAIN_DYNAMIC_MICRO_POP_ENABLED = 'Micro drops randomly vanish and land again, each on its own clock.',
    RAIN_DYNAMIC_MICRO_POP_PICK = 'Share of micro disks that take part in the pop-in cycle (pickup range).',
    RAIN_DYNAMIC_MICRO_POP_PERIOD = 'Mean cycle length in seconds (each disk x 0.5..1.5).',
    RAIN_DYNAMIC_MICRO_POP_OFF = 'Share of its cycle a picked disk is absent before it lands.',
    RAIN_DYNAMIC_MICRO_POP_FADE = 'Share of its life a disk spends fading out at the end.',
    RAIN_DYNAMIC_MICRO_POP_FLASH = 'Short highlight when a disk lands.',
    RAIN_DYNAMIC_MICRO_POP_ID_SCALE = 'Disk id cells per pattern cell. Raise if neighbouring disks pop together.',
    RAIN_DYNAMIC_SMEAR_G_CONTRAST = 'G contrast around PIVOT: higher cuts the pattern away more raggedly.',
    RAIN_DYNAMIC_SMEAR_G_PIVOT = 'G value that the contrast keeps fixed.',
    RAIN_DYNAMIC_SMEAR_G_GAMMA = 'Gamma after contrast: > 1 darkens G (more hidden micro).',
    RAIN_DYNAMIC_SMEAR_MASK_CELLS = 'Procedural mask only: blob scale.',
    RAIN_DYNAMIC_SMEAR_MASK_WARP = 'Procedural mask only: blob outline warp.',
    RAIN_DYNAMIC_SMEAR_FILL_CELLS = 'Procedural mask only: G noise scale.',
    RAIN_DYNAMIC_SMEAR_FILL_PATCH_CELLS = 'Procedural mask only: G patch scale.',
    RAIN_VISOR_MOTION_TEST_CLEAR = 'Calls clearMotion() on the visor node chain every frame (stored previous transform = current).',
    RAIN_VISOR_MOTION_TEST_LATE = 'Re-applies the camera-locked transform in the render callback, after the camera scripts. Tests a one-frame lag.',
    RAIN_DYNAMIC_SHOT_TONE_ENABLED = 'Tones the refraction source once per frame before its mips: far geometry gets aerial fog by depth, sky becomes the fog tone. Removes the paint-like edges in blurred drops.',
    RAIN_DYNAMIC_SHOT_TONE_AERIAL_DENSITY = 'Aerial fog per metre: amount = 1 - exp(-distance x density). 0.004 = 33 % at 100 m, 86 % at 500 m.',
    RAIN_DYNAMIC_SHOT_TONE_AERIAL_MAX = 'Upper limit of the aerial fog on geometry (sky always gets the full fog tone).',
    RAIN_DYNAMIC_SHOT_TONE_SATURATION = 'Colour kept on far geometry in the refraction source (scaled by distance; the near cockpit keeps its colour). Lower = greyer, closer to the fogged frame.',
    RAIN_DYNAMIC_SHOT_TONE_CLOUD_CONTRAST = 'Cloud detail kept in the fog-toned sky (luminance ratio to the broad sky, bounded 0.95..1.12).',
    RAIN_DYNAMIC_SHOT_TONE_MODE = '1 = aerial fog toward the fog colour (v1). 2 = match the shot to this frame (dynamic::hdr before car glass): hue, fog and exposure from the real frame, detail from the shot.',
    RAIN_DYNAMIC_SHOT_TONE_MATCH_MIP = 'Blur level of the frame/shot ratio. Higher = smoother tone transfer, lower = follows smaller objects.',
    RAIN_DYNAMIC_SHOT_TONE_MATCH_STRENGTH = 'How much of the frame tone is applied to the refraction source.',
    RAIN_DYNAMIC_SHOT_TONE_MATCH_CHROMA = '1 = per-channel ratio (hue matched), 0 = luminance ratio only (shot hue kept).',
    RAIN_DYNAMIC_SHOT_TONE_RATIO_MIN = 'Lower clamp of the frame/shot ratio.',
    RAIN_DYNAMIC_SHOT_TONE_RATIO_MAX = 'Upper clamp of the frame/shot ratio.',
    RAIN_DYNAMIC_FOG_TONE_SATURATION = 'Chroma kept in the colour used for veils, glints, turbid smear and pop flashes (the raw fog colour was too blue).',
    RAIN_DYNAMIC_SHOT_TONE_PREVIEW = 'Shows the toned refraction source next to the raw shot in this window.',
    RAIN_DYNAMIC_DROP_DEPTH_OCCLUDE = 'Second pass writes visor depth where drops are, so car glass drawn later cannot cover them.',
    RAIN_DYNAMIC_DROP_DEPTH_ALPHA_MIN = 'Exact depth pass: only pixels at least this opaque occlude the glass.',
}

-- Track wind in world m/s (x, z), per RAIN_DYNAMIC_SMEAR_WIND_MODE axes
-- (0 = ignore). Shared by the smear density and the GPU airflow force.
rainDynamicSceneCopyState.windWorldMS = function(state, sim)
    local w = sim and sim.windVelocityKmh
    local mode = math.floor(cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_WIND_MODE + 0.5)
    if not w or mode <= 0 then return 0.0, 0.0 end
    local wx, wz = w.x, w.y
    if mode == 2 then wz = -wz elseif mode == 3 then wx, wz = -wx, -wz end
    return wx / 3.6, wz / 3.6
end

rainDynamicSceneCopyState.appFolder = appFolder
rainDynamicSceneCopyState.smearUpdate = function(state, sim)
    local r = cfg.RUNTIME
    if sim.frame ~= nil and state.smearFrame == sim.frame then
        return state.smearLevel or 0.0
    end
    state.smearFrame = sim.frame
    if state.smearTexturePathKey ~= r.RAIN_DYNAMIC_SMEAR_TEXTURE then
        state.smearTexturePathKey = r.RAIN_DYNAMIC_SMEAR_TEXTURE
        local path = state.appFolder .. '/' .. r.RAIN_DYNAMIC_SMEAR_TEXTURE
        state.smearTexturePath = io.fileExists(path) and path or nil
    end
    local dt = math.min(math.max(sim.dt or 0.0, 0.0), 0.1)
    local rain = math.max(0.0, math.min(1.0,
        r.RAIN_GPU_STATE_RAIN_OVERRIDE >= 0.0 and r.RAIN_GPU_STATE_RAIN_OVERRIDE
        or sim.rainIntensity or 0.0))
    -- Incoming air in world space: car velocity (m/s) minus wind. The wind
    -- vec2 is taken as game-space (x, z) km/h (assumption, see doc).
    local car = ac.getCar(0)
    local vx, vy, vz = 0.0, 0.0, 0.0
    if car and car.velocity then
        vx, vy, vz = car.velocity.x, car.velocity.y, car.velocity.z
    end
    local carKmh = math.sqrt(vx * vx + vy * vy + vz * vz) * 3.6
    local facingNoWind = 0.0
    local look = sim.cameraLook
    if carKmh > 1.0 and look then
        facingNoWind = math.max(0.0, (look.x * vx + look.y * vy
            + look.z * vz) / (carKmh / 3.6))
    end
    local w = sim.windVelocityKmh
    local wx, wz = state.windWorldMS(state, sim)
    vx = vx - wx
    vz = vz - wz
    state.smearCarKmh, state.smearFacingNoWind = carKmh, facingNoWind
    state.smearWindX, state.smearWindY = w and w.x or 0.0, w and w.y or 0.0
    local airKmh = math.sqrt(vx * vx + vy * vy + vz * vz) * 3.6
    local amp = airKmh / math.max(r.RAIN_DYNAMIC_SMEAR_REF_KMH, 1.0)
    local density = rain * amp
    local facing = 0.0
    if airKmh > 1.0 and look then
        local inv = 1.0 / (airKmh / 3.6)
        facing = math.max(0.0, (look.x * vx + look.y * vy + look.z * vz) * inv)
        facing = facing ^ math.max(r.RAIN_DYNAMIC_SMEAR_FACING_POWER, 0.05)
    end
    local triggered = r.RAIN_DYNAMIC_SMEAR_TRIGGER_OVERRIDE
        or density >= r.RAIN_DYNAMIC_SMEAR_TRIGGER
    local target = triggered and math.min(1.0, density
        / math.max(r.RAIN_DYNAMIC_SMEAR_FULL, 1e-3)) * facing or 0.0
    -- Explicit switch: a slider parked at -0.00 used to count as >= 0 and
    -- forced the reveal to zero.
    if r.RAIN_DYNAMIC_SMEAR_REVEAL_OVERRIDE_ON then
        target = math.max(0.0, math.min(1.0, r.RAIN_DYNAMIC_SMEAR_REVEAL_OVERRIDE))
    end
    if not r.RAIN_DYNAMIC_SMEAR_ENABLED then target = 0.0 end
    local level = state.smearLevel or 0.0
    local tau = target > level and r.RAIN_DYNAMIC_SMEAR_ATTACK_SECONDS
        or r.RAIN_DYNAMIC_SMEAR_RELEASE_SECONDS
    level = level + (target - level) * (1.0 - math.exp(-dt / math.max(tau, 0.05)))
    if level < 0.0005 and target <= 0.0 then level = 0.0 end
    state.smearRain, state.smearAirKmh, state.smearAmp = rain, airKmh, amp
    -- Shared clock (micro pop-in). Long wrap: a wrap re-phases every disk.
    state.smearTime = ((state.smearTime or 0.0) + dt) % 65536.0
    -- Trail ripple T3 (docs/RAINFX_TRAIL_REFRACTION.md): speed-weighted
    -- mean drop flow in visor UV (readback, every 4 frames), smoothed; the
    -- ripple phase integrates it so the pattern travels with the water.
    state.flowTick = ((state.flowTick or 0) + 1) % 4
    if state.flowTick == 0 then
        local n = rainDynamicStateReadbackCount or 0
        local su, sv, sw = 0.0, 0.0, 0.0
        for i = 1, n do
            if (rainDynamicStateAlive[i] or 0.0) > 0.5 then
                local fu = rainDynamicStateVelocityU[i] or 0.0
                local fv = rainDynamicStateVelocityV[i] or 0.0
                local sp = math.sqrt(fu * fu + fv * fv)
                if sp > 0.002 then
                    su, sv, sw = su + fu * sp, sv + fv * sp, sw + sp
                end
            end
        end
        state.flowTU = sw > 0.0 and su / sw or 0.0
        state.flowTV = sw > 0.0 and sv / sw or 0.0
    end
    local fk = 1.0 - math.exp(-dt / 0.5)
    state.flowU = (state.flowU or 0.0) + ((state.flowTU or 0.0) - (state.flowU or 0.0)) * fk
    state.flowV = (state.flowV or 0.0) + ((state.flowTV or 0.0) - (state.flowV or 0.0)) * fk
    local fsp = math.sqrt(state.flowU * state.flowU + state.flowV * state.flowV)
    if fsp > 0.003 then
        state.flowDirU, state.flowDirV = state.flowU / fsp, state.flowV / fsp
    end
    state.ripplePhase = ((state.ripplePhase or 0.0) + fsp * dt
        * r.RAIN_DYNAMIC_TRAIL_RIPPLE_ALONG * r.RAIN_DYNAMIC_TRAIL_RIPPLE_SPEED) % 4096.0
    state.smearDensity, state.smearFacing = density, facing
    state.smearTriggered, state.smearTarget = triggered, target
    state.smearLevel = level
    return level
end

-- Water field helpers (docs/RAINFX_WATER_FIELD.md). Stored on the shared
-- state table instead of new chunk-level locals (Lua local/upvalue limits).
rainDynamicSceneCopyState.waterKernel = function(state)
    if state.waterKernelCanvas then return state.waterKernelCanvas end
    local canvas = ui.ExtraCanvas(vec2(64, 64), 1,
        render.TextureFormat.R8G8B8A8.UNorm)
        :setName('RainFX water kernel')
    -- Straight alpha dome h = 1 - r^2, zero at the quad's inscribed circle.
    canvas:updateWithShader({
        blendMode = render.BlendMode.Opaque,
        shader = [[
            float4 main(PS_IN pin)
            {
                float2 p = pin.Tex * 2.0 - 1.0;
                return float4(1.0, 1.0, 1.0, saturate(1.0 - dot(p, p)));
            }
        ]]
    })
    state.waterKernelCanvas = canvas
    return canvas
end

-- Ribbon kernel (docs/RAINFX_TRAIL_FLOW.md): straight-alpha profile
-- h = 1 - v^2 across, constant along. Consecutive sheet segments drawn from
-- the previous to the current point abut exactly, so a fast path is one
-- continuous film instead of a chain of stretched domes.
rainDynamicSceneCopyState.waterRibbonKernel = function(state)
    if state.waterRibbonCanvas then return state.waterRibbonCanvas end
    local canvas = ui.ExtraCanvas(vec2(8, 64), 1,
        render.TextureFormat.R8G8B8A8.UNorm)
        :setName('RainFX water ribbon kernel')
    canvas:updateWithShader({
        blendMode = render.BlendMode.Opaque,
        shader = [[
            float4 main(PS_IN pin)
            {
                float v = pin.Tex.y * 2.0 - 1.0;
                return float4(1.0, 1.0, 1.0, saturate(1.0 - v * v));
            }
        ]]
    })
    state.waterRibbonCanvas = canvas
    return canvas
end

-- Impact splash v2 (docs/RAINFX_IMPACT_SPLASH.md). State at t = 0..1 of
-- its life, drawn as union kernels at the frozen impact point:
--   centre: pressed flat (amplitude falls), then empty after HOLLOW_AT;
--   rim: kernels on a ring of radius Rf (1 + SPREAD E s(t)) carry the mass
--        moved out of the centre (slope, i.e. the 3D look, moves with it);
--   break-up after BREAK_AT: rim kernels fly outward, shrink and vanish
--        one by one; small satellites are thrown beyond the rim.
-- `quad(cx, cy, rx, ry, ux, uy, code, energy, amp)`; amp scales height.
rainDynamicSceneCopyState.waterFieldSplashV2 = function(quad, origin, scale,
    t, minKernel, ampScale)
    local r = cfg.RUNTIME
    local frac = rainDynamicSurfaceFrac
    local function sstep(a, b, x)
        local k = math.max(0.0, math.min(1.0, (x - a) / math.max(b - a, 1e-4)))
        return k * k * (3.0 - 2.0 * k)
    end
    local Rf, E = origin.radius, origin.energy or origin.amount
    local sa, sb = origin.seedA, origin.seedB
    local x, y = origin.x, origin.y
    -- These values depend only on the drop life. Reuse them for every
    -- animation frame and for the final persistent-trail stamp.
    local pieces = origin.splashPieces
    if not pieces then
        local ring = {}
        local satellites = {}
        local n = math.floor(10 + 12 * E * (0.5 + 0.5 * frac(sb * 3.7)) + 0.5)
        for k = 1, n do
            local h1 = frac(sa * 17.13 + k * 0.7548776662)
            local h2 = frac(sb * 11.71 + k * 0.5698402911)
            local h3 = frac((sa + sb) * 7.77 + k * 0.4142135623)
            local a = (k + 0.6 * (h1 - 0.5)) / n * math.pi * 2.0 + sa * 6.28
            local j = #ring
            ring[j + 1], ring[j + 2], ring[j + 3] = h1, h2, h3
            ring[j + 4], ring[j + 5] = math.cos(a), math.sin(a)
        end
        local m = math.floor(2 + 6 * E * frac(sa * 4.9) + 0.5)
        for k = 1, m do
            local h1 = frac(sb * 13.3 + k * 0.6180339887)
            local h2 = frac(sa * 19.9 + k * 0.3819660113)
            local a = h1 * math.pi * 2.0
            local j = #satellites
            satellites[j + 1], satellites[j + 2] = h2, math.cos(a)
            satellites[j + 3] = math.sin(a)
        end
        pieces = { ring = ring, satellites = satellites,
            ringCount = n, satelliteCount = m,
            centreCos = math.cos(sa * 6.28),
            centreSin = math.sin(sa * 6.28),
            centreAspect = 0.88 + 0.12 * frac(sb * 2.9) }
        origin.splashPieces = pieces
    end
    local amp0 = ampScale or 1.0
    t = math.max(0.0, math.min(1.0, t))
    local s = 1.0 - (1.0 - t) * (1.0 - t)
    local Rp = Rf * (1.0 + r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SPREAD * E * s)
    local count = 0
    -- Pressed centre: flattens (lower dome), then drops below threshold.
    local ac = (1.0 - sstep(0.05, r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_HOLLOW_AT,
        t)) * (1.0 - 0.45 * s)
    if ac > 0.02 then
        quad(x * scale, y * scale, Rp * 0.80 * scale,
            Rp * 0.80 * pieces.centreAspect * scale,
            pieces.centreCos, pieces.centreSin, Rp / 32.0, 0.5 * E,
            ac * amp0)
        count = count + 1
    end
    -- Rim ring, then break-up.
    local ringOn = sstep(0.0, 0.18, t)
    local breakAt = r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_BREAK_AT
    local brk = math.max(0.0, math.min(1.0, (t - breakAt)
        / math.max(1.0 - breakAt, 1e-3)))
    local ring = pieces.ring
    for k = 1, pieces.ringCount do
        local j = (k - 1) * 5
        local h1, h2, h3 = ring[j + 1], ring[j + 2], ring[j + 3]
        -- Pieces vanish one by one while the ring breaks up.
        if h3 >= brk * 0.6 then
            local ca, sn = ring[j + 4], ring[j + 5]
            local d = Rp * (0.88 + 0.24 * h2) + Rf
                * r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SCATTER * E * brk
                * (0.4 + h2)
            local rr = math.max(minKernel, Rf * (0.30 + 0.18 * h1)
                * (1.0 - 0.55 * brk) * (0.8 + 0.4 * E))
            -- Intact ring: stretched along the rim; broken: round beads.
            local along = rr * (1.0 + (0.8 + 0.6 * h2) * (1.0 - brk))
            quad((x + ca * d) * scale, (y + sn * d) * scale, along * scale,
                rr * scale, -sn, ca, rr / 32.0, 1.0, ringOn * amp0)
            count = count + 1
        end
    end
    -- Satellites thrown beyond the rim.
    if t > 0.25 then
        local fly = (t - 0.25) / 0.75
        local satellites = pieces.satellites
        for k = 1, pieces.satelliteCount do
            local j = (k - 1) * 3
            local h2 = satellites[j + 1]
            local d = Rp * (1.05 + 0.9 * h2 * fly)
            local rr = math.max(minKernel, Rf * (0.08 + 0.14 * h2))
            quad((x + satellites[j + 2] * d) * scale,
                (y + satellites[j + 3] * d) * scale,
                rr * scale, rr * scale, 1.0, 0.0, rr / 32.0, 1.0, amp0)
            count = count + 1
        end
    end
    return count
end

-- R1.4 only needs impact lifecycle metadata. Avoid body geometry, velocity
-- normalization, kernel setup and per-life seeds for ineligible GPU drops.
rainDynamicSceneCopyState.waterFieldCollectGpuSplash = function(state, stamps,
    size)
    local r = cfg.RUNTIME
    local origins = state.tearOrigin or {}
    local overrides = state.gpuOverrides or {}
    local splashes = state.gpuSplashList or {}
    state.tearOrigin = origins
    state.gpuOverrides = overrides
    state.gpuSplashList = splashes
    local tearing = 0
    if not r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_V2 then
        state.waterFieldKernels = 0
        state.waterFieldTearHeads = 0
        return
    end
    local car = ac.getCar(0)
    local kmh = car and car.speedKmh or 0.0
    local tearMin = r.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KMH
    local speedAmount = math.max(0.0, math.min(1.0,
        (kmh - tearMin) / math.max(
            r.RAIN_DYNAMIC_WATER_FIELD_TEAR_FULL_KMH - tearMin, 1.0)))
    local speedShare = math.max(0.0, math.min(1.0,
        r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SPEED_SHARE or 1.0))
    local heavyMin = math.min(r.RAIN_GPU_SIZE_MIN_HEAVY,
        r.RAIN_GPU_SIZE_MAX_HEAVY)
    local heavyMax = math.max(r.RAIN_GPU_SIZE_MIN_HEAVY,
        r.RAIN_GPU_SIZE_MAX_HEAVY)
    local sizeThresholdMM = heavyMin + (heavyMax - heavyMin)
        * math.max(0.0, math.min(100.0,
            r.RAIN_DYNAMIC_WATER_FIELD_TEAR_HEAVY_SIZE_PERCENT)) * 0.01
    local uvPerMM = math.max(r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM,
        0.000001)
    local clock = rainDynamicStateRenderClock
    for i = 1, #stamps do
        local stamp = stamps[i]
        local R = stamp.radius or 0.0
        if R > 0.25 then
            local index = stamp.index
            local birthAt = state.birthSeenAt and state.birthSeenAt[index]
            local age = birthAt and clock - birthAt
            if age and age >= 0.0 then
                local generation = state.generation
                    and state.generation[index] or 0
                local origin = origins[index]
                if not (origin and origin.generation == generation) then
                    origin = nil
                    local radiusUV = rainDynamicStateRadius[index] or 0.0
                    local diameterMM = radiusUV * 2.0 / uvPerMM
                    local sizeAmount = 0.0
                    if diameterMM >= sizeThresholdMM then
                        sizeAmount = 0.35 + 0.65 * math.max(0.0,
                            math.min(1.0, (diameterMM - sizeThresholdMM)
                                / math.max(heavyMax - sizeThresholdMM,
                                    0.000001)))
                    end
                    local speedSelected = speedAmount > 0.0
                        and rainDynamicSurfaceFrac(index * 0.438579
                            + generation * 0.913247) < speedShare
                    local amount = math.max(
                        speedSelected and speedAmount or 0.0, sizeAmount)
                    if amount > 0.0 then
                        local Rf = math.max(R, radiusUV * size)
                        local sizeF = math.min(1.0, Rf / math.max(
                            r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SIZE_REF, 0.5))
                        origin = { generation = generation, x = stamp.x,
                            y = stamp.y, radius = Rf,
                            seedA = rainDynamicSurfaceFrac(index * 0.7548776662
                                + generation * 0.5698402911),
                            seedB = rainDynamicSurfaceFrac(index * 0.6180339887
                                + generation * 0.4142135623),
                            amount = amount,
                            energy = amount * (0.55 + 0.45 * sizeF),
                            duration = math.max(0.05,
                                r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SECONDS
                                * (0.6 + 0.8 * sizeF)),
                            stage = 0, inked = false }
                        origins[index] = origin
                    end
                end
                if origin then
                    local st = age / origin.duration
                    local bodyAmp = 1.0
                    local splashScale = 1.0
                    if st < 1.0 then
                        splashes[#splashes + 1] = { index, origin.x,
                            origin.y, origin.radius, origin.energy,
                            st, generation }
                        local back = math.max(0.0,
                            math.min(1.0, (st - 0.7) / 0.3))
                        bodyAmp = back * back * (3.0 - 2.0 * back)
                        splashScale = r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_RESIDUAL
                        tearing = tearing + 1
                    elseif not origin.inked then
                        origin.inked = true
                        if r.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED then
                            state.pendingSplash = state.pendingSplash or {}
                            state.pendingSplash[#state.pendingSplash + 1] =
                                { origin = origin, v2 = true }
                        end
                    end
                    if age < origin.duration * 3.0 then
                        splashScale = splashScale + (1.0 - splashScale)
                            * math.max(0.0, math.min(1.0,
                                (st - 1.0) / 2.0))
                    end
                    if bodyAmp < 0.999
                        or math.abs(splashScale - 1.0) > 1e-3 then
                        overrides[#overrides + 1] =
                            { index, bodyAmp, splashScale }
                    end
                end
            end
        end
    end
    state.waterFieldKernels = 0
    state.waterFieldTearHeads = tearing
end

-- Draws every head stamp as soft kernels. Called inside canvas:update().
rainDynamicSceneCopyState.waterFieldDrawStamps = function(state, stamps,
    size, sim)
    local kernel = state.waterKernel(state)
    local ks = math.max(1.0, cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_KERNEL_SCALE)
    local q1, q2, q3, q4 = vec2(), vec2(), vec2(), vec2()
    local color = rgbm(0.0, 1.0, 0.0, 1.0)
    -- Body amplitude of the current stamp (0 while its splash is hollow).
    local bodyAmp = 1.0
    local function kernelQuad(cx, cy, rx, ry, ux, uy, code, energy, amp)
        local ax, ay = rx * ks, ry * ks
        local vx, vy = -uy, ux
        q1.x, q1.y = cx - ux * ax - vx * ay, cy - uy * ax - vy * ay
        q2.x, q2.y = cx + ux * ax - vx * ay, cy + uy * ax - vy * ay
        q3.x, q3.y = cx + ux * ax + vx * ay, cy + uy * ax + vy * ay
        q4.x, q4.y = cx - ux * ax + vx * ay, cy - uy * ax + vy * ay
        color.r = math.min(code, 1.0)
        color.g = 1.0
        color.b = energy
        color.mult = amp or bodyAmp
        if color.mult > 0.005 then
            ui.drawImageQuad(kernel, q1, q2, q3, q4, color)
        end
    end
    local lobes = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_LOBES
    local splashV2 = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_V2
    local speedShare = math.max(0.0, math.min(1.0,
        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SPEED_SHARE or 1.0))
    local stretchGain = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_MOTION_STRETCH
    local car = ac.getCar(0)
    local kmh = car and car.speedKmh or 0.0
    local tearMin = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KMH
    local speedAmount = math.max(0.0, math.min(1.0, (kmh - tearMin) / math.max(
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_FULL_KMH - tearMin,
            1.0)))
    local heavyMin = math.min(cfg.RUNTIME.RAIN_GPU_SIZE_MIN_HEAVY,
        cfg.RUNTIME.RAIN_GPU_SIZE_MAX_HEAVY)
    local heavyMax = math.max(cfg.RUNTIME.RAIN_GPU_SIZE_MIN_HEAVY,
        cfg.RUNTIME.RAIN_GPU_SIZE_MAX_HEAVY)
    local heavyPercent = math.max(0.0, math.min(100.0,
        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_HEAVY_SIZE_PERCENT))
    local sizeThresholdMM = heavyMin
        + (heavyMax - heavyMin) * heavyPercent * 0.01
    local tearMinKernel = math.max(0.5,
        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS)
    local drawn = 0
    local tearing = 0
    -- R1.1: in GPU-heads mode the body/tail/lobe/puddle kernels come from
    -- the GPU pass; only splash/tear pieces are drawn here.
    local gpu = state.gpuHeadsActive
    local gpuSplash = gpu and cfg.RUNTIME.RAIN_GPU_SPLASH
    state.gpuOverrides = gpu and (state.gpuOverrides or {}) or state.gpuOverrides
    state.gpuSplashList = gpuSplash and (state.gpuSplashList or {}) or state.gpuSplashList
    local function bq(...)
        if not gpu then kernelQuad(...) end
    end
    for _, stamp in ipairs(stamps) do
        local R = stamp.radius or 0.0
        if R > 0.25 then
            local index = stamp.index
            local code = R / 32.0
            local vu = rainDynamicStateVelocityU[index] or 0.0
            local vv = rainDynamicStateVelocityV[index] or 0.0
            local speed = math.sqrt(vu * vu + vv * vv)
            local ux, uy = 1.0, 0.0
            if speed > 1e-6 then ux, uy = vu / speed, vv / speed end
            local generation = state.generation
                and state.generation[index] or 0
            local seedA = rainDynamicSurfaceFrac(index * 0.7548776662
                + generation * 0.5698402911)
            local seedB = rainDynamicSurfaceFrac(index * 0.6180339887
                + generation * 0.4142135623)
            if speed <= 1e-6 then
                local angle = seedA * math.pi
                ux, uy = math.cos(angle), math.sin(angle)
            end
            -- Impact splash v2: animated at the frozen impact point. While
            -- it runs, the body is hidden (hollow centre) and comes back as
            -- a smaller residual drop at the end.
            bodyAmp = 1.0
            local splashScale = 1.0
            local birthAt2 = state.birthSeenAt and state.birthSeenAt[index]
            local age2 = birthAt2 and rainDynamicStateRenderClock - birthAt2
            local diameterMM = (rainDynamicStateRadius[index] or 0.0) * 2.0
                / math.max(cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM,
                    0.000001)
            local sizeEligible = diameterMM >= sizeThresholdMM
            local sizeAmount = sizeEligible and (0.35 + 0.65
                * math.max(0.0, math.min(1.0,
                    (diameterMM - sizeThresholdMM)
                    / math.max(heavyMax - sizeThresholdMM, 0.000001)))) or 0.0
            -- Thin speed-only splashes by a stable per-life hash. A large
            -- drop still qualifies at any speed; 1.0 restores the old load.
            local speedSelected = rainDynamicSurfaceFrac(index * 0.438579
                + generation * 0.913247) < speedShare
            local impactAmount = math.max(
                speedSelected and speedAmount or 0.0, sizeAmount)
            local origin = state.tearOrigin and state.tearOrigin[index]
            local activeOrigin = origin and origin.generation == generation
            if splashV2 and age2 and age2 >= 0.0
                and (impactAmount > 0.0 or activeOrigin) then
                state.tearOrigin = state.tearOrigin or {}
                if not activeOrigin then
                    local Rf = math.max(R,
                        (rainDynamicStateRadius[index] or 0.0) * size)
                    local sizeF = math.min(1.0, Rf / math.max(
                        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SIZE_REF,
                        0.5))
                    origin = { generation = generation, x = stamp.x,
                        y = stamp.y, radius = Rf, seedA = seedA,
                        seedB = seedB, amount = impactAmount,
                        energy = impactAmount * (0.55 + 0.45 * sizeF),
                        duration = math.max(0.05,
                            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SECONDS
                            * (0.6 + 0.8 * sizeF)),
                        stage = 0, inked = false }
                    state.tearOrigin[index] = origin
                end
                local st = age2 / origin.duration
                if st < 1.0 then
                    if gpuSplash then
                        state.gpuSplashList[#state.gpuSplashList + 1] =
                            { index, origin.x, origin.y, origin.radius,
                                origin.energy, st, generation }
                    else
                        drawn = drawn + state.waterFieldSplashV2(kernelQuad,
                            origin, 1.0, st, tearMinKernel, 1.0)
                    end
                    local back = math.max(0.0, math.min(1.0, (st - 0.7) / 0.3))
                    bodyAmp = back * back * (3.0 - 2.0 * back)
                    splashScale = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_RESIDUAL
                    tearing = tearing + 1
                elseif not origin.inked then
                    -- Leave the scattered beads in the persistent trail.
                    origin.inked = true
                    if cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED then
                        state.pendingSplash = state.pendingSplash or {}
                        state.pendingSplash[#state.pendingSplash + 1] =
                            { origin = origin, v2 = true }
                    end
                end
                if age2 < origin.duration * 3.0 then
                    -- The residual drop grows back to full size slowly.
                    splashScale = splashScale + (1.0 - splashScale)
                        * math.max(0.0, math.min(1.0,
                            (age2 / origin.duration - 1.0) / 2.0))
                else
                    splashScale = 1.0
                end
            end
            if gpu and (bodyAmp < 0.999 or math.abs(splashScale - 1.0) > 1e-3) then
                state.gpuOverrides[#state.gpuOverrides + 1] = { index, bodyAmp, splashScale }
            end
            -- The GPU pass owns these kernels. Do not calculate their
            -- per-drop geometry on the CPU when it is active.
            if not gpu then
            R = R * splashScale
            -- Body: mild stretch along motion, radius-relative.
            local stretch = math.min(0.6, speed * stretchGain
                / math.max(R / size, 1e-6) * 0.05)
            bq(stamp.x, stamp.y, R * (1.0 + 0.6 * stretch),
                R * (1.0 - 0.25 * stretch), ux, uy, code, 0.0)
            drawn = drawn + 1
            -- Tapered tail: two shrinking kernels toward the tail point.
            if stamp.tailX then
                for k = 1, 2 do
                    local t = k * 0.4
                    bq(stamp.x + (stamp.tailX - stamp.x) * t,
                        stamp.y + (stamp.tailY - stamp.y) * t,
                        R * (0.85 - 0.3 * t), R * (0.85 - 0.3 * t),
                        ux, uy, code, 0.0)
                end
                drawn = drawn + 2
            end
            -- Existing per-life lobe and puddle circles become kernels.
            if stamp.lobeX then
                bq(stamp.lobeX, stamp.lobeY, stamp.lobeRadius,
                    stamp.lobeRadius, ux, uy, stamp.lobeRadius / 32.0, 0.0)
                drawn = drawn + 1
            end
            if stamp.puddleX then
                bq(stamp.puddleX, stamp.puddleY, stamp.puddleRadius,
                    stamp.puddleRadius, ux, uy, stamp.puddleRadius / 32.0, 0.0)
                bq(stamp.puddle2X, stamp.puddle2Y,
                    stamp.puddle2Radius, stamp.puddle2Radius, ux, uy,
                    stamp.puddle2Radius / 32.0, 0.0)
                drawn = drawn + 2
            end
            -- Stable per-life irregular outline: 0-2 offset kernels.
            if lobes and R >= 2.0 then
                local count = R >= 4.0 and 2 or 1
                for k = 1, count do
                    local a = (seedA + k * 0.37) * math.pi * 2.0
                    local d = R * (0.25 + 0.30 * rainDynamicSurfaceFrac(
                        seedB * 7.13 + k * 0.29))
                    local rr = R * (0.45 + 0.30 * rainDynamicSurfaceFrac(
                        seedA * 5.71 + k * 0.53))
                    bq(stamp.x + math.cos(a) * d,
                        stamp.y + math.sin(a) * d, rr, rr, ux, uy,
                        R / 32.0, 0.0)
                end
                drawn = drawn + count
            end
            end
        end
    end
    state.waterFieldKernels = drawn
    state.waterFieldTearHeads = tearing
end

-- Continuous water influx; spatial occupancy shapes the source, not its mass.
rainDynamicSceneCopyState.waterFieldUpdateImpactSheet = function(state,
    stamps, headSize, sim)
    if not cfg.RUNTIME.RAIN_DYNAMIC_IMPACT_SHEET_ENABLED then
        if state.impactSheetReady then
            state.impactSheetA:clear(rgbm.colors.transparent)
            state.impactSheetB:clear(rgbm.colors.transparent)
        end
        state.impactSheetReady = false
        state.impactFlux = 0.0
        state.impactFeed = 0.0
        state.impactGridAt = nil
        return false
    end
    local size = 512
    if not state.impactSheetA then
        state.impactSheetA = ui.ExtraCanvas(vec2(size, size), 1,
            render.TextureFormat.R16G16B16A16.Float)
            :setName('RainFX impact film A')
        state.impactSheetB = ui.ExtraCanvas(vec2(size, size), 1,
            render.TextureFormat.R16G16B16A16.Float)
            :setName('RainFX impact film B')
        state.impactSheetA:clear(rgbm.colors.transparent)
        state.impactSheetB:clear(rgbm.colors.transparent)
        state.impactSheetRead = state.impactSheetA
    end
    if not state.impactSource then
        state.impactSource = ui.ExtraCanvas(vec2(8, 8), 1,
            render.TextureFormat.R16G16B16A16.Float)
            :setName('RainFX film source distribution')
    end
    local dt = math.min(math.max(sim.dt or 0.0, 0.0), 0.05)
    local rain = math.max(0.0, math.min(1.0,
        cfg.RUNTIME.RAIN_GPU_STATE_RAIN_OVERRIDE >= 0.0
            and cfg.RUNTIME.RAIN_GPU_STATE_RAIN_OVERRIDE
            or sim.rainIntensity or 0.0))
    -- Relative air projected onto the visor-facing direction. The scalar
    -- speed magnitude alone would incorrectly count tail/side winds.
    local car = ac.getCar(0)
    local wx, wz = state.windWorldMS(state, sim)
    local look = sim.cameraLook
    local frontal = 0.0
    if car and car.velocity and look then
        frontal = math.max(0.0, (car.velocity.x - wx) * look.x
            + car.velocity.y * look.y + (car.velocity.z - wz) * look.z) * 3.6
    end
    -- Provisional dimensionless curve, not calibrated meteorological units.
    local flux = rain * rain * rain + rain * frontal / 180.0
    local targetFeed = math.max(0.0,
        flux - cfg.RUNTIME.RAIN_DYNAMIC_IMPACT_SHEET_FLUX_START)
        * cfg.RUNTIME.RAIN_DYNAMIC_IMPACT_SHEET_FEED
    state.impactFeed = (state.impactFeed or 0.0)
        + (targetFeed - (state.impactFeed or 0.0))
            * (1.0 - math.exp(-dt / 0.25))
    state.impactFlux, state.impactFrontal = flux, frontal
    -- All sizes participate. Normalize occupancy by total live samples so
    -- changing 2048 to 4096 slots cannot double the film water supply.
    if not state.impactGridAt
        or rainDynamicStateRenderClock - state.impactGridAt >= 0.10 then
        local cells = {}
        local total = 0
        for _, stamp in ipairs(stamps) do
            local x = math.max(0, math.min(7,
                math.floor(stamp.x / headSize * 8)))
            local y = math.max(0, math.min(7,
                math.floor(stamp.y / headSize * 8)))
            local key = y * 8 + x + 1
            cells[key] = (cells[key] or 0) + 1
            total = total + 1
        end
        state.impactSource:clear(rgbm.colors.transparent)
        state.impactSource:update(function()
            for key = 1, 64 do
                local x, y = (key - 1) % 8, math.floor((key - 1) / 8)
                local density = total > 0 and (cells[key] or 0) * 64 / total or 0.0
                ui.drawRectFilled(vec2(x, y), vec2(x + 1, y + 1),
                    rgbm(density, density, density, 1.0))
            end
        end)
        state.impactGridAt = rainDynamicStateRenderClock
        state.impactSourceCount = total
    end
    local source = state.impactSheetRead
    local target = source == state.impactSheetA
        and state.impactSheetB or state.impactSheetA
    local flowU = math.max(-0.25, math.min(0.25, state.flowU or 0.0))
    local flowV = math.max(-0.25, math.min(0.25, state.flowV or 0.0))
    local copied = target:updateWithShader({
        async = true,
        blendMode = render.BlendMode.Opaque,
        textures = {
            txImpactPrevious = source,
            txImpactSource = state.impactSource,
            txImpactBoundary = textureRainBoundaryMask,
        },
        values = {
            gImpactStep = vec2(flowU * dt, flowV * dt),
            gImpactFeed = state.impactFeed * dt,
            gImpactDecay = math.exp(-dt * 1.05 / math.max(
                cfg.RUNTIME.RAIN_DYNAMIC_IMPACT_SHEET_SECONDS, 0.05)),
            gImpactTexel = 1.0 / size,
        },
        shader = [[
            float4 main(PS_IN pin)
            {
                float2 uv = pin.Tex - gImpactStep;
                float4 centre = txImpactPrevious.SampleLevel(samLinearClamp, uv, 0.0);
                float4 side = txImpactPrevious.SampleLevel(samLinearClamp,
                    uv + float2(gImpactTexel, 0.0), 0.0)
                    + txImpactPrevious.SampleLevel(samLinearClamp,
                    uv - float2(gImpactTexel, 0.0), 0.0);
                float oldHeight = lerp(centre.g, side.g * 0.5, 0.035) * gImpactDecay;
                float density = txImpactSource.SampleLevel(samLinearClamp, pin.Tex, 0.0).r;
                // Fixed spatial source variation avoids re-randomizing the
                // water input every frame. Smooth influx avoids patch pops.
                float variation = 0.65 + 0.35 * sin(pin.Tex.x * 83.0
                    + sin(pin.Tex.y * 51.0) * 2.0);
                float height = min(32.0, oldHeight + gImpactFeed * density * variation);
                // Film canvas already encodes signed visor V as V+1.
                // Clamp sampling negative raw V would read the all-zero
                // top border of the boundary mask and erase every texel.
                float boundary = txImpactBoundary.SampleLevel(samLinearClamp,
                    pin.Tex, 0.0).r;
                height *= smoothstep(0.45, 0.55, boundary);
                return float4(height * 0.75, height, height, height);
            }
        ]],
    })
    if copied == false then
        state.impactSheetReady = false
        return false
    end
    state.impactSheetRead = target
    state.impactSheetReady = true
    state.impactSheetError = nil
    return true
end
-- Rendering-only film underlay. The persistent trail remains a pure flow
-- field for its own decay and for GPU wet-path steering.
rainDynamicSceneCopyState.waterFieldCompositeImpact = function(state)
    state.waterTrailComposite = nil
    if not state.impactSheetReady then return end
    local size = state.waterTrailSize
    if not state.impactComposite or state.impactCompositeSize ~= size then
        if state.impactComposite then state.impactComposite:dispose() end
        state.impactComposite = ui.ExtraCanvas(vec2(size, size), 1,
            render.TextureFormat.R16G16B16A16.Float)
            :setName('RainFX trail and film render composite')
        state.impactCompositeSize = size
    end
    local ready = state.impactComposite:updateWithShader({
        async = true,
        blendMode = render.BlendMode.Opaque,
        textures = {
            txPureTrail = state.waterTrailRead,
            txLocalFilm = state.impactSheetRead,
        },
        shader = [[
            float4 main(PS_IN pin)
            {
                float4 trail = txPureTrail.SampleLevel(samLinearClamp, pin.Tex, 0.0);
                float height = txLocalFilm.SampleLevel(samLinearClamp, pin.Tex, 0.0).g;
                // Soft compression preserves film variation at high influx.
                float film = 0.75 * height / (1.0 + height);
                // Alpha stores the unmodified trail profile for refraction.
                return float4(trail.r + film * 0.75,
                    trail.g + film, trail.b + film, trail.g);
            }
        ]],
    })
    if ready ~= false then state.waterTrailComposite = state.impactComposite end
end

-- Persistent, noisily decaying trail canvas (thinner copies of moving heads).
rainDynamicSceneCopyState.waterFieldUpdateTrail = function(state, stamps,
    headSize, sim)
    if not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED then
        state.waterTrailReady = false
        return
    end
    local impactStart = cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0
    local impactOk, impactErr = pcall(state.waterFieldUpdateImpactSheet,
        state, stamps, headSize, sim)
    if not impactOk then
        state.impactSheetReady = false
        state.impactSheetError = tostring(impactErr)
        cfg.RUNTIME.RAIN_DYNAMIC_IMPACT_SHEET_ENABLED = false
        ac.warn(appNameDebug .. ' Impact film disabled: '
            .. state.impactSheetError)
    end
    state.profImpactSheetMs = ((cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0) - impactStart) * 1000.0
    local size = math.max(128, math.floor(
        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_SIZE))
    if not state.waterTrailA or state.waterTrailSize ~= size then
        if state.waterTrailA then state.waterTrailA:dispose() end
        if state.waterTrailB then state.waterTrailB:dispose() end
        state.waterTrailA = ui.ExtraCanvas(vec2(size, size), 1,
            render.TextureFormat.R16G16B16A16.Float)
            :setName('RainFX water trail A')
        state.waterTrailB = ui.ExtraCanvas(vec2(size, size), 1,
            render.TextureFormat.R16G16B16A16.Float)
            :setName('RainFX water trail B')
        state.waterTrailA:clear(rgbm.colors.transparent)
        state.waterTrailB:clear(rgbm.colors.transparent)
        state.waterTrailRead = state.waterTrailA
        state.waterTrailSize = size
    end
    local source = state.waterTrailRead
    local target = source == state.waterTrailA
        and state.waterTrailB or state.waterTrailA
    local seconds = math.max(
        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_SECONDS, 0.05)
    -- ln(1 / threshold) ~ 1.05: a full-height texel crosses the
    -- silhouette threshold after about `seconds`.
    local decay = math.exp(-math.min(math.max(sim.dt or 0.0, 0.0), 0.05)
        * 1.05 / seconds)
    local copied = target:updateWithShader({
        async = true,
        blendMode = render.BlendMode.Opaque,
        textures = {
            txTrailPrevious = source,
        },
        values = {
            gTrailTexel = 1.0 / size,
            -- 0.25 is the stability limit of the explicit 4-tap step.
            gTrailDiffuse = math.max(0.0, math.min(0.25,
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_DIFFUSE)),
            gTrailDecay = decay,
            gTrailSheetPersist =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_PERSIST,
            gTrailNoise = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_NOISE,
            gTrailNoiseCells =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_NOISE_CELLS,
        },
        shader = [[
            float trailHash(float2 p)
            {
                p = frac(p * float2(123.34, 456.21));
                p += dot(p, p + 45.32);
                return frac(p.x * p.y);
            }
            float trailNoise(float2 x)
            {
                float2 i = floor(x);
                float2 f = frac(x);
                f = f * f * (3.0 - 2.0 * f);
                float a = trailHash(i);
                float b = trailHash(i + float2(1.0, 0.0));
                float c = trailHash(i + float2(0.0, 1.0));
                float d = trailHash(i + float2(1.0, 1.0));
                return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
            }
            float4 main(PS_IN pin)
            {
                float4 previous = txTrailPrevious.SampleLevel(
                    samLinearClamp, pin.Tex, 0.0);
                // Surface-tension levelling: all channels diffuse together,
                // so the R/G and B/G ratio codes are preserved.
                float4 around = txTrailPrevious.SampleLevel(samLinearClamp,
                        pin.Tex + float2(gTrailTexel, 0.0), 0.0)
                    + txTrailPrevious.SampleLevel(samLinearClamp,
                        pin.Tex - float2(gTrailTexel, 0.0), 0.0)
                    + txTrailPrevious.SampleLevel(samLinearClamp,
                        pin.Tex + float2(0.0, gTrailTexel), 0.0)
                    + txTrailPrevious.SampleLevel(samLinearClamp,
                        pin.Tex - float2(0.0, gTrailTexel), 0.0);
                previous += (around * 0.25 - previous) * (4.0 * gTrailDiffuse);
                // Spatially varying decay: thinning tracks break into
                // beads where the noise keeps water longer.
                float n = trailNoise(pin.Tex * gTrailNoiseCells);
                // Sheet water (B/G) thins smoothly and lasts longer.
                float sheet = saturate(previous.b / max(previous.g, 1e-3));
                float k = pow(gTrailDecay,
                    max(0.05, (1.0 + gTrailNoise * (1.0 - sheet)
                        * (n * 2.0 - 1.0))
                        * (1.0 - gTrailSheetPersist * sheet)));
                float4 next = previous * k;
                return next.g < 0.02 ? float4(0.0, 0.0, 0.0, 0.0) : next;
            }
        ]]
    })
    if copied == false then return end
    state.waterTrailRead = target
    state.waterTrailReady = true
    local scale = size / math.max(headSize, 1)
    local minSpeed = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_MIN_SPEED
    local width = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_WIDTH
    local kernel = state.waterKernel(state)
    local ribbon = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_RIBBON
        and state.waterRibbonKernel(state) or nil
    local ks = math.max(1.0, cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_KERNEL_SCALE)
    local p1, p2 = vec2(), vec2()
    local q1, q2, q3, q4 = vec2(), vec2(), vec2(), vec2()
    local color = rgbm(0.0, 1.0, 0.0, 1.0)
    local function trailQuad(cx, cy, rx, ry, ux, uy, code, energy, amp)
        local ax, ay = rx * ks, ry * ks
        local vx, vy = -uy, ux
        q1.x, q1.y = cx - ux * ax - vx * ay, cy - uy * ax - vy * ay
        q2.x, q2.y = cx + ux * ax - vx * ay, cy + uy * ax - vy * ay
        q3.x, q3.y = cx + ux * ax + vx * ay, cy + uy * ax + vy * ay
        q4.x, q4.y = cx - ux * ax + vx * ay, cy - uy * ax + vy * ay
        color.r = math.min(code, 1.0)
        color.g = 1.0
        color.b = energy
        if amp then color.mult = amp end
        ui.drawImageQuad(kernel, q1, q2, q3, q4, color)
    end
    local splashSheet = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SHEET
    local function splashQuad(cx, cy, rx, ry, ux, uy, code, energy, amp)
        trailQuad(cx, cy, rx, ry, ux, uy, code, energy * splashSheet,
            amp or 1.0)
    end
    local sheetOn = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_ENABLED
    local sheetStart = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_START_SPEED
    local sheetSpan = math.max(
        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_FULL_SPEED - sheetStart,
        1e-5)
    -- Disabled density branch contributes zero to the OR, leaving speed only.
    local sheetDensity = 0.0
    if cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_GATE then
        local dmin = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_MIN
        sheetDensity = math.max(0.0, math.min(1.0,
            ((state.smearDensity or 0.0) - dmin) / math.max(
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_FULL - dmin,
                1e-3)))
    end
    state.waterSheetDensity = sheetDensity
    state.waterSheetSamples = #stamps
    state.waterSheetRadiusPassed = 0
    state.waterSheetSpeedPassed = 0
    state.waterSheetTriggerPassed = 0
    state.waterSheetMaxFactor = 0.0
    local widen = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_WIDEN
    local thin = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_THIN
    state.waterTrailLastX = state.waterTrailLastX or {}
    state.waterTrailLastY = state.waterTrailLastY or {}
    state.waterTrailLastGen = state.waterTrailLastGen or {}
    local lastX, lastY = state.waterTrailLastX, state.waterTrailLastY
    local lastGen = state.waterTrailLastGen
    local maxSpeed = 0.0
    local sheets = 0
    local trails = 0
    local pending = state.pendingSplash
    state.pendingSplash = nil
    local tearMinKernel = math.max(0.5,
        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS)
    target:update(function()
        -- One-shot torn splashes at their impact origin.
        if pending then
            for _, item in ipairs(pending) do
                -- Minimum piece size is enforced in trail texels.
                if item.v2 then
                    -- Final scattered beads only (no centre, broken rim).
                    trails = trails + state.waterFieldSplashV2(splashQuad,
                        item.origin, scale, 1.0,
                        tearMinKernel / math.max(scale, 0.05), 0.85)
                end
            end
            color.mult = 1.0
        end
        for _, stamp in ipairs(stamps) do
            local index = stamp.index
            local vu = rainDynamicStateVelocityU[index] or 0.0
            local vv = rainDynamicStateVelocityV[index] or 0.0
            local speed = math.sqrt(vu * vu + vv * vv)
            local R = stamp.radius or 0.0
            maxSpeed = math.max(maxSpeed, speed)
            -- Either speed or density can create a sheet; use the stronger
            -- ramp without doubling the amplitude when both qualify.
            local fast = sheetOn and math.max(sheetDensity,
                math.max(0.0, math.min(1.0,
                    (speed - sheetStart) / sheetSpan))) or 0.0
            if cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING
                and R > math.max(cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_MIN_RADIUS, 0.0) then
                state.waterSheetRadiusPassed = state.waterSheetRadiusPassed + 1
                if speed >= minSpeed and speed > 1e-6 then
                    if speed > sheetStart then
                        state.waterSheetSpeedPassed = state.waterSheetSpeedPassed + 1
                    end
                    if fast > 0.0 then
                        state.waterSheetTriggerPassed = state.waterSheetTriggerPassed + 1
                        state.waterSheetMaxFactor = math.max(state.waterSheetMaxFactor, fast)
                    end
                end
            end
            local generation = state.generation
                and state.generation[index] or 0
            if speed >= minSpeed and speed > 1e-6
                and R > math.max(cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_MIN_RADIUS, 0.0) and fast > 0.0 then
                -- Fast flow: a wide, flat, continuous sheet segment from
                -- the previous trail point to just behind the head.
                local back = R * math.max(cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_HEAD_BACK, 0.0) / speed
                local x = (stamp.x - vu * back) * scale
                local y = (stamp.y - vv * back) * scale
                -- Trigger ramps decide whether to stamp; both paths use
                -- the same cross-section instead of trigger-dependent geometry.
                local form = math.max(0.0, math.min(1.0,
                    cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_FORM))
                local rr = R * width * (1.0 + widen * form)
                local fx, fy = x, y
                if lastGen[index] == generation and lastX[index] then
                    local dx, dy = x - lastX[index], y - lastY[index]
                    -- Ignore teleports (respawn / readback jumps).
                    if dx * dx + dy * dy < math.max(
                        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_LINK_RADII * R * scale,
                        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_LINK_MIN_TEXELS, 0.0) ^ 2 then
                        fx, fy = lastX[index], lastY[index]
                    end
                end
                local sx, sy = x - fx, y - fy
                local len = math.sqrt(sx * sx + sy * sy)
                local ux, uy = 1.0, 0.0
                if len > 1e-4 then ux, uy = sx / len, sy / len end
                -- Keep sheet height above the configurable visibility floor.
                -- Aggressive thinning otherwise hides isolated sheets below
                -- the WF threshold, leaving only overlapping slow trails.
                color.mult = math.max(1.0 - thin * form,
                    math.max(0.0, math.min(1.0,
                        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_HEIGHT_MIN)))
                if ribbon then
                    -- Exact segment previous -> current point (no along
                    -- taper), plus a round cap only where the path starts.
                    local hw = rr * scale * ks
                    local vx, vy = -uy, ux
                    q1.x, q1.y = fx - vx * hw, fy - vy * hw
                    q2.x, q2.y = x - vx * hw, y - vy * hw
                    q3.x, q3.y = x + vx * hw, y + vy * hw
                    q4.x, q4.y = fx + vx * hw, fy + vy * hw
                    color.r = math.min(rr / 32.0, 1.0)
                    color.g = 1.0
                    color.b = form
                    if len > 1e-3 then
                        ui.drawImageQuad(ribbon, q1, q2, q3, q4, color)
                    end
                    if fx == x and fy == y then
                        trailQuad(x, y, rr * scale, rr * scale,
                            ux, uy, rr / 32.0, form)
                    end
                else
                    local ax = (len * 0.5 / ks + rr * scale)
                    trailQuad((x + fx) * 0.5, (y + fy) * 0.5, ax, rr * scale,
                        ux, uy, rr / 32.0, form)
                end
                color.mult = 1.0
                lastX[index], lastY[index] = x, y
                lastGen[index] = generation
                sheets = sheets + 1
                trails = trails + 1
            elseif speed >= minSpeed and speed > 1e-6
                and R > math.max(cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_MIN_RADIUS, 0.0) then
                -- Just behind the head, so the head itself stays crisp.
                local back = R * math.max(cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_HEAD_BACK, 0.0) / speed
                local x = (stamp.x - vu * back) * scale
                local y = (stamp.y - vv * back) * scale
                local r = R * width * scale * ks
                p1.x, p1.y = x - r, y - r
                p2.x, p2.y = x + r, y + r
                -- Radius code stays in head-mask texels for one decode.
                color.r = math.min(R * width / 32.0, 1.0)
                color.g = 1.0
                color.b = 0.0
                color.mult = 1.0
                ui.drawImage(kernel, p1, p2, color)
                lastX[index], lastY[index] = x, y
                lastGen[index] = generation
                trails = trails + 1
            else
                lastX[index] = nil
            end
        end
    end)
    state.waterTrailStamps = trails
    state.waterTrailSheets = sheets
    state.waterTrailMaxSpeed = maxSpeed
    state.waterFieldCompositeImpact(state)
end

-- Birth probes use a separate small canvas so their growth cannot erase the
-- validated R/G wipe and liquid-ridge channels. Only recent GPU births stamp.
-- R1.1 GPU heads (docs/RAINFX_GPU_PRELAID.md §4). Pass A: per tile, a
-- bitmask of the drops whose conservative footprint touches the tile
-- (RGBA32F, 24 exact bits per channel = 96 drops per texel). Pass B: every
-- head-canvas pixel walks its tile's bits and blends the same kernels as
-- waterFieldDrawStamps, in slot order. No list truncation, no tile seams:
-- the footprint test is conservative, so nothing is cut at tile borders.
-- (s59: shader strings live in rainDynamicSceneCopyState, not as chunk
-- locals: the main chunk is at Lua's 200-local limit.)
rainDynamicSceneCopyState.gpuHeadsCommon = [[
float rgFrac(float x) { return x - floor(x); }
bool rgDrop(int i, out float2 pos, out float R, out float2 vel,
    out float idx, out float gen, out float rUV)
{
    float4 st = txRainState.Load(int3(i, 0, 0));
    float4 me = txRainStateMeta.Load(int3(i, 0, 0));
    float packed = me.a;
    float status = packed - 4.0 * floor(packed / 4.0);
    pos = float2(st.r, st.g + 1.0) * gSize;
    vel = st.ba;
    rUV = max(me.r, 0.0);
    R = rUV * gSize;
    idx = (float)i + 1.0;          // Lua slots are 1-based (seeds)
    gen = floor(packed / 4.0);
    if (abs(status - 1.0) > 0.25) return false;
    if (st.r < 0.0 || st.r > 1.0 || st.g < -1.0 || st.g > 0.0) return false;
    return R > 0.0;
}
]]
rainDynamicSceneCopyState.gpuHeadsPassA = rainDynamicSceneCopyState.gpuHeadsCommon .. [[
// s60: one helper per channel (no dynamic l-value indexing, which forced
// an unroll of a [loop] and failed to compile: X3550 / X3531).
float rgBitsFor(int base, float2 tmin, float2 tmax)
{
    uint bits = 0u;
    [loop] for (int b = 0; b < 24; b++)
    {
        int i = base + b;
        if (i >= (int)gCount) break;
        float2 pos; float R; float2 vel; float idx; float gen; float rUV;
        if (rgDrop(i, pos, R, vel, idx, gen, rUV))
        {
            float reach = R * (gKs * 1.4 + max(gMaxRadii, max(gPuddleReach * 1.1, 0.6)) + 0.1) + 2.0;
            float2 q = clamp(pos, tmin, tmax);
            if (dot(q - pos, q - pos) <= reach * reach)
                bits |= (1u << (uint)b);
        }
    }
    return (float)bits;
}
float4 main(PS_IN pin)
{
    float xf = floor(pin.Tex.x * gMaskW);
    float tyf = floor(pin.Tex.y * gTilesY);
    float txf = floor(xf / gWords);
    float wf = xf - txf * gWords;
    float2 tmin = float2(txf, tyf) * gTile;
    float2 tmax = tmin + gTile;
    int base = (int)wf * 96;
    return float4(rgBitsFor(base, tmin, tmax),
        rgBitsFor(base + 24, tmin, tmax),
        rgBitsFor(base + 48, tmin, tmax),
        rgBitsFor(base + 72, tmin, tmax));
}
]]
-- One bit per nonempty 96-drop tile-mask word. Two summary texels cover
-- up to 192 words (18,432 slots), without dropping dense-tile candidates.
rainDynamicSceneCopyState.gpuHeadsSummaryPass = [[
float4 main(PS_IN pin)
{
    int x = (int)floor(pin.Tex.x * gSummaryW);
    int ty = (int)floor(pin.Tex.y * gTilesY);
    int tx = x / (int)gSummaryWords;
    int block = x - tx * (int)gSummaryWords;
    uint bx = 0u, by = 0u, bz = 0u, bw = 0u;
    [loop] for (int j = 0; j < 96; ++j)
    {
        int word = block * 96 + j;
        if (word >= (int)gWords) break;
        float4 m = txMask.Load(int3(tx * (int)gWords + word, ty, 0));
        if (m.x > 0.0 || m.y > 0.0 || m.z > 0.0 || m.w > 0.0)
        {
            uint bit = 1u << (uint)(j % 24);
            if (j < 24) bx |= bit;
            else if (j < 48) by |= bit;
            else if (j < 72) bz |= bit;
            else bw |= bit;
        }
    }
    return float4((float)bx, (float)by, (float)bz, (float)bw);
}
]]
rainDynamicSceneCopyState.gpuHeadsPassB = rainDynamicSceneCopyState.gpuHeadsCommon .. [[
void rgKern(float2 px, float2 c, float ax, float ay, float2 u, float code,
    float amp, inout float4 acc)
{
    ax *= gKs; ay *= gKs;
    float2 d = px - c;
    float2 v = float2(-u.y, u.x);
    float2 p = float2(dot(d, u) / max(ax, 1e-3), dot(d, v) / max(ay, 1e-3));
    float k = saturate(1.0 - dot(p, p)) * amp;
    if (k <= 0.0 || amp <= 0.005) return;
    acc.rgb = float3(min(code, 1.0), 1.0, 0.0) * k + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}
void rgEval(int i, float2 px, inout float4 acc)
{
    float2 pos; float R; float2 vel; float idx; float gen; float rUV;
    if (!rgDrop(i, pos, R, vel, idx, gen, rUV)) return;
    float speed = length(vel);
    float seedA = rgFrac(idx * 0.7548776662 + gen * 0.5698402911);
    float seedB = rgFrac(idx * 0.6180339887 + gen * 0.4142135623);
    // body stretch tail (updateBirthMask)
    bool hasTail = false; float2 tail = pos;
    if (gBodyStretch > 0.5)
    {
        float mr = min(gMaxRadii, speed * gLookback / max(R / gSize, 1e-6));
        if (speed > 0.0 && mr > 0.20) { tail = pos - vel / speed * (mr * R); hasTail = true; }
    }
    // shape lobe
    bool hasLobe = false; float2 lobe = pos; float lobeR = 0.0;
    if (gShapeOn > 0.5 && seedA > 0.34 && R >= 1.2)
    {
        float jitter = (seedB - 0.5) * 1.10;
        float2 dir = float2((pos.x / gSize - 0.5) * 0.9 + jitter, 1.0 + (seedA - 0.5) * 0.30);
        dir /= max(length(dir), 1e-6);
        lobe = pos + dir * (R * (0.45 + 0.15 * seedB) * gShapeStrength);
        lobeR = R * (0.55 + 0.10 * seedB);
        R = R * (1.0 - 0.10 * gShapeStrength);
        hasLobe = true;
    }
    // puddles
    bool hasPuddle = false; float2 p1 = pos, p2 = pos; float r1 = 0.0, r2 = 0.0;
    float diameterMM = 2.0 * rUV / max(gUvPerMM, 1e-6);
    float puddleSeed = rgFrac(idx * 0.4142135623 + gen * 0.7320508076);
    if (gPuddleOn > 0.5 && diameterMM >= gPuddleMinMM && puddleSeed < gPuddleShare)
    {
        float ang = rgFrac(idx * 0.5698402911 + gen * 0.6180339887) * 6.28318530718;
        float motion = min(speed * 10.0, 1.0);
        float2 vd = speed > 1e-6 ? vel / speed : float2(0.0, 0.0);
        float2 dd = float2(cos(ang), sin(ang)) * (1.0 - motion) + vd * motion;
        dd /= max(length(dd), 0.001);
        float reach = R * gPuddleReach;
        p1 = pos + dd * reach; r1 = R * (0.58 + 0.12 * puddleSeed);
        p2 = pos + float2(-dd.y * 0.7 - dd.x * 0.35, dd.x * 0.7 - dd.y * 0.35) * reach;
        r2 = R * 0.42;
        hasPuddle = true;
    }
    if (R <= 0.25) return;
    float code = R / 32.0;
    // splash v2 override from the CPU (body hidden / residual size)
    float amp = 1.0, scale = 1.0;
    float4 ov = txOverride.Load(int3(i, 0, 0));
    if (ov.a > 0.5) { amp = ov.r; scale = ov.g; }
    float2 u = speed > 1e-6 ? vel / speed
        : float2(cos(seedA * 3.14159265), sin(seedA * 3.14159265));
    R *= scale;
    float stretch = min(0.6, speed * gStretchGain / max(R / gSize, 1e-6) * 0.05);
    rgKern(px, pos, R * (1.0 + 0.6 * stretch), R * (1.0 - 0.25 * stretch), u, code, amp, acc);
    if (hasTail)
    {
        [unroll] for (int k = 1; k <= 2; k++)
        {
            float t = k * 0.4;
            float rr = R * (0.85 - 0.3 * t);
            rgKern(px, pos + (tail - pos) * t, rr, rr, u, code, amp, acc);
        }
    }
    if (hasLobe) rgKern(px, lobe, lobeR, lobeR, u, lobeR / 32.0, amp, acc);
    if (hasPuddle)
    {
        rgKern(px, p1, r1, r1, u, r1 / 32.0, amp, acc);
        rgKern(px, p2, r2, r2, u, r2 / 32.0, amp, acc);
    }
    if (gLobesOn > 0.5 && R >= 2.0)
    {
        int cnt = R >= 4.0 ? 2 : 1;
        [loop] for (int k = 1; k <= cnt; k++)
        {
            float a = (seedA + k * 0.37) * 6.28318530718;
            float d = R * (0.25 + 0.30 * rgFrac(seedB * 7.13 + k * 0.29));
            float rr = R * (0.45 + 0.30 * rgFrac(seedA * 5.71 + k * 0.53));
            rgKern(px, pos + float2(cos(a), sin(a)) * d, rr, rr, u, R / 32.0, amp, acc);
        }
    }
}
void rgWalk(float fbits, int base, float2 px, inout float4 acc, inout int occupied)
{
    uint bits = (uint)fbits;
    [loop] while (bits != 0u)
    {
        uint b = firstbitlow(bits);
        bits &= bits - 1u;
        occupied++;
        rgEval(base + (int)b, px, acc);
    }
}
void rgWalkWord(int w, int tx, int ty, float2 px,
    inout float4 acc, inout int occupied)
{
    float4 m = txMask.Load(int3(tx * (int)gWords + w, ty, 0));
    rgWalk(m.x, w * 96, px, acc, occupied);
    rgWalk(m.y, w * 96 + 24, px, acc, occupied);
    rgWalk(m.z, w * 96 + 48, px, acc, occupied);
    rgWalk(m.w, w * 96 + 72, px, acc, occupied);
}
void rgWalkSummary(float fbits, int base, int tx, int ty, float2 px,
    inout float4 acc, inout int occupied)
{
    uint bits = (uint)fbits;
    [loop] while (bits != 0u)
    {
        uint b = firstbitlow(bits);
        bits &= bits - 1u;
        int w = base + (int)b;
        if (w < (int)gWords) rgWalkWord(w, tx, ty, px, acc, occupied);
    }
}
float4 main(PS_IN pin)
{
    if (gDebug > 2.5) return float4(0.0, 0.0, 0.0, 0.0);
    float2 tex = pin.Tex;
    if (gFlipY > 0.5) tex.y = 1.0 - tex.y;
    float2 px = tex * gSize;
    int tx = (int)min(floor(px.x / gTile), gTilesX - 1.0);
    int ty = (int)min(floor(px.y / gTile), gTilesY - 1.0);
    float4 acc = 0.0;
    int occupied = 0;
    if (gSparseWords > 0.5)
    {
        [loop] for (int block = 0; block < (int)gSummaryWords; ++block)
        {
            float4 s = txSummary.Load(int3(tx * (int)gSummaryWords + block, ty, 0));
            int base = block * 96;
            rgWalkSummary(s.x, base, tx, ty, px, acc, occupied);
            rgWalkSummary(s.y, base + 24, tx, ty, px, acc, occupied);
            rgWalkSummary(s.z, base + 48, tx, ty, px, acc, occupied);
            rgWalkSummary(s.w, base + 72, tx, ty, px, acc, occupied);
        }
    }
    else
    {
        [loop] for (int w = 0; w < (int)gWords; ++w)
            rgWalkWord(w, tx, ty, px, acc, occupied);
    }
    if (gDebug > 0.5 && gDebug < 1.5)
        return float4(saturate(occupied / 64.0), acc.g, 0.0, 1.0);
    return acc;
}
]]
rainDynamicSceneCopyState.gpuHeadsRun = function(target, size, sim)
    local st = rainDynamicSceneCopyState
    local r = cfg.RUNTIME
    local state = rainStateReadIsA and rainStateA or rainStateB
    local meta = rainStateReadIsA and rainStateMetaA or rainStateMetaB
    local count = rainDynamicStateReadbackCount or 0
    if not state or not meta or count <= 0 then return false end
    local tile = math.max(16, math.floor(r.RAIN_GPU_HEADS_TILE))
    local tilesX = math.ceil(size / tile)
    local tilesY = tilesX
    local words = math.ceil(count / 96)
    local maskW = tilesX * words
    local summaryWords = math.ceil(words / 96)
    local summaryW = tilesX * summaryWords
    if not st.gpuMask or st.gpuMaskW ~= maskW or st.gpuMaskH ~= tilesY then
        if st.gpuMask then st.gpuMask:dispose() end
        st.gpuMask = ui.ExtraCanvas(vec2(maskW, tilesY), 1,
            render.AntialiasingMode.None, render.TextureFormat.R32G32B32A32.Float)
        st.gpuMask:setName('RainFX GPU heads tile mask')
        st.gpuMaskW, st.gpuMaskH = maskW, tilesY
    end
    if r.RAIN_GPU_HEADS_SPARSE_WORDS
        and (not st.gpuSummary or st.gpuSummaryW ~= summaryW
            or st.gpuSummaryH ~= tilesY) then
        if st.gpuSummary then st.gpuSummary:dispose() end
        st.gpuSummary = ui.ExtraCanvas(vec2(summaryW, tilesY), 1,
            render.AntialiasingMode.None,
            render.TextureFormat.R32G32B32A32.Float)
        st.gpuSummary:setName('RainFX GPU heads sparse word summary')
        st.gpuSummaryW, st.gpuSummaryH = summaryW, tilesY
    end
    if not st.gpuOverride or st.gpuOverrideN ~= count then
        if st.gpuOverride then st.gpuOverride:dispose() end
        st.gpuOverride = ui.ExtraCanvas(vec2(count, 1), 1,
            render.AntialiasingMode.None, render.TextureFormat.R16G16B16A16.Float)
        st.gpuOverride:setName('RainFX GPU heads splash override')
        st.gpuOverride:clear(rgbm.colors.transparent)
        st.gpuOverrideN = count
    end
    local values = st.gpuValues or {}
    st.gpuValues = values
    values.gSize = size
    values.gTile = tile
    values.gTilesX = tilesX
    values.gTilesY = tilesY
    values.gWords = words
    values.gMaskW = maskW
    values.gSummaryW = summaryW
    values.gSummaryWords = summaryWords
    values.gSparseWords = r.RAIN_GPU_HEADS_SPARSE_WORDS and 1.0 or 0.0
    values.gCount = count
    values.gKs = math.max(1.0, r.RAIN_DYNAMIC_WATER_FIELD_KERNEL_SCALE)
    values.gMaxRadii = r.RAIN_DYNAMIC_BIRTH_MASK_BODY_MAX_RADII
    values.gLookback = r.RAIN_DYNAMIC_BIRTH_MASK_BODY_LOOKBACK_SECONDS
    values.gBodyStretch = r.RAIN_DYNAMIC_BIRTH_MASK_BODY_STRETCH and 1.0 or 0.0
    values.gShapeOn = r.RAIN_DYNAMIC_BIRTH_MASK_SHAPE_VARIATION and 1.0 or 0.0
    values.gShapeStrength = math.max(0.0, math.min(1.5, r.RAIN_DYNAMIC_BIRTH_MASK_SHAPE_STRENGTH))
    values.gPuddleOn = r.RAIN_DYNAMIC_BIRTH_PUDDLE_ENABLED and 1.0 or 0.0
    values.gPuddleMinMM = r.RAIN_DYNAMIC_BIRTH_PUDDLE_MIN_MM
    values.gPuddleShare = r.RAIN_DYNAMIC_BIRTH_PUDDLE_SHARE
    values.gPuddleReach = r.RAIN_DYNAMIC_BIRTH_PUDDLE_REACH
    values.gUvPerMM = r.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM
    values.gStretchGain = r.RAIN_DYNAMIC_WATER_FIELD_MOTION_STRETCH
    values.gLobesOn = r.RAIN_DYNAMIC_WATER_FIELD_LOBES and 1.0 or 0.0
    values.gFlipY = r.RAIN_GPU_HEADS_FLIP_Y and 1.0 or 0.0
    values.gDebug = r.RAIN_GPU_HEADS_DEBUG or 0
    local okA, errA = pcall(function()
        st.gpuMask:updateWithShader({
            textures = { txRainState = state, txRainStateMeta = meta },
            values = values,
            shader = rainDynamicSceneCopyState.gpuHeadsPassA,
        })
    end)
    if not okA then st.gpuHeadsErr = 'pass A: ' .. tostring(errA); return false end
    if r.RAIN_GPU_HEADS_SPARSE_WORDS then
        local okS, errS = pcall(function()
            local updated = st.gpuSummary:updateWithShader({
                textures = { txMask = st.gpuMask },
                values = values,
                shader = st.gpuHeadsSummaryPass,
            })
            if updated == false then error('summary shader pending') end
        end)
        if not okS then st.gpuHeadsErr = 'summary: ' .. tostring(errS); return false end
    end
    local okB, errB = pcall(function()
        target:updateWithShader({
            blendMode = render.BlendMode.Opaque,
            textures = { txRainState = state, txRainStateMeta = meta,
                txMask = st.gpuMask, txOverride = st.gpuOverride,
                txSummary = st.gpuSummary or st.gpuMask },
            values = values,
            shader = rainDynamicSceneCopyState.gpuHeadsPassB,
        })
    end)
    if not okB then st.gpuHeadsErr = 'pass B: ' .. tostring(errB); return false end
    st.gpuHeadsErr = nil
    return true
end
-- Splash v2 overrides (body amplitude, residual scale) collected by the
-- CPU pass this frame; used by pass B next frame (one-frame lag).
rainDynamicSceneCopyState.gpuOverrideWrite = function()
    local st = rainDynamicSceneCopyState
    if not st.gpuOverride then return end
    local list = st.gpuOverrides or {}
    st.gpuOverride:clear(rgbm.colors.transparent)
    if #list > 0 then
        st.gpuOverride:update(function()
            for _, o in ipairs(list) do
                ui.drawRectFilled(vec2(o[1] - 1, 0), vec2(o[1], 1),
                    rgbm(o[2], o[3], 0.0, 1.0))
            end
        end)
    end
    st.gpuOverrideCount = #list
    st.gpuOverrides = {}
end
rainDynamicSceneCopyState.gpuSplashAtlasShader = [[
float splashFrac(float x) { return x - floor(x); }
float splashStep(float a, float b, float x)
{
    float q = saturate((x - a) / max(b - a, 1e-4));
    return q * q * (3.0 - 2.0 * q);
}
void splashKern(float2 px, float2 c, float ax, float ay, float2 u,
    float code, float energy, float amp, inout float4 acc)
{
    ax *= gKs; ay *= gKs;
    float2 d = px - c;
    float2 v = float2(-u.y, u.x);
    float2 p = float2(dot(d, u) / max(ax, 1e-3),
        dot(d, v) / max(ay, 1e-3));
    float k = saturate(1.0 - dot(p, p)) * amp;
    if (k <= 0.0 || amp <= 0.005) return;
    acc.rgb = float3(min(code, 1.0), 1.0, energy) * k
        + acc.rgb * (1.0 - k);
    acc.a = k + acc.a * (1.0 - k);
}
float4 main(PS_IN pin)
{
    float2 atlasPx = floor(pin.Tex * float2(gAtlasW, gAtlasH));
    int col = (int)floor(atlasPx.x / gTileSize);
    int row = (int)floor(atlasPx.y / gTileSize);
    int i = row * (int)gAtlasCols + col;
    if (i >= (int)gSplashCount) return 0.0;
    float4 a = txSplashMeta.Load(int3(i * 2, 0, 0));
    float4 b = txSplashMeta.Load(int3(i * 2 + 1, 0, 0));
    float Rf = a.x * gSize, E = a.y, t = saturate(a.z);
    float sa = b.x, sb = b.y, reach = b.z * gSize;
    float2 cell = atlasPx - float2(col, row) * gTileSize;
    float2 px = ((cell + 0.5) / gTileSize * 2.0 - 1.0) * reach;
    float4 acc = 0.0;
    float s = 1.0 - (1.0 - t) * (1.0 - t);
    float Rp = Rf * (1.0 + gSplashSpread * E * s);
    float centre = (1.0 - splashStep(0.05, gSplashHollowAt, t))
        * (1.0 - 0.45 * s);
    if (centre > 0.02)
        splashKern(px, 0.0, Rp * 0.80,
            Rp * 0.80 * (0.88 + 0.12 * splashFrac(sb * 2.9)),
            float2(cos(sa * 6.28), sin(sa * 6.28)),
            Rp / 32.0, 0.5 * E, centre, acc);
    float ringOn = splashStep(0.0, 0.18, t);
    float brk = saturate((t - gSplashBreakAt)
        / max(1.0 - gSplashBreakAt, 1e-3));
    int n = (int)floor(10.0 + 12.0 * E
        * (0.5 + 0.5 * splashFrac(sb * 3.7)) + 0.5);
    [loop] for (int k = 1; k <= n; ++k)
    {
        float h1 = splashFrac(sa * 17.13 + k * 0.7548776662);
        float h2 = splashFrac(sb * 11.71 + k * 0.5698402911);
        float h3 = splashFrac((sa + sb) * 7.77 + k * 0.4142135623);
        if (h3 < brk * 0.6) continue;
        float ang = (k + 0.6 * (h1 - 0.5)) / n * 6.28318530718 + sa * 6.28;
        float ca = cos(ang), sn = sin(ang);
        float d = Rp * (0.88 + 0.24 * h2) + Rf
            * gSplashScatter * E * brk * (0.4 + h2);
        float rr = max(gSplashMinKernel, Rf * (0.30 + 0.18 * h1)
            * (1.0 - 0.55 * brk) * (0.8 + 0.4 * E));
        float along = rr * (1.0 + (0.8 + 0.6 * h2) * (1.0 - brk));
        splashKern(px, float2(ca, sn) * d, along, rr,
            float2(-sn, ca), rr / 32.0, 1.0, ringOn, acc);
    }
    if (t > 0.25)
    {
        int m = (int)floor(2.0 + 6.0 * E * splashFrac(sa * 4.9) + 0.5);
        float fly = (t - 0.25) / 0.75;
        [loop] for (int k = 1; k <= m; ++k)
        {
            float h1 = splashFrac(sb * 13.3 + k * 0.6180339887);
            float h2 = splashFrac(sa * 19.9 + k * 0.3819660113);
            float ang = h1 * 6.28318530718;
            float d = Rp * (1.05 + 0.9 * h2 * fly);
            float rr = max(gSplashMinKernel, Rf * (0.08 + 0.14 * h2));
            splashKern(px, float2(cos(ang), sin(ang)) * d,
                rr, rr, float2(1.0, 0.0), rr / 32.0, 1.0, 1.0, acc);
        }
    }
    // Atlas is drawn with straight-alpha UI blending. Convert the
    // accumulated premultiplied colour back before that final blend.
    if (acc.a > 1e-5) acc.rgb /= acc.a;
    return acc;
}
]]
rainDynamicSceneCopyState.gpuSplashRender = function(target, size)
    local st = rainDynamicSceneCopyState
    local list = st.gpuSplashList or {}
    if #list > 1024 then
        error('GPU splash atlas limit (1024 heads); CPU fallback next frame')
    end
    local count = math.min(#list, 1024)
    st.gpuSplashCount = count
    st.gpuSplashOverflow = #list - count
    st.gpuSplashList = {}
    -- ExtraCanvas shader updates can become visible after the CPU has
    -- advanced to another compact list order. Composite the atlas and
    -- coordinates from the same completed frame, then write the next one
    -- into the other atlas texture.
    local drawList = st.gpuSplashDrawList
    local drawAtlas = st.gpuSplashReadAtlas
    if drawList and drawAtlas and st.gpuSplashDrawSize == size
        and count <= (st.gpuSplashCapacity or 0)
        and #drawList > 0 then
        local tile = 64
        local cols = 32
        local atlasW = st.gpuSplashAtlasW
        local atlasH = st.gpuSplashAtlasH
        target:update(function()
            for j = 1, #drawList do
                local o = drawList[j]
                local col = (j - 1) % cols
                local row = math.floor((j - 1) / cols)
                ui.drawImage(drawAtlas,
                    vec2(o[2] - o[8], o[3] - o[8]),
                    vec2(o[2] + o[8], o[3] + o[8]),
                    rgbm(1.0, 1.0, 1.0, 1.0),
                    vec2(col * tile / atlasW, row * tile / atlasH),
                    vec2((col + 1) * tile / atlasW,
                        (row + 1) * tile / atlasH))
            end
        end)
    end
    st.gpuSplashDrawList = nil
    if count == 0 then return end
    local capacity = 128
    while capacity < count do capacity = capacity * 2 end
    capacity = math.max(capacity, st.gpuSplashCapacity or 0)
    local tile = 64
    local cols = 32
    local atlasW = cols * tile
    local atlasH = math.ceil(capacity / cols) * tile
    if st.gpuSplashCapacity ~= capacity then
        if st.gpuSplashMeta then st.gpuSplashMeta:dispose() end
        if st.gpuSplashAtlasA then st.gpuSplashAtlasA:dispose() end
        if st.gpuSplashAtlasB then st.gpuSplashAtlasB:dispose() end
        st.gpuSplashMeta = ui.ExtraCanvas(vec2(capacity * 2, 1), 1,
            render.AntialiasingMode.None, render.TextureFormat.R32G32B32A32.Float)
        st.gpuSplashAtlasA = ui.ExtraCanvas(vec2(atlasW, atlasH), 1,
            render.AntialiasingMode.None, render.TextureFormat.R16G16B16A16.Float)
        st.gpuSplashAtlasB = ui.ExtraCanvas(vec2(atlasW, atlasH), 1,
            render.AntialiasingMode.None, render.TextureFormat.R16G16B16A16.Float)
        st.gpuSplashMeta:setName('RainFX GPU splash metadata')
        st.gpuSplashAtlasA:setName('RainFX GPU splash atlas A')
        st.gpuSplashAtlasB:setName('RainFX GPU splash atlas B')
        st.gpuSplashCapacity = capacity
        st.gpuSplashWriteIsA = true
    end
    st.gpuSplashAtlasW, st.gpuSplashAtlasH = atlasW, atlasH
    local spread = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SPREAD
    local scatter = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_SCATTER
    local ks = math.max(1.0, cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_KERNEL_SCALE)
    st.gpuSplashMeta:clear(rgbm.colors.transparent)
    st.gpuSplashMeta:update(function()
        for j = 1, count do
            local o = list[j]
            local reach = o[4] * ((1.0 + spread * o[5]) * 2.0
                + scatter * o[5] * 1.5 + 0.8 * ks) + 2.0
            o[8] = reach
            local sa = rainDynamicSurfaceFrac(o[1] * 0.7548776662
                + o[7] * 0.5698402911)
            local sb = rainDynamicSurfaceFrac(o[1] * 0.6180339887
                + o[7] * 0.4142135623)
            local mx = (j - 1) * 2
            ui.drawRectFilled(vec2(mx, 0), vec2(mx + 1, 1),
                rgbm(o[4] / size, o[5], o[6], 1.0))
            ui.drawRectFilled(vec2(mx + 1, 0), vec2(mx + 2, 1),
                rgbm(sa, sb, reach / size, 1.0))
        end
    end)
    local r = cfg.RUNTIME
    local values = { gSize = size, gAtlasW = atlasW, gAtlasH = atlasH,
        gAtlasCols = cols, gTileSize = tile, gSplashCount = count,
        gKs = ks, gSplashSpread = spread,
        gSplashScatter = scatter,
        gSplashBreakAt = r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_BREAK_AT,
        gSplashHollowAt = r.RAIN_DYNAMIC_WATER_FIELD_SPLASH_HOLLOW_AT,
        gSplashMinKernel = math.max(0.5,
            r.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS) }
    local writeAtlas = st.gpuSplashWriteIsA
        and st.gpuSplashAtlasA or st.gpuSplashAtlasB
    local updated = writeAtlas:updateWithShader({
        textures = { txSplashMeta = st.gpuSplashMeta },
        values = values, shader = st.gpuSplashAtlasShader,
        blendMode = render.BlendMode.Opaque,
    })
    if updated == false then error('GPU splash atlas shader pending') end
    st.gpuSplashReadAtlas = writeAtlas
    st.gpuSplashWriteIsA = not st.gpuSplashWriteIsA
    st.gpuSplashDrawList = list
    st.gpuSplashDrawSize = size
end

rainDynamicSceneCopyState.updateTrailMaskTimed = function(sim)
    local t0 = cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0
    local res = rainDynamicSceneCopyState.updateTrailMask(sim)
    rainDynamicSceneCopyState.profTrailMaskMs = ((cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0) - t0) * 1000.0
    return res
end
rainDynamicSceneCopyState.updateBirthMask = function(sim)
    if not rainDynamicStateHasSnapshot then return end
    local state = rainDynamicSceneCopyState
    local size = math.max(128, math.floor(
        cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SIZE))
    -- Water field only (legacy RGBA8 birth optics removed): fp16 height
    -- and radius channels, fully redrawn every frame.
    local waterField = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_ENABLED
    local birthFormat = render.TextureFormat.R16G16B16A16.Float
    if not state.birthMaskA or state.birthMaskSize ~= size then
        if state.birthMaskA then state.birthMaskA:dispose() end
        if state.birthMaskB then state.birthMaskB:dispose() end
        state.birthMaskWaterField = true
        state.birthMaskA = ui.ExtraCanvas(vec2(size, size), 1,
            birthFormat)
            :setName('RainFX Birth Mask A')
        state.birthMaskB = nil
        state.birthMaskA:clear(rgbm.colors.transparent)
        state.birthMaskRead = state.birthMaskA
        state.birthMaskSize = size
        state.birthMaskFrame = nil
        state.birthMaskCursor = 1
        state.birthMaskRecentCursor = 1
    end
    if state.birthMaskSuspended then
        state.birthMaskA:clear(rgbm.colors.transparent)
        if state.birthMaskB then
            state.birthMaskB:clear(rgbm.colors.transparent)
        end
        state.birthMaskSuspended = false
    end
    if state.birthMaskFrame == sim.frame then return end
    -- Water-field heads redraw every frame; the separate trail canvas keeps
    -- history. Self-accumulating heads would flatten into plateaus.
    local fullRedraw = true
    local target = state.birthMaskA
    state.birthMaskRead = state.birthMaskA
    target:clear(rgbm.colors.transparent)
    -- R1.1: GPU heads fill the canvas; the CPU pass then only overlays the
    -- splash / tear pieces and records splash overrides.
    state.gpuHeadsActive = false
    if waterField and cfg.RUNTIME.RAIN_GPU_HEADS then
        local tg = cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0
        local okG, resG = pcall(state.gpuHeadsRun, target, size, sim)
        state.gpuHeadsActive = okG and resG == true
        if not okG then state.gpuHeadsErr = tostring(resG) end
        state.profGpuSubmitMs = ((cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0) - tg) * 1000.0
    end

    local cpuBuildStart = cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0
    local stamps = {}
    local count = rainDynamicStateReadbackCount
    -- Every live drop is stamped every frame (full redraw).
    local budget = math.max(1, count)
    local recentBudget = count
    local growTime = math.max(
        cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_GROW_SECONDS, 0.01)
    local predictedAge = math.min(math.max(
        rainDynamicStateRenderClock - rainDynamicStateSnapshotTime, 0.0),
        cfg.RUNTIME.RAIN_DYNAMIC_STATE_PREDICTION_MAX_SECONDS)
    local recentCursor = state.birthMaskRecentCursor or 1
    local fresh = 0
    local stretched = 0
    local maxMotionRadii = 0.0

    -- Give new births a few growing stamps before the rotating refresh
    -- sweep handles all living drops. Rotation avoids low-slot bias.
    for inspected = 0, count - 1 do
        if fresh >= recentBudget then break end
        local index = (recentCursor - 1 + inspected) % count + 1
        local birthAt = state.birthSeenAt
            and state.birthSeenAt[index]
        local age = birthAt and rainDynamicStateRenderClock - birthAt
        if age and age >= 0.0 and age < growTime
            and (rainDynamicStateAlive[index] or 0.0) > 0.5
        then
            local u = (rainDynamicStateU[index] or -1.0)
                + (rainDynamicStateVelocityU[index] or 0.0)
                    * predictedAge
            local v = (rainDynamicStateV[index] or -2.0)
                + (rainDynamicStateVelocityV[index] or 0.0)
                    * predictedAge
            if u >= 0.0 and u <= 1.0 and v >= -1.0 and v <= 0.0 then
                local growth = math.min(age / growTime, 1.0)
                stamps[#stamps + 1] = {
                    x = u * size, y = (v + 1.0) * size,
                    -- State radius is already the physical visor-UV
                    -- radius; use the same UV span for both canvas axes.
                    radius = (rainDynamicStateRadius[index] or 0.0)
                        * size * (0.28 + 0.72 * growth),
                    index = index,
                }
                fresh = fresh + 1
            end
        end
    end
    state.birthMaskRecentCursor = count > 0
        and (recentCursor - 1 + 41) % count + 1 or 1

    -- Refresh only a fixed slice per frame. Stale footprints decay in
    -- this same canvas while existing wipe/ridge masks remain independent.
    local cursor = state.birthMaskCursor or 1
    local inspected = 0
    while inspected < count and #stamps < budget do
        local index = (cursor - 1 + inspected) % count + 1
        if (rainDynamicStateAlive[index] or 0.0) > 0.5 then
            local birthAt = state.birthSeenAt
                and state.birthSeenAt[index]
            local age = birthAt and rainDynamicStateRenderClock - birthAt
            if not age or age >= growTime then
                local u = (rainDynamicStateU[index] or -1.0)
                    + (rainDynamicStateVelocityU[index] or 0.0)
                        * predictedAge
                local v = (rainDynamicStateV[index] or -2.0)
                    + (rainDynamicStateVelocityV[index] or 0.0)
                        * predictedAge
                if u >= 0.0 and u <= 1.0 and v >= -1.0 and v <= 0.0 then
                    local radiusPx =
                        (rainDynamicStateRadius[index] or 0.0) * size
                    local stamp = {
                        x = u * size, y = (v + 1.0) * size,
                        radius = radiusPx,
                        index = index,
                    }
                    if cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_BODY_STRETCH
                        and radiusPx > 0.0 then
                        local velocityU =
                            rainDynamicStateVelocityU[index] or 0.0
                        local velocityV =
                            rainDynamicStateVelocityV[index] or 0.0
                        local speed = math.sqrt(
                            velocityU * velocityU
                            + velocityV * velocityV)
                        local motionRadii = math.min(
                            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_BODY_MAX_RADII,
                            speed
                                * cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_BODY_LOOKBACK_SECONDS
                                / math.max(radiusPx / size, 0.000001))
                        maxMotionRadii = math.max(maxMotionRadii, motionRadii)
                        if speed > 0.0 and motionRadii > 0.20 then
                            local distancePx = motionRadii * radiusPx
                            stamp.tailX = stamp.x
                                - velocityU / speed * distancePx
                            stamp.tailY = stamp.y
                                - velocityV / speed * distancePx
                            stretched = stretched + 1
                        end
                    end
                    stamps[#stamps + 1] = stamp
                end
            end
        end
        inspected = inspected + 1
    end
    state.birthMaskCursor = count > 0
        and (cursor - 1 + inspected) % count + 1 or 1
    local shaped = 0
    local puddles = 0
    if cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SHAPE_VARIATION
        or cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_ENABLED then
        local strength = math.max(0.0, math.min(1.5,
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SHAPE_STRENGTH))
        for _, stamp in ipairs(stamps) do
            -- A stable per-life lobe keeps the outline from crawling
            -- between full-frame redraws. Bias it down/outward on the visor.
            local generation = state.generation
                and state.generation[stamp.index] or 0
            local seed = rainDynamicSurfaceFrac(
                stamp.index * 0.7548776662
                + generation * 0.5698402911)
            if cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SHAPE_VARIATION
                and seed > 0.34 and stamp.radius >= 1.2 then
                local radius = stamp.radius
                if not state.gpuHeadsActive then
                    local secondary = rainDynamicSurfaceFrac(
                        stamp.index * 0.6180339887
                        + generation * 0.4142135623)
                    local jitter = (secondary - 0.5) * 1.10
                    local dirX = (stamp.x / size - 0.5) * 0.9 + jitter
                    local dirY = 1.0 + (seed - 0.5) * 0.30
                    local length = math.sqrt(dirX * dirX + dirY * dirY)
                    local reach = radius
                        * (0.45 + 0.15 * secondary) * strength
                    stamp.lobeX = stamp.x + dirX / length * reach
                    stamp.lobeY = stamp.y + dirY / length * reach
                    stamp.lobeRadius = radius * (0.55 + 0.10 * secondary)
                end
                stamp.radius = radius * (1.0 - 0.10 * strength)
                shaped = shaped + 1
            end
            if not state.gpuHeadsActive then
            local diameterMM = 2.0
                * (rainDynamicStateRadius[stamp.index] or 0.0)
                / math.max(cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM, 0.000001)
            local puddleSeed = rainDynamicSurfaceFrac(
                stamp.index * 0.4142135623 + generation * 0.7320508076)
            if cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_ENABLED
                and diameterMM >= cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_MIN_MM
                and puddleSeed < cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_SHARE
            then
                -- The per-life seed selects a stable irregular footprint.
                -- A moving drop bends its forward lobe toward velocity.
                local angle = rainDynamicSurfaceFrac(
                    stamp.index * 0.5698402911 + generation * 0.6180339887)
                    * math.pi * 2.0
                local velocityU = rainDynamicStateVelocityU[stamp.index] or 0.0
                local velocityV = rainDynamicStateVelocityV[stamp.index] or 0.0
                local speed = math.sqrt(velocityU * velocityU
                    + velocityV * velocityV)
                local motion = math.min(speed * 10.0, 1.0)
                local dx = math.cos(angle) * (1.0 - motion)
                    + (speed > 0.000001 and velocityU / speed or 0.0)
                        * motion
                local dy = math.sin(angle) * (1.0 - motion)
                    + (speed > 0.000001 and velocityV / speed or 0.0)
                        * motion
                local norm = math.max(math.sqrt(dx * dx + dy * dy), 0.001)
                dx, dy = dx / norm, dy / norm
                local reach = stamp.radius
                    * cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_REACH
                stamp.puddleX = stamp.x + dx * reach
                stamp.puddleY = stamp.y + dy * reach
                stamp.puddleRadius = stamp.radius * (0.58 + 0.12 * puddleSeed)
                stamp.puddle2X = stamp.x
                    + (-dy * 0.7 - dx * 0.35) * reach
                stamp.puddle2Y = stamp.y
                    + (dx * 0.7 - dy * 0.35) * reach
                stamp.puddle2Radius = stamp.radius * 0.42
                puddles = puddles + 1
            end
            end
        end
    end
    if waterField then
        state.profCpuBuildMs = ((cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0) - cpuBuildStart) * 1000.0
        -- Bake the kernels outside any canvas:update() callback.
        state.waterKernel(state)
        if cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_RIBBON then
            state.waterRibbonKernel(state)
        end
        local overlayStart = cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0
        if #stamps > 0 and not (state.gpuHeadsActive
                and (cfg.RUNTIME.RAIN_GPU_HEADS_DEBUG or 0) >= 1.5) then
            if state.gpuHeadsActive and cfg.RUNTIME.RAIN_GPU_SPLASH then
                -- Metadata only: no head quads are submitted in R1.4.
                local splashStateStart = cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0
                state.waterFieldCollectGpuSplash(state, stamps, size)
                state.profSplashStateMs =
                    ((cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0) - splashStateStart) * 1000.0
            else
                state.profSplashStateMs = 0.0
                target:update(function()
                    state.waterFieldDrawStamps(state, stamps, size, sim)
                end)
            end
        else
            state.profSplashStateMs = 0.0
            state.waterFieldKernels = 0
            state.waterFieldTearHeads = 0
        end
        if state.gpuHeadsActive then
            local overrideStart = cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0
            state.gpuOverrideWrite()
            state.profOverrideWriteMs =
                ((cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0) - overrideStart) * 1000.0
            if cfg.RUNTIME.RAIN_GPU_SPLASH then
                local splashStart = cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0
                local okSplash, errSplash = pcall(state.gpuSplashRender,
                    target, size)
                state.profGpuSplashSubmitMs =
                    ((cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0) - splashStart) * 1000.0
                if not okSplash then
                    state.gpuSplashErr = tostring(errSplash)
                    cfg.RUNTIME.RAIN_GPU_SPLASH = false
                else
                    state.gpuSplashErr = nil
                end
            else
                state.gpuSplashCount = 0
                state.gpuSplashOverflow = 0
                state.profGpuSplashSubmitMs = 0.0
                state.gpuSplashDrawList = nil
            end
        else
            state.profOverrideWriteMs = 0.0
        end
        if not (state.gpuHeadsActive and cfg.RUNTIME.RAIN_GPU_SPLASH) then
            state.gpuSplashList = {}
        end
        state.profHeadOverlayMs = ((cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0) - overlayStart) * 1000.0
        local trailStart = cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0
        state.waterFieldUpdateTrail(state, stamps, size, sim)
        state.profWaterTrailMs = ((cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and os.preciseClock() or 0.0) - trailStart) * 1000.0
    end
    state.birthMaskRead = target
    state.birthMaskFrame = sim.frame
    state.birthMaskStamps = (state.birthMaskStamps or 0) + #stamps
    state.birthMaskFresh = (state.birthMaskFresh or 0) + fresh
    state.birthMaskStretched = (state.birthMaskStretched or 0)
        + stretched
    state.birthMaskShaped = (state.birthMaskShaped or 0) + shaped
    state.birthMaskPuddles = (state.birthMaskPuddles or 0) + puddles
    state.birthMaskMaxMotion = math.max(
        state.birthMaskMaxMotion or 0.0, maxMotionRadii)
    if sim.frame % 180 == 0 then
        ac.log(appNameDebug .. ' Dynamic birth mask: '
            .. tostring(size) .. 'x' .. tostring(size)
            .. ' stamps=' .. tostring(state.birthMaskStamps)
            .. ' fresh=' .. tostring(state.birthMaskFresh)
            .. ' stretched=' .. tostring(state.birthMaskStretched)
            .. ' shaped=' .. tostring(state.birthMaskShaped)
            .. ' puddles=' .. tostring(state.birthMaskPuddles)
            .. ' maxMotionRadii='
            .. string.format('%.2f', state.birthMaskMaxMotion)
            .. ' budget=' .. tostring(budget)
            .. ' waterField=' .. tostring(waterField))
        state.birthMaskStamps = 0
        state.birthMaskFresh = 0
        state.birthMaskStretched = 0
        state.birthMaskShaped = 0
        state.birthMaskPuddles = 0
        state.birthMaskMaxMotion = 0.0
    end
end

-- Update the independent scene before the main render, as recommended by
-- the CSP GeometryShot API. The transparent pass only reads this texture.
render.onSceneReady(function()
    if not cfg.RUNTIME.RAIN_DYNAMIC_DROP_GEOMETRY_SHOT_DEBUG
        or not cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_STATE_ENABLED
        or not cfg.RUNTIME.RAIN_ENABLED
    then
        return
    end

    local sim = ac.getSim()
    if not sim then return end
    if not rainDynamicManualPreDrawLogged then
        ac.log(appNameDebug .. ' Dynamic drop scene-ready shot: starting frame='
            .. tostring(sim.frame))
    end
    local yebisShot = cfg.RUNTIME.RAIN_DYNAMIC_DROP_SHOT_YEBIS_DEBUG
    local shotWithDepth = cfg.RUNTIME.RAIN_DYNAMIC_DROP_SKY_DEPTH_DEBUG
        or cfg.RUNTIME.RAIN_DYNAMIC_DROP_SKY_FOG_COLOR_DEBUG
        or cfg.RUNTIME.RAIN_DYNAMIC_DROP_SKY_CLOUD_DETAIL_DEBUG
    local shotMips = (cfg.RUNTIME.RAIN_DYNAMIC_DROP_SKY_CLOUD_DETAIL_DEBUG
        or cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_ENABLED)
        and 10 or 1
    local shotScale = yebisShot and math.max(0.5, math.min(1.0,
        cfg.RUNTIME.RAIN_DYNAMIC_DROP_SHOT_YEBIS_SCALE)) or 1.0
    local shotWidth = math.max(1, math.floor(shotScale * (
        rainDynamicSceneCopyState.mainTargetWidth
            or (sim.windowWidth or 1) * 0.5)))
    local shotHeight = math.max(1, math.floor(shotScale * (
        rainDynamicSceneCopyState.mainTargetHeight
            or (sim.windowHeight or 1) * 0.5)))
    local shotResized = not rainDynamicSceneCopyState.geometryShot
        or rainDynamicSceneCopyState.shotWidth ~= shotWidth
        or rainDynamicSceneCopyState.shotHeight ~= shotHeight
        or rainDynamicSceneCopyState.shotYebis ~= yebisShot
        or rainDynamicSceneCopyState.shotWithDepth ~= shotWithDepth
        or rainDynamicSceneCopyState.shotMips ~= shotMips
    if shotResized then
        if rainDynamicSceneCopyState.geometryShot then
            rainDynamicSceneCopyState.geometryShot:dispose()
        end
        rainDynamicSceneCopyState.geometryShot = ac.GeometryShot(
            ac.findNodes('sceneRoot:yes'),
            vec2(shotWidth, shotHeight),
            shotMips,
            shotWithDepth,
            yebisShot and render.AntialiasingMode.YEBIS
                or render.AntialiasingMode.None,
            yebisShot and render.TextureFormat.R8G8B8A8.UNorm
                or render.TextureFormat.R16G16B16A16.Float
        )
        rainDynamicSceneCopyState.geometryShot:setOriginalLighting(true)
        rainDynamicSceneCopyState.geometryShot:setShadersType(
            render.ShadersType.Main
        )
        rainDynamicSceneCopyState.geometryShot:setGrass(true)
        rainDynamicSceneCopyState.geometryShot:setSky(true)
        -- Keep streaks out of the independently rendered drop source.
        rainDynamicSceneCopyState.geometryShot:setParticles(false)
        rainDynamicSceneCopyState.shotWidth = shotWidth
        rainDynamicSceneCopyState.shotHeight = shotHeight
        rainDynamicSceneCopyState.shotYebis = yebisShot
        rainDynamicSceneCopyState.shotWithDepth = shotWithDepth
        rainDynamicSceneCopyState.shotMips = shotMips
    end
    if rainDynamicSceneCopyState.shotTransparent
        ~= cfg.RUNTIME.RAIN_DYNAMIC_DROP_SHOT_TRANSPARENT or shotResized then
        rainDynamicSceneCopyState.shotTransparent =
            cfg.RUNTIME.RAIN_DYNAMIC_DROP_SHOT_TRANSPARENT
        rainDynamicSceneCopyState.geometryShot:setTransparentPass(
            cfg.RUNTIME.RAIN_DYNAMIC_DROP_SHOT_TRANSPARENT)
    end
    rainDynamicSceneCopyState.geometryShot:setClippingPlanes(
        math.max(sim.cameraClipNear or 0.05,
            cfg.RUNTIME.RAIN_DYNAMIC_DROP_SHOT_NEAR),
        sim.cameraClipFar
    )
    local shotOk, shotResult = pcall(function()
        local updated = rainDynamicSceneCopyState.geometryShot:update(
            sim.cameraPosition,
            sim.cameraLook,
            sim.cameraUp,
            sim.cameraFOV
        )
        if updated == false then return false end
        if shotMips > 1 then
            local mipsUpdated =
                rainDynamicSceneCopyState.geometryShot:mipsUpdate()
            if mipsUpdated == false then return false end
        end
        return true
    end)
    if not shotOk or not shotResult then
        rainDynamicSceneCopyState.shotFrame = nil
        if not rainDynamicSceneCopyState.shotWaitLogged then
            ac.warn(appNameDebug .. ' Dynamic drop scene-ready shot '
                .. 'pending; retrying: ' .. tostring(shotResult))
            rainDynamicSceneCopyState.shotWaitLogged = true
        end
        return
    end
    rainDynamicSceneCopyState.shotWaitLogged = false
    rainDynamicSceneCopyState.shotFrame = sim.frame
    if not rainDynamicManualPreDrawLogged or shotResized then
        ac.log(appNameDebug .. ' Dynamic drop scene-ready shot: updated '
            .. tostring(shotWidth) .. 'x' .. tostring(shotHeight)
            .. ' yebis=' .. tostring(yebisShot)
            .. ' depth=' .. tostring(shotWithDepth)
            .. ' mips=' .. tostring(shotMips)
            .. ' frame=' .. tostring(sim.frame))
    end
end)

-- Stage 4A dynamic droplet final draw
--
-- Reference validation:
-- Draw the runtime droplet mesh at the selected transparent stage. The vertices
-- are in the visor mesh's local coordinates; use the scene mesh's original
-- transform when drawing it explicitly.
--------------------------------------------------------
-- P1 post overlay (docs/RAINFX_POST_OVERLAY.md).
rainDynamicSceneCopyState.overlay = { status = 'off' }
rainDynamicSceneCopyState.rainOverlayParams = function(src, w, h)
    local base = rainDynamicSceneCopyState.lastDropMeshParams
    if not base then return nil end
    local ov = rainDynamicSceneCopyState.overlay
    local p = ov.params
    if not p then
        p = { mesh = base.mesh, transform = base.transform,
            shader = base.shader, textures = {}, values = {} }
        ov.params = p
    end
    for k, v in pairs(base.textures) do p.textures[k] = v end
    for k, v in pairs(base.values) do p.values[k] = v end
    p.textures.txDynamicSnapshot = src
    local inv = vec2(1.0 / w, 1.0 / h)
    p.values.gDynamicDropInvScreenSize = inv
    p.values.gDynamicDropInvRenderTargetSize = inv
    p.values.gDynamicDropLDR = 1.0
    p.values.gDynamicDropLdrFogMip = cfg.RUNTIME.RAIN_VISOR_OVERLAY_FOG_MIP
    -- Final frame is already toned: no shot sky correction.
    p.values.gDynamicDropHazeSkyCorrection = 0.0
    p.values.gDynamicDropTrailSkyCorrection = 0.0
    p.values.gDynamicDropBirthSkyCorrection = 0.0
    p.values.gDynamicDropDepthOnly = 0.0
    p.values.gDynamicDropPremulOut = cfg.RUNTIME.RAIN_VISOR_LAYER and 1.0 or 0.0
    -- s41: same look in screen terms at any overlay resolution.
    local mainW = math.max(1, rainDynamicSceneCopyState.mainTargetWidth or w)
    local k = w / mainW
    p.values.gDynamicDropMipBias = math.log(math.max(k, 1e-3)) / math.log(2)
    for _, key in ipairs({ 'gDynamicDropHazeSpecklePixels',
        'gDynamicDropLargeFullPx', 'gDynamicDropLargeStartPx',
        'gDynamicDropLargeWarpPx', 'gDynamicDropSmearFacetPixels',
        'gDynamicDropTrailFilmPixels', 'gDynamicDropTrailRefractPx',
        'gDynamicDropTrailRidgePixels' }) do
        if type(base.values[key]) == 'number' then
            p.values[key] = base.values[key] * k
        end
    end
    return p
end
rainDynamicSceneCopyState.rainOverlayEnsure = function(ov, w, h)
    if ov.shot and ov.w == w and ov.h == h then return end
    if ov.shot then ov.shot:dispose() end
    if ov.src then ov.src:dispose() end
    ov.src = ui.ExtraCanvas(vec2(w, h),
        math.max(1, math.floor(cfg.RUNTIME.RAIN_VISOR_OVERLAY_SOURCE_MIPS)),
        render.AntialiasingMode.None, render.TextureFormat.R16G16B16A16.Float)
    ov.src:setName('RainFX overlay source (final frame)')
    ov.shot = ac.GeometryShot({
        transparent = function()
            if cfg.RUNTIME.RAIN_VISOR_LAYER then
                rainDynamicSceneCopyState.visorLayerDraw(ov)
                return
            end
            local p = ov.drawParams
            if not p then return end
            rainDynamicSurfaceMesh:setVisible(true, false)
            -- Opaque + depth: the texel keeps the shader's straight
            -- (rgb, a); the nearest visor part wins; clipped pixels stay
            -- (0, 0, 0, 0) from the clear.
            render.setBlendMode(render.BlendMode.Opaque)
            render.setCullMode(render.CullMode.None)
            render.setDepthMode(render.DepthMode.Normal)
            local okDraw, res = pcall(render.mesh, p)
            rainDynamicSurfaceMesh:setVisible(false, false)
            ov.drawn = okDraw and res and true or false
            if not okDraw then ov.err = tostring(res) end
        end,
    }, vec2(w, h), 1, true, render.AntialiasingMode.None,
        render.TextureFormat.R16G16B16A16.Float)
    ov.shot:setName('RainFX visor overlay')
    pcall(function() ov.shot:setSky(false) end)
    pcall(function() ov.shot:setParticles(false) end)
    pcall(function() ov.shot:setClearColor(rgbm(0, 0, 0, 0)) end)
    ov.w, ov.h = w, h
end
rainDynamicSceneCopyState.rainOverlayRender = function(ov, sim)
    ov.drawParams = rainDynamicSceneCopyState.rainOverlayParams(ov.src, ov.w, ov.h)
    if not ov.drawParams then ov.status = 'waiting for drop params'; return false end
    pcall(function() ov.shot:setClippingPlanes(
        math.max(sim.cameraClipNear or 0.05, 0.001), sim.cameraClipFar) end)
    local ok, res = pcall(function()
        return ov.shot:update(sim.cameraPosition, sim.cameraLook,
            sim.cameraUp, sim.cameraFOV)
    end)
    if not ok then ov.err = tostring(res) end
    return ok
end
-- Fallback (one frame late) when the shot cannot update inside the HUD.
render.onSceneReady(function()
    local ov = rainDynamicSceneCopyState.overlay
    if not cfg.RUNTIME.RAIN_VISOR_OVERLAY or not ov.hudUpdateFailed
        or not ov.shot then return end
    local sim = ac.getSim()
    if sim then rainDynamicSceneCopyState.rainOverlayRender(ov, sim) end
end)
-- Visor layer V1 (docs/RAINFX_VISOR_LAYER.md).
rainDynamicSceneCopyState.visorLayer = { hidden = false }
rainDynamicSceneCopyState.visorLayerDefs = function()
    local T = appFolder .. '/texture/'
    return {
        -- s44: all two-sided (user: single-sided parts were overdrawn by
        -- the two-sided ones; the cost difference is negligible).
        housing = {
            { mesh = 'BODY_FRAME_OVERLAY', two = true, mat = 'FRAME',
                tex = T .. 'BODY_FRAME/BODY_FRAME_1K_txDiff.dds',
                nrm = T .. 'BODY_FRAME/BODY_FRAME_1K_txNormal.dds' },
            { mesh = 'BODY_GLASSLINE_OVERLAY', two = true, grey = true, mat = 'RUBBER', interior = true,
                nrm = T .. 'BODY_FRAME/BODY_INT_BORDER_GLASSLINE_2K_txNormal.dds' },
            { mesh = 'BODY_FABRIC_OVERLAY', two = true, mat = 'FABRIC', interior = true,
                tex = T .. 'BODY_FRAME/BODY_INT_FABRIC_2K_txDiff.dds',
                nrm = T .. 'BODY_FRAME/BODY_INT_FABRIC_4K_txNormal.dds',
                maps = T .. 'BODY_FRAME/BODY_INT_FABRIC_2K_txMaps.dds' },
        },
        -- back to front (outermost first, as seen from the eye)
        glass = {
            { mesh = 'GLASS_COATING_OVERLAY', two = true, kind = 2 },
            { rain = true },
            { mesh = 'GLASS_INT_OVERLAY', two = true, kind = 3,
              band = T .. 'GLASS/GLASS_EXT_BAND_WITH_ALPHAMASK.dds',
              bandUV = T .. 'GLASS/GLASS_INT_EXT_UV_FIELD.dds',
              nrm = T .. 'GLASS/GLASS_INT_EXT_4k_txNormal.dds',
              outline = T .. 'GLASS/GLASS_INT_OUTLINE_MASK.png',
              lens = T .. 'GLASS/GLASS_INT_LENS_FIELD.dds' },
            -- The band owns the final overlap; inner optics never replace it.
            { mesh = 'GLASS_EXT_OVERLAY', two = true, kind = 1,
              tex = T .. 'GLASS/GLASS_EXT_BAND_WITH_ALPHAMASK.dds',
              nrm = T .. 'GLASS/GLASS_INT_EXT_4k_txNormal.dds' },
        },
    }
end
-- s56: per-mesh parameter UI of the custom-shader (*_OVERLAY) meshes,
-- shown in the KN5 tab material popup.
rainDynamicSceneCopyState.visorLayerItemFor = function(meshName)
    local vl = rainDynamicSceneCopyState.visorLayer
    local defs = vl.defs or rainDynamicSceneCopyState.visorLayerDefs()
    for _, it in ipairs(defs.housing) do
        if it.mesh == meshName then return it end
    end
    for _, it in ipairs(defs.glass) do
        if it.mesh == meshName then return it end
    end
    if meshName == 'GLASS_RAINFX_OVERLAY' then return { rainNote = true } end
    return nil
end
rainDynamicSceneCopyState.visorLayerParamUI = function(editor, item)
    local r = cfg.RUNTIME
    local function sl(label, key, a, b, fmt)
        local v, ch = ui.slider(label, r[key], a, b, fmt)
        if ch then r[key] = v end
    end
    local function ck(label, key)
        if ui.checkbox(label, r[key]) then r[key] = not r[key] end
    end
    ui.text('Custom shader (rainVisorLayer.hlsl), scene stack. '
        .. 'Values are runtime config (RAIN_VISOR_LAYER_*).')
    if item.rainNote then
        ui.text('Rain surface: its parameters are in the RainFX tab.')
        return
    end
    if item.mat == 'FRAME' then
        sl('Frame normal', 'RAIN_VISOR_LAYER_FRAME_NORMAL', 0.0, 3.0, '%.2f')
        sl('Frame spec', 'RAIN_VISOR_LAYER_FRAME_SPEC', 0.0, 2.0, '%.2f')
        sl('Frame gloss', 'RAIN_VISOR_LAYER_FRAME_GLOSS', 0.0, 1.0, '%.2f')
    elseif item.mat == 'RUBBER' then
        sl('Glass line grey', 'RAIN_VISOR_LAYER_BORDER_GREY', 0.0, 0.5, '%.3f')
        sl('Glass line normal', 'RAIN_VISOR_LAYER_RUBBER_NORMAL', 0.0, 3.0, '%.2f')
        sl('Glass line spec', 'RAIN_VISOR_LAYER_RUBBER_SPEC', 0.0, 2.0, '%.2f')
        sl('Glass line gloss', 'RAIN_VISOR_LAYER_RUBBER_GLOSS', 0.0, 1.0, '%.2f')
    elseif item.mat == 'FABRIC' then
        sl('Fabric normal (fuzz)', 'RAIN_VISOR_LAYER_FABRIC_NORMAL', 0.0, 3.0, '%.2f')
        sl('Fabric sheen', 'RAIN_VISOR_LAYER_FABRIC_SHEEN', 0.0, 2.0, '%.2f')
        sl('Fabric sheen power', 'RAIN_VISOR_LAYER_FABRIC_SHEEN_POWER', 1.0, 8.0, '%.2f')
        sl('Fabric spec', 'RAIN_VISOR_LAYER_FABRIC_SPEC', 0.0, 2.0, '%.2f')
        sl('Fabric gloss (x txMaps G)', 'RAIN_VISOR_LAYER_FABRIC_GLOSS', 0.0, 1.0, '%.2f')
        sl('Fabric lit-zone lift (direct light)', 'RAIN_VISOR_LAYER_FABRIC_LIT_LIFT', 0.0, 3.0, '%.2f')
    elseif item.kind == 1 then
        sl('Glass film alpha (outside the band)', 'RAIN_VISOR_LAYER_GLASS_ALPHA', 0.0, 0.5, '%.3f')
        sl('Top band normal relief', 'RAIN_VISOR_LAYER_EXT_RELIEF', 0.0, 3.0, '%.3f')
        sl('Top band opacity', 'RAIN_VISOR_LAYER_BAND_OPACITY', 0.0, 1.0, '%.2f')
        ck('Top band responds to external light', 'RAIN_VISOR_LAYER_BAND_EXTERNAL_LIGHT')
        sl('Top band brightness with external light off', 'RAIN_VISOR_LAYER_BAND_UNLIT_BRIGHTNESS', 0.0, 1.0, '%.3f')
        sl('Top band starts at texture alpha', 'RAIN_VISOR_LAYER_BAND_ALPHA_MIN', 0.0, 0.99, '%.2f')
    elseif item.kind == 2 then
        sl('Glass film alpha (shared by coating / inner glass)', 'RAIN_VISOR_LAYER_GLASS_ALPHA', 0.0, 0.5, '%.3f')
        ui.separator()
    elseif item.kind == 3 then
        ck('E2/E3 inner glass optics (prototype)', 'RAIN_VISOR_LAYER_OPTICS')
        ck('Preview effective sharp rim', 'RAIN_VISOR_LAYER_OPTICS_MASK_PREVIEW')
        sl('Masked optics brightness', 'RAIN_VISOR_LAYER_OPTICS_BRIGHTNESS', 0.0, 2.0, '%.2f')
        sl('E2 relief normal strength', 'RAIN_VISOR_LAYER_OPTICS_NORMAL', 0.0, 6.0, '%.3f')
        sl('E3 refraction (pixels)', 'RAIN_VISOR_LAYER_OPTICS_REFRACTION_PX', 0.0, 48.0, '%.2f px')
        sl('E3 lens slope gain', 'RAIN_VISOR_LAYER_OPTICS_LENS_GAIN', 0.0, 16.0, '%.2f')
        sl('E3 hairline split (pixels)', 'RAIN_VISOR_LAYER_OPTICS_BLUR_PX', 0.0, 3.0, '%.2f px')
        sl('Rim peak sharpness (higher = narrower)', 'RAIN_VISOR_LAYER_OPTICS_RIM_SHARPNESS', 1.0, 8.0, '%.2f')
        sl('Rim normal peak threshold', 'RAIN_VISOR_LAYER_OPTICS_RIM_PEAK', 0.08, 1.0, '%.3f')
        ui.text('E2 normal-map relief lighting (independent of E3)')
        sl('Relief highlight', 'RAIN_VISOR_LAYER_OPTICS_RELIEF_SPEC', 0.0, 4.0, '%.2f')
        sl('Relief gloss', 'RAIN_VISOR_LAYER_OPTICS_RELIEF_GLOSS', 0.0, 1.0, '%.2f')
        sl('Relief shading', 'RAIN_VISOR_LAYER_OPTICS_RELIEF_SHADE', 0.0, 1.0, '%.2f')
        sl('Rim transmission loss', 'RAIN_VISOR_LAYER_OPTICS_TRANSMISSION_LOSS', 0.0, 0.8, '%.2f')
        sl('Rim environment reflection', 'RAIN_VISOR_LAYER_OPTICS_REFLECTION', 0.0, 1.0, '%.2f')
        sl('Rim reflection reach (pixels)', 'RAIN_VISOR_LAYER_OPTICS_REFLECTION_PX', 0.0, 160.0, '%.1f px')
        ui.separator()
        ui.text('Optics inside the outline band (independent of the sharp rim)')
        ck('Outline band interior refraction', 'RAIN_VISOR_LAYER_OPTICS_INTERIOR')
        sl('Interior refraction (pixels)', 'RAIN_VISOR_LAYER_OPTICS_INTERIOR_PX', 0.0, 48.0, '%.2f px')
        sl('Interior normal influence', 'RAIN_VISOR_LAYER_OPTICS_INTERIOR_NORMAL', 0.0, 6.0, '%.2f')
        sl('Interior dome thickness (pixels)', 'RAIN_VISOR_LAYER_OPTICS_INTERIOR_BEND_PX', 0.0, 16.0, '%.2f px')
        sl('Interior hairline split (pixels)', 'RAIN_VISOR_LAYER_OPTICS_INTERIOR_SPLIT_PX', 0.0, 3.0, '%.2f px')
        sl('Interior blur radius (pixels)', 'RAIN_VISOR_LAYER_OPTICS_INTERIOR_BLUR_PX', 0.0, 12.0, '%.2f px')
        sl('Interior blur amount', 'RAIN_VISOR_LAYER_OPTICS_INTERIOR_BLUR_AMOUNT', 0.0, 1.0, '%.2f')
        sl('Interior soft defocus radius', 'RAIN_VISOR_LAYER_OPTICS_INTERIOR_SOFT_PX', 0.0, 24.0, '%.2f px')
        sl('Interior soft defocus amount', 'RAIN_VISOR_LAYER_OPTICS_INTERIOR_SOFT_AMOUNT', 0.0, 1.0, '%.2f')
    end
    if item.interior then
        ui.separator()
        ui.text('Interior light (shared by fabric and glass line)')
        ck('Helmet shadow (sun only through the opening)', 'RAIN_VISOR_LAYER_HELMET_SHADOW')
        sl('Shadow: sun-forward cos dark', 'RAIN_VISOR_LAYER_SHADOW_COS_LO', -1.0, 1.0, '%.2f')
        sl('Shadow: sun-forward cos lit', 'RAIN_VISOR_LAYER_SHADOW_COS_HI', -1.0, 1.0, '%.2f')
        sl('Interior ambient', 'RAIN_VISOR_LAYER_INTERIOR_AMBIENT', 0.0, 1.5, '%.2f')
        sl('Interior: sun bounce', 'RAIN_VISOR_LAYER_SUN_BOUNCE', 0.0, 1.0, '%.2f')
        sl('Interior: bounce kept in shadow', 'RAIN_VISOR_LAYER_BOUNCE_BASE', 0.0, 1.0, '%.2f')
        sl('Interior: light through opening', 'RAIN_VISOR_LAYER_OPENING', 0.0, 1.5, '%.2f')
        sl('Interior: sky chroma (0 neutral)', 'RAIN_VISOR_LAYER_INTERIOR_SKY_CHROMA', 0.0, 1.0, '%.2f')
    end
    ui.separator()
    ui.text('Shared lighting (all custom-shader meshes)')
    sl('Stack sun (x HDR light colour)', 'RAIN_VISOR_LAYER_SUN_HDR', 0.0, 3.0, '%.2f')
    sl('Ambient (x source-mean luminance)', 'RAIN_VISOR_LAYER_AMBIENT', 0.0, 2.0, '%.2f')
    sl('Ambient sky chroma', 'RAIN_VISOR_LAYER_AMBIENT_SAT', 0.0, 1.0, '%.2f')
    sl('Ambient floor (down faces)', 'RAIN_VISOR_LAYER_AMBIENT_FLOOR', 0.0, 1.0, '%.2f')
    sl('Ambient mip', 'RAIN_VISOR_LAYER_AMBIENT_MIP', 0.0, 10.0, '%.1f')
    ck('Normal maps: flip green', 'RAIN_VISOR_LAYER_NORMAL_FLIP_G')
    ck('Light direction flip (toward light = -lightDirection)', 'RAIN_VISOR_LAYER_LIGHT_FLIP')
    ui.text('(These settings are runtime values, like the RainFX tab; save them to the Lua defaults when final.)')
end
rainDynamicSceneCopyState.visorLayerEditor = function(meshName)
    for _, e in ipairs(MATERIAL_EDITORS or {}) do
        if e.meshName == meshName then return e end
    end
    return nil
end
-- Hide (or restore) every visor KN5 mesh in the normal scene pass.
-- s51: names of the meshes the overlay draws itself.
rainDynamicSceneCopyState.visorLayerDrawnSet = function()
    local vl = rainDynamicSceneCopyState.visorLayer
    if vl.drawnSet then return vl.drawnSet end
    local set = {}
    local defs = vl.defs or rainDynamicSceneCopyState.visorLayerDefs()
    for _, it in ipairs(defs.housing) do if it.mesh then set[it.mesh] = true end end
    for _, it in ipairs(defs.glass) do if it.mesh then set[it.mesh] = true end end
    vl.drawnSet = set
    return set
end
-- Hide (or restore) the overlay-drawn visor meshes in the scene pass.
-- s51: meshes the overlay does not draw always follow their Visible box.
rainDynamicSceneCopyState.visorLayerSceneHide = function(hide)
    local vl = rainDynamicSceneCopyState.visorLayer
    local drawn = rainDynamicSceneCopyState.visorLayerDrawnSet()
    for _, e in ipairs(MATERIAL_EDITORS or {}) do
        if e.targetMesh and #e.targetMesh > 0 then
            local hideThis = hide and drawn[e.meshName]
            e.targetMesh:setVisible((not hideThis) and e.visible or false, false)
        end
    end
    vl.hidden = hide
end
-- s51 mirror / main pass switching (render.on stages exist for both).
rainDynamicSceneCopyState.visorLayerPassSwitch = function(mirror)
    local r = cfg.RUNTIME
    if not (r.RAIN_VISOR_OVERLAY and r.RAIN_VISOR_LAYER and r.RAIN_VISOR_LAYER_MIRROR_STOCK) then
        return
    end
    local vl = rainDynamicSceneCopyState.visorLayer
    local drawn = rainDynamicSceneCopyState.visorLayerDrawnSet()
    for _, e in ipairs(MATERIAL_EDITORS or {}) do
        if drawn[e.meshName] and e.targetMesh and #e.targetMesh > 0 then
            e.targetMesh:setVisible(mirror and e.visible or false, false)
        end
    end
    if vl.probe then
        vl.probe:setVisible((not mirror) and r.RAIN_VISOR_LAYER_SHADOW_PROBE and true or false)
    end
end
if cfg.RUNTIME.RAIN_VISOR_OVERLAY and cfg.RUNTIME.RAIN_VISOR_LAYER_MIRROR_STOCK then
    render.on('mirror.track.opaque', function()
        pcall(rainDynamicSceneCopyState.visorLayerPassSwitch, true)
    end)
    render.on('main.track.opaque', function()
        pcall(rainDynamicSceneCopyState.visorLayerPassSwitch, false)
    end)
end
rainDynamicSceneCopyState.visorLayerDrawItem = function(item, ov)
    local r = cfg.RUNTIME
    local vl = rainDynamicSceneCopyState.visorLayer
    local e = rainDynamicSceneCopyState.visorLayerEditor(item.mesh)
    if not e or not e.targetMesh or #e.targetMesh == 0 or e.visible == false then
        return
    end
    local shader = vl.shader
    if not shader then return end
    local sim = ac.getSim()
    local lc = sim and sim.lightColor or rgb(1, 1, 1)
    local lmax = math.max(lc.r, lc.g, lc.b, 1e-3)
    local sun = rgb(lc.r / lmax, lc.g / lmax, lc.b / lmax)
        * (r.RAIN_VISOR_LAYER_SUN * math.min(1.0, lmax))
    if ov.hdr then
        -- s53 scene stack: real HDR light colour, toned by post-processing
        sun = rgb(lc.r, lc.g, lc.b) * r.RAIN_VISOR_LAYER_SUN_HDR
    end
    item.params = item.params or {
        mesh = e.targetMesh, transform = 'original', shader = shader,
        textures = { txLayerDiffuse = false, txLayerSource = false,
            txLayerNormal = false, txLayerMaps = false, txLayerOutline = false, txLayerLens = false, txLayerBand = false, txLayerBandUV = false,
            txLayerProbe = false },
        values = {},
    }
    local p = item.params
    p.mesh = e.targetMesh
    p.textures.txLayerDiffuse = item.tex or ov.src
    p.textures.txLayerSource = ov.src
    p.textures.txLayerNormal = item.nrm or ov.src
    p.textures.txLayerOutline = item.outline or ov.src
    p.textures.txLayerLens = item.lens or ov.src
    p.textures.txLayerBand = item.band or ov.src
    p.textures.txLayerBandUV = item.bandUV or ov.src
    p.textures.txLayerMaps = item.maps or ov.src
    local v = p.values
    local M = item.mat or 'FRAME'
    local function mr(key, def)
        local val = r['RAIN_VISOR_LAYER_' .. M .. '_' .. key]
        return val == nil and def or val
    end
    v.gLayerMat = M == 'FABRIC' and 2.0 or (M == 'RUBBER' and 1.0 or 0.0)
    v.gLayerUseNormal = item.nrm and 1.0 or 0.0
    v.gLayerUseMaps = item.maps and 1.0 or 0.0
    v.gLayerNormalFlipG = r.RAIN_VISOR_LAYER_NORMAL_FLIP_G and 1.0 or 0.0
    v.gLayerNormalStrength = item.kind == 1 and (r.RAIN_VISOR_LAYER_EXT_RELIEF or 1.0) or mr('NORMAL', 1.0)
    v.gLayerSpec = mr('SPEC', 0.0)
    v.gLayerGloss = mr('GLOSS', 0.5)
    v.gLayerSheen = mr('SHEEN', 0.0)
    v.gLayerSheenPower = mr('SHEEN_POWER', 3.0)
    v.gLayerHDR = ov.hdr and 1.0 or 0.0
    v.gLayerFabricLitLift = r.RAIN_VISOR_LAYER_FABRIC_LIT_LIFT or 0.6
    v.gLayerKind = item.kind or 0
    v.gLayerUseDiffuse = item.tex and 1.0 or 0.0
    local g = r.RAIN_VISOR_LAYER_BORDER_GREY
    v.gLayerColor = item.grey and rgb(g, g, g) or rgb(0.5, 0.5, 0.5)
    local ld = sim and sim.lightDirection or vec3(0, -1, 0)
    v.gLayerLightDir = r.RAIN_VISOR_LAYER_LIGHT_FLIP and vec3(-ld.x, -ld.y, -ld.z) or ld
    -- hemisphere chroma: luminance-normalised, desaturated toward grey
    local function chroma(c)
        c = c or rgb(1, 1, 1)
        local l = math.max(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b, 1e-4)
        local k = math.max(0.0, r.RAIN_VISOR_LAYER_AMBIENT_SAT)
        return rgb(1 + (c.r / l - 1) * k, 1 + (c.g / l - 1) * k, 1 + (c.b / l - 1) * k)
    end
    v.gLayerAmbSky = chroma(sim and sim.skyColor)
    v.gLayerAmbHorizon = chroma(sim and (sim.horizonColor or sim.fogColor))
    if item.interior then
        local k = math.max(0.0, r.RAIN_VISOR_LAYER_INTERIOR_SKY_CHROMA)
        local function toward(c)
            return rgb(1 + (c.r - 1) * k, 1 + (c.g - 1) * k, 1 + (c.b - 1) * k)
        end
        v.gLayerAmbSky = toward(v.gLayerAmbSky)
        v.gLayerAmbHorizon = toward(v.gLayerAmbHorizon)
    end
    v.gLayerAmbFloor = r.RAIN_VISOR_LAYER_AMBIENT_FLOOR
    local sunVis, ambK = 1.0, 1.0
    if item.interior and r.RAIN_VISOR_LAYER_HELMET_SHADOW and sim then
        local L = v.gLayerLightDir
        local f = sim.cameraLook
        local c = L.x * f.x + L.y * f.y + L.z * f.z
        local lo = r.RAIN_VISOR_LAYER_SHADOW_COS_LO
        local hi = math.max(r.RAIN_VISOR_LAYER_SHADOW_COS_HI, lo + 1e-3)
        local t = math.min(math.max((c - lo) / (hi - lo), 0.0), 1.0)
        sunVis = t * t * (3.0 - 2.0 * t)
        ambK = r.RAIN_VISOR_LAYER_INTERIOR_AMBIENT
    end
    v.gLayerSun = sun * sunVis
    v.gLayerAmbientGain = r.RAIN_VISOR_LAYER_AMBIENT * ambK
    if item.interior then
        local base = math.min(math.max(r.RAIN_VISOR_LAYER_BOUNCE_BASE, 0.0), 1.0)
        v.gLayerBounce = sun * (r.RAIN_VISOR_LAYER_SUN_BOUNCE
            * (base + (1.0 - base) * sunVis))
        v.gLayerBounceFrame = r.RAIN_VISOR_LAYER_OPENING
    else
        v.gLayerBounce = rgb(0, 0, 0)
        v.gLayerBounceFrame = 0.0
    end
    v.gLayerAmbientMip = r.RAIN_VISOR_LAYER_AMBIENT_MIP
    v.gLayerGlassAlpha = r.RAIN_VISOR_LAYER_GLASS_ALPHA
    v.gLayerOptics = (item.kind == 3 and r.RAIN_VISOR_LAYER_OPTICS) and 1.0 or 0.0
    v.gLayerOpticsNormal = r.RAIN_VISOR_LAYER_OPTICS_NORMAL
    v.gLayerOpticsRefractionPx = r.RAIN_VISOR_LAYER_OPTICS_REFRACTION_PX
    v.gLayerOpticsBlurPx = r.RAIN_VISOR_LAYER_OPTICS_BLUR_PX
    v.gLayerOpticsRimSharpness = r.RAIN_VISOR_LAYER_OPTICS_RIM_SHARPNESS
    v.gLayerOpticsRimPeak = r.RAIN_VISOR_LAYER_OPTICS_RIM_PEAK
    v.gLayerOpticsLensGain = r.RAIN_VISOR_LAYER_OPTICS_LENS_GAIN
    v.gLayerOpticsTransmissionLoss = r.RAIN_VISOR_LAYER_OPTICS_TRANSMISSION_LOSS
    v.gLayerOpticsReflection = r.RAIN_VISOR_LAYER_OPTICS_REFLECTION
    v.gLayerOpticsReflectionPx = r.RAIN_VISOR_LAYER_OPTICS_REFLECTION_PX
    v.gLayerOpticsMaskPreview = r.RAIN_VISOR_LAYER_OPTICS_MASK_PREVIEW and 1.0 or 0.0
    v.gLayerOpticsBrightness = r.RAIN_VISOR_LAYER_OPTICS_BRIGHTNESS
    v.gLayerOpticsReliefSpec = r.RAIN_VISOR_LAYER_OPTICS_RELIEF_SPEC
    v.gLayerOpticsReliefGloss = r.RAIN_VISOR_LAYER_OPTICS_RELIEF_GLOSS
    v.gLayerOpticsReliefShade = r.RAIN_VISOR_LAYER_OPTICS_RELIEF_SHADE
    v.gLayerOpticsInterior = r.RAIN_VISOR_LAYER_OPTICS_INTERIOR and 1.0 or 0.0
    v.gLayerOpticsInteriorPx = r.RAIN_VISOR_LAYER_OPTICS_INTERIOR_PX
    v.gLayerOpticsInteriorNormal = r.RAIN_VISOR_LAYER_OPTICS_INTERIOR_NORMAL
    v.gLayerOpticsInteriorBendPx = r.RAIN_VISOR_LAYER_OPTICS_INTERIOR_BEND_PX
    v.gLayerOpticsInteriorSplitPx = r.RAIN_VISOR_LAYER_OPTICS_INTERIOR_SPLIT_PX
    v.gLayerOpticsInteriorBlurPx = r.RAIN_VISOR_LAYER_OPTICS_INTERIOR_BLUR_PX
    v.gLayerOpticsInteriorBlurAmount = r.RAIN_VISOR_LAYER_OPTICS_INTERIOR_BLUR_AMOUNT
    v.gLayerOpticsInteriorSoftPx = r.RAIN_VISOR_LAYER_OPTICS_INTERIOR_SOFT_PX or 4.0
    v.gLayerOpticsInteriorSoftAmount = r.RAIN_VISOR_LAYER_OPTICS_INTERIOR_SOFT_AMOUNT or 1.0
    v.gLayerCameraSide = sim.cameraSide
    v.gLayerCameraUp = sim.cameraUp
    v.gLayerCameraLook = sim.cameraLook
    v.gLayerCameraTanFov = math.tan(math.rad(sim.cameraFOV or 60.0) * 0.5)
















    v.gLayerBandOpacity = item.kind == 3 and 0.0 or r.RAIN_VISOR_LAYER_BAND_OPACITY
    v.gLayerBandExternalLight = r.RAIN_VISOR_LAYER_BAND_EXTERNAL_LIGHT and 1.0 or 0.0
    v.gLayerBandUnlitBrightness = r.RAIN_VISOR_LAYER_BAND_UNLIT_BRIGHTNESS
    v.gLayerBandAlphaMin = r.RAIN_VISOR_LAYER_BAND_ALPHA_MIN or 0.90
    local probeOn = item.mat ~= nil
        and r.RAIN_VISOR_LAYER_SHADOW_PROBE and vl.probeReady and vl.probeCanvas ~= nil
    p.textures.txLayerProbe = probeOn and vl.probeCanvas or ov.src
    v.gLayerProbeOn = probeOn and 1.0 or 0.0
    v.gLayerInvShotSize = vec2(1.0 / math.max(ov.w or 1, 1), 1.0 / math.max(ov.h or 1, 1))
    v.gLayerProbeAlbedo = r.RAIN_VISOR_LAYER_PROBE_ALBEDO
    local lcH = sim and sim.lightColor or rgb(1, 1, 1)
    v.gLayerSunHDRLum = 0.2126 * lcH.r + 0.7152 * lcH.g + 0.0722 * lcH.b
    v.gLayerProbeGain = r.RAIN_VISOR_LAYER_PROBE_GAIN
    v.gLayerProbeStrength = r.RAIN_VISOR_LAYER_PROBE_STRENGTH
    v.gLayerProbeMinNL = r.RAIN_VISOR_LAYER_PROBE_MIN_NL
    v.gLayerProbeMaxDepth = r.RAIN_VISOR_LAYER_PROBE_MAX_DEPTH
    v.gLayerProbeDebug = (probeOn and r.RAIN_VISOR_LAYER_PROBE_DEBUG) and 1.0 or 0.0
    render.setCullMode(item.two and render.CullMode.None
        or (r.RAIN_VISOR_LAYER_CULL_FLIP and render.CullMode.Front
            or render.CullMode.Back))
    e.targetMesh:setVisible(true, false)
    local ok, err = pcall(render.mesh, p)
    e.targetMesh:setVisible(false, false)
    if not ok then vl.err = item.mesh .. ': ' .. tostring(err) end
end
-- s49 scene-shadow probe instance.
rainDynamicSceneCopyState.visorProbeEnsure = function()
    local vl = rainDynamicSceneCopyState.visorLayer
    if vl.probe ~= nil or vl.probeFailed then return vl.probe end
    if not axisRollNode then return nil end
    local ok, node = pcall(function()
        return axisRollNode:loadKN5({ filename = cfg.RUNTIME.MODEL_PATH,
            forceRenderableOn = true })
    end)
    if not ok or not node then
        vl.probeFailed = true
        vl.probeErr = tostring(node)
        return nil
    end
    pcall(function() node:ensureUniqueMaterials() end)
    local keep = {}
    for _, item in ipairs((vl.defs or rainDynamicSceneCopyState.visorLayerDefs()).housing) do
        keep[item.mesh] = true
    end
    local refs = {}
    for _, e in ipairs(MATERIAL_EDITORS or {}) do
        local ref = node:findMeshes(e.meshName)
        if ref and #ref > 0 then
            if keep[e.meshName] then
                refs[#refs + 1] = ref
                pcall(function()
                    ref:setMaterialTexture('txDiffuse', rgbm(1, 1, 1, 1))
                    ref:setMaterialTexture('txNormal', rgbm(0.5, 0.5, 1, 1))
                    ref:setMaterialProperty('ksAmbient', 0.0)
                    ref:setMaterialProperty('ksSpecular', 0.0)
                    ref:setMaterialProperty('ksEmissive', rgb(0, 0, 0))
                end)
                pcall(function() ref:setMaterialProperty('fresnelMaxLevel', 0.0) end)
                pcall(function() ref:setMaterialProperty('fresnelC', 0.0) end)
                pcall(function() ref:setMaterialProperty('ksSpecularEXP', 1.0) end)
                -- the probe must not cast its own shadows onto anything
                pcall(function() ref:setShadows(false) end)
            else
                ref:setVisible(false, false)
            end
        end
    end
    vl.probe, vl.probeRefs, vl.probeAlbedo = node, refs, nil
    return node
end
rainDynamicSceneCopyState.visorProbeSet = function(on)
    local r = cfg.RUNTIME
    local vl = rainDynamicSceneCopyState.visorLayer
    if not on then
        if vl.probe then vl.probe:setVisible(false) end
        return
    end
    local node = rainDynamicSceneCopyState.visorProbeEnsure()
    if not node then return end
    node:setVisible(true)
    if vl.probeAlbedo ~= r.RAIN_VISOR_LAYER_PROBE_ALBEDO then
        vl.probeAlbedo = r.RAIN_VISOR_LAYER_PROBE_ALBEDO
        for _, ref in ipairs(vl.probeRefs or {}) do
            pcall(function() ref:setMaterialProperty('ksDiffuse', vl.probeAlbedo) end)
        end
    end
end
-- Called in the drop callback (in-scene stage): copy the HDR frame with
-- linear depth so the overlay can read the probe's lit pixels.
rainDynamicSceneCopyState.visorProbeCopy = function(sim)
    local r = cfg.RUNTIME
    local vl = rainDynamicSceneCopyState.visorLayer
    if not (r.RAIN_VISOR_OVERLAY and r.RAIN_VISOR_LAYER and r.RAIN_VISOR_LAYER_SHADOW_PROBE)
        or not vl.probe then
        vl.probeReady = false
        return
    end
    local mw = math.max(64, rainDynamicSceneCopyState.mainTargetWidth or 1280)
    local mh = math.max(64, rainDynamicSceneCopyState.mainTargetHeight or 720)
    local w, h = math.floor(mw / 2), math.floor(mh / 2)
    if not vl.probeCanvas or vl.probeW ~= w or vl.probeH ~= h then
        if vl.probeCanvas then vl.probeCanvas:dispose() end
        vl.probeCanvas = ui.ExtraCanvas(vec2(w, h), 1, render.AntialiasingMode.None,
            render.TextureFormat.R16G16B16A16.Float)
        vl.probeCanvas:setName('RainFX visor shadow probe (HDR + depth)')
        vl.probeW, vl.probeH = w, h
    end
    local n = math.max(sim.cameraClipNear or 0.05, 0.001)
    local f = math.max(sim.cameraClipFar or 5000.0, n + 1.0)
    local ok = pcall(function()
        vl.probeCanvas:updateSceneWithShader({
            async = true,
            textures = { txInput = 'dynamic::hdr', txDepthIn = 'dynamic::depth' },
            values = { gN = n, gF = f,
                gReversed = r.RAIN_DYNAMIC_SHOT_TONE_FRAME_DEPTH_REVERSED and 1.0 or 0.0 },
            shader = [[
                float4 main(PS_IN pin)
                {
                    float3 c = txInput.SampleLevel(samLinearClamp, pin.Tex, 0.0).rgb;
                    float d = txDepthIn.SampleLevel(samLinearClamp, pin.Tex, 0.0).r;
                    if (gReversed > 0.5) d = 1.0 - d;
                    float lin = d > 0.99999 ? 10000.0
                        : gN * gF / max(gF - d * (gF - gN), 1e-4);
                    return float4(c, min(lin, 10000.0));
                }
            ]]
        })
    end)
    vl.probeReady = ok
end

-- s53 scene stack: called from the in-scene drop callback.
-- All inner optics use a stable copy AFTER rain colour, before lens draws.
-- Never sample the live render target or the pre-rain tone snapshot here.
rainDynamicSceneCopyState.visorOpticsCapture = function(w, h)
    local vl = rainDynamicSceneCopyState.visorLayer
    local r = cfg.RUNTIME
    local soft = r.RAIN_VISOR_LAYER_OPTICS and r.RAIN_VISOR_LAYER_OPTICS_INTERIOR
        and (r.RAIN_VISOR_LAYER_OPTICS_INTERIOR_SOFT_PX or 4.0) > 0
        and (r.RAIN_VISOR_LAYER_OPTICS_INTERIOR_SOFT_AMOUNT or 1.0) > 0
    local mips = soft and 6 or 1
    if not vl.opticsSource or vl.opticsW ~= w or vl.opticsH ~= h or vl.opticsMips ~= mips then
        if vl.opticsSource then vl.opticsSource:dispose() end
        vl.opticsSource = ui.ExtraCanvas(vec2(w, h), mips, render.AntialiasingMode.None,
            render.TextureFormat.R16G16B16A16.Float)
        vl.opticsSource:setName('Visor inner optics source (scene + rain)')
        vl.opticsW, vl.opticsH = w, h
        vl.opticsMips = mips
    end
    local ok, err = pcall(function()
        vl.opticsSource:copyFrom('dynamic::hdr')
        if mips > 1 and vl.opticsSource:mipsUpdate() == false then error('Optics MIP generation pending') end
    end)
    vl.opticsReady = ok
    if not ok then vl.err = 'post-rain optics capture: ' .. tostring(err); return nil end
    return vl.opticsSource
end
-- phase 'pre'  : housing (opaque, depth write) + glass items before rain
-- phase 'post' : glass items after rain (before the drop depth pass)
rainDynamicSceneCopyState.visorSceneStack = function(phase)
    local r = cfg.RUNTIME
    if not r.RAIN_VISOR_SCENE_STACK or r.RAIN_VISOR_OVERLAY then return end
    local vl = rainDynamicSceneCopyState.visorLayer
    if not vl.shader then
        for _, sh in ipairs(shaders) do
            if sh.ID == 'RAINFXVISORLAYER' and sh.LOADED then vl.shader = sh.HLSL end
        end
        if not vl.shader then vl.status = 'shader not loaded'; return end
    end
    vl.defs = vl.defs or rainDynamicSceneCopyState.visorLayerDefs()
    local st = rainDynamicSceneCopyState
    local src = (st.toneReady and st.toneCanvas) or st.geometryShot or 'dynamic::hdr'
    local sov = vl.sceneOv or {}
    vl.sceneOv = sov
    sov.src, sov.hdr = src, true
    sov.w = math.max(1, st.mainTargetWidth or 1280)
    sov.h = math.max(1, st.mainTargetHeight or 720)
    if phase == 'post' and r.RAIN_VISOR_LAYER_OPTICS then
        local opticsSource = rainDynamicSceneCopyState.visorOpticsCapture(sov.w, sov.h)
        if opticsSource then
            sov.src = opticsSource
        end
    end
    if phase == 'pre' then
        rainDynamicSceneCopyState.visorLayerSceneHide(true)
        render.setBlendMode(render.BlendMode.Opaque)
        render.setDepthMode(render.DepthMode.Normal)
        for _, item in ipairs(vl.defs.housing) do
            rainDynamicSceneCopyState.visorLayerDrawItem(item, sov)
        end
    end
    local afterRain = false
    for _, item in ipairs(vl.defs.glass) do
        if item.rain then
            afterRain = true
        elseif (phase == 'pre' and not afterRain) or (phase == 'post' and afterRain) then
            render.setBlendMode(render.BlendMode.BlendPremultiplied)
            render.setDepthMode(render.DepthMode.ReadOnly)
            if not (phase == 'post' and not vl.opticsReady and item.kind == 3 and r.RAIN_VISOR_LAYER_OPTICS) then
                rainDynamicSceneCopyState.visorLayerDrawItem(item, sov)
            end
        end
    end
    -- state the rain draw / depth pass expect
    render.setBlendMode(render.BlendMode.BlendAccurate)
    render.setDepthMode(render.DepthMode.ReadOnly)
    render.setCullMode(render.CullMode.None)
    vl.status = 'scene stack drawn'
end

-- Called inside the overlay GeometryShot transparent callback.
rainDynamicSceneCopyState.visorLayerDraw = function(ov)
    local vl = rainDynamicSceneCopyState.visorLayer
    if not vl.shader then
        for _, sh in ipairs(shaders) do
            if sh.ID == 'RAINFXVISORLAYER' and sh.LOADED then vl.shader = sh.HLSL end
        end
    end
    vl.defs = vl.defs or rainDynamicSceneCopyState.visorLayerDefs()
    -- 1. housing: opaque, depth write
    render.setBlendMode(render.BlendMode.Opaque)
    render.setDepthMode(render.DepthMode.Normal)
    for _, item in ipairs(vl.defs.housing) do
        rainDynamicSceneCopyState.visorLayerDrawItem(item, ov)
    end
    -- 2. glass back to front: premultiplied, depth read-only
    for _, item in ipairs(vl.defs.glass) do
        render.setBlendMode(render.BlendMode.BlendPremultiplied)
        render.setDepthMode(render.DepthMode.ReadOnly)
        if item.rain then
            local p = ov.drawParams
            if p then
                render.setCullMode(render.CullMode.None)
                rainDynamicSurfaceMesh:setVisible(true, false)
                local okDraw, res = pcall(render.mesh, p)
                rainDynamicSurfaceMesh:setVisible(false, false)
                ov.drawn = okDraw and res and true or false
                if not okDraw then ov.err = tostring(res) end
            end
        else
            rainDynamicSceneCopyState.visorLayerDrawItem(item, ov)
        end
    end
    vl.status = vl.shader and 'drawn' or 'shader not loaded'
end

-- HUD lift: windows moved to a redirect layer, drawn above the overlay.
-- Lua IMGUI windows (names starting with "IMGUI") are drawn after our
-- callback already and keep mouse input, so they are skipped by default.
rainDynamicSceneCopyState.hudLift = { lifted = {}, skip = {}, nextScan = 0 }
rainDynamicSceneCopyState.hudLiftRelease = function()
    local hl = rainDynamicSceneCopyState.hudLift
    for name in pairs(hl.lifted) do
        pcall(function()
            local a = ac.accessAppWindow(name)
            if a and a:valid() then a:setRedirectLayer(0) end
        end)
    end
    hl.lifted = {}
end
ac.onRelease(function()
    rainDynamicSceneCopyState.hudLiftRelease()
    if rainDynamicSceneCopyState.visorLayer.hidden then
        pcall(rainDynamicSceneCopyState.visorLayerSceneHide, false)
    end
end)
rainDynamicSceneCopyState.hudLiftUpdate = function()
    local r = cfg.RUNTIME
    local hl = rainDynamicSceneCopyState.hudLift
    local layer = math.max(1, math.floor(r.RAIN_VISOR_OVERLAY_HUD_LAYER))
    if hl.layer and hl.layer ~= layer then
        rainDynamicSceneCopyState.hudLiftRelease()
    end
    hl.layer = layer
    local now = os.clock()
    if now >= hl.nextScan then
        hl.nextScan = now + 1.0
        local okList, list = pcall(ac.getAppWindows)
        hl.windows = okList and list or {}
        for _, wnd in ipairs(hl.windows) do
            local name = wnd.name
            if hl.skip[name] == nil then
                hl.skip[name] = name:sub(1, 5) == 'IMGUI'
            end
            -- Never lift our own window (it must keep mouse input).
            local own = (tostring(wnd.title):lower():find('real visor', 1, true)
                or name:lower():find('realvisor', 1, true)
                or name:lower():find('real visor', 1, true)) ~= nil
            if own then hl.skip[name] = true end
            local want = wnd.visible and not hl.skip[name] and not own
            local is = hl.lifted[name] ~= nil
            -- s41: redirect only on change (s40 also re-applied when the
            -- reported layer differed, every second: periodic flicker).
            if want and not is then
                pcall(function()
                    local a = ac.accessAppWindow(name)
                    if a and a:valid() then
                        a:setRedirectLayer(layer)
                        hl.lifted[name] = true
                        hl.settle = 2
                    end
                end)
            elseif not want and is then
                pcall(function()
                    local a = ac.accessAppWindow(name)
                    if a and a:valid() then a:setRedirectLayer(0) end
                end)
                hl.lifted[name] = nil
                hl.settle = 2
            end
        end
    end
    -- Layer content may be stale/uninitialised right after a redirect.
    if (hl.settle or 0) > 0 then
        hl.settle = hl.settle - 1
        hl.status = 'settling'
        return
    end
    local size = ui.windowSize()
    local okDraw = pcall(function()
        ui.renderShader({
            p1 = vec2(0, 0), p2 = size,
            blendMode = r.RAIN_VISOR_OVERLAY_HUD_PREMULTIPLIED
                and render.BlendMode.BlendPremultiplied
                or render.BlendMode.AlphaBlend,
            textures = { txHud = 'dynamic::hud::redirected::' .. tostring(layer) },
            shader = [[
                float4 main(PS_IN pin)
                {
                    return txHud.SampleLevel(samLinearClamp, pin.Tex, 0.0);
                }
            ]]
        })
    end)
    hl.status = okDraw and 'ok' or 'FAIL'
end

-- ui.onExclusiveHUD holds ONE callback: the P0 probe callback below calls
-- this first.
rainDynamicSceneCopyState.rainOverlayHud = function(mode)
    local r = cfg.RUNTIME
    local ov = rainDynamicSceneCopyState.overlay
    local overlayLayer = r.RAIN_VISOR_OVERLAY and r.RAIN_VISOR_LAYER
    -- the scene stack is drawn from the drop callback, which needs the rain
    -- pipeline; without it the KN5 meshes fall back to their Visible boxes.
    local wantHide = overlayLayer or (r.RAIN_VISOR_SCENE_STACK
        and r.RAIN_ENABLED and r.RAIN_DYNAMIC_SURFACE_STATE_ENABLED)
    pcall(rainDynamicSceneCopyState.visorProbeSet,
        overlayLayer and r.RAIN_VISOR_LAYER_SHADOW_PROBE and true or false)
    if wantHide then
        -- every frame: other code (editors, profiles) may set visibility
        rainDynamicSceneCopyState.visorLayerSceneHide(true)
    elseif rainDynamicSceneCopyState.visorLayer.hidden then
        rainDynamicSceneCopyState.visorLayerSceneHide(false)
    end
    if not r.RAIN_VISOR_OVERLAY then
        if next(rainDynamicSceneCopyState.hudLift.lifted) then
            rainDynamicSceneCopyState.hudLiftRelease()
        end
        if ov.shot then ov.shot:dispose(); ov.shot = nil end
        if ov.src then ov.src:dispose(); ov.src = nil end
        ov.status = 'off'
        return
    end
    if not r.RAIN_ENABLED or not r.RAIN_DYNAMIC_SURFACE_STATE_ENABLED then return end
    local sim = ac.getSim()
    if not sim then return end
    local mw = math.max(64, rainDynamicSceneCopyState.mainTargetWidth or 1280)
    local mh = math.max(64, rainDynamicSceneCopyState.mainTargetHeight or 720)
    local ws = ui.windowSize()
    local t = math.min(math.max(r.RAIN_VISOR_OVERLAY_RES_SCALE or 1.0, 0.0), 1.0)
    local w = math.floor(mw + (math.max(ws.x, 64) - mw) * t + 0.5)
    local h = math.floor(mh + (math.max(ws.y, 64) - mh) * t + 0.5)
    rainDynamicSceneCopyState.rainOverlayEnsure(ov, w, h)
    -- 1. Source = the final frame of THIS frame, before our overlay.
    local okSrc = pcall(function()
        ov.src:updateWithShader({
            textures = { txInput = 'dynamic::screen' },
            shader = [[
                float4 main(PS_IN pin)
                {
                    return float4(txInput.SampleLevel(samLinearClamp,
                        pin.Tex, 0.0).rgb, 1.0);
                }
            ]]
        })
        ov.src:mipsUpdate()
    end)
    -- 2. Render the visor layer now (fallback: next sceneReady).
    if not ov.hudUpdateFailed then
        if not rainDynamicSceneCopyState.rainOverlayRender(ov, sim) then ov.hudUpdateFailed = true end
    end
    -- 3. Composite over the final frame.
    local size = ui.windowSize()
    local okComp = pcall(function()
        local premul = r.RAIN_VISOR_LAYER
        ui.renderShader({
            p1 = vec2(0, 0), p2 = size,
            blendMode = premul and render.BlendMode.BlendPremultiplied
                or render.BlendMode.AlphaBlend,
            textures = { txOverlay = ov.shot },
            values = { gDebugAlpha = r.RAIN_VISOR_OVERLAY_DEBUG_ALPHA and 1.0 or 0.0 },
            shader = [[
                float4 main(PS_IN pin)
                {
                    float4 c = txOverlay.SampleLevel(samLinearClamp, pin.Tex, 0.0);
                    if (gDebugAlpha > 0.5)
                        return float4(c.aaa, 1.0);
                    return float4(saturate(c.rgb), saturate(c.a));
                }
            ]]
        })
    end)
    if r.RAIN_VISOR_OVERLAY_HUD_LIFT then
        rainDynamicSceneCopyState.hudLiftUpdate()
    elseif next(rainDynamicSceneCopyState.hudLift.lifted) then
        rainDynamicSceneCopyState.hudLiftRelease()
    end
    ov.status = string.format('src %s  render %s  composite %s  drawn %s',
        okSrc and 'ok' or 'FAIL',
        ov.hudUpdateFailed and 'sceneReady (1 frame late)' or 'HUD',
        okComp and 'ok' or 'FAIL', tostring(ov.drawn))
end

-- Overlay probe P0 (docs/RAINFX_POST_OVERLAY.md). Verifies:
--  1. a GeometryShot with a custom transparent callback can run our
--     render.mesh (custom shader, SceneReference, setVisible trick);
--  2. what dynamic::screen holds at UI time (current final frame? does it
--     contain what we draw in the HUD -> feedback?);
--  3. full-screen coverage / alignment of ui.onExclusiveHUD drawing.
rainDynamicSceneCopyState.overlayProbe = { status = 'off' }
render.onSceneReady(function()
    local r = cfg.RUNTIME
    local op = rainDynamicSceneCopyState.overlayProbe
    if not r.RAIN_VISOR_OVERLAY_PROBE then
        if op.shot then op.shot:dispose(); op.shot = nil end
        op.status = 'off'
        return
    end
    local sim = ac.getSim()
    local params = rainDynamicSceneCopyState.lastDropMeshParams
    if not sim or not params then op.status = 'waiting for drop params'; return end
    local w = math.max(64, rainDynamicSceneCopyState.mainTargetWidth or 1280)
    local h = math.max(64, rainDynamicSceneCopyState.mainTargetHeight or 720)
    if not op.shot or op.w ~= w or op.h ~= h then
        if op.shot then op.shot:dispose() end
        op.calls, op.drawn = 0, 0
        op.shot = ac.GeometryShot({
            transparent = function()
                local p = rainDynamicSceneCopyState.lastDropMeshParams
                if not p then return end
                op.calls = (op.calls or 0) + 1
                rainDynamicSurfaceMesh:setVisible(true, false)
                render.setBlendMode(render.BlendMode.AlphaBlend)
                render.setCullMode(render.CullMode.None)
                render.setDepthMode(render.DepthMode.Off)
                local okDraw, res = pcall(render.mesh, p)
                rainDynamicSurfaceMesh:setVisible(false, false)
                if okDraw and res then op.drawn = (op.drawn or 0) + 1 end
                if not okDraw then op.err = tostring(res) end
            end,
        }, vec2(w, h), 1, false, render.AntialiasingMode.None,
            render.TextureFormat.R16G16B16A16.Float)
        op.shot:setName('RainFX overlay probe')
        pcall(function() op.shot:setSky(false) end)
        pcall(function() op.shot:setParticles(false) end)
        pcall(function() op.shot:setClearColor(rgbm(0, 0, 0, 0)) end)
        op.w, op.h = w, h
    end
    pcall(function() op.shot:setClippingPlanes(
        math.max(sim.cameraClipNear or 0.05, 0.001), sim.cameraClipFar) end)
    local ok, res = pcall(function()
        return op.shot:update(sim.cameraPosition, sim.cameraLook,
            sim.cameraUp, sim.cameraFOV)
    end)
    op.status = ok and string.format('ok  callback calls %d  mesh drawn %d',
        op.calls or 0, op.drawn or 0) or ('FAIL ' .. tostring(res))
end)
ui.onExclusiveHUD(function(mode)
    local okHud, errHud = pcall(rainDynamicSceneCopyState.rainOverlayHud, mode)
    if not okHud then rainDynamicSceneCopyState.overlay.err = tostring(errHud) end
    local r = cfg.RUNTIME
    local op = rainDynamicSceneCopyState.overlayProbe
    if not r.RAIN_VISOR_OVERLAY_PROBE or not op.shot then return end
    -- 2: snapshot of dynamic::screen at HUD time, BEFORE our overlay draw.
    local okCopy = pcall(function()
        local sw = 320
        local sh = math.floor(sw * (op.h or 9) / math.max(op.w or 16, 1))
        if not op.screenCopy or op.scW ~= sw or op.scH ~= sh then
            if op.screenCopy then op.screenCopy:dispose() end
            op.screenCopy = ui.ExtraCanvas(vec2(sw, sh), 1,
                render.AntialiasingMode.None, render.TextureFormat.R8G8B8A8.UNorm)
            op.scW, op.scH = sw, sh
        end
        op.screenCopy:updateWithShader({
            textures = { txInput = 'dynamic::screen' },
            shader = [[
                float4 main(PS_IN pin)
                {
                    return float4(txInput.SampleLevel(samLinearClamp,
                        pin.Tex, 0.0).rgb, 1.0);
                }
            ]]
        })
    end)
    op.screenCopyOk = okCopy
    if r.RAIN_VISOR_OVERLAY_PROBE_FULLSCREEN then
        -- 3: full-screen, premultiplied-ish alpha over the final frame.
        local size = ui.windowSize()
        ui.drawImage(op.shot, vec2(0, 0), size)
        op.hudSize = size
    end
end)

-- Stage probe (docs/RAINFX_STAGE_PROBE.md). Registered before the drop
-- draw callback: inside the drop stage it captures the frame BEFORE drops.
rainDynamicSceneCopyState.probeStages = {
    'main.track.opaque', 'main.root.opaque', 'main.track.transparent',
    'main.root.transparent', 'main.smoke',
}
rainDynamicSceneCopyState.probe = {}
rainDynamicSceneCopyState.probeCapture = function(stage, inScene)
    local st = rainDynamicSceneCopyState
    local r = cfg.RUNTIME
    if not r.RAIN_DYNAMIC_STAGE_PROBE then return end
    local sim = ac.getSim()
    local frame = sim and sim.frame or 0
    if st.probeFrame ~= frame then
        st.probeFrame, st.probeSeq = frame, 0
    end
    st.probeSeq = (st.probeSeq or 0) + 1
    local p = st.probe[stage]
    local w = math.max(64, math.floor(r.RAIN_DYNAMIC_STAGE_PROBE_WIDTH))
    local src = r.RAIN_DYNAMIC_STAGE_PROBE_SOURCE
    local aspect = sim and sim.windowHeight and sim.windowWidth
        and sim.windowWidth > 0 and sim.windowHeight / sim.windowWidth or 0.5625
    local h = math.max(36, math.floor(w * aspect))
    if not p or p.w ~= w or p.h ~= h then
        if p and p.canvas then p.canvas:dispose() end
        p = { w = w, h = h, canvas = ui.ExtraCanvas(vec2(w, h), 1,
            render.AntialiasingMode.None, render.TextureFormat.R8G8B8A8.UNorm) }
        st.probe[stage] = p
    end
    local params = {
        async = true,
        textures = { txInput = src == 3 and 'dynamic::depth'
            or (src == 2 and 'dynamic::screen' or 'dynamic::hdr') },
        values = { gMode = src, gExposure = r.RAIN_DYNAMIC_STAGE_PROBE_EXPOSURE },
        shader = [[
            float4 main(PS_IN pin)
            {
                float4 c = txInput.SampleLevel(samLinearClamp, pin.Tex, 0.0);
                if (gMode > 2.5)
                {
                    // Non-linear depth: far = black, near = white.
                    float d = saturate((1.0 - c.r) * 50.0 * gExposure);
                    return float4(d, d, d, 1.0);
                }
                float3 x = c.rgb * gExposure;
                if (gMode < 1.5)
                    x = sqrt(x / (1.0 + x));   // HDR -> displayable
                return float4(saturate(x), 1.0);
            }
        ]]
    }
    local ok, res = pcall(function()
        if inScene then return p.canvas:updateSceneWithShader(params) end
        return p.canvas:updateWithShader(params)
    end)
    p.ok = ok and res ~= false
    p.err = not ok and tostring(res) or nil
    p.order, p.frame = st.probeSeq, frame
end
-- Diagnostic capture must be registered before the rain draw for source order.
-- It is opt-in at Lua load; no probe callbacks run in the release default.
if cfg.RUNTIME.RAIN_DYNAMIC_STAGE_PROBE then
    for _, stage in ipairs(rainDynamicSceneCopyState.probeStages) do
        render.on(stage, function()
            rainDynamicSceneCopyState.probeCapture(stage, true)
        end)
    end
    render.onSceneReady(function()
        rainDynamicSceneCopyState.probeCapture('sceneReady (prev frame)', false)
    end)
end

render.on(cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG
    and 'main.smoke'
    or (cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_TRACK
        and 'main.track.transparent'
        or 'main.root.transparent'), function()
    if not cfg.RUNTIME.RAIN_ENABLED
        or not cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_STATE_ENABLED
    then
        return
    end

    local sim = ac.getSim()
    if not sim then
        return
    end
    if cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG
        and rainDynamicSceneCopyState.lastSmokeDrawFrame == sim.frame
    then
        return
    end

    if not rainDynamicRootCallbackLogged then
        ac.log(
            appNameDebug
            .. ' Dynamic drop Stage 4B.2 callback entered'
        )
        rainDynamicRootCallbackLogged = true
    end

    -- scene-ready prepares GPU state and transport before this draw.
    if rainDynamicSceneCopyState.preparedFrame ~= sim.frame then
        if not rainDynamicSceneCopyState.prepareWaitLogged then
            ac.warn(appNameDebug .. ' Dynamic drop waiting for scene-ready '
                .. 'GPU and surface preparation')
            rainDynamicSceneCopyState.prepareWaitLogged = true
        end
        return
    end
    rainDynamicSceneCopyState.prepareWaitLogged = false

    local rainDynamicDropShader = nil
    for _, shader in ipairs(shaders) do
        if shader.ID == 'RAINFXDYNAMICDROP'
            and shader.LOADED then
            rainDynamicDropShader = shader
            break
        end
    end

    if not rainDynamicDropShader then
        if not rainDynamicSceneCopyState.shaderWaitLogged then
            ac.warn(appNameDebug .. ' Dynamic drop shader waiting for load')
            rainDynamicSceneCopyState.shaderWaitLogged = true
        end
        return
    end
    if rainDynamicSceneCopyState.shaderWaitLogged then
        ac.log(appNameDebug .. ' Dynamic drop shader ready')
        rainDynamicSceneCopyState.shaderWaitLogged = false
    end

    updateRainDynamicStateRenderClock(sim)
    requestRainDynamicStateReadback()
    if rainDynamicSurfaceMeshCount > 0 then
        applyRainDynamicStateToSurfaceMesh()
    end

    if cfg.RUNTIME.RAIN_DYNAMIC_DROP_SCREEN_UV_PREPASS then
        local copyWidth = math.max(1, math.floor((sim.windowWidth or 1) * 0.5 + 0.5))
        local copyHeight = math.max(1, math.floor((sim.windowHeight or 1) * 0.5 + 0.5))
        if not rainDynamicSceneCopyState.canvas
            or rainDynamicSceneCopyState.width ~= copyWidth
            or rainDynamicSceneCopyState.height ~= copyHeight
        then
            if rainDynamicSceneCopyState.canvas then
                rainDynamicSceneCopyState.canvas:dispose()
            end
            rainDynamicSceneCopyState.canvas = ui.ExtraCanvas(
                vec2(copyWidth, copyHeight),
                1,
                render.AntialiasingMode.None,
                render.TextureFormat.R16G16B16A16.Float
            )
            rainDynamicSceneCopyState.width = copyWidth
            rainDynamicSceneCopyState.height = copyHeight
            rainDynamicSceneCopyState.readyLogged = false
        end

        local copyReady = rainDynamicSceneCopyState.canvas:updateSceneWithShader({
            async = true,
            textures = { txInput = 'dynamic::hdr' },
            shader = [[
float4 main(PS_IN pin)
{
    return txInput.SampleLevel(samLinearClamp, pin.Tex, 0.0);
}
]],
        })
        if not copyReady then return end
        if not rainDynamicSceneCopyState.readyLogged then
            ac.log(appNameDebug .. ' Dynamic HDR diagnostic prepass ready')
            rainDynamicSceneCopyState.readyLogged = true
        end
    end

    if cfg.RUNTIME.RAIN_DYNAMIC_DROP_SPARSE_FRAME_DEBUG
        and sim.frame % 4 ~= 0
    then
        return
    end

    if cfg.RUNTIME.RAIN_DYNAMIC_DROP_GEOMETRY_SHOT_DEBUG
        and (not rainDynamicSceneCopyState.geometryShot
            or rainDynamicSceneCopyState.shotFrame ~= sim.frame)
    then
        if not rainDynamicSceneCopyState.shotDrawWaitLogged then
            ac.warn(appNameDebug .. ' Dynamic drop waiting for current '
                .. 'scene-ready shot')
            rainDynamicSceneCopyState.shotDrawWaitLogged = true
        end
        return
    end
    rainDynamicSceneCopyState.shotDrawWaitLogged = false

    render.setBlendMode(
        cfg.RUNTIME.RAIN_DYNAMIC_DROP_UV_DEBUG
        and render.BlendMode.AlphaBlend
        or render.BlendMode.BlendAccurate
    )
    render.setCullMode(render.CullMode.None)

    -- Diagnostic contract:
    -- With UV debug enabled this draw ignores scene depth and must show the
    -- RG quad-UV gradient from both normal directions if this callback is the
    -- final visible custom-shader path.
    render.setDepthMode(
        (cfg.RUNTIME.RAIN_DYNAMIC_DROP_UV_DEBUG
            or cfg.RUNTIME.RAIN_DYNAMIC_DROP_DEPTH_OFF)
        and render.DepthMode.Off
        or render.DepthMode.ReadOnly
    )

    local dynamicRenderTargetSize = render.getRenderTargetSize()
    if dynamicRenderTargetSize.x > 64 and dynamicRenderTargetSize.y > 64 then
        rainDynamicSceneCopyState.mainTargetWidth =
            math.floor(dynamicRenderTargetSize.x)
        rainDynamicSceneCopyState.mainTargetHeight =
            math.floor(dynamicRenderTargetSize.y)
    end

    -- Visibility-gated manual draw test:
    -- keep the attached mesh hidden between callbacks so the ordinary scene
    -- pass cannot render its black fallback material. Enable it only while
    -- render.mesh() consumes the SceneReference, then hide it again.
    -- (Legacy optical wave test removed 2026-10-02: its uniforms were no
    -- longer read by the shader. docs/RAINFX_WATER_FIELD.md §10.)
    rainDynamicSurfaceMesh:setVisible(true, false)

    if not rainDynamicManualPreDrawLogged then
        local dynamicHDRSize = ui.imageSize('dynamic::hdr')
        ac.log(
            appNameDebug
            .. ' Dynamic drop Stage 4B.2 pre-draw: uvDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_UV_DEBUG)
            .. ' prepass='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_SCREEN_UV_PREPASS)
            .. ' drawStage='
            .. (cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG
                and 'smoke' or (cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_TRACK
                    and 'track' or 'root'))
            .. ' sparseFrame='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_SPARSE_FRAME_DEBUG)
            .. ' hdrSnapshot='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_HDR_SNAPSHOT_DEBUG)
            .. ' geometryShot='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_GEOMETRY_SHOT_DEBUG)
            .. ' shotYebis='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_SHOT_YEBIS_DEBUG)
            .. ' shotDepthDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_SKY_DEPTH_DEBUG)
            .. ' skyFogColorDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_SKY_FOG_COLOR_DEBUG)
            .. ' skyCloudDetailDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_SKY_CLOUD_DETAIL_DEBUG)
            .. ' screenSourceCompareDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_SCREEN_SOURCE_COMPARE_DEBUG)
            .. ' weatherScreenFrame='
            .. tostring(rainDynamicSceneCopyState.weatherFrame)
            .. ' fogColor='
            .. tostring(sim.fogColor)
            .. ' whiteReferencePoint='
            .. tostring(sim.whiteReferencePoint)
            .. ' postProcessing='
            .. tostring(sim.isPostProcessingActive)
            .. ' windowSize='
            .. tostring(sim.windowWidth) .. 'x' .. tostring(sim.windowHeight)
            .. ' targetSize='
            .. tostring(dynamicRenderTargetSize.x) .. 'x'
            .. tostring(dynamicRenderTargetSize.y)
            .. ' hdrSize='
            .. tostring(dynamicHDRSize.x) .. 'x'
            .. tostring(dynamicHDRSize.y)
            .. ' snapshotSize='
            .. tostring(rainDynamicSceneCopyState.width) .. 'x'
            .. tostring(rainDynamicSceneCopyState.height)
            .. ' earlyCaptureFrame='
            .. tostring(rainDynamicSceneCopyState.captureFrame)
            .. ' shotFrame='
            .. tostring(rainDynamicSceneCopyState.shotFrame)
            .. ' drawFrame='
            .. tostring(sim.frame)
            .. ' shaderBytes='
            .. tostring(#rainDynamicDropShader.HLSL)
        )
        rainDynamicManualPreDrawLogged = true
    end

    -- Fog tone for veils / glints / flashes: fog colour with its chroma
    -- reduced (luminance kept). The raw fog colour read far too blue.
    do
        local f = sim.fogColor
        local l = f.r * 0.2126 + f.g * 0.7152 + f.b * 0.0722
        local k = math.max(0.0, cfg.RUNTIME.RAIN_DYNAMIC_FOG_TONE_SATURATION)
        rainDynamicSceneCopyState.fogTone = rgb(l + (f.r - l) * k,
            l + (f.g - l) * k, l + (f.b - l) * k)
    end
    rainDynamicSceneCopyState.shotToneUpdate(sim)
    pcall(rainDynamicSceneCopyState.visorProbeCopy, sim)
    local dropMeshParams = {
        mesh = rainDynamicSurfaceMesh,
        transform = 'original',
        textures = {
            txDynamicSnapshot = (rainDynamicSceneCopyState.toneReady
                    and rainDynamicSceneCopyState.toneCanvas)
                or rainDynamicSceneCopyState.geometryShot
                or rainDynamicSceneCopyState.canvas
                or 'dynamic::hdr',
            txDynamicShotDepth =
                rainDynamicSceneCopyState.shotWithDepth
                and rainDynamicSceneCopyState.geometryShot
                and rainDynamicSceneCopyState.geometryShot:depth()
                or false,
            -- Shared slot: the smear mask texture takes it when loaded
            -- (only the screen-source compare debug reads it otherwise;
            -- a 12th texture binding is avoided, see RAINFX_HAZE.md).
            txDynamicWeatherScreen =
                (cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_ENABLED
                    and cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_USE_TEXTURE
                    and rainDynamicSceneCopyState.smearTexturePath)
                or rainDynamicSceneCopyState.weatherScreenCanvas
                or 'dynamic::screen',
            txDynamicMicroPattern =
                rainDynamicSceneCopyState.microPatternCanvas or false,
            txDynamicTrailMask =
                rainDynamicSceneCopyState.trailMaskRead or false,
            txDynamicBirthMask =
                rainDynamicSceneCopyState.birthMaskRead or false,
            txDynamicWaterTrail =
                rainDynamicSceneCopyState.waterTrailComposite
                or rainDynamicSceneCopyState.waterTrailRead or false,
        },
        values = {
            gDynamicDropWeatherFogColor =
                rainDynamicSceneCopyState.fogTone or sim.fogColor,
            gDynamicDropLDR = 0.0,
            gDynamicDropMipBias = 0.0,
            gDynamicDropPremulOut = 0.0,
            gDynamicDropLdrFogMip = cfg.RUNTIME.RAIN_VISOR_OVERLAY_FOG_MIP,
            gDynamicDropLdrFogSat = math.max(0.0,
                cfg.RUNTIME.RAIN_DYNAMIC_FOG_TONE_SATURATION or 1.0),

            gDynamicDropInvScreenSize = vec2(
                1.0 / math.max(sim.windowWidth or 1, 1),
                1.0 / math.max(sim.windowHeight or 1, 1)
            ),

            gDynamicDropInvRenderTargetSize = vec2(
                1.0 / math.max(dynamicRenderTargetSize.x, 1),
                1.0 / math.max(dynamicRenderTargetSize.y, 1)
            ),

            gDynamicDropMicroPatternEnabled =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_ENABLED
                and rainDynamicSceneCopyState.microPatternReady
                and 1.0 or 0.0,
            gDynamicDropMicroDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_DEBUG and 1.0 or 0.0,
            gDynamicDropMicroRain = math.max(0.0, math.min(1.0,
                cfg.RUNTIME.RAIN_GPU_STATE_RAIN_OVERRIDE >= 0.0
                    and cfg.RUNTIME.RAIN_GPU_STATE_RAIN_OVERRIDE
                    or sim.rainIntensity or 0.0))
                ^ cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RAIN_POWER,
            gDynamicDropMicroPatternGrid =
                rainDynamicSceneCopyState.microPatternGrid or 1,
            gDynamicDropMicroRadiusMin =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MIN,
            gDynamicDropMicroRadiusMax =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MAX,
            gDynamicDropMicroOutlineDark =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_OUTLINE_DARK,
            gDynamicDropMicroWaterLensRefraction =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_WATER_LENS_REFRACTION,
            gDynamicDropMicroWaterLensSlope =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_WATER_LENS_SLOPE,
            gDynamicDropWFKernelScale =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_KERNEL_SCALE,
            gDynamicDropCameraSide = sim.cameraSide,
            gDynamicDropCameraUp = sim.cameraUp,
            gDynamicDropBirthSkyCorrection =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SKY_CORRECTION
                and rainDynamicSceneCopyState.shotWithDepth
                and not rainDynamicSceneCopyState.toneReady
                and 1.0 or 0.0,
            gDynamicDropTrailMaskDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_ENABLED
                and cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_DEBUG
                and rainDynamicSceneCopyState.trailMaskRead
                and 1.0 or 0.0,
            gDynamicDropTrailMaskWipeEnabled =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_ENABLED
                and cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_WIPE_ENABLED
                and rainDynamicSceneCopyState.trailMaskRead
                and 1.0 or 0.0,
            gDynamicDropTrailMaskWipeStrength =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_WIPE_STRENGTH,
            gDynamicDropTrailFilmEnabled =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_ENABLED
                and cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_ENABLED
                and rainDynamicSceneCopyState.trailMaskRead
                and 1.0 or 0.0,
            gDynamicDropTrailSkyCorrection =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SKY_CORRECTION
                and rainDynamicSceneCopyState.shotWithDepth
                and not rainDynamicSceneCopyState.toneReady
                and 1.0 or 0.0,
            gDynamicDropTrailFilmOpacity =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_OPACITY,
            gDynamicDropTrailFilmPixels =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_PIXELS,
            gDynamicDropTrailFilmAgeExp =
                math.max(cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SECONDS, 0.05)
                / math.max(cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_SECONDS or 1.0, 0.05),
            gDynamicDropTrailRidgeEnabled =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_ENABLED
                and cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_ENABLED
                and rainDynamicSceneCopyState.trailMaskRead
                and 1.0 or 0.0,
            gDynamicDropTrailRidgeOpacity =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_OPACITY,
            gDynamicDropTrailRidgePixels =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_PIXELS,
            gDynamicDropMicroOpacity =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_OPACITY,
            gDynamicDropWaterField =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED
                and cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_ENABLED
                and rainDynamicSceneCopyState.birthMaskRead
                and 1.0 or 0.0,
            gDynamicDropWFTrail =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED
                and rainDynamicSceneCopyState.waterTrailReady
                and rainDynamicSceneCopyState.waterTrailRead
                and 1.0 or 0.0,
            gDynamicDropWFDebug = math.floor(
                (cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_DEBUG or 0) + 0.5),
            gDynamicDropWFThreshold =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_THRESHOLD,
            gDynamicDropWFRefraction =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_REFRACTION,
            gDynamicDropWFSceneMip =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SCENE_MIP,
            gDynamicDropWFSlopeMip =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SLOPE_MIP,
            gDynamicDropWFEdgeLoss =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_EDGE_LOSS,
            gDynamicDropWFLossStart =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_LOSS_START,
            gDynamicDropWFLossEnd =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_LOSS_END,
            gDynamicDropWFGlint = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_GLINT,
            gDynamicDropWFOpacity =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_OPACITY,
            gDynamicDropWFHeadStep =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_NORMAL_STEP_TEXELS
                / math.max(rainDynamicSceneCopyState.birthMaskSize or 2048, 1),
            gDynamicDropTrailRefractV2 =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_REFRACT_V2 and 1.0 or 0.0,
            gDynamicDropTrailRefractPx = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_REFRACT_PX,
            gDynamicDropTrailGradStep2 = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_GRAD_WIDE_TEXELS
                / math.max(rainDynamicSceneCopyState.waterTrailSize or 1024, 1),
            gDynamicDropTrailGradMix = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_GRAD_MIX,
            gDynamicDropTrailProfileRange = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_PROFILE_RANGE,
            gDynamicDropTrailSlopeMax = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_SLOPE_MAX,
            gDynamicDropTrailMipBase = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MIP_BASE,
            gDynamicDropTrailMipSlope = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MIP_SLOPE,
            gDynamicDropTrailSheetBlur = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_SHEET_BLUR,
            gDynamicDropTrailRippleAmp = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_RIPPLE_AMP,
            gDynamicDropTrailRippleAlong = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_RIPPLE_ALONG,
            gDynamicDropTrailRippleAcross = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_RIPPLE_ACROSS,
            gDynamicDropTrailRipplePhase = rainDynamicSceneCopyState.ripplePhase or 0.0,
            gDynamicDropTrailFlowDir = vec2(rainDynamicSceneCopyState.flowDirU or 0.0,
                rainDynamicSceneCopyState.flowDirV or 1.0),
            gDynamicDropTrailEdgeBoost = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_EDGE_BOOST,
            gDynamicDropTrailEdgeStart = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_EDGE_START,
            gDynamicDropTrailEdgeEnd = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_EDGE_END,
            gDynamicDropTrailFilmBoost = cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_FILM_BOOST,
            gDynamicDropSmearTrailClear = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_TRAIL_CLEAR,
            gDynamicDropWFTrailStep = math.max(
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_GRADIENT_TRAIL_TEXELS
                    / math.max(rainDynamicSceneCopyState.waterTrailSize or 1024, 1),
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_NORMAL_STEP_TEXELS
                    / math.max(rainDynamicSceneCopyState.birthMaskSize or 2048, 1)),
            gDynamicDropWaterToneMicro =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_TONE_MICRO and 1.0 or 0.0,
            gDynamicDropLargeStartPx = cfg.RUNTIME.RAIN_DYNAMIC_WATER_LARGE_START_PX,
            gDynamicDropLargeFullPx = cfg.RUNTIME.RAIN_DYNAMIC_WATER_LARGE_FULL_PX,
            gDynamicDropLargeBlurMip = cfg.RUNTIME.RAIN_DYNAMIC_WATER_LARGE_BLUR_MIP,
            gDynamicDropLargeWarpPx = cfg.RUNTIME.RAIN_DYNAMIC_WATER_LARGE_WARP_PIXELS,
            gDynamicDropLargeWarpCells = cfg.RUNTIME.RAIN_DYNAMIC_WATER_LARGE_WARP_CELLS,
            gDynamicDropLargeEdgeSoft = cfg.RUNTIME.RAIN_DYNAMIC_WATER_LARGE_EDGE_SOFT,
            gDynamicDropSmearIntensity = rainDynamicSceneCopyState.smearUpdate(
                rainDynamicSceneCopyState, sim),
            gDynamicDropSmear = (cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_ENABLED
                and ((rainDynamicSceneCopyState.smearLevel or 0.0) > 0.001
                    or cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_DEBUG > 0))
                and 1.0 or 0.0,
            -- 1 only while the shared slot really holds the mask texture.
            gDynamicDropSmearTexture = (cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_USE_TEXTURE
                and rainDynamicSceneCopyState.smearTexturePath)
                and 1.0 or 0.0,
            gDynamicDropSmearDebug = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_DEBUG,
            gDynamicDropSmearNoseEnabled = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_NOSE_EXCLUDE
                and 1.0 or 0.0,
            gDynamicDropSmearNose = vec4(cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_NOSE_U,
                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_NOSE_TIP_V,
                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_NOSE_HALF_WIDTH,
                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_NOSE_HEIGHT),
            gDynamicDropSmearNoseSoft = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_NOSE_SOFT,
            gDynamicDropSmearEdgeSoft = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_EDGE_SOFT,
            gDynamicDropSmearMicroHide = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_MICRO_HIDE,
            gDynamicDropSmearMicroTurbid = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_MICRO_TURBID,
            gDynamicDropSmearDropTurbid = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_DROP_TURBID,
            gDynamicDropSmearTrailMix = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_TRAIL_MIX,
            gDynamicDropImpactFilm = rainDynamicSceneCopyState.waterTrailComposite
                and 1.0 or 0.0,
            gDynamicDropSmearFilmMix = cfg.RUNTIME.RAIN_DYNAMIC_IMPACT_SHEET_SMEAR_MIX,
            gDynamicDropImpactWavePx = cfg.RUNTIME.RAIN_DYNAMIC_IMPACT_SHEET_WAVE_PX,
            gDynamicDropImpactOpacity = cfg.RUNTIME.RAIN_DYNAMIC_IMPACT_SHEET_OPACITY,
            gDynamicDropSmearTrailTurbid = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_TRAIL_TURBID,
            gDynamicDropSmearTrailBlur = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_TRAIL_BLUR,
            gDynamicDropSmearHeadMix = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_HEAD_MIX,
            gDynamicDropSmearHeadHide = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_HEAD_HIDE,
            gDynamicDropSmearTrailHide = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_TRAIL_HIDE,
            gDynamicDropSmearRTiling = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_R_TILING,
            gDynamicDropSmearGTiling = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_G_TILING,
            gDynamicDropWaterToneFloor = cfg.RUNTIME.RAIN_DYNAMIC_WATER_TONE_FLOOR,
            gDynamicDropSmearPathWeaken = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_PATH_WEAKEN,
            gDynamicDropSmearMip = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_MIP,
            gDynamicDropSmearGContrast = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_G_CONTRAST,
            gDynamicDropSmearGPivot = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_G_PIVOT,
            gDynamicDropSmearGGamma = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_G_GAMMA,
            gDynamicDropSmearVeil = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_VEIL,
            gDynamicDropSmearClasses = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_CLASSES,
            gDynamicDropSmearClassSoft = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_CLASS_SOFT,
            gDynamicDropSmearClassSeed = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_CLASS_SEED,
            gDynamicDropSmearFacetPixels = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_FACET_PIXELS,
            gDynamicDropSmearToneRange = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_TONE_RANGE,
            gDynamicDropSmearClassMipRange = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_CLASS_MIP_RANGE,
            gDynamicDropSmearEraseSpan = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_ERASE_SPAN,
            gDynamicDropSmearClassWipe = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_CLASS_WIPE,
            gDynamicDropSmearLineStrength = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_LINE_STRENGTH,
            gDynamicDropSmearLineWidth = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_LINE_WIDTH,
            gDynamicDropSmearFacetAlpha = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_ENABLED
                and cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_FACET_ALPHA or 0.0,
            gDynamicDropMicroPointLoad =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_POINT_LOAD and 1.0 or 0.0,
            gDynamicDropMicroPopEnabled =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_POP_ENABLED and 1.0 or 0.0,
            gDynamicDropMicroPopPick = cfg.RUNTIME.RAIN_DYNAMIC_MICRO_POP_PICK,
            gDynamicDropMicroPopPeriod = cfg.RUNTIME.RAIN_DYNAMIC_MICRO_POP_PERIOD,
            gDynamicDropMicroPopOff = cfg.RUNTIME.RAIN_DYNAMIC_MICRO_POP_OFF,
            gDynamicDropMicroPopFade = cfg.RUNTIME.RAIN_DYNAMIC_MICRO_POP_FADE,
            gDynamicDropMicroPopFlash = cfg.RUNTIME.RAIN_DYNAMIC_MICRO_POP_FLASH,
            gDynamicDropMicroPopIdScale = cfg.RUNTIME.RAIN_DYNAMIC_MICRO_POP_ID_SCALE,
            gDynamicDropMicroPopTime = rainDynamicSceneCopyState.smearTime or 0.0,
            gDynamicDropSmearMaskCells = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_MASK_CELLS,
            gDynamicDropSmearMaskWarp = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_MASK_WARP,
            gDynamicDropSmearFillCells = cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_FILL_CELLS,
            gDynamicDropSmearFillPatchCells =
                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_FILL_PATCH_CELLS,
            gDynamicDropWaterToneEnabled =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_TONE_ENABLED and 1.0 or 0.0,
            gDynamicDropWaterToneContrast = cfg.RUNTIME.RAIN_DYNAMIC_WATER_TONE_CONTRAST,
            gDynamicDropWaterToneRatioMin = cfg.RUNTIME.RAIN_DYNAMIC_WATER_TONE_RATIO_MIN,
            gDynamicDropWaterToneRatioMax = cfg.RUNTIME.RAIN_DYNAMIC_WATER_TONE_RATIO_MAX,
            gDynamicDropWaterToneBgMip = cfg.RUNTIME.RAIN_DYNAMIC_WATER_TONE_BG_MIP,
            gDynamicDropHazeEnabled =
                cfg.RUNTIME.RAIN_DYNAMIC_HAZE_ENABLED and 1.0 or 0.0,
            gDynamicDropHazeMistCells = cfg.RUNTIME.RAIN_DYNAMIC_HAZE_MIST_CELLS,
            gDynamicDropHazeOrderCells =
                cfg.RUNTIME.RAIN_DYNAMIC_HAZE_ORDER_CELLS,
            gDynamicDropHazeSpeckleCells =
                cfg.RUNTIME.RAIN_DYNAMIC_HAZE_SPECKLE_CELLS,
            gDynamicDropHazeDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_HAZE_DEBUG and 1.0 or 0.0,
            gDynamicDropHazeRain = math.max(0.0, math.min(1.0,
                cfg.RUNTIME.RAIN_GPU_STATE_RAIN_OVERRIDE >= 0.0
                    and cfg.RUNTIME.RAIN_GPU_STATE_RAIN_OVERRIDE
                    or sim.rainIntensity or 0.0))
                ^ cfg.RUNTIME.RAIN_DYNAMIC_HAZE_RAIN_POWER,
            gDynamicDropHazeStrength = cfg.RUNTIME.RAIN_DYNAMIC_HAZE_STRENGTH,
            gDynamicDropHazeMottle = cfg.RUNTIME.RAIN_DYNAMIC_HAZE_MOTTLE,
            gDynamicDropHazeRevealSoft =
                cfg.RUNTIME.RAIN_DYNAMIC_HAZE_REVEAL_SOFT,
            gDynamicDropHazeMip = cfg.RUNTIME.RAIN_DYNAMIC_HAZE_MIP,
            gDynamicDropHazeVeil = cfg.RUNTIME.RAIN_DYNAMIC_HAZE_VEIL,
            gDynamicDropHazeSpecklePixels =
                cfg.RUNTIME.RAIN_DYNAMIC_HAZE_SPECKLE_PIXELS,
            gDynamicDropHazeTrailClear =
                cfg.RUNTIME.RAIN_DYNAMIC_HAZE_TRAIL_CLEAR,
            gDynamicDropHazeSkyCorrection =
                cfg.RUNTIME.RAIN_DYNAMIC_HAZE_SKY_CORRECTION
                and rainDynamicSceneCopyState.shotWithDepth
                and not rainDynamicSceneCopyState.toneReady
                and 1.0 or 0.0,
            gDynamicDropWFSheetBlur =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_BLUR,
            gDynamicDropWFSheetVeil =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_VEIL,
            gDynamicDropWFSheetAlpha =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_ALPHA,
            gDynamicDropWFSheetEdgeSoft =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_EDGE_SOFT,
            gDynamicDropWFInvMaskSize = 1.0
                / math.max(rainDynamicSceneCopyState.birthMaskSize or 2048, 1),
            gDynamicDropDepthOnly = 0.0,
            gDynamicDropDepthExact =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_DEPTH_OCCLUDE_MODE >= 2
                and 1.0 or 0.0,
            gDynamicDropDepthAlphaMin = cfg.RUNTIME.RAIN_DYNAMIC_DROP_DEPTH_ALPHA_MIN,
            gDynamicDropHazeDepthMin = cfg.RUNTIME.RAIN_DYNAMIC_DROP_HAZE_DEPTH_MIN,
        },
        shader = rainDynamicDropShader.HLSL
    }
    rainDynamicSceneCopyState.lastDropMeshParams = dropMeshParams
    local dynamicDrawn = false
    local sceneStackOk = pcall(rainDynamicSceneCopyState.visorSceneStack, 'pre')
    if not ((cfg.RUNTIME.RAIN_VISOR_OVERLAY_PROBE
            and cfg.RUNTIME.RAIN_VISOR_OVERLAY_PROBE_HIDE_SCENE)
            or cfg.RUNTIME.RAIN_VISOR_OVERLAY) then
        dynamicDrawn = render.mesh(dropMeshParams)
    end
    -- s53: glass in front of the rain (GLASS_EXT band, GLASS_INT), before
    -- the drop depth pass so the same-surface GLASS_EXT is not rejected.
    if sceneStackOk then
        local okPost, errPost = pcall(rainDynamicSceneCopyState.visorSceneStack, 'post')
        if not okPost then rainDynamicSceneCopyState.visorLayer.err = tostring(errPost) end
    end
    -- Depth occlusion pass (docs/RAINFX_IMPACT_SPLASH.md §7): same mesh and
    -- shader in depth-only mode (alpha 0 output, clipped where the visor is
    -- bare), so car glass drawn later cannot blend over the drops.
    if dynamicDrawn and cfg.RUNTIME.RAIN_DYNAMIC_DROP_DEPTH_OCCLUDE
        and not cfg.RUNTIME.RAIN_DYNAMIC_DROP_DEPTH_OFF
        and not cfg.RUNTIME.RAIN_DYNAMIC_DROP_UV_DEBUG then
        dropMeshParams.values.gDynamicDropDepthOnly = 1.0
        render.setBlendMode(render.BlendMode.AlphaBlend)
        render.setDepthMode(render.DepthMode.Normal)
        render.mesh(dropMeshParams)
        dropMeshParams.values.gDynamicDropDepthOnly = 0.0
        render.setDepthMode(render.DepthMode.ReadOnly)
        render.setBlendMode(render.BlendMode.BlendAccurate)
    end
    if cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG
        and dynamicDrawn
    then
        rainDynamicSceneCopyState.lastSmokeDrawFrame = sim.frame
    end

    rainDynamicSurfaceMesh:setVisible(false, false)

    if not rainDynamicManualDrawLogged then
        ac.log(
            appNameDebug
            .. ' Dynamic drop Stage 4B.2 '
            .. (cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG
                and 'smoke' or (cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_TRACK
                    and 'track' or 'root'))
            .. ' draw: result='
            .. tostring(dynamicDrawn)
            .. ' shaderBytes='
            .. tostring(
                rainDynamicDropShader.HLSL
                and #rainDynamicDropShader.HLSL
                or 0
            )
        )
        rainDynamicManualDrawLogged = true
    end
end)


render.on('main.track.transparent', function()
    -- ac.log('[RealVisor] ENTER main.track.transparent')
    if cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG
        and not rainDynamicManualDrawLogged
    then
        local stageSim = ac.getSim()
        if stageSim then
            if not rainDynamicSceneCopyState.smokeProbeStartFrame then
                rainDynamicSceneCopyState.smokeProbeStartFrame = stageSim.frame
            elseif not rainDynamicSceneCopyState.smokeProbeWarned
                and stageSim.frame
                    - rainDynamicSceneCopyState.smokeProbeStartFrame > 120
            then
                ac.warn(appNameDebug .. ' Dynamic drop smoke stage: '
                    .. 'no completed drop draw after 120 frames')
                rainDynamicSceneCopyState.smokeProbeWarned = true
            end
        end
    end

    
    if not cfg.RUNTIME.RAIN_ENABLED  then
        return
    end


    local rainShader = nil
    local rainDynamicDropShader = nil


    for i, shader in ipairs(shaders) do

        if shader.ID == 'RAINFXVISOR'
            and shader.LOADED then
            rainShader = shader
        elseif shader.ID == 'RAINFXDYNAMICDROP'
            and shader.LOADED then
            rainDynamicDropShader = shader
        end
    end


    if not rainShader then
        if not rainRenderDiagnosticLogged then
            ac.warn(appNameDebug .. ' Rain render skipped: RAINFXVISOR shader is not loaded')
            rainRenderDiagnosticLogged = true
        end
        return
    end


    if rainLastDebugMode ~= cfg.RUNTIME.RAIN_DEBUG then
        rainLastDebugMode = cfg.RUNTIME.RAIN_DEBUG

        ac.log(
            appNameDebug
            .. ' Rain render debug=' .. tostring(cfg.RUNTIME.RAIN_DEBUG)
            .. ' mesh=' .. tostring(rainTargetMesh ~= nil)
            .. ' meshCount=' .. tostring(rainTargetMesh and #rainTargetMesh or 0)
            .. ' shaderBytes=' .. tostring(rainShader.HLSL and #rainShader.HLSL or 0)
        )
    end


    if not rainTargetMesh
        or #rainTargetMesh == 0 then
        return
    end

    
    local startingTransform = 
        rainTargetMesh:getWorldTransformationRaw():clone()


    if not startingTransform then
        return
    end


    --------------------------------------------------------
    -- Rain state
    --------------------------------------------------------

    local sim = ac.getSim()

    local car = ac.getCar(0)


    if not car then
        return
    end


    
    --------------------------------------------------------
    -- Vehicle acceleration is updated once per simulation frame by
    -- updateRainFlow(). The render pass evaluates each drop locally.
    --------------------------------------------------------

    --------------------------------------------------------
    -- Persistent GPU state update
    --------------------------------------------------------

    -- Persistent state is prepared at scene-ready before any draw.
    if cfg.RUNTIME.RAIN_GPU_STATE_MODE > 0
        and rainDynamicSceneCopyState.stateReadyFrame ~= sim.frame
    then
        return
    end

    --------------------------------------------------------
    -- Render
    --------------------------------------------------------

    --------------------------------------------------------
    -- Stage 1 dynamic mesh renderer experiment
    --
    -- This branch intentionally keeps the canonical fullscreen
    -- renderer available. Enable the test switch to render only
    -- the 256 small mesh quads.
    --------------------------------------------------------

    if cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_STATE_ENABLED then
        -- The separate manual-draw callback handles the dynamic surface at
        -- the stage selected by RAIN_DYNAMIC_DROP_DRAW_AT_TRACK.
        return
    end

    if cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_TEST_ENABLED then

        if not initializeRainDynamicSurfaceTest() then
            return
        end

        render.setBlendMode(render.BlendMode.AlphaBlend)
        render.setCullMode(render.CullMode.None)
        render.setDepthMode(render.DepthMode.ReadOnly)

        render.mesh({
            mesh = rainDynamicSurfaceMesh,
            shader = RAIN_DYNAMIC_SURFACE_DIAGNOSTIC_HLSL
        })

        return
    end

    if cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_ENABLED then

        if not initializeRainDynamicMeshTest() then
            return
        end

        render.setBlendMode(
            render.BlendMode.AlphaBlend
        )

        render.setCullMode(
            render.CullMode.None
        )

        render.setDepthMode(
            render.DepthMode.ReadOnly
        )

        render.mesh({
            mesh = rainDynamicMeshTest,
            shader = RAIN_DYNAMIC_MESH_TEST_HLSL
        })

        return
    end

    --------------------------------------------------------
    -- Render
    --------------------------------------------------------
    
    
    render.setBlendMode(
        render.BlendMode.AlphaBlend
    )

    render.setCullMode(
        render.CullMode.None
    )

    render.setDepthMode(
        render.DepthMode.ReadOnly
    )


    local result = render.mesh({

        mesh = 
            rainTargetMesh,


        transform = 
            startingTransform,


        textures = {
            
            txRainBoundaryMask =
                textureRainBoundaryMask,

            txRainState =
                rainStateReadIsA
                and rainStateA
                or rainStateB,

            txRainStateMeta =
                rainStateReadIsA
                and rainStateMetaA
                or rainStateMetaB,

            txRainSurfaceNormal =
                textureRainSurfaceNormal,

        },

        values = {
            gRainDebug = cfg.RUNTIME.RAIN_DEBUG,

            gRainStateCount =
                cfg.RUNTIME.RAIN_GPU_STATE_MODE == 4
                and 9
                or cfg.RUNTIME.RAIN_GPU_STATE_MODE == 10
                and 9
                or cfg.RUNTIME.RAIN_GPU_STATE_MODE == 7
                and 1
                or cfg.RUNTIME.RAIN_GPU_STATE_COUNT,

            gRainAcceleration = rainAccelerationCurrent,

            gRainForceMask =
                (cfg.RUNTIME.RAIN_FORCE_GRAVITY_ENABLED and RAIN_FORCE_GRAVITY or 0)
                + (cfg.RUNTIME.RAIN_FORCE_INERTIA_ENABLED and RAIN_FORCE_INERTIA or 0)
                + (cfg.RUNTIME.RAIN_FORCE_AIRFLOW_ENABLED and RAIN_FORCE_AIRFLOW or 0),

            gRainPhysicsAccelScale =
                cfg.RUNTIME.RAIN_PHYSICS_ACCEL_SCALE,

            gRainStateGravity =
                math.abs(
                    ac.getSim()
                    and ac.getSim().gravity
                    or -9.81
                ),

            gRainAirVelocityWorld = vec3(
                -ac.getCar(0).velocity.x,
                -ac.getCar(0).velocity.y,
                -ac.getCar(0).velocity.z
            ),

            gRainAirDensity =
                cfg.RUNTIME.RAIN_AIR_DENSITY,

            gRainAirDragCoeff =
                cfg.RUNTIME.RAIN_AIR_DRAG_COEFF,

            gRainStatePhysicalDiameterUVPerMM =
                cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM,

            gRainObjectToWorld =
                startingTransform,

            gRainDebugPredictionTime = 0.25,
            gRainDebugForceArrowScale = 0.015,
            gRainDebugStateSpeedScale = 0.016
        },

        shader = 
            rainShader.HLSL

            -- shader = [[
            --     float4 main(PS_IN pin) {
            --         return txRain.Sample(samAnisotropic, pin.Tex);
            --     }
            -- ]]


        })




        -- ac.log('[RealVisor] texture =' .. textureRainSurfaceNormal)
end)

------------------------------------------------------------
-- Initialize
------------------------------------------------------------

local function initializeScene()


    --------------------------------------------------------
    -- carsRoot
    --------------------------------------------------------

    carsRoot =
        ac.findNodes('carsRoot:yes')

    if not carsRoot
        or #carsRoot == 0 then

        ac.warn(            
            appNameDebug .. ' carsRoot not found'
        )

        return false
    end


    --------------------------------------------------------
    -- Driver Head Observation
    --------------------------------------------------------

    findDriverHeadAndNeck()


    --------------------------------------------------------
    -- Temporal Crash patches (v0.2.0 method)
    --------------------------------------------------------
    cameraAnchor = carsRoot:createBoundingSphereNode(
        'REALVISOR_CAMERA_ANCHOR',
        5.0
    )

    if cameraAnchor == nil then
        ac.warn(appNameDebug .. ' Camera anchor creation failed')
        return false
    end
    

    --------------------------------------------------------
    -- IMPORTANT
    --
    -- Use a normal node.
    --
    -- Previous version used a BoundingSphereNode.
    -- Rotation tracking did not work correctly in testing.
    --------------------------------------------------------

    cameraRoot = cameraAnchor:createNode(
            'REALVISOR_CAMERA_ROOT'
        )

    if not cameraRoot then
        ac.warn(
            appNameDebug .. ' Camera root creation failed'
        )

        return false
    end


    --------------------------------------------------------
    -- Local offset
    --------------------------------------------------------

    offsetNode =
        cameraRoot:createNode(
            'REALVISOR_OFFSET'
        )


    --------------------------------------------------------
    -- G-Force Motion
    --------------------------------------------------------

    motionNode =
        offsetNode:createNode(
            'REALVISOR_MOTION'
        )

    if not cameraRoot then
    ac.warn(
        appNameDebug .. ' Motion node creation failed'
    )

        return false
    end

    --------------------------------------------------------
    -- Scale
    --------------------------------------------------------

    scaleNode =
        motionNode:createNode(
            'REALVISOR_SCALE'
        )


    --------------------------------------------------------
    -- Model axis
    --------------------------------------------------------

    -- axisNode =
    --     scaleNode:createNode(
    --         'REALVISOR_AXIS'
    --     )

    axisPitchNode =
    scaleNode:createNode(
        'REALVISOR_AXIS_PITCH'
    )

    axisYawNode =
    axisPitchNode:createNode(
        'REALVISOR_AXIS_YAW'
    )

    axisRollNode =
    axisYawNode:createNode(
        'REALVISOR_AXIS_ROLL'
    )

    if not offsetNode
        or not scaleNode
        or not axisPitchNode 
        or not axisYawNode 
        or not axisRollNode then

        ac.warn(
            appNameDebug .. ' Transform hierarchy failed'
        )

        return false
    end


    --------------------------------------------------------
    -- Load KN5
    --------------------------------------------------------

    visor =
        axisRollNode:loadKN5({

            filename = cfg.RUNTIME.MODEL_PATH,

            forceRenderableOn = true
        })


    if visor and cfg.RUNTIME.RAIN_VISOR_MOTION_STENCIL >= 0.0 then
        visor:setMotionStencil(cfg.RUNTIME.RAIN_VISOR_MOTION_STENCIL)
        -- visor:setDepthMode(render.DepthMode.Normal)
    end

    if not visor then

        ac.warn(
            appNameDebug .. ' Failed to load KN5: '
            .. cfg.RUNTIME.MODEL_PATH
        )

        return false
    end


    --------------------------------------------------------
    -- Setup Camera Clipping 
    --------------------------------------------------------

    if activeNearclip and ac.getSim().cameraClipFar then
        ac.overrideCameraClipPlanes(activeNearclip, ac.getSim().cameraClipFar)
    end


    --------------------------------------------------------
    -- Find glass mesh
    --  see Material Definition Section
    --------------------------------------------------------


    for i, editor in ipairs(MATERIAL_EDITORS) do
        editor.targetMesh = 
            visor:findMeshes(
                editor.meshName
            )
        
        if editor.targetMesh
            and #editor.targetMesh > 0 then

            ac.log(
            appNameDebug .. ' ' .. editor.meshName .. ' found'
        )

            --------------------------------------------------------
            -- binding target mesh for RainFX
            --------------------------------------------------------

            if editor.id == 'OVRGLASSRAINFX' then
                rainTargetMesh = editor.targetMesh 
            end


            --------------------------------------------------------
            -- Find Material
            --
            -- Locate mtVISOR_GLASS_EXT_DIRT (assigned to VISOR_GLASS_EXT_DIRT)
            -- using CSP's 'material:' scene query, then do the initial
            -- parameter read so the editor window has data as soon as it
            -- is opened.
            --------------------------------------------------------

            editor.materialQueryRef =
                visor:findMeshes(
                    'material:'
                    .. editor.materialName
                )

            if editor.materialQueryRef
                and #editor.materialQueryRef > 0 then
                    
                ac.log(
                    appNameDebug .. ' MATERIAL: ' .. editor.materialName .. ' found'
                )

                loadMaterialParams(editor)
            end
            
        else

        ac.warn(
            appNameDebug .. ' ' .. editor.meshName .. ' not found. Skip finding material..'
        )
        end
    end


    --------------------------------------------------------
    -- Apply profile
    --------------------------------------------------------

    -- activeProfile = math.clamp(
    --         tonumber(cfg.GENERAL.ACTIVE) or 1,
    --         1,
    --         2
    -- )

    loadProfiles()

    applyActiveProfileToRuntime()


    --------------------------------------------------------
    -- Apply initial transforms
    --------------------------------------------------------

    applyScale()

    applyAxisCorrection()


    initialized = true


    ac.log(
        appNameDebug .. ' initialized'
    )


    return true
end


------------------------------------------------------------
-- Update Visor transform
------------------------------------------------------------
local prevPos = nil
local prevForward = nil
local textDebugDeltaPos = nil
local textDebugPos = nil
local textDebugCamRotation = nil
local function updateVisorTransform()

    
    --------------------------------------------------------
    -- Get camera position
    --------------------------------------------------------

    local position =
        ac.getCameraPosition()


    --------------------------------------------------------
    -- Debug logger: Position delta 
    --------------------------------------------------------
    if cfg.RUNTIME.DEBUG_DELTAPOS then
        
        if prevPos ~= nil and prevPos ~= position then
            textDebugDeltaPos = 'X: ' .. string.format('%.4f',position.x - prevPos.x) 
                                .. ', Y: ' .. string.format('%.4f',position.y - prevPos.y) 
                                .. ', Z: ' .. string.format('%.4f',position.z - prevPos.z)
            textDebugPos = 'X: ' .. string.format('%.4f',position.x) 
                                .. ', Y: ' .. string.format('%.4f',position.y) 
                                .. ', Z: ' .. string.format('%.4f',position.z)
        ac.log(
            appNameDebug .. ' ' .. textDebugDeltaPos
        )
        end
    
        prevPos = position
    end


    --------------------------------------------------------
    -- Get camera forward direction
    --------------------------------------------------------

    local forward =
        ac.getCameraForward()
    

    local up = ac.getCameraUp()

    --------------------------------------------------------
    -- Debug logger: Orientation (Forward) delta
    --------------------------------------------------------
    if cfg.RUNTIME.DEBUG_ROTATION then
        if prevForward ~= nil and prevForward ~= forward then

            --------------------------------------------------------
            -- 1. Delta Rotation
            --------------------------------------------------------
            -- -- 1. 성분별 Vector 차이 (x, y, z)
            -- local dX = forward.x - prevForward.x
            -- local dY = forward.y - prevForward.y
            -- local dZ = forward.z - prevForward.z

            -- -- 2. 이전 방향과의 각도 차이 (Degree)
            -- -- Inner product(내적)를 이용한 사이각 계산
            -- local dot = math.max(-1.0, math.min(1.0, forward:dot(prevForward)))
            -- local angleRad = math.acos(dot)
            -- local angleDeg = math.deg(angleRad)

            -- textDebugRotation = appNameDebug .. ' world rotation: ' .. string.format('%.2f°', angleDeg)
            --                     .. ' | Forward Delta X: ' .. string.format('%.4f', dX)
            --                     .. ', Y: ' .. string.format('%.4f', dY)
            --                     .. ', Z: ' .. string.format('%.4f', dZ)


            --------------------------------------------------------
            -- 2. AC-cam vs Visor Rotation Comparison 
            --------------------------------------------------------
            -- Cam fwd vector normalized
            local fwd = forward:normalize()

            -- Pitch: -90° ~ 90°
            local pitchRad = math.asin(math.max(-1.0, math.min(1.0, fwd.y)))
            local pitchDeg = math.deg(pitchRad)

            -- Yaw: -180° ~ 180°
            local yawRad = math.atan2(fwd.x, fwd.z)
            local yawDeg = math.deg(yawRad)

            textDebugCamRotation = 'World-Cam (Pitch ' .. string.format('%.1f°', pitchDeg)
                                .. ', Yaw ' .. string.format('%.1f°', yawDeg)
                                .. ') \t\t Fwd Vec (' .. string.format('%.3f', fwd.x) 
                                .. ', ' .. string.format('%.3f', fwd.y) 
                                .. ', ' .. string.format('%.3f', fwd.z) .. ')'

            ac.log(
                appNameDebug .. ' ' .. textDebugCamRotation
            )
        end
        prevForward = forward
    end


    --------------------------------------------------------
    -- Position
    --------------------------------------------------------
    
    cameraAnchor:setPosition(
    -- cameraRoot:setPosition(
        position
    )

    --------------------------------------------------------
    -- Orientation
    --
    -- Camera Root receives camera rotation directly.
    --
    -- Axis correction is handled by child node.
    --------------------------------------------------------

    cameraRoot:setOrientation(

        forward,

        (up or worldUp)
    )
end


------------------------------------------------------------
-- Update local offset
------------------------------------------------------------

local function updateOffset()


    --------------------------------------------------------
    -- Currently no G-force motion.
    --
    -- Offset is local to cameraRoot.
    --------------------------------------------------------

    offsetNode:setPosition(
        activeOffset
    )
end


------------------------------------------------------------
-- Update local offset
------------------------------------------------------------

local function updateMotion(dt)
    
    if not motionNode then
        return
    end


    ------------------------------------------------------------
    -- Disabled
    ------------------------------------------------------------
    if activeEnableMotion ~= 1 then

        motionCurrent:set(
            0,
            0,
            0
        )

        previousVelocity = nil

        motionNode:setPosition(
            motionCurrent
        )

        return
    end


    ------------------------------------------------------------
    -- Invalid delta time
    ------------------------------------------------------------

    if not dt or dt <= 0.000001 then
        ac.log(
            appNameDebug .. ' MOTION: Invalid delta time!'
        )
        return
    end

    
    ------------------------------------------------------------
    -- Player car
    ------------------------------------------------------------

    local playerCar = 
        ac.getCar(0)


    if not playerCar then
        return
    end


    ------------------------------------------------------------
    -- Vehicle velocity
    ------------------------------------------------------------

    local velocity = 
        playerCar.velocity


    if not velocity then
        return
    end


    ------------------------------------------------------------
    -- First frame
    ------------------------------------------------------------

    if previousVelocity == nil then

        previousVelocity =
            vec3(
                velocity.x,
                velocity.y,
                velocity.z
            )

        return
    end
    

    ------------------------------------------------------------
    -- World acceleration
    ------------------------------------------------------------

    local acceleration =
        vec3(
                (velocity.x - previousVelocity.x) / dt,
                (velocity.y - previousVelocity.y) / dt,
                (velocity.z - previousVelocity.z) / dt
            )


    ------------------------------------------------------------
    -- Save velocity
    ------------------------------------------------------------

    previousVelocity:set(
        velocity
    )


    ------------------------------------------------------------
    -- Camera basis
    ------------------------------------------------------------
    
    local cameraForward =
        ac.getCameraForward()

    if cameraForward:lengthSquared() < 0.000001 then
        return
    end


    ------------------------------------------------------------
    -- Copy forward vector
    --
    -- Do not modify CSP camera vector directly
    ------------------------------------------------------------

    local forward =
        vec3(
            cameraForward.x,
            cameraForward.y,
            cameraForward.z
        )

    forward:normalize()


    ------------------------------------------------------------
    -- Create fresh world up vector every frame
    --
    -- Never use global worldUp as a temporary calculation vector
    ------------------------------------------------------------

    local localWorldUp =
        vec3(
            0,
            1,
            0
        )


    ------------------------------------------------------------
    -- Camera right axis
    ------------------------------------------------------------

    local right =
        localWorldUp:cross(
            forward
        )

    if right:lengthSquared() < 0.000001 then
        return
    end

    right:normalize()


    ------------------------------------------------------------
    -- Camera up axis
    ------------------------------------------------------------

    local up =
        forward:cross(
            right
        )

    if up:lengthSquared() < 0.000001 then
        return
    end

    up:normalize()


    ------------------------------------------------------------
    -- Convert acceleration
    -- into camera-local coordinates
    ------------------------------------------------------------

    local accelerationX =
        acceleration:dot(right)

    local accelerationY =
        acceleration:dot(up)

    local accelerationZ =
        acceleration:dot(forward)


    ------------------------------------------------------------
    -- Inertial target
    --
    -- Opposite direction to acceleration
    ------------------------------------------------------------

    motionTarget.x =
            -accelerationX
            * activeMotionGainX
            * activeMotionSharpness

    motionTarget.y =
            -accelerationY
            * activeMotionGainY
            * activeMotionSharpness

    motionTarget.z =
            -accelerationZ
            * activeMotionGainZ
            * activeMotionSharpness


    ------------------------------------------------------------
    -- Axis limits
    ------------------------------------------------------------

    motionTarget.x =
        clampValue(

            motionTarget.x,

            -activeMotionLimitX,

            activeMotionLimitX
        )


    motionTarget.y =
        clampValue(

            motionTarget.y,

            -activeMotionLimitY,

            activeMotionLimitY
        )


    motionTarget.z =
        clampValue(

            motionTarget.z,

            -activeMotionLimitZ,

            activeMotionLimitZ
        )


    ------------------------------------------------------------
    -- Exponential smoothing
    ------------------------------------------------------------
    local smoothingAlpha =
        1.0
        -
        math.exp(
            -activeMotionSmoothing
            * dt
        )

    motionCurrent.x =
        motionCurrent.x
        +
        (
            motionTarget.x
            -
            motionCurrent.x
        )
        * smoothingAlpha


    motionCurrent.y =
        motionCurrent.y
        +
        (
            motionTarget.y
            -
            motionCurrent.y
        )
        * smoothingAlpha


    motionCurrent.z =
        motionCurrent.z
        +
        (
            motionTarget.z
            -
            motionCurrent.z
        )
        * smoothingAlpha


    ------------------------------------------------------------
    -- Apply
    ------------------------------------------------------------

    motionNode:setPosition(
        motionCurrent
    )
    

    ------------------------------------------------------------
    -- Debug
    ------------------------------------------------------------

    if cfg.RUNTIME.DEBUG_MOTION then

        textDebugMotion =
            string.format(

                'Accel: %.2f %.2f %.2f | Motion: %.4f %.4f %.4f',

                accelerationX,
                accelerationY,
                accelerationZ,

                motionCurrent.x,
                motionCurrent.y,
                motionCurrent.z
            )
    end
end


------------------------------------------------------------
-- Initialize custom shaders
------------------------------------------------------------

local function initShaders()
    local allLoaded = true
    for _, shader in ipairs(shaders) do
        if not shader.LOADED or not shader.HLSL
            or #shader.HLSL == 0
        then
            local file, err = io.open(shader.PATH, 'r')
            local source = nil
            if file then
                source = file:read('*a')
                file:close()
                -- CSP appends this source after its shader template. A UTF-8
                -- BOM is only legal at the start of the complete HLSL file.
                if source and source:sub(1, 3) == string.char(239, 187, 191) then
                    source = source:sub(4)
                end
            end
            if source and #source > 0 then
                shader.HLSL = source
                shader.LOADED = true
                shader.RETRY_LOGGED = false
                ac.log(appNameDebug .. ' SHADER LOADED: ' .. shader.ID
                    .. ' HLSL bytes=' .. tostring(#source)
                    .. ' path=' .. shader.PATH)
            else
                shader.HLSL = nil
                shader.LOADED = false
                allLoaded = false
                if not shader.RETRY_LOGGED then
                    ac.warn(appNameDebug .. ' HLSL not ready, retrying: '
                        .. shader.PATH .. ' error=' .. tostring(err))
                    shader.RETRY_LOGGED = true
                end
            end
        end
    end
    shaderInitialized = allLoaded
end

------------------------------------------------------------
-- Update rain flow
--
-- Acceleration is filtered once per simulation frame and passed to the
-- shader as a WORLD-SPACE external-force input. Per-drop adhesion, drag,
-- terminal speed and travel are evaluated in one place in HLSL.
------------------------------------------------------------
local function updateRainFlow(dt)

    if not cfg.RUNTIME.RAIN_ENABLED 
        or not shaderInitialized then
        return
    end

    if not dt or dt <= 0.000001 then
        return
    end

    local car = ac.getCar(0)

    if not car or not car.velocity then
        return
    end

    local accelerationG = car.acceleration

    if not accelerationG
        or not car.side
        or not car.up
        or not car.look then
        return
    end

    ------------------------------------------------------------
    -- ac.getCar(0).acceleration is car-local G acceleration.
    -- Convert it to WORLD m/s^2 using the verified car basis.
    -- A droplet attached to the visor experiences inertial force
    -- opposite the vehicle's acceleration, hence the final negation.
    --
    -- Car-local axes:
    --   X = side, Y = up, Z = look/forward.
    ------------------------------------------------------------
    local accelerationWorld =
        car.side * accelerationG.x
        + car.up * accelerationG.y
        + car.look * accelerationG.z

    local targetAcceleration =
        vec3(
            -accelerationWorld.x * 9.81,
            -accelerationWorld.y * 9.81,
            -accelerationWorld.z * 9.81
        )

    ------------------------------------------------------------
    -- Direct physical acceleration input.
    ------------------------------------------------------------
    rainAccelerationCurrent = targetAcceleration
end


------------------------------------------------------------
-- DLSS shimmer tests (docs/RAINFX_VISOR_GLASS.md §6)
------------------------------------------------------------

rainDynamicSceneCopyState.visorClearMotion = function()
    local chain = { cameraAnchor, cameraRoot, offsetNode, motionNode,
        scaleNode, axisPitchNode, axisYawNode, axisRollNode, visor }
    for i = 1, 9 do
        if chain[i] then chain[i]:clearMotion() end
    end
end

render.on('main.track.opaque', function()
    if not visor or activeEnableMode ~= 1 or not cameraAnchor then
        return
    end
    local r = cfg.RUNTIME
    if r.RAIN_VISOR_MOTION_TEST_LATE then
        updateVisorTransform()
        if r.RAIN_VISOR_MOTION_TEST_CLEAR then
            rainDynamicSceneCopyState.visorClearMotion()
        end
    end
    local st = rainDynamicSceneCopyState
    local name = r.RAIN_VISOR_REDRAW_TEST_MESH or ''
    if st.visorRedrawName ~= name then
        if st.visorRedrawRef then st.visorRedrawRef:setVisible(true) end
        st.visorRedrawName = name
        st.visorRedrawRef = name ~= '' and visor:findMeshes(name) or nil
        if st.visorRedrawRef and #st.visorRedrawRef == 0 then
            ac.warn(appNameDebug .. ' Redraw test: mesh not found: ' .. name)
            st.visorRedrawRef = nil
        end
    end
    if st.visorRedrawRef then
        -- 2026-10-03 fix: `sim` is not a chunk-level local here; the former
        -- `sim.lightDirection` raised every frame AFTER the mesh was made
        -- visible and the render state changed (cull None / opaque blend /
        -- depth write leaked into the rest of the stage).
        local simNow = ac.getSim()
        st.visorRedrawRef:setVisible(true, false)
        render.setBlendMode(render.BlendMode.Opaque)
        render.setDepthMode(render.DepthMode.Normal)
        render.setCullMode(render.CullMode.None)
        local ok, err = pcall(render.mesh, {
            mesh = st.visorRedrawRef,
            transform = 'original',
            textures = {},
            values = { gTestLight = simNow and simNow.lightDirection or vec3(0, 1, 0) },
            shader = [[
                float4 main(PS_IN pin) {
                    float3 n = normalize(pin.NormalW);
                    float l = 0.30 + 0.70 * saturate(dot(n, gTestLight));
                    return pin.ApplyFog(float4(
                        gWhiteRefPoint * float3(0.55, 0.50, 0.45) * l, 1.0));
                }
            ]]
        })
        st.visorRedrawRef:setVisible(false, false)
        -- Opaque-stage defaults back for whatever draws next here.
        render.setCullMode(render.CullMode.Back)
        if not ok and not st.visorRedrawWarned then
            ac.warn(appNameDebug .. ' Redraw test: ' .. tostring(err))
            st.visorRedrawWarned = true
        end
    end
end)

------------------------------------------------------------
-- Main update
------------------------------------------------------------

function script.update(dt)

    --------------------------------------------------------
    -- Initialize
    --------------------------------------------------------

    if not initialized then

        initializeScene()

        return
    end


    
    --------------------------------------------------------
    -- Rain flow
    --------------------------------------------------------

    if not shaderInitialized then

        initShaders()

    else

        updateRainFlow(dt)
    end


    --------------------------------------------------------
    -- Driver Head Observation
    --
    -- IMPORTANT:
    -- This only reads the neck.
    -- It does NOT modify camera or visor.
    --------------------------------------------------------

    observeDriverHead(dt)


    if not visor then  

        ac.overrideCameraClipPlanes(nil, nil)

        return
    end


    --------------------------------------------------------
    -- Visibility
    --------------------------------------------------------

    visor:setVisible(
        activeEnableMode == 1 and true or false
    )


    if activeEnableMode ~= 1 then
        -- ac.log(appNameDebug .. ' cfg.RUNTIME.ENABLED = false update terminated')
        return
    end


    updateHelmetVisibility()


    --------------------------------------------------------
    -- Visor transform
    --------------------------------------------------------

    updateVisorTransform()


    --------------------------------------------------------
    -- Local offset
    --------------------------------------------------------

    updateOffset()


    --------------------------------------------------------
    -- G-force Motion 
    --------------------------------------------------------

    updateMotion(dt)


    --------------------------------------------------------
    -- Calibration
    --------------------------------------------------------

    applyScale()

    applyAxisCorrection()

    if cfg.RUNTIME.RAIN_VISOR_MOTION_TEST_CLEAR then
        rainDynamicSceneCopyState.visorClearMotion()
    end

end


------------------------------------------------------------
-- Material Parameter Prototype: UI draw helpers
--
-- These only read/write extDirtValues (UI state). Nothing here
-- touches the material -- that only happens in
-- applyMaterialParams(), on "Refresh".
------------------------------------------------------------


local function drawFloatParam(editor, label, paramName, fmt)
    
    local entry = 
        editor.values[paramName]
        

    if not entry then
        
        ui.text(
            label .. ': N/A'
        )

        return
    end


    if editor.inputBuffers[paramName] == nil then

        editor.inputBuffers[paramName] =
            string.format(
                fmt or '%.3f', 
                entry.value
            )
    end

    
    local newText, changed, enterPressed =
    ui.inputText(
            label 
            .. '##'
            .. editor.id
            .. '_'
            .. paramName,

            editor.inputBuffers[paramName]
        )


    if changed then

        editor.inputBuffers[paramName] = 
        newText

        local numberValue = 
        tonumber(newText)

        if numberValue ~= nil then        

            entry.value = 
            numberValue
        end
    end


    if enterPressed then

        materialInputApplyRequested = 
        true
    end
    
end


local function drawBoolParam(editor, label, paramName)
    
    local entry = 
        editor.values[paramName]

        if not entry then
        return
    end


    local changed, _ =
        ui.checkbox(
            label
            .. '##'
            .. editor.id
            .. '_'
            .. paramName,
            
            entry.value
        )

    if changed then

        entry.value = 
        not entry.value
    end
end


local function drawVec2Param(editor, labelX, labelY, paramName, minV, maxV, fmt)

    local entry = 
        editor.values[paramName]
        
    if not entry then
        return
    end


    local nx, changedX =
        ui.slider(
            labelX, 
            entry.value.x, 
            minV, 
            maxV, 
            fmt or '%.3f'
        )


    if changedX then
        entry.value.x = nx
    end


    ui.sameLine(0, 20)

    
    local ny, changedY =
    ui.slider(
            labelY, 
            entry.value.y, 
            minV, 
            maxV, 
            fmt or '%.3f'
        )


    if changedY then
        entry.value.y = ny
    end
end


local function drawVec3Param(editor, label, paramName, minV, maxV, fmt)

    local entry = editor.values[paramName]

    if not entry then
        return
    end
    
    ui.text(label)

    local nx, cx = ui.slider(label .. ' R', entry.value.x, minV, maxV, fmt or '%.3f')
    if cx then entry.value.x = nx end

    local ny, cy = ui.slider(label .. ' G', entry.value.y, minV, maxV, fmt or '%.3f')
    if cy then entry.value.y = ny end

    local nz, cz = ui.slider(label .. ' B', entry.value.z, minV, maxV, fmt or '%.3f')
    if cz then entry.value.z = nz end
end    


------------------------------------------------------------
-- v0.4.0
-- Draw UI Integrated 
------------------------------------------------------------

local function drawMaterialParameters(editor)

    local currentGroup = 
        nil

    for _, paramDef in ipairs(
        editor.parameters
    ) do
        
        ------------------------------------------------------------
        -- Change Group
        ------------------------------------------------------------
        
        if paramDef.group
            and paramDef.group ~= currentGroup then
            
            if currentGroup ~= nil then
                
                ui.separator()
            end

            ui.text(
                paramDef.group
            )

            currentGroup = 
                paramDef.group
        end


        ------------------------------------------------------------
        -- Separeted UI Design by value types
        ------------------------------------------------------------
        
        if paramDef.type == 'float' then
            
            drawFloatParam(
                editor,

                paramDef.label
                    or paramDef.name,

                paramDef.name,

                paramDef.format
            )


        elseif  paramDef.type == 'bool' then

            drawBoolParam(

                editor,

                paramDef.label
                    or paramDef.name,

                paramDef.name
            )

        elseif paramDef.type == 'vec2' then

            drawVec2Param(

                editor,

                paramDef.labelX
                    or 'X',
                
                paramDef.labelY
                    or 'Y',
                
                paramDef.name,

                paramDef.rangeMin,

                paramDef.rangeMax,

                paramDef.format
            )

        elseif paramDef.type == 'vec3' then

            drawVec3Param(

                editor,

                paramDef.label
                    or paramDef.name,

                paramDef.name,

                paramDef.rangeMin,

                paramDef.rangeMax,

                paramDef.format
            )
        end
    end
end


------------------------------------------------------------
-- Material Parameter Prototype: floating editor window
--
-- ui.beginWindow / ui.endWindow open an auxiliary floating window
-- independent of the app's main window (per CSP's own ui.beginWindow
-- API) -- verify signature against your local CSP Lua docs if it
-- doesn't compile on your CSP build; ui.openPopup / ui.beginPopup
-- is the documented fallback.
-- NOTE: Use openPopup/beginPopup instead
------------------------------------------------------------


local function drawMaterialEditorWindow(editor)

    if not materialEditWindowOpen 
        or not editor then

        return
    end

    if ui.beginPopup(strMaterialEditorPopup) then

        ui.text(
            editor.materialName
            .. ' - Material'
        )

        ui.separator()


        local overlayItem = rainDynamicSceneCopyState.visorLayerItemFor
            and rainDynamicSceneCopyState.visorLayerItemFor(editor.meshName)
        if overlayItem then

            -- s56: custom-shader (*_OVERLAY) meshes: our shader parameters
            -- instead of the DUMMY KN5 material.
            rainDynamicSceneCopyState.visorLayerParamUI(editor, overlayItem)

        elseif not editor.materialQueryRef
            or #editor.materialQueryRef == 0 then

            ui.text(
                'Material not found: ' 
                .. editor.materialName
            )

        elseif not editor.loaded then

            ui.text(
                'Parameters not loaded yet.'
            )

        else


            drawMaterialParameters(
                editor
            )
        end


        ui.separator()


        if ui.button('Refresh') 
            or materialInputApplyRequested then

                materialInputApplyRequested = false
                applyMaterialParams(editor)
        end


        ui.sameLine(0, 15)

        if ui.button('Reload from material') then

            loadMaterialParams(editor)
        end


        ui.sameLine(0, 15)


        if ui.button('Close') then

            materialEditWindowOpen = false

            activeMaterialEditor = nil

            ui.closePopup()
        end


        if editor.lastError then
            ui.text('Last error: ' .. editor.lastError)
        end

        -- s56 fix: every successful beginPopup needs endPopup (it was
        -- missing, which broke the popup and the window after it opened).
        ui.endPopup()
    end
end


------------------------------------------------------------
-- Main window
------------------------------------------------------------


-- RainFX UI: callbacks keep local variables isolated and only draw open panels.
rainDynamicSceneCopyState.rainUIPanels = {}
rainDynamicSceneCopyState.rainUISlider = function(label, key, lo, hi, fmt)
    local value, changed = ui.slider(label, cfg.RUNTIME[key], lo, hi, fmt)
    if changed then cfg.RUNTIME[key] = value end
    local help = rainDynamicSceneCopyState.uiHelp
    if help[key] and ui.itemHovered() then ui.setTooltip(help[key]) end
end
rainDynamicSceneCopyState.rainUICheck = function(label, key)
    if ui.checkbox(label, cfg.RUNTIME[key]) then cfg.RUNTIME[key] = not cfg.RUNTIME[key] end
    local help = rainDynamicSceneCopyState.uiHelp
    if help[key] and ui.itemHovered() then ui.setTooltip(help[key]) end
end
rainDynamicSceneCopyState.rainUIGroup = function(label, key)
    local id = '##RainFX_' .. key
    if ui.button(label .. id, vec2(math.max(160, ui.availableSpaceX()), 0)) then ui.openPopup(id) end
    if ui.beginPopup(id) then
        ui.text(label)
        ui.sameLine()
        if ui.button('Close##RainFXClose') then ui.closePopup() end
        ui.separator()
        -- Clamp popup height to the current display; long panels scroll.
        local display = ac.getUI().windowSize
        local ok, err = pcall(ui.childWindow, '##RainFXContent',
            vec2(math.min(780, math.max(330, display.x - 80)),
                math.min(600, math.max(180, display.y - 140))), false,
            rainDynamicSceneCopyState.rainUIPanels[key])
        if not ok then ui.text('Panel error: ' .. tostring(err)) end
        ui.endPopup()
    end
end

rainDynamicSceneCopyState.rainUIUpdateProfile = function()
    if not cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING then return end
    local p = rainDynamicSceneCopyState
    p.profBirthAvg = (p.profBirthAvg or 0) * 0.95 + (p.profBirthMs or 0) * 0.05
    p.profTrailAvg = (p.profTrailAvg or 0) * 0.95 + (p.profTrailMaskMs or 0) * 0.05
    p.profBuildAvg = (p.profBuildAvg or 0) * 0.95 + (p.profCpuBuildMs or 0) * 0.05
    p.profOverlayAvg = (p.profOverlayAvg or 0) * 0.95 + (p.profHeadOverlayMs or 0) * 0.05
    p.profWaterTrailAvg = (p.profWaterTrailAvg or 0) * 0.95 + (p.profWaterTrailMs or 0) * 0.05
    p.profSplashStateAvg = (p.profSplashStateAvg or 0) * 0.95
        + (p.profSplashStateMs or 0) * 0.05
    p.profOverrideWriteAvg = (p.profOverrideWriteAvg or 0) * 0.95
        + (p.profOverrideWriteMs or 0) * 0.05
    cfg.RUNTIME.AVG_TIME_X_MIN = cfg.RUNTIME.AVG_TIME_X_MIN == 0.0 and p.profBirthAvg or math.min(cfg.RUNTIME.AVG_TIME_X_MIN, (p.profBirthAvg or 0.0))
    cfg.RUNTIME.AVG_TIME_X_MAX = cfg.RUNTIME.AVG_TIME_X_MAX == 0.0 and p.profBirthAvg or math.max(cfg.RUNTIME.AVG_TIME_X_MAX, (p.profBirthAvg or 0.0))
    cfg.RUNTIME.AVG_TIME_Y_MIN = cfg.RUNTIME.AVG_TIME_Y_MIN == 0.0 and p.profTrailAvg or math.min(cfg.RUNTIME.AVG_TIME_Y_MIN, (p.profTrailAvg or 0.0))
    cfg.RUNTIME.AVG_TIME_Y_MAX = cfg.RUNTIME.AVG_TIME_Y_MAX == 0.0 and p.profTrailAvg or math.max(cfg.RUNTIME.AVG_TIME_Y_MAX, (p.profTrailAvg or 0.0))
end

rainDynamicSceneCopyState.rainUIPanels['population'] = function()
    ui.separator()
    ui.text('Lifecycle test: -1 = live rain, 0 = dry, 0.5 = medium, 1 = heavy.')
    local rainOverride, rainOverrideChanged = ui.slider(
        'Lifecycle rain override',
        cfg.RUNTIME.RAIN_GPU_STATE_RAIN_OVERRIDE,
        -1.0, 1.0, '%.2f'
    )
    if rainOverrideChanged then
        cfg.RUNTIME.RAIN_GPU_STATE_RAIN_OVERRIDE = rainOverride
    end
    do
        local count, changed = ui.slider('GPU drop slots (restart game)',
            cfg.RUNTIME.RAIN_GPU_STATE_COUNT, 512.0, 4096.0, '%.0f')
        if changed then
            cfg.RUNTIME.RAIN_GPU_STATE_COUNT =
                math.max(512, math.min(4096,
                    math.floor(count / 512 + 0.5) * 512))
        end
        ui.text('Allocated slots: '
            .. tostring(rainDynamicSceneCopyState.allocatedStateCount or 0)
            .. ' / selected: '
            .. tostring(cfg.RUNTIME.RAIN_GPU_STATE_COUNT))
        ui.text('512 = baseline; 3072 = 6x capacity. Change needs game restart.')
        ui.text('Birth mask redraw and GPU readback scale with live slots; compare FPS.')
        if ui.checkbox('Pre-laid GPU birth sites (R1.2)',
            cfg.RUNTIME.RAIN_GPU_PRELAID_SITES) then
            cfg.RUNTIME.RAIN_GPU_PRELAID_SITES =
                not cfg.RUNTIME.RAIN_GPU_PRELAID_SITES
        end
        if cfg.RUNTIME.RAIN_GPU_PRELAID_SITES then
            ui.text(string.format('Birth atlas: %s | %d sites%s',
                rainDynamicSceneCopyState.spawnAtlas and 'ready' or 'pending',
                rainDynamicSceneCopyState.spawnAtlasCount or 0,
                rainDynamicSceneCopyState.spawnAtlasError
                    and (' | ' .. rainDynamicSceneCopyState.spawnAtlasError) or ''))
            if ui.checkbox('Preview birth atlas (R=U, G=V+1, B=order)',
                cfg.RUNTIME.RAIN_GPU_PRELAID_DEBUG) then
                cfg.RUNTIME.RAIN_GPU_PRELAID_DEBUG =
                    not cfg.RUNTIME.RAIN_GPU_PRELAID_DEBUG
            end
            if cfg.RUNTIME.RAIN_GPU_PRELAID_DEBUG
                and rainDynamicSceneCopyState.spawnAtlas then
                ui.image(rainDynamicSceneCopyState.spawnAtlas, vec2(320, 24))
            end
        end
    end
    local densityScale, densityChanged = ui.slider(
        'Moving drop density',
        cfg.RUNTIME.RAIN_GPU_STATE_DENSITY_SCALE,
        0.5, 2.0, '%.2f'
    )
    if densityChanged then
        cfg.RUNTIME.RAIN_GPU_STATE_DENSITY_SCALE = densityScale
    end
end

rainDynamicSceneCopyState.rainUIPanels['birth_size'] = function()
    ui.separator()
    ui.text('Moving droplet birth size (mm): weather keyframes')
    ui.text('Dry=0, Light=0.03, Rain=0.50, Heavy=1.00. New births only.')
    do
        for _, key in ipairs({
            { 'Dry minimum', 'RAIN_GPU_SIZE_MIN_DRY' },
            { 'Dry maximum', 'RAIN_GPU_SIZE_MAX_DRY' },
            { 'Light minimum', 'RAIN_GPU_SIZE_MIN_LIGHT' },
            { 'Light maximum', 'RAIN_GPU_SIZE_MAX_LIGHT' },
            { 'Rain minimum', 'RAIN_GPU_SIZE_MIN_RAIN' },
            { 'Rain maximum', 'RAIN_GPU_SIZE_MAX_RAIN' },
            { 'Heavy minimum', 'RAIN_GPU_SIZE_MIN_HEAVY' },
            { 'Heavy maximum', 'RAIN_GPU_SIZE_MAX_HEAVY' },
            { 'Rare minimum', 'RAIN_GPU_SIZE_MIN_RARE' },
            { 'Rare maximum', 'RAIN_GPU_SIZE_MAX_RARE' },
        }) do
            local value, changed = ui.slider(key[1] .. ' (mm)',
                cfg.RUNTIME[key[2]], 0.15, 6.0, '%.2f')
            if changed then cfg.RUNTIME[key[2]] = value end
        end
        local value, changed = ui.slider('Birth size small-drop bias',
            cfg.RUNTIME.RAIN_GPU_SIZE_BIAS, 0.5, 4.0, '%.2f')
        if changed then cfg.RUNTIME.RAIN_GPU_SIZE_BIAS = value end


        local strSliderChanceRareDry = 'Rare'
                                    .. string.format('%.2f', cfg.RUNTIME.RAIN_GPU_SIZE_MIN_RARE)
                                    .. 'mm chance at dry'
        value, changed = ui.slider(strSliderChanceRareDry,
                                    cfg.RUNTIME.RAIN_GPU_SIZE_RARECHANCE_DRY, 0.0, 0.03, '%.3f')
        if changed then cfg.RUNTIME.RAIN_GPU_SIZE_RARECHANCE_DRY = value end


        local strSliderChanceRareHeavy = 'Rare'
                                    .. string.format('%.2f', cfg.RUNTIME.RAIN_GPU_SIZE_MAX_RARE)
                                    .. 'mm chance at heavy'
        value, changed = ui.slider(strSliderChanceRareHeavy,
                                    cfg.RUNTIME.RAIN_GPU_SIZE_RARECHANCE_HEAVY, 0.0, 0.03, '%.3f')
        if changed then cfg.RUNTIME.RAIN_GPU_SIZE_RARECHANCE_HEAVY = value end
    end
    do
        local value, changed = ui.slider('Extra capacity rain ramp',
                                    cfg.RUNTIME.RAIN_GPU_STATE_CAPACITY_RAMP_POWER,
                                    0.4, 3.0, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_GPU_STATE_CAPACITY_RAMP_POWER = value
        end
        ui.text('At 0.03 rain, preserve the 512-slot population;')
        ui.text('at 1.00 rain, use all selected slots.')
    end
end

rainDynamicSceneCopyState.rainUIPanels['lifecycle'] = function()
    local exposureGain, exposureChanged = ui.slider(
        'Driving rain exposure gain',
        cfg.RUNTIME.RAIN_GPU_STATE_SPEED_EXPOSURE_GAIN,
        0.0, 2.0, '%.2f'
    )
    if exposureChanged then
        cfg.RUNTIME.RAIN_GPU_STATE_SPEED_EXPOSURE_GAIN = exposureGain
    end
    local minimumAge, minimumAgeChanged = ui.slider(
        'Moving drop minimum age (seconds)',
        cfg.RUNTIME.RAIN_GPU_STATE_AGE_MIN_SECONDS,
        1.0, 30.0, '%.1f'
    )
    if minimumAgeChanged then
        cfg.RUNTIME.RAIN_GPU_STATE_AGE_MIN_SECONDS = minimumAge
        cfg.RUNTIME.RAIN_GPU_STATE_AGE_MAX_SECONDS = math.max(
            minimumAge, cfg.RUNTIME.RAIN_GPU_STATE_AGE_MAX_SECONDS)
    end
    local maximumAge, maximumAgeChanged = ui.slider(
        'Moving drop maximum age (seconds)',
        cfg.RUNTIME.RAIN_GPU_STATE_AGE_MAX_SECONDS,
        1.0, 45.0, '%.1f'
    )
    if maximumAgeChanged then
        cfg.RUNTIME.RAIN_GPU_STATE_AGE_MAX_SECONDS = maximumAge
        cfg.RUNTIME.RAIN_GPU_STATE_AGE_MIN_SECONDS = math.min(
            maximumAge, cfg.RUNTIME.RAIN_GPU_STATE_AGE_MIN_SECONDS)
    end
    ui.text('Boundary exits remain active; age sliders change live GPU state.')
end

rainDynamicSceneCopyState.rainUIPanels['forces'] = function()
    local tfSlider = rainDynamicSceneCopyState.rainUISlider
    local tfCheck = rainDynamicSceneCopyState.rainUICheck
    local movingCap, movingCapChanged = ui.slider(
        'Moving drop speed / calibrated cap',
        cfg.RUNTIME.RAIN_GPU_STATE_MOBILE_SPEED_MULTIPLIER,
        1.0, 24.0, '%.1f'
    )
    if movingCapChanged then
        cfg.RUNTIME.RAIN_GPU_STATE_MOBILE_SPEED_MULTIPLIER = movingCap
    end
    local movingDrag, movingDragChanged = ui.slider(
        'Moving drop drag',
        cfg.RUNTIME.RAIN_GPU_STATE_MOBILE_DRAG,
        0.0, 4.0, '%.2f'
    )
    if movingDragChanged then
        cfg.RUNTIME.RAIN_GPU_STATE_MOBILE_DRAG = movingDrag
    end
    ui.text('Driving blend: stopped below 2 m/s; full at 18 m/s.')

        ui.text(cfg.RUNTIME.RAIN_GPU_STATE_WETPATH_SHADER
            and 'Wet-path shader code: available' or 'Wet-path shader code: OFF; steering controls have no effect (reload required).')
        tfCheck('Wet-path steering (needs WETPATH_SHADER)', 'RAIN_GPU_STATE_WETPATH_ENABLED')
        tfSlider('Wet-path gain', 'RAIN_GPU_STATE_WETPATH_GAIN', 0.0, 4.0, '%.2f')
        tfSlider('Wet-path min speed', 'RAIN_GPU_STATE_WETPATH_MIN_SPEED', 0.0, 0.05, '%.4f')
        tfSlider('Wet-path look-ahead (radii)', 'RAIN_GPU_STATE_WETPATH_AHEAD', 0.0, 5.0, '%.2f')
        tfSlider('Steering max turn rate (rad/s)', 'RAIN_GPU_STATE_STEER_TURN_RATE', 0.0, 10.0, '%.2f')
        tfSlider('Birth hold (s)', 'RAIN_GPU_STATE_BIRTH_HOLD_SECONDS', 0.0, 5.0, '%.2f')
        tfSlider('Birth ramp (s)', 'RAIN_GPU_STATE_BIRTH_RAMP_SECONDS', 0.0, 5.0, '%.2f')
    --------------------------------------------------------
    -- Unified external-force source controls (Phase A)
    -- The three checkboxes feed one GPU bitmask. The shader then
    -- evaluates all enabled sources through one common pipeline.
    --------------------------------------------------------
    ui.separator()
    ui.text('External Force Sources (Phase A)')

    local gravityChanged, _ = ui.checkbox(
        'Gravity',
        cfg.RUNTIME.RAIN_FORCE_GRAVITY_ENABLED
    )
    if gravityChanged then
        cfg.RUNTIME.RAIN_FORCE_GRAVITY_ENABLED =
            not cfg.RUNTIME.RAIN_FORCE_GRAVITY_ENABLED
    end

    local inertiaChanged, _ = ui.checkbox(
        'Vehicle Inertia',
        cfg.RUNTIME.RAIN_FORCE_INERTIA_ENABLED
    )
    if inertiaChanged then
        cfg.RUNTIME.RAIN_FORCE_INERTIA_ENABLED =
            not cfg.RUNTIME.RAIN_FORCE_INERTIA_ENABLED
    end

    local airflowChanged, _ = ui.checkbox(
        'Airflow',
        cfg.RUNTIME.RAIN_FORCE_AIRFLOW_ENABLED
    )
    if airflowChanged then
        cfg.RUNTIME.RAIN_FORCE_AIRFLOW_ENABLED =
            not cfg.RUNTIME.RAIN_FORCE_AIRFLOW_ENABLED
    end

    local airflowModeChanged, _ = ui.checkbox(
        'Airflow follows visor downward (compare with original)',
        cfg.RUNTIME.RAIN_AIRFLOW_DOWNWARD_MODE
    )
    if airflowModeChanged then
        cfg.RUNTIME.RAIN_AIRFLOW_DOWNWARD_MODE =
            not cfg.RUNTIME.RAIN_AIRFLOW_DOWNWARD_MODE
    end
    local airflowDownGain, airflowDownGainChanged = ui.slider(
        'Airflow downward / outward coupling',
        cfg.RUNTIME.RAIN_AIRFLOW_DOWNWARD_GAIN,
        0.0, 3.0, '%.2f'
    )
    if airflowDownGainChanged then
        cfg.RUNTIME.RAIN_AIRFLOW_DOWNWARD_GAIN = airflowDownGain
    end
    ui.text('Mode affects settled moving drops only when Airflow is enabled.')
    local windChanged = ui.checkbox('Airflow includes track wind',
        cfg.RUNTIME.RAIN_FORCE_AIRFLOW_INCLUDE_WIND)
    if windChanged then
        cfg.RUNTIME.RAIN_FORCE_AIRFLOW_INCLUDE_WIND =
            not cfg.RUNTIME.RAIN_FORCE_AIRFLOW_INCLUDE_WIND
    end
    ui.text(string.format('Airflow source: %s  wind (%.2f, %.2f) m/s',
        cfg.RUNTIME.RAIN_FORCE_AIRFLOW_INCLUDE_WIND and 'car + track wind'
            or 'car only',
        rainDynamicSceneCopyState.airflowWindX or 0.0,
        rainDynamicSceneCopyState.airflowWindZ or 0.0))

    local activeForceMask =
        (cfg.RUNTIME.RAIN_FORCE_GRAVITY_ENABLED and RAIN_FORCE_GRAVITY or 0)
        + (cfg.RUNTIME.RAIN_FORCE_INERTIA_ENABLED and RAIN_FORCE_INERTIA or 0)
        + (cfg.RUNTIME.RAIN_FORCE_AIRFLOW_ENABLED and RAIN_FORCE_AIRFLOW or 0)

    ui.text(string.format(
        'Force mask: %d  [G:%s I:%s A:%s]',
        activeForceMask,
        cfg.RUNTIME.RAIN_FORCE_GRAVITY_ENABLED and 'ON' or 'OFF',
        cfg.RUNTIME.RAIN_FORCE_INERTIA_ENABLED and 'ON' or 'OFF',
        cfg.RUNTIME.RAIN_FORCE_AIRFLOW_ENABLED and 'ON' or 'OFF'
    ))
    ui.text('All enabled sources are summed in WORLD m/s^2, then projected once onto the visor surface.')

    ui.separator()
    ui.text('Settled-water physics tuning (temporary)')
    ui.text('Changes apply live. Set one source at a time before mixing forces.')
    for _, control in ipairs({
        {'Base force conversion', 'RAIN_PHYSICS_ACCEL_SCALE', 0.0, 0.20, '%.5f'},
        {'Gravity gain', 'RAIN_FORCE_GRAVITY_GAIN', 0.0, 4.0, '%.2f'},
        {'Inertia gain', 'RAIN_FORCE_INERTIA_GAIN', 0.0, 4.0, '%.2f'},
        {'Airflow gain', 'RAIN_FORCE_AIRFLOW_GAIN', 0.0, 2.0, '%.3f'},
        {'Static adhesion minimum', 'RAIN_ADHESION_MIN', 0.0, 4.0, '%.3f'},
        {'Static adhesion maximum', 'RAIN_ADHESION_MAX', 0.0, 4.0, '%.3f'},
        {'Kinetic adhesion / static', 'RAIN_GPU_STATE_KINETIC_ADHESION_FRACTION', 0.0, 1.0, '%.3f'},
        {'Flow acceleration', 'RAIN_FLOW_ACCELERATION', 0.0, 0.30, '%.4f'},
        {'Flow force gain in motion', 'RAIN_GPU_STATE_MOVING_FORCE_GAIN', 0.0, 40.0, '%.2f'},
        {'Flow speed scale', 'RAIN_FLOW_SPEED_SCALE', 0.0, 8.0, '%.2f'},
        {'Flow drag when pinned', 'RAIN_FLOW_DRAG', 0.0, 20.0, '%.2f'},
        {'Movement threshold (UV/s)', 'RAIN_GPU_STATE_MOBILE_THRESHOLD_UV', 0.0011, 0.050, '%.4f'},
        {'Surface speed 1 mm (UV/s)', 'RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_1MM', 0.001, 1.00, '%.4f'},
    }) do
        local value, sliderChanged = ui.slider(
            control[1], cfg.RUNTIME[control[2]],
            control[3], control[4], control[5]
        )
        if sliderChanged then
            cfg.RUNTIME[control[2]] = value
            if control[2] == 'RAIN_ADHESION_MIN' then
                cfg.RUNTIME.RAIN_ADHESION_MAX = math.max(
                    value, cfg.RUNTIME.RAIN_ADHESION_MAX)
            elseif control[2] == 'RAIN_ADHESION_MAX' then
                cfg.RUNTIME.RAIN_ADHESION_MIN = math.min(
                    value, cfg.RUNTIME.RAIN_ADHESION_MIN)
            end
        end
    end

    --------------------------------------------------------
    -- Phase A validation
    --------------------------------------------------------
    ui.separator()
    ui.text('Canonical force-source isolation')
    ui.text('Use STATE_MODE = 3. Test one source at a time, then enable combinations:')
    ui.text('1) Gravity only -> 2) Inertia only -> 3) Gravity + Inertia -> 4) Airflow')
    ui.text('Enable or disable airflow above to isolate its contribution.')
end

rainDynamicSceneCopyState.rainUIPanels['merge'] = function()
    ui.separator()
    ui.text('Coalescence and absorption steering')
    do
        local function coSlider(label, key, minV, maxV, fmt)
            local value, changed = ui.slider(label,
                cfg.RUNTIME[key], minV, maxV, fmt)
            if changed then cfg.RUNTIME[key] = value end
        end
        if ui.checkbox('Merge overlapping drops (mass/volume)',
            cfg.RUNTIME.RAIN_GPU_STATE_MERGE_ENABLED) then
            cfg.RUNTIME.RAIN_GPU_STATE_MERGE_ENABLED =
                not cfg.RUNTIME.RAIN_GPU_STATE_MERGE_ENABLED
        end
        coSlider('Merge reach (x r1+r2)',
            'RAIN_GPU_STATE_MERGE_REACH', 0.3, 1.5, '%.2f')
        coSlider('Merge max diameter (mm)',
            'RAIN_GPU_STATE_MERGE_MAX_DIAMETER_MM', 1.0, 10.0, '%.1f')
        coSlider('Merge pairs per snapshot',
            'RAIN_GPU_STATE_MERGE_MAX_PAIRS', 0, 1024, '%.0f')
        if ui.checkbox('Steer moving drops toward neighbours',
            cfg.RUNTIME.RAIN_GPU_STATE_ATTRACT_ENABLED) then
            cfg.RUNTIME.RAIN_GPU_STATE_ATTRACT_ENABLED =
                not cfg.RUNTIME.RAIN_GPU_STATE_ATTRACT_ENABLED
        end
        coSlider('Steer reach (x r1+r2)',
            'RAIN_GPU_STATE_ATTRACT_REACH', 1.0, 4.0, '%.2f')
        coSlider('Steer gain (UV/s^2)',
            'RAIN_GPU_STATE_ATTRACT_GAIN', 0.0, 0.3, '%.3f')
        coSlider('Steer min speed (UV/s)',
            'RAIN_GPU_STATE_ATTRACT_MIN_SPEED', 0.0, 0.02, '%.4f')
        coSlider('Steer cone (cos, 0 = half-plane)',
            'RAIN_GPU_STATE_ATTRACT_CONE', -1.0, 0.95, '%.2f')
        ui.text(string.format('Snapshot: %d merge pairs, %d steering | total pairs %d',
            rainDynamicSceneCopyState.mergePairs or 0,
            rainDynamicSceneCopyState.mergeAttracts or 0,
            rainDynamicSceneCopyState.mergePairsTotal or 0))
    end
end

rainDynamicSceneCopyState.rainUIPanels['birth_shape'] = function()
    ui.separator()
    ui.text('GPU head stamps (water-field source)')
    do
        local changed = ui.checkbox('GPU birth mask enabled',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED
        end
        changed = ui.checkbox('Birth mask only (hide old GPU heads)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ONLY)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ONLY =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ONLY
        end
        ui.text('Changing birth mask only requires game restart to rebuild mesh.')
        changed = ui.checkbox('Moving drop body stretch',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_BODY_STRETCH)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_BODY_STRETCH =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_BODY_STRETCH
        end
        changed = ui.checkbox('Asymmetric drop outline',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SHAPE_VARIATION)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SHAPE_VARIATION =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SHAPE_VARIATION
        end
        changed = ui.checkbox('Irregular large birth puddles',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_ENABLED)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_ENABLED =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_ENABLED
        end
        changed = ui.checkbox('Water-field heads weather sky tone',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SKY_CORRECTION)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SKY_CORRECTION =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SKY_CORRECTION
        end
        local value
        value, changed = ui.slider('Asymmetric outline strength',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SHAPE_STRENGTH,
            0.0, 1.5, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SHAPE_STRENGTH = value
        end
        value, changed = ui.slider('Puddle share of large births',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_SHARE,
            0.0, 1.0, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_SHARE = value
        end
        value, changed = ui.slider('Puddle minimum diameter (mm)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_MIN_MM,
            0.5, 5.0, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_MIN_MM = value
        end
        value, changed = ui.slider('Puddle lobe reach (radii)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_REACH,
            0.2, 1.3, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_PUDDLE_REACH = value
        end
        value, changed = ui.slider('Moving body lookback (seconds)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_BODY_LOOKBACK_SECONDS,
            0.0, 0.12, '%.3f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_BODY_LOOKBACK_SECONDS = value
        end
        value, changed = ui.slider('Moving body max reach (radii)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_BODY_MAX_RADII,
            0.0, 3.0, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_BODY_MAX_RADII = value
        end
        value, changed = ui.slider('Birth growth time (seconds)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_GROW_SECONDS,
            0.03, 0.35, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_GROW_SECONDS = value
        end
        value, changed = ui.combo('Birth mask resolution',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SIZE >= 2048 and 3
                or cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SIZE >= 1024 and 2
                or 1,
            { '512 x 512', '1024 x 1024', '2048 x 2048' })
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SIZE =
                ({ 512, 1024, 2048 })[value]
        end
    end
end

rainDynamicSceneCopyState.rainUIPanels['heads'] = function()
    local wfSlider = rainDynamicSceneCopyState.rainUISlider
        if ui.checkbox('Water field enabled',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_ENABLED) then
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_ENABLED =
                not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_ENABLED
        end
        local debug, debugChanged = ui.slider(
            'Water field debug (1 height, 2 slope, 3 large)',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_DEBUG, 0, 3, '%.0f')
        if debugChanged then
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_DEBUG =
                math.floor(debug + 0.5)
        end
        wfSlider('WF silhouette threshold',
            'RAIN_DYNAMIC_WATER_FIELD_THRESHOLD', 0.05, 0.9, '%.2f')
        wfSlider('WF kernel scale',
            'RAIN_DYNAMIC_WATER_FIELD_KERNEL_SCALE', 1.0, 2.0, '%.2f')
        wfSlider('WF refraction field (shot heights)',
            'RAIN_DYNAMIC_WATER_FIELD_REFRACTION', 0.0, 1.0, '%.2f')
        wfSlider('WF scene mip',
            'RAIN_DYNAMIC_WATER_FIELD_SCENE_MIP', 0.0, 8.0, '%.1f')
        wfSlider('WF extra mip at slope',
            'RAIN_DYNAMIC_WATER_FIELD_SLOPE_MIP', 0.0, 4.0, '%.1f')
        wfSlider('WF rim energy loss',
            'RAIN_DYNAMIC_WATER_FIELD_EDGE_LOSS', 0.0, 1.0, '%.2f')
        wfSlider('WF loss start slope',
            'RAIN_DYNAMIC_WATER_FIELD_LOSS_START', 0.0, 2.0, '%.2f')
        wfSlider('WF loss end slope',
            'RAIN_DYNAMIC_WATER_FIELD_LOSS_END', 0.1, 3.0, '%.2f')
        wfSlider('WF lower rim sky glint',
            'RAIN_DYNAMIC_WATER_FIELD_GLINT', 0.0, 2.0, '%.2f')
        wfSlider('WF head/splash sheet blur (legacy trail optics)',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_BLUR', 0.0, 5.0, '%.2f')
        wfSlider('WF opacity',
            'RAIN_DYNAMIC_WATER_FIELD_OPACITY', 0.0, 1.0, '%.2f')
        wfSlider('WF normal step (texels)',
            'RAIN_DYNAMIC_WATER_FIELD_NORMAL_STEP_TEXELS', 0.5, 4.0, '%.2f')
        wfSlider('WF motion stretch',
            'RAIN_DYNAMIC_WATER_FIELD_MOTION_STRETCH', 0.0, 2.0, '%.2f')
        if ui.checkbox('WF per-life lobes',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_LOBES) then
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_LOBES =
                not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_LOBES
        end
end

rainDynamicSceneCopyState.rainUIPanels['splash'] = function()
    local wfSlider = rainDynamicSceneCopyState.rainUISlider
        wfSlider('WF tear start (km/h)',
            'RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KMH', 0.0, 200.0, '%.0f')
        wfSlider('WF tear full (km/h)',
            'RAIN_DYNAMIC_WATER_FIELD_TEAR_FULL_KMH', 10.0, 300.0, '%.0f')
        wfSlider('WF torn impact: heavy size range (%)',
            'RAIN_DYNAMIC_WATER_FIELD_TEAR_HEAVY_SIZE_PERCENT',
            0.0, 100.0, '%.0f')
        do
            local low = math.min(cfg.RUNTIME.RAIN_GPU_SIZE_MIN_HEAVY,
                cfg.RUNTIME.RAIN_GPU_SIZE_MAX_HEAVY)
            local high = math.max(cfg.RUNTIME.RAIN_GPU_SIZE_MIN_HEAVY,
                cfg.RUNTIME.RAIN_GPU_SIZE_MAX_HEAVY)
            local threshold = low + (high - low) * math.max(0.0, math.min(100.0,
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_HEAVY_SIZE_PERCENT)) * 0.01
            ui.text(string.format('Heavy birth size %.2f-%.2f mm | size trigger at %.2f mm or larger (or speed)',
                low, high, threshold))
        end
        if ui.checkbox('Impact splash v2 (press, ring, scatter)',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_V2) then
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_V2 =
                not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SPLASH_V2
        end
        wfSlider('Speed-only splash birth share',
            'RAIN_DYNAMIC_WATER_FIELD_SPLASH_SPEED_SHARE', 0.0, 1.0, '%.2f')
        wfSlider('Splash v2 duration (s)',
            'RAIN_DYNAMIC_WATER_FIELD_SPLASH_SECONDS', 0.05, 2.0, '%.2f')
        wfSlider('Splash v2 size ref (head texels)',
            'RAIN_DYNAMIC_WATER_FIELD_SPLASH_SIZE_REF', 1.0, 32.0, '%.1f')
        wfSlider('Splash v2 spread',
            'RAIN_DYNAMIC_WATER_FIELD_SPLASH_SPREAD', 0.0, 5.0, '%.2f')
        wfSlider('Splash v2 hollow at (t)',
            'RAIN_DYNAMIC_WATER_FIELD_SPLASH_HOLLOW_AT', 0.1, 1.0, '%.2f')
        wfSlider('Splash v2 break at (t)',
            'RAIN_DYNAMIC_WATER_FIELD_SPLASH_BREAK_AT', 0.1, 0.95, '%.2f')
        wfSlider('Splash v2 scatter',
            'RAIN_DYNAMIC_WATER_FIELD_SPLASH_SCATTER', 0.0, 5.0, '%.2f')
        wfSlider('Splash v2 residual drop',
            'RAIN_DYNAMIC_WATER_FIELD_SPLASH_RESIDUAL', 0.0, 1.0, '%.2f')
        wfSlider('WF tear min piece (texels)',
            'RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS', 0.5, 4.0, '%.2f')
end

rainDynamicSceneCopyState.rainUIPanels['trail'] = function()
    local tfSlider = rainDynamicSceneCopyState.rainUISlider
    local wfSlider = rainDynamicSceneCopyState.rainUISlider
    local tfCheck = rainDynamicSceneCopyState.rainUICheck
        tfSlider('Trail levelling (diffusion)', 'RAIN_DYNAMIC_WATER_FIELD_TRAIL_DIFFUSE', 0.0, 0.25, '%.3f')
        tfCheck('Fast sheets as ribbons', 'RAIN_DYNAMIC_WATER_FIELD_SHEET_RIBBON')
        tfSlider('Slope step (trail texels)', 'RAIN_DYNAMIC_WATER_FIELD_GRADIENT_TRAIL_TEXELS', 0.0, 3.0, '%.2f')
        ui.text('Trail refraction v2 (RAINFX_TRAIL_REFRACTION.md)')
        if ui.checkbox('Trails: cylindrical lens refraction (T1+T2)',
            cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_REFRACT_V2) then
            cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_REFRACT_V2 =
                not cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_REFRACT_V2
        end
        wfSlider('Trail image shift at slope 1 (px)',
            'RAIN_DYNAMIC_TRAIL_REFRACT_PX', 0.0, 60.0, '%.1f')
        wfSlider('Trail wide gradient step (texels)',
            'RAIN_DYNAMIC_TRAIL_GRAD_WIDE_TEXELS', 1.0, 10.0, '%.1f')
        wfSlider('Trail gradient mix (edge .. interior)',
            'RAIN_DYNAMIC_TRAIL_GRAD_MIX', 0.0, 1.0, '%.2f')
        wfSlider('Trail thickness range (G above threshold)',
            'RAIN_DYNAMIC_TRAIL_PROFILE_RANGE', 0.02, 1.0, '%.2f')
        wfSlider('Trail slope max',
            'RAIN_DYNAMIC_TRAIL_SLOPE_MAX', 0.2, 4.0, '%.2f')
        wfSlider('Trail base mip (sharpness)',
            'RAIN_DYNAMIC_TRAIL_MIP_BASE', 0.0, 4.0, '%.2f')
        wfSlider('Trail mip by curvature',
            'RAIN_DYNAMIC_TRAIL_MIP_SLOPE', 0.0, 4.0, '%.2f')
        wfSlider('Trail fast-flow sheet blur (mip)',
            'RAIN_DYNAMIC_TRAIL_SHEET_BLUR', 0.0, 4.0, '%.2f')
        wfSlider('T3 ripple amount (thickness)',
            'RAIN_DYNAMIC_TRAIL_RIPPLE_AMP', 0.0, 1.5, '%.2f')
        wfSlider('T3 ripple cells along flow',
            'RAIN_DYNAMIC_TRAIL_RIPPLE_ALONG', 5.0, 300.0, '%.0f')
        wfSlider('T3 ripple cells across flow',
            'RAIN_DYNAMIC_TRAIL_RIPPLE_ACROSS', 10.0, 600.0, '%.0f')
        wfSlider('T3 ripple speed (x drop flow)',
            'RAIN_DYNAMIC_TRAIL_RIPPLE_SPEED', 0.0, 3.0, '%.2f')
        ui.text(string.format('Mean drop flow (UV/s): %.3f, %.3f',
            rainDynamicSceneCopyState.flowU or 0.0,
            rainDynamicSceneCopyState.flowV or 0.0))
        wfSlider('T4 edge refraction boost',
            'RAIN_DYNAMIC_TRAIL_EDGE_BOOST', 0.0, 3.0, '%.2f')
        wfSlider('T4 edge from slope',
            'RAIN_DYNAMIC_TRAIL_EDGE_START', 0.0, 2.0, '%.2f')
        wfSlider('T4 edge full at slope',
            'RAIN_DYNAMIC_TRAIL_EDGE_END', 0.1, 3.0, '%.2f')
        wfSlider('T6 film / ridge bend boost',
            'RAIN_DYNAMIC_TRAIL_FILM_BOOST', 0.0, 6.0, '%.2f')
        if ui.checkbox('WF trails',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED) then
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED =
                not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED
        end
        wfSlider('WF trail/sheet min head radius (texels)',
            'RAIN_DYNAMIC_WATER_FIELD_TRAIL_MIN_RADIUS', 0.0, 4.0, '%.3f')
        wfSlider('WF trail/sheet minimum motion (UV/s)',
            'RAIN_DYNAMIC_WATER_FIELD_TRAIL_MIN_SPEED', 0.0, 0.1, '%.4f')
        wfSlider('WF trail/sheet head setback (radii)',
            'RAIN_DYNAMIC_WATER_FIELD_TRAIL_HEAD_BACK', 0.0, 2.0, '%.2f')
        wfSlider('WF trail lifetime (s)',
            'RAIN_DYNAMIC_WATER_FIELD_TRAIL_SECONDS', 0.1, 6.0, '%.2f')
        wfSlider('WF trail width (radii)',
            'RAIN_DYNAMIC_WATER_FIELD_TRAIL_WIDTH', 0.1, 1.0, '%.2f')
        wfSlider('WF trail bead noise',
            'RAIN_DYNAMIC_WATER_FIELD_TRAIL_NOISE', 0.0, 1.5, '%.2f')
        wfSlider('WF trail noise cells',
            'RAIN_DYNAMIC_WATER_FIELD_TRAIL_NOISE_CELLS', 50.0, 1500.0, '%.0f')
end

rainDynamicSceneCopyState.rainUIPanels['sheet'] = function()
    local wfSlider = rainDynamicSceneCopyState.rainUISlider
        ui.text('FAST-FLOW SHEET: activation gates')
        ui.text(cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING and 'Eligibility counters: active'
            or 'Eligibility counters OFF: enable profiling in GPU rendering and performance.')
        if ui.checkbox('WF fast-flow sheet film',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_ENABLED) then
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_ENABLED =
                not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_ENABLED
        end
        wfSlider('Sheet start speed (UV/s)',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_START_SPEED', 0.0, 0.3, '%.4f')
        wfSlider('Sheet full speed (UV/s)',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_FULL_SPEED', 0.0001, 0.5, '%.4f')
        ui.text(string.format('Required: birth mask %s | WF %s | trails %s | sheet %s',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED and 'ON' or 'OFF',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_ENABLED and 'ON' or 'OFF',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED and 'ON' or 'OFF',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_ENABLED and 'ON' or 'OFF'))
        ui.text(string.format('Per drop: radius > %.3f head-mask texels; motion >= minimum; sheet speed OR density.',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_MIN_RADIUS))
        ui.text('Shared radius / minimum motion: edit in Trail flow and optics.')
        ui.text(string.format('Trail minimum %.3f UV/s | observed max %.3f UV/s (not car km/h)',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_MIN_SPEED,
            rainDynamicSceneCopyState.waterTrailMaxSpeed or 0.0))
        if ui.checkbox('Allow density OR speed to trigger sheet (rain x airspeed)',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_GATE) then
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_GATE =
                not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_GATE
        end
        wfSlider('Sheet density start (0 below)',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_MIN', 0.0, 3.0, '%.2f')
        wfSlider('Sheet density full (not an upper cutoff)',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_FULL', 0.05, 5.0, '%.2f')
        ui.text(string.format('Sheet density contribution %.2f (density %.2f)',
            rainDynamicSceneCopyState.waterSheetDensity or 0.0,
            rainDynamicSceneCopyState.smearDensity or 0.0))
        wfSlider('Sheet density reference airspeed (shared with smear)',
            'RAIN_DYNAMIC_SMEAR_REF_KMH', 1.0, 400.0, '%.1f')
        ui.text(string.format('Density = rain %.2f x relative air %.0f / reference %.0f km/h',
            rainDynamicSceneCopyState.smearRain or 0.0,
            rainDynamicSceneCopyState.smearAirKmh or 0.0,
            cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_REF_KMH))
        ui.text('Trigger = max(speed ramp, density ramp). Either trigger uses the SAME sheet shape.')
        if cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_FULL_SPEED <= cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_START_SPEED then
            ui.text('Sheet speed range invalid: full should be greater than start.')
        end
        if cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_GATE
            and cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_FULL <= cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_DENSITY_MIN then
            ui.text('Sheet density range invalid: full should be greater than start.')
        end
        if cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED
            and cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_ENABLED
            and cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED then
            ui.text(string.format('Current samples %d | radius pass %d | radius + speed pass %d',
                rainDynamicSceneCopyState.waterSheetSamples or 0,
                rainDynamicSceneCopyState.waterSheetRadiusPassed or 0,
                rainDynamicSceneCopyState.waterSheetSpeedPassed or 0))
            ui.text(string.format('Radius + motion + (speed OR density) pass %d',
                rainDynamicSceneCopyState.waterSheetTriggerPassed or 0))
            ui.text(string.format('Generated sheet segments %d | strongest trigger factor %.2f | canvas %s',
                rainDynamicSceneCopyState.waterTrailSheets or 0,
                rainDynamicSceneCopyState.waterSheetMaxFactor or 0.0,
                rainDynamicSceneCopyState.waterTrailReady and 'ready' or 'pending'))
        else
            ui.text('Sheet update blocked: enable birth mask, WF and trails; counters are not current.')
        end
        ui.text(string.format('Visor surface renderer: micro pattern %s | birth canvas %s',
            cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_ENABLED and rainDynamicSceneCopyState.microPatternReady and 'ready' or 'OFF/pending',
            rainDynamicSceneCopyState.birthMaskRead and 'ready' or 'pending'))
        wfSlider('Sheet continuity max segment (head radii)',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_LINK_RADII', 0.5, 64.0, '%.1f')
        wfSlider('Sheet continuity minimum allowance (trail texels)',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_LINK_MIN_TEXELS', 0.0, 32.0, '%.2f')
        ui.text('Longer jumps restart the ribbon. Allowance = max(radius limit, texel floor).')
        ui.text('Shared sheet shape (applies to speed AND density triggers):')
        wfSlider('Sheet shape strength (independent of trigger)',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_FORM', 0.0, 1.0, '%.2f')
        wfSlider('Sheet minimum height (before decay)',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_HEIGHT_MIN', 0.0, 1.0, '%.2f')
        ui.text(string.format('Sheet base height %.2f | WF threshold %.2f | profile range %.2f',
            math.max(1.0 - cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_THIN
                * cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_FORM,
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_HEIGHT_MIN),
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_THRESHOLD,
            cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_PROFILE_RANGE))
        if math.max(1.0 - cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_THIN
            * cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_FORM,
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_SHEET_HEIGHT_MIN)
            <= cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_THRESHOLD then
            ui.text('Sheet height is below visibility threshold: only accumulated overlaps may show.')
        end
        ui.text('Appearance controls (do not trigger sheets):')
        wfSlider('Sheet widen (x trail width)',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_WIDEN', 0.0, 4.0, '%.2f')
        wfSlider('Sheet thinning (amplitude)',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_THIN', 0.0, 0.8, '%.2f')
        wfSlider('Sheet persistence',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_PERSIST', 0.0, 0.9, '%.2f')
        ui.text('Sheet optical blur: Trail flow and optics -> Trail fast-flow sheet blur.')
        wfSlider('Sheet milky veil',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_VEIL', 0.0, 0.8, '%.2f')
        wfSlider('Splash sheet factor',
            'RAIN_DYNAMIC_WATER_FIELD_SPLASH_SHEET', 0.0, 1.0, '%.2f')
        wfSlider('Sheet opacity (transparent film)',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_ALPHA', 0.0, 1.0, '%.2f')
        wfSlider('Sheet edge softness',
            'RAIN_DYNAMIC_WATER_FIELD_SHEET_EDGE_SOFT', 0.0, 0.35, '%.2f')
end

rainDynamicSceneCopyState.rainUIPanels['impact'] = function()
    local wfSlider = rainDynamicSceneCopyState.rainUISlider
        ui.text('LOCAL IMPACT FILM: separate from fast-flow sheet gates')
        ui.text('Requires birth mask + WF + trails + impact film; no density or sheet-speed gate.')
        ui.text('New water feed requires influx > start and live source samples inside the visor boundary.')
        ui.text('Influx = rain^3 + rain x frontal relative air / 180; existing film decays below start.')
        if ui.checkbox('Local impact film prototype',
            cfg.RUNTIME.RAIN_DYNAMIC_IMPACT_SHEET_ENABLED) then
            cfg.RUNTIME.RAIN_DYNAMIC_IMPACT_SHEET_ENABLED =
                not cfg.RUNTIME.RAIN_DYNAMIC_IMPACT_SHEET_ENABLED
        end
        wfSlider('Impact film influx start (provisional)',
            'RAIN_DYNAMIC_IMPACT_SHEET_FLUX_START', 0.0, 3.0, '%.2f')
        wfSlider('Impact film water feed',
            'RAIN_DYNAMIC_IMPACT_SHEET_FEED', 0.1, 6.0, '%.2f')
        wfSlider('Impact film life (s)',
            'RAIN_DYNAMIC_IMPACT_SHEET_SECONDS', 0.1, 2.0, '%.2f')
        wfSlider('Impact film refraction on smear',
            'RAIN_DYNAMIC_IMPACT_SHEET_SMEAR_MIX', 0.0, 1.0, '%.2f')
        wfSlider('Impact film wave refraction (px)',
            'RAIN_DYNAMIC_IMPACT_SHEET_WAVE_PX', 0.0, 60.0, '%.1f')
        wfSlider('Impact film opacity (1 = opaque)',
            'RAIN_DYNAMIC_IMPACT_SHEET_OPACITY', 0.0, 1.0, '%.2f')
        ui.text(string.format('Impact film: influx %.2f | feed %.2f/s | frontal air %.0f km/h | %.2f ms',
            rainDynamicSceneCopyState.impactFlux or 0.0,
            rainDynamicSceneCopyState.impactFeed or 0.0,
            rainDynamicSceneCopyState.impactFrontal or 0.0,
            rainDynamicSceneCopyState.profImpactSheetMs or 0.0))
        ui.text(string.format('Impact film state: %s | source samples %d',
            rainDynamicSceneCopyState.impactSheetReady and 'ready' or 'pending/off',
            rainDynamicSceneCopyState.impactSourceCount or 0))
        if rainDynamicSceneCopyState.impactSheetError then
            ui.text('Impact film error: '
                .. rainDynamicSceneCopyState.impactSheetError)
        end
end

rainDynamicSceneCopyState.rainUIPanels['micro'] = function()
    local tfSlider = rainDynamicSceneCopyState.rainUISlider
    local wfSlider = rainDynamicSceneCopyState.rainUISlider
    local tfCheck = rainDynamicSceneCopyState.rainUICheck
        ui.text('Micro pop-in (random landing)')
        tfCheck('Micro pop-in', 'RAIN_DYNAMIC_MICRO_POP_ENABLED')
        tfCheck('Micro exact point reads (Load)', 'RAIN_DYNAMIC_MICRO_POINT_LOAD')
        tfSlider('Pop pickup share', 'RAIN_DYNAMIC_MICRO_POP_PICK', 0.0, 1.0, '%.2f')
        tfSlider('Pop period (s)', 'RAIN_DYNAMIC_MICRO_POP_PERIOD', 0.5, 60.0, '%.1f')
        tfSlider('Pop absent share', 'RAIN_DYNAMIC_MICRO_POP_OFF', 0.0, 0.95, '%.2f')
        tfSlider('Pop fade-out share', 'RAIN_DYNAMIC_MICRO_POP_FADE', 0.0, 1.0, '%.2f')
        tfSlider('Pop landing flash', 'RAIN_DYNAMIC_MICRO_POP_FLASH', 0.0, 2.0, '%.2f')
        tfSlider('Pop id cells', 'RAIN_DYNAMIC_MICRO_POP_ID_SCALE', 0.25, 4.0, '%.2f')
        ui.text('Micro pattern bake (re-bakes 0.4 s after a change)')
        wfSlider('Micro disk diameter (mm)',
            'RAIN_DYNAMIC_MICRO_PATTERN_DIAMETER_MM', 0.2, 3.0, '%.2f')
        wfSlider('Micro pixelation (texels per cell)',
            'RAIN_DYNAMIC_MICRO_PATTERN_TEXELS_PER_CELL', 1.5, 12.0, '%.2f')
        wfSlider('Micro cut line (texels)',
            'RAIN_DYNAMIC_MICRO_PATTERN_RIM_TEXELS', 0.0, 2.0, '%.2f')
        wfSlider('Micro strata',
            'RAIN_DYNAMIC_MICRO_PATTERN_STRATA', 1.0, 6.0, '%.0f')
        wfSlider('Micro first stratum presence',
            'RAIN_DYNAMIC_MICRO_PATTERN_FIRST_PRESENCE', 0.0, 1.0, '%.2f')
        wfSlider('Micro stratum presence',
            'RAIN_DYNAMIC_MICRO_PATTERN_PRESENCE', 0.0, 1.0, '%.2f')
        wfSlider('Micro radius min (cells)',
            'RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MIN', 0.15, 0.85, '%.2f')
        wfSlider('Micro radius max (cells)',
            'RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MAX', 0.3, 0.95, '%.2f')
        ui.text(string.format('Micro pattern %dx%d, grid %d',
            rainDynamicSceneCopyState.microPatternSize or 0,
            rainDynamicSceneCopyState.microPatternSize or 0,
            rainDynamicSceneCopyState.microPatternGrid or 0))
        wfSlider('Micro outline (0 = invisible cut line)',
            'RAIN_DYNAMIC_MICRO_PATTERN_OUTLINE_DARK', 0.0, 1.0, '%.2f')
        wfSlider('Micro opacity',
            'RAIN_DYNAMIC_MICRO_LAYER_OPACITY', 0.0, 1.0, '%.2f')
        wfSlider('Micro lens refraction (x WF field)',
            'RAIN_DYNAMIC_MICRO_WATER_LENS_REFRACTION', 0.0, 2.0, '%.2f')
        wfSlider('Micro lens slope scale',
            'RAIN_DYNAMIC_MICRO_WATER_LENS_SLOPE', 0.0, 2.0, '%.2f')
    ui.separator()
    ui.text('Micro droplets: rain density')

    local microRainPower, microRainPowerChanged = ui.slider(
        'Micro circle density / rain curve',
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RAIN_POWER,
        -1.00, 3.00, '%.2f'
    )
    if microRainPowerChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RAIN_POWER = microRainPower
    end
end

rainDynamicSceneCopyState.rainUIPanels['wipe'] = function()
    ui.separator()
    ui.text('Dynamic UV mask and micro clearing')
    local maskDebugChanged = ui.checkbox(
        'Show UV mask instead of micro circles',
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_DEBUG
    )
    if maskDebugChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_DEBUG =
            not cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_DEBUG
    end
    local maskWipeChanged = ui.checkbox(
        'Clear micro circles along drop paths',
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_WIPE_ENABLED
    )
    if maskWipeChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_WIPE_ENABLED =
            not cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_WIPE_ENABLED
    end
    local wipeStrength, wipeStrengthChanged = ui.slider(
        'Micro clearing strength',
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_WIPE_STRENGTH,
        0.0, 1.50, '%.2f'
    )
    if wipeStrengthChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_WIPE_STRENGTH =
            wipeStrength
    end
    do
        -- Path width = drop diameter * scale + offset (debug tuning).
        local function pathSlider(label, key, minV, maxV, fmt)
            local value, changed = ui.slider(label,
                cfg.RUNTIME[key], minV, maxV, fmt)
            if changed then cfg.RUNTIME[key] = value end
        end
        pathSlider('Wipe width (x drop diameter)',
            'RAIN_DYNAMIC_TRAIL_MASK_WIPE_WIDTH_SCALE', 0.0, 3.0, '%.2f')
        pathSlider('Wipe width offset (mm)',
            'RAIN_DYNAMIC_TRAIL_MASK_WIPE_WIDTH_OFFSET_MM', -1.0, 4.0, '%.2f')
        pathSlider('Liquid ridge width (x drop diameter)',
            'RAIN_DYNAMIC_TRAIL_MASK_RIDGE_WIDTH_SCALE', 0.0, 2.0, '%.2f')
        pathSlider('Liquid ridge offset (mm)',
            'RAIN_DYNAMIC_TRAIL_MASK_RIDGE_WIDTH_OFFSET_MM', -1.0, 3.0, '%.2f')
        pathSlider('Path min width (mask texels)',
            'RAIN_DYNAMIC_TRAIL_MASK_MIN_WIDTH_TEXELS', 0.25, 4.0, '%.2f')
        local maskSize, maskSizeChanged = ui.slider(
            'Path mask resolution (texels)',
            cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SIZE, 256, 2048, '%.0f')
        if maskSizeChanged then
            -- Powers of two only; the canvas is recreated on change.
            cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SIZE =
                2 ^ math.floor(math.log(math.max(maskSize, 256), 2) + 0.5)
        end
        local mmPerTexel = 1.0 / math.max(
            cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM
            * cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SIZE, 1e-6)
        ui.text(string.format('Path mask %d (%.2f mm/texel), mean wipe width %.2f texels',
            cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SIZE, mmPerTexel,
            rainDynamicSceneCopyState.trailMaskMeanWidth or 0.0))
    end
    local wipeSeconds, wipeSecondsChanged = ui.slider(
        'Wipe recovery time (seconds)',
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SECONDS,
        0.30, 5.00, '%.2f'
    )
    if wipeSecondsChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SECONDS =
            wipeSeconds
    end

    local filmChanged = ui.checkbox(
        'Thin water film in cleared paths',
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_ENABLED
    )
    if filmChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_ENABLED =
            not cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_ENABLED
    end
    local filmOpacity, filmOpacityChanged = ui.slider(
        'Thin film opacity',
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_OPACITY,
        0.0, 0.50, '%.2f'
    )
    if filmOpacityChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_OPACITY = filmOpacity
    end
    local filmPixels, filmPixelsChanged = ui.slider(
        'Thin film refraction (pixels)',
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_PIXELS,
        0.0, 10.0, '%.1f'
    )
    if filmPixelsChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_PIXELS = filmPixels
    end
    local filmSeconds, filmSecondsChanged = ui.slider(
        'Thin film lifetime (seconds)',
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_SECONDS or 1.0,
        0.10, 5.00, '%.2f'
    )
    if filmSecondsChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_SECONDS = filmSeconds
    end

    local ridgeChanged = ui.checkbox(
        'Narrow liquid ridge in wiped paths',
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_ENABLED
    )
    if ridgeChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_ENABLED =
            not cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_ENABLED
    end
    local ridgeOpacity, ridgeOpacityChanged = ui.slider(
        'Liquid ridge opacity',
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_OPACITY,
        0.0, 0.60, '%.2f'
    )
    if ridgeOpacityChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_OPACITY = ridgeOpacity
    end
    do
        local changed = ui.checkbox('Wiped paths weather sky tone',
            cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SKY_CORRECTION)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SKY_CORRECTION =
                not cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_SKY_CORRECTION
        end
    end
    local ridgePixels, ridgePixelsChanged = ui.slider(
        'Liquid ridge refraction (pixels)',
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_PIXELS,
        0.0, 16.0, '%.1f'
    )
    if ridgePixelsChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_PIXELS = ridgePixels
    end
    local ridgeSeconds, ridgeSecondsChanged = ui.slider(
        'Liquid ridge lifetime (seconds)',
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_SECONDS,
        0.15, 2.00, '%.2f'
    )
    if ridgeSecondsChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_SECONDS = ridgeSeconds
    end
end

rainDynamicSceneCopyState.rainUIPanels['haze'] = function()
    local hzSlider = rainDynamicSceneCopyState.rainUISlider
    ui.separator()
    ui.text('Haze / condensation film')
    do
        local function hzSlider(label, key, minV, maxV, fmt)
            local value, changed = ui.slider(label,
                cfg.RUNTIME[key], minV, maxV, fmt)
            if changed then cfg.RUNTIME[key] = value end
        end
        if ui.checkbox('Haze enabled',
            cfg.RUNTIME.RAIN_DYNAMIC_HAZE_ENABLED) then
            cfg.RUNTIME.RAIN_DYNAMIC_HAZE_ENABLED =
                not cfg.RUNTIME.RAIN_DYNAMIC_HAZE_ENABLED
        end
        if ui.checkbox('Haze debug (blue = amount)',
            cfg.RUNTIME.RAIN_DYNAMIC_HAZE_DEBUG) then
            cfg.RUNTIME.RAIN_DYNAMIC_HAZE_DEBUG =
                not cfg.RUNTIME.RAIN_DYNAMIC_HAZE_DEBUG
        end
        hzSlider('Haze strength', 'RAIN_DYNAMIC_HAZE_STRENGTH',
            0.0, 1.0, '%.2f')
        hzSlider('Haze mottle', 'RAIN_DYNAMIC_HAZE_MOTTLE', 0.0, 1.0, '%.2f')
        hzSlider('Haze rain power', 'RAIN_DYNAMIC_HAZE_RAIN_POWER',
            0.2, 3.0, '%.2f')
        hzSlider('Haze reveal softness', 'RAIN_DYNAMIC_HAZE_REVEAL_SOFT',
            0.01, 0.4, '%.2f')
        hzSlider('Haze blur mip', 'RAIN_DYNAMIC_HAZE_MIP', 0.0, 8.0, '%.1f')
        hzSlider('Haze veil', 'RAIN_DYNAMIC_HAZE_VEIL', 0.0, 0.6, '%.2f')
        hzSlider('Haze speckle (px)', 'RAIN_DYNAMIC_HAZE_SPECKLE_PIXELS',
            0.0, 8.0, '%.1f')
        hzSlider('Haze cleared by water tracks',
            'RAIN_DYNAMIC_HAZE_TRAIL_CLEAR', 0.0, 1.0, '%.2f')
        hzSlider('Haze mist cells', 'RAIN_DYNAMIC_HAZE_MIST_CELLS',
            2.0, 40.0, '%.1f')
        hzSlider('Haze reveal cells',
            'RAIN_DYNAMIC_HAZE_ORDER_CELLS', 1.0, 30.0, '%.1f')
        hzSlider('Haze speckle cells',
            'RAIN_DYNAMIC_HAZE_SPECKLE_CELLS', 100.0, 1500.0, '%.0f')
    end
end

rainDynamicSceneCopyState.rainUIPanels['smear'] = function()
    local tfSlider = rainDynamicSceneCopyState.rainUISlider
    local tfCheck = rainDynamicSceneCopyState.rainUICheck
    local help = rainDynamicSceneCopyState.uiHelp
        ui.text('Smear mask v3 (RAINFX_SMEAR_MASK.md)')
        tfCheck('Smear mask enabled', 'RAIN_DYNAMIC_SMEAR_ENABLED')
        do
            local value, changed = ui.slider('Smear debug (1 region/G, 2 raw R, 3 raw G)',
                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_DEBUG, 0, 4, '%.0f')
            if changed then
                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_DEBUG = math.floor(value + 0.5)
            end
        end
        local sm = rainDynamicSceneCopyState
        ui.text(string.format('Texture: %s', sm.smearTexturePath
            and (cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_USE_TEXTURE and 'loaded' or 'off')
            or 'not found (procedural)'))
        ui.text(string.format('rain %.2f  air %.0f km/h  amp %.2f  density %.2f',
            sm.smearRain or 0.0, sm.smearAirKmh or 0.0, sm.smearAmp or 0.0,
            sm.smearDensity or 0.0))
        ui.text(string.format('trigger %s  facing %.2f  target %.2f  level %.2f',
            sm.smearTriggered and 'ON' or 'off', sm.smearFacing or 0.0,
            sm.smearTarget or 0.0, sm.smearLevel or 0.0))
        tfCheck('Use mask texture', 'RAIN_DYNAMIC_SMEAR_USE_TEXTURE')
        tfCheck('Smear: soft nose exclusion', 'RAIN_DYNAMIC_SMEAR_NOSE_EXCLUDE')
        tfSlider('Nose centre U', 'RAIN_DYNAMIC_SMEAR_NOSE_U', 0.0, 1.0, '%.3f')
        tfSlider('Nose tip V', 'RAIN_DYNAMIC_SMEAR_NOSE_TIP_V', 0.0, 1.0, '%.3f')
        tfSlider('Nose half width', 'RAIN_DYNAMIC_SMEAR_NOSE_HALF_WIDTH', 0.01, 0.4, '%.3f')
        tfSlider('Nose height', 'RAIN_DYNAMIC_SMEAR_NOSE_HEIGHT', 0.01, 0.6, '%.3f')
        tfSlider('Nose edge softness', 'RAIN_DYNAMIC_SMEAR_NOSE_SOFT', 0.001, 0.15, '%.3f')
        tfCheck('Trigger override', 'RAIN_DYNAMIC_SMEAR_TRIGGER_OVERRIDE')
        tfCheck('Reveal override on', 'RAIN_DYNAMIC_SMEAR_REVEAL_OVERRIDE_ON')
        tfSlider('Reveal override value', 'RAIN_DYNAMIC_SMEAR_REVEAL_OVERRIDE', 0.0, 1.0, '%.2f')
        ui.text(string.format('car %.0f km/h  wind (%.1f, %.1f) km/h  facing(no wind) %.2f',
            sm.smearCarKmh or 0.0, sm.smearWindX or 0.0, sm.smearWindY or 0.0,
            sm.smearFacingNoWind or 0.0))
        do
            local value, changed = ui.slider('Wind axes (0 off, 1 x,z, 2 x,-z, 3 -x,-z)',
                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_WIND_MODE, 0, 3, '%.0f')
            if changed then
                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_WIND_MODE = math.floor(value + 0.5)
            end
        end
        tfSlider('Airspeed for amp 1 (km/h)', 'RAIN_DYNAMIC_SMEAR_REF_KMH', 10.0, 400.0, '%.0f')
        tfSlider('Trigger density', 'RAIN_DYNAMIC_SMEAR_TRIGGER', 0.0, 3.0, '%.2f')
        tfSlider('Full-reveal density', 'RAIN_DYNAMIC_SMEAR_FULL', 0.05, 5.0, '%.2f')
        tfSlider('Facing power', 'RAIN_DYNAMIC_SMEAR_FACING_POWER', 0.1, 8.0, '%.2f')
        tfSlider('Attack (s)', 'RAIN_DYNAMIC_SMEAR_ATTACK_SECONDS', 0.05, 20.0, '%.2f')
        tfSlider('Release (s)', 'RAIN_DYNAMIC_SMEAR_RELEASE_SECONDS', 0.05, 60.0, '%.2f')
        tfSlider('Reveal edge soft (R)', 'RAIN_DYNAMIC_SMEAR_EDGE_SOFT', 0.0, 0.3, '%.3f')
        tfSlider('Micro hide (visible = G)', 'RAIN_DYNAMIC_SMEAR_MICRO_HIDE', 0.0, 1.0, '%.2f')
        tfSlider('Micro turbid x G', 'RAIN_DYNAMIC_SMEAR_MICRO_TURBID', 0.0, 1.0, '%.2f')
        tfSlider('Drop turbid x G', 'RAIN_DYNAMIC_SMEAR_DROP_TURBID', 0.0, 1.0, '%.2f')
        tfSlider('Region: WF trail refraction strength', 'RAIN_DYNAMIC_SMEAR_TRAIL_MIX', 0.0, 1.0, '%.2f')
        tfSlider('WF trail turbidity (region transition only)', 'RAIN_DYNAMIC_SMEAR_TRAIL_TURBID', 0.0, 1.0, '%.2f')
        tfSlider('WF trail blur (region transition only)', 'RAIN_DYNAMIC_SMEAR_TRAIL_BLUR', 0.0, 4.0, '%.2f')
        tfSlider('WF trail opacity clearing (region transition only)', 'RAIN_DYNAMIC_SMEAR_TRAIL_CLEAR', 0.0, 1.0, '%.2f')
        tfSlider('Region: head mix with beneath', 'RAIN_DYNAMIC_SMEAR_HEAD_MIX', 0.0, 1.0, '%.2f')
        tfSlider('Region: paths/film/ridge follow G', 'RAIN_DYNAMIC_SMEAR_PATH_WEAKEN', 0.0, 1.0, '%.2f')
        tfSlider('Region: moving drops follow G', 'RAIN_DYNAMIC_SMEAR_HEAD_HIDE', 0.0, 1.0, '%.2f')
        tfSlider('WF trail visibility by G (region transition only)', 'RAIN_DYNAMIC_SMEAR_TRAIL_HIDE', 0.0, 1.0, '%.2f')
        tfSlider('Mask R tiling (region blobs)', 'RAIN_DYNAMIC_SMEAR_R_TILING', 0.25, 8.0, '%.2f')
        tfSlider('Mask G tiling (pattern density)', 'RAIN_DYNAMIC_SMEAR_G_TILING', 0.25, 12.0, '%.2f')
        tfSlider('Turbid blur (mip)', 'RAIN_DYNAMIC_SMEAR_MIP', 0.0, 9.0, '%.1f')
        tfSlider('G contrast', 'RAIN_DYNAMIC_SMEAR_G_CONTRAST', 0.2, 6.0, '%.2f')
        tfSlider('G pivot', 'RAIN_DYNAMIC_SMEAR_G_PIVOT', 0.0, 1.0, '%.2f')
        tfSlider('G gamma', 'RAIN_DYNAMIC_SMEAR_G_GAMMA', 0.2, 4.0, '%.2f')
        tfSlider('Turbid veil', 'RAIN_DYNAMIC_SMEAR_VEIL', 0.0, 1.0, '%.2f')
        ui.text('Class facets v7 (debug 4 = class / presence / blend)')
        do
            local value, changed = ui.slider('Facet classes',
                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_CLASSES, 1, 8, '%.0f')
            if help.RAIN_DYNAMIC_SMEAR_CLASSES and ui.itemHovered() then
                ui.setTooltip(help.RAIN_DYNAMIC_SMEAR_CLASSES)
            end
            if changed then
                cfg.RUNTIME.RAIN_DYNAMIC_SMEAR_CLASSES = math.floor(value + 0.5)
            end
        end
        tfSlider('Class boundary blur', 'RAIN_DYNAMIC_SMEAR_CLASS_SOFT', 0.0, 1.0, '%.2f')
        tfSlider('Class seed', 'RAIN_DYNAMIC_SMEAR_CLASS_SEED', 0.0, 10.0, '%.2f')
        tfSlider('Facet image offset (px)', 'RAIN_DYNAMIC_SMEAR_FACET_PIXELS', 0.0, 60.0, '%.1f')
        tfSlider('Facet tone range', 'RAIN_DYNAMIC_SMEAR_TONE_RANGE', 0.0, 0.6, '%.2f')
        tfSlider('Facet blur range (mip)', 'RAIN_DYNAMIC_SMEAR_CLASS_MIP_RANGE', 0.0, 4.0, '%.2f')
        tfSlider('Class erase span (reveal)', 'RAIN_DYNAMIC_SMEAR_ERASE_SPAN', 0.01, 1.0, '%.2f')
        tfSlider('Class erase by wiping', 'RAIN_DYNAMIC_SMEAR_CLASS_WIPE', 0.0, 2.0, '%.2f')
        tfSlider('Boundary line strength', 'RAIN_DYNAMIC_SMEAR_LINE_STRENGTH', 0.0, 0.6, '%.2f')
        tfSlider('Boundary line width', 'RAIN_DYNAMIC_SMEAR_LINE_WIDTH', 0.005, 0.5, '%.3f')
        tfSlider('Facet film on bare glass', 'RAIN_DYNAMIC_SMEAR_FACET_ALPHA', 0.0, 1.0, '%.2f')
        ui.text('Procedural test mask (no texture)')
        tfSlider('Blob cells (per UV)', 'RAIN_DYNAMIC_SMEAR_MASK_CELLS', 0.5, 30.0, '%.1f')
        tfSlider('Blob warp', 'RAIN_DYNAMIC_SMEAR_MASK_WARP', 0.0, 2.0, '%.2f')
        tfSlider('G noise cells', 'RAIN_DYNAMIC_SMEAR_FILL_CELLS', 20.0, 2000.0, '%.0f')
        tfSlider('G patch cells', 'RAIN_DYNAMIC_SMEAR_FILL_PATCH_CELLS', 2.0, 300.0, '%.0f')
        ui.separator()
end

rainDynamicSceneCopyState.rainUIPanels['large'] = function()
    local tfSlider = rainDynamicSceneCopyState.rainUISlider
        ui.text('Large drops (low-res inner image, soft edge)')
        tfSlider('Large from radius (px)', 'RAIN_DYNAMIC_WATER_LARGE_START_PX', 0.0, 60.0, '%.1f')
        tfSlider('Large full at radius (px)', 'RAIN_DYNAMIC_WATER_LARGE_FULL_PX', 1.0, 120.0, '%.1f')
        tfSlider('Large extra blur (mip)', 'RAIN_DYNAMIC_WATER_LARGE_BLUR_MIP', 0.0, 4.0, '%.2f')
        tfSlider('Large inner warp (px)', 'RAIN_DYNAMIC_WATER_LARGE_WARP_PIXELS', 0.0, 20.0, '%.1f')
        tfSlider('Large warp cell (x radius)', 'RAIN_DYNAMIC_WATER_LARGE_WARP_CELLS', 0.1, 3.0, '%.2f')
        tfSlider('Large soft edge', 'RAIN_DYNAMIC_WATER_LARGE_EDGE_SOFT', 0.0, 0.3, '%.3f')
end

rainDynamicSceneCopyState.rainUIPanels['water_tone'] = function()
    local tfSlider = rainDynamicSceneCopyState.rainUISlider
    local tfCheck = rainDynamicSceneCopyState.rainUICheck
        tfCheck('Anti-chrome tone limiter', 'RAIN_DYNAMIC_WATER_TONE_ENABLED')
        tfSlider('Tone contrast (1 = off)', 'RAIN_DYNAMIC_WATER_TONE_CONTRAST', 0.0, 1.0, '%.2f')
        tfSlider('Tone ratio min', 'RAIN_DYNAMIC_WATER_TONE_RATIO_MIN', 0.0, 1.0, '%.2f')
        tfSlider('Tone ratio max', 'RAIN_DYNAMIC_WATER_TONE_RATIO_MAX', 1.0, 4.0, '%.2f')
        tfSlider('Tone background mip', 'RAIN_DYNAMIC_WATER_TONE_BG_MIP', 0.0, 9.0, '%.1f')
        tfCheck('Tone limiter on micro water lens', 'RAIN_DYNAMIC_WATER_TONE_MICRO')
        ui.separator()
        tfSlider('Tone window floor (x fog)', 'RAIN_DYNAMIC_WATER_TONE_FLOOR', 0.0, 1.0, '%.2f')
end

rainDynamicSceneCopyState.rainUIPanels['source_tone'] = function()
    local tfSlider = rainDynamicSceneCopyState.rainUISlider
    local tfCheck = rainDynamicSceneCopyState.rainUICheck
    local help = rainDynamicSceneCopyState.uiHelp
        tfCheck('Refraction source: transparent pass (glass)', 'RAIN_DYNAMIC_DROP_SHOT_TRANSPARENT')
        ui.text('Refraction source tone (RAINFX_SHOT_TONE.md)')
        tfCheck('Tone pass (before blur)', 'RAIN_DYNAMIC_SHOT_TONE_ENABLED')
        do
            local value, changed = ui.slider('Tone mode (1 aerial, 2 ratio, 3 frame composite)',
                cfg.RUNTIME.RAIN_DYNAMIC_SHOT_TONE_MODE, 1, 3, '%.0f')
            if help.RAIN_DYNAMIC_SHOT_TONE_MODE and ui.itemHovered() then
                ui.setTooltip(help.RAIN_DYNAMIC_SHOT_TONE_MODE)
            end
            if changed then cfg.RUNTIME.RAIN_DYNAMIC_SHOT_TONE_MODE = math.floor(value + 0.5) end
        end
        tfSlider('Composite: depth agree full frame (rel)', 'RAIN_DYNAMIC_SHOT_TONE_AGREE_LO', 0.0, 0.5, '%.3f')
        tfSlider('Composite: depth agree none (rel)', 'RAIN_DYNAMIC_SHOT_TONE_AGREE_HI', 0.01, 1.0, '%.3f')
        tfCheck('Composite: frame depth reversed', 'RAIN_DYNAMIC_SHOT_TONE_FRAME_DEPTH_REVERSED')
        tfSlider('Composite: reject frame darker than shot x', 'RAIN_DYNAMIC_SHOT_TONE_FRAME_MIN_RATIO', 0.0, 1.0, '%.2f')
        tfCheck('Composite: trust nearer frame (wheel, cockpit; debug blue)', 'RAIN_DYNAMIC_SHOT_TONE_NEAR_TRUST')
        tfCheck('Composite: frame priority (shot only for helmet range)', 'RAIN_DYNAMIC_SHOT_TONE_FRAME_PRIORITY')
        tfSlider('Composite: nearer frame trusted beyond (m)', 'RAIN_DYNAMIC_SHOT_TONE_NEAR_TRUST_MIN', 0.05, 0.6, '%.3f')
        tfCheck('Composite debug (green frame / red shot / blue near frame)', 'RAIN_DYNAMIC_SHOT_TONE_COMPOSE_DEBUG')
        tfSlider('Match: ratio mip (shot)', 'RAIN_DYNAMIC_SHOT_TONE_MATCH_MIP', 2, 8, '%.0f')
        tfSlider('Match: strength', 'RAIN_DYNAMIC_SHOT_TONE_MATCH_STRENGTH', 0.0, 1.0, '%.2f')
        tfSlider('Match: chroma (0 = luminance only)', 'RAIN_DYNAMIC_SHOT_TONE_MATCH_CHROMA', 0.0, 1.0, '%.2f')
        tfSlider('Match: ratio min', 'RAIN_DYNAMIC_SHOT_TONE_RATIO_MIN', 0.05, 1.0, '%.2f')
        tfSlider('Match: ratio max', 'RAIN_DYNAMIC_SHOT_TONE_RATIO_MAX', 1.0, 10.0, '%.2f')
        tfSlider('Veil / glint fog chroma', 'RAIN_DYNAMIC_FOG_TONE_SATURATION', 0.0, 1.0, '%.2f')
        tfSlider('Aerial fog density (1/m)', 'RAIN_DYNAMIC_SHOT_TONE_AERIAL_DENSITY', 0.0, 0.03, '%.4f')
        tfSlider('Aerial fog max (geometry)', 'RAIN_DYNAMIC_SHOT_TONE_AERIAL_MAX', 0.0, 1.0, '%.2f')
        tfSlider('Geometry saturation', 'RAIN_DYNAMIC_SHOT_TONE_SATURATION', 0.0, 1.5, '%.2f')
        tfSlider('Sky cloud contrast', 'RAIN_DYNAMIC_SHOT_TONE_CLOUD_CONTRAST', 0.0, 1.0, '%.2f')
        tfCheck('Preview toned source', 'RAIN_DYNAMIC_SHOT_TONE_PREVIEW')
        ui.separator()
        if cfg.RUNTIME.RAIN_DYNAMIC_SHOT_TONE_PREVIEW then
            local st = rainDynamicSceneCopyState
            ui.text(st.toneReady and 'toned (left) / raw shot (right)'
                or 'tone pass not ready')
            if st.toneReady and st.toneCanvas and st.geometryShot then
                local w = 240
                local h = w * (st.toneHeight or 9) / math.max(st.toneWidth or 16, 1)
                ui.image(st.toneCanvas, vec2(w, h))
                ui.sameLine()
                ui.image(st.geometryShot, vec2(w, h))
            end
        end
        tfSlider('Refraction source near clip (m)', 'RAIN_DYNAMIC_DROP_SHOT_NEAR', 0.01, 0.5, '%.2f')
end

rainDynamicSceneCopyState.rainUIPanels['depth'] = function()
    local tfSlider = rainDynamicSceneCopyState.rainUISlider
    local tfCheck = rainDynamicSceneCopyState.rainUICheck
        tfCheck('Drops ignore scene depth (diagnostic only)', 'RAIN_DYNAMIC_DROP_DEPTH_OFF')
        tfCheck('Drops occlude later car glass (depth pass)', 'RAIN_DYNAMIC_DROP_DEPTH_OCCLUDE')
        ui.text('DLSS shimmer tests (RAINFX_VISOR_GLASS.md §6)')
        tfCheck('T1: clear visor motion every frame', 'RAIN_VISOR_MOTION_TEST_CLEAR')
        tfCheck('T2: re-apply visor transform at render', 'RAIN_VISOR_MOTION_TEST_LATE')
        do
            local v = cfg.RUNTIME.RAIN_VISOR_REDRAW_TEST_MESH or ''
            if ui.checkbox('T3: redraw GLASS_COATING_REFL via render.mesh', v == 'GLASS_COATING_REFL') then
                cfg.RUNTIME.RAIN_VISOR_REDRAW_TEST_MESH = v == 'GLASS_COATING_REFL' and '' or 'GLASS_COATING_REFL'
            end
            if ui.itemHovered() then
                ui.setTooltip('Hides GLASS_COATING_REFL in the normal pass and draws it with a flat lit test shader in our pass. If it stops shimmering, the KN5 render path is the cause.')
            end
        end
        do
            local value, changed = ui.slider('Depth pass mode (1 cheap, 2 exact)',
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_DEPTH_OCCLUDE_MODE, 1, 2, '%.0f')
            if changed then
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_DEPTH_OCCLUDE_MODE = math.floor(value + 0.5)
            end
        end
        tfSlider('Depth pass alpha min (exact)', 'RAIN_DYNAMIC_DROP_DEPTH_ALPHA_MIN', 0.02, 0.95, '%.2f')
        tfSlider('Haze/film also writes depth from alpha (0 off)', 'RAIN_DYNAMIC_DROP_HAZE_DEPTH_MIN', 0.0, 0.95, '%.2f')
end

rainDynamicSceneCopyState.rainUIPanels['visor_stack'] = function()
    local tfCheck = rainDynamicSceneCopyState.rainUICheck
        ui.text('Visor scene stack (RAINFX_VISOR_LAYER.md §17)')
        tfCheck('Visor stack drawn in the scene (custom shaders)', 'RAIN_VISOR_SCENE_STACK')
        if cfg.RUNTIME.RAIN_VISOR_SCENE_STACK then
            local vl = rainDynamicSceneCopyState.visorLayer
            ui.text('stack: ' .. tostring(vl.status) .. (vl.err and ('  err ' .. vl.err) or ''))
            ui.text('Per-mesh parameters: KN5 tab -> "Click to Edit" on a *_OVERLAY mesh.')
        end
        ui.separator()
end

rainDynamicSceneCopyState.rainUIPanels['performance'] = function()
    if ui.checkbox('CPU timing and diagnostic counters (profiling)', cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING) then
        cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING = not cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING
    end
    if not cfg.RUNTIME.RAIN_PERFORMANCE_PROFILING then
        ui.text('CPU profiling OFF: timing values are inactive. Enable for measurements.')
    end
        if ui.checkbox('Freeze GPU drop state (performance probe)',
            cfg.RUNTIME.RAIN_GPU_STATE_FREEZE_DEBUG) then
            cfg.RUNTIME.RAIN_GPU_STATE_FREEZE_DEBUG =
                not cfg.RUNTIME.RAIN_GPU_STATE_FREEZE_DEBUG
            rainDynamicSceneCopyState.stateFreezeUntil =
                cfg.RUNTIME.RAIN_GPU_STATE_FREEZE_DEBUG
                    and (os.preciseClock() + 30.0) or nil
        end
        if cfg.RUNTIME.RAIN_GPU_STATE_FREEZE_DEBUG then
            ui.text(string.format('GPU DROP PHYSICS FROZEN (%.0f s left; auto resumes)',
                math.max(0.0, (rainDynamicSceneCopyState.stateFreezeUntil
                    or os.preciseClock()) - os.preciseClock())))
        end
        ui.text(string.format('Trail: %d stamps, %d sheet, max head speed %.3f UV/s',
            rainDynamicSceneCopyState.waterTrailStamps or 0,
            rainDynamicSceneCopyState.waterTrailSheets or 0,
            rainDynamicSceneCopyState.waterTrailMaxSpeed or 0.0))
        local car = ac.getCar(0)
        ui.text(string.format('WF CPU kernels %d (GPU heads excluded) | splash heads %d | %.0f km/h',
            rainDynamicSceneCopyState.waterFieldKernels or 0,
            rainDynamicSceneCopyState.waterFieldTearHeads or 0,
            car and car.speedKmh or 0.0))
        do
            local p = rainDynamicSceneCopyState
            if cfg.RUNTIME.RAIN_GPU_STATE_FREEZE_DEBUG then
                ui.text('PERFORMANCE PROBE: GPU DROP PHYSICS FROZEN')
            end





            ui.text(string.format('Rain birth + WF CPU (avg): total %.2f ms | wipe mask %.2f ms | slots %d',
                (p.profBirthAvg or 0.0), (p.profTrailAvg or 0.0), rainDynamicStateReadbackCount or 0))
            ui.text(string.format('R1.1 CPU parts (avg): build %.2f | head overlay %.2f | water trail %.2f ms',
                (p.profBuildAvg or 0.0), (p.profOverlayAvg or 0.0), (p.profWaterTrailAvg or 0.0)))
            if ui.checkbox('GPU heads (R1.1, tile binning)', cfg.RUNTIME.RAIN_GPU_HEADS) then
                cfg.RUNTIME.RAIN_GPU_HEADS = not cfg.RUNTIME.RAIN_GPU_HEADS
            end
            if cfg.RUNTIME.RAIN_GPU_HEADS then
                if ui.checkbox('GPU splash pieces (R1.4 prototype)',
                    cfg.RUNTIME.RAIN_GPU_SPLASH) then
                    cfg.RUNTIME.RAIN_GPU_SPLASH =
                        not cfg.RUNTIME.RAIN_GPU_SPLASH
                end
                ui.text(string.format('GPU splash atlas: %d heads | submit %.2f ms%s%s',
                    p.gpuSplashCount or 0,
                    p.profGpuSplashSubmitMs or 0,
                    (p.gpuSplashOverflow or 0) > 0
                        and (' | ' .. p.gpuSplashOverflow .. ' over limit') or '',
                    p.gpuSplashErr and (' | ' .. p.gpuSplashErr) or ''))
                if cfg.RUNTIME.RAIN_GPU_SPLASH then


                    ui.text(string.format('R1.4 CPU split (avg): splash state %.2f | override upload %.2f ms',
                        (p.profSplashStateAvg or 0.0), (p.profOverrideWriteAvg or 0.0)))
                end
                ui.text(string.format('GPU heads: %s | submit %.2f ms | splash overrides %d%s',
                    p.gpuHeadsActive and 'active' or 'off',
                    p.profGpuSubmitMs or 0, p.gpuOverrideCount or 0,
                    p.gpuHeadsErr and ('  err ' .. p.gpuHeadsErr) or ''))
                local tv, tc = ui.slider('GPU heads tile (px)', cfg.RUNTIME.RAIN_GPU_HEADS_TILE, 16, 256, '%.0f')
                if tc then cfg.RUNTIME.RAIN_GPU_HEADS_TILE = math.floor(tv + 0.5) end
                if ui.checkbox('GPU heads: skip empty tile words (R1.3)',
                    cfg.RUNTIME.RAIN_GPU_HEADS_SPARSE_WORDS) then
                    cfg.RUNTIME.RAIN_GPU_HEADS_SPARSE_WORDS =
                        not cfg.RUNTIME.RAIN_GPU_HEADS_SPARSE_WORDS
                end
                local dv, dc = ui.slider('GPU heads debug (1 occupancy, 2 GPU only, 3 no heads)', cfg.RUNTIME.RAIN_GPU_HEADS_DEBUG, 0, 3, '%.0f')
                if dc then cfg.RUNTIME.RAIN_GPU_HEADS_DEBUG = math.floor(dv + 0.5) end
                if ui.checkbox('GPU heads: flip canvas Y (if heads appear mirrored)', cfg.RUNTIME.RAIN_GPU_HEADS_FLIP_Y) then
                    cfg.RUNTIME.RAIN_GPU_HEADS_FLIP_Y = not cfg.RUNTIME.RAIN_GPU_HEADS_FLIP_Y
                end
            end




            ui.text(
                string.format('%.2f ~ %.2fms | %.2f ~ %.2fms',
                    cfg.RUNTIME.AVG_TIME_X_MIN,
                    cfg.RUNTIME.AVG_TIME_X_MAX,
                    cfg.RUNTIME.AVG_TIME_Y_MIN,
                    cfg.RUNTIME.AVG_TIME_Y_MAX
                )
            )
        end
    if ui.button('Reset timing range') then
        cfg.RUNTIME.AVG_TIME_X_MIN = 0.0
        cfg.RUNTIME.AVG_TIME_X_MAX = 0.0
        cfg.RUNTIME.AVG_TIME_Y_MIN = 0.0
        cfg.RUNTIME.AVG_TIME_Y_MAX = 0.0
    end
end

rainDynamicSceneCopyState.rainUIPanels['debug'] = function()
    --------------------------------------------------------
    -- RainFX Debug controls
    --------------------------------------------------------
    ui.separator()
    ui.text('RainFX Debug Code')

    local RAIN_DEBUG_VALUES = { 0, 1, 2, 3, 4, 5, 6 }
    local rainDebugIndex = 1
    for i, value in ipairs(RAIN_DEBUG_VALUES) do
        if value == cfg.RUNTIME.RAIN_DEBUG then
            rainDebugIndex = i
            break
        end
    end

    local newRainDebugIndex, rainDebugChanged = ui.combo(
        'RAIN_DEBUG',
        rainDebugIndex,
        RAIN_DEBUG_OPTIONS
    )

    if rainDebugChanged then
        cfg.RUNTIME.RAIN_DEBUG = RAIN_DEBUG_VALUES[newRainDebugIndex]
    end

    local RAIN_GPU_STATE_MODE_VALUES = {
        0, 1, 3, 4, 6, 7, 10
    }

    local stateModeIndex = 1
    for i, modeValue in ipairs(RAIN_GPU_STATE_MODE_VALUES) do
        if modeValue == cfg.RUNTIME.RAIN_GPU_STATE_MODE then
            stateModeIndex = i
            break
        end
    end

    local newStateModeIndex, stateModeChanged = ui.combo(
        'STATE_MODE',
        stateModeIndex,
        RAIN_GPU_STATE_MODE_OPTIONS
    )

    if stateModeChanged then
        cfg.RUNTIME.RAIN_GPU_STATE_MODE =
            RAIN_GPU_STATE_MODE_VALUES[newStateModeIndex]
    end

    ui.text('Canonical physical RainFX state: physical droplet profile + unified external forces.')

    if cfg.RUNTIME.RAIN_GPU_STATE_MODE == 7 then
        ui.separator()
        ui.text('Single persistent droplet position probe')
        ui.text('Signed visor UV coordinates (U 0..1, V -1..0); changing either value re-spawns the single drop with zero velocity.')

        local singleX, singleXChanged = ui.slider(
            'SINGLE_DROP_X',
            cfg.RUNTIME.RAIN_GPU_STATE_SINGLE_DROP_X,
            0.0,
            1.0,
            '%.4f'
        )
        if singleXChanged then
            cfg.RUNTIME.RAIN_GPU_STATE_SINGLE_DROP_X = singleX
            rainStateSingleDropDirty = true
        end

        local singleY, singleYChanged = ui.slider(
            'SINGLE_DROP_Y',
            cfg.RUNTIME.RAIN_GPU_STATE_SINGLE_DROP_Y,
            -1.0,
            0.0,
            '%.4f'
        )
        if singleYChanged then
            cfg.RUNTIME.RAIN_GPU_STATE_SINGLE_DROP_Y = singleY
            rainStateSingleDropDirty = true
        end

        ui.text('Single-drop position probe is available only in STATE_MODE 7.')
    end
end

rainDynamicSceneCopyState.rainUIPanels['stage'] = function()
    local tfSlider = rainDynamicSceneCopyState.rainUISlider
    local tfCheck = rainDynamicSceneCopyState.rainUICheck
        ui.text('Stage probe (RAINFX_STAGE_PROBE.md)')
        tfCheck('Stage probe: capture every render stage (Lua reload)', 'RAIN_DYNAMIC_STAGE_PROBE')
        if cfg.RUNTIME.RAIN_DYNAMIC_STAGE_PROBE then
            local value, changed = ui.slider('Probe source (1 hdr, 2 screen, 3 depth)',
                cfg.RUNTIME.RAIN_DYNAMIC_STAGE_PROBE_SOURCE, 1, 3, '%.0f')
            if changed then cfg.RUNTIME.RAIN_DYNAMIC_STAGE_PROBE_SOURCE = math.floor(value + 0.5) end
            tfSlider('Probe exposure', 'RAIN_DYNAMIC_STAGE_PROBE_EXPOSURE', 0.05, 8.0, '%.2f')
            tfSlider('Probe width (px)', 'RAIN_DYNAMIC_STAGE_PROBE_WIDTH', 128, 640, '%.0f')
            local st = rainDynamicSceneCopyState
            local names = { 'sceneReady (prev frame)' }
            for _, n in ipairs(st.probeStages) do names[#names + 1] = n end
            local drawStage = cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG and 'main.smoke'
                or (cfg.RUNTIME.RAIN_DYNAMIC_DROP_DRAW_AT_TRACK and 'main.track.transparent'
                    or 'main.root.transparent')
            local col = 0
            for _, n in ipairs(names) do
                local p = st.probe[n]
                ui.beginGroup()
                ui.text(string.format('%s%s', n, n == drawStage and '  [drops drawn here]' or ''))
                if p then
                    ui.text(string.format('order %s  frame %s  %s', tostring(p.order),
                        tostring(p.frame), p.ok and 'ok' or ('FAIL ' .. tostring(p.err or 'pending'))))
                    ui.image(p.canvas, vec2(p.w, p.h))
                else
                    ui.text('not called yet')
                end
                ui.endGroup()
                col = col + 1
                if col % 2 == 1 then ui.sameLine() end
            end
        end
        ui.separator()
end

rainDynamicSceneCopyState.rainUIPanels['overlay'] = function()
    local tfSlider = rainDynamicSceneCopyState.rainUISlider
    local tfCheck = rainDynamicSceneCopyState.rainUICheck
    ui.text('Archived rendering experiments. Optional diagnostics; current scene rendering uses Visor stack.')
        ui.text('Post overlay P1 (RAINFX_POST_OVERLAY.md, archived)')
        tfCheck('Visor layer as post overlay (P1, archived; Lua reload)', 'RAIN_VISOR_OVERLAY')
        if cfg.RUNTIME.RAIN_VISOR_OVERLAY then
            local ov = rainDynamicSceneCopyState.overlay
            ui.text('status: ' .. tostring(ov.status) .. (ov.err and ('  err ' .. ov.err) or ''))
            tfSlider('Overlay veil tone mip (frame mean)', 'RAIN_VISOR_OVERLAY_FOG_MIP', 0.0, 9.0, '%.1f')
            tfSlider('Overlay resolution (0 render, 1 output)', 'RAIN_VISOR_OVERLAY_RES_SCALE', 0.0, 1.0, '%.2f')
            ui.separator()
            ui.text('Visor layer V1 (RAINFX_VISOR_LAYER.md)')
            tfCheck('Visor KN5 drawn in the overlay (hidden in scene)', 'RAIN_VISOR_LAYER')
            if cfg.RUNTIME.RAIN_VISOR_LAYER then
                local vl = rainDynamicSceneCopyState.visorLayer
                ui.text('layer: ' .. tostring(vl.status) .. (vl.err and ('  err ' .. vl.err) or ''))
                ui.text('s56: per-mesh parameters moved to the KN5 tab ->')
                ui.text('"Click to Edit" on the *_OVERLAY meshes.')
            end
            ui.text(string.format('overlay %sx%s', tostring(ov.w), tostring(ov.h)))
            tfCheck('Overlay debug: show alpha', 'RAIN_VISOR_OVERLAY_DEBUG_ALPHA')
            tfCheck('HUD lift: AC / Python apps above the overlay (no mouse while lifted)', 'RAIN_VISOR_OVERLAY_HUD_LIFT')
            if cfg.RUNTIME.RAIN_VISOR_OVERLAY_HUD_LIFT then
                tfCheck('HUD lift: premultiplied blend', 'RAIN_VISOR_OVERLAY_HUD_PREMULTIPLIED')
                local hl = rainDynamicSceneCopyState.hudLift
                ui.text('HUD lift draw: ' .. tostring(hl.status) .. '  layer ' .. tostring(hl.layer))
                if hl.windows then
                    for _, wnd in ipairs(hl.windows) do
                        if wnd.visible then
                            local lift = not hl.skip[wnd.name]
                            if ui.checkbox(string.format('lift: %s (%s)', tostring(wnd.title),
                                    tostring(wnd.name)), lift) then
                                hl.skip[wnd.name] = lift
                                hl.nextScan = 0
                            end
                        end
                    end
                end
            end
            if ov.shot then
                local w = 320
                local h = w * (ov.h or 9) / math.max(ov.w or 16, 1)
                ui.text('overlay layer (left) / source = final frame (right)')
                ui.image(ov.shot, vec2(w, h))
                ui.sameLine()
                if ov.src then ui.image(ov.src, vec2(w, h)) end
            end
        end
        ui.separator()
        ui.text('Overlay probe P0 (RAINFX_POST_OVERLAY.md)')
        tfCheck('Overlay probe: render drops offscreen', 'RAIN_VISOR_OVERLAY_PROBE')
        if cfg.RUNTIME.RAIN_VISOR_OVERLAY_PROBE then
            tfCheck('Overlay probe: draw full-screen in HUD', 'RAIN_VISOR_OVERLAY_PROBE_FULLSCREEN')
            tfCheck('Overlay probe: hide in-scene drops', 'RAIN_VISOR_OVERLAY_PROBE_HIDE_SCENE')
            local op = rainDynamicSceneCopyState.overlayProbe
            ui.text('status: ' .. tostring(op.status) .. (op.err and ('  err ' .. op.err) or ''))
            ui.text(string.format('shot %sx%s  HUD size %s  screen copy %s',
                tostring(op.w), tostring(op.h), tostring(op.hudSize),
                op.screenCopyOk == nil and '-' or (op.screenCopyOk and 'ok' or 'FAIL')))
            if op.shot then
                local w = 320
                local h = w * (op.h or 9) / math.max(op.w or 16, 1)
                ui.text('offscreen drops (left) / dynamic::screen at HUD time (right)')
                ui.image(op.shot, vec2(w, h))
                ui.sameLine()
                if op.screenCopy then ui.image(op.screenCopy, vec2(w, h)) end
            end
        end
end

function windowMain(dt)

    local p = getActiveProfile()

    local changed = nil     -- state boolean


    ui.text(
        strDisplayName .. ' v' .. strVersion
    )

    ui.separator()

    --------------------------------------------------------
    -- Main UI Tabs
    --------------------------------------------------------
    ui.tabBar('RealVisorMainTabs', function()

        ui.tabItem('Transform', 0, function()

    --------------------------------------------------------
    -- Profile Selector
    --------------------------------------------------------

    local profileChanged

    local selectedProfile = activeProfile

    selectedProfile, profileChanged =
        ui.combo(
            'Profile',
            selectedProfile,
            {
                'Profile 1',
                'Profile 2'
            }
        )

    if profileChanged then
        setActiveProfile(selectedProfile)
    end


    --------------------------------------------------------
    -- Enable
    --------------------------------------------------------

    local changedEnableMode, _ =
    ui.checkbox(

        'Enable Real Visor',

        cfg.GENERAL.ENABLE == 1
    )

    if changedEnableMode then

        setProfileValue(
            'ENABLE_MODE',
            1 - cfg.GENERAL.ENABLE
        )

        ac.log(
            appNameDebug
            .. ' Visor '
            .. (cfg.GENERAL.ENABLE == 1 and 'Enabled' or 'Disabled')
        )

    end


    ui.sameLine(0, 20)

    local changedHideHelmet, _= ui.checkbox(

            'Hide driver head&helmet (to avoid light render conflicts)',

            p.HIDE_DRIVER_HELMET == 1
        )


    if changedHideHelmet then

        setProfileValue(
            'HIDE_DRIVER_HELMET',
            1- p.HIDE_DRIVER_HELMET
        )


    end


    --------------------------------------------------------
    -- Scale
    --------------------------------------------------------

    ui.separator()

    ui.text('Model Scale')


    local newScale, changedScale =
    ui.slider(
        'Scale',
        p.SCALE,
        0.10,
        3.00,
        '%.4f'
    )


    if changedScale then
        -- p.SCALE = newScale
        setProfileValue('SCALE', newScale)
    end

    profileContextMenu('Scale', 'SCALE')


    --------------------------------------------------------
    -- Axis
    --------------------------------------------------------

    ui.separator()

    ui.text('Axis Correction')


    local newPitch, changedPitch =
    ui.slider(
        'Pitch',
        p.PITCH,
        -89.0,
        89.0,
        '%.2f°'
    )

    if changedPitch then
        -- p.PITCH = newPitch
        setProfileValue('PITCH', newPitch)
    end

    profileContextMenu('Pitch', 'PITCH')



    local newYaw, changedYaw =
        ui.slider(
            'Yaw',
            p.YAW,
            -179.0,
            179.0,
            '%.2f°'
        )

    if changedYaw then
        -- p.YAW = newYaw
        setProfileValue('YAW', newYaw)
    end

    profileContextMenu('Yaw', 'YAW')



    local newRoll, changedRoll =
        ui.slider(
            'Roll',
            p.ROLL,
            -179.0,
            179.0,
            '%.2f°'
        )

    if changedRoll then
        -- p.ROLL = newRoll
        setProfileValue('ROLL', newRoll)
    end

    profileContextMenu('Roll', 'ROLL')


    --------------------------------------------------------
    -- Offset
    --------------------------------------------------------

    ui.separator()

    ui.text('Camera Local Offset')


    local newX, changedX =
        ui.slider(
            'Offset X',
            p.OFFSET_X,
            -1.20,
            1.20,
            '%.4f'
        )

    if changedX then
        -- p.OFFSET_X = newX
        setProfileValue('OFFSET_X', newX)
    end

    profileContextMenu('Offset_X', 'OFFSET_X')


    local newY, changedY =
    ui.slider(
        'Offset Y',
        p.OFFSET_Y,
            -1.20,
            1.20,
            '%.4f'
        )

        if changedY then
            -- p.OFFSET_Y = newY
            setProfileValue('OFFSET_Y', newY)
        end

        profileContextMenu('Offset Y', 'OFFSET_Y')


        local newZ, changedZ =
        ui.slider(
            'Offset Z',
            p.OFFSET_Z,
            -1.20,
            1.20,
            '%.4f'
        )

        if changedZ then
            -- p.OFFSET_Z = newZ
            setProfileValue('OFFSET_Z', newZ)
        end

        profileContextMenu('Offset Z', 'OFFSET_Z')


    --------------------------------------------------------
    -- Near Clip Distance
    --------------------------------------------------------
    ui.separator()

    ui.text(
        'Near Clip Distance'
    )

    local newNearclip, changedNearclip =

    ui.slider(
        'Near Clip',
        p.NEARCLIP,
        0.001,
        0.100,
        '%.4f'
    )

    if changedNearclip then

        -- p.NEARCLIP= newNearclip

        setProfileValue(
            'NEARCLIP',
            newNearclip
        )

    end

    profileContextMenu('Near Clip', 'NEARCLIP')


    --------------------------------------------------------
    -- G-Force Motion
    --------------------------------------------------------

    ui.separator()

    ui.text(
        'G-Force Motion'
    )


        --------------------------------------------------------
        -- G-Force Motion: Enable / Disable
        --------------------------------------------------------
        local changedEnableMotion, newEnableMotion =
            ui.checkbox(

                'Enable Motion',

                p.ENABLE_MOTION == 1
            )

        if changedEnableMotion then

            setProfileValue(
                'ENABLE_MOTION',
                1 - p.ENABLE_MOTION
            )

        end

        profileContextMenu('Enable Motion', 'ENABLE_MOTION')


        --------------------------------------------------------
        -- G-Force Motion: X
        --------------------------------------------------------

        local newMotionGainX, changed =
            ui.slider(

                'Motion X',

                p.MOTION_GAIN_X,

                0.0,

                0.01,

                '%.5f'
            )


        if changed then

            -- p.MOTION_GAIN_X = newMotionGainX


            setProfileValue(
                'MOTION_GAIN_X',
                newMotionGainX
            )

        end

        profileContextMenu('Motion X', 'MOTION_GAIN_X')


        --------------------------------------------------------
        -- G-Force Motion: Y
        --------------------------------------------------------

        local newMotionGainY, changed =
        ui.slider(

            'Motion Y',

            p.MOTION_GAIN_Y,

            0.0,

            0.01,

            '%.5f'
        )


        if changed then

            -- p.MOTION_GAIN_Y = newMotionGainY


            setProfileValue(
                'MOTION_GAIN_Y',
                newMotionGainY
            )

        end

        profileContextMenu('Motion Y', 'MOTION_GAIN_Y')


        --------------------------------------------------------
        -- G-Force Motion: Z
        --------------------------------------------------------

        local newMotionGainZ, changed =
        ui.slider(

            'Motion Z',

            p.MOTION_GAIN_Z,

            0.0,

            0.01,

            '%.5f'
        )


        if changed then

            -- p.MOTION_GAIN_Z = newMotionGainZ

            setProfileValue(
                'MOTION_GAIN_Z',
                newMotionGainZ
            )

        end

        profileContextMenu('Motion Z', 'MOTION_GAIN_Z')


        --------------------------------------------------------
        -- G-Force Motion: Sharpness
        --------------------------------------------------------

        local newMotionSharpness, changed =
            ui.slider(

                'Motion Strength',

                p.MOTION_SHARPNESS,

                0.0,

                5.0,

                '%.2f'
            )


        if changed then

            -- p.MOTION_SHARPNESS = newMotionSharpness


            setProfileValue(
                'MOTION_SHARPNESS',
                newMotionSharpness
            )

        end

        profileContextMenu('Motion Strength', 'MOTION_SHARPNESS')


        --------------------------------------------------------
        -- G-Force Motion: Smoothing
        --------------------------------------------------------

        local newMotionSmoothing, changed =
        ui.slider(

            'Motion Response',

            p.MOTION_SMOOTHING,

            0.1,

            50.0,

            '%.2f'
        )


        if changed then

            -- p.MOTION_SMOOTHING = newMotionSmoothing


            setProfileValue(
                'MOTION_SMOOTHING',
                newMotionSmoothing
            )


        end

    profileContextMenu('Motion Response', 'MOTION_SMOOTHING')


        end)

        ui.tabItem('KN5', 0, function()

    --------------------------------------------------------
    -- Glass debug: MESH & Material Configuration
    --------------------------------------------------------

    ui.separator()

    ui.text('Model Config & Debug')

    ui.text('\tVisible')
    ui.text('\t')


    for i, foundEditor in ipairs(MATERIAL_EDITORS) do


        --------------------------------------------------------
        -- Util: Show / Hide Meshes
        --------------------------------------------------------
        ui.sameLine(0, 5)

        changed, _ = ui.checkbox(
                string.format(i, '[%d]'),
                foundEditor.visible
            )


        if changed then

            foundEditor.visible =
                not foundEditor.visible

            if foundEditor.targetMesh
                and #foundEditor.targetMesh > 0 then

                foundEditor.targetMesh:setVisible(foundEditor.visible, false)
            end

            saveProfiles()

            ac.log(
                appNameDebug .. ' ' .. foundEditor.meshName .. (foundEditor.visible and ': Show' or ': Hide')
            )
        end


        --------------------------------------------------------
        -- Debug: Found Meshes
        --------------------------------------------------------
        ui.sameLine(0, 5)

        ui.text(
            '\t' .. foundEditor.meshName .. ': '
            .. ((foundEditor.targetMesh and #foundEditor.targetMesh > 0 )
            and 'FOUND' or 'NOTFOUND' )
        )


        --------------------------------------------------------
        -- Debug: Found Material
        --------------------------------------------------------
        ui.sameLine(320, 0)

        ui.text(
            foundEditor.materialName .. ': '
            .. ((foundEditor.materialQueryRef and #foundEditor.materialQueryRef > 0)
            and 'FOUND' or 'NOTFOUND')
        )


        --------------------------------------------------------
        -- Button: Open Material Parameter editor
        --------------------------------------------------------

        local isOverlayMesh = rainDynamicSceneCopyState.visorLayerItemFor
            and rainDynamicSceneCopyState.visorLayerItemFor(foundEditor.meshName)
        if foundEditor.materialQueryRef or isOverlayMesh then
            ui.text('')
            ui.sameLine(320, 15)

            if ui.button(
                '>> Click to Edit [' .. foundEditor.id .. '] <<'
                ) then

                activeMaterialEditor =
                    foundEditor

                materialEditWindowOpen =
                    true

                if not activeMaterialEditor.loaded
                    and not isOverlayMesh then

                    loadMaterialParams(
                        activeMaterialEditor
                    )
                end

                ui.openPopup(
                    strMaterialEditorPopup
                )
            end
        end
        ui.text('\t')
    end

    -- s56: the popup must be drawn in the same ID scope as ui.openPopup()
    -- (inside this tab), not at window level.
    drawMaterialEditorWindow(activeMaterialEditor)


    --------------------------------------------------------
    -- Runtime info
    --------------------------------------------------------

    ui.text(

        string.format(

            '\tScale: %.4f',

            activeScale
        )
    )


    --------------------------------------------------------
    -- Debug Log
    --------------------------------------------------------

    ui.text('')
    ui.sameLine(0, 15)

    changed, _ = ui.checkbox(

        '[Log] Show position delta',

        cfg.RUNTIME.DEBUG_DELTAPOS
    )

    if changed then
        cfg.RUNTIME.DEBUG_DELTAPOS = not cfg.RUNTIME.DEBUG_DELTAPOS
    end
    if textDebugDeltaPos then
        ui.text(
            '\t\t*Delta: ' .. textDebugDeltaPos
            .. '\n\t\t*World: ' .. textDebugPos
        )
    end

    ui.text('')
    ui.sameLine(0, 15)

    changed, _ = ui.checkbox(

        '[Log] world rotation',

        cfg.RUNTIME.DEBUG_ROTATION
    )

    if changed then
        cfg.RUNTIME.DEBUG_ROTATION = not cfg.RUNTIME.DEBUG_ROTATION
    end

    if textDebugCamRotation then
        ui.text('\t\t*' .. textDebugCamRotation)
    end


        end)

        ui.tabItem('RainFX', 0, function()

    rainDynamicSceneCopyState.rainUIUpdateProfile()
    ui.text('RainFX tuning')
    ui.text('Choose a group to open its settings. Values remain live when the popup is closed.')
    ui.separator()
    ui.text('Simulation and births')
    ui.columns(2, false, '##RainFXMenu_Simulation_and_births')
    rainDynamicSceneCopyState.rainUIGroup('Population and GPU birth sites', 'population')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Birth sizes and weather ranges', 'birth_size')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Rain exposure and lifetime', 'lifecycle')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Forces and water physics', 'forces')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Coalescence and steering', 'merge')
    ui.nextColumn()
    ui.columns(1)
    ui.separator()
    ui.text('Water layers')
    ui.columns(2, false, '##RainFXMenu_Water_layers')
    rainDynamicSceneCopyState.rainUIGroup('Moving drop shape and growth', 'birth_shape')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('WF heads and optics', 'heads')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Impact splash and tearing', 'splash')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Trail flow and optics', 'trail')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Fast-flow sheet', 'sheet')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Local impact film', 'impact')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Micro pattern and landing', 'micro')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Wipe paths, film and ridge', 'wipe')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Haze and condensation', 'haze')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Smear mask and facets', 'smear')
    ui.nextColumn()
    ui.columns(1)
    ui.separator()
    ui.text('Scene and colour')
    ui.columns(2, false, '##RainFXMenu_Scene_and_colour')
    rainDynamicSceneCopyState.rainUIGroup('Large-drop optics', 'large')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Water tone', 'water_tone')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Refraction source and tone', 'source_tone')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Depth and shimmer', 'depth')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Visor scene stack', 'visor_stack')
    ui.nextColumn()
    ui.columns(1)
    ui.separator()
    ui.text('Diagnostics')
    ui.columns(2, false, '##RainFXMenu_Diagnostics')
    rainDynamicSceneCopyState.rainUIGroup('GPU rendering and performance', 'performance')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Debug modes and single-drop probe', 'debug')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Render stage probe', 'stage')
    ui.nextColumn()
    rainDynamicSceneCopyState.rainUIGroup('Archived overlay experiments', 'overlay')
    ui.nextColumn()
    ui.columns(1)

        end)

    end)

    -- (s56: the material editor popup is drawn inside the KN5 tab.)


end
