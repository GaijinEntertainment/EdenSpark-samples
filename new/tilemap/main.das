// Tilemap sample: loading and rendering maps made in the Tiled editor (https://www.mapeditor.org/).
//
// Four maps exported from Tiled as JSON are loaded and spawned, one per supported map
// orientation/tileset combination:
//   - desert: orthogonal, a classic tile-grid map on an atlas tileset (margin/spacing)
//   - sticker_knight: orthogonal, an object-based platformer map on an image-collection
//     tileset, with parallax cloud/background layers and flipped sprites
//   - hex_mini: hexagonal (staggeraxis "y", staggerindex "odd"), a tiny atlas-tileset map
//   - isometric_grass_and_water: isometric, an atlas-tileset map
//
// Controls: WASD / arrow keys or gamepad left stick / dpad - scroll the camera,
// mouse wheel or gamepad right stick - zoom, Space or gamepad A - switch maps.
//
// The reusable part lives in tiled_map.das (parsing) and tiled_scene.das (spawning).
//
// How to export a map from Tiled so this sample can load it:
//   1. Map -> Map Properties -> "Tile Layer Format" = "CSV". The engine can't decompress
//      base64/zlib tile data.
//   2. Edit -> Preferences -> General -> Export Options: enable "Detach templates" and
//      "Resolve object types and properties". Template objects (.tx files) are not
//      supported; with these options Tiled inlines them on export.
//   3. Export with File -> Export As (NOT Save - export options do not apply to Save):
//      the map as .tmj, external tilesets as .tsj, into one folder together with the
//      tileset images.
//   4. Rename the exported files to "<name>.tmj.json" / "<name>.tsj.json" - the engine
//      imports text assets only with a .txt/.json extension. Do not edit the content:
//      tileset references inside (e.g. "desert.tsx") are resolved by the loader.
//   5. Optional: slice atlas textures with the Sprite Editor (the default
//      "<texture>_<index>" names match Tiled's tile ids) - tiles then render via engine
//      Sprites. Import tile atlases pixel-art style (Point filter, no mips) to avoid
//      seams between tiles.

require engine.core
require tiled_map
require tiled_scene

struct MapSlot {
    path : string
    data : TiledMapData
    scene : TiledScene
}

var g_maps : array<MapSlot>
var g_current = 0
var g_cam : NodeId
var g_camPos : float3
var g_orthoSize = 20f // visible height in world units

def activate_map(idx : int) {
    for (i in range(0, length(g_maps))) {
        g_maps[i].scene.root.isActive = (i == idx)
    }
    g_current = idx
    let ws = g_maps[idx].scene.worldSize

    // start at the map center, fit the whole map height on screen
    g_camPos = float3(ws.x * 0.5f, ws.y * 0.5f, -10f)
    g_cam.localPosition = g_camPos
    g_orthoSize = ws.y * 1.5
    get_component(g_cam) $(var cam : Camera?) {
        cam.orthographicSize = g_orthoSize
        let bg = g_maps[idx].data.map.backgroundcolor
        let c = empty(bg) ? float4(0.83f, 0.72f, 0.51f, 1f) : parse_tiled_color(bg)
        cam.backgroundColor = float3(c.x, c.y, c.z)
    }
    print("tilemap sample: showing \"{g_maps[idx].path}\" ({int(ws.x)}x{int(ws.y)} tiles)")
}

[export]
def on_initialize() {
    show_mouse_cursor(true)
    // maps that fail to load (load_tiled_map reports the error) are just left out
    for (path in fixed_array(
        "maps/desert/desert.tmj.json",
        "maps/sticker_knight/sandbox.tmj.json",
        "maps/hex/hex_mini.tmj.json",
        "maps/isometric/isometric_grass_and_water.tmj.json"
    )) {
        var slot = MapSlot(path = path)
        if (load_tiled_map(path, slot.data)) {
            slot.scene <- spawn_tiled_map(slot.data, path)
            slot.scene.root.isActive = false
            g_maps |> emplace(slot)
        }
    }

    g_cam = create_node(NodeData(name = "camera"))
    add_component(g_cam, new Camera(
        orthographic = true,
        orthographicSize = g_orthoSize,
        fovAxis = FovAxis.Vertical,
    ))
    if (length(g_maps) > 0) {
        activate_map(0)
    }

    add_and_activate_action_set("tilemap_demo", {
        "scroll" => Action(joystickActions = JoystickAction(
            keyboardDPads = [
                KeyboardDPadInput(leftIdx = KeyCode.A, rightIdx = KeyCode.D, upIdx = KeyCode.W, downIdx = KeyCode.S),
                KeyboardDPadInput(leftIdx = KeyCode.Left, rightIdx = KeyCode.Right, upIdx = KeyCode.Up, downIdx = KeyCode.Down)
            ],
            sticks = [
                GamepadStickInput(xIdx = GamepadAxis.LThumbH, yIdx = GamepadAxis.LThumbV, deadZoneX = 0.15f, deadZoneY = 0.15f)
            ],
            gamepadDPads = [
                GamepadDPadInput(leftIdx = GamepadButton.Left, rightIdx = GamepadButton.Right, upIdx = GamepadButton.Up, downIdx = GamepadButton.Down)
            ]
        )),
        "switch_map" => Action(buttonActions = ButtonAction(
            keyboardButtons = [KeyboardButtonInput(idx = KeyCode.Space)],
            gamepadButtons = [GamepadButtonInput(idx = GamepadButton.A)]
        )),
        "zoom" => Action(axisActions = AxisAction(mouseAxis = [
            MouseBtnAxisInput(positiveIdx = MouseButton.WheelUp, negativeIdx = MouseButton.WheelDown)
        ])),
        // separate action: the stick is a continuous value held over many frames, unlike
        // the wheel which ticks once - the two need different zoom speed handling
        "zoom_stick" => Action(axisActions = AxisAction(stickAxis = [
            GamepadAxisInput(idx = GamepadAxis.RThumbV, deadZone = 0.2f)
        ]))
    })
    create_debug_text("WASD/arrows/left stick - scroll, wheel/right stick - zoom, Space/gamepad A - switch map", float2(10))
}

[export]
def on_update() {
    if (length(g_maps) == 0) {
        return
    }

    if (is_action_just_pressed("switch_map")) {
        activate_map((g_current + 1) % length(g_maps))
    }

    let ws = g_maps[g_current].scene.worldSize

    let wheel = get_action_axis("zoom")            // +1/-1 on the frame the wheel moves
    let stickZoom = get_action_axis("zoom_stick")  // held continuous value, -1..1
    if (wheel != 0f || stickZoom != 0f) {
        // wheel: 10% per notch; stick: up to 2x per second while fully deflected
        let scale = pow(0.9f, wheel) * pow(0.5f, stickZoom * get_delta_time())
        g_orthoSize = clamp(g_orthoSize * scale, 4f, ws.y * 2f)
        get_component(g_cam) $(var cam : Camera?) {
            cam.orthographicSize = g_orthoSize
        }
    }

    // scroll speed scales with zoom: half a screen height per second
    let dir = get_action_vector2("scroll")
    let scrollSpeed = g_orthoSize * 0.5f
    g_camPos.x = clamp(g_camPos.x + dir.x * scrollSpeed * get_delta_time(), 0f, ws.x)
    g_camPos.y = clamp(g_camPos.y + dir.y * scrollSpeed * get_delta_time(), 0f, ws.y)
    g_cam.localPosition = g_camPos

    update_tiled_parallax(g_maps[g_current].scene, float2(g_camPos.x, g_camPos.y))
    draw_tiled_objects_debug(g_maps[g_current].data)
}
