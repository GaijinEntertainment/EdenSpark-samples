require engine.core
require game

class ScoreSetHudBehavior : Component {
    def override on_update() {
        get_component(nodeId) $(var text : UIText?) {
            text.text = "{get_current_score()}"
        }
    }
}
