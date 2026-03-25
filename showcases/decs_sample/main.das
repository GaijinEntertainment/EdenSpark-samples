
require engine.core
require daslib/decs_boost public


let numberOfCubes = 100
let rotationSpeed = 0.5
let cubeScale = 0.28

// can specify prefix="string", prefix for nothing, or not specify for Node_
[decs_template(prefix)]
struct Node {
    nodeId : NodeId
    cubeIndex : int
    color : float4
    angle : float
}


[decs_template(prefix)]
struct Input {
    userInput : bool
    clockwise : bool
}


def sincos(x : float) : float2 {
    var res : float2
    sincos(x, res.x, res.y)
    return res
}

def calc_angle(index : int) : float {
    return 2. * PI * float(index) / float(numberOfCubes)
}

[export]
def on_initialize() {
    add_and_activate_action_set("basic", {
        "toggleDirection" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        )
    })

    create_render_settings()
    let sun = create_node(NodeData(rotation = quat4(0, 0.5, 0)))
    add_component(sun, new DirectionLight())

    let camera = create_node(NodeData(name = "camera", position = float3(0, -1.5, -10)))
    add_component(camera, new Camera())
    look_at(camera, float3(0, 0, 0))

    for (i in range(numberOfCubes)) {
        let angle = calc_angle(i)
        let pos = sincos(angle)
        let cube = create_node(NodeData(scale = float3(cubeScale)))
        add_component(cube, new Mesh(meshId = CUBE_MESH_ID))

        create_entity(@(eid, cmp) {
            apply_decs_template(cmp, Node(nodeId = cube, cubeIndex = i, angle = angle))
        })
    }

    create_entity(@(eid, cmp) {
        apply_decs_template(cmp, Input(userInput = true, clockwise = true))
    })
}



[decs(stage = logic)]
def update_color(var node : Node) {
    let pos = 0.5 * sincos(node.angle + get_time()) + float2(0.5)
    node.color = float4(pos.x, pos.y, sin(get_time()) * 0.5 + 0.5, 1.0)
    node.nodeId?.Mesh.color = node.color
}

[decs(stage = logic)]
def update_position(input : Input) {
    query($(var node : Node) {
        node.angle += get_delta_time() * (input.clockwise ? 1. : -1.) * rotationSpeed
        let pos = sincos(node.angle)
        let y = sin(get_time() * float(node.cubeIndex + 100) * 0.01) * 3.0
        node.nodeId.localPosition = float3(pos.x * 5., y, pos.y * 5.)
    })
}


[decs(stage = control, REQUIRE=userInput)]
def update_input(var input : Input) {
    if (is_action_just_released("toggleDirection")) {
        input.clockwise = !input.clockwise
    }
}

[export]
def on_update() {
    decs_stage("control")
    decs_stage("logic")
}
