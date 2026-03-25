require engine.core
require game

class KickGameReloadBehavior : Component {
    def override on_initialize() : void {
        kick_game_reload()
    }
}
