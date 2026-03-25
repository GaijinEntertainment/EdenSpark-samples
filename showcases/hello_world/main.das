require engine.core

[export]
def on_initialize() {
    let canvas = create_node(NodeData(name = "ui canvas"))
    add_component(canvas, new UICanvas(screenMode = ScreenMode.FitExtend, size = float2(1200, 800)))
    add_component(canvas, new UIVerticalLayout(
        alignment = LayoutAlignment.MiddleCenter,
        spacing = 10.0
    ))

    let imageNode = create_node(NodeData(name = "image", parent = canvas))
    add_component(imageNode, new UIImage(
        textureId = request_texture("%builtin_package/logo.png"),
        size = float2(250., 250.)
    ))

    let textNode = create_node(NodeData(name = "text", parent = canvas))
    add_component(textNode, new UIText(
        text = "Hello, World!",
        fontSize = 48.0,
        pivot = float2(0.5, 0)
    ))
    textNode?.UIFrame.size = textNode?.UIText.textSize

    // Need any camera for UI to be seen
    let camera = create_node(NodeData(name = "camera"))
    add_component(camera, new Camera(
        backgroundColor = color32_to_float4(0xff2a1f3d).xyz
    ))
}


[export]
def on_update() {
    let dt = get_delta_time()
}
