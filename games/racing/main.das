require engine.core
require engine.math_core
require trackSegment
require collision

let MAX_PLAYERS = 4

enum GameMode {
    None
    Menu
    Solo
    HumanVsHuman
    HumanVsAi
    AiVsAi
}


struct WheelPhysics {
    pos : float3 // relative to car center
    radius : float
    depth : float // radius minus distance from center to ground, depth < 0 - not touching ground
    rotationAngle : float
}


struct CarControls {
    horizontalMoveActionName : string
    verticalMoveActionName : string
    forward : float
    steer : float
}


struct CarAiState {
    level : float // 0..1
    pathPointIndex : int
    timeToReverseMove : float
}


struct CarPhysics {
    pos : float3 // world position of center of mass
    vel : float3
    rot : quat4 // rotation quaternion
    rotVel : float3 // angular velocity
    wheels : WheelPhysics[4]
    targetSpeed : float
    slippage : float
    steerAngle : float // in radians, 0 = straight ahead
    settingsIndex : int // index of car settings in CarPreset array
    tiltAngles : float3
    speed : float
    finished : bool
    finishTime : float
}


struct NodeSettings {
    pos : float3
    color : float4
    meshPath : string
}


struct CarPreset {
    name : string // preset name
    chassis : array<NodeSettings>
    wheelFrontLeft : array<NodeSettings>
    wheelFrontRight : array<NodeSettings>
    wheelBackLeft : array<NodeSettings>
    wheelBackRight : array<NodeSettings>
}


struct CarVisuals {
    mainNode : NodeId

    chassisRootNode : NodeId
    frontLeftWheelNode : NodeId
    frontRightWheelNode : NodeId
    backLeftWheelNode : NodeId
    backRightWheelNode : NodeId

    bodyNodes : array<NodeId>

    def setColor(color : float4) : void {
        for (node in bodyNodes) {
            node?.Mesh.color = color
        }
    }
}


def set_static(node : NodeId) {
    get_component(node) $(var mesh : Mesh?) {
        mesh.isStatic = true
    }
}


def load_car_visuals(preset_index : int, i : int, color : float4) {
    let car = request_prefab("assets/cars/car1.fbx")
    let mainNode = instantiate_prefab(car)

    var bodyNodes = [
        find_child_recursive(mainNode, "Plane.008"),
    ]

    // where are 2 nodes with the same name "Plane.018" in the car model
    find_children_recursive(mainNode, "Plane.018", bodyNodes)

    let chassisRootNode = create_node(NodeData(name = "chassis"))
    chassisRootNode.add_child(find_child_recursive(mainNode, "Plane.015"))
    chassisRootNode.add_child(find_child_recursive(mainNode, "Plane.017"))
    chassisRootNode.add_child(find_child_recursive(mainNode, "Plane.019"))
    chassisRootNode.add_child(find_child_recursive(mainNode, "Plane.013"))
    for (node in bodyNodes) {
        chassisRootNode.add_child(node)
    }

    mainNode.add_child(chassisRootNode)

    car_visuals[i] = new CarVisuals(
        mainNode = mainNode,
        chassisRootNode = chassisRootNode,
        frontLeftWheelNode = find_child_recursive(mainNode, "Wheel1"),
        frontRightWheelNode = find_child_recursive(mainNode, "Wheel4"),
        backLeftWheelNode = find_child_recursive(mainNode, "Wheel2"),
        backRightWheelNode = find_child_recursive(mainNode, "Wheel3"),
        bodyNodes <- bodyNodes
    )
    car_visuals[i]->setColor(color)
}



def update_car_visuals_in_world(visuals : CarVisuals, phys : CarPhysics) {

    visuals.mainNode.localPosition = phys.pos
    visuals.mainNode.localRotation = phys.rot
    visuals.chassisRootNode.localRotation = quat4(phys.tiltAngles)
    visuals.frontLeftWheelNode.localRotation = quat4(PI, HALF_PI + phys.steerAngle, phys.wheels[0].rotationAngle)
    visuals.frontRightWheelNode.localRotation = quat4(0.0, HALF_PI + phys.steerAngle, phys.wheels[1].rotationAngle)
    visuals.backLeftWheelNode.localRotation = quat4(PI, HALF_PI, phys.wheels[2].rotationAngle)
    visuals.backRightWheelNode.localRotation = quat4(0.0, HALF_PI, phys.wheels[3].rotationAngle)
}


struct PlayerCamera {
    node : NodeId
    nodeCreated : bool
    eye, at, up : float3
    fov : float
}


class UILinks : Component {
    menu : NodeId
    menuItemsContainer : NodeId

    hint : NodeId

    player1Info : NodeId
    player1ControlsInfo : NodeId
    player1SpeedInfo : NodeId

    player2Info : NodeId
    player2ControlsInfo : NodeId
    player2SpeedInfo : NodeId
}


var camera_fullscreen : PlayerCamera
var camera_left_half : PlayerCamera
var camera_right_half : PlayerCamera

var scene_root : NodeId

var tree_models <- [
    request_prefab("assets/nature/tree1.fbx"),
    request_prefab("assets/nature/tree2.fbx"),
    request_prefab("assets/nature/tree3.fbx"),
    request_prefab("assets/nature/tree4.fbx"),
    request_prefab("assets/nature/tree5.fbx"),
    request_prefab("assets/nature/tree6.fbx"),
]

var tree_wall_model = request_prefab("assets/nature/tree_wall.fbx")

var @safe_when_uninitialized track_segments_desc : TrackSegmentDescription[3][3][11]
var track_segments_res : MeshId[3][3][11]
var track_segments_created : bool[3][3][11]

let trackMaterialId = create_material(MaterialImport(diffuse = request_texture("assets/track/road.jpg")))

let GAME_MODS_NUM : int = 4
let GAME_MODES : GameMode[GAME_MODS_NUM] = fixed_array(GameMode.Solo, GameMode.HumanVsHuman, GameMode.HumanVsAi, GameMode.AiVsAi)

var ui_links : UILinks? = null
var menu_selection_nodes : NodeId[GAME_MODS_NUM]
var current_menu_idx : int = 0
var prev_menu_idx : int = 0
var top_ui_string : NodeId

var start_angle : float = 0.0
var start_pos : float3 = float3(0, 0, 0)
var finish_segment : float4 = float4(0, 0, 0, 0)
var race_time : double = 0.0lf


def bring_to_start(pos : float3) : float3 {
    let quat = quat4(0.0, start_angle, 0.0)
    return quat * pos + start_pos
}


//////////////////////////////////// must be avalivable by default //////////////////////////
var status_node : NodeId

def set_debug_status_string(str : string) {
    update_debug_text(status_node, str)
}

def create_status_string(position : float2, text : string = "") {
    status_node = create_debug_text(text, position, TOP_LEFT_ANCHOR)
}
/////////////////////////////////////////////////////////////////////////////////////////////

var ui_node_root : NodeId

def create_ui_nodes() {
    ui_node_root = instantiate_prefab(request_prefab("assets/ui/UI.prefab"))
    ui_links = ui_node_root?.UILinks

    if (ui_links == null) {
        return
    }

    ui_links.hint.isActive = false

    let menu_items <- get_children(ui_links.menuItemsContainer)
    for (i, node in range(0, length(menu_items)), menu_items) {
        get_component(node) $(var comp : UIText?) {
            comp.text := ""
        }
        menu_selection_nodes[i] = node
    }

    ui_links.player1Info.isActive = false
    ui_links.player2Info.isActive = false
}


def set_camera_active(camera : PlayerCamera, active : bool) {
    (get_component(camera.node, type<Camera>)).fov = camera.fov
    camera.node.isActive = active
}


def initialize_camera(var camera : PlayerCamera&, fov_scale : float, viewport : float4) {
    camera.nodeCreated = true
    camera.fov = deg_to_rad(71.0) * fov_scale
    camera.node = create_node()
    add_component(camera.node, new Camera(fovAxis = FovAxis.Horizontal, fov = camera.fov, zfar = 2000.0, znear = 0.1,
                                        backgroundColor = float3(0.5 + 0.25, 0.55 + 0.25, 0.63 + 0.25),
                                        viewport = viewport))
    camera.node.isActive = false
}


def update_camera(var camera : PlayerCamera&, phys : CarPhysics, dt : float) {
    var timeAfterFinish = phys.finished ? float(race_time) - phys.finishTime : 0.0
    var k = dt / (1.0 + sqr(max(timeAfterFinish - 0.3, 0.0)) * 100.0)
    if (timeAfterFinish < 0.3) {
        camera.at = phys.pos + float3(0, 1, 0)
    } else {
        camera.at = approach(camera.at, phys.pos + float3(0, 1, 0), k, 0.21)
    }
    camera.eye = approach(camera.eye, camera.at + phys.rot * float3(0.0, 1.0, -5.0 + 0.27 * phys.speed), k, 0.21)
    camera.up = float3(0, 1, 0)
    camera.node.localPosition = camera.eye
    camera.node.localRotation = make_quat_from_basis_zy(camera.at - camera.eye, camera.up)
}


var sunLight : NodeId

var players_count : int
var car_controls : CarControls[MAX_PLAYERS]
var car_phys : CarPhysics[MAX_PLAYERS]
var car_ai : CarAiState[MAX_PLAYERS]
var car_visuals : CarVisuals? [MAX_PLAYERS]

var track_root_node : NodeId
var track_center_line : array<float3>

var game_mode = GameMode.None


def reset(var visuals : CarVisuals?&) {
    if (visuals != null) {
        remove_node(visuals.mainNode)
    }
    visuals = null
}

def reset(var ai : CarAiState&) {
    ai.level = 0.0
    ai.pathPointIndex = 0
    ai.timeToReverseMove = 0.0
}

def reset(var phys : CarPhysics&) {
    phys.pos = float3()
    phys.vel = float3()
    phys.rot = quat4()
    phys.rotVel = float3()
    phys.targetSpeed = 0.0
    phys.slippage = 0.0
    phys.steerAngle = 0.0
    phys.settingsIndex = 0
    phys.tiltAngles = float3()
    phys.speed = 0.0
    phys.finished = false
    phys.finishTime = 0.0
}

def reset(var camera : PlayerCamera&) {
    camera.eye = bring_to_start(float3(0, 1, 0))
    camera.at = bring_to_start(float3(0, 1, 1))
    camera.up = float3(0, 1, 0)
}


def cleanup() {
    clear_track_collision()
    clear(track_center_line)
    remove_node(track_root_node)
    remove_node(ui_node_root)
    reset(camera_fullscreen)
    reset(camera_left_half)
    reset(camera_right_half)

    for (visuals in car_visuals) {
        reset(visuals)
    }

    for (ai in car_ai) {
        reset(ai)
    }

    for (phys in car_phys) {
        reset(phys)
    }
}


def initialize_game_mode(mode : GameMode) {
    if (game_mode != GameMode.None) {
        cleanup()
    }

    game_mode = mode

    if (mode == GameMode.Solo) {
        players_count = 1
    } elif (mode == GameMode.HumanVsHuman || mode == GameMode.AiVsAi) {
        players_count = 2
    } elif (mode == GameMode.HumanVsAi) {
        players_count = 4
    } else {
        players_count = 0
    }

    let carColors <- [float4(0.4, 0.5, 0.8, 1.0), float4(0.8, 0.4, 0.3, 1.0),
        float4(0.8, 0.7, 0.2, 1.0), float4(0.8, 0.8, 0.8, 1.0)]

    for (i in range(players_count)) {
        load_car_visuals(0, i, sqr(carColors[i]))
        car_phys[i].rot = quat4(0.0, start_angle, 0.0)
    }

    car_phys[0].pos = bring_to_start(float3(-1.5, 0.0, 7.0))
    car_phys[1].pos = bring_to_start(float3(1.5, 0.0, mode == GameMode.HumanVsAi ? 9.0 : 7.0))
    car_phys[2].pos = bring_to_start(float3(-3.0, 0.0, 14.0))
    car_phys[3].pos = bring_to_start(float3(3.0, 0.0, 16.0))

    car_ai[0].level = 0.55
    car_ai[1].level = 0.6
    car_ai[2].level = 0.8
    car_ai[3].level = 0.9

    let useSplitScreen = mode == GameMode.HumanVsHuman || mode == GameMode.AiVsAi
    set_camera_active(camera_fullscreen, !useSplitScreen)
    set_camera_active(camera_left_half, useSplitScreen)
    set_camera_active(camera_right_half, useSplitScreen)

    camera_fullscreen.node.localPosition = bring_to_start(float3(0, 1, 3))
    camera_left_half.node.localPosition = bring_to_start(float3(0, 1, 3))
    camera_right_half.node.localPosition = bring_to_start(float3(0, 1, 3))

    race_time = 0.0lf

    create_ui_nodes()
    if (mode == GameMode.Menu) {
        camera_fullscreen.node.localPosition = bring_to_start(float3(0, 1, 3))
        camera_fullscreen.node.localRotation = quat4(0.15, start_angle, 0.)

        ui_links.menu.isActive = true

        ui_links.hint.isActive = false
        ui_links.player1Info.isActive = false
        ui_links.player2Info.isActive = false
    } else {
        ui_links.menu.isActive = false
        ui_links.hint.isActive = true

        if (mode == GameMode.Solo || mode == GameMode.HumanVsAi) {
            ui_links.player1Info.isActive = true
            ui_links.player2Info.isActive = false
        } elif (mode == GameMode.HumanVsHuman) {
            ui_links.player1Info.isActive = true
            ui_links.player2Info.isActive = true
        } elif (mode == GameMode.AiVsAi) {
            ui_links.player1Info.isActive = true
            ui_links.player1ControlsInfo.isActive = false
            ui_links.player1SpeedInfo.isActive = true

            ui_links.player2Info.isActive = true
            ui_links.player2ControlsInfo.isActive = false
            ui_links.player2SpeedInfo.isActive = true
        }
    }


    let trackSeed = 114
    create_track(trackSeed)
}



def track_angle_index_to_segments(angle_index : int) {
    return 6 + 2 * abs(angle_index - 5)
}

def track_angle_index_to_rad(angle_index : int) {
    return float(angle_index - 5) * 0.22
}


def request_track_segment_res(start_width_idx, end_width_idx, angle_idx : int) {
    if (track_segments_created[start_width_idx][end_width_idx][angle_idx]) {
        return track_segments_res[start_width_idx][end_width_idx][angle_idx]
    }

    var desc : TrackSegmentDescription& = track_segments_desc[start_width_idx][end_width_idx][angle_idx]
    desc.subdivLength = 5.0
    desc.subdivCount = track_angle_index_to_segments(angle_idx)
    desc.startWidth = float(start_width_idx) * 1.5 + 2.5
    desc.endWidth = float(end_width_idx) * 1.5 + 2.5
    desc.rotation = track_angle_index_to_rad(angle_idx)
    var resourceId = generate_mesh("%file/trackSegmentGen.das", track_segment_desc_to_resource_request(desc))
    track_segments_res[start_width_idx][end_width_idx][angle_idx] = resourceId
    track_segments_created[start_width_idx][end_width_idx][angle_idx] = true
    return resourceId
}


def create_track(seed : int) {
    track_root_node = create_node()
    var p = float3(0, 0, 0)
    var angleIndex = 5
    var trackAngle = -PI * 0.5
    var trackWidthIdx0 = 2
    var trackWidthIdx1 = 2
    var leftDist = 20.0
    var rightDist = 20.0
    set_random_seed(seed)

    let totalSegments = 70
    let startTurnSegments = 2
    let endTurnSegments = 3

    for (i in range(0, totalSegments)) {

        if (i < startTurnSegments) {
            angleIndex = 0
            trackWidthIdx1 = 2
        }

        if (i >= totalSegments - endTurnSegments) {
            angleIndex = 10
            trackWidthIdx1 = 2
        }

        if (i == totalSegments - endTurnSegments - 1) {
            angleIndex = 5
        }

        if (i >= startTurnSegments && i <= startTurnSegments + 2) {
            angleIndex = 5
            trackWidthIdx1 = 2
        }

        var trackSegmentNode = create_node(NodeData(parent = track_root_node))
        var segmentResourceId = request_track_segment_res(trackWidthIdx0, trackWidthIdx1, angleIndex)
        var desc : TrackSegmentDescription& = track_segments_desc[trackWidthIdx0][trackWidthIdx1][angleIndex]
        add_component(trackSegmentNode, new Mesh(
            meshId = segmentResourceId,
            materialId = trackMaterialId,
            color = float4(0.8)
        ))

        trackSegmentNode.localRotation = quat4(0.0, trackAngle, 0.0)
        trackSegmentNode.localPosition = p
        set_static(trackSegmentNode)

        if (i == startTurnSegments) {
            start_pos = p
            start_angle = trackAngle + PI * 0.5
            // block start position
            add_segment_to_collision(float4(p.x + sin(trackAngle) * 5.0, p.z + cos(trackAngle) * 5.0,
                                            p.x - sin(trackAngle) * 5.0, p.z - cos(trackAngle) * 5.0))
        }

        if (i == totalSegments - endTurnSegments) {
            finish_segment = float4(p.x + sin(trackAngle) * 5.0, p.z + cos(trackAngle) * 5.0,
                                    p.x - sin(trackAngle) * 5.0, p.z - cos(trackAngle) * 5.0)
            var finishNode = create_node(NodeData(parent = track_root_node))
            add_component(finishNode, new Mesh(meshId = CUBE_MESH_ID))
            finishNode.localPosition = p + float3(0.0, 0.01, 0.0)
            finishNode.localRotation = quat4(0.0, trackAngle, 0.0)
            finishNode.localScale = float3(1.0, 0.02, 10.0)
            set_static(finishNode)
        }


        var decorPoints <- get_points_for_decor(desc, p, trackAngle)
        var wallPoints <- get_points_for_tree_walls(desc, p, trackAngle, leftDist, rightDist)
        var collisionSegments <- get_collision_segments(desc, p, trackAngle)
        var centerPoints <- get_center_line_points(desc, p, trackAngle)

        if (i > startTurnSegments) {
            push(track_center_line, centerPoints)
        }

        for (seg in collisionSegments) {
            add_segment_to_collision(seg)
        }

        for (decorPoint in decorPoints) {
            let decorNode = instantiate_prefab(
                random_element(tree_models),
                NodeData(
                    position = decorPoint,
                    rotation = quat4(0.0, random_range(0.0, 2.0 * PI), 0.0),
                    scale = float3(random_range(0.3, 0.4)),
                    parent = track_root_node
                )
            )
            set_static(decorNode)
        }

        for (wallPoint in wallPoints) {
            let wallNode = instantiate_prefab(
                tree_wall_model,
                NodeData(
                    position = float3(wallPoint.xyz),
                    rotation = quat4(0.0, wallPoint.w + PI * 0.5, 0.0),
                    scale = float3(0.5, random_range(0.45, 0.7), 0.5),
                    parent = track_root_node
                )
            )
            set_static(wallNode)
        }

        p = get_end_of_segment(desc, p, trackAngle)

        trackAngle += track_angle_index_to_rad(angleIndex)
        angleIndex = random_bool() ? random_range(4, 7) : random_range(0, 11)
        trackWidthIdx0 = trackWidthIdx1
        trackWidthIdx1 = random_bool() && i > 5 ? random_range(0, 3) : random_range(1, 3)
    }

    print_collision_grid_density()
}


def setup_light() {
    sunLight = create_node(NodeData(rotation = make_quat_from_basis_zy(float3(1, -2, 0), float3(0, 1, 0))))
    add_component(sunLight, new DirectionLight(color = float3(1.0, 1.0, 0.98), intensity = 3.0))
    sunLight.localRotation = make_quat_from_basis_zy(float3(0.0, -1.3, 1.0), float3(0, 1, 0))

    let renderSettings = create_render_settings()
    get_component(renderSettings) $(var shadow : ShadowSettings?) {
        shadow.powWeight = 0.9
        shadow.maxDist = 200.0
        shadow.cascadeWidth = 2048
        shadow.cascadeDepthHighPrecision = true
        shadow.numCascades = 2
    }

    get_component(renderSettings) $(var ambient : AmbientSettings?) {
        ambient.ambientStrength = 1.0
        ambient.ambientSource = AmbientSource.SkyColor
    }

    get_component(renderSettings) $(var aa : AntiAliasing?) {
        aa.active = true
        aa.mode = AntiAliasingMode.FXAA
    }

    get_component(renderSettings) $(var tonemap : Tonemap?) {
        tonemap.active = true
    }
}


def update_human_controls(var controls : CarControls&, dt : float) {
    var control = float2(0)

    control.x += get_action_axis(controls.horizontalMoveActionName)
    control.y += get_action_axis(controls.verticalMoveActionName)

    controls.steer = clamp(control.x, -1.0, 1.0)
    controls.forward = clamp(control.y, -1.0, 1.0)
}


def update_ai_controls(var controls : CarControls&, var phys : CarPhysics&, var ai : CarAiState&, dt : float) {
    while (ai.pathPointIndex < length(track_center_line) - 1 &&
            length(track_center_line[ai.pathPointIndex] - phys.pos) < lerp(15.0, 30.0, ai.level)) {
        ai.pathPointIndex++
    }

    var targetPoint = track_center_line[ai.pathPointIndex]

    var carDir = phys.rot * float3(0, 0, 1)
    var carRight = phys.rot * float3(1, 0, 0)
    var p1 = phys.pos + carDir + carRight * 0.4
    var p2 = phys.pos + carDir - carRight * 0.4
    var d1 = test_segment_to_track_collision(p1.xz, (p1 + carDir * 15.0 + carRight * 0.2).xz)
    var d2 = test_segment_to_track_collision(p2.xz, (p2 + carDir * 15.0 - carRight * 0.2).xz)
    controls.forward = lerp(0.6, 1.0, ai.level)

    var carOnTail : bool = false
    var carAtFront : bool = false
    var frontCarPos : float3
    for (otherCar in car_phys) {
        if (otherCar.pos != phys.pos) {
            if (length(otherCar.pos - (phys.pos - carDir * 1.2 * 2.0)) < 2.5) {
                carOnTail = true
            }
            if (length(otherCar.pos - (phys.pos + carDir * 1.2 * 2.0)) < 2.5) {
                carAtFront = true
                frontCarPos = otherCar.pos
            }
        }
    }

    if (ai.timeToReverseMove > 0.0 && !carOnTail) {
        ai.timeToReverseMove -= dt
        controls.forward = -controls.forward
    }

    if (controls.forward > 0.0) {
        if (carAtFront) {
            controls.forward *= 0.8
        }
        controls.forward *= cvt(min(d1, d2), 0.0, 15.0, 0.5, 1.0)
    }

    controls.steer = clamp(dot(normalize(targetPoint - phys.pos), carRight) * lerp(2.0, 5.0, ai.level), -1.0, 1.0) * sign(controls.forward)

    if (carAtFront) {
        controls.steer -= clamp(dot(normalize(frontCarPos - phys.pos), carRight) * 1.0, -0.5, 0.5) * sign(controls.forward)
    }

    if ((d1 < 2.0 || d2 < 2.0 || carAtFront) && abs(phys.speed) < 6.0 && controls.forward > 0.0) {
        ai.timeToReverseMove = 1.25
    }
}


def update_car_to_car_collision(var phys1 : CarPhysics&, var phys2 : CarPhysics&) {
    if (length(phys1.pos - phys2.pos) > 10.0) {
        return
    }

    var carDir1 = phys1.rot * float3(0, 0, 1)
    var carRight1 = phys1.rot * float3(1, 0, 0)
    var carDir2 = phys2.rot * float3(0, 0, 1)
    var carRight2 = phys2.rot * float3(1, 0, 0)
    var normal : float2
    var depth : float
    if (test_car_to_car_collision(phys1.pos.xz, carDir1.xz * 1.4, carRight1.xz * 0.6,
                                 phys2.pos.xz, carDir2.xz * 1.4, carRight2.xz * 0.6,
                                 depth, normal)) {
        var n = normalize(phys1.pos - phys2.pos)
        var collisionPoint = (phys1.pos + phys2.pos) * 0.5
        var offs = n * depth * 0.501
        var velDiff = phys1.vel - phys2.vel
        var sameVelDirection = dot(phys1.vel, phys2.vel) > 0.0

        phys1.pos += offs
        phys1.vel += n * min(depth, 0.1) * 10.0 * sqr(dot(carDir1, n))
        if (sameVelDirection && dot(carDir1, phys2.pos - phys1.pos) > 0.0) {
            phys1.vel += n * 0.02 * length(phys1.vel)
        }
        phys1.slippage = max(phys1.slippage, min(length(velDiff) * 0.1, 0.4))
        phys1.targetSpeed = lerp(phys1.targetSpeed, dot(phys1.vel, carDir1), 0.25)
        phys1.rotVel.x = cross(collisionPoint - phys1.pos, -velDiff).y * 0.2

        phys2.pos -= offs
        phys2.vel -= n * min(depth, 0.1) * 10.0 * sqr(dot(carDir1, n))
        if (sameVelDirection && dot(carDir2, phys1.pos - phys2.pos) > 0.0) {
            phys2.vel -= n * 0.02 * length(phys2.vel)
        }
        phys2.slippage = max(phys1.slippage, min(length(velDiff) * 0.1, 0.4))
        phys2.targetSpeed = lerp(phys2.targetSpeed, dot(phys2.vel, carDir2), 0.25)
        phys2.rotVel.x = cross(collisionPoint - phys2.pos, velDiff).y * 0.2
    }
}


def check_car_finished(var phys : CarPhysics&) {
    if (phys.finished) {
        return
    }
    var collisionPoint, normal : float2
    var depth : float
    var finish : float4[1]
    finish[0] = finish_segment
    var carDir = phys.rot * float3(0, 0, 1)
    var carRight = phys.rot * float3(1, 0, 0)
    if (test_car_to_segments_collision(phys.pos.xz, carDir.xz * 1.4, carRight.xz * 0.6, finish, depth, normal, collisionPoint)) {
        phys.finished = true
        phys.finishTime = float(race_time)
    }
}


def update_after_finish_controls(var controls : CarControls&, var phys : CarPhysics&, var ai : CarAiState&, dt : float) {
    if (ai.pathPointIndex == 0) {
        for (i in range(length(track_center_line))) {
            var reverseI = length(track_center_line) - 1 - i
            if (length(track_center_line[reverseI] - phys.pos) < 25.0) {
                ai.pathPointIndex = reverseI
                break
            }
        }
    }

    update_ai_controls(controls, phys, ai, dt)

    if (ai.pathPointIndex >= length(track_center_line) - 1) {
        controls.forward = 0.0
        controls.steer = 0.0
    }
}


def update_car_phys(var phys : CarPhysics&, controls : CarControls, dt : float) {
    var carDir = phys.rot * float3(0, 0, 1)
    var carUp = phys.rot * float3(0, 1, 0)
    var carRight = phys.rot * float3(1, 0, 0)

    phys.speed = dot(phys.vel, carDir)
    var prevSpeed = phys.speed

    phys.targetSpeed = move_to(phys.targetSpeed, 0.0, dt, 0.24 + abs(phys.speed) * (0.2 + 0.5 * abs(phys.steerAngle)))

    var fwd = controls.forward
    if (abs(phys.speed) < 3.0) {
        fwd = clamp(controls.forward, -0.5, 0.08)
    }
    phys.targetSpeed = move_to(phys.targetSpeed, fwd > 0.0 ? fwd * 45.0 : fwd * 15.0, dt, abs(controls.forward) * 10.0)

    var maxSteerAngle = min(2.5 / max(abs(phys.speed), 1.0), 1.0)
    phys.steerAngle = move_to(phys.steerAngle, maxSteerAngle * controls.steer, dt, maxSteerAngle * 12.0)

    // collision with borders
    if (true) {
        var collisionPoint, normal : float2
        var depth : float
        if (test_car_to_track_collision(phys.pos.xz, carDir.xz * 1.4, carRight.xz * 0.6, depth, normal, collisionPoint)) {
            let n = float3(normal.x, 0.0, normal.y)
            let relativePosX = dot(collisionPoint - phys.pos.xz, carDir.xz)
            let relativePosZ = dot(collisionPoint - phys.pos.xz, carRight.xz)
            let rotationDir = abs(dot(carDir, n)) > 0.5 && phys.speed < 10.0 ? 1.0 : -1.0 // -1.0 - arcade, 1.0 - realistic
            let applySpeedChange = relativePosX * dot(phys.vel, carDir) > 0.0
            if (applySpeedChange) {
                phys.rotVel.x += rotationDir * abs(relativePosX) * relativePosZ * abs(dot(phys.vel, n)) * 0.2
            }
            phys.rotVel.x = clamp(phys.rotVel.x, -2.0, 2.0)

            var jump = normal * (depth + 0.001)
            phys.pos += float3(jump.x, 0.0, jump.y)
            if (applySpeedChange) {
                phys.vel = lerp(project(phys.vel, n), reflect(phys.vel, n), 0.08)
                if (abs(phys.targetSpeed) > 1.0) {
                    phys.targetSpeed *= saturate(length(phys.vel) / (phys.speed + 1e-3)) * dot(normalize(phys.vel), carDir)
                }
                phys.slippage = abs(dot(carDir, n)) + 0.1
            }
        }
    }

    phys.rotVel.x = approach(phys.rotVel.x, phys.steerAngle * 0.3 * abs(phys.speed), dt, 0.14)
    carDir = normalize(carDir + carRight * clamp(phys.speed, -1.0, 1.0) * phys.rotVel.x * dt)

    // skid
    if (phys.speed > 15.0 && abs(phys.steerAngle) > phys.speed * 0.001 && controls.forward < -0.5) {
        phys.slippage = 0.35
    }

    // stop the car when sliding sideways
    if (phys.speed < 10.0 && abs(dot(carDir, normalize(phys.vel))) < 0.8) {
        phys.vel = approach(phys.vel, float3(0), dt, 0.14)
    }

    phys.vel = approach(phys.vel, carDir * phys.targetSpeed, dt, phys.slippage)
    phys.pos += phys.vel * dt
    phys.rot = make_quat_from_basis_zy(carDir, float3(0, 1, 0))

    let trackSlippage = 0.01
    phys.slippage = approach(phys.slippage, trackSlippage, dt, 0.4)

    let accelForward = clamp((phys.speed - prevSpeed) / (dt + 1e-7), -15.0, 15.0)
    let accelSide = phys.rotVel.x * min(abs(phys.speed), 20.0)
    let wishTilt = float3(-accelForward * 0.0012, 0.0, accelSide * 0.005)
    phys.tiltAngles = approach(phys.tiltAngles, wishTilt, dt, 0.12)

//    set_debug_status_string("speed = {phys.speed} m/s  ang = {phys.steerAngle}  max = {maxSteerAngle}")

    for (wheel in phys.wheels) {
        wheel.rotationAngle += phys.speed * 2.0 * PI * dt / 1.2
        wheel.rotationAngle = normalize_angle(wheel.rotationAngle)
    }
}


def setup_human_input() {
    let firstPlayerSet : ActionSet = {
        "VerticalMove1" => Action(
            axisActions = AxisAction(
                keyboardAxis = [KeyboardBtnAxisInput(negativeIdx=KeyCode.S, positiveIdx=KeyCode.W)],
                stickAxis = [GamepadAxisInput(idx=GamepadAxis.LRTrigger)]
            )
        ),
        "HorizontalMove1" => Action(
            axisActions = AxisAction(
                keyboardAxis = [KeyboardBtnAxisInput(negativeIdx=KeyCode.A, positiveIdx=KeyCode.D)],
                stickAxis = [GamepadAxisInput(idx=GamepadAxis.LThumbH)]
            )
        )
    }

    let secondPlayerSet : ActionSet = {
        "VerticalMove2" => Action(
            axisActions = AxisAction(
                keyboardAxis = [KeyboardBtnAxisInput(negativeIdx=KeyCode.K, positiveIdx=KeyCode.I), KeyboardBtnAxisInput(negativeIdx=KeyCode.Numpad5, positiveIdx=KeyCode.Numpad8)],
                stickAxis = [GamepadAxisInput(idx=GamepadAxis.LRTrigger, gamepadIdx=ControllerIndex.Device1)]
            )
        ),
        "HorizontalMove2" => Action(
            axisActions = AxisAction(
                keyboardAxis = [KeyboardBtnAxisInput(negativeIdx=KeyCode.L, positiveIdx=KeyCode.M), KeyboardBtnAxisInput(negativeIdx=KeyCode.Numpad4, positiveIdx=KeyCode.Numpad6)],
                stickAxis = [GamepadAxisInput(idx=GamepadAxis.LThumbH, gamepadIdx=ControllerIndex.Device1)]
            )
        )
    }

    add_and_activate_action_set("ui", {
        "Ok" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Return)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        ),
        "Up" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Up), KeyboardButtonInput(idx=KeyCode.Numpad8)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Up)]
            )
        ),
        "Down" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Down), KeyboardButtonInput(idx=KeyCode.Numpad5)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Down)]
            )
        ),
        "Back" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Back)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.B)]
            )
        ),
    })

    add_and_activate_action_set("first_player", firstPlayerSet)

    car_controls[0].horizontalMoveActionName = "HorizontalMove1"
    car_controls[0].verticalMoveActionName = "VerticalMove1"

    add_and_activate_action_set("second_player", secondPlayerSet)

    car_controls[1].horizontalMoveActionName = "HorizontalMove2"
    car_controls[1].verticalMoveActionName = "VerticalMove2"
}


def update_menu() {
    let up_pressed = is_action_just_pressed("Up")
    let down_pressed = is_action_just_pressed("Down")
    var fire_pressed = is_action_just_pressed("Ok")

    prev_menu_idx = current_menu_idx

    if (up_pressed) {
        current_menu_idx = (current_menu_idx - 1 + GAME_MODS_NUM) % GAME_MODS_NUM
    } elif (down_pressed) {
        current_menu_idx = (current_menu_idx + 1) % GAME_MODS_NUM
    }

    if (current_menu_idx != prev_menu_idx) {
        get_component(menu_selection_nodes[prev_menu_idx]) $(var comp : UIText?) {
            comp.text = ""
        }
    }

    get_component(menu_selection_nodes[current_menu_idx]) $(var comp : UIText?) {
        comp.text = ">"
    }

    if (fire_pressed && ui_links.menu.isActive) {
        initialize_game_mode(GAME_MODES[current_menu_idx])
    }
}


def update_ingame_ui(phys : CarPhysics, text_node : NodeId) {
    if (phys.finished) {
        var sec = int(phys.finishTime)
        var min = sec / 60
        var ms = int((phys.finishTime - float(sec)) * 1000.0)
        sec = sec % 60
        text_node?.UIText.text = "Finished! Time: {min}:{sec}.{ms}"
    } else {
        text_node?.UIText.text = "Speed: {abs(int(phys.speed * 3.6 + 0.5))} km/h"
    }
}


[export]
def on_initialize() {
    create_status_string(float2(20, -20))
    setup_human_input()
    setup_light()

    //use screen size for camera initialization
    initialize_camera(camera_fullscreen, 1.0, float4(0.0, 0.0, 1.0, 1.0))
    initialize_camera(camera_left_half, 0.65, float4(0.0, 0.0, 0.5, 1.0))
    initialize_camera(camera_right_half, 0.65, float4(0.5, 0.0, 0.5, 1.0))
    initialize_game_mode(GameMode.Menu)
}


def guaranteed_step_update(dt : float) {
    if (dt > 1.0 / 20.0) {// guard against too big dt
        guaranteed_step_update(dt * 0.5)
        guaranteed_step_update(dt * 0.5)
        return
    }

    race_time += double(dt)

    for (i in range(players_count)) {
        for (j in range(i + 1, players_count)) {
            update_car_to_car_collision(car_phys[i], car_phys[j])
        }
    }

    if (game_mode == GameMode.HumanVsHuman) {
        update_human_controls(car_controls[0], dt)
        update_human_controls(car_controls[1], dt)
    } elif (game_mode == GameMode.Solo) {
        update_human_controls(car_controls[0], dt)
    } elif (game_mode == GameMode.AiVsAi) {
        for (i in range(players_count)) {
            update_ai_controls(car_controls[i], car_phys[i], car_ai[i], dt)
        }
    } elif (game_mode == GameMode.HumanVsAi) {
        update_human_controls(car_controls[0], dt)
        for (i in range(1, players_count)) {
            update_ai_controls(car_controls[i], car_phys[i], car_ai[i], dt)
        }
    }

    for (i in range(players_count)) {
        if (car_phys[i].finished) {
            update_after_finish_controls(car_controls[i], car_phys[i], car_ai[i], dt)
        }
    }

    for (i in range(players_count)) {
        update_car_phys(car_phys[i], car_controls[i], dt)
        check_car_finished(car_phys[i])
    }

    if (game_mode == GameMode.HumanVsHuman || game_mode == GameMode.AiVsAi) {
        update_camera(camera_left_half, car_phys[0], dt)
        update_camera(camera_right_half, car_phys[1], dt)
    } elif (game_mode != GameMode.Menu) {
        update_camera(camera_fullscreen, car_phys[0], dt)
    }
}


[export]
def on_update() {
    let dt = get_delta_time()

    if (game_mode == GameMode.Menu) {
        update_menu()
        return
    } elif (is_action_just_pressed("Back")) {
        initialize_game_mode(GameMode.Menu)
    }

    guaranteed_step_update(dt)

    for (i in range(players_count)) {
        if (car_visuals[i] != null) {
            update_car_visuals_in_world(*car_visuals[i], car_phys[i])
        }
    }

    if (game_mode == GameMode.HumanVsHuman || game_mode == GameMode.AiVsAi) {
        update_ingame_ui(car_phys[0], ui_links.player1SpeedInfo)
        update_ingame_ui(car_phys[1], ui_links.player2SpeedInfo)
    } elif (game_mode != GameMode.Menu) {
        update_ingame_ui(car_phys[0], ui_links.player1SpeedInfo)
    }
}
