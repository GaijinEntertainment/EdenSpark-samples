require engine.core
require engine.networking


[replicated(sync = (Transform, Mesh))]
class OrbitCube : Component {
    orbitRadius : float = 5.0
    orbitPhase : float = 0.0
    orbitSpeed : float = 0.7
    bobHeight : float = 1.5

    def override on_update {
        return if (hasRemoteAuthority)
        let a = orbitPhase + get_time() * orbitSpeed
        nodeId.localPosition = float3(cos(a) * orbitRadius, 1.5 + sin(a * 3.0) * bobHeight * 0.5, sin(a) * orbitRadius)
        nodeId.localRotation = quat4(0.0, a * 2.0, 0.0)
    }
}


[net_command(reliability=UNRELIABLE)]
struct PingCmd {
    clientTime : float
}

[net_command(reliability=UNRELIABLE)]
struct PongCmd {
    clientTime : float
}


def public mesh_name(mesh_id : MeshId) : string {
    if (mesh_id == CUBE_MESH_ID) {
        return "cube"
    } elif (mesh_id == SPHERE_MESH_ID) {
        return "sphere"
    }
    return "<unknown>"
}


let private TARGET_GM = 60.0
let private SOFTENING = 2.5
let private DRAG = 0.15
let private MAX_STEP = 0.05
//hotrel_tag(!move-speed)
let private MAX_SPEED = 8.0
//hotrel_tag(!move-speed)
//hotrel_tag(move-speed) let private MAX_SPEED = 12.0
let private MAX_RADIUS = 14.0 // constraint: past it an asteroid leaves the frame of the main.das camera
let private WALL_BOUNCE = 0.6

//hotrel_tag(!drop-method)
def private hotrel_keep_mark() : int {
    return 1
}
//hotrel_tag(!drop-method)

//hotrel_tag(add-method)
def public hotrel_move_scale() : float {
    return 1.5
}
//hotrel_tag(add-method)

//hotrel_tag(add-struct)
struct HotrelMoveScratch {
    scale : float
}
//hotrel_tag(add-struct)


[replicated]
class Asteroid : Component {
    color : float4 = float4(1)
    spawnPos : float3
    spawnVel : float3
    target : NodeId

    def override on_initialize {
        if (hasRemoteAuthority) {
            add_component(nodeId, new Mesh(meshId = SPHERE_MESH_ID, color = color))
            add_component(nodeId, new AsteroidMotion(pos = spawnPos, vel = spawnVel))
        }
    }
}


// constraint: a changed field re-sends the whole component, so a replicated pos would snap back on each target switch
class AsteroidMotion : Component {
    pos : float3
    vel : float3

    def override on_update {
        var target = NodeId()
        get_component(nodeId) <| $(asteroid : Asteroid?) {
            target = asteroid.target
        }
        integrate(min(get_delta_time(), MAX_STEP), target)
        nodeId.localPosition = pos
    }

    def integrate(dt : float; target : NodeId) {
        if (target.isAlive) {
            let d = target.localPosition - pos
            let softSq = dot(d, d) + SOFTENING * SOFTENING
            vel += d * (TARGET_GM * dt / (softSq * sqrt(softSq)))
        }
        vel *= max(1.0 - DRAG * dt, 0.0)
        let speed = length(vel)
        if (speed > MAX_SPEED) {
            vel *= MAX_SPEED / speed
        }
        pos += vel * dt

        let r = length(pos)
        if (r > MAX_RADIUS) {
            let n = pos / r
            pos = n * MAX_RADIUS
            let outward = dot(vel, n)
            if (outward > 0.0) {
                vel -= n * (outward * (1.0 + WALL_BOUNCE))
            }
        }
    }
}


def public asteroid_chase_speed(radius : float) : float {
    //! Keeps a fresh asteroid circling instead of dropping straight onto its first target.
    return sqrt(TARGET_GM / radius)
}
