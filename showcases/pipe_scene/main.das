require engine.core
require engine.free_camera

let cameraPos = float3(0, 120, 95)
let cameraEuler = float3(PI / 3f, PI, 0f)

let sunDirection = float3(-2f * PI / 3f, -PI / 3f, 8f * PI / 9f)
var pipeNode : NodeId
var extruderNode : NodeId

def init_camera() {
    let camera = create_free_camera(cameraPos, quat4(cameraEuler))

    let sun = create_node(NodeData(rotation = quat4(sunDirection)))
    add_component(sun, new DirectionLight())

    let renderSettings = create_render_settings()
    get_component(renderSettings) $(var shadow : ShadowSettings?) {
        shadow.powWeight = 0.9f
    }
    get_component(renderSettings) $(var tonemap : Tonemap?) {
        tonemap.active = true
    }
}


def init_world() {

    init_camera()
    var pipePoints <- [
        float3(0, 0, -36),
        float3(9, 2, -3),
        float3(0, -2, 12),
        float3(-36, 0, 24),
        float3(-9, 2, -3),
        float3(9, -2, -3),
        float3(36, 0, 24),
        float3(0, 2, 12),
        float3(-9, -2, -3)
    ]
    let pipeMesh = create_pipe_mesh(PipeInit(
        points <- pipePoints,
        closed = true
    ))
    pipeNode = create_node(NodeData())
    add_component(pipeNode, new Mesh(
        meshId = pipeMesh,
        materialId = request_material("assets/uv_checker.material")
    ))

    var polygonPoints <- [
        float2(-0.5, -0.5),
        float2(-0.5, 0.5),
        float2(-0.3, 0.1),
        float2(0.3, 0.1),
        float2(0.5, 0.5),
        float2(0.5, -0.5),
        float2(0.3, -0.1),
        float2(-0.3, -0.1)
    ]

    var extruderPoints <- [
        float3(0, -10, 50),
        float3(0, 10, 50),
        float3(0, 10, 60),
        float3(-10, 10, 60),
        float3(-10, 10, 40),
        float3(10, 10, 40),
        float3(10, 10, 60),
        float3(10, 0, 60),
        float3(-10, 0, 60),
        float3(-10, 0, 40),
        float3(10, 0, 40),
        float3(10, -10, 40),
        float3(10, -10, 60),
        float3(-10, -10, 60),
        float3(-10, -10, 40),
        float3(0, -10, 40)
    ]

    let extruderMesh = create_extruder_mesh(ExtruderInit(
        polygonPoints <- polygonPoints,
        points <- extruderPoints,
        closed = true
    ))
    extruderNode = create_node(NodeData())
    add_component(extruderNode, new Mesh(
        meshId = extruderMesh,
        materialId = request_material("assets/uv_checker.material")
    ))
}


[export] def on_initialize() {
    init_world()
}


[export]
def on_update() {
    let t = get_time()
    pipeNode.localRotation = quat4(0, 0.5 * t, 0)
}
