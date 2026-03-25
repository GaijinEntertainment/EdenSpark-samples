require engine.core
require engine.math_core
require genericUtils


var seed : int4 = int4(1, 2, 7, 25)


let MAP_SIZE_X = 28
let MAP_SIZE_Y = 16


let OBSTACLE_FOR_BULLET = 1 << 0
let OBSTACLE_FOR_UNIT = 1 << 1




let levels : array<string> <- [
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaa" +
    "a..........................a" +
    "a............1..xxxxxxxx...a" +
    "a...............x......x...a" +
    "a...aaaaaaaaa...x..2...x...a" +
    "a...........a...xxxxxxxx...a" +
    "a...........a..............a" +
    "a.....0.....x..............a" +
    "a...........x......a.......a" +
    "a...........aooooo.a..1....a" +
    "a..................a.......a" +
    "a..................aaaaa...a" +
    "a..........................a" +
    "a..........................a" +
    "a..........................a" +
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaa",

    "aaaaaaaaaaaaaaaaaaaaaaaaaaaa" +
    "a..........................a" +
    "a..........................a" +
    "a..........................a" +
    "a...................1......a" +
    "a..........................a" +
    "a..........................a" +
    "a..........................a" +
    "a.........0................a" +
    "a..........................a" +
    "a..........................a" +
    "a..........................a" +
    "a..........................a" +
    "a..........................a" +
    "a..........................a" +
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaa"
]


let {
    tank_fire_sound <- fixed_array(
        request_sound("assets/sound/tank_fire1.wav"),
        request_sound("assets/sound/tank_fire2.wav"),
        request_sound("assets/sound/tank_fire3.wav"),
        request_sound("assets/sound/tank_fire4.wav")
    )

    bounce_sound = request_sound("assets/sound/bullet_bounce.wav")
    explosion_sound = request_sound("assets/sound/tank_explosion.wav")

    explosion_texture = request_texture("assets/explosion_particle.png")
}

struct Particle {
    alive : bool
    position : float2
    velocity : float2
    size : float
    timeToLive : float
    initialTimeToLive : float
    color : uint
    node : NodeId
}

struct CellDescription {
    levelSymbol : int
    color : uint
    height : int
    obstacle : int
    descructableByBullet : bool
    descructableByExplosion : bool
    resource : PrefabId
}

struct BulletTypeDescription {
    speed : float
    radius : float
    explosionRadius : float
    maxCollisions : int
    timeToLive : float
    color : uint
    resource : PrefabId
    timeToSpawnParticle : float
    particleTexture : TextureId
    particleSize : float
    particleColor : uint
    particleTimeToLive : float
}

struct WeaponDescription {
    bulletType : int
    cooldown : float
}

struct Bullet {
    alive : bool
    bulletType : int
    position : float2
    velocity : float2
    owner : int
    collisionsLeft : int
    timeToLive : float
    timeToSpawnParticle : float
    node : NodeId
}

struct UnitTypeDescription {
    maxSpeed : float
    acceleration : float
    innerRadius : float
    outerSoftRadius : float
    chassisAngularSpeed : float
    turretAngularSpeed : float
    explosionRadius : float
    weapon : int
    color : float4
}



struct UnitControl {
    move : float2
    turretDirection : float2
    fire : bool
}

struct AIState {
    moveToTarget : bool
    target : float2
    wishTarget : float2
    timeToChangeTarget : float
}

class Unit : Component {
    alive : bool
    unitType : int
    position : float2
    prevPosition : float2
    speed : float
    chassisAngle : float
    turretAngle : float
    weaponCooldown : float
    control : UnitControl
    aiState : AIState
    unitPositionNode : NodeId
    chassisNode : NodeId
    turretNode : NodeId

    def setColor(color : float4) : void {
        chassisNode?.Mesh.color = color
        turretNode?.Mesh.color = color
    }
}

let unitTypeDescriptions : UnitTypeDescription[3] <- fixed_array(
    UnitTypeDescription(
        maxSpeed = 3.0,
        acceleration = 15.0,
        innerRadius = 0.44,
        outerSoftRadius = 0.49,
        chassisAngularSpeed = 7.0,
        turretAngularSpeed = 10.0,
        color = color32_to_float4(0xFFFFFFFF),
        explosionRadius = 4.0,
        weapon = 0
    ),

    UnitTypeDescription(
        maxSpeed = 3.0,
        acceleration = 4.0,
        innerRadius = 0.44,
        outerSoftRadius = 0.49,
        chassisAngularSpeed = 7.0,
        turretAngularSpeed = 10.0,
        color = color32_to_float4(0xFFAF90FF),
        explosionRadius = 4.0,
        weapon = 0
    ),

    UnitTypeDescription(
        maxSpeed = 3.0,
        acceleration = 8.0,
        innerRadius = 0.44,
        outerSoftRadius = 0.49,
        chassisAngularSpeed = 7.0,
        turretAngularSpeed = 10.0,
        color = color32_to_float4(0xFFFF905F),
        explosionRadius = 4.0,
        weapon = 0
    )
)



let bulletTypeDescriptions : BulletTypeDescription[3] <- fixed_array(
    BulletTypeDescription(
        speed = 6.0,
        radius = 0.1,
        explosionRadius = 0.0,
        maxCollisions = 2,
        timeToLive = 8.0,
        color = 0xFFFFFFFF,
        timeToSpawnParticle = 0.04,
        resource = request_prefab("assets/bullet.fbx"),
        particleTexture = explosion_texture,
        particleSize = 0.25,
        particleColor = 0x70FFFFFF,
        particleTimeToLive = 1.0
    ),

    BulletTypeDescription(
        speed = 6.0,
        radius = 0.1,
        explosionRadius = 0.0,
        maxCollisions = 2,
        timeToLive = 8.0,
        color = 0xFFFFFF00,
        timeToSpawnParticle = 0.04,
        resource = request_prefab("assets/bullet.fbx"),
        particleTexture = explosion_texture,
        particleSize = 0.25,
        particleColor = 0x70FFFFFF,
        particleTimeToLive = 1.0
    ),

    BulletTypeDescription(
        speed = 6.0,
        radius = 0.1,
        explosionRadius = 0.0,
        maxCollisions = 2,
        timeToLive = 8.0,
        color = 0xFFFF00FF,
        timeToSpawnParticle = 0.04,
        resource = request_prefab("assets/bullet.fbx"),
        particleTexture = explosion_texture,
        particleSize = 0.25,
        particleColor = 0xE0FFFFFF,
        particleTimeToLive = 1.0
    )
)


let weaponDescriptions : WeaponDescription[3] <- fixed_array(
    WeaponDescription(
        bulletType = 0,
        cooldown = 1.5
    ),

    WeaponDescription(
        bulletType = 1,
        cooldown = 1.5
    ),

    WeaponDescription(
        bulletType = 2,
        cooldown = 1.5
    )
)


let cellDescriptions : CellDescription[4] <- fixed_array(
    CellDescription(
        levelSymbol = '.',
        color = 0xFF202020,
        height = 0,
        obstacle = 0,
        descructableByBullet = false,
        descructableByExplosion = false,
        resource = PrefabId()
    ),

    CellDescription(
        levelSymbol = 'a',
        color = 0xFFF0F0F0,
        height = 2,
        obstacle = OBSTACLE_FOR_BULLET | OBSTACLE_FOR_UNIT,
        descructableByBullet = false,
        descructableByExplosion = false,
        resource = request_prefab("assets/block.fbx")
    ),

    CellDescription(
        levelSymbol = 'x',
        color = 0xFFFFCF90,
        height = 2,
        obstacle = OBSTACLE_FOR_BULLET | OBSTACLE_FOR_UNIT,
        descructableByBullet = true,
        descructableByExplosion = true,
        resource = request_prefab("assets/destructable_block.fbx")
    ),

    CellDescription(
        levelSymbol = 'o',
        color = 0xFFA0A0FF,
        height = 0,
        obstacle = OBSTACLE_FOR_UNIT,
        descructableByBullet = false,
        descructableByExplosion = false,
        resource = request_prefab("assets/cave.fbx")
    )
)


var current_level : int
var level : int[MAP_SIZE_Y][MAP_SIZE_X]
var level_nodes : NodeId[MAP_SIZE_Y][MAP_SIZE_X]
var units : array<Unit?>
var player_index : int
var bullets : array<Bullet>
var particles : array<Particle>
var cursor_node : NodeId


def load_level(str : string) {
    var x = 0
    var y = 0
    let tank_prefab = request_prefab("assets/tank.prefab")
    for (c in str) {
        if (c >= '0' && c <= '9') {
            if (c == '0') {
                player_index = length(units)
            }

            let node = instantiate_prefab(tank_prefab)
            var unit = get_component(node, type<Unit>)
            if (unit == null) {
                continue
            }

            let position = float2(float(x) + 0.5, float(y) + 0.5)
            unit.alive = true
            unit.unitType = c - '0'
            unit.position = position

            unit.unitPositionNode.localPosition = game_to_world(position)
            unit.unitPositionNode.localRotation = quat4(-PI / 2.0, 0f, 0f)
            unit.unitPositionNode.localScale = float3(0.1, 0.1, 0.1)

            unit->setColor(unitTypeDescriptions[unit.unitType].color)

            push(units, unit)

            level[y][x] = 0
        } else {
            var found = false
            for (index, desc in range(100), cellDescriptions) {
                if (desc.levelSymbol == c) {
                    level[y][x] = index
                    found = true
                    break
                }
            }
            if (!found) {
                level[y][x] = 0
                print("Unknown level symbol: {c} at {x}, {y}\n")
            }
        }

        x++
        if (x == MAP_SIZE_X) {
            x = 0
            y++
            if (y == MAP_SIZE_Y) {
                break
            }
        }
    }

    update_level_geometry()
}



def get_cell_safe(x : int, y : int) : int {
    if (x < 0 || x >= MAP_SIZE_X || y < 0 || y >= MAP_SIZE_Y) {
        return 0
    }
    return level[y][x]
}

let deltaCross = fixed_array(
    int2(-1, 0),
    int2(1, 0),
    int2(0, -1),
    int2(0, 1)
)
let deltaDiag = fixed_array(
    int2(1, 1),
    int2(-1, 1),
    int2(1, -1),
    int2(-1, -1)
)

def get_level_sdf(position : float2, obstacle_mask : int) : float {
    let x = int(position.x)
    let y = int(position.y)
    let centeredPosition = float2(x, y) + float2(0.5)
    var distance = 1.0

    if ((cellDescriptions[get_cell_safe(x, y)].obstacle & obstacle_mask) != 0) {
        distance = -1.0
        for (delta in deltaCross) {
            if ((cellDescriptions[get_cell_safe(x + delta.x, y + delta.y)].obstacle & obstacle_mask) == 0) {
                distance = max(distance, -abs(dot(centeredPosition + float2(delta) * 0.5 - position, float2(delta))))
            }
        }
        return distance
    }

    for (delta in deltaCross) {
        if ((cellDescriptions[get_cell_safe(x + delta.x, y + delta.y)].obstacle & obstacle_mask) != 0) {
            distance = min(distance, abs(dot(centeredPosition + float2(delta) * 0.5 - position, float2(delta))))
        }
    }

    for (delta in deltaDiag) {
        if ((cellDescriptions[get_cell_safe(x + delta.x, y + delta.y)].obstacle & obstacle_mask) != 0) {
            distance = min(distance, length(centeredPosition + float2(delta) * 0.5 - position))
        }
    }

    return distance
}



def get_level_collision_normal(position : float2, obstacle_mask : int) : float2 {
    let step = 0.1
    let dx = get_level_sdf(float2(position.x + step, position.y), obstacle_mask) - get_level_sdf(float2(position.x - step, position.y), obstacle_mask)
    let dy = get_level_sdf(float2(position.x, position.y + step), obstacle_mask) - get_level_sdf(float2(position.x, position.y - step), obstacle_mask)
    return normalize(float2(dx, dy))
}


def get_unit_collision_normal(position : float2, ignoreIndex : int) : float2 {
    return float2(0, 0)
}


def get_unit_in_radius(position : float2, radius : float, ignoreIndex : int) : int {
    return -1
}


def get_bullet_in_radius(position : float2, radius : float, ignoreIndex : int) : int {
    return -1
}

var camera_node : NodeId


def create_cursor() {
    cursor_node = instantiate_prefab(request_prefab("assets/block.fbx"))
    cursor_node.localPosition = float3(1000.0, 0.0, 0.0)
    cursor_node.localScale = float3(0.01)
}


def create_camera() {
    camera_node = create_node(NodeData(position = float3(0, 0, -10)))
    add_component(camera_node, new Camera(fovAxis = FovAxis.Horizontal, fov = 78.0 * TO_RAD))
}

let GAME_Z = 10.0
let GAME_SIZE = float2(MAP_SIZE_X, MAP_SIZE_Y)
let GAME_HALF_SIZE = GAME_SIZE / 2.0

def game_to_world(position : float2) : float3 {
    return float3(position.x - GAME_HALF_SIZE.x, GAME_HALF_SIZE.y - position.y, GAME_Z)
}

def world_to_game(position : float3) : float2 {
    return float2(position.x + GAME_HALF_SIZE.x, GAME_HALF_SIZE.y - position.y)
}

def update_level_geometry() {
    for (y in range(MAP_SIZE_Y)) {
        for (x in range(MAP_SIZE_X)) {
            let cell = level[y][x]
            assume cellDescription = cellDescriptions[cell]
            if (cellDescription.levelSymbol != '.') {
                let node = instantiate_prefab(cellDescription.resource)
                node?.Mesh.color = color32_to_float4(cellDescription.color)
                node.localPosition = game_to_world(float2(x, y) + float2(0.5))
                node.localScale = float3(0.1)
                node.localRotation = quat4(-PI / 2.0, 0f, 0f)
                level_nodes[y][x] = node
            }
        }
    }
}


def draw_cursor() {
    cursor_node.localPosition = game_to_world(cursor_world_position)
}


def draw_units() {
    for (u in units) {
        if (u.alive) {
            u.unitPositionNode.localPosition = game_to_world(u.position)
            u.chassisNode.localRotation = quat4(0f, u.chassisAngle, 0f)
            u.turretNode.localRotation = quat4(0f, u.turretAngle + PI, 0f)
        }
    }
}


def draw_bullets() {
    for (b in bullets) {
        if (!!b.node && b.alive) {
            b.node.localPosition = game_to_world(b.position)
            b.node.localRotation = quat4(-PI / 2.0, 0f, 0f) * quat4(0f, atan2(-b.velocity.y, -b.velocity.x), 0f)
        }
    }
}


def draw_particles() {
    for (p in particles) {
        if (p.alive) {
            p.node.localPosition = game_to_world(p.position) + float3(0.0, 0.0, -0.3)
            p.node.localScale = float3(p.size)
            p.node?.SpriteRenderer.color = float4(saturate(p.timeToLive / p.initialTimeToLive))
        }
    }
}


var cursor_world_position : float2

def update_input() {
    get_component(camera_node) $(camera : Camera?) {
        let ray = camera.screenToRay(get_action_vector2("fireDirection"))
        let p = game_to_world(float2())
        let n = float3(0, 0, 1)
        let t = dot(n, p - ray.origin) / dot(n, ray.direction)
        cursor_world_position = world_to_game((ray.origin + ray.direction * t))
    }
}


def apply_player_input(var u : Unit&) {
    var moveDir = get_action_vector2("move")
    moveDir = normalize(float2(moveDir.x, -moveDir.y))
    u.control.move = moveDir
    u.control.fire = is_action_pressed("fire")

    u.control.turretDirection = cursor_world_position - u.position
    if (length(u.control.turretDirection) > 1e-6) {
        u.control.turretDirection = normalize(u.control.turretDirection)
    }
}


def allocate_particle() : int {
    for (p, i in particles, range(length(particles))) {
        if (!p.alive) {
            return i
        }
    }
    emplace(particles, Particle())
    return length(particles) - 1
}


def allocate_bullet() : int {
    for (b, i in bullets, range(length(bullets))) {
        if (!b.alive) {
            return i
        }
    }
    emplace(bullets, Bullet())
    return length(bullets) - 1
}



def get_bullets_avoidance_sdf(position : float2) : float {
    let time0 = 0.25 // sec
    let time1 = 1.25 // sec
    var distance = 1.0
    for (b in bullets) {
        if (b.alive) {
            distance = min(distance, distance_to_segment(b.position + b.velocity * time0, b.position + b.velocity * time1, position))
        }
    }
    return distance
}

def get_bullets_avoidance_dir(position : float2) : float2 {
    let step = 0.1
    let dx = get_bullets_avoidance_sdf(float2(position.x + step, position.y)) - get_bullets_avoidance_sdf(float2(position.x - step, position.y))
    let dy = get_bullets_avoidance_sdf(float2(position.x, position.y + step)) - get_bullets_avoidance_sdf(float2(position.x, position.y - step))
    return normalize(float2(dx, dy))
}


def trace_hit(start, end : float2, radius : float, obstacle_mask : int) : bool {
    let step = 0.25
    let advance = normalize(end - start) * step
    let maxSteps = int(length(end - start) / step)
    var pos = start
    for (i in range(maxSteps)) {
        let sdf = get_level_sdf(pos, obstacle_mask)
        if (sdf < radius) {
            return true
        }
        pos += advance
    }
    return false
}


def estimate_ai_position(unit_index : int, target_pos : float2) : float {
    assume u = units[unit_index]
    if (trace_hit(u.position, target_pos, 0.4, OBSTACLE_FOR_UNIT)) {
        return -1e6
    }
    var score = -length(target_pos - units[player_index].position)
    let ds1 = dot(angle_to_direction(u.chassisAngle), normalize(target_pos - u.position))
    let ds2 = dot(angle_to_direction(u.chassisAngle + PI), normalize(target_pos - u.position))
    score += max(ds1, ds2) * 3.0
    score += get_level_sdf(target_pos, OBSTACLE_FOR_UNIT) * 5.0
    for (otherUnit, otherIndex in units, count()) {
        if (otherUnit.alive && otherIndex != unit_index) {
            score += max(length(target_pos - otherUnit.position) - 3.0, 0.0)
        }
    }
    if (!trace_hit(target_pos, units[player_index].position, 0.5, OBSTACLE_FOR_BULLET)) {
        score += 50.0
    }
    return score
}


def get_next_ai_move_target(unit_index : int) : float2 {
    assume u = units[unit_index]
    var bestPos = u.position
    var bestScore = estimate_ai_position(unit_index, bestPos)
    for (i in range(30)) {
        let targetPos = u.position + random_range(float2(-8), float2(8))
        var score = estimate_ai_position(unit_index, targetPos)
        if (score > bestScore) {
            bestScore = score
            bestPos = targetPos
        }
    }
    return bestPos
}


def update_units_ai(dt : float) {
    let t = get_time()
    for (u, index in units, count()) {
        if (u.alive && index != player_index) {
            assume unitTypeDesc = unitTypeDescriptions[u.unitType]
            assume weaponDesc = weaponDescriptions[unitTypeDesc.weapon]
            u.control.move = float2(0, 0)

            let avoidanceDir = get_bullets_avoidance_dir(u.position)
            if (length(avoidanceDir) > 1e-6) {
                u.aiState.wishTarget = u.position + avoidanceDir * 3.0
            }

            if (u.aiState.moveToTarget) {
                if (u.aiState.target == float2(0, 0)) {
                    u.aiState.target = u.position
                    u.aiState.wishTarget = u.position
                }

                u.control.move = u.aiState.target - u.position
                u.aiState.target = lerp(u.aiState.wishTarget, u.aiState.target, float2(1.0 - dt))
            }

            u.aiState.timeToChangeTarget -= length(u.position - u.aiState.target) < 1.0 ? dt * 5.0 : dt
            if (u.aiState.timeToChangeTarget < 0.0) {
                u.aiState.timeToChangeTarget = random_range(1.0, 3.0)
                u.aiState.wishTarget = get_next_ai_move_target(index)
                u.aiState.moveToTarget = true
            }

            var dirToPlayer = units[player_index].position - u.position
            let playerVisible = !trace_hit(u.position, units[player_index].position, 0.1, OBSTACLE_FOR_BULLET)
            var turretAngle = atan2(u.control.turretDirection.y, u.control.turretDirection.x)
            turretAngle = angle_move_to(turretAngle,
                playerVisible ? atan2(dirToPlayer.y, dirToPlayer.x) : u.chassisAngle, dt, unitTypeDesc.turretAngularSpeed)
            u.control.turretDirection = angle_to_direction(turretAngle)
            u.control.fire = (sin(float(index) + t) > 0.5 && playerVisible &&
                get_level_sdf(u.position + u.control.turretDirection * 2.0, OBSTACLE_FOR_BULLET) > 0.6 &&
                dot(u.control.turretDirection, normalize(dirToPlayer)) > 0.99)
        }
    }
}


def update_units(dt : float) {
    if (!empty(units) && units[player_index].alive) {
        apply_player_input(*units[player_index])
    }

    for (u, index in units, count()) {
        if (u.alive) {
            u.prevPosition = u.position
            assume unitTypeDesc = unitTypeDescriptions[u.unitType]
            assume weaponDesc = weaponDescriptions[unitTypeDesc.weapon]

            if (length(u.control.move) > 1e-6) {
                u.speed = move_to(u.speed, unitTypeDesc.maxSpeed, dt, unitTypeDesc.acceleration)
                var wishAngle = atan2(u.control.move.y, u.control.move.x)
                if (abs(angle_diff(wishAngle, u.chassisAngle)) > PI * 0.5) {
                    u.chassisAngle -= PI
                    u.speed = 0.0//-u.speed
                }
                u.chassisAngle = angle_move_to(u.chassisAngle, atan2(u.control.move.y, u.control.move.x), dt, unitTypeDesc.chassisAngularSpeed)
            } else {
                u.speed = move_to(u.speed, 0.0, dt, unitTypeDesc.acceleration)
            }

            u.turretAngle = atan2(u.control.turretDirection.y, u.control.turretDirection.x)

            let moveDir = angle_to_direction(u.chassisAngle)
            u.position += moveDir * u.speed * min(length(u.control.move), 1.0f) * dt

            let distToCollision = get_level_sdf(u.position, OBSTACLE_FOR_UNIT)
            if (distToCollision < unitTypeDesc.outerSoftRadius) {
                u.position += get_level_collision_normal(u.position, OBSTACLE_FOR_UNIT) * (unitTypeDesc.outerSoftRadius - distToCollision)
            }

            if (u.control.fire && u.weaponCooldown <= 0.0) {
                play_sound(random_element(tank_fire_sound))
                u.weaponCooldown = weaponDesc.cooldown
                assume bulletTypeDesc = bulletTypeDescriptions[weaponDesc.bulletType]
                let dir = angle_to_direction(u.turretAngle)
                let bulletIndex = allocate_bullet()
                assume b = bullets[bulletIndex]
                b <- Bullet(
                    alive = true,
                    bulletType = weaponDesc.bulletType,
                    position = u.position + dir * (unitTypeDesc.outerSoftRadius + bulletTypeDesc.radius),
                    velocity = dir * bulletTypeDesc.speed,
                    owner = index,
                    collisionsLeft = bulletTypeDesc.maxCollisions,
                    timeToLive = bulletTypeDesc.timeToLive
                )
                let node = instantiate_prefab(bulletTypeDesc.resource)
                node?.Mesh.color = color32_to_float4(bulletTypeDesc.color)
                bullets[bulletIndex].node = node
                node.localScale = float3(0.1, 0.1, 0.1)
                node.localPosition = game_to_world(b.position)
                node.localRotation = quat4(-PI / 2.0, 0f, 0f) * quat4(0f, atan2(b.velocity.y, b.velocity.x), 0f)
            } else {
                u.weaponCooldown -= dt
            }
        }
    }
}


def spawn_explosion(pos : float2, radius : float) {
    for (i in range(15)) {
        let particleIndex = allocate_particle()
        let vector = random_point_inside_unit_circle()

        let node = create_node(NodeData(
            position = game_to_world(pos + vector * radius) + float3(0.0, 0.0, 0.5),
            rotation = quat4(0f, 0f, atan2(vector.y, vector.x)),
            scale = float3(0.3 * radius)
        ))
        add_component(node, new SpriteRenderer(
            textureId = explosion_texture,
            useTextureSizeForScaling = false
        ))
        particles[particleIndex] <- Particle(
            alive = true,
            position = pos + vector * radius,
            velocity = vector * 0.5,
            timeToLive = 1.0,
            initialTimeToLive = 1.0,
            size = radius,
            color = 0xFFFFFFFF,
            node = node
        )
    }
}



def spawn_bullet_particle(b : Bullet, pos : float2) {
    assume bulletTypeDesc = bulletTypeDescriptions[b.bulletType]
    let particleIndex = allocate_particle()

    let node = create_node(NodeData(
        position = game_to_world(pos) + float3(0.0, 0.0, 0.5),
        rotation = quat4(0f, 0f, atan2(b.velocity.y, b.velocity.x)),
        scale = float3(0.3)
    ))
    add_component(node, new SpriteRenderer(
        textureId = bulletTypeDesc.particleTexture,
        useTextureSizeForScaling = false
    ))
    particles[particleIndex] <- Particle(
        alive = true,
        position = pos,
        velocity = b.velocity * 0.05,
        timeToLive = bulletTypeDesc.particleTimeToLive,
        initialTimeToLive = bulletTypeDesc.particleTimeToLive,
        size = bulletTypeDesc.particleSize,
        color = bulletTypeDesc.particleColor,
        node = node
    )
}


def get_destructable_cell(position, offset : float2) : int2 {
    let xx = int(position.x + offset.x)
    let yy = int(position.y + offset.y)
    if (cellDescriptions[get_cell_safe(xx, yy)].descructableByBullet) {
        return int2(xx, yy)
    }

    let x = int(position.x)
    let y = int(position.y)
    if (cellDescriptions[get_cell_safe(x, y)].descructableByBullet) {
        return int2(x, y)
    }
    for (delta in deltaCross) {
        if (cellDescriptions[get_cell_safe(x + delta.x, y + delta.y)].descructableByBullet) {
            return int2(x, y) + delta
        }
    }
    return int2(0, 0)
}


def destroy_unit(var u : Unit?) {
    set_pitch(play_sound(explosion_sound), random_range(0.95, 1.05))
    spawn_explosion(u.position, 0.9)
    u.alive = false
    remove_node(u.nodeId)
}


def destroy_bullet(var b : Bullet&) {
    b.alive = false
    remove_node(b.node)
}


def update_bullets(dt : float) {
    for (b in bullets) {
        if (b.alive) {
            assume bulletTypeDesc = bulletTypeDescriptions[b.bulletType]
            b.position += b.velocity * dt
            b.timeToLive -= dt
            if (b.timeToLive <= 0.0) {
                destroy_bullet(b)
                continue
            }

            b.timeToSpawnParticle -= dt
            if (b.timeToSpawnParticle <= 0.0) {
                spawn_bullet_particle(b, b.position + b.timeToSpawnParticle * b.velocity)
                b.timeToSpawnParticle += bulletTypeDesc.timeToSpawnParticle
            }

            let distToCollision = get_level_sdf(b.position, OBSTACLE_FOR_BULLET)
            if (distToCollision < bulletTypeDesc.radius) {
                set_volume(play_sound(bounce_sound), 0.5) |> set_pitch(random_range(0.95, 1.05))
                let destroyCellPos = get_destructable_cell(b.position, normalize(b.velocity) * bulletTypeDesc.radius * 1.5)
                if (destroyCellPos.x != 0) {
                    level[destroyCellPos.y][destroyCellPos.x] = 0
                    remove_node(level_nodes[destroyCellPos.y][destroyCellPos.x])
                    set_volume(play_sound(explosion_sound), 0.5) |> set_pitch(random_range(1.95, 2.05))
                    spawn_explosion(float2(destroyCellPos) + float2(0.5), 0.6)
                    destroy_bullet(b)
                    continue
                } elif (b.collisionsLeft > 0) {
                    b.collisionsLeft -= 1
                    b.velocity = reflect(b.velocity, get_level_collision_normal(b.position, OBSTACLE_FOR_BULLET))
                    b.position += b.velocity * dt
                } else {
                    destroy_bullet(b)
                    continue
                }
            }

            for (u, index in units, count()) {
                if (u.alive) {//&& index != b.owner
                    let unitTypeDesc = unitTypeDescriptions[u.unitType]
                    let dist = length(u.position - b.position)
                    if (dist < unitTypeDesc.outerSoftRadius) {
                        destroy_bullet(b)
                        destroy_unit(u)
                        break
                    }
                }
            }
        }
    }
}



def update_particles(dt : float) {
    for (p in particles) {
        if (p.alive) {
            p.position += p.velocity * dt
            p.timeToLive -= dt
            if (p.timeToLive <= 0.0) {
                p.alive = false
                remove_node(p.node)
            }
        }
    }
}



def create_light() {
    let sun = create_node(NodeData(rotation = quat4(float3(30, -30, -10) * PI / 180.0)))
    add_component(sun, new DirectionLight())

    let renderSettings = create_render_settings()
    get_component(renderSettings) $(var shadow : ShadowSettings?) {
        shadow.powWeight = 0.6
        shadow.maxDist = 200.0
    }

    get_component(renderSettings) $(var sky : Sky?) {
        sky.active = false
    }

    get_component(renderSettings) $(var amb : AmbientSettings?) {
        amb.ambientSource = AmbientSource.ConstColor
    }

    get_component(renderSettings) $(var ssao : SSAOSettings?) {
        ssao.active = false
    }
}

def restart() {
    current_level = 0
    clear_scene()
    load_level(levels[current_level])
    create_cursor()
    create_camera()
    create_light()
    create_status_string(
        float2(20, -20),
        "WASD/arrows to move, LMB/space to fire"
    )
}


def init_world() {
    restart()
}


[export]
def on_initialize() {
    print("eden: on_initialize")
    randomize_seed()
    init_world()

    add_and_activate_action_set("player", {
        "move" => Action(
            joystickActions = JoystickAction(
                keyboardDPads = [KeyboardDPadInput(leftIdx=KeyCode.A, rightIdx=KeyCode.D, upIdx=KeyCode.W, downIdx=KeyCode.S), KeyboardDPadInput(leftIdx=KeyCode.Left, rightIdx=KeyCode.Right, upIdx=KeyCode.Up, downIdx=KeyCode.Down)],
                sticks = [GamepadStickInput(xIdx=GamepadAxis.LThumbH, yIdx=GamepadAxis.LThumbV)],
            )
        ),
        "fire" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                mouseButtons = [MouseButtonInput(idx=MouseButton.Left)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        ),
        "fireDirection" => Action(
            pointerActions = PointerAction(
                valueType = ValueType.Accumulate,
                mouse = MouseInput(active = true),
            )
        )
    })
}


def guaranteed_step_update(dt : float) {
    if (dt > 1.0 / 20.0) {// guard against too big dt
        guaranteed_step_update(dt * 0.5)
        guaranteed_step_update(dt * 0.5)
        return
    }

    update_units_ai(dt)
    update_units(dt)
    update_bullets(dt)
    update_particles(dt)
}


[export]
def on_update() {
    update_input()
    guaranteed_step_update(get_delta_time())

    //setup_2d_camera(float2(MAP_SIZE_X, MAP_SIZE_Y) * 0.5, float(MAP_SIZE_X) * 1.5)
    //draw_level()
    draw_units()
    draw_particles()
    draw_bullets()
    draw_cursor()
}

