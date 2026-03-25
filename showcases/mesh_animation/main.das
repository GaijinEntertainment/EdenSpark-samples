require engine.core
require engine.free_camera

// require engine.runtime.memory_profiler

// sources: https://catlikecoding.com/unity/tutorials/flow/waves/

def GerstnerWave(wave : float4, p : float3, var tangent, binormal : float3&, time : float) : float3 {

    let steepness = wave.z
    let wavelength = wave.w
    let k = 2f * PI / wavelength
    let c = sqrt(9.8 / k)
    let d = normalize(wave.xy)
    let f = k * (dot(d, p.xz) - c * time)
    let a = steepness / k

    var sin_f, cos_f : float
    sincos(f, sin_f, cos_f)

    tangent += float3(
        -d.x * d.x * (steepness * sin_f),
        d.x * (steepness * cos_f),
        -d.x * d.y * (steepness * sin_f)
    )
    binormal += float3(
        -d.x * d.y * (steepness * sin_f),
        d.y * (steepness * cos_f),
        -d.y * d.y * (steepness * sin_f)
    )
    return float3(
        d.x * (a * cos_f),
        a * sin_f,
        d.y * (a * cos_f)
    )
}

def animate_vertex(var vertex, normal : float3&, wave_a, wave_b, wave_c : float4, time : float) : void {
    let gridPoint = vertex
    var tangent = float3(1, 0, 0)
    var binormal = float3(0, 0, 1)
    var p = gridPoint
    p += GerstnerWave(wave_a, gridPoint, tangent, binormal, time)
    p += GerstnerWave(wave_b, gridPoint, tangent, binormal, time)
    p += GerstnerWave(wave_c, gridPoint, tangent, binormal, time)
    normal = normalize(cross(binormal, tangent))
    vertex = p
}

def animate_mesh(mesh_src : MeshGeometry, var mesh_dst : MeshGeometry, time : float) : void {
    let wave_a = float4(1, 1, 0.25, 60)
    let wave_b = float4(1, 0.6, 0.25, 31)
    let wave_c = float4(1, 1.3, 0.25, 18)
    resize(mesh_dst.normals, length(mesh_dst.vertices))
    for (vertex_src, vertex_dst, normal_dst in mesh_src.vertices, mesh_dst.vertices, mesh_dst.normals) {
        vertex_dst = vertex_src
        animate_vertex(vertex_dst, normal_dst, wave_a, wave_b, wave_c, time)
    }
}

def create_plane_mesh(n : int, size : float) : MeshGeometry {

    var vertices : array<float3>
    var uv : array<float2>
    var triangles : array<uint3>

    reserve(vertices, n * n)
    reserve(uv, n * n)

    for (i in range(n)) {
        for (j in range(n)) {

            let u = float(i) / float(n - 1)
            let v = float(j) / float(n - 1)
            push(vertices, float3(u - 0.5f, 0f, v - 0.5f) * size)
            push(uv, float2(u, v))
        }
    }


    reserve(triangles, (n - 1) * (n - 1) * 2)
    for (i in range(n - 1)) {
        for (j in range(n - 1)) {
            let a = i * n + j
            let b = i * n + j + 1
            let c = (i + 1) * n + j
            let d = (i + 1) * n + j + 1
            push(triangles, uint3(a, b, d))
            push(triangles, uint3(a, d, c))
        }
    }

    return <- MeshGeometry(vertices <- vertices, uv <- uv, triangles <- triangles)
}

var originalMesh, animatedMesh : MeshGeometry
var meshId : MeshId
var originalCollision, animatedCollision : MeshGeometry
var collisionId : CollisionId

[export]
def on_initialize() {
    // create free camera
    create_free_camera(float3(0, 25, -190))

    // create light
    add_component(create_node(NodeData(rotation = quat4(0.2, PI, 0f), name = "sun")), new DirectionLight())

    // add default render settings
    let renderSettings = create_render_settings()


    let size = 200.f
    let planeFrequency = 100
    let collisionFrequency = 25

    originalMesh <- create_plane_mesh(planeFrequency, size)
    animatedMesh := originalMesh
    meshId = create_mesh(originalMesh)

    originalCollision <- create_plane_mesh(collisionFrequency, size)
    animatedCollision := originalCollision
    collisionId = create_mesh_collision(originalCollision)

    let plane = create_node(NodeData(name = "plane"))
    add_component(plane, new Mesh(
        meshId = meshId,
        materialId = request_material("wave.material")
    ))
    add_component(plane, new Collider(shape = mesh_shape(collisionId)))

    let ballStep = 3f
    let N = 15
    let offset = -float3(N, 0, N) * ballStep * 0.5f
    let sphereMesh = SPHERE_MESH_ID
    for (i in range(N)) {
        for (j in range(N)) {
            let pos = float3(i, 10, j) * ballStep + offset
            let sphere = create_node(NodeData(position = pos + offset, name = "sphere"))
            add_component(sphere, new Mesh(meshId = sphereMesh))
            add_component(sphere, new Collider(shape = sphere_shape()))
            add_component(sphere, new RigidBody())
        }
    }
}

[export]
def on_update() {

    animate_mesh(originalMesh, animatedMesh, get_time())
    update_mesh(meshId, animatedMesh)
    animate_mesh(originalCollision, animatedCollision, get_time())
    update_mesh_collision(collisionId, animatedCollision)
}
