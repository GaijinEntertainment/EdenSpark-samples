require engine.core


//////////////////////////////// Debug UI //////////////////////////////////////////

let LINES_COUNT = 15

var debug_text_node : NodeId[LINES_COUNT]
var lines : string[LINES_COUNT]

def init_debug_text(position : float2) {
    for (node, i in debug_text_node, count()) {
        node = create_debug_text(float2(position.x, position.y + float((i - LINES_COUNT / 2) * 30)), MIDDLE_CENTER_ANCHOR)
    }
}

def add_debug_line(text : string) {
    for (i in range(1, LINES_COUNT)) {
        lines[i - 1] = lines[i]
    }

    lines[LINES_COUNT - 1] = text

    for (node, line in debug_text_node, lines) {
        update_debug_text(node, line)
    }
}

////////////////////////////////////////////////////////////////////////////////////


let keyMap <- [
    (GamepadButton.Up, "Up"),
    (GamepadButton.Down, "Down"),
    (GamepadButton.Left, "Left"),
    (GamepadButton.Right, "Right"),
    (GamepadButton.Start, "Start"), // hidden
    (GamepadButton.Back, "Back"),
    (GamepadButton.L3, "L3"),
    (GamepadButton.R3, "R3"),
    (GamepadButton.A, "A"),
    (GamepadButton.B, "B"),
    (GamepadButton.X, "X"),
    (GamepadButton.Y, "Y"),
    (GamepadButton.LeftBumper, "LB"),
    (GamepadButton.RightBumper, "RB"),
    (GamepadButton.LeftTrigger, "LT"),
    (GamepadButton.RightTrigger, "RT"),
]


def get_gamepad_keys(input_key : GamepadButtons) : string {
    var name = ""
    for (key in keyMap) {
        if ((input_key & key._0) != bitfield(0)) {
            name += key._1 + " "
        }
    }
    return name
}


def is_any_button(input_key : GamepadButtons) : bool {
    for (key in keyMap) {
        return true if ((input_key & key._0) != bitfield(0))
    }
    return false
}


def is_button_event(event : RawGamepadInputEvent) : bool {
    return is_any_button(event.buttonDownState) || is_any_button(event.buttonPressedState) || is_any_button(event.buttonReleasedState)
}


def is_right_stick_event(event : RawGamepadInputEvent) : bool {
    return event.rxyz != float3(0)
}


def is_left_stick_event(event : RawGamepadInputEvent) : bool {
    return event.xyz != float3(0)
}


////////////////////////////////////////////////////////////////////////////////////


[export]
def on_initialize() {
    // create fixed camera
    add_component(create_node(), new Camera())

    // add text to the screen
    init_debug_text(float2(0, 0))
    add_debug_line("Press the gamepad to get input events")
}


[export]
def on_update() {
    for (cmd in get_input_command_buffer()) {
        if (cmd is RawGamepadInputEvent) {
            let gamepad = cmd as RawGamepadInputEvent
            // print entire event to the console
            print("Gamepad input event {gamepad}")

            let debugLine = build_string() $(var str) {
                if (is_button_event(gamepad)) {
                    write(str, ", states: down ")
                    write(str, get_gamepad_keys(gamepad.buttonDownState))
                    write(str, ", pressed ")
                    write(str, get_gamepad_keys(gamepad.buttonPressedState))
                    write(str, ", released ")
                    write(str, get_gamepad_keys(gamepad.buttonReleasedState))

                    // add slider coords if such action exists (only with GamepadButton.LeftBumper and GamepadButton.RightBumper)
                    if (gamepad.slider != float2(0)) {
                        write(str, ", slider: ")
                        write(str, gamepad.slider)
                    }
                }

                if (is_right_stick_event(gamepad)) {
                    write(str, ", right xyz = ")
                    write(str, gamepad.rxyz)
                }

                if (is_left_stick_event(gamepad)) {
                    write(str, ", left xyz = ")
                    write(str, gamepad.xyz)
                }
            }

            // event can be multi-type, add line only if some type of event exists (button/right stick/left stick)
            if (debugLine != "") {
                add_debug_line("id: {gamepad.gamepadIndex}{debugLine}")
            }
        }
    }
}
