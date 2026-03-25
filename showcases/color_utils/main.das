require engine.core


let canvas = create_node(NodeData(name = "canvas"))


def text(x, y : int, s : string, color : float4 = float4(1)) {
    let node = create_node(NodeData(parent = canvas))
    add_component(node, new UIText(
        color = color,
        text = s,
        pivot = float2(),
        horAlignment = TextHorAlignment.Left,
        vertAlignment = TextVertAlignment.Top
    ))
    add_component(node, new UIAnchor(
        anchorMin = TOP_LEFT_ANCHOR,
        anchorMax = TOP_LEFT_ANCHOR,
        top = float(y) * 20.0,
        left = float(x) * 14.0
    ))
}


[export]
def on_initialize() {
    add_component(canvas, new UICanvas(screenMode = ScreenMode.Fullscreen))
    let camera = create_node(NodeData(position = float3(0, 0, -5)))
    add_component(camera, new Camera(orthographic = true, orthographicSize = 8f, fovAxis = FovAxis.Horizontal, fov = TO_RAD * 90f))
    let square_char = "\u2586"

    text(1, 1, "desaturate(color, amount)")
    for (i in 0 .. 11) {
        text(1 + i, 2, square_char, desaturate(float4(1.0, 0.2, 0.8, 1.0), float(i) / 10.0))
    }

    text(1, 4, "lerp_color32(color1, color2, t)")
    for (i in 0 .. 11) {
        text(1 + i, 5, square_char, color32_to_float4(lerp_color32(0xFFFF40F0, 0xFF40FF80, float(i) / 10.0)))
    }

    text(1, 7, "srgb_to_linear(color)")
    for (i in 0 .. 11) {
        var c = float4(float3(float(i) / 10.0), 1.0)
        text(1 + i, 8, square_char, c)
        text(1 + i, 9, square_char, srgb_to_linear(c))
    }

    text(1, 11, "linear_to_srgb(color)")
    for (i in 0 .. 11) {
        var c = float4(float3(float(i) / 10.0), 1.0)
        text(1 + i, 12, square_char, c)
        text(1 + i, 13, square_char, linear_to_srgb(c))
    }

    text(1, 15, "hsv_to_rgb(h, s, v), rgb_to_hsv(color)")
    for (x in 0 .. 11) {
        for (y in 0 .. 11) {
            var hsv = float3(float(x) / 11.0, 0.7, float(y + 1) / 11.0)
            var c = hsv_to_rgb(hsv)
            var restoredHsv = rgb_to_hsv(c)
            if (length(hsv - restoredHsv) > 0.01) {
                text(1 + x, 16 + y, square_char, float4(1.0)) // ERROR
            } else {
                text(1 + x, 16 + y, square_char, c)
            }
        }
    }

    text(1, 28, "get_random_color()")
    for (i in 0 .. 11) {
        text(1 + i, 29, square_char, get_random_color())
    }

    // color32
    text(40, 1, "add_color32(color1, color2)")
    for (i in 0 .. 11) {
        var color1 = get_random_color32()
        var color2 = get_random_color32()
        var result = add_color32(color1, color2)
        text(40 + i, 2, square_char, color32_to_float4(color1))
        text(40 + i, 3, square_char, color32_to_float4(color2))
        text(40 + i, 4, square_char, color32_to_float4(result))
    }

    text(40, 6, "sub_color32(color1, color2)")
    for (i in 0 .. 11) {
        var color1 = get_random_color32()
        var color2 = get_random_color32()
        var result = sub_color32(color1, color2)
        text(40 + i, 7, square_char, color32_to_float4(color1))
        text(40 + i, 8, square_char, color32_to_float4(color2))
        text(40 + i, 9, square_char, color32_to_float4(result))
    }

    text(40, 11, "mul_color32(color1, color2)")
    for (i in 0 .. 11) {
        var color1 = get_random_color32()
        //var color2 = //get_random_color32()
        var color2 = float4_to_color32(float4(0.0, float(i) / 11.0, 1.0 - float(i) / 11.0, 1.0))
        var result = mul_color32(color1, color2)
        text(40 + i, 12, square_char, color32_to_float4(color1))
        text(40 + i, 13, square_char, color32_to_float4(color2))
        text(40 + i, 14, square_char, color32_to_float4(result))
    }

    text(40, 16, "mul_color32(color1, k)")
    for (i in 0 .. 11) {
        var color1 = get_random_color32()
        var k = float(i) / 10.0
        var result = mul_color32(color1, k)
        text(40 + i, 17, square_char, color32_to_float4(color1))
        text(40 + i, 18, square_char, float4(k, k, k, 1.0f))
        text(40 + i, 19, square_char, color32_to_float4(result))
    }
}


[export]
def on_update() {
    pass
}
