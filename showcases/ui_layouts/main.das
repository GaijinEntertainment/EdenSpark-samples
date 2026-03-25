require engine.core


def create_frame(parent : NodeId) : NodeId {
    let node = create_node(NodeData(parent = parent))

    add_component(node, new UIFrame(size = float2(100, 100)))
    add_component(node, new UIImage(color = float4(1)))

    return node
}


def create_hor_layout(pos : float2, parent : NodeId) : NodeId {
    let layout = create_node(NodeData(name = "horizontal", parent = parent))
    add_component(layout, new UIImage(color = float4(1.0, 1.0, 1.0, 0.5), localPosition2D = pos, size = float2(500, 200)))
    add_component(layout, new UIHorizontalLayout(
        spacing = 10.0,
        alignment = LayoutAlignment.BottomLeft
    ))

    var nodes : NodeId[4]

    for (i in 0..3) {
        nodes[i] = create_frame(layout)
    }

    get_component(nodes[1]) $(var frame : UIFrame?) {
        frame.size += float2(30, 50)
        frame.pivot = float2(1, 0)
    }

    return layout
}


def create_vert_layout(pos : float2, parent : NodeId) : NodeId {
    let layout = create_node(NodeData(name = "vertical", parent = parent))
    add_component(layout, new UIImage(color = float4(1.0, 1.0, 1.0, 0.5), localPosition2D = pos, size = float2(200, 500)))
    add_component(layout, new UIVerticalLayout(
        spacing = 10.0,
        alignment = LayoutAlignment.BottomRight
    ))

    var nodes : NodeId[5]

    for (i in 0..3) {
        nodes[i] = create_frame(layout)
    }

    get_component(nodes[1]) $(var frame : UIFrame?) {
        frame.size += float2(30, 50)
        frame.pivot = float2(1, 0)
    }

    return layout
}


def create_flow_layout(pos : float2, parent : NodeId) : NodeId {
    let layout = create_node(NodeData(name = "flow", parent = parent))
    add_component(layout, new UIImage(color = float4(1.0, 1.0, 1.0, 0.5), localPosition2D = pos, size = float2(500, 500)))
    add_component(layout, new UIFlowLayout(
        spacing = float2(10.0)
    ))

    var nodes : NodeId[10]

    for (i in 0..9) {
        nodes[i] = create_frame(layout)
    }

    get_component(nodes[1]) $(var frame : UIFrame?) {
        frame.size += float2(30, 50)
        frame.pivot = float2(1, 0)
    }

    return layout
}


[export]
def on_initialize() {
    let canvas = create_node(NodeData(name = "ui canvas"))
    add_component(canvas, new UICanvas(screenMode = ScreenMode.Custom))
    get_component(canvas) $(var frame : UIFrame?) {
        frame.size = float2(1)
    }

    create_hor_layout(float2(-400, 0), canvas)
    create_vert_layout(float2(0, 0), canvas)
    create_flow_layout(float2(400, 0), canvas)

    let camera = create_node(NodeData(name = "camera"))
    add_component(camera, new Camera(
        backgroundColor = color32_to_float4(0xff1e1e1e).xyz
    ))
}
