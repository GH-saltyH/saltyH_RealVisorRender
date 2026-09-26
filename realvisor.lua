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
    local rainDynamicMeshTestVertices = nil
    local rainDynamicMeshTestIndices = nil
    local rainDynamicMeshTestInitialized = false

    
    --------------------------------------------------------
    -- Path: Settings
    --------------------------------------------------------
    
    local settingsFile = 
    appFolder .. '/settings.ini'
    
    
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
        RAIN_FORCE_AIRFLOW_ENABLED = false,

        -- All external accelerations enter the GPU in SI m/s^2 and
        -- share this compact surface-force conversion.
        -- This preserves the previously validated gravity calibration.
        RAIN_PHYSICS_ACCEL_SCALE = 0.03567788,

        -- Air model constants (SI).
        RAIN_AIR_DENSITY = 1.20,
        RAIN_AIR_DRAG_COEFF = 0.47,

        -- Drop dynamics
        -- Acceleration after surface adhesion is exceeded.
        RAIN_FLOW_ACCELERATION = 0.020,

        -- Post-adhesion flow intensity multiplier. Default 1.0 preserves
        -- the current physical calibration; later tuning must still respect
        -- the absolute physical max-speed clamp.
        RAIN_FLOW_SPEED_SCALE = 1.0,

        -- Linear air/viscous drag coefficient.
        RAIN_FLOW_DRAG = 7.0,

        -- Adhesion threshold range. A drop remains attached while the
        -- effective tangential force is below its own threshold.
        RAIN_ADHESION_MIN = 0.65,
        RAIN_ADHESION_MAX = 2.20,

        ------------------------------------------------------------
        -- v0.6.1 RainFX persistent GPU state validation
        ------------------------------------------------------------

        -- Number of persistent droplet state texels.
        -- One texel represents one persistent droplet.
        RAIN_GPU_STATE_COUNT = 256,

        -- Persistent state:
        -- 0 = disabled
        -- 1 = initialize only
        -- 3 = canonical persistent RainFX physics
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
        RAIN_GPU_STATE_BOUNDARY_MARGIN = 0.005,
        RAIN_GPU_STATE_RESPAWN_GAP_MIN = 0.15,
        RAIN_GPU_STATE_RESPAWN_GAP_MAX = 0.75,

        -- Stage 7C: physical-reference size-dependent surface max speed.
        -- 1 mm diameter occupies exactly 0.0029296875 visor UV in the
        -- calibrated Debug 50 mesh measurement.
        RAIN_GPU_STATE_PHYSICAL_DIAMETER_UV_PER_MM = 0.0029296875,
        RAIN_GPU_STATE_PHYSICAL_MAX_SPEED_1MM = 0.016,
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
    '[3] Canonical persistent RainFX physics',
    '[4] Canonical persistent physics + 3x3 physical-size diagnostic',
    '[6] Canonical persistent physics + boundary lifecycle',
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
        gRainStateRespawnGapMin = 0.15,
        gRainStateRespawnGapMax = 0.75,
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

        /*
            Final physical droplet model.
            Every persistent texel uses a deterministic hash-selected
            diameter in the measured 0.5–6.0 mm domain.
            Future rain profiles may replace only this distribution.
        */
        float rainStatePhysicalDiameterMM(float index)
        {
            return lerp(
                0.5,
                6.0,
                rainStateHash(index + 101.0)
            );
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
            Deterministic rejection sampling for initial/respawn positions.
            This runs only when creating/recreating a droplet, not for every
            live state every frame.
        */
        float2 rainStateFindValidPosition(
            float stateIndex,
            float cycleSeed
        )
        {
            for (int attempt = 0; attempt < 24; ++attempt)
            {
                float seed =
                    stateIndex
                    + cycleSeed * 17.123
                    + (float)attempt * 37.719
                    + 911.731;

                float2 candidate = float2(
                    rainStateHash(seed + 13.0),
                    -rainStateHash(seed + 47.0)
                );

                if (rainStateBoundaryMask(candidate) >= 0.5)
                {
                    return candidate;
                }
            }

            /*
                Safe deterministic fallback. A malformed/empty mask should
                not create undefined state; normal lifecycle validation will
                still expose such a mask immediately.
            */
            return float2(0.5, -0.5);
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
            float radius
        )
        {
            float3 forceWorld = float3(0.0, 0.0, 0.0);

            if (fmod(floor(gRainForceMask), 2.0) >= 0.5)
                forceWorld +=
                    float3(0.0, -gRainStateGravity, 0.0)
                    * gRainPhysicsAccelScale;

            if (fmod(floor(gRainForceMask / 2.0), 2.0) >= 0.5)
                forceWorld +=
                    gRainAcceleration
                    * gRainPhysicsAccelScale;

            if (fmod(floor(gRainForceMask / 4.0), 2.0) >= 0.5)
                forceWorld +=
                    rainStateAirflowAccelerationWorld(
                        normalWorld,
                        radius
                    )
                    * gRainPhysicsAccelScale;

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

            float3 forceWorld =
                rainStateExternalForceWorld(
                    normalWorld,
                    radius
                );

            float2 tangentForce =
                rainStateProjectForce(
                    forceWorld,
                    normalWorld
                );

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
            float dt
        )
        {
            /*
                Keep the existing numerical behavior:
                below adhesion the droplet receives the stronger
                attachment damping, then the normal flow drag is applied.
            */
            if (forceMagnitude <= adhesion)
            {
                velocity *=
                    exp(
                        -gRainStateFlowDrag
                        * 2.0
                        * dt
                    );
            }

            velocity *=
                exp(
                    -max(
                        gRainStateFlowDrag,
                        0.0
                    )
                    * dt
                );

            return velocity;
        }

        float2 rainStateClampSpeed(
            float2 velocity,
            float radius
        )
        {
            float speed =
                length(velocity);

            float maxSpeed =
                rainStateMaxSpeedValue(radius);

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
            float respawnCycle
        )
        {
            return rainStateFindValidPosition(
                stateIndex,
                respawnCycle
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

            velocity +=
                rainStateFlowAcceleration(
                    tangentForce,
                    forceMagnitude,
                    adhesion,
                    dt
                );

            velocity =
                rainStateApplyDrag(
                    velocity,
                    forceMagnitude,
                    adhesion,
                    dt
                );

            velocity =
                rainStateClampSpeed(
                    velocity,
                    radius
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
                        0.0
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
                Lifecycle flags in Meta.A:
                    0 = dead / waiting for respawn gap
                    1 = alive
                    2 = respawn pending; consume on this state pass

                Meta.B remains the accumulated age/waiting timer.
                The respawn cycle is derived deterministically from stateIndex.
            */
            if (gRainStateLifecycle > 0.5)
            {
                if (meta.a > 1.5)
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
                            meta.b
                        );

                    return float4(
                        respawn,
                        0.0,
                        0.0
                    );
                }

                if (meta.a < 0.5)
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
        gRainStateRespawnGapMin = 0.15,
        gRainStateRespawnGapMax = 0.75,
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
            This pass uses exactly the same deterministic 0.5–6.0 mm
            distribution as the persistent state initialization/update pass.
            Future rain profiles may replace only this distribution.
        */
        float rainStatePhysicalDiameterMM(float index)
        {
            return lerp(
                0.5,
                6.0,
                rainStateHash(index + 101.0)
            );
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


                float diameterMM = rainStatePhysicalDiameterMM(index);
                float radius = diameterMM * 0.00146484375;
                float mass = rainStatePhysicalMassProfile(diameterMM);

                return float4(radius, mass, 0.0, 1.0);
            }

            float4 meta = txRainStateMeta.SampleLevel(
                samPointRainMeta, suv, 0.0
            );

            float dt = max(gRainStateDeltaTime, 0.0);

            if (gRainStateLifecycle > 0.5)
            {
                if (meta.a > 1.5)
                {
                    /*
                        Consume the pending respawn. Meta is float4, so there
                        is no Meta.C channel: use the accumulated waiting-age
                        value as the respawn seed before resetting age.
                    */
                    float respawnSeed = meta.b;

                    meta.a = 1.0;
                    meta.b = 0.0;

                    float diameterMM =
                        rainStatePhysicalDiameterMM(
                            index + respawnSeed * 17.123
                        );

                    meta.r = diameterMM * 0.00146484375;
                    meta.g = rainStatePhysicalMassProfile(diameterMM);

                    return meta;
                }

                if (meta.a < 0.5)
                {
                    meta.b += dt;

                    float gap01 = rainStateHash(
                        index
                        + 701.0
                    );

                    float respawnGap = lerp(
                        gRainStateRespawnGapMin,
                        gRainStateRespawnGapMax,
                        gap01
                    );

                    if (meta.b >= respawnGap)
                    {
                        /*
                            Preserve the accumulated wait value for the
                            pending-respawn seed. It is reset only after the
                            state shader consumes the respawn.
                        */
                        meta.a = 2.0;
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
                    meta.a = 0.0;
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


    ac.log(
        appNameDebug
        .. ' cfg.GENERAL.ENABLE = '
        .. tostring(cfg.GENERAL.ENABLE)
    )

end


local function saveProfiles()
    local p1 = cfg.PROFILE_1
    local p2 = cfg.PROFILE_2

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
        p2.HIDE_DRIVER_HELMET
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
    local MATERIAL_EDITORS = {


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
            or cfg.RUNTIME.RAIN_GPU_STATE_COUNT
        )
    )
end

local function initializeRainGPUState()
    if rainStateA and rainStateB and rainStateMetaA and rainStateMetaB then
        return true
    end

    local count = rainStateCountForMode()

    rainStateA = ui.ExtraCanvas(
        vec2(count, 1),
        1,
        render.TextureFormat.R32G32B32A32.Float
    ):setName('RainFX State A')

    rainStateB = ui.ExtraCanvas(
        vec2(count, 1),
        1,
        render.TextureFormat.R32G32B32A32.Float
    ):setName('RainFX State B')

    rainStateMetaA = ui.ExtraCanvas(
        vec2(count, 1),
        1,
        render.TextureFormat.R32G32B32A32.Float
    ):setName('RainFX State Meta A')

    rainStateMetaB = ui.ExtraCanvas(
        vec2(count, 1),
        1,
        render.TextureFormat.R32G32B32A32.Float
    ):setName('RainFX State Meta B')

    if not rainStateA or not rainStateB or not rainStateMetaA or not rainStateMetaB then
        ac.warn(appNameDebug .. ' Rain GPU state: ExtraCanvas allocation failed')
        rainStateA = nil
        rainStateB = nil
        rainStateMetaA = nil
        rainStateMetaB = nil
        return false
    end

    local physicalTest =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE == 10 and 1.0 or 0.0

    local physicalGridTest =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE == 4 and 1.0 or 0.0

    local lifecycle =
        (
            cfg.RUNTIME.RAIN_GPU_STATE_MODE == 6
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

    rainStateUpdateParams.textures.txRainState = false
    rainStateUpdateParams.textures.txRainStateMeta = false
    rainStateUpdateParams.textures.txRainSurfaceNormal = false
    rainStateUpdateParams.textures.txRainBoundaryMask = textureRainBoundaryMask

    rainStateMetaUpdateParams.textures.txRainStateMeta = false
    rainStateMetaUpdateParams.textures.txRainState = false
    rainStateMetaUpdateParams.textures.txRainBoundaryMask = textureRainBoundaryMask

    rainStateA:updateWithShader(rainStateUpdateParams)
    rainStateB:updateWithShader(rainStateUpdateParams)
    rainStateMetaA:updateWithShader(rainStateMetaUpdateParams)
    rainStateMetaB:updateWithShader(rainStateMetaUpdateParams)

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
            cfg.RUNTIME.RAIN_GPU_STATE_MODE == 6
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
            cfg.RUNTIME.RAIN_GPU_STATE_MODE == 6
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
-- Creates one persistent mesh containing 256 small quads.
-- No GPU state readback and no alterVertices() are used yet.
-- The only purpose of this stage is to validate the public
-- createMesh() -> render.mesh() path and establish a renderer
-- performance baseline against the fullscreen 256-drop search.
--------------------------------------------------------

local RAIN_DYNAMIC_MESH_TEST_HLSL = [[
#include "rainDynamicMeshTest.hlsl"
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

            local z =
                cfg.RUNTIME.RAIN_DYNAMIC_MESH_TEST_Z

            rainDynamicMeshTestVertices:set(
                vertexIndex,
                ac.MeshVertex.new(
                    vec3(x0, y0, z),
                    vec3(0, 0, 1),
                    vec2(0, 0)
                )
            )
            vertexIndex = vertexIndex + 1

            rainDynamicMeshTestVertices:set(
                vertexIndex,
                ac.MeshVertex.new(
                    vec3(x1, y0, z),
                    vec3(0, 0, 1),
                    vec2(1, 0)
                )
            )
            vertexIndex = vertexIndex + 1

            rainDynamicMeshTestVertices:set(
                vertexIndex,
                ac.MeshVertex.new(
                    vec3(x1, y1, z),
                    vec3(0, 0, 1),
                    vec2(1, 1)
                )
            )
            vertexIndex = vertexIndex + 1

            rainDynamicMeshTestVertices:set(
                vertexIndex,
                ac.MeshVertex.new(
                    vec3(x0, y1, z),
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

    local root = ac.emptySceneReference()

    if not root then
        ac.warn(
            appNameDebug
            .. ' Dynamic mesh test: failed to create root SceneReference'
        )
        return false
    end

    rainDynamicMeshTest =
        root:createMesh(
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
-- 3.6.0 TESTING: Custom Shader Render - RainDrops
--------------------------------------------------------
render.on('main.track.transparent', function()
    -- ac.log('[RealVisor] ENTER main.track.transparent')
    
    
    if not cfg.RUNTIME.RAIN_ENABLED  then
        return
    end


    local rainShader = nil


    for i, shader in ipairs(shaders) do

        if shader.ID == 'RAINFXVISOR' 
            and shader.LOADED then

                rainShader = shader
            break

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

    updateRainGPUState(sim)

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
            transform = startingTransform,
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

    for idx, shader in ipairs(shaders) do
        
        local file, err = io.open(shader.PATH, 'r')

        if not file then

            ac.log(
                appNameDebug
                .. ' HLSL load failed: '
                .. shader.PATH
                .. ' not exists'
            )

            shader.LOADED = false


        else

            ac.log(
                appNameDebug
                .. 'SHADER LOADED: '
                .. shader.ID
            )
            
            shader.HLSL = file:read('*a')
            file:close()

            shader.LOADED = true

            shaderInitialized = true

            ac.log(
                appNameDebug
                .. ' HLSL bytes=' .. tostring(#shader.HLSL)
                .. ' path=' .. shader.PATH
            )

        end
    end
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

                foundEditor.targetMesh:setVisible(foundEditor.visible)
            end

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

    --------------------------------------------------------
    -- Phase A validation
    --------------------------------------------------------
    ui.separator()
    ui.text('Canonical force-source isolation')
    ui.text('Use STATE_MODE = 3. Test one source at a time, then enable combinations:')
    ui.text('1) Gravity only -> 2) Inertia only -> 3) Gravity + Inertia -> 4) Airflow')
    ui.text('Airflow is intentionally OFF by default until its incidence/mass response is verified.')

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