require engine.core
require engine.helper_functions

let SCENE_TIME = 6.0
let TRANSITION_TIME = 1.0

let GRID_SIZE = 22
var cubes : array<NodeId>
var pos : array<float3>[2]
var scales : array<float3>[2]
var colors : array<float4>[2]
var transition : array<float>

var grid : int2
var fireflies : int2
var trees : int2[3]
var ground : int2

var treesPos <- [float3(-5, 0, 0), float3(4, 0, 4), float3(4, 0, -3)]

var firstT = 0.0
var firefliesPos : array<float3>

def allocate_cubes(count : int) : int2 {// count, length
    let start = length(cubes)
    resize(cubes, start + count)
    resize(transition, start + count)
    for (i in range(count)) {
        cubes[i + start] = create_cube(float3(0.0, 0.0, 0.0), float3(0.0))
    }
    for (j in range(2)) {
        resize(pos[j], start + count)
        resize(scales[j], start + count)
        resize(colors[j], start + count)
    }
    return int2(start, count)
}


def update_cubes() {
    for (i in range(length(cubes))) {
        let t = smoothstep(transition[i])
        let pos = lerp(pos[0][i], pos[1][i], t)
        let scale = lerp(scales[0][i], scales[1][i], t)
        let color = lerp(colors[0][i], colors[1][i], t)
        set_position(cubes[i], pos)
        set_scale(cubes[i], scale)
        cubes[i]?.Mesh.color = color
    }
}


def update_scene_0(to : int) {
    colors[to][ground.x] = float4(0.9, 0.9, 0.9, 1.0)
    let t = get_time()
    let half_size = float(GRID_SIZE) * 0.5
    var i = grid.x
    for (ix in range(GRID_SIZE)) {
        for (iz in range(GRID_SIZE)) {
            let x = float(ix) - half_size
            let z = float(iz) - half_size
            scales[to][i] = float3(1.0)
            colors[to][i] = float4(1.0)
            pos[to][i] = float3(x, 70.0, z)
            i++
        }
    }
}


def update_scene_1(to : int) {
    colors[to][ground.x] = float4(0.15, 0.15, 0.15, 1.0)
    let t = get_time()
    let half_size = float(GRID_SIZE) * 0.5
    var i = grid.x
    for (ix in range(GRID_SIZE)) {
        for (iz in range(GRID_SIZE)) {
            let x = float(ix) - half_size
            let z = float(iz) - half_size
            let y = (sin(length(float2(x, z)) * 1.2 + t * 3.0) + 1.0) * 0.5 + 0.001
            scales[to][i] = float3(y, 1.4, 0.1)
            colors[to][i] = float4(1.0 - x * 0.04, 1.0, 1.0 + z * 0.04, 1.0)
            pos[to][i] = float3(x, 0.0, z)
            i++
        }
    }
}


def update_scene_2(to : int) {
    colors[to][ground.x] = float4(0.1, 0.0, 0.0, 1.0)
    let t = get_time()
    let half_size = float(GRID_SIZE) * 0.5
    var i = grid.x
    for (ix in range(GRID_SIZE)) {
        for (iz in range(GRID_SIZE)) {
            let x = float(ix) - half_size
            let z = float(iz) - half_size
            let y = (sin(length(float2(x, z)) * 0.6 + t * 1.0) + 1.0) * 0.5 + 0.001
            pos[to][i] = float3(x, y, z)
            scales[to][i] = float3(y, y * 2.0, y)
            colors[to][i] = float4(1.0 - y * 0.2, 1.0 - y * 0.5, 1.0 - y, 1.0)
            i++
        }
    }
}


def update_scene_3(to : int) {
    colors[to][ground.x] = float4(0.0, 0.15, 0.2, 1.0)
    let t = get_time()
    let half_size = float(GRID_SIZE) * 0.5
    var i = grid.x
    for (ix in range(GRID_SIZE)) {
        for (iz in range(GRID_SIZE)) {
            let x = float(ix) - half_size
            let z = float(iz) - half_size
            let y = (sin(length_sq(float2(x, z)) * 0.08 - t * 4.0) + 1.0) * 0.5 + 0.001
            pos[to][i] = float3(x, y, z)
            scales[to][i] = float3(0.3, y * 2.0, 0.3)
            colors[to][i] = float4(y + 0.2, y + 0.3, y + 0.4, 1.0)
            i++
        }
    }

    for (f in range(fireflies.x, fireflies.x + fireflies.y)) {
        let p = firefliesPos[f - fireflies.x]
        pos[to][f] = float3(p.x, -1.0, p.z)
        scales[to][f] = float3(0.1, 0.1, 0.1)
        colors[to][f] = float4(2.0, 2.0, 2.0, 1.0)
    }

    for (r in range(length(trees))) {
        for (w in range(trees[r].x, trees[r].x + trees[r].y)) {
            let p = treesPos[r]
            pos[to][w] = float3(p.x, -1.0, p.z)
            scales[to][w] = float3(1.0, 1.0, 1.0)
            colors[to][w] = float4(0.2, 0.4, 0.2, 1.0)
        }
    }
}


def update_scene_4(to : int) {
    colors[to][ground.x] = float4(0.08, 0.1, 0.15, 1.0)
    let t = get_time()
    let half_size = float(GRID_SIZE) * 0.5
    var i = grid.x
    for (ix in range(GRID_SIZE)) {
        for (iz in range(GRID_SIZE)) {
            let x = float(ix) - half_size
            let z = float(iz) - half_size
            let y = ((sin(x * 0.42) + sin(x * 0.82 + z * 0.3) * 0.5 +
                      sin(z * 0.38 + 23.0) + sin(z * 1.5 + 52.0 + x * 4.0) * 0.5) * 0.2 + 2.0 - length(float2(x, z)) * 0.2)

            pos[to][i] = float3(x, y, z)
            scales[to][i] = float3(1.0, y, 1.0)
            colors[to][i] = float4(y + 0.2, y + 0.4, y - 0.2, 2.0) * 0.5
            i++
        }
    }

    for (f in range(fireflies.x, fireflies.x + fireflies.y)) {
        let p = firefliesPos[f - fireflies.x] + (sin(float3(t + float(f)) * float3(1.0, 1.3, 1.7)) + sin(float3(t + float(f)) * float3(0.4, 0.5, 0.36)) * 0.5) * 0.3
        pos[to][f] = p + float3(0.0, 2.0, 0.0)
        scales[to][f] = float3(0.1, 0.1, 0.1)
        colors[to][f] = float4(2.0, 2.0, 2.0, 1.0)
    }

    set_random_seed(1234)

    for (r in range(length(trees))) {
        i = 0
        for (w in range(trees[r].x, trees[r].x + trees[r].y)) {
            let p = treesPos[r]
            if (i == 0) {
                pos[to][w] = float3(p.x, 2.0, p.z)
                scales[to][w] = float3(0.3, 4.0, 0.3)
                colors[to][w] = float4(0.25, 0.2, 0.05, 1.0)
            } else {
                let dir = random_unit_vector() * 0.6
                pos[to][w] = p + float3(0, 4, 0) + dir
                scales[to][w] = random_range(float3(0.5, 1.0, 0.5), float3(1.1, 1.9, 1.1))
                colors[to][w] = float4(0.1, 0.4 + random_range(0.0, 0.2), 0.1, 1.0)
            }
            i++
        }
    }
}


def update_scene_5(to : int) {
    colors[to][ground.x] = float4(0.13, 0.2, 0.1, 1.0)
    set_random_seed(943)
    let t = get_time()
    let half_size = float(GRID_SIZE) * 0.5
    var i = grid.x
    var cloudPos = random_point_inside_unit_circle() * 9.0
    for (ix in range(GRID_SIZE)) {
        if ((ix & 1) == 0) {
            cloudPos = random_point_inside_unit_circle() * 9.0
        }
        for (iz in range(GRID_SIZE)) {
            let offs = random_point_inside_unit_circle()
            let dist = sqr(1.0 - length(offs))
            scales[to][i] = random_range(float3(0.8, 0.8, 0.8), float3(1.0, 1.0, 1.0)) * random_range(1.2, 1.6) * float3(1.0, 1.5 * dist + 0.03, 1.0)
            pos[to][i] = float3(cloudPos.x + 1.5 * offs.x, 1.2 + scales[to][i].y * 0.5, cloudPos.y + 1.5 * offs.y) * 1.5
            colors[to][i] = float4(0.9, 0.9, 0.9, 1.0)
            //scales[to][i] *= float3(1.0 + 0.1 * sin(t + float(i)), 1.0, 1.0 + 0.1 * cos(t * 0.7 + float(i)))
            i++
        }
    }

    for (f in range(fireflies.x, fireflies.x + fireflies.y)) {
        let p = firefliesPos[f - fireflies.x]
        pos[to][f] = float3(p.x, -1.0, p.z)
        scales[to][f] = float3(0.1, 0.1, 0.1)
        colors[to][f] = float4(2.0, 2.0, 2.0, 1.0)
    }

    for (r in range(length(trees))) {
        for (w in range(trees[r].x, trees[r].x + trees[r].y)) {
            let p = treesPos[r]
            pos[to][w] = float3(p.x, -1.0, p.z)
            scales[to][w] = float3(1.0, 1.0, 1.0)
            colors[to][w] = float4(0.2, 0.4, 0.2, 1.0)
        }
    }
}


[export]
def on_initialize() {
    ground = allocate_cubes(1)
    for (i in range(2)) {
        pos[i][ground.x] = float3(0.0, -1.0, 0.0)
        scales[i][ground.x] = float3(100.0, 2.0, 100.0)
        colors[i][ground.x] = float4(0.15, 0.15, 0.15, 1.0)
    }

    grid = allocate_cubes(GRID_SIZE * GRID_SIZE)
    for (i in range(length(trees))) {
        trees[i] = allocate_cubes(10)
    }

    fireflies = allocate_cubes(10)
    resize(firefliesPos, 10)

    for (p in firefliesPos) {
        p = float3(random_range(-10.0, 10.0), random_range(2.0, 3.0), random_range(-10.0, 10.0))
    }

    set_light_color(float3(1.0, 0.95, 0.9) * 1.2)
    set_light_direction(float3(-0.2, -1.0, 0.7))

    set_3d_camera_fov_degrees(40.0)

    let renderSettings = create_render_settings()
    get_component(renderSettings) $(var aa : AntiAliasing?) {
        aa.active = true
        aa.mode = AntiAliasingMode.MSAA
    }
}


[export]
def on_update() {
    if (firstT == 0.0) {
        firstT = get_time()
    }
    let t = get_time() - firstT
    var scene = int(t / SCENE_TIME)
    let transitionT = t % SCENE_TIME
    for (i in range(length(transition))) {
        transition[i] = saturate(transitionT / TRANSITION_TIME - float(i) / float(length(transition)))
    }

    var s = sin(sin(t * 0.1) * 0.3 + 0.5)
    var c = cos(sin(t * 0.1) * 0.3 + 0.5)
    set_3d_camera_look(float3(16.0 * s, 13.0, 16.0 * c) * 1.35, float3(0.0, -3.0, 0.0), float3(0.0, 1.0, 0.0))

//    update_scene_5(1)
//    update_scene_5(0)

    scene %= 6

    if (scene == 0) {
        update_scene_0(0)
        update_scene_1(1)
    } elif (scene == 1) {
        update_scene_1(0)
        update_scene_2(1)
    } elif (scene == 2) {
        update_scene_2(0)
        update_scene_3(1)
    } elif (scene == 3) {
        update_scene_3(0)
        update_scene_4(1)
    } elif (scene == 4) {
        update_scene_4(0)
        update_scene_5(1)
    } elif (scene == 5) {
        update_scene_5(0)
        update_scene_0(1)
    }

    update_cubes()
}
