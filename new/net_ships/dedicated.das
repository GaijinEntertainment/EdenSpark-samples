require engine.core
require engine.networking
require ships_common


var private {
    shipsSpawned : int = 0
    shipByConn : table<int; NodeId>
}


// Not [replicated]: no client sees another player's stick.
class ShipControl : Component {
    private sticks : array<Stick>
    private applied = Stick(tick = -1)
    private controlsTickDelta : int = 1

    def receive(cmd : ShipInputToServer) {
        for (stick in cmd.sticks) {
            if (empty(sticks) || stick.tick > back(sticks).tick) {
                sticks |> push(stick)
            }
        }
        while (length(sticks) > STICK_HISTORY) {
            sticks |> erase(0)
        }
    }

    def private planControlsTickDelta {
        let rtt = get_round_trip_msec(get_node_owner(nodeId))
        let wanted = min(ceili(float(rtt) * PHYSICS_FPS / 2000.0) + CONTROLS_PIPELINE_TICKS, MAX_CONTROLS_TICK_DELTA)
        if (wanted > controlsTickDelta || wanted <= controlsTickDelta - 2) {
            controlsTickDelta = wanted
        }
    }

    def private newestStickAtOrBefore(tick : int) : Stick {
        var found = applied
        for (stick in sticks) {
            if (stick.tick <= tick && stick.tick > found.tick) {
                found = stick
            }
        }
        return tick - found.tick > STICK_HOLD_TICKS ? Stick(tick = found.tick) : found
    }

    def step(now : int) {
        planControlsTickDelta()
        sendState()
        applied = newestStickAtOrBefore(now - controlsTickDelta)
        get_component(nodeId) <| $(var body : RigidBody?) {
            drive_ship(body, nodeId, applied)
        }
    }

    def private sendState {
        return if (applied.tick < 0)
        var answer = BodiesAuthorityToClient(appliedStickTick = applied.tick)
        add_body_state(answer, nodeId)
        for (rock in find_components(type<Asteroid>)) {
            add_body_state(answer, rock.nodeId)
        }
        broadcast_net_command(answer, get_node_owner(nodeId))
    }
}


def private add_body_state(var answer : BodiesAuthorityToClient; node : NodeId) {
    get_component(node) <| $(var body : RigidBody?) {
        answer.bodies |> push(BodyState(node = node, state = read_ship_state(node, body)))
    }
}


[net_event_handler(client_connected)]
def private spawn_ship_for(conn : ConnectionId; userId : uint64; name : string) {
    let node = spawn_ship(shipsSpawned)
    shipsSpawned++
    add_component(node, new ShipControl())
    set_node_owner(node, conn)
    shipByConn[*conn] = node
    on_collision(node, @(collision) {
        broadcast_net_command(ShipBumpedToClient(node = node, byShip = has_component(collision.nodeId, type<Ship>)))
    })
    print("[net_ships] connection {*conn} drives {node.name}")
}

[net_event_handler(client_disconnected)]
def private remove_ships_of(conn : ConnectionId; cause : DisconnectCause) {
    let found = shipByConn?[*conn] ?? NodeId()
    return if (!found.isAlive)
    remove_node(found)
    shipByConn |> erase(*conn)
}


[net_command_handler]
def on_ship_input(cmd : ShipInputToServer; from : ConnectionId) {
    let node = shipByConn?[*from] ?? NodeId()
    return if (!node.isAlive)
    get_component(node) <| $(var control : ShipControl?) {
        control.receive(cmd)
    }
}


[export]
def on_initialize {
    set_physics_fps(PHYSICS_FPS)
    set_replication_fps(PHYSICS_FPS)
    spawn_arena()
    print("[net_ships] arena built, waiting for the session")
}

[export]
def on_fixed_update {
    let tick = get_fixed_tick()
    for (control in find_components(type<ShipControl>)) {
        control.step(tick)
    }
}
