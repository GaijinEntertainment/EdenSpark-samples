require engine.core
require engine.render.pixel_render


let pixel_resolution : int2 = int2(480, 280)

struct PixelCanvas {
    bitmap : Bitmap
    textureId : TextureId
}


def initialize_pixel_renderer(pixel_resolution_ : int2) : PixelCanvas {
    print("initialize_pixel_renderer with resolution {pixel_resolution_}")
    var canvas : PixelCanvas

    canvas.textureId = create_texture(pixel_resolution.x, pixel_resolution.y, array<uint>(), TextureDeclaration(
        filter = TextureFilter.Bilinear,
        generateMipLevels = false,
        addressing = TextureAddress.Clamp
    ))

    let screenAspectRatio = float(get_resolution().x) / float(get_resolution().y)
    let bufferAspectRatio = float(pixel_resolution.x) / float(pixel_resolution.y)
    let scale : float2 = float2(bufferAspectRatio, 1.0) * min((screenAspectRatio / bufferAspectRatio), 1.0)

    let node = create_node(NodeData(scale = float3(scale, 1.0)))
    add_component(node, new Mesh(meshId = QUAD_MESH_ID,
        materialId = create_material(MaterialImport(
            shaderName = "pixel_art",
            diffuse = canvas.textureId
        ))
    ))
    let camera = create_node(NodeData(position = float3(0, 0, -1)))
    add_component(camera, new Camera(orthographic = true, orthographicSize = 1.0, fovAxis = FovAxis.Vertical, fov = TO_RAD * 90f))

    canvas.bitmap <- Bitmap(pixel_resolution.x, pixel_resolution.y)
    return <- canvas
}


def finalize_pixel_renderer(var canvas : PixelCanvas) {
    print("finalize_pixel_renderer")
    clear(canvas.bitmap.pixels)
}


var canvas : PixelCanvas

[export]
def on_initialize() {
    canvas <- initialize_pixel_renderer(pixel_resolution)
}



[export]
def on_update() {
    fill_rect(canvas.bitmap, int2(0, 0), pixel_resolution, 0xFF101010)

    var anim_time = int(get_time() * 60.0)

    var pos : int2 = int2(10, 10)
    draw_text(canvas.bitmap, pos, "perlin_noise(pos)", 0xFFFFFFFF)
    pos.y += 20

    // 2d perlin noise
    for (y in range(80)) {
        for (x in range(80)) {
            var value = perlin_noise(float2(x, y + anim_time) * 0.05)
            var color = float4_to_color32(float4(value, value, value, 1.0))
            set_pixel(canvas.bitmap, int2(x, y) + pos, color)
        }
    }

    // 1d perlin noise
    var prev : float2
    for (x in range(81)) {
        var value = perlin_noise(float(x + anim_time) * 0.05)
        var p = float2(float(x) * 3.0, value * 80.0) + float2(pos) + float2(100, 0)
        if (x > 0) {
            antialiased_line(canvas.bitmap, prev, p, 0xFFFFFFFF, 3.0)
        }
        prev = p
    }

    // 2d fractal noise
    pos.y += 100
    draw_text(canvas.bitmap, pos, "fractal_noise(pos, scale, roughness, octaves)", 0xFFFFFFFF)
    pos.y += 20
    for (y in range(80)) {
        for (x in range(80)) {
            var value = fractal_noise(float2(x, y + anim_time), 0.05, 0.6, 4.0)
            var color = float4_to_color32(float4(value, value, value, 1.0))
            set_pixel(canvas.bitmap, int2(x, y) + pos, color)
        }
    }

    // 1d fractal noise
    for (x in range(81)) {
        var value = fractal_noise(float(x + anim_time), 0.05, 0.6, 4.0)
        var p = float2(float(x) * 3.0, value * 80.0) + float2(pos) + float2(100, 0)
        if (x > 0) {
            antialiased_line(canvas.bitmap, prev, p, 0xFFFFFFFF, 3.0)
        }
        prev = p
    }

    update_texture(canvas.bitmap, canvas.textureId)
}

