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


[export]
def on_initialize() {
    show_mouse_cursor(true)
    init_debug_text(float2(0, 0))
    add_debug_line("Move the mouse to get input events")
    // create cametera to workaround bug with clearing
    add_component(create_node(), new Camera())
}


[export]
def on_update() {
    let dt = get_delta_time()

    for (cmd in get_input_command_buffer()) {
        if (cmd is RawMouseInputEvent) {
            let mouse = cmd as RawMouseInputEvent
            if (mouse.kind == RawMouseInputEventKind.MouseDown) {
                add_debug_line("kind = MouseDown,  buttonIdx = {mouse.buttonIdx}, absolutePosition = {mouse.absolutePosition}")
            }
            if (mouse.kind == RawMouseInputEventKind.MouseUp) {
                add_debug_line("kind = MouseUp,    buttonIdx = {mouse.buttonIdx}, absolutePosition = {mouse.absolutePosition}")
            }
            if (mouse.kind == RawMouseInputEventKind.MouseMove) {
                add_debug_line("kind = MouseMove,  absolutePosition = {mouse.absolutePosition}, deltaPosition = {mouse.deltaPosition}")
            }
            if (mouse.kind == RawMouseInputEventKind.MouseWheel) {
                add_debug_line("kind = MouseWheel, wheel = {mouse.wheel}")
            }
        }
    }
}
