require engine.core
require game
require top_score

class ScoreSetMenuBehavior : Component {
    def override on_initialize() : void {
        let score = get_current_score()
        let prevTopScore = get_top_score()
        let isNewRecord = score > prevTopScore
        if (isNewRecord) {
            set_top_score(score)
        }

        get_component(nodeId) $(var text : UIText?) {
            text.text = "SCORE{isNewRecord ? " (NEW RECORD!)" : ""}: {score}"
        }
    }
}
