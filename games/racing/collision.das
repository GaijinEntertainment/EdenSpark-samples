require daslib/math
require daslib/strings
require engine.math_core

module collision

let GRID_SIZE = 32
let GRID_SIZE_MASK = uint(GRID_SIZE - 1)
let GRID_CELL_SIZE = 8.0
let INV_GRID_CELL_SIZE = 1.0 / float(GRID_CELL_SIZE)

var collision_grid : array<float4>[GRID_SIZE][GRID_SIZE]

def clear_track_collision() {
    for (i in range(0, GRID_SIZE)) {
        for (j in range(0, GRID_SIZE)) {
            clear(collision_grid[i][j])
        }
    }
}


def print_collision_grid_density() {
    for (i in range(0, GRID_SIZE)) {
        var s : string
        for (j in range(0, GRID_SIZE)) {
            s += "{length(collision_grid[i][j])}"
            while (length(s) <= (j + 1) * 4) {
                s += " "
            }
        }
        print(s)
    }
}


def add_segment_to_collision(segment : float4) {
    let h = floori((segment) * INV_GRID_CELL_SIZE)
    let min_x = min(h.x, h.z) - 1
    let max_x = max(h.x, h.z) + 1
    let min_y = min(h.y, h.w) - 1
    let max_y = max(h.y, h.w) + 1

    for (i in range(min_x, max_x + 1)) {
        for (j in range(min_y, max_y + 1)) {
            push(collision_grid[uint(i) & GRID_SIZE_MASK][uint(j) & GRID_SIZE_MASK], segment)
        }
    }
}



def cross2d(a, b : float2) : float {
    return a.x * b.y - a.y * b.x
}


def trace_ray_segment(ray_from, ray_dir : float2, a, b : float2, var max_dist : float&) : bool {
    let segment = b - a
    let det = cross2d(segment, ray_dir)

    if (abs(det) < 1e-8) {
        return false
    }

    let inv_det = 1.0 / det
    let to_segment = ray_from - a
    let v = cross2d(to_segment, segment) * inv_det
    if (v < 0.0 || v > max_dist) {
        return false
    }

    let u = cross2d(to_segment, ray_dir) * inv_det

    if (u < 0.0 || u > 1.0) {
        return false
    }

    max_dist = v
    return true
}


def distance_from_point_to_line(point, a, b : float2) : float {
    let segment = b - a
    let to_segment = point - a
    let det = cross2d(segment, to_segment)
    return abs(det) / (length(segment) + 1e-9)
}


def test_car_to_segments_collision(center : float2, dir_forward, dir_right : float2, segments : auto, var depth : float&, var normal : float2&, var collision_point : float2&) : bool {
    let halfDiag = length(dir_forward + dir_right)
    var dirs : float2[4]
    dirs[0] = normalize(dir_forward + dir_right)
    dirs[1] = normalize(dir_forward - dir_right)
    dirs[2] = normalize(-dir_forward + dir_right)
    dirs[3] = normalize(-dir_forward - dir_right)

    var d = halfDiag
    var found = false

    for (seg in segments) {
        for (dir in dirs) {
            if (trace_ray_segment(center, dir, seg.xy, seg.zw, d)) {
                normal = normalize(seg.zw - seg.xy).yx
                normal.y = -normal.y
                if (dot(normal, center - seg.xy) < 0.0) {
                    normal = -normal
                }
                collision_point = center + dir * d
                depth = distance_from_point_to_line(center + halfDiag * dir, seg.xy, seg.zw)
                found = true
            }
        }
    }
    return found
}


def test_segment_to_track_collision(a, b : float2) : float {
    let center = (a + b) * 0.5
    let uc = uint2(floori(center * INV_GRID_CELL_SIZE)) & uint2(GRID_SIZE_MASK, GRID_SIZE_MASK)
    var d = length(b - a)
    let dir = normalize(b - a)
    for (seg in collision_grid[uc.x][uc.y]) {
        trace_ray_segment(a, dir, seg.xy, seg.zw, d)
    }
    return d
}


def test_car_to_track_collision(center : float2, dir_forward, dir_right : float2, var depth : float&, var normal : float2&, var collision_point : float2&) : bool {
    let uc = uint2(floori(center * INV_GRID_CELL_SIZE)) & uint2(GRID_SIZE_MASK, GRID_SIZE_MASK)
    return test_car_to_segments_collision(center, dir_forward, dir_right, collision_grid[uc.x][uc.y], depth, normal, collision_point)
}


def test_car_to_car_collision(center1 : float2, dir_forward1, dir_right1 : float2, center2 : float2, dir_forward2, dir_right2 : float2, var depth : float&, var normal : float2&) : bool {

    if (length(center1 - center2) > 10.0) {
        return false
    }

    var box1, box2 : float4[4]
    var tmp : float2

    box2[0] = float4(center2 + dir_forward2 - dir_right2, center2 + dir_forward2 + dir_right2)
    box2[1] = float4(center2 - dir_forward2 - dir_right2, center2 - dir_forward2 + dir_right2)
    box2[2] = float4(center2 - dir_forward2 - dir_right2, center2 + dir_forward2 - dir_right2)
    box2[3] = float4(center2 + dir_forward2 + dir_right2, center2 - dir_forward2 + dir_right2)

    if (test_car_to_segments_collision(center1, dir_forward1, dir_right1, box2, depth, normal, tmp)) {
        return true
    }

    box1[0] = float4(center1 + dir_forward1 - dir_right1, center1 + dir_forward1 + dir_right1)
    box1[1] = float4(center1 - dir_forward1 - dir_right1, center1 - dir_forward1 + dir_right1)
    box1[2] = float4(center1 - dir_forward1 - dir_right1, center1 + dir_forward1 - dir_right1)
    box1[3] = float4(center1 + dir_forward1 + dir_right1, center1 - dir_forward1 + dir_right1)

    if (test_car_to_segments_collision(center2, dir_forward2, dir_right2, box1, depth, normal, tmp)) {
        normal = -normal
        return true
    }

    return false
}
