require engine.core
require game.common
require game.game_mode

let levelPrefab = request_prefab("prefabs/level.prefab") //! Arena: floors, walls, spawn points

[export]
def on_initialize() {
    // lighting and post processing defaults
    create_render_settings()

    // initialize collision layers for physics
    init_collision_layers()

    // the level and its navigation mesh
    let levelRoot = instantiate_prefab(levelPrefab)
    add_component(levelRoot, new NavMesh(agentRadius = CHARACTER_RADIUS, agentHeight = CHARACTER_HEIGHT))
    levelRoot?.NavMesh.bakeAsync() @(result : BakeResult) {
        if (result != BakeResult.Baked) {
            print("Navigation Mesh bake result: {result}")
        }
    }

    // showing controls
    let debugText = create_debug_text("Move: WASD\nLook: Mouse\nJump: Space\nSprint: Shift\nShoot: Left Mouse Button\nReload: R\nSelect Pistol: 1\nSelect Rifle: 2\nThird Person: C", float2(20, 20), TOP_LEFT_ANCHOR)
    set_text_color(debugText, float4(0, 0, 0, 1))

    // GameMode starts the match
    let gameMode = create_node(NodeData(name = "gameMode"))
    add_component(gameMode, new GameMode())
}
