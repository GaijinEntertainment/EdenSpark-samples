require engine.core
require top_score

class TopScoreSetBehavior : Component {
    def override on_initialize() {
        show_top_score()
    }

    def override on_update() {
        show_top_score()
    }

    def show_top_score() {
        get_component(nodeId) $(var text : UIText?) {
            text.text = "TOP SCORE: {get_top_score()}"
        }
    }
}
