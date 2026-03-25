module pixelRenderer

require engine.core
require engine.render.pixel_render public

/*
Usage:
    draw_text(pixel_buffer, int2(15, 34), "Hello World!", 0xFFFF0000)
*/

let pixel_resolution : int2 = int2(480, 280)

struct BitMapWithTexture {
    bitmap : Bitmap
    textureId : TextureId
}


def initialize_pixel_renderer(pixel_resolution_ : int2) : BitMapWithTexture {
    print("initialize_pixel_renderer with resolution {pixel_resolution_}\n")
    var canvas : BitMapWithTexture

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


def finalize_pixel_renderer(var canvas : BitMapWithTexture) {
    print("finalize_pixel_renderer\n")
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
