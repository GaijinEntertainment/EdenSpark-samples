require engine.gen_geometry.mesh_structures
require engine.math_core
require math

module trackSegmentGen public


struct TrackSegmentDescription {
    rotation : float = 0.0
    subdivLength : float = 5.0
    subdivCount : int = 10
    startWidth : float = 3.0
    endWidth : float = 3.0
}


[mesh_generator]
def generate_track_mesh(desc : TrackSegmentDescription) : MeshGeometry {
    let slicePoints = fixed_array(
        float2(0.0, 0.0), float2(0.25, 0.0), float2(0.5, 0.0), float2(0.75, 0.0), float2(1.0, 0.0),
        float2(1.1, 0.2), float2(1.3, 0.4), float2(1.8, 0.45), float2(2.0, 0.1), float2(6.0, 0.0)
    )
    var mesh : MeshGeometry
    var center : float3 = float3(0)

    for (i in range(desc.subdivCount + 1)) {
        var t = float(i) / float(desc.subdivCount)
        var width = lerp(desc.startWidth, desc.endWidth, smoothstep(t))
        var angle = desc.rotation * t
        var cos_angle = cos(angle)
        var sin_angle = sin(angle)

        let low = -length(slicePoints) + 1
        let high = length(slicePoints) - 1

        for (j in range(low, high + 1)) {
            var slicePoint = slicePoints[abs(j)]
            var x = slicePoint.x * width * float(sign(j))
            var position = center + x * float3(sin_angle, 0.0, cos_angle) + float3(0.0, slicePoint.y, 0.0)

            if (abs(x) > 1.1 * width && j != low && j != high && i != 0 && i != desc.subdivCount) {
                position.y += random_float() * 0.4
            }

            var normal = float3(0, 1, 0)
            var tex_coord = float2(slicePoint.x * 0.12 + 0.5, t)
            push(mesh.vertices, position)
            push(mesh.normals, normal)
            push(mesh.uv, tex_coord)
        }

        center += float3(cos_angle, 0.0, -sin_angle) * desc.subdivLength
    }


    let vertexPerSubdiv = length(slicePoints) * 2 - 1
    for (i in range(desc.subdivCount)) {
        for (j in range(vertexPerSubdiv - 1)) {
            var baseIndex = i * vertexPerSubdiv + j
            push(mesh.triangles, uint3(baseIndex, baseIndex + 1, baseIndex + vertexPerSubdiv))
            push(mesh.triangles, uint3(baseIndex + 1, baseIndex + vertexPerSubdiv + 1, baseIndex + vertexPerSubdiv))
        }
    }

    return <- mesh
}
