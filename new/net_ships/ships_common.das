require engine.core
require engine.networking


let public {
    ARENA_HALF = float2(20.0, 12.0)
    SHIP_RADIUS = 0.9
    THRUST_FORCE = 14.0
    TURN_SPEED = 3.5
    SHIP_MASS = 1.0
    SHIP_LINEAR_DAMPING = 0.8
    SHIP_ANGULAR_DAMPING = 6.0
    PHYSICS_FPS = 60.0
    STICK_HISTORY = 64
    MAX_CONTROLS_TICK_DELTA = int(0.375 * PHYSICS_FPS)
    CONTROLS_PIPELINE_TICKS = 4
    STICK_HOLD_TICKS = int(0.35 * PHYSICS_FPS)
}



let public {
    ASTEROID_COUNT = 7
    SHIP_COLORS = [float4(0.95, 0.35, 0.25, 1), float4(0.3, 0.7, 1.0, 1), float4(0.4, 0.9, 0.4, 1), float4(1.0, 0.85, 0.3, 1), float4(0.85, 0.45, 1.0, 1), float4(0.4, 0.95, 0.9, 1)]
}


[replicated(sync = Transform)]
class Ship : Component {
    color : float4 = float4(1)
}

[replicated]
class Asteroid : Component {
    color : float4 = float4(1)
}

[replicated(sync = Collider)]
class Wall : Component {}


struct Stick {
    tick : int // the client's fixed tick it was sampled on
    thrust : float // -1 .. 1 along the nose
    turn : float // -1 .. 1, positive clockwise
}

[net_command(reliability=UNRELIABLE_SEQUENCED, channel=Controls)]
struct ShipInputToServer {
    sticks : Stick[2]
}


struct ShipState {
    pos : float3
    vel : float3
    angle : float // around Z; at 0 the nose points along +Y
}

def ship_angle(rot : quat4) : float {
    let nose = rot * float3(0, 1, 0)
    return atan2(-nose.x, nose.y)
}

def read_ship_state(node : NodeId; body : RigidBody?) : ShipState {
    return ShipState(pos = node.localPosition, vel = body.velocity, angle = ship_angle(node.localRotation))
}

let public {
    STATE_POS_EPS = 0.02 // meters
    STATE_VEL_EPS = 0.1 // m/s
    STATE_ANGLE_EPS = 0.01 // radians
}

def states_agree(a, b : ShipState) : bool {
    return (length(a.pos - b.pos) <= STATE_POS_EPS && length(a.vel - b.vel) <= STATE_VEL_EPS
        && abs(angle_diff(a.angle, b.angle)) <= STATE_ANGLE_EPS)
}


def spawn_wall(pos, size : float3) {
    let node = create_node(NodeData(name = "wall", position = pos, scale = size))
    add_component(node, new Wall())
    add_component(node, new Collider(shape = box_shape(), restitution = 0.9))
}

def spawn_walls {
    let h = ARENA_HALF
    let t = 1.0
    spawn_wall(float3(0, h.y + t * 0.5, 0), float3(h.x * 2.0 + t * 2.0, t, 4.0))
    spawn_wall(float3(0, -h.y - t * 0.5, 0), float3(h.x * 2.0 + t * 2.0, t, 4.0))
    spawn_wall(float3(h.x + t * 0.5, 0, 0), float3(t, h.y * 2.0, 4.0))
    spawn_wall(float3(-h.x - t * 0.5, 0, 0), float3(t, h.y * 2.0, 4.0))
}

def add_asteroid_body(node : NodeId) {
    let radius = node.localScale.x * 0.5
    add_component(node, new Collider(shape = sphere_shape(), restitution = 1.0, friction = 0.0))
    add_component(node, new RigidBody(mass = radius * radius * 4.0, useGravity = false, allowedDofs = AllowedDofs.AllowedDofs2D,
        linearDamping = 0.0, angularDamping = 0.0))
}

def spawn_asteroids {
    for (i in range(ASTEROID_COUNT)) {
        let radius = 0.9 + random_float() * 0.5
        let pos = float3((random_float() - 0.5) * ARENA_HALF.x * 1.6, (random_float() - 0.5) * ARENA_HALF.y * 1.6, 0.0)
        let node = create_node(NodeData(name = "asteroid_{i}", position = pos, scale = float3(radius * 2.0)))
        let color = float4(0.5 + random_float() * 0.2, 0.45, 0.4, 1.0)
        add_component(node, new Asteroid(color = color))
        add_component(node, new Mesh(meshId = SPHERE_MESH_ID, color = color))
        add_asteroid_body(node)
        let angle = random_float() * 2.0 * PI
        get_component(node) <| $(var body : RigidBody?) {
            body.velocity = float3(cos(angle), sin(angle), 0.0) * (1.5 + random_float() * 2.0)
        }
    }
}


def add_ship_body(node : NodeId) {
    add_component(node, new Collider(shape = sphere_shape(radius = SHIP_RADIUS), restitution = 0.6, friction = 0.1))
    add_component(node, new RigidBody(mass = SHIP_MASS, useGravity = false, allowedDofs = AllowedDofs.AllowedDofs2D,
        linearDamping = SHIP_LINEAR_DAMPING, angularDamping = SHIP_ANGULAR_DAMPING))
}


def spawn_arena {
    spawn_walls()
    spawn_asteroids()
}


def spawn_ship(index : int) : NodeId {
    let angle = float(index) * 2.4
    let node = create_node(NodeData(name = "ship_{index}", position = float3(cos(angle) * 6.0, sin(angle) * 6.0, 0.0),
        rotation = quat4(0.0, 0.0, angle + PI * 0.5)))
    add_component(node, new Ship(color = SHIP_COLORS[index % length(SHIP_COLORS)]))
    add_ship_body(node)
    return node
}

def drive_ship(var body : RigidBody?; node : NodeId; stick : Stick) {
    apply_force(body, node.localRotation * float3(0, 1, 0) * (THRUST_FORCE * clamp(stick.thrust, -1.0, 1.0)))
    body.angularVelocity = float3(0, 0, -TURN_SPEED * clamp(stick.turn, -1.0, 1.0))
}


struct BodyState {
    node : NodeId
    state : ShipState
}

[net_command(reliability=UNRELIABLE_SEQUENCED, channel=Default)]
struct BodiesAuthorityToClient {
    appliedStickTick : int
    bodies : array<BodyState>
}


[net_command(reliability=UNRELIABLE, channel=Events)]
struct ShipBumpedToClient {
    node : NodeId
    byShip : bool
}
