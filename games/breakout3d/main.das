require engine.core
require engine.math_core


//////////////////////////////// UI Debug String ///////////////////////////////////
var debug_text_node : NodeId

def set_debug_text(text : string) {
    update_debug_text(debug_text_node, text)
}

def init_debug_text(position : float2) {
    debug_text_node = create_debug_text(position)
}
////////////////////////////////////////////////////////////////////////////////////


let FIELD_WIDTH = 24
let FIELD_HEIGHT = 18
let DEFAULT_RACKET_WIDTH = 2.0
let EXTERNDED_RACKET_WIDTH = 3.5
let BALL_SPEED = 14.0
let MAX_BALLS = 20
let MAX_BONUSES = 10
let MAX_PARTICLES = 200
let MAX_BRICKS = 200


enum GameState {
    Game
    AllBallsLost
    LevelCompleted
}


let BONUS_BIG_RACKET = 0
let BONUS_BOMB = 1
let BONUS_EXTRA_BALL = 2
let BONUS_COUNT = 3

enum BallType {
    Normal
    Bullet
    Count
}

enum BrickType {
    None
    Wall
    Red
    Green
    Blue
    Magenta
    Count
}


let bonus_type_to_color : float4[BONUS_COUNT] = fixed_array(
    float4(0.1, 0.12, 1.0, 1.0),
    float4(1.0, 0.3, 0.03, 1.0),
    float4(1.0, 1.0, 1.0, 1.0)
)


let brick_type_to_color : float4[int(BrickType.Count)] = fixed_array(
    float4(),
    float4(1.0, 1.0, 1.0, 1.0),
    float4(1.0, 0.2, 0.17, 1.0),
    float4(0.3, 1.0, 0.2, 1.0),
    float4(0.3, 0.4, 1.0, 1.0),
    float4(1.0, 0.2, 1.0, 1.0)
)


let levels : array<string> <- [
    "w  w  w  w  w  w  w  w  w  w  w  w  w  w  w  w  w  w  w  w  w  w  w  w  " +
    "w  0  00 000.  .  .  .  .  .  .  0  0  .  .  .  .  .  .  .  00000 0  w  " +
    "w  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  w  " +
    "w  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  w  " +
    "w  .  .  .  .  .  .  .  .  .  .  2  2  2  2  2  2  23 2332  2  2  2  w  " +
    "w  1  1  1  1  1  12 122.  .  .  .  .  .  .  2  .  .  .  .  .  .  .  w  " +
    "w  .  .  .  .  .  .  1  .  .  .  .  .  .  .  23323 2  2  2  2  2  2  w  " +
    "w  1  1  1  12 1221  1  1  1  1  1  .  .  .  .  .  .  .  2  .  .  .  w  " +
    "w  .  .  .  .  .  .  .  .  .  .  1  .  .  .  .  .  .  .  23323 2  2  w  " +
    "w  1  1  1  1  1  1  1  1  1  1  1  1  1  1  1  .  .  .  .  .  .  .  w  " +
    "w  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  w  " +
    "w  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  w  " +
    "w  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  w  " +
    "w  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  w  " +
    "w  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  w  " +
    "w  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  w  " +
    "w  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  w  " +
    "w  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  .  w  ",
]



let ball_radius : float[int(BallType.Count)] = fixed_array(0.5, 0.4)

struct Ball {
    alive : bool
    position : float2
    prevPosition : float2
    velocity : float2
    ballType : BallType
    timeToDetach : float
    node : NodeId
}

struct Racket {
    position : float2
    width : float
    prevWidth : float
    nextWidth : float
    widthTransition : float
    timeToDefaultWidth : float
    node : NodeId
}

struct Bonus {
    alive : bool
    position : float2
    velocity : float2
    bonusType : int
    node : NodeId
}

struct Particle {
    alive : bool
    position : float3
    velocity : float3
    ttl : float // time to live
    size : float
    node : NodeId
}

struct Brick {
    alive : bool
    moving : bool
    brickType : BrickType
    position : float2
    size : float2
    alt : float
    velocity : float
    node : NodeId
}


var balls : Ball[MAX_BALLS]
var bonuses : Bonus[MAX_BONUSES]
var particles : Particle[MAX_PARTICLES]
var bricks : Brick[MAX_BRICKS]
var field_hegiht : int[FIELD_HEIGHT][FIELD_WIDTH]
var brick_indices : array<int>[FIELD_HEIGHT][FIELD_WIDTH]
var racket : Racket
var lives : int
var score : int
var level : int
var game_state : GameState
var time_to_next_game_state : float
var bonus_accum : float // used to make bonus drops more "fair"


var floor_node : NodeId


def allocate_ball() : int {
    for (i in 0 .. MAX_BALLS) {
        if (!balls[i].alive) {
            return i
        }
    }
    return -1
}

def allocate_bonus() : int {
    for (i in 0 .. MAX_BONUSES) {
        if (!bonuses[i].alive) {
            return i
        }
    }
    return -1
}

def allocate_particle() : int {
    for (i in 0 .. MAX_PARTICLES) {
        if (!particles[i].alive) {
            return i
        }
    }
    return -1
}


def clear_level() {
    for (ball in balls) {
        if (ball.alive) {
            remove_node(ball.node)
            ball.alive = false
        }
    }

    for (bonus in bonuses) {
        if (bonus.alive) {
            remove_node(bonus.node)
            bonus.alive = false
        }
    }

    for (particle in particles) {
        if (particle.alive) {
            remove_node(particle.node)
            particle.alive = false
        }
    }

    for (brick in bricks) {
        if (brick.alive) {
            remove_node(brick.node)
            brick.alive = false
        }
    }

    for (y in 0 .. FIELD_HEIGHT) {
        for (x in 0 .. FIELD_WIDTH) {
            field_hegiht[y][x] = 0
            clear(brick_indices[y][x])
        }
    }
}


def is_any_ball_alive() : bool {
    for (ball in balls) {
        if (ball.alive) {
            return true
        }
    }
    return false
}


def is_any_brick_alive() : bool {
    for (brick in bricks) {
        if (brick.alive) {
            return true
        }
    }
    return false
}


def load_level(index : int) {
    var i : int = 0
    var levelArray <- [ for (c in levels[index]); c ]
    for (y in 0 .. FIELD_HEIGHT) {
        for (x in 0 .. FIELD_WIDTH) {
            for (a in 0 .. 3) {
                let c = levelArray[(y * FIELD_WIDTH + (FIELD_WIDTH - x - 1)) * 3 + a]
                var brickType = BrickType.None
                if (c == '0') {
                    brickType = BrickType.Red
                } elif (c == '1') {
                    brickType = BrickType.Green
                } elif (c == '2') {
                    brickType = BrickType.Blue
                } elif (c == '3') {
                    brickType = BrickType.Magenta
                } elif (c == 'w') {
                    brickType = BrickType.Wall
                }

                if (brickType != BrickType.None) {
                    assume brick = bricks[i]
                    brick.alive = true
                    brick.moving = false
                    brick.brickType = brickType
                    brick.position = float2(x, y)
                    brick.size = float2(1.0)
                    brick.alt = float(field_hegiht[y][x])
                    brick.velocity = 0.0
                    let node = create_node(NodeData(
                        position = float3(float(x) + brick.size.x * 0.5, brick.alt + 0.5, float(y) + brick.size.y * 0.5)
                    ))
                    add_component(node, new Mesh(meshId = CUBE_MESH_ID, color = brick_type_to_color[int(brickType)]))
                    node.localScale = c == 'w' ? float3(1) : float3(0.95)
                    brick.node = node
                    push(brick_indices[y][x], i)
                    field_hegiht[y][x]++
                    i++
                }
            }
        }
    }

    print("Loaded level {index}\n")
    print("Bricks: {i}\n")
}


def clear_balls() {
    for (ball in balls) {
        if (ball.alive) {
            remove_node(ball.node)
            ball.alive = false
        }
    }
}


def setup_racket() {
    racket.position = float2(FIELD_WIDTH / 2, FIELD_HEIGHT - 1)
    racket.width = DEFAULT_RACKET_WIDTH
    racket.prevWidth = racket.width
    racket.nextWidth = racket.width
    racket.timeToDefaultWidth = 0.0
    racket.widthTransition = 0.0
}


def goto_level(index : int) {
    clear_level()
    load_level(index)
    setup_racket()
    create_ball()
}


def create_light() {
    let sunLight = create_node()
    add_component(sunLight, new DirectionLight())
    sunLight.localRotation = make_quat_from_basis_zy(float3(-1.5, -2.3, -1.0), float3(0, 1, 0))

    let renderSettings = create_render_settings()
    get_component(renderSettings, $(var shadow : ShadowSettings?) {
        shadow.powWeight = 0.6;
        shadow.maxDist = 200.0;
    })
}


def create_camera() {
    let camera_node = create_node()
    add_component(camera_node, new Camera(fovAxis = FovAxis.Horizontal, fov = deg_to_rad(41.0), zfar = 2000.0, znear = 0.1))
    let at = float3(FIELD_WIDTH, 0, FIELD_HEIGHT) * 0.5
    let eye = at + float3(0, 30, 30)
    let up = float3(0, 1, 0)
    camera_node.localPosition = eye
    camera_node.localRotation = make_quat_from_basis_zy(at - eye, up)
}


def create_floor() {
    floor_node = create_node(NodeData(position = float3(float(FIELD_WIDTH) / 2.0, 0.0, float(FIELD_HEIGHT) / 2.0)))
    add_component(floor_node, new Mesh(meshId = PLANE_MESH_ID, color = float4(0.25, 0.25, 0.25, 1.0)))
    floor_node.localScale = float3(FIELD_WIDTH, 1, FIELD_HEIGHT) * 2.0
}


def create_racket() {
    racket.node = create_node()
    for (i in 0..8) {
        let k = float(i) / 7.0
        let segmentNode = create_node(NodeData(parent = racket.node, position = float3(0.1 * (float(i) - 3.5), 0.0, 0.6 * sqr(k - 0.5))))
        add_component(segmentNode, new Mesh(meshId = CUBE_MESH_ID))
        segmentNode.localScale = float3(0.2, 0.8, 0.2)
        segmentNode.localRotation = quat4(float3(0.0, (0.5 - k) * 1.3, 0.0))
    }
}


def create_ball() {
    let i = allocate_ball()
    assume ball = balls[i]
    ball.alive = true
    ball.ballType = BallType.Normal
    ball.position = float2(racket.position.x, racket.position.y - 0.5 - ball_radius[int(ball.ballType)])
    ball.prevPosition = ball.position
    ball.velocity = normalize(float2(4.0, -10.0)) * BALL_SPEED
    ball.timeToDetach = 1.0
    ball.node = create_node(NodeData(position = float3(ball.position.x, 0.0, ball.position.y) + float3(0.5)))
    add_component(ball.node, new Mesh(meshId = SPHERE_MESH_ID))
    ball.node.localScale = float3(ball_radius[int(ball.ballType)])
}


def create_particle(position : float3, velocity : float3, ttl : float, color : float4) {
    let i = allocate_particle()
    if (i == -1) {
        return
    }
    assume particle = particles[i]
    particle.alive = true
    particle.position = position
    particle.velocity = velocity
    particle.ttl = ttl
    particle.size = random_range(0.2, 0.4)
    particle.node = create_node(NodeData(position = position))
    add_component(particle.node, new Mesh(meshId = CUBE_MESH_ID, color = color))
    particle.node.localScale = float3(particle.size)
}


def create_explosion(bounds_min, bounds_max : float3, color : float4) {
    for (i in 0 .. 15) {
        let pos = random_range(bounds_min, bounds_max)
        let vel = normalize(pos - (bounds_min + bounds_max) * 0.5) * random_range(0.5, 1.5)
        create_particle(pos, vel, random_range(0.5, 1.0), color)
    }
}


def try_create_random_bonus(position : float2) {
    bonus_accum += random_range(0.0, 0.25)
    if (bonus_accum < 1.0) {
        return
    }
    bonus_accum -= 1.0

    let i = allocate_bonus()
    if (i == -1) {
        return
    }
    assume bonus = bonuses[i]
    let t = random_range(0, BONUS_COUNT)
    bonus.alive = true
    bonus.bonusType = t
    bonus.position = position
    bonus.velocity = float2(0.0, 4.0)
    bonus.node = create_node(NodeData(position = float3(bonus.position.x, 0.5, bonus.position.y) + float3(0.5)))
    if (t == BONUS_BIG_RACKET) {
        add_component(bonus.node, new Mesh(meshId = CUBE_MESH_ID))
        bonus.node.localScale = float3(1.0, 0.3, 0.3)
    } elif (t == BONUS_EXTRA_BALL) {
        add_component(bonus.node, new Mesh(meshId = SPHERE_MESH_ID))
        bonus.node.localScale = float3(0.6, 0.6, 0.6)
    } elif (t == BONUS_BOMB) {
        add_component(bonus.node, new Mesh(meshId = SPHERE_MESH_ID))
        bonus.node.localScale = float3(0.8, 0.8, 0.8)
    } else {
        assert(false)
    }
    bonus.node?.Mesh.color = bonus_type_to_color[t]
}


def restart() {
    lives = 3
    score = 0
    level = 0
    bonus_accum = 0.5
    goto_level(level)
}


[export]
def on_initialize() {
    init_debug_text(float2(20, 20))
    restart()
    create_light()
    create_camera()
    create_floor()
    create_racket()

    add_and_activate_action_set("player", {
        "horizontalMove" => Action(
            axisActions = AxisAction(
                keyboardAxis = [KeyboardBtnAxisInput(negativeIdx=KeyCode.Left, positiveIdx=KeyCode.Right), KeyboardBtnAxisInput(negativeIdx=KeyCode.A, positiveIdx=KeyCode.D)],
                gamepadAxis = [GamepadBtnAxisInput(negativeIdx=GamepadButton.Left, positiveIdx=GamepadButton.Right)],
                stickAxis = [GamepadAxisInput(idx=GamepadAxis.LThumbH), GamepadAxisInput(idx=GamepadAxis.RThumbH)]
            )
        )
    })
}


def update_visuals() {
    set_debug_text("Lives: {lives}  Score: {score}  Level: {level + 1}")

    for (ball in balls) {
        if (ball.alive) {
            ball.node.localPosition = float3(ball.position.x, 0.5, ball.position.y)
        }
    }

    for (bonus in bonuses) {
        if (bonus.alive) {
            bonus.node.localPosition = float3(bonus.position.x, 0.5, bonus.position.y)
        }
    }

    for (particle in particles) {
        if (particle.alive) {
            particle.node.localPosition = particle.position
            particle.node.localScale = float3(particle.size * particle.ttl)
        }
    }

    for (brick in bricks) {
        if (brick.alive && brick.moving) {
            brick.node.localPosition = float3(brick.position.x + brick.size.x * 0.5, brick.alt + 0.5, brick.position.y + brick.size.y * 0.5)
        }
    }

    racket.node.localScale = float3(racket.width, 1.0, 1.0)
    racket.node.localPosition = float3(racket.position.x, 0.5, racket.position.y)
}


def update_racket(dt : float) {
    if (racket.timeToDefaultWidth > 0.0) {
        racket.timeToDefaultWidth -= dt
        if (racket.timeToDefaultWidth <= 0.0) {
            racket.nextWidth = DEFAULT_RACKET_WIDTH
            racket.prevWidth = racket.width
            racket.widthTransition = 0.0
        }
    }

    racket.widthTransition = clamp(racket.widthTransition + dt * 5.0, 0.0, 1.0)
    racket.width = lerp(racket.prevWidth, racket.nextWidth, racket.widthTransition)

    var moveDir = get_action_axis("horizontalMove")

    racket.position.x = racket.position.x - clamp(moveDir, -1.0, 1.0) * dt * 18.0
    racket.position.x = clamp(racket.position.x, racket.width * 0.5 + 1.0, float(FIELD_WIDTH) - racket.width * 0.5 - 1.0)
}


def test_for_wall(ix, iy : int) : bool {
    if (ix < 0 || ix >= FIELD_WIDTH || iy < 0 || iy >= FIELD_HEIGHT) {
        return true
    }

    for (idx in brick_indices[iy][ix]) {
        assume brick = bricks[idx]
        if (brick.alive && brick.alt <= 0.5) {
            return true
        }
    }

    return false
}


def update_ball_brick_collision(var ball : Ball&) {
    var p0 = ball.prevPosition
    var p1 = ball.position
    var normal : float2
    var brickIndex : int = -1
    var hitTime = 9999.0

    let radius = ball_radius[int(ball.ballType)]
    for (iy in int(ball.position.y) - 2 .. int(ball.position.y) + 2) {
        for (ix in int(ball.position.x) - 2 .. int(ball.position.x) + 2) {
            if (ix < 0 || ix >= FIELD_WIDTH || iy < 0 || iy >= FIELD_HEIGHT) {
                continue
            }
            for (idx in brick_indices[iy][ix]) {
                assume brick = bricks[idx]
                if (!brick.alive || brick.alt > 0.5) {
                    continue
                }

                var extensionLeftTop = float2(radius)
                var extensionRightBottom = float2(radius)

                if (test_for_wall(ix - 1, iy)) {
                    extensionLeftTop.x = 0.0
                }

                if (test_for_wall(ix + 1, iy)) {
                    extensionRightBottom.x = 0.0
                }

                if (test_for_wall(ix, iy - 1)) {
                    extensionLeftTop.y = 0.0
                }

                if (test_for_wall(ix, iy + 1)) {
                    extensionRightBottom.y = 0.0
                }

                let leftTop = brick.position - extensionLeftTop
                let rightBottom = brick.position + brick.size + extensionRightBottom
                var currentHitTime = 0.0
                var currentHitPoint = float2(0.0)
                var currentHitNormal = float2(0.0)

                if (trace_segment_solid_aabb(p0, p1, leftTop, rightBottom, currentHitTime, currentHitNormal, currentHitPoint)) {
                    if (currentHitTime < hitTime) {
                        hitTime = currentHitTime
                        normal = currentHitNormal
                        ball.position = currentHitPoint
                        brickIndex = idx
                    }
                }
            }
        }
    }

    if (brickIndex == -1) {
        return
    }
    assume brick = bricks[brickIndex]

    if (brick.brickType != BrickType.Wall) {
        score += 10
        try_create_random_bonus(brick.position + brick.size * 0.5)
        remove_node(brick.node)
        brick.alive = false

        create_explosion(float3(brick.position.x, brick.alt, brick.position.y),
            float3(brick.position.x + brick.size.x, brick.alt + 1.0, brick.position.y + brick.size.y),
            brick_type_to_color[int(brick.brickType)])

        for (f in brick_indices[int(brick.position.y)][int(brick.position.x)]) {
            if (bricks[f].alive) {
                bricks[f].moving = true
            }
        }
    }

    let depth = abs(dot(ball.position - p1, normal))
    ball.position += normal * depth * 1.01
    if (dot(normal, ball.velocity) < 0.0) {
        ball.velocity = reflect(ball.velocity, normal)
    }

    if (ball.ballType == BallType.Bullet) {
        remove_node(ball.node)
        ball.alive = false
    }
}



def update_ball_racket_collision(var ball : Ball&) {
    if (ball.velocity.y < 0.0) {
        return
    }
    let radius = ball_radius[int(ball.ballType)]
    let racketBox = (float4(racket.position.x - racket.width * 0.5, racket.position.y - 0.2, racket.position.x + racket.width * 0.5, racket.position.y + 0.2) +
        float4(-radius, -radius, radius, radius))

    if (ball.position.x >= racketBox.x && ball.position.x <= racketBox.z && ball.position.y >= racketBox.y && ball.position.y <= racketBox.w) {
        let ballSpeed = length(ball.velocity)
        ball.velocity.y = -ball.velocity.y
        ball.velocity.x = clamp(ball.velocity.x + (ball.position.x - racket.position.x) * 7.0, -11.0, 11.0)
        ball.velocity = normalize(ball.velocity) * ballSpeed
    }
}


def update_ball(dt : float, var ball : Ball&) {
    ball.prevPosition = ball.position
    if (ball.timeToDetach > 0.0) {
        ball.timeToDetach -= dt
        ball.position = float2(racket.position.x, racket.position.y - 0.5 - ball_radius[int(ball.ballType)])
        return
    }

    ball.position += ball.velocity * dt
    update_ball_brick_collision(ball)
    update_ball_racket_collision(ball)
    if (ball.position.y > float(FIELD_HEIGHT) + 3.0) {
        remove_node(ball.node)
        ball.alive = false
    }
}


def update_moving_bricks(dt : float) {
    for (brick, index in bricks, count()) {
        if (brick.alive && brick.moving) {
            var bricksUnder = 0
            for (i in brick_indices[int(brick.position.y)][int(brick.position.x)]) {
                if (i == index) {
                    break
                }
                if (bricks[i].alive) {
                    bricksUnder += 1
                }
            }
            let targetAlt = float(bricksUnder)
            if (brick.alt == targetAlt) {
                brick.moving = false
                continue
            }
            brick.velocity -= dt * 10.0
            brick.alt += brick.velocity * dt
            if (brick.alt < targetAlt) {
                brick.alt = targetAlt
                brick.velocity = 0.0
            }
        }
    }
}


def bonus_caught(var bonus : Bonus&) {
    remove_node(bonus.node)
    bonus.alive = false
    if (bonus.bonusType == BONUS_BIG_RACKET) {
        racket.prevWidth = racket.width
        racket.nextWidth = EXTERNDED_RACKET_WIDTH
        racket.timeToDefaultWidth = 12.0
        racket.widthTransition = 0.0
    } elif (bonus.bonusType == BONUS_EXTRA_BALL) {
        for (ball in balls) {
            if (ball.alive && ball.ballType == BallType.Normal) {
                let i = allocate_ball()
                if (i == -1) {
                    break
                }
                assume newBall = balls[i]
                newBall = ball
                newBall.node = create_node(NodeData(position = float3(newBall.position.x, 0.0, newBall.position.y) + float3(0.5)))
                add_component(newBall.node, new Mesh(meshId = SPHERE_MESH_ID))
                newBall.node.localScale = float3(ball_radius[int(newBall.ballType)])
                newBall.velocity.x *= -1.0
                break
            }
        }
    } elif (bonus.bonusType == BONUS_BOMB) {
        for (x in 0 .. 6) {
            let vel = normalize(float2((float(x) - 2.0) / 4.0, -6.0)) * BALL_SPEED
            let i = allocate_ball()
            if (i == -1) {
                break
            }
            assume bullet = balls[i]
            bullet.alive = true
            bullet.ballType = BallType.Bullet
            bullet.position = float2(bonus.position.x, bonus.position.y)
            bullet.velocity = vel
            bullet.timeToDetach = 0.0
            bullet.node = create_node(NodeData(position = float3(bullet.position.x, 0.0, bullet.position.y) + float3(0.5)))
            add_component(bullet.node, new Mesh(meshId = SPHERE_MESH_ID, color = float4(1.0, 0.4, 0.1, 1.0)))
            bullet.node.localScale = float3(0.4)
        }
    }
}


def update_bonuses(dt : float) {
    for (bonus, index in bonuses, count()) {
        if (bonus.alive) {
            bonus.position += bonus.velocity * dt
            if (bonus.position.y > float(FIELD_HEIGHT) + 3.0) {
                remove_node(bonus.node)
                bonus.alive = false
                continue
            }

            let radius = 0.3
            let racketBox = (float4(racket.position.x - racket.width * 0.5, racket.position.y - 0.5, racket.position.x + racket.width * 0.5, racket.position.y + 0.5) +
                float4(-radius, -radius, radius, radius))

            if (bonus.position.x >= racketBox.x && bonus.position.x <= racketBox.z && bonus.position.y >= racketBox.y && bonus.position.y <= racketBox.w) {
                bonus_caught(bonus)
            }
        }
    }
}


def update_particles(dt : float) {
    for (particle in particles) {
        if (particle.alive) {
            particle.position += particle.velocity * dt
            if (particle.position.y < 0.0) {
                particle.velocity.y = -particle.velocity.y * 0.5
                particle.position.y = 0.0
            }
            particle.velocity.y -= dt * 40.0
            particle.ttl -= dt
            if (particle.ttl <= 0.0) {
                remove_node(particle.node)
                particle.alive = false
            }
        }
    }
}


def is_level_complete() {
    for (brick in bricks) {
        if (brick.alive && brick.brickType != BrickType.Wall) {
            return false
        }
    }
    return true
}


def is_failed() {
    for (ball in balls) {
        if (ball.alive) {
            return false
        }
    }
    return true
}


def guaranteed_step_update(dt : float) {
    if (dt > 1.0 / 40.0) {// guard against too big dt
        guaranteed_step_update(dt * 0.5)
        guaranteed_step_update(dt * 0.5)
        return
    }

    update_racket(dt)
    for (ball in balls) {
        if (ball.alive) {
            update_ball(dt, ball)
        }
    }
    update_moving_bricks(dt)
    update_bonuses(dt)
    update_particles(dt)
}


[export]
def on_update() {
    let dt = get_delta_time()
    guaranteed_step_update(dt)

    if (is_level_complete()) {
        level += 1
        if (level >= length(levels)) {
            level = 0
        }
        goto_level(level)
    }

    if (is_failed()) {
        lives -= 1
        if (lives <= 0) {
            restart()
        } else {
            clear_balls()
            create_ball()
        }
    }

    update_visuals()
}

