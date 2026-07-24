require engine.core
require engine.arcball_camera
require engine.render.wireframe_render

// Click-to-move over a baked navmesh, driven by the stateful NavCorridor; C toggles the simplest
// waypoint follower for comparison. The corridor mode draws in cyan, the simple mode in orange.
var useCorridor = true

var camera : NodeId
var character : NodeId
var cursorPos : float2

var corridor = NavCorridor() // survives script hot-reload like any global; a navmesh rebake invalidates it
var moving = false
var wasdAnchored = false // WASD reuses the corridor, re-anchored at the character

var path : array<float3> // simple mode only
var pathIdx = 0

var requestedDest : float3
var hasDest = false
var pathReachesDest = false
var optimizeTimer = 0f

let MOVE_SPEED = 6.0f
let REACH_EPS = 0.4f // matches the NavMesh agentRadius

// corridor mode: cyan route, yellow destination; simple mode: orange route, amber destination;
// partial routes (the goal is unreachable) use the darker shade of the mode's palette
let PATH_LINE_COLOR = float4(0.1f, 0.9f, 1.0f, 1.0f)
let PARTIAL_PATH_COLOR = float4(0.5f, 0.4f, 1.0f, 1.0f)
let WAYPOINT_COLOR = float4(1.0f, 0.85f, 0.1f, 1.0f)
let SIMPLE_PATH_LINE_COLOR = float4(1.0f, 0.55f, 0.1f, 1.0f)
let SIMPLE_PARTIAL_PATH_COLOR = float4(0.8f, 0.3f, 0.05f, 1.0f)
let SIMPLE_WAYPOINT_COLOR = float4(1.0f, 0.75f, 0.35f, 1.0f)
let TRACE_CLEAR_COLOR = float4(0.2f, 1.0f, 0.3f, 1.0f)
let TRACE_BLOCKED_COLOR = float4(1.0f, 0.25f, 0.1f, 1.0f)
let WALL_HINT_COLOR = float4(1.0f, 0.3f, 1.0f, 1.0f)
let WAYPOINT_RADIUS = 0.25f
let CURSOR_MARKER_RADIUS = 0.2f
let WALL_HINT_RADIUS = 3.0f

[export]
def on_initialize() {
    create_render_settings()

    show_mouse_cursor(true)
    set_mouse_cursor_locked(false)

    camera = create_node(NodeData(name = "camera"))
    camera.add_component(new Camera())
    camera.add_component(new ArcballCamera(distance = 38.1f, euler = float3(0.7854f, -0.6155f, 0f), focusPosition = float3(0)))

    character = create_node(NodeData(name = "character", position = float3(-5, 0, 9)))
    let body = create_node(NodeData(name = "body", parent = character, position = float3(0, 1, 0)))
    add_component(body, new Mesh(meshId = CAPSULE_MESH_ID, color = float4(0.2f, 0.85f, 0.35f, 1.0f)))

    add_and_activate_action_set("navmesh_demo", {
        "moveTo" => Action(buttonActions = ButtonAction(mouseButtons = [MouseButtonInput(idx = MouseButton.Left)])),
        "cursor" => Action(pointerActions = PointerAction(valueType = ValueType.Accumulate, mouse = MouseInput(active = true))),
        "wasd" => Action(joystickActions = JoystickAction(keyboardDPads = [KeyboardDPadInput(leftIdx = KeyCode.A, rightIdx = KeyCode.D, upIdx = KeyCode.W, downIdx = KeyCode.S)])),
        "toggleMode" => Action(buttonActions = ButtonAction(keyboardButtons = [KeyboardButtonInput(idx = KeyCode.C)])),
    })

    create_debug_text("[LMB] walk to point / [WASD] direct move / [C] toggle corridor vs simple follower", float2(10, 10), TOP_LEFT_ANCHOR)

    // there is baked navmesh in prefab, but it is dropped when game starts because node transform is changed from what was baked in prefab
    let navmesh = request_prefab("unreachable.prefab").instantiate_prefab(NodeData(position = float3(0, -30, 0)))
    navmesh?.NavMesh.bakeAsync() @(result : BakeResult) {
        print("navmesh demo: bake result: {result}")
    }
}

[export]
def on_update() {
    cursorPos = get_action_vector2("cursor")
    if (is_action_just_pressed("moveTo")) {
        request_move_to_cursor()
    }
    if (is_action_just_pressed("toggleMode")) {
        useCorridor = !useCorridor
        let modeName = useCorridor ? "NavCorridor" : "simple waypoint follower"
        print("navmesh demo: click-to-move mode = {modeName}")
        if (hasDest) {
            path_to(requestedDest) // continue to the same destination in the new mode
        }
    }

    direct_control()
    if (useCorridor) {
        follow_corridor()
    } else {
        follow_path()
    }
    draw_cursor_marker()
    draw_route()
    draw_trace()
    draw_wall_hint()
}

def request_move_to_cursor() {
    let ray = camera?.Camera.screenToRay(cursorPos)
    trace(RayCast(ray = ray, maxDistance = 1000.0)) $(hit) {
        path_to(hit.position)
    }
}

def path_to(dest : float3) {
    requestedDest = dest
    hasDest = true
    wasdAnchored = false
    if (useCorridor) {
        // a small shift of the destination while walking patches the corridor tail instead of a full
        // findPath; the distance is 3D on purpose - a point on another storey is never "near"
        if (moving && corridor.isValid() && length(corridor.target - dest) < 5.0 && corridor.moveTarget(dest)) {
            return
        }
        let res = corridor.findPath(character.localPosition, dest)
        pathReachesDest = res == PathResult.Full
        moving = res != PathResult.NoPath
    } else {
        clear(path)
        pathIdx = 0
        let res = navmesh_find_path(NavPathQuery(from = character.localPosition, to = dest)) $(p : array<float3>) {
            path.push(p)
        }
        pathReachesDest = res == PathResult.Full
    }
}

// steer toward the first funnel corner recomputed from the CURRENT position; movePosition commits the step
def follow_corridor() {
    if (!moving) {
        return
    }
    let pos = character.localPosition
    let corners <- corridor.corners(2)
    // an empty funnel just means every corner was consumed - head straight for the target
    let corner = length(corners) > 0 ? corners[0] : corridor.target
    let toCorner = float3(corner.x - pos.x, 0f, corner.z - pos.z)
    let dist = length(toCorner)
    let step = MOVE_SPEED * get_delta_time()
    let want = dist > 1e-4 ? pos + toCorner * saturate(step / dist) : corner
    if (!corridor.movePosition(want)) {
        path_to(requestedDest) // the navmesh was rebaked under us - replan from where we are
        return
    }
    character.localPosition = corridor.position

    // a few times per second, shortcut the corridor toward the corner after the current one
    optimizeTimer += get_delta_time()
    if (optimizeTimer > 0.5) {
        optimizeTimer = 0f
        if (length(corners) > 1) {
            corridor.optimize(corners[1])
        }
    }

    if (corridor.distanceToGoal(REACH_EPS * 2.0) <= REACH_EPS) {
        moving = false
    }
}

// the simple mode: step straight toward precomputed waypoints (can drift off the line at corners)
def follow_path() {
    let pos = character.localPosition
    while (pathIdx < length(path) && length(path[pathIdx] - pos) <= REACH_EPS) {
        pathIdx++
    }
    if (pathIdx >= length(path)) {
        return
    }
    let target = path[pathIdx]
    let dist = length(target - pos)
    let step = MOVE_SPEED * get_delta_time()
    character.localPosition = lerp(pos, target, saturate(step / dist))
}

// WASD, camera-relative; the corridor anchored at the character doubles as the constrained mover
def direct_control() {
    let stick = get_action_vector2("wasd")
    if (stick == float2(0)) {
        return
    }
    moving = false
    hasDest = false
    let pos = character.localPosition
    if (!wasdAnchored || !corridor.isValid()) {
        wasdAnchored = corridor.findPath(pos, pos) != PathResult.NoPath
        if (!wasdAnchored) {
            return // the character is off-mesh
        }
    }
    let fwd = cross(camera.localRight, UP)
    let want = pos + (camera.localRight * stick.x + fwd * stick.y) * MOVE_SPEED * get_delta_time()
    if (corridor.movePosition(want)) {
        character.localPosition = corridor.position
    } else {
        wasdAnchored = false // rebaked under us; re-anchor next frame
    }
}

def draw_route() {
    let lineColor = (useCorridor ? (pathReachesDest ? PATH_LINE_COLOR : PARTIAL_PATH_COLOR)
                  : (pathReachesDest ? SIMPLE_PATH_LINE_COLOR : SIMPLE_PARTIAL_PATH_COLOR))
    if (hasDest) {
        let destColor = pathReachesDest ? (useCorridor ? WAYPOINT_COLOR : SIMPLE_WAYPOINT_COLOR) : lineColor
        draw_sphere(requestedDest, 0.4f, destColor, 1, 16, WireframeDrawFlags.ZTest)
    }
    if (useCorridor) {
        if (!moving) {
            return
        }
        // the corners are recomputed each frame, so the drawn route always starts at the character
        let corners <- corridor.corners(8)
        var prev = character.localPosition
        for (p in corners) {
            draw_sphere(p, WAYPOINT_RADIUS, lineColor, 1, 16, WireframeDrawFlags.ZTest)
            draw_line(prev, p, lineColor, 1, WireframeDrawFlags.ZTest)
            prev = p
        }
    } else {
        let n = length(path)
        if (n == 0) {
            return
        }
        for (i in range(n)) {
            draw_sphere(path[i], WAYPOINT_RADIUS, lineColor, 1, 16, WireframeDrawFlags.ZTest)
            if (i + 1 < n) {
                draw_line(path[i], path[i + 1], lineColor, 1, WireframeDrawFlags.ZTest)
            }
        }
        if (pathIdx < n) {
            draw_line(character.localPosition, path[pathIdx], lineColor, 1, WireframeDrawFlags.ZTest)
        }
    }
}

def draw_cursor_marker() {
    let ray = camera?.Camera.screenToRay(cursorPos)
    trace(RayCast(ray = ray, maxDistance = 1000.0)) $(hit) {
        let onMesh = navmesh_project_point(NavPointQuery(pos = hit.position)) $(projected) {
            draw_sphere(projected, CURSOR_MARKER_RADIUS, TRACE_CLEAR_COLOR, 1, 12, WireframeDrawFlags.ZTest)
        }
        if (!onMesh) {
            draw_sphere(hit.position, CURSOR_MARKER_RADIUS, TRACE_BLOCKED_COLOR, 1, 12, WireframeDrawFlags.ZTest)
        }
    }
}

def draw_wall_hint() {
    navmesh_distance_to_wall(NavWallQuery(pos = character.localPosition, maxRadius = WALL_HINT_RADIUS)) $(hit) {
        draw_line(character.localPosition, hit.position, WALL_HINT_COLOR, 1, WireframeDrawFlags.ZTest)
        draw_sphere(hit.position, 0.1f, WALL_HINT_COLOR, 1, 8, WireframeDrawFlags.ZTest)
    }
}

def draw_trace() {
    if (!hasDest) {
        return
    }
    let res = navmesh_trace(NavRayCast(from = character.localPosition, to = requestedDest)) $(hit) {
        draw_line(character.localPosition, hit.position, TRACE_BLOCKED_COLOR, 1, WireframeDrawFlags.ZTest)
        draw_sphere(hit.position, 0.15f, TRACE_BLOCKED_COLOR, 1, 12, WireframeDrawFlags.ZTest)
    }
    if (res == NavMeshTraceResult.Reached) {
        draw_line(character.localPosition, requestedDest, TRACE_CLEAR_COLOR, 1, WireframeDrawFlags.ZTest)
    }
}
