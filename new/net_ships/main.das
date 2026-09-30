// Net Ships: a 2D arena where every player drives a ship and pushes the others around. One window
// hosts and runs dedicated.das in its process, the others join it from the lobby.

require engine.core
require engine.networking
require ships_common
require engine.ui.fast_ui


let {
    HISTORY_TICKS = 60
    VISUAL_ERROR_FADE = 0.15
    BLINK_TIME = 0.15
    STICK_DEADZONE = 0.15
    OWN_NOSE_COLOR = float4(1, 1, 1, 1)
    OTHER_NOSE_COLOR = float4(0.1, 0.1, 0.12, 1)
    GHOST_COLOR = float4(0.35, 0.4, 0.5, 0.5)
    SHOW_GHOST = true
    BUMP_COLOR = float4(1, 1, 1, 1)
    CAMERA_MARGIN = 2.0
    FRAME_COLOR = float4(0.6, 0.65, 0.8, 1)
    BG_SIZE = 50.0
}


var private {
    camera : NodeId
    sticks : Stick[2]
    menu : NodeId
    recordedStick : int = -1
    ownShip : NodeId
    predictedOf : table<uint64; NodeId>
}


class ShipView : Component {
    color : float4 = float4(1)
    own : bool = false
    ghost : bool = false
    private visual : NodeId
    private hull : NodeId
    private nose : NodeId
    private blink : float = 0.0
    private shownHull : float4

    def override on_initialize {
        visual = create_node(NodeData(name = "visual", parent = nodeId))
        hull = create_node(NodeData(name = "hull", parent = visual, scale = float3(1.2, 1.8, 0.4)))
        add_component(hull, new Mesh(meshId = CUBE_MESH_ID))
        nose = create_node(NodeData(name = "nose", parent = visual, position = float3(0, 0.9, 0), scale = float3(0.5, 0.6, 0.5)))
        add_component(nose, new Mesh(meshId = CUBE_MESH_ID, color = own ? OWN_NOSE_COLOR : OTHER_NOSE_COLOR))
    }

    def override on_update {
        get_component(nodeId) <| $(var body : PredictedBody?) {
            visual.localPosition = quat4(0.0, 0.0, -ship_angle(nodeId.localRotation)) * body.visualError
            visual.localRotation = quat4(0.0, 0.0, body.visualTurn)
        }
        blink = max(blink - get_delta_time(), 0.0)
        paint(hull, ghost ? GHOST_COLOR : (blink > 0.0 ? BUMP_COLOR : color), shownHull)
        if (ghost && nose.isActive) {
            nose.isActive = false
            hull.isActive = SHOW_GHOST
            hull.localPosition = float3(0, 0, 0.3)
            hull.localScale = float3(1.2, 1.8, 0.1)
        }
    }

    def bumped {
        blink = BLINK_TIME
    }

    def private paint(part : NodeId; wanted : float4; var shown : float4&) {
        return if (wanted == shown)
        shown = wanted
        get_component(part) <| $(var mesh : Mesh?) {
            mesh.color = wanted
        }
    }
}


struct Recorded {
    afterStick : int
    state : ShipState
}


struct Miss {
    pos : float3
    vel : float3
}

def private carried(miss : Miss; ticks : int; damping : float) : Miss {
    var at = miss
    for (_tick in range(ticks)) {
        at.vel *= 1.0 - damping / PHYSICS_FPS
        at.pos += at.vel / PHYSICS_FPS
    }
    return at
}


class PredictedBody : Component {
    mirror : NodeId
    visualError : float3
    visualTurn : float = 0.0
    private history : array<Recorded>
    private contactAt : int = -1

    def override on_initialize {
        on_collision(nodeId, @(collision) {
            get_component(nodeId) <| $(var body : PredictedBody?) {
                body.touched()
            }
            get_component(nodeId) <| $(var view : ShipView?) {
                view.bumped()
            }
        })
        on_collision_stay(nodeId, @(collision) {
            get_component(nodeId) <| $(var body : PredictedBody?) {
                body.touched()
            }
        })
    }

    def touched {
        contactAt = recordedStick
    }

    def record(afterStick : int) {
        get_component(nodeId) <| $(var body : RigidBody?) {
            history.push(Recorded(afterStick = afterStick, state = read_ship_state(nodeId, body)), 0)
        }
        while (!empty(history) && afterStick - back(history).afterStick > HISTORY_TICKS) {
            history.pop()
        }
    }

    def override on_update {
        if (!mirror.isAlive) {
            remove_node(nodeId)
            return
        }
        let fade = exp(-get_delta_time() / VISUAL_ERROR_FADE)
        visualError *= fade
        visualTurn *= fade
    }

    def onAuthority(appliedStickTick : int; state : ShipState) {
        let idx = find_index_if(history, $(r : Recorded) { return r.afterStick == appliedStickTick; })
        return if (idx < 0)
        let mine = history[idx].state
        if (states_agree(mine, state)) {
            forget(idx)
            return
        }
        let miss = Miss(pos = state.pos - mine.pos, vel = state.vel - mine.vel)
        let missAngle = angle_diff(mine.angle, state.angle)
        var damping = 0.0
        get_component(nodeId) <| $(var body : RigidBody?) {
            damping = body.linearDamping
        }
        let free = contactAt < appliedStickTick
        for (k in range(0, idx)) {
            let at = carried(miss, free ? history[k].afterStick - appliedStickTick : 0, damping)
            history[k].state.pos += at.pos
            history[k].state.vel += at.vel
            history[k].state.angle += missAngle
        }
        let now = carried(miss, free ? history[0].afterStick + 1 - appliedStickTick : 0, damping)
        get_component(nodeId) <| $(var body : RigidBody?) {
            nodeId.localPosition += now.pos
            nodeId.localRotation = quat4(0.0, 0.0, ship_angle(nodeId.localRotation) + missAngle)
            body.velocity += now.vel
        }
        forget(idx)
        visualError -= now.pos
        visualTurn -= missAngle
    }

    def private forget(idx : int) {
        while (length(history) > idx) {
            history.pop()
        }
    }
}


class RockView : Component {
    color : float4 = float4(1)
    private visual : NodeId

    def override on_initialize {
        visual = create_node(NodeData(name = "visual", parent = nodeId))
        add_component(visual, new Mesh(meshId = SPHERE_MESH_ID, color = color))
    }

    def override on_update {
        get_component(nodeId) <| $(var body : PredictedBody?) {
            visual.localPosition = quat4(0.0, 0.0, -ship_angle(nodeId.localRotation)) * body.visualError / nodeId.localScale.x
            visual.localRotation = quat4(0.0, 0.0, body.visualTurn)
        }
    }
}


def private spawn_predicted_rock(mirror : NodeId; state : ShipState; ticksAhead : int) {
    var color = float4(1)
    get_component(mirror) <| $(var rock : Asteroid?) {
        color = rock.color
    }
    let pos = state.pos + state.vel * (float(ticksAhead) / PHYSICS_FPS)
    let node = create_node(NodeData(name = mirror.name, position = pos, rotation = quat4(0.0, 0.0, state.angle), scale = mirror.localScale))
    add_asteroid_body(node)
    get_component(node) <| $(var body : RigidBody?) {
        body.velocity = state.vel
    }
    add_component(node, new RockView(color = color))
    add_component(node, new PredictedBody(mirror = mirror))
    predictedOf[uint64(mirror)] = node
}


[net_command_handler]
def on_bodies_authority(cmd : BodiesAuthorityToClient) {
    return if (recordedStick < 0)
    for (b in cmd.bodies) {
        let predicted = predictedOf?[uint64(b.node)] ?? NodeId()
        if (predicted.isAlive) {
            get_component(predicted) <| $(var body : PredictedBody?) {
                body.onAuthority(cmd.appliedStickTick, b.state)
            }
        } elif (b.node.isAlive && has_component(b.node, type<Asteroid>)) {
            spawn_predicted_rock(b.node, b.state, recordedStick + 1 - cmd.appliedStickTick)
        }
    }
}

[net_command_handler]
def on_ship_bumped(cmd : ShipBumpedToClient) {
    return if (!cmd.node.isAlive)
    get_component(cmd.node) <| $(var view : ShipView?) {
        view.bumped()
    }
    return if (!cmd.byShip)
    let predicted = predictedOf?[uint64(cmd.node)] ?? NodeId()
    return if (!predicted.isAlive)
    get_component(predicted) <| $(var view : ShipView?) {
        view.bumped()
    }
}


def private spawn_own_ship(mirror : NodeId; color : float4) {
    sticks[0] = Stick(tick = -1)
    sticks[1] = Stick(tick = -1)
    let node = create_node(NodeData(name = "own_ship", position = mirror.localPosition, rotation = mirror.localRotation))
    add_component(node, new ShipView(color = color, own = true))
    add_ship_body(node)
    add_component(node, new PredictedBody(mirror = mirror))
    ownShip = node
    predictedOf[uint64(mirror)] = node
    print("[net_ships] driving {mirror.name}")
}

def private dress_mirrors {
    for (ship in find_components(type<Ship>)) {
        if (!has_component(ship.nodeId, type<ShipView>)) {
            add_component(ship.nodeId, new ShipView(color = ship.color,
                own = is_node_owner(ship.nodeId) && !has_node_remote_authority(ship.nodeId)))
            if (has_node_remote_authority(ship.nodeId) && !is_node_owner(ship.nodeId)) {
                set_mirror_interpolation(ship.nodeId, true)
            }
        }
        get_component(ship.nodeId) <| $(var view : ShipView?) {
            if (has_node_remote_authority(ship.nodeId) && is_node_owner(ship.nodeId) && !view.ghost) {
                view.ghost = true
                spawn_own_ship(ship.nodeId, ship.color)
            }
        }
    }
}


[export]
def on_initialize {
    set_physics_fps(PHYSICS_FPS)
    init_input()
    show_mouse_cursor(true)
    set_lobby_callbacks(@@on_lobby_created, @@on_connection_established, @@on_connection_lost, @@on_lobby_left, @@on_lobby_destroyed)
    set_lobby_max_connections(8)
    build_stage()
    start_offline_arena()
    build_menu(MenuMode.Offline)
}


def private build_stage {
    camera = create_node(NodeData(name = "camera", position = float3(0, 0, -30)))
    add_component(camera, new Camera(orthographic = true, backgroundColor = float3(0.04, 0.05, 0.08)))
    fit_camera(get_resolution())
    let sun = create_node(NodeData(name = "sun", rotation = quat4(0.5, -0.4, 0.0)))
    add_component(sun, new DirectionalLight())
    create_render_settings()
    spawn_frame()
    let bg = create_node(NodeData(name = "background", rotation = quat4(-PI * 0.5, 0.0, 0.0), scale = float3(BG_SIZE, 1, BG_SIZE)))
    add_component(bg, new Mesh(meshId = PLANE_MESH_ID, materialId = request_material("bg.material")))
    create_debug_text("W/S thrust, A/D turn, or the left stick. Push the others around.", float2(20, -20), BOTTOM_LEFT_ANCHOR)
}


enum private MenuMode {
    Idle
    Offline
    Online
}

def private build_menu(mode : MenuMode) {
    if (menu.isAlive) {
        remove_node(menu)
    }
    var buttons : array<NodeId>
    if (mode == MenuMode.Online) {
        buttons |> push(button("Leave", @() { leave_lobby_room(); }))
    } else {
        if (mode == MenuMode.Idle) {
            buttons |> push(button("Single player", @() { start_offline_arena(); build_menu(MenuMode.Offline); }))
        }
        buttons |> push(button("Multiplayer", @() { open_lobby_menu(); }))
    }
    menu = canvas(float2(1920, 1080))
    children(menu, [add_anchor(set_frame_pos(set_spacing(vbox(buttons), 8), float2(16, 16)), TOP_LEFT_ANCHOR)])
}


def private start_offline_arena {
    spawn_arena()
    let ship = spawn_ship(0)
    set_node_owner(ship, LOCAL_PLAYER)
    on_collision(ship, @(collision) {
        get_component(ship) <| $(var view : ShipView?) {
            view.bumped()
        }
    })
}

def private reset_to_empty_stage {
    clear_scene()
    clear(predictedOf)
    recordedStick = -1
    build_stage()
}


def on_lobby_created(data : LobbyData) {
    print("[net_ships] lobby created hosting={data.shouldHost}")
    reset_to_empty_stage()
    build_menu(MenuMode.Online)
}
def on_connection_established(userName : string) {
    print("[net_ships] connected as {userName}")
    build_menu(MenuMode.Online)
}

def on_connection_lost(cause : DisconnectCause) {
    print("[net_ships] connection lost cause={cause}")
    back_to_menu()
}

def private back_to_menu {
    reset_to_empty_stage()
    build_menu(MenuMode.Idle)
}
def on_lobby_left(kicked : bool) {
    back_to_menu()
}
def on_lobby_destroyed() {
    back_to_menu()
}

[export]
def on_update {
    dress_mirrors()
}

[export]
def on_fixed_update {
    sticks[0] = sticks[1]
    sticks[1] = Stick(tick = get_fixed_tick(), thrust = get_action_axis("thrust"), turn = get_action_axis("turn"))
    if (has_network()) {
        return if (!ownShip.isAlive)
        broadcast_net_command(ShipInputToServer(sticks = sticks))
        recordedStick = sticks[1].tick - 1
        for (body in find_components(type<PredictedBody>)) {
            body.record(recordedStick)
        }
        get_component(ownShip) <| $(var body : RigidBody?) {
            drive_ship(body, ownShip, sticks[1])
        }
        return
    }
    for (ship in find_components(type<Ship>)) {
        if (is_node_owner(ship.nodeId)) {
            get_component(ship.nodeId) <| $(var body : RigidBody?) {
                drive_ship(body, ship.nodeId, sticks[1])
            }
        }
    }
}

[export]
def on_resolution_changed(res : int2) {
    fit_camera(res)
}

def private spawn_bar(pos, size : float3) {
    let node = create_node(NodeData(name = "frame", position = pos, scale = size))
    add_component(node, new Mesh(meshId = CUBE_MESH_ID, color = FRAME_COLOR))
}

def private spawn_frame {
    let h = ARENA_HALF
    let t = 0.15
    spawn_bar(float3(0, h.y + t * 0.5, 0), float3(h.x * 2.0 + t * 2.0, t, t))
    spawn_bar(float3(0, -h.y - t * 0.5, 0), float3(h.x * 2.0 + t * 2.0, t, t))
    spawn_bar(float3(h.x + t * 0.5, 0, 0), float3(t, h.y * 2.0, t))
    spawn_bar(float3(-h.x - t * 0.5, 0, 0), float3(t, h.y * 2.0, t))
}

def private init_input {
    add_and_activate_action_set("ship", {
        "thrust" => Action(axisActions = AxisAction(
            keyboardAxis = [
                KeyboardBtnAxisInput(negativeIdx = KeyCode.S, positiveIdx = KeyCode.W),
                KeyboardBtnAxisInput(negativeIdx = KeyCode.Down, positiveIdx = KeyCode.Up)
            ],
            stickAxis = [GamepadAxisInput(idx = GamepadAxis.LThumbV, deadZone = STICK_DEADZONE)]
        )),
        "turn" => Action(axisActions = AxisAction(
            keyboardAxis = [
                KeyboardBtnAxisInput(negativeIdx = KeyCode.A, positiveIdx = KeyCode.D),
                KeyboardBtnAxisInput(negativeIdx = KeyCode.Left, positiveIdx = KeyCode.Right)
            ],
            stickAxis = [GamepadAxisInput(idx = GamepadAxis.LThumbH, deadZone = STICK_DEADZONE)]
        ))
    })
}

def private fit_camera(res : int2) {
    let arena = ARENA_HALF * 2.0 + float2(CAMERA_MARGIN)
    let wide = float(res.x) / float(res.y) >= arena.x / arena.y
    get_component(camera) <| $(var cam : Camera?) {
        cam.fovAxis = wide ? FovAxis.Vertical : FovAxis.Horizontal
        cam.orthographicSize = wide ? arena.y : arena.x
    }
}
