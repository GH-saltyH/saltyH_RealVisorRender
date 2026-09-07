------------------------------------------------------------
-- Real Visor Overlay
local strDisplayName = 'Real Visor Overlay'
-- Version: 0.3.1
local strAppNameInternal = 'RealVisor'
local strVersion= '0.3.1'
local appNameDebug = '[RealVisor_v' .. strVersion .. ']'
--
-- Author: saltyH
-- CSP Target: 0.3.0-preview477+
--
-- Tested on AC 1.16 / CSP 0.3.0-preview542
--
-- Focus:
-- G-Force Motion (Tested)
-- Support all-axis rotation (Tested *has Gimbal Lock limitation)
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

    modelPitchDeg = 0,      -- 위아래
    modelYawDeg = 0,        -- 지금은 모델 자체를 돌려서 제작했음 -90.0,  
    modelRollDeg = 0,       -- 기울임회전

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

    debugShowGlassExt = true,
    debugShowGlassInt = true,
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

    debugMotion = false
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
local visorGlassExt = nil


------------------------------------------------------------
-- Runtime state
------------------------------------------------------------

local initialized = false

local lastScale = -1

local lastPitch = 99999
local lastYaw = 99999
local lastRoll = 99999


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
            'VISOR_GLASS_INT'
        )
    visorGlassExt =
        visor:findMeshes(
            'VISOR_GLASS_EXT'
        )

    if visorGlassInt
        and #visorGlassInt > 0 then

        ac.log(
            appNameDebug .. ' VISOR_GLASS_INT found'
        )

    else

        ac.warn(
            appNameDebug .. ' VISOR_GLASS_INT not found'
        )
    end

    if visorGlassExt
        and #visorGlassExt > 0 then

        ac.log(
            appNameDebug .. ' VISOR_GLASS_EXT found'
        )

    else
        visorGlassExt =
            visor:findMeshes(
                'VISOR_GLASS_EXT_REFLECT'
            )

        ac.warn(
            appNameDebug .. ' VISOR_GLASS_EXT not found : try find VISOR_GLASS_EXT_REFLECT instead'
        )
        if visorGlassExt
            and #visorGlassExt > 0 then

            ac.log(
                appNameDebug .. ' VISOR_GLASS_EXT_REFLECT found'
            )

        else
            ac.warn(
                appNameDebug .. ' VISOR_GLASS_EXT_REFLECT not found'
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
    local foundGlassExt, foundGlassInt = visorGlassExt, visorGlassInt
    
    ui.text(
        '\tVISOR_GLASS_EXT: ' 
        .. ((visorGlassExt and #visorGlassExt > 0 )
        and 'FOUND' or 'NOTFOUND' )
    )
    ui.sameLine(0, 50)
    ui.text(
        'VISOR_GLASS_INT:' 
        .. ((visorGlassInt and #visorGlassInt > 0 )
        and 'FOUND' or 'NOTFOUND')
    )

    --------------------------------------------------------
    -- Glass debug: Show / Hide Meshes
    --------------------------------------------------------
    ui.text( '\tVisibility')
    ui.text('')
    ui.sameLine(0, 15)

    changed, _ = ui.checkbox(
            'VISOR_GLASS_EXT',
            cfg.debugShowGlassExt
        )

    if changed then
        cfg.debugShowGlassExt = not cfg.debugShowGlassExt
        if visorGlassExt and #visorGlassExt > 0 then
            visorGlassExt:setVisible(cfg.debugShowGlassExt)
        end
        --setMeshesVisible(visorGlassExt, cfg.debugShowGlassExt)
        ac.log(
            appNameDebug .. ' VISOR_GLASS_EXT' .. (cfg.enabled and ': Show' or ': Hide')
        )
    end        

    ui.sameLine(0, 70)

    changed, _ = ui.checkbox(
            'VISOR_GLASS_INT',
            cfg.debugShowGlassInt 
        )

    if changed then
        cfg.debugShowGlassInt = not cfg.debugShowGlassInt
        if visorGlassInt and #visorGlassInt > 0 then
            visorGlassInt:setVisible(cfg.debugShowGlassInt)
        end
        --setMeshesVisible(visorGlassInt, cfg.debugShowGlassInt)
        ac.log(
            appNameDebug .. ' VISOR_GLASS_INT' .. (cfg.enabled and ': Show' or ': Hide')
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
    
end