require engine.core

let orthographicSize = 8.0
let grid = float2(6)
let resolutionCoeff = 16.0 / 9.0
let cellSize = orthographicSize * float2(1., 1. / resolutionCoeff) / float2(grid)
let cellGraphSize = 0.25
let cellBallSize = 0.05
let cellGraphOffset = float2(-cellGraphSize * 0.5, -cellGraphSize * 0.5 * resolutionCoeff)
let cellBallStartOffset = float2(cellGraphSize, -cellGraphSize * 0.5 * resolutionCoeff)
let cellControlBallOffset = float2(-cellGraphSize * 0.5, -cellGraphSize * resolutionCoeff * 0.8 - cellBallSize * 0.5)
let maxAnimTime = 2.

var canvas : UICanvas?

struct CellAnim {
    easingBall : NodeId
    controlBall : NodeId
    vertStick : NodeId
    horStick : NodeId
    easingFn : function<(p : float) : float const> <- @@linear
    centerPos : float3
}

var cellAnims : array<CellAnim>


def create_easing_graph_mesh(easingFn : function<(p : float) : float const>) : MeshId {
    var points : array<float3>
    for (i in range(0, 1001)) {
        let p = float(i) / 1000.0
        let point = float3(p, easingFn(p), -1.)
        push(points, point)
    }
    var polygonPoints <- [
        float2(-0.01, -0.01),
        float2(-0.01, 0.01),
        float2(0.01, 0.01),
        float2(0.01, -0.01),
    ]
    var extruderMesh = create_extruder_mesh(ExtruderInit(
        polygonPoints <- polygonPoints,
        points <- points,
        bendRadius = 0.
    ))
    return <- extruderMesh
}


def create_easing_cell(easingFn : function<(p : float) : float const>, name : string, gridPos : int2) {
    let centerPos = float3((float2(gridPos) - (grid - float2(1.)) * 0.5) * cellSize, 0.)

    // Graph node
    let graphNode = create_node(NodeData(
        position = centerPos + float3(cellGraphOffset * cellSize, 0.),
        scale = float3(cellGraphSize * cellSize.x)
    ))
    let graphMesh = create_easing_graph_mesh(easingFn)
    add_component(graphNode, new Mesh(
        meshId = graphMesh,
        color = RED_COLOR,
    ))

    // Easing ball node
    let ballNode = create_node(NodeData(
        position = centerPos + float3(cellBallStartOffset * cellSize, 0.),
        scale = float3(cellBallSize)
    ))
    add_component(ballNode, new Mesh(meshId = SPHERE_MESH_ID, color = YELLOW_COLOR))

    //Control ball node
    let controlBallNode = create_node(NodeData(
        position = centerPos + float3(cellControlBallOffset * cellSize, 0.),
        scale = float3(cellBallSize)
    ))
    add_component(controlBallNode, new Mesh(meshId = SPHERE_MESH_ID, color = GREEN_COLOR))

    // Vertical stick node
    let vertStickNode = create_node(NodeData(
        position = centerPos + float3(cellControlBallOffset.x * cellSize.x, 0.5 * (cellControlBallOffset.y + cellGraphOffset.y) * cellSize.y, 0.),
        scale = float3(0.005, (cellGraphOffset.y - cellControlBallOffset.y) * cellSize.y, 0.005)
    ))
    add_component(vertStickNode, new Mesh(meshId = CUBE_MESH_ID, color = float4(0.4, 0.4, 0.4, 1.)))

    // Horizontal stick node
    let horStickNode = create_node(NodeData(
        position = centerPos + float3(0.5 * (cellBallStartOffset.x + cellGraphOffset.x) * cellSize.x, cellBallStartOffset.y * cellSize.y, 0.),
        scale = float3((cellBallStartOffset.x - cellGraphOffset.x) * cellSize.x, 0.005, 0.005)
    ))
    add_component(horStickNode, new Mesh(meshId = CUBE_MESH_ID, color = float4(0.5, 0.5, 0.5, 1.)))

    //Vertical axis node
    let vertAxisNode = create_node(NodeData(
        position = centerPos + float3(cellBallStartOffset.x * cellSize.x, 0., 0.),
        scale = float3(0.005, cellGraphSize * cellSize.x, 0.005)
    ))
    add_component(vertAxisNode, new Mesh(meshId = CUBE_MESH_ID))

    // Horizontal axis node
    let horAxisNode = create_node(NodeData(
        position = centerPos + float3(0., cellControlBallOffset.y * cellSize.y, 0.),
        scale = float3(cellGraphSize * cellSize.x, 0.005, 0.005)
    ))
    add_component(horAxisNode, new Mesh(meshId = CUBE_MESH_ID))

    // Label node
    let labelNode = create_node(NodeData(parent = canvas.nodeId, name = "lbl_{gridPos.x}_{gridPos.y}"))
    add_component(labelNode, new UIText(text = name, fontSize = 12., color = WHITE_COLOR))
    let anchorX = (float(gridPos.x) + 0.5) / float(grid.x)
    let anchorY = 0.85 - float(gridPos.y) / float(grid.y)
    add_component(labelNode, new UIAnchor(
        anchorMin = float2(anchorX, anchorY),
        anchorMax = float2(anchorX, anchorY),
    ))

    // Animate ball
    let cellAnim = CellAnim(
        easingBall = ballNode,
        controlBall = controlBallNode,
        vertStick = vertStickNode,
        horStick = horStickNode,
        easingFn = easingFn,
        centerPos = centerPos
    )
    push(cellAnims, cellAnim)
}


[export]
def on_initialize() {
    let uiRoot = create_node(NodeData(name = "canvas"))
    canvas = add_component(uiRoot, new UICanvas(screenMode = ScreenMode.Custom))

    // Row-major order
    create_easing_cell(@@inQuad, "inQuad", int2(0, 5))
    create_easing_cell(@@outQuad, "outQuad", int2(1, 5))
    create_easing_cell(@@inOutQuad, "inOutQuad", int2(2, 5))
    create_easing_cell(@@inCubic, "inCubic", int2(3, 5))
    create_easing_cell(@@outCubic, "outCubic", int2(4, 5))
    create_easing_cell(@@inOutCubic, "inOutCubic", int2(5, 5))

    create_easing_cell(@@inQuart, "inQuart", int2(0, 4))
    create_easing_cell(@@outQuart, "outQuart", int2(1, 4))
    create_easing_cell(@@inOutQuart, "inOutQuart", int2(2, 4))
    create_easing_cell(@@inQuintic, "inQuintic", int2(3, 4))
    create_easing_cell(@@outQuintic, "outQuintic", int2(4, 4))
    create_easing_cell(@@inOutQuintic, "inOutQuintic", int2(5, 4))

    create_easing_cell(@@inSine, "inSine", int2(0, 3))
    create_easing_cell(@@outSine, "outSine", int2(1, 3))
    create_easing_cell(@@inOutSine, "inOutSine", int2(2, 3))
    create_easing_cell(@@inCirc, "inCirc", int2(3, 3))
    create_easing_cell(@@outCirc, "outCirc", int2(4, 3))
    create_easing_cell(@@inOutCirc, "inOutCirc", int2(5, 3))

    create_easing_cell(@@inExp, "inExp", int2(0, 2))
    create_easing_cell(@@outExp, "outExp", int2(1, 2))
    create_easing_cell(@@inOutExp, "inOutExp", int2(2, 2))
    create_easing_cell(@@inElastic, "inElastic", int2(3, 2))
    create_easing_cell(@@outElastic, "outElastic", int2(4, 2))
    create_easing_cell(@@inOutElastic, "inOutElastic", int2(5, 2))

    create_easing_cell(@@inBack, "inBack", int2(0, 1))
    create_easing_cell(@@outBack, "outBack", int2(1, 1))
    create_easing_cell(@@inOutBack, "inOutBack", int2(2, 1))
    create_easing_cell(@@inBounce, "inBounce", int2(3, 1))
    create_easing_cell(@@outBounce, "outBounce", int2(4, 1))
    create_easing_cell(@@inOutBounce, "inOutBounce", int2(5, 1))

    create_easing_cell(@@inOutBezier, "inOutBezier", int2(0, 0))
    create_easing_cell(@@cosineFull, "cosineFull", int2(1, 0))
    create_easing_cell(@@inStep, "inStep", int2(2, 0))
    create_easing_cell(@@outStep, "outStep", int2(3, 0))
    create_easing_cell(@@smoothStartArch3, "smoothStartArch3", int2(4, 0))
    create_easing_cell(@@smoothStopArch3, "smoothStopArch3", int2(5, 0))

    let camera = create_node(NodeData(position = float3(0, 0, -5)))
    add_component(camera, new Camera(orthographic = true, fovAxis = FovAxis.Horizontal, orthographicSize = 8f, fov = TO_RAD * 90f))

    let sun = create_node()
    add_component(sun, new DirectionLight())

    for (x in range(0, int(grid.x) + 1)) {
        let pos = float3((float(x) - grid.x * 0.5) * cellSize.x, 0, 0)
        let node = create_node(NodeData(position = pos, scale = float3(0.005, cellSize.y * grid.y, 0.005)))
        add_component(node, new Mesh(meshId = CUBE_MESH_ID))
    }
    for (y in range(0, int(grid.y) + 1)) {
        let pos = float3(0, (float(y) - grid.y * 0.5) * cellSize.y, 0)
        let node = create_node(NodeData(position = pos, scale = float3(cellSize.x * grid.x, 0.005, 0.005)))
        add_component(node, new Mesh(meshId = CUBE_MESH_ID))
    }
}


[export]
def on_update() {
    let t = (get_time() / maxAnimTime) % 1.

    for (cellAnim in cellAnims) {
        let easing = cellAnim.easingFn
        let easedT = easing(t)
        let startY = cellBallStartOffset.y
        let endY = -cellBallStartOffset.y
        let ballPos = cellAnim.centerPos + float3(cellBallStartOffset.x * cellSize.x, lerp(startY, endY, easedT) * cellSize.y, 0.)
        cellAnim.easingBall.localPosition = ballPos

        let startX = cellGraphOffset.x * cellSize.x
        let endX = cellGraphOffset.x * cellSize.x + cellGraphSize * cellSize.x
        let controlBallPos = cellAnim.centerPos + float3(lerp(startX, endX, t), cellControlBallOffset.y * cellSize.y, 0.)
        cellAnim.controlBall.localPosition = controlBallPos

        let vertStickPos = float3(controlBallPos.x, cellAnim.centerPos.y + 0.5 * (cellControlBallOffset.y + cellGraphOffset.y) * cellSize.y + 0.5 * easedT * cellGraphSize * cellSize.x, 0.)
        let vertStickScaleY = (cellGraphOffset.y - cellControlBallOffset.y) * cellSize.y + easedT * cellGraphSize * cellSize.x
        cellAnim.vertStick.localPosition = vertStickPos
        cellAnim.vertStick.localScale = float3(0.005, vertStickScaleY, 0.005)

        let horStickPos = float3(cellAnim.centerPos.x + 0.5 * (cellBallStartOffset.x + cellGraphOffset.x + t * cellGraphSize) * cellSize.x, ballPos.y, 0.)
        let horStickScaleX = (cellBallStartOffset.x - cellGraphOffset.x - t * cellGraphSize) * cellSize.x
        cellAnim.horStick.localPosition = horStickPos
        cellAnim.horStick.localScale = float3(horStickScaleX, 0.005, 0.005)
    }
}


[export]
def on_resolution_changed(res : int2) {
    canvas.size = float(res.x) * float2(1., 1. / resolutionCoeff)
}
