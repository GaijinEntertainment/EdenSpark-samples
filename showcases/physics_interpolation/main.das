require engine.core
require math

var cameraNode : NodeId
var flyTime : float = -1.0
var ballNoPhys : NodeId

let camZ = -50f
let moveSpeed = 100f
let trackLength = 100f


class BallTag : Component {}

[export]
def on_initialize() {
    cameraNode = create_node(NodeData(position = float3(0f, 0f, camZ)))
    add_component(cameraNode, new Camera())
    let renderSettings = create_render_settings()
    (get_component(renderSettings, type<ShadowSettings>)).active = false

    let sunDirection = float3(PI / 3.0, -PI / 3.0, 0f)
    let sun = create_node(NodeData(rotation = quat4(sunDirection)))
    add_component(sun, new DirectionLight())

    let barrierStart = create_node(NodeData(position = float3(-10, 0, 0), scale = float3(10, 100, 10)))
    add_component(barrierStart, new Mesh(meshId = CUBE_MESH_ID))
    add_component(barrierStart, new Collider(shape = box_shape(), restitution = 1f))

    let barrierEnd = create_node(NodeData(position = float3(trackLength + 10.0, 0.0, 0.0), scale = float3(10, 100, 10)))
    add_component(barrierEnd, new Mesh(meshId = CUBE_MESH_ID))
    add_component(barrierEnd, new Collider(shape = box_shape(), restitution = 1f))

    let ball1 = create_node(NodeData(position = float3(0., -18., 0.), scale = float3(10)))
    add_component(ball1, new Mesh(meshId = SPHERE_MESH_ID))
    add_component(ball1, new RigidBody(useGravity = false, linearDamping = 0f, interpolation = Interpolation.None))
    add_component(ball1, new Collider(shape = sphere_shape(), restitution = 1f))
    add_component(ball1, new BallTag())

    let text1 = create_node(NodeData(position = float3(1.75, 0.0, 0.0), parent = ball1))
    add_component(text1, new Text3D(text = "Interpolation None", color = float4(0, 0, 0, 1), useDepthScale = false))

    let ball2 = create_node(NodeData(position = float3(0., -6., 0.), scale = float3(10)))
    add_component(ball2, new Mesh(meshId = SPHERE_MESH_ID))
    add_component(ball2, new RigidBody(useGravity = false, linearDamping = 0f, interpolation = Interpolation.Interpolate))
    add_component(ball2, new Collider(shape = sphere_shape()))
    add_component(ball2, new BallTag())

    let text2 = create_node(NodeData(position = float3(1.75, 0.0, 0.0), parent = ball2))
    add_component(text2, new Text3D(text = "Interpolation Interpolate", color = float4(0, 0, 0, 1), useDepthScale = false))

    let ball3 = create_node(NodeData(position = float3(0., 6., 0.), scale = float3(10)))
    add_component(ball3, new Mesh(meshId = SPHERE_MESH_ID))
    add_component(ball3, new RigidBody(useGravity = false, linearDamping = 0f, interpolation = Interpolation.Extrapolate))
    add_component(ball3, new Collider(shape = sphere_shape(), restitution = 1f))
    add_component(ball3, new BallTag())

    let text3 = create_node(NodeData(position = float3(1.75, 0.0, 0.0), parent = ball3))
    add_component(text3, new Text3D(text = "Interpolation Extrapolate", color = float4(0, 0, 0, 1), useDepthScale = false))

    let ball4 = create_node(NodeData(position = float3(0., 18., 0.), scale = float3(10)))
    add_component(ball4, new Mesh(meshId = SPHERE_MESH_ID))
    ballNoPhys = ball4

    let text4 = create_node(NodeData(position = float3(1.75, 0.0, 0.0), parent = ball4))
    add_component(text4, new Text3D(text = "No physics", color = float4(0, 0, 0, 1), useDepthScale = false))

    set_target_fps(60.)
    set_physics_fps(70.)

    create_debug_text("Press Space (or A on gamepad) to push objects\nPress R (or Y on gamepad) to restart", float2(20, -20), BOTTOM_LEFT_ANCHOR)

    add_and_activate_action_set("basic", {
        "pushBalls" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        ),
        "resetBalls" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.R)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Y)]
            )
        )
    })
}


def cameraBounce(x, maxVal) {
    if (x < 0f) {
        return 0f
    }
    let a = fract(x / maxVal) * maxVal
    if (int(x / maxVal) % 2 == 0) {
        return a
    }
    return maxVal - a
}


[export]
def on_update() {
    let dt = get_delta_time()

    if (is_action_just_pressed("pushBalls")) {
        for (ballTag in find_components(type<BallTag>)) {
            ballTag.nodeId.localPosition = float3(0f, ballTag.nodeId.localPosition.yz)
            ballTag.nodeId?.RigidBody.velocity = float3(moveSpeed, 0f, 0f)
        }
        flyTime = 0.0
    }

    if (is_action_just_pressed("resetBalls")) {
        for (ballTag in find_components(type<BallTag>)) {
            ballTag.nodeId.localPosition = float3(0f, ballTag.nodeId.localPosition.yz)
            ballTag.nodeId?.RigidBody.velocity = float3(0)
        }
        flyTime = -1f
    }

    cameraNode.localPosition = float3(cameraBounce(flyTime * moveSpeed, trackLength), 0., camZ)
    ballNoPhys.localPosition = float3(cameraBounce(flyTime * moveSpeed, trackLength), 18., 0.)
    if (flyTime < 0.) {
        return
    }
    flyTime += dt
}
