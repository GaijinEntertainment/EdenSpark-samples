require engine.core

let characterScale = 0.5
let enviDragCoeff = 0.5
let jumpCooldownTime = 0.2
let ouchCooldownTime = 3.0

struct CameraSetup {
    targetPosYZ : float2 = float2(3, -5) * characterScale
    targetLookAtDist : float = 6.0 * characterScale
    verticalCoeffStrength : float = 0.2
    approachAlongDirInertia : float = 0.1
    approachToBackInertia : float = 0.5
    approachToLookDirInertia : float = 0.1
    approachToUpDirStrength : float = 0.5
}

struct CharacterSetup {
    torqueCoeff : float = 2000.0
    turnStrength : float = 3.0
    brakingStrength : float = 10.0
    mass : float = 5.0
    radius : float = 1.0 * characterScale
    jumpStrength : float = 10.0
}

struct CameraState {
    node : NodeId
    setup : CameraSetup = CameraSetup()
    upDir : float3 = float3(0, 1, 0)
}

// CharacterState is an engine struct.
struct MainCharacterState {
    node : NodeId
    setup : CharacterSetup = CharacterSetup()
    upDir : float3 = float3(0, 1, 0)
    forwardDir : float3 = float3(0, 0, 1)
    velocity : float3 = float3(0, 0, 0)
}

var camera : CameraState = CameraState()
var character : MainCharacterState = MainCharacterState()
var jumpCooldown : float = 0.0
var ouchCooldown : float = 0.0
var isJumpScheduled : bool = false
var lastHorCollisionPos : float3 = float3(0, 0, 0)
var infoNode : NodeId
var ouchNode : NodeId
var statusNode : NodeId
var topGroundHeight : float = 0.0
var lastContactNormal : float3 = float3(0, 1, 0)
var isOnSurface : bool = false

def process_contact(contact_pos, contact_norm : float3) {
    if (abs(contact_norm.y) > 0.5) {
        if ((lastHorCollisionPos - contact_pos).y > 30.0) {
            ouchCooldown = ouchCooldownTime
        }
        lastHorCollisionPos = contact_pos
        topGroundHeight = max(topGroundHeight, contact_pos.y)
    }
    lastContactNormal = contact_norm
}

def process_jump(contact_norm : float3) {
    if (isJumpScheduled && jumpCooldown > 0.0) {
        let impulse = contact_norm * character.setup.jumpStrength * character.setup.mass
        apply_rigid_body_impulse(character.node?.RigidBody, impulse)
        isJumpScheduled = false
    }
}

def process_collision(collision : Collision const) {
    process_contact(collision.positions[0], collision.normal)
    isOnSurface = true
}

def process_collision_persisted(collision : Collision const) {
    process_contact(collision.positions[0], collision.normal)
    process_jump(lastContactNormal)
}

def process_collision_removed(otherNode : NodeId const) {
    process_jump(lastContactNormal)
    isOnSurface = false
}

def move_character(dt : float) {
    var torqueCoeffAmount = 0.0
    var brakingAmount = 0.0
    var turnAmount = 0.0
    var impulse = float3(0, 0, 0)

    if (get_action_axis("accelerate") > 0.0) {
        torqueCoeffAmount += character.setup.torqueCoeff
    }
    if (get_action_axis("accelerate") < 0.0) {
        // torqueCoeffAmount -= character.setup.torqueCoeff
        brakingAmount += character.setup.brakingStrength
    }
    turnAmount += get_action_axis("turn") * character.setup.turnStrength

    var isNearToSurface = false
    var surfaceNorm = float3(0, 1, 0)

    overlap(SphereQuery(position = character.node.worldPosition, radius = character.setup.radius * 1.1)) \
        $(hits : array<OverlapHit>#) {
            var hitNormSum = float3(0, 0, 0)
            for (hit in hits) {
                if (hit.nodeId == character.node) {
                    continue
                }
                hitNormSum += hit.normal
            }
            let hitNormSumLen = length(hitNormSum)
            if (hitNormSumLen > 0.001) {
                isNearToSurface = true
                surfaceNorm = hitNormSum / hitNormSumLen
            }
        }

    jumpCooldown -= dt
    ouchCooldown -= dt

    if (is_action_just_pressed("jump")) {
        jumpCooldown = jumpCooldownTime
        isJumpScheduled = true
    }

    if (isOnSurface) {
        process_jump(surfaceNorm)
    }

    get_component(character.node) $(var rigidBody : RigidBody?) {
        let turnDelta = dt * turnAmount
        let speed = length(rigidBody.velocity)
        let velocityProjected = rigidBody.velocity - dot(rigidBody.velocity, character.upDir) * character.upDir

        let speedProjected = length(velocityProjected)
        if (speedProjected > 0.1) {
            // character.forwardDir = rigidBody.velocity / speed
            character.forwardDir = velocityProjected / speedProjected
        }

        if (isNearToSurface) {
            let turnRotation = quat4(character.upDir, turnDelta)
            character.forwardDir = turnRotation * character.forwardDir
            rigidBody.velocity = turnRotation * rigidBody.velocity
        }

        character.velocity = rigidBody.velocity

        let rightDir = cross(character.upDir, character.forwardDir)
        let torqueDelta = torqueCoeffAmount * rightDir * dt

        let braking = exp(-brakingAmount * dt)
        rigidBody.angularVelocity = length(rigidBody.angularVelocity) * rightDir * braking
        apply_rigid_body_torque(rigidBody, torqueDelta)
    }
}

def camera_follow_character(dt : float) {
    let charPos = character.node.worldPosition
    let camPos = camera.node.worldPosition
    let camToChar = charPos - camPos
    let camToCharLen = length(camToChar)
    let camToCharProjDir = normalize(camToChar - dot(camToChar, character.upDir) * character.upDir)

    let dirCrossVelLen = length(cross(character.forwardDir, character.velocity))
    let verCoeff = 1.0 - exp(-dirCrossVelLen * camera.setup.verticalCoeffStrength)

    let horTargetDist = length(camera.setup.targetPosYZ)
    let verTargetPos = charPos - camToChar / camToCharLen * horTargetDist
    let verTargetLookAt = charPos

    let horTargetPosAlongDir = charPos + character.upDir * camera.setup.targetPosYZ.x + camToCharProjDir * camera.setup.targetPosYZ.y
    let horTargetPosToBack = charPos + character.upDir * camera.setup.targetPosYZ.x + character.forwardDir * camera.setup.targetPosYZ.y
    let horTargetLookAt = charPos + camToCharProjDir * camera.setup.targetLookAtDist

    let verPosApproach = approach(camPos, verTargetPos, dt, camera.setup.approachAlongDirInertia)
    let horPosApproachAlongDir = approach(camPos, horTargetPosAlongDir, dt, camera.setup.approachAlongDirInertia)
    let horPosApproach = approach(horPosApproachAlongDir, horTargetPosToBack, dt, camera.setup.approachToBackInertia)
    camera.node.worldPosition = lerp(horPosApproach, verPosApproach, verCoeff)

    let upDirRot = slerp(quat4(camera.upDir, character.upDir), quat4(float4(0, 0, 0, 1)), exp(-camera.setup.approachToUpDirStrength * dt))
    camera.upDir = upDirRot * camera.upDir

    let verTargetLookRot = quat4(look_at(camera.node.worldPosition, verTargetLookAt, camera.upDir))
    let horTargetLookRot = quat4(look_at(camera.node.worldPosition, horTargetLookAt, camera.upDir))
    let targetLookRot = slerp(horTargetLookRot, verTargetLookRot, verCoeff)
    camera.node.worldRotation = approach(camera.node.worldRotation, targetLookRot, dt, camera.setup.approachToLookDirInertia)
}

[export]
def on_initialize() {
    set_physics_fps(30.0) // Should be enough.
    set_target_fps(1000.0)

    let characterMaterial = request_material("assets/ball_mat.material")

    let sphereMesh = create_sphere_mesh(SphereInit(subdivisions = 32, radius = character.setup.radius))
    character.node = create_node(NodeData(position = float3(0, character.setup.radius * 2.0, 0)))
    add_component(character.node, new Mesh(meshId = sphereMesh, materialId = characterMaterial))
    add_component(character.node, new RigidBody(
        mass = character.setup.mass,
        linearDamping = enviDragCoeff, angularDamping = 0.0,
        collisionDetection = CollisionDetection.Continuous,
        interpolation = Interpolation.Interpolate,
        maxVelocity = 500.0,
        maxAngularVelocity = 100.0))
    add_component(character.node, new Collider(
        shape = sphere_shape(character.setup.radius),
        friction = 100.0,
        restitution = 0.2))
    on_collision(character.node) @(collision) {
        process_collision(collision)
    }
    on_collision_stay(character.node) @(collision) {
        process_collision_persisted(collision)
    }
    on_collision_exit(character.node) @(otherNode) {
        process_collision_removed(otherNode)
    }

    camera.node = create_node(NodeData(position = float3(0, 5, -5), rotation = quat4(PI / 4f, 0, 0)))
    add_component(camera.node, new Camera(zfar = 1000.0, fovAxis = FovAxis.Horizontal, fov = TO_RAD * 90f))

    let sun = create_node(NodeData(rotation = quat4(PI / 3f, -PI * 0.25f, 0f)))
    add_component(sun, new DirectionLight())

    let renderSettings = create_render_settings()
    get_component(renderSettings) $(var ssao : SSAOSettings?) {
        ssao.active = true
        ssao.method = SSAOMethod.GTAO
        ssao.strength = 0.7f
    }

    let infoText = "Climb as high as you can. WASD/Arrows to move, Space to jump. You can jump off from walls too."
    infoNode = create_debug_text(infoText, float2(10, -10), BOTTOM_LEFT_ANCHOR)
    infoNode?.UIText.color = BLACK_COLOR

    ouchNode = create_node()
    add_component(ouchNode, new UIText(text = "", pivot = float2(0.5, 0.5), color = BLACK_COLOR, fontSize = 48.0))

    statusNode = create_debug_text("", float2(10, -40), BOTTOM_LEFT_ANCHOR)
    statusNode?.UIText.color = BLACK_COLOR

    add_and_activate_action_set("player", {
        "accelerate" => Action(
            axisActions = AxisAction(
                keyboardAxis = [KeyboardBtnAxisInput(negativeIdx=KeyCode.Down, positiveIdx=KeyCode.Up), KeyboardBtnAxisInput(negativeIdx=KeyCode.S, positiveIdx=KeyCode.W)],
                gamepadAxis = [GamepadBtnAxisInput(negativeIdx=GamepadButton.Down, positiveIdx=GamepadButton.Up)],
                stickAxis = [GamepadAxisInput(idx=GamepadAxis.LThumbV)]
            )
        ),
        "turn" => Action(
            axisActions = AxisAction(
                keyboardAxis = [KeyboardBtnAxisInput(negativeIdx=KeyCode.Left, positiveIdx=KeyCode.Right), KeyboardBtnAxisInput(negativeIdx=KeyCode.A, positiveIdx=KeyCode.D)],
                gamepadAxis = [GamepadBtnAxisInput(negativeIdx=GamepadButton.Left, positiveIdx=GamepadButton.Right)],
                stickAxis = [GamepadAxisInput(idx=GamepadAxis.LThumbH)]
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
    let dt = get_delta_time()
    move_character(dt)
    camera_follow_character(dt)

    if (ouchCooldown > 0.0) {
        (get_component(ouchNode, type<UIText>)).text = "Ouch!"
    } else {
        (get_component(ouchNode, type<UIText>)).text = ""
    }

    // No proper formatting of floats yet?
    update_debug_text(statusNode, "Top height on ground: {int(topGroundHeight)}.{int(topGroundHeight * 1000.0) % 1000}")
}
