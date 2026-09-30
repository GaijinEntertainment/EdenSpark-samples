require engine.core

def random_point_on_sphere() : float3 {
    let z = 1.0 - 2.0 * random_float()
    let r = sqrt(max(0.0, 1.0 - z * z))
    let phi = 2.0 * PI * random_float()
    return float3(r * cos(phi), r * sin(phi), z)
}

struct SubFireworkSetup {
    prefab : PrefabId
    count : int
}

class FireworkBehavior : Component {
    subFireworks : array<SubFireworkSetup>

    lifeTimeRange : float2
    speed : float
    drag : float // Speed reduction coefficient.
    acceleration : float3 // Gravity or other constant acceleration in world space.

    private velocity : float3
    private lifeTime : float

    def override on_initialize() {
        velocity = nodeId.worldRotation * float3(0, speed, 0)
        lifeTime = lerp(lifeTimeRange.x, lifeTimeRange.y, random_float())
    }

    def override on_update() {
        let dt = get_delta_time()

        lifeTime -= dt
        if (lifeTime <= 0.0) {
            launch_sub_fireworks()
            remove_node(nodeId)
            return
        }

        velocity += acceleration * dt - velocity * drag * dt
        nodeId.worldPosition += velocity * dt
    }

    def private launch_sub_fireworks() {
        for (sub in subFireworks) {
            for (i in range(sub.count)) {
                let dir = random_point_on_sphere()
                sub.prefab.instantiate_prefab(NodeData(
                    position = nodeId.worldPosition,
                    rotation = quat4(UP, dir)
                ))
            }
        }
    }
}

class TextFader : Component {
    fadeStart : float
    fadeEnd : float

    private fadeTime : float = 0.0

    def override on_update() {
        fadeTime += get_delta_time()
        nodeId.get_component() $(var text : UIText?) {
            var color = text.color
            color.w = 1.0 - clamp((fadeTime - fadeStart) / (fadeEnd - fadeStart), 0.0, 1.0)
            text.color = color
        }
    }
}

let fireworksPrefab = request_prefab("fireworks/firework.prefab")

[export]
def on_initialize() {
    add_and_activate_action_set("components", {
        "launch_firework" => Action(
            buttonActions = ButtonAction(
                keyboardButtons = [KeyboardButtonInput(idx=KeyCode.Space)],
                gamepadButtons = [GamepadButtonInput(idx=GamepadButton.A)]
            )
        ),
    })
}

[export]
def on_update() {
    if (is_action_just_pressed("launch_firework")) {
        instantiate_prefab(fireworksPrefab, NodeData(rotation = quat4(0, random_float() * 2.0 * PI, random_float() * 0.2 * PI)))
    }
}

