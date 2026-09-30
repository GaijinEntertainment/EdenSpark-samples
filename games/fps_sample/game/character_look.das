require engine.core
require common
require health

//! Radius of the sphere that keeps the viewpoint out of walls, in meters
let RAY_WIDTH = 0.2

//! How far ahead the aim point is placed when nothing is hit, beyond the range of any weapon
let AIM_RANGE = 1000.

[require(component=(Health))]
class CharacterLook : Component {
    //! Where a character looks from and what it aims at. Add it to the character node.

    @hint = "Keep the camera behind the character"
    thirdPerson : bool

    @hint = "Camera node of this character, placed on the viewpoint every frame"
    cameraNode : NodeId

    @hint = "Eyes height above the character node, in meters"
    firstPersonHeight : float = EYE_HEIGHT

    @hint = "Point the viewpoint orbits around in third person, relative to the look direction"
    thirdPersonCenterOffset : float3 = float3(1., 1.5, 0.)

    @hint = "How far behind that point the viewpoint hangs in third person, in meters"
    thirdPersonDistance : float = 3.

    @hint = "Look direction around the vertical axis"
    lookYaw : float

    @hint = "Look direction up and down"
    lookPitch : float

    private viewPosition : float3 //! Where the view is taken from
    private aimPoint : float3     //! What the view points at
    private health : Health?      //! Access to character health

    def override on_initialize() {
        // cache frequently-used components of the same character
        health = nodeId.get_component(type<Health>)

        updateView()
    }

    def override on_update() {
        updateView()
    }

    def isThirdPerson() : bool {
        // a dead character is watched from the outside
        return thirdPerson || health.isDead
    }

    def lookDelta(deltaYaw : float, deltaPitch : float, minPitch : float, maxPitch : float) {
        // receive look input
        lookYaw += deltaYaw
        lookPitch = clamp(lookPitch + deltaPitch, minPitch, maxPitch)
    }

    def setDirection(direction : float3) {
        if (length_sq(direction) < 0.0001) {
            return
        }

        // snap the direction, used on spawn
        lookYaw = yawFromDirection(direction)
        lookPitch = 0.
    }

    def getEyePosition() : float3 {
        // the eyes the shots leave from
        return nodeId.worldPosition + UP * firstPersonHeight
    }

    def getRotation() : quat4 {
        // for the camera
        return quat4(-lookPitch, lookYaw, 0)
    }

    def getYawRotation() : quat4 {
        // for the body, which stays upright
        return quat4(0, lookYaw, 0)
    }

    def getAimDirection() : float3 {
        // the direction from the eyes to the aim point
        let toAim = aimPoint - getEyePosition()
        return length_sq(toAim) > 0.0001 ? normalize(toAim) : getRotation() * FORWARD
    }

    def private yawFromDirection(direction : float3) : float {
        // angle of the direction around the vertical axis
        let dir = normalize(direction)
        return safe_acos(dir.z) * (safe_asin(dir.x) >= 0. ? 1. : -1.)
    }

    def private updateView() {
        let rotation = getRotation()
        let forward = rotation * FORWARD

        // first person looks out of the eyes, third person orbits a point beside the character
        let eye = getEyePosition()
        viewPosition = eye
        aimPoint = eye + forward * AIM_RANGE
        if (isThirdPerson()) {
            let center = orbitCenter(eye)
            let back = rotation * BACKWARD

            viewPosition = center + back * freeDistance(center, back, thirdPersonDistance)
            aimPoint = crosshairPoint(forward)
        }

        // the camera looks from the viewpoint
        if (!!cameraNode) {
            cameraNode.worldPosition = viewPosition
            cameraNode.worldRotation = rotation
        }
    }

    def private orbitCenter(eye : float3) : float3 {
        // the point the viewpoint orbits around, kept out of walls
        let toCenter = nodeId.worldPosition + getYawRotation() * thirdPersonCenterOffset - eye
        let wanted = length(toCenter)
        if (wanted < 0.0001) {
            return eye
        }

        let direction = toCenter / wanted
        return eye + direction * freeDistance(eye, direction, wanted)
    }

    def private freeDistance(from : float3; direction : float3; wanted : float) : float {
        // how far the viewpoint may go before it reaches a wall
        var free = wanted
        trace(SphereCast(position = from, radius = RAY_WIDTH, rayDirection = direction, maxDistance = wanted, collisionMask = 1u << uint(CollisionLayer.World))) $(hit) {
            free = min(free, hit.distance)
        }

        return free
    }

    def private crosshairPoint(forward : float3) : float3 {
        // what the crosshair covers, characters included
        var point = viewPosition + forward * AIM_RANGE
        var pointDistance = AIM_RANGE

        // the shooter and the hits behind it are no aim points
        let minDistance = length(viewPosition - getEyePosition())
        let mask = (1u << uint(CollisionLayer.World)) | (1u << uint(CollisionLayer.Character))
        trace_all(RayCast(ray = Ray(origin = viewPosition, direction = forward), maxDistance = AIM_RANGE, collisionMask = mask)) $(hits : array<RaycastHit>#) {
            for (hit in hits) {
                if (hit.nodeId != nodeId && hit.distance > minDistance && hit.distance < pointDistance) {
                    point = hit.position
                    pointDistance = hit.distance
                }
            }
        }

        return point
    }
}
