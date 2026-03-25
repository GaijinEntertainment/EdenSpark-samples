require engine.core

var camera : NodeId

def init_world() {
    camera = create_node(NodeData(position = float3(0, 0, -100)))
    add_component(camera, new Camera(
        orthographic = true,
        orthographicSize = float(get_resolution().y),
        fovAxis = FovAxis.Vertical,
        fov = TO_RAD * 90f
    ))
    // Flat shading
    let flatShading = create_base_render_settings("flat shading")
    add_component(flatShading, new AmbientSettings(
        ambientStrength = 1f,
        ambientColor = float3(1f),
        ambientSource = AmbientSource.ConstColor
    ))
}

[export]
def on_resolution_changed(resolution : int2) {
    get_component(camera, type<Camera>).orthographicSize = float(resolution.y)
}

[export] def on_initialize() {
    init_world()
}

def getNodePos(idx : uint) {
    return float3(0., float(get_resolution().y) * 0.5 - 315f - float(idx) * 330., 0.)
}

class JoystickView : Component {
    idx : uint = 0u
    name : string = "n/a"
    vendor : string = "n/a"
    userId : int = -1
    lbl : NodeId
    buttonsLbl : NodeId

    lHolder : NodeId
    lStick : NodeId
    lStickLbl : NodeId

    rHolder : NodeId
    rStick : NodeId
    rStickLbl : NodeId

    lShiftHolder : NodeId
    lShift : NodeId
    lShiftLbl : NodeId

    rShiftHolder : NodeId
    rShift : NodeId
    rShiftLbl : NodeId

    keyMap <- [
        (GamepadButton.Up, "Up"),
        (GamepadButton.Down, "Down"),
        (GamepadButton.Left, "Left"),
        (GamepadButton.Right, "Right"),
        (GamepadButton.Start, "Start"), // hidden
        (GamepadButton.Back, "Back"),
        (GamepadButton.L3, "L3"),
        (GamepadButton.R3, "R3"),
        (GamepadButton.A, "A"),
        (GamepadButton.B, "B"),
        (GamepadButton.X, "X"),
        (GamepadButton.Y, "Y"),
        (GamepadButton.LeftBumper, "LB"),
        (GamepadButton.RightBumper, "RB"),
        (GamepadButton.LeftTrigger, "LT"),
        (GamepadButton.RightTrigger, "RT"),
    ]

    def override on_initialize() : void {
        updateLabel()
    }

    def override on_update() {
        let stickRadius = 65.0
        let shiftSize = float3(10, 65, 0)
        draw_sphere(lHolder.worldPosition, stickRadius * lHolder.worldScale.x)
        draw_sphere(rHolder.worldPosition, stickRadius * rHolder.worldScale.x)
        draw_box(lShiftHolder.worldTransform, float3(-10, -10, 0), shiftSize)
        draw_box(rShiftHolder.worldTransform, float3(-10, -10, 0), shiftSize)
    }

    def updateLabel() {
        (get_component(lbl, type<UIText>)).text = "#{int(idx)} <{name}> [{vendor}] uid: {userId}"
    }

    def updatePos() {
        nodeId.localPosition = getNodePos(idx)
    }

    def set(evt : RawGamepadInputEvent) {

        var btnText = ""
        for (key in keyMap) {
            btnText = "{btnText}{key._1}:{(evt.buttonDownState & key._0) != bitfield(0u) ? "@" : "-"} "
        }

        (get_component(buttonsLbl, type<UIText>)).text = btnText

        lStick.localPosition = float3(evt.xyz.xy, 0.) * 65.
        rStick.localPosition = float3(evt.rxyz.xy, 0.) * 65.

        (get_component(lStickLbl, type<UIText>)).text = "{evt.xyz.x:0.3f} {-evt.xyz.y:0.3f}"
        (get_component(rStickLbl, type<UIText>)).text = "{evt.rxyz.x:0.3f} {-evt.rxyz.y:0.3f}"

        let lShiftVal = evt.slider[0]
        let rShiftVal = evt.slider[1]
        lShift.localPosition = float3(0., lShiftVal, 0.) * 65.
        rShift.localPosition = float3(0., rShiftVal, 0.) * 65.

        (get_component(lShiftLbl, type<UIText>)).text = "{lShiftVal:0.3f}"
        (get_component(rShiftLbl, type<UIText>)).text = "{rShiftVal:0.3f}"
    }
}


def create_stick(node : NodeId, pos : float3, var holder : NodeId&, var stick : NodeId&, var lbl : NodeId&, lblVertPos : float) : void {
    holder = create_node(NodeData(parent = node, position = pos))
    let dot = create_node(NodeData(parent = holder, position = float3(0., 0., 0.1), scale = float3(22.)))
    add_component(dot, new Mesh(meshId = SPHERE_MESH_ID))

    stick = create_node(NodeData(parent = holder, scale = float3(22.)))
    add_component(stick, new Mesh(meshId = SPHERE_MESH_ID, color = color32_to_float4(0xff98c86e)))

    lbl = create_node(NodeData(parent = holder))
    add_component(lbl, new UIFrame(localPosition2D = float2(0, lblVertPos), pivot = float2(0.5, 1)))
    add_component(lbl, new UIText())
}


def create_view(idx : uint, name, vendor : string) {
    let pos = getNodePos(idx)
    let node = create_node(NodeData(position = pos))
    let lbl = create_node(NodeData(parent = node))
    add_component(lbl, new UIFrame(localPosition2D = float2(0, 0), pivot = float2(0.5, 1)))
    add_component(lbl, new UIText())

    let buttonsLbl = create_node(NodeData(parent = node))
    add_component(buttonsLbl, new UIFrame(localPosition2D = float2(0, 30), pivot = float2(0.5, 1)))
    add_component(buttonsLbl, new UIText(text = ""))

    var lHolder, lStick, lStickLbl : NodeId
    create_stick(node, float3(-200, 150, 0.), lHolder, lStick, lStickLbl, 90.)
    var rHolder, rStick, rStickLbl : NodeId
    create_stick(node, float3(0, 150, 0.), rHolder, rStick, rStickLbl, 90.)

    var lShiftHolder, lShift, lShiftLbl : NodeId
    create_stick(node, float3(170, 90, 0.), lShiftHolder, lShift, lShiftLbl, 30.)
    var rShiftHolder, rShift, rShiftLbl : NodeId
    create_stick(node, float3(250, 90, 0.), rShiftHolder, rShift, rShiftLbl, 30.)

    let panel = create_node(NodeData(parent = node, position = float3(0, 85, 0), scale = float3(950, 315, 1)))
    add_component(panel, new Mesh(meshId = QUAD_MESH_ID, color = color32_to_float4(0xff333333)))


    add_component(node, new JoystickView(idx = idx, name = name, vendor = vendor, lbl = lbl, buttonsLbl = buttonsLbl,
        lHolder = lHolder, lStick = lStick, lStickLbl = lStickLbl, rHolder = rHolder, rStick = rStick, rStickLbl = rStickLbl,
        lShiftHolder = lShiftHolder, lShift = lShift, lShiftLbl = lShiftLbl, rShiftHolder = rShiftHolder, rShift = rShift, rShiftLbl = rShiftLbl
     ))

    return node
}

var views : array<NodeId>
var no : NodeId

def remove_no() {
    if (!!no) {
        remove_node(no)
        no = NodeId(0ul)
    }
}

def add_no() {
    if (!no) {
        no = create_node()
        add_component(no, new UIText(text = "Connect gamepad"))
    }
}

[export]
def on_update() {

    let gamepadsCount = get_gamepads_count()
    if (length(views) != gamepadsCount) {
        get_gamepads_info() $(idx, deviceName, deviceVendor, userId) {
            if (idx < length(views)) {
                get_component(views[idx], $(var view : JoystickView?) {
                    view.name = string(deviceName)
                    view.vendor = string(deviceVendor)
                    view.userId = userId
                    view->updateLabel()
                })
            } else {
                push(views, create_view(uint(idx), string(deviceName), string(deviceVendor)))
            }
        }

        for (i in range(gamepadsCount, length(views))) {
            remove_node(views[i])
        }

        resize(views, gamepadsCount)
    }

    for (cmd in get_input_command_buffer()) {
        match (cmd) {
            if (match_type(type<RawGamepadInputEvent>, $v(event))) {
                debug(event)
                let found = get_component(views[event.gamepadIndex], $(var view : JoystickView?) {
                    view->set(event)
                })
            }
        }
    }

    if (length(views) == 0) {
        add_no()
    } else {
        remove_no()
    }
}

