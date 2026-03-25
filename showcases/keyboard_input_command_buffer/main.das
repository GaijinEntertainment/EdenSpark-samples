require engine.core
require daslib/utf8_utils


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


[export]
def on_initialize() {
    // create fixed camera
    add_component(create_node(), new Camera())

    // add text to the screen
    init_debug_text(float2(0, 0))
    add_debug_line("Press the keyboard to get input events")
}


[export]
def on_update() {
    for (cmd in get_input_command_buffer()) {
        // handle keyboard event depending on its kind
        match (cmd) {
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyDown, buttonIdx = $v(buttonIdx), charCode = $v(charCode), repeat = $v(repeat))) {
                var inscope utf <- utf8_encode(charCode)
                add_debug_line("kind = KeyDown, {string(utf)} (code: {charCode}), buttonIdx = {buttonIdx} ({int(buttonIdx)}), is repeat: {repeat}")
            }
            if (RawKeyboardInputEvent(kind = RawKeyboardInputEventKind.KeyUp, buttonIdx = $v(buttonIdx))) {
                add_debug_line("kind = KeyUp, buttonIdx = {buttonIdx} ({int(buttonIdx)})")
            }
        }
    }
}

