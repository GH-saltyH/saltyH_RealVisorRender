------------------------------------------------------------
-- Real Visor Overlay
-- Prototype v0.1.0
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
    -- KN5
    --------------------------------------------------------

    modelPath = 'visors/visor_lando.kn5',


    --------------------------------------------------------
    -- Camera-relative base transform
    --
    -- X = Right
    -- Y = Up
    -- Z = Forward
    --------------------------------------------------------

    offset = vec3(
        0.0,
        0.0,
        0.08
    ),


    --------------------------------------------------------
    -- Scale
    --------------------------------------------------------

    scale = 1.0,


    --------------------------------------------------------
    -- Motion prototype
    --------------------------------------------------------

    dynamicMotion = false,


    --------------------------------------------------------
    -- Global intensity
    --------------------------------------------------------

    motionMultiplier = 1.0,


    --------------------------------------------------------
    -- Vehicle acceleration response
    --------------------------------------------------------

    lateralMultiplier = 0.002,
    verticalMultiplier = 0.001,
    longitudinalMultiplier = 0.003,


    --------------------------------------------------------
    -- Spring
    --------------------------------------------------------

    springStrength = 35.0,
    springDamping = 8.0
}


------------------------------------------------------------
-- Runtime
------------------------------------------------------------

local visor = nil
local sceneRoot = nil
local cameraAnchor = nil

local initialized = false
local loadAttempted = false


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
    -- World Up
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
-- Scene initialization
------------------------------------------------------------

local function initializeScene()

    if initialized then
        return true
    end


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

    ------------------------------------------------
    -- Camera Anchor 생성
    ------------------------------------------------

    cameraAnchor = sceneRoot:createBoundingSphereNode(
        'REALVISOR_CAMERA_ANCHOR',
        1000.0
    )

    if cameraAnchor == nil then
        ac.warn('[RealVisor] Failed to create anchor')
        return false
    end

    --------------------------------------------------------
    -- Load KN5 as child(Anchor)
    --------------------------------------------------------

    visor = sceneRoot:loadKN5({
        filename = cfg.modelPath,
        forceRenderableOn = true
    })


    if visor == nil then

        ac.warn(
            '[RealVisor] Failed to load KN5: '
            .. cfg.modelPath
        )

        return false
    end

    ------------------------------------------------
    -- 불필요한 Shadow 제거
    ------------------------------------------------

    visor:setShadows(false)


    ------------------------------------------------
    -- 모델 축 보정
    --
    -- 테스트 결과 -90° 필요
    ------------------------------------------------

    visor:setRotation(
        vec3(0, 1, 0),
        math.rad(-90)
    )


    visor:clearMotion()



    

    initialized = true


    ac.log(
        '[RealVisor] visor_lando.kn5 loaded'
    )


    return true
end


------------------------------------------------------------
-- Get vehicle acceleration
--
-- This function intentionally isolates vehicle motion access.
--
-- API field verification will be the next refinement stage.
------------------------------------------------------------

local function getVehicleAcceleration()

    local car = ac.getCar(0)


    if car == nil then
        return vec3(0, 0, 0)
    end


    --------------------------------------------------------
    -- Prototype fallback
    --------------------------------------------------------

    if car.acceleration ~= nil then
        return car.acceleration
    end


    return vec3(0, 0, 0)
end


------------------------------------------------------------
-- Dynamic motion
------------------------------------------------------------

local function updateDynamicMotion(dt, right, up, forward)

    if not cfg.dynamicMotion then

        motion.position:set(0, 0, 0)
        motion.velocity:set(0, 0, 0)
        motion.target:set(0, 0, 0)

        return
    end


    --------------------------------------------------------
    -- Vehicle acceleration
    --------------------------------------------------------

    local acceleration =
        getVehicleAcceleration()


    --------------------------------------------------------
    -- Convert acceleration into camera space
    --------------------------------------------------------

    local lateral =
        acceleration:dot(right)


    local vertical =
        acceleration:dot(up)


    local longitudinal =
        acceleration:dot(forward)


    --------------------------------------------------------
    -- Target parallax offset
    --
    -- Negative direction creates inertial response.
    --------------------------------------------------------

    motion.target:set(

        -lateral
            * cfg.lateralMultiplier
            * cfg.motionMultiplier,

        -vertical
            * cfg.verticalMultiplier
            * cfg.motionMultiplier,

        -longitudinal
            * cfg.longitudinalMultiplier
            * cfg.motionMultiplier
    )


    --------------------------------------------------------
    -- Spring-damper
    --------------------------------------------------------

    local displacement =
        motion.target
        - motion.position


    local springForce =
        displacement
        * cfg.springStrength


    local dampingForce =
        motion.velocity
        * cfg.springDamping


    local accelerationForce =
        springForce
        - dampingForce


    motion.velocity =
        motion.velocity
        + accelerationForce * dt


    motion.position =
        motion.position
        + motion.velocity * dt
end


------------------------------------------------------------
-- Main update
------------------------------------------------------------

function script.update(dt)

    --------------------------------------------------------
    -- Initialize
    --------------------------------------------------------

    if not initialized then

        if not loadAttempted then

            loadAttempted = true

            initializeScene()

        end

        return
    end


    --------------------------------------------------------
    -- Model visibility
    --------------------------------------------------------

    if visor == nil then
        return
    end


    --------------------------------------------------------
    -- Camera
    --------------------------------------------------------

    local cameraPosition =
        ac.getCameraPosition()


    local right, up, forward =
        getCameraBasis()


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
    -- Final camera-relative offset
    --------------------------------------------------------

    local finalOffset =

        cfg.offset
        + motion.position


    --------------------------------------------------------
    -- Convert camera local space
    -- into world space
    --------------------------------------------------------

    local worldPosition =

        cameraPosition

        + right
            * finalOffset.x

        + up
            * finalOffset.y

        + forward
            * finalOffset.z


    --------------------------------------------------------
    -- Apply position
    --------------------------------------------------------

    visor:setPosition(
        worldPosition
    )


    --------------------------------------------------------
    -- Apply orientation
    --------------------------------------------------------

    visor:setOrientation(
        forward,
        up
    )
end


------------------------------------------------------------
-- Debug UI
------------------------------------------------------------

function windowMain(dt)

    ui.text('Real Visor Overlay')
    ui.separator()


    --------------------------------------------------------
    -- Enable
    --------------------------------------------------------

    cfg.enabled =
        ui.checkbox(
            'Enable visor',
            cfg.enabled
        )


    ui.separator()


    --------------------------------------------------------
    -- Base Offset
    --------------------------------------------------------

    ui.text('Camera Offset')


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
            2.0,
            '%.4f m'
        )


    --------------------------------------------------------
    -- Scale
    --------------------------------------------------------

    ui.separator()

    ui.text('Model')

    cfg.scale =
        ui.slider(
            'Scale',
            cfg.scale,
            0.1,
            5.0,
            '%.3f'
        )


    --------------------------------------------------------
    -- Dynamic motion
    --------------------------------------------------------

    ui.separator()

    ui.text('Dynamic Motion')


    cfg.dynamicMotion =
        ui.checkbox(
            'Enable G-Force Parallax',
            cfg.dynamicMotion
        )


    if cfg.dynamicMotion then

        cfg.motionMultiplier =
            ui.slider(
                'Overall Strength',
                cfg.motionMultiplier,
                0.0,
                5.0,
                '%.3f'
            )


        cfg.lateralMultiplier =
            ui.slider(
                'Lateral',
                cfg.lateralMultiplier,
                0.0,
                0.05,
                '%.5f'
            )


        cfg.verticalMultiplier =
            ui.slider(
                'Vertical',
                cfg.verticalMultiplier,
                0.0,
                0.05,
                '%.5f'
            )


        cfg.longitudinalMultiplier =
            ui.slider(
                'Longitudinal',
                cfg.longitudinalMultiplier,
                0.0,
                0.05,
                '%.5f'
            )


        ui.separator()


        cfg.springStrength =
            ui.slider(
                'Spring',
                cfg.springStrength,
                1.0,
                100.0,
                '%.1f'
            )


        cfg.springDamping =
            ui.slider(
                'Damping',
                cfg.springDamping,
                0.0,
                30.0,
                '%.1f'
            )
    end


    --------------------------------------------------------
    -- Runtime info
    --------------------------------------------------------

    ui.separator()

    ui.text(
        initialized
            and 'Status: KN5 loaded'
            or 'Status: Waiting'
    )
end