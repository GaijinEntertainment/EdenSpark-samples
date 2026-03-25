require engine.core
require common

def get_triangle_norm(v0, v1, v2 : float3) {
    return normalize(cross(v1 - v0, v2 - v0))
}

def add_vert_triange_face_to_geometry(var geom : MeshGeometry, v0, v1, v2 : float3) {
    let baseVert = geom.vertices.length()
    var norm = get_triangle_norm(v0, v1, v2)
    geom.vertices.push(v0)
    geom.vertices.push(v1)
    geom.vertices.push(v2)
    geom.normals.push(norm)
    geom.normals.push(norm)
    geom.normals.push(norm)
    geom.uv.push(float2(0, 0))
    geom.uv.push(float2(0.5, 1))
    geom.uv.push(float2(1, 0))
    geom.triangles.push(uint3(baseVert, baseVert + 1, baseVert + 2))
}

def add_quad_face_to_geometry(var geom : MeshGeometry, v0, v1, v2, v3 : float3, uv_offset : float2 = float2(0, 0)) {
    let baseVert = geom.vertices.length()
    var norm = normalize(get_triangle_norm(v0, v2, v1) + get_triangle_norm(v1, v2, v3))
    geom.vertices.push(v0)
    geom.vertices.push(v1)
    geom.vertices.push(v2)
    geom.vertices.push(v3)
    geom.normals.push(norm)
    geom.normals.push(norm)
    geom.normals.push(norm)
    geom.normals.push(norm)
    geom.uv.push(float2(0, 0) + uv_offset)
    geom.uv.push(float2(1, 0) + uv_offset)
    geom.uv.push(float2(0, 1) + uv_offset)
    geom.uv.push(float2(1, 1) + uv_offset)
    geom.triangles.push(uint3(baseVert, baseVert + 2, baseVert + 1))
    geom.triangles.push(uint3(baseVert + 1, baseVert + 2, baseVert + 3))
}

def make_empty_tile_geometry(world : WorldState, global_ring_id, row_id : int) {
    // Quad.

    var baseVerts : float3[4]
    var baseNorms : float3[4]
    get_world_position_normal_at_grid_pos(world, float(row_id), float(global_ring_id), baseVerts[0], baseNorms[0])
    get_world_position_normal_at_grid_pos(world, float(row_id + 1), float(global_ring_id), baseVerts[1], baseNorms[1])
    get_world_position_normal_at_grid_pos(world, float(row_id), float(global_ring_id + 1), baseVerts[2], baseNorms[2])
    get_world_position_normal_at_grid_pos(world, float(row_id + 1), float(global_ring_id + 1), baseVerts[3], baseNorms[3])

    var tileGeometry = MeshGeometry()
    add_quad_face_to_geometry(tileGeometry, baseVerts[0], baseVerts[1], baseVerts[2], baseVerts[3])
    return <- tileGeometry
}

def make_small_obstacle_geometry(world : WorldState, global_ring_id, row_id : int) {
    // Pyramid.

    var baseVerts : float3[9]
    var baseNorms : float3[5]
    get_world_position_normal_at_grid_pos(world, float(row_id), float(global_ring_id), baseVerts[0], baseNorms[0])
    get_world_position_normal_at_grid_pos(world, float(row_id + 1), float(global_ring_id), baseVerts[1], baseNorms[1])
    get_world_position_normal_at_grid_pos(world, float(row_id), float(global_ring_id + 1), baseVerts[2], baseNorms[2])
    get_world_position_normal_at_grid_pos(world, float(row_id + 1), float(global_ring_id + 1), baseVerts[3], baseNorms[3])
    get_world_position_normal_at_grid_pos(world, float(row_id) + 0.5, float(global_ring_id) + 0.5, baseVerts[4], baseNorms[4])
    baseVerts[4] += baseNorms[4] * world.setup.tileSize.y
    baseVerts[5] = (baseVerts[0] + baseVerts[1]) * 0.5
    baseVerts[6] = (baseVerts[1] + baseVerts[3]) * 0.5
    baseVerts[7] = (baseVerts[3] + baseVerts[2]) * 0.5
    baseVerts[8] = (baseVerts[2] + baseVerts[0]) * 0.5

    var norm : float3
    var tileGeometry = MeshGeometry()
    // Make quads to use quad materials. And to not see piexlization.
    add_quad_face_to_geometry(tileGeometry, baseVerts[0], baseVerts[5], baseVerts[4], baseVerts[1], float2(-0.01, 0))
    add_quad_face_to_geometry(tileGeometry, baseVerts[1], baseVerts[6], baseVerts[4], baseVerts[3], float2(1, 0))
    add_quad_face_to_geometry(tileGeometry, baseVerts[3], baseVerts[7], baseVerts[4], baseVerts[2], float2(-0.01, 0))
    add_quad_face_to_geometry(tileGeometry, baseVerts[2], baseVerts[8], baseVerts[4], baseVerts[0], float2(1, 0))
    // add_vert_triange_face_to_geometry(tileGeometry, baseVerts[0], baseVerts[4], baseVerts[1])
    // add_vert_triange_face_to_geometry(tileGeometry, baseVerts[1], baseVerts[4], baseVerts[3])
    // add_vert_triange_face_to_geometry(tileGeometry, baseVerts[3], baseVerts[4], baseVerts[2])
    // add_vert_triange_face_to_geometry(tileGeometry, baseVerts[2], baseVerts[4], baseVerts[0])
    return <- tileGeometry
}

def make_medium_obstacle_geometry(world : WorldState, global_ring_id, row_id : int) {
    // Box.

    var baseVerts : float3[8]
    var baseNorms : float3[4]
    get_world_position_normal_at_grid_pos(world, float(row_id), float(global_ring_id), baseVerts[0], baseNorms[0])
    get_world_position_normal_at_grid_pos(world, float(row_id + 1), float(global_ring_id), baseVerts[1], baseNorms[1])
    get_world_position_normal_at_grid_pos(world, float(row_id), float(global_ring_id + 1), baseVerts[2], baseNorms[2])
    get_world_position_normal_at_grid_pos(world, float(row_id + 1), float(global_ring_id + 1), baseVerts[3], baseNorms[3])
    baseVerts[4] = baseVerts[0] + baseNorms[0] * world.setup.tileSize.y
    baseVerts[5] = baseVerts[1] + baseNorms[1] * world.setup.tileSize.y
    baseVerts[6] = baseVerts[2] + baseNorms[2] * world.setup.tileSize.y
    baseVerts[7] = baseVerts[3] + baseNorms[3] * world.setup.tileSize.y

    var tileGeometry = MeshGeometry()
    add_quad_face_to_geometry(tileGeometry, baseVerts[0], baseVerts[1], baseVerts[4], baseVerts[5])
    add_quad_face_to_geometry(tileGeometry, baseVerts[1], baseVerts[3], baseVerts[5], baseVerts[7], float2(1, 0))
    add_quad_face_to_geometry(tileGeometry, baseVerts[3], baseVerts[2], baseVerts[7], baseVerts[6])
    add_quad_face_to_geometry(tileGeometry, baseVerts[2], baseVerts[0], baseVerts[6], baseVerts[4], float2(1, 0))
    add_quad_face_to_geometry(tileGeometry, baseVerts[4], baseVerts[5], baseVerts[6], baseVerts[7], float2(1, 0))
    return <- tileGeometry
}

def make_big_obstacle_geometry(global_ring_id, row_id : int) {

}

def make_fatal_obstacle_geometry(global_ring_id, row_id : int) {

}
