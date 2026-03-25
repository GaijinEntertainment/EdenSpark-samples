require engine.core

class MovingPlatform : Component {
    pos1 : float3
    pos2 : float3
    rot1 : float
    rot2 : float
    animSpeed : float = 1.0
    animPos : float = 0.0

    def override on_update() {// will be called each frame
        let hasRigidBody = get_component(nodeId) $(var rigidBody : RigidBody?) {
            rigidBody.velocity = (animPos < 1. ? pos2 - pos1 : pos1 - pos2) * animSpeed

            let rot = (animPos < 1. ? rot2 - rot1 : rot1 - rot2) * TO_RAD * animSpeed
            rigidBody.angularVelocity = float3(0, rot, 0)
        }
        nodeId.localPosition = animPos < 1. ? lerp(pos1, pos2, animPos) : lerp(pos2, pos1, animPos - 1.0)
        nodeId.localRotation = quat4(0, (animPos < 1. ? lerp(rot1, rot2, animPos) : lerp(rot2, rot1, animPos - 1.0)) * TO_RAD, 0)

        animPos += get_delta_time() * animSpeed
        while (animPos > 2.) {
            animPos -= 2.
        }
    }
}


class CharacterTrigger : CollisionListener {
    showBodyOnCollision : NodeId
    showBodyOnNoCollision : NodeId

    def override on_collision(c : Collision) {
        showBodyOnCollision.isActive = true
        showBodyOnNoCollision.isActive = false
    }

    def override on_collision_exit(node : NodeId) {
        showBodyOnCollision.isActive = false
        showBodyOnNoCollision.isActive = true
    }
}

class CollisionTestCallbacks : CollisionListener {

    def override on_collision(c : Collision) {
        print("on_collision: {nodeId} with {c.nodeId}")
    }
    def override on_collision_stay(c : Collision) {
        print("on_collision_stay: {nodeId} with {c.nodeId}")
    }
    def override on_collision_exit(otherNode : NodeId) {
        print("on_collision_exit: {nodeId} with {otherNode}")
    }
}

class CollisionTest : Component {
    private selfPrefab : PrefabId
    timer : float = 5.
    speed : float = 2.

    def override on_initialize() {
        var inscope children = nodeId.get_children()
        for (child in children) {
            child.on_collision(@(collision : Collision) {
                print("on_collision: {child} with {collision.nodeId}")
            })

            child.on_collision_stay(@(collision : Collision) {
                print("on_collision_stay: {child} with {collision.nodeId}")
            })

            child.on_collision_exit(@(collision : NodeId) {
                print("on_collision_exit: {child} with {collision}")
            })

            child?.RigidBody.velocity = float3(speed, 0, 0)
        }
    }

    def override on_update() {
        timer -= get_delta_time()
        if (timer <= 0.) {
            selfPrefab = request_prefab("collision_test.prefab")
            selfPrefab.instantiate_prefab(NodeData(position = nodeId.worldPosition))
            remove_node(nodeId)
        }
    }
}
