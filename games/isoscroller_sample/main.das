require engine.core

let roomPrefab = request_prefab("room.prefab")
let characterModel = "character/character.fbx"
let characterAnimationRunning = "Run"
let characterPrefab = request_prefab("character/character.prefab")
let uiPrefab = request_prefab("ui.prefab")
let renderSettings = request_prefab("render_settings.prefab")

def init_world() {
    let room = instantiate_prefab(roomPrefab)

    let sun = create_node(NodeData(name = "camera", rotation = quat4(float3(-2f * PI / 3f, -PI / 3f, 8f * PI / 9f))))
    sun.add_component(new DirectionLight())

    renderSettings.instantiate_prefab()
}

[export]
def on_initialize() {
    set_default_restitution(0.1)
    set_default_friction(0.9)

    init_world()

    let spawner = find_component(type<PlayerSpawner>)
    if (spawner == null) {
        return
    }
    let charNode = characterPrefab.instantiate_prefab(NodeData(
        position = spawner.nodeId.worldPosition,
        rotation = quat4(),
        scale = float3(1)
    ))
    charNode.add_component(new CharacterInput())
    charNode.add_component(new CharacterAnimated(modelName = characterModel, animName = characterAnimationRunning))
    charNode.add_component(new RespawnWhenFalling(spawnerNode = spawner.nodeId))

    let camera = create_node(NodeData(name = "camera", rotation = quat4(PI / 6., PI, 0)))
    camera.add_component(new Camera(fovAxis = FovAxis.Vertical, fov = 60. * TO_RAD))
    camera.add_component(new SideScrollerCamera(lookatNode = charNode, zyPos = float2(8, 12)))

    let ui = uiPrefab.instantiate_prefab()
    let winText = find_component(type<ButtonWinText>)
    let winButton = find_component(type<WinButton>)
    if (winText != null && winButton != null) {
        winText.nodeId?.ButtonWinText.button = winButton.nodeId
    }

    add_and_activate_action_set("player", {
        "left" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Left), KeyboardButtonInput(idx=KeyCode.A)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Left)]
            )
        ),
        "right" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Right), KeyboardButtonInput(idx=KeyCode.D)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Right)]
            )
        ),
        "forward" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Up), KeyboardButtonInput(idx=KeyCode.W)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Up)]
            )
        ),
        "backward" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Down), KeyboardButtonInput(idx=KeyCode.S)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Down)]
            )
        ),
        "jump" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        )
    })
}


[export]
def on_update() {
    // logic in the components
}

class NoSleep : Component {
    def override on_update() {
        if (nodeId.has_component(type<RigidBody>)) {
            if (nodeId?.RigidBody.isSleeping) {
                nodeId?.RigidBody.isSleeping = false
            }
        }
    }
}

class SideScrollerCamera : Component {
    lookatNode : NodeId
    zyPos : float2

    def override on_update() {
        var lookatXPos = 0.
        if (!!lookatNode) {
            lookatXPos = lookatNode.worldPosition.x
        }
        nodeId.worldPosition = float3(lookatXPos, zyPos.x, zyPos.y)
    }
}

class FloorButton : CollisionListener {
    pressHeight : float = 0.1
    cooldownDuration : float = 0.1
    private downCooldown : float = -1.
    private position : float

    def is_pressed() : bool {
        return downCooldown >= 0.
    }

    def override on_initialize() {
        super.on_initialize()
        nodeId?.RigidBody.motionType = MotionType.Kinematic
        nodeId?.Collider.isSensor = true
    }

    def override on_update() {
        var dirty = false

        if (downCooldown < 0. && position < 0.) {
            position = min(position + 0.1, 0.)
            dirty = true
        } elif (downCooldown >= 0. && position > -pressHeight) {
            position = max(position - 0.2, -pressHeight)
            dirty = true
        }

        if (downCooldown > 0.) {
            downCooldown -= get_delta_time()
            if (downCooldown < 0.) {
                downCooldown = -1.
            }
        }

        if (dirty) {
            for (i in range(nodeId.childCount)) {
                nodeId.get_child(i).localPosition = UP * position
            }
        }
    }

    def override on_collision(c : Collision) { if (c.nodeId.has_component(type<RigidBody>)) { downCooldown = cooldownDuration; } }
    def override on_collision_stay(c : Collision) { if (c.nodeId.has_component(type<RigidBody>)) { downCooldown = cooldownDuration; } }
}

class ButtonWinText : Component {
    button : NodeId
    onText : string
    offText : string

    def override on_update() {
        let is_pressed = !!button && button?.FloorButton.is_pressed()
        nodeId?.UIText.text = (is_pressed ? onText : offText)
    }
}

class WinButton : Component {}

class ButtonHighlight : Component {
    button : NodeId
    materialOn : MaterialId
    materialOff : MaterialId

    def override on_update() {
        let is_pressed = !!button && button?.FloorButton.is_pressed()
        nodeId?.Mesh.materialId = (is_pressed ? materialOn : materialOff)
    }
}

class ButtonDoor : Component {
    button : NodeId
    rot1 : float3
    rot2 : float
    animDuration : float = 1.0
    private animPos : float = 0.0

    def override on_update() {
        let is_pressed = !!button && button?.FloorButton.is_pressed()
        if (is_pressed && animPos < 1.) {
            animPos += get_delta_time() / animDuration
            animPos = min(animPos, 1.)
        } elif (!is_pressed && animPos > 0.) {
            animPos -= get_delta_time() / animDuration
            animPos = max(animPos, 0.)
        }
        let rot = (animPos < 1. ? rot2 - rot1.x : rot1.x - rot2) * TO_RAD / animDuration
        nodeId.localRotation = quat4(lerp(rot1.x, rot2, animPos) * TO_RAD, rot1.y * TO_RAD, rot1.z * TO_RAD)
    }
}


class CharacterInput : Component {
    runSpeed : float = 7.
    jumpHeight : float = 2.
    jumpDuration : float = 0.8

    private characterInertia : float3

    def override on_initialize() : void {
        nodeId.add_component(new CharacterController(velocity = float3()))
        nodeId.add_component(new Collider(shape = capsule_shape([radius = 0.5, height = 2.0, translation = float3(0, 1.0, 0)])))
        nodeId.add_component(new RigidBody(motionType = MotionType.Kinematic))
    }

    def override on_update() {
        var moveDir = float3()
        let jumpImpulse = 4. * jumpHeight / jumpDuration
        let gravity = DOWN * (8. * jumpHeight / (jumpDuration * jumpDuration))
        let charState = nodeId?.CharacterController.state
        let viewTransform = quat4(0, PI, 0)

        // Input
        if (is_action_pressed("right")) { moveDir += viewTransform * RIGHT; }
        if (is_action_pressed("forward")) { moveDir += viewTransform * FORWARD; }
        if (is_action_pressed("left")) { moveDir += viewTransform * LEFT; }
        if (is_action_pressed("backward")) { moveDir += viewTransform * BACKWARD; }
        moveDir = moveDir.normalize()

        // Jump
        if (is_action_pressed("jump")) {
            if (nodeId?.CharacterController.state == CharacterState.OnGround) {
                characterInertia += float3(0, jumpImpulse, 0) + moveDir * runSpeed
                moveDir = float3()
            }
        }

        // Handle inertia
        if (charState == CharacterState.InAir) {
            characterInertia += gravity * get_delta_time()
        } elif (charState == CharacterState.OnGround) {
            if (dot(characterInertia, DOWN) > 0.) {
                characterInertia *= float3(0, 1, 0)
                characterInertia = max(characterInertia, float3(0, 0, 0))
            }
        } else {
            let groundNormal = nodeId?.CharacterController.groundNormal
            characterInertia += gravity * get_delta_time()
            if (dot(characterInertia, groundNormal) < 0.) {
                characterInertia = project(characterInertia, groundNormal)
            }
        }

        // Apply velocity
        let speedMul = (charState == CharacterState.OnGround ? 1.0 : 0.5)
        nodeId?.CharacterController.velocity = moveDir * runSpeed * speedMul + characterInertia

        // Clamp velocity to maximum speed
        var horVel = nodeId?.CharacterController.velocity * float3(1, 0, 1)
        if (length_sq(horVel) > runSpeed * runSpeed) {
            horVel = horVel.normalize() * runSpeed
            nodeId?.CharacterController.velocity = nodeId?.CharacterController.velocity * float3(0, 1, 0) + horVel
        }

        // Look at the input direction
        let rotateSpeed = PI * 4. * get_delta_time()
        if (length_sq(moveDir) > 0.) {
            let inputYaw = acos(moveDir.z) * (asin(moveDir.x) >= 0. ? 1. : -1.)
            let curYaw = acos(nodeId.localForward.z) * (asin(nodeId.localForward.x) >= 0. ? 1. : -1.)
            let yawDiff = clamp(angle_diff(curYaw, inputYaw), -rotateSpeed, rotateSpeed)
            nodeId.worldRotation = quat4(0, curYaw + yawDiff, 0)
        }
    }
}

class CharacterAnimated : Component {
    animName : string
    modelName : string
    blendingSpeed : float = 0.2

    private animation : AnimationId
    private animProgress : float = -1.
    private animWeight : float = 0.

    def override on_initialize() : void {
        nodeId.add_component(new Animator())
        animation = request_animation(modelName, animName)
    }

    def override on_update() {
        if (!nodeId.has_component(type<CharacterController>)) {
            return
        }

        let moveDir = normalize(nodeId?.CharacterController.velocity)

        let isRunning = length_sq(moveDir) > 0.
        if (isRunning && animProgress < 0.) {
            animProgress = 0.
        }
        var desiredWeight = 0.
        if (isRunning) {
            desiredWeight = 1.
        }
        if (isRunning && animWeight == 0.) {
            animProgress = 0.
        }
        if (animWeight < 0. && desiredWeight == 0.) {
            animWeight = 0.
        } elif (animWeight > 1. && desiredWeight == 1.) {
            animWeight = 1.
        } else {
            animWeight += sign(desiredWeight - animWeight) * blendingSpeed
        }

        if (animProgress >= 0.) {
            get_animation_duration(animation) $(duration) {
                animProgress += get_delta_time() * 1.0 / duration
                animProgress -= float(int(animProgress))
                sample_animation_and_blend(nodeId, [animation, animation], [0., max(animProgress, -1.)], [1. - animWeight, animWeight])
            }
        } else {
            sample_animation_and_blend(nodeId, [animation], [0.], [1.])
        }
    }
}

class PlayerSpawner : Component {}

class RespawnWhenFalling : Component {
    deathHeight : float = -5.
    spawnerNode : NodeId

    def override on_update() {
        if (nodeId.worldPosition.y <= deathHeight) {
            nodeId.worldPosition = spawnerNode.worldPosition
            if (nodeId.has_component(type<RigidBody>)) {
                nodeId?.RigidBody.velocity = float3()
                nodeId?.RigidBody.angularVelocity = float3()
            }
        }
    }
}
