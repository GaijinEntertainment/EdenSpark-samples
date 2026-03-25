require engine.core
require engine.free_camera

let FIELD_HEIGHT = 40
let FIELD_WIDTH = 80
var FIELD : int[FIELD_HEIGHT][FIELD_WIDTH]
let TOTAL_ROOMS = 20

let TILE_VOID = ' '
let TILE_FLOOR = '.'
let TILE_WALL = '#'
let TILE_CORNER = '!' //A separate tile for corners is necessary for correct door checks, shown on the map as TILE_WALL
let TILE_OPENED_DOOR = '+'
let TILE_CLOSED_DOOR = 'x'
let TILE_PLAYER = '@'
let TILE_MONEY = '$'
let TILE_ENEMY = 'E'
let TILE_BOSS = 'B'
let TILE_SPIKES = '^'


var camera : NodeId
let cameraPos = float3(FIELD_WIDTH / 2, 60, -60)
let cameraEuler = float3(PI / 3f, 0f, 0f)

let sunDirection = float3(PI / 2f, -PI / 6f, PI / 6f)

var root : NodeId

class RotateComponent : Component {
    angle : float = 0f
    speed = 1f

    def override on_update() {
        angle += get_delta_time() * speed
        nodeId.localRotation = quat4(-angle, 0., PI / 2.)
    }
}


def is_perimeter(tile : int) {
    return tile == TILE_WALL || tile == TILE_CORNER || tile == TILE_OPENED_DOOR || tile == TILE_CLOSED_DOOR
}


def get_door_coords(wallStart, wallEnd : int, wallConstCoord : int, isVertical : bool, var doorCoords : array<int2>) {
    var doorCounter = 0
    var doorCoord : int2
    for (i in range(wallStart, wallEnd + 1)) {
        let curTile = isVertical ? FIELD[i][wallConstCoord] : FIELD[wallConstCoord][i]
        if (curTile == TILE_WALL) {
            doorCounter++
            if (random_range(0, doorCounter) == 0) {
                doorCoord = int2(wallConstCoord, i)
            }
        } elif (curTile == TILE_CORNER) {
            doorCounter = 0
            if (doorCoord != int2(0)) {
                push(doorCoords, isVertical ? doorCoord : int2(doorCoord.y, doorCoord.x))
            }
        }
    }

    if (doorCoord != int2(0)) {
        push(doorCoords, isVertical ? doorCoord : int2(doorCoord.y, doorCoord.x))
    }
}


def add_object(name : string, meshId : MeshId, position : float3, scale : float3 = float3(1.), rotation : quat4 = quat4(), parent : NodeId = NodeId(), tint = float4(1.)) {
    let node = create_node(NodeData(name = name, parent = parent, position = position, rotation = rotation, scale = scale))
    add_component(node, new Mesh(meshId = meshId, color = tint))
    return node
}


def destroy_root() {
    if (!!root) {
        remove_node(root)
    }
}


def room(withPlayer : bool, bossSpawnPossible : bool) {
    let width = random_range(5, 15)
    let height = random_range(3, 9)
    let left = random_range(2, FIELD_WIDTH - width - 2)
    let right = left + width
    let top = random_range(2, FIELD_HEIGHT - height - 2)
    let bottom = top + height

    //CHECKS
    for (y in range(top - 1, bottom + 2)) {
        for (x in range(left - 1, right + 2)) {
            if (FIELD[y][x] == TILE_FLOOR || FIELD[y][x] == TILE_PLAYER || FIELD[y][x] == TILE_MONEY || FIELD[y][x] == TILE_ENEMY) {
                return false
            }
        }
    }

    for (y in range(top - 2, bottom + 2)) {
        if (is_perimeter(FIELD[y][left - 2]) && is_perimeter(FIELD[y + 1][left - 2]) || is_perimeter(FIELD[y][right + 2]) && is_perimeter(FIELD[y + 1][right + 2])) {
            return false
        }
    }
    for (x in range(left - 2, right + 2)) {
        if (is_perimeter(FIELD[top - 2][x]) && is_perimeter(FIELD[top - 2][x + 1]) || is_perimeter(FIELD[bottom + 2][x]) && is_perimeter(FIELD[bottom + 2][x + 1])) {
            return false
        }
    }

    //DOORS
    var doorCoords : array<int2>
    if (!withPlayer) {
        get_door_coords(top, bottom, left - 1, true, doorCoords)
        get_door_coords(top, bottom, right + 1, true, doorCoords)
        get_door_coords(left, right, top - 1, false, doorCoords)
        get_door_coords(left, right, bottom + 1, false, doorCoords)

        //If the room is not adjacent to any other room don't make such a room
        if (empty(doorCoords)) {
            return false
        }
    }

    //DRAWING
    for (y in range(top - 1, bottom + 2)) {
        let horizontalWall = (y < top) || (y > bottom)
        for (x in range(left - 1, right + 2)) {
            let verticalWall = (x < left) || (x > right)
            let cornerTile = horizontalWall && verticalWall
            let wallTile = horizontalWall ^^ verticalWall
            FIELD[y][x] = cornerTile ? TILE_CORNER : (wallTile ? TILE_WALL : TILE_FLOOR)
        }
    }

    for (doorCoord in doorCoords) {
        FIELD[doorCoord.y][doorCoord.x] = random_range(0, 2) == 0 ? TILE_OPENED_DOOR : TILE_CLOSED_DOOR
    }

    if (withPlayer) {
        FIELD[random_range(top + 1, bottom)][random_range(left + 1, right)] = TILE_PLAYER
    } elif (bossSpawnPossible && random_range(0, 2) == 0) {//50% chance for boss room to appear
        let bossTop = random_range(top + 1, bottom - 1)
        let bossLeft = random_range(left + 1, right - 1)
        FIELD[bossTop][bossLeft] = TILE_BOSS
        FIELD[bossTop + 1][bossLeft] = TILE_BOSS
        FIELD[bossTop][bossLeft + 1] = TILE_BOSS
        FIELD[bossTop + 1][bossLeft + 1] = TILE_BOSS
    } else {
        //25% chance of treasure room
        if (random_range(0, 4) == 0) {
            for (i in range(random_range(3, 7))) {
                FIELD[random_range(top + 1, bottom)][random_range(left + 1, right)] = TILE_MONEY
            }
        } else {
            for (i in range(random_range(1, 3))) {
                FIELD[random_range(top + 1, bottom)][random_range(left + 1, right)] = TILE_ENEMY
            }
        }

        for (y in range(top + 1, bottom)) {
            for (x in range(left + 1, right)) {
                if (FIELD[y][x] == TILE_FLOOR && random_range(0, 40) == 0) {
                    FIELD[y][x] = TILE_SPIKES
                }
            }
        }
    }
    return true
}


def gen_map() {
    for (y in range(FIELD_HEIGHT)) {
        for (tile in FIELD[y]) {
            tile = TILE_VOID
        }
    }

    var roomNumber = 0
    while (roomNumber < TOTAL_ROOMS) {
        if (room(roomNumber == 0, roomNumber == TOTAL_ROOMS - 1)) {
            roomNumber++
        }
    }
}


def log_map() {
    for (y in range(FIELD_HEIGHT)) {
        let str = build_string() $(builder) {
            for (tile in FIELD[y]) {
                write(builder, tile == TILE_CORNER ? to_char(TILE_WALL) : to_char(tile))
            }
        }
        print(str)
    }
    print("{to_char(TILE_WALL)} - wall")
    print("{to_char(TILE_FLOOR)} - floor")
    print("{to_char(TILE_SPIKES)} - spikes")
    print("{to_char(TILE_OPENED_DOOR)} - opened door")
    print("{to_char(TILE_CLOSED_DOOR)} - closed door")
    print("{to_char(TILE_PLAYER)} - player")
    print("{to_char(TILE_MONEY)} - gold")
    print("{to_char(TILE_ENEMY)} - enemy")
    print("{to_char(TILE_BOSS)} - boss")
}


def init_camera() {
    camera = create_free_camera(cameraPos, quat4(cameraEuler))

    let sun = create_node(NodeData(name = "Sun", rotation = quat4(sunDirection)))
    add_component(sun, new DirectionLight())

    let renderSettings = create_render_settings()

    get_component(renderSettings) $(var shadow : ShadowSettings?) {
        shadow.powWeight = 0.9f
    }
    get_component(renderSettings) $(var tonemap : Tonemap?) {
        tonemap.active = true
    }
}


def init_dungeon() {
    let RANDOM_SEED : uint4 // = uint4(3496812185u, 2175600463u, 2174993478u, 2180081864u)
    if (RANDOM_SEED != uint4()) {
        set_random_seed(RANDOM_SEED)
    } else {
        randomize_seed()
    }
    print("seed - {get_random_seed()}")

    gen_map()
    log_map()

    root = create_node(NodeData(name = "root"))
    var isBossDrawn = false
    for (y in range(FIELD_HEIGHT)) {
        for (x in range(FIELD_WIDTH)) {
            if (FIELD[y][x] == TILE_WALL || FIELD[y][x] == TILE_CORNER) {
                var wall = add_object("wall ({x}, {y})", CUBE_MESH_ID, float3(x, 1, -y), float3(1., 2., 1.), quat4(), root)
            } elif (FIELD[y][x] == TILE_OPENED_DOOR) {
                add_object("opened door ({x}, {y})", CUBE_MESH_ID, float3(x, 1, -y), float3(1., 2., 1.), quat4(), root, float4(0, 1, 0, 1))
            } elif (FIELD[y][x] == TILE_CLOSED_DOOR) {
                add_object("closed door ({x}, {y})", CUBE_MESH_ID, float3(x, 1, -y), float3(1., 2., 1.), quat4(), root, float4(0.2, 0.2, 0.2, 1.))
            } elif (FIELD[y][x] != TILE_VOID) {
                var floor = add_object("floor ({x}, {y})", CUBE_MESH_ID, float3(x, 0, -y), float3(1., 0.05, 1.), quat4(), root)
                if (FIELD[y][x] == TILE_PLAYER) {
                    add_object("player", CAPSULE_MESH_ID, float3(x, 1, -y), float3(1), quat4(), root, float4(0, 0, 1, 1))
                } elif (FIELD[y][x] == TILE_ENEMY) {
                    add_object("enemy ({x}, {y})", CAPSULE_MESH_ID, float3(x, 1, -y), float3(1), quat4(), root, float4(1, 0, 0, 1))
                } elif (FIELD[y][x] == TILE_MONEY) {
                    var coin = add_object("coin ({x}, {y})", CYLINDER_MESH_ID, float3(float(x), 0.55, float(-y)), float3(1., 0.1, 1.), quat4(0., 0., PI / 2.), root, float4(1, 1, 0, 1))
                    add_component(coin, new RotateComponent())
                } elif (FIELD[y][x] == TILE_SPIKES) {
                    var spikes = create_node(NodeData(name = "spikes ({x}, {y})", parent = root, position = float3(x, 0., -y)))
                    add_object("spike 1 ({x}, {y})", CONE_MESH_ID, float3(-0.25, 0.25, -0.25), float3(0.375, 0.5, 0.375), quat4(), spikes, float4(0.5, 0.5, 0.5, 1))
                    add_object("spike 2 ({x}, {y})", CONE_MESH_ID, float3(0.25, 0.25, -0.25), float3(0.375, 0.5, 0.375), quat4(), spikes, float4(0.5, 0.5, 0.5, 1))
                    add_object("spike 3 ({x}, {y})", CONE_MESH_ID, float3(-0.25, 0.25, 0.25), float3(0.375, 0.5, 0.375), quat4(), spikes, float4(0.5, 0.5, 0.5, 1))
                    add_object("spike 4 ({x}, {y})", CONE_MESH_ID, float3(0.25, 0.25, 0.25), float3(0.375, 0.5, 0.375), quat4(), spikes, float4(0.5, 0.5, 0.5, 1))
                    var tween = position_tween(spikes, spikes.localPosition - float3(0., 0.4, 0.), 1., @@inOutQuintic).set_loops(-1, LoopType.Yoyo)
                } elif (FIELD[y][x] == TILE_BOSS && !isBossDrawn) {
                    add_object("boss", CAPSULE_MESH_ID, float3(float(x) + 0.5, 2., float(-y) - 0.5), float3(2), quat4(), root, float4(1, 0, 0, 1))
                    isBossDrawn = true
                }
            }
        }
    }
}


def init_world() {
    init_camera()
    init_dungeon()
    create_debug_text("Press R (or Y on gamepad) to regenerate dungeon", float2(100, -50), BOTTOM_LEFT_ANCHOR)
}


def init_input() {
    add_and_activate_action_set("basic", {
        "restartGame" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.R)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Y)]
            )
        )
    })
}


def regenerate_dungeon() {
    destroy_root()
    print("Regenerating dungeon")
    init_dungeon()
}


[export] def on_initialize() {
    init_world()
    init_input()
}


[export] def on_update() {
    if (is_action_just_pressed("restartGame")) {
        regenerate_dungeon()
    }
}