------------------------------------------------------------
-- Real Visor Overlay
-- Prototype v0.2.0
--
-- Author: saltyH
-- Target: CSP 0.3.0-preview500+
--
-- KN5:
-- visors/visor_lando.kn5
------------------------------------------------------------


------------------------------------------------------------
-- Configuration
------------------------------------------------------------

local cfg = {

    enabled = true,


    --------------------------------------------------------
    -- Visor KN5
    --------------------------------------------------------

    modelPath = 'visors/visor_lando.kn5',


    --------------------------------------------------------
    -- Model Axis Correction
    --
    -- Test result:
    -- -90° horizontal correction required.
    --------------------------------------------------------

    modelYawDeg = -90.0,

    
    --------------------------------------------------------
    -- Camera Local Offset
    --
    -- X = Camera Right
    -- Y = Camera Up
    -- Z = Camera Forward
    --------------------------------------------------------

    offset = vec3(
        0.0,
        0.0,
        0.08
    ),


    --------------------------------------------------------
    -- Scale
    --------------------------------------------------------

    modelScale = 0.019,


    --------------------------------------------------------
    -- Motion prototype
    --------------------------------------------------------
    enableMotion = false,
    dynamicMotion = false,


    --------------------------------------------------------
    -- Motion: Global intensity
    --------------------------------------------------------

    motionMultiplier = 1.0,


    --------------------------------------------------------
    -- Motion: Vehicle acceleration response
    --------------------------------------------------------

    lateralMultiplier = 0.002,
    verticalMultiplier = 0.001,
    longitudinalMultiplier = 0.003,


    --------------------------------------------------------
    -- Motion: Spring
    --------------------------------------------------------

    springStrength = 35.0,
    springDamping = 8.0
}


------------------------------------------------------------
-- Scene References
------------------------------------------------------------

local sceneRoot = nil

local cameraAnchor = nil
local motionNode = nil
local scaleNode = nil
local axisNode = nil

local visor = nil


------------------------------------------------------------
-- Runtime State
------------------------------------------------------------

local initialized = false

local lastScale = -1.0
local lastYaw = 99999.0


------------------------------------------------------------
-- Dynamic motion state
------------------------------------------------------------

local motion = {

    position = vec3(0, 0, 0),

    velocity = vec3(0, 0, 0),

    target = vec3(0, 0, 0)
}


------------------------------------------------------------
-- Camera Basis
--
-- Camera API:
-- ac.getCameraPosition()
-- ac.getCameraForward()
--
-- Right / Up are temporarily reconstructed from Forward.
------------------------------------------------------------

local function getCameraBasis()

    local forward = ac.getCameraForward()

    forward:normalize()


    --------------------------------------------------------
    -- World Up (Temporary)
    --------------------------------------------------------

    local worldUp = vec3(0, 1, 0)


    --------------------------------------------------------
    -- Right
    --------------------------------------------------------

    local right = forward:cross(worldUp)

    if right:lengthSquared() < 0.00001 then

        right = vec3(1, 0, 0)

    else

        right:normalize()

    end


    --------------------------------------------------------
    -- Reconstruct Up
    --------------------------------------------------------

    local up = right:cross(forward)
    up:normalize()


    return right, up, forward
end


------------------------------------------------------------
-- Apply Model Scale
--
-- Scale is isolated into its own node.
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

        lastScale = cfg.modelScale
    end
end


------------------------------------------------------------
-- Apply Model Axis Correction
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
-- Scene initialization
------------------------------------------------------------

local function initializeScene()
    

    --------------------------------------------------------
    -- Find cars root
    --------------------------------------------------------

    sceneRoot = ac.findNodes('carsRoot:yes')


    if sceneRoot == nil or #sceneRoot == 0 then

        ac.warn(
            '[RealVisor] carsRoot not found'
        )

        return false
    end

    --------------------------------------------------------
    -- Camera Anchor
    --
    -- Bounding sphere node is used for efficient hierarchy.
    --
    -- Radius is deliberately generous while calibration
    -- is still ongoing.
    --------------------------------------------------------

    cameraAnchor = sceneRoot:createBoundingSphereNode(
        'REALVISOR_CAMERA_ANCHOR',
        5.0
    )

    if cameraAnchor == nil then
        ac.warn('[RealVisor] Camera anchor creation failed')
        return false
    end


    --------------------------------------------------------
    -- Motion Node
    --------------------------------------------------------

    motionNode =
        cameraAnchor:createNode(
            'REALVISOR_MOTION'
        )


    if not motionNode then

        ac.warn(
            '[RealVisor] Motion node creation failed'
        )

        return false
    end


    --------------------------------------------------------
    -- Scale Node
    --------------------------------------------------------

    scaleNode =
        motionNode:createNode(
            'REALVISOR_SCALE'
        )


    if not scaleNode then

        ac.warn(
            '[RealVisor] Scale node creation failed'
        )

        return false
    end


    --------------------------------------------------------
    -- Axis Correction Node
    --------------------------------------------------------

    axisNode =
        scaleNode:createNode(
            'REALVISOR_AXIS'
        )


    if not axisNode then

        ac.warn(
            '[RealVisor] Axis node creation failed'
        )

        return false
    end


    --------------------------------------------------------
    -- Load KN5 as child(Anchor)
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
    -- Important:
    --
    -- Real Visor is a camera overlay.
    -- It should NOT cast world shadows.
    --------------------------------------------------------

    local allMeshes =
        visor:findMeshes('*')


    if #allMeshes > 0 then

        allMeshes:setShadows(true)

        ac.log(
            '[RealVisor] Any Mesh matches * found'
        )

    else
        ac.warn(
            '[RealVisor] Matches * not found'
        )
    end


    --------------------------------------------------------
    -- Apply initial transforms
    --------------------------------------------------------

    applyScale()

    applyAxisCorrection()


    --------------------------------------------------------
    -- VISOR_GLASS reference
    --
    -- No rendering modification is performed here.
    --
    -- This only prepares the architecture for
    -- future mesh-specific work.
    --------------------------------------------------------

    local visorGlass =
        visor:findMeshes(
            'VISOR_GLASS'
        )


    if #visorGlass > 0 then

        ac.log(
            '[RealVisor] VISOR_GLASS found'
        )

        ac.log(
            '[RealVisor] Material: '
            .. visorGlass:materialName()
        )

        ac.log(
            '[RealVisor] Shader: '
            .. visorGlass:shaderName()
        )

        visorGlass:setVisible(true)

    else

        ac.warn(
            '[RealVisor] VISOR_GLASS not found'
        )

    end


    --------------------------------------------------------
    -- AABB Debug
    --------------------------------------------------------

    local minAABB,
          maxAABB,
          meshCount =
        visor:getLocalAABB()


    ac.log(

        string.format(

            '[RealVisor] Mesh count: %d',
            meshCount or 0
        )
    )


    if minAABB and maxAABB then

        ac.log(

            string.format(

                '[RealVisor] Local AABB '
                .. 'Min=(%.3f, %.3f, %.3f) '
                .. 'Max=(%.3f, %.3f, %.3f)',

                minAABB.x,
                minAABB.y,
                minAABB.z,

                maxAABB.x,
                maxAABB.y,
                maxAABB.z
            )
        )
    end


    initialized = true


    ac.log(
        '[RealVisor] v0.2 initialized'
    )


    return true
end


------------------------------------------------------------
-- Motion
--
-- Currently disabled by default.
--
-- Structure is retained for v0.3.
------------------------------------------------------------

local function updateMotion(dt)

    if not cfg.enableMotion then

        motion.position:set(
            0,
            0,
            0
        )

        motion.velocity:set(
            0,
            0,
            0
        )

        motion.target:set(
            0,
            0,
            0
        )

        return
    end


    --------------------------------------------------------
    -- Future implementation point
    --------------------------------------------------------

end


------------------------------------------------------------
-- Update Camera Anchor
------------------------------------------------------------

local function updateCameraTransform()


    --------------------------------------------------------
    -- Camera Position
    --------------------------------------------------------

    local cameraPosition =
        ac.getCameraPosition()


    --------------------------------------------------------
    -- Camera Orientation
    --------------------------------------------------------

    local right,
          up,
          forward =
        getCameraBasis()


    --------------------------------------------------------
    -- Anchor World Position
    --------------------------------------------------------

    cameraAnchor:setPosition(
        cameraPosition
    )


    --------------------------------------------------------
    -- Anchor Orientation
    --------------------------------------------------------

    cameraAnchor:setOrientation(
        forward,
        up
    )
end


------------------------------------------------------------
-- Update Local Motion
------------------------------------------------------------

local function updateLocalTransform()


    --------------------------------------------------------
    -- Dynamic motion
    --------------------------------------------------------

    updateMotion(0)


    --------------------------------------------------------
    -- Base offset + motion
    --------------------------------------------------------

    local finalOffset =

        cfg.offset
        + motion.position


    --------------------------------------------------------
    -- This position is LOCAL
    --
    -- Parent is already camera-aligned.
    --------------------------------------------------------

    motionNode:setPosition(
        finalOffset
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


    --------------------------------------------------------
    -- Safety
    --------------------------------------------------------

    if not visor then
        return
    end


    --------------------------------------------------------
    -- Model visibility
    --------------------------------------------------------

    visor:setVisible(
        cfg.enabled
    )


    if not cfg.enabled then
        return
    end


    --------------------------------------------------------
    -- Camera Anchor
    --------------------------------------------------------

    updateCameraTransform()


    --------------------------------------------------------
    -- Model Parameters
    --------------------------------------------------------

    applyScale()

    applyAxisCorrection()


    --------------------------------------------------------
    -- Dynamic motion
    --------------------------------------------------------

    updateDynamicMotion(
        dt,
        right,
        up,
        forward
    )


    --------------------------------------------------------
    -- Motion
    --------------------------------------------------------

    updateMotion(dt)


    local finalOffset =

        cfg.offset
        + motion.position


    motionNode:setPosition(
        finalOffset
    )
end


------------------------------------------------------------
-- Main Window
------------------------------------------------------------

function windowMain(dt)

    ui.text('Real Visor Overlay v0.2')

    ui.separator()


    --------------------------------------------------------
    -- Status
    --------------------------------------------------------

    ui.text(
        initialized
            and 'Status: ACTIVE'
            or 'Status: INITIALIZING'
    )


    ui.separator()

    --------------------------------------------------------
    -- Enable
    --------------------------------------------------------

    cfg.enabled =
        ui.checkbox(
            'Enable Real Visor',
            cfg.enabled
        )


     --------------------------------------------------------
    -- Scale
    --------------------------------------------------------

    ui.separator()

    ui.text('Model Scale')


    cfg.modelScale =
        ui.slider(

            'Scale',

            cfg.modelScale,

            0.005,

            1.0,

            '%.4f'
        )


    --------------------------------------------------------
    -- Axis
    --------------------------------------------------------

    ui.separator()

    ui.text('Model Axis Correction')


    cfg.modelYawDeg =
        ui.slider(

            'Yaw',

            cfg.modelYawDeg,

            -180.0,

            180.0,

            '%.1f°'
        )


    --------------------------------------------------------
    -- Camera Local Offset
    --------------------------------------------------------

    ui.separator()

    ui.text('Camera Local Offset')


    cfg.offset.x =
        ui.slider(

            'Right',

            cfg.offset.x,

            -1.0,

            1.0,

            '%.4f m'
        )


    cfg.offset.y =
        ui.slider(

            'Up',

            cfg.offset.y,

            -1.0,

            1.0,

            '%.4f m'
        )


    cfg.offset.z =
        ui.slider(

            'Forward',

            cfg.offset.z,

            -0.5,

            1.0,

            '%.4f m'
        )


    --------------------------------------------------------
    -- Motion
    --------------------------------------------------------

    ui.separator()

    ui.text('Dynamic Motion')


    cfg.enableMotion =
        ui.checkbox(

            'Enable Motion Prototype',

            cfg.enableMotion
        )


    if cfg.enableMotion then

        ui.textWrapped(

            'G-force motion is reserved '
            .. 'for the next implementation stage.'
        )

    end


    --------------------------------------------------------
    -- Debug Information
    --------------------------------------------------------

    ui.separator()

    ui.text('Debug')


    ui.text(
        string.format(

            'Scale: %.4f',

            cfg.modelScale
        )
    )


    ui.text(
        string.format(

            'Yaw: %.1f°',

            cfg.modelYawDeg
        )
    )
end