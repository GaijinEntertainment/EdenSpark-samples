require engine.core
require health
require character_look
require character_movement

let bodyPrefab = request_prefab("prefabs/character_visual.prefab")

//! Seconds the body takes to fall down, until there is a death animation to play instead
let FALL_TIME = 0.4

class CharacterTeamColor : Component {
    //! Tag component, for coloring parts of a model that should be in team colors
}

[require(component=(CharacterLook, CharacterMovement))]
class CharacterVisual : Component {
    //! The body other players see.
    //! For the local player set hiddenFromOwnCamera, so the body stays out of the first person view
    //! but still casts its shadow

    @hint = "Color of the body parts marked with CharacterTeamColor."
    teamColor : float4 = float4(1)

    @hint = "Hide the model from this character's own camera, keeping only its shadow. Use it for the local player."
    hiddenFromOwnCamera : bool

    private look : CharacterLook?         //! Access to character look
    private movement : CharacterMovement? //! Access to character movement
    private body : NodeId                 //! Spawned visual model
    private health : Health?              //! Access to character health
    private wasDead : bool                //! Previous value of isDead
    private wasThirdPerson : bool         //! Previous value of the view mode

    def override on_initialize() {
        // cache frequently-used components of the same character
        look = nodeId.get_component(type<CharacterLook>)
        movement = nodeId.get_component(type<CharacterMovement>)
        health = nodeId.get_component(type<Health>)

        // the model as a child node
        body = instantiate_prefab(bodyPrefab, NodeData(parent = nodeId))

        // team color on the tagged parts
        for (child in get_children(body)) {
            get_component(child) $(var mesh : Mesh?) {
                if (has_component(child, type<CharacterTeamColor>)) {
                    mesh.color = teamColor
                }
            }
        }

        // orientation on the first frame
        body.worldRotation = look.getYawRotation()
    }

    def private updateVisibility() {
        if (look.isThirdPerson() == wasThirdPerson) {
            return
        }
        wasThirdPerson = look.isThirdPerson()

        // an own body is invisible to its owner, but its shadow is not
        let visibility = hiddenFromOwnCamera && !wasThirdPerson ? MeshVisibility.CastAnyShadows : MeshVisibility.FullVisibility
        for (child in get_children(body)) {
            get_component(child) $(var mesh : Mesh?) {
                mesh.visibility = visibility
            }
        }
    }

    def override on_update() {
        updateVisibility()

        // the body tips over on death and gets up again on the respawn
        if (health.isDead != wasDead) {
            wasDead = health.isDead
            if (wasDead) {
                // the model rises to the axis of the lying capsule
                let lying = quat_to_euler(look.getYawRotation()) + float3(-PI * 0.5, 0., 0.)
                rotation_tween(body, lying, FALL_TIME)
                position_tween(body, UP * movement.getWidth() * 0.5, FALL_TIME)
            } else {
                body.localPosition = float3(0)
            }
        }

        if (!wasDead) {
            // the body follows the look direction, but stays upright
            body.worldRotation = look.getYawRotation()
        }
    }
}
