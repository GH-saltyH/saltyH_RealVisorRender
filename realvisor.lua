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
    
    local textureRaindrops = appFolder .. '/texture/drops.dds'
    local textureRainSurfaceNormal = appFolder .. '/texture/GLASS_EXT_RAINFX_surfaceNormal_objectSpace_2K.dds'
    local testtextureRainSurfaceNormal = appFolder .. '/texture/test_objectSpace.dds'

    
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

        -- Master amount
        RAIN_AMOUNT = 250.0,

        -- Base Rain Speed
        RAIN_SPEED_BASE = 0.0018,

        -- Vehicle speed influence
        RAIN_SPEED_MIN = 0.0,
        RAIN_SPEED_MAX = 10.0,

        -- Visual density
        RAIN_DENSITY = 1.0,

        -- Drop dynamics
        -- Acceleration after surface adhesion is exceeded.
        RAIN_FLOW_ACCELERATION = 0.020,

        -- Linear air/viscous drag coefficient.
        RAIN_FLOW_DRAG = 7.0,

        -- Maximum procedural surface speed in UV-space units per second.
        RAIN_FLOW_MAX_SPEED = 0.035,

        -- Quadratic air-drag test coefficient.
        -- Debug 31 only: converts relative air speed squared into
        -- the same compact force space used by RainFX.
        RAIN_AIR_DRAG_SCALE = 0.000050,

        -- World-space acceleration influence.
        -- RainFX keeps vehicle acceleration in WORLD space and projects
        -- it onto each droplet's local surface tangent frame in HLSL.
        -- Use one scalar so response does not depend on the car's
        -- orientation relative to the global world axes.
        RAIN_ACCEL_GAIN = 0.000024,

        -- Legacy per-camera-axis gains retained for config compatibility.
        -- They are no longer used by RainFX physics.
        RAIN_ACCEL_GAIN_X = 0.00000505,
        RAIN_ACCEL_GAIN_Y = 0.000001,
        RAIN_ACCEL_GAIN_Z = 0.000024,

        -- Acceleration response / damping
        RAIN_FLOW_RESPONSE = 5.0,

        -- Maximum procedural travel distance in grid-space units.
        -- The shader uses this guard to keep moving drops inside its
        -- current-cell + 8-neighbor search envelope.
        RAIN_FLOW_MAX = 0.65,

        -- Rain surface / adhesion model
        -- UV center is intentionally explicit so the surface model
        -- can later be remapped without rewriting the physics.
        RAIN_SURFACE_CENTER_X = 0.5,
        RAIN_SURFACE_CENTER_Y = 0.5,

        -- Approximate visor curvature in UV space.
        -- X controls lateral curvature; Y controls upper/lower curvature.
        RAIN_SURFACE_CURVATURE_X = 0.35,
        RAIN_SURFACE_CURVATURE_Y = 0.12,

        -- Global visor downward slope. This gives gravity a tangential
        -- component even at the UV center.
        RAIN_SURFACE_SLOPE_Y = 0.12,

        -- Adhesion threshold range. A drop remains attached while the
        -- effective tangential force is below its own threshold.
        RAIN_ADHESION_MIN = 0.65,
        RAIN_ADHESION_MAX = 2.20,

        -- Physical gravity used by the surface model.
        RAIN_GRAVITY = 0.35,

        -- Converts physical acceleration units into the compact
        -- surface-force space used by the procedural visor model.
        RAIN_FORCE_SCALE = 100000.0,

        -- Procedural lifetime of one drop before it respawns.
        RAIN_DROP_LIFETIME_MIN = 4.0,
        RAIN_DROP_LIFETIME_MAX = 10.0,
        RAIN_DROP_RESPAWN_GAP_MIN = 0.15,
        RAIN_DROP_RESPAWN_GAP_MAX = 0.75,

        ------------------------------------------------------------
        -- v0.6.1 RainFX persistent GPU state validation
        ------------------------------------------------------------

        -- Number of persistent droplet state texels.
        -- One texel represents one persistent droplet.
        RAIN_GPU_STATE_COUNT = 256,

        -- Persistent state:
        -- 0 = disabled
        -- 1 = initialize only
        -- 2 = synthetic force validation
        -- 3 = persistent RainFX physics
        -- 4 = persistent physics with the measured 3x3 L/M/S test grid
        RAIN_GPU_STATE_MODE = 4,

        RAIN_GPU_STATE_UV_SCALE = 18.0,
        RAIN_GPU_STATE_MESH_V_MIN = -0.713,
        RAIN_GPU_STATE_MESH_V_MAX = -0.302,
        
        RAIN_GPU_STATE_MESH_U_MIN = 0.3,
        RAIN_GPU_STATE_MESH_U_MAX = 0.7,

        -- Synthetic force used only by the Stage 1 state validation.
        -- This is deliberately independent from the final RainFX force model.
        RAIN_GPU_STATE_TEST_FORCE_X = 0.035,
        RAIN_GPU_STATE_TEST_FORCE_Y = 0.010,

        RAIN_GPU_STATE_DRAG = 0.35,
        RAIN_GPU_STATE_MAX_SPEED = 0.12,

        -- Debug 25: amplify the measured accumulated displacement only for
        -- visualization. This does not change physics or state integration.
        RAIN_GPU_STATE_DEBUG_DISPLACEMENT_SCALE = 50.0,
        RAIN_GPU_STATE_DEBUG_SAMPLE_INTERVAL = 0.25,
        RAIN_GPU_STATE_DEBUG_VELOCITY_SCALE = 50.0,

        -- Debug
        -- 0 = normal rain
        -- 1 = projected force magnitude / components
        -- 2 = input acceleration
        -- 3 = solid render-path test
        -- 4 = mesh UV coverage
        -- 5 = local surface normal (object-space RGB)
        -- 6 = local projected movement direction / strength (world-space physics)
        -- 18 = persistent GPU state position / velocity diagnostic
        RAIN_DEBUG = 36,

        RAIN_DEBUG_CENTER_X = 0.5,
        RAIN_DEBUG_CENTER_Y = 0.5,

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
local rainPreviousVelocity = nil
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
local rainStateDebugOrigin = nil
local rainStateDebugCapturePending = false
local rainStateDebugSampleTimer = 0.0
local rainStateReadIsA = true
local rainStateInitialized = false
local rainStateLastFrame = -1

local rainStateUpdateParams = {
    defines = { RAIN_GPU_STATE_PASS = true },

    textures = {
        txRainState = false,
        txRainStateMeta = false,
        txRainSurfaceNormal = false,
    },

    values = {
        gRainStateDeltaTime = 0.0,
        gRainStateCount = 256.0,
        gRainStateForce = vec2(0.0, 0.0),
        gRainAcceleration = vec3(0.0, 0.0, 0.0),
        gRainAirVelocityWorld = vec3(0.0, 0.0, 0.0),
        gRainAirDragScale = 0.000050,
        gRainStateDrag = 0.35,
        gRainStateMaxSpeed = 0.12,
        gRainStateFlowAcceleration = 0.020,
        gRainStateUVScale = 18.0,
        gRainStateGravity = 0.35,
        gRainStateForceScale = 100000.0,
        gRainStateAdhesionMin = 0.65,
        gRainStateAdhesionMax = 2.20,
        gRainStateMeshVMin = -0.579,
        gRainStateMeshVMax = -0.362,
        gRainObjectToWorld = mat4x4.identity(),
        gRainStateInit = 0.0,
        gRainStatePhysics = 0.0,
        gRainStateTestGrid = 0.0,
        -- Keep disabled for Debug 36 baseline; enable after persistent airflow validation.
        gRainStateUseAirDrag = 0.0,
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

        float3 rainStateNormalWorld(float2 p) {
            float2 uv = float2(
                p.x,
                lerp(gRainStateMeshVMin, gRainStateMeshVMax, p.y)
            );

            float3 n = txRainSurfaceNormal.SampleLevel(
                samLinearRain, uv, 0.0
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
            float3 v = normalize(cross(normalObject, u));

            float3 uWorld = normalize(mul(u, (float3x3)gRainObjectToWorld));
            float3 vWorld = normalize(mul(v, (float3x3)gRainObjectToWorld));

            return float2(-dot(forceWorld, uWorld), dot(forceWorld, vWorld));
        }

        /*
            Consolidated external force entry point.

            Gravity and vehicle acceleration are always part of the persistent
            physics baseline. Airflow remains opt-in until its direction and
            magnitude are revalidated against the persistent state.
        */
        float3 rainStateExternalForceWorld()
        {
            float3 force =
                float3(0.0, -gRainStateGravity, 0.0)
                + gRainAcceleration * gRainStateForceScale;

            if (gRainStateUseAirDrag > 0.5)
            {
                float3 airflow = gRainAirVelocityWorld;
                float airSpeed = length(airflow);

                force +=
                    airflow
                    * airSpeed
                    * max(gRainAirDragScale, 0.0);
            }

            return force;
        }

        float4 main(PS_IN pin) {
            float count = max(gRainStateCount, 1.0);
            float index = min(floor(pin.Tex.x * count), count - 1.0);
            float2 suv = float2((index + 0.5) / count, 0.5);

            if (gRainStateInit > 0.5) {
                if (gRainStateTestGrid > 0.5 && index < 9.0) {
                    const float measuredX[3] = {
                        0.682, 0.491, 0.300
                    };

                    const float measuredY[3] = {
                        -0.410, -0.501, -0.591
                    };

                    int i = (int)index;
                    int ix = i % 3;
                    int iy = i / 3;

                    float y01 = saturate(
                        (measuredY[iy] - gRainStateMeshVMin)
                        / max(
                            gRainStateMeshVMax - gRainStateMeshVMin, 
                            0.000001
                        )
                    );

                    return float4(measuredX[ix], y01, 0.0, 0.0);
                }

                float2 p = float2(
                    rainStateHash(index + 11.0),
                    rainStateHash(index + 47.0)
                );
                return float4(p, 0.0, 0.0);
            }

            float4 state = txRainState.SampleLevel(samPointRain, suv, 0.0);
            float4 meta = txRainStateMeta.SampleLevel(samPointRain, suv, 0.0);

            float2 p = state.rg;
            float2 v = state.ba;
            float radius = meta.r;
            float mass = max(meta.g, 1.0);
            float dt = max(gRainStateDeltaTime, 0.0);

            if (gRainStatePhysics > 0.5) {
                float3 force =
                    rainStateExternalForceWorld();

                float3 n = rainStateNormalWorld(p);
                float2 tf = rainStateProjectForce(force, n);
                float f = length(tf);

                float radius01 = saturate(
                    (radius - 0.032) / (0.115 - 0.032)
                );

                float adhesionBase = lerp(
                    gRainStateAdhesionMin,
                    gRainStateAdhesionMax,
                    rainStateHash(index + 211.0)
                );

                float adhesion = adhesionBase / sqrt(mass);
                float excess = max(f - adhesion, 0.0);

                if (excess > 0.000001) {
                    float2 dir = tf / f;
                    float acceleration =
                        excess
                        * gRainStateFlowAcceleration
                        / max(gRainStateUVScale, 0.000001);

                    v += dir * acceleration * dt;
                } else {
                    v *= exp(-gRainStateDrag * 2.0 * dt);
                }

                v *= exp(-max(gRainStateDrag, 0.0) * dt);

                float speed = length(v);
                if (speed > gRainStateMaxSpeed) {
                    v = v / max(speed, 0.000001) * gRainStateMaxSpeed;
                }

                p = frac(p + v * dt);
            } else {
                v += gRainStateForce * dt;
                v *= exp(-max(gRainStateDrag, 0.0) * dt);

                float speed = length(v);
                if (speed > gRainStateMaxSpeed) {
                    v = v / max(speed, 0.000001) * gRainStateMaxSpeed;
                }

                p = frac(p + v * dt);
            }

            return float4(p, v);
        }
    ]],
}

local rainStateDebugOriginUpdateParams = {
    textures = {
        txRainState = false,
    },

    values = {
        gRainStateCount = 256.0,
    },

    shader = [[
        SamplerState samPointRainOrigin {
            Filter = MIN_MAG_MIP_POINT;
            AddressU = CLAMP;
            AddressV = CLAMP;
            AddressW = CLAMP;
        };

        float4 main(PS_IN pin) {
            float count = max(gRainStateCount, 1.0);
            float index = min(floor(pin.Tex.x * count), count - 1.0);
            float2 suv = float2((index + 0.5) / count, 0.5);
            float2 position = txRainState.SampleLevel(
                samPointRainOrigin, suv, 0.0
            ).rg;
            return float4(position, 0.0, 1.0);
        }
    ]],
}

local rainStateMetaUpdateParams = {
    textures = { txRainStateMeta = false },
    values = {
        gRainStateDeltaTime = 0.0,
        gRainStateCount = 256.0,
        gRainStateInit = 0.0,
        gRainStateTestGrid = 0.0,
    },

    shader = [[
        SamplerState samPointRainMeta {
            Filter = MIN_MAG_MIP_POINT;
            AddressU = CLAMP;
            AddressV = CLAMP;
            AddressW = CLAMP;
        };

        float rainStateHash(float n) {
            return frac(sin(n * 127.1 + 311.7) * 43758.5453);
        }

        float4 main(PS_IN pin) {
            float count = max(gRainStateCount, 1.0);
            float index = min(floor(pin.Tex.x * count), count - 1.0);
            float2 suv = float2((index + 0.5) / count, 0.5);

            if (gRainStateInit > 0.5) {
                if (gRainStateTestGrid > 0.5 && index < 9.0) {
                    const float radiusValues[9] = {
                        0.115, 0.0735, 0.032,
                        0.0735, 0.032, 0.115,
                        0.032, 0.115, 0.0735
                    };
                    float radius = radiusValues[(int)index];
                    float radius01 = saturate((radius - 0.032) / (0.115 - 0.032));
                    float mass = lerp(1.0, 9.0, radius01 * radius01);
                    return float4(radius, mass, 0.0, 1.0);
                }

                float r01 = rainStateHash(index + 101.0);
                float radius = lerp(0.032, 0.115, r01);
                float mass = lerp(1.0, 9.0, r01 * r01);
                return float4(radius, mass, 0.0, 1.0);
            }

            float4 meta = txRainStateMeta.SampleLevel(
                samPointRainMeta, suv, 0.0
            );
            meta.b += max(gRainStateDeltaTime, 0.0);
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

local function initializeRainGPUState()
    if rainStateA and rainStateB then
        return true
    end

    local count =
        math.max(
            1,
            math.floor(
                cfg.RUNTIME.RAIN_GPU_STATE_MODE == 4
                and 9
                or cfg.RUNTIME.RAIN_GPU_STATE_COUNT
            )
        )

    rainStateA =
        ui.ExtraCanvas(
            vec2(count, 1),
            1,
            render.TextureFormat.R32G32B32A32.Float
        ):setName('RainFX State A')

    rainStateB =
        ui.ExtraCanvas(
            vec2(count, 1),
            1,
            render.TextureFormat.R32G32B32A32.Float
        ):setName('RainFX State B')

    rainStateMetaA =
        ui.ExtraCanvas(
            vec2(count, 1),
            1,
            render.TextureFormat.R32G32B32A32.Float
        ):setName('RainFX State Meta A')

    rainStateMetaB =
        ui.ExtraCanvas(
            vec2(count, 1),
            1,
            render.TextureFormat.R32G32B32A32.Float
        ):setName('RainFX State Meta B')

    rainStateDebugOrigin =
        ui.ExtraCanvas(
            vec2(count, 1),
            1,
            render.TextureFormat.R32G32B32A32.Float
        ):setName('RainFX Debug Origin')

    if not rainStateA or not rainStateB or not rainStateMetaA or not rainStateMetaB or not rainStateDebugOrigin then
        ac.warn(
            appNameDebug
            .. ' Rain GPU state: ExtraCanvas allocation failed'
        )

        rainStateA = nil
        rainStateB = nil
        rainStateMetaA = nil
        rainStateMetaB = nil
        rainStateDebugOrigin = nil
        return false
    end

    rainStateUpdateParams.values.gRainStateCount = count
    rainStateUpdateParams.values.gRainStateInit = 1.0
    rainStateUpdateParams.values.gRainStateTestGrid =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE == 4
        and 1.0
        or 0.0
    rainStateUpdateParams.values.gRainStatePhysics = 0.0
    rainStateUpdateParams.values.gRainStateMeshVMin = cfg.RUNTIME.RAIN_GPU_STATE_MESH_V_MIN
    rainStateUpdateParams.values.gRainStateMeshVMax = cfg.RUNTIME.RAIN_GPU_STATE_MESH_V_MAX
    rainStateUpdateParams.textures.txRainState = false
    rainStateUpdateParams.textures.txRainStateMeta = false
    rainStateUpdateParams.textures.txRainSurfaceNormal = false

    rainStateMetaUpdateParams.values.gRainStateCount = count
    rainStateMetaUpdateParams.values.gRainStateInit = 1.0
    rainStateMetaUpdateParams.values.gRainStateTestGrid =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE == 4
        and 1.0
        or 0.0
    rainStateMetaUpdateParams.textures.txRainStateMeta = false

    rainStateA:updateWithShader(rainStateUpdateParams)
    rainStateB:updateWithShader(rainStateUpdateParams)
    rainStateMetaA:updateWithShader(rainStateMetaUpdateParams)
    rainStateMetaB:updateWithShader(rainStateMetaUpdateParams)

    rainStateDebugOriginUpdateParams.values.gRainStateCount = count
    rainStateDebugOriginUpdateParams.textures.txRainState = rainStateA
    rainStateDebugOrigin:updateWithShader(rainStateDebugOriginUpdateParams)

    rainStateUpdateParams.values.gRainStateInit = 0.0

    rainStateReadIsA = true
    rainStateInitialized = true
    rainStateDebugSampleTimer = 0.0
    rainStateLastFrame = -1

    ac.log(
        appNameDebug
        .. ' Rain GPU state initialized: '
        .. tostring(count)
        .. ' texels'
    )

    return true
end


local function updateRainGPUState(sim)
    if cfg.RUNTIME.RAIN_GPU_STATE_MODE <= 0 then
        return
    end

    if not initializeRainGPUState() then
        return
    end

    if not rainStateInitialized then
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

    local physicsMode =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE >= 3

    local transform =
        rainTargetMesh
        and rainTargetMesh:getWorldTransformationRaw():clone()
        or mat4x4.identity()

    rainStateUpdateParams.values.gRainStateDeltaTime =
        math.min(dt, 0.05)

    rainStateUpdateParams.values.gRainStateCount =
        math.max(
            1,
            math.floor(
                cfg.RUNTIME.RAIN_GPU_STATE_MODE == 4
                and 9
                or cfg.RUNTIME.RAIN_GPU_STATE_COUNT
            )
        )

    rainStateUpdateParams.values.gRainStateForce:set(
        cfg.RUNTIME.RAIN_GPU_STATE_TEST_FORCE_X,
        cfg.RUNTIME.RAIN_GPU_STATE_TEST_FORCE_Y
    )

    rainStateUpdateParams.values.gRainStateDrag =
        physicsMode
        and cfg.RUNTIME.RAIN_FLOW_DRAG
        or cfg.RUNTIME.RAIN_GPU_STATE_DRAG

    rainStateUpdateParams.values.gRainStateMaxSpeed =
        physicsMode
        and (
            cfg.RUNTIME.RAIN_FLOW_MAX_SPEED
            / math.max(cfg.RUNTIME.RAIN_GPU_STATE_UV_SCALE, 0.000001)
        )
        or cfg.RUNTIME.RAIN_GPU_STATE_MAX_SPEED

    rainStateUpdateParams.values.gRainAcceleration =
        rainAccelerationCurrent

    rainStateUpdateParams.values.gRainStateFlowAcceleration =
        cfg.RUNTIME.RAIN_FLOW_ACCELERATION

    rainStateUpdateParams.values.gRainStateUVScale =
        cfg.RUNTIME.RAIN_GPU_STATE_UV_SCALE

    rainStateUpdateParams.values.gRainStateGravity =
        cfg.RUNTIME.RAIN_GRAVITY

    rainStateUpdateParams.values.gRainStateForceScale =
        cfg.RUNTIME.RAIN_FORCE_SCALE

    rainStateUpdateParams.values.gRainStateAdhesionMin =
        cfg.RUNTIME.RAIN_ADHESION_MIN

    rainStateUpdateParams.values.gRainStateAdhesionMax =
        cfg.RUNTIME.RAIN_ADHESION_MAX

    rainStateUpdateParams.values.gRainStateMeshVMin =
        cfg.RUNTIME.RAIN_GPU_STATE_MESH_V_MIN

    rainStateUpdateParams.values.gRainStateMeshVMax =
        cfg.RUNTIME.RAIN_GPU_STATE_MESH_V_MAX

    rainStateUpdateParams.values.gRainObjectToWorld =
        transform

    rainStateUpdateParams.values.gRainStatePhysics =
        physicsMode and 1.0 or 0.0

    rainStateUpdateParams.values.gRainStateTestGrid =
        cfg.RUNTIME.RAIN_GPU_STATE_MODE == 4
        and 1.0
        or 0.0

    rainStateMetaUpdateParams.values.gRainStateCount =
        math.max(
            1,
            math.floor(
                cfg.RUNTIME.RAIN_GPU_STATE_MODE == 4
                and 9
                or cfg.RUNTIME.RAIN_GPU_STATE_COUNT
            )
        )

    rainStateMetaUpdateParams.values.gRainStateDeltaTime =
        math.min(dt, 0.05)

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
    rainStateMetaUpdateParams.textures.txRainStateMeta = readMeta

    writeState:updateWithShader(rainStateUpdateParams)
    writeMeta:updateWithShader(rainStateMetaUpdateParams)

    rainStateReadIsA = not rainStateReadIsA

    if rainStateDebugCapturePending and rainStateDebugOrigin then
        local currentState =
            rainStateReadIsA and rainStateA or rainStateB

        rainStateDebugOriginUpdateParams.values.gRainStateCount =
            math.max(
                1,
                math.floor(
                    cfg.RUNTIME.RAIN_GPU_STATE_MODE == 4
                    and 9
                    or cfg.RUNTIME.RAIN_GPU_STATE_COUNT
                )
            )

        rainStateDebugOriginUpdateParams.textures.txRainState =
            currentState

        rainStateDebugOrigin:updateWithShader(
            rainStateDebugOriginUpdateParams
        )

        rainStateDebugCapturePending = false
        rainStateDebugSampleTimer = 0.0

        ac.log(
            appNameDebug
            .. ' Rain Debug ' .. tostring(cfg.RUNTIME.RAIN_DEBUG)
            .. ': displacement sample captured'
        )
    end

    if cfg.RUNTIME.RAIN_DEBUG == 26 and rainStateDebugOrigin then
        rainStateDebugSampleTimer =
            rainStateDebugSampleTimer + math.min(dt, 0.05)

        local sampleInterval =
            math.max(
                cfg.RUNTIME.RAIN_GPU_STATE_DEBUG_SAMPLE_INTERVAL,
                0.01
            )

        if rainStateDebugSampleTimer >= sampleInterval then
            local currentState =
                rainStateReadIsA and rainStateA or rainStateB

            rainStateDebugOriginUpdateParams.values.gRainStateCount =
                math.max(1, math.floor(cfg.RUNTIME.RAIN_GPU_STATE_COUNT))

            rainStateDebugOriginUpdateParams.textures.txRainState =
                currentState

            rainStateDebugOrigin:updateWithShader(
                rainStateDebugOriginUpdateParams
            )

            rainStateDebugSampleTimer = 0.0
        end
    end
end

--------------------------------------------------------
-- 3.6.0 TESTING: Custom Shader Render - RainDrops
--------------------------------------------------------
local UV_DEBUG_SHADER = [[

float4 main(PS_IN pin)
{
    return float4(
        pin.Tex.x,
        pin.Tex.y,
        0.0,
        1.0
    );
}

]]

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
        if cfg.RUNTIME.RAIN_DEBUG == 25
            or cfg.RUNTIME.RAIN_DEBUG == 26
            or cfg.RUNTIME.RAIN_DEBUG == 36 then
            rainStateDebugCapturePending = true
        end

        ac.log(
            appNameDebug
            .. ' Rain render debug=' .. tostring(cfg.RUNTIME.RAIN_DEBUG)
            .. ' mesh=' .. tostring(rainTargetMesh ~= nil)
            .. ' meshCount=' .. tostring(rainTargetMesh and #rainTargetMesh or 0)
            .. ' shaderBytes=' .. tostring(rainShader.HLSL and #rainShader.HLSL or 0)
        )
    end


    if not textureRaindrops then
        return
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
    -- Speed
    --------------------------------------------------------
    
    local speed =
        car.velocity:length()
    
    
    local speed01 =
        math.clamp(
            speed / cfg.RUNTIME.RAIN_SPEED_MAX,
            0.0,
            1.0
        )
    
    local acceleration = 
        car.acceleration

    
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
            
            txRainDrops =
                textureRaindrops,

            txRainSurfaceNormal =
                textureRainSurfaceNormal,

            txRainState =
                rainStateReadIsA
                and rainStateA
                or rainStateB,

            txRainStateMeta =
                rainStateReadIsA
                and rainStateMetaA
                or rainStateMetaB,

            txRainStateOrigin =
                rainStateDebugOrigin,

        },

        
        values = {

            gRainAcceleration =
                rainAccelerationCurrent,

            -- Airflow is opposite vehicle world velocity.
            -- Debug 31 consumes this value only; persistent physics is
            -- intentionally unchanged until the direction test is verified.
            gRainAirVelocityWorld =
                vec3(
                    -car.velocity.x,
                    -car.velocity.y,
                    -car.velocity.z
                ),

            gRainAirDragScale =
                cfg.RUNTIME.RAIN_AIR_DRAG_SCALE,

            gRainDebug =
                cfg.RUNTIME.RAIN_DEBUG,

            gRainObjectToWorld =
                startingTransform,

            gRainCameraSide =
                ac.getCameraSide(),

            gRainCameraUp =
                ac.getCameraUp(),

            gRainCameraForward =
                ac.getCameraForward(),

            gRainSurfaceCenter =
                vec2(
                    cfg.RUNTIME.RAIN_SURFACE_CENTER_X,
                    cfg.RUNTIME.RAIN_SURFACE_CENTER_Y
                ),

            gRainSurfaceCurvature =
                vec2(
                    cfg.RUNTIME.RAIN_SURFACE_CURVATURE_X,
                    cfg.RUNTIME.RAIN_SURFACE_CURVATURE_Y
                ),

            gRainSurfaceSlopeY =
                cfg.RUNTIME.RAIN_SURFACE_SLOPE_Y,

            gRainAdhesionMin =
                cfg.RUNTIME.RAIN_ADHESION_MIN,

            gRainAdhesionMax =
                cfg.RUNTIME.RAIN_ADHESION_MAX,

            gRainGravity =
                cfg.RUNTIME.RAIN_GRAVITY,

            gRainForceScale =
                cfg.RUNTIME.RAIN_FORCE_SCALE,


            gRainDropLifetimeMin =
                cfg.RUNTIME.RAIN_DROP_LIFETIME_MIN,

            gRainDropLifetimeMax =
                cfg.RUNTIME.RAIN_DROP_LIFETIME_MAX,

            gRainDropRespawnGapMin =
                cfg.RUNTIME.RAIN_DROP_RESPAWN_GAP_MIN,

            gRainDropRespawnGapMax =
                cfg.RUNTIME.RAIN_DROP_RESPAWN_GAP_MAX,

            gRainFlowMax =
                cfg.RUNTIME.RAIN_FLOW_MAX,

            gRainFlowAcceleration =
                cfg.RUNTIME.RAIN_FLOW_ACCELERATION,

            gRainFlowDrag =
                cfg.RUNTIME.RAIN_FLOW_DRAG,

            gRainFlowMaxSpeed =
                cfg.RUNTIME.RAIN_FLOW_MAX_SPEED,

            gRainAmount =
                cfg.RUNTIME.RAIN_AMOUNT,

            gRainDensity =
                cfg.RUNTIME.RAIN_DENSITY,

            gRainTime =
                sim.time,

            gRainStateCount =
                cfg.RUNTIME.RAIN_GPU_STATE_COUNT,

            gRainStateMaxSpeed =
                cfg.RUNTIME.RAIN_GPU_STATE_MODE >= 3
                and (
                    cfg.RUNTIME.RAIN_FLOW_MAX_SPEED
                    / math.max(cfg.RUNTIME.RAIN_GPU_STATE_UV_SCALE, 0.000001)
                )
                or cfg.RUNTIME.RAIN_GPU_STATE_MAX_SPEED,

            gRainUVCenterX =
                    cfg.RUNTIME.RAIN_DEBUG_CENTER_X,                    
            
            gRainUVCenterY =
                    cfg.RUNTIME.RAIN_DEBUG_CENTER_Y,

            gRainStateDebugDisplacementScale =
                cfg.RUNTIME.RAIN_GPU_STATE_DEBUG_DISPLACEMENT_SCALE,

            gRainStateDebugSampleInterval =
                cfg.RUNTIME.RAIN_GPU_STATE_DEBUG_SAMPLE_INTERVAL,

            gRainStateDebugVelocityScale =
                cfg.RUNTIME.RAIN_GPU_STATE_DEBUG_VELOCITY_SCALE,

            gRainStateMeshVMin =
                cfg.RUNTIME.RAIN_GPU_STATE_MESH_V_MIN,

            gRainStateMeshVMax =
                cfg.RUNTIME.RAIN_GPU_STATE_MESH_V_MAX,

            gRainStateMeshUMin =
                cfg.RUNTIME.RAIN_GPU_STATE_MESH_U_MIN,

            gRainStateMeshUMax =
                cfg.RUNTIME.RAIN_GPU_STATE_MESH_U_MAX
        },

        shader = 
            -- UV_DEBUG_SHADER
            -- RAIN_SHADER
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

    local velocity = car.velocity

    if rainPreviousVelocity == nil then
        rainPreviousVelocity =
            vec3(
                velocity.x,
                velocity.y,
                velocity.z
            )

        return
    end

    ------------------------------------------------------------
    -- Acceleration is derived from velocity delta.
    -- This is the inertial input used by every individual drop.
    ------------------------------------------------------------
    local rawAcceleration =
        vec3(
            (velocity.x - rainPreviousVelocity.x) / dt,
            (velocity.y - rainPreviousVelocity.y) / dt,
            (velocity.z - rainPreviousVelocity.z) / dt
        )

    rainPreviousVelocity:set(velocity)

    ------------------------------------------------------------
    -- Keep acceleration in WORLD space.
    --
    -- RainFX physics must not use the camera basis: the visor can rotate
    -- independently of the vehicle and its camera-space normal field is
    -- intentionally almost uniform in the exposed region.
    --
    -- The shader receives this world-space vector and projects it onto
    -- each drop's local surface tangent frame using the object-space
    -- normal texture plus the rendered mesh UV derivatives.
    ------------------------------------------------------------
    local targetAcceleration =
        vec3(
            rawAcceleration.x * cfg.RUNTIME.RAIN_ACCEL_GAIN,
            rawAcceleration.y * cfg.RUNTIME.RAIN_ACCEL_GAIN,
            rawAcceleration.z * cfg.RUNTIME.RAIN_ACCEL_GAIN
        )

    ------------------------------------------------------------
    -- Smooth acceleration itself, not drop position.
    ------------------------------------------------------------
    local response =
        math.max(
            cfg.RUNTIME.RAIN_FLOW_RESPONSE,
            0.01
        )

    local smoothing =
        1.0
        - math.exp(
            -response * dt
        )

    rainAccelerationCurrent =
        rainAccelerationCurrent
        + (
            targetAcceleration
            - rainAccelerationCurrent
        ) * smoothing
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
    

    --------------------------------------------------------
    -- RainFX Debug controls
    --------------------------------------------------------
    ui.separator()
    ui.text('RainFX Debug Code')

    
    local strRainDebug = string.format('%d', cfg.RUNTIME.RAIN_DEBUG)


    local newText, changed, enterPressed =
        ui.inputText(
                'Debug mode',

                strRainDebug
            )

    if changed then
        cfg.RUNTIME.RAIN_DEBUG = safe_tonumber(newText, 0)
    end

    local newCenterX, changed = ui.slider(
        'CENTER_X',
        cfg.RUNTIME.RAIN_DEBUG_CENTER_X,
        -2.0,
        2.0,
        '%.3f'
    )
    
    if changed then
        cfg.RUNTIME.RAIN_DEBUG_CENTER_X = newCenterX
    end
    

    local newCenterY, changed = ui.slider(
        'CENTER_Y',
        cfg.RUNTIME.RAIN_DEBUG_CENTER_Y,
        -2.0,
        2.0,
        '%.3f'
    )
    
    if changed then
        cfg.RUNTIME.RAIN_DEBUG_CENTER_Y = newCenterY
    end
    
    
    local newVerticalUVMin, changed = ui.slider(
        '(UV Calibration) Vertical Min',
        cfg.RUNTIME.RAIN_GPU_STATE_MESH_V_MIN,
        -2.0,
        2.0,
        '%.3f'
    )
    
    if changed then
        cfg.RUNTIME.RAIN_GPU_STATE_MESH_V_MIN = newVerticalUVMin
    end
    
    
    local newVerticalUVMax, changed = ui.slider(
        '(UV Calibration) Vertical Max',
        cfg.RUNTIME.RAIN_GPU_STATE_MESH_V_MAX,
        -2.0,
        2.0,
        '%.3f'
    )
    
    if changed then
        cfg.RUNTIME.RAIN_GPU_STATE_MESH_V_MAX = newVerticalUVMax
    end
    
    local newHorizontalUVMin, changed = ui.slider(
        '(UV Calibration) Horizontal Min',
        cfg.RUNTIME.RAIN_GPU_STATE_MESH_U_MIN,
        -2.0,
        2.0,
        '%.3f'
    )
    
    if changed then
        cfg.RUNTIME.RAIN_GPU_STATE_MESH_U_MIN = newHorizontalUVMin
    end
    
    
    local newHorizontalUVMax, changed = ui.slider(
        '(UV Calibration) Horizontal Max',
        cfg.RUNTIME.RAIN_GPU_STATE_MESH_U_MAX,
        -2.0,
        2.0,
        '%.3f'
    )
    
    if changed then
        cfg.RUNTIME.RAIN_GPU_STATE_MESH_U_MAX = newHorizontalUVMax
    end
    --------------------------------------------------------
    -- Material Parameter: floating editor window
    --------------------------------------------------------

    drawMaterialEditorWindow(activeMaterialEditor)


end