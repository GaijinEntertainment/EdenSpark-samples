require engine.core
require character_input
require weapon_controller
require weapon_visual
require character_ai
require health
require common
require character_look
require character_movement
require character_visual
require spawn

let PLAYER_TEAM = 0
let ENEMY_TEAM = 1

let hudPrefab = request_prefab("prefabs/hud.prefab") //! Screen overlay: crosshair and ammo counter
let weaponFpvPrefab = request_prefab("prefabs/weapon_fpv.prefab") //! First person weapon model, with WeaponVisual inside

class GameMode : Component {
    //! The match logic - spawning and respawning players

    def override on_initialize() {
        // crosshair and ammo counter
        instantiate_prefab(hudPrefab)

        // spawn the player
        let player = create_node(NodeData(name = "player"))
        add_component(player, new CharacterController())
        add_component(player, new Collider(shape = capsule_shape([radius = CHARACTER_RADIUS, height = CHARACTER_HEIGHT, translation = UP * CHARACTER_HEIGHT * 0.5]), collisionLayer = uint8(CollisionLayer.Character)))
        add_component(player, new Health())
        add_component(player, new PlayerInfo(team = PLAYER_TEAM))
        add_component(player, new CharacterInput())
        add_component(player, new CharacterLook())
        add_component(player, new CharacterMovement())
        add_component(player, new WeaponController())

        add_component(player, new CharacterVisual(hiddenFromOwnCamera = true))

        // the camera of the player
        let camera = create_node(NodeData(name = "camera", parent = player, position = UP * EYE_HEIGHT))
        add_component(camera, new Camera(fovAxis = FovAxis.Horizontal, fov = TO_RAD * 90f, znear = 0.1, zfar = 1000.))
        player?.CharacterLook.cameraNode = camera
        instantiate_prefab(weaponFpvPrefab, NodeData(parent = camera, scale = float3(0.7)))

        spawn_at_team_point(player, PLAYER_TEAM)

        // spawn the bot
        let enemy = create_node(NodeData(name = "enemy"))
        add_component(enemy, new CharacterController())
        add_component(enemy, new Collider(shape = capsule_shape([radius = CHARACTER_RADIUS, height = CHARACTER_HEIGHT, translation = UP * CHARACTER_HEIGHT * 0.5]), collisionLayer = uint8(CollisionLayer.Character)))
        add_component(enemy, new Health())
        add_component(enemy, new PlayerInfo(team = ENEMY_TEAM))
        add_component(enemy, new BotSimpleAi()) // NOTE: bot
        add_component(enemy, new CharacterLook())
        add_component(enemy, new CharacterMovement())
        add_component(enemy, new WeaponController())

        add_component(enemy, new CharacterVisual(teamColor = float4(0.8, 0.5, 0.1, 1.0)))
        spawn_at_team_point(enemy, ENEMY_TEAM)
    }

    def override on_update() {
        update_respawns()
    }
}

