require engine.core


[export] def on_initialize() {

    let cube = create_node(NodeData(name = "cube", position = float3(0, 1, 0), rotation = quat4(0, PI * 0.3f, 0)))
    add_component(cube, new Mesh(meshId = CUBE_MESH_ID))
    let plane = create_node(NodeData(name = "plane", scale = float3(10, 1, 10)))
    add_component(plane, new Mesh(meshId = PLANE_MESH_ID))

    let camera = create_node(NodeData(name = "camera", position = float3(0, 5, -5), rotation = quat4(PI / 4f, 0, 0)))
    add_component(camera, new Camera())

    let sun = create_node(NodeData(name = "sun", rotation = quat4(PI / 3f, -PI * 0.25f, 0f)))
    add_component(sun, new DirectionLight())

    let renderSettings = create_render_settings()
}

[export]
def on_update() {
}
