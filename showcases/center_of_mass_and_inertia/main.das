require engine.core


class CenterOfMass : Component {
    value : float3 = float3(0, 0, 0)
    apply : bool = false
    reset : bool = false
    print : bool = false

    def private do_apply() {
        nodeId?.RigidBody.centerOfMass = value
    }

    def private do_print() {
        let rb = nodeId?.RigidBody
        print("{nodeId} centerOfMass={rb.centerOfMass}")
    }

    def override on_initialize() {
        if (apply) {
            apply = false
            do_apply()
        }
        if (print) {
            print = false
            do_print()
        }
    }

    def override on_update() {
        if (reset) {
            reset = false
            nodeId?.RigidBody.reset_center_of_mass()
        }
        if (apply) {
            apply = false
            do_apply()
        }
        if (print) {
            print = false
            do_print()
        }
    }
}

class Inertia : Component {
    diagonal : float3 = float3(1, 1, 1)
    rotation : quat4 = quat4()
    rotateOnly : bool = false
    apply : bool = false
    reset : bool = false
    print : bool = false

    def private do_apply() {
        if (!rotateOnly) {
            nodeId?.RigidBody.inertia = diagonal
        }
        nodeId?.RigidBody.inertiaRotation = rotation
    }


    def private do_print() {
        let rb = nodeId?.RigidBody
        print("{nodeId} inertia={rb.inertia} inertiaRotation={rb.inertiaRotation}")
    }

    def override on_initialize() {
        if (apply) {
            apply = false
            do_apply()
        }
        if (print) {
            print = false
            do_print()
        }
    }

    def override on_update() {
        if (reset) {
            reset = false
            nodeId?.RigidBody.reset_inertia()
        }
        if (apply) {
            apply = false
            do_apply()
        }
        if (print) {
            print = false
            do_print()
        }
    }
}

class Top : Component {}

[export]
def on_post_initialize() {
    for (comp in find_components(type<Top>)) {
        comp.nodeId?.RigidBody.apply_angular_impulse(float3(0, 1, 0))
    }
}
