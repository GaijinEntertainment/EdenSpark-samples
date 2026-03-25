require engine.core
require common
require geometry
require sound
require user_settings

module game private

let mouseSensitivity = 0.005
let stickSensitivity = 10.0
let buttonSensitivity = 10.0

let emptyTileMaterial = request_material("assets/tile_mat.material")
let smallObstacleMaterial = request_material("assets/small_obstacle_mat.material")
let mediumObstacleMaterial = request_material("assets/medium_obstacle_mat.material")
let hpBonusMaterial = request_material("assets/hp_bonus_mat.material")

let obstacleColorTable = fixed_array(
    float3(0.5, 0.5, 0.0), float3(0.5, 0.0, 0.5), float3(0.0, 0.5, 0.5),
    float3(1.0, 1.0, 0.5), float3(1.0, 0.5, 1.0), float3(0.5, 1.0, 1.0),
    float3(0.5, 0.5, 1.0), float3(0.5, 1.0, 0.5), float3(1.0, 0.5, 0.5),
    float3(0.0, 0.5, 1.0), float3(0.5, 1.0, 0.0), float3(1.0, 0.0, 0.5),
    float3(0.5, 0.0, 1.0), float3(0.0, 1.0, 0.5), float3(1.0, 0.5, 0.0),
)

class ObstacleGenerator {
    obstacleSetup : ObstacleSetup
    def abstract hasObstacle(global_ring_id, row_id : int) : bool
}

enum GameState {
    Ready // To not reload game until it's started when kicking reload multiple times.
    Running
    Over
}
var gameState : GameState = GameState.Over

var player : PlayerState = PlayerState()
var world : WorldState = WorldState()

// var statusTextNode : NodeId
var renderSettingsNode : NodeId
var gameSceneNode : NodeId


def eucl_mod(a, b) {
    return ((a % b) + b) % b
}

def get_player_distance_to_row(row_id : int) {
    let rowCoord = float(row_id) + 0.5
    let diff = player.curRow - rowCoord
    let fRowCount = float(world.setup.rowCount)
    return abs(diff - fRowCount * round(diff / fRowCount))
}

def init_rings() {
    var tilesNode = create_node(NodeData(name = "tiles", parent = gameSceneNode))
    world.tileRings.clear()
    world.tileRings.resize(world.setup.ringCount)
    for (ringId in range(world.setup.ringCount)) {
        for (rowId in range(world.setup.rowCount)) {
            let tileNode = create_node(NodeData(name = "tile_{ringId}_{rowId}", parent = tilesNode))
            world.tileRings[ringId].push(Tile(node = tileNode))
        }
    }
}

def get_first_global_ring_id() {
    return int(player.curRing)
}

def get_last_global_ring_id() {
    return get_first_global_ring_id() + world.setup.ringCount - 1
}

def add_or_update_node_mesh(node : NodeId, geometry : MeshGeometry, material : MaterialId) {
    if (node.has_component(type<Mesh>)) {
        get_component(node, $(var mesh : Mesh?) {
            update_mesh(mesh.meshId, geometry)
            mesh.materialId = material
        })
    } else {
        let mesh = create_mesh(geometry)
        node.add_component(new Mesh(meshId = mesh, materialId = material))
    }
}

def add_obstacle(global_ring_id, row_id : int, obstacle_setup : ObstacleSetup) {
    let ringId = eucl_mod(global_ring_id, world.setup.ringCount)

    var obstacleId = -1
    if (world.obstacleFreeIds.length() > 0) {
        obstacleId = world.obstacleFreeIds.back()
        world.obstacleFreeIds.pop()
    } else {
        obstacleId = world.obstacles.length()
        world.obstacles.push(Obstacle())
    }

    var inscope obstacleGeometry : MeshGeometry
    var obstacleMaterial : MaterialId
    if (obstacle_setup.obstacleType == ObstacleType.Small) {
        obstacleGeometry <- make_small_obstacle_geometry(world, global_ring_id, row_id)
        obstacleMaterial = smallObstacleMaterial
    } elif (obstacle_setup.obstacleType == ObstacleType.Medium) {
        obstacleGeometry <- make_medium_obstacle_geometry(world, global_ring_id, row_id)
        obstacleMaterial = mediumObstacleMaterial
    }

    var obstacleNode = world.obstacles[obstacleId].node
    if (!obstacleNode) {
        obstacleNode = create_node(NodeData(name = "obstacle", parent = world.obstaclesNode))
    }
    obstacleNode.isActive = true

    add_or_update_node_mesh(obstacleNode, obstacleGeometry, obstacleMaterial)

    world.obstacles[obstacleId].setup = obstacle_setup
    world.obstacles[obstacleId].node = obstacleNode
    world.tileRings[ringId][row_id].obstacleId = obstacleId

    obstacleNode?.Mesh.setPerInstanceData(float4(obstacle_setup.color, 1.0), float4(0, 0, 0.5, 1))

    return obstacleId
}

def remove_obstacle(obstacle_id : int) {
    world.obstacles[obstacle_id].node.isActive = false
    world.obstacleFreeIds.push(obstacle_id)
}

def update_tile_mesh(global_ring_id, row_id : int) {
    let ringId = eucl_mod(global_ring_id, world.setup.ringCount)

    let tileEffect = world.tileRings[ringId][row_id].effect
    var inscope tileGeometry : MeshGeometry
    var tileMaterial : MaterialId

    tileGeometry <- make_empty_tile_geometry(world, global_ring_id, row_id)

    if (tileEffect == TileEffect.BonusHealth) {
        tileMaterial = hpBonusMaterial
    } else {
        tileMaterial = emptyTileMaterial
    }

    add_or_update_node_mesh(world.tileRings[ringId][row_id].node, tileGeometry, tileMaterial)
}

def move_player(dt : float) {
    let sensitivityMul = exp2((userSettings.inputSensitivity - 0.5) * 4.0)
    let turnInput = (\
        get_action_vector2("turn_mouse").x * mouseSensitivity / dt + \
        get_action_vector2("turn_stick").x * stickSensitivity + \
        get_action_axis("turn_button") * buttonSensitivity) * sensitivityMul

    if (userSettings.turnMode == TurnMode.Inertial) {
        player.turnSpeed += turnInput * dt
    } else {
        player.turnSpeed = approach(player.turnSpeed, turnInput, dt, 0.05)
    }

    player.prevRow = player.curRow
    player.prevRing = player.curRing
    player.curRow += player.turnSpeed * dt
    player.curRing += player.setup.forwardSpeed * dt
}

def reset_tile(global_ring_id, row_id : int) {
    let ringId = eucl_mod(global_ring_id, world.setup.ringCount)
    world.tileRings[ringId][row_id] = Tile(node = world.tileRings[ringId][row_id].node)
}

def process_collisions() {
    // TODO: Make going out of bounds to be a game loss if edges aren't connected.
    // player.curRow = clamp(player.curRow, 0.0, float(world.setup.rowCount))
    player.curRow = fract(player.curRow / float(world.setup.rowCount)) * float(world.setup.rowCount)
    // Somehow the above operation can result in curRow being >= 18.0. This is a workaround.
    if (player.curRow >= float(world.setup.rowCount)) {
        player.curRow = 0.0
    }

    let globalRingId = int(player.curRing + player.setup.hitDistance)
    let ringId = eucl_mod(globalRingId, world.setup.ringCount)
    let rowId = int(player.curRow)
    let obstacleId = world.tileRings[ringId][rowId].obstacleId
    let hasObstacle = obstacleId >= 0
    let tileObstacleType = hasObstacle ? world.obstacles[obstacleId].setup.obstacleType : ObstacleType.None
    let tileEffect = world.tileRings[ringId][rowId].effect

    var hitAmount = 0.0
    if (tileObstacleType == ObstacleType.Small) {
        hitAmount = 0.5
    }
    elif (tileObstacleType == ObstacleType.Medium) {
        hitAmount = 1.0
    }
    elif (tileObstacleType == ObstacleType.Big) {
        hitAmount = 2.0
    }
    elif (tileObstacleType == ObstacleType.Fatal) {
        hitAmount = player.hitPoints
    }

    player.hitPoints -= hitAmount

    if (tileEffect == TileEffect.BonusHealth) {
        if (player.hitPoints < player.setup.maxHitPoints) {
            play_game_sound(pickupSound)
        }
        player.hitPoints += 1.0
    }

    player.hitPoints = clamp(player.hitPoints, 0.0, player.setup.maxHitPoints)

    if (hasObstacle) {
        remove_obstacle(obstacleId)
        play_game_sound(hitSound)
    }

    reset_tile(globalRingId, rowId)

    if (player.hitPoints == 0.0) {
        gameState = GameState.Over
    }
}

def update_world() {
    let globalRingIdFrom = int(floor(player.prevRing)) + world.setup.ringCount
    let globalRingIdTo = int(floor(player.curRing)) + world.setup.ringCount
    for (globalRingId in range(globalRingIdFrom, globalRingIdTo)) {
        let ringId = eucl_mod(globalRingId, world.setup.ringCount)
        for (rowId in range(world.setup.rowCount)) {
            let obstacleId = world.tileRings[ringId][rowId].obstacleId
            if (obstacleId >= 0) {
                remove_obstacle(obstacleId)
            }
            reset_tile(globalRingId, rowId)

            let randVal = random_float()
            let skipTile = (globalRingId < world.setup.playerRowObstaclesBeginAtDist && rowId == 0) || \
                globalRingId < world.setup.obstaclesBeginAtDist
            var obstacleType = ObstacleType.None
            if (!skipTile) {
                let smallObstacleProb = 0.02 * exp2(float(globalRingId) * world.setup.obstacleIncreaseTwicePeriodInv)
                let mediumObstacleProb = 0.02 * exp2(float(globalRingId) * world.setup.obstacleIncreaseTwicePeriodInv)
                let obstacleProb = smallObstacleProb + mediumObstacleProb
                let hpProb = 0.002

                let smallObstacleDelim = smallObstacleProb / obstacleProb * min(1.0, obstacleProb)
                let mediumObstacleDelim = smallObstacleDelim + mediumObstacleProb / obstacleProb * min(1.0, obstacleProb)
                let hpDelim = mediumObstacleDelim + hpProb

                if (randVal < smallObstacleDelim) {
                    obstacleType = ObstacleType.Small
                } elif (randVal < mediumObstacleDelim) {
                    obstacleType = ObstacleType.Medium
                } elif (randVal < hpDelim) {
                    world.tileRings[ringId][rowId].effect = TileEffect.BonusHealth
                }
            }

            if (obstacleType != ObstacleType.None) {
                let obstacleSetup = ObstacleSetup(obstacleType = obstacleType, color = obstacleColorTable[random_int() % obstacleColorTable.length()])
                add_obstacle(globalRingId, rowId, obstacleSetup)
            }

            world.tubeCurveGenerator.advance(float(globalRingId + 1))
            update_tile_mesh(globalRingId, rowId)
        }
    }
}

def update_lighting() {
    get_component(renderSettingsNode, $(var fog : DistanceFog?) {
        fog.color = float4(world.fogColor, 1.0)
        fog.startDistance = world.fogStartDistance
    })

    get_component(renderSettingsNode, $(var ambient : AmbientSettings?) {
        ambient.ambientColor = world.fogColor
    })

    get_component(player.cameraNode, $(var cam : Camera?) {
        cam.backgroundColor = world.fogColor
    })
}

def paint_tiles() {
    let lastGlobalRingId = get_last_global_ring_id()
    var trailPos = world.setup.obstacleTrailLength
    var trailColor = float3(0, 0, 0)

    for (rowId in range(world.setup.rowCount)) {
        var lastObstaclePos = lastGlobalRingId
        let distToRow = get_player_distance_to_row(rowId)
        for (i in range(world.setup.ringCount)) {
            let globalRingId = lastGlobalRingId - i
            let ringId = eucl_mod(globalRingId, world.setup.ringCount)

            let obstacleId = world.tileRings[ringId][rowId].obstacleId
            if (obstacleId >= 0) {
                trailPos = 0
                trailColor = world.obstacles[obstacleId].setup.color
                lastObstaclePos = globalRingId
            }

            let trailAmount = 1.0 - float(trailPos) / float(world.setup.obstacleTrailLength)
            let distToObstacle = float(lastObstaclePos) - player.curRing
            let warnColorAmount = (1.0 - saturate(distToRow - 0.5)) * saturate(1.0 - distToObstacle / float(world.setup.obstacleWarnDist))

            let tileNode = world.tileRings[ringId][rowId].node
            let tileEffect = world.tileRings[ringId][rowId].effect
            let addColor = (globalRingId & 1) > 0 ? float3(0.1) : float3(0.0)
            var tileRenderColor = world.tileRings[ringId][rowId].color + addColor
            if (trailPos < world.setup.obstacleTrailLength) {
                let trailRenderColor = lerp(trailColor, world.setup.obstacleWarnColor, warnColorAmount)
                tileRenderColor = lerp(tileRenderColor, trailRenderColor, trailAmount)
            }

            tileRenderColor = tileEffect == TileEffect.None ? tileRenderColor : float3(1.0, 1.0, 1.0)
            tileNode?.Mesh.setPerInstanceData(float4(tileRenderColor, 1.0), float4(0, 0, 1, 1))

            trailPos += 1
        }
    }
}

def update_player_camera() {
    var surfacePos : float3
    var surfaceNorm : float3
    var surfaceDir : float3
    get_world_position_normal_at_grid_pos(world, player.curRow, player.curRing, surfacePos, surfaceNorm)
    get_world_direction_at_grid_pos(world, player.curRow, player.curRing, surfaceDir)

    let rightVector = normalize(cross(surfaceNorm, surfaceDir))
    let upVector = normalize(cross(surfaceDir, rightVector))
    let forwardVector = normalize(surfaceDir)
    player.cameraNode.worldPosition = surfacePos + surfaceNorm * player.setup.cameraHeight
    player.cameraNode.worldRotation = quat4(rightVector, upVector, forwardVector)
}

def init_game() {
    player = PlayerState()
    world = WorldState()

    assert(!gameSceneNode)
    gameSceneNode = create_node(NodeData(name = "game_scene"))
    renderSettingsNode = create_render_settings()
    renderSettingsNode.parent = gameSceneNode // For scene clearing.

    get_component(renderSettingsNode, $(var fog : DistanceFog?) {
        fog.active = true
        fog.density = 0.04
        fog.mode = DistanceFogMode.ExponentialSquared
    })

    get_component(renderSettingsNode, $(var ambient : AmbientSettings?) {
        ambient.ambientSource = AmbientSource.ConstColor
    })

    get_component(renderSettingsNode, $(var sky : Sky?) {
        sky.active = false
    })

    get_component(renderSettingsNode, $(var ssao : SSAOSettings?) {
        ssao.active = false
    })

    player.cameraNode = create_node(NodeData(name = "camera", parent = gameSceneNode))
    player.cameraNode.add_component(new Camera(fovAxis = FovAxis.Horizontal, fov = TO_RAD * 90f, zfar = 1000.0))

    world.obstaclesNode = create_node(NodeData(name = "obstacles", parent = gameSceneNode))

    init_rings()
    update_world()
    update_lighting()
    paint_tiles()
    update_player_camera()
}

def clear_scene_fully() {
    // Meshes remain uncleared. Have to live with that for now.
    if (!gameSceneNode) {
        return
    }
    remove_node(gameSceneNode)
    gameSceneNode = NodeId()
}

def public kick_game_reload() {
    if (gameState == GameState.Ready) {
        return
    }
    clear_scene_fully()
    init_game()
    gameState = GameState.Ready
}

def public update_game() {
    if (gameState != GameState.Running) {
        kick_game_reload()
    }
    gameState = GameState.Running

    let dt = get_delta_time()

    move_player(dt)
    process_collisions()
    update_world()
    update_lighting()
    paint_tiles()
    update_player_camera()

    return gameState == GameState.Over
}

def public get_current_score() {
    return int(player.curRing)
}

def public get_current_hp() {
    return player.hitPoints
}
