require engine.core
require top_score
require show_confirm_box

class ClearTopScoreBehavior : Component {

    def override on_initialize() : void {
        get_component(nodeId) $(var btn : UIButton?) {
            btn.onClick = @() {
                show_confirm_box("WANT TO CLEAR?") <| @() {
                    set_top_score(0)
                }
            }
        }
    }
}
