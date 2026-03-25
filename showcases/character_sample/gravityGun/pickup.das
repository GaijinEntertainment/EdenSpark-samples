
require engine.core
require gravityGunComponent
require collision

var pickups : array<PickupComponent?>


[export]
def on_initialize() {
    find_components(pickups)
}


def disablePickupHints() {
    for (pickupComp in pickups) {
        if (pickupComp.nodeId.isAlive) {
            pickupComp.hint.isActive = false
        }
    }
}

class PickupComponent : Component {
    hint : NodeId
}

class PickupHandler : Component {
    def override on_update() {
        disablePickupHints()

        let resolution = get_resolution()
        let ray : Ray = nodeId?.Camera.screenToRay(float2(resolution.x / 2, resolution.y / 2))
        let rayCast : RayCast = RayCast(ray = ray, maxDistance = 6.0, collisionMask = 1u << uint(CollisionLayer.Pickups))

        trace_all(rayCast) $(hits) {
            for (hit in hits) {
                get_component(hit.nodeId) $(pickup : PickupComponent?) {
                    pickup.hint.isActive = true
                    processPickupInput(hit.nodeId)
                }
            }
        }
    }

    def private abstract processPickupInput(node : NodeId) : void
}