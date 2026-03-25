require engine.core
require engine.free_camera


[export]
def on_initialize() {
    // create free camera
    create_free_camera(float3(0, 25, -190))

    // create light
    add_component(create_node(NodeData(rotation = quat4(0.2, PI, 0), name = "sun")), new DirectionLight())

    // add default render settings
    let renderSettings = create_render_settings()

    let waterNode = create_node(NodeData(scale = float3(1000f, 1f, 1000f), name = "water"))
    add_component(waterNode, new Mesh(
        meshId = PLANE_MESH_ID,
        materialId = request_material("water.material")
    ))
}
