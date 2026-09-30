require engine.core
require health
require common
require character_look

struct WeaponData {
    //! Stats of a weapon

    name : string = ""             //! Name of the weapon
    damage : float = 25.           //! Hit points taken away by single shot
    fireRate : float = 6.          //! Shots per second
    magazineSize : int = 12        //! Bullets in a full magazine
    reloadTime : float = 1.5       //! Seconds a reload takes
    maxRange : float = 100.        //! Range of a shot
    automatic : bool = false       //! Is automatic shooting mode
    viewmodelNode : string = ""    //! Visual node name
    recoilStrength : float = 8. * TO_RAD //! Recoil strength, in radians
    recoilDuration : float = 0.05  //! Recoil duration, in seconds
}

let PISTOL = WeaponData(
    name = "Pistol",
    damage = 34.,
    fireRate = 4.,
    magazineSize = 10,
    reloadTime = 1.2,
    maxRange = 60.,
    automatic = false,
    viewmodelNode = "pistol"
)

let RIFLE = WeaponData(
    name = "Rifle",
    damage = 20.,
    fireRate = 10.,
    magazineSize = 30,
    reloadTime = 2.,
    maxRange = 150.,
    automatic = true,
    viewmodelNode = "rifle"
)

enum WeaponState {
    //! State of a weapon

    Idle      //! Ready to fire
    Reloading //! Reloading the magazine
}

[require(component=(CharacterLook))]
class WeaponController : Component {
    //! Weapon logic - shooting, reloading, weapon switching.
    //! It shoots from the eyes of the character at the aim point

    @hint = "Weapon in hands right now."
    weapon : WeaponData = PISTOL

    @hint = "Rounds left in the magazine."
    ammo : int

    @hint = "Idle or reloading."
    state : WeaponState

    private shotFired : bool        //! A shot was fired in this frame
    private cooldown : float        //! Time before the next shot is allowed
    private reloadRemaining : float //! Time left of the current reload
    private triggerPulled : bool    //! Requested trigger pull, consumed by the next update

    private look : CharacterLook?   //! Access to character look

    def override on_initialize() {
        // cache frequently-used components of the same character
        look = nodeId.get_component(type<CharacterLook>)

        equip(weapon)
    }

    def isShotFired() : bool {
        return shotFired
    }

    def equip(newWeapon : WeaponData) {
        weapon = newWeapon
        ammo = weapon.magazineSize
        state = WeaponState.Idle
        cooldown = 0.
    }

    def pullTrigger() {
        triggerPulled = true
    }

    def reload() {
        if (state == WeaponState.Idle && ammo < weapon.magazineSize) {
            startReload()
        }
    }

    def override on_update() {
        // reset the shot flag
        shotFired = false

        // process current weapon
        match (state) {
            if (WeaponState.Idle) {
                updateIdle()
            }
            if (WeaponState.Reloading) {
                updateReloading()
            }
        }

        triggerPulled = false
    }

    def private updateIdle() {
        cooldown = max(cooldown - get_delta_time(), 0.)

        if (triggerPulled && cooldown <= 0.) {
            // out of ammo - auto reload
            if (ammo <= 0) {
                startReload()
                return
            }

            cooldown = 1. / weapon.fireRate
            ammo -= 1
            shoot()
        }
    }

    def private updateReloading() {
        reloadRemaining -= get_delta_time()
        if (reloadRemaining <= 0.) {
            ammo = weapon.magazineSize
            state = WeaponState.Idle
        }
    }

    def private startReload() {
        state = WeaponState.Reloading
        reloadRemaining = weapon.reloadTime
    }

    def private shoot() {
        // shots leave the eyes and go to the aim point
        let ray = Ray(origin = look.getEyePosition(), direction = look.getAimDirection())

        // first ray cast - to the wall
        var shotRange = weapon.maxRange
        trace(RayCast(ray = ray, maxDistance = shotRange, collisionMask = 1u << uint(CollisionLayer.World))) $(hit) {
            shotRange = hit.distance
        }

        // second ray cast - the closest victim, the shooter aside
        var target = NodeId()
        var targetDistance = shotRange
        trace_all(RayCast(ray = ray, maxDistance = shotRange, collisionMask = 1u << uint(CollisionLayer.Character))) $(hits : array<RaycastHit>#) {
            for (hit in hits) {
                if (hit.nodeId != nodeId && hit.distance < targetDistance) {
                    target = hit.nodeId
                    targetDistance = hit.distance
                }
            }
        }

        if (!!target) {
            get_component(target) $(var health : Health?) {
                health.takeDamage(weapon.damage)
            }
        }

        shotFired = true
    }
}
