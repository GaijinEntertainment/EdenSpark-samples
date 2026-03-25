require engine.core
require game

class GameUpdateBehavior : Component {

    def override on_initialize() : void {
        show_mouse_cursor(false)
        set_mouse_cursor_locked(true)
    }

    def override on_update() {
        let gameIsOver = update_game()
        if (gameIsOver) {
            instantiate_prefab(request_prefab("prefabs/ui/game_over_menu.prefab"))
        }
    }
}
