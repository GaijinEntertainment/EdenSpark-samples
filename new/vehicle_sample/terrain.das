require engine.core
require engine.gen_geometry.mesh_structures

module terrain public

// city instead of being the whole map
let TERRAIN_SIZE = 1000.
let TERRAIN_RESOLUTION = 100
let TERRAIN_BASE_Y = -8. // sits mostly below the city floor (y=0) so it reads as background relief
let TERRAIN_MAX_HEIGHT = 45.
let TERRAIN_NOISE_FREQUENCY = 0.02
let TERRAIN_COLOR = color32_to_float4(0xFFA3D877)

let RELIEF_FLAT_L1 = 100.
let RELIEF_FULL_L1 = 500.

def public spawn_terrain() : NodeId {
    var geo = create_plane_mesh_geometry(TERRAIN_RESOLUTION)

    for (v, i in geo.vertices, range(length(geo.vertices))) {
        let worldX = v.x * TERRAIN_SIZE
        let worldZ = v.z * TERRAIN_SIZE
        let noiseVal = perlin_noise(float2(worldX, worldZ) * TERRAIN_NOISE_FREQUENCY)

        let l1Dist = abs(worldX) + abs(worldZ)
        let reliefT = clamp((l1Dist - RELIEF_FLAT_L1) / (RELIEF_FULL_L1 - RELIEF_FLAT_L1), 0., 1.)

        geo.vertices[i] = float3(worldX, reliefT * (TERRAIN_BASE_Y + noiseVal * TERRAIN_MAX_HEIGHT), worldZ)
    }

    geo.normals.resize(0)

    let collisionId = create_mesh_collision_sync(geo.triangles, geo.vertices, false)
    let terrainMesh = create_mesh(geo)

    let terrainNode = create_node(NodeData(name = "terrain"))
    add_component(terrainNode, new Mesh(meshId = terrainMesh, color = TERRAIN_COLOR))
    add_component(terrainNode, new Collider(shape = mesh_shape(collisionId), friction = 0.8))

    return terrainNode
}
