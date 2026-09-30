require engine.core
require engine.networking
require engine.net.lobby
require engine.helper_functions
require net_cubes_common

let PING_PERIOD = 0.5

var private {
    cubeCount : int = -1
    asteroidCount : int = -1
    pingTimer : float = 0.0
    pongCount : int = 0
}


[net_command_handler]
def on_pong(cmd : PongCmd) {
    let rtt = get_time() - cmd.clientTime
    return if (rtt < 0.0 || rtt > 5.0)
    pongCount++
    print("[net_cubes] ping {int(rtt * 1000.0)} ms (pong #{pongCount})")
}

[export]
def on_update {
    let n = length(find_components(type<OrbitCube>))
    if (n != cubeCount) {
        cubeCount = n
        print("[net_cubes] visible cubes: {n}")
    }
    let a = length(find_components(type<Asteroid>))
    if (a != asteroidCount) {
        asteroidCount = a
        print("[net_cubes] visible asteroids: {a}")
    }
    if (has_network() && is_server()) {
        return
    }
    if (cubeCount > 0) {
        pingTimer += get_delta_time()
        if (pingTimer >= PING_PERIOD) {
            pingTimer = 0.0
            broadcast_net_command(PingCmd(clientTime = get_time()))
        }
    }
}

[export]
def on_initialize {
    create_plane(float3(0.0, 0.0, 0.0), float3(30.0), quat4(), float4(0.16, 0.17, 0.19, 1.0))
    set_light_color(float3(1.0, 0.95, 0.9) * 1.2)
    set_light_direction(float3(-0.3, -1.0, 0.5))
    set_3d_camera_fov_degrees(45.0)
    set_3d_camera_look(float3(12.0, 9.0, 12.0), float3(0.0, 1.0, 0.0), float3(0.0, 1.0, 0.0))
    create_render_settings()

    set_lobby_callbacks(@@on_lobby_created, @@on_connection_established, @@on_connection_lost, @@on_lobby_left, @@on_lobby_destroyed)
    print("[net_cubes] open_lobby_menu")
    open_lobby_menu()
}

def on_lobby_created(data : LobbyData) {
    print("[net_cubes] lobby created hosting={data.shouldHost}")
}

def on_connection_established(userName : string) {
    print("[net_cubes] connected as {userName}")
}

def on_connection_lost(cause : DisconnectCause) {
    print("[net_cubes] connection lost cause={cause}")
}

def on_lobby_left(kicked : bool) {
    print("[net_cubes] on_lobby_left kicked={kicked}")
}

def on_lobby_destroyed() {
    print("[net_cubes] on_lobby_destroyed")
}
