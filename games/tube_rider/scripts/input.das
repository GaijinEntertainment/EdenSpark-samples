require engine.core

[export]
def on_initialize() {
    let inputHandler : ActionSet = {
        "turn_mouse" => Action(
            pointerActions = PointerAction(
                valueType = ValueType.Delta,
                mouse = MouseInput(active = true),
            ),
        ),
        "turn_stick" => Action(
            joystickActions = JoystickAction(
                sticks = [GamepadStickInput(xIdx = GamepadAxis.LThumbH), GamepadStickInput(xIdx = GamepadAxis.RThumbH)]
            )
        ),
        "turn_button" => Action(
            axisActions = AxisAction(
                keyboardAxis = [KeyboardBtnAxisInput(negativeIdx = KeyCode.A, positiveIdx = KeyCode.D), KeyboardBtnAxisInput(negativeIdx = KeyCode.Left, positiveIdx = KeyCode.Right)],
                gamepadAxis = [GamepadBtnAxisInput(negativeIdx = GamepadButton.Left, positiveIdx = GamepadButton.Right), GamepadBtnAxisInput(negativeIdx = GamepadButton.X, positiveIdx = GamepadButton.B)],
            )
        ),
        "pause" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx = KeyCode.Back)],
                gamepadButtons = [GamepadButtonInput(idx = GamepadButton.Back)]
            )
        ),
    }

    add_and_activate_action_set("handler", inputHandler)
}
