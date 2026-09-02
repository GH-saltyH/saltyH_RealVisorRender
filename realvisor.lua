------------------------------------------------------------
-- Real Visor Overlay
-- Version: 0.2.1
--
-- Author: saltyH
-- CSP Target: 0.3.0-preview500+
--
-- Focus:
-- Camera rotation tracking
------------------------------------------------------------


------------------------------------------------------------
-- Configuration
------------------------------------------------------------

local cfg = {

    enabled = true,

    modelPath = 'visors/visor_lando.kn5',


    --------------------------------------------------------
    -- Model calibration
    --------------------------------------------------------

    modelScale = 0.017,

    modelYawDeg = 0,        -- 지금은 모델 자체를 돌려서 제작했음 -90.0,  


    --------------------------------------------------------
    -- Camera-local offset
    --------------------------------------------------------

    offset = vec3(
        -0.0049,
        -0.0519,
        0.0005
    ),

    debugDeltapos = false,
    debugRotation = false,

    --------------------------------------------------------
    -- Future motion
    --------------------------------------------------------

    enableMotion = false
}


------------------------------------------------------------
-- Scene references
------------------------------------------------------------

local carsRoot = nil

local cameraAnchor = nil    -- Temporal Crash Patches v2.0.0 Restore

local cameraRoot = nil
local offsetNode = nil
local scaleNode = nil
local axisNode = nil

local visor = nil
local visorGlassInt = nil
local visorGlassExt = nil


------------------------------------------------------------
-- Runtime state
------------------------------------------------------------

local initialized = false

local lastScale = -1
local lastYaw = 99999


------------------------------------------------------------
-- Camera vectors
------------------------------------------------------------

local worldUp = vec3(0, 1, 0)


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

    if not axisNode then
        return
    end


    if math.abs(
        cfg.modelYawDeg - lastYaw
    ) < 0.0001 then
        return
    end


    axisNode:setRotation(

        vec3(0, 1, 0),

        math.rad(
            cfg.modelYawDeg
        )
    )


    lastYaw = cfg.modelYawDeg
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
            '[RealVisor] carsRoot not found'
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
        ac.warn('[RealVisor] Camera anchor creation failed')
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
            '[RealVisor] Camera root creation failed'
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
    -- Scale
    --------------------------------------------------------

    scaleNode =
        offsetNode:createNode(
            'REALVISOR_SCALE'
        )


    --------------------------------------------------------
    -- Model axis
    --------------------------------------------------------

    axisNode =
        scaleNode:createNode(
            'REALVISOR_AXIS'
        )


    if not offsetNode
        or not scaleNode
        or not axisNode then

        ac.warn(
            '[RealVisor] Transform hierarchy failed'
        )

        return false
    end


    --------------------------------------------------------
    -- Load KN5
    --------------------------------------------------------

    visor =
        axisNode:loadKN5({

            filename = cfg.modelPath,

            forceRenderableOn = true
        })


    if not visor then

        ac.warn(
            '[RealVisor] Failed to load KN5: '
            .. cfg.modelPath
        )

        return false
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
            '[RealVisor] VISOR_GLASS_INT found'
        )

    else

        ac.warn(
            '[RealVisor] VISOR_GLASS_INT not found'
        )
    end

    if visorGlassExt
        and #visorGlassExt > 0 then

        ac.log(
            '[RealVisor] VISOR_GLASS_EXT found'
        )

    else

        ac.warn(
            '[RealVisor] VISOR_GLASS_EXT not found'
        )
    end

    --------------------------------------------------------
    -- Apply initial transforms
    --------------------------------------------------------

    applyScale()

    applyAxisCorrection()


    initialized = true


    ac.log(
        '[RealVisor] v0.2.1 initialized'
    )


    return true
end


------------------------------------------------------------
-- Update camera transform
------------------------------------------------------------
local prevPos = nil
local textDebugDeltaPos = nil
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
        ac.log(
            '[RealVisor] ' .. textDebugDeltaPos
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

            -- textDebugRotation = '[RealVisor] world rotation: ' .. string.format('%.2f°', angleDeg)
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

            textDebugCamRotation = 'World-Cam Pitch: ' .. string.format('%.1f°', pitchDeg)
                                .. ', Yaw: ' .. string.format('%.1f°', yawDeg)
                                .. ' | Fwd Vec (' .. string.format('%.3f', fwd.x) 
                                .. ', ' .. string.format('%.3f', fwd.y) 
                                .. ', ' .. string.format('%.3f', fwd.z) .. ')'

            ac.log(
                '[RealVisor] ' .. textDebugCamRotation
            )
        end
        prevForward = forward
    end


    --------------------------------------------------------
    -- Position
    --------------------------------------------------------

    cameraRoot:setPosition(
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
        return
    end


    --------------------------------------------------------
    -- Visibility
    --------------------------------------------------------

    visor:setVisible(
        cfg.enabled
    )


    if not cfg.enabled then
        -- ac.log('[RealVisor] cfg.enabled = false update terminated')
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
        'Real Visor Overlay v0.2.1'
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
            '[RealVisor] Visor ' .. (cfg.enabled and 'Enabled' or 'Disabled')
        )
    end        


    --------------------------------------------------------
    -- Scale
    --------------------------------------------------------

    ui.separator()

    ui.text('Model Scale')

    changed = nil
    cfg.modelScale, changed =
        ui.slider(

            'Scale',

            cfg.modelScale,

            0.005,

            0.05,

            '%.4f'
        )

    if changed then
        ac.log(
            '[RealVisor] KN5 Global Scale: ' .. cfg.modelScale
        )
    end

    --------------------------------------------------------
    -- Axis
    --------------------------------------------------------

    ui.separator()

    ui.text('Axis Correction')

    changed = nil
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
            '[RealVisor] KN5 Yaw: ' .. cfg.modelYawDeg
        )
    end

    --------------------------------------------------------
    -- Offset
    --------------------------------------------------------

    ui.separator()

    ui.text('Camera Local Offset')


    changed = nil
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
            '[RealVisor] KN5 Camera Offset(Right): ' .. cfg.offset.x
        )
    end

    changed = nil
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
            '[RealVisor] KN5 Camera Offset(Up): ' .. cfg.offset.y
        )
    end

    changed = nil
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
            '[RealVisor] KN5 Camera Offset(Forward): ' .. cfg.offset.z
        )
    end

    --------------------------------------------------------
    -- Glass debug
    --------------------------------------------------------

    ui.separator()
    ui.text('Model Config')
    ui.text(
        visorGlass
            and #visorGlass > 0
            and 'VISOR_GLASS: FOUND'
            or 'VISOR_GLASS: NOT FOUND'
    )


    --------------------------------------------------------
    -- Runtime info
    --------------------------------------------------------

    ui.text(

        string.format(

            'Scale: %.4f',

            cfg.modelScale
        )
    )

    
    --------------------------------------------------------
    -- Debug Log
    --------------------------------------------------------

    changed = nil
    changed, _ = ui.checkbox(

        '[Log] position delta',

        cfg.debugDeltapos
    )

    if changed then
        cfg.debugDeltapos = not cfg.debugDeltapos
    end     
    if textDebugDeltaPos then 
        ui.text('       *LastDelta: ' .. textDebugDeltaPos)
    end
    
    
    changed = nil
    changed, _ = ui.checkbox(

        '[Log] world rotation',

        cfg.debugRotation
    )

    if changed then
        cfg.debugRotation = not cfg.debugRotation
    end     

    if textDebugCamRotation then
        ui.text('          ' .. textDebugCamRotation)
    end
    
end