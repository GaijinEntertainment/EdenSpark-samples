require engine.core


def create_text(canvas : NodeId, position : float3, box : float2, pivot : float2, halign : TextHorAlignment, valign : TextVertAlignment, fontAutoSize : bool = false, fontSize : float = 16.0) : NodeId {
    let node = create_node(NodeData(parent = canvas, position = position))

    add_component(node, new UIImage(
        color = float4(0.5, 0.5, 0.0, 1.0),
        size = box,
        pivot = pivot
    ))
    add_component(node, new UIText(
        text = "This is a text vertical alignment property showcase\n\n\npivot = {pivot}\nwordWrapping = true\nsize = {box}\nhorAlignment = {halign}\nvertAlignment = {valign}",
        fontSize = fontSize,
        wordWrapping = true,
        pivot = pivot,
        horAlignment = halign,
        vertAlignment = valign
    ))
    node?.UIFrame.localPosition2D = float2(position.x, position.y)

    if (fontAutoSize) {
        node?.UIText.fontAutoSize = float2(7.0, 500.0)
        node?.UIText.text = "{node?.UIText.text}\nfontAutoSize = 7.0, 500.0"
    }

    return node
}


def create_text_not_wrapped(canvas : NodeId, position : float3, box : float2, pivot : float2, halign : TextHorAlignment, valign : TextVertAlignment, fontAutoSize : bool = false, fontSize : float = 16.0) : NodeId {
    let node = create_text(canvas, position, box, pivot, halign, valign, fontAutoSize, fontSize)

    node?.UIText.wordWrapping = false
    node?.UIText.text = "This text is not wrapped (but still have \\n's)\n\n\npivot = {pivot}\nwordWrapping = false\nhorAlignment = {halign}\nvertAlignment = {valign}"

    return node
}


def create_text_not_wrapped_no_max_size(canvas : NodeId, position : float3, box : float2, pivot : float2, halign : TextHorAlignment, valign : TextVertAlignment, fontAutoSize : bool = false, fontSize : float = 16.0) : NodeId {
    let node = create_text(canvas, position, box, pivot, halign, valign, fontAutoSize, fontSize)

    node?.UIText.wordWrapping = false
    node?.UIText.text = "This text is not wrapped (but still have \\n's)\nsize is set to -1, -1\n\n\npivot = {pivot}\nwordWrapping = false\nhorAlignment = {halign}\nvertAlignment = {valign}"

    node?.UIFrame.size = float2(-1)
    remove_component(node, type<UIImage>)

    return node
}


def create_text_custom_pivot(canvas : NodeId, position : float3, box : float2, pivot : float2, halign : TextHorAlignment, valign : TextVertAlignment, fontAutoSize : bool = false, fontSize : float = 16.0) : NodeId {
    let node = create_text(canvas, position, box, pivot, halign, valign, fontAutoSize, fontSize)

    node?.UIText.text = "This text have custom pivot (and aligns properly!)\n\n\npivot = {pivot}\nwordWrapping = true\nsize = {box}\nhorAlignment = {halign}\nvertAlignment = {valign}"

    return node
}


def draw_hor_guide(canvas : NodeId, yPos : float, color : float4 = color32_to_float4(0xffff00ff)) : void {
    let node = create_node(NodeData(parent = canvas))
    add_component(node, new UIImage(
        color = color,
        size = float2(get_resolution().x * 10, 1)
    ))
    node?.UIFrame.localPosition2D = float2(0, yPos)
}


def draw_vert_guide(canvas : NodeId, xPos : float, color : float4 = color32_to_float4(0xffff00ff)) : void {
    let node = create_node(NodeData(parent = canvas))
    add_component(node, new UIImage(
        color = color,
        size = float2(1, get_resolution().y * 10)
    ))
    node?.UIFrame.localPosition2D = float2(xPos, 0)
}


def create_guides(canvas : NodeId) : void {
    draw_hor_guide(canvas, 0.0, float4(0f, 1f, 0f, 1f))
    draw_vert_guide(canvas, 0.0, float4(0f, 1f, 0f, 1f))

    for (i in 1..20) {
        draw_hor_guide(canvas, float(i * 50))
        draw_hor_guide(canvas, -float(i * 50))

        draw_vert_guide(canvas, float(i * 50))
        draw_vert_guide(canvas, -float(i * 50))
    }
}

var node : NodeId

[export]
def on_initialize() {
    let canvas = create_node(NodeData(name = "ui canvas"))
    add_component(canvas, new UICanvas())

    // vertical alignment + multi line
    node = create_text(canvas, float3(-500, 275, 0), float2(300, 250), float2(0.5, 0.5), TextHorAlignment.Left, TextVertAlignment.Top, true)
    create_text(canvas, float3(-500, 0, 0), float2(300, 100), float2(0.5, 0.5), TextHorAlignment.Center, TextVertAlignment.Middle)
    create_text(canvas, float3(-500, -275, 0), float2(300, 250), float2(0.5, 0.5), TextHorAlignment.Right, TextVertAlignment.Bottom)

    // vertical alignment + multi line + pivot
    create_text_custom_pivot(canvas, float3(0, 200, 0), float2(300, 250), float2(0.5, 0.0), TextHorAlignment.Left, TextVertAlignment.Top)
    create_text_custom_pivot(canvas, float3(0, -200, 0), float2(300, 250), float2(0.5, 1.0), TextHorAlignment.Left, TextVertAlignment.Top)

    // single character vertical alignment, should produce the same resultsw regarding of TextVertAlignment value
    create_text(canvas, float3(-50, 0, 0), float2(200, 200), float2(0.5, 0.5), TextHorAlignment.Center, TextVertAlignment.Top, true)?.UIText.text = "7"
    create_text(canvas, float3(250, 0, 0), float2(200, 200), float2(0.5, 0.5), TextHorAlignment.Center, TextVertAlignment.Middle, true)?.UIText.text = "7"
    create_text(canvas, float3(550, 0, 0), float2(200, 200), float2(0.5, 0.5), TextHorAlignment.Center, TextVertAlignment.Bottom, true)?.UIText.text = "7"

    // multi line + wrapping disabed
    create_text_not_wrapped(canvas, float3(500, 275, 0), float2(300, 250), float2(0.5, 0.5), TextHorAlignment.Left, TextVertAlignment.Top)
    create_text_not_wrapped_no_max_size(canvas, float3(500, -275, 0), float2(300, 250), float2(0.5, 0.5), TextHorAlignment.Right, TextVertAlignment.Top)


    create_guides(canvas)

    let camera = create_node(NodeData(name = "camera"))
    add_component(camera, new Camera(
        backgroundColor = color32_to_float4(0xff2a1f3d).xyz
    ))
}


[export]
def on_update() {
    let dt = get_delta_time()
}
