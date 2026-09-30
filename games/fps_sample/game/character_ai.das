require engine.core
require engine.ai.behtree
require common
require health
require spawn
require character_look
require character_movement
require weapon_controller

//! Routes for every bot
var private corridors : table<NodeId, NavCorridor>

class StandAndShoot : BehNode {
    //! Stand and shoot the target

    private ai : BotSimpleAi?
    private look : CharacterLook?
    private movement : CharacterMovement?
    private weapon : WeaponController?

    def override tick(nodeId : NodeId) : BehResult {
        if (ai == null) {
            ai = get_component(nodeId, type<BotSimpleAi>)
            look = get_component(nodeId, type<CharacterLook>)
            movement = get_component(nodeId, type<CharacterMovement>)
            weapon = get_component(nodeId, type<WeaponController>)
        }

        // drop a dead target
        if (!ai.target || !ai.target.isAlive || ai.isDead(ai.target)) {
            ai.target = NodeId()
            return BehResult.Fail
        }

        // target visibility
        let visible = ai.canSee(ai.target)

        look.setDirection(ai.target.worldPosition - nodeId.worldPosition)
        movement.input(float3(0))

        // shooting at a visible target
        if (visible) {
            ai.lostTimeout = 0.
            if (ai.shootTimeout <= 0.) {
                weapon.pullTrigger()
                ai.shootTimeout = ai.shootInterval
            } else {
                ai.shootTimeout -= get_delta_time()
            }
            return BehResult.Running
        }

        // forgetting a target out of sight
        ai.lostTimeout += get_delta_time()
        if (ai.lostTimeout >= ai.forgetAfterLostTime) {
            ai.target = NodeId()
            ai.shootTimeout = -1.
            return BehResult.Fail
        }

        return BehResult.Running
    }
}

class Wander : BehNode {
    //! Walk between random points, in search for a target

    private ai : BotSimpleAi?
    private look : CharacterLook?
    private movement : CharacterMovement?

    def override tick(nodeId : NodeId) : BehResult {
        if (ai == null) {
            ai = get_component(nodeId, type<BotSimpleAi>)
            look = get_component(nodeId, type<CharacterLook>)
            movement = get_component(nodeId, type<CharacterMovement>)
        }

        ai.scanTimer -= get_delta_time()
        if (ai.scanTimer <= 0.) {
            ai.scanTimer = ai.scanInterval
            ai.target = ai.findTarget()
        }

        let moveDir = ai.followRoute()
        look.setDirection(moveDir)

        // the bot walks where it looks
        movement.input(FORWARD * length(moveDir) * ai.moveFactor)

        return BehResult.Success
    }
}

class BotSimpleAi : Component {
    //! Search and shoot other players

    @hint = "Part of the top speed while looking for somebody"
    moveFactor : float = 0.33

    @hint = "Radius of the circle a new wander point is searched in, in meters."
    wanderRadius : float = 20.

    @hint = "Seconds without moving before another destination is picked"
    stuckTime : float = 1.

    @hint = "How far the character has to move to count as moving, in meters"
    stuckDistance : float = 1.

    @hint = "How close to a wander point counts as arrived, in meters."
    reachDistance : float = 1.

    @hint = "Interval between two searches for a new target"
    scanInterval : float = 0.3

    @hint = "How far a target can be spotted, in meters."
    detectionRange : float = 25.

    @hint = "Half of the field of view, in radians."
    detectionHalfAngle : float = 60. * TO_RAD

    @hint = "Seconds a target that left the view is kept before the search starts again."
    forgetAfterLostTime : float = 1.

    @hint = "Shooting cooldown"
    shootInterval : float = 1.

    //! State shared by the tree nodes
    target : NodeId            //! Who is being shot at, or nothing while searching
    stuckPosition : float3     //! Where the character stood when it last made progress
    stuckTimeout : float       //! Time spent without moving away from that position
    scanTimer : float          //! Timeout before changing target
    lostTimeout : float        //! Timeout before losing target
    shootTimeout : float       //! Cooldown before shooting

    private look : CharacterLook?         //! Access to character look
    private info : PlayerInfo?            //! Access to player info
    private health : Health?              //! Access to character health
    private movement : CharacterMovement? //! Access to character movement
    private tree : BehNode?               //! The behaviour itself

    def override on_initialize() {
        // route of this bot
        corridors[nodeId].reset()

        // behaviour tree, shooting before wandering
        tree = new SelectorBehNode(name = "root", children = array<BehNode?>(
            new StandAndShoot(name = "stand and shoot"),
            new Wander(name = "wander")
        ))
        tree.init()
    }

    def override on_update() {
        // cache frequently-used components of the same character
        if (look == null) {
            look = nodeId.get_component(type<CharacterLook>)
            info = nodeId.get_component(type<PlayerInfo>)
            health = nodeId.get_component(type<Health>)
            movement = nodeId.get_component(type<CharacterMovement>)
        }

        // a dead body does nothing until the respawn
        if (health.isDead) {
            return
        }

        tree.update(nodeId)
    }

    def isDead(other : NodeId) : bool {
        let otherHealth = get_component(other, type<Health>)
        return otherHealth == null || otherHealth.isDead
    }

    def override on_destroy() {
        erase(corridors, nodeId)
    }

    def canSee(target : NodeId) : bool {
        let eye = look.getEyePosition()
        let targetEye = get_component(target, type<CharacterLook>).getEyePosition()
        let toTarget = targetEye - eye
        let distance = length(toTarget)

        // skip by distance
        if (distance > detectionRange) {
            return false
        }

        // skip by direction
        let direction = toTarget / distance
        if (dot(look.getRotation() * FORWARD, direction) < cos(detectionHalfAngle)) {
            return false
        }

        // skip by visibility
        var blocked = false
        trace(RayCast(ray = Ray(origin = eye, direction = direction), maxDistance = distance, collisionMask = 1u << uint(CollisionLayer.World))) $(hit) {
            blocked = true
        }
        return !blocked
    }

    def findTarget() : NodeId {
        var found = NodeId()
        var foundDistance = detectionRange

        for (other in find_components(type<PlayerInfo>)) {
            if (other.nodeId == nodeId || other.team == info.team || isDead(other.nodeId)) {
                continue
            }

            let distance = length(other.nodeId.worldPosition - nodeId.worldPosition)
            if (distance < foundDistance && canSee(other.nodeId)) {
                found = other.nodeId
                foundDistance = distance
            }
        }

        return found
    }

    def followRoute() : float3 {
        // progress since the last cached position
        if (length(horizontalOffset(stuckPosition)) > stuckDistance) {
            stuckPosition = nodeId.worldPosition
            stuckTimeout = 0.
        } else {
            stuckTimeout += get_delta_time()
        }

        var moveDir = float3(0)
        get(corridors, nodeId, $(var corridor : NavCorridor) {
            let pos = nodeId.worldPosition

            // the corridor follows the character
            var routeReady = (corridor.isValid() && corridor.movePosition(pos) &&
                length(horizontalOffset(corridor.position)) < movement.getWidth())

            // rebuilding the route after a push
            if (!routeReady && corridor.isValid()) {
                routeReady = corridor.findPath(pos, corridor.target) != PathResult.NoPath
            }

            // another destination on arrival or on a blocked way
            if (stuckTimeout >= stuckTime || (routeReady && corridor.distanceToGoal(reachDistance * 2.) <= reachDistance)) {
                routeReady = pickDestination(corridor)
            }

            // nowhere to walk
            if (!routeReady) {
                return
            }

            // move by route
            let corners <- corridor.corners(2)
            let steerTo = length(corners) > 0 ? corners[0] : corridor.target
            let toCorner = horizontalOffset(steerTo)
            moveDir = normalize(toCorner)
        })
        return moveDir
    }

    def private pickDestination(var corridor : NavCorridor) : bool {
        stuckPosition = nodeId.worldPosition
        stuckTimeout = 0.

        // the farthest of a few random points
        var destination = nodeId.worldPosition
        var bestDistance = 0.
        navmesh_random_points_around_circle(NavCircleQuery(center = nodeId.worldPosition, radius = wanderRadius, count = 4)) $(points) {
            for (point in points) {
                let candidateDistance = length(horizontalOffset(point))
                if (candidateDistance > bestDistance) {
                    bestDistance = candidateDistance
                    destination = point
                }
            }
        }

        // nothing walkable around
        if (bestDistance < reachDistance) {
            corridor.reset()
            return false
        }

        return corridor.findPath(nodeId.worldPosition, destination) != PathResult.NoPath
    }

    def private horizontalOffset(to : float3) : float3 {
        return float3(to.x - nodeId.worldPosition.x, 0., to.z - nodeId.worldPosition.z)
    }
}
