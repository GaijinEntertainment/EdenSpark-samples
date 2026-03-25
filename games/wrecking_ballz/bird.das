module bird

require engine.core
require common
// require camera

let birdNestPos = float2(-50f, 8.5)
let aimSpeed = 0.05f
let slingDeadZone = 1f
let maxSlingDistance = 8f
let slingStiffness = 500f
let respawnTimeout = 5f

let birdNestPrefab = request_prefab("nest.prefab")
let birdPrefab = request_prefab("bird.prefab")
let birdIdleMaterial = request_material("assets/bird.material")
let birdActiveMaterial = request_material("assets/birdActive.material")

def add_bird_nest() {
    let newNest = instantiate_prefab(birdNestPrefab)
    newNest.localPosition = float3(birdNestPos.x, 0., 5.)
}


class BirdNest : Component {
    def override on_initialize() {
        let newBird = instantiate_prefab(birdPrefab)
        newBird.localPosition = float3(birdNestPos, 5.)
    }
}

enum BirdState {
    Ready
    MouseOver
    Aiming
    Flying
}

class Bird : Component {
    birdPos : float2 = float2()
    slingDir : float2 = float2(0, 0)
    birdState : BirdState = BirdState.Ready
    timeBeforeRespawn : float = 0.0
    meshNode : NodeId

    def override on_initialize() {
        setBirdState(BirdState.Ready)
    }

    def override on_update() {
        let dt = get_delta_time()

        if (get_action_vector2("aimAngle") != float2(0, 0)) {
            bird_handle_mousemove(get_action_vector2("aimAngle"), get_action_vector2("aim"))
        }
        if (is_action_just_pressed("fire")) {
            bird_handle_mousedown()
        }
        if (is_action_just_released("fire")) {
            bird_handle_mouseup()
        }

        birdPos = nodeId.localPosition.xy

        // game logic after the bird started flying
        if (birdState == BirdState.Flying) {
            // if we are still on the sling - speedup
            if (length_sq(slingDir) > 0f && dot(birdNestPos - birdPos, slingDir) > 0f) {
                let slingForce = slingDir * slingStiffness * dt
                get_component(nodeId) $(var rigidBody : RigidBody?) {
                    apply_rigid_body_impulse(rigidBody, float3(slingForce, 0f))
                }
            } else {
                slingDir = float2(0, 0)
            }

            // respawn time
            timeBeforeRespawn -= dt
            if (timeBeforeRespawn < 0f) {
                setBirdState(BirdState.Ready)
            }
        }
    }

    def setBirdState(newState : BirdState) {
        if (newState == birdState) {
            return
        }

        let prevState = birdState

        // change selection color
        if (newState == BirdState.MouseOver || prevState == BirdState.MouseOver) {
            meshNode?.Mesh.materialId = newState == BirdState.MouseOver ? birdActiveMaterial : birdIdleMaterial
        }

        // prepare bird physics
        match (newState) {
            if (BirdState.Ready) {
                (get_component(nodeId, type<RigidBody>)).motionType = MotionType.Kinematic
                (get_component(nodeId, type<RigidBody>)).velocity = float3()
                nodeId.worldPosition = float3(birdNestPos, nodeId.worldPosition.z)
            }
            if (BirdState.Flying) {
                timeBeforeRespawn = respawnTimeout
                slingDir = normalize(slingDir)
                (get_component(nodeId, type<RigidBody>)).motionType = MotionType.Dynamic
            }
        }
        birdState = newState
    }

    def bird_handle_mousemove(deltaPos : float2, absPos : float2) {
        match (birdState) {
            if (BirdState.Aiming) {
                // it's better not to use absolute mouse position here, because the position of the camera changes as the bird is moved
                let newBirdPos = birdPos + deltaPos * aimSpeed * float2(1, -1)
                slingDir = newBirdPos - birdNestPos
                if (length_sq(slingDir) > maxSlingDistance * maxSlingDistance) {
                    slingDir = normalize(slingDir) * maxSlingDistance
                }
                nodeId.worldPosition = float3(slingDir + birdNestPos, nodeId.worldPosition.z)
                birdPos = slingDir + birdNestPos
            }
            if (BirdState.Ready || BirdState.MouseOver) {
                for (cam in find_components(type<Camera>)) {
                    let ray = cam.screenToRay(absPos)
                    trace(RayCast(ray = ray)) $(hit) {
                        let isMouseOver = hit.nodeId == nodeId
                        setBirdState(isMouseOver ? BirdState.MouseOver : BirdState.Ready)
                    }
                    break
                }
            }
        }
    }
    def bird_handle_mousedown() {
        if (birdState == BirdState.MouseOver) {
            setBirdState(BirdState.Aiming)
        }
    }

    def bird_handle_mouseup() {
        if (birdState == BirdState.Aiming) {
            slingDir = birdNestPos - birdPos
            if (length(slingDir) > slingDeadZone) {
                setBirdState(BirdState.Flying)
            } else {
                setBirdState(BirdState.Ready)
            }
        }
    }
}
