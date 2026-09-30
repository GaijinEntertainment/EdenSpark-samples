require engine.core

let CHARACTER_RADIUS = 0.5
let CHARACTER_HEIGHT = 2.0
let EYE_HEIGHT = 1.6

enum CollisionLayer {
    //! Global collision layers

    World = 0     //! Level geometry
    Character = 1 //! Players and bots
    DeadCharacter = 2 //! Dead characters, waiting for their respawn
}

def init_collision_layers() {
    set_collision_between_layers(CollisionLayer.DeadCharacter, CollisionLayer.Character, false)
}