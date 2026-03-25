require engine.core

def private custom_mouse_over_event_handler(evt : UIMouseEvent) {
    if (evt.phase == UIInputEventPhase.Target) {
        get_component(evt.currentTarget) $(var btn : ButtonHoverEffectBehavior?) {
            btn.hoverEffectNode.isActive = true
        }
    }
}


def private custom_mouse_out_event_handler(evt : UIMouseEvent) {
    if (evt.phase == UIInputEventPhase.Target) {
        get_component(evt.currentTarget) $(var btn : ButtonHoverEffectBehavior?) {
            btn.hoverEffectNode.isActive = false
        }
    }
}

class ButtonHoverEffectBehavior : Component {
    hoverEffectNode : NodeId

    def override on_initialize() : void {
        add_ui_event_listener(nodeId, UIMouseEventType.MouseOver, @@custom_mouse_over_event_handler)
        add_ui_event_listener(nodeId, UIMouseEventType.MouseOut, @@custom_mouse_out_event_handler)
    }

    def override on_destroy() : void {
        remove_ui_event_listener(nodeId, UIMouseEventType.MouseOver, @@custom_mouse_over_event_handler)
        remove_ui_event_listener(nodeId, UIMouseEventType.MouseOut, @@custom_mouse_out_event_handler)
    }
}
