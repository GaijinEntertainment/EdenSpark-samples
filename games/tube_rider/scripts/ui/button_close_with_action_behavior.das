require engine.core

class ButtonCloseWithActionBehavior : Component {
    windowToCloseNode : NodeId
    action : lambda<() : void>

    def override on_initialize() : void {
        get_component(nodeId) $(var btn : UIButton?) {
            btn.onClick = @() {
                action()
                remove_node(windowToCloseNode)
            }
        }
    }
}
