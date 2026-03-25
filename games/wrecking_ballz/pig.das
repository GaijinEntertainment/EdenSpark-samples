module pig

require engine.core
require common

let pigRadius = 2f
let pigDeathThreshold = 7.5f
let pigDeathPenetrationThreshold = pigRadius * 0.5
let pigDeathExplosionRadiusMul = 3.0
let pigDeathExplosionStrength = 200.0

class Pig : Component {
    def override on_initialize {
        on_collision(nodeId) @(c) {
            pig_collision(nodeId, c.nodeId, c.impulse, c.penetration)
        }
    }
}


def pig_collision(pigNode : NodeId, otherNode : NodeId, impulse : float, penetration : float) {
    if (impulse >= pigDeathThreshold || penetration >= pigDeathPenetrationThreshold) {
        pig_death(pigNode)
    }
}


def pig_death(pigNode : NodeId) {
    let pigPos = pigNode.localPosition
    let pigRadius = pigNode.localScale.x
    overlap(SphereQuery(
        position = pigPos,
        radius = pigRadius * pigDeathExplosionRadiusMul
    )) $(hits : array<OverlapHit>#) {
        for (hit in hits) {
            let explosionDir = normalize(hit.pointOnBody - pigPos)
            let explosionStrengthByDist = pigDeathExplosionStrength * explosion_formula(hit.distance, pigRadius, pigDeathExplosionRadiusMul)
            get_component(hit.nodeId) $(var rigidBody : RigidBody?) {
                apply_rigid_body_impulse(rigidBody, explosionDir * explosionStrengthByDist, hit.pointOnBody)
            }
        }
    }
    remove_node(pigNode)
}

def explosion_formula(distance : float, pigRadius : float, radiusMul : float) : float {
    // explosion_formula(distance=pigRadius) => 1
    // explosion_formula(distance=pigRadius*radiusMul) => 0
    let a = 1.0 / (pigRadius * (1.0 - max(radiusMul, 1.0)))
    let b = -1.0 * radiusMul / (1.0 - max(radiusMul, 1.0))
    return a * distance + b
}
