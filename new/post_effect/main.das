require engine.core
require engine.arcball_camera

var settingsNode : NodeId

struct PostFxEntry {
    name : string
    matId : MaterialId
}

class PostFxSelector : Component {
    @no_export entries  : array<PostFxEntry>
    @no_export hintNode : NodeId
    @no_export current  : int = 0  // 0 = none, 1..N = entries[0..N-1]

    def override on_initialize() {
        hintNode = create_debug_text("[Tab] none", float2(10, 10), TOP_LEFT_ANCHOR)
        add_and_activate_action_set("postfx_select", {
            "nextFx" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx = KeyCode.Tab)]
                )
            ),
            "prevFx" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx = KeyCode.Tab, modifier = KeyboardShifts.Shift)]
                )
            ),
            "toggleFx" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx = KeyCode.Space)]
                )
            )
        })
}

    def applyFx() {
        if (has_component(settingsNode, type<PostEffect>)) {
            remove_component(settingsNode, type<PostEffect>)
        }
        let name = current > 0 ? entries[current - 1].name : "none"
        if (current > 0 && !is_action_pressed("toggleFx")) {
            add_component(settingsNode, new PostEffect(materialId = entries[current - 1].matId))
        }
        update_debug_text(hintNode, "[Tab/Shift+Tab] {name}  [Space] hide")
    }

    def override on_update() {
        let n = length(entries) + 1
        if (is_action_just_pressed("nextFx")) {
            current = (current + 1) % n
            applyFx()
        } elif (is_action_just_pressed("prevFx")) {
            current = (current + n - 1) % n
            applyFx()
        } elif (is_action_just_pressed("toggleFx") || is_action_just_released("toggleFx")) {
            applyFx()
        }
    }
}


def make_colored_cube(pos : float3; col : float4; sz : float3 = float3(1)) {
    let n = create_node(NodeData(name = "cube"))
    add_component(n, new Mesh(meshId = CUBE_MESH_ID))
    n.localPosition = pos
    n.localScale = sz
    n?.Mesh.color = col
    return n
}

[export]
def on_initialize() {
    show_mouse_cursor(true)

    let camera = create_node(NodeData(name = "arcball_camera"))
    camera.add_component(new Camera(backgroundColor = float3(0, 0, 0)))
    camera.add_component(new ArcballCamera())

    // Floor
    make_colored_cube(float3(0, -1, 0),  float4(0.25, 0.22, 0.30, 1), float3(120, 0.2, 120))

    // Central cluster — objects at varied depths so waves cross them at different times
    make_colored_cube(float3(0.0,  0,  0),   float4(0.9, 0.3, 0.2, 1))
    make_colored_cube(float3(2.0,  0,  2.0), float4(0.2, 0.7, 0.3, 1))
    make_colored_cube(float3(-2.0,  0,  2.0), float4(0.2, 0.4, 0.9, 1))
    make_colored_cube(float3(0.0,  0,  4.0), float4(0.9, 0.8, 0.1, 1))
    make_colored_cube(float3(0.0,  0,  7.0), float4(0.8, 0.2, 0.8, 1))
    make_colored_cube(float3(3.5,  0,  5.5), float4(0.1, 0.9, 0.9, 1))
    make_colored_cube(float3(-3.5,  0,  5.5), float4(1.0, 0.5, 0.1, 1))

    // Pillars at increasing depth
    make_colored_cube(float3(1.0,  0.5,  1.5), float4(0.8, 0.8, 1.0, 1), float3(0.5, 2.0, 0.5))
    make_colored_cube(float3(-1.0,  0.5,  3.5), float4(0.8, 1.0, 0.8, 1), float3(0.5, 2.0, 0.5))
    make_colored_cube(float3(1.5,  0.5,  6.0), float4(1.0, 0.8, 0.8, 1), float3(0.5, 2.0, 0.5))

    // Small cubes on top of pillars
    make_colored_cube(float3(1.0,  1.8,  1.5), float4(1.0, 1.0, 0.5, 1), float3(0.4))
    make_colored_cube(float3(-1.0,  1.8,  3.5), float4(0.5, 1.0, 1.0, 1), float3(0.4))
    make_colored_cube(float3(1.5,  1.8,  6.0), float4(1.0, 0.5, 1.0, 1), float3(0.4))

    let light = create_node(NodeData(name = "sun"))
    add_component(light, new DirectionalLight())
    light.localRotation = quat4(float3(40.0, 20.0, 0.0))

    settingsNode = create_render_settings()

    let names = [
        "scanner",
        "depth_vis",
        "vignette",
        "depth_outline",
        "heat_haze",
        "frost",
        "heal",
        "damage",
        "helmet",
        "radial_blur",
        "night_vision",
        "sharpen",
    ]

    var entries = [for (name in names); PostFxEntry(name = name, matId = request_material("materials/{name}.material"))]

    let selector = create_node(NodeData(name = "postfx_selector"))
    add_component(selector, new PostFxSelector(entries <- entries))
}
