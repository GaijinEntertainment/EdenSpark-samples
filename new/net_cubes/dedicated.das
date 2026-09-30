require engine.core
require engine.networking
require net_cubes_common


let CUBE_COUNT = 8
let ASTEROID_COUNT = 5
let ASTEROID_RADIUS = 8.5
let TARGET_SWITCH_PERIOD = 1.0
let COMET_MESH_SWITCH_PERIOD = 0.7

var private {
    active : bool = false
    cometNode : NodeId
    cometTimer : float = 0.0
    cometMeshTimer : float = 0.0
    cometIsSphere : bool = false
    ring : array<NodeId>
    targetTimer : float = 0.0
    targetStep : int = 0
}


def private spawn_asteroids() {
    for (i in range(ASTEROID_COUNT)) {
        let f = float(i) / float(ASTEROID_COUNT)
        let angle = f * 6.28
        let radius = ASTEROID_RADIUS + f * 2.0
        let node = create_node(NodeData(name = "asteroid_{i}"))
        add_component(node, new Asteroid(
            color = float4(0.6, 0.6 + 0.3 * f, 0.7, 1.0),
            spawnPos = float3(cos(angle) * radius, 1.5 + f * 2.5, sin(angle) * radius),
            spawnVel = float3(-sin(angle), 0.0, cos(angle)) * asteroid_chase_speed(radius)
        ))
    }
    switch_asteroid_targets()
}


def private switch_asteroid_targets() {
    return if (empty(ring))
    var i = 0
    for (asteroid in find_components(type<Asteroid>)) {
        asteroid.target = ring[(targetStep + i) % length(ring)]
        i++
    }
}


[net_command_handler]
def echo_ping(cmd : PingCmd, connection : ConnectionId) {
    broadcast_net_command(PongCmd(clientTime = cmd.clientTime), connection)
}


[export]
def on_initialize {
    set_replication_fps(60.0)

    if (!has_network() || !is_server()) {
        error("[net_cubes] no listen session - run with --listen=127.0.0.1:20020")
        return
    }
    for (i in range(CUBE_COUNT)) {
        let f = float(i) / float(CUBE_COUNT)
        let node = create_node(NodeData(name = "orbit_cube_{i}"))
        add_component(node, new Mesh(meshId = CUBE_MESH_ID,
            color = float4(0.5 + 0.5 * sin(f * 6.28), 0.5 + 0.5 * sin(f * 6.28 + 2.09), 0.5 + 0.5 * sin(f * 6.28 + 4.18), 1.0)))
        add_component(node, new OrbitCube(
            orbitRadius = 4.0 + f * 3.0,
            orbitPhase = f * 6.28,
            orbitSpeed = 0.4 + f * 0.5
        ))
        ring |> push(node)
    }
    spawn_asteroids()
    active = true
    print("[net_cubes] server active: {CUBE_COUNT} cubes, {ASTEROID_COUNT} asteroids on port 20020")
}

[export]
def on_update {
    if (!active) {
        return
    }
    targetTimer += get_delta_time()
    if (targetTimer >= TARGET_SWITCH_PERIOD) {
        targetTimer = 0.0
        targetStep++
        switch_asteroid_targets()
    }
    cometTimer += get_delta_time()
    if (!cometNode && cometTimer >= 2.0) {
        cometTimer = 0.0
        cometMeshTimer = 0.0
        cometIsSphere = false
        cometNode = create_node(NodeData(name = "comet"))
        set_net_replication(cometNode, type<Collider>, true)
        set_net_replication(cometNode, type<RigidBody>, true)
        add_component(cometNode, new Mesh(meshId = CUBE_MESH_ID, color = float4(1.0, 0.9, 0.2, 1.0)))
        add_component(cometNode, new Collider(friction = 0.4, shapes = [box_shape(float3(1))]))
        add_component(cometNode, new RigidBody(motionType = MotionType.Kinematic, useGravity = false))
        add_component(cometNode, new OrbitCube(
            orbitRadius = 9.0,
            orbitPhase = get_time(),
            orbitSpeed = 1.6,
            bobHeight = 4.0
        ))
    } elif (!!cometNode && cometTimer >= 3.0) {
        cometTimer = 0.0
        remove_node(cometNode)
        cometNode = NodeId()
    }
    switch_comet_mesh()
}


def private switch_comet_mesh() {
    return if (!cometNode)
    cometMeshTimer += get_delta_time()
    return if (cometMeshTimer < COMET_MESH_SWITCH_PERIOD)
    cometMeshTimer = 0.0
    cometIsSphere = !cometIsSphere
    get_component(cometNode) <| $(var mesh : Mesh?) {
        mesh.meshId = cometIsSphere ? SPHERE_MESH_ID : CUBE_MESH_ID
        print("[net_cubes] comet mesh -> {mesh_name(mesh.meshId)}")
    }
}
