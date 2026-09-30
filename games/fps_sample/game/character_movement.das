require engine.core
require common
require health
require character_look

[require(component=(CharacterController, Collider, Health, CharacterLook))]
class CharacterMovement : Component {
    //! Movement of a character. Walking, jumping, falling

    @hint = "Top speed of the character, in meters per second"
    maxSpeed : float = 9.

    @hint = "How fast the character leaves the ground when jumping, in meters per second."
    jumpSpeed : float = 4.5

    private verticalSpeed : float              //! Current fall or jump speed
    private controller : CharacterController?  //! Access to physics controller
    private collider : Collider?               //! Access to physics collider
    private health : Health?                   //! Access to character health
    private look : CharacterLook?              //! Access to character look

    private moveRequest : float3        //! Requested movement for this frame, from nothing to the top speed
    private jumpRequested : bool        //! Requested jump, consumed by the next update
    private wasDead : bool              //! Previous value of isDead
    private standingShape : Shape       //! Collider shape of a standing character

    def override on_initialize() {
        // cache frequently-used components of the same character
        controller = nodeId.get_component(type<CharacterController>)
        collider = nodeId.get_component(type<Collider>)
        standingShape = get_shape(collider)
        health = nodeId.get_component(type<Health>)
        look = nodeId.get_component(type<CharacterLook>)
    }

    def input(direction : float3; jump : bool = false) {
        // record the request
        moveRequest = direction
        jumpRequested ||= jump
    }

    def override on_update() {
        // handle death
        if (health.isDead != wasDead) {
            wasDead = health.isDead
            collider.collisionLayer = uint8(wasDead ? CollisionLayer.DeadCharacter : CollisionLayer.Character)
            set_shape(collider, 0, wasDead ? lyingShape() : standingShape)
        }
        if (wasDead) {
            moveRequest = float3(0)
            jumpRequested = false
        }

        // gravity and jumping
        if (controller.state == CharacterState.OnGround) {
            verticalSpeed = 0.
            if (jumpRequested) {
                verticalSpeed = jumpSpeed
            }
        } else {
            verticalSpeed += controller.gravity.y * get_delta_time()
        }

        // hand the result over to physics
        let horizontalVelocity = look.getYawRotation() * moveRequest * maxSpeed
        controller.velocity = horizontalVelocity + UP * verticalSpeed

        // reset input
        moveRequest = float3(0)
        jumpRequested = false
    }

    def getWidth() : float {
        // the width of the body
        if (!(standingShape is capsule)) {
            return 0.
        }

        return (standingShape as capsule).radius * 2.
    }

    def private lyingShape() : Shape {
        // shape of a player lying on the floor
        if (!(standingShape is capsule)) {
            return standingShape
        }

        let standing = standingShape as capsule

        let lying = quat4(-PI * 0.5, look.lookYaw, 0.)
        return capsule_shape([radius = standing.radius, height = standing.height,
            translation = lying * standing.translation + UP * standing.radius, rotation = lying])
    }
}
