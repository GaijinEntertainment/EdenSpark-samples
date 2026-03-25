require engine.core
require scripts.user_settings

class SetTurnModeBehavior : Component {
    def override on_initialize() : void {
        get_component(nodeId) $(var btn : UIButton?) {
            btn.onClick = @() {
                userSettings.turnMode = userSettings.turnMode == TurnMode.Instant ? TurnMode.Inertial : TurnMode.Instant
                (get_component(nodeId, type<UIText>)).text = userSettings.turnMode == TurnMode.Instant ? "INSTANT" : "INERTIAL"
            }
        }
        (get_component(nodeId, type<UIText>)).text = userSettings.turnMode == TurnMode.Instant ? "INSTANT" : "INERTIAL"
    }
}
