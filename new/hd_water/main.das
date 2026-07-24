require engine.core

var isBadWeather = false
var badWeatherNode : NodeId
var goodWeatherNode : NodeId

class NodeSubmerger : Component {
    private isSubmerged : bool = false
    upHeight : float = 0.0f
    downHeight : float = 0.0f
    def override on_update() {
        let dt = get_delta_time()
        if (is_action_just_pressed("Submerge")) {
            isSubmerged = !isSubmerged
        }
        let newY = approach(nodeId.localPosition.y, isSubmerged ? downHeight : upHeight, dt, 0.2f)
        nodeId.localPosition = float3(nodeId.localPosition.x, newY, nodeId.localPosition.z)
    }
}

[export] def on_initialize() {
    show_mouse_cursor(false)

    let inputHandler : ActionSet = {
        "Switch Weather" => Action(
            buttonActions = ButtonAction(
                mouseButtons = [MouseButtonInput(idx=MouseButton.Left)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        ),
        "Submerge" => Action(
            buttonActions = ButtonAction(
                mouseButtons = [MouseButtonInput(idx=MouseButton.Right)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.B)]
            )
        )
    }

    add_and_activate_action_set("handler", inputHandler)

    badWeatherNode = instantiate_prefab(request_prefab("bad_weather.prefab"))
    goodWeatherNode = instantiate_prefab(request_prefab("good_weather.prefab"))
    badWeatherNode.isActive = false

    create_debug_text("LMB/GamepadA to switch view; RMB/GamepadB to submerge/emerge", float2(20, -20), BOTTOM_LEFT_ANCHOR)
}

[export] def on_update() {
    if (is_action_just_pressed("Switch Weather")) {
        isBadWeather = !isBadWeather
        badWeatherNode.isActive = isBadWeather
        goodWeatherNode.isActive = !isBadWeather
    }
}
