require engine.core
require game

class UpdateHpBarBehavior : Component {
    def override on_update() {// will be called each frame
        let hp = get_current_hp()
        let hpElems = get_children(nodeId)
        for (hpElemNode, i in hpElems, range(length(hpElems))) {
            if (float(i) >= hp) {
                hpElemNode.isActive = false
            } else {
                let sizeRel = min(hp - float(i), 1.0)
                get_component(hpElemNode) $(var frame : UIFrame?) {
                    frame.size = float2(frame.size.y * sizeRel, frame.size.y)
                }
                hpElemNode.isActive = true
            }
        }
    }
}
