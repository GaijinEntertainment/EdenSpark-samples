require engine.core
require engine.free_camera

var camera : NodeId
var statusNode : NodeId


let activeColor = color32_to_float4(0xffffff00)
let reactiveColor = color32_to_float4(0xff303030)
let textColor = color32_to_float4(0xffffffff)
let textColorDark = color32_to_float4(0xff000000)

[export] def on_initialize() {
    statusNode = create_debug_text(float2(20, 20), TOP_LEFT_ANCHOR)

    init_scene()
    init_collision_layers()
    init_input()
    startSample(curSampleIdx)

    set_physics_fps(100f)
}

var curSampleRoot : NodeId
var curSampleIdx = 1

def startSample(sampleIdx) {
    if (curSampleRoot != NodeId()) {
        remove_node(curSampleRoot)
    }
    curSampleRoot = create_node(NodeData(name = "sample"))
    curSampleIdx = sampleIdx
    match (curSampleIdx) {
        if (1) { add_component(curSampleRoot, new DampingRestitutionSample()); }
        if (2) { add_component(curSampleRoot, new CollisionShapesSample()); }
        if (3) { add_component(curSampleRoot, new CollisionLayersSample()); }
        if (4) { add_component(curSampleRoot, new ShapeQueryVoxelsSample()); }
        if (5) { add_component(curSampleRoot, new RaycastSample()); }
        if (6) { add_component(curSampleRoot, new ChainsSample()); }
        if (7) { add_component(curSampleRoot, new CollisionCallbackSample()); }
        if (8) { add_component(curSampleRoot, new LongChainSample()); }
        if (9) { add_component(curSampleRoot, new ManyBodiesSample()); }
    }
    let x = 1
}

[export]
def on_update() {
    if (is_action_just_pressed("sample1")) { startSample(1); }
    if (is_action_just_pressed("sample2")) { startSample(2); }
    if (is_action_just_pressed("sample3")) { startSample(3); }
    if (is_action_just_pressed("sample4")) { startSample(4); }
    if (is_action_just_pressed("sample5")) { startSample(5); }
    if (is_action_just_pressed("sample6")) { startSample(6); }
    if (is_action_just_pressed("sample7")) { startSample(7); }
    if (is_action_just_pressed("sample8")) { startSample(8); }
    if (is_action_just_pressed("sample9")) { startSample(9); }
    if (is_action_just_pressed("nextSample")) {
        var nextIdx = curSampleIdx + 1
        if (nextIdx > 9) {
            nextIdx = 1
        }
        startSample(nextIdx)
    }
    if (is_action_just_pressed("prevSample")) {
        var prevIdx = curSampleIdx - 1
        if (prevIdx < 1) {
            prevIdx = 9
        }
        startSample(prevIdx)
    }
}


def set_debug_status_string(str) {
    update_debug_text(statusNode, "Select sample: 1-9 (use left/right bumper to navigate if using gamepad)\n[FPS = {1. / get_delta_time()}]\n[{curSampleIdx}] " + str)
}

def init_scene() {
    let scale = float3(400f, 0.1f, 400f)
    let angle = 0f // PI * -0.125f
    let plane = create_node(NodeData(rotation = quat4(0f, 0f, angle), scale = scale))
    add_component(plane, new Mesh(meshId = CUBE_MESH_ID))
    add_component(plane, new Collider(shape = box_shape(scale)))

    let sunDirection = float3(PI / 12f, -PI * 0.25f, 0f)
    let sun = create_node(NodeData(rotation = quat4(sunDirection)))
    add_component(sun, new DirectionLight())

    let renderSettings = create_render_settings()

    get_component(renderSettings) $(var shadow : ShadowSettings?) {
        shadow.powWeight = 0.6f
        shadow.maxDist = 550f
        shadow.numCascades = 4
    }

    toggle_free_camera(camera, float3(0, 80, -100), quat4(float3(PI * 0.15f, 0f, 0f)))
}

enum CollisionLayer {
    Default
    RaycastTarget
    RaycastGhost
    Border = MAX_PHYS_LAYER - 2
    Test1 = MAX_PHYS_LAYER - 1
    Test2 = MAX_PHYS_LAYER
}

var shouldCollideTestCubes = false

def init_collision_layers() {
    set_collision_layer_mask(CollisionLayer.RaycastGhost, 0u)
    set_collision_layer_mask(CollisionLayer.Border, 1u << uint(CollisionLayer.Test1) | 1u << uint(CollisionLayer.Test2))

    set_collision_between_layers(CollisionLayer.Test1, CollisionLayer.Test2, shouldCollideTestCubes)
}

def init_input() {
    add_and_activate_action_set("chooseSample", {
        "sample1" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._1)]
            )
        ),
        "sample2" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._2)]
            )
        ),
        "sample3" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._3)]
            )
        ),
        "sample4" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._4)]
            )
        ),
        "sample5" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._5)]
            )
        ),
        "sample6" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._6)]
            )
        ),
        "sample7" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._7)]
            )
        ),
        "sample8" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._8)]
            )
        ),
        "sample9" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode._9)]
            )
        ),
        "nextSample" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Equals)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.RightBumper)]
            )
        ),
        "prevSample" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Minus)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.LeftBumper)]
            )
        )
    })
}

class CollisionLayersSample : Component {
    def override on_initialize() {
        set_debug_status_string("Collision layers sample\nPress Space (or A on gamepad) to change collision between boxes")

        let node1 = create_node(NodeData(parent = nodeId, position = float3(-5f, 1.5, -1f), scale = float3(3)))
        add_component(node1, new Mesh(meshId = CUBE_MESH_ID, color = activeColor))
        add_component(node1, new RigidBody(linearDamping = 0f, velocity = float3(10, 0, 0), allowedDofs = AllowedDofs.AllowTranslationX | AllowedDofs.AllowTranslationZ))
        add_component(node1, new Collider(shape = box_shape(), friction = 0f, restitution = 1f,  collisionLayer = uint8(CollisionLayer.Test1)))

        let node2 = create_node(NodeData(parent = nodeId, position = float3(5f, 1.5, 0f), scale = float3(3)))
        add_component(node2, new Mesh(meshId = CUBE_MESH_ID, color = activeColor))
        add_component(node2, new RigidBody(linearDamping = 0f, velocity = float3(-10, 0, 0), allowedDofs = AllowedDofs.AllowTranslationX | AllowedDofs.AllowTranslationZ))
        add_component(node2, new Collider(shape = box_shape(), friction = 0f, restitution = 1f, collisionLayer = uint8(CollisionLayer.Test2)))

        let border1 = create_node(NodeData(parent = nodeId, position = float3(-10f, 1.5, 0f), scale = float3(3, 3, 6)))
        add_component(border1, new Mesh(meshId = CUBE_MESH_ID, color = reactiveColor))
        add_component(border1, new Collider(shape = box_shape(), collisionLayer = uint8(CollisionLayer.Border)))

        let border2 = create_node(NodeData(parent = nodeId, position = float3(10f, 1.5, 0f), scale = float3(3, 3, 6)))
        add_component(border2, new Mesh(meshId = CUBE_MESH_ID, color = reactiveColor))
        add_component(border2, new Collider(shape = box_shape(), collisionLayer = uint8(CollisionLayer.Border)))

        add_and_activate_action_set("collisionLayers", {
            "toggleCollision" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
                )
            )
        })
    }

    def override on_update() {
        if (is_action_just_pressed("toggleCollision")) {
            shouldCollideTestCubes = !shouldCollideTestCubes
            set_collision_between_layers(CollisionLayer.Test1, CollisionLayer.Test2, shouldCollideTestCubes)
        }
    }
}

class DampingRestitutionSample : Component {
    ball : NodeId
    def override on_initialize() {
        set_debug_status_string("Damping and Restitution Sample\nPress arrows to move the ball\nPress G (or Y on gamepad) to flip gravity")

        for (i in -5 .. 5) {
            for (j in -5 .. 5) {
                let iValue = float(i + 6) / 10f
                let jValue = float(j + 6) / 10f
                let node = create_node(NodeData(parent = nodeId, position = float3(float(i) * 5f, 20f, float(j) * 5f), name = "ball", scale = float3(2.)))
                add_component(node, new Mesh(meshId = SPHERE_MESH_ID, color = reactiveColor))

                add_component(node, new RigidBody(linearDamping = iValue))
                add_component(node, new Collider(shape = sphere_shape(), restitution = jValue))
                add_component(node, new Text3D(text = "")) // "{iValue:.1f}x{jValue:.1f}", color = textColor))
            }
        }

        ball = create_node(NodeData(parent = nodeId, position = float3(0, 20, 0), scale = float3(4f), name = "ball"))
        add_component(ball, new Mesh(meshId = SPHERE_MESH_ID, color = activeColor))
        add_component(ball, new Collider(shape = sphere_shape()))
        add_component(ball, new RigidBody())
        add_component(ball, new Text3D(text = "ball", color = textColorDark, fontSize = 32f))

        add_and_activate_action_set("dampingRestitution", {
            "toggleActiveState" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.G)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Y)]
                )
            ),
            "moveUp" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Up)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Up)]
                )
            ),
            "moveDown" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Down)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Down)]
                )
            ),
            "moveLeft" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Left)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Left)]
                )
            ),
            "moveRight" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Right)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Right)]
                )
            )
        })
    }

    def override on_update() {
        get_component(ball) $(var rigidBody : RigidBody?) {
            if (is_action_pressed("moveDown")) {
                apply_rigid_body_impulse(rigidBody, float3(0, 0, -1) * get_delta_time() * 10.)
            }
            if (is_action_pressed("moveUp")) {
                apply_rigid_body_impulse(rigidBody, float3(0, 0, 1) * get_delta_time() * 10.)
            }
            if (is_action_pressed("moveRight")) {
                apply_rigid_body_impulse(rigidBody, float3(1, 0, 0) * get_delta_time() * 10.)
            }
            if (is_action_pressed("moveLeft")) {
                apply_rigid_body_impulse(rigidBody, float3(-1, 0, 0) * get_delta_time() * 10.)
            }
        }

        if (is_action_just_pressed("toggleActiveState")) {
            var cur_grav = get_gravity()
            cur_grav *= -1.0
            set_gravity(cur_grav)

            // wake up all sleeping objects
            for (body in find_components(type<RigidBody>)) {
                body.isSleeping = false
            }
        }
    }
}

class CollisionShapesSample : Component {
    def override on_initialize() {
        set_debug_status_string("Collision shapes")

        let labelsScale = float3(10f)
        let labelsFontSize = 32f

        let nodeSphere = create_node(NodeData(parent = nodeId, position = float3(-30, 10, 0), scale = float3(5.), name = "sphere"))
        add_component(nodeSphere, new Mesh(meshId = SPHERE_MESH_ID, color = reactiveColor))
        add_component(nodeSphere, new RigidBody())
        add_component(nodeSphere, new Collider(shape = sphere_shape()))
        let nodeSphereText = create_node(NodeData(parent = nodeId,
            position = nodeSphere.localPosition + float3(0, 10, 0),
            scale = labelsScale,
            name = "sphere text"
        ))
        add_component(nodeSphereText, new Text3D(text = "Sphere", fontSize = labelsFontSize))

        let nodeCube = create_node(NodeData(parent = nodeId, position = float3(-10, 10, 0), scale = float3(5., 8., 5.), name = "cube"))
        add_component(nodeCube, new Mesh(meshId = CUBE_MESH_ID, color = reactiveColor))
        add_component(nodeCube, new RigidBody())
        add_component(nodeCube, new Collider(shape = box_shape()))
        let nodeCubeText = create_node(NodeData(parent = nodeId,
            position = nodeCube.localPosition + float3(0, 5, 0),
            scale = labelsScale,
            name = "cube text"
        ))
        add_component(nodeCubeText, new Text3D(text = "Box", fontSize = labelsFontSize))

        let nodeCapsule = create_node(NodeData(parent = nodeId, position = float3(10, 10, 0), scale = float3(5.), name = "capsule"))
        add_component(nodeCapsule, new Mesh(meshId = CAPSULE_MESH_ID, color = reactiveColor))
        add_component(nodeCapsule, new RigidBody())
        add_component(nodeCapsule, new Collider(shape = capsule_shape()))
        let nodeCapsuleText = create_node(NodeData(parent = nodeId,
            position = nodeCapsule.localPosition + float3(0, 5, 0),
            scale = labelsScale,
            name = "capsule text"
        ))
        add_component(nodeCapsuleText, new Text3D(text = "Capsule", fontSize = labelsFontSize))

        let nodeCylinder = create_node(NodeData(parent = nodeId, position = float3(30, 10, 0), scale = float3(5.), name = "cylinder"))
        add_component(nodeCylinder, new Mesh(meshId = CYLINDER_MESH_ID, color = reactiveColor))
        add_component(nodeCylinder, new RigidBody())
        add_component(nodeCylinder, new Collider(shape = cylinder_shape()))
        let nodeCylinderText = create_node(NodeData(parent = nodeId,
            position = nodeCylinder.localPosition + float3(0, 5, 0),
            scale = labelsScale,
            name = "cylinder text"
        ))
        add_component(nodeCylinderText, new Text3D(text = "Cylinder", fontSize = labelsFontSize))

        let coneMesh = create_solid_of_revolution_mesh(RevolutionInit(
            points <- array(float2(0, 0), float2(1, 0), float2(0, 2))
        ))

        let externalMesh = request_mesh_from_model("battleaxe.obj", "BattleAxe")
        let externalCollision = request_collision_from_model("battleaxe.obj", "BattleAxe")
        let nodeExternalMesh = create_node(NodeData(parent = nodeId, position = float3(10, 10, 20), scale = float3(1.), name = "external mesh"))
        add_component(nodeExternalMesh, new Mesh(meshId = externalMesh, color = reactiveColor))
        add_component(nodeExternalMesh, new RigidBody())
        add_component(nodeExternalMesh, new Collider(shape = mesh_shape(externalCollision)))
        let nodeExternalMeshText = create_node(NodeData(parent = nodeId,
            position = nodeExternalMesh.localPosition + float3(0, 5, 0),
            scale = labelsScale,
            name = "external mesh text"
        ))
        add_component(nodeExternalMeshText, new Text3D(text = "Mesh (external)", fontSize = labelsFontSize))

        let compoundNode = create_node(NodeData(parent = nodeId, position = float3(50, 10, 0), scale = float3(5., 8., 5.), name = "compound"))
        add_component(compoundNode, new Mesh(meshId = CUBE_MESH_ID, color = reactiveColor))
        add_component(compoundNode, new RigidBody())
        add_component(compoundNode, new Collider(shapes = [
            box_shape(),
            sphere_shape(),
            cylinder_shape(),
            capsule_shape(),
            mesh_shape([mesh = externalCollision]),
        ]))
        let compoundNodeText = create_node(NodeData(parent = nodeId,
            position = compoundNode.localPosition + float3(0, 5, 0),
            scale = labelsScale,
            name = "compound text"
        ))
        add_component(compoundNodeText, new Text3D(text = "Collider", fontSize = labelsFontSize))
    }
}


class ChainsSample : Component {
    chainStart : NodeId

    def override on_initialize() {
        set_debug_status_string("Joints sample\nPress arrows to move")

        let chainPos = float3(0, 50, 0)

        var chains : array<NodeId>

        chainStart = create_node(NodeData(name = "ChainHead", parent = nodeId, position = chainPos, scale = float3(2.5)))
        add_component(chainStart, new Mesh(meshId = SPHERE_MESH_ID, color = activeColor))
        add_component(chainStart, new RigidBody(mass = 100.0, linearDamping = 1.0, allowedDofs = AllowedDofs.AllowTranslationX | AllowedDofs.AllowTranslationZ))
        add_component(chainStart, new Collider(shape = sphere_shape()))
        add_component(chainStart, new SixDofJoint(
            node0 = chainStart,
            limitTranslation = float3(0., 0., 0.),
            limitRotation = deg_to_rad(float3(15., 15., 15.)),
            friction = 0.8,
            frictionTorque = 0.8,
            softTranslationLimit = float2(0., 0.)
        ))

        let chain_length = 5.0
        for (i in range(0, 5)) {
            let newChain = create_node(NodeData(name = "Chain {i}", parent = nodeId, position = chainPos + float3(6f + float(i) * (chain_length + 1.0), 0f, 0f), scale = float3(chain_length + 2f, 1.5f, 1.5f)))
            add_component(newChain, new Mesh(meshId = CUBE_MESH_ID, color = reactiveColor))
            add_component(newChain, new RigidBody())
            add_component(newChain, new Collider(shape = box_shape()))
            push(chains, newChain)

            if (i == 0) {
                get_component(chainStart, type<SixDofJoint>).node1 = newChain
            }
        }

        for (i in range(1, length(chains))) {
            let jointPos = float3(0.5, 0f, 0f) + float3(0.5 / chains[i - 1].localScale.x)

            let joint = create_node(NodeData(
                parent = nodeId,
                name = "Chain Joint",
                position = chains[i - 1].worldPosition + jointPos * chains[i - 1].localScale,
                rotation = quat4(HALF_PI, HALF_PI, 0)
            ))
            // add_component(joint, new SpringJoint(node0 = chains[i - 1], node1 = chains[i]))
            // add_component(joint, new HingeJoint(node0 = chains[i - 1], node1 = chains[i], angle = 15.))
            add_component(joint, new SixDofJoint(node0 = chains[i - 1], node1 = chains[i],
                limitTranslation = float3(0., 0., 0.),
                limitRotation = deg_to_rad(float3(15., 15., 15.)),
                friction = 0.8,
                frictionTorque = 0.8,
                softTranslationLimit = float2(0., 0.)
            ))
        }

        add_and_activate_action_set("chainSample", {
            "chainMoveUp" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Up)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Up)]
                )
            ),
            "chainMoveDown" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Down)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Down)]
                )
            ),
            "chainMoveLeft" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Left)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Left)]
                )
            ),
            "chainMoveRight" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Right)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.Right)]
                )
            )
        })
    }

    def override on_update() {
        var newVelocity = float3()
        if (is_action_pressed("chainMoveDown")) {
            newVelocity += float3(0, 0, -1)
        }
        if (is_action_pressed("chainMoveUp")) {
            newVelocity += float3(0, 0, 1)
        }
        if (is_action_pressed("chainMoveRight")) {
            newVelocity += float3(1, 0, 0)
        }
        if (is_action_pressed("chainMoveLeft")) {
            newVelocity += float3(-1, 0, 0)
        }
        (get_component(chainStart, type<RigidBody>)).velocity = newVelocity * 10.
    }
}


class LongChainSample : Component {
    curChainIdx : int = 2
    curChainLengthIdx : int = 0

    def override on_initialize() {
        genChain()

        add_and_activate_action_set("longChainSample", {
            "toggleJointType" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
                )
            ),
            "toggleChainLength" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Tab)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.B)]
                )
            )
        })
    }

    def override on_update() {
        var change = false
        if (is_action_just_pressed("toggleJointType")) {
            curChainIdx += 1
            if (curChainIdx > 2) {
                curChainIdx = 0
            }
            change = true
        }

        if (is_action_just_pressed("toggleChainLength")) {
            curChainLengthIdx += 1
            if (curChainLengthIdx > 2) {
                curChainLengthIdx = 0
            }
            change = true
        }

        if (change) {
            for (node in get_children(nodeId)) {
                remove_node(node)
            }
            genChain()
        }
    }

    def genChain() {
        let chainsCount = fixed_array(50, 100, 200)[curChainLengthIdx]
        let curJointStr = fixed_array("SpringJoint", "HingeJoint", "SixDofJoint")[curChainIdx]
        set_debug_status_string("Joints sample (stress test)\nPress Space (or A on gamepad) to change joint\nPress Tab (or B on gamepad) to change chains count\nCurrent joint = {curJointStr}, current count = {chainsCount}")

        var prevNode : NodeId
        var chainBound2 : NodeId

        let chainRange = 50.0
        let chainLength = chainRange * 2. / float(chainsCount)
        let posY = 20.

        for (i in range(0, 2)) {
            let chainBound = create_node(NodeData(name = "Bound {i+1}", parent = nodeId, position = float3((chainRange + 0.5) * (i == 0 ? -1. : 1.), posY, 0f)))
            add_component(chainBound, new Mesh(meshId = CUBE_MESH_ID, color = reactiveColor))
            add_component(chainBound, new Collider(shape = box_shape()))
            if (i == 0) {
                prevNode = chainBound
            } else {
                chainBound2 = chainBound
            }
        }

        for (i in range(0, chainsCount)) {
            let posX = -chainRange + chainLength * (float(i) + 0.5)
            let newChain = create_node(NodeData(
                name = "Chain {i + 1}",
                parent = nodeId,
                position = float3(posX, posY, 0f),
                scale = float3(chainLength * 0.9, 1.0f, 1.0f)
            ))

            let joint = create_node(NodeData(
                parent = nodeId,
                name = "Chain Joint {i + 1} {i + 2}",
                position = float3(posX - chainLength * 0.5, posY, 0f),
                rotation = quat4(HALF_PI, HALF_PI, 0.)
            ))

            add_component(newChain, new Mesh(meshId = CUBE_MESH_ID, color = activeColor))
            add_component(newChain, new RigidBody())
            add_component(newChain, new Collider(shape = box_shape()))

            if (curChainIdx == 0) {
                add_component(joint, new SpringJoint(node0 = prevNode, node1 = newChain))
            } elif (curChainIdx == 1) {
                add_component(joint, new HingeJoint(node0 = prevNode, node1 = newChain, angle = 15.))
            } elif (curChainIdx == 2) {
                add_component(joint, new SixDofJoint(node0 = prevNode, node1 = newChain,
                    limitTranslation = float3(0., 0., 0.),
                    limitRotation = deg_to_rad(float3(15., 15., 15.))
                ))
            }
            prevNode = newChain
        }

        let joint = create_node(NodeData(
            parent = nodeId,
            name = "Chain Joint {chainsCount + 1} {chainsCount + 2}",
            position = float3(chainRange, posY, 0.),
            rotation = quat4(HALF_PI, HALF_PI, 0.)
        ))

        if (curChainIdx == 0) {
            add_component(joint, new SpringJoint(node0 = prevNode, node1 = chainBound2))
        } elif (curChainIdx == 1) {
            add_component(joint, new HingeJoint(node0 = prevNode, node1 = chainBound2, angle = 15.))
        } elif (curChainIdx == 2) {
            add_component(joint, new SixDofJoint(node0 = prevNode, node1 = chainBound2,
                limitTranslation = float3(0., 0., 0.),
                limitRotation = deg_to_rad(float3(15., 15., 15.))
            ))
        }
    }
}

class ColoredCollisionListener : CollisionListener {
    node : NodeId
    def override on_initialize() {
        super.on_initialize()
        node?.Mesh.color = reactiveColor
    }
    def override on_collision(c : Collision) {
        node?.Mesh.color = activeColor
    }
    def override on_collision_exit(otherNode : NodeId) {
        node?.Mesh.color = reactiveColor
    }
}

class CollisionCallbackSample : Component {
    def override on_initialize() {
        set_debug_status_string("Collision callback sample")

        let ballDynamic = create_node(NodeData(parent = nodeId, position = float3(10, 30, 0), scale = float3(3)))
        add_component(ballDynamic, new Mesh(meshId = SPHERE_MESH_ID, color = reactiveColor))
        add_component(ballDynamic, new RigidBody(
            motionType = MotionType.Dynamic,
            linearDamping = 0.,
            allowedDofs = AllowedDofs.AllowTranslationY
        ))
        add_component(ballDynamic, new Collider(shape = sphere_shape(), restitution = 1.))
        add_component(ballDynamic, new ColoredCollisionListener(node = ballDynamic))

        let ballKinematic = create_node(NodeData(parent = nodeId, position = float3(-10, 20, 0), scale = float3(3)))
        add_component(ballKinematic, new Mesh(meshId = SPHERE_MESH_ID, color = reactiveColor))
        add_component(ballKinematic, new RigidBody(
            motionType = MotionType.Kinematic,
            velocity = float3(0, -10, 0),
            allowedDofs = AllowedDofs.AllowTranslationY
        ))
        add_component(ballKinematic, new Collider(shape = sphere_shape()))
        add_component(ballKinematic, new ColoredCollisionListener(node = ballKinematic))

        on_collision(ballKinematic) @(c) {
            let curVel = get_component(ballKinematic, type<RigidBody>).velocity
            if (dot(c.normal, curVel) < 0.) {
                get_component(ballKinematic, type<RigidBody>).velocity = -1. * curVel
            }
        }

        let bouncePad = create_node(NodeData(parent = nodeId, position = float3(-10, 30, 0), scale = float3(5, 1, 5)))
        add_component(bouncePad, new Mesh(meshId = CUBE_MESH_ID))
        add_component(bouncePad, new RigidBody(motionType = MotionType.Kinematic))
        add_component(bouncePad, new Collider(shape = box_shape()))

        let sensorBox = create_node(NodeData(parent = nodeId, position = float3(10, 20, 0), scale = float3(5, 5, 5)))
        add_component(sensorBox, new Mesh(meshId = CUBE_MESH_ID))
        add_component(sensorBox, new Collider(shape = box_shape(), isSensor = true))
        add_component(sensorBox, new ColoredCollisionListener(node = sensorBox))
    }
}


class ShapeCastTargetTag : Component {
}

class ShapeQueryVoxelsSample : Component {
    center = float3(0, 20, 0)
    prevRaycastTargets : array<NodeId>
    shapecastExample : int = 0
    textShapequery : NodeId

    def override on_initialize() {
        set_debug_status_string("Shape Query sample\nPress Space (or A on gamepad) to change shape")

        let density = 5f
        let bounds = 20f
        let count = int(bounds / density)
        for (x in -count .. count) {
            for (y in -count .. count) {
                for (z in -count .. count) {
                    let node = create_node(NodeData(parent = nodeId, position = center + float3(x, y, z) * density, scale = float3(density)))
                    add_component(node, new Mesh(meshId = CUBE_MESH_ID, visibility = bitfield16(0))).color = reactiveColor
                    add_component(node, new Collider(shape = box_shape(), collisionLayer = uint8(CollisionLayer.RaycastTarget)))
                    add_component(node, new ShapeCastTargetTag())
                }
            }
        }

        add_and_activate_action_set("shapeQueryVoxels", {
            "nextShapeQuery" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
                )
            )
        })
    }

    def override on_update() {
        if (is_action_just_pressed("nextShapeQuery")) {
            shapecastExample += 1
        }

        var queryHitCb <- $(hits : array < NodeId >) {
            for (prevHit in prevRaycastTargets) {
                (get_component(prevHit, type<Mesh>)).visibility = bitfield16(0)
            }
            clear(prevRaycastTargets)
            for (hit in hits) {
                get_component(hit) $(_ : ShapeCastTargetTag?) {
                    push(prevRaycastTargets, hit)
                    (get_component(hit, type<Mesh>)).visibility = MeshVisibility.FullVisibility
                }
            }
        }

        let queryRaycastHitCb <- $(hits : array < RaycastHit >#) {
            var hitNodes : array<NodeId>
            for (hit in hits) {
                push(hitNodes, hit.nodeId)
            }
            queryHitCb(hitNodes)
        }

        let queryOverlapHitCb <- $(hits : array < OverlapHit >#) {
            var hitNodes : array<NodeId>
            for (hit in hits) {
                push(hitNodes, hit.nodeId)
            }
            queryHitCb(hitNodes)
        }

        let queryShapeCastHitCb <- $(hits : array < ShapeCastHit >#) {
            var hitNodes : array<NodeId>
            for (hit in hits) {
                push(hitNodes, hit.nodeId)
            }
            queryHitCb(hitNodes)
        }

        match (shapecastExample) {
            if (0) {
                set_debug_status_string("Shape Query sample\nPress Space (or A on gamepad) to change shape\nRaycastAll query")
                trace_all(RayCast(
                    ray = Ray(center, float3(sin(get_time()), cos(get_time()), 0.)),
                    maxDistance = 100f,
                    collisionMask = ~(1u << uint(CollisionLayer.RaycastGhost))
                ), queryRaycastHitCb)
            }
            if (1) {
                set_debug_status_string("Shape Query sample\nPress Space (or A on gamepad) to change shape\nBox query")
                overlap(BoxQuery(
                    position = center + float3(0f, sin(get_time()) * 10f, 0f),
                    size = float3(20f, 10f, 20f),
                    rotation = quat4(0.0, PI / 4.0, 0.0),
                    collisionMask = (1u << uint(CollisionLayer.RaycastTarget))
                ), queryOverlapHitCb)
            }
            if (2) {
                set_debug_status_string("Shape Query sample\nPress Space (or A on gamepad) to change shape\nSphere query")
                overlap(SphereQuery(
                    position = center,
                    radius = 10f + sin(get_time()) * 5f,
                    collisionMask = (1u << uint(CollisionLayer.RaycastTarget))
                ), queryOverlapHitCb)
            }
            if (3) {
                set_debug_status_string("Shape Query sample\nPress Space (or A on gamepad) to change shape\nCapsule query")
                overlap(CapsuleQuery(
                    position = center,
                    height = 30.,
                    radius = 2.,
                    rotation = quat4(PI * 0.25, get_time(), 0.),
                    collisionMask = (1u << uint(CollisionLayer.RaycastTarget))
                ), queryOverlapHitCb)
            }
            // if (4) {
            //     set_debug_status_string("Shape Query sample\nPress Space (or A on gamepad) to change shape\nShapeCast Box (down)")
            //     // NOTE: working poorly with big shapes. Works okay with small shapes though
            //     trace_all(BoxCast(
            //         position=center + float3(0f, sin(get_time()) * 10f, 0f),
            //         size=float3(20f, 10f, 20f),
            //         rotation=quat4(float3(0.0, PI / 4.0, 0.0)),
            //         collisionMask=(1u << uint(CollisionLayer.RaycastTarget)),
            //         rayDirection=float3(0, -1, 0),
            //         maxDistance=100f,
            //     ), queryShapeCastHitCb)
            // }
            // if (5) {
            //     set_debug_status_string("Shape Query sample\nPress Space (or A on gamepad) to change shape\nShapeCast Sphere (down)")
            //     // NOTE: working poorly with big shapes. Works okay with small shapes though
            //     trace_all(SphereCast(
            //         position=center,
            //         radius=10f + sin(get_time()) * 5f,
            //         collisionMask=(1u << uint(CollisionLayer.RaycastTarget)),
            //         rayDirection=float3(0, -1, 0),
            //         maxDistance=100f,
            //     ), queryShapeCastHitCb)
            // }
            // if (6) {
            //     set_debug_status_string("Shape Query sample\nPress Space (or A on gamepad) to change shape\nShapeCast Capsule (down)")
            //     // NOTE: working poorly with big shapes. Works okay with small shapes though
            //     trace_all(CapsuleCast(
            //         position = center,
            //         height = 30.,
            //         radius = 2.,
            //         rotation = quat4(PI * 0.25, get_time(), 0.),
            //         collisionMask=(1u << uint(CollisionLayer.RaycastTarget)),
            //         rayDirection=float3(0, -1, 0),
            //         maxDistance=100f,
            //     ), queryShapeCastHitCb)
            // }
            if (_) {
                shapecastExample = 0
            }
        }
    }
}

class RaycastSample : Component {
    traceExample : int = 0
    raycastGhost : NodeId
    raycastSrc : NodeId
    textRaycast : NodeId

    def override on_initialize() {
        set_debug_status_string("Raycast sample\nPress Space (or A on gamepad) to change shape")

        let raycastTarget = create_node(NodeData(parent = nodeId, position = float3(0f, 2.5, 0f), scale = float3(5f)))
        add_component(raycastTarget, new Mesh(meshId = CUBE_MESH_ID, color = activeColor))
        add_component(raycastTarget, new Collider(shape = box_shape(), collisionLayer = uint8(CollisionLayer.RaycastTarget)))

        raycastSrc = create_node(NodeData(parent = nodeId, position = float3(0, 0, 0), rotation = quat4(0f, 0f, PI / 2f), scale = float3(5f)))
        add_component(raycastSrc, new Mesh(meshId = CUBE_MESH_ID, color = activeColor))
        add_component(raycastSrc, new Collider(shape = box_shape(), collisionLayer = uint8(CollisionLayer.RaycastGhost)))

        raycastGhost = create_node(NodeData(parent = nodeId, position = float3(0, 0, 0), rotation = quat4(0f, 0f, PI / 2f), scale = float3(5f)))
        add_component(raycastGhost, new Mesh(meshId = CUBE_MESH_ID, color = reactiveColor))

        add_and_activate_action_set("raycastSample", {
            "nextRaycast" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
                )
            )
        })
    }

    def override on_update() {
        let rayDirection = float3(0, -1, 0)
        let maxDistance = 100f
        let newPos = float3(sin(get_time()) * 15f, 20f, 0f)
        raycastSrc.localPosition = newPos

        if (is_action_just_pressed("nextRaycast")) {
            traceExample += 1
        }

        match (traceExample) {
            if (0) {
                trace(RayCast(
                    ray = Ray(newPos, rayDirection),
                    maxDistance = 100f,
                    collisionMask = ~(1u << uint(CollisionLayer.RaycastGhost))
                ), $(hit) {
                    raycastGhost.localPosition = hit.position
                })
                (get_component(raycastSrc, type<Mesh>)).meshId = SPHERE_MESH_ID
                (get_component(raycastGhost, type<Mesh>)).meshId = SPHERE_MESH_ID
                set_debug_status_string("Raycast sample\nPress Space (or A on gamepad) to change shape\nLine raycast")
            }
            if (1) {
                trace(BoxCast(
                    position = newPos,
                    size = float3(5.0),
                    rayDirection = rayDirection,
                    maxDistance = 100f,
                    collisionMask = ~(1u << uint(CollisionLayer.RaycastGhost))
                ), $(hit) {
                    raycastGhost.localPosition = newPos + hit.offset
                })
                (get_component(raycastSrc, type<Mesh>)).meshId = CUBE_MESH_ID
                (get_component(raycastGhost, type<Mesh>)).meshId = CUBE_MESH_ID
                set_debug_status_string("Raycast sample\nPress Space (or A on gamepad) to change shape\nBox ShapeCast")
            }
            if (2) {
                trace(SphereCast(
                    position = newPos,
                    radius = 2.5f,
                    rayDirection = rayDirection,
                    maxDistance = 100f,
                    collisionMask = ~(1u << uint(CollisionLayer.RaycastGhost))
                ), $(hit) {
                    raycastGhost.localPosition = newPos + hit.offset
                })
                (get_component(raycastSrc, type<Mesh>)).meshId = SPHERE_MESH_ID
                (get_component(raycastGhost, type<Mesh>)).meshId = SPHERE_MESH_ID
                set_debug_status_string("Raycast sample\nPress Space (or A on gamepad) to change shape\nSphere ShapeCast")
            }
            if (3) {
                trace(CapsuleCast(
                    position = newPos,
                    height = 10.,
                    radius = 2.5,
                    axis = AxisDirection.XAxis,
                    rayDirection = rayDirection,
                    maxDistance = 100f,
                    collisionMask = ~(1u << uint(CollisionLayer.RaycastGhost))
                ), $(hit) {
                    raycastGhost.localPosition = newPos + hit.offset
                })
                (get_component(raycastSrc, type<Mesh>)).meshId = CAPSULE_MESH_ID
                (get_component(raycastGhost, type<Mesh>)).meshId = CAPSULE_MESH_ID
                set_debug_status_string("Raycast sample\nPress Space (or A on gamepad) to change shape\nCapsule ShapeCast")
            }
            if (4) {
                sweep_test(NodeCast(
                    nodeId = raycastSrc,
                    from = newPos,
                    to = newPos + rayDirection * maxDistance
                    // collisionMask // no need to set collision mask: sweep_test ignores source body
                ), $(hit) {
                    raycastGhost.localPosition = newPos + hit.offset
                })
                (get_component(raycastSrc, type<Mesh>)).meshId = CUBE_MESH_ID
                (get_component(raycastGhost, type<Mesh>)).meshId = CUBE_MESH_ID
                set_debug_status_string("Raycast sample\nPress Space (or A on gamepad) to change shape\nSweep Test")
            }
            if (_) {
                traceExample = 0
            }
        }
    }
}

class ManyBodiesSample : Component {
    objectsCount : int = 0
    ccdObjectsCount : int = 0
    objectsNeed = 20000 - 10
    ccdObjectsLimit = 2000
    perFrame = 100
    center = float3(0, 70, 0)
    gravityMode : int = 0

    def override on_initialize() {
        set_debug_status_string("Many Bodies Stress-test sample\nPress Space (or A on gamepad) to change gravity")

        let bboxTop = create_node(NodeData(parent = nodeId, name = "topWall", position = center + float3(0., 50., 0.), scale = float3(100, 1, 100)))
        add_component(bboxTop, new Collider(shape = box_shape()))

        let bboxBottom = create_node(NodeData(parent = nodeId, name = "bottomWall", position = center + float3(0., -50., 0.), scale = float3(100, 1, 100)))
        add_component(bboxBottom, new Collider(shape = box_shape()))

        let bboxBack = create_node(NodeData(parent = nodeId, name = "backWall", position = center + float3(0., 0., 50.), scale = float3(100, 100, 1)))
        add_component(bboxBack, new Collider(shape = box_shape()))

        let bboxFront = create_node(NodeData(parent = nodeId, name = "frontWall", position = center + float3(0., 0., -50.), scale = float3(100, 100, 1)))
        add_component(bboxFront, new Collider(shape = box_shape()))

        let bboxLeft = create_node(NodeData(parent = nodeId, name = "leftWall", position = center + float3(-50., 0., 0.), scale = float3(1, 100, 100)))
        add_component(bboxLeft, new Collider(shape = box_shape()))

        let bboxRight = create_node(NodeData(parent = nodeId, name = "rightWall", position = center + float3(50., 0., 0.), scale = float3(1, 100, 100)))
        add_component(bboxRight, new Collider(shape = box_shape()))

        update_gravity_mode()

        add_and_activate_action_set("manyBodiesSample", {
            "changeGravity" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
                )
            ),
            "stressTestChangeBodyType" => Action(
                buttonActions = ButtonAction(
                    keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Return)],
                    gamepadButtons = [GamepadButtonInput(idx=GamepadButton.X)]
                )
            )
        })
    }

    def override on_update() {
        var itCount = 0
        while (objectsCount < objectsNeed) {
            itCount += 1
            if (itCount > perFrame) {
                break
            }
            let pos = random_range(float3(-40), float3(40))
            let vel = random_range(float3(-1), float3(1)) * 100.
            let angVel = random_range(float3(-1), float3(1)) * 10.
            let collisionDetection = (ccdObjectsCount < ccdObjectsLimit) ? CollisionDetection.Continuous : CollisionDetection.Discrete
            let sphereNode = create_node(NodeData(parent = nodeId, name = "sphere {objectsCount}", position = center + pos, scale = float3(1, 1, 1)))
            add_component(sphereNode, new Mesh(meshId = CUBE_MESH_ID))
            add_component(sphereNode, new RigidBody(
                linearDamping = 0.,
                angularDamping = 0.,
                velocity = vel,
                angularVelocity = angVel,
                collisionDetection = collisionDetection
            ))
            add_component(sphereNode, new Collider(shape = box_shape(), restitution = 1.))

            objectsCount += 1
            if (collisionDetection == CollisionDetection.Continuous) {
                ccdObjectsCount += 1
            }
        }

        set_debug_status_string("Many Bodies Stress-Test Sample
Press Space (or A on gamepad) to change gravity
{objectsCount}/{objectsNeed} bodies created
First 2000 bodies - with continuous collision detection
Gravity = {fixed_array("no gravity", "down", "up")[gravityMode]}
Press Enter (or X on gamepad) for additional stress - changing body type mid-frame")

        if (is_action_just_pressed("changeGravity")) {
            gravityMode = (gravityMode + 1) % 3
            update_gravity_mode()
        }

        if (is_action_just_pressed("stressTestChangeBodyType")) {
            for (node in get_children(nodeId)) {
                if (!has_component(node, type<Mesh>)) {
                    continue
                }
                if (node.has_component(type<RigidBody>)) {
                    if (node.get_component(type<RigidBody>).collisionDetection == CollisionDetection.Continuous) {
                        ccdObjectsCount -= 1
                    }
                    node.remove_component(type<RigidBody>)
                } else {
                    let collisionDetection = (ccdObjectsCount < ccdObjectsLimit) ? CollisionDetection.Continuous : CollisionDetection.Discrete
                    node.add_component(new RigidBody(
                        linearDamping = 0.,
                        angularDamping = 0.,
                        collisionDetection = collisionDetection,
                        velocity = random_range(float3(-1), float3(1)) * 100.,
                        angularVelocity = random_range(float3(-1), float3(1)) * 10.))
                    if (collisionDetection == CollisionDetection.Continuous) {
                        ccdObjectsCount += 1
                    }
                }
            }
        }
    }

    def update_gravity_mode() {
        set_gravity(float3(0.0, 9.8 * fixed_array(0., -1., 1.)[gravityMode], 0.0))
    }

    def override on_destroy() {
        set_gravity(float3(0.0, -9.8, 0.0))
    }
}
