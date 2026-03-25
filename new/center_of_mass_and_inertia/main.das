require engine.core


class CenterOfMass : Component {
    value : float3 = float3(0, 0, 0)
    reapply : bool = false
    reset : bool = false

    def private do_apply() {
        nodeId?.RigidBody.centerOfMass = value
    }

    def override on_initialize() {
        do_apply()
    }

    def override on_update() {
        if (reapply) {
            reapply = false
            do_apply()
        }
        if (reset) {
            reset = false
            nodeId?.RigidBody.reset_center_of_mass()
        }
    }
}

class CenterOfMassPrinter : Component {
    reprint : bool

    def private do_print() {
        print("{nodeId} center of mass is {nodeId?.RigidBody.centerOfMass}")
    }

    def override on_initialize() {
        do_print()
    }

    def override on_update() {
        if (reprint) {
            reprint = false
            do_print()
        }
    }
}

class Inertia : Component {
    value : float3 = float3(0, 0, 0)
    rotation : quat4 = quat4()
    rotateOnly : bool = false
    reapply : bool = false
    reset : bool = false

    def private do_apply() {
        nodeId?.RigidBody.set_inertia(rotateOnly ? nodeId?.RigidBody.inertia : value, rotation)
    }

    def override on_initialize() {
        do_apply()
    }

    def override on_update() {
        if (reapply) {
            reapply = false
            do_apply()
        }
        if (reset) {
            reset = false
            nodeId?.RigidBody.reset_inertia()
        }
    }
}


class InertiaPrinter : Component {
    reprint : bool

    def private do_print() {
        let rb = nodeId?.RigidBody
        print("{nodeId} diag {rb.inertia} rot {rb.inertiaRotation.quat_to_euler().rad_to_deg()}")
    }

    def override on_initialize() {
        do_print()
    }

    def override on_update() {
        if (reprint) {
            reprint = false
            do_print()
        }
    }
}

class Top : Component {}

[export]
def on_post_initialize() {
    for (comp in find_components(type<Top>)) {
        comp.nodeId?.RigidBody.apply_rigid_body_angular_impulse(float3(0, 1, 0))
    }
}
