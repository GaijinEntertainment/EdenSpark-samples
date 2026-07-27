require engine.core
require daslib/strings_boost
require terrain
require driving_assists

var statusNode : NodeId
var status2Node : NodeId
var statusOutputNode : NodeId

let VEHICLE_LIST : array<tuple<name : string; prefab : PrefabId>> = [
    (name = "sedan", prefab = request_prefab("sedan.prefab")),
    (name = "suv", prefab = request_prefab("suv.prefab")),
    (name = "race", prefab = request_prefab("race.prefab"))
]

let CAR_KEYS = [KeyCode._0, KeyCode._1, KeyCode._2, KeyCode._3, KeyCode._4, KeyCode._5, KeyCode._6, KeyCode._7, KeyCode._8, KeyCode._9]

let TEST_SCENE = request_prefab("test_scene.prefab")

var playerVehicle : NodeId
var playerCamera : NodeId
var assistsEnabled : bool = true
var currentVehicleIndex : int = 1

class VehicleCamera : Component {
    vehicle : NodeId
    orbitMode : bool = true
    // orbit mode
    private yaw : float = 0.
    private pitch : float = deg_to_rad(20.)
    distance : float = 7.
    private centerOffset : float3 = float3(0., 1.5, 0.)
    // auto-follow mode
    private cameraRotationAngle : float = 0.
    xRotation : float = deg_to_rad(22.0)
    offset : float3 = float3(0, 2.2, -3)

    def override on_initialize() {
        if (!!vehicle) {
            yaw = quat_to_euler(vehicle.worldRotation).y
            cameraRotationAngle = yaw
        }
        set_mouse_cursor_locked(true)
    }

    def override on_update() {
        if (!vehicle) {
            return
        }

        if (is_action_just_pressed("toggleCamera")) {
            orbitMode = !orbitMode
            if (orbitMode) {
                yaw = quat_to_euler(nodeId.worldRotation).y
                set_mouse_cursor_locked(true)
            } else {
                cameraRotationAngle = quat_to_euler(nodeId.worldRotation).y
                set_mouse_cursor_locked(false)
            }
        }

        if (orbitMode) {
            if (is_mouse_cursor_locked()) {
                let mouseDelta = get_action_vector2("cameraAim") * 0.001
                yaw += mouseDelta.x
                pitch = clamp(pitch + mouseDelta.y, deg_to_rad(-20.), deg_to_rad(70.))
                distance = clamp(distance * pow(1.2, -get_action_axis("cameraZoom")), 2., 20.)
            }
            let dir = quat4(pitch, yaw, 0.) * BACKWARD
            let camCenter = vehicle.worldPosition + centerOffset
            nodeId.worldPosition = camCenter + dir * distance
            nodeId.worldRotation = quat4(pitch, yaw, 0.)
        } else {
            nodeId.worldPosition = vehicle.worldPosition + cross(vehicle.localRight, UP) * offset.z + cross(-vehicle.localForward, UP) * offset.x + UP * offset.y
            let goalCameraRotationAngle = quat_to_euler(vehicle.worldRotation).y
            cameraRotationAngle = angle_approach(cameraRotationAngle, goalCameraRotationAngle, get_delta_time(), 0.1)
            let camAngleDiff = angle_diff(cameraRotationAngle, goalCameraRotationAngle)
            let maxAngleDiff = deg_to_rad(5.)
            if (camAngleDiff > maxAngleDiff) {
                cameraRotationAngle = goalCameraRotationAngle - maxAngleDiff
            } elif (camAngleDiff < -maxAngleDiff) {
                cameraRotationAngle = goalCameraRotationAngle + maxAngleDiff
            }
            nodeId.worldRotation = quat4(xRotation, cameraRotationAngle, 0)
        }
    }
}

class VehicleInput : Component {
    handbrake : bool
    isManual : bool = false

    tractionControlAssist : TractionControlAssist = TractionControlAssist()
    absAssist : AbsAssist = AbsAssist()
    stabilityControlAssist : StabilityControlAssist = StabilityControlAssist()
    corneringLimiterAssist : CorneringSpeedLimiterAssist = CorneringSpeedLimiterAssist()
    unstuckAssist : UnstuckAssist = UnstuckAssist()

    private smoothedGas : float = 0.0
    private smoothedBrake : float = 0.0

    isForward : bool = true
    private wasBraking : bool = false

    def override on_update() {
        if (!has_component(nodeId, type<VehicleController>)) {
            return
        }
        var vc = get_component(nodeId, type<VehicleController>)
        var rb = get_component(nodeId, type<RigidBody>)
        let dt = get_delta_time()

        update_driving_input(vc, rb, dt)
        if (assistsEnabled) {
            apply_assists(vc, rb, dt)
        }
        update_labels(vc, rb)
    }

    def private update_driving_input(var vc : VehicleController?; rb : RigidBody?; dt : float) {
        let rawGasKeys = get_action_axis("gasKeys")
        let rawGasStick = get_action_axis("gasStick")
        let rawGas = clamp(rawGasKeys + rawGasStick, -1., 1.)
        let gasRate = abs(rawGasStick) > 0.05 ? 12. : 1.
        let brakeRate = abs(rawGasStick) > 0.05 ? 20. : 10.
        let brakePressed = rawGas < -0.1

        let rawSteerKeys = get_action_axis("steeringKeys")
        let rawSteerStick = get_action_axis("steeringStick")
        let rawSteer = clamp(rawSteerKeys + rawSteerStick, -1., 1.)
        let steerRate = 5.

        if (is_action_just_pressed("handbrake")) {
            handbrake = !handbrake
        }

        if (is_action_just_pressed("toggleAssists")) {
            assistsEnabled = !assistsEnabled
        }

        if (is_action_just_pressed("gearMode")) {
            isManual = !isManual
            vc.isAutomatic = !isManual
        }

        if (isManual) {
            let currentGear = vc.currentGear
            let maxGear = vc.gearRatios.length()
            let minGear = -vc.reverseGearRatios.length()
            if (is_action_just_pressed("gearUp")) {
                vc.currentGear = min(currentGear + 1, maxGear)
            }
            if (is_action_just_pressed("gearDown")) {
                vc.currentGear = max(currentGear - 1, minGear)
            }
            let clutchTarget = is_action_pressed("clutch") ? 0. : 1.
            vc.clutchInput = move_to(vc.clutchInput, clutchTarget, dt, 5.)
            smoothedGas = move_to(smoothedGas, max(rawGas, 0.), dt, gasRate)
            smoothedBrake = move_to(smoothedBrake, max(-rawGas, 0.), dt, brakeRate)
        } else {
            // Automatic
            let forwardSpeed = dot(rb.velocity * float3(1, 0, 1), nodeId.localRotation * FORWARD)
            if (forwardSpeed > 0.01) {
                isForward = true
                smoothedGas = move_to(smoothedGas, max(rawGas, 0.), dt, gasRate)
                smoothedBrake = move_to(smoothedBrake, max(-rawGas, 0.), dt, brakeRate)
            } elif (forwardSpeed < -0.01) {
                isForward = false
                smoothedGas = move_to(smoothedGas, rawGas, dt, gasRate)
                smoothedBrake = move_to(smoothedBrake, max(rawGas, 0.), dt, brakeRate)
            } else {
                if (isForward) {
                    if (brakePressed && !wasBraking) {
                        isForward = false
                    }
                } elif (!brakePressed) {
                    isForward = true
                }

                smoothedGas = move_to(smoothedGas, isForward ? max(rawGas, 0.) : min(rawGas, 0.), dt, gasRate)
                smoothedBrake = move_to(smoothedBrake, 0., dt, brakeRate)
            }
        }
        wasBraking = brakePressed

        vc.steeringInput = move_to(vc.steeringInput, rawSteer, dt, steerRate)
        vc.handbrakeInput = move_to(vc.handbrakeInput, handbrake ? 1. : 0., dt, 10.)

        vc.gasInput = smoothedGas
        vc.brakeInput = smoothedBrake
    }

    def private apply_assists(var vc : VehicleController?; var rb : RigidBody?; dt : float) {
        let speed = dot(rb.velocity * float3(1, 0, 1), nodeId.localRotation * FORWARD)
        absAssist.apply_assist(vc, speed)
        unstuckAssist.apply_assist(vc, rb, nodeId, speed)

        let isDrifting = abs(vc.steeringInput) > 0.1 && abs(rb.angularVelocity.y) > 0.5 && sign(vc.steeringInput) != sign(rb.angularVelocity.y)
        if (vc.handbrakeInput < 0.5 && !isDrifting) {
            tractionControlAssist.apply_assist(vc, speed)
            stabilityControlAssist.apply_assist(vc, rb, speed, dt)
            corneringLimiterAssist.apply_assist(vc, speed)
        }
    }

    def private update_labels(vc : VehicleController?; rb : RigidBody?) {
        let MSEC_TO_KMH = 3600. / 1000.
        let currentGear = vc.currentGear
        let gearLabel = currentGear == 0 ? "N" : (currentGear > 0 ? "{currentGear}" : "R")
        let modeLabel = isManual ? "Manual" : "Auto"

        var wheelSpeedsText = ""
        for (wIdx in range(vc.wheels.length())) {
            let kmh = floor(vc.wheels[wIdx].linearSpeed() * MSEC_TO_KMH)
            wheelSpeedsText = wIdx == 0 ? "{kmh}" : "{wheelSpeedsText}, {kmh}"
        }

        let gas = abs(smoothedGas)
        let brake = smoothedBrake
        let steer = vc.steeringInput
        let handbrakeVal = vc.handbrakeInput
        let clutchVal = vc.clutchInput

        let clutchLine = isManual ? "\nClutch   : [{clutchVal>0.1?"|":" "}{clutchVal>0.3?"|":" "}{clutchVal>0.5?"|":" "}{clutchVal>0.7?"|":" "}{clutchVal>0.9?"|":" "}] (press V)" : ""
        let assistsLine = "\nAssists  : {assistsEnabled ? "ON" : "OFF"} (press Z)"
        update_debug_text(statusNode,
"Gas      : [{gas>0.1?"|":" "}{gas>0.3?"|":" "}{gas>0.5?"|":" "}{gas>0.7?"|":" "}{gas>0.9?"|":" "}] (press W/Up)
Steering : [{steer < -0.9?"|":" "}{steer < -0.7?"|":" "}{steer < -0.5?"|":" "}{steer < -0.3?"|":" "}{steer < -0.1?"|":" "}{steer>0.1?"|":" "}{steer>0.3?"|":" "}{steer>0.5?"|":" "}{steer>0.7?"|":" "}{steer>0.9?"|":" "}] (press A/D/Left/Right)
Brake    : [{brake>0.1?"|":" "}{brake>0.3?"|":" "}{brake>0.5?"|":" "}{brake>0.7?"|":" "}{brake>0.9?"|":" "}] (press S/Down)
Handbrake: [{handbrakeVal>0.1?"|":" "}{handbrakeVal>0.3?"|":" "}{handbrakeVal>0.5?"|":" "}{handbrakeVal>0.7?"|":" "}{handbrakeVal>0.9?"|":" "}] (press Space to toggle){clutchLine}{assistsLine}")

        update_debug_text(statusOutputNode,
"RPM: {floor(vc.currentRPM)}
Gear: {gearLabel} | Mode: {modeLabel}{isManual ? " (press Q/E to change)" : " (press Tab to change)"}
Speed: {floor((rb.velocity * float3(1,0,1)).length() * MSEC_TO_KMH)} km/h
Wheels (km/h): {wheelSpeedsText}")
    }
}

[export] def on_initialize() {
    statusNode = create_debug_text(float2(20, -20), BOTTOM_LEFT_ANCHOR)
    statusNode?.UIText.color = BLACK_COLOR

    status2Node = create_debug_text(float2(20, 20), TOP_LEFT_ANCHOR)
    status2Node?.UIText.color = BLACK_COLOR

    statusOutputNode = create_debug_text(float2(-20, -20), BOTTOM_RIGHT_ANCHOR)
    statusOutputNode?.UIText.color = BLACK_COLOR

    update_debug_text(status2Node, "0 - init_procedural_vehicle()\n1 - sedan\n2 - suv\n3 - race")

    init_lights()
    init_input()
    spawn_terrain()
    playerVehicle = VEHICLE_LIST[0].prefab.instantiate_prefab(NodeData(position = float3(0, 10, 0)))
    add_component(playerVehicle, new VehicleInput())

    playerCamera = create_node(NodeData(name = "camera"))
    add_component(playerCamera, new Camera())
    add_component(playerCamera, new VehicleCamera(vehicle = playerVehicle))

    TEST_SCENE.instantiate_prefab(NodeData(position = float3(0, 0.05, 0)))

    set_physics_fps(100f)
}

[export] def on_update() {
    handle_car_change()
}

def init_input() {
    var actionSet : ActionSet = {
        "gasKeys" => Action(
            axisActions = AxisAction(
                keyboardAxis = [KeyboardBtnAxisInput(positiveIdx=KeyCode.Up, negativeIdx=KeyCode.Down),
                                KeyboardBtnAxisInput(positiveIdx=KeyCode.W, negativeIdx=KeyCode.S)],
            )
        ),
        "steeringKeys" => Action(
            axisActions = AxisAction(
                keyboardAxis = [KeyboardBtnAxisInput(positiveIdx=KeyCode.Right, negativeIdx=KeyCode.Left),
                                KeyboardBtnAxisInput(positiveIdx=KeyCode.D, negativeIdx=KeyCode.A)],
            )
        ),
        "gasStick" => Action(
            axisActions = AxisAction(
                stickAxis = [GamepadAxisInput(idx=GamepadAxis.LRTrigger)]
            )
        ),
        "steeringStick" => Action(
            axisActions = AxisAction(
                stickAxis = [GamepadAxisInput(idx=GamepadAxis.LThumbH)]
            )
        ),
        "handbrake" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.X)]
            )
        ),
        "cameraAim" => Action(
            pointerActions = PointerAction(
                valueType = ValueType.Delta,
                mouse = MouseInput(active = true),
                gamepadPointers = [GamepadPointerInput(xIdx=GamepadAxis.RThumbH, yIdx=GamepadAxis.RThumbV, isYInverted=true, sensitivity=20.0)]
            )
        ),
        "cameraZoom" => Action(
            axisActions = AxisAction(
                mouseAxis = [MouseBtnAxisInput(positiveIdx=MouseButton.WheelUp, negativeIdx=MouseButton.WheelDown)]
            )
        ),
        "toggleCamera" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.C)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.L3)]
            )
        ),
        "nextVehicle" => Action(
            buttonActions = ButtonAction(
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Y)]
            )
        ),
        "gearMode" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Tab)]
            )
        ),
        "toggleAssists" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Z)]
            )
        ),
        "clutch" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.V)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.B)]
            )
        ),
        "gearUp" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.E)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.RightBumper)]
            )
        ),
        "gearDown" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Q)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.LeftBumper)]
            )
        ),
    }

    for (idx in range(VEHICLE_LIST.length() + 1)) {
        actionSet.emplace("car{idx}", Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=CAR_KEYS[idx])]
            )
        ))
    }

    add_and_activate_action_set("playerInput", actionSet)
}

def spawn_vehicle(idx : int) {
    currentVehicleIndex = idx
    var pos = playerVehicle.localPosition + UP * 2.
    var forward = playerVehicle.localRotation * FORWARD
    if (length(forward) == 0.) {
        forward = FORWARD
    }
    let rot = make_quat_from_basis_zy(forward, UP)
    playerVehicle.remove_node()
    if (idx == 0) {
        playerVehicle = init_procedural_vehicle()
        playerVehicle.worldPosition = pos
        playerVehicle.worldRotation = rot
    } else {
        playerVehicle = VEHICLE_LIST[idx - 1].prefab.instantiate_prefab(NodeData(position = pos, rotation = rot))
    }
    add_component(playerVehicle, new VehicleInput())
    playerCamera?.VehicleCamera.vehicle = playerVehicle
}

def handle_car_change() {
    if (is_action_just_pressed("car0")) {
        spawn_vehicle(0)
        return
    }

    for (idx in range(VEHICLE_LIST.length())) {
        if (is_action_just_pressed("car{idx + 1}")) {
            spawn_vehicle(idx + 1)
            return
        }
    }

    if (is_action_just_pressed("nextVehicle")) {
        spawn_vehicle((currentVehicleIndex + 1) % (VEHICLE_LIST.length() + 1))
    }
}

let wheelMaterial = create_material(MaterialImport(shaderName = "standard_unlit_shader", diffuse = request_texture("%builtin_package/logo.png")))
def init_procedural_vehicle() {
    let newVehicle = create_node(NodeData(name = "vehicle", position = float3(0, 10, 0)))
    add_component(newVehicle, new VehicleController())
    get_component(newVehicle) $(var vc : VehicleController?) {
        vc.wheels[0].position = float3(-1, 0, 1)
        vc.wheels[0].maxSteeringAngle = deg_to_rad(30.)

        vc.wheels[1].position = float3(1, 0, 1)
        vc.wheels[1].maxSteeringAngle = deg_to_rad(30.)

        vc.wheels[2].position = float3(-1, 0, -1)

        vc.wheels[3].position = float3(1, 0, -1)
    }

    for (wIdx in range(newVehicle?.VehicleController.wheels.length())) {
        var w = newVehicle?.VehicleController.wheels[wIdx]
        let wheelNode = create_node(NodeData(name = "wheel{wIdx}", parent = newVehicle, position = w.position))
        let cylinder = create_node(NodeData(name = "cylinder", parent = wheelNode, rotation = quat4(0, 0, HALF_PI), scale = float3(0.5, 0.05, 0.5)))
        add_component(cylinder, new Mesh(meshId = CYLINDER_MESH_ID, color = WHITE_COLOR, materialId = wheelMaterial))
        w.visualNode = wheelNode
    }

    let bodyVisual = create_node(NodeData(name = "body", parent = newVehicle, scale = float3(2, 1, 2)))
    add_component(bodyVisual, new Mesh(meshId = CUBE_MESH_ID))
    add_component(newVehicle, new Collider(shape = box_shape(float3(2, 1, 2)), friction = 1.))
    add_component(newVehicle, new RigidBody(mass = 1500.))

    return newVehicle
}

def init_lights() {
    let sunDirection = float3(PI / 3f, -PI * 0.25f, 0f)
    let sun = create_node(NodeData(rotation = quat4(sunDirection)))
    add_component(sun, new DirectionLight())

    let renderSettings = create_render_settings()

    get_component(renderSettings) $(var shadow : ShadowSettings?) {
        shadow.powWeight = 0.8f
        shadow.maxDist = 100f
        shadow.numCascades = 4
    }

    get_component(renderSettings) $(var ssao : SSAOSettings?) {
        ssao.mode = SSAOMode.Immediate
        ssao.method = SSAOMethod.SSAO
    }
}

