require engine.core

require engine.async.coroutine



var cube : NodeId

var debug_text_node : NodeId


def set_debug_text(text : string) {
    (get_component(debug_text_node, type<UIText>)).text = text
}


def init_debug_text(position : float2) {
    let canvas = create_node(NodeData(name = "canvas")).add_component(new UICanvas(screenMode = ScreenMode.Fullscreen)).nodeId
    debug_text_node = create_node(NodeData(parent = canvas))
    add_component(debug_text_node, new UIText(pivot = float2(0.5, 1.0), fontSize = 48f, color = float4(0, 0, 0, 1)))
    add_component(debug_text_node, new UIAnchor(anchorMin = MIDDLE_CENTER_ANCHOR, anchorMax = MIDDLE_CENTER_ANCHOR, left = position.x, top = position.y))
}


[export] def on_initialize() {

    show_mouse_cursor()

    add_and_activate_action_set("basic", {
        "click" => Action(
            buttonActions = ButtonAction(
                mouseButtons = [MouseButtonInput(idx=MouseButton.Left)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        )
    })

    cube = create_node(NodeData(name = "cube", position = float3(0, 1, 0), rotation = quat4(0, PI * 0.3f, 0)))
    add_component(cube, new Mesh(
        meshId = CUBE_MESH_ID,
        materialId = create_material(MaterialImport(
            shaderName = "standard_diffuse_shader",
            diffuse = request_texture("%builtin_package/logo.png")
        ))
    ))
    let plane = create_node(NodeData(name = "plane", scale = float3(10, 1, 10)))
    add_component(plane, new Mesh(meshId = PLANE_MESH_ID))


    let camera = create_node(NodeData(position = float3(0, 5, -5), rotation = quat4(PI / 4f, 0f, 0f)))
    add_component(camera, new Camera())

    let sun = create_node(NodeData(rotation = quat4(PI / 3f, -PI * 0.25f, 0f)))
    add_component(sun, new DirectionLight())

    let renderSettings = create_render_settings()

    init_debug_text(float2(20, 80))

    start_coroutine(start_game())
}


[async] def start_game(delay : float = 0.0, click_to_skip : bool = false) : void {
    var t = 0.
    while (t < delay) {
        t += get_delta_time()
        await_next_frame()
        if (click_to_skip && is_action_just_pressed("click")) {
            break
        }
    }
    cube.localPosition = float3(0., 1., 0.)
    start_coroutine(cube, smooth_rect_move(cube))
    set_debug_text("click to start coroutine")
}

[async] def await_mouse_press() : float {
    // wait for mouse button press
    var delay = 0.
    while (!is_action_just_pressed("click")) {
        await_next_frame()
        delay += get_delta_time()
        if (delay > 10.0) {
            print("timeout waiting for mouse press")
            return false
        }
    }

    set_debug_text("")
    yield delay
}


[async] def smooth_move(node : NodeId; from, to : float3; time : float) : void {
    var t = 0f
    while (t < time) {
        node.localPosition = lerp(from, to, float3(t / time))
        await_next_frame()
        t += get_delta_time()
    }

    node.localPosition = to
}

var canStop = false

[async] def smooth_rect_move(node : NodeId; width : float = 2.; time : float = 1f) : void {
    let delay = await(await_mouse_press())
    print("Button pressed after {delay} seconds")
    set_debug_text("moving forward")
    await(smooth_move(node, float3(0., 1., 0.), float3(0., 1., width), time))
    set_debug_text("moving right\nclick to stop")
    canStop = true
    await(smooth_move(node, float3(0., 1., width), float3(width, 1., width), time))
    set_debug_text("moving back\nclick to stop")
    await(smooth_move(node, float3(width, 1., width), float3(width, 1., 0.), time))
    set_debug_text("moving left\nclick to stop")
    await(smooth_move(node, float3(width, 1., 0.), float3(0., 1., 0.), time))
    canStop = false

    start_coroutine(start_game())
}


[export] def on_update() {
    if (canStop && is_action_just_pressed("click")) {
        if (stop_coroutines(cube)) {
            canStop = false
            set_debug_text("stopped, click to restart or wait 2 sec")
            start_coroutine(start_game(2., /*click_to_skip*/ true))
        }
    }
}