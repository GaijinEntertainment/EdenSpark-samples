require engine.core

def get_or_create_canvas_node() : NodeId {
    let canvasNode = find_component(type<UICanvas>)
    var chosenCanvasNode : NodeId
    if (canvasNode != null) {
        chosenCanvasNode = canvasNode.nodeId
    } else {
        chosenCanvasNode = create_node(NodeData(name = "ui_canvas"))
        add_component(chosenCanvasNode, new UIFrame(size = float2(1600, 900)))
        add_component(chosenCanvasNode, new UICanvas(screenMode = ScreenMode.FitExtend))
    }
    return chosenCanvasNode
}

class AutoAttachToCanvas : Component {
    def override on_initialize() {
        nodeId.set_parent(get_or_create_canvas_node(), AddChildStrategy.KeepLocalTransform)
    }
}

class AutoTakeOverCanvas : Component {
    def override on_initialize() {
        let canvasNode = get_or_create_canvas_node()
        for (child in get_children(canvasNode)) {
            remove_node(child)
        }
        nodeId.set_parent(canvasNode, AddChildStrategy.KeepLocalTransform)
    }
}
