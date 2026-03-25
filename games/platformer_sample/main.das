require engine.core
require quad_gen

let ROOM_SIZE_X = 32
let ROOM_SIZE_Y = 18

let SPEED = 8.0
let JUMP_SPEED = 14.0
let GROUND_ACCELERATION = 80.0
let GROUND_DECELERATION = 40.0
let AIR_ACCELERATION = 8.0
let AIR_DECELERATION = 1.0
let GRAVITY_POS = 80.0
let GRAVITY_NEG = 100.0
let AIR_TIME_GRAVITY = 40.0
let AIR_TIME_SPEED_THRESHOLD = 2.0
let MAX_FALL_SPEED = 35.0
let MAX_JUMP_SPEED = 30.0
let MAX_SPEED = 20.0
let COYOTE_TIME = 0.1
let JUMP_BUFFER_TIME = 0.2
let LONG_JUMP_TIME = 0.2
let DASH_BUFFER_TIME = 0.15
let DASH_TIME = 0.2


enum GameState {
    None
    Ingame
    Status
}

enum TileType {
    Empty
    Wall
    Platform
    Lava
    LavaHotAir
    SpikeUp
    SpikeDown
    SpikeLeft
    SpikeRight
    Grass1
    Grass2
    Bubble
    HeroLeft
    HeroRight
    Teleport
    Particle
}

let emptyMaterial = request_texture("assets/sprites/empty.png")

let tileMaterials <- {
    TileType.Empty => emptyMaterial,
    TileType.Wall => request_texture("assets/sprites/wall.png"),
    TileType.Platform => request_texture("assets/sprites/platform.png"),
    TileType.Lava => request_texture("assets/sprites/lava.png"),
    TileType.LavaHotAir => request_texture("assets/sprites/lava_hot_air.png"),
    TileType.SpikeUp => request_texture("assets/sprites/pike_up.png"),
    TileType.SpikeDown => request_texture("assets/sprites/pike_down.png"),
    TileType.SpikeLeft => request_texture("assets/sprites/pike_left.png"),
    TileType.SpikeRight => request_texture("assets/sprites/pike_right.png"),
    TileType.Grass1 => request_texture("assets/sprites/grass1.png"),
    TileType.Grass2 => request_texture("assets/sprites/grass2.png"),
    TileType.Bubble => request_texture("assets/sprites/bubble.png"),
    TileType.HeroLeft => request_texture("assets/sprites/hero_left.png"),
    TileType.HeroRight => request_texture("assets/sprites/hero_right.png"),
    TileType.Teleport => request_texture("assets/sprites/teleport.png"),
    TileType.Particle => request_texture("assets/sprites/particle.png"),
}

let tileRenderOrder <- {
    TileType.Grass1 => -2,
    TileType.Grass2 => -2,
    TileType.Bubble => 2,
    TileType.HeroLeft => 1,
    TileType.HeroRight => 1,
    TileType.Teleport => 2,
    TileType.Particle => 3,
}


let charToTileType <- {
    ' ' => TileType.Empty,
    '#' => TileType.Wall,
    '=' => TileType.Platform,
    '~' => TileType.Lava,
    '_' => TileType.LavaHotAir,
    '^' => TileType.SpikeUp,
    'v' => TileType.SpikeDown,
    '<' => TileType.SpikeLeft,
    '>' => TileType.SpikeRight,
    ',' => TileType.Grass1,
    '.' => TileType.Grass2,
    'o' => TileType.Bubble,
}


def create_textured_rect(tileType : TileType, position, size : float2, pivot : float2 = float2(0.0), color : float4 = float4(1.0)) : NodeId {

    let node = create_node(NodeData(position = float3(position + size * 0.5 - float2(0.5), 0.0), scale = float3(size, 1.0)))
    add_component(node, new SpriteRenderer(
        textureId = tileMaterials?[tileType] ?? emptyMaterial,
        color = color,
        uvRect = float4(0f, 0f, size.x, size.y),
        useTextureSizeForScaling = false,
        renderOrder = tileRenderOrder?[tileType] ?? 0))

    return node
}


let rooms <- [
    "#     ##########################" +
    "#                              1" +
    "#     o           o       ,.   1" +
    "# o     __________        ##.  1" +
    "#,.,   #~~~~~~~~~~#        ## ##" +
    "#####  ############           ##" +
    "#                             ##" +
    "#   @                       .###" +
    "#           o              #####" +
    "#                   #__________#" +
    "#,.,,.,. o, .,      #~~~~~~~~~~#" +
    "##############     #############" +
    "#                             <#" +
    "#>       o    ++  +           <#" +
    "#>           ######## +        #" +
    "#           ### o o ###     .  #" +
    "#   o o  ,..,.   ,.      .,##,.#" +
    "################################",

    "##############       ###########" +
    "0            #                 #" +
    "0  o         #                 #" +
    "0..,         #                 #" +
    "#####        #.,o.,.o,,.       #" +
    "#     .o     ############      #" +
    "#    ###                       #" +
    "#        , o                  ##" +
    "#        ###   o               #" +
    "#             . ,              #" +
    "#             ###    o         #" +
    "#                   ,          2" +
    "#                  ###    o    2" +
    "#                        .,. , 2" +
    "#                       ########" +
    "#______________________________#" +
    "#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#" +
    "#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#",

    "################################" +
    "#               vvv            #" +
    "#        . o        o .,. ,    #" +
    "#  o     #####       ######    #" +
    "# ,          # . # ,.#    #   o#" +
    "####,.       #########  o      #" +
    "#  ### .                  ,    #" +
    "#    ###                 .#o   #" +
    "#      ###               ##    #" +
    "#             ..          #   .#" +
    "#            ###     o        ##" +
    "1          ###vv    ,          3" +
    "1        ###vv     ###    o    3" +
    "1      ###vv             .,. , 3" +
    "########vv              ########" +
    "#                              #" +
    "#.,..o,.,. , #       # ., ,,. .#" +
    "##############1111111###########",

    "################################" +
    "#                              #" +
    "#    o,.     ,. o.,. o., o     #" +
    "#    ###   ################    #" +
    "#                o             #" +
    "#      ..,                     #" +
    "#    ######       ______  o    #" +
    "#         #     ##~~~~~~##     #" +
    "###       #      ########      #" +
    "# #       #                 o  #" +
    "# ####    #                   ##" +
    "2         #o.                  #" +
    "2        ####                  #" +
    "2         #       ,..,         #" +
    "###########  ############      #" +
    "#            #>   o            #" +
    "#     .,. ., #>, .,., .,,o..., #" +
    "#00000##########################",
]


let {
    sound_coin = request_sound("assets/sounds/coin.wav")
    sound_complete = request_sound("assets/sounds/complete.wav")
    sound_dash = request_sound("assets/sounds/dash.wav")
    sound_death = request_sound("assets/sounds/death.wav")
    sound_jump = request_sound("assets/sounds/jump.wav")
    sound_spawn = request_sound("assets/sounds/spawn.wav")
    sound_touchdown = request_sound("assets/sounds/touchdown.wav")
}


struct Block {
    active : bool
    obstacle : bool
    tileType : TileType
    position : float2
    size : float2
    velocity : float2
    userData : int
    node : NodeId
}


struct Controls {
    left : bool
    right : bool
    jump : bool
    leftDown : bool
    rightDown : bool
    jumpDown : bool
    horizontal : float // -1 .. 1
    doubleLeftTime : float
    doubleRightTime : float
}


struct Player {
    active : bool
    position : float2
    size : float2
    velocity : float2
    lastMoveDirectionSign : float
    dashTime : float
    dashDirection : float
    grounded : bool
    groundedTime : float
    longJumpTime : float
    jumpBufferTime : float
    controls : Controls
    node : NodeId
}

struct Particle {
    active : bool
    position : float2
    velocity : float2
    progress : float
    lifeTime : float
    size : float2
    node : NodeId
}


var currentRoomIndex : int
var blocks : array<Block>
var player : Player
var particles : array<Particle>
var collectedIntems : table<int3> // x, y, room
var coins : int
var totalCoins : int
var respawnPosition : float2
var timeToRespawn : float
var deaths : int
var totalGameTime : double


var gameState : GameState = GameState.None
var nextGameState : GameState = GameState.None
var timeInCurrentGameState : float = 0.0
var timeToChangeGameState : float = 0.0


//////////////////////////////////////////////////////////////////////////
var debugTextNode : NodeId

def set_debug_text(text : string, centered = false) {
    if (centered) {
        update_debug_text(debugTextNode, text, float2(), MIDDLE_CENTER_ANCHOR)
    } else {
        update_debug_text(debugTextNode, text, float2(20), TOP_LEFT_ANCHOR)
    }
}

def init_debug_text(position : float2) {
    debugTextNode = create_debug_text(position)
}
//////////////////////////////////////////////////////////////////////////


def on_game_state_changed(prev_state, new_state : GameState) {
    print("Game state changed: {prev_state} -> {new_state}")
    if (prev_state == GameState.Ingame) {
        clear_blocks()
        clear_particles()
        if (player.active) {
            player.active = false
            remove_node(player.node)
        }
    }

    if (new_state == GameState.Ingame) {
        reset_game()
    }
}


def update_game_state(dt : float) {
    timeInCurrentGameState += dt
    if (timeToChangeGameState > 0.0) {
        timeToChangeGameState -= dt
        if (timeToChangeGameState <= 0.0 && gameState != nextGameState) {
            var prevGameState = gameState
            gameState = nextGameState
            timeInCurrentGameState = 0.0
            on_game_state_changed(prevGameState, gameState)
        }
    }
}

def set_next_game_state(new_state : GameState, time_to_change : float = 1e-30) {
    print("Set next game state: {gameState} -> {new_state}")
    nextGameState = new_state
    timeToChangeGameState = time_to_change
}


def clear_particles() {
    for (p in particles) {
        if (p.active) {
            remove_node(p.node)
        }
    }
    clear(particles)
}


def deactivate_particle(index : int) {
    particles[index].active = false
    remove_node(particles[index].node)
}


def create_particle(position, velocity : float2, lifeTime : float, size : float2, color : float4 = float4(1.0)) {
    var index = -1
    for (p, i in particles, count()) {
        if (!p.active) {
            index = i
            break
        }
    }

    if (index == -1) {
        if (length(particles) > 1000) {
            return
        }
        emplace(particles, Particle())
        index = length(particles) - 1
    }

    assume p = particles[index]
    p.active = true
    p.progress = 0.0
    p.position = position
    p.velocity = velocity
    p.lifeTime = lifeTime
    p.size = size
    p.node = create_textured_rect(TileType.Particle, p.position, float2(1), float2(0.5), color)
}


def create_particle_explosion(position : float2, radius : float, time : float, color1, color2 : float4) {
    let count = 20
    for (i in 0 .. count) {
        var angle = random_range(0.0, 2.0 * PI)
        var speed = random_range(0.2, 6.0)
        var size = float2(random_range(0.2, 0.6))
        var velocity = float2(cos(angle), sin(angle)) * speed
        create_particle(position + velocity * radius / 5.0, velocity, random_range(0.5, 1.0) * time, size,
            lerp(color1, color2, random_range(0.0, 1.0)))
    }
}


def create_particle_trail(prev_pos, cur_pos : float2) {
    let len = length(cur_pos - prev_pos)
    let particlesPerOneMeter = 5.0

    let wholeCount = int(len * particlesPerOneMeter)
    let lastParticleProbablity = len * particlesPerOneMeter - float(wholeCount)

    for (i in 0 .. wholeCount) {
        var progress = float(i) / float(wholeCount)
        var position = lerp(prev_pos, cur_pos, progress)
        create_particle(position + random_range(float2(-0.3), float2(0.3)), float2(0), 0.3, float2(0.4), float4(1.0))
    }

    if (lastParticleProbablity > random_range(0.0, 1.0)) {
        create_particle(cur_pos + random_range(float2(-0.3), float2(0.3)), float2(0), 0.3, float2(0.4), float4(1.0))
    }
}


def update_particles(dt : float) {
    for (p, i in particles, count()) {
        if (!p.active) {
            continue
        }

        let vvv = p.progress
        let delta = dt / (p.lifeTime + 0.001)
        p.progress += delta
        p.position += p.velocity * dt

        if (p.progress >= 1.0) {
            deactivate_particle(i)
        } else {
            var scale = float3(p.size * lerp(1.0, 0.05, p.progress), 1.0)
            p.node.localPosition = float3(p.position, 1.0)
            p.node.localScale = scale
        }
    }
}


def clear_blocks() {
    for (b in blocks) {
        if (b.active) {
            remove_node(b.node)
        }
    }
    clear(blocks)
}


def deactivate_block(index : int) {
    blocks[index].active = false
    remove_node(blocks[index].node)
}


def create_player(position : float2) {
    player.active = true
    player.position = position
    player.velocity = float2(0)
    player.lastMoveDirectionSign = 1.0
    player.node = create_textured_rect(TileType.HeroRight, player.position, float2(1), float2(1) / 2.0)
    player.size = float2(0.99)
    player.grounded = false
    player.groundedTime = 0.0
    player.jumpBufferTime = 0.0
    player.longJumpTime = 0.0
    player.controls.doubleLeftTime = 0.0
    player.controls.doubleRightTime = 0.0
    player.dashTime = 0.0
}


def kill_player() {
    play_sound(sound_death)
    player.active = false
    remove_node(player.node)
    create_particle_explosion(player.position + float2(0.5), 0.5, 0.5, float4(0.8, 0.7, 0.6, 1.0), float4(1.0, 0.8, 0.7, 1.0))
}


def load_room(index : int) {
    print("Load room {index}")
    clear_blocks()
    clear_particles()
    currentRoomIndex = index
    var arr : int[ROOM_SIZE_X + 2][ROOM_SIZE_Y + 2]
    var pos = 0
    for (y in 0 .. ROOM_SIZE_Y) {
        for (x in 0 .. ROOM_SIZE_X) {
            arr[x + 1][(ROOM_SIZE_Y - 1 - y) + 1] = int(character_at(rooms[index], pos))
            pos++
        }
    }

    for (y in 1 .. ROOM_SIZE_Y + 1) {
        for (x in 1 .. ROOM_SIZE_X + 1) {
            // Create a block
            var size = int2(1)
            var position = int2(x, y)
            var v = arr[x][y]

            if (v == 0 || v == ' ') {
                continue
            }

            if (key_exists(collectedIntems, int3(x, y, index))) {
                continue
            }

            var tileType = charToTileType?[v] ?? TileType.Empty

            if (tileType == TileType.Wall || tileType == TileType.Platform || tileType == TileType.Lava || tileType == TileType.LavaHotAir) {
                // find block size
                while (arr[x + size.x][y] == v) {
                    size.x++
                }

                while (arr[x][y + size.y] == v) {
                    var sameRaw = true
                    for (i in 0 .. size.x) {
                        if (arr[x + i][y + size.y] != v) {
                            sameRaw = false
                            break
                        }
                    }
                    if (sameRaw) {
                        size.y++
                    } else {
                        break
                    }
                }

                // remove block area
                for (i in 0 .. size.x) {
                    for (j in 0 .. size.y) {
                        arr[x + i][y + j] = 0
                    }
                }
            } else {
                // remove single block
                arr[x][y] = 0
            }

            if (tileType != TileType.Empty) {
                var b <- Block()
                b.active = true
                b.tileType = tileType
                b.position = float2(position)
                b.size = float2(size)
                b.obstacle = b.tileType == TileType.Wall || b.tileType == TileType.Platform
                b.node = create_textured_rect(b.tileType, b.position, b.size)
                emplace(blocks, b)
            } else {
                if (v == '@' && !player.active) {
                    create_player(float2(position) + float2(0.5))
                    respawnPosition = player.position
                }

                if (v >= '0' && v <= '9') {
                    var b <- Block()
                    b.active = true
                    b.tileType = TileType.Teleport
                    b.userData = v - '0'
                    b.position = float2(position)
                    b.size = float2(size)
                    b.obstacle = false
                    b.node = create_textured_rect(b.tileType, b.position, b.size)
                    emplace(blocks, b)
                }
            }
        }
    }
}


// continuous collision detection
def trace_rectangle_to_scene(from, to, size : float2, var hit_normal : float2&, var hit_pos : float2&, var hit_block_index : int&) : bool {
    var hit = false
    var hitTime = 9999.0
    var hitNormal = float2(0)
    var hitBlockIndex = -1
    var hitPos = float2(0)
    for (i, b in count(), blocks) {
        if (!b.active || !b.obstacle) {
            continue
        }

        var t = 0.0
        var normal = float2(0)
        if (trace_segment_solid_aabb(from, to, b.position - size, b.position + b.size, t, normal, hitPos)) {
            if (t < hitTime) {
                hitTime = t
                hitNormal = normal
                hit_pos = hitPos
                hitBlockIndex = i
                hit = true
            }
        }
    }

    hit_normal = hitNormal
    hit_block_index = hitBlockIndex
    return hit
}


def draw_debug_box(min, max : float2, color : float4) {
    draw_box(float3(min, -4.0), float3(max, 4.0), color, 5)
}


def test_point_scene_collision(pos : float2) : bool {
    //draw_debug_box(pos, pos + float2(0.1), float4(1, 0, 0, 1))
    for (b in blocks) {
        if (!b.active || !b.obstacle) {
            continue
        }

        if (pos.x >= b.position.x && pos.x <= b.position.x + b.size.x &&
            pos.y >= b.position.y && pos.y <= b.position.y + b.size.y) {
            //draw_debug_box(b.position, b.position + b.size, float4(0, 1, 0, 1))
            return true
        }
    }
    return false
}


def update_input() {
    assume c = player.controls
    var prevControls = c
    c.horizontal = 0.0
    let moveDir = get_action_axis("horizontalMove")
    c.left = moveDir < 0.0
    c.leftDown = c.left && !prevControls.left
    c.right = moveDir > 0.0
    c.rightDown = c.right && !prevControls.right
    c.jump = is_action_pressed("jump")
    c.jumpDown = c.jump && !prevControls.jump
    c.horizontal = (c.right ? 1.0 : 0.0) - (c.left ? 1.0 : 0.0)
}


def check_contact_with_blocks(pos, size : float2) {
    var teleportBlockIndex = -1

    for (b, i in blocks, count()) {
        if (!b.active || b.obstacle) {
            continue
        }

        if (pos.x + size.x < b.position.x || pos.x > b.position.x + b.size.x ||
            pos.y + size.y < b.position.y || pos.y > b.position.y + b.size.y) {
            continue
        }

        if (b.tileType == TileType.Teleport) {
            teleportBlockIndex = i
            break
        }

        if (b.tileType == TileType.Bubble) {
            create_particle_explosion(b.position + b.size / 2.0, 0.5, 0.25, float4(0.5, 0.7, 1.0, 1.0), float4(0.9, 0.9, 1.0, 1.0))
            insert(collectedIntems, int3(int(b.position.x), int(b.position.y), currentRoomIndex))
            coins++
            play_sound(sound_coin)
            if (coins == totalCoins) {
                set_next_game_state(GameState.Status, 1.5)
                play_sound(sound_complete)
            }
            deactivate_block(i)
        }

        if (b.tileType == TileType.Lava || b.tileType == TileType.SpikeDown || b.tileType == TileType.SpikeUp ||
           b.tileType == TileType.SpikeLeft || b.tileType == TileType.SpikeRight) {
            kill_player()
            deaths++
            timeToRespawn = 1.0
            return
        }
    }

    if (teleportBlockIndex != -1) {
        assume b = blocks[teleportBlockIndex]
        if (b.position.x == 1.0) {
            player.position = float2(float(ROOM_SIZE_X) - 1.2, b.position.y)
        } elif (b.position.x == float(ROOM_SIZE_X)) {
            player.position = float2(2.2, b.position.y)
        } elif (b.position.y == 1.0) {
            player.position = float2(b.position.x, float(ROOM_SIZE_Y) - 1.2)
        } elif (b.position.y == float(ROOM_SIZE_Y)) {
            player.position = float2(b.position.x, 2.2)
        }
        respawnPosition = player.position
        player.grounded = false
        player.velocity = float2(0)
        load_room(b.userData)
    }
}


def update_player(dt : float) {
    var prevGrounded = player.grounded

    if (player.controls.horizontal != 0.0) {
        player.lastMoveDirectionSign = player.controls.horizontal
    }

    let traceDownLength = -0.015
    player.grounded = (test_point_scene_collision(player.position + float2(0.01, traceDownLength)) ||
                       test_point_scene_collision(player.position + float2(player.size.x - 0.01, traceDownLength)))

    if (player.grounded) {
        if (!prevGrounded) {
            set_volume(play_sound(sound_touchdown), 0.4)
        }
        player.groundedTime = COYOTE_TIME
    } else {
        player.groundedTime -= dt
    }

    if (player.controls.jumpDown) {
        player.jumpBufferTime = JUMP_BUFFER_TIME
    } else {
        player.jumpBufferTime -= dt
    }

    if (player.controls.jump && player.jumpBufferTime > 0.0 && player.groundedTime > 0.0) {
        if (player.velocity.y <= JUMP_SPEED * 0.1) {
            set_volume(play_sound(sound_jump), 0.4)
        }
        player.velocity.y = JUMP_SPEED
        player.longJumpTime = LONG_JUMP_TIME
        player.grounded = false
        player.groundedTime = 0.0
        player.jumpBufferTime = 0.0
    }

    if (player.controls.jump && player.longJumpTime > 0.0 && player.velocity.y > 0.0) {
        player.velocity.y = JUMP_SPEED
    }

    player.longJumpTime -= dt
    if (player.velocity.y <= 0.0 || !player.controls.jump) {
        player.longJumpTime = 0.0
    }

    var horizontalAccel = player.grounded ? GROUND_ACCELERATION : AIR_ACCELERATION
    var horizontalDecel = player.grounded ? GROUND_DECELERATION : AIR_DECELERATION
    var verticalAccel = player.velocity.y > 0.0 ? GRAVITY_POS : GRAVITY_NEG

    if (abs(player.velocity.y) < AIR_TIME_SPEED_THRESHOLD) {
        verticalAccel = AIR_TIME_GRAVITY
    }

    if (player.controls.leftDown) {
        if (player.controls.doubleLeftTime > 0.0) {
            play_sound(sound_dash)
            player.dashTime = DASH_TIME
            player.dashDirection = -1.0
            player.controls.doubleLeftTime = 0.0
            player.controls.doubleRightTime = 0.0
        } else {
            player.controls.doubleLeftTime = DASH_BUFFER_TIME
        }
    } else {
        player.controls.doubleLeftTime -= dt
    }

    if (player.controls.rightDown) {
        if (player.controls.doubleRightTime > 0.0) {
            play_sound(sound_dash)
            player.dashTime = DASH_TIME
            player.dashDirection = 1.0
            player.controls.doubleLeftTime = 0.0
            player.controls.doubleRightTime = 0.0
        } else {
            player.controls.doubleRightTime = DASH_BUFFER_TIME
        }
    } else {
        player.controls.doubleRightTime -= dt
    }

    if (player.dashTime > 0.0) {
        player.dashTime -= dt
        player.velocity.x = player.dashDirection * MAX_SPEED
        player.velocity.y = 0.0
        if (player.controls.horizontal * player.dashDirection < 0.0) {
            player.dashTime = 0.0
        }
    }

    player.velocity.x = lerp(player.velocity.x, player.controls.horizontal * SPEED,
        player.controls.horizontal == 0.0 ? horizontalDecel * dt : horizontalAccel * dt)

    player.velocity.y = clamp(player.velocity.y - verticalAccel * dt, -MAX_FALL_SPEED, MAX_JUMP_SPEED)

    var prevPos = player.position
    var nextPos = player.position + player.velocity * dt

    var hitPos = float2(0)
    var hitNormal = float2(0)
    var hitBlockIndex = -1
    var fromPos = player.position

    if (trace_rectangle_to_scene(fromPos, nextPos, player.size, hitNormal, hitPos, hitBlockIndex)) {
        fromPos = hitPos + hitNormal * 0.001
        player.velocity += hitNormal * dot(player.velocity, hitNormal) * -1.0
        // second itaration
        nextPos = fromPos + player.velocity * dt
        if (trace_rectangle_to_scene(fromPos, nextPos, player.size, hitNormal, hitPos, hitBlockIndex)) {
            player.position = hitPos + hitNormal * 0.001
            player.velocity += hitNormal * dot(player.velocity, hitNormal) * -1.0
        } else {
            player.position = nextPos
        }
    } else {
        player.position = nextPos
    }

    if (player.dashTime > 0.0) {
        create_particle_trail(prevPos + player.size * 0.5, player.position + player.size * 0.5)
    }

    check_contact_with_blocks(player.position, player.size)
}


def update_scene() {
    if (player.active) {
        player.node.localPosition = float3(player.position, 2.1)
        player.node.localScale = float3(player.lastMoveDirectionSign, 1.0, 1.0)
    }
}


def count_total_coins() {
    totalCoins = 0
    for (room in rooms) {
        for (c in room) {
            if (c == 'o') {
                totalCoins++
            }
        }
    }
}


def reset_game() {
    clear_blocks()
    clear_particles()
    player.active = false
    clear(collectedIntems)
    coins = 0
    count_total_coins()
    timeToRespawn = -1.0
    deaths = 0
    totalGameTime = double(0.0)
    load_room(0)
}


[export]
def on_initialize() {
    init_debug_text(float2(20))
    let camera = create_node(NodeData(position = float3((ROOM_SIZE_X + 2) / 2, (ROOM_SIZE_Y + 2) / 2, -5)))
    add_component(camera, new Camera(orthographic = true, orthographicSize = 36f, backgroundColor = float3(0), fovAxis = FovAxis.Horizontal, fov = TO_RAD * 90f))
    set_next_game_state(GameState.Ingame)

    add_and_activate_action_set("player", {
        "horizontalMove" => Action(
            axisActions = AxisAction(
                keyboardAxis = [KeyboardBtnAxisInput(negativeIdx=KeyCode.Left, positiveIdx=KeyCode.Right), KeyboardBtnAxisInput(negativeIdx=KeyCode.A, positiveIdx=KeyCode.D)],
                gamepadAxis = [GamepadBtnAxisInput(negativeIdx=GamepadButton.Left, positiveIdx=GamepadButton.Right)],
                stickAxis = [GamepadAxisInput(idx=GamepadAxis.LThumbH)]
            )
        ),
        "jump" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space), KeyboardButtonInput(idx=KeyCode.Up), KeyboardButtonInput(idx=KeyCode.W)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        ),
        "start" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Return)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        )
    })
}


def guaranteed_step_update(dt : float) {
    if (dt > 1.0 / 150.0) {// guard against too big dt
        guaranteed_step_update(dt * 0.5)
        guaranteed_step_update(dt * 0.5)
        return
    }

    update_input()
    if (player.active) {
        update_player(dt)
    }

    if (gameState == GameState.Ingame) {
        totalGameTime += double(dt)
        if (timeToRespawn > 0.0 && !player.active) {
            timeToRespawn -= dt
            if (timeToRespawn <= 0.0) {
                create_player(respawnPosition)
                play_sound(sound_spawn)
            }
        }
    }

    if (gameState == GameState.Status) {
        if (is_action_pressed("start") && timeInCurrentGameState > 0.7) {
            set_next_game_state(GameState.Ingame)
        }
    }
}


[export]
def on_update() {
    var dt = get_delta_time()
    update_game_state(dt)
    guaranteed_step_update(dt)
    update_scene()
    update_particles(dt)

    set_debug_text("Coins: {coins}/{totalCoins}  Deaths: {deaths}  Time: {totalGameTime:0.3f}",
        gameState == GameState.Status)
}
