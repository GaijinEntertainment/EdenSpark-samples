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


def load_pixel_image(path : string, transparent_color_from_left_top_pixel : bool = false, cb : block<(var bmp : Bitmap) : void>) {
    get_image_content(path) $(var bitmap : Bitmap) {
        if (transparent_color_from_left_top_pixel) {
            let transparentColor = bitmap.pixels[0]
            for (p in bitmap.pixels) {
                p = (p == transparentColor) ? 0u : p | 0xFF000000
            }
        }
        cb(bitmap)
    }
}


var canvas : PixelCanvas
var pine : Bitmap
var timeAccumDouble : double
var timeAccum : float

[export]
def on_initialize() {
    canvas <- initialize_pixel_renderer(pixel_resolution)
    load_pixel_image("assets/pine.png", true) $(var loaded_image) {
        pine <- loaded_image
    }
}


def draw_background(var bitmap : Bitmap) {
    var color = 0xFF000000
    var y = 0
    for (i in 1 .. 20) {
        fill_rect(bitmap, int2(0, y), int2(pixel_resolution.x, y + i), color)
        y += i
        fill_rect(bitmap, int2(0, y), int2(pixel_resolution.x, y + i), color | 0x2000)
        y += i
        color += 0x00040008
    }
}


def draw_circles(var bitmap : Bitmap) {
    for (i in range(0, 15)) {
        let fillColor = 0xFF80A0E0
        let strokeColor = 0xFFFFFFFF
        let radius = i
        let center = int2(10 + i * 30, 205)
        fill_circle(bitmap, center, radius, fillColor)
        circle(bitmap, center, radius, strokeColor)
    }
}


def draw_lines(var bitmap : Bitmap) {
    var t = get_time() * 0.1
    for (i in range(0, 1)) {
        let color = 0xFFFFFFFF
        let start = float2(200, 100)
        let tmp = float2(cos(t + float(i) * 0.2) * 60.0, sin(t + float(i) * 0.2) * 60.0)
        let end = start + tmp
        line(bitmap, start, end, color)
    }
}


def draw_sprite(var bitmap : Bitmap) {
    copy_image_rect(bitmap, pine, int2(30, 30), int2(0, 0), int2(pine.w, pine.h), true)
}


[export]
def on_update() {
    draw_background(canvas.bitmap)
    draw_circles(canvas.bitmap)

//    draw_text(canvas.bitmap, int2(10, 10), "Hello, World!", 0xFFFFFFFF)
//    var a : array<int>
//    resize(a, 10)
//    a[-1] = 123

    draw_lines(canvas.bitmap)
    //set_pixel(canvas.bitmap, 100, 100, 0xFF00FFFF) // red
    draw_sprite(canvas.bitmap)
    update_texture(canvas.bitmap, canvas.textureId)
}


