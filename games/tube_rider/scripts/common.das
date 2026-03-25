require engine.core
require tube_curve_generator

// Should be private, but das can't handle that.
let defRowCount = 18
let defRingCount = 100
let defTubeCurveRingCount = defRingCount + 2
let defTubeCurveRingsPerSegment = 10

enum TileEffect : uint8 {
    None,
    BonusHealth,
    BonusBlast,
    BonusSlowDown,
    DebuffColorBlindness,
    DebuffInstability
}

enum ObstacleType : uint8 {
    None,
    Small,
    Medium,
    Big,
    Fatal
}

struct PlayerSetup {
    forwardSpeed : float = 15.0
    maxHitPoints : float = 5.0
    hitDistance : float = 0.2
    cameraHeight : float = 0.5
}

struct PlayerState {
    setup : PlayerSetup = PlayerSetup()
    cameraNode : NodeId
    curRow : float = 0.5
    prevRow : float = 0.5
    curRing : float = 0.0
    prevRing : float = -float(defRingCount)
    hitPoints : float = 1.0
    turnSpeed : float = 0.0
}

struct WorldSetup {
    rowCount : int = defRowCount
    ringCount : int = defRingCount
    tileSize : float3 = float3(1, 1, 1)
    obstacleTrailLength : int = 30
    obstacleWarnDist : int = 0 // Not needed for now.
    obstacleWarnColor : float3 = float3(1, 0, 0)
    obstacleIncreaseTwicePeriodInv : float = 1.0 / 3000.0
    obstaclesBeginAtDist : int = 5
    playerRowObstaclesBeginAtDist : int = 20
}

struct ObstacleSetup {
    obstacleType : ObstacleType
    color : float3
}

struct Obstacle {
    setup : ObstacleSetup = ObstacleSetup()
    node : NodeId
}

struct Tile {
    node : NodeId
    obstacleId : int = -1
    effect : TileEffect = TileEffect.None
    color : float3 = float3(0, 0, 0)
}

struct WorldState {
    setup : WorldSetup = WorldSetup()
    tubeCurveGenerator = TubeCurveGenerator(defTubeCurveRingCount, defTubeCurveRingsPerSegment)
    geometryNode : NodeId
    tileRings : array<array<Tile>>
    obstacles : array<Obstacle>
    obstacleFreeIds : array<int>
    obstaclesNode : NodeId
    fogColor : float3 = float3(1, 0.8, 0.6)
    fogStartDistance : float = 0.0
}

def get_world_position_normal_at_grid_pos(world : WorldState, row_pos, ring_pos : float, var pos, norm : float3&) {
    let orientation = 1.0
    let angle = float(row_pos) / float(world.setup.rowCount) * 2.0 * PI * orientation
    let radius = world.setup.tileSize.x / (2.0 * sin(PI / float(world.setup.rowCount)))
    let dir = float2(cos(angle), sin(angle))

    let tubeTransform = world.tubeCurveGenerator.getCenterTransformAtDistance(ring_pos)

    norm = tubeTransform.rot * -(RIGHT * dir.x + UP * dir.y)
    pos = -norm * radius + tubeTransform.pos
}

def get_world_direction_at_grid_pos(world : WorldState, row_pos, ring_pos : float, var dir : float3&) {
    let tubeTransform = world.tubeCurveGenerator.getCenterTransformAtDistance(ring_pos)
    dir = tubeTransform.rot * FORWARD
}
