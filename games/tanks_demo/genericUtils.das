require engine.core
require engine.scene_core


var statusNode : NodeId

[export]
def set_debug_status_string(str : string) {
    update_debug_text(statusNode, str)
}

[export]
def create_status_string(position : float2, text : string = "") {
    statusNode = create_debug_text(text, position, BOTTOM_LEFT_ANCHOR)
    set_text_color(statusNode, float4(1, 1, 0, 1))
    set_text_font_size(statusNode, 24.0)
}
