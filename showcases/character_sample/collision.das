require engine.core

enum CollisionLayer {
    Default = 0,
    Player = 1,
    Transparent = 2,
    Pickups = 3,
    Collider = 4
}


def init_collisions() {
    set_collision_between_layers(CollisionLayer.Player, CollisionLayer.Transparent, false)
}