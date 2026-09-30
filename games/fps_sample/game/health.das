require engine.core

class Health : Component {
    //! Hit points

    @hint = "Maximum hit points"
    maxHp : float = 100.

    @hint = "Current hit points"
    hp : float

    @hint = "Is the player dead"
    isDead : bool

    def override on_initialize() {
        hp = maxHp
    }

    def takeDamage(amount : float) {
        if (isDead) {
            return
        }

        hp = max(hp - amount, 0.)
        isDead = hp <= 0.
    }

    def revive() {
        hp = maxHp
        isDead = false
    }
}
