options no_unused_block_arguments
options no_unused_function_arguments

module quad_gen

require engine.gen_geometry.mesh_structures

def create_quad_mesh(width, height : int) : MeshGeometry {

    var vertices <- [
        float3(0, 0, 0),
        float3(0, height, 0),
        float3(width, height, 0),
        float3(width, 0, 0)
    ]
    var normals <- [float3(0, 0, -1), float3(0, 0, -1), float3(0, 0, -1), float3(0, 0, -1)]
    var uvs <- [float2(0, 0), float2(0, height), float2(width, height), float2(width, 0)]

    var triangles <- [uint3(0u, 1u, 2u), uint3(2u, 3u, 0u)]

    return <- MeshGeometry(vertices <- vertices, normals <- normals, uv <- uvs, triangles <- triangles)
}
