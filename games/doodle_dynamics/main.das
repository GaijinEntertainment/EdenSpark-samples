require engine.core

let LINE_WIDTH = 2.0
let THRESHOLD_ANGLE = 5. * TO_RAD
let THRESHOLD_DISTANCE = LINE_WIDTH
let LINE_COLOR = color32_to_float4(0x18396eff)
let MAX_CAPSULES_COUNT = 100

let defaultMaterial = create_material(MaterialImport(shaderName = "standard_unlit_shader"))

let ROOM_ASPECT = 4. / 3.
let ROOM_VERT_SIZE = 200.
let EDGES_MARGIN = 0.02

var camera : NodeId
var curShapeParent : NodeId
var curShapePoints : array<float2>
var curLineVisual : NodeId
var hint : NodeId

class RemovableTag : Component {}

[export]
def on_initialize() {
    let edgeVerPos = ROOM_VERT_SIZE * 0.5
    let edgeHorPos = edgeVerPos * ROOM_ASPECT

    set_gravity(float3(0, -20, 0))
    set_physics_fps(100.)

    camera = create_node(NodeData(name = "camera", position = float3(0, 0, -10)))
    add_component(camera, new Camera(
        orthographic = true,
        orthographicSize = ROOM_VERT_SIZE * (EDGES_MARGIN + 1.0),
        fovAxis = FovAxis.Vertical,
        fov = TO_RAD * 90f,
        backgroundColor = color32_to_float4(0xffffffff).xyz
    ))

    let floor = create_node(NodeData(name = "floor", position = float3(0, -edgeVerPos - ROOM_VERT_SIZE / 2., 0), scale = float3(ROOM_VERT_SIZE * 3., ROOM_VERT_SIZE, 1)))
    add_component(floor, new Collider(shape = box_shape()))

    let ceiling = create_node(NodeData(name = "ceiling", position = float3(0, edgeVerPos + ROOM_VERT_SIZE / 2., 0), scale = float3(ROOM_VERT_SIZE * 3., ROOM_VERT_SIZE, 1)))
    add_component(ceiling, new Collider(shape = box_shape()))

    let wallLeft = create_node(NodeData(name = "wallLeft", position = float3(-edgeHorPos - ROOM_VERT_SIZE / 2., 0, 0), scale = float3(ROOM_VERT_SIZE, ROOM_VERT_SIZE, 1)))
    add_component(wallLeft, new Collider(shape = box_shape()))

    let wallRight = create_node(NodeData(name = "wallRight", position = float3(edgeHorPos + ROOM_VERT_SIZE / 2., 0, 0), scale = float3(ROOM_VERT_SIZE, ROOM_VERT_SIZE, 1)))
    add_component(wallRight, new Collider(shape = box_shape()))

    let floorLine = create_node(NodeData(name = "floor_line", position = float3(0, -edgeVerPos - LINE_WIDTH * 0.5, 0), scale = float3(ROOM_VERT_SIZE * ROOM_ASPECT + LINE_WIDTH * 2., LINE_WIDTH, 1)))
    add_component(floorLine, new Mesh(meshId = CUBE_MESH_ID, materialId = defaultMaterial, color = color32_to_float4(0xff000000)))

    let ceilingLine = create_node(NodeData(name = "ceiling_line", position = float3(0, edgeVerPos + LINE_WIDTH * 0.5, 0), scale = float3(ROOM_VERT_SIZE * ROOM_ASPECT + LINE_WIDTH * 2., LINE_WIDTH, 1)))
    add_component(ceilingLine, new Mesh(meshId = CUBE_MESH_ID, materialId = defaultMaterial, color = color32_to_float4(0xff000000)))

    let leftWallLine = create_node(NodeData(name = "left_wall_line", position = float3(-edgeHorPos - LINE_WIDTH * 0.5, 0, 0), scale = float3(LINE_WIDTH, ROOM_VERT_SIZE + LINE_WIDTH * 2., 1)))
    add_component(leftWallLine, new Mesh(meshId = CUBE_MESH_ID, materialId = defaultMaterial, color = color32_to_float4(0xff000000)))

    let rightWallLine = create_node(NodeData(name = "right_wall_line", position = float3(edgeHorPos + LINE_WIDTH * 0.5, 0, 0), scale = float3(LINE_WIDTH, ROOM_VERT_SIZE + LINE_WIDTH * 2., 1)))
    add_component(rightWallLine, new Mesh(meshId = CUBE_MESH_ID, materialId = defaultMaterial, color = color32_to_float4(0xff000000)))

    hint = create_node(NodeData(name = "hint"))
    add_component(hint, new UIText(text = "Left click to draw a line, right click to remove a line", color = color32_to_float4(0xff000000)))

    show_mouse_cursor(true)

    add_and_activate_action_set("player", {
        "startDraw" => Action(
            buttonActions = ButtonAction(
                mouseButtons = [MouseButtonInput(idx=MouseButton.Left)],
            )
        ),
        "cursor" => Action(
            pointerActions = PointerAction(
                valueType = ValueType.Accumulate,
                mouse = MouseInput(active = true),
            )
        ),
        "startRemove" => Action(
            buttonActions = ButtonAction(
                mouseButtons = [MouseButtonInput(idx=MouseButton.Right)],
            )
        )
    })

    let settings = create_base_render_settings()
    add_component(settings, new AntiAliasing(mode = AntiAliasingMode.FXAA, fxaa_quality = FXAAQuality.Low))
}

[export]
def on_update() {
    if (is_action_just_pressed("startDraw")) {
        let mouse_pos = get_action_vector2("cursor")
        let pos = camera?.Camera.screenToWorld(mouse_pos).xy
        create_line(pos)
        if (hint.isAlive) {
            remove_node(hint)
        }
    }
    if (is_action_pressed("startDraw") && !curShapePoints.empty()) {
        let mouse_pos = get_action_vector2("cursor")
        let pos = camera?.Camera.screenToWorld(mouse_pos).xy
        let prevPos = curShapePoints.empty() ? pos : curShapePoints[curShapePoints.length() - 1]

        let capsuleQuery = CapsuleQuery(
            position = float3((pos + prevPos) * 0.5, 0.),
            height = length(pos - prevPos),
            radius = LINE_WIDTH * 0.5,
            axis = AxisDirection.YAxis,
            rotation = make_quat_from_basis_zy(float3(0, 0, 1), float3(pos - prevPos, 0.))
        )
        overlap(capsuleQuery) $(hits : array<OverlapHit>#) {
            if (!hits.empty()) {
                finish_shape()
            }
        }

        if (!curShapePoints.empty()) {
            let canContinuePath = create_line(pos)
            if (!canContinuePath) {
                finish_shape()
            }
        }
    }

    if (!is_action_pressed("startDraw") && !curShapePoints.empty()) {
        finish_shape()
    }

    if (is_action_pressed("startRemove") && curShapePoints.empty()) {
        let mouse_pos = get_action_vector2("cursor")
        let pos = camera?.Camera.screenToWorld(mouse_pos).xy
        var wasRemoved = false
        overlap(SphereQuery(position = float3(pos, 0.), radius = LINE_WIDTH * 0.5)) $(hits : array<OverlapHit>#) {
            for (hit in hits) {
                if (hit.nodeId.isAlive && hit.nodeId.has_component(type<RemovableTag>)) {
                    hit.nodeId.remove_node()
                    wasRemoved = true
                }
            }
        }
        if (wasRemoved) {
            // NOTE: after removing a node some other nodes could remaing hanging in the air
            // so wake up all the physics nodes
            for (tagComp in find_components(type<RemovableTag>)) {
                get_component(tagComp.nodeId, $(var rigidBody : RigidBody?) {
                    rigidBody.isSleeping = false
                })
            }
        }
    }
}

def create_line(newPos : float2) : bool {
    if (curShapePoints.empty()) {
        curShapePoints.push(newPos)
    }

    if (curShapeParent == NodeId()) {
        curShapeParent = create_node(NodeData(name = "shape"))
    }

    let prevPoint = (curShapePoints.length() > 1) ? curShapePoints[curShapePoints.length() - 1] : newPos
    let rotation = angle_between(float2(0, 1), newPos - prevPoint)

    let prevLineStart = curShapePoints.length() > 1 ? curShapePoints[curShapePoints.length() - 2] : curShapePoints[curShapePoints.length() - 1]
    let updatedLineRotation = angle_between(float2(0, 1), newPos - prevLineStart)
    if (!!curLineVisual &&
            (abs(angle_diff(updatedLineRotation, rotation)) <= THRESHOLD_ANGLE ||
            length(newPos - prevLineStart) <= THRESHOLD_DISTANCE)) {
        curLineVisual.localPosition = float3((prevLineStart + newPos) * 0.5, 0.)
        curLineVisual.localRotation = quat4(0, 0, updatedLineRotation)
        curLineVisual.localScale = float3(LINE_WIDTH, length(newPos - prevLineStart), LINE_WIDTH)

        curShapePoints[curShapePoints.length() - 1] = newPos
    } else {
        curShapePoints.push(newPos)
        curLineVisual = NodeId()
    }

    if (!curLineVisual) {
        let lineCenter = (curShapePoints.length() > 1) ? ((prevPoint + newPos) * 0.5) : newPos
        let scale = length(newPos - prevPoint)

        let startCap = create_node(NodeData(name = "joint", parent = curShapeParent, position = float3(prevPoint, 0.), scale = float3(LINE_WIDTH)))
        add_component(startCap, new Mesh(meshId = SPHERE_MESH_ID, materialId = defaultMaterial, color = LINE_COLOR))

        let line = create_node(NodeData(name = "line", parent = curShapeParent, position = float3(lineCenter, 0.), rotation = quat4(0, 0, rotation), scale = float3(LINE_WIDTH, scale, LINE_WIDTH)))
        add_component(line, new Mesh(meshId = CUBE_MESH_ID, materialId = defaultMaterial, color = LINE_COLOR))

        curLineVisual = line
    }

    return curShapePoints.length() <= MAX_CAPSULES_COUNT
}

def finish_shape() {
    if (!curShapeParent) {
        return
    }

    let endCap = create_node(NodeData(name = "path_end", parent = curShapeParent, position = float3(curShapePoints[length(curShapePoints) - 1], 0.), scale = float3(LINE_WIDTH)))
    add_component(endCap, new Mesh(meshId = SPHERE_MESH_ID, materialId = defaultMaterial, color = LINE_COLOR))

    var shapesLen = 0.
    var shapes : array<Shape>
    if (!curShapePoints.empty()) {
        for (line_idx in range(1, curShapePoints.length())) {
            let a = curShapePoints[line_idx - 1]
            let b = curShapePoints[line_idx]
            let abLen = distance(a, b)
            let abRot = quat4(0, 0, angle_between(float2(0, 1), b - a))
            shapes.push(capsule_shape(LINE_WIDTH * 0.5, abLen + LINE_WIDTH, AxisDirection.YAxis, float3((a + b) / 2., 0.), abRot))
            shapesLen += abLen
        }
    }
    curShapePoints.clear()

    let mass = max(shapesLen, 1.0)
    curShapeParent.add_component(new RigidBody(mass = mass, allowedDofs = AllowedDofs.AllowedDofs2D, collisionDetection = CollisionDetection.Continuous))
    curShapeParent.add_component(new Collider(shapes = shapes))
    curShapeParent.add_component(new RemovableTag())
    curShapeParent = NodeId()
    curLineVisual = NodeId()
}

def cross(a : float2, b : float2) : float {
    return a.x * b.y - b.x * a.y
}

def angle_between(a : float2, b : float2) : float {
    var lengthMul = 1.
    if (abs(length_sq(a) - 1.) > 1e-5) {
        lengthMul *= length(a)
    }
    if (abs(length_sq(b) - 1.) > 1e-5) {
        lengthMul *= length(b)
    }
    if (lengthMul == 0.) {
        return 0.
    }
    let angle = acos(dot(a, b) / lengthMul)
    let isCcw = cross(a, b) >= 0.
    return angle * (isCcw ? 1. : -1.)
}
