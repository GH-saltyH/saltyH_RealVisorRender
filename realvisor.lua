------------------------------------------------------------
-- Real Visor Overlay
local strDisplayName = 'Real Visor Overlay'
-- Version: 0.3.2
local strAppNameInternal = 'RealVisor'
local strVersion= '0.3.2'
local appNameDebug = '[RealVisor_v' .. strVersion .. ']'
--
-- Author: saltyH
-- CSP Target: 0.3.0-preview477+
--
-- Tested on AC 1.16 / CSP 0.3.0-preview542
--
-- Focus:
-- 0.3.0
-- G-Force Motion (Tested)
-- 0.3.1
-- Support all-axis rotation (Tested *has Gimbal Lock limitation)
-- 0.3.2
-- Material Parameter Prototype
--  VISOR_GLASS_EXT_REFLECT, Tested
------------------------------------------------------------

------------------------------------------------------------
-- Configuration
------------------------------------------------------------

local cfg = {

    enabled = true,

    --modelPath = 'visors/visor_lando.kn5',
    modelPath = 'visors/visor_lando_reflection.kn5',


    --------------------------------------------------------
    -- Model calibration
    --------------------------------------------------------

    modelScale = 1.00,

    modelPitchDeg = 0,      
    modelYawDeg = 0,       
    modelRollDeg = 0,      

    --------------------------------------------------------
    -- Camera-local offset
    --------------------------------------------------------

    offset = vec3(
        -0.0033,
        -0.0102,
       -0.0492
    ),

    --------------------------------------------------------
    -- Camera-local offset
    --------------------------------------------------------

    distantNearclip = 0.0245,
    
    
    --------------------------------------------------------
    -- Debug Controls
    --------------------------------------------------------

    debugShowGlassExtDirt = true,
    debugShowGlassInt = true,
    debugShowGlassIntRefl = true,
    debugDeltapos = false,
    debugRotation = false,


    --------------------------------------------------------
    -- G-Force Motion
    --------------------------------------------------------

    enableMotion = true,

    motionGainX = 0.00009,
    motionGainY = 0.00006,
    motionGainZ = 0.00007,

    motionSmoothing = 30.0,

    motionSharpness = 1.11,

    motionLimitX = 0.025,
    motionLimitY = 0.020,
    motionLimitZ = 0.020,

    debugMotion = false,

    --------------------------------------------------------
    -- Material Parameter Prototype (VISOR_GLASS_EXT_DIRT)
    --------------------------------------------------------

    -- Experimental: some 'bool' jstyle shader parameters may actually need
    -- to be sent as 0/1 floats rather than Lua true/false to take effect.
    -- Toggle this in the material editor window while testing
    materialBoolAsNumber = true
}


------------------------------------------------------------
-- Global Names
------------------------------------------------------------
local strMeshVisorExtDirt = 'VISOR_GLASS_EXT_DIRT'
local strMeshVisorInt = 'VISOR_GLASS_INT'
local strMeshVisorIntRefl = 'VISOR_GLASS_INT_REFLECT'

local strMaterialEditorPopup = 'RealVisorMaterialEditor'
-- Material assigned to VISOR_GLASS_EXT_DIRT (Material Parameter Prototype target)
local strMaterialVisorExtDirt = 'mtVISOR_GLASS_EXT_DIRT'
local strMaterialVisorIntRefl = 'mtVISOR_GLASS_INT_REFLECT'


------------------------------------------------------------
-- Custom Parametor Registry
------------------------------------------------------------
local EXTDIRT_PARAMETERS = {

  -- Scalar
  {    name = 'ksAmbient',    type = 'float'  },
  {    name = 'ksDiffuse',    type = 'float'  },

  {    name = 'ksSpecular',    type = 'float'  },
  {    name = 'ksSpecularEXP',    type = 'float'  },

  {    name = 'ksAlphaRef',    type = 'float'  },

  {    name = 'fresnelC',    type = 'float'  },
  {    name = 'fresnelEXP',    type = 'float'  },
  {    name = 'fresnelMaxLevel',    type = 'float'  },

  {    name = 'extColoredReflection',    type = 'float'  },
  {    name = 'extColoredReflectionN',    type = 'float'  },
  
  {    name = 'nmObjectSpace',    type = 'float'  },

  {    name = 'NMmult',    type = 'float'  },
  {    name = 'detailNMmult',    type = 'float'  },

  {    name = 'uvMultX',    type = 'float'  },
  {    name = 'uvMultY',    type = 'float'  },

  {    name = 'uvOffsetX',    type = 'float'  },
  {    name = 'uvOffsetY',    type = 'float'  },


  -- Vector3
  {    name = 'ksEmissive',    type = 'vec3'  },


  -- Vector2
  {    name = 'offsetDSpeed',    type = 'vec2'  },
  {    name = 'offsetNMSpeed',    type = 'vec2'  },
  {    name = 'offsetNMdetailSpeed',    type = 'vec2'  },
  {    name = 'pauseTiming',    type = 'vec2'  },


  -- Boolean / 0 or 1
  {    name = 'isAdditive',    type = 'bool'  },
  {    name = 'emAlphaFromDiffuse',    type = 'bool'  },
  {    name = 'emClipOutside',    type = 'bool'  }
}

local INTREFLECT_PARAMETERS = {

  -- Scalar
  {    name = 'ksAmbient',    type = 'float'  },
  {    name = 'ksDiffuse',    type = 'float'  },
  
  {    name = 'ksSpecular',    type = 'float'  },
  {    name = 'ksSpecularEXP',    type = 'float'  },
  
  {    name = 'ksAlphaRef',    type = 'float'  },

  {    name = 'fresnelC',    type = 'float'  },
  {    name = 'fresnelEXP',    type = 'float'  },
  {    name = 'fresnelMaxLevel',    type = 'float'  },

  -- Vector3
  {    name = 'ksEmissive',    type = 'vec3'  },

  -- Boolean / 0 or 1
  {    name = 'isAdditive',    type = 'bool'  },
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
local visorGlassInt = nil
local visorGlassIntRefl = nil
local visorGlassExtDirt = nil

local visorGlassExtDirtMaterial = nil   -- SceneReference for mtVISOR_GLASS_EXT_DIRT, once located
local visorGlassIntReflMaterial = nil   -- mtVISOR_GLASS_INT_REFLECT

------------------------------------------------------------
-- Runtime state
------------------------------------------------------------

local initialized = false

local lastScale = -1

local lastPitch = 99999
local lastYaw = 99999
local lastRoll = 99999

local materialInputBuffers = {} -- materials Input Buffer during editing
local materialInputApplyRequested = false   -- It helps to trigger when you presses 'Enter' on inputtext
local extDirtValues = {}        -- Live UI/edit state for EXT_DIRT_PARAMETERS, keyed by parameter name
local intReflValues = {}        -- Reflection parameter container (reserved for future prototype)


------------------------------------------------------------
-- Material editor state (VISOR_GLASS_EXT_DIRT prototype)
------------------------------------------------------------

local materialParamsLoaded = false      -- Have EXTDIRT_PARAMETERS been read from material at least once?
local materialEditWindowOpen = false    -- Visibility flag for the floating material editor window
local materialLastError = nil           -- Last apply/read error message, shown in the editor window


------------------------------------------------------------
-- Motion state
------------------------------------------------------------

local previousVelocity = nil
    
local motionCurrent = vec3(
    0,
    0,
    0
)
    
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


------------------------------------------------------------
-- Material Parameter Prototype: helpers
--
-- Read and Apply are kept strictly separate:
--   - loadExtDirtMaterialParams() reads current values from the material
--     into extDirtValues (UI state). Only called on init / manual reload.
--   - applyExtDirtMaterialParams() pushes edited UI state back onto the
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

local function loadExtDirtMaterialParams()

    extDirtValues = {}

    if not visorGlassExtDirt or #visorGlassExtDirt == 0 then

        ac.warn(
            appNameDebug .. ' MATERIAL: ' .. strMeshVisorExtDirt .. ' mesh not available, cannot read material'
        )

        materialParamsLoaded = false

        return false 
    end

    for _, paramDef in ipairs(EXTDIRT_PARAMETERS) do

        local rawValue, readOk =
            readMaterialProperty(visorGlassExtDirt, paramDef)

        local entry = {
            type = paramDef.type,
            readOk = readOk
        }

        if paramDef.type == 'float' then

            entry.value = tonumber(rawValue) or 0.0

        elseif paramDef.type == 'bool' then

            --------------------------------------------------------
            -- Boolean parameters may come back as a real Lua boolean
            -- or as a 0/1 float, depending on the CSP build/shader.
            -- Normalize to a Lua boolean for the checkbox UI; the
            -- send-back format is controlled separately by
            -- cfg.materialBoolAsNumber in applyExtDirtMaterialParams().
            --------------------------------------------------------

            if type(rawValue) == 'boolean' then
                entry.value = rawValue

            elseif type(rawValue) == 'number' then
                entry.value = rawValue > 0.5

            else
                entry.value = false
            end

        elseif paramDef.type == 'vec2' then

            local okX, xValue = pcall(function() return rawValue.x end)
            local okY, yValue = pcall(function() return rawValue.y end)

            if okX and okY and xValue ~= nil and yValue ~= nil then
                entry.value = vec2(xValue, yValue)
            else
                entry.value = vec2(0, 0)
            end

        elseif paramDef.type == 'vec3' then

            local okX, xValue = pcall(function() return rawValue.x end)
            local okY, yValue = pcall(function() return rawValue.y end)
            local okZ, zValue = pcall(function() return rawValue.z end)

            if okX and okY and okZ and xValue ~= nil and yValue ~= nil and zValue ~= nil then
                entry.value = vec3(xValue, yValue, zValue)
            else
                entry.value = vec3(0, 0, 0)
            end
        end

        extDirtValues[paramDef.name] = entry

        if not readOk then
            ac.warn(
                appNameDebug .. ' MATERIAL: failed to read "' .. paramDef.name .. '", using default'
            )
        end
    end

    materialParamsLoaded = true

    ac.log(
        appNameDebug .. ' MATERIAL: ' .. strMaterialVisorExtDirt .. ' parameters loaded'
    )

    materialInputBuffers = {}

    return true
end


--------------------------------------------------------
-- Push edited extDirtValues back onto the material.
-- Only called explicitly (Refresh button) -- never per-frame.
--------------------------------------------------------

local function applyExtDirtMaterialParams()

    if not visorGlassExtDirt or #visorGlassExtDirt == 0 then

        materialLastError = strMeshVisorExtDirt .. ' mesh not available'

        return false
    end

    local allOk = true

    for _, paramDef in ipairs(EXTDIRT_PARAMETERS) do

        local entry = extDirtValues[paramDef.name]

        if entry then

            local sendValue = entry.value

            if paramDef.type == 'bool' then

                if cfg.materialBoolAsNumber then
                    sendValue = entry.value and 1.0 or 0.0
                else
                    sendValue = entry.value and true or false
                end
            end

            local ok, err = pcall(
                function()
                    visorGlassExtDirt:setMaterialProperty(
                        paramDef.name,
                        sendValue
                    )
                end
            )

            if not ok then

                allOk = false

                materialLastError = paramDef.name .. ': ' .. tostring(err)

                ac.warn(
                    appNameDebug .. ' MATERIAL: failed to set "' .. paramDef.name .. '" -> ' .. tostring(err)
                )
            end
        end
    end

    if allOk then

        materialLastError = nil

        ac.log(
            appNameDebug .. ' MATERIAL: ' .. strMaterialVisorExtDirt .. ' parameters applied'
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
        cfg.modelScale - lastScale
    ) < 0.000001 then
        return
    end


    local transform =
        scaleNode:getTransformationRaw()


    if transform then

        transform:set(

            mat4x4.scaling(
                vec3.new(cfg.modelScale)
            )
        )
    end


    lastScale = cfg.modelScale
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
            cfg.modelPitchDeg - lastPitch
        ) >= 0.0001 then

        axisPitchNode:setRotation(

            vec3(1, 0, 0),

            math.rad(
                cfg.modelPitchDeg
            )
        )

        lastPitch =
            cfg.modelPitchDeg
    end


    ------------------------------------------------------------
    -- Yaw
    ------------------------------------------------------------

    if axisYawNode
        and math.abs(
            cfg.modelYawDeg - lastYaw
        ) >= 0.0001 then

        axisYawNode:setRotation(

            vec3(0, 1, 0),

            math.rad(
                cfg.modelYawDeg
            )
        )

        lastYaw=
            cfg.modelYawDeg
    end


    ------------------------------------------------------------
    -- Roll
    ------------------------------------------------------------

    if axisRollNode
        and math.abs(
            cfg.modelRollDeg - lastRoll
        ) >= 0.0001 then

        axisRollNode:setRotation(

            vec3(0, 0, 1),

            math.rad(
                cfg.modelRollDeg
            )
        )

        lastRoll=
            cfg.modelRollDeg
    end
end


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

            filename = cfg.modelPath,

            forceRenderableOn = true
        })


    if not visor then

        ac.warn(
            appNameDebug .. ' Failed to load KN5: '
            .. cfg.modelPath
        )

        return false
    end


    --------------------------------------------------------
    -- Setup Camera Clipping 
    --------------------------------------------------------

    if cfg.distantNearclip and ac.getSim().cameraClipFar then
        ac.overrideCameraClipPlanes(cfg.distantNearclip, ac.getSim().cameraClipFar)
    end


    --------------------------------------------------------
    -- Find glass mesh
    --
    -- Actual tested filter:
    -- VISOR_GLASS
    --------------------------------------------------------

    visorGlassInt =
        visor:findMeshes(
            strMeshVisorInt
        )

    visorGlassIntRefl =
        visor:findMeshes(
            strMeshVisorIntRefl
        )

    visorGlassExtDirt =
        visor:findMeshes(
            strMeshVisorExtDirt
        )

    if visorGlassInt
        and #visorGlassInt > 0 then

        ac.log(
            appNameDebug .. ' ' .. strMeshVisorInt .. ' found'
        )

    else

        ac.warn(
            appNameDebug .. ' ' .. strMeshVisorInt .. ' not found'
        )
    end


    if visorGlassIntRefl
        and #visorGlassIntRefl > 0 then

        ac.log(
            appNameDebug .. ' ' .. strMeshVisorIntRefl .. ' found'
        )
        

    else

        ac.warn(
            appNameDebug .. ' ' .. strMeshVisorIntRefl .. ' not found'
        )
    end

    
    if visorGlassExtDirt
        and #visorGlassExtDirt > 0 then

        ac.log(
            appNameDebug .. ' ' .. strMeshVisorExtDirt .. ' found'
        )

    else

        ac.warn(
            appNameDebug .. ' ' .. strMeshVisorExtDirt .. ' not found'
        )
        -- visorGlassExtDirt =
        --     visor:findMeshes(
        --         'VISOR_GLASS_EXT_REFLECT'
        --     )

        -- ac.warn(
        --     appNameDebug .. ' VISOR_GLASS_EXT not found : try find VISOR_GLASS_EXT_REFLECT instead'
        -- )
        -- if visorGlassExtDirt
        --     and #visorGlassExtDirt > 0 then

        --     ac.log(
        --         appNameDebug .. ' VISOR_GLASS_EXT_REFLECT found'
        --     )

        -- else
            -- ac.warn(
            --     appNameDebug .. ' VISOR_GLASS_EXT_REFLECT not found'
            -- )
        -- end
    end


    --------------------------------------------------------
    -- Material Parameter Prototype
    --
    -- Locate mtVISOR_GLASS_EXT_DIRT (assigned to VISOR_GLASS_EXT_DIRT)
    -- using CSP's 'material:' scene query, then do the initial
    -- parameter read so the editor window has data as soon as it
    -- is opened.
    --------------------------------------------------------

    if visorGlassExtDirt and #visorGlassExtDirt > 0 then

        visorGlassExtDirtMaterial =
            visor:findMeshes(
                'material:' .. strMaterialVisorExtDirt
            )

        if visorGlassExtDirtMaterial
            and #visorGlassExtDirtMaterial > 0 then

            ac.log(
                appNameDebug .. ' MATERIAL: ' .. strMaterialVisorExtDirt .. ' found'
            )

            loadExtDirtMaterialParams()

        else

            ac.warn(
                appNameDebug .. ' MATERIAL: ' .. strMaterialVisorExtDirt .. ' not found'
            )
        end
    end


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
-- Update camera transform
------------------------------------------------------------
local prevPos = nil
local textDebugDeltaPos = nil
local textDebugPos = nil
local textDebugCamRotation = nil
local function updateCameraTransform()

    
    --------------------------------------------------------
    -- Get camera position
    --------------------------------------------------------

    local position =
        ac.getCameraPosition()


    --------------------------------------------------------
    -- Debug logger: Position delta 
    --------------------------------------------------------
    if cfg.debugDeltapos then
        
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
    

    --------------------------------------------------------
    -- Debug logger: Orientation (Forward) delta
    --------------------------------------------------------
    if cfg.debugRotation then
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

        worldUp
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
        cfg.offset
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
    if not cfg.enableMotion then

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
            * cfg.motionGainX
            * cfg.motionSharpness

    motionTarget.y =
            -accelerationY
            * cfg.motionGainY
            * cfg.motionSharpness

    motionTarget.y =
            -accelerationY
            * cfg.motionGainY
            * cfg.motionSharpness


    ------------------------------------------------------------
    -- Axis limits
    ------------------------------------------------------------

    motionTarget.x =
        clampValue(

            motionTarget.x,

            -cfg.motionLimitX,

            cfg.motionLimitX
        )


    motionTarget.y =
        clampValue(

            motionTarget.y,

            -cfg.motionLimitY,

            cfg.motionLimitY
        )


    motionTarget.z =
        clampValue(

            motionTarget.z,

            -cfg.motionLimitZ,

            cfg.motionLimitZ
        )


    ------------------------------------------------------------
    -- Exponential smoothing
    ------------------------------------------------------------
    local smoothingAlpha =
        1.0
        -
        math.exp(
            -cfg.motionSmoothing 
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

    if cfg.debugMotion then

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


    if not visor then  

        ac.overrideCameraClipPlanes(nil, nil)

        return
    end


    --------------------------------------------------------
    -- Visibility
    --------------------------------------------------------

    visor:setVisible(
        cfg.enabled
    )


    if not cfg.enabled then
        -- ac.log(appNameDebug .. ' cfg.enabled = false update terminated')
        return
    end


    --------------------------------------------------------
    -- Camera transform
    --------------------------------------------------------

    updateCameraTransform()


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
-- applyExtDirtMaterialParams(), on "Refresh".
------------------------------------------------------------

local function drawFloatParam(label, paramName, fmt)

    local entry = extDirtValues[paramName]

    if not entry then
        ui.text(label .. ': N/A')
        return
    end

    if materialInputBuffers[paramName] == nil then
        materialInputBuffers[paramName] =
            string.format(fmt or '%.3f', entry.value)
    end

    local newText, changed, enterPressed =
        ui.inputText(
            label .. '##' .. paramName,
            materialInputBuffers[paramName]
        )

    if changed then

        materialInputBuffers[paramName] = newText
        local numberValue = tonumber(newText)

        if numberValue ~= nil then        
            entry.value = numberValue
        end
    end

    if enterPressed then
        materialInputApplyRequested = true
    end

end


local function drawBoolParam(label, paramName)

    local entry = extDirtValues[paramName]

    if not entry then
        return
    end

    local changed, _ =
        ui.checkbox(
            label,
            entry.value
        )

    if changed then
        entry.value = not entry.value
    end
end


local function drawVec2Param(labelX, labelY, paramName, minV, maxV, fmt)

    local entry = extDirtValues[paramName]

    if not entry then
        return
    end

    local nx, changedX =
        ui.slider(labelX, entry.value.x, minV, maxV, fmt or '%.3f')

    if changedX then
        entry.value.x = nx
    end

    ui.sameLine(0, 20)

    local ny, changedY =
        ui.slider(labelY, entry.value.y, minV, maxV, fmt or '%.3f')

    if changedY then
        entry.value.y = ny
    end
end


local function drawVec3Param(label, paramName, minV, maxV, fmt)

    local entry = extDirtValues[paramName]

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
-- Material Parameter Prototype: floating editor window
--
-- ui.beginWindow / ui.endWindow open an auxiliary floating window
-- independent of the app's main window (per CSP's own ui.beginWindow
-- API) -- verify signature against your local CSP Lua docs if it
-- doesn't compile on your CSP build; ui.openPopup / ui.beginPopup
-- is the documented fallback.
-- NOTE: Use openPopup/beginPopup instead
------------------------------------------------------------


local function drawMaterialEditorWindow()

    if not materialEditWindowOpen then
        return
    end

    if ui.beginPopup(
        strMaterialEditorPopup,
        nil,
        nil,
        materialEditWindowOpen
    ) then

        ui.text(strMaterialVisorExtDirt .. ' - Material')
        ui.separator()

        if not visorGlassExtDirtMaterial
            or #visorGlassExtDirtMaterial == 0 then

            ui.text(
                'Material not found: ' 
                .. strMaterialVisorExtDirt
            )

        elseif not materialParamsLoaded then

            ui.text('Parameters not loaded yet.')

        else

            ui.text('Base')
            drawFloatParam('Ambient', 'ksAmbient')
            drawFloatParam('Diffuse', 'ksDiffuse')
            drawFloatParam('Specular', 'ksSpecular')
            drawFloatParam('Specular EXP', 'ksSpecularEXP', '%.1f')
            drawFloatParam('Alpha Ref', 'ksAlphaRef', '%.3f')

            ui.separator()
            ui.text('Fresnel')
            drawFloatParam('C', 'fresnelC')
            drawFloatParam('EXP', 'fresnelEXP', '%.2f')
            drawFloatParam('Max Level', 'fresnelMaxLevel')

            ui.separator()
            ui.text('Colored Reflection')
            drawFloatParam('Amount', 'extColoredReflection')
            drawFloatParam('Amount N', 'extColoredReflectionN')

            ui.separator()
            ui.text('Normal')
            drawFloatParam('Object Space', 'nmObjectSpace')
            drawFloatParam('NM Mult', 'NMmult')
            drawFloatParam('Detail NM', 'detailNMmult')

            ui.separator()
            ui.text('UV')
            drawFloatParam('MultX', 'uvMultX')
            ui.sameLine(0,20)
            drawFloatParam('MultY', 'uvMultY')

            drawFloatParam('OffsetX', 'uvOffsetX')
            ui.sameLine(0,20)
            drawFloatParam('OffsetY', 'uvOffsetY')

            ui.separator()
            ui.text('Emissive')
            drawVec3Param('ksEmissive', 'ksEmissive', 0.0, 5.0)

            ui.separator()
            ui.text('UV Animation (offset speed)')
            drawVec2Param('D Speed X', 'D Speed Y', 'offsetDSpeed', -5.0, 5.0)
            drawVec2Param('NM Speed X', 'NM Speed Y', 'offsetNMSpeed', -5.0, 5.0)
            drawVec2Param('Detail NM Speed X', 'Detail NM Speed Y', 'offsetNMdetailSpeed', -5.0, 5.0)
            drawVec2Param('Pause Timing X', 'Pause Timing Y', 'pauseTiming', 0.0, 10.0)

            ui.separator()
            ui.text('Flags')
            drawBoolParam('Additive', 'isAdditive')
            drawBoolParam('Emissive Alpha From Diffuse', 'emAlphaFromDiffuse')
            drawBoolParam('Emissive Clip Outside', 'emClipOutside')

            ui.separator()

            local changedBoolMode, _ =
                ui.checkbox('Send bool as 0/1 (experimental)', cfg.materialBoolAsNumber)

            if changedBoolMode then
                cfg.materialBoolAsNumber = not cfg.materialBoolAsNumber
            end
        end

        ui.separator()

        if ui.button('Refresh') 
            or materialInputApplyRequested then
                materialInputApplyRequested = false
                applyExtDirtMaterialParams()
        end

        ui.sameLine(0, 15)

        if ui.button('Reload from material') then
            loadExtDirtMaterialParams()
        end

        ui.sameLine(0, 15)

        if ui.button('Close') then
            materialEditWindowOpen = false
            ui.closePopup()
        end

        if materialLastError then
            ui.text('Last error: ' .. materialLastError)
        end

    end
end


------------------------------------------------------------
-- Main window
------------------------------------------------------------


function windowMain(dt)

    

    ui.text(
        strDisplayName .. ' v' .. strVersion
    )

    ui.separator()



    local changed = nil     -- local boolean
    --------------------------------------------------------
    -- Enable
    --------------------------------------------------------
    changed, _ = ui.checkbox(

            'Enable Real Visor',

            cfg.enabled
        )

    if changed then
        cfg.enabled = not cfg.enabled
        ac.log(
            appNameDebug .. ' Visor ' .. (cfg.enabled and 'Enabled' or 'Disabled')
        )
    end        


    --------------------------------------------------------
    -- Scale
    --------------------------------------------------------

    ui.separator()

    ui.text('Model Scale')

    cfg.modelScale, changed =
        ui.slider(

            'Scale',

            cfg.modelScale,

            0.01,

            10.00,

            '%.4f'
        )

    if changed then
        ac.log(
            appNameDebug .. ' KN5 Global Scale: ' .. cfg.modelScale
        )
    end

    --------------------------------------------------------
    -- Axis
    --------------------------------------------------------

    ui.separator()

    ui.text('Axis Correction')


        --------------------------------------------------------
        -- Pitch
        --------------------------------------------------------
        cfg.modelPitchDeg, changed =
            ui.slider(

                'Pitch',

                cfg.modelPitchDeg,

                -180,

                180,

                '%.1f°'
            )

        if changed then
            ac.log(
                appNameDebug .. ' KN5 Pitch: ' .. cfg.modelPitchDeg
            )
        end


        --------------------------------------------------------
        -- Yaw
        --------------------------------------------------------
        cfg.modelYawDeg, changed =
            ui.slider(

                'Yaw',

                cfg.modelYawDeg,

                -180,

                180,

                '%.1f°'
            )

        if changed then
            ac.log(
                appNameDebug .. ' KN5 Yaw: ' .. cfg.modelYawDeg
            )
        end


        --------------------------------------------------------
        -- Pitch
        --------------------------------------------------------
        cfg.modelRollDeg, changed =
            ui.slider(

                'Roll',

                cfg.modelRollDeg,

                -180,

                180,

                '%.1f°'
            )

        if changed then
            ac.log(
                appNameDebug .. ' KN5 Roll: ' .. cfg.modelRollDeg
            )
        end


    --------------------------------------------------------
    -- Offset
    --------------------------------------------------------

    ui.separator()

    ui.text('Camera Local Offset')


    cfg.offset.x, changed =
        ui.slider(

            'Right',

            cfg.offset.x,

            -0.3,

            0.3,

            '%.4f m'
        )

    if changed then
        ac.log(
            appNameDebug .. ' KN5 Camera Offset(Right): ' .. cfg.offset.x
        )
    end


    cfg.offset.y, changed =
        ui.slider(

            'Up',

            cfg.offset.y,

            -0.3,

            0.3,

            '%.4f m'
        )

    if changed then
        ac.log(
            appNameDebug .. ' KN5 Camera Offset(Up): ' .. cfg.offset.y
        )
    end

    cfg.offset.z, changed =
        ui.slider(

            'Forward',

            cfg.offset.z,

            -0.3,

            0.5,

            '%.4f m'
        )

    if changed then
        ac.log(
            appNameDebug .. ' KN5 Camera Offset(Forward): ' .. cfg.offset.z
        )
    end

    --------------------------------------------------------
    -- Near Clip Distance
    --------------------------------------------------------
    ui.separator()

    ui.text(
        'Near Clip Distance'
    )

    cfg.distantNearclip, changed = ui.slider(

        'Near Clip',

        cfg.distantNearclip,

        0.0001,

        0.3,

        '%.4f m'
    )

    if changed and visor then
        ac.overrideCameraClipPlanes(cfg.distantNearclip, ac.getSim().cameraClipFar)
        ac.log(
            appNameDebug .. 'Set CamClipDist (Near: ' .. string.format('%4f', ac.getSim().cameraClipNear) .. ', Far Clip: ' .. ac.getSim().cameraClipFar .. ')'
        )
    end


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
        changed, _ =
            ui.checkbox(

                'Enable Motion',

                cfg.enableMotion
            )

        if changed then
            cfg.enableMotion = 
                not cfg.enableMotion
        end


        --------------------------------------------------------
        -- G-Force Motion: X
        --------------------------------------------------------

        cfg.motionGainX, changed =
            ui.slider(

                'Motion X',

                cfg.motionGainX,

                0.0,

                0.01,

                '%.5f'
            )


        --------------------------------------------------------
        -- G-Force Motion: Y
        --------------------------------------------------------

        cfg.motionGainY, changed =
            ui.slider(

                'Motion Y',

                cfg.motionGainY,

                0.0,

                0.01,

                '%.5f'
            )


        --------------------------------------------------------
        -- G-Force Motion: Z
        --------------------------------------------------------

        cfg.motionGainZ, changed =
            ui.slider(

                'Motion Z',

                cfg.motionGainZ,

                0.0,

                0.01,

                '%.5f'
            )


        --------------------------------------------------------
        -- G-Force Motion: Sharpness
        --------------------------------------------------------

        cfg.motionSharpness, changed =
            ui.slider(

                'Motion Strength',

                cfg.motionSharpness,

                0.0,

                5.0,

                '%.2f'
            )


        --------------------------------------------------------
        -- G-Force Motion: Smothing
        --------------------------------------------------------

        cfg.motionSmoothing, changed =
            ui.slider(

                'Motion Response',

                cfg.motionSmoothing,

                0.1,

                50.0,

                '%.2f'
            )


    --------------------------------------------------------
    -- Glass debug: MESH Found
    --------------------------------------------------------

    ui.separator()
    ui.text('Model Config')
    local foundGlassExt, foundGlassInt, foundGlassIntRefl = visorGlassExtDirt, visorGlassInt, visorGlassIntRefl
    
    ui.text(
        '\t' .. strMeshVisorExtDirt .. ': ' 
        .. ((visorGlassExtDirt and #visorGlassExtDirt > 0 )
        and 'FOUND' or 'NOTFOUND' )
    )
    
    ui.text(
        '\t' .. strMeshVisorInt .. ': ' 
        .. ((visorGlassInt and #visorGlassInt > 0 )
        and 'FOUND' or 'NOTFOUND')
    )

    ui.text(
        '\t' .. strMeshVisorIntRefl .. ': ' 
        .. ((visorGlassIntRefl and #visorGlassIntRefl > 0 )
        and 'FOUND' or 'NOTFOUND')
    )

    
    --------------------------------------------------------
    -- Material Parameter Prototype: open editor
    --------------------------------------------------------

    ui.text(
        '\t' .. strMaterialVisorExtDirt .. ': '
        .. ((visorGlassExtDirtMaterial and #visorGlassExtDirtMaterial > 0)
        and 'FOUND' or 'NOTFOUND')
    )

    if ui.button('Edit ' .. strMeshVisorExtDirt .. ' Material...') then

        materialEditWindowOpen = true

        if not materialParamsLoaded then
            loadExtDirtMaterialParams()
        end

        ui.openPopup(strMaterialEditorPopup)
    end


    --------------------------------------------------------
    -- Glass debug: Show / Hide Meshes
    --------------------------------------------------------
    ui.text( '\tVisibility')
    ui.text('')
    ui.sameLine(0, 15)

    changed, _ = ui.checkbox(
            strMeshVisorExtDirt,
            cfg.debugShowGlassExtDirt
        )

    if changed then
        cfg.debugShowGlassExtDirt = not cfg.debugShowGlassExtDirt
        if visorGlassExtDirt and #visorGlassExtDirt > 0 then
            visorGlassExtDirt:setVisible(cfg.debugShowGlassExtDirt)
        end
        --setMeshesVisible(visorGlassExtDirt, cfg.debugShowGlassExtDirt)
        ac.log(
            appNameDebug .. ' ' .. strMeshVisorExtDirt .. (cfg.debugShowGlassExtDirt and ': Show' or ': Hide')
        )
    end        

    ui.sameLine(0, 30)

    changed, _ = ui.checkbox(
            strMeshVisorInt,
            cfg.debugShowGlassInt 
        )

    if changed then
        cfg.debugShowGlassInt = not cfg.debugShowGlassInt
        if visorGlassInt and #visorGlassInt > 0 then
            visorGlassInt:setVisible(cfg.debugShowGlassInt)
        end
        --setMeshesVisible(visorGlassInt, cfg.debugShowGlassInt)
        ac.log(
            appNameDebug .. ' ' .. strMeshVisorInt .. (cfg.debugShowGlassInt and ': Show' or ': Hide')
        )
    end        

    ui.sameLine(0, 35)

    changed, _ = ui.checkbox(
            strMeshVisorIntRefl,
            cfg.debugShowGlassIntRefl
        )

    if changed then
        cfg.debugShowGlassIntRefl = not cfg.debugShowGlassIntRefl
        if visorGlassIntRefl and #visorGlassIntRefl > 0 then
            visorGlassIntRefl:setVisible(cfg.debugShowGlassIntRefl)
        end
        --setMeshesVisible(visorGlassInt, cfg.debugShowGlassInt)
        ac.log(
            appNameDebug .. ' ' .. strMeshVisorIntRefl .. (cfg.debugShowGlassIntRefl and ': Show' or ': Hide')
        )
    end       

    --------------------------------------------------------
    -- Runtime info
    --------------------------------------------------------

    ui.text(

        string.format(

            '\tScale: %.4f',

            cfg.modelScale
        )
    )

    
    --------------------------------------------------------
    -- Debug Log
    --------------------------------------------------------

    ui.text('')
    ui.sameLine(0, 15)

    changed, _ = ui.checkbox(

        '[Log] Show position delta',

        cfg.debugDeltapos
    )

    if changed then
        cfg.debugDeltapos = not cfg.debugDeltapos
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

        cfg.debugRotation
    )

    if changed then
        cfg.debugRotation = not cfg.debugRotation
    end     

    if textDebugCamRotation then
        ui.text('\t\t*' .. textDebugCamRotation)
    end
    

    
    --------------------------------------------------------
    -- Material Parameter Prototype: floating editor window
    --------------------------------------------------------

    drawMaterialEditorWindow()


end