require engine.core

// Traction Control: cuts gas on driven wheels that spin faster than the car is moving.
struct TractionControlAssist {
    enabled : bool = true
    slip : float = 1.5 // m/s
    gain : float = 0.6
}

def apply_assist(s : TractionControlAssist; var vc : VehicleController?; speed : float) {
    if (!s.enabled) {
        return
    }
    var driveSlip = 0.
    for (i in range(vc.axles.length())) {
        let a = vc.axles[i]
        if (a.torque > 0. && a.leftWheel >= 0) { driveSlip = max(driveSlip, abs(vc.wheels[a.leftWheel].linearSpeed()) - abs(speed)) }
        if (a.torque > 0. && a.rightWheel >= 0) { driveSlip = max(driveSlip, abs(vc.wheels[a.rightWheel].linearSpeed()) - abs(speed)) }
    }
    vc.gasInput *= saturate(1. - s.gain * max(0., driveSlip - s.slip))
}

// ABS: releases the brake on wheels that lock up and spin slower than the car is moving.
struct AbsAssist {
    enabled : bool = true
    slip : float = 1.5 // m/s
    gain : float = 0.6
}

def apply_assist(s : AbsAssist; var vc : VehicleController?; speed : float) {
    if (!s.enabled) {
        return
    }
    var lockSlip = 0.
    for (i in range(vc.wheels.length())) {
        let w = vc.wheels[i]
        lockSlip = max(lockSlip, abs(speed) - abs(w.linearSpeed()))
    }
    vc.brakeInput *= saturate(1. - s.gain * max(0., lockSlip - s.slip))
}

// Electronic Stability Control: reins in yaw rate to keep the car from spinning out.
struct StabilityControlAssist {
    enabled : bool = true
    margin : float = 1.4
    minRate : float = 0.35 // rad/s
    rate : float = 6.0 // 1/s
}

def apply_assist(s : StabilityControlAssist; vc : VehicleController?; var rb : RigidBody?; speed : float; dt : float) {
    if (!s.enabled) {
        return
    }
    var minZ = 1e9
    var maxZ = -1e9
    var maxSteer = 0.
    for (i in range(vc.wheels.length())) {
        let w = vc.wheels[i]
        minZ = min(minZ, w.position.z)
        maxZ = max(maxZ, w.position.z)
        maxSteer = max(maxSteer, w.maxSteeringAngle)
    }
    let allowed = abs(speed) * abs(tan(vc.steeringInput * maxSteer)) / max(maxZ - minZ, 0.5) * s.margin + s.minRate
    var av = rb.angularVelocity
    if (abs(av.y) <= allowed) {
        return
    }
    av.y = lerp(av.y, sign(av.y) * allowed, saturate(s.rate * dt))
    rb.angularVelocity = av
}

// Cornering Speed Limiter: cuts gas and brakes before a too-sharp turn breaks traction.
struct CorneringSpeedLimiterAssist {
    enabled : bool = true
    maxLateralAccel : float = 8.0 // m/s^2
    gain : float = 0.6
    intensity : float = 0.5 // 0 = assist fully off, 1 = full-strength correction
}

def apply_assist(s : CorneringSpeedLimiterAssist; var vc : VehicleController?; speed : float) {
    if (!s.enabled || s.intensity <= 0.) {
        return
    }
    var minZ = 1e9
    var maxZ = -1e9
    var maxSteer = 0.
    for (i in range(vc.wheels.length())) {
        let w = vc.wheels[i]
        minZ = min(minZ, w.position.z)
        maxZ = max(maxZ, w.position.z)
        maxSteer = max(maxSteer, w.maxSteeringAngle)
    }
    let steerAngle = abs(vc.steeringInput * maxSteer)
    if (steerAngle < 0.01) {
        return
    }
    let wheelbase = max(maxZ - minZ, 0.5)
    let safeSpeed = sqrt(s.maxLateralAccel * wheelbase / tan(steerAngle))
    let overspeed = max(0., abs(speed) - safeSpeed)
    vc.gasInput *= lerp(1., saturate(1. - s.gain * overspeed), s.intensity)
    vc.brakeInput = max(vc.brakeInput, saturate(s.gain * overspeed) * s.intensity)
}

// Unstuck: pushes the car away from whatever it's jammed against when the wheel is turned.
struct UnstuckAssist {
    enabled : bool = true
    minGas : float = 0.5
    maxSpeed : float = 0.5
    minSteer : float = 0.1
    rayDistance : float = 2.0 // m
    maxNormalUpDot : float = 0.3 // hit normals steeper than this count as a wall, not a slope
    turnRate : float = 0.3 // rad/s
}

def apply_assist(s : UnstuckAssist; vc : VehicleController?; var rb : RigidBody?; nodeId : NodeId; speed : float) {
    if (!s.enabled || abs(vc.gasInput) < s.minGas || abs(speed) > s.maxSpeed || abs(vc.steeringInput) < s.minSteer) {
        return
    }
    let forward = nodeId.localForward * sign(vc.gasInput)
    let from = nodeId.worldPosition
    sweep_test(NodeCast(nodeId = nodeId, from = from, to = from + forward * s.rayDistance)) $(hit) {
        if (abs(dot(hit.normal, UP)) < s.maxNormalUpDot) {
            var tangent = normalize(cross(UP, hit.normal))
            if (dot(tangent, nodeId.localRight) * sign(vc.steeringInput) < 0.) {
                tangent = -tangent
            }
            let impulse = tangent * rb.mass * s.turnRate
            apply_impulse(rb, impulse * 0.5, from + hit.offset)
            apply_impulse(rb, -impulse * 0.5, from - hit.offset)
        }
    }
}
