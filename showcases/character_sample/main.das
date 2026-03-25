require engine.core
require moving_platform
require gravityGun/pickup
require gravityGun/gravityGunComponent
require collision

var player1 : NodeId
var player2 : NodeId
var camera : NodeId
var statusNode : NodeId

var playerInertia : float3

[export]
def on_initialize() {
    init_collisions()

    // Add the scene
    let capsule = CAPSULE_MESH_ID
    let scenePrefab = request_prefab("scene.prefab")
    let sceneRoot = instantiate_prefab(scenePrefab)

    // Add the player
    player1 = create_node(NodeData(name = "player", position = float3(1, 3, 1)))
    add_component(player1, new CharacterController())
    add_component(player1, new Collider(shape = capsule_shape([translation = float3(0, 1., 0)]), collisionLayer = uint8(CollisionLayer.Player)))
    let player1_mesh = create_node(NodeData(name = "mesh", parent = player1, position = float3(0, 1, 0)))
    add_component(player1_mesh, new Mesh(meshId = capsule))
    let player1_front = create_node(NodeData(name = "front marker", parent = player1, position = UP * 1.5 + FORWARD, scale = float3(0.1, 0.1, 0.5)))
    add_component(player1_front, new Mesh(meshId = CUBE_MESH_ID))

    on_collision(player1) @(c) {
        if (abs(dot(c.normal, UP)) < cos(45. * TO_RAD)) {
            print("Collision with normal {c.normal}")
        }
    }

    // Add the second player
    player2 = create_node(NodeData(name = "player 2", position = float3(0, 3, 33)))
    add_component(player2, new CharacterController())
    add_component(player2, new Collider(shape = capsule_shape()))
    add_component(player2, new Mesh(meshId = capsule))

    // Add camera
    camera = create_node(NodeData(name = "camera"))
    add_component(camera, new Camera(fovAxis = FovAxis.Horizontal, fov = TO_RAD * 90f, znear = 0.1, zfar = 1000.))
    add_component(camera, new ThirdPersonCamera(centerNode = player1, centerOffset = float3(0, 1.5, 0)))
    add_component(camera, new GravityGunPickupHandler())

    // Add UI
    statusNode = create_debug_text(float2(20, -20), BOTTOM_LEFT_ANCHOR)
    get_component(statusNode) $(var text : UIText?) {
        text.color = color32_to_float4(0xFF000000)
    }

    add_and_activate_action_set("components", {
        "activate" => Action(
            buttonActions = ButtonAction(
                mouseButtons = [MouseButtonInput(idx=MouseButton.Left)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        ),
        "deactivate" => Action(
            buttonActions = ButtonAction(
                mouseButtons = [MouseButtonInput(idx=MouseButton.Right)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.B)]
            )
        ),
        "pickup" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.E)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Y)]
            )
        ),
        "keyboardOption1" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._1)],
            )
        ),
        "keyboardOption2" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._2)],
            )
        ),
        "keyboardOption3" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._3)],
            )
        ),
        "keyboardOption4" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._4)],
            )
        ),
        "keyboardOption5" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._5)],
            )
        ),
        "keyboardOption6" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._6)],
            )
        )
    })

    add_and_activate_action_set("player1", {
        "move1" => Action(
            joystickActions = JoystickAction(
                keyboardDPads = [KeyboardDPadInput(leftIdx=KeyCode.A, rightIdx=KeyCode.D, upIdx=KeyCode.W, downIdx=KeyCode.S)],
                gamepadDPads = [GamepadDPadInput(leftIdx=GamepadButton.Left, rightIdx=GamepadButton.Right, upIdx=GamepadButton.Up, downIdx=GamepadButton.Down)],
                sticks = [GamepadStickInput(xIdx=GamepadAxis.LThumbH, yIdx=GamepadAxis.LThumbV)]
            )
        ),
        "speedUp" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.LShift)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.X)]
            )
        ),
        "jump" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        ),
        "cameraAim" => Action(
            pointerActions = PointerAction(
                valueType = ValueType.Delta,
                mouse = MouseInput(active = true),
                gamepadPointers = [GamepadPointerInput(xIdx=GamepadAxis.RThumbH, yIdx=GamepadAxis.RThumbV)]
            )
        )
    })

    add_and_activate_action_set("player2", {
        "move2" => Action(
            joystickActions = JoystickAction(
                keyboardDPads = [KeyboardDPadInput(leftIdx=KeyCode.Left, rightIdx=KeyCode.Right, upIdx=KeyCode.Up, downIdx=KeyCode.Down)],
                gamepadDPads = [GamepadDPadInput(leftIdx=GamepadButton.Left, rightIdx=GamepadButton.Right, upIdx=GamepadButton.Up, downIdx=GamepadButton.Down, gamepadIdx=ControllerIndex.Device1)],
                sticks = [GamepadStickInput(xIdx=GamepadAxis.RThumbH, yIdx=GamepadAxis.RThumbV, gamepadIdx=ControllerIndex.Device1)]
            )
        )
    })
}


[export]
def on_update() {
    get_component(player1) $(var charCtrl : CharacterController?) {
        // Process input
        let forwardLocal = cross(camera.localRight, UP) // support movement while looking up/down
        let moveDir = get_action_vector2("move1")
        let forwardVel = moveDir.y > 0.5 ? forwardLocal : ZERO
        let backwardVel = moveDir.y < -0.5 ? -forwardLocal : ZERO
        let rightVel = moveDir.x > 0.5 ? camera.localRight : ZERO
        let leftVel = moveDir.x < -0.5 ? -camera.localRight : ZERO
        var inputVel = normalize(forwardVel + backwardVel + rightVel + leftVel)

        // Look at the input direction
        let rotateSpeed = PI * 4. * get_delta_time()
        if (length_sq(inputVel) > 0.) {
            let inputYaw = acos(inputVel.z) * (asin(inputVel.x) >= 0. ? 1. : -1.)
            let curYaw = acos(player1.localForward.z) * (asin(player1.localForward.x) >= 0. ? 1. : -1.)
            let yawDiff = clamp(angle_diff(curYaw, inputYaw), -rotateSpeed, rotateSpeed)
            player1.worldRotation = quat4(0, curYaw + yawDiff, 0)
        }

        // Move
        let speed = is_action_pressed("speedUp") ? 10. : 5.
        charCtrl.velocity = inputVel * speed

        // Inertial movement - jump
        if (is_action_pressed("jump") && charCtrl.state == CharacterState.OnGround) {
            playerInertia += UP * 6.
        }

        // Inertial movement - slope
        match (charCtrl.state) {
            if (CharacterState.OnGround) {
                playerInertia = float3(0, max(playerInertia.y, 0.), 0)
            }
            if (CharacterState.InAir) {
                playerInertia += charCtrl.gravity * get_delta_time()
            }
            if (_) {
                let groundNormal = charCtrl.groundNormal
                playerInertia += charCtrl.gravity * get_delta_time()
                if (dot(playerInertia, groundNormal) < 0.) {
                    playerInertia = project(playerInertia, groundNormal)
                }
            }
        }
        charCtrl.velocity += playerInertia

        update_debug_text(statusNode, "CharacterController test
Player 1: WASD to move, SHIFT to speedup, SPACE to jump
Player 2: arrows to move
Player 1 state: {charCtrl.state}, ground node: {charCtrl.groundNode} normal: {charCtrl.groundNormal}
Players have rigid bodies (press to toggle): [1] {has_component(player1, type<RigidBody>) ? "on" : "off"}, [2] {has_component(player2, type<RigidBody>) ? "on" : "off"}
Players have character controllers (press to toggle): [3] {has_component(player1, type<CharacterController>) ? "on" : "off"}, [4] {has_component(player2, type<CharacterController>) ? "on" : "off"},
Players have collision listeners (press to toggle): [5] {has_component(player1, type<CollisionTestCallbacks>) ? "on" : "off"}, [6] {has_component(player2, type<CollisionTestCallbacks>) ? "on" : "off"}")
    }

    get_component(player2) $(var charCtrl : CharacterController?) {
        // Process 2nd player
        let moveDir = get_action_vector2("move2")
        let forwardVel = moveDir.y > 0.5 ? FORWARD : ZERO
        let backwardVel = moveDir.y < -0.5 ? BACKWARD : ZERO
        let rightVel = moveDir.x > 0.5 ? LEFT : ZERO
        let leftVel = moveDir.x < -0.5 ? RIGHT : ZERO
        var inputVel = normalize(forwardVel + backwardVel + rightVel + leftVel)

        // Simple gravitation - without inertia
        let verticalVelocity = charCtrl.velocity.y
        charCtrl.velocity = inputVel * 5. + float3(0, verticalVelocity, 0)
        if (charCtrl.state != CharacterState.OnGround) {
            charCtrl.velocity += charCtrl.gravity * get_delta_time()
        } else {
            charCtrl.velocity *= float3(1, 0, 1)
        }
    }

    if (is_action_just_pressed("keyboardOption1")) {
        if (has_component(player1, type<RigidBody>)) {
            remove_component(player1, type<RigidBody>)
        } else {
            add_component(player1, new RigidBody(motionType = MotionType.Kinematic))
        }
    }

    if (is_action_just_pressed("keyboardOption2")) {
        if (has_component(player2, type<RigidBody>)) {
            remove_component(player2, type<RigidBody>)
        } else {
            add_component(player2, new RigidBody(motionType = MotionType.Kinematic))
        }
    }

    if (is_action_just_pressed("keyboardOption3")) {
        if (has_component(player1, type<CharacterController>)) {
            remove_component(player1, type<CharacterController>)
        } else {
            add_component(player1, new CharacterController())
        }
    }

    if (is_action_just_pressed("keyboardOption4")) {
        if (has_component(player2, type<CharacterController>)) {
            remove_component(player2, type<CharacterController>)
        } else {
            add_component(player2, new CharacterController())
        }
    }

    if (is_action_just_pressed("keyboardOption5")) {
        if (has_component(player1, type<CollisionTestCallbacks>)) {
            remove_component(player1, type<CollisionTestCallbacks>)
        } else {
            add_component(player1, new CollisionTestCallbacks())
        }
    }

    if (is_action_just_pressed("keyboardOption6")) {
        if (has_component(player2, type<CollisionTestCallbacks>)) {
            remove_component(player2, type<CollisionTestCallbacks>)
        } else {
            add_component(player2, new CollisionTestCallbacks())
        }
    }
}

class ThirdPersonCamera : Component {
    centerNode : NodeId
    centerOffset : float3
    distance : float = 5.
    yaw : float
    pitch : float
    smoothedDistance : float = -1.

    def override on_initialize() {
        if (!!centerNode) {
            let rightLocal = centerNode.worldRotation * FORWARD
            yaw = acos(rightLocal.z) * (asin(rightLocal.x) >= 0. ? 1. : -1.)
        }
        set_mouse_cursor_locked(true)
    }

    def override on_update() {
        // Process input
        if (is_mouse_cursor_locked()) {
            let mouse_delta = get_action_vector2("cameraAim") * 0.01
            yaw = yaw + mouse_delta.x
            pitch = clamp(pitch + mouse_delta.y, -45. * TO_RAD, 90. * TO_RAD)
        }

        if (!centerNode) {
            return
        }

        // Camera position
        let dir = quat4(pitch, yaw, 0) * BACKWARD
        let camCenter = centerNode.worldPosition + centerOffset
        var camPos = camCenter + dir * smoothedDistance

        // Camera offset
        if (smoothedDistance < 0.) {
            smoothedDistance = distance
        }
        smoothedDistance += 10. * get_delta_time()
        smoothedDistance = min(distance, smoothedDistance)
        trace(SphereCast(
            position = camCenter,
            radius = 0.5,
            rayDirection = dir * smoothedDistance,
            collisionMask = 1u << uint(CollisionLayer.Default)
        ))$(hit) {
            smoothedDistance = min(smoothedDistance, hit.distance)
            camPos = camCenter + dir * smoothedDistance
        }

        // Set position
        nodeId.worldPosition = camPos
        nodeId.worldRotation = quat4(pitch, yaw, 0)
    }
}


class GravityGunPickupHandler : PickupHandler {
    def private override processPickupInput(pickup : NodeId) {
        if (is_action_just_pressed("pickup")) {
            remove_node(pickup)
            add_component(camera, new GravityGunComponent(prefab = "gravityGun/gravityGun.prefab", camera = camera))
            request_prefab("gravityGun/gravityGunUI.prefab") |> instantiate_prefab()
        }
    }
}
