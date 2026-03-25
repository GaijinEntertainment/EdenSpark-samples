require engine.core

class ButtonCloseBehavior : Component {
    windowToCloseNode : NodeId

    def override on_initialize() : void {
        get_component(nodeId) $(var btn : UIButton?) {
            btn.onClick = @() {
                remove_node(windowToCloseNode)
            }
        }
    }
}
