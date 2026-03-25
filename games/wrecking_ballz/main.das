require engine.core

require common
require bird
require camera
require pig

let level1Prefab = request_prefab("levels/level1.prefab")
let groundPrefab = request_prefab("ground.prefab")
let cameraPrefab = request_prefab("camera.prefab")
let uiPrefab = request_prefab("ui.prefab")

var curLevel : NodeId

def init_static_scene() {
    let staticLevel = instantiate_prefab(groundPrefab)
    staticLevel.localPosition = float3(0, 0, 5)
    add_bird_nest()
    instantiate_prefab(uiPrefab)

    let flatShading = create_base_render_settings("flat shading")
    add_component(flatShading, new AmbientSettings(
        ambientStrength = 1f,
        ambientColor = float3(1f),
        ambientSource = AmbientSource.ConstColor
    ))
}

def reset_scene() {
    if (!!curLevel) {
        remove_node(curLevel)
    }
    curLevel = instantiate_prefab(level1Prefab)
    curLevel.localPosition = float3(0, 0, 5)
}

[cheat] def reset_level() {
    reset_scene()
}

[export] def on_initialize() {
    instantiate_prefab(cameraPrefab)

    // setup scene - static & dynamic
    init_static_scene()
    reset_scene()

    // not-so-important stuff
    show_mouse_cursor(true)
    set_physics_fps(100f)

    add_and_activate_action_set("game", {
        "reset" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.R)],
            )
        )
    })

    add_and_activate_action_set("player", {
        "aim" => Action(
            pointerActions = PointerAction(
                valueType = ValueType.Accumulate,
                mouse = MouseInput(active = true),
            )
        ),
        "aimAngle" => Action(
            pointerActions = PointerAction(
                valueType = ValueType.Delta,
                mouse = MouseInput(active = true),
            )
        ),
        "fire" => Action(
            buttonActions = ButtonAction(
                mouseButtons = [MouseButtonInput(idx=MouseButton.Left)],
            )
        ),
    })
}


[export]
def on_update() {
    let dt = get_delta_time()

    if (is_action_just_pressed("reset")) {
        reset_level()
    }
}
