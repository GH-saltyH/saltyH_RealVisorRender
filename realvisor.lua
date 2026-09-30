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
        'visors/visor_lando_2025Champion_maxquality.kn5',
        

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
        -- false: original signed tangent airflow, true: downward visor
        -- runoff with the original left/right tangent component.
        RAIN_AIRFLOW_DOWNWARD_MODE = true,
        RAIN_AIRFLOW_DOWNWARD_GAIN = 1.25,

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
        RAIN_FLOW_ACCELERATION = 0.0251,

        -- Post-adhesion flow intensity multiplier. Default 1.0 preserves
        -- the current physical calibration; later tuning must still respect
        -- the absolute physical max-speed clamp.
        RAIN_FLOW_SPEED_SCALE = 1.0,

        -- Linear air/viscous drag coefficient.
        RAIN_FLOW_DRAG = 0.91,           -- Default 7.00     *Fine Tuned

        -- Adhesion threshold range. A drop remains attached while the
        -- effective tangential force is below its own threshold.
        RAIN_ADHESION_MIN = 0.308,       -- Default 0.65   *Fine Tuned
        RAIN_ADHESION_MAX = 0.541,       -- Default 2.20   *Fine Tuned

        ------------------------------------------------------------
        -- v0.6.1 RainFX persistent GPU state validation
        ------------------------------------------------------------

        -- Number of persistent droplet state texels.
        -- One texel represents one persistent droplet.
        RAIN_GPU_STATE_COUNT = 3072,

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
        RAIN_GPU_STATE_DENSITY_SCALE = 1.0,
        RAIN_GPU_STATE_CAPACITY_RAMP_POWER = 1.0,
        -- Live birth-size keyframes in mm; a slot samples these at birth.
        RAIN_GPU_SIZE_MIN_DRY = 0.32,                   -- Default 0.35mm
        RAIN_GPU_SIZE_MAX_DRY = 0.38,                   -- Default 1.40mm
        RAIN_GPU_SIZE_MIN_LIGHT = 0.35,                 -- Default 0.35mm
        RAIN_GPU_SIZE_MAX_LIGHT = 0.49,                 -- Default 2.53mm
        RAIN_GPU_SIZE_MIN_RAIN = 0.50,                  -- Default 0.91mm    
        RAIN_GPU_SIZE_MAX_RAIN = 0.82,                  -- Default 4.10mm
        RAIN_GPU_SIZE_MIN_HEAVY = 0.75,                 -- Default 1.15mm
        RAIN_GPU_SIZE_MAX_HEAVY = 1.42,                 -- Default 4.10mm
        RAIN_GPU_SIZE_MIN_RARE = 1.25,                  -- Default 5mm
        RAIN_GPU_SIZE_MAX_RARE = 2.03,                  -- Default 6mm            
        RAIN_GPU_SIZE_BIAS = 2.0,
        RAIN_GPU_SIZE_RARECHANCE_DRY = 0.003,           -- Rare-size drop chance at dry
        RAIN_GPU_SIZE_RARECHANCE_HEAVY = 0.028,         -- Rare-size drop chance at heavy
        -- Add encounters from vehicle speed without changing surface flow.
        RAIN_GPU_STATE_SPEED_EXPOSURE_GAIN = 1.0,           -- Driving rain exposure gain, default: 1.00
        RAIN_GPU_STATE_AGE_MIN_SECONDS = 5.0,               -- Moving drop minimum age (seconds), default: 8.0
        RAIN_GPU_STATE_AGE_MAX_SECONDS = 10.0,              -- Moving drop maximum age (seconds), default: 18.0
        RAIN_GPU_STATE_MOBILE_SPEED_MULTIPLIER = 3.9,       -- Moving drop speed / calibrated cap, 
        RAIN_GPU_STATE_MOBILE_DRAG = 0.62,                  -- Moving drop drag,  Default : 1.59
        RAIN_GPU_STATE_KINETIC_ADHESION_FRACTION = 0.044,   -- Kinetic adhesion / static  default : 0.08
        RAIN_GPU_STATE_MOVING_FORCE_GAIN = 5.64,            -- Flow force gain in motion
        RAIN_GPU_STATE_MOBILE_THRESHOLD_UV = 0.0011,        -- Movement threshold (UV/s)
        RAIN_GPU_STATE_BOUNDARY_MARGIN = 0.005,
        RAIN_GPU_STATE_RESPAWN_GAP_MIN = 0.15,
        RAIN_GPU_STATE_RESPAWN_GAP_MAX = 0.75,

        -- Stage 7C: physical-reference size-dependent surface max speed.
        -- 1 mm diameter occupies exactly 0.0029296875 visor UV in the
        -- calibrated Debug 50 mesh measurement.
        RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM = 0.0029296875,
        RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_1MM = 0.1000,      -- Default 0.016
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

        -- Temporary Stage 4A transport diagnostic:
        -- when true, dynamic-drop shader shows quad UV directly and bypasses
        -- circular clipping. This isolates shader binding/UV interpolation
        -- from the later droplet silhouette.
        RAIN_DYNAMIC_DROP_UV_DEBUG = false,

        -- Stage 4B.1: copy the HDR scene at pin.ScreenPos into each clipped
        -- droplet footprint without offset. A correct result should be nearly
        -- invisible and proves scene-texture/screen-UV alignment before
        -- refraction is introduced.
        RAIN_DYNAMIC_DROP_HDR_COPY_DEBUG = false,

        -- Stage 4B.2: controlled screen-space radial refraction. Keep the HDR
        -- copy debug disabled while testing this branch.
        RAIN_DYNAMIC_DROP_REFRACTION_DEBUG = true,
        RAIN_DYNAMIC_DROP_REFRACTION_PIXELS = 48.0,
        -- Retire the opaque diagnostic and its bright center seam; 48px
        -- above preserves the established left-hand lens displacement.
        RAIN_DYNAMIC_DROP_OPAQUE_REFRACTION_SPLIT_DEBUG = false,
        -- Compare the clean GeometryShot against the final screen on sky.
        RAIN_DYNAMIC_DROP_SKY_SOURCE_DEBUG = false,
        -- Keep the shot in HDR until the same final post-process as the frame.
        RAIN_DYNAMIC_DROP_SHOT_YEBIS_DEBUG = false,
        -- Visualize independent-shot depth in the visible right half:
        -- magenta for far/sky, cyan for geometry. Visible left stays HDR.
        RAIN_DYNAMIC_DROP_SKY_DEPTH_DEBUG = false,
        -- Replace shot sky tone with the current weather fog color.
        RAIN_DYNAMIC_DROP_SKY_FOG_COLOR_DEBUG = true,
        -- Recover restrained cloud brightness using the shot's broad mip.
        RAIN_DYNAMIC_DROP_SKY_CLOUD_DETAIL_DEBUG = true,
        -- Right half tests a monotonic concave lens with a softer rim.
        -- Keep the former inverted source available as a disabled control.
        RAIN_DYNAMIC_DROP_INVERTED_FOOTPRINT_DEBUG = false,
        RAIN_DYNAMIC_DROP_CONCAVE_LENS_DEBUG = true,
        -- Fade the right-hand lens toward the real scene at the edge.
        RAIN_DYNAMIC_DROP_SOFT_COMPOSITE_DEBUG = true,
        -- Compare a low-cost wide-field, high-contrast light response on the
        -- concave half without widening its seam-free base scene mapping.
        RAIN_DYNAMIC_DROP_WIDE_GLINT_DEBUG = false,
        -- Right-hand lens samples roughly one third of the full scene;
        -- compare image content against the unchanged left-hand control.
        RAIN_DYNAMIC_DROP_WIDE_SCENE_DEBUG = true,
        -- Use the projected visor surface tangent for the wide image axis;
        -- retain a small stable per-drop residual angle in radians.
        RAIN_DYNAMIC_DROP_WIDE_SURFACE_ROTATION_DEBUG = true,
        RAIN_DYNAMIC_DROP_WIDE_ROTATION_RADIANS = 0.45,
        -- Right-only orb probe: broad forward image with low-detail mips.
        RAIN_DYNAMIC_DROP_WIDE_ORB_DEBUG = true,
        -- Orb field radius in screen UV: lower values show a closer scene.
        RAIN_DYNAMIC_DROP_ORB_FIELD_RADIUS = 0.48,
        -- Limit GPU drop optics to the scene directly ahead of each drop.
        RAIN_DYNAMIC_DROP_FORWARD_SCENE_ONLY = true,
        RAIN_DYNAMIC_DROP_FORWARD_SCENE_RADIUS = 0.24,
        -- Flip both projected surface axes for a 180-degree lens image test.
        RAIN_DYNAMIC_DROP_ORB_INVERT_IMAGE = false,
        -- Source direction follows the projected drop position on the visor.
        RAIN_DYNAMIC_DROP_ORB_POSITION_BEND = 0.72,
        RAIN_DYNAMIC_DROP_ORB_SIDE_UPSHIFT = 0.72,
        RAIN_DYNAMIC_DROP_ORB_GLOW = 0.12,
        -- Keep the accepted wide orb on both sides while scene tone is
        -- investigated. Re-enable only for explicit optical A/B tests.
        RAIN_DYNAMIC_DROP_SPLIT_COMPARE_DEBUG = false,
        -- Keep the low-detail center; make its visible edge about half as
        -- blurred using the same existing GeometryShot mip chain.
        RAIN_DYNAMIC_DROP_WIDE_ORB_EDGE_MIP = 3.5,
        -- The screen copy did not fix the rain overlay or tone mismatch;
        -- disable its per-frame allocation/copy/mips before testing stages.
        RAIN_DYNAMIC_DROP_SCREEN_SOURCE_COMPARE_DEBUG = false,
        -- Full-size YEBIS verifies refraction after the half-size fog test.
        RAIN_DYNAMIC_DROP_SHOT_YEBIS_SCALE = 1.0,
        -- Retain force-driven wave code for later optical tuning.
        RAIN_DYNAMIC_DROP_WAVE_ENABLED = false,
        -- Compare an uneven right-half outline with the circular left half.
        RAIN_DYNAMIC_DROP_SHAPE_DEBUG = true,
        RAIN_DYNAMIC_DROP_SHAPE_STRENGTH = 1.0,
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
        RAIN_DYNAMIC_MICRO_NORMAL_TEXTURE_SIZE = 4096,
        RAIN_DYNAMIC_MICRO_NORMAL_BUMP = 0.90,
        RAIN_DYNAMIC_MICRO_NORMAL_MIP = 1.5,
        RAIN_DYNAMIC_MICRO_CONCAVE_OPTICS = 1.60,
        RAIN_DYNAMIC_MICRO_LAYER_COUNT = 4096,
        RAIN_DYNAMIC_MICRO_LAYER_MIN_DIAMETER_MM = 0.035,
        RAIN_DYNAMIC_MICRO_LAYER_MAX_DIAMETER_MM = 0.25,
        RAIN_DYNAMIC_MICRO_LAYER_DEBUG = false,
        RAIN_DYNAMIC_MICRO_LAYER_REFRACTION_PIXELS = 15.0,
        RAIN_DYNAMIC_MICRO_PATTERN_IMAGE_SCALE = 21.4,      
        RAIN_DYNAMIC_MICRO_PATTERN_IMAGE_ROTATION_DEGREES = 180.0,
        RAIN_DYNAMIC_MICRO_PATTERN_ANGLE_LIGHT = 1.23,
        RAIN_DYNAMIC_MICRO_PATTERN_ANGLE_SHADOW = 1.16,
        RAIN_DYNAMIC_MICRO_PATTERN_NORMAL_SCENE_GAIN = 0.02,
        RAIN_DYNAMIC_MICRO_PATTERN_RAIN_POWER = 0.92,
        RAIN_DYNAMIC_MICRO_PATTERN_RIM_STRENGTH = 0.12,
        RAIN_DYNAMIC_MICRO_PATTERN_EXTRA_RIM_WIDTH = 0.03, -- legacy (unused)
        -- Micro pattern v2 (docs/RAINFX_MICRO_PATTERN.md). Bake-time values;
        -- changes need a Lua reload.
        RAIN_DYNAMIC_MICRO_PATTERN_STRATA = 6,
        RAIN_DYNAMIC_MICRO_PATTERN_FIRST_PRESENCE = 0.55,
        RAIN_DYNAMIC_MICRO_PATTERN_PRESENCE = 0.77,
        RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MIN = 0.32, -- cells, FINE TUNED
        RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MAX = 0.55, -- cells, FINE TUNED
        RAIN_DYNAMIC_MICRO_PATTERN_RIM_CELLS = 0.07, -- superseded by RIM_TEXELS
        -- Invisible cut line: the winner's outer ring (in pattern texels)
        -- shows the unrefracted scene/haze, separating fragments.
        RAIN_DYNAMIC_MICRO_PATTERN_RIM_TEXELS = 1.43,       -- FINE TUNED
        -- Pattern texels per grid cell (legacy look 2048 / 546 = 3.75).
        RAIN_DYNAMIC_MICRO_PATTERN_TEXELS_PER_CELL = 12.00,     --FINE TUNED
        -- 0 = invisible cut line (gap). > 0 = draw the ring refracted but
        -- darkened by this amount instead.
        RAIN_DYNAMIC_MICRO_PATTERN_OUTLINE_DARK = 0.0,
        RAIN_DYNAMIC_MICRO_LAYER_SCENE_MIP = 4.1,
        RAIN_DYNAMIC_MICRO_LAYER_OPACITY = 0.8,
        -- Persistent UV wipe mask composited with the static micro layer.
        RAIN_DYNAMIC_TRAIL_MASK_ENABLED = true,
        RAIN_DYNAMIC_TRAIL_MASK_DEBUG = false,
        RAIN_DYNAMIC_TRAIL_MASK_WIPE_ENABLED = true,
        RAIN_DYNAMIC_TRAIL_MASK_WIPE_STRENGTH = 1.0,
        RAIN_DYNAMIC_TRAIL_MASK_FILM_ENABLED = true,
        RAIN_DYNAMIC_TRAIL_MASK_SKY_CORRECTION = true,
        RAIN_DYNAMIC_TRAIL_MASK_FILM_OPACITY = 0.50,
        RAIN_DYNAMIC_TRAIL_MASK_FILM_PIXELS = 7.1,
        RAIN_DYNAMIC_TRAIL_MASK_RIDGE_ENABLED = true,
        RAIN_DYNAMIC_TRAIL_MASK_RIDGE_SECONDS = 0.63,
        RAIN_DYNAMIC_TRAIL_MASK_RIDGE_OPACITY = 0.60,
        RAIN_DYNAMIC_TRAIL_MASK_RIDGE_PIXELS = 7.8,
        RAIN_DYNAMIC_TRAIL_MASK_SIZE = 512,
        RAIN_DYNAMIC_BIRTH_MASK_ENABLED = true,
        RAIN_DYNAMIC_BIRTH_MASK_DEBUG = false,
        RAIN_DYNAMIC_BIRTH_MASK_OPTICS = true,
        RAIN_DYNAMIC_BIRTH_MASK_ONLY = true,
        RAIN_DYNAMIC_BIRTH_MASK_REFRACTION_PIXELS = 32.2,
        RAIN_DYNAMIC_BIRTH_MASK_HIGHLIGHT = 0.70,
        RAIN_DYNAMIC_BIRTH_MASK_OPACITY = 0.90,
        RAIN_DYNAMIC_BIRTH_MASK_SCENE_MIP = 5.9,
        RAIN_DYNAMIC_BIRTH_MASK_IMAGE_MAPPING = true,
        RAIN_DYNAMIC_BIRTH_MASK_IMAGE_SCALE = 12.0,
        RAIN_DYNAMIC_BIRTH_MASK_IMAGE_ROTATION_DEGREES = 180.0,
        RAIN_DYNAMIC_BIRTH_MASK_IMAGE_MIX = 1.0,
        RAIN_DYNAMIC_BIRTH_MASK_SHADOW = 0.195,
        RAIN_DYNAMIC_BIRTH_MASK_RELIEF = 0.70,
        RAIN_DYNAMIC_BIRTH_MASK_EDGE_GAIN = 11.8,
        RAIN_DYNAMIC_BIRTH_MASK_WIDE_NORMAL = true,
        RAIN_DYNAMIC_BIRTH_MASK_NORMAL_REACH_TEXELS = 4.0,
        RAIN_DYNAMIC_BIRTH_MASK_SIZE = 2048,
        RAIN_DYNAMIC_BIRTH_MASK_FULL_REDRAW = true,
        RAIN_DYNAMIC_BIRTH_MASK_BODY_STRETCH = true,
        RAIN_DYNAMIC_BIRTH_MASK_SHAPE_VARIATION = true,
        RAIN_DYNAMIC_BIRTH_MASK_SHAPE_STRENGTH = 0.85,
        RAIN_DYNAMIC_BIRTH_PUDDLE_ENABLED = true,
        RAIN_DYNAMIC_BIRTH_PUDDLE_SHARE = 0.25,
        RAIN_DYNAMIC_BIRTH_PUDDLE_MIN_MM = 1.40,
        RAIN_DYNAMIC_BIRTH_PUDDLE_REACH = 0.70,
        RAIN_DYNAMIC_BIRTH_MASK_SKY_CORRECTION = true,
        RAIN_DYNAMIC_MICRO_PATTERN_SKY_CORRECTION = true,
        RAIN_DYNAMIC_BIRTH_MASK_BODY_LOOKBACK_SECONDS = 0.04,
        RAIN_DYNAMIC_BIRTH_MASK_BODY_MAX_RADII = 1.5,
        RAIN_DYNAMIC_BIRTH_MASK_SECONDS = 1.20,
        RAIN_DYNAMIC_BIRTH_MASK_MAX_STAMPS = 64,
        RAIN_DYNAMIC_BIRTH_MASK_RECENT_STAMPS = 24,
        RAIN_DYNAMIC_BIRTH_MASK_GROW_SECONDS = 0.12,

        -- Water field (docs/RAINFX_WATER_FIELD.md). Heads are drawn as soft
        -- height kernels into the birth-mask canvas (fp16): G = union height,
        -- R/G = radius code (radius texels / 32), B/G = impact energy.
        -- A threshold on G gives the silhouette, so overlapping kernels merge
        -- like metaballs; the slope of G drives one screen-space refraction
        -- rule for every shape (round, lobed, torn, trail). false = legacy.
        RAIN_DYNAMIC_WATER_FIELD_ENABLED = true,
        RAIN_DYNAMIC_WATER_FIELD_DEBUG = 0, -- 1 height/silhouette, 2 slope
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
        RAIN_DYNAMIC_WATER_FIELD_TEAR_ENABLED = true,
        RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KMH = 50.0,
        RAIN_DYNAMIC_WATER_FIELD_TEAR_FULL_KMH = 150.0,
        RAIN_DYNAMIC_WATER_FIELD_TEAR_SECONDS = 0.44,
        RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_DIAMETER_MM = 0.70,
        -- Kernels below ~1.5 texels never cross the silhouette threshold
        -- on the texel grid; tear pieces are clamped to this size.
        RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS = 0.85,
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED = true,
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_SIZE = 1024,
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_SECONDS = 0.46,      -- FINE TUNED
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_WIDTH = 0.78,        -- FINE TUNED
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_NOISE = 0.75,        -- FINE TUNED
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_NOISE_CELLS = 203.0, -- FINE TUNED
        RAIN_DYNAMIC_WATER_FIELD_TRAIL_MIN_SPEED = 0.004, -- visor UV / s

        -- Haze / condensation film (docs/RAINFX_HAZE.md). Procedural in
        -- visor UV (no texture); revealed by rain in a stable order, cleared
        -- by wipes and water-field tracks; composited under micro disks.
        RAIN_DYNAMIC_HAZE_ENABLED = true,
        RAIN_DYNAMIC_HAZE_DEBUG = false,
        RAIN_DYNAMIC_HAZE_TEXTURE_SIZE = 1024,
        RAIN_DYNAMIC_HAZE_MIST_CELLS = 31.7,
        RAIN_DYNAMIC_HAZE_ORDER_CELLS = 30.0,
        RAIN_DYNAMIC_HAZE_SPECKLE_CELLS = 1500.0,
        RAIN_DYNAMIC_HAZE_STRENGTH = 0.87,
        RAIN_DYNAMIC_HAZE_MOTTLE = 0.70,
        RAIN_DYNAMIC_HAZE_RAIN_POWER = 0.80,
        RAIN_DYNAMIC_HAZE_REVEAL_SOFT = 0.40,
        RAIN_DYNAMIC_HAZE_MIP = 4.5,
        RAIN_DYNAMIC_HAZE_VEIL = 0.12,
        RAIN_DYNAMIC_HAZE_SPECKLE_PIXELS = 2.0,
        RAIN_DYNAMIC_HAZE_TRAIL_CLEAR = 0.90,
        RAIN_DYNAMIC_HAZE_SKY_CORRECTION = true,
        RAIN_DYNAMIC_TRAIL_MASK_MAX_STAMPS = 64,
        RAIN_DYNAMIC_TRAIL_MASK_SECONDS = 3.11,
        -- Stage 4B.2D: compare HDR/LDR dynamic scene textures using both
        -- pin.ScreenPos and a fixed screen-center UV after a late Lua reload.
        RAIN_DYNAMIC_DROP_SCENE_SOURCE_DEBUG = false,

        -- Stage 4B.2F: compare possible interpretations of mesh.fx ScreenPos.
        RAIN_DYNAMIC_DROP_SCREEN_UV_DEBUG = false,
        -- Test whether track-stage HDR works without the extra scene copy.
        RAIN_DYNAMIC_DROP_SCREEN_UV_PREPASS = false,
        -- Compare dynamic::hdr at the track transparent draw stage.
        RAIN_DYNAMIC_DROP_DRAW_AT_TRACK = true,
        -- Verified: this stage excludes sharp rain streaks from dynamic
        -- drops. Other KN5 transparent visor regions still show the artifact
        -- and require a separate visor-wide rendering/order investigation.
        RAIN_DYNAMIC_DROP_DRAW_AT_SMOKE_DEBUG = true,
        -- Leave three empty frames before each diagnostic draw to check
        -- whether HDR/LDR contains droplets from earlier frames.
        RAIN_DYNAMIC_DROP_SPARSE_FRAME_DEBUG = false,
        -- Compare live HDR with an opaque-pass copy if needed.
        RAIN_DYNAMIC_DROP_HDR_SNAPSHOT_DEBUG = false,
        -- Render the scene again without the hidden transport mesh to test
        -- a source that cannot contain previous droplet draws.
        RAIN_DYNAMIC_DROP_GEOMETRY_SHOT_DEBUG = true,
        -- Keep the best empirical scale as a reference against projection.
        RAIN_DYNAMIC_DROP_GEOMETRY_UV_SCALE_A = 20.5,
        RAIN_DYNAMIC_DROP_PIXEL_UV_DEBUG = true,

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
    defines = { RAIN_GPU_STATE_PASS = true },

    textures = {
        txRainState = false,
        txRainStateMeta = false,
        txRainSurfaceNormal = false,
        txRainBoundaryMask = false,
    },

    values = {
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
            for (int attempt = 0; attempt < 128; ++attempt)
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
                for (int probe = 0; probe < 16; ++probe)
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
                    rainStateFindValidPosition(
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
    textures = {
        txRainStateMeta = false,
        txRainState = false,
        txRainBoundaryMask = false,
    },
    values = {
        gRainStateDeltaTime = 0.0,
        gRainStateCount = 256.0,
        gRainStateInit = 0.0,
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
                    float admission = rainStateHash(index + 419.0);
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


local PARAMS_KS_PERPIXELREFLECTION = {
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
            id = 'BODYFRAMEFLIP',

            meshName = 
                'BODY_FRAME_FLIP',

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
            id = 'GLASSRUBBER',

            meshName = 
                'BODY_INT_BORDER_GLASSLINE',

            materialName = 
                'mtBODY_INT_BORDER',

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
            id = 'BODYFABRIC',

            meshName = 
                'BODY_INT_FABRIC',

            materialName = 
                'mtBODY_INT_FABRIC',

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
            id = 'GLASSEXT',

            meshName = 
                'GLASS_EXT',

            materialName = 
                'mtGLASS_EXT',

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
            id = 'GLASSCOATING',

            meshName = 
                'GLASS_COATING',

            materialName = 
                'mtGLASS_COATING',

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

    rainStateMetaUpdateParams.textures.txRainStateMeta = false
    rainStateMetaUpdateParams.textures.txRainState = false
    rainStateMetaUpdateParams.textures.txRainBoundaryMask = textureRainBoundaryMask

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
    rainStateUpdateParams.values.gRainAirVelocityWorld:set(
        -ac.getCar(0).velocity.x,
        -ac.getCar(0).velocity.y,
        -ac.getCar(0).velocity.z
    )
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
    local microCount = cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_ENABLED
        and not useMicroPattern
        and math.max(0, math.floor(cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_COUNT))
        or 0
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
    local microVertexIndex = count * 4 + 1
    local microMapped = 0
    local microClusters = math.max(1, math.ceil(microCount / 3))
    for i = 0, microCount - 1 do
        local cluster = math.floor(i / 3)
        local anchor = rainDynamicSurfaceAreaWeightedUV(
            rainDynamicSurfaceLookup, cluster, microClusters)
        local diameterMM = cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_MIN_DIAMETER_MM
            + rainDynamicSurfaceFrac((i + 0.5) * 0.61803398875)
                * (cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_MAX_DIAMETER_MM
                    - cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_MIN_DIAMETER_MM)
        local spreadUV = diameterMM
            * cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM * 0.90
        local uv = anchor and vec2(
            anchor.x + (rainDynamicSurfaceFrac((i + 0.5) * 0.7548776662) - 0.5) * spreadUV,
            anchor.y + (rainDynamicSurfaceFrac((i + 0.5) * 0.5698402911) - 0.5) * spreadUV)
            or nil
        local sample = uv and rainDynamicSurfaceSample(
            rainDynamicSurfaceLookup, vertices, uv) or nil
        if not sample and anchor then
            sample = rainDynamicSurfaceSample(
                rainDynamicSurfaceLookup, vertices, anchor)
        end
        if sample then microMapped = microMapped + 1 end
        local seed = 2048 + (i % 1021)
        local microRadiusUV = diameterMM
            * cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM * 0.5
        local indexBase = (i + 1) * 6 - 5
        local center = sample and sample.position
            + sample.normal * cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_TEST_OFFSET_M
            or vec3(0, 0, 0)
        local normal = sample and sample.normal or vec3(0, 0, 1)
        local uOffset = sample and sample.tangentU
            * (microRadiusUV * sample.metersPerUVU) or vec3(0, 0, 0)
        local vOffset = sample and sample.tangentV
            * (microRadiusUV * sample.metersPerUVV) or vec3(0, 0, 0)
        meshVertices:set(microVertexIndex, ac.MeshVertex.new(
            center - uOffset - vOffset, normal, vec2(seed * 2, 0)))
        meshVertices:set(microVertexIndex + 1, ac.MeshVertex.new(
            center + uOffset - vOffset, normal, vec2(seed * 2 + 1, 0)))
        meshVertices:set(microVertexIndex + 2, ac.MeshVertex.new(
            center + uOffset + vOffset, normal, vec2(seed * 2 + 1, 1)))
        meshVertices:set(microVertexIndex + 3, ac.MeshVertex.new(
            center - uOffset + vOffset, normal, vec2(seed * 2, 1)))
        local microBase = count * 4 + i * 4
        meshIndices:set(indexBase, microBase)
        meshIndices:set(indexBase + 1, microBase + 1)
        meshIndices:set(indexBase + 2, microBase + 2)
        meshIndices:set(indexBase + 3, microBase)
        meshIndices:set(indexBase + 4, microBase + 2)
        meshIndices:set(indexBase + 5, microBase + 3)
        microVertexIndex = microVertexIndex + 4
    end
    if not useMicroPattern then
        ac.log(appNameDebug .. ' Micro layer mesh: mapped='
            .. tostring(microMapped) .. '/' .. tostring(microCount)
            .. ' clusters=' .. tostring(microClusters)
            .. ' diameterMM='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_MIN_DIAMETER_MM)
            .. '..'
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_MAX_DIAMETER_MM))
    end

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
            if rainDynamicSceneCopyState.microNormalCanvas then
                rainDynamicSceneCopyState.microNormalCanvas:dispose()
                rainDynamicSceneCopyState.microNormalCanvas = nil
            end
            rainDynamicSceneCopyState.microNormalReady = false
            if rainDynamicSceneCopyState.microPatternReady then
                local normalSize = math.max(256,
                    math.floor(cfg.RUNTIME.RAIN_DYNAMIC_MICRO_NORMAL_TEXTURE_SIZE))
                local canvasOk, normalCanvas = pcall(function()
                    return ui.ExtraCanvas(vec2(normalSize, normalSize), 6,
                        render.TextureFormat.R8G8B8A8.UNorm)
                        :setName('RainFX static micro normals')
                end)
                if canvasOk and normalCanvas then
                    local bakeOk, bakeResult = pcall(function()
                        local updated = normalCanvas:updateWithShader({
                            textures = {
                                txMicroMask = rainDynamicSceneCopyState.microPatternCanvas
                            },
                            shader = [[
                                SamplerState samLinearMicroBake
                                {
                                    Filter = MIN_MAG_MIP_LINEAR;
                                    AddressU = CLAMP;
                                    AddressV = CLAMP;
                                    AddressW = CLAMP;
                                };
                                float4 main(PS_IN pin)
                                {
                                    float4 disk = txMicroMask.SampleLevel(
                                        samLinearMicroBake, pin.Tex, 0.0);
                                    float2 xy = disk.xy * 2.0 - 1.0;
                                    float z = sqrt(saturate(1.0 - dot(xy, xy)));
                                    float3 normal = normalize(float3(xy, z));
                                    return float4(normal * 0.5 + 0.5, 1.0);
                                }
                            ]]
                        })
                        if updated ~= false then
                            normalCanvas:mipsUpdate()
                        end
                        return updated
                    end)
                    rainDynamicSceneCopyState.microNormalReady =
                        bakeOk and bakeResult ~= false
                    if rainDynamicSceneCopyState.microNormalReady then
                        rainDynamicSceneCopyState.microNormalCanvas = normalCanvas
                    else
                        normalCanvas:dispose()
                        ac.warn(appNameDebug .. ' Micro normal bake: '
                            .. tostring(bakeResult))
                    end
                else
                    ac.warn(appNameDebug .. ' Micro normal canvas: '
                        .. tostring(normalCanvas))
                end
                ac.log(appNameDebug .. ' Micro normals: '
                    .. tostring(normalSize) .. 'x' .. tostring(normalSize)
                    .. ' ready='
                    .. tostring(rainDynamicSceneCopyState.microNormalReady))
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
            rainDynamicSceneCopyState.updateTrailMask, sim)
        if not maskOk and not rainDynamicSceneCopyState.maskWarned then
            ac.warn(appNameDebug .. ' Dynamic UV mask update failed: '
                .. tostring(maskError))
            rainDynamicSceneCopyState.maskWarned = true
        end
        rainDynamicSceneCopyState.microRebakeIfNeeded(
            rainDynamicSceneCopyState)
        if cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED then
            local birthOk, birthError = pcall(
                rainDynamicSceneCopyState.updateBirthMask, sim)
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
        state.trailMaskA = ui.ExtraCanvas(vec2(size, size), 1,
            render.TextureFormat.R8G8B8A8.UNorm)
            :setName('RainFX Wipe Mask A')
        state.trailMaskB = ui.ExtraCanvas(vec2(size, size), 1,
            render.TextureFormat.R8G8B8A8.UNorm)
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
                return float4(previous.r * gRidgeDecay,
                    previous.g * gWipeDecay, 0.0,
                    previous.a * gWipeDecay);
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
                    stamps[#stamps + 1] = {
                        x0 = fromU * size, y0 = (fromV + 1.0) * size,
                        x1 = u * size, y1 = (v + 1.0) * size,
                        radius = math.max(radius * size, 1.4),
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
        target:update(function()
            local wipeColor = rgbm(0.0, 0.95, 0.0, 1.0)
            local ridgeColor = rgbm(0.95, 0.95, 0.0, 1.0)
            for _, stamp in ipairs(stamps) do
                local first = vec2(stamp.x0, stamp.y0)
                local last = vec2(stamp.x1, stamp.y1)
                ui.drawLine(first, last, wipeColor,
                    math.max(stamp.radius * 1.5, 2.0))
                ui.drawCircleFilled(last, stamp.radius,
                    wipeColor, 8)
                -- Narrow liquid core inside a wider wiped footprint.
                ui.drawLine(first, last, ridgeColor,
                    math.max(stamp.radius * 0.75, 1.0))
                ui.drawCircleFilled(last,
                    math.max(stamp.radius * 0.55, 0.75),
                    ridgeColor, 8)
            end
        end)
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

-- Impact splash (docs/RAINFX_WATER_FIELD.md): a pressed "pancake" that
-- spreads to a wide flat disk sized from the drop, with a torn rim of
-- random lobes/notches/tongues and a few small satellite droplets.
-- Everything is random per life (seeds), nothing is evenly spaced.
-- `stage` 1..4 grows the pancake (drawn once per stage into the persistent
-- trail canvas); satellites appear at the last stage. `scale` maps head
-- texels to the target canvas; radius codes stay in head texels.
rainDynamicSceneCopyState.waterFieldTearPieces = function(quad, origin,
    scale, stage, minKernel)
    local frac = rainDynamicSurfaceFrac
    local Rf = origin.radius
    local amount = origin.amount
    local sa0, sb0 = origin.seedA, origin.seedB
    local x, y = origin.x, origin.y
    local grow = 0.5 + 0.125 * math.min(stage, 4)
    local pancake = Rf * (1.4 + 0.9 * amount) * (0.85 + 0.3 * frac(sa0 * 9.1))
        * grow
    local count = 0
    -- Flat core: a big, low-slope body (thin film, clear interior).
    local ox = (frac(sb0 * 5.3) - 0.5) * 0.2 * pancake
    local oy = (frac(sa0 * 6.7) - 0.5) * 0.2 * pancake
    quad((x + ox) * scale, (y + oy) * scale, pancake * 0.95 * scale,
        pancake * (0.86 + 0.12 * frac(sb0 * 2.9)) * scale,
        math.cos(sa0 * 6.28), math.sin(sa0 * 6.28), pancake / 32.0, 1.0)
    count = count + 1
    -- Torn rim: random angles, random radial reach, some missing (notches),
    -- some stretched outward (tongues).
    local rimCount = 14 + math.floor(10 * amount * frac(sb0 * 3.7) + 0.5)
    for k = 1, rimCount do
        local h1 = frac(sa0 * 17.13 + k * 0.7548776662)
        local h2 = frac(sb0 * 11.71 + k * 0.5698402911)
        local h3 = frac((sa0 + sb0) * 7.77 + k * 0.4142135623)
        if h3 > 0.18 then
            local a = h1 * math.pi * 2.0
            local ca, sn = math.cos(a), math.sin(a)
            local reach = pancake * (0.86 + 0.22 * h2)
            local rr = math.max(minKernel, pancake * (0.07 + 0.10 * h3))
            local tongue = h2 > 0.85 and (1.5 + 1.0 * h3) or 1.0
            quad((x + ca * reach) * scale, (y + sn * reach) * scale,
                rr * tongue * scale, rr * scale, ca, sn, rr / 32.0, 1.0)
            count = count + 1
        end
    end
    -- Satellites: a few small droplets thrown clear of the rim.
    if stage >= 4 then
        local satellites = math.floor(2 + 5 * amount * frac(sa0 * 4.9) + 0.5)
        for k = 1, satellites do
            local h1 = frac(sb0 * 13.3 + k * 0.6180339887)
            local h2 = frac(sa0 * 19.9 + k * 0.3819660113)
            local a = h1 * math.pi * 2.0
            local d = pancake * (1.2 + 0.7 * h2)
            local rr = math.max(minKernel, Rf * (0.10 + 0.22 * h2))
            quad((x + math.cos(a) * d) * scale, (y + math.sin(a) * d) * scale,
                rr * scale, rr * scale, 1.0, 0.0, rr / 32.0, 1.0)
            count = count + 1
        end
    end
    return count
end

-- Draws every head stamp as soft kernels. Called inside canvas:update().
rainDynamicSceneCopyState.waterFieldDrawStamps = function(state, stamps,
    size, sim)
    local kernel = state.waterKernel(state)
    local ks = math.max(1.0, cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_KERNEL_SCALE)
    local q1, q2, q3, q4 = vec2(), vec2(), vec2(), vec2()
    local color = rgbm(0.0, 1.0, 0.0, 1.0)
    local function kernelQuad(cx, cy, rx, ry, ux, uy, code, energy)
        local ax, ay = rx * ks, ry * ks
        local vx, vy = -uy, ux
        q1.x, q1.y = cx - ux * ax - vx * ay, cy - uy * ax - vy * ay
        q2.x, q2.y = cx + ux * ax - vx * ay, cy + uy * ax - vy * ay
        q3.x, q3.y = cx + ux * ax + vx * ay, cy + uy * ax + vy * ay
        q4.x, q4.y = cx - ux * ax + vx * ay, cy - uy * ax + vy * ay
        color.r = math.min(code, 1.0)
        color.g = 1.0
        color.b = energy
        color.mult = 1.0
        ui.drawImageQuad(kernel, q1, q2, q3, q4, color)
    end
    local lobes = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_LOBES
    local stretchGain = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_MOTION_STRETCH
    local car = ac.getCar(0)
    local kmh = car and car.speedKmh or 0.0
    local tearMin = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KMH
    local tearAmount = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_ENABLED
        and math.max(0.0, math.min(1.0, (kmh - tearMin) / math.max(
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_FULL_KMH - tearMin,
            1.0))) or 0.0
    local tearSeconds = math.max(
        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_SECONDS, 0.01)
    local tearMinRadiusUV =
        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_DIAMETER_MM * 0.5
        * cfg.RUNTIME.RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM
    local tearMinKernel = math.max(0.5,
        cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS)
    local drawn = 0
    local tearing = 0
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
            -- Body: mild stretch along motion, radius-relative.
            local stretch = math.min(0.6, speed * stretchGain
                / math.max(R / size, 1e-6) * 0.05)
            kernelQuad(stamp.x, stamp.y, R * (1.0 + 0.6 * stretch),
                R * (1.0 - 0.25 * stretch), ux, uy, code, 0.0)
            drawn = drawn + 1
            -- Tapered tail: two shrinking kernels toward the tail point.
            if stamp.tailX then
                for k = 1, 2 do
                    local t = k * 0.4
                    kernelQuad(stamp.x + (stamp.tailX - stamp.x) * t,
                        stamp.y + (stamp.tailY - stamp.y) * t,
                        R * (0.85 - 0.3 * t), R * (0.85 - 0.3 * t),
                        ux, uy, code, 0.0)
                end
                drawn = drawn + 2
            end
            -- Existing per-life lobe and puddle circles become kernels.
            if stamp.lobeX then
                kernelQuad(stamp.lobeX, stamp.lobeY, stamp.lobeRadius,
                    stamp.lobeRadius, ux, uy, stamp.lobeRadius / 32.0, 0.0)
                drawn = drawn + 1
            end
            if stamp.puddleX then
                kernelQuad(stamp.puddleX, stamp.puddleY, stamp.puddleRadius,
                    stamp.puddleRadius, ux, uy, stamp.puddleRadius / 32.0, 0.0)
                kernelQuad(stamp.puddle2X, stamp.puddle2Y,
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
                    kernelQuad(stamp.x + math.cos(a) * d,
                        stamp.y + math.sin(a) * d, rr, rr, ux, uy,
                        R / 32.0, 0.0)
                end
                drawn = drawn + count
            end
            -- Impact at speed: a torn splash that stays WHERE IT LANDED.
            -- The pieces are separate water; only the head keeps moving.
            -- With trails on, the splash is stamped once into the
            -- persistent trail canvas (it then thins and beads there).
            -- Without trails it is drawn at the frozen impact origin.
            local birthAt = state.birthSeenAt and state.birthSeenAt[index]
            local age = birthAt and rainDynamicStateRenderClock - birthAt
            if tearAmount > 0.0 and age and age >= 0.0 and age < tearSeconds
                and (rainDynamicStateRadius[index] or 0.0) >= tearMinRadiusUV
            then
                local Rf = math.max(R,
                    (rainDynamicStateRadius[index] or 0.0) * size)
                state.tearOrigin = state.tearOrigin or {}
                local origin = state.tearOrigin[index]
                if not origin or origin.generation ~= generation then
                    origin = { generation = generation, x = stamp.x,
                        y = stamp.y, radius = Rf, seedA = seedA,
                        seedB = seedB, amount = tearAmount, stage = 0 }
                    state.tearOrigin[index] = origin
                end
                -- Spread in 4 steps over ~0.12 s (one stamp per step).
                local targetStage = math.min(4, math.floor(age / 0.03) + 1)
                if cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED then
                    state.pendingSplash = state.pendingSplash or {}
                    while origin.stage < targetStage do
                        origin.stage = origin.stage + 1
                        state.pendingSplash[#state.pendingSplash + 1] =
                            { origin = origin, stage = origin.stage }
                    end
                else
                    origin.stage = targetStage
                    drawn = drawn + state.waterFieldTearPieces(kernelQuad,
                        origin, 1.0, targetStage, tearMinKernel)
                end
                tearing = tearing + 1
            end
        end
    end
    state.waterFieldKernels = drawn
    state.waterFieldTearHeads = tearing
end

-- Persistent, noisily decaying trail canvas (thinner copies of moving heads).
rainDynamicSceneCopyState.waterFieldUpdateTrail = function(state, stamps,
    headSize, sim)
    if not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED then
        state.waterTrailReady = false
        return
    end
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
        textures = { txTrailPrevious = source },
        values = {
            gTrailDecay = decay,
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
                // Spatially varying decay: thinning tracks break into
                // beads where the noise keeps water longer.
                float n = trailNoise(pin.Tex * gTrailNoiseCells);
                float k = pow(gTrailDecay,
                    max(0.05, 1.0 + gTrailNoise * (n * 2.0 - 1.0)));
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
    local ks = math.max(1.0, cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_KERNEL_SCALE)
    local p1, p2 = vec2(), vec2()
    local q1, q2, q3, q4 = vec2(), vec2(), vec2(), vec2()
    local color = rgbm(0.0, 1.0, 0.0, 1.0)
    local function trailQuad(cx, cy, rx, ry, ux, uy, code, energy)
        local ax, ay = rx * ks, ry * ks
        local vx, vy = -uy, ux
        q1.x, q1.y = cx - ux * ax - vx * ay, cy - uy * ax - vy * ay
        q2.x, q2.y = cx + ux * ax - vx * ay, cy + uy * ax - vy * ay
        q3.x, q3.y = cx + ux * ax + vx * ay, cy + uy * ax + vy * ay
        q4.x, q4.y = cx - ux * ax + vx * ay, cy - uy * ax + vy * ay
        color.r = math.min(code, 1.0)
        color.g = 1.0
        color.b = energy
        color.mult = 1.0
        ui.drawImageQuad(kernel, q1, q2, q3, q4, color)
    end
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
                trails = trails + state.waterFieldTearPieces(trailQuad,
                    item.origin, scale, item.stage,
                    tearMinKernel / math.max(scale, 0.05))
            end
        end
        for _, stamp in ipairs(stamps) do
            local index = stamp.index
            local vu = rainDynamicStateVelocityU[index] or 0.0
            local vv = rainDynamicStateVelocityV[index] or 0.0
            local speed = math.sqrt(vu * vu + vv * vv)
            local R = stamp.radius or 0.0
            if speed >= minSpeed and R > 0.5 then
                -- Just behind the head, so the head itself stays crisp.
                local back = R * 0.9 / speed
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
                trails = trails + 1
            end
        end
    end)
    state.waterTrailStamps = trails
end

-- Birth probes use a separate small canvas so their growth cannot erase the
-- validated R/G wipe and liquid-ridge channels. Only recent GPU births stamp.
rainDynamicSceneCopyState.updateBirthMask = function(sim)
    if not rainDynamicStateHasSnapshot then return end
    local state = rainDynamicSceneCopyState
    local size = math.max(128, math.floor(
        cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SIZE))
    -- The water field needs fp16 height and radius channels.
    local waterField = cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_ENABLED
    local birthFormat = waterField
        and render.TextureFormat.R16G16B16A16.Float
        or render.TextureFormat.R8G8B8A8.UNorm
    if not state.birthMaskA or state.birthMaskSize ~= size
        or state.birthMaskWaterField ~= waterField then
        if state.birthMaskA then state.birthMaskA:dispose() end
        if state.birthMaskB then state.birthMaskB:dispose() end
        state.birthMaskWaterField = waterField
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
    local fullRedraw = cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_FULL_REDRAW
        or waterField
    local target
    local seconds = math.max(
        cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SECONDS, 0.05)
    if fullRedraw then
        if state.birthMaskB then
            state.birthMaskRead = state.birthMaskA
            state.birthMaskB:dispose()
            state.birthMaskB = nil
        end
        target = state.birthMaskA
        target:clear(rgbm.colors.transparent)
    else
        if not state.birthMaskB then
            state.birthMaskB = ui.ExtraCanvas(vec2(size, size), 1,
                birthFormat)
                :setName('RainFX Birth Mask B')
            state.birthMaskB:clear(rgbm.colors.transparent)
        end
        local source = state.birthMaskRead
        target = source == state.birthMaskA
            and state.birthMaskB or state.birthMaskA
        local decay = math.exp(
            -math.min(math.max(sim.dt or 0.0, 0.0), 0.05)
            * 2.0 / seconds)
        local copied = target:updateWithShader({
            async = true,
            textures = { txBirthPrevious = source },
            values = { gBirthDecay = decay },
            shader = [[
                float4 main(PS_IN pin)
                {
                    float4 previous = txBirthPrevious.SampleLevel(
                        samLinearClamp, pin.Tex, 0.0);
                    return float4(previous.rgb * gBirthDecay,
                        previous.r * gBirthDecay);
                }
            ]]
        })
        if copied == false then return end
    end

    local stamps = {}
    local count = rainDynamicStateReadbackCount
    local budget = math.max(1, math.floor(
        cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_MAX_STAMPS))
    if fullRedraw then budget = math.max(budget, count) end
    local recentBudget = fullRedraw and count
        or math.min(budget, math.max(0, math.floor(
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_RECENT_STAMPS)))
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
                local secondary = rainDynamicSurfaceFrac(
                    stamp.index * 0.6180339887
                    + generation * 0.4142135623)
                local jitter = (secondary - 0.5) * 1.10
                local dirX = (stamp.x / size - 0.5) * 0.9
                    + jitter
                local dirY = 1.0 + (seed - 0.5) * 0.30
                local length = math.sqrt(dirX * dirX + dirY * dirY)
                local radius = stamp.radius
                local reach = radius
                    * (0.45 + 0.15 * secondary) * strength
                stamp.lobeX = stamp.x + dirX / length * reach
                stamp.lobeY = stamp.y + dirY / length * reach
                stamp.lobeRadius = radius * (0.55 + 0.10 * secondary)
                stamp.radius = radius * (1.0 - 0.10 * strength)
                shaped = shaped + 1
            end
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
    if waterField then
        -- Bake the kernel outside any canvas:update() callback.
        state.waterKernel(state)
        if #stamps > 0 then
            target:update(function()
                state.waterFieldDrawStamps(state, stamps, size, sim)
            end)
        end
        state.waterFieldUpdateTrail(state, stamps, size, sim)
    elseif #stamps > 0 then
        target:update(function()
            for _, stamp in ipairs(stamps) do
                -- R: footprint, G/B: the unwarped droplet center in
                -- normalized visor UV. One lifetime keeps one scene pivot.
                local bodyColor = rgbm(1.0,
                    stamp.x / size, stamp.y / size, 1.0)
                if stamp.tailX then
                    ui.drawLine(
                        vec2(stamp.tailX, stamp.tailY),
                        vec2(stamp.x, stamp.y),
                        bodyColor,
                        stamp.radius * 2.0)
                    ui.drawCircleFilled(
                        vec2(stamp.tailX, stamp.tailY),
                        stamp.radius,
                        bodyColor, 12)
                end
                if stamp.puddleX then
                    ui.drawCircleFilled(vec2(stamp.puddleX, stamp.puddleY),
                        stamp.puddleRadius, bodyColor, 12)
                    ui.drawCircleFilled(vec2(stamp.puddle2X, stamp.puddle2Y),
                        stamp.puddle2Radius, bodyColor, 12)
                end
                if stamp.lobeX then
                    ui.drawCircleFilled(
                        vec2(stamp.lobeX, stamp.lobeY),
                        stamp.lobeRadius, bodyColor, 12)
                end
                ui.drawCircleFilled(
                    vec2(stamp.x, stamp.y), stamp.radius,
                    bodyColor, 16)
            end
        end)
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
            .. ' fullRedraw=' .. tostring(fullRedraw)
            .. ' recovery=' .. tostring(seconds))
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
    rainDynamicSceneCopyState.geometryShot:setClippingPlanes(
        sim.cameraClipNear,
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
        cfg.RUNTIME.RAIN_DYNAMIC_DROP_UV_DEBUG
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
    local waveDirection = vec2(0.0, 0.0)
    local waveEnvelope = 0.0
    local wavePhase = 0.0
    if cfg.RUNTIME.RAIN_DYNAMIC_DROP_WAVE_ENABLED then
    -- Scope the complete diagnostic force pipeline to the enabled case.
    local waveState = rainDynamicSceneCopyState.waveState
    if not waveState then
        waveState = { envelope = 0.0, previousForce = 0.0, phase = 0.0 }
        rainDynamicSceneCopyState.waveState = waveState
    end
    local car = ac.getCar(0)
    local inertiaEnabled = cfg.RUNTIME.RAIN_FORCE_INERTIA_ENABLED
    local airflowEnabled = cfg.RUNTIME.RAIN_FORCE_AIRFLOW_ENABLED
    local waveSourceMask = (inertiaEnabled and 2 or 0)
        + (airflowEnabled and 4 or 0)
    if waveState.sourceMask ~= waveSourceMask then
        waveState.sourceMask = waveSourceMask
        waveState.envelope = 0.0
        waveState.previousForce = 0.0
        waveState.triggerLogged = false
    end
    local externalAcceleration = rainAccelerationCurrent
    local forceX = inertiaEnabled and car and car.side and (
        externalAcceleration.x * car.side.x
        + externalAcceleration.y * car.side.y
        + externalAcceleration.z * car.side.z
    ) * cfg.RUNTIME.RAIN_PHYSICS_ACCEL_SCALE or 0.0
    local forceY = inertiaEnabled and car and car.look and (
        externalAcceleration.x * car.look.x
        + externalAcceleration.y * car.look.y
        + externalAcceleration.z * car.look.z
    ) * cfg.RUNTIME.RAIN_PHYSICS_ACCEL_SCALE or 0.0
    -- The physics shader evaluates airflow separately for each drop's size
    -- and surface normal. This shared optical test uses one representative
    -- diameter and the car's forward axis as the visor-front normal.
    local airflowMagnitude = 0.0
    if airflowEnabled and car and car.velocity and car.look then
        local velocity = car.velocity
        local speed = math.sqrt(velocity.x * velocity.x
            + velocity.y * velocity.y + velocity.z * velocity.z)
        if speed > 0.0001 then
            local incidence = math.max(0.0, math.min(1.0,
                (velocity.x * car.look.x + velocity.y * car.look.y
                    + velocity.z * car.look.z) / speed))
            local radiusM = math.max(0.000001,
                cfg.RUNTIME.RAIN_DYNAMIC_SURFACE_TEST_DROPLET_DIAMETER_MM
                    * 0.0005)
            -- Exact area/mass ratio of the physics shader's water sphere:
            -- (pi*r^2) / ((4/3)*pi*r^3*1000) = 3/(4000*r).
            airflowMagnitude = 0.5 * math.max(0.0, cfg.RUNTIME.RAIN_AIR_DENSITY)
                * speed * speed
                * math.max(0.0, cfg.RUNTIME.RAIN_AIR_DRAG_COEFF)
                * 3.0 / (4000.0 * radiusM) * incidence
                * cfg.RUNTIME.RAIN_PHYSICS_ACCEL_SCALE
            forceX = forceX - velocity.x / speed * airflowMagnitude
                * car.side.x - velocity.y / speed * airflowMagnitude
                * car.side.y - velocity.z / speed * airflowMagnitude
                * car.side.z
            forceY = forceY - velocity.x / speed * airflowMagnitude
                * car.look.x - velocity.y / speed * airflowMagnitude
                * car.look.y - velocity.z / speed * airflowMagnitude
                * car.look.z
        end
    end
    local forceMagnitude = math.sqrt(forceX * forceX + forceY * forceY)
    local waveDT = math.min(math.max(sim.dt or 0.0, 0.0), 0.1)
    local waveDrive = math.min(1.0, math.max(0.0,
        (forceMagnitude - 0.05) * 3.5))
    local waveImpulse = math.min(1.0, math.max(0.0,
        (forceMagnitude - waveState.previousForce) * 7.0))
    waveState.envelope = math.max(
        waveState.envelope * math.exp(-4.0 * waveDT),
        waveDrive,
        waveImpulse
    )
    waveState.previousForce = forceMagnitude
    waveState.phase = (waveState.phase + waveDT * 9.0) % (math.pi * 2.0)
    if not inertiaEnabled and not airflowEnabled then
        waveState.envelope = 0.0
        waveState.previousForce = 0.0
        waveState.triggerLogged = false
    end
    if waveState.envelope > 0.15 and not waveState.triggerLogged then
        ac.log(appNameDebug .. ' Dynamic drop wave force: inertia='
            .. tostring(inertiaEnabled)
            .. ' airflow=' .. tostring(airflowEnabled)
            .. ' source=rainAccelerationCurrent+airflow magnitude='
            .. string.format('%.3f', forceMagnitude)
            .. ' airflowMagnitude=' .. string.format('%.3f', airflowMagnitude)
            .. ' envelope=' .. string.format('%.3f', waveState.envelope))
        waveState.triggerLogged = true
    end
    waveDirection = vec2(
        forceX / math.max(forceMagnitude, 0.001),
        forceY / math.max(forceMagnitude, 0.001)
    )
    waveEnvelope = waveState.envelope
    wavePhase = waveState.phase
    end
    rainDynamicSurfaceMesh:setVisible(true, false)

    if not rainDynamicManualPreDrawLogged then
        local dynamicHDRSize = ui.imageSize('dynamic::hdr')
        ac.log(
            appNameDebug
            .. ' Dynamic drop Stage 4B.2 pre-draw: uvDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_UV_DEBUG)
            .. ' refractionDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_REFRACTION_DEBUG)
            .. ' sceneSourceDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_SCENE_SOURCE_DEBUG)
            .. ' screenUVDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_SCREEN_UV_DEBUG)
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
            .. ' invertedFootprintDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_INVERTED_FOOTPRINT_DEBUG)
            .. ' concaveLensDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_CONCAVE_LENS_DEBUG)
            .. ' softCompositeDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_SOFT_COMPOSITE_DEBUG)
            .. ' wideGlintDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_WIDE_GLINT_DEBUG)
            .. ' wideSceneDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_WIDE_SCENE_DEBUG)
            .. ' wideRotationRadians='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_WIDE_ROTATION_RADIANS)
            .. ' wideSurfaceRotationDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_WIDE_SURFACE_ROTATION_DEBUG)
            .. ' wideOrbDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_WIDE_ORB_DEBUG)
            .. ' splitCompareDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_SPLIT_COMPARE_DEBUG)
            .. ' wideOrbEdgeMip='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_WIDE_ORB_EDGE_MIP)
            .. ' screenSourceCompareDebug='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_SCREEN_SOURCE_COMPARE_DEBUG)
            .. ' weatherScreenFrame='
            .. tostring(rainDynamicSceneCopyState.weatherFrame)
            .. ' fogColor='
            .. tostring(sim.fogColor)
            .. ' pixelUV='
            .. tostring(cfg.RUNTIME.RAIN_DYNAMIC_DROP_PIXEL_UV_DEBUG)
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

    local dynamicDrawn = render.mesh({
        mesh = rainDynamicSurfaceMesh,
        transform = 'original',
        textures = {
            txDynamicScene = 'dynamic::hdr',
            txDynamicSnapshot = rainDynamicSceneCopyState.geometryShot
                or rainDynamicSceneCopyState.canvas
                or 'dynamic::hdr',
            txDynamicShotDepth =
                rainDynamicSceneCopyState.shotWithDepth
                and rainDynamicSceneCopyState.geometryShot
                and rainDynamicSceneCopyState.geometryShot:depth()
                or false,
            txDynamicScreen = 'dynamic::screen',
            txDynamicWeatherScreen =
                rainDynamicSceneCopyState.weatherScreenCanvas
                or 'dynamic::screen',
            txDynamicControl = textureRainSurfaceNormal,
            txDynamicMicroPattern =
                rainDynamicSceneCopyState.microPatternCanvas or false,
            txDynamicMicroNormal =
                rainDynamicSceneCopyState.microNormalCanvas or false,
            txDynamicTrailMask =
                rainDynamicSceneCopyState.trailMaskRead or false,
            txDynamicBirthMask =
                rainDynamicSceneCopyState.birthMaskRead or false,
            txDynamicWaterTrail =
                rainDynamicSceneCopyState.waterTrailRead or false,
        },
        values = {
            gDynamicDropDebugUV =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_UV_DEBUG
                and 1.0
                or 0.0,

            gDynamicDropHDRCopyDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_HDR_COPY_DEBUG
                and 1.0
                or 0.0,

            gDynamicDropRefractionDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_REFRACTION_DEBUG
                and 1.0
                or 0.0,
            gDynamicDropSkySourceDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_SKY_SOURCE_DEBUG
                and 1.0 or 0.0,
            gDynamicDropOpaqueRefractionSplitDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_OPAQUE_REFRACTION_SPLIT_DEBUG
                and 1.0 or 0.0,

            gDynamicDropSceneSourceDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_SCENE_SOURCE_DEBUG
                and 1.0
                or 0.0,

            gDynamicDropScreenUVDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_SCREEN_UV_DEBUG
                and 1.0
                or 0.0,

            gDynamicDropSnapshotDebug =
                (cfg.RUNTIME.RAIN_DYNAMIC_DROP_HDR_SNAPSHOT_DEBUG
                    or cfg.RUNTIME.RAIN_DYNAMIC_DROP_GEOMETRY_SHOT_DEBUG)
                and 1.0
                or 0.0,

            gDynamicDropGeometryShotDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_GEOMETRY_SHOT_DEBUG
                and 1.0
                or 0.0,
            gDynamicDropSkyDepthDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_SKY_DEPTH_DEBUG
                and rainDynamicSceneCopyState.shotWithDepth
                and 1.0 or 0.0,
            gDynamicDropSkyFogColorDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_SKY_FOG_COLOR_DEBUG
                and rainDynamicSceneCopyState.shotWithDepth
                and 1.0 or 0.0,
            gDynamicDropSkyCloudDetailDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_SKY_CLOUD_DETAIL_DEBUG
                and rainDynamicSceneCopyState.shotWithDepth
                and 1.0 or 0.0,
            gDynamicDropInvertedFootprintDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_INVERTED_FOOTPRINT_DEBUG
                and 1.0 or 0.0,
            gDynamicDropConcaveLensDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_CONCAVE_LENS_DEBUG
                and 1.0 or 0.0,
            gDynamicDropSoftCompositeDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_SOFT_COMPOSITE_DEBUG
                and 1.0 or 0.0,
            gDynamicDropWideGlintDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_WIDE_GLINT_DEBUG
                and 1.0 or 0.0,
            gDynamicDropWideSceneDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_WIDE_SCENE_DEBUG
                and 1.0 or 0.0,
            gDynamicDropWideRotationRadians =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_WIDE_ROTATION_RADIANS,
            gDynamicDropWideSurfaceRotationDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_WIDE_SURFACE_ROTATION_DEBUG
                and 1.0 or 0.0,
            gDynamicDropWideOrbDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_WIDE_ORB_DEBUG
                and 1.0 or 0.0,
            gDynamicDropOrbFieldRadius =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_ORB_FIELD_RADIUS,
            gDynamicDropForwardSceneOnly =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_FORWARD_SCENE_ONLY
                and 1.0 or 0.0,
            gDynamicDropForwardSceneRadius =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_FORWARD_SCENE_RADIUS,
            gDynamicDropOrbInvertImage =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_ORB_INVERT_IMAGE
                and 1.0 or 0.0,
            gDynamicDropOrbPositionBend =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_ORB_POSITION_BEND,
            gDynamicDropOrbSideUpshift =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_ORB_SIDE_UPSHIFT,
            gDynamicDropOrbGlow =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_ORB_GLOW,
            gDynamicDropSplitCompareDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_SPLIT_COMPARE_DEBUG
                and 1.0 or 0.0,
            gDynamicDropWideOrbEdgeMip =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_WIDE_ORB_EDGE_MIP,
            gDynamicDropScreenSourceCompareDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_SCREEN_SOURCE_COMPARE_DEBUG
                and 1.0 or 0.0,
            gDynamicDropWeatherFogColor = sim.fogColor,

            gDynamicDropGeometryUVScaleA =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_GEOMETRY_UV_SCALE_A,
            gDynamicDropPixelUVDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_PIXEL_UV_DEBUG
                and 1.0
                or 0.0,

            gDynamicDropInvScreenSize = vec2(
                1.0 / math.max(sim.windowWidth or 1, 1),
                1.0 / math.max(sim.windowHeight or 1, 1)
            ),

            gDynamicDropInvRenderTargetSize = vec2(
                1.0 / math.max(dynamicRenderTargetSize.x, 1),
                1.0 / math.max(dynamicRenderTargetSize.y, 1)
            ),

            gDynamicDropRefractionPixels =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_REFRACTION_PIXELS,
            gDynamicDropShapeDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_SHAPE_DEBUG and 1.0 or 0.0,
            gDynamicDropShapeStrength =
                cfg.RUNTIME.RAIN_DYNAMIC_DROP_SHAPE_STRENGTH,
            gDynamicDropMicroLayerEnabled =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_ENABLED and 1.0 or 0.0,
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
            gDynamicDropMicroRefractionPixels =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_REFRACTION_PIXELS,
            gDynamicDropMicroPatternGrid =
                rainDynamicSceneCopyState.microPatternGrid or 1,
            gDynamicDropMicroRadiusMin =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MIN,
            gDynamicDropMicroRadiusMax =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RADIUS_MAX,
            gDynamicDropMicroOutlineDark =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_OUTLINE_DARK,
            gDynamicDropMicroImageScale =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_IMAGE_SCALE,
            gDynamicDropMicroImageRotation = vec2(
                math.cos(math.rad(
                    cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_IMAGE_ROTATION_DEGREES)),
                math.sin(math.rad(
                    cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_IMAGE_ROTATION_DEGREES))),
            gDynamicDropMicroAngleLight =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_ANGLE_LIGHT,
            gDynamicDropMicroAngleShadow =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_ANGLE_SHADOW,
            gDynamicDropMicroNormalReady =
                rainDynamicSceneCopyState.microNormalReady and 1.0 or 0.0,
            gDynamicDropMicroNormalBump =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_NORMAL_BUMP,
            gDynamicDropMicroNormalMip =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_NORMAL_MIP,
            gDynamicDropMicroConcaveOptics =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_CONCAVE_OPTICS,
            gDynamicDropMicroLightWorld = sim.lightDirection,
            gDynamicDropMicroNormalGain =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_NORMAL_SCENE_GAIN,
            gDynamicDropObjectToWorld =
                rainDynamicSurfaceParent:getWorldTransformationRaw(),
            gDynamicDropCameraSide = sim.cameraSide,
            gDynamicDropCameraUp = sim.cameraUp,
            gDynamicDropCameraLook = sim.cameraLook,
            gDynamicDropMicroRimStrength =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RIM_STRENGTH,
            gDynamicDropBirthMaskDebug =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED
                and cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_DEBUG
                and rainDynamicSceneCopyState.birthMaskRead
                and 1.0 or 0.0,
            gDynamicDropBirthMaskOptics =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED
                and cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_OPTICS
                and rainDynamicSceneCopyState.birthMaskRead
                and 1.0 or 0.0,
            gDynamicDropBirthSkyCorrection =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SKY_CORRECTION
                and rainDynamicSceneCopyState.shotWithDepth
                and 1.0 or 0.0,
            gDynamicDropMicroSkyCorrection =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_SKY_CORRECTION
                and rainDynamicSceneCopyState.shotWithDepth
                and 1.0 or 0.0,
            gDynamicDropBirthMaskOnly =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED
                and cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ONLY
                and rainDynamicSceneCopyState.birthMaskRead
                and 1.0 or 0.0,
            gDynamicDropBirthRefractionPixels =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_REFRACTION_PIXELS,
            gDynamicDropBirthHighlight =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_HIGHLIGHT,
            gDynamicDropBirthOpacity =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_OPACITY,
            gDynamicDropBirthSceneMip =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SCENE_MIP,
            gDynamicDropBirthImageMapping =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_MAPPING
                and 1.0 or 0.0,
            gDynamicDropBirthImageScale =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_SCALE,
            gDynamicDropBirthImageRotation = vec2(
                math.cos(math.rad(
                    cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_ROTATION_DEGREES)),
                math.sin(math.rad(
                    cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_ROTATION_DEGREES))),
            gDynamicDropBirthImageMix =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_MIX,
            gDynamicDropBirthShadow =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SHADOW,
            gDynamicDropBirthRelief =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_RELIEF,
            gDynamicDropBirthEdgeGain =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_EDGE_GAIN,
            gDynamicDropBirthWideNormal =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_WIDE_NORMAL
                and 1.0 or 0.0,
            gDynamicDropBirthNormalReach =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_NORMAL_REACH_TEXELS,
            gDynamicDropBirthInvMaskSize =
                1.0 / math.max(
                    rainDynamicSceneCopyState.birthMaskSize or 2048, 1),
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
                and 1.0 or 0.0,
            gDynamicDropTrailFilmOpacity =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_OPACITY,
            gDynamicDropTrailFilmPixels =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_FILM_PIXELS,
            gDynamicDropTrailRidgeEnabled =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_ENABLED
                and cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_ENABLED
                and rainDynamicSceneCopyState.trailMaskRead
                and 1.0 or 0.0,
            gDynamicDropTrailRidgeOpacity =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_OPACITY,
            gDynamicDropTrailRidgePixels =
                cfg.RUNTIME.RAIN_DYNAMIC_TRAIL_MASK_RIDGE_PIXELS,
            gDynamicDropMicroSceneMip =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_SCENE_MIP,
            gDynamicDropMicroOpacity =
                cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_OPACITY,
            gDynamicDropWaterField =
                cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED
                and cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_ENABLED
                and rainDynamicSceneCopyState.birthMaskRead
                and rainDynamicSceneCopyState.birthMaskWaterField
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
            gDynamicDropWFNormalStep =
                cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_NORMAL_STEP_TEXELS
                / math.max(rainDynamicSceneCopyState.birthMaskSize or 2048, 1),
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
                and 1.0 or 0.0,
            gDynamicDropWFInvMaskSize = 1.0
                / math.max(rainDynamicSceneCopyState.birthMaskSize or 2048, 1),
            gDynamicDropWaveDirection = waveDirection,
            gDynamicDropWaveEnvelope = waveEnvelope,
            gDynamicDropWavePhase = wavePhase,
        },
        shader = rainDynamicDropShader.HLSL
    })
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

            if editor.id == 'GLASSEXTDUMMY' then
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

    if ui.beginPopup(

        strMaterialEditorPopup,
        
        nil,
        nil,

        materialEditWindowOpen

    ) then

        ui.text(
            editor.materialName
            .. ' - Material'
        )

        ui.separator()


        if not editor.materialQueryRef
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

    end
end


------------------------------------------------------------
-- Main window
------------------------------------------------------------


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
    
        if foundEditor.materialQueryRef then
            ui.text('')
            ui.sameLine(320, 15)
           
            if ui.button(
                '>> Click to Edit [' .. foundEditor.id .. '] <<' 
                ) then
                    
                activeMaterialEditor = 
                    foundEditor
        
                materialEditWindowOpen = 
                    true
        
                if not activeMaterialEditor.loaded then

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
    end
    local densityScale, densityChanged = ui.slider(
        'Moving drop density',
        cfg.RUNTIME.RAIN_GPU_STATE_DENSITY_SCALE,
        0.5, 2.0, '%.2f'
    )
    if densityChanged then
        cfg.RUNTIME.RAIN_GPU_STATE_DENSITY_SCALE = densityScale
    end
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

    ui.separator()
    ui.text('GPU birth mask: growth probe')
    do
        local changed = ui.checkbox('GPU birth mask enabled',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ENABLED
        end
        changed = ui.checkbox('Show cyan birth mask',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_DEBUG)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_DEBUG =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_DEBUG
        end
        changed = ui.checkbox('Birth mask optical scene',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_OPTICS)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_OPTICS =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_OPTICS
        end
        changed = ui.checkbox('Birth mask only (hide old GPU heads)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ONLY)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ONLY =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_ONLY
        end
        ui.text('Changing birth mask only requires game restart to rebuild mesh.')
        changed = ui.checkbox('Birth mask full redraw (no ghost)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_FULL_REDRAW)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_FULL_REDRAW =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_FULL_REDRAW
        end
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
        changed = ui.checkbox('Birth mask weather sky tone',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SKY_CORRECTION)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SKY_CORRECTION =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SKY_CORRECTION
        end
        changed = ui.checkbox('Wide mask normal (compare)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_WIDE_NORMAL)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_WIDE_NORMAL =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_WIDE_NORMAL
        end
        changed = ui.checkbox('Birth scene center mapping (compare)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_MAPPING)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_MAPPING =
                not cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_MAPPING
        end
        changed = ui.checkbox('Micro circles weather sky tone',
            cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_SKY_CORRECTION)
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_SKY_CORRECTION =
                not cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_SKY_CORRECTION
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
        value, changed = ui.slider('Birth scene area scale',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_SCALE,
            0.5, 80.0, '%.1f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_SCALE = value
        end
        value, changed = ui.slider('Birth scene rotation (degrees)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_ROTATION_DEGREES,
            -180.0, 180.0, '%.1f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_ROTATION_DEGREES = value
        end
        value, changed = ui.slider('Birth scene mapping mix',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_MIX,
            0.0, 1.0, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_IMAGE_MIX = value
        end
        value, changed = ui.slider('Birth scene blur / mip level',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SCENE_MIP,
            0.0, 6.0, '%.1f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SCENE_MIP = value
        end
        value, changed = ui.slider('Birth normal reach (mask texels)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_NORMAL_REACH_TEXELS,
            0.5, 4.0, '%.1f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_NORMAL_REACH_TEXELS = value
        end
        value, changed = ui.slider('Birth normal relief',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_RELIEF,
            0.0, 2.5, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_RELIEF = value
        end
        value, changed = ui.slider('Birth refraction edge gain',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_EDGE_GAIN,
            0.0, 40.0, '%.1f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_EDGE_GAIN = value
        end
        value, changed = ui.slider('Birth refraction (pixels)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_REFRACTION_PIXELS,
            0.0, 40.0, '%.1f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_REFRACTION_PIXELS = value
        end
        value, changed = ui.slider('Birth angle highlight',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_HIGHLIGHT,
            0.0, 0.7, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_HIGHLIGHT = value
        end
        value, changed = ui.slider('Birth angle shadow',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SHADOW,
            0.0, 0.50, '%.3f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SHADOW = value
        end
        value, changed = ui.slider('Birth scene opacity',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_OPACITY,
            0.0, 1.0, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_OPACITY = value
        end
        value, changed = ui.slider('Birth growth time (seconds)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_GROW_SECONDS,
            0.03, 0.35, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_GROW_SECONDS = value
        end
        value, changed = ui.slider('Birth mask recovery (seconds)',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SECONDS,
            0.20, 3.0, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_SECONDS = value
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
        value, changed = ui.slider('Birth mask stamps per frame',
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_MAX_STAMPS,
            16.0, 512.0, '%.0f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_BIRTH_MASK_MAX_STAMPS =
                math.floor(value + 0.5)
        end
    end

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

    ui.separator()
    ui.text('Water field heads (soft kernels + threshold)')
    do
        local function wfSlider(label, key, minV, maxV, fmt)
            local value, changed = ui.slider(label,
                cfg.RUNTIME[key], minV, maxV, fmt)
            if changed then cfg.RUNTIME[key] = value end
        end
        if ui.checkbox('Water field enabled',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_ENABLED) then
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_ENABLED =
                not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_ENABLED
        end
        local debug, debugChanged = ui.slider(
            'Water field debug (1 height, 2 slope)',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_DEBUG, 0, 2, '%.0f')
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
        if ui.checkbox('WF torn impacts at speed',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_ENABLED) then
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_ENABLED =
                not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TEAR_ENABLED
        end
        wfSlider('WF tear start (km/h)',
            'RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KMH', 0.0, 200.0, '%.0f')
        wfSlider('WF tear full (km/h)',
            'RAIN_DYNAMIC_WATER_FIELD_TEAR_FULL_KMH', 10.0, 300.0, '%.0f')
        wfSlider('WF tear duration (s)',
            'RAIN_DYNAMIC_WATER_FIELD_TEAR_SECONDS', 0.05, 1.5, '%.2f')
        if ui.checkbox('WF trails',
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED) then
            cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED =
                not cfg.RUNTIME.RAIN_DYNAMIC_WATER_FIELD_TRAIL_ENABLED
        end
        wfSlider('WF trail lifetime (s)',
            'RAIN_DYNAMIC_WATER_FIELD_TRAIL_SECONDS', 0.1, 6.0, '%.2f')
        wfSlider('WF trail width (radii)',
            'RAIN_DYNAMIC_WATER_FIELD_TRAIL_WIDTH', 0.1, 1.0, '%.2f')
        wfSlider('WF trail bead noise',
            'RAIN_DYNAMIC_WATER_FIELD_TRAIL_NOISE', 0.0, 1.5, '%.2f')
        wfSlider('WF trail noise cells',
            'RAIN_DYNAMIC_WATER_FIELD_TRAIL_NOISE_CELLS', 50.0, 1500.0, '%.0f')
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
        wfSlider('WF tear min diameter (mm)',
            'RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_DIAMETER_MM', 0.3, 4.0, '%.2f')
        wfSlider('WF tear min piece (texels)',
            'RAIN_DYNAMIC_WATER_FIELD_TEAR_MIN_KERNEL_TEXELS', 0.5, 4.0, '%.2f')
        local car = ac.getCar(0)
        ui.text(string.format('WF kernels %d | tearing heads %d | %.0f km/h',
            rainDynamicSceneCopyState.waterFieldKernels or 0,
            rainDynamicSceneCopyState.waterFieldTearHeads or 0,
            car and car.speedKmh or 0.0))
    end

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

    ui.separator()
    ui.text('Micro droplets: scene optics')
    do
        local value, changed = ui.slider(
            'Micro scene image scale',
            cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_IMAGE_SCALE,
            1.0, 30.0, '%.1f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_IMAGE_SCALE = value
        end
        value, changed = ui.slider('Micro scene opacity',
            cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_OPACITY,
            0.0, 1.0, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_OPACITY = value
        end
        value, changed = ui.slider('Micro angle rim highlight',
            cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RIM_STRENGTH,
            0.0, 0.60, '%.2f')
        if changed then
            cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RIM_STRENGTH = value
        end
    end
    local microBlur, microBlurChanged = ui.slider(
        'Micro scene blur / mip level',
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_SCENE_MIP,
        0.0, 6.0, '%.1f'
    )
    if microBlurChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_LAYER_SCENE_MIP = microBlur
    end
    local microNormalGain, microNormalChanged = ui.slider(
        'Micro scene shift / visor normal',
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_NORMAL_SCENE_GAIN,
        0.0, 0.20, '%.3f'
    )
    if microNormalChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_NORMAL_SCENE_GAIN = microNormalGain
    end

    local microRotation, microRotationChanged = ui.slider(
        'Micro scene rotation (degrees)',
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_IMAGE_ROTATION_DEGREES,
        -180.0, 180.0, '%.1f'
    )
    if microRotationChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_IMAGE_ROTATION_DEGREES = microRotation
    end
    local microAngleLight, microAngleLightChanged = ui.slider(
        'Micro angle highlight',
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_ANGLE_LIGHT,
        0.0, 2.0, '%.2f'
    )
    if microAngleLightChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_ANGLE_LIGHT = microAngleLight
    end
    local microAngleShadow, microAngleShadowChanged = ui.slider(
        'Micro angle shadow',
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_ANGLE_SHADOW,
        0.0, 2.0, '%.2f'
    )
    if microAngleShadowChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_ANGLE_SHADOW = microAngleShadow
    end

    local microNormalBump, microNormalBumpChanged = ui.slider(
        'Micro convex normal strength',
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_NORMAL_BUMP,
        0.25, 2.5, '%.2f'
    )
    if microNormalBumpChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_NORMAL_BUMP = microNormalBump
    end

    local microNormalMip, microNormalMipChanged = ui.slider(
        'Micro normal softness / mip',
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_NORMAL_MIP,
        0.0, 4.0, '%.1f'
    )
    if microNormalMipChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_NORMAL_MIP = microNormalMip
    end
    local microConcave, microConcaveChanged = ui.slider(
        'Micro concave scene profile',
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_CONCAVE_OPTICS,
        0.0, 3.00, '%.2f'
    )
    if microConcaveChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_CONCAVE_OPTICS = microConcave
    end

    local microRainPower, microRainPowerChanged = ui.slider(
        'Micro circle density / rain curve',
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RAIN_POWER,
        -1.00, 3.00, '%.2f'
    )
    if microRainPowerChanged then
        cfg.RUNTIME.RAIN_DYNAMIC_MICRO_PATTERN_RAIN_POWER = microRainPower
    end

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
        {'Surface speed 1 mm (UV/s)', 'RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_1MM', 0.001, 0.10, '%.4f'},
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
    ui.text('Airflow is OFF by default; enable it for force tests.')

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

        ui.text('RAIN_DEBUG 41: white = current position valid, yellow = current position outside mask, red = predicted boundary crossing.')
    end

        end)

    end)

    --------------------------------------------------------
    -- Material Parameter: floating editor window
    --------------------------------------------------------

    drawMaterialEditorWindow(activeMaterialEditor)


end
