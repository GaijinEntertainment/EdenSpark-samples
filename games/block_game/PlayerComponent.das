require engine.core

require BlockComponent

let sensitivity = 0.003

[require(component=(CharacterController))]
class Player : Component {
    private yaw : float
    private pitch : float
    eye : NodeId
    @no_export camera : Camera?
    speed : float
    jumpForce : float
    private vertVel : float
    private controller : CharacterController?

    def override on_initialize() {
        controller = nodeId |> get_component(type<CharacterController>)
        camera = eye |> get_component(type<Camera>)

        add_and_activate_action_set("player", {
            "move" => Action(
                joystickActions = JoystickAction(
                    keyboardDPads = [KeyboardDPadInput(leftIdx=KeyCode.A, rightIdx=KeyCode.D, upIdx=KeyCode.W, downIdx=KeyCode.S)],
                    sticks = [GamepadStickInput(xIdx=GamepadAxis.LThumbH, yIdx=GamepadAxis.LThumbV)],
                )
            ),
            "jump" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
                )
            ),
            "action" => Action(
                buttonActions = ButtonAction(
                    mouseButtons = [MouseButtonInput(idx=MouseButton.Left)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.X)]
                )
            ),
            "aim" => Action(
                pointerActions = PointerAction(
                    valueType = ValueType.Delta,
                    mouse = MouseInput(active = true),
                    gamepadPointers = [GamepadPointerInput(xIdx=GamepadAxis.RThumbH, yIdx=GamepadAxis.RThumbV)]
                )
            )
        })
    }

    def rotate() {
        let mouseDelta = get_action_vector2("aim")
        pitch += mouseDelta.y * sensitivity
        pitch = clamp(pitch, -PI * 0.5, PI * 0.5)
        yaw += mouseDelta.x * sensitivity
        let yawRot = quat4(UP, yaw)
        let pitchRot = quat4(RIGHT, pitch)

        nodeId.localRotation = yawRot
        eye.localRotation = pitchRot
    }

    def override on_update() {
        if (!is_mouse_cursor_locked()) {
            return
        }

        rotate()

        var dir : float3

        let forward = nodeId.localForward
        let right = nodeId.localRight

        let move = get_action_vector2("move")
        dir += move.x * right
        dir += move.y * forward

        dir = normalize(dir)

        let state = controller.state
        if (state == CharacterState.OnGround) {
            vertVel = 0.
            if (is_action_just_pressed("jump")) {
                vertVel = jumpForce
            }
        } else {
            vertVel += get_gravity().y * get_delta_time()
        }

        controller.velocity = dir * speed + UP * vertVel


        if (is_action_pressed("action")) {
            let ray = camera.screenToRay(float2(get_resolution()) / 2.)
            trace(RayCast(ray = ray, maxDistance = 5.)) $(hit) {
                var hitBlock = get_component(hit.nodeId, type<Block>)
                if (hitBlock != null) {
                    hitBlock.add_breaking()
                }
            }
        }
    }
}