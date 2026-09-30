require engine.core
require engine.gen_geometry.mesh_structures
require engine.math_core

module road public

let BYPASS_UNIT_LENGTH = 115.0
let BYPASS_CORNER_RADIUS = 15.0
let BYPASS_CORNER_STEPS = 10
let BYPASS_ROAD_WIDTH = 10.0
let BYPASS_ROAD_POSITION = float3(-60.0, 0.1, 0.0)
let BYPASS_ROAD_ROTATION = quat4(0.0, PI, 0.0)
let BYPASS_ROAD_COLOR = float4(0.22, 0.22, 0.24, 1.0)

def private push_corner_steps(var stepLengths : array<float>&; var stepRotations : array<float>&; turnAngle : float) {
    let stepRotation = turnAngle / float(BYPASS_CORNER_STEPS)
    let stepLength = BYPASS_CORNER_RADIUS * abs(turnAngle) / float(BYPASS_CORNER_STEPS)
    for (i in range(BYPASS_CORNER_STEPS)) {
        push(stepLengths, stepLength)
        push(stepRotations, stepRotation)
    }
}

def private build_l_shape_track_steps(var stepLengths : array<float>&; var stepRotations : array<float>&) {
    let lengthsInUnits <- [1.0, 1.5, 0.5, 1.0, 1.0, 0.5, 0.5]
    let turns <- [HALF_PI, HALF_PI, HALF_PI, -HALF_PI, HALF_PI, HALF_PI]

    for (i in range(length(lengthsInUnits))) {
        var straightLength = lengthsInUnits[i] * BYPASS_UNIT_LENGTH
        if (i > 0) {
            straightLength -= BYPASS_CORNER_RADIUS // corner at the start of this straight
        }
        if (i < length(turns)) {
            straightLength -= BYPASS_CORNER_RADIUS // corner at the end of this straight
        }
        push(stepLengths, straightLength)
        push(stepRotations, 0.0)

        if (i < length(turns)) {
            push_corner_steps(stepLengths, stepRotations, turns[i])
        }
    }
}

def public spawn_bypass_road() : NodeId {
    var stepLengths : array<float>
    var stepRotations : array<float>
    build_l_shape_track_steps(stepLengths, stepRotations)

    let startPoint = float3(-BYPASS_UNIT_LENGTH * 0.5, 0.0, BYPASS_UNIT_LENGTH)
    let geo = generate_track_mesh(stepLengths, stepRotations, BYPASS_ROAD_WIDTH, startPoint, 0.0)
    let collisionId = create_mesh_collision_sync(geo.triangles, geo.vertices, false)
    let roadMesh = create_mesh(geo)

    let roadNode = create_node(NodeData(name = "bypass road", position = BYPASS_ROAD_POSITION, rotation = BYPASS_ROAD_ROTATION))
    add_component(roadNode, new Mesh(meshId = roadMesh, color = BYPASS_ROAD_COLOR, isStatic = true))
    add_component(roadNode, new Collider(shape = mesh_shape(collisionId), friction = 1.0))

    return roadNode
}

def public generate_track_mesh(stepLengths : array<float>; stepRotations : array<float>; width : float; startPoint : float3; startAngle : float) : MeshGeometry {
    var mesh : MeshGeometry
    let halfWidth = width * 0.5
    let stepCount = length(stepLengths)
    var center = startPoint
    var angle = startAngle

    for (i in range(stepCount + 1)) {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        let perp = float3(sinAngle, 0.0, cosAngle)

        push(mesh.vertices, center - perp * halfWidth)
        push(mesh.vertices, center + perp * halfWidth)
        push(mesh.normals, float3(0.0, 1.0, 0.0))
        push(mesh.normals, float3(0.0, 1.0, 0.0))
        let t = float(i) / float(stepCount)
        push(mesh.uv, float2(0.0, t))
        push(mesh.uv, float2(1.0, t))

        if (i < stepCount) {
            var baseIndex = i * 2
            push(mesh.triangles, uint3(baseIndex, baseIndex + 1, baseIndex + 2))
            push(mesh.triangles, uint3(baseIndex + 1, baseIndex + 3, baseIndex + 2))

            let forward = float3(cosAngle, 0.0, -sinAngle)
            center += forward * stepLengths[i]
            angle += stepRotations[i]
        }
    }

    return <- mesh
}
