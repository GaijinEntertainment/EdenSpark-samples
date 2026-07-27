require engine.core
require engine.free_camera
require engine.input_core

[export]
def on_initialize() {
    show_mouse_cursor(true)
    create_render_settings()

    let sun = create_node(NodeData(name = "sun", rotation = quat4(deg_to_rad(45.0), deg_to_rad(30.0), 0.0)))
    add_component(sun, new DirectionalLight(color = float3(1, 0.95, 0.85), intensity = 3.0))

    create_free_camera(float3(0, 0, -15))

    var shaders = [
        "sepia",
        "vignette_2d",
        "pixelate",
        "scanlines",
        "chromatic_aberration",
        "blur",
        "grayscale",
        "invert",
        "dissolve_2d",
        "gameboy",
        "wave",
        "magma_2d",
        "halftone",
        "posterize",
        "noise_grain",
        "wipe_horizontal",
        "wipe_vertical",
        "dissolve_wipe_h",
        "dissolve_wipe_v",
        "teleport",
        "water_2d",
        "hologram_2d",
        "shiny",
        "outline_2d",
        "fractal_noise",
        "plasma",
        "swirl",
        "ripple",
        "burn",
        "freeze",
        "poison",
        "shield_hit",
        "glow",
        "shadow_2d",
        "glitch_2d",
        "mandelbrot",
        // "voronoi",
        "julia",
        "kaleidoscope",
        "dithering",
        "crt",
        "flash",
        "gradient_map",
        "dissolve_edge",
        "bloom",
        "bulge",
        "emboss",
        "sharpen_2d",
        "smooth_2d",
    ]

    let count = length(shaders)
    let perRow = ceili(sqrt(float(count) * 4.0 / 3.0))
    let rows = (count + perRow - 1) / perRow
    let spacing = 2.5

    for (i, name in range(count), shaders) {
        let col = i % perRow
        let row = i / perRow
        let x = (float(col) - float(perRow - 1) * 0.5) * spacing
        let y = (float(rows - 1) * 0.5 - float(row)) * spacing
        let plane = create_node(NodeData(
            name = name,
            position = float3(x, y, 0),
            scale = float3(2, 2, 1)
        ))
        let mat = request_material("materials/{name}.material")
        add_component(plane, new Mesh(meshId = QUAD_MESH_ID, materialId = mat))
        let txt = create_node(NodeData(parent = plane, position = float3(0, -0.65, 0), scale = float3(0.075, 0.075, 0.075)))
        add_component(txt, new Text3D(text = name, fontSize = 16.0, useDepthScale = false))
    }
}
