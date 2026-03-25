require engine.core

let unlitMaterial = create_material(MaterialImport(shaderName = "standard_unlit_shader"))
let sphereMesh = create_sphere_mesh(SphereInit(subdivisions = 64, radius = 1.f))
let gameZoneSize = float2(3, 4)

let uiPrefab = request_prefab("ui.prefab")

let spawnSound = request_sound("spawn.wav")
let collideSound = request_sound("collide.wav")

var playerPoints = 0

struct SphereDesc {
    color : float4
    radius : float
    spawnChance : int
    spawnAbovePoints : int
}

let spheres = [
    SphereDesc(radius = 0.16, color = color32_to_float4(0xFFA5B1FF), spawnChance = 10, spawnAbovePoints = 0),
    SphereDesc(radius = 0.18, color = color32_to_float4(0xFFFFA5A5), spawnChance = 8, spawnAbovePoints = 10),
    SphereDesc(radius = 0.2, color = color32_to_float4(0xFF5948C4), spawnChance = 5, spawnAbovePoints = 20),
    SphereDesc(radius = 0.22, color = color32_to_float4(0xFFF79E40), spawnChance = 5, spawnAbovePoints = 40),
    SphereDesc(radius = 0.25, color = color32_to_float4(0xFFF74040)),
    SphereDesc(radius = 0.4, color = color32_to_float4(0xFF85D8E2)),
    SphereDesc(radius = 0.5, color = color32_to_float4(0xFFE29EDF)),
    SphereDesc(radius = 0.8, color = color32_to_float4(0xFFE2E23D)),
    SphereDesc(radius = 0.85, color = color32_to_float4(0xFF70EFC3)),
    SphereDesc(radius = 0.9, color = color32_to_float4(0xFF90DD52)),
]
let bgColor = color32_to_float4(0xFFFFFBBA).xyz
let borderColor = color32_to_float4(0xFF595E70)

def choose_sphere(points) {
    var maxWeight = 0
    for (sphereIdx in range(0, length(spheres))) {
        if (points < spheres[sphereIdx].spawnAbovePoints) { continue; }
        maxWeight += spheres[sphereIdx].spawnChance
    }
    var randomVal = random_range(0, maxWeight)
    for (sphereIdx in range(0, length(spheres))) {
        if (points < spheres[sphereIdx].spawnAbovePoints) { continue; }
        if (randomVal < spheres[sphereIdx].spawnChance) {
            return sphereIdx
        }
        randomVal -= spheres[sphereIdx].spawnChance
    }
    return 0
}

def create_sphere(index, pos) {
    let sphere = create_node(NodeData(position = pos, name = "sphere{index}", scale = float3(spheres[index].radius)))
    sphere.add_component(new Mesh(meshId = sphereMesh, materialId = unlitMaterial, color = spheres[index].color))
    sphere.add_component(new RigidBody(
        allowedDofs = AllowedDofs.AllowedDofs2D,
        mass = spheres[index].radius,
        angularVelocity = random_range(float3(0, 0, 1) * -1. * PI, float3(0, 0, 1) * 1. * PI),
        interpolation = Interpolation.Interpolate,
        collisionDetection = CollisionDetection.Continuous
    ))
    sphere.add_component(new Collider(shape = sphere_shape([radius = 1.])))
    sphere.add_component(new SphereTag())

    if ((index + 1) < length(spheres)) {
        sphere.add_component(new SphereMerger(sphereIndex = index))
    }

    return sphere
}

def create_border(parent : NodeId, size : float2, thickness : float) {
    let leftTop = LEFT * size.x / 2. + UP * size.y / 2.
    let rightBottom = RIGHT * size.x / 2. + DOWN * size.y / 2.
    let leftBorder = create_node(NodeData(parent = parent, name = "left",
        position = leftTop + LEFT * thickness / 2. + DOWN * size.y * 0.5,
        scale = float3(thickness, size.y, 1)
    ))
    let rightBorder = create_node(NodeData(parent = parent, name = "right",
        position = leftTop + RIGHT * size.x + RIGHT * thickness / 2. + DOWN * size.y / 2.,
        scale = float3(thickness, size.y, 1)
    ))
    let bottomBorder = create_node(NodeData(parent = parent, name = "bottom",
        position = leftTop + DOWN * size.y + DOWN * thickness / 2. + RIGHT * size.x / 2.,
        scale = float3(size.x + thickness * 2., thickness, 1)
    ))

    leftBorder.add_component(new Mesh(meshId = CUBE_MESH_ID, materialId = unlitMaterial, color = borderColor))
    leftBorder.add_component(new Collider(shape = box_shape()))

    rightBorder.add_component(new Mesh(meshId = CUBE_MESH_ID, materialId = unlitMaterial, color = borderColor))
    rightBorder.add_component(new Collider(shape = box_shape()))

    bottomBorder.add_component(new Mesh(meshId = CUBE_MESH_ID, materialId = unlitMaterial, color = borderColor))
    bottomBorder.add_component(new Collider(shape = box_shape()))
}

def create_spawner(pos) {
    let node = create_node(NodeData(position = pos, name = "spawner"))
    let bounds = gameZoneSize.x / 2.
    node.add_component(new Spawner(bounds = float2(-bounds, bounds)))
    return node
}

def create_finish_sensor(bounds) {
    let safetyThickness = 3.
    let node = create_node(NodeData(name = "finish_sensor",
        position = UP * (bounds.y / 2. + safetyThickness / 2.),
        scale = float3(bounds.x + safetyThickness * 2., safetyThickness, 1.)
    ))
    node.add_component(new Collider(shape = box_shape(), isSensor = true))
    node.add_component(new FinishSensor())
    return node
}

def pause_physics {
    for (sphere in find_components(type<SphereTag>)) {
        sphere.nodeId?.RigidBody.enabled = false
    }
    for (spawner in find_components(type<Spawner>)) {
        spawner.nodeId.isActive = false
    }
}

[export]
def on_initialize {
    let camera = create_node(NodeData(position = float3(0, 0, -5), name = "camera"))
    add_component(camera, new Camera(orthographic = true, orthographicSize = gameZoneSize.y + 3., backgroundColor = bgColor, fovAxis = FovAxis.Vertical, fov = TO_RAD * 90f))

    let renderSettings = create_render_settings()
    renderSettings?.Sky.active = false
    renderSettings?.ShadowSettings.active = false

    let ui = instantiate_prefab(uiPrefab)

    set_default_restitution(0.)
    set_default_friction(1.)

    let border = create_node(NodeData(name = "border"))
    create_border(border, gameZoneSize, 0.3)

    let spawner = create_spawner(UP * (gameZoneSize.y / 2. + 1.))

    let colorRuler = create_node(NodeData(name = "color_ruler", position = DOWN * (gameZoneSize.y / 2. + 0.8)))
    let rulerLeftPos = -1.7
    for (sphereIdx in range(0, spheres.length())) {
        let ruler_sphere = create_node(NodeData(name = "sphere", parent = colorRuler, scale = float3(0.5)))
        ruler_sphere.add_component(new Mesh(meshId = sphereMesh, materialId = unlitMaterial, color = spheres[sphereIdx].color))

        var pos = rulerLeftPos
        let sizeMultiplier = 0.8
        for (i in range(sphereIdx)) {
            pos += spheres[i].radius * sizeMultiplier * 0.5
            pos += spheres[i + 1].radius * sizeMultiplier * 0.5
        }
        ruler_sphere.localPosition = float3(pos, 0, 0)
        ruler_sphere.localScale = float3(spheres[sphereIdx].radius * sizeMultiplier * 0.5)

    }

    let finishSensor = create_finish_sensor(gameZoneSize)
    finishSensor?.FinishSensor.onFinish <- @() {
        pause_physics()
    }

    show_mouse_cursor(true)
}

class SphereTag : Component {
    canFinish : bool = false
}

class Spawner : Component {
    bounds : float2
    moveSpeed = gameZoneSize.x / 1.5
    spawnCooldown : float = 0.5
    nextSphereIdx : int
    lastSpawnTime : float

    def override on_initialize {
        nodeId.add_component(new Mesh(meshId = sphereMesh, materialId = unlitMaterial))
        nextSphereIdx = 0
        update_to_next_sphere()
        lastSpawnTime = get_time()

        add_and_activate_action_set("player", {
            "horizontalMove" => Action(
                axisActions = AxisAction(
                    keyboardAxis = [KeyboardBtnAxisInput(negativeIdx=KeyCode.Left, positiveIdx=KeyCode.Right), KeyboardBtnAxisInput(negativeIdx=KeyCode.A, positiveIdx=KeyCode.D)],
                    gamepadAxis = [GamepadBtnAxisInput(negativeIdx=GamepadButton.Left, positiveIdx=GamepadButton.Right)],
                    stickAxis = [GamepadAxisInput(idx=GamepadAxis.LThumbH)]
                )
            ),
            "spawn" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space), KeyboardButtonInput(idx=KeyCode.Down), KeyboardButtonInput(idx=KeyCode.Return)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
                )
            ),
        })
    }

    def override on_update {
        // padding on the sides - so the falling sphere wouldn't collide with the wall
        let collisionPadding = 0.01
        let sphereRadius = spheres[nextSphereIdx].radius + collisionPadding

        let horizontalMove = get_action_axis("horizontalMove")
        if (horizontalMove < 0f) { nodeId.localPosition += LEFT * moveSpeed * get_delta_time(); }
        if (horizontalMove > 0f) { nodeId.localPosition += RIGHT * moveSpeed * get_delta_time(); }

        if (nodeId.localPosition.x < (bounds.x + sphereRadius)) {
            nodeId.localPosition = nodeId.localPosition * float3(0, 1, 1) + float3(bounds.x + sphereRadius, 0, 0)
        }
        if (nodeId.localPosition.x > (bounds.y - sphereRadius)) {
            nodeId.localPosition = nodeId.localPosition * float3(0, 1, 1) + float3(bounds.y - sphereRadius, 0, 0)
        }

        if ((is_action_just_pressed("spawn")) && (get_time() - lastSpawnTime > spawnCooldown)) {
            var newPos = nodeId.worldPosition
            if (newPos.x < (bounds.x + sphereRadius)) { newPos += RIGHT * sphereRadius; }
            if (newPos.x > (bounds.y - sphereRadius)) { newPos += LEFT * sphereRadius; }

            create_sphere(nextSphereIdx, newPos)
            playerPoints += (nextSphereIdx + 1)

            nextSphereIdx = choose_sphere(playerPoints)
            update_to_next_sphere()
            lastSpawnTime = get_time()

            let sound = play_sound(spawnSound)
            set_pitch(sound, random_float() * 0.3 + 1.)
        }
    }

    def update_to_next_sphere {
        nodeId.localScale = float3(spheres[nextSphereIdx].radius)
        nodeId?.Mesh.color = spheres[nextSphereIdx].color
    }
}

class SphereMerger : CollisionListener {
    sphereIndex : int = 0

    def override on_collision(contact : Collision) {
        if (!contact.nodeId || !contact.nodeId.isAlive) {
            return
        }
        if (contact.nodeId.has_component(type<SphereMerger>) && nodeId.has_component(type<SphereTag>)) {
            nodeId?.SphereTag.canFinish = true
        }
        if (contact.nodeId.has_component(type<SphereMerger>) && contact.nodeId?.SphereMerger.sphereIndex == sphereIndex) {
            playerPoints += (sphereIndex + 1)
            let between = (nodeId.worldPosition + contact.nodeId.worldPosition) / 2.
            nodeId.remove_node()
            contact.nodeId.remove_node()
            create_sphere(sphereIndex + 1, between)

            let sound = play_sound(collideSound)
            set_pitch(sound, random_float() * 0.3 + 1.)
        }
    }
}

class FinishSensor : CollisionListener {
    onFinish : lambda<() : void>

    def override on_collision(collision : Collision) {
        if (!collision.nodeId || !collision.nodeId.isAlive) {
            return
        }
        check_node(collision.nodeId)
    }

    def override on_collision_stay(collision : Collision) {
        if (!collision.nodeId || !collision.nodeId.isAlive) {
            return
        }
        check_node(collision.nodeId)
    }

    def check_node(otherNode : NodeId) {
        if (!otherNode.has_component(type<SphereTag>) || !otherNode?.SphereTag.canFinish) {
            return
        }

        if (otherNode.worldPosition.y >= (nodeId.worldPosition.y - nodeId.worldScale.y / 2.)) {
            onFinish()
        }
    }
}

class ScoreText : Component {
    def override on_update {
        nodeId?.UIText.text = "Score: {playerPoints}"
    }
}

class AutoresizeFont : Component {
    relativeSize : float = -1.

    def override on_update {
        var newSize = relativeSize * float(get_resolution().y)
        if (newSize > 0.) {
            nodeId?.UIText.fontSize = newSize
        }
    }
}
