require engine.core


var triangleNode : NodeId
var trianglePos = float2(0)
var triangleAngle = PI * 0.5

var speed = float2(0)
let maxSpeed = 1.5
let accelerationForward = 3.
let accelerationBackward = 1.
let deceleration = 0.5
let angularVel = PI


def init_input() {
    add_and_activate_action_set("input", {
        "acceleration" => Action(
            axisActions = AxisAction(
                keyboardAxis = [KeyboardBtnAxisInput(negativeIdx=KeyCode.Down, positiveIdx=KeyCode.Up), KeyboardBtnAxisInput(negativeIdx=KeyCode.S, positiveIdx=KeyCode.W)],
                stickAxis = [GamepadAxisInput(idx=GamepadAxis.LThumbV)]
            )
        ),
        "rotation" => Action(
            axisActions = AxisAction(
                keyboardAxis = [KeyboardBtnAxisInput(negativeIdx=KeyCode.Left, positiveIdx=KeyCode.Right), KeyboardBtnAxisInput(negativeIdx=KeyCode.A, positiveIdx=KeyCode.D)],
                stickAxis = [GamepadAxisInput(idx=GamepadAxis.LThumbH)]
            )
        )
    })
}

def update_input() {
    let dt = get_delta_time()
    if (length_sq(speed) < maxSpeed * maxSpeed) {
        let axis = get_action_axis("acceleration")
        if (axis > 0.) {
            speed += angle_to_direction(triangleAngle) * accelerationForward * axis * dt
        }
        if (axis < 0.) {
            speed -= angle_to_direction(triangleAngle) * accelerationBackward * -axis * dt
        }
    }
    if (length_sq(speed) > 0.) {
        speed = normalize(speed) * (length(speed) - deceleration * dt)
    }
    if (length_sq(speed) > maxSpeed * maxSpeed) {
        speed = normalize(speed) * maxSpeed
    }
    trianglePos += speed * dt

    let dAngle = angularVel * dt
    triangleAngle -= get_action_axis("rotation") * dAngle
}



[export]
def on_initialize() {
    let quadMesh = QUAD_MESH_ID
    triangleNode = create_node(NodeData(name = "triangle", position = ZERO, scale = float3(0.5)))
    let triangleTexture = request_texture("assets/basic_triangle.png")
    let triangleMaterial = create_material(MaterialImport(
        shaderName = "standard_unlit_shader",
        diffuse = triangleTexture,
        transparencyMode = TransparencyMode.Translucent,
        faceCullMode = FaceCullMode.None
    ))
    add_component(triangleNode, new Mesh(meshId = quadMesh, materialId = triangleMaterial))

    let camera = create_node(NodeData(name = "camera", position = float3(0, 0, -5)))
    add_component(camera, new Camera(orthographic = true, orthographicSize = 10f))// 10 game meters

    init_input()
}


[export]
def on_update() {
    update_input()
    triangleNode.localPosition = float3(trianglePos, 0.)
    triangleNode.localRotation = quat4(FORWARD, triangleAngle - PI * 0.5)
}
