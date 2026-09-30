// Tilemap sample: load and render maps made in the Tiled editor (https://www.mapeditor.org/).
// Parsing lives in tiled_map.das, spawning in tiled_scene.das. The desert and sticker-knight
// maps are loaded in BOTH source formats (JSON .tmj and XML .tmx) to show load_tiled_map
// reads either transparently. Controls: WASD/arrows/left stick scroll, wheel/right stick zoom,
// Space/gamepad A switch map.
//
// How to export a map from Tiled so this sample can load it:
//   1. Any "Tile Layer Format" works: CSV or Base64 (uncompressed, gzip, zlib or Zstandard)
//      all load - the loader base64-decodes and decompresses the payload.
//   2. Export the map + external tilesets into one folder together with the tileset images.
//      Native XML (.tmx/.tsx, via Save or Export) or JSON (.tmj/.tsj, via Export As) both work
//      - load_tiled_map sniffs the content, not the extension.
//   3. Rename the files so the engine imports them as text assets (it keys off the extension
//      .txt/.json/.xml), content unchanged: XML -> "<name>.tmx.xml" / "<name>.tsx.xml";
//      JSON -> "<name>.tmj.json" / "<name>.tsj.json". Tileset refs inside (e.g. "desert.tsx")
//      are resolved by the loader.
//   4. Object templates (.tx) are resolved automatically for XML maps (they are XML too, kept
//      next to the map). For a JSON export they are NOT - optionally enable Edit -> Preferences
//      -> Export Options "Detach templates" + "Resolve object types and properties" so Tiled
//      inlines them into the .tmj.
//   5. Optional: slice atlas textures with the Sprite Editor (default "<texture>_<index>" names
//      match Tiled tile ids); import atlases pixel-art style (Point filter, no mips).

require engine.core
require tiled_map
require tiled_scene

struct MapSlot {
    path : string
    format : string         //! "XML" or "JSON" - which source the map was loaded from
    data : TiledMapData
    scene : TiledScene
}

def map_format(path : string) : string {
    //! Label only (load_tiled_map sniffs the content itself); read off the on-disk extension.
    return find(path, ".tmx.") >= 0 || find(path, ".tsx.") >= 0 ? "XML" : "JSON"
}

var g_maps : array<MapSlot>
var g_current = 0
var g_cam : NodeId
var g_camPos : float3
var g_orthoSize = 20f // visible height in world units
var g_label : NodeId  // on-screen current-map name/format/size

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
    let lbl = "[{g_maps[idx].format}] {g_maps[idx].path}  ({int(ws.x)}x{int(ws.y)} tiles)"
    update_debug_text(g_label, lbl)
    print("tilemap sample: showing {lbl}")
}

[export]
def on_initialize() {
    show_mouse_cursor(true)
    // desert + sticker-knight in both formats (JSON and XML load identically). The XML files are
    // the unmodified Tiled originals - desert and orthogonal-outside use base64 + zlib tile layers
    // (decoded on load) and embedded tilesets; sticker-knight uses CSV plus .tx object templates.
    // Failed loads are skipped.
    for (path in fixed_array(
        "maps/desert/desert.tmj.json",
        "maps/desert/desert.tmx.xml",
        "maps/sticker_knight/sandbox.tmj.json",
        "maps/sticker_knight/sandbox.tmx.xml",
        "maps/hex/hex_mini.tmj.json",
        "maps/isometric/isometric_grass_and_water.tmj.json",
        "maps/ortho_outside/orthogonal-outside.tmx.xml",
        "maps/perspective/perspective_walls.tmx.xml"
    )) {
        var slot = MapSlot(path = path, format = map_format(path))
        if (load_tiled_map(path, slot.data)) {
            slot.scene <- spawn_tiled_map(slot.data, path)
            slot.scene.root.isActive = false
            print("tilemap sample: loaded [{slot.format}] \"{path}\" ({slot.data.map.width}x{slot.data.map.height} tiles, {length(slot.data.tilesets)} tileset(s))")
            g_maps |> emplace(slot)
        }
    }

    g_cam = create_node(NodeData(name = "camera"))
    add_component(g_cam, new Camera(
        orthographic = true,
        orthographicSize = g_orthoSize,
        fovAxis = FovAxis.Vertical,
    ))
    g_label = create_debug_text("", float2(10, 34)) // current-map label, filled by activate_map
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
        // step to the PREVIOUS map - handy for A/B comparing the same scene loaded from JSON vs XML
        "switch_map_back" => Action(buttonActions = ButtonAction(
            keyboardButtons = [KeyboardButtonInput(idx = KeyCode.Space, modifier = KeyboardShifts.Shift)],
            gamepadButtons = [GamepadButtonInput(idx = GamepadButton.B)]
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
    create_debug_text("WASD/arrows/left stick - scroll, wheel/right stick - zoom, Space/A - next map, Shift+Space/B - prev map", float2(10))
}

[export]
def on_update() {
    if (length(g_maps) == 0) {
        return
    }

    let n = length(g_maps)
    // check "back" first: Shift+Space may also trigger the plain "switch_map" (Space), so a
    // back press wins and forward is skipped that frame
    if (is_action_just_pressed("switch_map_back")) {
        activate_map((g_current - 1 + n) % n)
    } elif (is_action_just_pressed("switch_map")) {
        activate_map((g_current + 1) % n)
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
