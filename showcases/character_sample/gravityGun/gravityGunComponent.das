
require engine.core
require daslib/defer
require engine.sound_core
require collision

let private multiplier = 500.0f
let private sendForce = 600.0f
let private attention = 30.0f

let private buzzingSound = request_sound("assets/soft_electricity_buz.mp3")
let private blastSound = request_sound("assets/blast.mp3")

class GravityGunComponent : Component {
    prefab : string
    camera : NodeId
    attachedObject : NodeId
    attachedConfig : RigitBodyRestoreParams
    sound : SoundHandle

    private mesh : NodeId

    def override on_initialize() {
        request_prefab(prefab) |> instantiate_prefab(NodeData(parent = nodeId))
    }

    def override on_update() {
        if (has_component(nodeId, type<RechargeTag>)) {
            return
        }

        if (is_action_just_pressed("activate") && hasAttachedObject()) {
            sendObjectFlying(self, camera?.Camera)
            return
        }

        if (is_action_pressed("deactivate")) {
            if (!hasAttachedObject()) {
                findPullablePointingAt(self, camera?.Camera)
            }
            elif (!isAttachedObjectPulled()) {
                pullPhysObjectPointingAt(self, camera?.Camera)
            }
        }
        elif (hasAttachedObject()) {
            detachObject()
        }
    }

    def hasAttachedObject() : bool {
        return attachedObject != NodeId()
    }

    def isAttachedObjectPulled() : bool {
        return attachedObject.parent == nodeId
    }

    def attachObject(at : float3, rot : quat4) {
        attachedObject.worldPosition = at
        attachedObject.worldRotation = rot
        attachedObject.parent = nodeId
        attachedObject.get_component($(var collider : Collider?) {
            collider.collisionLayer = uint8(CollisionLayer.Transparent)
        })

        get_component(attachedObject) $(var rb : RigidBody?) {
            attachedConfig.take(rb)
        }

        stop(sound)
        get_component(attachedObject) $(r : RigidBody?) {
            sound = play_sound_loop(buzzingSound) |> set_pitch() <| lerp(0.9, 1.0, 10.0 / r.mass)
        }

//         print("dist {hit.nodeId} {ray.origin} {ray.direction}")
//         draw_ray(ray, 2.0, float4(1, 0, 0, 1), 240)
    }

    def detachObject() : NodeId {
        attachedObject.get_component($(var collider : Collider?) {
            collider.collisionLayer = uint8(CollisionLayer.Default)
        })
        get_component(attachedObject) $(var rb : RigidBody?) {
            rb.restore(attachedConfig)
        }
        attachedObject.parent = NodeId()
        defer() {
            attachedObject = NodeId()
            attachedConfig = RigitBodyRestoreParams()
        }

        stop(sound)
        sound = INVALID_SOUND_HANDLE

        return attachedObject
    }
}

class PullableTag : Component {}

struct RigitBodyRestoreParams {
    useGravity : bool
    maxAngularVelocity : float
    maxVelocity : float
}

def take(var params : RigitBodyRestoreParams, var rb : RigidBody?) {
    params.useGravity = rb.useGravity
    params.maxAngularVelocity = rb.maxAngularVelocity
    params.maxVelocity = rb.maxVelocity

    rb.useGravity = false
    rb.maxAngularVelocity = 0.0
    rb.maxVelocity = 0.0
}

def restore(var rb : RigidBody?, var params : RigitBodyRestoreParams) {
    rb.useGravity = params.useGravity
    rb.maxAngularVelocity = params.maxAngularVelocity
    rb.maxVelocity = params.maxVelocity
}

class RechargeTag : Component {
    cd = 1.0
    private elapsed : float -const = 0.0

    def override on_update() {
        let dt = get_delta_time()
        elapsed += dt

        if (elapsed >= cd && !is_action_pressed("deactivate")) {
            remove_component(nodeId, type<RechargeTag>)
        }
    }
}

def findPullablePointingAt(var gun : GravityGunComponent, camera : Camera?) {
    let resolution = get_resolution()
    let ray : Ray = camera.screenToRay(float2(resolution.x / 2, resolution.y / 2))
    let rayCast : RayCast = RayCast(ray = ray, maxDistance = 10.0)

    trace_all(rayCast) $(hits) {
        for (hit in hits) {
            if (has_component(hit.nodeId, type<PullableTag>)) {
                gun.attachedObject = hit.nodeId
            }
        }
    }
}

def pullPhysObjectPointingAt(var gun : GravityGunComponent, camera : Camera?) {
    let resolution = get_resolution()
    let ray : Ray = camera.screenToRay(float2(resolution.x / 2, resolution.y / 2))

    if (!gun.attachedObject) {
        return
    }

    if (gun.sound == INVALID_SOUND_HANDLE) {
        gun.sound = play_sound_loop(buzzingSound)
    }

    if (distance(gun.attachedObject.worldPosition, gun.nodeId.worldPosition) < 3.0) {
        gun.attachObject(ray.origin + ray.direction * 3.0, camera.nodeId.worldRotation)
        return
    }

    let dir = normalize(gun.nodeId.worldPosition - gun.attachedObject.worldPosition)
    let force = distance(gun.attachedObject.worldPosition, gun.nodeId.worldPosition)

    apply_rigid_body_force(gun.attachedObject?.RigidBody, dir * force * multiplier)
}

def sendObjectFlying(var gun : GravityGunComponent, camera : Camera?) {
    let resolution = get_resolution()
    let ray : Ray = camera.screenToRay(float2(resolution.x / 2, resolution.y / 2))
    let obj = gun.detachObject()

//     draw_ray(ray, sendForce, float4(0, 1, 0, 1), 240)

    add_component(gun.nodeId, new RechargeTag())

    get_component(obj) $(r : RigidBody?) {
        apply_rigid_body_impulse(r, ray.direction * sendForce)
        play_sound(blastSound) |> set_volume(0.2) |> set_pitch(2.0 * 10.0 / r.mass)
    }
}