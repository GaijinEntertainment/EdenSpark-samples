require engine.core
require engine.free_camera

var camera : NodeId

def get_nice_color() : float3 {
    return get_random_color(float3(0.0, 0.85, 1.0)).xyz
}

[export] def on_initialize() {

    // make the random seed fixed for consistent results
    set_random_seed(0)
    show_mouse_cursor(true)
    let scale = float3(200f, 0.1f, 200f)
    let plane = create_node(NodeData(scale = scale, name = "plane"))
    add_component(plane, new Mesh(meshId = CUBE_MESH_ID))
    add_component(plane, new Collider(shape = box_shape(scale)))

    let sunDirection = float3(PI / 12f, -PI * 0.25f, 0f)
    let sun = create_node(NodeData(rotation = quat4(sunDirection), name = "sun"))
    add_component(sun, new DirectionLight())

    let renderSettings = create_render_settings()

    toggle_free_camera(camera, float3(0, 6, -12), quat4(float3(PI * 0.15f, 0f, 0f)))

    for (i in -5 .. 5) {
        for (j in -5 .. 5) {
            let anchor = float3(0, 5f, 0)
            let offset = random_point_inside_unit_sphere() * 5f
            let node = create_node(NodeData(position = anchor + offset, name = "object"))
            node.add_component(new RigidBody())
            var meshId : MeshId
            var shape : Shape
            let rand = random_range(0, 3)
            if (rand == 0) {
                meshId = CUBE_MESH_ID
                shape = box_shape()
            } elif (rand == 1) {
                meshId = CYLINDER_MESH_ID
                shape = cylinder_shape()
            } else {
                meshId = SPHERE_MESH_ID
                shape = sphere_shape()
            }
            node.add_component(new Mesh(meshId = meshId))
            node.add_component(new Collider(shape = shape))
            if (random_float() < 0.2f) {
                node.add_component(new Outline(color = get_nice_color(), zTest = OutlineZTest.ZTestOn))
            }
        }
    }

    let inputHandler : ActionSet = {
        "Select" => Action(
            buttonActions = ButtonAction(
                mouseButtons = [MouseButtonInput(idx=MouseButton.Left)]
            )
        ),
        "Position" => Action(
            pointerActions = PointerAction(
                valueType = ValueType.Accumulate,
                mouse = MouseInput(active = true)
            )
        )
    }

    add_and_activate_action_set("handler", inputHandler)
    create_debug_text("Click objects to toggle outline", float2(20, -20), BOTTOM_LEFT_ANCHOR)
}

[export] def on_update() {
    if (is_action_just_pressed("Select")) {
        get_component(camera) $(cam : Camera?) {
            let ray = cam.screenToRay(get_action_vector2("Position"))
            trace(RayCast(ray = ray)) $(hit) {
                var removeOutline = false
                let hasOutline = get_component(hit.nodeId) $(var outline : Outline?) {
                    if (outline.zTest == OutlineZTest.ZTestOn) {
                        outline.zTest = OutlineZTest.ZTestOff
                    } elif (outline.zTest == OutlineZTest.ZTestOff) {
                        outline.zTest = OutlineZTest.ZTestInverted
                    } else {
                        removeOutline = true
                    }
                }
                if (removeOutline) {
                    hit.nodeId.remove_component(type<Outline>)
                } elif (!hasOutline) {
                    hit.nodeId.add_component(new Outline(color = get_nice_color(), zTest = OutlineZTest.ZTestOn))
                }
            }
        }
    }
}